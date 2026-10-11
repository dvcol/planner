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
  private struct ReviewBinding {
    let session: PlannerDatasetSession
    let payloadDigest: String
  }
  private var reviews: [UUID: ReviewBinding] = [:]
  private enum ItemStateChange {
    case archive(Bool)
    case completion(Bool)
  }
  private enum ListChange {
    case content(PlannerListChanges, [PlannerListField: PlannerFieldHash])
    case archive(Bool)
  }

  private enum ScheduleOwner {
    case item(PlannerSchemaV14.Item)
    case itinerary(PlannerSchemaV14.Itinerary)

    var binding: PlannerBoundIdentity {
      get throws {
        let identifier: UUID?
        let lifetime: UUID?
        let kind: String
        switch self {
        case .item(let owner):
          identifier = owner.id
          lifetime = owner.lifetimeId
          kind = "item"
        case .itinerary(let owner):
          identifier = owner.id
          lifetime = owner.lifetimeId
          kind = "itinerary"
        }
        guard let identifier, let lifetime else {
          throw PlannerFailure("readUnavailable", "The Schedule owner has unresolved identity.")
        }
        return .init(kind: kind, id: identifier, lifetimeId: lifetime)
      }
    }

    func assignment(_ snapshot: ScheduleSnapshot) throws -> PlannerSchemaV14.Schedule {
      switch self {
      case .item(let owner): return try .init(snapshot: snapshot, owner: owner)
      case .itinerary(let owner): return try .init(snapshot: snapshot, owner: owner)
      }
    }
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
          guard (1...14).contains(identity.schemaVersion) else {
            throw PlannerFailure(
              "unsupportedVersion", "The dataset uses an unsupported storage schema.")
          }
          if identity.schemaVersion < 14, configuration.processRole == .shareExtension {
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
            schemaVersion: 14, datasetId: UUID(), epochId: UUID(), namespaceId: UUID(),
            ownershipBinding: "local:" + UUID().uuidString
          )
          try plannerWriteDurably(JSONEncoder().encode(identity), to: configuration.controlURL)
        }
        _ = try openContainer()
        if identity.schemaVersion < 14 {
          identity = PlannerStoreIdentity(
            schemaVersion: 14, datasetId: identity.datasetId, epochId: identity.epochId,
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

  public func prepareReview(session: PlannerDatasetSession, command: PlannerCommand)
    -> PlannerReviewResult
  {
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        let targets: [PlannerReviewTarget]
        let impact: PlannerReviewImpact
        let digest: String
        switch command {
        case .setBulkCompletion(let scope, let done):
          let resolution = try resolveBulkCompletion(scope, context: context)
          targets = resolution.targets.map { .appearance($0.appearance) }
          impact = .init(
            kind: .bulkCompletion, targetCount: Int64(targets.count), globalFlagsChanged: false,
            sourceDeletes: [], referenceRemovals: [])
          digest = bulkCompletionDigest(
            scope: scope, done: done, identity: identity, bindings: resolution.bindings)
        case .deleteSource(let source):
          if source.kind == .list {
            let resolution = try resolveListDeletion(source, context: context)
            targets = [.source(source)] + resolution.removals.map { .reference($0) }
            impact = .init(
              kind: .deleteSource, targetCount: Int64(targets.count), globalFlagsChanged: false,
              sourceDeletes: [source], referenceRemovals: resolution.removals)
            digest = sourceDeletionDigest(
              source: source, identity: identity, bindings: resolution.bindings,
              removals: resolution.removals)
          } else if source.kind == .item {
            let resolution = try resolveItemDeletion(source, context: context)
            targets = [.source(source)] + resolution.removals.map { .reference($0) }
            impact = .init(
              kind: .deleteSource, targetCount: Int64(targets.count), globalFlagsChanged: false,
              sourceDeletes: resolution.sourceDeletes, referenceRemovals: resolution.removals)
            digest = sourceDeletionDigest(
              source: source, identity: identity, bindings: resolution.bindings,
              removals: resolution.removals)
          } else {
            let resolution = try resolveLabelDeletion(source, context: context)
            let removals = resolution.associations.map(\.reference)
            targets = [.source(source)] + removals.map { .reference($0) }
            impact = .init(
              kind: .deleteSource, targetCount: Int64(targets.count), globalFlagsChanged: false,
              sourceDeletes: [source], referenceRemovals: removals)
            digest = sourceDeletionDigest(
              source: source, identity: identity, bindings: resolution.bindings)
          }
        default:
          throw PlannerFailure(
            "invalidInput", "This command has no reviewable impact.", propertyPath: "/command/type")
        }
        let reviewId = UUID()
        reviews[reviewId] = ReviewBinding(
          session: session, payloadDigest: digest)
        return .reviewed(
          .init(
            reviewId: reviewId, reviewToken: .init(reviewId: reviewId), command: command,
            targets: targets, impact: impact))
      }
    } catch {
      return .failed(failure(error, code: "readUnavailable"))
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
        case .deleteSource(let source):
          if source.kind == .list {
            return try executeListDeletion(
              operation, source: source, identity: identity, context: context, archive: archive,
              receipts: receipts, envelope: envelope)
          }
          if source.kind == .item {
            return try executeItemDeletion(
              operation, source: source, identity: identity, context: context, archive: archive,
              receipts: receipts, envelope: envelope)
          }
          return try executeLabelDeletion(
            operation, source: source, identity: identity, context: context, archive: archive,
            receipts: receipts, envelope: envelope)
        case .setBulkCompletion(let scope, let done):
          return try executeBulkCompletion(
            operation, scope: scope, done: done, identity: identity, context: context,
            archive: archive, receipts: receipts, envelope: envelope)
        case .reorderItineraryEntry(let itineraryId, let entryId, let placement):
          return try executeItineraryEntryReordering(
            operation, itineraryId: itineraryId, entryId: entryId, placement: placement,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .removeItineraryEntry(let itineraryId, let entryId):
          return try executeItineraryEntryRemoval(
            operation, itineraryId: itineraryId, entryId: entryId, identity: identity,
            context: context, archive: archive, receipts: receipts, envelope: envelope)
        case .addItineraryEntry(let itineraryId, let source, let placement):
          return try executeItineraryEntryCreation(
            operation, itineraryId: itineraryId, sourceReference: source, placement: placement,
            identity: identity, context: context, archive: archive, receipts: receipts,
            envelope: envelope)
        case .editItinerary(let sourceId, let changes, let hashes):
          return try executeItineraryEdit(
            operation, sourceId: sourceId, changes: changes, hashes: hashes, identity: identity,
            context: context, archive: archive, receipts: receipts, envelope: envelope)
        case .createItinerary(let content):
          return try executeItineraryCreation(
            operation, content: content, identity: identity, context: context, archive: archive,
            receipts: receipts, envelope: envelope)
        case .editCategory(let sourceId, let changes, let hashes):
          return try executeCategoryEdit(
            operation, sourceId: sourceId, changes: changes, hashes: hashes, identity: identity,
            context: context, archive: archive, receipts: receipts, envelope: envelope)
        case .editTag(let sourceId, let changes, let hashes):
          return try executeTagEdit(
            operation, sourceId: sourceId, changes: changes, hashes: hashes, identity: identity,
            context: context, archive: archive, receipts: receipts, envelope: envelope)
        case .createCategory(let content):
          return try executeCategoryCreation(
            operation, content: content, identity: identity, context: context, archive: archive,
            receipts: receipts, envelope: envelope)
        case .createTag(let content):
          return try executeTagCreation(
            operation, content: content, identity: identity, context: context, archive: archive,
            receipts: receipts, envelope: envelope)
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
          if source.kind == .itinerary {
            return try executeItineraryArchive(
              operation, source: source, archived: archived, identity: identity,
              context: context, archive: archive, receipts: receipts, envelope: envelope)
          }
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
          if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
            let stored = try receipt.evidence()
            let digest = content.payloadDigest(
              datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
              bindings: stored.bindings)
            guard receipt.payloadDigest == digest else {
              throw PlannerFailure(
                "operationPayloadMismatch",
                "This operation identity already describes different content.")
            }
            let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
            return appliedResult(
              operationId: operation.operationId, evidence: evidence, envelope: envelope)
          }
          let selectedCategories = try selectedCategoryRecords(
            content.categoryIds, context: context)
          let selectedTags = try selectedTagRecords(content.tagIds, context: context)
          let bindings =
            try selectedCategories.map { record in
              let snapshot = try record.value()
              return PlannerBoundIdentity(
                kind: "category", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
            }
            + selectedTags.map { record in
              let snapshot = try record.value()
              return PlannerBoundIdentity(
                kind: "tag", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
            }
          let digest = content.payloadDigest(
            datasetId: identity.datasetId,
            ownershipBinding: identity.ownershipBinding, bindings: bindings)
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
          let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
            try $0.value()
          }
          let existingAssociations = try labelAssociationSnapshots(context)
          let item = try PlannerSchemaV14.Item(input: content)
          item.labelAssociations =
            selectedCategories.map {
              PlannerSchemaV14.LabelAssociation(item: item, category: $0)
            } + selectedTags.map { PlannerSchemaV14.LabelAssociation(item: item, tag: $0) }
          let snapshot = try item.value()
          let generatedReferences = snapshot.labelAssociations.sorted {
            $0.id.uuidString < $1.id.uuidString
          }.map { PlannerAppliedIdentity.reference($0.reference) }
          let result = PlannerAppliedResult(
            generatedIdentities: [.source(snapshot.reference)] + generatedReferences,
            affectedIdentities: [.source(snapshot.reference)] + generatedReferences)
          let proposal = RecoveryPreparedProposal(
            proposalId: UUID(), originalOperationId: operation.operationId,
            datasetId: identity.datasetId,
            ownershipBinding: identity.ownershipBinding,
            proposedBackup: PlannerDataSnapshot(
              itineraries: try itinerarySnapshots(context),
              labelAssociations: existingAssociations + snapshot.labelAssociations,
              tags: try tagSnapshots(context), categories: try categorySnapshots(context),
              items: existingItems + [snapshot], lists: try listSnapshots(context),
              memberships: try membershipSnapshots(context),
              deletionMarkers: try deletionMarkers(context)),
            payloadDigest: digest, evidence: "preparedUnverified"
          )
          try archive.prepare(proposal)
          let receipt = try PlannerSchemaV1.Receipt(
            operation: operation, digest: digest, result: result, bindings: bindings)
          context.insert(item)
          for association in item.labelAssociations ?? [] { context.insert(association) }
          context.insert(receipt)
          do { try context.save() } catch {
            context.rollback()
            throw PlannerFailure(
              "persistenceFailure",
              "The complete Item action was not committed: \(error.localizedDescription)")
          }
          do {
            let generation = try archive.publish(
              itineraries: try itinerarySnapshots(context),
              labelAssociations: existingAssociations + snapshot.labelAssociations,
              tags: try tagSnapshots(context), categories: try categorySnapshots(context),
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
          if source.kind == .itinerary {
            let identifier = source.id
            var descriptor = FetchDescriptor<PlannerSchemaV14.Itinerary>(
              predicate: #Predicate { $0.id == identifier })
            descriptor.fetchLimit = 2
            let records = try context.fetch(descriptor)
            guard records.count == 1, let record = records.first else {
              throw PlannerFailure(
                "missingReference", "The selected Itinerary is missing or unresolved.")
            }
            return .source(
              .itinerary(
                try record.value().read(
                  datasetId: identity.datasetId, memberships: membershipSnapshots(context),
                  items: context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
                    try $0.value()
                  }, lists: listSnapshots(context))))
          }
          if source.kind == .category {
            return .source(
              .category(
                try categorySnapshot(source.id, context: context).read(
                  datasetId: identity.datasetId)))
          }
          if source.kind == .tag {
            return .source(
              .tag(
                try tagSnapshot(source.id, context: context).read(
                  datasetId: identity.datasetId)))
          }
          if source.kind == .list {
            let sourceIdentifier = source.id
            var descriptor = FetchDescriptor<PlannerSchemaV14.List>(
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
                  items: context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
                    try $0.value()
                  }, entries: itineraryEntrySnapshots(context))))
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
          let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).filter {
            $0.id == source.id
          }
          guard items.count == 1, let item = items.first else {
            throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
          }
          return .source(
            .item(
              try item.value().read(
                datasetId: identity.datasetId, memberships: membershipSnapshots(context),
                entries: itineraryEntrySnapshots(context))))
        }
      }
    } catch { return .failed(failure(error, code: "readUnavailable")) }
  }

  private func readAppearance(
    _ appearance: PlannerAppearance, datasetId: UUID, context: ModelContext
  ) throws -> PlannerAppearanceRead {
    switch appearance {
    case .expandedListItem(let itineraryId, let listEntryId, let membershipId):
      return try readExpandedAppearance(
        appearance, itineraryId: itineraryId, listEntryId: listEntryId,
        membershipId: membershipId, datasetId: datasetId, context: context)
    case .directItineraryItem(let itineraryId, let entryId):
      return try readDirectItineraryAppearance(
        appearance, itineraryId: itineraryId, entryId: entryId, datasetId: datasetId,
        context: context)
    case .listMembership(let listId, let membershipId):
      var descriptor = FetchDescriptor<PlannerSchemaV14.Membership>(
        predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
      descriptor.fetchLimit = 2
      let records = try context.fetch(descriptor)
      guard records.count == 1, let membership = records.first else {
        throw PlannerFailure(
          "missingReference", "The selected List appearance is missing or unresolved.")
      }
      let binding = try membership.value()
      let itemId = binding.item.id
      var itemDescriptor = FetchDescriptor<PlannerSchemaV14.Item>(
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
        labels: source.labels,
        globalDone: source.globalDone, localDone: binding.localDone,
        effectiveDone: source.globalDone || binding.localDone, archived: source.archived,
        fieldHashes: source.input.fieldHashes(
          datasetId: datasetId, itemId: source.id, lifetimeId: source.lifetimeId,
          links: source.links.map(\.read), labelAssociations: source.labelAssociations))
    }
  }

  private func readSchedule(
    _ source: PlannerEntityReference, datasetId: UUID, context: ModelContext
  ) throws -> PlannerScheduleSourceRead {
    let identifier = source.id
    var descriptor = FetchDescriptor<PlannerSchemaV14.Schedule>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected Schedule is missing or unresolved.")
    }
    let resolved = try resolvedSchedule(record, context: context)
    return PlannerScheduleSourceRead(
      source: resolved.snapshot.reference,
      content: PlannerScheduleContent(
        source: resolved.source, form: resolved.snapshot.form),
      fieldHashes: [.form: resolved.snapshot.formHash(datasetId: datasetId)])
  }

  private func resolvedSchedule(_ record: PlannerSchemaV14.Schedule, context: ModelContext) throws
    -> (snapshot: ScheduleSnapshot, source: PlannerEntityReference, owner: ScheduleOwner)
  {
    guard let ownerIdentifier = record.sourceId, let ownerLifetime = record.sourceLifetimeId else {
      throw PlannerFailure("readUnavailable", "The Schedule's source binding is unresolved.")
    }
    guard let ownerKind = PlannerEntityKind(rawValue: record.sourceKind) else {
      throw PlannerFailure("readUnavailable", "The Schedule has an unsupported source kind.")
    }
    let owner = PlannerEntityReference(kind: ownerKind, id: ownerIdentifier)
    let resolvedOwner = try resolveScheduleOwner(owner, context: context)
    let binding = try resolvedOwner.binding
    guard binding.lifetimeId == ownerLifetime else {
      throw PlannerFailure("readUnavailable", "The Schedule's source lifetime no longer resolves.")
    }
    let snapshot = try record.value(
      ownerId: ownerIdentifier, ownerLifetimeId: ownerLifetime, ownerKind: binding.kind)
    return (snapshot, owner, resolvedOwner)
  }

  private func resolveScheduleOwner(
    _ source: PlannerEntityReference, context: ModelContext, sourcePath: String? = nil
  ) throws -> ScheduleOwner {
    let identifier = source.id
    switch source.kind {
    case .item:
      var descriptor = FetchDescriptor<PlannerSchemaV14.Item>(
        predicate: #Predicate { $0.id == identifier })
      descriptor.fetchLimit = 2
      let records = try context.fetch(descriptor)
      if records.count == 1, let owner = records.first { return .item(owner) }
    case .itinerary:
      var descriptor = FetchDescriptor<PlannerSchemaV14.Itinerary>(
        predicate: #Predicate { $0.id == identifier })
      descriptor.fetchLimit = 2
      let records = try context.fetch(descriptor)
      if records.count == 1, let owner = records.first { return .itinerary(owner) }
    default:
      throw PlannerFailure(
        "invalidInput", "Schedules can belong to an Item or Itinerary.",
        propertyPath: "/command/source/kind")
    }
    throw PlannerFailure(
      "missingReference", "The Schedule's source is missing or unresolved.",
      propertyPath: sourcePath)
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
            let hasSavedOrder: Bool
            switch itemQuery.scope {
            case .list, .itinerary: hasSavedOrder = true
            case .global, .inbox: hasSavedOrder = false
            }
            guard hasSavedOrder, itemQuery.sort.direction == .ascending else {
              throw PlannerFailure(
                "invalidInput", "Manual order requires an ascending List or Itinerary query.",
                propertyPath: "/query/sort")
            }
          case .title, .created, .lastUpdated, .duration: break
          }
          let historyToken = try latestHistoryToken(in: context)
          var membershipListsByItem: [UUID: Set<UUID>] = [:]
          if itemQuery.lists?.ids.isEmpty == false {
            for membership in try membershipSnapshots(context) {
              membershipListsByItem[membership.item.id, default: []].insert(membership.list.id)
            }
          }
          let listedIdentifiers: Set<UUID>
          switch itemQuery.scope {
          case .global: listedIdentifiers = []
          case .inbox:
            if itemQuery.lists?.ids.isEmpty == false {
              listedIdentifiers = Set(membershipListsByItem.keys)
            } else {
              listedIdentifiers = Set(try membershipSnapshots(context).map { $0.item.id })
            }
          case .list(let listId):
            let snapshot = try listQuerySnapshot(
              session: query.session, listId: listId, query: itemQuery,
              presentation: presentation, membershipListsByItem: membershipListsByItem,
              context: context)
            guard try latestHistoryToken(in: context) == historyToken else {
              throw PlannerFailure(
                "readUnavailable", "The store changed while building this query.")
            }
            querySnapshots = querySnapshots.filter { $0.value.historyToken == historyToken }
            querySnapshots[snapshot.generation] = QueryBinding(
              snapshot: snapshot, historyToken: historyToken)
            return .snapshot(snapshot)
          case .itinerary(let itineraryId):
            let snapshot = try itineraryItemQuerySnapshot(
              session: query.session, itineraryId: itineraryId, query: itemQuery,
              presentation: presentation, membershipListsByItem: membershipListsByItem,
              context: context)
            guard try latestHistoryToken(in: context) == historyToken else {
              throw PlannerFailure(
                "readUnavailable", "The store changed while building this query.")
            }
            querySnapshots = querySnapshots.filter { $0.value.historyToken == historyToken }
            querySnapshots[snapshot.generation] = QueryBinding(
              snapshot: snapshot, historyToken: historyToken)
            return .snapshot(snapshot)
          }
          let textTerms = itemQuery.text.split(whereSeparator: \.isWhitespace).map(String.init)
          let locale = Locale(identifier: "en_US_POSIX")
          var descriptor = FetchDescriptor<PlannerSchemaV14.Item>()
          if textTerms.isEmpty, itemQuery.duration?.minimumMinutes == nil,
            itemQuery.duration?.maximumMinutes == nil, itemQuery.sort.mode != .duration,
            itemQuery.categories?.ids.isEmpty != false, itemQuery.tags?.ids.isEmpty != false,
            !itemQuery.hasAddress, !itemQuery.hasLinks
          {
            descriptor.propertiesToFetch = [\.id, \.title, \.globalDone, \.archived]
            if itemQuery.scheduled != .all { descriptor.propertiesToFetch.append(\.lifetimeId) }
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
            if let group = itemQuery.lists, !group.ids.isEmpty {
              guard let identifier = item.id else {
                throw PlannerFailure(
                  "readUnavailable", "A membership-filtered Item has unresolved identity.")
              }
              guard group.matches(membershipListsByItem[identifier] ?? []) else { return false }
            }
            guard try matchesItemLabels(item, query: itemQuery) else { return false }
            guard try matchesItemPresence(item, query: itemQuery) else { return false }
            guard try matchesItemScheduling(item, scheduled: itemQuery.scheduled, context: context)
            else { return false }
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
    _ item: PlannerSchemaV14.Item, terms: [String], locale: Locale
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

  private func matchesItemPresence(_ item: PlannerSchemaV14.Item, query: PlannerItemQuery) throws
    -> Bool
  {
    guard query.hasAddress || query.hasLinks else { return true }
    let value = try item.value()
    if query.hasAddress,
      value.input.location?.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty
        != false
    {
      return false
    }
    if query.hasLinks, value.links.isEmpty { return false }
    return true
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
    _ item: PlannerSchemaV14.Item, duration: PlannerItemQuery.Duration?
  ) throws -> Bool {
    guard let duration, duration.minimumMinutes != nil || duration.maximumMinutes != nil else {
      return true
    }
    guard let estimate = try item.value().input.estimate else { return duration.includeUnknown }
    if let minimum = duration.minimumMinutes, estimate.minutes < minimum { return false }
    if let maximum = duration.maximumMinutes, estimate.minutes > maximum { return false }
    return true
  }

  private func matchesItemLabels(_ item: PlannerSchemaV14.Item, query: PlannerItemQuery) throws
    -> Bool
  {
    guard query.categories?.ids.isEmpty == false || query.tags?.ids.isEmpty == false else {
      return true
    }
    let content = try item.value().input
    return (query.categories?.matches(content.categoryIds) ?? true)
      && (query.tags?.matches(content.tagIds) ?? true)
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
    _ item: PlannerSchemaV14.Item, mode: PlannerItemQuery.Sort.Mode
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
    if query.sourceKind == .category {
      return try categoryCatalogSnapshot(session: session, query: query, context: context)
    }
    if query.sourceKind == .tag {
      return try tagCatalogSnapshot(session: session, query: query, context: context)
    }
    if query.sourceKind == .itinerary {
      return try itineraryCatalogSnapshot(session: session, query: query, context: context)
    }
    if query.sourceKind == .schedule {
      return try scheduleCatalogSnapshot(session: session, query: query, context: context)
    }
    guard query.sourceKind == .list else {
      throw PlannerFailure(
        "unavailable", "This catalog slice supports List discovery only.",
        propertyPath: "/query/sourceKind")
    }
    var descriptor = FetchDescriptor<PlannerSchemaV14.List>()
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

  private func itineraryCatalogSnapshot(
    session: PlannerDatasetSession, query: PlannerCatalogQuery, context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    var descriptor = FetchDescriptor<PlannerSchemaV14.Itinerary>()
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.title, \.archived]
    let locale = Locale(identifier: "en_US_POSIX")
    let terms = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
    let matches = try context.fetch(descriptor).filter { itinerary in
      switch query.archive {
      case .active: if itinerary.archived { return false }
      case .archived: if !itinerary.archived { return false }
      case .all: break
      }
      return terms.allSatisfy {
        itinerary.title.range(
          of: $0, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) != nil
      }
    }
    let values = try matches.map { itinerary in
      guard let identifier = itinerary.id, itinerary.lifetimeId != nil,
        !itinerary.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PlannerFailure(
          "readUnavailable", "A catalog Itinerary has unresolved identity or title.")
      }
      return (
        source: PlannerEntityReference(kind: .itinerary, id: identifier),
        comparisonName: itinerary.title.folding(
          options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
      )
    }
    guard Set(values.map { $0.source.id }).count == values.count else {
      throw PlannerFailure(
        "readUnavailable", "Catalog Itinerary identities are duplicated and unresolved.")
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

  private func scheduleCatalogSnapshot(
    session: PlannerDatasetSession, query: PlannerCatalogQuery, context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    guard query.text.isEmpty else {
      throw PlannerFailure(
        "invalidInput", "Schedule catalogs require empty text.", propertyPath: "/query/text")
    }
    guard query.archive == .all else {
      throw PlannerFailure(
        "invalidInput", "Schedules have no archive state; select all.",
        propertyPath: "/query/archive")
    }
    let sources = try context.fetch(FetchDescriptor<PlannerSchemaV14.Schedule>()).map {
      try resolvedSchedule($0, context: context).snapshot.reference
    }
    guard Set(sources.map(\.id)).count == sources.count else {
      throw PlannerFailure("readUnavailable", "Catalog Schedule identities are duplicated.")
    }
    let sorted = sources.sorted { $0.id.uuidString < $1.id.uuidString }
    return PlannerQuerySnapshot(
      session: session, generation: UUID(), rows: sorted.map(PlannerRowIdentity.source),
      matchingCount: Int64(sorted.count), rowPresentation: nil,
      progress: [], unresolvedReferences: [])
  }

  private func listQuerySnapshot(
    session: PlannerDatasetSession, listId: UUID, query: PlannerItemQuery,
    presentation: PlannerRowPresentationContext, membershipListsByItem: [UUID: Set<UUID>],
    context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    var lists = FetchDescriptor<PlannerSchemaV14.List>(
      predicate: #Predicate { $0.id == listId })
    lists.fetchLimit = 2
    lists.propertiesToFetch = [\.id, \.lifetimeId]
    let owners = try context.fetch(lists)
    guard owners.count == 1, let owner = owners.first, let lifetimeId = owner.lifetimeId else {
      throw PlannerFailure("missingReference", "The selected List is missing or unresolved.")
    }
    let memberships = FetchDescriptor<PlannerSchemaV14.Membership>(
      predicate: #Predicate { $0.listId == listId && $0.listLifetimeId == lifetimeId },
      sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
    let children = try context.fetch(memberships).map { try $0.value() }
    guard Set(children.map(\.id)).count == children.count,
      Set(children.map { $0.item.id }).count == children.count
    else {
      throw PlannerFailure("readUnavailable", "List memberships are duplicated and unresolved.")
    }
    let appearances = children.map {
      ContextualQueryAppearance(
        item: $0.item, appearance: .listMembership(listId: listId, membershipId: $0.id),
        localDone: $0.localDone)
    }
    return try contextualItemQuerySnapshot(
      session: session, container: .init(kind: .list, id: listId), appearances: appearances,
      query: query, presentation: presentation, membershipListsByItem: membershipListsByItem,
      context: context)
  }

  private func itineraryItemQuerySnapshot(
    session: PlannerDatasetSession, itineraryId: UUID, query: PlannerItemQuery,
    presentation: PlannerRowPresentationContext, membershipListsByItem: [UUID: Set<UUID>],
    context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    var itineraries = FetchDescriptor<PlannerSchemaV14.Itinerary>(
      predicate: #Predicate { $0.id == itineraryId })
    itineraries.fetchLimit = 2
    itineraries.propertiesToFetch = [\.id, \.lifetimeId]
    let owners = try context.fetch(itineraries)
    guard owners.count == 1, let owner = owners.first, let lifetimeId = owner.lifetimeId else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let descriptor = FetchDescriptor<PlannerSchemaV14.ItineraryEntry>(
      predicate: #Predicate {
        $0.itineraryId == itineraryId && $0.itineraryLifetimeId == lifetimeId
      }, sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
    let entries = try context.fetch(descriptor).map { try $0.value() }
    guard Set(entries.map(\.id)).count == entries.count else {
      throw PlannerFailure("readUnavailable", "Itinerary entries are duplicated and unresolved.")
    }
    var appearances: [ContextualQueryAppearance] = []
    for entry in entries {
      if entry.source.kind == "item" {
        appearances.append(
          .init(
            item: entry.source,
            appearance: .directItineraryItem(itineraryId: itineraryId, entryId: entry.id),
            localDone: entry.localDone == true))
        continue
      }
      let listId = entry.source.id
      let listLifetimeId = entry.source.lifetimeId
      let memberships = FetchDescriptor<PlannerSchemaV14.Membership>(
        predicate: #Predicate { $0.listId == listId && $0.listLifetimeId == listLifetimeId },
        sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
      let children = try context.fetch(memberships).map { try $0.value() }
      guard Set(children.map(\.id)).count == children.count,
        Set(children.map { $0.item.id }).count == children.count
      else {
        throw PlannerFailure("readUnavailable", "List memberships are duplicated and unresolved.")
      }
      for membership in children {
        let localDone =
          entry.expandedCompletions.first {
            $0.context.membershipId == membership.id
              && $0.context.membershipLifetimeId == membership.lifetimeId
          }?.localDone ?? false
        appearances.append(
          .init(
            item: membership.item,
            appearance: .expandedListItem(
              itineraryId: itineraryId, listEntryId: entry.id, membershipId: membership.id),
            localDone: localDone))
      }
    }
    return try contextualItemQuerySnapshot(
      session: session, container: .init(kind: .itinerary, id: itineraryId),
      appearances: appearances,
      query: query, presentation: presentation, membershipListsByItem: membershipListsByItem,
      context: context)
  }

  private struct ContextualQueryAppearance {
    let item: PlannerBoundIdentity
    let appearance: PlannerAppearance
    let localDone: Bool
  }

  private func contextualItemQuerySnapshot(
    session: PlannerDatasetSession, container: PlannerEntityReference,
    appearances: [ContextualQueryAppearance], query: PlannerItemQuery,
    presentation: PlannerRowPresentationContext, membershipListsByItem: [UUID: Set<UUID>],
    context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    let itemIdentifiers = appearances.map { Optional($0.item.id) }
    let textTerms = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
    var items = FetchDescriptor<PlannerSchemaV14.Item>(
      predicate: #Predicate { itemIdentifiers.contains($0.id) })
    if textTerms.isEmpty, query.duration?.minimumMinutes == nil,
      query.duration?.maximumMinutes == nil, query.sort.mode != .duration,
      query.categories?.ids.isEmpty != false, query.tags?.ids.isEmpty != false,
      !query.hasAddress, !query.hasLinks
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
        comparisonDate: Date?, appearanceOrder: Int
      )] =
        []
    for (appearanceOrder, appearance) in appearances.enumerated() {
      guard let matches = sources[appearance.item.id], matches.count == 1,
        let item = matches.first, item.lifetimeId == appearance.item.lifetimeId,
        !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PlannerFailure("readUnavailable", "A contextual child Item is unresolved.")
      }
      let effectiveDone = item.globalDone || appearance.localDone
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
      if let group = query.lists, !group.matches(membershipListsByItem[appearance.item.id] ?? []) {
        continue
      }
      if !(try matchesItemLabels(item, query: query)) { continue }
      if !(try matchesItemPresence(item, query: query)) { continue }
      if !(try matchesItemScheduling(item, scheduled: query.scheduled, context: context)) {
        continue
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
            source: PlannerEntityReference(kind: .item, id: appearance.item.id),
            appearance: appearance.appearance),
          comparisonTitle: item.title.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: locale),
          itemId: appearance.item.id, durationMinutes: durationMinutes,
          comparisonDate: try chronologicalSortDate(item, mode: query.sort.mode),
          appearanceOrder: appearanceOrder
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
        if first.itemId != second.itemId {
          return first.itemId.uuidString < second.itemId.uuidString
        }
        return first.appearanceOrder < second.appearanceOrder
      }
    }
    let rows = matching.map(\.identity)
    let totalCount = Int64(appearances.count)
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
          container: container, state: state,
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
        var memberships = FetchDescriptor<PlannerSchemaV14.Membership>(
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
      case .appearance(let reference, let appearance):
        let read = try readAppearance(appearance, datasetId: session.datasetId, context: context)
        guard read.source == reference else {
          throw PlannerFailure("readUnavailable", "The snapshot appearance source is unresolved.")
        }
        source = reference
        localDone = read.localDone
        expectedLifetimeId = read.sourceLifetimeId
      case .source(let reference):
        source = reference
        localDone = nil
        expectedLifetimeId = nil
      }
      if source.kind == .category {
        let category = try categorySnapshot(source.id, context: context)
        return PlannerRowRead(
          identity: identity, sourceLifetimeId: category.lifetimeId,
          title: category.content.name, subtitle: nil, estimate: nil,
          globalDone: nil, localDone: nil, effectiveDone: nil, archived: nil,
          hasLocation: false, hasLinks: false, ownedLocation: nil, previewLink: nil,
          labels: [], scheduleSummary: .none)
      }
      if source.kind == .tag {
        let tag = try tagSnapshot(source.id, context: context)
        return PlannerRowRead(
          identity: identity, sourceLifetimeId: tag.lifetimeId,
          title: tag.content.name, subtitle: nil, estimate: nil,
          globalDone: nil, localDone: nil, effectiveDone: nil, archived: nil,
          hasLocation: false, hasLinks: false, ownedLocation: nil, previewLink: nil,
          labels: [], scheduleSummary: .none)
      }
      if source.kind == .list {
        let sourceIdentifier = source.id
        var descriptor = FetchDescriptor<PlannerSchemaV14.List>(
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
          labels: [], scheduleSummary: .none)
      }
      if source.kind == .itinerary {
        return try itineraryCatalogRow(identity: identity, sourceId: source.id, context: context)
      }
      if source.kind == .schedule {
        return try scheduleCatalogRow(identity: identity, sourceId: source.id, context: context)
      }
      guard let presentation = snapshot.rowPresentation else {
        throw PlannerFailure("readUnavailable", "The Item query has no presentation context.")
      }
      let sourceIdentifier = source.id
      var descriptor = FetchDescriptor<PlannerSchemaV14.Item>(
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
      let owned = FetchDescriptor<PlannerSchemaV14.OwnedLink>(
        predicate: #Predicate {
          $0.ownerId == sourceIdentifier && $0.ownerLifetimeId == lifetimeId
        })
      var selected = FetchDescriptor<PlannerSchemaV14.OwnedLink>(
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
      var scheduleSource = source
      var scheduleLifetimeId = lifetimeId
      if case .appearance(_, let appearance) = identity {
        let itineraryId: UUID?
        switch appearance {
        case .directItineraryItem(let identifier, _), .expandedListItem(let identifier, _, _):
          itineraryId = identifier
        case .listMembership: itineraryId = nil
        }
        if let itineraryId {
          var descriptor = FetchDescriptor<PlannerSchemaV14.Itinerary>(
            predicate: #Predicate { $0.id == itineraryId })
          descriptor.fetchLimit = 2
          descriptor.propertiesToFetch = [\.id, \.lifetimeId]
          let owners = try context.fetch(descriptor)
          guard owners.count == 1, let ownerLifetimeId = owners.first?.lifetimeId else {
            throw PlannerFailure("readUnavailable", "The row's planning Itinerary is unresolved.")
          }
          scheduleSource = .init(kind: .itinerary, id: itineraryId)
          scheduleLifetimeId = ownerLifetimeId
        }
      }
      let summary = try rowScheduleSummary(
        source: scheduleSource, lifetimeId: scheduleLifetimeId,
        presentation: presentation, context: context)
      return try item.rowRead(
        identity: identity, localDone: localDone,
        hasLinks: context.fetchCount(owned) > 0, previewLink: preview,
        labels: rowLabels(source: source, lifetimeId: lifetimeId, context: context),
        scheduleSummary: summary)
    }
    guard try latestHistoryToken(in: context) == binding.historyToken else {
      querySnapshots.removeValue(forKey: generation)
      throw staleSnapshot(generation)
    }
    return PlannerRowWindow(
      generation: generation, offset: offset, matchingCount: snapshot.matchingCount,
      rowPresentation: snapshot.rowPresentation, rows: rows)
  }

  private func rowLabels(
    source: PlannerEntityReference, lifetimeId: UUID, context: ModelContext
  ) throws -> [PlannerLabelRead] {
    let ownerKind = source.kind.rawValue
    let ownerId = source.id
    let descriptor = FetchDescriptor<PlannerSchemaV14.LabelAssociation>(
      predicate: #Predicate {
        $0.ownerKind == ownerKind && $0.ownerId == ownerId && $0.ownerLifetimeId == lifetimeId
      }, sortBy: [SortDescriptor(\.id)])
    let associations = try context.fetch(descriptor)
    let labels = try associations.map { try $0.labelRead() }
    let pairs = labels.map { $0.reference.kind.rawValue + ":" + $0.reference.id.uuidString }
    guard Set(associations.compactMap(\.id)).count == associations.count,
      Set(pairs).count == labels.count
    else {
      throw PlannerFailure("readUnavailable", "The row has duplicate label associations.")
    }
    return labels
  }

  private func itineraryCatalogRow(
    identity: PlannerRowIdentity, sourceId: UUID, context: ModelContext
  ) throws -> PlannerRowRead {
    var descriptor = FetchDescriptor<PlannerSchemaV14.Itinerary>(
      predicate: #Predicate { $0.id == sourceId })
    descriptor.fetchLimit = 2
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.title, \.archived, \.locationData]
    let records = try context.fetch(descriptor)
    guard records.count == 1, let itinerary = records.first, let lifetimeId = itinerary.lifetimeId
    else {
      throw PlannerFailure("readUnavailable", "A snapshot Itinerary is missing or unresolved.")
    }
    let content = PlannerItineraryContentInput(
      title: itinerary.title,
      location: try itinerary.locationData.map {
        try JSONDecoder().decode(PlannerOwnedLocation.self, from: $0)
      })
    try content.validate()
    let owned = FetchDescriptor<PlannerSchemaV14.OwnedLink>(
      predicate: #Predicate {
        $0.ownerKind == "itinerary" && $0.ownerId == sourceId && $0.ownerLifetimeId == lifetimeId
      })
    var selected = FetchDescriptor<PlannerSchemaV14.OwnedLink>(
      predicate: #Predicate {
        $0.ownerKind == "itinerary" && $0.ownerId == sourceId && $0.ownerLifetimeId == lifetimeId
          && $0.kind != "appleMaps" && $0.kind != "googleMaps"
      }, sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
    selected.fetchLimit = 1
    selected.propertiesToFetch = [
      \.id, \.lifetimeId, \.ownerKind, \.ownerId, \.ownerLifetimeId, \.rank,
      \.originalUrl, \.label, \.kind,
    ]
    let preview = try context.fetch(selected).first?.value(
      ownerId: sourceId, ownerLifetimeId: lifetimeId, ownerKind: "itinerary"
    ).read
    return PlannerRowRead(
      identity: identity, sourceLifetimeId: lifetimeId, title: content.title,
      subtitle: nil, estimate: nil, globalDone: nil, localDone: nil, effectiveDone: nil,
      archived: itinerary.archived, hasLocation: content.location != nil,
      hasLinks: try context.fetchCount(owned) > 0,
      ownedLocation: content.location, previewLink: preview,
      labels: try rowLabels(
        source: .init(kind: .itinerary, id: sourceId), lifetimeId: lifetimeId, context: context),
      scheduleSummary: .none)
  }

  private func scheduleCatalogRow(
    identity: PlannerRowIdentity, sourceId: UUID, context: ModelContext
  ) throws -> PlannerRowRead {
    var descriptor = FetchDescriptor<PlannerSchemaV14.Schedule>(
      predicate: #Predicate { $0.id == sourceId })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("readUnavailable", "A snapshot Schedule is missing or unresolved.")
    }
    let resolved = try resolvedSchedule(record, context: context)
    let title: String
    switch resolved.owner {
    case .item(let owner): title = owner.title
    case .itinerary(let owner): title = owner.title
    }
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw PlannerFailure("readUnavailable", "The Schedule owner has an unresolved title.")
    }
    return PlannerRowRead(
      identity: identity, sourceLifetimeId: resolved.snapshot.lifetimeId,
      title: title, subtitle: nil, estimate: nil,
      globalDone: nil, localDone: nil, effectiveDone: nil, archived: nil,
      hasLocation: false, hasLinks: false, ownedLocation: nil, previewLink: nil,
      labels: [], scheduleSummary: .none)
  }

  private func rowScheduleSummary(
    source: PlannerEntityReference, lifetimeId: UUID, presentation: PlannerRowPresentationContext,
    context: ModelContext
  ) throws -> PlannerRowScheduleSummary {
    let sourceIdentifier = source.id
    let sourceKind = source.kind.rawValue
    let referenceInstant = presentation.referenceInstant
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: presentation.displayTimeZone)!
    let currentDate = try scheduleCivilDate(referenceInstant, calendar: calendar)
    let assignments = FetchDescriptor<PlannerSchemaV14.Schedule>(
      predicate: #Predicate {
        $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
          && $0.sourceLifetimeId == lifetimeId
      })
    let assignmentCount = try context.fetchCount(assignments)
    guard assignmentCount > 0 else {
      if source.kind == .item,
        try hasInheritedSchedule(itemId: sourceIdentifier, lifetimeId: lifetimeId, context: context)
      {
        return .inScheduledPlan
      }
      return .none
    }
    let candidates = [
      FetchDescriptor<PlannerSchemaV14.Schedule>(
        predicate: #Predicate {
          $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
            && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) <= referenceInstant
            && $0.end != nil && ($0.end ?? referenceInstant) > referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV14.Schedule>(
        predicate: #Predicate {
          $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
            && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) >= referenceInstant
        }, sortBy: [SortDescriptor(\.start), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV14.Schedule>(
        predicate: #Predicate {
          $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
            && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) < referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
    ]
    var allDayDescriptor = FetchDescriptor<PlannerSchemaV14.Schedule>(
      predicate: #Predicate {
        $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
          && $0.sourceLifetimeId == lifetimeId
          && $0.formKind == "allDay"
      })
    allDayDescriptor.propertiesToFetch = [
      \.id, \.lifetimeId, \.sourceKind, \.sourceId, \.sourceLifetimeId, \.formKind,
      \.civilStartData,
      \.civilEndData, \.start, \.end, \.planningTimeZone,
    ]
    let civilAssignments = try context.fetch(allDayDescriptor).map {
      try $0.value(ownerId: sourceIdentifier, ownerLifetimeId: lifetimeId, ownerKind: sourceKind)
    }
    for (phase, candidateDescriptor) in candidates.enumerated() {
      var descriptor = candidateDescriptor
      descriptor.fetchLimit = 1
      descriptor.propertiesToFetch = [
        \.id, \.lifetimeId, \.sourceKind, \.sourceId, \.sourceLifetimeId, \.start, \.end,
        \.planningTimeZone,
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
        eligible.append(
          try record.value(
            ownerId: sourceIdentifier, ownerLifetimeId: lifetimeId, ownerKind: sourceKind))
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
      if source.kind == .itinerary {
        return .itinerarySpan(
          schedule: value.reference, owner: source, form: value.form,
          additionalCount: Int64(assignmentCount - 1))
      }
      return .directItem(
        schedule: value.reference, owner: source, form: value.form,
        additionalCount: Int64(assignmentCount - 1))
    }
    throw PlannerFailure("readUnavailable", "The row owner's Schedule assignments are unresolved.")
  }

  private func hasInheritedSchedule(itemId: UUID, lifetimeId: UUID, context: ModelContext) throws
    -> Bool
  {
    let directEntries = FetchDescriptor<PlannerSchemaV14.ItineraryEntry>(
      predicate: #Predicate {
        $0.sourceKind == "item" && $0.sourceId == itemId && $0.sourceLifetimeId == lifetimeId
      })
    var itineraries = try context.fetch(directEntries).map { try $0.value().itinerary }
    let memberships = FetchDescriptor<PlannerSchemaV14.Membership>(
      predicate: #Predicate { $0.itemId == itemId && $0.itemLifetimeId == lifetimeId })
    for membership in try context.fetch(memberships) {
      let list = try membership.value().list
      let listId = list.id
      let listLifetimeId = list.lifetimeId
      let listEntries = FetchDescriptor<PlannerSchemaV14.ItineraryEntry>(
        predicate: #Predicate {
          $0.sourceKind == "list" && $0.sourceId == listId && $0.sourceLifetimeId == listLifetimeId
        })
      itineraries.append(
        contentsOf: try context.fetch(listEntries).map { try $0.value().itinerary })
    }
    for itinerary in itineraries {
      let itineraryId = itinerary.id
      let itineraryLifetimeId = itinerary.lifetimeId
      var assignments = FetchDescriptor<PlannerSchemaV14.Schedule>(
        predicate: #Predicate {
          $0.sourceKind == "itinerary" && $0.sourceId == itineraryId
            && $0.sourceLifetimeId == itineraryLifetimeId
        })
      assignments.fetchLimit = 1
      guard let assignment = try context.fetch(assignments).first else { continue }
      _ = try assignment.value(
        ownerId: itineraryId, ownerLifetimeId: itineraryLifetimeId, ownerKind: "itinerary")
      return true
    }
    return false
  }

  private func matchesItemScheduling(
    _ item: PlannerSchemaV14.Item, scheduled: PlannerItemQuery.Scheduling, context: ModelContext
  ) throws -> Bool {
    guard scheduled != .all else { return true }
    guard let itemId = item.id, let lifetimeId = item.lifetimeId else {
      throw PlannerFailure("readUnavailable", "A schedule-filtered Item has unresolved identity.")
    }
    var assignments = FetchDescriptor<PlannerSchemaV14.Schedule>(
      predicate: #Predicate {
        $0.sourceKind == "item" && $0.sourceId == itemId && $0.sourceLifetimeId == lifetimeId
      })
    assignments.fetchLimit = 1
    let hasSchedule: Bool
    if let assignment = try context.fetch(assignments).first {
      _ = try assignment.value(ownerId: itemId, ownerLifetimeId: lifetimeId)
      hasSchedule = true
    } else {
      hasSchedule = try hasInheritedSchedule(
        itemId: itemId, lifetimeId: lifetimeId, context: context)
    }
    return hasSchedule == (scheduled == .scheduled)
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

  private func labelAssociationSnapshots(_ context: ModelContext) throws
    -> [LabelAssociationSnapshot]
  {
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.LabelAssociation>()).map {
      try $0.value()
    }
    let pairs = snapshots.map {
      $0.owner.kind + ":" + $0.owner.id.uuidString + ":" + $0.owner.lifetimeId.uuidString
        + ":" + $0.label.kind + ":" + $0.label.id.uuidString + ":" + $0.label.lifetimeId.uuidString
    }
    guard Set(snapshots.map(\.id)).count == snapshots.count, Set(pairs).count == snapshots.count
    else {
      throw PlannerFailure(
        "readUnavailable", "The graph has duplicate label association identities or pairs.")
    }
    return snapshots
  }

  private func selectedCategoryRecords(
    _ identifiers: Set<UUID>, context: ModelContext,
    propertyPath: String = "/command/content/categoryIds"
  ) throws
    -> [PlannerSchemaV14.Category]
  {
    try identifiers.sorted { $0.uuidString < $1.uuidString }.map { identifier in
      let records = try context.fetch(
        FetchDescriptor<PlannerSchemaV14.Category>(
          predicate: #Predicate { $0.id == identifier }))
      guard records.count == 1, let record = records.first else {
        throw PlannerFailure(
          "missingReference", "A selected Category is missing or ambiguous.",
          propertyPath: propertyPath)
      }
      _ = try record.value()
      return record
    }
  }

  private func selectedTagRecords(
    _ identifiers: Set<UUID>, context: ModelContext,
    propertyPath: String = "/command/content/tagIds"
  ) throws
    -> [PlannerSchemaV14.Tag]
  {
    try identifiers.sorted { $0.uuidString < $1.uuidString }.map { identifier in
      let records = try context.fetch(
        FetchDescriptor<PlannerSchemaV14.Tag>(
          predicate: #Predicate { $0.id == identifier }))
      guard records.count == 1, let record = records.first else {
        throw PlannerFailure(
          "missingReference", "A selected Tag is missing or ambiguous.",
          propertyPath: propertyPath)
      }
      _ = try record.value()
      return record
    }
  }

  private func categorySnapshots(_ context: ModelContext) throws -> [CategorySnapshot] {
    try context.fetch(FetchDescriptor<PlannerSchemaV14.Category>()).map { try $0.value() }
  }

  private func categorySnapshot(_ identifier: UUID, context: ModelContext) throws
    -> CategorySnapshot
  {
    var descriptor = FetchDescriptor<PlannerSchemaV14.Category>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected Category is missing or unresolved.")
    }
    return try record.value()
  }

  private func categoryCatalogSnapshot(
    session: PlannerDatasetSession, query: PlannerCatalogQuery, context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    guard query.archive == .all else {
      throw PlannerFailure(
        "invalidInput", "Categories have no archive state; select all.",
        propertyPath: "/query/archive")
    }
    let locale = Locale(identifier: "en_US_POSIX")
    let terms = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
    let matches = try categorySnapshots(context).filter { category in
      terms.allSatisfy {
        category.content.name.range(
          of: $0, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) != nil
      }
    }
    guard Set(matches.map(\.id)).count == matches.count else {
      throw PlannerFailure(
        "readUnavailable", "Catalog Category identities are duplicated and unresolved.")
    }
    let comparator = String.Comparator(
      options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    let sorted = matches.sorted { first, second in
      let comparison = comparator.compare(first.content.name, second.content.name)
      if comparison != .orderedSame { return comparison == .orderedAscending }
      return first.id.uuidString < second.id.uuidString
    }
    return PlannerQuerySnapshot(
      session: session, generation: UUID(), rows: sorted.map { .source($0.reference) },
      matchingCount: Int64(sorted.count), rowPresentation: nil, progress: [],
      unresolvedReferences: [])
  }

  private func executeCategoryCreation(
    _ operation: PlannerOperation, content: PlannerCategoryContentInput,
    identity: PlannerStoreIdentity,
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
    let category = try PlannerSchemaV14.Category(content: content)
    let snapshot = try category.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingCategories = try categorySnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
      try $0.value()
    }
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: existingCategories + [snapshot],
        items: existingItems, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified"
    )
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result)
    context.insert(category)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Category action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: existingCategories + [snapshot],
        items: existingItems, lists: try listSnapshots(context),
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

  private func tagSnapshots(_ context: ModelContext) throws -> [TagSnapshot] {
    try context.fetch(FetchDescriptor<PlannerSchemaV14.Tag>()).map { try $0.value() }
  }

  private func tagSnapshot(_ identifier: UUID, context: ModelContext) throws
    -> TagSnapshot
  {
    var descriptor = FetchDescriptor<PlannerSchemaV14.Tag>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected Tag is missing or unresolved.")
    }
    return try record.value()
  }

  private func tagCatalogSnapshot(
    session: PlannerDatasetSession, query: PlannerCatalogQuery, context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    guard query.archive == .all else {
      throw PlannerFailure(
        "invalidInput", "Tags have no archive state; select all.",
        propertyPath: "/query/archive")
    }
    let locale = Locale(identifier: "en_US_POSIX")
    let terms = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
    let matches = try tagSnapshots(context).filter { tag in
      terms.allSatisfy {
        tag.content.name.range(
          of: $0, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) != nil
      }
    }
    guard Set(matches.map(\.id)).count == matches.count else {
      throw PlannerFailure(
        "readUnavailable", "Catalog Tag identities are duplicated and unresolved.")
    }
    let comparator = String.Comparator(
      options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    let sorted = matches.sorted { first, second in
      let comparison = comparator.compare(first.content.name, second.content.name)
      if comparison != .orderedSame { return comparison == .orderedAscending }
      return first.id.uuidString < second.id.uuidString
    }
    return PlannerQuerySnapshot(
      session: session, generation: UUID(), rows: sorted.map { .source($0.reference) },
      matchingCount: Int64(sorted.count), rowPresentation: nil, progress: [],
      unresolvedReferences: [])
  }

  private func executeTagCreation(
    _ operation: PlannerOperation, content: PlannerTagContentInput,
    identity: PlannerStoreIdentity,
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
    let tag = try PlannerSchemaV14.Tag(content: content)
    let snapshot = try tag.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingTags = try tagSnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
      try $0.value()
    }
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: existingTags + [snapshot],
        categories: try categorySnapshots(context),
        items: existingItems, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified"
    )
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result)
    context.insert(tag)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Tag action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: existingTags + [snapshot],
        categories: try categorySnapshots(context),
        items: existingItems, lists: try listSnapshots(context),
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

  private func itinerarySnapshots(_ context: ModelContext) throws -> [ItinerarySnapshot] {
    try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>()).map { try $0.value() }
  }

  private func executeItineraryCreation(
    _ operation: PlannerOperation, content: PlannerItineraryContentInput,
    identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive, receipts: [PlannerSchemaV1.Receipt],
    envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    try content.validate()
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      let digest = content.payloadDigest(identity: identity, bindings: stored.bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch",
          "This operation identity already describes different content.")
      }
      let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
      return appliedResult(
        operationId: operation.operationId, evidence: evidence, envelope: envelope)
    }
    let selectedCategories = try selectedCategoryRecords(
      content.categoryIds, context: context)
    let selectedTags = try selectedTagRecords(content.tagIds, context: context)
    let bindings =
      try selectedCategories.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(
          kind: "category", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
      + selectedTags.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(
          kind: "tag", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
    let digest = content.payloadDigest(identity: identity, bindings: bindings)
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
    let existingItineraries = try itinerarySnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
      try $0.value()
    }
    let existingAssociations = try labelAssociationSnapshots(context)
    let itinerary = try PlannerSchemaV14.Itinerary(input: content)
    itinerary.labelAssociations =
      selectedCategories.map {
        PlannerSchemaV14.LabelAssociation(itinerary: itinerary, category: $0)
      } + selectedTags.map { PlannerSchemaV14.LabelAssociation(itinerary: itinerary, tag: $0) }
    let snapshot = try itinerary.value()
    let generatedReferences = snapshot.labelAssociations.sorted {
      $0.id.uuidString < $1.id.uuidString
    }.map { PlannerAppliedIdentity.reference($0.reference) }
    let result = PlannerAppliedResult(
      generatedIdentities: [.source(snapshot.reference)] + generatedReferences,
      affectedIdentities: [.source(snapshot.reference)] + generatedReferences)
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: existingItineraries + [snapshot],
        labelAssociations: existingAssociations + snapshot.labelAssociations,
        tags: try tagSnapshots(context), categories: try categorySnapshots(context),
        items: existingItems, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified"
    )
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    context.insert(itinerary)
    for association in itinerary.labelAssociations ?? [] { context.insert(association) }
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Itinerary action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: existingItineraries + [snapshot],
        labelAssociations: existingAssociations + snapshot.labelAssociations,
        tags: try tagSnapshots(context), categories: try categorySnapshots(context),
        items: existingItems, lists: try listSnapshots(context),
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
    let list = try PlannerSchemaV14.List(content: content)
    let snapshot = try list.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingLists = try listSnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
      try $0.value()
    }
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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

  private func executeCategoryEdit(
    _ operation: PlannerOperation, sourceId: UUID, changes: PlannerCategoryChanges,
    hashes: [PlannerCategoryField: PlannerFieldHash],
    identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    let fields = try changes.validatedFields()
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
      let digest = try changes.payloadDigest(
        sourceId: sourceId, fields: fields, hashes: hashes, identity: identity,
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
    let categories = try context.fetch(FetchDescriptor<PlannerSchemaV14.Category>())
    let matches = categories.filter { $0.id == sourceId }
    guard matches.count == 1, let category = matches.first else {
      throw PlannerFailure("missingReference", "The selected Category is missing or unresolved.")
    }
    let before = try category.value()
    let bindings = [
      PlannerBoundIdentity(kind: "category", id: before.id, lifetimeId: before.lifetimeId)
    ]
    let digest = try changes.payloadDigest(
      sourceId: sourceId, fields: fields, hashes: hashes, identity: identity, bindings: bindings)
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
        details: .staleCategoryEdit(
          conflictingFields: conflictingFields,
          currentValues: Dictionary(
            uniqueKeysWithValues: conflictingFields.map { ($0, before.fieldValue($0)) }),
          currentFieldHashes: currentHashes.filter { conflictingFields.contains($0.key) }))
    }
    let content = changes.applying(to: before.content)
    let updatedAt = Date()
    let colorData = try content.color.map { try JSONEncoder().encode($0) }
    let after = CategorySnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: updatedAt,
      content: content)
    let snapshots = try categories.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let result = PlannerAppliedResult(generated: [], affected: [before.reference])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: snapshots,
        items: items, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified")
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if fields.contains(.name) { category.name = content.name }
    if fields.contains(.color) { category.colorData = colorData }
    if fields.contains(.iconName) { category.iconName = content.iconName }
    category.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Category action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: snapshots,
        items: items, lists: try listSnapshots(context),
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

  private func executeTagEdit(
    _ operation: PlannerOperation, sourceId: UUID, changes: PlannerTagChanges,
    hashes: [PlannerTagField: PlannerFieldHash],
    identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    let fields = try changes.validatedFields()
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
      let digest = try changes.payloadDigest(
        sourceId: sourceId, fields: fields, hashes: hashes, identity: identity,
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
    let tags = try context.fetch(FetchDescriptor<PlannerSchemaV14.Tag>())
    let matches = tags.filter { $0.id == sourceId }
    guard matches.count == 1, let tag = matches.first else {
      throw PlannerFailure("missingReference", "The selected Tag is missing or unresolved.")
    }
    let before = try tag.value()
    let bindings = [
      PlannerBoundIdentity(kind: "tag", id: before.id, lifetimeId: before.lifetimeId)
    ]
    let digest = try changes.payloadDigest(
      sourceId: sourceId, fields: fields, hashes: hashes, identity: identity, bindings: bindings)
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
        details: .staleTagEdit(
          conflictingFields: conflictingFields,
          currentValues: Dictionary(
            uniqueKeysWithValues: conflictingFields.map { ($0, before.fieldValue($0)) }),
          currentFieldHashes: currentHashes.filter { conflictingFields.contains($0.key) }))
    }
    let content = changes.applying(to: before.content)
    let updatedAt = Date()
    let colorData = try content.color.map { try JSONEncoder().encode($0) }
    let after = TagSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: updatedAt,
      content: content)
    let snapshots = try tags.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let result = PlannerAppliedResult(generated: [], affected: [before.reference])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: snapshots,
        categories: try categorySnapshots(context),
        items: items, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified")
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if fields.contains(.name) { tag.name = content.name }
    if fields.contains(.color) { tag.colorData = colorData }
    if fields.contains(.iconName) { tag.iconName = content.iconName }
    tag.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Tag action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: snapshots,
        categories: try categorySnapshots(context),
        items: items, lists: try listSnapshots(context),
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
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let result = PlannerAppliedResult(generated: [], affected: [before.reference])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
    try context.fetch(FetchDescriptor<PlannerSchemaV14.List>()).map { try $0.value() }
  }

  private func membershipSnapshots(_ context: ModelContext) throws -> [MembershipSnapshot] {
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.Membership>()).map {
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

  private func itineraryEntrySnapshots(_ context: ModelContext) throws -> [ItineraryEntrySnapshot] {
    let entries = try context.fetch(FetchDescriptor<PlannerSchemaV14.ItineraryEntry>()).map {
      try $0.value()
    }
    guard Set(entries.map(\.id)).count == entries.count else {
      throw PlannerFailure("readUnavailable", "The itinerary entries have duplicate identities.")
    }
    return entries
  }

  private func readDirectItineraryAppearance(
    _ appearance: PlannerAppearance, itineraryId: UUID,
    entryId: UUID, datasetId: UUID, context: ModelContext
  ) throws -> PlannerAppearanceRead {
    let entries = try itineraryEntrySnapshots(context).filter {
      $0.id == entryId && $0.itinerary.id == itineraryId && $0.source.kind == "item"
    }
    guard entries.count == 1, let entry = entries.first, let localDone = entry.localDone else {
      throw PlannerFailure(
        "missingReference", "The direct itinerary Item appearance is missing or unresolved.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).filter {
      $0.id == entry.source.id && $0.lifetimeId == entry.source.lifetimeId
    }
    guard items.count == 1, let record = items.first else {
      throw PlannerFailure("missingReference", "The appearance's Item lifetime is unresolved.")
    }
    let source = try record.value()
    return .init(
      appearance: appearance, source: source.reference, sourceLifetimeId: source.lifetimeId,
      content: source.input.readContent(links: source.links.map(\.read)),
      labels: source.labels,
      globalDone: source.globalDone,
      localDone: localDone, effectiveDone: source.globalDone || localDone,
      archived: source.archived,
      fieldHashes: source.input.fieldHashes(
        datasetId: datasetId, itemId: source.id,
        lifetimeId: source.lifetimeId, links: source.links.map(\.read),
        labelAssociations: source.labelAssociations))
  }

  private func executeItineraryEntryReordering(
    _ operation: PlannerOperation, itineraryId: UUID, entryId: UUID, placement: PlannerPlacement,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let digest = itineraryEntryReorderingDigest(
        itineraryId: itineraryId, entryId: entryId, placement: placement, identity: identity,
        bindings: try receipt.evidence().bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another entry reorder.")
      }
      return appliedResult(
        operationId: operation.operationId,
        evidence: try RecoveryReceipt(receipt, checkpoint: nil), envelope: envelope)
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    var descriptor = FetchDescriptor<PlannerSchemaV14.ItineraryEntry>(
      predicate: #Predicate { $0.id == entryId && $0.itineraryId == itineraryId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first, let owner = record.itinerary else {
      throw PlannerFailure(
        "missingReference", "The selected itinerary entry is missing or unresolved.")
    }
    let before = try record.value()
    let ownerSnapshot = try owner.value()
    switch placement {
    case .before(let identifier), .after(let identifier):
      guard identifier != entryId else {
        throw PlannerFailure(
          "invalidInput", "An entry cannot use itself as its placement anchor.",
          propertyPath: "/command/placement/associationId")
      }
    case .first, .last: break
    }
    var entries = ownerSnapshot.entries
    let ordered = entries
    let remaining = ordered.filter { $0.id != entryId }
    let insertionIndex = try associationInsertionIndex(placement, in: remaining)
    var desiredOrder = remaining.map(\.id)
    desiredOrder.insert(entryId, at: insertionIndex)
    let changed = desiredOrder != ordered.map(\.id)
    var bindings = [
      PlannerBoundIdentity(kind: "itineraryEntry", id: before.id, lifetimeId: before.lifetimeId),
      before.itinerary, before.source,
    ]
    switch placement {
    case .before(let identifier), .after(let identifier):
      if let anchor = remaining.first(where: { $0.id == identifier }) {
        bindings.append(.init(kind: "itineraryEntry", id: anchor.id, lifetimeId: anchor.lifetimeId))
      }
    case .first, .last: break
    }
    let digest = itineraryEntryReorderingDigest(
      itineraryId: itineraryId, entryId: entryId, placement: placement, identity: identity,
      bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another entry reorder.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    if changed {
      let rank = try associationInsertionRank(
        at: insertionIndex, ordered: remaining, associations: &entries)
      guard let selectedIndex = entries.firstIndex(where: { $0.id == entryId }) else {
        throw PlannerFailure("missingReference", "The selected itinerary entry is missing.")
      }
      entries[selectedIndex].rank = rank
      entries.sort {
        if $0.rank != $1.rank { return $0.rank < $1.rank }
        return $0.id.uuidString < $1.id.uuidString
      }
    }
    let updatedAt = changed ? Date() : ownerSnapshot.updatedAt
    let ownerAfter = ItinerarySnapshot(
      id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
      createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt, input: ownerSnapshot.input,
      archived: ownerSnapshot.archived, links: ownerSnapshot.links,
      schedules: ownerSnapshot.schedules,
      labelAssociations: ownerSnapshot.labelAssociations, labels: ownerSnapshot.labels,
      entries: entries)
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>()).map {
      if $0.id == itineraryId { return ownerAfter }
      return try $0.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)])
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    let ranks = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.rank) })
    for entry in owner.entries ?? [] {
      if let identifier = entry.id, let rank = ranks[identifier], entry.rank != rank {
        entry.rank = rank
      }
    }
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete entry reorder was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: snapshots, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func itineraryEntryReorderingDigest(
    itineraryId: UUID, entryId: UUID, placement: PlannerPlacement, identity: PlannerStoreIdentity,
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
        "type": .string("reorderItineraryEntry"), "itineraryId": .identity(itineraryId),
        "entryId": .identity(entryId), "placement": placementValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }

  private func executeItineraryEntryRemoval(
    _ operation: PlannerOperation, itineraryId: UUID, entryId: UUID,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let digest = itineraryEntryRemovalDigest(
        itineraryId: itineraryId, entryId: entryId, identity: identity,
        bindings: try receipt.evidence().bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another entry removal.")
      }
      return appliedResult(
        operationId: operation.operationId,
        evidence: try RecoveryReceipt(receipt, checkpoint: nil), envelope: envelope)
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    var descriptor = FetchDescriptor<PlannerSchemaV14.ItineraryEntry>(
      predicate: #Predicate { $0.id == entryId && $0.itineraryId == itineraryId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let entry = selected.first, let owner = entry.itinerary else {
      throw PlannerFailure(
        "missingReference", "The selected itinerary entry is missing or unresolved.")
    }
    let before = try entry.value()
    let ownerSnapshot = try owner.value()
    let bindings = [
      PlannerBoundIdentity(kind: "itineraryEntry", id: before.id, lifetimeId: before.lifetimeId),
      before.itinerary, before.source,
    ]
    let digest = itineraryEntryRemovalDigest(
      itineraryId: itineraryId, entryId: entryId, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another entry removal.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let updatedAt = Date()
    let ownerAfter = ItinerarySnapshot(
      id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
      createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt, input: ownerSnapshot.input,
      archived: ownerSnapshot.archived, links: ownerSnapshot.links,
      schedules: ownerSnapshot.schedules,
      labelAssociations: ownerSnapshot.labelAssociations, labels: ownerSnapshot.labels,
      entries: ownerSnapshot.entries.filter { $0.id != entryId })
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>()).map {
      if $0.id == itineraryId { return ownerAfter }
      return try $0.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let removalMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .itineraryEntry(id: before.id, lifetimeId: before.lifetimeId), closedFamilyId: nil)
    let markers = try deletionMarkers(context) + [removalMarker]
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)]
        + before.expandedCompletions.map { .reference($0.reference) })
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    for completion in entry.expandedCompletions ?? [] { context.delete(completion) }
    context.delete(entry)
    context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete entry removal was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: snapshots, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func itineraryEntryRemovalDigest(
    itineraryId: UUID, entryId: UUID, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("removeItineraryEntry"), "itineraryId": .identity(itineraryId),
        "entryId": .identity(entryId),
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }

  private func executeItineraryEntryCreation(
    _ operation: PlannerOperation, itineraryId: UUID, sourceReference: PlannerEntityReference,
    placement: PlannerPlacement, identity: PlannerStoreIdentity, context: ModelContext,
    archive: PlannerRecoveryArchive, receipts: [PlannerSchemaV1.Receipt],
    envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    guard [.item, .list].contains(sourceReference.kind) else {
      throw PlannerFailure(
        "invalidInput", "An itinerary entry source must be an Item or List.",
        propertyPath: "/command/source/kind")
    }
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let digest = itineraryEntryCreationDigest(
        itineraryId: itineraryId, source: sourceReference,
        placement: placement, identity: identity, bindings: try receipt.evidence().bindings)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another entry addition.")
      }
      return appliedResult(
        operationId: operation.operationId,
        evidence: try RecoveryReceipt(receipt, checkpoint: nil), envelope: envelope)
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let itineraries = try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>())
    let owners = itineraries.filter { $0.id == itineraryId }
    guard owners.count == 1, let itinerary = owners.first else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let before = try itinerary.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
    let item: PlannerSchemaV14.Item?
    let list: PlannerSchemaV14.List?
    let source: PlannerBoundIdentity
    if sourceReference.kind == .item {
      let matches = items.filter { $0.id == sourceReference.id }
      guard matches.count == 1, let record = matches.first else {
        throw PlannerFailure(
          "missingReference", "The entry's shared Item is missing or unresolved.")
      }
      let value = try record.value()
      item = record
      list = nil
      source = .init(kind: "item", id: value.id, lifetimeId: value.lifetimeId)
    } else {
      let matches = lists.filter { $0.id == sourceReference.id }
      guard matches.count == 1, let record = matches.first else {
        throw PlannerFailure(
          "missingReference", "The entry's shared List is missing or unresolved.")
      }
      let value = try record.value()
      item = nil
      list = record
      source = .init(kind: "list", id: value.id, lifetimeId: value.lifetimeId)
    }
    var entries = before.entries
    let insertionIndex = try associationInsertionIndex(placement, in: entries)
    var bindings = [
      PlannerBoundIdentity(kind: "itinerary", id: before.id, lifetimeId: before.lifetimeId), source,
    ]
    switch placement {
    case .before(let identifier), .after(let identifier):
      if let anchor = entries.first(where: { $0.id == identifier }) {
        bindings.append(.init(kind: "itineraryEntry", id: anchor.id, lifetimeId: anchor.lifetimeId))
      }
    case .first, .last: break
    }
    let digest = itineraryEntryCreationDigest(
      itineraryId: itineraryId, source: sourceReference,
      placement: placement, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another entry addition.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let rank = try associationInsertionRank(
      at: insertionIndex, ordered: entries, associations: &entries)
    let identifier = UUID()
    let entry = ItineraryEntrySnapshot(
      id: identifier, lifetimeId: identifier, itinerary: bindings[0],
      source: source, rank: rank, localDone: source.kind == "item" ? false : nil)
    entries.append(entry)
    let updatedAt = Date()
    let after = ItinerarySnapshot(
      id: before.id, lifetimeId: before.lifetimeId,
      createdAt: before.createdAt, updatedAt: updatedAt, input: before.input,
      archived: before.archived,
      links: before.links, schedules: before.schedules, labelAssociations: before.labelAssociations,
      labels: before.labels,
      entries: entries)
    let snapshots = try itineraries.map { record in
      if record.id == itineraryId { return after }
      return try record.value()
    }
    let itemSnapshots = try items.map { try $0.value() }
    let listSnapshots = try lists.map { try $0.value() }
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [.reference(entry.reference)],
      affectedIdentities: [.reference(entry.reference), .source(before.reference)])
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels,
          tags: tags, categories: categories, items: itemSnapshots, lists: listSnapshots,
          memberships: memberships, deletionMarkers: markers), payloadDigest: digest,
        evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    context.insert(
      PlannerSchemaV14.ItineraryEntry(snapshot: entry, itinerary: itinerary, item: item, list: list)
    )
    let ranks = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.rank) })
    for record in itinerary.entries ?? [] {
      if let identifier = record.id, let rank = ranks[identifier] { record.rank = rank }
    }
    itinerary.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete itinerary entry action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: snapshots, labelAssociations: labels,
        tags: tags, categories: categories, items: itemSnapshots, lists: listSnapshots,
        memberships: memberships, deletionMarkers: markers, receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func itineraryEntryCreationDigest(
    itineraryId: UUID, source: PlannerEntityReference,
    placement: PlannerPlacement, identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity]
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
        "type": .string("addItineraryEntry"), "itineraryId": .identity(itineraryId),
        "source": .record(["kind": .string(source.kind.rawValue), "id": .identity(source.id)]),
        "placement": placementValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    return plannerDigest(
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
      prefix: "sha256-payload-v1:")
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
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
    let insertionIndex = try associationInsertionIndex(placement, in: ordered)
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
      let rank = try associationInsertionRank(
        at: insertionIndex, ordered: ordered, associations: &memberships)
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers),
      payloadDigest: digest, evidence: "preparedUnverified")
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if let added {
      context.insert(PlannerSchemaV14.Membership(snapshot: added, list: list, item: item))
    }
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for record in try context.fetch(FetchDescriptor<PlannerSchemaV14.Membership>()) {
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
    var descriptor = FetchDescriptor<PlannerSchemaV14.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure("missingReference", "The selected membership is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
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
    let expandedRecords = record.expandedCompletions ?? []
    let expandedSnapshots = try expandedRecords.map { try $0.value() }.sorted {
      $0.context.orderingKey < $1.context.orderingKey
    }
    let retainedItineraries = removingExpandedContexts(
      for: before, from: try itinerarySnapshots(context))
    let affectedItineraries = Set(expandedSnapshots.map(\.itineraryId)).sorted {
      $0.uuidString < $1.uuidString
    }
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)]
        + expandedSnapshots.map { .reference($0.reference) }
        + affectedItineraries.map { .source(.init(kind: .itinerary, id: $0)) })
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: retainedItineraries,
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    for completion in expandedRecords { context.delete(completion) }
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
        itineraries: retainedItineraries,
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
    var descriptor = FetchDescriptor<PlannerSchemaV14.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure("missingReference", "The selected membership is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
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
    let insertionIndex = try associationInsertionIndex(placement, in: ordered)
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
      let rank = try associationInsertionRank(
        at: insertionIndex, ordered: ordered, associations: &memberships)
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
    let expandedRecords = record.expandedCompletions ?? []
    let expandedSnapshots = try expandedRecords.map { try $0.value() }.sorted {
      $0.context.orderingKey < $1.context.orderingKey
    }
    let retainedItineraries = removingExpandedContexts(
      for: before, from: try itinerarySnapshots(context))
    let affectedItineraries = Set(expandedSnapshots.map(\.itineraryId)).sorted {
      $0.uuidString < $1.uuidString
    }
    let result = PlannerAppliedResult(
      generatedIdentities: added == nil ? [] : [.reference(destinationReference)],
      affectedIdentities: [
        .reference(before.reference), .reference(destinationReference),
        .source(ownerSnapshot.reference), .source(destinationSnapshot.reference),
      ] + expandedSnapshots.map { .reference($0.reference) }
        + affectedItineraries.map { .source(.init(kind: .itinerary, id: $0)) })
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: retainedItineraries,
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    for completion in expandedRecords { context.delete(completion) }
    context.delete(record)
    if let added {
      context.insert(PlannerSchemaV14.Membership(snapshot: added, list: destination, item: source))
    }
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV14.Membership>()) {
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
        itineraries: retainedItineraries,
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
    var descriptor = FetchDescriptor<PlannerSchemaV14.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure("missingReference", "The selected membership is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
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
    let insertionIndex = try associationInsertionIndex(placement, in: remaining)
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
      let rank = try associationInsertionRank(
        at: insertionIndex, ordered: remaining, associations: &memberships)
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
          itineraries: try itinerarySnapshots(context),
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV14.Membership>()) {
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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

  private func resolveExpandedAppearance(
    itineraryId: UUID, listEntryId: UUID, membershipId: UUID,
    context: ModelContext
  ) throws -> (entry: PlannerSchemaV14.ItineraryEntry, membership: PlannerSchemaV14.Membership) {
    var entryDescriptor = FetchDescriptor<PlannerSchemaV14.ItineraryEntry>(
      predicate: #Predicate {
        $0.id == listEntryId && $0.itineraryId == itineraryId && $0.sourceKind == "list"
      })
    entryDescriptor.fetchLimit = 2
    let entries = try context.fetch(entryDescriptor)
    var membershipDescriptor = FetchDescriptor<PlannerSchemaV14.Membership>(
      predicate: #Predicate { $0.id == membershipId })
    membershipDescriptor.fetchLimit = 2
    let memberships = try context.fetch(membershipDescriptor)
    guard entries.count == 1, let entry = entries.first, memberships.count == 1,
      let membership = memberships.first
    else {
      throw PlannerFailure(
        "missingReference", "The expanded itinerary appearance is missing or unresolved.")
    }
    let entryBinding = try entry.value()
    let membershipBinding = try membership.value()
    guard
      entryBinding.source.id == membershipBinding.list.id
        && entryBinding.source.lifetimeId == membershipBinding.list.lifetimeId
    else {
      throw PlannerFailure(
        "missingReference", "The selected membership does not belong to this itinerary List entry.")
    }
    return (entry, membership)
  }

  private func readExpandedAppearance(
    _ appearance: PlannerAppearance, itineraryId: UUID,
    listEntryId: UUID, membershipId: UUID, datasetId: UUID, context: ModelContext
  ) throws -> PlannerAppearanceRead {
    let records = try resolveExpandedAppearance(
      itineraryId: itineraryId, listEntryId: listEntryId, membershipId: membershipId,
      context: context)
    let entry = try records.entry.value()
    let membership = try records.membership.value()
    guard let item = records.membership.item else {
      throw PlannerFailure("missingReference", "The expanded appearance's Item is unresolved.")
    }
    let source = try item.value()
    let localDone =
      entry.expandedCompletions.first {
        $0.context.membershipId == membership.id
          && $0.context.membershipLifetimeId == membership.lifetimeId
      }?.localDone ?? false
    return .init(
      appearance: appearance, source: source.reference, sourceLifetimeId: source.lifetimeId,
      content: source.input.readContent(links: source.links.map(\.read)),
      labels: source.labels,
      globalDone: source.globalDone,
      localDone: localDone, effectiveDone: source.globalDone || localDone,
      archived: source.archived,
      fieldHashes: source.input.fieldHashes(
        datasetId: datasetId, itemId: source.id, lifetimeId: source.lifetimeId,
        links: source.links.map(\.read), labelAssociations: source.labelAssociations))
  }

  private func executeExpandedCompletion(
    _ operation: PlannerOperation, appearance: PlannerAppearance,
    itineraryId: UUID, listEntryId: UUID, membershipId: UUID, done: Bool,
    identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive, receipts: [PlannerSchemaV1.Receipt]
  ) throws -> PlannerOperationResult {
    let records = try resolveExpandedAppearance(
      itineraryId: itineraryId, listEntryId: listEntryId, membershipId: membershipId,
      context: context)
    let before = try records.entry.value()
    let membership = try records.membership.value()
    guard let owner = records.entry.itinerary else {
      throw PlannerFailure("missingReference", "The expanded appearance's Itinerary is unresolved.")
    }
    let ownerSnapshot = try owner.value()
    let binding = PlannerExpandedContext(
      listEntryId: before.id, listEntryLifetimeId: before.lifetimeId,
      membershipId: membership.id, membershipLifetimeId: membership.lifetimeId)
    let bindings = [
      before.itinerary, before.source, membership.item,
      PlannerBoundIdentity(kind: "itineraryEntry", id: before.id, lifetimeId: before.lifetimeId),
      PlannerBoundIdentity(
        kind: "membership", id: membership.id, lifetimeId: membership.lifetimeId),
    ]
    let digest = appearanceCompletionDigest(
      appearance: appearance, done: done, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another completion action.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let previous = before.expandedCompletions.first { $0.context == binding }
    let after = ExpandedCompletionSnapshot(
      context: binding, localDone: done, itineraryId: itineraryId)
    var entryAfter = before
    if previous != nil || done {
      entryAfter.expandedCompletions.removeAll { $0.context == binding }
      entryAfter.expandedCompletions.append(after)
      entryAfter.expandedCompletions.sort { $0.context.orderingKey < $1.context.orderingKey }
    }
    let updatedAt = (previous?.localDone ?? false) == done ? ownerSnapshot.updatedAt : Date()
    let ownerAfter = ItinerarySnapshot(
      id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
      createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt, input: ownerSnapshot.input,
      archived: ownerSnapshot.archived, links: ownerSnapshot.links,
      schedules: ownerSnapshot.schedules,
      labelAssociations: ownerSnapshot.labelAssociations,
      labels: ownerSnapshot.labels,
      entries: ownerSnapshot.entries.map { entry in
        if entry.id == before.id { return entryAfter }
        return entry
      })
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>()).map {
      itinerary in
      if itinerary.id == itineraryId { return ownerAfter }
      return try itinerary.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(after.reference), .source(ownerSnapshot.reference)])
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels,
          tags: tags, categories: categories, items: items, lists: lists, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    let existing = (records.entry.expandedCompletions ?? []).first {
      $0.membershipId == membership.id && $0.membershipLifetimeId == membership.lifetimeId
    }
    if let existing {
      existing.localDone = done
    } else if done {
      context.insert(
        PlannerSchemaV14.ExpandedCompletion(
          listEntry: records.entry, membership: records.membership, localDone: done))
    }
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete expanded completion action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: snapshots, labelAssociations: labels,
        tags: tags, categories: categories, items: items, lists: lists, memberships: memberships,
        deletionMarkers: markers, receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func executeDirectItineraryCompletion(
    _ operation: PlannerOperation, appearance: PlannerAppearance, itineraryId: UUID, entryId: UUID,
    done: Bool, identity: PlannerStoreIdentity, context: ModelContext,
    archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt]
  ) throws -> PlannerOperationResult {
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV14.ItineraryEntry>()).filter {
      $0.id == entryId && $0.itineraryId == itineraryId && $0.sourceKind == "item"
    }
    guard records.count == 1, let record = records.first, let owner = record.itinerary else {
      throw PlannerFailure(
        "missingReference", "The direct itinerary Item appearance is missing or unresolved.")
    }
    let before = try record.value()
    let ownerSnapshot = try owner.value()
    let bindings = [
      PlannerBoundIdentity(kind: "itineraryEntry", id: before.id, lifetimeId: before.lifetimeId),
      before.itinerary, before.source,
    ]
    let digest = appearanceCompletionDigest(
      appearance: appearance, done: done, identity: identity, bindings: bindings)
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another completion action.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let entryAfter = ItineraryEntrySnapshot(
      id: before.id, lifetimeId: before.lifetimeId,
      itinerary: before.itinerary, source: before.source, rank: before.rank, localDone: done)
    let updatedAt = before.localDone == done ? ownerSnapshot.updatedAt : Date()
    let ownerAfter = ItinerarySnapshot(
      id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
      createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt, input: ownerSnapshot.input,
      archived: ownerSnapshot.archived, links: ownerSnapshot.links,
      schedules: ownerSnapshot.schedules,
      labelAssociations: ownerSnapshot.labelAssociations, labels: ownerSnapshot.labels,
      entries: ownerSnapshot.entries.map { entry in
        if entry.id == before.id { return entryAfter }
        return entry
      })
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>()).map {
      itinerary in
      if itinerary.id == itineraryId { return ownerAfter }
      return try itinerary.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)])
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels,
          tags: tags, categories: categories, items: items, lists: lists, memberships: memberships,
          deletionMarkers: markers), payloadDigest: digest, evidence: "preparedUnverified"))
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
        itineraries: snapshots, labelAssociations: labels,
        tags: tags, categories: categories, items: items, lists: lists, memberships: memberships,
        deletionMarkers: markers, receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private struct ListDeletionResolution {
    let record: PlannerSchemaV14.List
    let snapshot: ListSnapshot
    let memberships: [MembershipSnapshot]
    let entries: [ItineraryEntrySnapshot]
    let expanded: [ExpandedCompletionSnapshot]
    let membershipRecords: [PlannerSchemaV14.Membership]
    let entryRecords: [PlannerSchemaV14.ItineraryEntry]
    let expandedRecords: [PlannerSchemaV14.ExpandedCompletion]

    var source: PlannerBoundIdentity {
      .init(kind: "list", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
    }

    var bindings: [PlannerBoundIdentity] {
      [source]
        + memberships.flatMap {
          [.init(kind: "membership", id: $0.id, lifetimeId: $0.lifetimeId), $0.item]
        }
        + entries.flatMap {
          [.init(kind: "itineraryEntry", id: $0.id, lifetimeId: $0.lifetimeId), $0.itinerary]
        }
    }

    var removals: [PlannerReferenceRead] {
      memberships.map(\.reference) + entries.map(\.reference) + expanded.map(\.reference)
    }
  }

  private func resolveListDeletion(_ source: PlannerEntityReference, context: ModelContext)
    throws -> ListDeletionResolution
  {
    let identifier = source.id
    var descriptor = FetchDescriptor<PlannerSchemaV14.List>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected List is missing or unresolved.")
    }
    let snapshot = try record.value()
    let memberships = try membershipSnapshots(context).filter { $0.list.id == identifier }.sorted {
      $0.id.uuidString < $1.id.uuidString
    }
    let allEntries = try itineraryEntrySnapshots(context)
    let entries = allEntries.filter { $0.source.kind == "list" && $0.source.id == identifier }
      .sorted { $0.id.uuidString < $1.id.uuidString }
    let membershipRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.Membership>()).filter
    {
      $0.listId == identifier
    }
    let entryRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.ItineraryEntry>()).filter
    {
      $0.sourceKind == "list" && $0.sourceId == identifier
    }
    guard memberships.allSatisfy({ $0.list.lifetimeId == snapshot.lifetimeId }),
      entries.allSatisfy({ $0.source.lifetimeId == snapshot.lifetimeId }),
      Set(memberships.map(\.id)) == Set((record.memberships ?? []).compactMap(\.id)),
      membershipRecords.count == memberships.count,
      Set(entries.map(\.id)) == Set((record.itineraryEntries ?? []).compactMap(\.id)),
      entryRecords.count == entries.count
    else {
      throw PlannerFailure("readUnavailable", "The List's complete deletion closure is unresolved.")
    }
    let membershipIdentifiers = Set(memberships.map(\.id))
    let entryIdentifiers = Set(entries.map(\.id))
    let expandedRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.ExpandedCompletion>())
      .filter {
        $0.membershipId.map(membershipIdentifiers.contains) == true
          || $0.listEntryId.map(entryIdentifiers.contains) == true
      }
    let expanded = try expandedRecords.map { try $0.value() }.sorted {
      $0.context.orderingKey < $1.context.orderingKey
    }
    let expectedContexts = allEntries.flatMap(\.expandedCompletions).filter {
      membershipIdentifiers.contains($0.context.membershipId)
        || entryIdentifiers.contains($0.context.listEntryId)
    }
    guard Set(expanded.map(\.context)).count == expanded.count,
      Set(expanded.map(\.context)) == Set(expectedContexts.map(\.context)),
      expanded.allSatisfy({
        membershipIdentifiers.contains($0.context.membershipId)
          && entryIdentifiers.contains($0.context.listEntryId)
      }),
      expanded.count == membershipRecords.flatMap({ $0.expandedCompletions ?? [] }).count,
      expanded.count == entryRecords.flatMap({ $0.expandedCompletions ?? [] }).count
    else {
      throw PlannerFailure(
        "readUnavailable", "The List's expanded completion contexts are unresolved.")
    }
    return .init(
      record: record, snapshot: snapshot, memberships: memberships, entries: entries,
      expanded: expanded, membershipRecords: membershipRecords, entryRecords: entryRecords,
      expandedRecords: expandedRecords)
  }

  private func executeListDeletion(
    _ operation: PlannerOperation, source: PlannerEntityReference,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      guard
        receipt.payloadDigest
          == sourceDeletionDigest(
            source: source, identity: identity, bindings: stored.bindings,
            removals: stored.result.affectedReferences)
      else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation describes another deletion.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: try RecoveryReceipt(receipt, checkpoint: nil),
        envelope: envelope)
    }
    let completedIdentifiers = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIdentifiers.contains($0) } ?? false })
    else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    guard let token = operation.reviewToken, let review = reviews[token.reviewId],
      review.session == operation.session
    else {
      throw PlannerFailure(
        "staleReview", "Review the complete deletion impact in the current dataset session.",
        propertyPath: "/reviewToken", details: .staleReview)
    }
    let resolution = try resolveListDeletion(source, context: context)
    let digest = sourceDeletionDigest(
      source: source, identity: identity, bindings: resolution.bindings,
      removals: resolution.removals)
    guard digest == review.payloadDigest else {
      throw PlannerFailure(
        "staleReview", "The command or complete removal set changed; review it again.",
        details: .staleReview)
    }
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another deletion.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let removedMembershipIdentifiers = Set(resolution.memberships.map(\.id))
    let removedEntryIdentifiers = Set(resolution.entries.map(\.id))
    let affectedItineraryIdentifiers = Set(resolution.entries.map { $0.itinerary.id })
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context).filter { $0.id != source.id }
    let memberships = try membershipSnapshots(context).filter {
      !removedMembershipIdentifiers.contains($0.id)
    }
    let labels = try labelAssociationSnapshots(context)
    let categories = try categorySnapshots(context)
    let tags = try tagSnapshots(context)
    let updatedAt = Date()
    let itineraries = try itinerarySnapshots(context).map { value in
      ItinerarySnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: affectedItineraryIdentifiers.contains(value.id) ? updatedAt : value.updatedAt,
        input: value.input, archived: value.archived, links: value.links,
        schedules: value.schedules, labelAssociations: value.labelAssociations,
        labels: value.labels,
        entries: value.entries.filter { !removedEntryIdentifiers.contains($0.id) })
    }
    let newMarkers =
      [
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .source(resolution.source), closedFamilyId: nil)
      ]
      + resolution.memberships.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .membership(.init(kind: "membership", id: $0.id, lifetimeId: $0.lifetimeId)),
          closedFamilyId: nil)
      }
      + resolution.entries.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .itineraryEntry(id: $0.id, lifetimeId: $0.lifetimeId), closedFamilyId: nil)
      }
    let markers = try deletionMarkers(context) + newMarkers
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.source(source)] + resolution.removals.map { .reference($0) }
        + affectedItineraryIdentifiers.sorted { $0.uuidString < $1.uuidString }.map {
          .source(.init(kind: .itinerary, id: $0))
        })
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: resolution.bindings)
    for marker in newMarkers { context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
    for record in resolution.expandedRecords { context.delete(record) }
    for record in resolution.membershipRecords { context.delete(record) }
    for record in resolution.entryRecords {
      record.itinerary?.updatedAt = updatedAt
      context.delete(record)
    }
    context.delete(resolution.record)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete List deletion was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private struct ItemDeletionResolution {
    let record: PlannerSchemaV14.Item
    let snapshot: ItemSnapshot
    let memberships: [MembershipSnapshot]
    let entries: [ItineraryEntrySnapshot]
    let associations: [LabelAssociationSnapshot]
    let membershipRecords: [PlannerSchemaV14.Membership]
    let entryRecords: [PlannerSchemaV14.ItineraryEntry]
    let associationRecords: [PlannerSchemaV14.LabelAssociation]
    let linkRecords: [PlannerSchemaV14.OwnedLink]
    let scheduleRecords: [PlannerSchemaV14.Schedule]
    let expandedRecords: [PlannerSchemaV14.ExpandedCompletion]
    let expanded: [ExpandedCompletionSnapshot]
    let expandedBindings: [PlannerBoundIdentity]

    var source: PlannerBoundIdentity {
      .init(kind: "item", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
    }

    var bindings: [PlannerBoundIdentity] {
      [source]
        + snapshot.links.map { .init(kind: "ownedLink", id: $0.id, lifetimeId: $0.lifetimeId) }
        + snapshot.schedules.map { .init(kind: "schedule", id: $0.id, lifetimeId: $0.lifetimeId) }
        + memberships.flatMap {
          [.init(kind: "membership", id: $0.id, lifetimeId: $0.lifetimeId), $0.list]
        }
        + entries.flatMap {
          [.init(kind: "itineraryEntry", id: $0.id, lifetimeId: $0.lifetimeId), $0.itinerary]
        }
        + associations.flatMap {
          [.init(kind: "labelAssociation", id: $0.id, lifetimeId: $0.lifetimeId), $0.label]
        }
        + expandedBindings
    }

    var removals: [PlannerReferenceRead] {
      associations.map(\.reference)
        + snapshot.links.map { .ownedLink(id: $0.id, owner: snapshot.reference) }
        + snapshot.schedules.sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .schedule(id: $0.id, source: snapshot.reference)
        }
        + memberships.map(\.reference) + entries.map(\.reference) + expanded.map(\.reference)
    }

    var sourceDeletes: [PlannerEntityReference] {
      [snapshot.reference]
        + snapshot.schedules.sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .init(kind: .schedule, id: $0.id)
        }
    }
  }

  private func resolveItemDeletion(_ source: PlannerEntityReference, context: ModelContext)
    throws -> ItemDeletionResolution
  {
    let identifier = source.id
    var descriptor = FetchDescriptor<PlannerSchemaV14.Item>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
    }
    let snapshot = try record.value()
    let memberships = try membershipSnapshots(context).filter { $0.item.id == identifier }.sorted {
      $0.id.uuidString < $1.id.uuidString
    }
    let allEntries = try itineraryEntrySnapshots(context)
    let entries = allEntries.filter { $0.source.kind == "item" && $0.source.id == identifier }
      .sorted { $0.id.uuidString < $1.id.uuidString }
    let associations = try labelAssociationSnapshots(context).filter {
      $0.owner.kind == "item" && $0.owner.id == identifier
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    let membershipRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.Membership>()).filter
    { $0.itemId == identifier }
    let entryRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.ItineraryEntry>()).filter
    { $0.sourceKind == "item" && $0.sourceId == identifier }
    let associationRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.LabelAssociation>())
      .filter { $0.ownerKind == "item" && $0.ownerId == identifier }
    let linkRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.OwnedLink>()).filter {
      $0.ownerKind == "item" && $0.ownerId == identifier
    }
    let scheduleRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.Schedule>()).filter {
      $0.sourceKind == "item" && $0.sourceId == identifier
    }
    let links = try linkRecords.map {
      try $0.value(ownerId: identifier, ownerLifetimeId: snapshot.lifetimeId)
    }
    let schedules = try scheduleRecords.map {
      try $0.value(ownerId: identifier, ownerLifetimeId: snapshot.lifetimeId)
    }
    guard memberships.allSatisfy({ $0.item.lifetimeId == snapshot.lifetimeId }),
      entries.allSatisfy({ $0.source.lifetimeId == snapshot.lifetimeId }),
      associations.allSatisfy({ $0.owner.lifetimeId == snapshot.lifetimeId }),
      Set(memberships.map(\.id)) == Set((record.memberships ?? []).compactMap(\.id)),
      membershipRecords.count == memberships.count,
      Set(entries.map(\.id)) == Set((record.itineraryEntries ?? []).compactMap(\.id)),
      entryRecords.count == entries.count,
      Set(associations.map(\.id)) == Set(snapshot.labelAssociations.map(\.id)),
      associationRecords.count == associations.count,
      links.count == snapshot.links.count, Set(links.map(\.id)) == Set(snapshot.links.map(\.id)),
      schedules.count == snapshot.schedules.count,
      Set(schedules.map(\.id)) == Set(snapshot.schedules.map(\.id))
    else {
      throw PlannerFailure("readUnavailable", "The Item's complete deletion closure is unresolved.")
    }
    let membershipIds = Set(memberships.map(\.id))
    let expandedRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.ExpandedCompletion>())
      .filter { $0.membershipId.map(membershipIds.contains) == true }
    let expanded = try expandedRecords.map { try $0.value() }.sorted {
      $0.context.orderingKey < $1.context.orderingKey
    }
    let expectedContexts = allEntries.flatMap(\.expandedCompletions).filter {
      membershipIds.contains($0.context.membershipId)
    }
    guard Set(expanded.map(\.context)).count == expanded.count,
      Set(expanded.map(\.context)) == Set(expectedContexts.map(\.context)),
      expanded.count == membershipRecords.flatMap({ $0.expandedCompletions ?? [] }).count
    else {
      throw PlannerFailure(
        "readUnavailable", "The Item's expanded completion contexts are unresolved.")
    }
    let expandedBindings = try expanded.flatMap { completion -> [PlannerBoundIdentity] in
      guard
        let entry = allEntries.first(where: {
          $0.id == completion.context.listEntryId
            && $0.lifetimeId == completion.context.listEntryLifetimeId
        })
      else {
        throw PlannerFailure(
          "readUnavailable", "An expanded completion's List entry is unresolved.")
      }
      return [
        .init(kind: "itineraryEntry", id: entry.id, lifetimeId: entry.lifetimeId), entry.itinerary,
      ]
    }
    return .init(
      record: record, snapshot: snapshot, memberships: memberships, entries: entries,
      associations: associations, membershipRecords: membershipRecords, entryRecords: entryRecords,
      associationRecords: associationRecords, linkRecords: linkRecords,
      scheduleRecords: scheduleRecords,
      expandedRecords: expandedRecords, expanded: expanded, expandedBindings: expandedBindings)
  }

  private func executeItemDeletion(
    _ operation: PlannerOperation, source: PlannerEntityReference,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      guard
        receipt.payloadDigest
          == sourceDeletionDigest(
            source: source, identity: identity, bindings: stored.bindings,
            removals: stored.result.affectedReferences)
      else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation describes another deletion.")
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
    guard let token = operation.reviewToken, let review = reviews[token.reviewId],
      review.session == operation.session
    else {
      throw PlannerFailure(
        "staleReview", "Review the complete deletion impact in the current dataset session.",
        propertyPath: "/reviewToken", details: .staleReview)
    }
    let resolution = try resolveItemDeletion(source, context: context)
    let digest = sourceDeletionDigest(
      source: source, identity: identity, bindings: resolution.bindings,
      removals: resolution.removals)
    guard digest == review.payloadDigest else {
      throw PlannerFailure(
        "staleReview", "The command or complete removal set changed; review it again.",
        details: .staleReview)
    }
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another deletion.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let removedMembershipIds = Set(resolution.memberships.map(\.id))
    let removedEntryIds = Set(resolution.entries.map(\.id))
    let removedAssociationIds = Set(resolution.associations.map(\.id))
    let affectedListIds = Set(resolution.memberships.map { $0.list.id })
    let directlyAffectedItineraryIds = Set(resolution.entries.map { $0.itinerary.id })
    let updatedAt = Date()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).filter {
      $0.id != source.id
    }.map { try $0.value() }
    let memberships = try membershipSnapshots(context).filter {
      !removedMembershipIds.contains($0.id)
    }
    let labels = try labelAssociationSnapshots(context).filter {
      !removedAssociationIds.contains($0.id)
    }
    let categories = try categorySnapshots(context)
    let tags = try tagSnapshots(context)
    let listRecords = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
    let lists = try listRecords.map { record in
      let value = try record.value()
      guard affectedListIds.contains(value.id) else { return value }
      return ListSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: updatedAt, content: value.content, archived: value.archived)
    }
    let allItineraries = try itinerarySnapshots(context)
    let itineraries = allItineraries.map { value in
      let entries = value.entries.filter { !removedEntryIds.contains($0.id) }.map { original in
        var entry = original
        entry.expandedCompletions.removeAll {
          removedMembershipIds.contains($0.context.membershipId)
        }
        return entry
      }
      return ItinerarySnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: directlyAffectedItineraryIds.contains(value.id) ? updatedAt : value.updatedAt,
        input: value.input, archived: value.archived, links: value.links,
        schedules: value.schedules,
        labelAssociations: value.labelAssociations, labels: value.labels, entries: entries)
    }
    let newMarkers =
      [
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .source(resolution.source), closedFamilyId: nil)
      ]
      + resolution.snapshot.schedules.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .source(.init(kind: "schedule", id: $0.id, lifetimeId: $0.lifetimeId)),
          closedFamilyId: nil)
      }
      + resolution.memberships.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .membership(.init(kind: "membership", id: $0.id, lifetimeId: $0.lifetimeId)),
          closedFamilyId: nil)
      }
      + resolution.entries.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .itineraryEntry(id: $0.id, lifetimeId: $0.lifetimeId), closedFamilyId: nil)
      }
      + resolution.associations.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .labelAssociation(id: $0.id, lifetimeId: $0.lifetimeId), closedFamilyId: nil)
      }
    let markers = try deletionMarkers(context) + newMarkers
    let affectedItineraryIds = Set(
      allItineraries.filter { itinerary in
        directlyAffectedItineraryIds.contains(itinerary.id)
          || itinerary.entries.contains {
            $0.source.kind == "list" && affectedListIds.contains($0.source.id)
          }
      }.map(\.id))
    let affectedContainers =
      affectedListIds.sorted { $0.uuidString < $1.uuidString }.map {
        PlannerEntityReference(kind: .list, id: $0)
      }
      + affectedItineraryIds.sorted { $0.uuidString < $1.uuidString }.map {
        .init(kind: .itinerary, id: $0)
      }
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: resolution.sourceDeletes.map { .source($0) }
        + resolution.removals.map { .reference($0) } + affectedContainers.map { .source($0) })
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: resolution.bindings)
    for marker in newMarkers { context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
    for record in resolution.expandedRecords { context.delete(record) }
    for record in resolution.membershipRecords { context.delete(record) }
    for record in resolution.entryRecords {
      record.itinerary?.updatedAt = updatedAt
      context.delete(record)
    }
    for record in resolution.associationRecords { context.delete(record) }
    for record in resolution.linkRecords { context.delete(record) }
    for record in resolution.scheduleRecords { context.delete(record) }
    for record in listRecords where record.id.map(affectedListIds.contains) == true {
      record.updatedAt = updatedAt
    }
    context.delete(resolution.record)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Item deletion was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private enum LabelDeletionRecord {
    case category(PlannerSchemaV14.Category)
    case tag(PlannerSchemaV14.Tag)

    func delete(context: ModelContext) {
      switch self {
      case .category(let record): context.delete(record)
      case .tag(let record): context.delete(record)
      }
    }
  }

  private struct LabelDeletionResolution {
    let record: LabelDeletionRecord
    let source: PlannerBoundIdentity
    let records: [PlannerSchemaV14.LabelAssociation]
    let associations: [LabelAssociationSnapshot]

    var bindings: [PlannerBoundIdentity] {
      [source]
        + associations.flatMap {
          [.init(kind: "labelAssociation", id: $0.id, lifetimeId: $0.lifetimeId), $0.owner]
        }
    }
  }

  private func resolveLabelDeletion(_ source: PlannerEntityReference, context: ModelContext)
    throws -> LabelDeletionResolution
  {
    let sourceId = source.id
    let record: LabelDeletionRecord
    let binding: PlannerBoundIdentity
    let associationCount: Int
    switch source.kind {
    case .category:
      var descriptor = FetchDescriptor<PlannerSchemaV14.Category>(
        predicate: #Predicate { $0.id == sourceId })
      descriptor.fetchLimit = 2
      let records = try context.fetch(descriptor)
      guard records.count == 1, let category = records.first else {
        throw PlannerFailure("missingReference", "The selected Category is missing or unresolved.")
      }
      let snapshot = try category.value()
      record = .category(category)
      binding = .init(kind: "category", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      associationCount = snapshot.associations.count
    case .tag:
      var descriptor = FetchDescriptor<PlannerSchemaV14.Tag>(
        predicate: #Predicate { $0.id == sourceId })
      descriptor.fetchLimit = 2
      let records = try context.fetch(descriptor)
      guard records.count == 1, let tag = records.first else {
        throw PlannerFailure("missingReference", "The selected Tag is missing or unresolved.")
      }
      let snapshot = try tag.value()
      record = .tag(tag)
      binding = .init(kind: "tag", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      associationCount = snapshot.associations.count
    case .schedule:
      throw PlannerFailure(
        "invalidInput", "Source deletion accepts Items, Lists, Itineraries, Categories or Tags.",
        propertyPath: "/command/source/kind")
    default:
      throw PlannerFailure(
        "unavailable", "Reviewed deletion of this source kind is not implemented.")
    }
    let associations = try labelAssociationSnapshots(context).filter {
      $0.label.kind == binding.kind && $0.label.id == binding.id
        && $0.label.lifetimeId == binding.lifetimeId
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV14.LabelAssociation>()).filter {
      $0.labelKind == binding.kind && $0.labelId == binding.id
        && $0.labelLifetimeId == binding.lifetimeId
    }
    guard associationCount == associations.count, records.count == associations.count else {
      throw PlannerFailure("readUnavailable", "The shared label associations are unresolved.")
    }
    return .init(record: record, source: binding, records: records, associations: associations)
  }

  private func executeLabelDeletion(
    _ operation: PlannerOperation, source: PlannerEntityReference,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      guard
        receipt.payloadDigest
          == sourceDeletionDigest(
            source: source, identity: identity, bindings: stored.bindings)
      else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation describes another deletion.")
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
    guard let token = operation.reviewToken,
      let review = reviews[token.reviewId], review.session == operation.session
    else {
      throw PlannerFailure(
        "staleReview", "Review the complete deletion impact in the current dataset session.",
        propertyPath: "/reviewToken", details: .staleReview)
    }
    let resolution = try resolveLabelDeletion(source, context: context)
    let digest = sourceDeletionDigest(
      source: source, identity: identity, bindings: resolution.bindings)
    guard digest == review.payloadDigest else {
      throw PlannerFailure(
        "staleReview", "The command or complete removal set changed; review it again.",
        details: .staleReview)
    }
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another deletion.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let removedIds = Set(resolution.associations.map(\.id))
    let labels = try labelAssociationSnapshots(context).filter { !removedIds.contains($0.id) }
    let categories = try categorySnapshots(context).filter {
      source.kind != .category || $0.id != source.id
    }
    let tags = try tagSnapshots(context).filter { source.kind != .tag || $0.id != source.id }
    let updatedAt = Date()
    let affectedOwners = resolution.associations.map(\.owner)
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { record in
      let value = try record.value()
      guard
        affectedOwners.contains(where: {
          $0.kind == "item" && $0.id == value.id && $0.lifetimeId == value.lifetimeId
        })
      else { return value }
      return ItemSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: updatedAt,
        input: value.input, globalDone: value.globalDone, archived: value.archived,
        links: value.links, schedules: value.schedules,
        labelAssociations: value.labelAssociations.filter { !removedIds.contains($0.id) },
        labels: value.labels.filter { $0.reference != source })
    }
    let itineraries = try itinerarySnapshots(context).map { value in
      guard
        affectedOwners.contains(where: {
          $0.kind == "itinerary" && $0.id == value.id && $0.lifetimeId == value.lifetimeId
        })
      else { return value }
      return ItinerarySnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: updatedAt,
        input: value.input, archived: value.archived, links: value.links,
        schedules: value.schedules,
        labelAssociations: value.labelAssociations.filter { !removedIds.contains($0.id) },
        labels: value.labels.filter { $0.reference != source }, entries: value.entries)
    }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let sourceMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .source(resolution.source),
      closedFamilyId: nil)
    let newMarkers =
      [sourceMarker]
      + resolution.associations.map { association in
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .labelAssociation(id: association.id, lifetimeId: association.lifetimeId),
          closedFamilyId: nil)
      }
    let markers = try deletionMarkers(context) + newMarkers
    let owners = resolution.associations.map(\.ownerReference)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.source(source)]
        + resolution.associations.map { .reference($0.reference) }
        + owners.map { .source($0) })
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: resolution.bindings)
    for marker in newMarkers { context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
    for association in resolution.records {
      association.itemOwner?.updatedAt = updatedAt
      association.itineraryOwner?.updatedAt = updatedAt
      context.delete(association)
    }
    resolution.record.delete(context: context)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete deletion was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func executeBulkCompletion(
    _ operation: PlannerOperation, scope: PlannerBulkScope, done: Bool,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      guard
        receipt.payloadDigest
          == bulkCompletionDigest(
            scope: scope, done: done, identity: identity, bindings: stored.bindings)
      else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation describes another bulk action.")
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
    guard let token = operation.reviewToken else {
      throw PlannerFailure(
        "staleReview", "Review the full contextual target set before applying.",
        propertyPath: "/reviewToken", details: .staleReview)
    }
    guard let review = reviews[token.reviewId], review.session == operation.session else {
      throw PlannerFailure(
        "staleReview", "This review does not belong to the current dataset session.",
        details: .staleReview)
    }
    let resolution = try resolveBulkCompletion(scope, context: context)
    let bindings = resolution.bindings
    let digest = bulkCompletionDigest(
      scope: scope, done: done, identity: identity, bindings: bindings)
    guard digest == review.payloadDigest else {
      throw PlannerFailure(
        "staleReview", "The command or full target set changed; review it again.",
        details: .staleReview)
    }
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another bulk action.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let changed = resolution.targets.contains { $0.localDone != done }
    let lists = try listSnapshots(context).map { value in
      guard resolution.list != nil, value.id == resolution.owner.id else { return value }
      return ListSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: changed ? Date() : value.updatedAt, content: value.content,
        archived: value.archived)
    }
    let itineraries = try itinerarySnapshots(context).map { value in
      guard resolution.itinerary != nil, value.id == resolution.owner.id else { return value }
      return resolution.itineraryAfter(
        value, done: done, updatedAt: changed ? Date() : value.updatedAt)
    }
    let memberships = resolution.membershipsAfter(try membershipSnapshots(context), done: done)
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() }
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.source(resolution.reference)]
        + resolution.targets.map { .reference($0.reference) })
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    for target in resolution.targets { target.apply(done: done, context: context) }
    if let list = resolution.list,
      let snapshot = lists.first(where: { $0.id == resolution.owner.id })
    {
      list.updatedAt = snapshot.updatedAt
    }
    if let itinerary = resolution.itinerary,
      let snapshot = itineraries.first(where: { $0.id == resolution.owner.id })
    {
      itinerary.updatedAt = snapshot.updatedAt
    }
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete bulk action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        receipts: receipts + [receipt])
      return .init(
        operationId: operation.operationId,
        outcome: .applied(result: result, recovery: .complete(checkpointGeneration: generation)))
    } catch {
      return .init(
        operationId: operation.operationId,
        outcome: .applied(
          result: result, recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
    }
  }

  private func executeMembershipCompletion(
    _ operation: PlannerOperation, appearance: PlannerAppearance, done: Bool,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      let digest = appearanceCompletionDigest(
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
    case .expandedListItem(let itineraryId, let listEntryId, let membershipId):
      return try executeExpandedCompletion(
        operation, appearance: appearance, itineraryId: itineraryId,
        listEntryId: listEntryId, membershipId: membershipId, done: done, identity: identity,
        context: context, archive: archive, receipts: receipts)
    case .directItineraryItem(let itineraryId, let entryId):
      return try executeDirectItineraryCompletion(
        operation, appearance: appearance, itineraryId: itineraryId,
        entryId: entryId, done: done, identity: identity, context: context, archive: archive,
        receipts: receipts)
    case .listMembership(let ownerIdentifier, let associationIdentifier):
      listId = ownerIdentifier
      membershipId = associationIdentifier
    }
    var descriptor = FetchDescriptor<PlannerSchemaV14.Membership>(
      predicate: #Predicate { $0.id == membershipId && $0.listId == listId })
    descriptor.fetchLimit = 2
    let selected = try context.fetch(descriptor)
    guard selected.count == 1, let record = selected.first else {
      throw PlannerFailure(
        "missingReference", "The selected List appearance is missing or unresolved.")
    }
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV14.List>())
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
    let digest = appearanceCompletionDigest(
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
          itineraries: try itinerarySnapshots(context),
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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

  private func appearanceCompletionDigest(
    appearance: PlannerAppearance, done: Bool, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    let appearanceValue: PlannerCanonicalValue
    switch appearance {
    case .expandedListItem(let itineraryId, let listEntryId, let membershipId):
      appearanceValue = .record([
        "kind": .string("expandedListItem"), "itineraryId": .identity(itineraryId),
        "listEntryId": .identity(listEntryId), "membershipId": .identity(membershipId),
      ])
    case .directItineraryItem(let itineraryId, let entryId):
      appearanceValue = .record([
        "kind": .string("directItineraryItem"), "itineraryId": .identity(itineraryId),
        "entryId": .identity(entryId),
      ])
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
    var assignments = FetchDescriptor<PlannerSchemaV14.Schedule>(
      predicate: #Predicate { $0.id == scheduleId })
    assignments.fetchLimit = 2
    let records = try context.fetch(assignments)
    guard records.count == 1, let record = records.first,
      let ownerIdentifier = record.sourceId, let ownerLifetime = record.sourceLifetimeId
    else {
      throw PlannerFailure("missingReference", "The selected Schedule is missing or unresolved.")
    }
    guard let ownerKind = PlannerEntityKind(rawValue: record.sourceKind) else {
      throw PlannerFailure("readUnavailable", "The Schedule has an unsupported source kind.")
    }
    let owner = PlannerEntityReference(kind: ownerKind, id: ownerIdentifier)
    let ownerBinding = try resolveScheduleOwner(owner, context: context).binding
    guard ownerBinding.lifetimeId == ownerLifetime else {
      throw PlannerFailure("missingReference", "The Schedule's source lifetime no longer resolves.")
    }
    let before = try record.value(
      ownerId: ownerIdentifier, ownerLifetimeId: ownerLifetime, ownerKind: ownerBinding.kind)
    let bindings = [
      PlannerBoundIdentity(kind: "schedule", id: before.id, lifetimeId: before.lifetimeId),
      ownerBinding,
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
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { item in
      var snapshot = try item.value()
      if ownerKind == .item && item.id == ownerIdentifier {
        snapshot.schedules = snapshot.schedules.compactMap { schedule in
          if schedule.id == scheduleId { return after }
          return schedule
        }
      }
      return snapshot
    }
    let itineraries = try itinerarySnapshots(context).map { itinerary in
      var snapshot = itinerary
      if ownerKind == .itinerary && itinerary.id == ownerIdentifier {
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
        owner,
      ])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(),
        originalOperationId: operation.operationId, datasetId: identity.datasetId,
        ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries,
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
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
        itineraries: itineraries,
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
    guard source.kind == .item || source.kind == .itinerary else {
      throw PlannerFailure(
        "invalidInput", "Schedules can belong to an Item or Itinerary.",
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
    let owner = try resolveScheduleOwner(source, context: context, sourcePath: "/command/source")
    let bindings = [try owner.binding]
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
    var snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map {
      try $0.value()
    }
    var itineraries = try itinerarySnapshots(context)
    switch owner {
    case .item:
      guard let index = snapshots.firstIndex(where: { $0.id == source.id }) else {
        throw PlannerFailure("missingReference", "The Schedule's Item snapshot is missing.")
      }
      snapshots[index].schedules.append(assignment)
    case .itinerary:
      guard let index = itineraries.firstIndex(where: { $0.id == source.id }) else {
        throw PlannerFailure("missingReference", "The Schedule's Itinerary snapshot is missing.")
      }
      itineraries[index].schedules.append(assignment)
    }
    let result = PlannerAppliedResult(
      generated: [assignment.reference], affected: [source, assignment.reference])
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId,
        ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries,
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
          items: snapshots, lists: try listSnapshots(context),
          memberships: try membershipSnapshots(context),
          deletionMarkers: try deletionMarkers(context)),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    context.insert(try owner.assignment(assignment))
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Schedule was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: itineraries,
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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

  private func executeItineraryEdit(
    _ operation: PlannerOperation, sourceId: UUID, changes: PlannerItineraryChanges,
    hashes: [PlannerItineraryField: PlannerFieldHash], identity: PlannerStoreIdentity,
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
    let itineraries = try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>())
    let matches = itineraries.filter { $0.id == sourceId }
    guard matches.count == 1, let itinerary = matches.first else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let before = try itinerary.value()
    var selectedCategories: [PlannerSchemaV14.Category] = []
    var selectedTags: [PlannerSchemaV14.Tag] = []
    if case .set(let identifiers) = changes.categoryIds {
      selectedCategories = try selectedCategoryRecords(
        identifiers, context: context, propertyPath: "/command/changes/categoryIds")
    }
    if case .set(let identifiers) = changes.tagIds {
      selectedTags = try selectedTagRecords(
        identifiers, context: context, propertyPath: "/command/changes/tagIds")
    }
    let selectedBindings =
      try selectedCategories.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(
          kind: "category", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
      + selectedTags.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(kind: "tag", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
    let bindings =
      [
        PlannerBoundIdentity(kind: "itinerary", id: before.id, lifetimeId: before.lifetimeId)
      ] + (try changes.linkBindings(in: before)) + selectedBindings
      + changes.labelAssociationBindings(in: before)
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
    let fieldHashes = before.fieldHashes(datasetId: identity.datasetId)
    let conflictingFields = changedFields.filter { fieldHashes[$0] != hashes[$0] }
    if !conflictingFields.isEmpty {
      var currentValues: [PlannerItineraryField: PlannerItineraryFieldValue] = [:]
      var currentHashes: [PlannerItineraryField: PlannerFieldHash] = [:]
      for field in conflictingFields {
        guard let hash = fieldHashes[field] else {
          throw PlannerFailure("readUnavailable", "A changed field has no current hash.")
        }
        currentHashes[field] = hash
        currentValues[field] = before.fieldValue(field)
      }
      throw PlannerFailure(
        "staleEdit", "Changed fields differ from the supplied read.",
        details: .staleItineraryEdit(
          conflictingFields: conflictingFields, currentValues: currentValues,
          currentFieldHashes: currentHashes
        ))
    }
    let now = Date()
    let updatedInput = changes.applyingChanges(to: before.input)
    let updatedLocationData = try updatedInput.location.map { try JSONEncoder().encode($0) }
    let updatedColorData = try updatedInput.color.map { try JSONEncoder().encode($0) }
    let updatedLinks = try changes.applyingLinks(to: before)
    let updatedAssociations = changes.applyingLabelAssociations(
      to: before, selectedLabels: selectedBindings)
    let availableMetadata =
      try selectedCategories.map { record in
        let snapshot = try record.value()
        return PlannerLabelRead(
          reference: snapshot.reference, name: snapshot.content.name,
          color: snapshot.content.color, iconName: snapshot.content.iconName)
      }
      + selectedTags.map { record in
        let snapshot = try record.value()
        return PlannerLabelRead(
          reference: snapshot.reference, name: snapshot.content.name,
          color: snapshot.content.color, iconName: snapshot.content.iconName)
      } + before.labels
    let updatedLabels = try updatedAssociations.map { association in
      guard
        let metadata = availableMetadata.first(where: { $0.reference == association.labelReference }
        )
      else { throw PlannerFailure("readUnavailable", "The selected label metadata is unresolved.") }
      return metadata
    }
    let previousIdentifiers = Set(before.labelAssociations.map(\.id))
    let updatedIdentifiers = Set(updatedAssociations.map(\.id))
    let added = updatedAssociations.filter { !previousIdentifiers.contains($0.id) }
    let removed = before.labelAssociations.filter { !updatedIdentifiers.contains($0.id) }
    let removalMarkers = removed.map { association in
      PortableDeletionMarker(
        deletionId: UUID(), operationId: operation.operationId,
        target: .labelAssociation(id: association.id, lifetimeId: association.lifetimeId),
        closedFamilyId: nil)
    }
    let markers = try deletionMarkers(context) + removalMarkers
    let associations =
      try labelAssociationSnapshots(context).filter {
        $0.owner.kind != "itinerary" || $0.owner.id != before.id
          || $0.owner.lifetimeId != before.lifetimeId
      } + updatedAssociations
    let after = ItinerarySnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt, updatedAt: now,
      input: updatedInput, archived: before.archived,
      links: updatedLinks, schedules: before.schedules,
      labelAssociations: updatedAssociations, labels: updatedLabels, entries: before.entries
    )
    let snapshots = try itineraries.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let result = PlannerAppliedResult(
      generatedIdentities: added.map { .reference($0.reference) },
      affectedIdentities: [.source(before.reference)]
        + (removed + added).sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .reference($0.reference)
        })
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: snapshots,
        labelAssociations: associations, tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() },
        lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: markers),
      payloadDigest: digest, evidence: "preparedUnverified"
    )
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    if changedFields.contains(.title) { itinerary.title = updatedInput.title }
    if changedFields.contains(.notes) { itinerary.notes = updatedInput.notes }
    if changedFields.contains(.location) { itinerary.locationData = updatedLocationData }
    if changedFields.contains(.color) { itinerary.colorData = updatedColorData }
    if changedFields.contains(.iconName) { itinerary.iconName = updatedInput.iconName }
    if changedFields.contains(.links) {
      try itinerary.replaceLinks(with: updatedLinks, context: context)
    }
    if !changes.changedLabelKinds.isEmpty {
      try itinerary.replaceLabelAssociations(
        with: updatedAssociations, categories: selectedCategories, tags: selectedTags,
        context: context)
    }
    for marker in removalMarkers { context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
    itinerary.updatedAt = now
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Itinerary edit was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: snapshots,
        labelAssociations: associations, tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() },
        lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: markers,
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
    let matches = items.filter { $0.id == sourceId }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
    }
    let before = try item.value()
    var selectedCategories: [PlannerSchemaV14.Category] = []
    var selectedTags: [PlannerSchemaV14.Tag] = []
    if case .set(let identifiers) = changes.categoryIds {
      selectedCategories = try selectedCategoryRecords(
        identifiers, context: context, propertyPath: "/command/changes/categoryIds")
    }
    if case .set(let identifiers) = changes.tagIds {
      selectedTags = try selectedTagRecords(
        identifiers, context: context, propertyPath: "/command/changes/tagIds")
    }
    let selectedBindings =
      try selectedCategories.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(
          kind: "category", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
      + selectedTags.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(kind: "tag", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
    let bindings =
      [
        PlannerBoundIdentity(kind: "item", id: before.id, lifetimeId: before.lifetimeId)
      ] + (try changes.linkBindings(in: before)) + selectedBindings
      + changes.labelAssociationBindings(in: before)
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
      links: before.links.map(\.read), labelAssociations: before.labelAssociations
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
        if field == .categoryIds { currentValues[field] = .identitySet(before.input.categoryIds) }
        if field == .tagIds { currentValues[field] = .identitySet(before.input.tagIds) }
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
    let updatedAssociations = changes.applyingLabelAssociations(
      to: before, selectedLabels: selectedBindings)
    let availableMetadata =
      try selectedCategories.map { record in
        let snapshot = try record.value()
        return PlannerLabelRead(
          reference: snapshot.reference, name: snapshot.content.name,
          color: snapshot.content.color, iconName: snapshot.content.iconName)
      }
      + selectedTags.map { record in
        let snapshot = try record.value()
        return PlannerLabelRead(
          reference: snapshot.reference, name: snapshot.content.name,
          color: snapshot.content.color, iconName: snapshot.content.iconName)
      } + before.labels
    let updatedLabels = try updatedAssociations.map { association in
      guard
        let metadata = availableMetadata.first(where: { $0.reference == association.labelReference }
        )
      else { throw PlannerFailure("readUnavailable", "The selected label metadata is unresolved.") }
      return metadata
    }
    let previousIdentifiers = Set(before.labelAssociations.map(\.id))
    let updatedIdentifiers = Set(updatedAssociations.map(\.id))
    let added = updatedAssociations.filter { !previousIdentifiers.contains($0.id) }
    let removed = before.labelAssociations.filter { !updatedIdentifiers.contains($0.id) }
    let removalMarkers = removed.map { association in
      PortableDeletionMarker(
        deletionId: UUID(), operationId: operation.operationId,
        target: .labelAssociation(id: association.id, lifetimeId: association.lifetimeId),
        closedFamilyId: nil)
    }
    let markers = try deletionMarkers(context) + removalMarkers
    let associations =
      try labelAssociationSnapshots(context).filter {
        $0.owner.kind != "item" || $0.owner.id != before.id
          || $0.owner.lifetimeId != before.lifetimeId
      } + updatedAssociations
    let after = ItemSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt, updatedAt: now,
      input: updatedInput, globalDone: before.globalDone, archived: before.archived,
      links: updatedLinks, schedules: before.schedules,
      labelAssociations: updatedAssociations, labels: updatedLabels
    )
    let snapshots = try items.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let result = PlannerAppliedResult(
      generatedIdentities: added.map { .reference($0.reference) },
      affectedIdentities: [.source(before.reference)]
        + (removed + added).sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .reference($0.reference)
        })
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: associations, tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: snapshots, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: markers),
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
    if !changes.changedLabelKinds.isEmpty {
      try item.replaceLabelAssociations(
        with: updatedAssociations, categories: selectedCategories, tags: selectedTags,
        context: context)
    }
    for marker in removalMarkers { context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: associations, tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: snapshots, lists: try listSnapshots(context),
        memberships: try membershipSnapshots(context),
        deletionMarkers: markers,
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

  private func executeItineraryArchive(
    _ operation: PlannerOperation, source: PlannerEntityReference, archived: Bool,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let stored = try receipt.evidence()
      let digest = sourceStatePayloadDigest(
        source: source, change: .archive(archived), identity: identity, bindings: stored.bindings)
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
    let itineraries = try context.fetch(FetchDescriptor<PlannerSchemaV14.Itinerary>())
    let matches = itineraries.filter { $0.id == source.id }
    guard matches.count == 1, let itinerary = matches.first else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let before = try itinerary.value()
    let bindings = [
      PlannerBoundIdentity(kind: "itinerary", id: before.id, lifetimeId: before.lifetimeId)
    ]
    let digest = sourceStatePayloadDigest(
      source: source, change: .archive(archived), identity: identity, bindings: bindings)
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
    var updatedAt = before.updatedAt
    if archived != before.archived { updatedAt = Date() }
    let after = ItinerarySnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: updatedAt, input: before.input, archived: archived, links: before.links,
      schedules: before.schedules,
      labelAssociations: before.labelAssociations, labels: before.labels, entries: before.entries)
    let snapshots = try itineraries.map { record in
      if record.id == source.id { return after }
      return try record.value()
    }
    let result = PlannerAppliedResult(generated: [], affected: [source])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: snapshots,
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() },
        lists: try listSnapshots(context), memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context)),
      payloadDigest: digest, evidence: "preparedUnverified")
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    itinerary.archived = archived
    itinerary.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Itinerary archive action was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: snapshots,
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>()).map { try $0.value() },
        lists: try listSnapshots(context), memberships: try membershipSnapshots(context),
        deletionMarkers: try deletionMarkers(context), receipts: receipts + [receipt])
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV14.Item>())
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
      globalDone: globalDone, archived: archived, links: before.links, schedules: before.schedules,
      labelAssociations: before.labelAssociations, labels: before.labels)
    let snapshots = try items.map { record in
      if record.id == source.id { return after }
      return try record.value()
    }
    let result = PlannerAppliedResult(generated: [], affected: [source])
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId,
      datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
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
      identity.schemaVersion == 14
    else {
      throw PlannerFailure("staleDatasetSession", "The dataset session is no longer authorized.")
    }
    return identity
  }

  private func openContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: PlannerSchemaV14.self)
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
        (1...14).contains(identity.schemaVersion), !identity.ownershipBinding.isEmpty
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
