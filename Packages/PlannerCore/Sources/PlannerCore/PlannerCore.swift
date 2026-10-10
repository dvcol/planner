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
  private enum ListChange {
    case content(PlannerListChanges, [PlannerListField: PlannerFieldHash])
    case archive(Bool)
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
          guard (1...7).contains(identity.schemaVersion) else {
            throw PlannerFailure(
              "unsupportedVersion", "The dataset uses an unsupported storage schema.")
          }
          if identity.schemaVersion < 7, configuration.processRole == .shareExtension {
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
            schemaVersion: 7, datasetId: UUID(), epochId: UUID(), namespaceId: UUID(),
            ownershipBinding: "local:" + UUID().uuidString
          )
          try plannerWriteDurably(JSONEncoder().encode(identity), to: configuration.controlURL)
        }
        _ = try openContainer()
        if identity.schemaVersion < 7 {
          identity = PlannerStoreIdentity(
            schemaVersion: 7, datasetId: identity.datasetId, epochId: identity.epochId,
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
        case .moveMembership(let listId, let membershipId, let destinationListId, let placement):
          return try executeMembershipMove(
            operation, listId: listId, membershipId: membershipId,
            destinationListId: destinationListId, placement: placement,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .removeMembership(let listId, let membershipId):
          return try executeMembershipRemoval(
            operation, listId: listId, membershipId: membershipId,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .reorderMembership(let listId, let membershipId, let placement):
          return try executeMembershipReordering(
            operation, listId: listId, membershipId: membershipId, placement: placement,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .addMembership(let itemId, let listId, let placement):
          return try executeMembershipCreation(
            operation, itemId: itemId, listId: listId, placement: placement,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .editList(let sourceId, let changes, let hashes):
          return try executeListChange(
            operation, sourceId: sourceId, change: .content(changes, hashes),
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
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
          case .appearance(let appearance):
            return try executeMembershipCompletion(
              operation, appearance: appearance, done: done, identity: identity,
              context: context, archive: archive, receipts: receipts, envelope: envelope)
          case .globalItem(let itemId):
            return try executeItemStateChange(
              operation, source: PlannerEntityReference(kind: .item, id: itemId),
              change: .completion(done), identity: identity, context: context,
              archive: archive, receipts: receipts, envelope: envelope)
          }
        case .setArchive(let source, let archived):
          if source.kind == .list {
            return try executeListChange(
              operation, sourceId: source.id, change: .archive(archived), identity: identity,
              context: context, archive: archive, receipts: receipts, envelope: envelope)
          }
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
          let item = try PlannerSchemaV7.Item(input: content)
          let snapshot = try item.value()
          let result = PlannerAppliedResult(
            generated: [snapshot.reference], affected: [snapshot.reference])
          let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>()).map {
            try $0.value()
          }
          let proposal = RecoveryPreparedProposal(
            proposalId: UUID(), originalOperationId: operation.operationId,
            datasetId: identity.datasetId,
            ownershipBinding: identity.ownershipBinding,
            proposedBackup: PlannerDataSnapshot(
              items: existingItems + [snapshot], lists: try listSnapshots(context),
              memberships: try membershipSnapshots(context),
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
              memberships: try membershipSnapshots(context),
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
        case .appearance(let appearance):
          return .appearance(
            try readAppearance(appearance, datasetId: identity.datasetId, context: context))
        case .rows(let generation, let offset, let limit):
          return .rows(
            try readRows(
              session: session, context: context, generation: generation, offset: offset,
              limit: limit))
        case .source(let source):
          if source.kind == .list {
            let sourceIdentifier = source.id
            var descriptor = FetchDescriptor<PlannerSchemaV7.List>(
              predicate: #Predicate { $0.id == sourceIdentifier })
            descriptor.fetchLimit = 2
            let records = try context.fetch(descriptor)
            guard records.count == 1, let record = records.first else {
              throw PlannerFailure(
                "missingReference", "The selected List is missing or unresolved.")
            }
            return .source(
              .list(
                try record.value().read(
                  datasetId: identity.datasetId, memberships: membershipSnapshots(context),
                  items: context.fetch(FetchDescriptor<PlannerSchemaV7.Item>()).map {
                    try $0.value()
                  })))
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
          let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>()).filter {
            $0.id == source.id
          }
          guard items.count == 1, let item = items.first else {
            throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
          }
          return .source(
            .item(
              try item.value().read(
                datasetId: identity.datasetId, memberships: membershipSnapshots(context))))
        }
      }
    } catch { return .failed(failure(error, code: "readUnavailable")) }
  }

  private func readAppearance(
    _ appearance: PlannerAppearance, datasetId: UUID, context: ModelContext
  ) throws -> PlannerAppearanceRead {
    switch appearance {
    case .listMembership(let listId, let membershipId):
      var descriptor = FetchDescriptor<PlannerSchemaV7.Membership>(
        predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
      descriptor.fetchLimit = 2
      let records = try context.fetch(descriptor)
      guard records.count == 1, let membership = records.first else {
        throw PlannerFailure(
          "missingReference", "The selected List appearance is missing or unresolved.")
      }
      let binding = try membership.value()
      let itemId = binding.item.id
      var itemDescriptor = FetchDescriptor<PlannerSchemaV7.Item>(
        predicate: #Predicate { $0.id == itemId })
      itemDescriptor.fetchLimit = 2
      let items = try context.fetch(itemDescriptor)
      guard items.count == 1, let item = items.first else {
        throw PlannerFailure(
          "missingReference", "The appearance's shared Item is missing or unresolved.")
      }
      let source = try item.value()
      guard source.lifetimeId == binding.item.lifetimeId else {
        throw PlannerFailure(
          "missingReference", "The appearance's Item lifetime no longer resolves.")
      }
      return PlannerAppearanceRead(
        appearance: appearance, source: source.reference, sourceLifetimeId: source.lifetimeId,
        content: source.input.readContent(links: source.links.map(\.read)),
        globalDone: source.globalDone, localDone: binding.localDone,
        effectiveDone: source.globalDone || binding.localDone, archived: source.archived,
        fieldHashes: source.input.fieldHashes(
          datasetId: datasetId, itemId: source.id, lifetimeId: source.lifetimeId,
          links: source.links.map(\.read)))
    }
  }

  private func readSchedule(
    _ source: PlannerEntityReference, datasetId: UUID, context: ModelContext
  ) throws -> PlannerScheduleSourceRead {
    let identifier = source.id
    var descriptor = FetchDescriptor<PlannerSchemaV7.Schedule>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected Schedule is missing or unresolved.")
    }
    guard let ownerIdentifier = record.sourceId, let ownerLifetime = record.sourceLifetimeId else {
      throw PlannerFailure("readUnavailable", "The Schedule's source binding is unresolved.")
    }
    var owners = FetchDescriptor<PlannerSchemaV7.Item>(
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
        case .catalog(let catalogQuery):
          let historyToken = try latestHistoryToken(in: context)
          let snapshot = try listCatalogSnapshot(
            session: query.session, query: catalogQuery, context: context)
          guard try latestHistoryToken(in: context) == historyToken else {
            throw PlannerFailure(
              "readUnavailable", "The store changed while building this catalog.")
          }
          querySnapshots = querySnapshots.filter { $0.value.historyToken == historyToken }
          querySnapshots[snapshot.generation] = QueryBinding(
            snapshot: snapshot, historyToken: historyToken)
          return .snapshot(snapshot)
        case .items(let itemQuery):
          try validateItemDuration(itemQuery.duration)
          let presentation = try
            (itemQuery.rowPresentation
            ?? PlannerRowPresentationContext(
              referenceInstant: Date(), displayTimeZone: TimeZone.current.identifier)).validated()
          switch itemQuery.sort.mode {
          case .manual:
            guard case .list = itemQuery.scope, itemQuery.sort.direction == .ascending else {
              throw PlannerFailure(
                "invalidInput", "Manual order requires an ascending standalone List query.",
                propertyPath: "/query/sort")
            }
          case .title, .created, .lastUpdated, .duration: break
          }
          let historyToken = try latestHistoryToken(in: context)
          let listedIdentifiers: Set<UUID>
          switch itemQuery.scope {
          case .global: listedIdentifiers = []
          case .inbox: listedIdentifiers = Set(try membershipSnapshots(context).map { $0.item.id })
          case .list(let listId):
            let snapshot = try listQuerySnapshot(
              session: query.session, listId: listId, query: itemQuery,
              presentation: presentation, context: context)
            guard try latestHistoryToken(in: context) == historyToken else {
              throw PlannerFailure(
                "readUnavailable", "The store changed while building this query.")
            }
            querySnapshots = querySnapshots.filter { $0.value.historyToken == historyToken }
            querySnapshots[snapshot.generation] = QueryBinding(
              snapshot: snapshot, historyToken: historyToken)
            return .snapshot(snapshot)
          case .itinerary:
            throw PlannerFailure(
              "unavailable", "This Item-only fixture does not implement contextual queries.")
          }
          let textTerms = itemQuery.text.split(whereSeparator: \.isWhitespace).map(String.init)
          let locale = Locale(identifier: "en_US_POSIX")
          var descriptor = FetchDescriptor<PlannerSchemaV7.Item>()
          if textTerms.isEmpty, itemQuery.duration?.minimumMinutes == nil,
            itemQuery.duration?.maximumMinutes == nil, itemQuery.sort.mode != .duration
          {
            descriptor.propertiesToFetch = [\.id, \.title, \.globalDone, \.archived]
            if itemQuery.sort.mode == .created {
              descriptor.propertiesToFetch.append(\.createdAt)
            } else if itemQuery.sort.mode == .lastUpdated {
              descriptor.propertiesToFetch.append(\.updatedAt)
            }
          }
          let items = try context.fetch(descriptor).filter { item in
            if let identifier = item.id, listedIdentifiers.contains(identifier) { return false }
            switch itemQuery.completion {
            case .todo: if item.globalDone { return false }
            case .done: if !item.globalDone { return false }
            case .all: break
            }
            switch itemQuery.archive {
            case .active: if item.archived { return false }
            case .archived: if !item.archived { return false }
            case .all: break
            }
            guard try matchesItemDuration(item, duration: itemQuery.duration) else { return false }
            return try matchesItemText(item, terms: textTerms, locale: locale)
          }
          let values = try items.map { item in
            guard let id = item.id,
              !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
              throw PlannerFailure(
                "readUnavailable", "A query Item has unresolved identity or title.")
            }
            var durationMinutes: Int64?
            if itemQuery.sort.mode == .duration {
              durationMinutes = try item.value().input.estimate?.minutes
            }
            return (
              reference: PlannerEntityReference(kind: .item, id: id),
              comparisonTitle: item.title.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: locale),
              durationMinutes: durationMinutes,
              comparisonDate: try chronologicalSortDate(item, mode: itemQuery.sort.mode)
            )
          }
          guard Set(values.map { $0.reference.id }).count == values.count else {
            throw PlannerFailure(
              "readUnavailable", "Query Item identities are duplicated and unresolved.")
          }
          let comparator = String.Comparator(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
          )
          let sorted = values.sorted { first, second in
            if let firstDate = first.comparisonDate, let secondDate = second.comparisonDate,
              firstDate != secondDate
            {
              if itemQuery.sort.direction == .ascending { return firstDate < secondDate }
              return firstDate > secondDate
            }
            if itemQuery.sort.mode == .duration,
              let precedes = durationPrecedes(
                first.durationMinutes, second.durationMinutes, direction: itemQuery.sort.direction)
            {
              return precedes
            }
            let comparison = comparator.compare(first.comparisonTitle, second.comparisonTitle)
            if comparison != .orderedSame {
              if itemQuery.sort.mode != .title || itemQuery.sort.direction == .ascending {
                return comparison == .orderedAscending
              }
              return comparison == .orderedDescending
            }
            return first.reference.id.uuidString < second.reference.id.uuidString
          }
          let snapshot = PlannerQuerySnapshot(
            session: query.session, generation: UUID(),
            rows: sorted.map { .source($0.reference) },
            matchingCount: Int64(sorted.count), rowPresentation: presentation,
            progress: [], unresolvedReferences: [])
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

  private func matchesItemText(
    _ item: PlannerSchemaV7.Item, terms: [String], locale: Locale
  ) throws -> Bool {
    guard !terms.isEmpty else { return true }
    let value = try item.value()
    let searchableFields =
      [
        value.input.title, value.input.subtitle, value.input.notes,
        value.input.location?.displayName, value.input.location?.formattedAddress,
      ].compactMap { $0 }
      + value.links.flatMap { link in
        [link.originalUrl, link.label].compactMap { $0 }
      }
    return terms.allSatisfy { term in
      searchableFields.contains { field in
        field.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
          != nil
      }
    }
  }

  private func validateItemDuration(_ duration: PlannerItemQuery.Duration?) throws {
    guard let duration else { return }
    if let minimum = duration.minimumMinutes, minimum < 0 {
      throw PlannerFailure(
        "invalidInput", "The minimum duration must be nonnegative.",
        propertyPath: "/query/duration/minimumMinutes")
    }
    if let maximum = duration.maximumMinutes, maximum < 0 {
      throw PlannerFailure(
        "invalidInput", "The maximum duration must be nonnegative.",
        propertyPath: "/query/duration/maximumMinutes")
    }
    if let minimum = duration.minimumMinutes, let maximum = duration.maximumMinutes,
      maximum < minimum
    {
      throw PlannerFailure(
        "invalidInput", "The maximum duration must not be below the minimum.",
        propertyPath: "/query/duration")
    }
  }

  private func matchesItemDuration(
    _ item: PlannerSchemaV7.Item, duration: PlannerItemQuery.Duration?
  ) throws -> Bool {
    guard let duration, duration.minimumMinutes != nil || duration.maximumMinutes != nil else {
      return true
    }
    guard let estimate = try item.value().input.estimate else { return duration.includeUnknown }
    if let minimum = duration.minimumMinutes, estimate.minutes < minimum { return false }
    if let maximum = duration.maximumMinutes, estimate.minutes > maximum { return false }
    return true
  }

  /// Equal estimates return nil so the caller uses the fixed ascending title/identity tie-break.
  private func durationPrecedes(
    _ firstMinutes: Int64?, _ secondMinutes: Int64?, direction: PlannerItemQuery.Sort.Direction
  ) -> Bool? {
    guard let firstMinutes else {
      if secondMinutes == nil { return nil }
      return false
    }
    guard let secondMinutes else { return true }
    if firstMinutes == secondMinutes { return nil }
    if direction == .ascending { return firstMinutes < secondMinutes }
    return firstMinutes > secondMinutes
  }

  private func chronologicalSortDate(
    _ item: PlannerSchemaV7.Item, mode: PlannerItemQuery.Sort.Mode
  ) throws -> Date? {
    let date: Date?
    switch mode {
    case .created: date = item.createdAt
    case .lastUpdated: date = item.updatedAt
    default: return nil
    }
    guard let date, date.timeIntervalSinceReferenceDate.isFinite else {
      throw PlannerFailure("readUnavailable", "A query Item has an unresolved sort timestamp.")
    }
    return date
  }

  private func listCatalogSnapshot(
    session: PlannerDatasetSession, query: PlannerCatalogQuery, context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    guard query.sourceKind != .item else {
      throw PlannerFailure(
        "invalidInput", "Item discovery requires an Item query.", propertyPath: "/query/sourceKind")
    }
    guard query.sourceKind == .list else {
      throw PlannerFailure(
        "unavailable", "This catalog slice supports List discovery only.",
        propertyPath: "/query/sourceKind")
    }
    var descriptor = FetchDescriptor<PlannerSchemaV7.List>()
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.name, \.archived]
    let locale = Locale(identifier: "en_US_POSIX")
    let terms = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
    let matches = try context.fetch(descriptor).filter { list in
      switch query.archive {
      case .active: if list.archived { return false }
      case .archived: if !list.archived { return false }
      case .all: break
      }
      return terms.allSatisfy {
        list.name.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
          != nil
      }
    }
    let values = try matches.map { list in
      guard let identifier = list.id, list.lifetimeId != nil,
        !list.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PlannerFailure("readUnavailable", "A catalog List has unresolved identity or name.")
      }
      return (
        source: PlannerEntityReference(kind: .list, id: identifier),
        comparisonName: list.name.folding(
          options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
      )
    }
    guard Set(values.map { $0.source.id }).count == values.count else {
      throw PlannerFailure(
        "readUnavailable", "Catalog List identities are duplicated and unresolved.")
    }
    let comparator = String.Comparator(
      options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    let sorted = values.sorted { first, second in
      let comparison = comparator.compare(first.comparisonName, second.comparisonName)
      if comparison != .orderedSame { return comparison == .orderedAscending }
      return first.source.id.uuidString < second.source.id.uuidString
    }
    return PlannerQuerySnapshot(
      session: session, generation: UUID(), rows: sorted.map { .source($0.source) },
      matchingCount: Int64(sorted.count), rowPresentation: nil,
      progress: [], unresolvedReferences: [])
  }

  private func listQuerySnapshot(
    session: PlannerDatasetSession, listId: UUID, query: PlannerItemQuery,
    presentation: PlannerRowPresentationContext, context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    var lists = FetchDescriptor<PlannerSchemaV7.List>(
      predicate: #Predicate { $0.id == listId })
    lists.fetchLimit = 2
    lists.propertiesToFetch = [\.id, \.lifetimeId]
    let owners = try context.fetch(lists)
    guard owners.count == 1, let owner = owners.first, let lifetimeId = owner.lifetimeId else {
      throw PlannerFailure("missingReference", "The selected List is missing or unresolved.")
    }
    let memberships = FetchDescriptor<PlannerSchemaV7.Membership>(
      predicate: #Predicate { $0.listId == listId && $0.listLifetimeId == lifetimeId },
      sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
    let children = try context.fetch(memberships).map { try $0.value() }
    guard Set(children.map(\.id)).count == children.count,
      Set(children.map { $0.item.id }).count == children.count
    else {
      throw PlannerFailure("readUnavailable", "List memberships are duplicated and unresolved.")
    }
    let itemIdentifiers = children.map { Optional($0.item.id) }
    let textTerms = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
    var items = FetchDescriptor<PlannerSchemaV7.Item>(
      predicate: #Predicate { itemIdentifiers.contains($0.id) })
    if textTerms.isEmpty, query.duration?.minimumMinutes == nil,
      query.duration?.maximumMinutes == nil, query.sort.mode != .duration
    {
      items.propertiesToFetch = [\.id, \.lifetimeId, \.title, \.globalDone, \.archived]
      if query.sort.mode == .created {
        items.propertiesToFetch.append(\.createdAt)
      } else if query.sort.mode == .lastUpdated {
        items.propertiesToFetch.append(\.updatedAt)
      }
    }
    let sources = Dictionary(grouping: try context.fetch(items), by: \.id)
    var doneCount: Int64 = 0
    let locale = Locale(identifier: "en_US_POSIX")
    var matching:
      [(
        identity: PlannerRowIdentity, comparisonTitle: String, itemId: UUID,
        durationMinutes: Int64?,
        comparisonDate: Date?
      )] =
        []
    for membership in children {
      guard let matches = sources[membership.item.id], matches.count == 1,
        let item = matches.first, item.lifetimeId == membership.item.lifetimeId,
        !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PlannerFailure("readUnavailable", "A List child source is unresolved.")
      }
      let effectiveDone = item.globalDone || membership.localDone
      if effectiveDone { doneCount += 1 }
      switch query.completion {
      case .todo: if effectiveDone { continue }
      case .done: if !effectiveDone { continue }
      case .all: break
      }
      switch query.archive {
      case .active: if item.archived { continue }
      case .archived: if !item.archived { continue }
      case .all: break
      }
      if !(try matchesItemDuration(item, duration: query.duration)) { continue }
      if !(try matchesItemText(item, terms: textTerms, locale: locale)) { continue }
      var durationMinutes: Int64?
      if query.sort.mode == .duration {
        durationMinutes = try item.value().input.estimate?.minutes
      }
      matching.append(
        (
          identity: .appearance(
            source: PlannerEntityReference(kind: .item, id: membership.item.id),
            appearance: .listMembership(listId: listId, membershipId: membership.id)),
          comparisonTitle: item.title.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: locale),
          itemId: membership.item.id, durationMinutes: durationMinutes,
          comparisonDate: try chronologicalSortDate(item, mode: query.sort.mode)
        ))
    }
    if query.sort.mode != .manual {
      let comparator = String.Comparator(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: locale)
      matching.sort { first, second in
        if let firstDate = first.comparisonDate, let secondDate = second.comparisonDate,
          firstDate != secondDate
        {
          if query.sort.direction == .ascending { return firstDate < secondDate }
          return firstDate > secondDate
        }
        if query.sort.mode == .duration,
          let precedes = durationPrecedes(
            first.durationMinutes, second.durationMinutes, direction: query.sort.direction)
        {
          return precedes
        }
        let comparison = comparator.compare(first.comparisonTitle, second.comparisonTitle)
        if comparison != .orderedSame {
          if query.sort.mode != .title || query.sort.direction == .ascending {
            return comparison == .orderedAscending
          }
          return comparison == .orderedDescending
        }
        return first.itemId.uuidString < second.itemId.uuidString
      }
    }
    let rows = matching.map(\.identity)
    let totalCount = Int64(children.count)
    let state: PlannerContainerProgressState
    if totalCount == 0 {
      state = .empty
    } else if doneCount == totalCount {
      state = .complete
    } else {
      state = .partial
    }
    return PlannerQuerySnapshot(
      session: session, generation: UUID(), rows: rows, matchingCount: Int64(rows.count),
      rowPresentation: presentation,
      progress: [
        PlannerContainerProgress(
          container: PlannerEntityReference(kind: .list, id: listId), state: state,
          doneCount: doneCount, totalCount: totalCount)
      ], unresolvedReferences: [])
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
      let source: PlannerEntityReference
      let localDone: Bool?
      let expectedLifetimeId: UUID?
      switch identity {
      case .appearance(let reference, .listMembership(let listId, let membershipId)):
        var memberships = FetchDescriptor<PlannerSchemaV7.Membership>(
          predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
        memberships.fetchLimit = 2
        let records = try context.fetch(memberships)
        guard records.count == 1, let record = records.first else {
          throw PlannerFailure("readUnavailable", "A snapshot appearance is missing or unresolved.")
        }
        let membership = try record.value()
        guard reference.kind == .item, membership.item.id == reference.id else {
          throw PlannerFailure("readUnavailable", "The snapshot appearance's source is unresolved.")
        }
        source = reference
        localDone = membership.localDone
        expectedLifetimeId = membership.item.lifetimeId
      case .source(let reference):
        source = reference
        localDone = nil
        expectedLifetimeId = nil
      }
      if source.kind == .list {
        let sourceIdentifier = source.id
        var descriptor = FetchDescriptor<PlannerSchemaV7.List>(
          predicate: #Predicate { $0.id == sourceIdentifier })
        descriptor.fetchLimit = 2
        descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.name, \.archived]
        let records = try context.fetch(descriptor)
        guard records.count == 1, let list = records.first, let lifetimeId = list.lifetimeId,
          !list.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          throw PlannerFailure("readUnavailable", "A snapshot List is missing or unresolved.")
        }
        return PlannerRowRead(
          identity: identity, sourceLifetimeId: lifetimeId,
          title: list.name, subtitle: nil, estimate: nil,
          globalDone: nil, localDone: nil, effectiveDone: nil, archived: list.archived,
          hasLocation: false, hasLinks: false, ownedLocation: nil, previewLink: nil,
          scheduleSummary: .none)
      }
      guard let presentation = snapshot.rowPresentation else {
        throw PlannerFailure("readUnavailable", "The Item query has no presentation context.")
      }
      let sourceIdentifier = source.id
      var descriptor = FetchDescriptor<PlannerSchemaV7.Item>(
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
      guard let lifetimeId = item.lifetimeId,
        expectedLifetimeId == nil || expectedLifetimeId == lifetimeId
      else {
        throw PlannerFailure("readUnavailable", "The row Item has unresolved lifetime.")
      }
      let owned = FetchDescriptor<PlannerSchemaV7.OwnedLink>(
        predicate: #Predicate {
          $0.ownerId == sourceIdentifier && $0.ownerLifetimeId == lifetimeId
        })
      var selected = FetchDescriptor<PlannerSchemaV7.OwnedLink>(
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
        identity: identity, localDone: localDone,
        hasLinks: context.fetchCount(owned) > 0, previewLink: preview, scheduleSummary: summary)
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
    let assignments = FetchDescriptor<PlannerSchemaV7.Schedule>(
      predicate: #Predicate {
        $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
      })
    let assignmentCount = try context.fetchCount(assignments)
    guard assignmentCount > 0 else { return .none }
    let candidates = [
      FetchDescriptor<PlannerSchemaV7.Schedule>(
        predicate: #Predicate {
          $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) <= referenceInstant
            && $0.end != nil && ($0.end ?? referenceInstant) > referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV7.Schedule>(
        predicate: #Predicate {
          $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) >= referenceInstant
        }, sortBy: [SortDescriptor(\.start), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV7.Schedule>(
        predicate: #Predicate {
          $0.sourceId == sourceIdentifier && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) < referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
    ]
    var allDayDescriptor = FetchDescriptor<PlannerSchemaV7.Schedule>(
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
    let list = try PlannerSchemaV7.List(content: content)
    let snapshot = try list.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingLists = try listSnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>()).map {
      try $0.value()
    }
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        items: existingItems, lists: existingLists + [snapshot],
        memberships: try membershipSnapshots(context),
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
        memberships: try membershipSnapshots(context),
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

  private func executeListChange(
    _ operation: PlannerOperation, sourceId: UUID, change: ListChange,
    identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    let fields: [PlannerListField]
    let hashes: [PlannerListField: PlannerFieldHash]
    switch change {
    case .content(let changes, let values):
      fields = try changes.validatedFields()
      hashes = values
    case .archive:
      fields = []
      hashes = [:]
    }
    for field in fields where hashes[field] == nil {
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
      let digest = try listChangePayloadDigest(
        change: change, sourceId: sourceId, fields: fields, identity: identity,
        bindings: stored.bindings)
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
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV7.List>())
    let matches = lists.filter { $0.id == sourceId }
    guard matches.count == 1, let list = matches.first else {
      throw PlannerFailure("missingReference", "The selected List is missing or unresolved.")
    }
    let before = try list.value()
    let bindings = [
      PlannerBoundIdentity(kind: "list", id: before.id, lifetimeId: before.lifetimeId)
    ]
    let digest = try listChangePayloadDigest(
      change: change, sourceId: sourceId, fields: fields, identity: identity, bindings: bindings)
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
    let currentHashes = before.fieldHashes(datasetId: identity.datasetId)
    let conflictingFields = fields.filter { currentHashes[$0] != hashes[$0] }
    if !conflictingFields.isEmpty {
      throw PlannerFailure(
        "staleEdit", "Changed fields differ from the supplied read.",
        details: .staleListEdit(
          conflictingFields: conflictingFields,
          currentValues: Dictionary(
            uniqueKeysWithValues: conflictingFields.map { ($0, before.fieldValue($0)) }),
          currentFieldHashes: currentHashes.filter { conflictingFields.contains($0.key) }))
    }
    let content: PlannerListContent
    let archived: Bool
    let updatedAt: Date
    switch change {
    case .content(let changes, _):
      content = changes.applying(to: before.content)
      archived = before.archived
      updatedAt = Date()
    case .archive(let value):
      content = before.content
      archived = value
      updatedAt = value == before.archived ? before.updatedAt : Date()
    }
    let colorData = try content.color.map { try JSONEncoder().encode($0) }
    let after = ListSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: updatedAt,
      content: content, archived: archived)
    let snapshots = try lists.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>()).map { try $0.value() }
    let result = PlannerAppliedResult(generated: [], affected: [before.reference])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        items: items, lists: snapshots, memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified")
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if fields.contains(.name) { list.name = content.name }
    if fields.contains(.notes) { list.notes = content.notes }
    if fields.contains(.color) { list.colorData = colorData }
    if fields.contains(.iconName) { list.iconName = content.iconName }
    list.archived = archived
    list.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete List action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: items, lists: snapshots, memberships: try membershipSnapshots(context),
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

  private func listChangePayloadDigest(
    change: ListChange, sourceId: UUID, fields: [PlannerListField], identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) throws -> String {
    switch change {
    case .content(let changes, let hashes):
      return try changes.payloadDigest(
        sourceId: sourceId, fields: fields, hashes: hashes, identity: identity, bindings: bindings)
    case .archive(let value):
      return sourceStatePayloadDigest(
        source: PlannerEntityReference(kind: .list, id: sourceId), change: .archive(value),
        identity: identity, bindings: bindings)
    }
  }

  private func listSnapshots(_ context: ModelContext) throws -> [ListSnapshot] {
    try context.fetch(FetchDescriptor<PlannerSchemaV7.List>()).map { try $0.value() }
  }

  private func membershipSnapshots(_ context: ModelContext) throws -> [MembershipSnapshot] {
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV7.Membership>()).map {
      try $0.value()
    }
    guard Set(snapshots.map(\.id)).count == snapshots.count,
      Set(snapshots.map { $0.list.id.uuidString + "/" + $0.item.id.uuidString }).count
        == snapshots.count
    else {
      throw PlannerFailure("readUnavailable", "List memberships are duplicated and unresolved.")
    }
    return snapshots
  }

  private func executeMembershipCreation(
    _ operation: PlannerOperation, itemId: UUID, listId: UUID, placement: PlannerPlacement,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let digest = membershipCreationDigest(
        itemId: itemId, listId: listId, placement: placement, identity: identity,
        bindings: try receipt.evidence().bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another addition.")
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV7.List>())
    let itemMatches = items.filter { $0.id == itemId }
    let listMatches = lists.filter { $0.id == listId }
    guard itemMatches.count == 1, let item = itemMatches.first,
      listMatches.count == 1, let list = listMatches.first
    else {
      throw PlannerFailure(
        "missingReference", "The selected Item or List is missing or unresolved.")
    }
    let source = try item.value()
    let owner = try list.value()
    var memberships = try membershipSnapshots(context)
    let ordered = memberships.filter { $0.list.id == listId }.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.id.uuidString < $1.id.uuidString
    }
    let insertionIndex = try membershipInsertionIndex(placement, in: ordered)
    var bindings = [
      PlannerBoundIdentity(kind: "item", id: source.id, lifetimeId: source.lifetimeId),
      PlannerBoundIdentity(kind: "list", id: owner.id, lifetimeId: owner.lifetimeId),
    ]
    switch placement {
    case .before(let identifier), .after(let identifier):
      if let anchor = ordered.first(where: { $0.id == identifier }) {
        bindings.append(
          PlannerBoundIdentity(kind: "membership", id: anchor.id, lifetimeId: anchor.lifetimeId))
      }
    case .first, .last: break
    }
    let digest = membershipCreationDigest(
      itemId: itemId, listId: listId, placement: placement, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another addition.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let existing = memberships.first { $0.item.id == itemId && $0.list.id == listId }
    let added: MembershipSnapshot?
    let reference: PlannerReferenceRead
    if let existing {
      added = nil
      reference = existing.reference
    } else {
      let rank = try membershipInsertionRank(
        at: insertionIndex, ordered: ordered, memberships: &memberships)
      let identifier = UUID()
      let membership = MembershipSnapshot(
        id: identifier, lifetimeId: identifier, list: bindings[1], item: bindings[0],
        rank: rank, localDone: false)
      added = membership
      reference = membership.reference
      memberships.append(membership)
    }
    let result = PlannerAppliedResult(
      generatedIdentities: added == nil ? [] : [.reference(reference)],
      affectedIdentities: [.reference(reference), .source(owner.reference)])
    let itemSnapshots = try items.map { try $0.value() }
    let updatedAt = added == nil ? owner.updatedAt : Date()
    let listSnapshots = try lists.map { record in
      if record.id != listId { return try record.value() }
      return ListSnapshot(
        id: owner.id, lifetimeId: owner.lifetimeId, createdAt: owner.createdAt,
        updatedAt: updatedAt,
        content: owner.content, archived: owner.archived)
    }
    let markers = try deletionMarkers(context)
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers),
      payloadDigest: digest, evidence: "preparedUnverified")
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if let added {
      context.insert(PlannerSchemaV7.Membership(snapshot: added, list: list, item: item))
    }
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for record in try context.fetch(FetchDescriptor<PlannerSchemaV7.Membership>()) {
      if let identifier = record.id, let rank = ranks[identifier], record.rank != rank {
        record.rank = rank
      }
    }
    list.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete membership action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers, receipts: receipts + [receipt])
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

  private func executeMembershipRemoval(
    _ operation: PlannerOperation, listId: UUID, membershipId: UUID,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let digest = membershipRemovalDigest(
        listId: listId, membershipId: membershipId, identity: identity,
        bindings: try receipt.evidence().bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another removal.")
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
    var descriptor = FetchDescriptor<PlannerSchemaV7.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure("missingReference", "The selected membership is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV7.List>())
    let owners = lists.filter { $0.id == before.list.id && $0.lifetimeId == before.list.lifetimeId }
    let sources = items.filter {
      $0.id == before.item.id && $0.lifetimeId == before.item.lifetimeId
    }
    guard owners.count == 1, let owner = owners.first, sources.count == 1 else {
      throw PlannerFailure(
        "missingReference", "The membership's Item or List lifetime is unresolved.")
    }
    let membershipBinding = PlannerBoundIdentity(
      kind: "membership", id: before.id, lifetimeId: before.lifetimeId)
    let bindings = [membershipBinding, before.list, before.item]
    let digest = membershipRemovalDigest(
      listId: listId, membershipId: membershipId, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another removal.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let memberships = try membershipSnapshots(context).filter { $0.id != membershipId }
    let ownerSnapshot = try owner.value()
    let updatedAt = Date()
    let itemSnapshots = try items.map { try $0.value() }
    let listSnapshots = try lists.map { list in
      if list.id != listId { return try list.value() }
      return ListSnapshot(
        id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
        createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt,
        content: ownerSnapshot.content, archived: ownerSnapshot.archived)
    }
    let removalMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .membership(membershipBinding), closedFamilyId: nil)
    let markers = try deletionMarkers(context) + [removalMarker]
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    context.delete(record)
    context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete membership removal was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers, receipts: receipts + [receipt])
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

  private func membershipRemovalDigest(
    listId: UUID, membershipId: UUID, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("removeMembership"), "listId": .identity(listId),
        "membershipId": .identity(membershipId),
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }

  private func executeMembershipMove(
    _ operation: PlannerOperation, listId: UUID, membershipId: UUID,
    destinationListId: UUID, placement: PlannerPlacement,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let digest = membershipMoveDigest(
        listId: listId, membershipId: membershipId, destinationListId: destinationListId,
        placement: placement, identity: identity, bindings: try receipt.evidence().bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another move.")
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
    guard listId != destinationListId else {
      throw PlannerFailure(
        "invalidInput", "Use reorder to change position in the same List.",
        propertyPath: "/command/destinationListId")
    }
    var descriptor = FetchDescriptor<PlannerSchemaV7.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure("missingReference", "The selected membership is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV7.List>())
    let owners = lists.filter { $0.id == before.list.id && $0.lifetimeId == before.list.lifetimeId }
    let sources = items.filter {
      $0.id == before.item.id && $0.lifetimeId == before.item.lifetimeId
    }
    let destinations = lists.filter { $0.id == destinationListId }
    guard owners.count == 1, let owner = owners.first,
      sources.count == 1, let source = sources.first,
      destinations.count == 1, let destination = destinations.first
    else {
      throw PlannerFailure(
        "missingReference", "The membership's sources or destination List are unresolved.")
    }
    let ownerSnapshot = try owner.value()
    let destinationSnapshot = try destination.value()
    let membershipBinding = PlannerBoundIdentity(
      kind: "membership", id: before.id, lifetimeId: before.lifetimeId)
    let destinationBinding = PlannerBoundIdentity(
      kind: "list", id: destinationSnapshot.id, lifetimeId: destinationSnapshot.lifetimeId)
    var memberships = try membershipSnapshots(context)
    let ordered = memberships.filter { $0.list.id == destinationListId }.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.id.uuidString < $1.id.uuidString
    }
    let insertionIndex = try membershipInsertionIndex(placement, in: ordered)
    let existing = ordered.first {
      $0.item.id == before.item.id && $0.item.lifetimeId == before.item.lifetimeId
    }
    var bindings = [membershipBinding, before.list, before.item, destinationBinding]
    if let existing {
      bindings.append(
        PlannerBoundIdentity(kind: "membership", id: existing.id, lifetimeId: existing.lifetimeId))
    }
    switch placement {
    case .before(let identifier), .after(let identifier):
      if let anchor = ordered.first(where: { $0.id == identifier }) {
        bindings.append(
          PlannerBoundIdentity(kind: "membership", id: anchor.id, lifetimeId: anchor.lifetimeId))
      }
    case .first, .last: break
    }
    let digest = membershipMoveDigest(
      listId: listId, membershipId: membershipId, destinationListId: destinationListId,
      placement: placement, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another move.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    memberships.removeAll { $0.id == membershipId }
    let added: MembershipSnapshot?
    let destinationReference: PlannerReferenceRead
    if let existing {
      added = nil
      destinationReference = existing.reference
    } else {
      let rank = try membershipInsertionRank(
        at: insertionIndex, ordered: ordered, memberships: &memberships)
      let identifier = UUID()
      let membership = MembershipSnapshot(
        id: identifier, lifetimeId: identifier, list: destinationBinding, item: before.item,
        rank: rank, localDone: false)
      added = membership
      destinationReference = membership.reference
      memberships.append(membership)
    }
    let updatedAt = Date()
    let listSnapshots = try lists.map { list in
      if list.id == listId {
        return ListSnapshot(
          id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
          createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt,
          content: ownerSnapshot.content, archived: ownerSnapshot.archived)
      }
      if list.id == destinationListId, added != nil {
        return ListSnapshot(
          id: destinationSnapshot.id, lifetimeId: destinationSnapshot.lifetimeId,
          createdAt: destinationSnapshot.createdAt, updatedAt: updatedAt,
          content: destinationSnapshot.content, archived: destinationSnapshot.archived)
      }
      return try list.value()
    }
    let itemSnapshots = try items.map { try $0.value() }
    let removalMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .membership(membershipBinding), closedFamilyId: nil)
    let markers = try deletionMarkers(context) + [removalMarker]
    let result = PlannerAppliedResult(
      generatedIdentities: added == nil ? [] : [.reference(destinationReference)],
      affectedIdentities: [
        .reference(before.reference), .reference(destinationReference),
        .source(ownerSnapshot.reference), .source(destinationSnapshot.reference),
      ])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    context.delete(record)
    if let added {
      context.insert(PlannerSchemaV7.Membership(snapshot: added, list: destination, item: source))
    }
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV7.Membership>()) {
      if let identifier = membership.id, let rank = ranks[identifier], membership.rank != rank {
        membership.rank = rank
      }
    }
    owner.updatedAt = updatedAt
    if added != nil { destination.updatedAt = updatedAt }
    context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete membership move was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers, receipts: receipts + [receipt])
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

  private func membershipMoveDigest(
    listId: UUID, membershipId: UUID, destinationListId: UUID, placement: PlannerPlacement,
    identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity]
  ) -> String {
    let placementValue: PlannerCanonicalValue
    switch placement {
    case .first: placementValue = .record(["kind": .string("first")])
    case .last: placementValue = .record(["kind": .string("last")])
    case .before(let identifier):
      placementValue = .record(["kind": .string("before"), "associationId": .identity(identifier)])
    case .after(let identifier):
      placementValue = .record(["kind": .string("after"), "associationId": .identity(identifier)])
    }
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("moveMembership"), "listId": .identity(listId),
        "membershipId": .identity(membershipId), "destinationListId": .identity(destinationListId),
        "placement": placementValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }

  private func executeMembershipReordering(
    _ operation: PlannerOperation, listId: UUID, membershipId: UUID, placement: PlannerPlacement,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let digest = membershipReorderingDigest(
        listId: listId, membershipId: membershipId, placement: placement, identity: identity,
        bindings: try receipt.evidence().bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another reorder.")
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
    var descriptor = FetchDescriptor<PlannerSchemaV7.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure("missingReference", "The selected membership is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV7.List>())
    let owners = lists.filter { $0.id == before.list.id && $0.lifetimeId == before.list.lifetimeId }
    let sources = items.filter {
      $0.id == before.item.id && $0.lifetimeId == before.item.lifetimeId
    }
    guard owners.count == 1, let owner = owners.first, sources.count == 1 else {
      throw PlannerFailure(
        "missingReference", "The membership's Item or List lifetime is unresolved.")
    }
    switch placement {
    case .before(let identifier), .after(let identifier):
      guard identifier != membershipId else {
        throw PlannerFailure(
          "invalidInput", "A membership cannot use itself as its placement anchor.",
          propertyPath: "/command/placement/associationId")
      }
    case .first, .last: break
    }
    var memberships = try membershipSnapshots(context)
    let ordered = memberships.filter { $0.list.id == listId }.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.id.uuidString < $1.id.uuidString
    }
    let remaining = ordered.filter { $0.id != membershipId }
    let insertionIndex = try membershipInsertionIndex(placement, in: remaining)
    var desiredOrder = remaining.map(\.id)
    desiredOrder.insert(membershipId, at: insertionIndex)
    let changed = desiredOrder != ordered.map(\.id)
    var bindings = [
      PlannerBoundIdentity(kind: "membership", id: before.id, lifetimeId: before.lifetimeId),
      before.list, before.item,
    ]
    switch placement {
    case .before(let identifier), .after(let identifier):
      if let anchor = remaining.first(where: { $0.id == identifier }) {
        bindings.append(
          PlannerBoundIdentity(kind: "membership", id: anchor.id, lifetimeId: anchor.lifetimeId))
      }
    case .first, .last: break
    }
    let digest = membershipReorderingDigest(
      listId: listId, membershipId: membershipId, placement: placement, identity: identity,
      bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another reorder.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    if changed {
      let rank = try membershipInsertionRank(
        at: insertionIndex, ordered: remaining, memberships: &memberships)
      guard let selectedIndex = memberships.firstIndex(where: { $0.id == membershipId }) else {
        throw PlannerFailure("missingReference", "The selected membership is missing.")
      }
      memberships[selectedIndex].rank = rank
    }
    let ownerSnapshot = try owner.value()
    let updatedAt = changed ? Date() : ownerSnapshot.updatedAt
    let itemSnapshots = try items.map { try $0.value() }
    let listSnapshots = try lists.map { list in
      if list.id != listId { return try list.value() }
      return ListSnapshot(
        id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
        createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt,
        content: ownerSnapshot.content, archived: ownerSnapshot.archived)
    }
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId,
        ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV7.Membership>()) {
      if let identifier = membership.id, let rank = ranks[identifier], membership.rank != rank {
        membership.rank = rank
      }
    }
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete reorder was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers, receipts: receipts + [receipt])
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

  private func membershipReorderingDigest(
    listId: UUID, membershipId: UUID, placement: PlannerPlacement, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    let placementValue: PlannerCanonicalValue
    switch placement {
    case .first: placementValue = .record(["kind": .string("first")])
    case .last: placementValue = .record(["kind": .string("last")])
    case .before(let identifier):
      placementValue = .record(["kind": .string("before"), "associationId": .identity(identifier)])
    case .after(let identifier):
      placementValue = .record(["kind": .string("after"), "associationId": .identity(identifier)])
    }
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("reorderMembership"), "listId": .identity(listId),
        "membershipId": .identity(membershipId), "placement": placementValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }

  private func executeMembershipCompletion(
    _ operation: PlannerOperation, appearance: PlannerAppearance, done: Bool,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      let digest = membershipCompletionDigest(
        appearance: appearance, done: done, identity: identity, bindings: stored.bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another completion action."
        )
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
    let listId: UUID
    let membershipId: UUID
    switch appearance {
    case .listMembership(let ownerIdentifier, let associationIdentifier):
      listId = ownerIdentifier
      membershipId = associationIdentifier
    }
    var descriptor = FetchDescriptor<PlannerSchemaV7.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure(
        "missingReference", "The selected List appearance is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV7.List>())
    let owners = lists.filter { $0.id == before.list.id && $0.lifetimeId == before.list.lifetimeId }
    let sources = items.filter {
      $0.id == before.item.id && $0.lifetimeId == before.item.lifetimeId
    }
    guard owners.count == 1, let owner = owners.first, sources.count == 1 else {
      throw PlannerFailure(
        "missingReference", "The appearance's Item or List lifetime is unresolved.")
    }
    let ownerSnapshot = try owner.value()
    let bindings = [
      PlannerBoundIdentity(kind: "membership", id: before.id, lifetimeId: before.lifetimeId),
      before.list, before.item,
    ]
    let digest = membershipCompletionDigest(
      appearance: appearance, done: done, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another completion action.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let after = MembershipSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, list: before.list, item: before.item,
      rank: before.rank, localDone: done)
    let memberships = try membershipSnapshots(context).map { snapshot in
      if snapshot.id == before.id { return after }
      return snapshot
    }
    let itemSnapshots = try items.map { try $0.value() }
    let updatedAt = done == before.localDone ? ownerSnapshot.updatedAt : Date()
    let listSnapshots = try lists.map { list in
      if list.id != before.list.id { return try list.value() }
      return ListSnapshot(
        id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
        createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt,
        content: ownerSnapshot.content, archived: ownerSnapshot.archived)
    }
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId,
        ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    record.localDone = done
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete local completion action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers, receipts: receipts + [receipt])
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

  private func membershipCompletionDigest(
    appearance: PlannerAppearance, done: Bool, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    let appearanceValue: PlannerCanonicalValue
    switch appearance {
    case .listMembership(let listId, let membershipId):
      appearanceValue = .record([
        "kind": .string("listMembership"), "listId": .identity(listId),
        "membershipId": .identity(membershipId),
      ])
    }
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("setCompletion"),
        "scope": .record(["kind": .string("appearance"), "appearance": appearanceValue]),
        "done": .boolean(done),
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    return plannerDigest(
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
      prefix: "sha256-payload-v1:")
  }

  private func membershipCreationDigest(
    itemId: UUID, listId: UUID, placement: PlannerPlacement, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    let placementValue: PlannerCanonicalValue
    switch placement {
    case .first: placementValue = .record(["kind": .string("first")])
    case .last: placementValue = .record(["kind": .string("last")])
    case .before(let identifier):
      placementValue = .record(["kind": .string("before"), "associationId": .identity(identifier)])
    case .after(let identifier):
      placementValue = .record(["kind": .string("after"), "associationId": .identity(identifier)])
    }
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("addMembership"), "itemId": .identity(itemId), "listId": .identity(listId),
        "placement": placementValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
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
    var assignments = FetchDescriptor<PlannerSchemaV7.Schedule>(
      predicate: #Predicate { $0.id == scheduleId })
    assignments.fetchLimit = 2
    let records = try context.fetch(assignments)
    guard records.count == 1, let record = records.first,
      let ownerIdentifier = record.sourceId, let ownerLifetime = record.sourceLifetimeId
    else {
      throw PlannerFailure("missingReference", "The selected Schedule is missing or unresolved.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
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
          items: snapshots, lists: try listSnapshots(context),
          memberships: try membershipSnapshots(context), deletionMarkers: markers),
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
        items: snapshots, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context), deletionMarkers: markers,
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
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
          memberships: try membershipSnapshots(context),
          deletionMarkers: try deletionMarkers(context)),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    context.insert(try PlannerSchemaV7.Schedule(snapshot: assignment, owner: item))
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
        memberships: try membershipSnapshots(context),
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
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
        if field == .subtitle { currentValues[field] = .optionalString(before.input.subtitle) }
        if field == .notes { currentValues[field] = .optionalString(before.input.notes) }
        if field == .location { currentValues[field] = .optionalLocation(before.input.location) }
        if field == .estimate { currentValues[field] = .optionalEstimate(before.input.estimate) }
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
    let updatedEstimateData = try updatedInput.estimate.map { try JSONEncoder().encode($0) }
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
        memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified"
    )
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if changedFields.contains(.title) { item.title = updatedInput.title }
    if changedFields.contains(.subtitle) { item.subtitle = updatedInput.subtitle }
    if changedFields.contains(.notes) { item.notes = updatedInput.notes }
    if changedFields.contains(.location) { item.locationData = updatedLocationData }
    if changedFields.contains(.estimate) { item.estimateData = updatedEstimateData }
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
        memberships: try membershipSnapshots(context),
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
      let digest = sourceStatePayloadDigest(
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV7.Item>())
    let matches = items.filter { $0.id == source.id }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
    }
    let before = try item.value()
    let bindings = [
      PlannerBoundIdentity(kind: "item", id: before.id, lifetimeId: before.lifetimeId)
    ]
    let digest = sourceStatePayloadDigest(
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
        memberships: try membershipSnapshots(context),
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
        memberships: try membershipSnapshots(context),
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

  private func sourceStatePayloadDigest(
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
      identity.schemaVersion == 7
    else {
      throw PlannerFailure("staleDatasetSession", "The dataset session is no longer authorized.")
    }
    return identity
  }

  private func openContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: PlannerSchemaV7.self)
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
        (1...7).contains(identity.schemaVersion), !identity.ownershipBinding.isEmpty
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
