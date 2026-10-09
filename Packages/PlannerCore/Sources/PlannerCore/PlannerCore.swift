import Foundation
import SwiftData

public actor Planner {
  private let configuration: PlannerStorageConfiguration
  private var sessions: [UUID: PlannerDatasetSession] = [:]
  private struct QueryBinding {
    let snapshot: PlannerQuerySnapshot
    let historyToken: DefaultHistoryToken?
  }
  private var querySnapshots: [UUID: QueryBinding] = [:]
  private enum ItemStateChange {
    case archive(Bool)
    case completion(Bool)
  }

  public init(configuration: PlannerStorageConfiguration) {
    self.configuration = configuration
  }

  public func bootstrap() -> PlannerBootstrapResult {
    do {
      try validateConfiguration()
      if configuration.processRole == .shareExtension,
        !FileManager.default.fileExists(atPath: configuration.controlURL.path)
      {
        return .mainAppSetupRequired
      }
      return try coordinated {
        var identity: PlannerStoreIdentity
        if FileManager.default.fileExists(atPath: configuration.controlURL.path) {
          identity = try loadIdentity()
          guard (1...6).contains(identity.schemaVersion) else {
            throw PlannerFailure(
              "unsupportedVersion", "The dataset uses an unsupported storage schema.")
          }
          if identity.schemaVersion < 6, configuration.processRole == .shareExtension {
            return .mainAppMigrationRequired
          }
          guard FileManager.default.fileExists(atPath: configuration.storeURL.path) else {
            throw PlannerFailure(
              "unavailable",
              "The initialized dataset's store is missing; recovery remains separate.")
          }
        } else {
          guard configuration.processRole == .mainApplication else { return .mainAppSetupRequired }
          try FileManager.default.createDirectory(
            at: configuration.storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
          )
          let container = try openContainer()
          let context = ModelContext(container)
          context.autosaveEnabled = false
          try context.save()
          identity = PlannerStoreIdentity(
            schemaVersion: 6, datasetId: UUID(), epochId: UUID(), namespaceId: UUID(),
            ownershipBinding: "local:" + UUID().uuidString
          )
          try plannerWriteDurably(JSONEncoder().encode(identity), to: configuration.controlURL)
        }
        _ = try openContainer()
        if identity.schemaVersion < 6 {
          identity = PlannerStoreIdentity(
            schemaVersion: 6, datasetId: identity.datasetId, epochId: identity.epochId,
            namespaceId: identity.namespaceId, ownershipBinding: identity.ownershipBinding)
          try plannerWriteDurably(JSONEncoder().encode(identity), to: configuration.controlURL)
        }
        let archive = recoveryArchive(identity)
        let metadataURL = archive.namespaceURL.appendingPathComponent("identity.json")
        if FileManager.default.fileExists(atPath: metadataURL.path) {
          let recorded = try JSONDecoder().decode(
            PlannerStoreIdentity.self, from: Data(contentsOf: metadataURL))
          guard recorded.datasetId == identity.datasetId,
            recorded.namespaceId == identity.namespaceId,
            recorded.ownershipBinding == identity.ownershipBinding,
            recorded.epochId == identity.epochId
          else {
            throw PlannerFailure(
              "ownershipUnverified",
              "The independent recovery namespace belongs to another dataset.")
          }
          if recorded.schemaVersion != identity.schemaVersion {
            try plannerWriteDurably(JSONEncoder().encode(identity), to: metadataURL)
          }
        } else {
          try plannerWriteDurably(JSONEncoder().encode(identity), to: metadataURL)
        }
        let session = PlannerDatasetSession(
          datasetId: identity.datasetId, sessionId: UUID(),
          ownershipBinding: identity.ownershipBinding, epochId: identity.epochId
        )
        sessions[session.sessionId] = session
        return .ready(session)
      }
    } catch {
      return .unavailable(failure(error, code: "unavailable"))
    }
  }

  public func execute(_ operation: PlannerOperation) -> PlannerOperationResult {
    do {
      return try coordinated {
        let identity = try validateSession(operation.session)
        let container = try openContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let archive = recoveryArchive(identity)
        let receipts = try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>())
        let envelope = try archive.latest()
        switch operation.command {
        case .createList(let content):
          return try executeListCreation(
            operation, content: content, identity: identity, context: context, archive: archive,
            receipts: receipts, envelope: envelope)
        case .createSchedule(let source, let form):
          return try executeScheduleCreation(
            operation, source: source, form: form, identity: identity, context: context,
            archive: archive, receipts: receipts, envelope: envelope)
        case .setCompletion(let scope, let done):
          switch scope {
          case .globalItem(let itemId):
            return try executeItemStateChange(
              operation, source: PlannerEntityReference(kind: .item, id: itemId),
              change: .completion(done), identity: identity, context: context,
              archive: archive, receipts: receipts, envelope: envelope)
          }
        case .setArchive(let source, let archived):
          return try executeItemStateChange(
            operation, source: source, change: .archive(archived), identity: identity,
            context: context,
            archive: archive, receipts: receipts, envelope: envelope)
        case .editItem(let sourceId, let changes, let expectedFieldHashes):
          return try executeItemEdit(
            operation, sourceId: sourceId, changes: changes, hashes: expectedFieldHashes,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope
          )
        case .editSchedule(let scheduleId, let changes, let expectedFieldHashes):
          return try executeScheduleChange(
            operation, scheduleId: scheduleId, change: .form(changes.form),
            hashes: expectedFieldHashes,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .changeScheduleZone(let scheduleId, let planningTimeZone, let expectedFieldHashes):
          return try executeScheduleChange(
            operation, scheduleId: scheduleId, change: .zone(planningTimeZone),
            hashes: expectedFieldHashes,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .removeSchedule(let scheduleId):
          return try executeScheduleChange(
            operation, scheduleId: scheduleId, change: .remove, hashes: [:],
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .createItem(let content):
          try content.validate()
          let digest = content.payloadDigest(
            datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding)
          if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
            guard receipt.payloadDigest == digest else {
              throw PlannerFailure(
                "operationPayloadMismatch",
                "This operation identity already describes different content.")
            }
            let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
            return appliedResult(
              operationId: operation.operationId, evidence: evidence, envelope: envelope)
          }
          let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
          guard
            receipts.allSatisfy({ receipt in
              receipt.operationId.map { completedIds.contains($0) } ?? false
            })
          else {
            throw PlannerFailure(
              "mutationBlocked", "A prior applied action still needs independent recovery.")
          }
          if let proposal = try archive.proposals().first(where: {
            $0.originalOperationId == operation.operationId
          }) {
            guard proposal.payloadDigest == digest else {
              throw PlannerFailure(
                "operationPayloadMismatch", "Prepared evidence describes a different payload.")
            }
            return PlannerOperationResult(
              operationId: operation.operationId, outcome: .unverified(proposal.summary))
          }
          let item = try PlannerSchemaV5.Item(input: content)
          let snapshot = try item.value()
          let result = PlannerAppliedResult(
            generated: [snapshot.reference], affected: [snapshot.reference])
          let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV5.Item>()).map {
            try $0.value()
          }
          let proposal = RecoveryPreparedProposal(
            proposalId: UUID(), originalOperationId: operation.operationId,
            datasetId: identity.datasetId,
            ownershipBinding: identity.ownershipBinding,
            proposedBackup: PlannerDataSnapshot(
              items: existingItems + [snapshot], lists: try listSnapshots(context),
              deletionMarkers: try deletionMarkers(context)),
            payloadDigest: digest, evidence: "preparedUnverified"
          )
          try archive.prepare(proposal)
          let receipt = try PlannerSchemaV1.Receipt(
            operation: operation, digest: digest, result: result)
          context.insert(item)
          context.insert(receipt)
          do { try context.save() } catch {
            context.rollback()
            throw PlannerFailure(
              "persistenceFailure",
              "The complete Item action was not committed: \(error.localizedDescription)")
          }
          do {
            let generation = try archive.publish(
              items: existingItems + [snapshot], lists: try listSnapshots(context),
              deletionMarkers: try deletionMarkers(context),
              receipts: receipts + [receipt])
            return PlannerOperationResult(
              operationId: operation.operationId,
              outcome: .applied(
                result: result, recovery: .complete(checkpointGeneration: generation)
              ))
          } catch {
            return PlannerOperationResult(
              operationId: operation.operationId,
              outcome: .applied(
                result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))
              ))
          }
        }
      }
    } catch {
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .rejected(failure(error, code: "persistenceFailure")))
    }
  }

  public func read(session: PlannerDatasetSession, request: PlannerReadRequest) -> PlannerReadResult
  {
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let container = try openContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        switch request {
        case .rows(let generation, let offset, let limit):
          return .rows(
            try readRows(
              session: session, context: context, generation: generation, offset: offset,
              limit: limit))
        case .source(let source):
          if source.kind == .list {
            let sourceIdentifier = source.id
            var descriptor = FetchDescriptor<PlannerSchemaV6.List>(
              predicate: #Predicate { $0.id == sourceIdentifier })
            descriptor.fetchLimit = 2
            let records = try context.fetch(descriptor)
            guard records.count == 1, let record = records.first else {
              throw PlannerFailure(
                "missingReference", "The selected List is missing or unresolved.")
            }
            return .source(.list(try record.value().read(datasetId: identity.datasetId)))
          }
          if source.kind == .schedule {
            return .source(
              .schedule(
                try readSchedule(source, datasetId: identity.datasetId, context: context)))
          }
          guard source.kind == .item else {
            throw PlannerFailure(
              "unavailable", "This fixture currently implements Item reads only.")
          }
          let items = try context.fetch(FetchDescriptor<PlannerSchemaV5.Item>()).filter {
            $0.id == source.id
          }
          guard items.count == 1, let item = items.first else {
            throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
          }
          return .source(.item(try item.value().read(datasetId: identity.datasetId)))
        }
      }
    } catch { return .failed(failure(error, code: "readUnavailable")) }
  }

  private func readSchedule(
    _ source: PlannerEntityReference, datasetId: UUID, context: ModelContext
  ) throws -> PlannerScheduleSourceRead {
    let identifier = source.id
    var descriptor = FetchDescriptor<PlannerSchemaV5.Schedule>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected Schedule is missing or unresolved.")
    }
    guard let ownerIdentifier = record.sourceId, let ownerLifetime = record.sourceLifetimeId else {
      throw PlannerFailure("readUnavailable", "The Schedule's source binding is unresolved.")
    }
    var owners = FetchDescriptor<PlannerSchemaV5.Item>(
      predicate: #Predicate { $0.id == ownerIdentifier && $0.lifetimeId == ownerLifetime })
    owners.fetchLimit = 2
    owners.propertiesToFetch = [\.id, \.lifetimeId]
    guard try context.fetch(owners).count == 1 else {
      throw PlannerFailure(
        "readUnavailable", "The Schedule's source Item is missing or unresolved.")
    }
    let snapshot = try record.value(ownerId: ownerIdentifier, ownerLifetimeId: ownerLifetime)
    return PlannerScheduleSourceRead(
      source: snapshot.reference,
      content: PlannerScheduleContent(
        source: PlannerEntityReference(kind: .item, id: ownerIdentifier), form: snapshot.form),
      fieldHashes: [.form: snapshot.formHash(datasetId: datasetId)])
  }

  public func query(_ query: PlannerQuery) -> PlannerQueryResult {
    do {
      return try coordinated {
        _ = try validateSession(query.session)
        let container = try openContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        switch query.request {
        case .items(let itemQuery):
          let presentation = try
            (itemQuery.rowPresentation
            ?? PlannerRowPresentationContext(
              referenceInstant: Date(), displayTimeZone: TimeZone.current.identifier)).validated()
          switch itemQuery.scope {
          case .global, .inbox: break
          case .list, .itinerary:
            throw PlannerFailure(
              "unavailable", "This Item-only fixture does not implement contextual queries.")
          }
          let historyToken = try latestHistoryToken(in: context)
          var descriptor = FetchDescriptor<PlannerSchemaV5.Item>()
          descriptor.propertiesToFetch = [\.id, \.title, \.globalDone, \.archived]
          let items = try context.fetch(descriptor).filter { item in
            switch itemQuery.completion {
            case .todo: if item.globalDone { return false }
            case .done: if !item.globalDone { return false }
            case .all: break
            }
            switch itemQuery.archive {
            case .active: return !item.archived
            case .archived: return item.archived
            case .all: return true
            }
          }
          let values = try items.map { item in
            guard let id = item.id,
              !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
              throw PlannerFailure(
                "readUnavailable", "A query Item has unresolved identity or title.")
            }
            return (reference: PlannerEntityReference(kind: .item, id: id), title: item.title)
          }
          guard Set(values.map { $0.reference.id }).count == values.count else {
            throw PlannerFailure(
              "readUnavailable", "Query Item identities are duplicated and unresolved.")
          }
          let comparator = String.Comparator(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
          )
          let sorted = values.sorted { first, second in
            let comparison = comparator.compare(first.title, second.title)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return first.reference.id.uuidString < second.reference.id.uuidString
          }
          let snapshot = PlannerQuerySnapshot(
            session: query.session, generation: UUID(),
            rows: sorted.map { .source($0.reference) },
            matchingCount: Int64(sorted.count), rowPresentation: presentation)
          guard try latestHistoryToken(in: context) == historyToken else {
            throw PlannerFailure("readUnavailable", "The store changed while building this query.")
          }
          querySnapshots = querySnapshots.filter { $0.value.historyToken == historyToken }
          querySnapshots[snapshot.generation] = QueryBinding(
            snapshot: snapshot, historyToken: historyToken)
          return .snapshot(snapshot)
        }
      }
    } catch { return .failed(failure(error, code: "readUnavailable")) }
  }

  private func readRows(
    session: PlannerDatasetSession, context: ModelContext, generation: UUID, offset: Int64,
    limit: Int64
  ) throws -> PlannerRowWindow {
    guard offset >= 0, limit > 0 else {
      throw PlannerFailure("invalidInput", "Row offset must be nonnegative and limit positive.")
    }
    guard let binding = querySnapshots[generation], binding.snapshot.session == session else {
      throw staleSnapshot(generation)
    }
    guard try latestHistoryToken(in: context) == binding.historyToken else {
      querySnapshots.removeValue(forKey: generation)
      throw staleSnapshot(generation)
    }
    let snapshot = binding.snapshot
    let identities: [PlannerRowIdentity]
    if offset >= snapshot.matchingCount {
      identities = []
    } else {
      let count = min(limit, snapshot.matchingCount - offset)
      identities = Array(snapshot.rows.dropFirst(Int(offset)).prefix(Int(count)))
    }
    let rows = try identities.map { identity in
      switch identity {
      case .source(let source):
        guard let presentation = snapshot.rowPresentation else {
          throw PlannerFailure("readUnavailable", "The Item query has no presentation context.")
        }
        let sourceIdentifier = source.id
        var descriptor = FetchDescriptor<PlannerSchemaV5.Item>(
          predicate: #Predicate { $0.id == sourceIdentifier })
        descriptor.fetchLimit = 2
        descriptor.propertiesToFetch = [
          \.id, \.lifetimeId, \.title, \.subtitle, \.locationData, \.estimateData,
          \.globalDone, \.archived,
        ]
        let records = try context.fetch(descriptor)
        guard records.count == 1, let item = records.first else {
          throw PlannerFailure("readUnavailable", "A snapshot Item is missing or unresolved.")
        }
        guard let lifetimeId = item.lifetimeId else {
          throw PlannerFailure("readUnavailable", "The row Item has unresolved lifetime.")
        }
        let owned = FetchDescriptor<PlannerSchemaV5.OwnedLink>(
          predicate: #Predicate {
            $0.ownerId == sourceIdentifier && $0.ownerLifetimeId == lifetimeId
          })
        var selected = FetchDescriptor<PlannerSchemaV5.OwnedLink>(
          predicate: #Predicate {
            $0.ownerId == sourceIdentifier && $0.ownerLifetimeId == lifetimeId
              && $0.kind != "appleMaps" && $0.kind != "googleMaps"
          }, sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
        selected.fetchLimit = 1
        selected.propertiesToFetch = [
          \.id, \.lifetimeId, \.ownerId, \.ownerLifetimeId, \.rank, \.originalUrl, \.label, \.kind,
        ]
        let preview = try context.fetch(selected).first?.value(
          ownerId: sourceIdentifier, ownerLifetimeId: lifetimeId
        ).read
        let summary = try rowScheduleSummary(
          source: source, lifetimeId: lifetimeId,
          presentation: presentation, context: context)
        return try item.rowRead(
          hasLinks: context.fetchCount(owned) > 0, previewLink: preview, scheduleSummary: summary)
      }
    }
    guard try latestHistoryToken(in: context) == binding.historyToken else {
      querySnapshots.removeValue(forKey: generation)
      throw staleSnapshot(generation)
    }
    return PlannerRowWindow(
      generation: generation, offset: offset, matchingCount: snapshot.matchingCount,
      rowPresentation: snapshot.rowPresentation, rows: rows)
  }

  private func rowScheduleSummary(
    source: PlannerEntityReference, lifetimeId: UUID, presentation: PlannerRowPresentationContext,
    context: ModelContext
  ) throws -> PlannerRowScheduleSummary {
    let sourceIdentifier = source.id
    let referenceInstant = presentation.referenceInstant
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: presentation.displayTimeZone)!
    let currentDate = try scheduleCivilDate(referenceInstant, calendar: calendar)
    let assignments = FetchDescriptor<PlannerSchemaV5.Schedule>(
      predicate: #Predicate {
        $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
      })
    let assignmentCount = try context.fetchCount(assignments)
    guard assignmentCount > 0 else { return .none }
    let candidates = [
      FetchDescriptor<PlannerSchemaV5.Schedule>(
        predicate: #Predicate {
          $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) <= referenceInstant
            && $0.end != nil && ($0.end ?? referenceInstant) > referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV5.Schedule>(
        predicate: #Predicate {
          $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) >= referenceInstant
        }, sortBy: [SortDescriptor(\.start), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV5.Schedule>(
        predicate: #Predicate {
          $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) < referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
    ]
    var allDayDescriptor = FetchDescriptor<PlannerSchemaV5.Schedule>(
      predicate: #Predicate {
        $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
          && $0.formKind == "allDay"
      })
    allDayDescriptor.propertiesToFetch = [
      \.id, \.lifetimeId, \.sourceId, \.sourceLifetimeId, \.formKind, \.civilStartData,
      \.civilEndData, \.start, \.end, \.planningTimeZone,
    ]
    let civilAssignments = try context.fetch(allDayDescriptor).map {
      try $0.value(ownerId: sourceIdentifier, ownerLifetimeId: lifetimeId)
    }
    for (phase, candidateDescriptor) in candidates.enumerated() {
      var descriptor = candidateDescriptor
      descriptor.fetchLimit = 1
      descriptor.propertiesToFetch = [
        \.id, \.lifetimeId, \.sourceId, \.sourceLifetimeId, \.start, \.end, \.planningTimeZone,
        \.formKind, \.civilStartData, \.civilEndData,
      ]
      var eligible = civilAssignments.filter { candidate in
        guard case .allDay(let start, let end) = candidate.form else { return false }
        let finalDate = end ?? start
        if !currentDate.isEarlier(than: start), !finalDate.isEarlier(than: currentDate) {
          return phase == 0
        }
        if currentDate.isEarlier(than: start) { return phase == 1 }
        return phase == 2
      }
      if let record = try context.fetch(descriptor).first {
        eligible.append(try record.value(ownerId: sourceIdentifier, ownerLifetimeId: lifetimeId))
      }
      let keyed = try eligible.map {
        (assignment: $0, components: try scheduleStartComponents($0.form, calendar: calendar))
      }
      let selected = keyed.sorted { first, second in
        if first.components == second.components {
          return first.assignment.id.uuidString < second.assignment.id.uuidString
        }
        if phase == 1 { return first.components.lexicographicallyPrecedes(second.components) }
        return second.components.lexicographicallyPrecedes(first.components)
      }.first
      guard let value = selected?.assignment else { continue }
      return .directItem(
        schedule: value.reference, owner: source, form: value.form,
        additionalCount: Int64(assignmentCount - 1))
    }
    throw PlannerFailure("readUnavailable", "The Item's Schedule assignments are unresolved.")
  }

  private func latestHistoryToken(in context: ModelContext) throws -> DefaultHistoryToken? {
    var descriptor = HistoryDescriptor<DefaultHistoryTransaction>(
      sortBy: [SortDescriptor(\.transactionIdentifier, order: .reverse)])
    descriptor.fetchLimit = 1
    return try context.fetchHistory(descriptor).first?.token
  }

  private func staleSnapshot(_ generation: UUID) -> PlannerFailure {
    PlannerFailure(
      "staleSnapshot", "Run the query again before requesting this row window.",
      details: .staleSnapshot(requestedGeneration: generation, currentGeneration: nil))
  }

  public func operationStatus(session: PlannerDatasetSession, operationId: UUID)
    -> PlannerOperationStatus
  {
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let archive = recoveryArchive(identity)
        let envelope = try archive.latest()
        if let receipt = envelope?.receipts.first(where: { $0.operationId == operationId }),
          let value = receipt.checkpointGeneration, let generation = Int64(value)
        {
          return .appliedRecoveryComplete(result: receipt.result, checkpointGeneration: generation)
        }
        let container = try openContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        if let receipt = try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>()).first(
          where: { $0.operationId == operationId })
        {
          let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
          return .appliedRecoveryIncomplete(
            result: evidence.result,
            reason: PlannerFailure("recoveryIncomplete", "Independent recovery is not established.")
          )
        }
        if let proposal = try archive.proposals().first(where: {
          $0.originalOperationId == operationId
        }) {
          return .preparedUnverified(proposal.summary)
        }
        return .noReliableEvidence
      }
    } catch { return .unavailable(failure(error, code: "readUnavailable")) }
  }

  public func inspectRecovery(request: PlannerRecoveryRequest) -> PlannerRecoveryInspection {
    do {
      let archives = try discoveredArchives()
      switch request {
      case .namespaces: return .listedNamespaces(try archives.map { try $0.view() })
      case .namespace(let namespaceId):
        return .listed(try requireArchive(archives, namespaceId: namespaceId).view())
      case .acknowledgedSnapshot(let namespaceId, let generation):
        return .selected(
          try requireArchive(archives, namespaceId: namespaceId).selection(generation: generation))
      case .proposal:
        throw PlannerFailure(
          "unavailable", "Selecting prepared proposals is not implemented by this first fixture.")
      }
    } catch { return .failed(failure(error, code: "readUnavailable")) }
  }

  private func scheduleCivilDate(_ instant: Date, calendar: Calendar) throws -> PlannerCivilDate {
    let components = calendar.dateComponents([.era, .year, .month, .day], from: instant)
    guard let era = components.era, let year = components.year, let month = components.month,
      let day = components.day
    else {
      throw PlannerFailure("readUnavailable", "The calendar display date is unavailable.")
    }
    return PlannerCivilDate(year: era == 0 ? 1 - year : year, month: month, day: day)
  }

  private func scheduleStartComponents(_ form: PlannerScheduleForm, calendar: Calendar) throws
    -> [Int]
  {
    switch form {
    case .allDay(let start, _): return [start.year, start.month, start.day, 0, 0, 0, 0]
    case .timed(let start, _, _):
      let date = try scheduleCivilDate(start, calendar: calendar)
      let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: start)
      guard let hour = time.hour, let minute = time.minute, let second = time.second,
        let nanosecond = time.nanosecond
      else {
        throw PlannerFailure("readUnavailable", "The calendar display time is unavailable.")
      }
      return [date.year, date.month, date.day, hour, minute, second, nanosecond]
    }
  }

  private func executeListCreation(
    _ operation: PlannerOperation, content: PlannerListContentInput, identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive, receipts: [PlannerSchemaV1.Receipt],
    envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    try content.validate()
    let digest = content.payloadDigest(identity: identity)
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch",
          "This operation identity already describes different content.")
      }
      let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
      return appliedResult(
        operationId: operation.operationId, evidence: evidence, envelope: envelope)
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard
      receipts.allSatisfy({ receipt in
        receipt.operationId.map { completedIds.contains($0) } ?? false
      })
    else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes a different payload.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let list = try PlannerSchemaV6.List(content: content)
    let snapshot = try list.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingLists = try listSnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV5.Item>()).map {
      try $0.value()
    }
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        items: existingItems, lists: existingLists + [snapshot],
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified"
    )
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result)
    context.insert(list)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete List action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: existingItems, lists: existingLists + [snapshot],
        deletionMarkers: try deletionMarkers(context),
        receipts: receipts + [receipt])
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .complete(checkpointGeneration: generation)
        ))
    } catch {
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))
        ))
    }
  }

  private func listSnapshots(_ context: ModelContext) throws -> [ListSnapshot] {
    try context.fetch(FetchDescriptor<PlannerSchemaV6.List>()).map { try $0.value() }
  }

  private func deletionMarkers(_ context: ModelContext) throws -> [PortableDeletionMarker] {
    try context.fetch(FetchDescriptor<PlannerSchemaV4.DeletionMarker>()).map { try $0.value() }
  }

  private func executeScheduleChange(
    _ operation: PlannerOperation, scheduleId: UUID, change: ScheduleChange,
    hashes: [PlannerScheduleField: PlannerFieldHash], identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive, receipts: [PlannerSchemaV1.Receipt],
    envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    try change.validate()
    let expectedHash = hashes[.form]
    if change.requiresFormHash {
      guard let expectedHash else {
        throw PlannerFailure(
          "invalidInput", "The Schedule form requires its prior hash.",
          propertyPath: "/command/expectedFieldHashes/form")
      }
      let prefix = "sha256-v1:"
      let suffix = expectedHash.value.dropFirst(prefix.count)
      guard expectedHash.value.hasPrefix(prefix), suffix.count == 64,
        suffix.allSatisfy({ "0123456789abcdef".contains($0) })
      else {
        throw PlannerFailure(
          "invalidInput", "The supplied form hash has an unsupported format.",
          propertyPath: "/command/expectedFieldHashes/form")
      }
    }
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      guard
        receipt.payloadDigest
          == change.editDigest(
            scheduleId: scheduleId,
            expectedFormHash: expectedHash, identity: identity, bindings: stored.bindings)
      else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes a different edit.")
      }
      return appliedResult(
        operationId: operation.operationId,
        evidence: try RecoveryReceipt(receipt, checkpoint: nil), envelope: envelope)
    }
    let completedIdentifiers = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIdentifiers.contains($0) } ?? false })
    else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    var assignments = FetchDescriptor<PlannerSchemaV5.Schedule>(
      predicate: #Predicate { $0.id == scheduleId })
    assignments.fetchLimit = 2
    let records = try context.fetch(assignments)
    guard records.count == 1, let record = records.first,
      let ownerIdentifier = record.sourceId, let ownerLifetime = record.sourceLifetimeId
    else {
      throw PlannerFailure("missingReference", "The selected Schedule is missing or unresolved.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV5.Item>())
    let owners = items.filter { $0.id == ownerIdentifier && $0.lifetimeId == ownerLifetime }
    guard owners.count == 1 else {
      throw PlannerFailure(
        "missingReference", "The Schedule's source Item is missing or unresolved.")
    }
    let before = try record.value(ownerId: ownerIdentifier, ownerLifetimeId: ownerLifetime)
    let bindings = [
      PlannerBoundIdentity(kind: "schedule", id: before.id, lifetimeId: before.lifetimeId),
      PlannerBoundIdentity(kind: "item", id: ownerIdentifier, lifetimeId: ownerLifetime),
    ]
    let digest = change.editDigest(
      scheduleId: scheduleId, expectedFormHash: expectedHash,
      identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes a different edit.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let currentHash = before.formHash(datasetId: identity.datasetId)
    if let expectedHash, currentHash != expectedHash {
      throw PlannerFailure(
        "staleEdit", "The Schedule form differs from the supplied read.",
        details: .staleScheduleEdit(currentForm: before.form, currentFormHash: currentHash))
    }
    let replacementForm = try change.applying(to: before.form)
    let after = replacementForm.map {
      ScheduleSnapshot(id: before.id, lifetimeId: before.lifetimeId, form: $0)
    }
    let removalMarker: PortableDeletionMarker?
    if replacementForm == nil {
      removalMarker = PortableDeletionMarker(
        deletionId: UUID(), operationId: operation.operationId,
        target: .source(
          PlannerBoundIdentity(kind: "schedule", id: before.id, lifetimeId: before.lifetimeId)),
        closedFamilyId: nil)
    } else {
      removalMarker = nil
    }
    let markers = try deletionMarkers(context) + [removalMarker].compactMap { $0 }
    let snapshots = try items.map { item in
      var snapshot = try item.value()
      if item.id == ownerIdentifier {
        snapshot.schedules = snapshot.schedules.compactMap { schedule in
          if schedule.id == scheduleId { return after }
          return schedule
        }
      }
      return snapshot
    }
    let result = PlannerAppliedResult(
      generated: [],
      affected: [
        before.reference,
        PlannerEntityReference(kind: .item, id: ownerIdentifier),
      ])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(),
        originalOperationId: operation.operationId, datasetId: identity.datasetId,
        ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          items: snapshots, lists: try listSnapshots(context), deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest,
      result: result, bindings: bindings)
    if let replacementForm {
      try record.replace(with: replacementForm)
    } else if let removalMarker {
      context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
      context.delete(record)
    }
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Schedule change was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: snapshots, lists: try listSnapshots(context), deletionMarkers: markers,
        receipts: receipts + [receipt])
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func executeScheduleCreation(
    _ operation: PlannerOperation, source: PlannerEntityReference, form: PlannerScheduleForm,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    try form.validate()
    guard source.kind == .item else {
      throw PlannerFailure(
        "unavailable", "This Schedule slice supports direct Item assignments only.",
        propertyPath: "/command/source/kind")
    }
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      guard
        receipt.payloadDigest
          == form.creationDigest(source: source, identity: identity, bindings: stored.bindings)
      else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes a different Schedule.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: try RecoveryReceipt(receipt, checkpoint: nil),
        envelope: envelope)
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV5.Item>())
    let matches = items.filter { $0.id == source.id }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure(
        "missingReference", "The selected Item is missing or unresolved.",
        propertyPath: "/command/source")
    }
    let before = try item.value()
    let bindings = [
      PlannerBoundIdentity(kind: "item", id: before.id, lifetimeId: before.lifetimeId)
    ]
    let digest = form.creationDigest(source: source, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes a different Schedule.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let assignment = ScheduleSnapshot(id: UUID(), lifetimeId: UUID(), form: form)
    let after = ItemSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: before.updatedAt,
      input: before.input, globalDone: before.globalDone, archived: before.archived,
      links: before.links,
      schedules: before.schedules + [assignment])
    let snapshots = try items.map { record in
      if record.id == source.id { return after }
      return try record.value()
    }
    let result = PlannerAppliedResult(
      generated: [assignment.reference], affected: [before.reference, assignment.reference])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId,
        ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          items: snapshots, lists: try listSnapshots(context),
          deletionMarkers: try deletionMarkers(context)),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    context.insert(try PlannerSchemaV5.Schedule(snapshot: assignment, owner: item))
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Schedule was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: snapshots, lists: try listSnapshots(context),
        deletionMarkers: try deletionMarkers(context),
        receipts: receipts + [receipt])
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func executeItemEdit(
    _ operation: PlannerOperation, sourceId: UUID, changes: PlannerItemChanges,
    hashes: [PlannerItemField: PlannerFieldHash], identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    let changedFields = try changes.validatedFields()
    for field in changedFields where hashes[field] == nil {
      throw PlannerFailure(
        "invalidInput", "Every changed field requires its prior hash.",
        propertyPath: "/command/expectedFieldHashes/\(field.rawValue)")
    }
    for (field, hash) in hashes {
      let prefix = "sha256-v1:"
      let suffix = hash.value.dropFirst(prefix.count)
      guard hash.value.hasPrefix(prefix), suffix.count == 64,
        suffix.allSatisfy({ "0123456789abcdef".contains($0) })
      else {
        throw PlannerFailure(
          "invalidInput", "A supplied field hash has an unsupported format.",
          propertyPath: "/command/expectedFieldHashes/\(field.rawValue)")
      }
    }
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      let digest = try changes.editPayloadDigest(
        sourceId: sourceId, fields: changedFields, hashes: hashes,
        identity: identity, bindings: stored.bindings
      )
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity already describes a different edit.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: try RecoveryReceipt(receipt, checkpoint: nil),
        envelope: envelope)
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV5.Item>())
    let matches = items.filter { $0.id == sourceId }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
    }
    let before = try item.value()
    let bindings =
      [
        PlannerBoundIdentity(kind: "item", id: before.id, lifetimeId: before.lifetimeId)
      ] + (try changes.linkBindings(in: before))
    let digest = try changes.editPayloadDigest(
      sourceId: sourceId, fields: changedFields, hashes: hashes, identity: identity,
      bindings: bindings
    )
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes a different edit.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let fieldHashes = before.input.fieldHashes(
      datasetId: identity.datasetId, itemId: before.id, lifetimeId: before.lifetimeId,
      links: before.links.map(\.read)
    )
    let conflictingFields = changedFields.filter { fieldHashes[$0] != hashes[$0] }
    if !conflictingFields.isEmpty {
      var currentValues: [PlannerItemField: PlannerItemFieldValue] = [:]
      var currentHashes: [PlannerItemField: PlannerFieldHash] = [:]
      for field in conflictingFields {
        guard let hash = fieldHashes[field] else {
          throw PlannerFailure("readUnavailable", "A changed field has no current hash.")
        }
        currentHashes[field] = hash
        if field == .title { currentValues[field] = .string(before.input.title) }
        if field == .notes { currentValues[field] = .optionalString(before.input.notes) }
        if field == .location { currentValues[field] = .optionalLocation(before.input.location) }
        if field == .links { currentValues[field] = .links(before.links.map(\.read)) }
      }
      throw PlannerFailure(
        "staleEdit", "Changed fields differ from the supplied read.",
        details: .staleEdit(
          conflictingFields: conflictingFields, currentValues: currentValues,
          currentFieldHashes: currentHashes
        ))
    }
    let now = Date()
    let updatedInput = try changes.applyingChanges(to: before.input)
    let updatedLocationData = try updatedInput.location.map { try JSONEncoder().encode($0) }
    let updatedLinks = try changes.applyingLinks(to: before)
    let after = ItemSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt, updatedAt: now,
      input: updatedInput, globalDone: before.globalDone, archived: before.archived,
      links: updatedLinks, schedules: before.schedules
    )
    let snapshots = try items.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let result = PlannerAppliedResult(generated: [], affected: [before.reference])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        items: snapshots, lists: try listSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified"
    )
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if changedFields.contains(.title) { item.title = updatedInput.title }
    if changedFields.contains(.notes) { item.notes = updatedInput.notes }
    if changedFields.contains(.location) { item.locationData = updatedLocationData }
    if changedFields.contains(.links) { item.replaceLinks(with: updatedLinks, context: context) }
    item.updatedAt = now
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Item edit was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: snapshots, lists: try listSnapshots(context),
        deletionMarkers: try deletionMarkers(context),
        receipts: receipts + [receipt])
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func executeItemStateChange(
    _ operation: PlannerOperation, source: PlannerEntityReference, change: ItemStateChange,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    guard source.kind == .item else {
      throw PlannerFailure(
        "unavailable", "This fixture currently changes Item states only.",
        propertyPath: "/command/source/kind")
    }
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      let digest = itemStatePayloadDigest(
        source: source, change: change, identity: identity, bindings: stored.bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch",
          "This operation identity already describes a different action.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: try RecoveryReceipt(receipt, checkpoint: nil),
        envelope: envelope)
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV5.Item>())
    let matches = items.filter { $0.id == source.id }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
    }
    let before = try item.value()
    let bindings = [
      PlannerBoundIdentity(kind: "item", id: before.id, lifetimeId: before.lifetimeId)
    ]
    let digest = itemStatePayloadDigest(
      source: source, change: change, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes a different action.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    var archived = before.archived
    var globalDone = before.globalDone
    switch change {
    case .archive(let value): archived = value
    case .completion(let value): globalDone = value
    }
    var updatedAt = before.updatedAt
    if archived != before.archived || globalDone != before.globalDone {
      updatedAt = Date()
    }
    let after = ItemSnapshot(
      id: before.id, lifetimeId: before.lifetimeId,
      createdAt: before.createdAt, updatedAt: updatedAt, input: before.input,
      globalDone: globalDone, archived: archived, links: before.links, schedules: before.schedules)
    let snapshots = try items.map { record in
      if record.id == source.id { return after }
      return try record.value()
    }
    let result = PlannerAppliedResult(generated: [], affected: [source])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        items: snapshots, lists: try listSnapshots(context),
        deletionMarkers: try deletionMarkers(context)), payloadDigest: digest,
      evidence: "preparedUnverified")
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    switch change {
    case .archive(let value): item.archived = value
    case .completion(let value): item.globalDone = value
    }
    item.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Item state action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: snapshots, lists: try listSnapshots(context),
        deletionMarkers: try deletionMarkers(context),
        receipts: receipts + [receipt])
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return PlannerOperationResult(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func itemStatePayloadDigest(
    source: PlannerEntityReference, change: ItemStateChange, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    let command: PlannerCanonicalValue
    switch change {
    case .archive(let archived):
      command = .record([
        "type": .string("setArchive"),
        "source": .record(["kind": .string(source.kind.rawValue), "id": .identity(source.id)]),
        "archived": .boolean(archived),
      ])
    case .completion(let done):
      command = .record([
        "type": .string("setCompletion"),
        "scope": .record(["kind": .string("globalItem"), "itemId": .identity(source.id)]),
        "done": .boolean(done),
      ])
    }
    let value = PlannerCanonicalValue.record([
      "command": command, "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    return plannerDigest(
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
      prefix: "sha256-payload-v1:")
  }

  private func appliedResult(
    operationId: UUID, evidence: RecoveryReceipt, envelope: RecoveryEnvelope?
  ) -> PlannerOperationResult {
    if let recovered = envelope?.receipts.first(where: {
      $0.operationId == operationId && $0.payloadDigest == evidence.payloadDigest
        && $0.result == evidence.result
    }), let checkpoint = recovered.checkpointGeneration.flatMap(Int64.init) {
      return PlannerOperationResult(
        operationId: operationId,
        outcome: .applied(
          result: evidence.result, recovery: .complete(checkpointGeneration: checkpoint)))
    }
    return PlannerOperationResult(
      operationId: operationId,
      outcome: .applied(
        result: evidence.result,
        recovery: .incomplete(
          PlannerFailure("recoveryIncomplete", "Independent recovery is not established."))))
  }

  private func validateConfiguration() throws {
    guard configuration.storeURL.isFileURL, configuration.controlURL.isFileURL,
      configuration.recoveryDirectoryURL.isFileURL,
      configuration.storeURL.standardizedFileURL != configuration.controlURL.standardizedFileURL,
      configuration.storeURL.standardizedFileURL
        != configuration.recoveryDirectoryURL.standardizedFileURL
    else {
      throw PlannerFailure(
        "invalidInput", "Store, control and recovery require distinct local file locations.")
    }
  }

  private func loadIdentity() throws -> PlannerStoreIdentity {
    let identity = try JSONDecoder().decode(
      PlannerStoreIdentity.self, from: Data(contentsOf: configuration.controlURL))
    guard identity.ownershipBinding.hasPrefix("local:"),
      !identity.ownershipBinding.dropFirst(6).isEmpty
    else {
      throw PlannerFailure(
        "ownershipUnverified", "The local dataset has no established ownership binding.")
    }
    return identity
  }

  private func validateSession(_ session: PlannerDatasetSession) throws -> PlannerStoreIdentity {
    let identity = try loadIdentity()
    guard sessions[session.sessionId] == session, session.datasetId == identity.datasetId,
      session.ownershipBinding == identity.ownershipBinding, session.epochId == identity.epochId,
      identity.schemaVersion == 6
    else {
      throw PlannerFailure("staleDatasetSession", "The dataset session is no longer authorized.")
    }
    return identity
  }

  private func openContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: PlannerSchemaV6.self)
    let modelConfiguration = ModelConfiguration(
      schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
    return try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self, configurations: [modelConfiguration])
  }

  private func recoveryArchive(_ identity: PlannerStoreIdentity) -> PlannerRecoveryArchive {
    PlannerRecoveryArchive(rootURL: configuration.recoveryDirectoryURL, identity: identity)
  }

  private func discoveredArchives() throws -> [PlannerRecoveryArchive] {
    let directories = try FileManager.default.contentsOfDirectory(
      at: configuration.recoveryDirectoryURL, includingPropertiesForKeys: nil
    )
    .filter { !$0.lastPathComponent.hasPrefix(".") }
    let archives = try directories.map { directory in
      let identity = try JSONDecoder().decode(
        PlannerStoreIdentity.self,
        from: Data(contentsOf: directory.appendingPathComponent("identity.json")))
      guard directory.lastPathComponent == identity.namespaceId.uuidString,
        (1...6).contains(identity.schemaVersion), !identity.ownershipBinding.isEmpty
      else {
        throw PlannerFailure(
          "ownershipUnverified", "A recovery namespace has invalid ownership metadata.")
      }
      return recoveryArchive(identity)
    }
    guard Set(archives.map { $0.identity.namespaceId }).count == archives.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Recovery namespace identities are duplicated.")
    }
    return archives.sorted {
      $0.identity.namespaceId.uuidString < $1.identity.namespaceId.uuidString
    }
  }

  private func requireArchive(_ archives: [PlannerRecoveryArchive], namespaceId: UUID) throws
    -> PlannerRecoveryArchive
  {
    guard let archive = archives.first(where: { $0.identity.namespaceId == namespaceId }) else {
      throw PlannerFailure("missingReference", "The selected recovery namespace is missing.")
    }
    return archive
  }

  private func coordinated<Value>(_ action: () throws -> Value) throws -> Value {
    try FileManager.default.createDirectory(
      at: configuration.controlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let coordinator = NSFileCoordinator()
    var coordinationError: NSError?
    var outcome: Result<Value, any Error>?
    coordinator.coordinate(
      writingItemAt: configuration.controlURL, options: [], error: &coordinationError
    ) { _ in
      outcome = Result { try action() }
    }
    if let coordinationError { throw coordinationError }
    guard let outcome else {
      throw PlannerFailure("unavailable", "The Planner writer gate did not execute.")
    }
    return try outcome.get()
  }

  private func failure(_ error: any Error, code: String) -> PlannerFailure {
    if let failure = error as? PlannerFailure { return failure }
    return PlannerFailure(code, error.localizedDescription)
  }
}
