import Foundation
import Observation
import SwiftData

public actor Planner {
  private let configuration: PlannerStorageConfiguration
  private let captureHTTPTransport: any PlannerCaptureHTTPTransport
  private var nativeContainer:
    (container: ModelContainer, fileNumber: UInt64, systemNumber: UInt64)?
  private var sessions: [UUID: PlannerDatasetSession] = [:]
  private struct ChangeSubscription: Sendable {
    let session: PlannerDatasetSession
    let continuation: AsyncThrowingStream<PlannerChange, any Error>.Continuation
    let observation: Task<Void, Never>
    var fileObservations: [PlannerFileObservation]
    var historyToken: DefaultHistoryToken?
    var recovery: PlannerRecoveryObservation
  }
  private var changeSubscriptions: [UUID: ChangeSubscription] = [:]
  private struct QueryBinding {
    let snapshot: PlannerQuerySnapshot
    let historyToken: DefaultHistoryToken?
    var calendarEntries: [PlannerCalendarEntry]? = nil
    var itemQuery: PlannerItemQuery? = nil
    var mapContext: MapQueryContext? = nil
  }
  private enum MapAppearanceKey: Hashable {
    case membership(UUID)
    case entry(UUID)
    case expanded(entryId: UUID, membershipId: UUID)
  }
  private struct MapQueryAppearance {
    let source: PlannerBoundIdentity
    let placement: PlannerMapPlacement
  }
  private struct MapQueryContext {
    var collection: PlannerMapCollection?
    var branches: [PlannerMapListBranch] = []
    var appearances: [MapAppearanceKey: MapQueryAppearance] = [:]
  }
  private var querySnapshots: [UUID: QueryBinding] = [:]
  private struct ReviewBinding {
    let session: PlannerDatasetSession
    let payloadDigest: String
  }
  private var reviews: [UUID: ReviewBinding] = [:]
  private var captureDrafts: [UUID: PlannerPreparedCapture] = [:]
  private var associationUndoSnapshots: [UUID: PlannerAssociationUndoSnapshot] = [:]
  private var captureInputReloads:
    [UUID: (requestId: UUID, task: Task<[PlannerCaptureRetainedInput], Never>)] = [:]
  private var captureLookups:
    [UUID: (requestId: UUID, task: Task<PlannerCapturePreviewCandidate?, Never>)] = [:]
  private var appliedCaptureOperations:
    [UUID: (session: PlannerDatasetSession, generation: UUID, operationId: UUID)] = [:]
  private struct CaptureResolution {
    let draft: PlannerPreparedCapture
    let item: PlannerSchemaV18.Item?
    let lists: [PlannerSchemaV18.List]
    let categories: [PlannerSchemaV18.Category]
    let tags: [PlannerSchemaV18.Tag]
    let bindings: [PlannerBoundIdentity]
    let targets: [PlannerReviewTarget]
    let details: PlannerCaptureReview
  }
  private enum ItemStateChange {
    case archive(Bool)
    case completion(Bool)
  }
  private enum ListChange {
    case content(PlannerListChanges, [PlannerListField: PlannerFieldHash])
    case archive(Bool)
  }

  private enum ScheduleOwner {
    case item(PlannerSchemaV18.Item)
    case itinerary(PlannerSchemaV18.Itinerary)

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

    func assignment(_ snapshot: ScheduleSnapshot) throws -> PlannerSchemaV18.Schedule {
      switch self {
      case .item(let owner): return try .init(snapshot: snapshot, owner: owner)
      case .itinerary(let owner): return try .init(snapshot: snapshot, owner: owner)
      }
    }
  }

  public init(
    configuration: PlannerStorageConfiguration,
    captureHTTPTransport: any PlannerCaptureHTTPTransport = PlannerNativeCaptureHTTPTransport()
  ) {
    self.configuration = configuration
    self.captureHTTPTransport = captureHTTPTransport
  }

  deinit {
    for subscription in changeSubscriptions.values {
      subscription.observation.cancel()
      subscription.continuation.finish()
    }
  }

  public func changes(session: PlannerDatasetSession)
    -> AsyncThrowingStream<PlannerChange, any Error>
  {
    let (stream, continuation) = AsyncThrowingStream<PlannerChange, any Error>.makeStream()
    do {
      let identifier = UUID()
      let (observer, historyToken, fileObservations, recovery) = try coordinated {
        let identity = try validateSession(session)
        let container = try openContainer()
        let observer = try HistoryObserver(modelContainer: container)
        let recovery = readRecoveryObservation(identity)
        let fileObservations = try observeBoundFiles(identity, recovery: recovery, for: identifier)
        return (
          observer, try latestHistoryToken(in: ModelContext(container)), fileObservations,
          recovery
        )
      }
      let observation = Task { [weak self] in
        for await _ in Observations({ observer.eventCounter }) {
          guard !Task.isCancelled else { return }
          await self?.publishObservedChanges(for: identifier)
        }
      }
      changeSubscriptions[identifier] = .init(
        session: session, continuation: continuation, observation: observation,
        fileObservations: fileObservations, historyToken: historyToken, recovery: recovery)
      continuation.onTermination = { [weak self] _ in
        Task { await self?.endChangeSubscription(identifier) }
      }
    } catch {
      continuation.finish(throwing: failure(error, code: "observationUnavailable"))
    }
    return stream
  }

  private func publishObservedChanges(for identifier: UUID) {
    guard var subscription = changeSubscriptions[identifier] else { return }
    do {
      let (historyToken, fileObservations, recovery) = try coordinated {
        let identity = try validateSession(subscription.session)
        let recovery = readRecoveryObservation(identity)
        let fileObservations = try observeBoundFiles(identity, recovery: recovery, for: identifier)
        return (
          try latestHistoryToken(in: ModelContext(try openContainer())),
          fileObservations,
          recovery
        )
      }
      let dataChanged = historyToken != subscription.historyToken
      let recoveryChanged = !recoveryObservationsMatch(recovery, subscription.recovery)
      subscription.historyToken = historyToken
      subscription.fileObservations = fileObservations
      subscription.recovery = recovery
      changeSubscriptions[identifier] = subscription
      if dataChanged {
        subscription.continuation.yield(
          .init(notificationId: UUID(), payload: .dataChanged(affected: nil)))
      }
      if recoveryChanged {
        subscription.continuation.yield(
          .init(notificationId: UUID(), payload: .recoveryStatusChanged(value: recovery)))
      }
    } catch {
      subscription.continuation.finish(throwing: failure(error, code: "observationUnavailable"))
      endChangeSubscription(identifier)
    }
  }

  private func endChangeSubscription(_ identifier: UUID) {
    changeSubscriptions.removeValue(forKey: identifier)?.observation.cancel()
  }

  private func observeBoundFiles(
    _ identity: PlannerStoreIdentity, recovery: PlannerRecoveryObservation, for identifier: UUID
  ) throws
    -> [PlannerFileObservation]
  {
    let directory = recoveryArchive(identity).namespaceURL
    let requiredPaths = [
      configuration.controlURL.deletingLastPathComponent(), configuration.controlURL,
      configuration.storeURL.deletingLastPathComponent(),
      configuration.recoveryDirectoryURL.deletingLastPathComponent(),
    ]
    var observations: [PlannerFileObservation] = []
    for path in requiredPaths {
      observations.append(try observeBoundFile(path, for: identifier))
    }
    // Recovery can be temporarily unavailable; its parent still observes replacement and repair.
    do {
      for path in [configuration.recoveryDirectoryURL, directory] {
        observations.append(try observeBoundFile(path, for: identifier))
      }
      let checkpoints = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
      ).filter { $0.lastPathComponent.hasPrefix("checkpoint-") && $0.pathExtension == "json" }
      for checkpoint in checkpoints {
        observations.append(try observeBoundFile(checkpoint, for: identifier))
      }
    } catch {
      guard case .unavailable = recovery else { throw error }
    }
    return observations
  }

  private func observeBoundFile(_ url: URL, for identifier: UUID) throws
    -> PlannerFileObservation
  {
    try PlannerFileObservation(url: url) { [weak self] in
      Task { await self?.publishObservedChanges(for: identifier) }
    }
  }

  private func recoveryObservationsMatch(
    _ first: PlannerRecoveryObservation, _ second: PlannerRecoveryObservation
  ) -> Bool {
    switch (first, second) {
    case (
      .known(let firstGeneration, let firstIncomplete, let firstMaintenance, let firstBlocked),
      .known(let secondGeneration, let secondIncomplete, let secondMaintenance, let secondBlocked)
    ):
      return firstGeneration == secondGeneration && firstIncomplete == secondIncomplete
        && firstMaintenance == secondMaintenance && firstBlocked == secondBlocked
    case (.unavailable(let firstFailure), .unavailable(let secondFailure)):
      return firstFailure == secondFailure
    default: return false
    }
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
          guard (1...19).contains(identity.schemaVersion) else {
            throw PlannerFailure(
              "unsupportedVersion", "The dataset uses an unsupported storage schema.")
          }
          if identity.schemaVersion < 19, configuration.processRole == .shareExtension {
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
          let container = try openContainer(initializing: true)
          let context = ModelContext(container)
          context.autosaveEnabled = false
          try context.save()
          identity = PlannerStoreIdentity(
            schemaVersion: 19, datasetId: UUID(), epochId: UUID(), namespaceId: UUID(),
            ownershipBinding: "local:" + UUID().uuidString
          )
          try plannerWriteDurably(JSONEncoder().encode(identity), to: configuration.controlURL)
        }
        _ = try openContainer()
        if identity.schemaVersion < 19 {
          identity = PlannerStoreIdentity(
            schemaVersion: 19, datasetId: identity.datasetId, epochId: identity.epochId,
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
        let maintenanceContext = ModelContext(try openContainer())
        maintenanceContext.autosaveEnabled = false
        do {
          try ensureCanonicalMemberships(identity: identity, context: maintenanceContext)
        } catch let reason as PlannerFailure where reason.code == "maintenanceRequired" {
          guard case .known(_, _, _, true) = readRecoveryObservation(identity) else { throw reason }
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

  public func prepareCapture(session: PlannerDatasetSession, input: PlannerCaptureInput)
    -> PlannerCaptureDraftResult
  {
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        try ensureCanonicalMemberships(identity: identity, context: context)
        let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
          try $0.value()
        }
        let preparation: PlannerCapturePreparation
        switch input {
        case .direct(let inputs):
          preparation = try plannerPrepareDirectCapture(inputs, items: items)
        case .loaded(let inputs):
          preparation = try plannerPrepareCaptureInputs(inputs.inputs, items: items)
        }
        let draft = preparation.read
        captureDrafts[draft.draftId] = .init(
          session: session, read: draft, contentOrigins: preparation.contentOrigins,
          retainedInputs: preparation.retainedInputs, overrides: .init())
        return .draft(draft)
      }
    } catch {
      return .rejected(failure(error, code: "captureInputFailure"))
    }
  }

  public func updateCapture(
    session: PlannerDatasetSession, draftId: UUID, generation: UUID, edit: PlannerCaptureEdit
  ) async -> PlannerCaptureDraftResult {
    do {
      let initial = try coordinated {
        let draft = try preparedCapture(session: session, draftId: draftId)
        guard draft.read.generation == generation else {
          throw PlannerFailure(
            "captureDraftUnavailable", "The capture draft changed; read it before continuing.")
        }
        let proposed = try plannerEditCapture(draft, edit: edit, items: [])
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        _ = try selectedCategoryRecords(
          proposed.read.content.categoryIds, context: context, propertyPath: "/changes/categoryIds")
        _ = try selectedTagRecords(
          proposed.read.content.tagIds, context: context, propertyPath: "/changes/tagIds")
        guard !Task.isCancelled else {
          throw PlannerFailure("captureDraftUnavailable", "The capture edit was cancelled.")
        }
        cancelCaptureLookup(draftId: draftId)
        captureInputReloads.removeValue(forKey: draftId)?.task.cancel()
        return draft
      }
      let nativeInputs = initial.retainedInputs.filter {
        edit.retryInputIndexes.contains($0.inputIndex) && $0.nativeRepresentation != nil
      }
      var requestId: UUID?
      var reloaded: [PlannerCaptureRetainedInput] = []
      defer {
        if let requestId, captureInputReloads[draftId]?.requestId == requestId {
          captureInputReloads.removeValue(forKey: draftId)?.task.cancel()
        }
      }
      if !nativeInputs.isEmpty {
        let identifier = UUID()
        requestId = identifier
        let reservedBytes = initial.retainedInputs.reduce(0) { total, input in
          guard !edit.retryInputIndexes.contains(input.inputIndex),
            !edit.removeInputIndexes.contains(input.inputIndex)
          else { return total }
          return total + input.decodedByteCount
        }
        let availableBytes = PlannerCaptureLimits.maximumDecodedBytes - reservedBytes
        let loading = Task {
          await PlannerNativeCaptureLoader.reload(
            inputs: nativeInputs, maximumDecodedBytes: availableBytes)
        }
        captureInputReloads[draftId] = (identifier, loading)
        reloaded = await withTaskCancellationHandler(
          operation: { await loading.value }, onCancel: { loading.cancel() })
      }
      return try coordinated {
        let current = try preparedCapture(session: session, draftId: draftId)
        guard current.read.generation == generation, !Task.isCancelled,
          requestId == nil || captureInputReloads[draftId]?.requestId == requestId
        else {
          throw PlannerFailure(
            "captureDraftUnavailable", "The capture draft changed; read it before continuing.")
        }
        let replacements = Dictionary(uniqueKeysWithValues: reloaded.map { ($0.inputIndex, $0) })
        let draft = PlannerPreparedCapture(
          session: current.session, read: current.read, contentOrigins: current.contentOrigins,
          retainedInputs: current.retainedInputs.map { replacements[$0.inputIndex] ?? $0 },
          overrides: current.overrides)
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
          try $0.value()
        }
        let updated = try plannerEditCapture(draft, edit: edit, items: items)
        _ = try selectedCategoryRecords(
          updated.read.content.categoryIds, context: context, propertyPath: "/changes/categoryIds")
        _ = try selectedTagRecords(
          updated.read.content.tagIds, context: context, propertyPath: "/changes/tagIds")
        cancelCaptureLookup(draftId: draftId)
        captureDrafts[draftId] = updated
        return .draft(updated.read)
      }
    } catch {
      let reason = failure(error, code: "captureDraftUnavailable")
      guard let path = reason.propertyPath, path.hasPrefix("/command/changes") else {
        return .rejected(reason)
      }
      return .rejected(
        .init(
          reason.code, reason.message, propertyPath: String(path.dropFirst("/command".count)),
          details: reason.details))
    }
  }

  public func readCapture(session: PlannerDatasetSession, draftId: UUID)
    -> PlannerCaptureDraftResult
  {
    do {
      return try coordinated {
        .draft(try preparedCapture(session: session, draftId: draftId).read)
      }
    } catch {
      return .rejected(failure(error, code: "captureDraftUnavailable"))
    }
  }

  public func lookupCapture(
    session: PlannerDatasetSession, draftId: UUID, generation: UUID, linkId: UUID
  ) async -> PlannerCaptureDraftResult {
    let requestIdentifier = UUID()
    defer {
      if captureLookups[draftId]?.requestId == requestIdentifier {
        cancelCaptureLookup(draftId: draftId)
      }
    }
    do {
      let lookup = try coordinated {
        let draft = try preparedCapture(session: session, draftId: draftId)
        guard draft.read.generation == generation, !Task.isCancelled else {
          throw PlannerFailure(
            "captureDraftUnavailable", "The capture draft changed; read it before continuing.")
        }
        guard let link = draft.read.links.first(where: { $0.linkId == linkId }),
          link.kind == .appleMaps || link.kind == .googleMaps
        else {
          throw PlannerFailure(
            "invalidInput", "Choose a Maps link from this capture before lookup.",
            propertyPath: "/linkId")
        }
        cancelCaptureLookup(draftId: draftId)
        captureDrafts[draftId] = draft.replacingPreview(
          .init(state: .loading, linkId: linkId, candidate: nil))
        let lookup = Task {
          await plannerLookupCapturePlace(link.originalUrl, transport: captureHTTPTransport)
        }
        captureLookups[draftId] = (requestIdentifier, lookup)
        return lookup
      }
      let candidate = await withTaskCancellationHandler(
        operation: { await lookup.value }, onCancel: { lookup.cancel() })
      return try coordinated {
        let draft = try preparedCapture(session: session, draftId: draftId)
        guard draft.read.generation == generation, !Task.isCancelled,
          captureLookups[draftId]?.requestId == requestIdentifier
        else {
          throw PlannerFailure(
            "captureDraftUnavailable", "The capture draft changed; read it before continuing.")
        }
        let state: PlannerCapturePreview.State = candidate == nil ? .unavailable : .available
        let observed = draft.replacingPreview(
          .init(state: state, linkId: linkId, candidate: candidate))
        captureDrafts[draftId] = observed
        return .draft(observed.read)
      }
    } catch {
      return .rejected(failure(error, code: "captureDraftUnavailable"))
    }
  }

  private func cancelCaptureLookup(draftId: UUID) {
    guard let lookup = captureLookups.removeValue(forKey: draftId) else { return }
    lookup.task.cancel()
    guard let draft = captureDrafts[draftId], draft.read.preview.state == .loading else { return }
    captureDrafts[draftId] = draft.replacingPreview(
      .init(state: .unavailable, linkId: draft.read.preview.linkId, candidate: nil))
  }

  public func cancelCapture(session: PlannerDatasetSession, draftId: UUID, generation: UUID)
    -> PlannerCaptureCancelResult
  {
    do {
      return try coordinated {
        if let applied = appliedCaptureOperations[draftId] {
          _ = try validateSession(session)
          guard applied.session.datasetId == session.datasetId,
            applied.session.ownershipBinding == session.ownershipBinding,
            applied.session.epochId == session.epochId, applied.generation == generation
          else {
            throw PlannerFailure(
              "captureDraftUnavailable", "This applied capture belongs to another review.")
          }
          return .notCancellable(operationId: applied.operationId)
        }
        let draft = try preparedCapture(session: session, draftId: draftId)
        guard draft.read.generation == generation else {
          throw PlannerFailure(
            "captureDraftUnavailable", "The capture draft changed; read it before continuing.")
        }
        cancelCaptureLookup(draftId: draftId)
        captureInputReloads.removeValue(forKey: draftId)?.task.cancel()
        captureDrafts.removeValue(forKey: draftId)
        return .cancelled
      }
    } catch {
      return .rejected(failure(error, code: "captureDraftUnavailable"))
    }
  }

  private func preparedCapture(session: PlannerDatasetSession, draftId: UUID) throws
    -> PlannerPreparedCapture
  {
    _ = try validateSession(session)
    guard let draft = captureDrafts[draftId], draft.session.datasetId == session.datasetId,
      draft.session.ownershipBinding == session.ownershipBinding,
      draft.session.epochId == session.epochId
    else {
      throw PlannerFailure("captureDraftUnavailable", "The capture draft is no longer available.")
    }
    return draft
  }

  private func resolveCapture(
    session: PlannerDatasetSession, draftId: UUID, draftGeneration: UUID,
    choice: PlannerCaptureChoice, listIds: Set<UUID>, context: ModelContext
  ) throws -> CaptureResolution {
    let draft = try preparedCapture(session: session, draftId: draftId)
    guard draft.read.generation == draftGeneration else {
      throw PlannerFailure(
        "staleReview", "The capture draft changed; review it again.", details: .staleReview)
    }
    guard draft.read.saveAllowed else {
      throw PlannerFailure(
        "invalidInput", "Resolve the capture's blocking input or content issues before Add.")
    }
    try draft.read.content.validate()
    let availableLists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
    let lists = try listIds.sorted { $0.uuidString < $1.uuidString }.map { identifier in
      let matches = availableLists.filter { $0.id == identifier }
      guard matches.count == 1, let list = matches.first, !list.archived else {
        throw PlannerFailure(
          "staleReview", "A selected List is unavailable or archived; choose again.",
          propertyPath: "/command/listIds", details: .staleReview)
      }
      return list
    }
    var item: PlannerSchemaV18.Item?
    var categories: [PlannerSchemaV18.Category] = []
    var tags: [PlannerSchemaV18.Tag] = []
    var missingLinks = draft.read.links
    var missingListIds = listIds
    switch choice {
    case .createNew:
      categories = try selectedCategoryRecords(draft.read.content.categoryIds, context: context)
      tags = try selectedTagRecords(draft.read.content.tagIds, context: context)
    case .reuse(let itemId):
      let matches = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter {
        $0.id == itemId
      }
      guard matches.count == 1, let selected = matches.first else {
        throw PlannerFailure(
          "staleReview", "The selected Item is unavailable; choose again.", details: .staleReview)
      }
      let source = try selected.value()
      let originals = Set(source.links.map(\.originalUrl))
      guard draft.read.links.contains(where: { originals.contains($0.originalUrl) }) else {
        throw PlannerFailure(
          "staleReview", "The selected Item no longer matches a captured original link.",
          details: .staleReview)
      }
      item = selected
      missingLinks = draft.read.links.filter { !originals.contains($0.originalUrl) }
      let existingLists = Set(
        try membershipSnapshots(context).filter {
          $0.item.id == source.id && $0.item.lifetimeId == source.lifetimeId
        }.map { $0.list.id })
      missingListIds.subtract(existingLists)
    }
    var bindings =
      try lists.map { record in
        let value = try record.value()
        return PlannerBoundIdentity(kind: "list", id: value.id, lifetimeId: value.lifetimeId)
      }
      + categories.map { record in
        let value = try record.value()
        return PlannerBoundIdentity(kind: "category", id: value.id, lifetimeId: value.lifetimeId)
      }
      + tags.map { record in
        let value = try record.value()
        return PlannerBoundIdentity(kind: "tag", id: value.id, lifetimeId: value.lifetimeId)
      }
    var targets: [PlannerReviewTarget] = try lists.map { .source(try $0.value().reference) }
    var createContent: PlannerItemContentInput? = draft.read.content
    if let item {
      let source = try item.value()
      bindings.append(.init(kind: "item", id: source.id, lifetimeId: source.lifetimeId))
      bindings += source.links.map {
        .init(kind: "ownedLink", id: $0.id, lifetimeId: $0.lifetimeId)
      }
      let existing = try membershipSnapshots(context).filter {
        $0.item.id == source.id && $0.item.lifetimeId == source.lifetimeId
          && listIds.contains($0.list.id)
      }
      bindings += existing.map { .init(kind: "membership", id: $0.id, lifetimeId: $0.lifetimeId) }
      targets.append(.source(source.reference))
      targets += existing.map { .reference($0.reference) }
      createContent = nil
    }
    return .init(
      draft: draft, item: item, lists: lists, categories: categories, tags: tags,
      bindings: bindings, targets: targets,
      details: .init(
        createContent: createContent, missingLinks: missingLinks,
        missingListIds: missingListIds))
  }

  private func executeCapture(
    _ operation: PlannerOperation, draftId: UUID, draftGeneration: UUID,
    choice: PlannerCaptureChoice, listIds: Set<UUID>, identity: PlannerStoreIdentity,
    context: ModelContext, archive: PlannerRecoveryArchive, receipts: [PlannerSchemaV1.Receipt],
    envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let evidence = try receipt.evidence()
      let digest = plannerCaptureOperationDigest(
        draftId: draftId, draftGeneration: draftGeneration, choice: choice, listIds: listIds,
        identity: identity, bindings: evidence.bindings,
        membershipEvidence: evidence.resolvedMembershipEvidence)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation describes another capture.")
      }
      return appliedResult(
        operationId: operation.operationId,
        evidence: try RecoveryReceipt(receipt, checkpoint: nil), envelope: envelope)
    }
    let prepared = try archive.proposals().first { $0.originalOperationId == operation.operationId }
    if let prepared, let bindings = prepared.resolvedBindings,
      let membershipEvidence = prepared.resolvedMembershipEvidence
    {
      let digest = plannerCaptureOperationDigest(
        draftId: draftId, draftGeneration: draftGeneration, choice: choice, listIds: listIds,
        identity: identity, bindings: bindings, membershipEvidence: membershipEvidence)
      guard prepared.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another capture.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(prepared.summary))
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
        "staleReview", "Review the capture in the current dataset session.",
        propertyPath: "/reviewToken", details: .staleReview)
    }
    let resolution = try resolveCapture(
      session: operation.session, draftId: draftId,
      draftGeneration: draftGeneration, choice: choice,
      listIds: listIds, context: context)
    let reviewOperationDigest = plannerCaptureOperationDigest(
      draftId: draftId, draftGeneration: draftGeneration, choice: choice, listIds: listIds,
      identity: identity, bindings: resolution.bindings)
    let reviewDigest = plannerCaptureReviewDigest(
      operationDigest: reviewOperationDigest, source: try resolution.item?.value())
    guard reviewDigest == review.payloadDigest else {
      throw PlannerFailure(
        "staleReview", "The capture or selected identities changed; review again.",
        details: .staleReview)
    }
    if let proposal = prepared {
      guard proposal.payloadDigest == reviewOperationDigest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another capture.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let item: PlannerSchemaV18.Item
    let snapshot: ItemSnapshot
    if let existing = resolution.item {
      item = existing
      let before = try existing.value()
      var links = before.links
      if !resolution.details.missingLinks.isEmpty {
        links = before.links.enumerated().map { index, link in
          .init(
            id: link.id, lifetimeId: link.lifetimeId, rank: Int64(index),
            originalUrl: link.originalUrl, label: link.label, kind: link.kind,
            providerReference: link.providerReference)
        }
      }
      for link in resolution.details.missingLinks {
        let identifier = UUID()
        links.append(
          .init(
            id: identifier, lifetimeId: identifier, rank: Int64(links.count),
            originalUrl: link.originalUrl, label: link.label, kind: link.kind,
            providerReference: link.providerReference))
      }
      var updatedAt = before.updatedAt
      if !resolution.details.missingLinks.isEmpty { updatedAt = Date() }
      snapshot = .init(
        id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
        updatedAt: updatedAt, input: before.input, globalDone: before.globalDone,
        archived: before.archived, links: links, schedules: before.schedules,
        labelAssociations: before.labelAssociations, labels: before.labels,
        contentOrigins: before.contentOrigins)
    } else {
      item = try PlannerSchemaV18.Item(input: resolution.draft.read.content)
      item.applyContentOrigins(resolution.draft.contentOrigins)
      item.labelAssociations =
        resolution.categories.map {
          PlannerSchemaV18.LabelAssociation(item: item, category: $0)
        } + resolution.tags.map { PlannerSchemaV18.LabelAssociation(item: item, tag: $0) }
      snapshot = try item.value()
    }
    let itemBinding = PlannerBoundIdentity(
      kind: "item", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
    var memberships = try membershipSnapshots(context)
    var added: [MembershipSnapshot] = []
    for list in resolution.lists {
      let owner = try list.value()
      guard resolution.details.missingListIds.contains(owner.id) else { continue }
      let ordered = memberships.filter { $0.list.id == owner.id }.sorted {
        if $0.rank != $1.rank { return $0.rank < $1.rank }
        return $0.id.uuidString < $1.id.uuidString
      }
      let rank = try associationInsertionRank(
        at: ordered.count, ordered: ordered, associations: &memberships)
      let identifier = UUID()
      let membership = MembershipSnapshot(
        id: identifier, lifetimeId: identifier,
        list: .init(kind: "list", id: owner.id, lifetimeId: owner.lifetimeId),
        item: itemBinding, rank: rank, localDone: false)
      added.append(membership)
      memberships.append(membership)
    }
    let markers = try deletionMarkers(context)
    var membershipEvidence: [PlannerPortableMembershipProvenance]?
    if !listIds.isEmpty {
      let lineage = try PlannerNativeLineage(context: context)
      let addedIdentifiers = Set(added.map(\.id))
      let selectedMemberships = memberships.filter {
        $0.item.id == snapshot.id && $0.item.lifetimeId == snapshot.lifetimeId
          && listIds.contains($0.list.id)
      }
      let resolved = try selectedMemberships.map { membership in
        if addedIdentifiers.contains(membership.id) {
          return try lineage.provenanceForNewMembership(membership, markers: markers)
        }
        return lineage.membershipProvenance.first {
          $0.membershipId == membership.id && $0.membershipLifetimeId == membership.lifetimeId
        } ?? membership.baselineProvenance
      }
      membershipEvidence = plannerSortedMembershipEvidence(resolved)
      try plannerStageMembershipProvenance(
        resolved.filter {
          addedIdentifiers.contains($0.membershipId) && !$0.observedRemovalIds.isEmpty
        },
        context: context)
    }
    let digest = plannerCaptureOperationDigest(
      draftId: draftId, draftGeneration: draftGeneration, choice: choice, listIds: listIds,
      identity: identity, bindings: resolution.bindings, membershipEvidence: membershipEvidence)
    let updatedAt = Date()
    let lists = try listSnapshots(context).map { value in
      guard resolution.details.missingListIds.contains(value.id) else { return value }
      return ListSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: updatedAt, content: value.content, archived: value.archived,
        contentOrigins: value.contentOrigins)
    }
    let items =
      try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter { $0.id != snapshot.id }
      .map { try $0.value() } + [snapshot]
    let associations =
      try labelAssociationSnapshots(context).filter {
        $0.owner.kind != "item" || $0.owner.id != snapshot.id
      } + snapshot.labelAssociations
    let itineraries = try itinerarySnapshots(context)
    let categories = try categorySnapshots(context)
    let tags = try tagSnapshots(context)
    var generatedIdentities = added.map { PlannerAppliedIdentity.reference($0.reference) }
    if resolution.item == nil {
      generatedIdentities =
        [.source(snapshot.reference)]
        + snapshot.labelAssociations.map { .reference($0.reference) } + generatedIdentities
    }
    let result = PlannerAppliedResult(
      generatedIdentities: generatedIdentities,
      affectedIdentities: [.source(snapshot.reference)]
        + generatedIdentities.filter {
          if case .source = $0 { return false }
          return true
        }
        + (try resolution.lists.filter {
          $0.id.map { resolution.details.missingListIds.contains($0) } ?? false
        }.map { .source(try $0.value().reference) }))
    let proposalIdentifier = UUID()
    try archive.prepare(
      .init(
        proposalId: proposalIdentifier, originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries,
          labelAssociations: associations, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified",
        resolvedBindings: membershipEvidence.map { _ in resolution.bindings },
        resolvedMembershipEvidence: membershipEvidence))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result,
      bindings: resolution.bindings)
    if let membershipEvidence {
      receipt.resultData = try JSONEncoder().encode(
        PlannerStoredOperationEvidence(
          result: result, bindings: resolution.bindings,
          resolvedMembershipEvidence: membershipEvidence))
    }
    if resolution.item == nil {
      context.insert(item)
      for association in item.labelAssociations ?? [] { context.insert(association) }
    } else if !resolution.details.missingLinks.isEmpty {
      item.replaceLinks(with: snapshot.links, context: context)
      item.updatedAt = snapshot.updatedAt
    }
    for list in resolution.lists {
      guard let membership = added.first(where: { $0.list.id == list.id }) else { continue }
      context.insert(PlannerSchemaV18.Membership(snapshot: membership, list: list, item: item))
      list.updatedAt = updatedAt
    }
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for record in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
      if let identifier = record.id, let rank = ranks[identifier], record.rank != rank {
        record.rank = rank
      }
    }
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      do { try archive.discardPreparedProposal(proposalIdentifier) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The capture save failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
      throw PlannerFailure(
        "persistenceFailure",
        "The complete capture was not committed: \(error.localizedDescription)")
    }
    appliedCaptureOperations[draftId] = (operation.session, draftGeneration, operation.operationId)
    cancelCaptureLookup(draftId: draftId)
    captureInputReloads.removeValue(forKey: draftId)?.task.cancel()
    captureDrafts.removeValue(forKey: draftId)
    do {
      let generation = try archive.publish(
        itineraries: itineraries, labelAssociations: associations,
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

  private func resolveItemCreation(
    content: PlannerItemContentInput, listId: UUID?, context: ModelContext
  ) throws -> (
    destination: PlannerSchemaV18.List?, categories: [PlannerSchemaV18.Category],
    tags: [PlannerSchemaV18.Tag], bindings: [PlannerBoundIdentity]
  ) {
    let categories = try selectedCategoryRecords(content.categoryIds, context: context)
    let tags = try selectedTagRecords(content.tagIds, context: context)
    var bindings =
      try categories.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(
          kind: "category", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
      + tags.map { record in
        let snapshot = try record.value()
        return PlannerBoundIdentity(kind: "tag", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
      }
    guard let listId else { return (nil, categories, tags, bindings) }
    var descriptor = FetchDescriptor<PlannerSchemaV18.List>(
      predicate: #Predicate { $0.id == listId })
    descriptor.fetchLimit = 2
    let matches = try context.fetch(descriptor)
    guard matches.count == 1, let destination = matches.first, !destination.archived else {
      throw PlannerFailure(
        "missingReference", "The destination List is unavailable or archived.",
        propertyPath: "/command/listId")
    }
    let owner = try destination.value()
    bindings.append(.init(kind: "list", id: owner.id, lifetimeId: owner.lifetimeId))
    return (destination, categories, tags, bindings)
  }

  private func itemCreationReviewDigest(
    operationDigest: String, destination: ListSnapshot, identity: PlannerStoreIdentity
  ) throws -> String {
    guard let nameHash = destination.fieldHashes(datasetId: identity.datasetId)[.name] else {
      throw PlannerFailure("readUnavailable", "The destination List's name binding is unresolved.")
    }
    let value = PlannerCanonicalValue.record([
      "operationDigest": .string(operationDigest), "destinationNameHash": .string(nameHash.value),
    ])
    return plannerDigest(value.encoded(), prefix: "sha256-item-creation-review-v1:")
  }

  public func prepareReview(session: PlannerDatasetSession, command: PlannerCommand)
    -> PlannerReviewResult
  {
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        try ensureCanonicalMemberships(identity: identity, context: context)
        let targets: [PlannerReviewTarget]
        let impact: PlannerReviewImpact
        let digest: String
        switch command {
        case .createItem(let content, let listId?):
          try content.validate()
          let selection = try resolveItemCreation(
            content: content, listId: listId, context: context)
          guard let destination = selection.destination else {
            throw PlannerFailure("missingReference", "The destination List is unavailable.")
          }
          let owner = try destination.value()
          targets = [.source(owner.reference)]
          impact = .init(
            kind: .itemCreation, targetCount: 1, globalFlagsChanged: false,
            sourceDeletes: [], referenceRemovals: [])
          digest = try itemCreationReviewDigest(
            operationDigest: content.payloadDigest(
              datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
              bindings: selection.bindings, listId: listId), destination: owner, identity: identity)
        case .applyCapture(let draftId, let draftGeneration, let choice, let listIds):
          let resolution = try resolveCapture(
            session: session, draftId: draftId, draftGeneration: draftGeneration,
            choice: choice, listIds: listIds, context: context)
          targets = resolution.targets
          impact = .init(
            kind: .capture, targetCount: Int64(targets.count), globalFlagsChanged: false,
            sourceDeletes: [], referenceRemovals: [], captureDetails: resolution.details)
          let operationDigest = plannerCaptureOperationDigest(
            draftId: draftId, draftGeneration: draftGeneration, choice: choice, listIds: listIds,
            identity: identity, bindings: resolution.bindings)
          digest = plannerCaptureReviewDigest(
            operationDigest: operationDigest, source: try resolution.item?.value())
        case .applyImport, .restoreRecovery:
          let request = try PlannerImportRequest(command: command)
          let backup = request.backup
          let mode = request.mode
          let restoreDeletedData = request.restoreDeletedData
          guard !restoreDeletedData || mode == .overwrite else {
            throw PlannerFailure("invalidInput", "Restoration requires explicit Overwrite.")
          }
          let current = try importReviewSnapshot(context)
          let deletionImpacts = try importDeletionImpacts(
            incoming: backup, current: current, mode: mode, context: context)
          let resolution = try plannerResolveImportReview(
            incoming: backup, current: current, mode: mode, deletionImpacts: deletionImpacts)
          targets = resolution.targets
          impact = .init(
            kind: .importData, targetCount: Int64(targets.count),
            globalFlagsChanged: resolution.globalFlagsChanged,
            sourceDeletes: resolution.sourceDeletes,
            referenceRemovals: resolution.details.referenceChanges.filter { $0.change == .remove }
              .map(\.reference),
            importDetails: resolution.details)
          digest = plannerImportDigest(
            incoming: backup, current: current, mode: mode, identity: identity,
            restoreDeletedData: restoreDeletedData, recoverySelection: request.recoverySelection)
        case .setBulkCompletion(let scope, let done):
          let resolution = try resolveBulkCompletion(scope, context: context)
          targets = resolution.targets.map { .appearance($0.appearance) }
          impact = .init(
            kind: .bulkCompletion, targetCount: Int64(targets.count), globalFlagsChanged: false,
            sourceDeletes: [], referenceRemovals: [])
          digest = bulkCompletionDigest(
            scope: scope, done: done, identity: identity, bindings: resolution.bindings)
        case .deleteSource(let source):
          if source.kind == .itinerary {
            let resolution = try resolveItineraryDeletion(source, context: context)
            targets = [.source(source)] + resolution.removals.map { .reference($0) }
            impact = .init(
              kind: .deleteSource, targetCount: Int64(targets.count), globalFlagsChanged: false,
              sourceDeletes: resolution.sourceDeletes, referenceRemovals: resolution.removals)
            digest = sourceDeletionDigest(
              source: source, identity: identity, bindings: resolution.bindings,
              removals: resolution.removals)
          } else if source.kind == .list {
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
      let result: PlannerOperationResult = try coordinated {
        let identity = try validateSession(operation.session)
        let container = try openContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let archive = recoveryArchive(identity, context: context)
        var receipts = try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>())
        var envelope = try archive.latest()
        let hasAppliedHistory =
          receipts.contains { $0.operationId == operation.operationId }
          || (envelope?.receipts.contains { $0.operationId == operation.operationId } ?? false)
        if !hasAppliedHistory {
          let prepared = try archive.proposals().contains {
            $0.originalOperationId == operation.operationId
          }
          if !prepared {
            try ensureCanonicalMemberships(identity: identity, context: context)
            envelope = try archive.latest()
            guard try archive.incompleteMaintenance(in: context, envelope: envelope).isEmpty else {
              throw PlannerFailure(
                "mutationBlocked", "Committed maintenance still needs independent recovery.")
            }
          }
          receipts = try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>())
        }
        switch operation.command {
        case .restoreAssociation(let snapshot):
          return try executeAssociationRestoration(
            operation, snapshot: snapshot, identity: identity, context: context,
            archive: archive, receipts: receipts, envelope: envelope)
        case .applyCapture(let draftId, let draftGeneration, let choice, let listIds):
          return try executeCapture(
            operation, draftId: draftId, draftGeneration: draftGeneration, choice: choice,
            listIds: listIds, identity: identity, context: context, archive: archive,
            receipts: receipts, envelope: envelope)
        case .applyImport, .restoreRecovery:
          let request = try PlannerImportRequest(command: operation.command)
          if let selection = request.recoverySelection,
            selection.evidence == .preparedUnverified,
            selection.originalOperationId == operation.operationId
          {
            throw PlannerFailure(
              "invalidInput", "An unverified recovery proposal requires a new operation identity.",
              propertyPath: "/operationId")
          }
          return try executeImport(
            operation, request: request,
            identity: identity, context: context,
            archive: archive, receipts: receipts, envelope: envelope)
        case .deleteSource(let source):
          if source.kind == .itinerary {
            return try executeItineraryDeletion(
              operation, source: source, identity: identity, context: context, archive: archive,
              receipts: receipts, envelope: envelope)
          }
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
        case .createItem(let content, let listId):
          try content.validate()
          if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
            let stored = try receipt.evidence()
            let digest = content.payloadDigest(
              datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
              bindings: stored.bindings, listId: listId)
            guard receipt.payloadDigest == digest else {
              throw PlannerFailure(
                "operationPayloadMismatch",
                "This operation identity already describes different content.")
            }
            let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
            return appliedResult(
              operationId: operation.operationId, evidence: evidence, envelope: envelope)
          }
          let selection = try resolveItemCreation(
            content: content, listId: listId, context: context)
          let destination = selection.destination
          let selectedCategories = selection.categories
          let selectedTags = selection.tags
          let bindings = selection.bindings
          let digest = content.payloadDigest(
            datasetId: identity.datasetId,
            ownershipBinding: identity.ownershipBinding, bindings: bindings, listId: listId)
          let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
          guard
            receipts.allSatisfy({ receipt in
              receipt.operationId.map { completedIds.contains($0) } ?? false
            })
          else {
            throw PlannerFailure(
              "mutationBlocked", "A prior applied action still needs independent recovery.")
          }
          if let token = operation.reviewToken {
            guard let destination, let review = reviews[token.reviewId],
              review.session == operation.session,
              try review.payloadDigest
                == itemCreationReviewDigest(
                  operationDigest: digest, destination: destination.value(), identity: identity)
            else {
              throw PlannerFailure(
                "staleReview", "The destination or content changed; review creation again.",
                propertyPath: "/reviewToken", details: .staleReview)
            }
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
          let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
            try $0.value()
          }
          let existingAssociations = try labelAssociationSnapshots(context)
          let item = try PlannerSchemaV18.Item(input: content)
          item.labelAssociations =
            selectedCategories.map {
              PlannerSchemaV18.LabelAssociation(item: item, category: $0)
            } + selectedTags.map { PlannerSchemaV18.LabelAssociation(item: item, tag: $0) }
          let snapshot = try item.value()
          var memberships = try membershipSnapshots(context)
          var addedMembership: MembershipSnapshot?
          if let destination {
            let owner = try destination.value()
            let ordered = memberships.filter { $0.list.id == owner.id }.sorted {
              if $0.rank != $1.rank { return $0.rank < $1.rank }
              return $0.id.uuidString < $1.id.uuidString
            }
            let rank = try associationInsertionRank(
              at: ordered.count, ordered: ordered, associations: &memberships)
            let identifier = UUID()
            let membership = MembershipSnapshot(
              id: identifier, lifetimeId: identifier,
              list: .init(kind: "list", id: owner.id, lifetimeId: owner.lifetimeId),
              item: .init(kind: "item", id: snapshot.id, lifetimeId: snapshot.lifetimeId),
              rank: rank, localDone: false)
            addedMembership = membership
            memberships.append(membership)
          }
          let updatedAt = Date()
          let lists = try listSnapshots(context).map { owner in
            guard owner.id == listId else { return owner }
            return ListSnapshot(
              id: owner.id, lifetimeId: owner.lifetimeId, createdAt: owner.createdAt,
              updatedAt: updatedAt, content: owner.content, archived: owner.archived,
              contentOrigins: owner.contentOrigins)
          }
          var generatedReferences = snapshot.labelAssociations.sorted {
            $0.id.uuidString < $1.id.uuidString
          }.map { PlannerAppliedIdentity.reference($0.reference) }
          if let addedMembership {
            generatedReferences.append(.reference(addedMembership.reference))
          }
          var affectedIdentities: [PlannerAppliedIdentity] =
            [.source(snapshot.reference)] + generatedReferences
          if let listId { affectedIdentities.append(.source(.init(kind: .list, id: listId))) }
          let result = PlannerAppliedResult(
            generatedIdentities: [.source(snapshot.reference)] + generatedReferences,
            affectedIdentities: affectedIdentities)
          let membershipRecords: [PlannerSchemaV18.Membership]
          if destination != nil {
            membershipRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
          } else {
            membershipRecords = []
          }
          let receipt = try PlannerSchemaV1.Receipt(
            operation: operation, digest: digest, result: result, bindings: bindings)
          let proposal = RecoveryPreparedProposal(
            proposalId: UUID(), originalOperationId: operation.operationId,
            datasetId: identity.datasetId,
            ownershipBinding: identity.ownershipBinding,
            proposedBackup: PlannerDataSnapshot(
              itineraries: try itinerarySnapshots(context),
              labelAssociations: existingAssociations + snapshot.labelAssociations,
              tags: try tagSnapshots(context), categories: try categorySnapshots(context),
              items: existingItems + [snapshot], lists: lists, memberships: memberships,
              deletionMarkers: try deletionMarkers(context)),
            payloadDigest: digest, evidence: "preparedUnverified"
          )
          try archive.prepare(proposal)
          context.insert(item)
          for association in item.labelAssociations ?? [] { context.insert(association) }
          if let destination, let addedMembership {
            context.insert(
              PlannerSchemaV18.Membership(snapshot: addedMembership, list: destination, item: item))
            destination.updatedAt = updatedAt
            let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
            for record in membershipRecords {
              if let identifier = record.id, let rank = ranks[identifier], record.rank != rank {
                record.rank = rank
              }
            }
          }
          context.insert(receipt)
          do { try context.save() } catch {
            context.rollback()
            do { try archive.discardPreparedProposal(proposal.proposalId) } catch {
              throw PlannerFailure(
                "persistenceFailure",
                "The Item save failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
              )
            }
            throw PlannerFailure(
              "persistenceFailure",
              "The complete Item action was not committed: \(error.localizedDescription)")
          }
          do {
            let generation = try archive.publish(
              itineraries: try itinerarySnapshots(context),
              labelAssociations: existingAssociations + snapshot.labelAssociations,
              tags: try tagSnapshots(context), categories: try categorySnapshots(context),
              items: existingItems + [snapshot], lists: lists, memberships: memberships,
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
      guard case .applied = result.outcome,
        let snapshot = associationUndoSnapshots[result.operationId]
      else { return result }
      return .init(
        operationId: result.operationId, outcome: result.outcome,
        associationUndoSnapshot: snapshot)
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
        switch request {
        case .status: break
        default:
          let maintenanceContext = ModelContext(try openContainer())
          maintenanceContext.autosaveEnabled = false
          try ensureCanonicalMemberships(identity: identity, context: maintenanceContext)
        }
        switch request {
        case .status:
          return .status(
            PlannerNativeStatusRead(
              recovery: readRecoveryObservation(identity), account: .unknown,
              cloud: PlannerCloudObservation(
                state: .unknown, storeIdentity: nil, eventId: nil, observedAt: nil, reason: nil)))
        case .appearance(let appearance):
          let context = ModelContext(try openContainer())
          context.autosaveEnabled = false
          return .appearance(
            try readAppearance(appearance, datasetId: identity.datasetId, context: context))
        case .rows(let generation, let offset, let limit):
          let context = ModelContext(try openContainer())
          context.autosaveEnabled = false
          return .rows(
            try readRows(
              session: session, context: context, generation: generation, offset: offset,
              limit: limit))
        case .calendarRows(let generation, let offset, let limit):
          let context = ModelContext(try openContainer())
          context.autosaveEnabled = false
          return .calendarRows(
            try readCalendarRows(
              session: session, context: context, generation: generation, offset: offset,
              limit: limit))
        case .mapRows(let generation, let offset, let limit):
          let context = ModelContext(try openContainer())
          context.autosaveEnabled = false
          return .mapRows(
            try readMapRows(
              session: session, context: context, generation: generation, offset: offset,
              limit: limit))
        case .source(let source):
          let context = ModelContext(try openContainer())
          context.autosaveEnabled = false
          if source.kind == .itinerary {
            let identifier = source.id
            var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
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
                  items: itemEstimateSnapshots(context), lists: listEstimateSnapshots(context))))
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
            var descriptor = FetchDescriptor<PlannerSchemaV18.List>(
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
                  items: itemEstimateSnapshots(context), entries: itineraryEntrySnapshots(context)))
            )
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
          let sourceIdentifier = source.id
          var descriptor = FetchDescriptor<PlannerSchemaV18.Item>(
            predicate: #Predicate { $0.id == sourceIdentifier })
          descriptor.fetchLimit = 2
          let items = try context.fetch(descriptor)
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

  private func readRecoveryObservation(_ identity: PlannerStoreIdentity)
    -> PlannerRecoveryObservation
  {
    do {
      guard FileManager.default.fileExists(atPath: configuration.storeURL.path) else {
        throw PlannerFailure("readUnavailable", "The committed dataset store is unavailable.")
      }
      let context = ModelContext(try openContainer())
      context.autosaveEnabled = false
      let memberships = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
      let archive = recoveryArchive(identity)
      let envelope = try archive.latest()
      let acknowledged = Dictionary(
        uniqueKeysWithValues: (envelope?.receipts ?? []).map { ($0.operationId, $0) })
      let committed = try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>()).map {
        try RecoveryReceipt($0, checkpoint: nil)
      }
      guard Set(committed.map(\.operationId)).count == committed.count,
        committed.allSatisfy({
          $0.datasetId == identity.datasetId && $0.ownershipBinding == identity.ownershipBinding
        })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "Committed recovery evidence is inconsistent.")
      }
      var incomplete: [UUID] = []
      for receipt in committed {
        guard let recovered = acknowledged[receipt.operationId] else {
          incomplete.append(receipt.operationId)
          continue
        }
        guard recovered.payloadDigest == receipt.payloadDigest, recovered.result == receipt.result
        else {
          throw PlannerFailure(
            "recoveryIntegrityFailure", "Acknowledged operation evidence does not match its commit."
          )
        }
      }
      let maintenance = try archive.incompleteMaintenance(in: context, envelope: envelope)
      if try membershipConsolidationRequired(memberships, context: context) {
        guard !incomplete.isEmpty || !maintenance.isEmpty else {
          throw PlannerFailure(
            "maintenanceRequired", "Membership consolidation has not committed yet.")
        }
        _ = try canonicalRecoverySnapshot(context)
      }
      return .known(
        checkpointGeneration: (envelope?.checkpointGeneration).flatMap(Int64.init),
        incompleteOperationIds: incomplete.sorted { $0.uuidString < $1.uuidString },
        incompleteMaintenanceIds: maintenance,
        mutationBlocked: !incomplete.isEmpty || !maintenance.isEmpty)
    } catch { return .unavailable(failure(error, code: "readUnavailable")) }
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
      let membership = try resolveMembership(
        listId: listId, membershipId: membershipId, context: context)
      let binding = try membership.value()
      let itemId = binding.item.id
      var itemDescriptor = FetchDescriptor<PlannerSchemaV18.Item>(
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
    var descriptor = FetchDescriptor<PlannerSchemaV18.Schedule>(
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

  private func resolvedSchedule(_ record: PlannerSchemaV18.Schedule, context: ModelContext) throws
    -> (snapshot: ScheduleSnapshot, source: PlannerEntityReference, owner: ScheduleOwner)
  {
    guard let ownerIdentifier = record.sourceId, record.sourceLifetimeId != nil else {
      throw PlannerFailure("readUnavailable", "The Schedule's source binding is unresolved.")
    }
    guard let ownerKind = PlannerEntityKind(rawValue: record.sourceKind) else {
      throw PlannerFailure("readUnavailable", "The Schedule has an unsupported source kind.")
    }
    let owner = PlannerEntityReference(kind: ownerKind, id: ownerIdentifier)
    let resolvedOwner = try resolveScheduleOwner(owner, context: context)
    return try resolvedSchedule(record, owner: resolvedOwner)
  }

  private func resolvedSchedule(_ record: PlannerSchemaV18.Schedule, owner: ScheduleOwner) throws
    -> (snapshot: ScheduleSnapshot, source: PlannerEntityReference, owner: ScheduleOwner)
  {
    let binding = try owner.binding
    let source = PlannerEntityReference(
      kind: try scheduleOwnerKind(record), id: binding.id)
    guard record.sourceId == binding.id, let ownerLifetime = record.sourceLifetimeId else {
      throw PlannerFailure("readUnavailable", "The Schedule's source binding is unresolved.")
    }
    guard binding.lifetimeId == ownerLifetime else {
      throw PlannerFailure("readUnavailable", "The Schedule's source lifetime no longer resolves.")
    }
    let snapshot = try record.value(
      ownerId: binding.id, ownerLifetimeId: ownerLifetime, ownerKind: binding.kind)
    return (snapshot, source, owner)
  }

  private func scheduleOwnerKind(_ record: PlannerSchemaV18.Schedule) throws -> PlannerEntityKind {
    guard let kind = PlannerEntityKind(rawValue: record.sourceKind) else {
      throw PlannerFailure("readUnavailable", "The Schedule has an unsupported source kind.")
    }
    guard kind == .item || kind == .itinerary else {
      throw PlannerFailure(
        "invalidInput", "Schedules can belong to an Item or Itinerary.",
        propertyPath: "/command/source/kind")
    }
    return kind
  }

  private func resolveScheduleOwner(
    _ source: PlannerEntityReference, context: ModelContext, sourcePath: String? = nil
  ) throws -> ScheduleOwner {
    let identifier = source.id
    switch source.kind {
    case .item:
      var descriptor = FetchDescriptor<PlannerSchemaV18.Item>(
        predicate: #Predicate { $0.id == identifier })
      descriptor.fetchLimit = 2
      let records = try context.fetch(descriptor)
      if records.count == 1, let owner = records.first { return .item(owner) }
    case .itinerary:
      var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
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
        let identity = try validateSession(query.session)
        let container = try openContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        try ensureCanonicalMemberships(identity: identity, context: context)
        switch query.request {
        case .calendar(let calendarQuery):
          let historyToken = try latestHistoryToken(in: context)
          let entries = try calendarEntries(query: calendarQuery, context: context)
          guard try latestHistoryToken(in: context) == historyToken else {
            throw PlannerFailure(
              "readUnavailable", "The store changed while building this Calendar.")
          }
          querySnapshots = querySnapshots.filter { $0.value.historyToken == historyToken }
          if let retained = querySnapshots.values.first(where: {
            $0.snapshot.session == query.session && $0.calendarEntries == entries
          }) {
            return .snapshot(retained.snapshot)
          }
          let snapshot = PlannerQuerySnapshot(
            session: query.session, generation: UUID(),
            rows: entries.map { .source($0.schedule) }, matchingCount: Int64(entries.count),
            rowPresentation: nil, progress: [], unresolvedReferences: [])
          querySnapshots[snapshot.generation] = QueryBinding(
            snapshot: snapshot, historyToken: historyToken, calendarEntries: entries)
          return .snapshot(snapshot)
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
              snapshot: snapshot, historyToken: historyToken, itemQuery: itemQuery)
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
              snapshot: snapshot, historyToken: historyToken, itemQuery: itemQuery)
            return .snapshot(snapshot)
          }
          let textTerms = itemQuery.text.split(whereSeparator: \.isWhitespace).map(String.init)
          let locale = Locale(identifier: "en_US_POSIX")
          var descriptor = FetchDescriptor<PlannerSchemaV18.Item>()
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
            snapshot: snapshot, historyToken: historyToken, itemQuery: itemQuery)
          return .snapshot(snapshot)
        }
      }
    } catch { return .failed(failure(error, code: "readUnavailable")) }
  }

  private func matchesItemText(
    _ item: PlannerSchemaV18.Item, terms: [String], locale: Locale
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

  private func matchesItemPresence(_ item: PlannerSchemaV18.Item, query: PlannerItemQuery) throws
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
    _ item: PlannerSchemaV18.Item, duration: PlannerItemQuery.Duration?
  ) throws -> Bool {
    guard let duration, duration.minimumMinutes != nil || duration.maximumMinutes != nil else {
      return true
    }
    guard let estimate = try item.value().input.estimate else { return duration.includeUnknown }
    if let minimum = duration.minimumMinutes, estimate.minutes < minimum { return false }
    if let maximum = duration.maximumMinutes, estimate.minutes > maximum { return false }
    return true
  }

  private func matchesItemLabels(_ item: PlannerSchemaV18.Item, query: PlannerItemQuery) throws
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
    _ item: PlannerSchemaV18.Item, mode: PlannerItemQuery.Sort.Mode
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

  private struct CatalogSortValue {
    let source: PlannerEntityReference
    let comparisonName: String
    let comparisonDate: Date?
  }

  private func sortedCatalogIdentities(
    _ values: [CatalogSortValue], sort: PlannerCatalogQuery.Sort?, context: ModelContext
  ) throws -> [PlannerRowIdentity] {
    let estimateKeys: [UUID: CatalogEstimateSortKey]
    if sort?.mode == .fullEstimate {
      estimateKeys = try catalogEstimateSortKeys(sources: values.map(\.source), context: context)
    } else {
      estimateKeys = [:]
    }
    let comparator = String.Comparator(
      options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    let descendingTitle = sort?.mode == .title && sort?.direction == .descending
    let sorted = try values.sorted { first, second in
      if let firstDate = first.comparisonDate, let secondDate = second.comparisonDate,
        firstDate != secondDate
      {
        if sort?.direction == .descending { return firstDate > secondDate }
        return firstDate < secondDate
      }
      if sort?.mode == .fullEstimate,
        let precedes = try catalogEstimatePrecedes(
          estimateKeys[first.source.id], estimateKeys[second.source.id],
          direction: sort?.direction ?? .ascending)
      {
        return precedes
      }
      let comparison = comparator.compare(first.comparisonName, second.comparisonName)
      if comparison != .orderedSame {
        return comparison == (descendingTitle ? .orderedDescending : .orderedAscending)
      }
      return first.source.id.uuidString < second.source.id.uuidString
    }
    return sorted.map { .source($0.source) }
  }

  private func requiredCatalogSortDate(_ date: Date?) throws -> Date {
    guard let date, date.timeIntervalSinceReferenceDate.isFinite else {
      throw PlannerFailure("readUnavailable", "A catalog source has an unresolved sort timestamp.")
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
    if query.sort != nil, query.sourceKind != .list, query.sourceKind != .itinerary {
      throw PlannerFailure(
        "invalidInput", "Only List and Itinerary catalogs support sorting.",
        propertyPath: "/query/sort")
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
    var descriptor = FetchDescriptor<PlannerSchemaV18.List>()
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.name, \.archived]
    if query.sort?.mode == .created || query.sort?.mode == .lastUpdated {
      descriptor.propertiesToFetch += [\.createdAt, \.updatedAt]
    }
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
    let values = try matches.map { list -> CatalogSortValue in
      guard let identifier = list.id, list.lifetimeId != nil,
        !list.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PlannerFailure("readUnavailable", "A catalog List has unresolved identity or name.")
      }
      let comparisonDate: Date?
      if query.sort?.mode == .created {
        comparisonDate = try requiredCatalogSortDate(list.createdAt)
      } else if query.sort?.mode == .lastUpdated {
        comparisonDate = try requiredCatalogSortDate(list.updatedAt)
      } else {
        comparisonDate = nil
      }
      return CatalogSortValue(
        source: PlannerEntityReference(kind: .list, id: identifier),
        comparisonName: list.name.folding(
          options: [.caseInsensitive, .diacriticInsensitive], locale: locale),
        comparisonDate: comparisonDate
      )
    }
    guard Set(values.map { $0.source.id }).count == values.count else {
      throw PlannerFailure(
        "readUnavailable", "Catalog List identities are duplicated and unresolved.")
    }
    let rows = try sortedCatalogIdentities(values, sort: query.sort, context: context)
    return PlannerQuerySnapshot(
      session: session, generation: UUID(), rows: rows,
      matchingCount: Int64(rows.count), rowPresentation: nil,
      progress: [], unresolvedReferences: [])
  }

  private func itineraryCatalogSnapshot(
    session: PlannerDatasetSession, query: PlannerCatalogQuery, context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>()
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.title, \.archived]
    if query.sort?.mode == .created || query.sort?.mode == .lastUpdated {
      descriptor.propertiesToFetch += [\.createdAt, \.updatedAt]
    }
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
    let values = try matches.map { itinerary -> CatalogSortValue in
      guard let identifier = itinerary.id, itinerary.lifetimeId != nil,
        !itinerary.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PlannerFailure(
          "readUnavailable", "A catalog Itinerary has unresolved identity or title.")
      }
      let comparisonDate: Date?
      if query.sort?.mode == .created {
        comparisonDate = try requiredCatalogSortDate(itinerary.createdAt)
      } else if query.sort?.mode == .lastUpdated {
        comparisonDate = try requiredCatalogSortDate(itinerary.updatedAt)
      } else {
        comparisonDate = nil
      }
      return CatalogSortValue(
        source: PlannerEntityReference(kind: .itinerary, id: identifier),
        comparisonName: itinerary.title.folding(
          options: [.caseInsensitive, .diacriticInsensitive], locale: locale),
        comparisonDate: comparisonDate
      )
    }
    guard Set(values.map { $0.source.id }).count == values.count else {
      throw PlannerFailure(
        "readUnavailable", "Catalog Itinerary identities are duplicated and unresolved.")
    }
    let rows = try sortedCatalogIdentities(values, sort: query.sort, context: context)
    return PlannerQuerySnapshot(
      session: session, generation: UUID(), rows: rows,
      matchingCount: Int64(rows.count), rowPresentation: nil,
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
    let sources = try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()).map {
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
    var lists = FetchDescriptor<PlannerSchemaV18.List>(
      predicate: #Predicate { $0.id == listId })
    lists.fetchLimit = 2
    lists.propertiesToFetch = [\.id, \.lifetimeId]
    let owners = try context.fetch(lists)
    guard owners.count == 1, let owner = owners.first, let lifetimeId = owner.lifetimeId else {
      throw PlannerFailure("missingReference", "The selected List is missing or unresolved.")
    }
    let memberships = FetchDescriptor<PlannerSchemaV18.Membership>(
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
        localDone: $0.localDone, branchArchived: false)
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
    var itineraries = FetchDescriptor<PlannerSchemaV18.Itinerary>(
      predicate: #Predicate { $0.id == itineraryId })
    itineraries.fetchLimit = 2
    itineraries.propertiesToFetch = [\.id, \.lifetimeId]
    let owners = try context.fetch(itineraries)
    guard owners.count == 1, let owner = owners.first, let lifetimeId = owner.lifetimeId else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let descriptor = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>(
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
            localDone: entry.localDone == true, branchArchived: false))
        continue
      }
      let listId = entry.source.id
      let listLifetimeId = entry.source.lifetimeId
      var lists = FetchDescriptor<PlannerSchemaV18.List>(
        predicate: #Predicate { $0.id == listId && $0.lifetimeId == listLifetimeId })
      lists.fetchLimit = 2
      lists.propertiesToFetch = [\.id, \.lifetimeId, \.archived]
      let matchingLists = try context.fetch(lists)
      guard matchingLists.count == 1, let list = matchingLists.first else {
        throw PlannerFailure("readUnavailable", "An itinerary List entry is unresolved.")
      }
      let memberships = FetchDescriptor<PlannerSchemaV18.Membership>(
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
            localDone: localDone, branchArchived: list.archived))
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
    let branchArchived: Bool
  }

  private func contextualItemQuerySnapshot(
    session: PlannerDatasetSession, container: PlannerEntityReference,
    appearances: [ContextualQueryAppearance], query: PlannerItemQuery,
    presentation: PlannerRowPresentationContext, membershipListsByItem: [UUID: Set<UUID>],
    context: ModelContext
  ) throws -> PlannerQuerySnapshot {
    let itemIdentifiers = appearances.map { Optional($0.item.id) }
    let textTerms = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
    var items = FetchDescriptor<PlannerSchemaV18.Item>(
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
    var archivedCount: Int64 = 0
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
      if effectiveDone {
        doneCount += 1
      } else if item.archived || appearance.branchArchived {
        archivedCount += 1
      }
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
    } else if doneCount + archivedCount == totalCount {
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
          doneCount: doneCount, totalCount: totalCount, archivedCount: archivedCount)
      ], unresolvedReferences: [])
  }

  private struct CatalogEstimateSortKey {
    let certaintyRank: Int
    let minutes: Int64
  }

  private func catalogEstimatePrecedes(
    _ first: CatalogEstimateSortKey?, _ second: CatalogEstimateSortKey?,
    direction: PlannerCatalogQuery.Sort.Direction
  ) throws -> Bool? {
    guard let first, let second else {
      throw PlannerFailure("readUnavailable", "A catalog full-estimate key is unresolved.")
    }
    if first.certaintyRank != second.certaintyRank {
      return first.certaintyRank < second.certaintyRank
    }
    guard first.minutes != second.minutes else { return nil }
    if direction == .ascending { return first.minutes < second.minutes }
    return first.minutes > second.minutes
  }

  private func catalogEstimateSortKeys(
    sources: [PlannerEntityReference], context: ModelContext
  ) throws -> [UUID: CatalogEstimateSortKey] {
    let graph = try catalogEstimateGraph(
      identities: sources.map(PlannerRowIdentity.source), context: context)
    let listIdentifiers = Set(sources.filter { $0.kind == .list }.map(\.id))
    var totals: [UUID: PlannerDurationTotal] = [:]
    for list in graph.lists where listIdentifiers.contains(list.id) {
      totals[list.id] = try list.progressAndEstimates(
        memberships: graph.memberships, items: graph.items
      ).estimates.fullEstimate
    }
    let itineraryIdentifiers = sources.filter { $0.kind == .itinerary }.map(\.id)
    if !itineraryIdentifiers.isEmpty {
      let optionalIdentifiers = itineraryIdentifiers.map(Optional.some)
      var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
        predicate: #Predicate { optionalIdentifiers.contains($0.id) })
      descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.archived, \.manualEstimateData]
      for itinerary in try context.fetch(descriptor) {
        let snapshot = try itinerary.estimateSnapshot(entries: graph.entries)
        let total = try snapshot.progressAndEstimates(
          memberships: graph.memberships, items: graph.items, lists: graph.lists
        ).estimates.fullEstimate
        guard totals.updateValue(total, forKey: snapshot.reference.id) == nil else {
          throw PlannerFailure(
            "readUnavailable", "Catalog full-estimate identities are duplicated.")
        }
      }
    }
    guard Set(totals.keys) == Set(sources.map(\.id)) else {
      throw PlannerFailure("readUnavailable", "A catalog full estimate is unresolved.")
    }
    return try totals.mapValues { total in
      switch total {
      case .exact(let minutes): return .init(certaintyRank: 0, minutes: minutes)
      case .lowerBound(let minutes, _): return .init(certaintyRank: 1, minutes: minutes)
      case .unavailable: return .init(certaintyRank: 2, minutes: 0)
      case .upperBound:
        throw PlannerFailure("readUnavailable", "A full estimate has an invalid upper bound.")
      }
    }
  }

  private struct CatalogEstimateGraph {
    let memberships: [MembershipSnapshot]
    let items: [ContainerEstimateItemSnapshot]
    let lists: [ContainerEstimateListSnapshot]
    let entries: [ItineraryEntrySnapshot]
  }

  private func catalogEstimateGraph(
    identities: [PlannerRowIdentity], context: ModelContext
  ) throws -> CatalogEstimateGraph {
    let sources = identities.compactMap { identity -> PlannerEntityReference? in
      guard case .source(let source) = identity else { return nil }
      return source
    }
    let itineraryIdentifiers = sources.filter { $0.kind == .itinerary }.map(\.id)
    var listIdentifiers = sources.filter { $0.kind == .list }.map(\.id)
    guard !itineraryIdentifiers.isEmpty || !listIdentifiers.isEmpty else {
      return .init(memberships: [], items: [], lists: [], entries: [])
    }
    let entries: [ItineraryEntrySnapshot]
    if itineraryIdentifiers.isEmpty {
      entries = []
    } else {
      entries = try itineraryEntrySnapshots(context, itineraryIdentifiers: itineraryIdentifiers)
    }
    listIdentifiers += entries.filter { $0.source.kind == "list" }.map { $0.source.id }
    let memberships = try membershipSnapshots(context, listIdentifiers: listIdentifiers)
    let itemIdentifiers =
      memberships.map { $0.item.id }
      + entries.filter { $0.source.kind == "item" }.map { $0.source.id }
    return .init(
      memberships: memberships,
      items: try itemEstimateSnapshots(context, itemIdentifiers: itemIdentifiers),
      lists: try listEstimateSnapshots(context, listIdentifiers: listIdentifiers), entries: entries)
  }

  private func calendarEntries(query: PlannerCalendarQuery, context: ModelContext) throws
    -> [PlannerCalendarEntry]
  {
    let interval = try query.interval()
    let schedules = try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>())
    let owners = try calendarOwners(schedules: schedules, context: context)
    var entries: [PlannerCalendarEntry] = []
    var scheduleIdentifiers: Set<UUID> = []
    for record in schedules {
      guard let ownerIdentifier = record.sourceId else {
        throw PlannerFailure("readUnavailable", "The Schedule's source binding is unresolved.")
      }
      let source = PlannerEntityReference(kind: try scheduleOwnerKind(record), id: ownerIdentifier)
      guard let owner = owners[source] else {
        throw PlannerFailure("missingReference", "The Schedule's source is missing or unresolved.")
      }
      let resolved = try resolvedSchedule(record, owner: owner)
      guard scheduleIdentifiers.insert(resolved.snapshot.id).inserted else {
        throw PlannerFailure("readUnavailable", "Calendar Schedule identities are duplicated.")
      }
      let matches: Bool
      switch resolved.snapshot.form {
      case .timed(let start, let end, _):
        if let end {
          matches = start < interval.end && end > interval.start
        } else {
          matches = start >= interval.start && start < interval.end
        }
      case .allDay(let start, let end):
        matches =
          !query.endDay.isEarlier(than: start)
          && !(end ?? start).isEarlier(than: query.startDay)
      }
      guard matches else { continue }
      let title: String
      switch resolved.owner {
      case .item(let owner): title = owner.title
      case .itinerary(let owner): title = owner.title
      }
      guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PlannerFailure("readUnavailable", "The Schedule owner has an unresolved title.")
      }
      entries.append(
        PlannerCalendarEntry(
          schedule: resolved.snapshot.reference, source: resolved.source, title: title,
          form: resolved.snapshot.form))
    }
    return entries.sorted { $0.schedule.id.uuidString < $1.schedule.id.uuidString }
  }

  private func calendarOwners(
    schedules: [PlannerSchemaV18.Schedule], context: ModelContext
  ) throws -> [PlannerEntityReference: ScheduleOwner] {
    var itemIdentifiers: Set<UUID?> = []
    var itineraryIdentifiers: Set<UUID?> = []
    for schedule in schedules {
      guard let identifier = schedule.sourceId, schedule.sourceLifetimeId != nil else {
        throw PlannerFailure("readUnavailable", "The Schedule's source binding is unresolved.")
      }
      switch try scheduleOwnerKind(schedule) {
      case .item: itemIdentifiers.insert(identifier)
      case .itinerary: itineraryIdentifiers.insert(identifier)
      default: break
      }
    }
    let itemValues = Array(itemIdentifiers)
    let itineraryValues = Array(itineraryIdentifiers)
    var owners: [PlannerEntityReference: ScheduleOwner] = [:]
    if !itemIdentifiers.isEmpty {
      var descriptor = FetchDescriptor<PlannerSchemaV18.Item>(
        predicate: #Predicate { itemValues.contains($0.id) })
      descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.title]
      let records = Dictionary(grouping: try context.fetch(descriptor), by: \.id)
      for (identifier, matches) in records {
        guard let identifier, matches.count == 1, let owner = matches.first else {
          throw PlannerFailure(
            "missingReference", "The Schedule's source is missing or unresolved.")
        }
        owners[.init(kind: .item, id: identifier)] = .item(owner)
      }
    }
    if !itineraryIdentifiers.isEmpty {
      var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
        predicate: #Predicate { itineraryValues.contains($0.id) })
      descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.title]
      let records = Dictionary(grouping: try context.fetch(descriptor), by: \.id)
      for (identifier, matches) in records {
        guard let identifier, matches.count == 1, let owner = matches.first else {
          throw PlannerFailure(
            "missingReference", "The Schedule's source is missing or unresolved.")
        }
        owners[.init(kind: .itinerary, id: identifier)] = .itinerary(owner)
      }
    }
    return owners
  }

  private func readCalendarRows(
    session: PlannerDatasetSession, context: ModelContext, generation: UUID, offset: Int64,
    limit: Int64
  ) throws -> PlannerCalendarRowWindow {
    guard offset >= 0, limit > 0 else {
      throw PlannerFailure("invalidInput", "Row offset must be nonnegative and limit positive.")
    }
    guard let binding = querySnapshots[generation], binding.snapshot.session == session,
      let entries = binding.calendarEntries
    else { throw staleSnapshot(generation) }
    guard try latestHistoryToken(in: context) == binding.historyToken else {
      querySnapshots.removeValue(forKey: generation)
      throw staleSnapshot(generation)
    }
    let rows: [PlannerCalendarEntry]
    if offset >= binding.snapshot.matchingCount {
      rows = []
    } else {
      let count = min(limit, binding.snapshot.matchingCount - offset)
      rows = Array(entries.dropFirst(Int(offset)).prefix(Int(count)))
    }
    return PlannerCalendarRowWindow(
      generation: generation, offset: offset, matchingCount: binding.snapshot.matchingCount,
      rows: rows)
  }

  private func readMapRows(
    session: PlannerDatasetSession, context: ModelContext, generation: UUID, offset: Int64,
    limit: Int64
  ) throws -> PlannerMapRowWindow {
    guard offset >= 0, limit > 0 else {
      throw PlannerFailure("invalidInput", "Map row offset must be nonnegative and limit positive.")
    }
    guard let binding = querySnapshots[generation], binding.snapshot.session == session else {
      throw staleSnapshot(generation)
    }
    guard let query = binding.itemQuery else {
      throw PlannerFailure("invalidInput", "Map rows require an Item query generation.")
    }
    guard try latestHistoryToken(in: context) == binding.historyToken else {
      querySnapshots.removeValue(forKey: generation)
      throw staleSnapshot(generation)
    }
    let snapshot = binding.snapshot
    let mapContext: MapQueryContext
    if let retained = binding.mapContext {
      mapContext = retained
    } else {
      mapContext = try mapQueryContext(query: query, snapshot: snapshot, context: context)
    }
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
        guard source.kind == .item, mapContext.collection == nil else {
          throw PlannerFailure("readUnavailable", "The Map source has inconsistent scope.")
        }
        return try mapItemRow(identity: identity, source: source, context: context)
      case .appearance(let source, let appearance):
        let key = try mapAppearanceKey(appearance, scope: query.scope)
        guard let saved = mapContext.appearances[key], saved.source.kind == "item",
          saved.source.id == source.id, source.kind == .item
        else {
          throw PlannerFailure("readUnavailable", "The Map appearance has unresolved bindings.")
        }
        return try mapItemRow(
          identity: identity, source: source, expectedLifetime: saved.source.lifetimeId,
          placement: saved.placement, context: context)
      }
    }
    guard try latestHistoryToken(in: context) == binding.historyToken else {
      querySnapshots.removeValue(forKey: generation)
      throw staleSnapshot(generation)
    }
    var retained = binding
    retained.mapContext = mapContext
    querySnapshots[generation] = retained
    return PlannerMapRowWindow(
      generation: generation, offset: offset, matchingCount: snapshot.matchingCount,
      collection: mapContext.collection, listBranches: mapContext.branches, rows: rows)
  }

  private func mapItemRow(
    identity: PlannerRowIdentity, source: PlannerEntityReference, expectedLifetime: UUID? = nil,
    placement: PlannerMapPlacement? = nil, context: ModelContext
  ) throws -> PlannerMapRowRead {
    let identifier = source.id
    var descriptor = FetchDescriptor<PlannerSchemaV18.Item>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.title, \.locationData]
    let records = try context.fetch(descriptor)
    guard records.count == 1, let item = records.first, let lifetime = item.lifetimeId,
      expectedLifetime == nil || expectedLifetime == lifetime
    else {
      throw PlannerFailure("readUnavailable", "The Map Item is missing or unresolved.")
    }
    let location = try item.locationData.map {
      try JSONDecoder().decode(PlannerOwnedLocation.self, from: $0)
    }
    try PlannerItemContentInput(title: item.title, location: location).validate()
    let ownedLinks = try (item.links ?? []).map {
      try $0.value(ownerId: identifier, ownerLifetimeId: lifetime)
    }.sorted { first, second in
      if first.rank != second.rank { return first.rank < second.rank }
      return first.id.uuidString < second.id.uuidString
    }
    guard Set(ownedLinks.map(\.id)).count == ownedLinks.count else {
      throw PlannerFailure("readUnavailable", "The Map Item has duplicate owned links.")
    }
    let savedLinks = ownedLinks.filter { $0.kind == .appleMaps || $0.kind == .googleMaps }.map(
      \.read)
    return PlannerMapRowRead(
      identity: identity, sourceLifetimeId: lifetime, title: item.title,
      ownedLocation: location, mapsLinks: savedLinks, placement: placement)
  }

  private func mapAppearanceKey(_ appearance: PlannerAppearance, scope: PlannerItemQuery.Scope)
    throws -> MapAppearanceKey
  {
    switch (scope, appearance) {
    case (.list(let owner), .listMembership(let list, let membership)) where owner == list:
      return .membership(membership)
    case (.itinerary(let owner), .directItineraryItem(let itinerary, let entry))
    where owner == itinerary:
      return .entry(entry)
    case (.itinerary(let owner), .expandedListItem(let itinerary, let entry, let membership))
    where owner == itinerary:
      return .expanded(entryId: entry, membershipId: membership)
    default:
      throw PlannerFailure("readUnavailable", "The Map appearance belongs to another scope.")
    }
  }

  private func mapList(
    identifier: UUID, expectedLifetime: UUID? = nil, context: ModelContext
  ) throws -> (collection: PlannerMapCollection, archived: Bool) {
    var descriptor = FetchDescriptor<PlannerSchemaV18.List>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.name, \.archived]
    let records = try context.fetch(descriptor)
    guard records.count == 1, let list = records.first, let lifetime = list.lifetimeId,
      expectedLifetime == nil || expectedLifetime == lifetime,
      !list.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw PlannerFailure("readUnavailable", "The Map List is missing or unresolved.") }
    return (
      .init(
        source: .init(kind: .list, id: identifier), sourceLifetimeId: lifetime, title: list.name),
      list.archived
    )
  }

  private func mapMemberships(list: PlannerMapCollection, context: ModelContext) throws
    -> [MembershipSnapshot]
  {
    let identifier = list.source.id
    let lifetime = list.sourceLifetimeId
    let descriptor = FetchDescriptor<PlannerSchemaV18.Membership>(
      predicate: #Predicate { $0.listId == identifier && $0.listLifetimeId == lifetime },
      sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
    let memberships = try context.fetch(descriptor).map { try $0.value() }
    guard Set(memberships.map(\.id)).count == memberships.count,
      Set(memberships.map { $0.item.id }).count == memberships.count
    else { throw PlannerFailure("readUnavailable", "The Map List has unresolved memberships.") }
    return memberships
  }

  private func mapQueryContext(
    query: PlannerItemQuery, snapshot: PlannerQuerySnapshot, context: ModelContext
  ) throws -> MapQueryContext {
    switch query.scope {
    case .global, .inbox: return MapQueryContext()
    case .list(let identifier):
      let list = try mapList(identifier: identifier, context: context).collection
      var result = MapQueryContext(collection: list)
      for (index, membership) in try mapMemberships(list: list, context: context).enumerated() {
        result.appearances[.membership(membership.id)] = .init(
          source: membership.item,
          placement: .listMembership(membershipId: membership.id, childPosition: Int64(index) + 1))
      }
      return result
    case .itinerary(let identifier):
      return try itineraryMapContext(
        identifier: identifier, query: query, snapshot: snapshot, context: context)
    }
  }

  private func itineraryMapContext(
    identifier: UUID, query: PlannerItemQuery, snapshot: PlannerQuerySnapshot, context: ModelContext
  ) throws -> MapQueryContext {
    var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.title]
    let records = try context.fetch(descriptor)
    guard records.count == 1, let itinerary = records.first, let lifetime = itinerary.lifetimeId,
      !itinerary.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let presentation = snapshot.rowPresentation
    else { throw PlannerFailure("readUnavailable", "The Map Itinerary is missing or unresolved.") }
    let entriesDescriptor = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>(
      predicate: #Predicate { $0.itineraryId == identifier && $0.itineraryLifetimeId == lifetime },
      sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)])
    let entries = try context.fetch(entriesDescriptor).map { try $0.value() }
    guard Set(entries.map(\.id)).count == entries.count else {
      throw PlannerFailure("readUnavailable", "The Map Itinerary has duplicate entries.")
    }
    var result = MapQueryContext(
      collection: .init(
        source: .init(kind: .itinerary, id: identifier), sourceLifetimeId: lifetime,
        title: itinerary.title))
    var matchingChildren: [UUID: Int64] = [:]
    for identity in snapshot.rows {
      if case .appearance(_, .expandedListItem(let owner, let entry, _)) = identity,
        owner == identifier
      {
        matchingChildren[entry, default: 0] += 1
      }
    }
    let hasItemRestrictions =
      query.categories?.ids.isEmpty == false || query.tags?.ids.isEmpty == false
      || query.lists?.ids.isEmpty == false || query.duration != nil || query.hasAddress
      || query.hasLinks
      || query.scheduled != .all
    var matchingLists: Set<UUID> = []
    if !hasItemRestrictions {
      let headers = try listCatalogSnapshot(
        session: snapshot.session,
        query: .init(sourceKind: .list, text: query.text, archive: query.archive), context: context)
      matchingLists = Set(
        headers.rows.compactMap { identity in
          guard case .source(let source) = identity else { return nil }
          return source.id
        })
    }
    for (index, entry) in entries.enumerated() {
      let position = Int64(index) + 1
      if entry.source.kind == "item" {
        result.appearances[.entry(entry.id)] = .init(
          source: entry.source,
          placement: .itineraryItem(entryId: entry.id, routePosition: position))
        continue
      }
      let savedList = try mapList(
        identifier: entry.source.id, expectedLifetime: entry.source.lifetimeId, context: context)
      let list = savedList.collection
      let children = try mapMemberships(list: list, context: context)
      var appearances: [ContextualQueryAppearance] = []
      for (childIndex, membership) in children.enumerated() {
        let localDone =
          entry.expandedCompletions.first {
            $0.context.membershipId == membership.id
              && $0.context.membershipLifetimeId == membership.lifetimeId
          }?.localDone ?? false
        appearances.append(
          .init(
            item: membership.item,
            appearance: .expandedListItem(
              itineraryId: identifier, listEntryId: entry.id, membershipId: membership.id),
            localDone: localDone, branchArchived: savedList.archived))
        result.appearances[.expanded(entryId: entry.id, membershipId: membership.id)] = .init(
          source: membership.item,
          placement: .itineraryListItem(
            entryId: entry.id, routePosition: position, list: list,
            membershipId: membership.id, childPosition: Int64(childIndex) + 1))
      }
      let fullBranch = try contextualItemQuerySnapshot(
        session: snapshot.session, container: list.source, appearances: appearances,
        query: .init(
          scope: query.scope, completion: .all, archive: .all, sort: .init(mode: .manual)),
        presentation: presentation, membershipListsByItem: [:], context: context)
      let matchesCompletion: Bool
      switch query.completion {
      case .all: matchesCompletion = true
      case .todo: matchesCompletion = fullBranch.progress.first?.state != .complete
      case .done: matchesCompletion = fullBranch.progress.first?.state == .complete
      }
      let matchesHeader = matchingLists.contains(list.source.id) && matchesCompletion
      let count = matchingChildren[entry.id, default: 0]
      if matchesHeader || count > 0 {
        result.branches.append(
          .init(
            entryId: entry.id, routePosition: position, list: list,
            matchesHeader: matchesHeader, matchingChildCount: count))
      }
    }
    return result
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
    let estimateGraph = try catalogEstimateGraph(identities: identities, context: context)
    let rows = try identities.map { identity in
      let source: PlannerEntityReference
      let localDone: Bool?
      let expectedLifetimeId: UUID?
      switch identity {
      case .appearance(let reference, .listMembership(let listId, let membershipId)):
        var memberships = FetchDescriptor<PlannerSchemaV18.Membership>(
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
          title: category.content.name, subtitle: nil, estimate: nil, manualEstimate: nil,
          containerEstimates: nil,
          globalDone: nil, localDone: nil, effectiveDone: nil, archived: nil,
          hasLocation: false, hasLinks: false, ownedLocation: nil, previewLink: nil,
          labels: [], scheduleSummary: .none)
      }
      if source.kind == .tag {
        let tag = try tagSnapshot(source.id, context: context)
        return PlannerRowRead(
          identity: identity, sourceLifetimeId: tag.lifetimeId,
          title: tag.content.name, subtitle: nil, estimate: nil, manualEstimate: nil,
          containerEstimates: nil,
          globalDone: nil, localDone: nil, effectiveDone: nil, archived: nil,
          hasLocation: false, hasLinks: false, ownedLocation: nil, previewLink: nil,
          labels: [], scheduleSummary: .none)
      }
      if source.kind == .list {
        let sourceIdentifier = source.id
        var descriptor = FetchDescriptor<PlannerSchemaV18.List>(
          predicate: #Predicate { $0.id == sourceIdentifier })
        descriptor.fetchLimit = 2
        descriptor.propertiesToFetch = [
          \.id, \.lifetimeId, \.name, \.archived, \.manualEstimateData,
        ]
        let records = try context.fetch(descriptor)
        guard records.count == 1, let list = records.first, let lifetimeId = list.lifetimeId,
          !list.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          throw PlannerFailure("readUnavailable", "A snapshot List is missing or unresolved.")
        }
        let estimateSource = try list.estimateSnapshot()
        let summary = try estimateSource.progressAndEstimates(
          memberships: estimateGraph.memberships, items: estimateGraph.items)
        return PlannerRowRead(
          identity: identity, sourceLifetimeId: lifetimeId,
          title: list.name, subtitle: nil, estimate: nil,
          manualEstimate: estimateSource.manualEstimate, containerEstimates: summary.estimates,
          globalDone: nil, localDone: nil, effectiveDone: nil, archived: list.archived,
          hasLocation: false, hasLinks: false, ownedLocation: nil, previewLink: nil,
          labels: [], scheduleSummary: .none)
      }
      if source.kind == .itinerary {
        return try itineraryCatalogRow(
          identity: identity, sourceId: source.id, estimateGraph: estimateGraph, context: context)
      }
      if source.kind == .schedule {
        return try scheduleCatalogRow(identity: identity, sourceId: source.id, context: context)
      }
      guard let presentation = snapshot.rowPresentation else {
        throw PlannerFailure("readUnavailable", "The Item query has no presentation context.")
      }
      let sourceIdentifier = source.id
      var descriptor = FetchDescriptor<PlannerSchemaV18.Item>(
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
      let owned = FetchDescriptor<PlannerSchemaV18.OwnedLink>(
        predicate: #Predicate {
          $0.ownerId == sourceIdentifier && $0.ownerLifetimeId == lifetimeId
        })
      var selected = FetchDescriptor<PlannerSchemaV18.OwnedLink>(
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
          var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
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
    let descriptor = FetchDescriptor<PlannerSchemaV18.LabelAssociation>(
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
    identity: PlannerRowIdentity, sourceId: UUID, estimateGraph: CatalogEstimateGraph,
    context: ModelContext
  ) throws -> PlannerRowRead {
    var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
      predicate: #Predicate { $0.id == sourceId })
    descriptor.fetchLimit = 2
    descriptor.propertiesToFetch = [
      \.id, \.lifetimeId, \.title, \.archived, \.locationData, \.manualEstimateData,
    ]
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
    let owned = FetchDescriptor<PlannerSchemaV18.OwnedLink>(
      predicate: #Predicate {
        $0.ownerKind == "itinerary" && $0.ownerId == sourceId && $0.ownerLifetimeId == lifetimeId
      })
    var selected = FetchDescriptor<PlannerSchemaV18.OwnedLink>(
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
    let estimateSource = try itinerary.estimateSnapshot(entries: estimateGraph.entries)
    let summary = try estimateSource.progressAndEstimates(
      memberships: estimateGraph.memberships, items: estimateGraph.items, lists: estimateGraph.lists
    )
    return PlannerRowRead(
      identity: identity, sourceLifetimeId: lifetimeId, title: content.title,
      subtitle: nil, estimate: nil, manualEstimate: estimateSource.manualEstimate,
      containerEstimates: summary.estimates, globalDone: nil,
      localDone: nil, effectiveDone: nil,
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
    var descriptor = FetchDescriptor<PlannerSchemaV18.Schedule>(
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
      title: title, subtitle: nil, estimate: nil, manualEstimate: nil, containerEstimates: nil,
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
    let assignments = FetchDescriptor<PlannerSchemaV18.Schedule>(
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
      FetchDescriptor<PlannerSchemaV18.Schedule>(
        predicate: #Predicate {
          $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
            && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) <= referenceInstant
            && $0.end != nil && ($0.end ?? referenceInstant) > referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV18.Schedule>(
        predicate: #Predicate {
          $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
            && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) >= referenceInstant
        }, sortBy: [SortDescriptor(\.start), SortDescriptor(\.id)]),
      FetchDescriptor<PlannerSchemaV18.Schedule>(
        predicate: #Predicate {
          $0.sourceKind == sourceKind && $0.sourceId == sourceIdentifier
            && $0.sourceLifetimeId == lifetimeId
            && $0.start != nil && ($0.start ?? referenceInstant) < referenceInstant
        }, sortBy: [SortDescriptor(\.start, order: .reverse), SortDescriptor(\.id)]),
    ]
    var allDayDescriptor = FetchDescriptor<PlannerSchemaV18.Schedule>(
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
    let directEntries = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>(
      predicate: #Predicate {
        $0.sourceKind == "item" && $0.sourceId == itemId && $0.sourceLifetimeId == lifetimeId
      })
    var itineraries = try context.fetch(directEntries).map { try $0.value().itinerary }
    let memberships = FetchDescriptor<PlannerSchemaV18.Membership>(
      predicate: #Predicate { $0.itemId == itemId && $0.itemLifetimeId == lifetimeId })
    for membership in try context.fetch(memberships) {
      let list = try membership.value().list
      let listId = list.id
      let listLifetimeId = list.lifetimeId
      let listEntries = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>(
        predicate: #Predicate {
          $0.sourceKind == "list" && $0.sourceId == listId && $0.sourceLifetimeId == listLifetimeId
        })
      itineraries.append(
        contentsOf: try context.fetch(listEntries).map { try $0.value().itinerary })
    }
    for itinerary in itineraries {
      let itineraryId = itinerary.id
      let itineraryLifetimeId = itinerary.lifetimeId
      var assignments = FetchDescriptor<PlannerSchemaV18.Schedule>(
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
    _ item: PlannerSchemaV18.Item, scheduled: PlannerItemQuery.Scheduling, context: ModelContext
  ) throws -> Bool {
    guard scheduled != .all else { return true }
    guard let itemId = item.id, let lifetimeId = item.lifetimeId else {
      throw PlannerFailure("readUnavailable", "A schedule-filtered Item has unresolved identity.")
    }
    var assignments = FetchDescriptor<PlannerSchemaV18.Schedule>(
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

  public func retryRecovery(session: PlannerDatasetSession, operationId: UUID)
    -> PlannerOperationResult
  {
    var knownAppliedReceipt: RecoveryReceipt?
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let archive = recoveryArchive(identity)
        let latestRead = Result { try archive.latest() }
        if case .success(let envelope) = latestRead,
          let receipt = envelope?.receipts.first(where: { $0.operationId == operationId }),
          let checkpoint = receipt.checkpointGeneration.flatMap(Int64.init)
        {
          return PlannerOperationResult(
            operationId: operationId,
            outcome: .applied(
              result: receipt.result, recovery: .complete(checkpointGeneration: checkpoint)))
        }
        guard FileManager.default.fileExists(atPath: configuration.storeURL.path) else {
          throw PlannerFailure("readUnavailable", "The committed dataset store is unavailable.")
        }
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        let receipts = try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>())
        let matches = receipts.filter { $0.operationId == operationId }
        guard let receipt = matches.first else {
          throw PlannerFailure(
            "recoveryNotApplied", "Only a known applied operation can retry its checkpoint.")
        }
        guard matches.count == 1 else {
          throw PlannerFailure("readUnavailable", "Applied operation identities are duplicated.")
        }
        let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
        guard evidence.datasetId == identity.datasetId,
          evidence.ownershipBinding == identity.ownershipBinding
        else {
          throw PlannerFailure(
            "ownershipUnverified", "The applied operation has a different owner.")
        }
        knownAppliedReceipt = evidence
        _ = try latestRead.get()
        let snapshot = try canonicalRecoverySnapshot(context)
        let generation = try archive.publish(
          snapshot: snapshot, receipts: context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>()))
        return PlannerOperationResult(
          operationId: operationId,
          outcome: .applied(
            result: evidence.result, recovery: .complete(checkpointGeneration: generation)))
      }
    } catch {
      if let knownAppliedReceipt {
        return PlannerOperationResult(
          operationId: operationId,
          outcome: .applied(
            result: knownAppliedReceipt.result,
            recovery: .incomplete(failure(error, code: "recoveryIncomplete"))))
      }
      return PlannerOperationResult(
        operationId: operationId, outcome: .rejected(failure(error, code: "readUnavailable")))
    }
  }

  private func executeImport(
    _ operation: PlannerOperation, request: PlannerImportRequest,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    let backup = request.backup
    let mode = request.mode
    let restoreDeletedData = request.restoreDeletedData
    let empty = PlannerDecodedBackup(
      backup: .init(
        sources: [], labelAssociations: [], memberships: [], itineraryEntries: [],
        expandedCompletions: [], deletionMarkers: []))
    let digest = plannerImportDigest(
      incoming: backup, current: empty, mode: mode, identity: identity,
      restoreDeletedData: restoreDeletedData, recoverySelection: request.recoverySelection)
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let evidence = try receipt.evidence()
      let replayDigest = plannerImportDigest(
        incoming: backup, current: empty, mode: mode, identity: identity,
        restoreDeletedData: restoreDeletedData, recoverySelection: request.recoverySelection,
        resolvedBindings: evidence.resolvedMembershipEvidence.map { _ in evidence.bindings },
        membershipEvidence: evidence.resolvedMembershipEvidence)
      guard receipt.payloadDigest == replayDigest else {
        throw PlannerFailure("operationPayloadMismatch", "This operation describes another import.")
      }
      return appliedResult(
        operationId: operation.operationId,
        evidence: try RecoveryReceipt(receipt, checkpoint: nil), envelope: envelope)
    }
    let prepared = try archive.proposals().first { $0.originalOperationId == operation.operationId }
    if let prepared, let bindings = prepared.resolvedBindings,
      let membershipEvidence = prepared.resolvedMembershipEvidence
    {
      let replayDigest = plannerImportDigest(
        incoming: backup, current: empty, mode: mode, identity: identity,
        restoreDeletedData: restoreDeletedData, recoverySelection: request.recoverySelection,
        resolvedBindings: bindings, membershipEvidence: membershipEvidence)
      guard prepared.payloadDigest == replayDigest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another import.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(prepared.summary))
    }
    let completedIdentifiers = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIdentifiers.contains($0) } ?? false })
    else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let current = try importReviewSnapshot(context)
    guard let token = operation.reviewToken, let review = reviews[token.reviewId],
      review.session == operation.session,
      review.payloadDigest
        == plannerImportDigest(
          incoming: backup, current: current, mode: mode, identity: identity,
          restoreDeletedData: restoreDeletedData, recoverySelection: request.recoverySelection)
    else {
      throw PlannerFailure(
        "staleReview", "The import or current dataset changed; review it again.",
        propertyPath: "/reviewToken", details: .staleReview)
    }
    if let proposal = prepared {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another import.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let deletionImpacts = try importDeletionImpacts(
      incoming: backup, current: current, mode: mode, context: context)
    let resolution = try plannerResolveImportReview(
      incoming: backup, current: current, mode: mode, deletionImpacts: deletionImpacts)
    guard !restoreDeletedData || mode == .overwrite else {
      throw PlannerFailure("invalidInput", "Restoration requires explicit Overwrite.")
    }
    let requiresRestoration =
      !resolution.details.restorations.isEmpty
      || resolution.details.referenceChanges.contains { $0.change == .restore }
    guard !requiresRestoration || restoreDeletedData else {
      throw PlannerFailure("unavailable", "Deleted data needs separate reviewed restoration.")
    }
    let merge = try PlannerImportMerge(
      current: current.backup, resolution: resolution, mode: mode,
      operationId: operation.operationId)
    let executionEvidence = try plannerImportMembershipOperationEvidence(
      incoming: backup, current: current.backup, projected: merge.projected,
      changes: resolution.details.referenceChanges)
    let executionDigest = plannerImportDigest(
      incoming: backup, current: empty, mode: mode, identity: identity,
      restoreDeletedData: restoreDeletedData, recoverySelection: request.recoverySelection,
      resolvedBindings: executionEvidence?.bindings,
      membershipEvidence: executionEvidence?.memberships)
    try plannerRemoveUnretainedImportedRecords(notIn: merge.projected, context: context)
    try plannerInsertImportedGraph(
      merge.recordsToWrite, replacing: merge.sourceReplacements, context: context)
    let restored = try importReviewSnapshot(context)
    guard
      restored.backup.importCanonicalValue.encoded()
        == merge.projected.importCanonicalValue.encoded()
    else {
      context.rollback()
      throw PlannerFailure(
        "unavailable", "The native store cannot yet preserve every imported field.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let itineraries = try itinerarySnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let memberships = try membershipSnapshots(context)
    let markers = try deletionMarkers(context)
    let lineage = try PlannerNativeLineage(context: context)
    let proposalSnapshot = PlannerDataSnapshot(
      itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
      items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
      contextAliases: lineage.contextAliases, completionChanges: lineage.completionChanges,
      restorationFamilies: lineage.restorationFamilies,
      membershipProvenance: lineage.membershipProvenance,
      membershipRemovals: lineage.membershipRemovals)
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: proposalSnapshot, payloadDigest: executionDigest,
        evidence: "preparedUnverified", resolvedBindings: executionEvidence?.bindings,
        resolvedMembershipEvidence: executionEvidence?.memberships))
    let restoredSources = Set(resolution.details.restorations.map { $0.owner.reference })
    let generated = merge.recordsToWrite.sources.filter {
      !restoredSources.contains($0.importBinding.reference)
    }.map {
      PlannerAppliedIdentity.source($0.importBinding.reference)
    }
    let affected =
      generated
      + merge.sourceReplacements.map {
        PlannerAppliedIdentity.source($0.importBinding.reference)
      }
      + resolution.sourceDeletes.map { PlannerAppliedIdentity.source($0) }
      + restoredSources.map { PlannerAppliedIdentity.source($0) }
      + resolution.details.referenceChanges.filter {
        $0.change == .remove || $0.change == .restore
      }.map {
        .reference($0.reference)
      }
    let result = PlannerAppliedResult(
      generatedIdentities: generated, affectedIdentities: affected,
      importSummary: try resolution.details.appliedSummary(in: restored.backup))
    let bindings =
      executionEvidence?.bindings
      ?? backup.backup.sources.map {
        PlannerBoundIdentity(
          kind: $0.kind.rawValue, id: $0.id, lifetimeId: $0.importBinding.lifetimeId)
      }
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: executionDigest, result: result, bindings: bindings)
    if let executionEvidence {
      receipt.resultData = try JSONEncoder().encode(
        PlannerStoredOperationEvidence(
          result: result, bindings: bindings,
          resolvedMembershipEvidence: executionEvidence.memberships))
    }
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure", "The import was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        contextAliases: lineage.contextAliases, completionChanges: lineage.completionChanges,
        restorationFamilies: lineage.restorationFamilies,
        membershipProvenance: lineage.membershipProvenance,
        membershipRemovals: lineage.membershipRemovals, receipts: receipts + [receipt])
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

  public func exportData(session: PlannerDatasetSession) -> PlannerExportResult {
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        try ensureCanonicalMemberships(identity: identity, context: context)
        let lineage = try PlannerNativeLineage(context: context)
        let snapshot = PlannerDataSnapshot(
          itineraries: try itinerarySnapshots(context),
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context),
          categories: try categorySnapshots(context),
          items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
          lists: try listSnapshots(context), memberships: try membershipSnapshots(context),
          deletionMarkers: try deletionMarkers(context),
          contextAliases: lineage.contextAliases,
          completionChanges: lineage.completionChanges,
          restorationFamilies: lineage.restorationFamilies,
          membershipProvenance: lineage.membershipProvenance,
          membershipRemovals: lineage.membershipRemovals)
        try requireCompleteExportGraph(snapshot, context: context)
        _ = try snapshot.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return .exported(try encoder.encode(snapshot))
      }
    } catch { return .failed(failure(error, code: "readUnavailable")) }
  }

  private func importDeletionImpacts(
    incoming: PlannerDecodedBackup, current: PlannerDecodedBackup, mode: PlannerImportMode,
    context: ModelContext
  ) throws -> [PlannerImportDeletionImpact] {
    guard mode == .overwrite else { return [] }
    let projection = try PlannerImportProjection(backup: current.backup)
    var impacts: [PlannerImportDeletionImpact] = []
    for (index, marker) in incoming.backup.deletionMarkers.enumerated() {
      guard let owner = projection.liveOwner(for: marker.target) else { continue }
      if case .expandedCompletion(let completionContext) = marker.target {
        impacts.append(
          .init(
            markerIndex: index, sourceDeletes: [],
            referenceRemovals: [
              .expandedCompletion(
                itineraryId: owner.id, listEntryId: completionContext.listEntryId,
                membershipId: completionContext.membershipId)
            ]))
        continue
      }
      guard case .source(let source, _) = marker.target else {
        guard
          let reference = projection.references.first(where: {
            $0.identity == marker.target.importIdentity
          })
        else { continue }
        var removals = [reference.reference]
        switch marker.target {
        case .membership(let identifier, _):
          removals += projection.references.compactMap {
            guard case .expandedCompletion(_, _, let membershipId) = $0.reference,
              membershipId == identifier
            else { return nil }
            return $0.reference
          }
        case .itineraryEntry(let identifier, _):
          removals += projection.references.compactMap {
            guard case .expandedCompletion(_, let listEntryId, _) = $0.reference,
              listEntryId == identifier
            else { return nil }
            return $0.reference
          }
        default: break
        }
        impacts.append(
          .init(markerIndex: index, sourceDeletes: [], referenceRemovals: removals))
        continue
      }
      switch source.kind {
      case .item:
        let resolution = try resolveItemDeletion(source, context: context)
        impacts.append(
          .init(
            markerIndex: index, sourceDeletes: resolution.sourceDeletes,
            referenceRemovals: resolution.removals))
      case .list:
        let resolution = try resolveListDeletion(source, context: context)
        impacts.append(
          .init(
            markerIndex: index, sourceDeletes: [source], referenceRemovals: resolution.removals))
      case .itinerary:
        let resolution = try resolveItineraryDeletion(source, context: context)
        impacts.append(
          .init(
            markerIndex: index, sourceDeletes: resolution.sourceDeletes,
            referenceRemovals: resolution.removals))
      case .category, .tag:
        let resolution = try resolveLabelDeletion(source, context: context)
        impacts.append(
          .init(
            markerIndex: index, sourceDeletes: [source],
            referenceRemovals: resolution.associations.map(\.reference)))
      case .schedule:
        guard
          let reference = projection.references.first(where: {
            $0.identity == marker.target.importIdentity
          })
        else { continue }
        impacts.append(
          .init(
            markerIndex: index, sourceDeletes: [source],
            referenceRemovals: [reference.reference]))
      }
    }
    return impacts
  }

  private func maintenanceSnapshot(
    _ context: ModelContext, memberships: [MembershipSnapshot]? = nil
  ) throws -> PlannerDataSnapshot {
    let lineage = try PlannerNativeLineage(context: context)
    return PlannerDataSnapshot(
      itineraries: try itinerarySnapshots(context),
      labelAssociations: try labelAssociationSnapshots(context),
      tags: try tagSnapshots(context), categories: try categorySnapshots(context),
      items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
      lists: try listSnapshots(context),
      memberships: try memberships ?? membershipSnapshots(context),
      deletionMarkers: try deletionMarkers(context), contextAliases: lineage.contextAliases,
      completionChanges: lineage.completionChanges,
      restorationFamilies: lineage.restorationFamilies,
      membershipProvenance: lineage.membershipProvenance,
      membershipRemovals: lineage.membershipRemovals)
  }

  private func publishMaintenanceSnapshot(
    identity: PlannerStoreIdentity, context: ModelContext
  ) throws -> Int64 {
    let snapshot = try maintenanceSnapshot(context)
    try requireCompleteExportGraph(snapshot, context: context)
    _ = try snapshot.validated()
    let lineage = try PlannerNativeLineage(context: context)
    return try recoveryArchive(identity, context: context).publish(
      itineraries: try itinerarySnapshots(context),
      labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
      categories: try categorySnapshots(context),
      items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
      lists: try listSnapshots(context), memberships: try membershipSnapshots(context),
      deletionMarkers: try deletionMarkers(context), contextAliases: lineage.contextAliases,
      completionChanges: lineage.completionChanges,
      restorationFamilies: lineage.restorationFamilies,
      membershipProvenance: lineage.membershipProvenance,
      membershipRemovals: lineage.membershipRemovals,
      receipts: try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>()))
  }

  /// Recovery copies derive canonical data without creating a native maintenance transaction.
  private func canonicalRecoverySnapshot(_ context: ModelContext) throws -> PlannerDataSnapshot {
    let history = try latestHistoryToken(in: context)
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
    let snapshot: PlannerDataSnapshot
    if try membershipConsolidationRequired(records, context: context) {
      defer { context.rollback() }
      let memberships = try records.map { try $0.value() }
      let detached = try plannerStageDetachedExpandedRetirements(
        context: context, memberships: memberships, lineage: PlannerNativeLineage(context: context))
      let before = try maintenanceSnapshot(context, memberships: memberships)
      try requireCompleteExportGraph(before, context: context)
      let consolidation = try PlannerMembershipConsolidation(
        snapshot: before, detachedExpanded: detached)
      snapshot = try PlannerDataSnapshot(snapshot: before, canonical: consolidation.backup)
    } else {
      snapshot = try maintenanceSnapshot(context)
      try requireCompleteExportGraph(snapshot, context: context)
    }
    _ = try snapshot.validated()
    guard try latestHistoryToken(in: context) == history else {
      throw PlannerFailure(
        "recoveryIncomplete", "Native data changed while preparing its recovery copy.")
    }
    return snapshot
  }

  private func membershipConsolidationRequired(
    _ records: [PlannerSchemaV18.Membership], context: ModelContext
  ) throws -> Bool {
    let identifiers = records.compactMap(\.id)
    let pairs = records.compactMap { record -> String? in
      guard let list = record.listId, let listLifetime = record.listLifetimeId,
        let item = record.itemId, let itemLifetime = record.itemLifetimeId
      else { return nil }
      return list.uuidString + "/" + listLifetime.uuidString + "/"
        + item.uuidString + "/" + itemLifetime.uuidString
    }
    if Set(identifiers).count != identifiers.count || Set(pairs).count != pairs.count {
      return true
    }
    let lineage = try PlannerNativeLineage(context: context)
    var markerDescriptor = FetchDescriptor<PlannerSchemaV4.DeletionMarker>()
    if lineage.membershipRemovals.isEmpty {
      markerDescriptor.predicate = #Predicate { $0.sourceKind == "membership" }
    }
    let markers =
      try context.fetch(markerDescriptor).map { try $0.value() } + lineage.deletionMarkers
    let membershipClosures = try markers.compactMap { marker -> PlannerPortableDeletionMarker? in
      guard case .membership(let binding) = marker.target else { return nil }
      guard binding.kind == "membership" else {
        throw PlannerFailure("readUnavailable", "The membership closure kind is unsupported.")
      }
      return .init(
        deletionId: marker.deletionId, operationId: marker.operationId,
        target: .membership(id: binding.id, lifetimeId: binding.lifetimeId),
        closedFamilyId: marker.closedFamilyId)
    }
    if !membershipClosures.isEmpty {
      // Only closure identities are probed here; maintenance validates the complete graph.
      let closures = PlannerImportGraph(
        backup: .init(
          sources: [], labelAssociations: [], memberships: [], itineraryEntries: [],
          expandedCompletions: [], deletionMarkers: membershipClosures,
          restorationFamilies: lineage.restorationFamilies))
      if records.contains(where: {
        guard let identifier = $0.id, let lifetime = $0.lifetimeId else { return false }
        return closures.isClosed(.init(kind: .membership, id: identifier, lifetimeId: lifetime))
      }) {
        return true
      }
    }
    if !lineage.membershipRemovals.isEmpty {
      for record in records {
        let membership = try record.value()
        let retained =
          lineage.membershipProvenance.first {
            $0.membershipId == membership.id && $0.membershipLifetimeId == membership.lifetimeId
          } ?? membership.baselineProvenance
        let required = try lineage.provenanceForNewMembership(membership, markers: markers)
        if !Set(retained.observedRemovalIds).isSuperset(of: required.observedRemovalIds) {
          return true
        }
      }
    }
    let expandedRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>())
    let closedExpandedContexts = Set(
      lineage.deletionMarkers.compactMap { marker -> PlannerExpandedContext? in
        guard case .expandedCompletion(let completionContext) = marker.target else { return nil }
        return completionContext
      })
    var expandedContexts: Set<PlannerExpandedContext> = []
    for record in expandedRecords {
      guard let value = try? record.value(), expandedContexts.insert(value.context).inserted,
        !closedExpandedContexts.contains(value.context)
      else {
        return true
      }
    }
    if !lineage.contextAliases.isEmpty && !lineage.membershipProvenance.isEmpty {
      let memberships = try records.map { try $0.value().baselineProvenance }
      let aliases = PlannerMembershipConsolidation.aliasesRequiringCanonicalRootResolution(
        memberships: memberships,
        aliases: lineage.contextAliases, provenance: lineage.membershipProvenance)
      if !aliases.isEmpty {
        let graph = PlannerImportGraph(
          backup: try maintenanceSnapshot(context).decodedRecords().backup)
        let retired = PlannerMembershipConsolidation.membershipsRetiredByClosedCanonicalAliases(
          aliases: lineage.contextAliases, provenance: lineage.membershipProvenance, graph: graph)
        if memberships.contains(where: { retired.contains($0.membership) })
          || aliases.contains(where: {
            !graph.isClosed($0.context) && !graph.isClosed($0.canonicalContext)
          })
        {
          return true
        }
      }
    }
    let completionStates = try plannerCompletionHistoryStates(
      aliases: lineage.contextAliases, changes: lineage.completionChanges)
    for record in records {
      guard let identifier = record.id, let lifetime = record.lifetimeId,
        let expected = completionStates[
          .listMembership(membershipId: identifier, membershipLifetimeId: lifetime)]
      else { continue }
      if record.localDone != expected { return true }
    }
    if completionStates.keys.contains(where: {
      if case .directItineraryItem = $0 { return true }
      return false
    }) {
      for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()) {
        guard let identifier = entry.id, let lifetime = entry.lifetimeId,
          let expected = completionStates[
            .directItineraryItem(entryId: identifier, entryLifetimeId: lifetime)]
        else { continue }
        if entry.localDone != expected { return true }
      }
    }
    let liveMembershipBindings = Set(
      records.compactMap { record -> PlannerPortableBoundIdentity? in
        guard let identifier = record.id, let lifetime = record.lifetimeId else { return nil }
        return .init(kind: .membership, id: identifier, lifetimeId: lifetime)
      })
    var representedExpanded: Set<PlannerExpandedContext> = []
    for completion in expandedRecords {
      guard let identifier = completion.membershipId,
        let lifetime = completion.membershipLifetimeId,
        liveMembershipBindings.contains(
          .init(kind: .membership, id: identifier, lifetimeId: lifetime))
      else { return true }
      do {
        let value = try completion.value()
        representedExpanded.insert(value.context)
        if let expected = completionStates[.expandedListItem(value.context)],
          value.localDone != expected
        {
          return true
        }
      } catch { return true }
    }
    let missingCompletedContexts = completionStates.compactMap {
      completionContext, done -> PlannerExpandedContext? in
      guard done, case .expandedListItem(let expanded) = completionContext,
        !representedExpanded.contains(expanded),
        liveMembershipBindings.contains(
          .init(
            kind: .membership, id: expanded.membershipId,
            lifetimeId: expanded.membershipLifetimeId))
      else { return nil }
      return expanded
    }
    if !missingCompletedContexts.isEmpty {
      let graph = PlannerImportGraph(
        backup: try maintenanceSnapshot(context).decodedRecords().backup)
      for expanded in missingCompletedContexts {
        guard !graph.isClosed(.expandedListItem(expanded)),
          graph.backup.itineraryEntries.contains(where: {
            $0.id == expanded.listEntryId && $0.lifetimeId == expanded.listEntryLifetimeId
              && $0.source.kind == .list
          })
        else { continue }
        return true
      }
    }
    return false
  }

  private func ensureCanonicalMemberships(identity: PlannerStoreIdentity, context: ModelContext)
    throws
  {
    context.autosaveEnabled = false
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
    guard try membershipConsolidationRequired(records, context: context) else { return }
    let memberships = try records.map { try $0.value() }
    let archive = recoveryArchive(identity, context: context)
    let envelope = try archive.latest()
    let receipts = try context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>())
    let acknowledged = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map(acknowledged.contains) ?? false }),
      try archive.incompleteMaintenance(in: context, envelope: envelope).isEmpty
    else {
      throw PlannerFailure(
        "maintenanceRequired", "Prior recovery must complete before consolidation.")
    }
    let history = try latestHistoryToken(in: context)
    let maintenanceIdentifier = UUID()
    let usedIdentifiers = Set(receipts.compactMap(\.operationId))
      .union(try archive.maintenanceCommits(in: context).map(\.maintenanceId))
      .union(envelope?.maintenanceReceipts.map(\.evidence.maintenanceId) ?? [])
    guard !usedIdentifiers.contains(maintenanceIdentifier) else {
      throw PlannerFailure(
        "maintenanceRequired", "A fresh maintenance identity could not be issued.")
    }
    let consolidation: PlannerMembershipConsolidation
    let proposed: PlannerDataSnapshot
    do {
      let detached = try plannerStageDetachedExpandedRetirements(
        context: context, memberships: memberships, lineage: PlannerNativeLineage(context: context))
      let before = try maintenanceSnapshot(context, memberships: memberships)
      consolidation = try PlannerMembershipConsolidation(
        snapshot: before, detachedExpanded: detached)
      proposed = try PlannerDataSnapshot(snapshot: before, canonical: consolidation.backup)
      _ = try proposed.validated()
    } catch {
      context.rollback()
      throw error
    }
    do {
      let evidence = try archive.prepareMaintenance(
        .init(maintenanceId: maintenanceIdentifier, identity: identity, proposedBackup: proposed))
      try plannerStageMembershipConsolidation(consolidation.backup, context: context)
      context.insert(
        PlannerSchemaV19.MaintenanceCommit(
          maintenanceId: maintenanceIdentifier, evidenceData: try JSONEncoder().encode(evidence)))
      let staged = try maintenanceSnapshot(context)
      try requireCompleteExportGraph(staged, context: context)
      guard
        try staged.validated().backup.importCanonicalValue.encoded()
          == consolidation.backup.importCanonicalValue.encoded()
      else {
        throw PlannerFailure(
          "maintenanceRequired", "The staged consolidation differs from its proposal.")
      }
      let current = try loadIdentity()
      guard current.datasetId == identity.datasetId, current.namespaceId == identity.namespaceId,
        current.epochId == identity.epochId, current.ownershipBinding == identity.ownershipBinding,
        current.schemaVersion == identity.schemaVersion,
        try latestHistoryToken(in: context) == history
      else {
        throw PlannerFailure(
          "maintenanceRequired", "The dataset changed while preparing consolidation.")
      }
      try context.save()
    } catch {
      context.rollback()
      throw PlannerFailure(
        "maintenanceRequired",
        "Membership consolidation could not commit: " + failure(error, code: "unavailable").message)
    }
    querySnapshots.removeAll()
    do {
      _ = try publishMaintenanceSnapshot(identity: identity, context: context)
    } catch {
      // The native commit remains the authority; status and explicit retry expose incomplete recovery.
      return
    }
  }

  public func retryMaintenanceRecovery(session: PlannerDatasetSession, maintenanceId: UUID)
    -> PlannerMaintenanceRecoveryResult
  {
    var verifiedCommit = false
    do {
      return try coordinated {
        let identity = try validateSession(session)
        let archive = recoveryArchive(identity)
        let envelope = try archive.latest()
        if let acknowledged = envelope?.maintenanceReceipts.first(where: {
          $0.evidence.maintenanceId == maintenanceId
        }), let generation = Int64(acknowledged.checkpointGeneration) {
          return .complete(checkpointGeneration: generation)
        }
        let context = ModelContext(try openContainer())
        context.autosaveEnabled = false
        guard
          let commit = try archive.maintenanceCommits(in: context).first(where: {
            $0.maintenanceId == maintenanceId
          })
        else {
          throw PlannerFailure(
            "maintenanceNotApplied", "Only verified committed maintenance can retry recovery.")
        }
        try archive.verifyMaintenancePreparation(commit)
        verifiedCommit = true
        let snapshot = try canonicalRecoverySnapshot(context)
        return .complete(
          checkpointGeneration: try recoveryArchive(identity, context: context).publish(
            snapshot: snapshot, receipts: context.fetch(FetchDescriptor<PlannerSchemaV1.Receipt>()))
        )
      }
    } catch {
      let reason = failure(error, code: "recoveryIncomplete")
      if verifiedCommit { return .incomplete(reason: reason) }
      return .rejected(reason: reason)
    }
  }

  private func importReviewSnapshot(_ context: ModelContext) throws -> PlannerDecodedBackup {
    let lineage = try PlannerNativeLineage(context: context)
    let snapshot = PlannerDataSnapshot(
      itineraries: try itinerarySnapshots(context),
      labelAssociations: try labelAssociationSnapshots(context),
      tags: try tagSnapshots(context), categories: try categorySnapshots(context),
      items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
      lists: try listSnapshots(context), memberships: try membershipSnapshots(context),
      deletionMarkers: try deletionMarkers(context),
      contextAliases: lineage.contextAliases,
      completionChanges: lineage.completionChanges,
      restorationFamilies: lineage.restorationFamilies,
      membershipProvenance: lineage.membershipProvenance,
      membershipRemovals: lineage.membershipRemovals)
    try requireCompleteExportGraph(snapshot, context: context)
    return try snapshot.validated()
  }

  private func requireCompleteExportGraph(_ snapshot: PlannerDataSnapshot, context: ModelContext)
    throws
  {
    try requireExportedIdentities(
      stored: context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()).map(\.id),
      exported: snapshot.ownedLinks.map(\.id), kind: "bookmark")
    try requireExportedIdentities(
      stored: context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()).map(\.id),
      exported: snapshot.schedules.map(\.id), kind: "Schedule")
    try requireExportedIdentities(
      stored: context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).map(\.id),
      exported: snapshot.itineraryEntries.map(\.id), kind: "Itinerary entry")
    let contexts = try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).map {
      try $0.value().context
    }
    guard contexts.count == snapshot.expandedCompletions.count,
      Set(contexts) == Set(snapshot.expandedCompletions.map(\.context))
    else {
      throw PlannerFailure(
        "readUnavailable", "The complete expanded completion graph is unresolved.")
    }
  }

  private func requireExportedIdentities(stored: [UUID?], exported: [UUID], kind: String) throws {
    let storedIdentities = try stored.map { identifier in
      guard let identifier else {
        throw PlannerFailure("readUnavailable", "A stored \(kind) has unresolved identity.")
      }
      return identifier
    }
    guard storedIdentities.count == exported.count, Set(storedIdentities) == Set(exported) else {
      throw PlannerFailure("readUnavailable", "The complete \(kind) graph is unresolved.")
    }
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
      case .proposal(let namespaceId, let proposalId):
        return .selected(
          try requireArchive(archives, namespaceId: namespaceId).selection(proposalId: proposalId))
      case .maintenanceProposal(let namespaceId, let maintenanceId):
        return .selected(
          try requireArchive(archives, namespaceId: namespaceId).selection(
            maintenanceId: maintenanceId))
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
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()).map {
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
    -> [PlannerSchemaV18.Category]
  {
    try identifiers.sorted { $0.uuidString < $1.uuidString }.map { identifier in
      let records = try context.fetch(
        FetchDescriptor<PlannerSchemaV18.Category>(
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
    -> [PlannerSchemaV18.Tag]
  {
    try identifiers.sorted { $0.uuidString < $1.uuidString }.map { identifier in
      let records = try context.fetch(
        FetchDescriptor<PlannerSchemaV18.Tag>(
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
    try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).map { try $0.value() }
  }

  private func categorySnapshot(_ identifier: UUID, context: ModelContext) throws
    -> CategorySnapshot
  {
    var descriptor = FetchDescriptor<PlannerSchemaV18.Category>(
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
    let category = try PlannerSchemaV18.Category(content: content)
    let snapshot = try category.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingCategories = try categorySnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
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
    try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).map { try $0.value() }
  }

  private func tagSnapshot(_ identifier: UUID, context: ModelContext) throws
    -> TagSnapshot
  {
    var descriptor = FetchDescriptor<PlannerSchemaV18.Tag>(
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
    let tag = try PlannerSchemaV18.Tag(content: content)
    let snapshot = try tag.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingTags = try tagSnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
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
    try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).map { try $0.value() }
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
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
      try $0.value()
    }
    let existingAssociations = try labelAssociationSnapshots(context)
    let itinerary = try PlannerSchemaV18.Itinerary(input: content)
    itinerary.labelAssociations =
      selectedCategories.map {
        PlannerSchemaV18.LabelAssociation(itinerary: itinerary, category: $0)
      } + selectedTags.map { PlannerSchemaV18.LabelAssociation(itinerary: itinerary, tag: $0) }
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
    let list = try PlannerSchemaV18.List(content: content)
    let snapshot = try list.value()
    let result = PlannerAppliedResult(
      generated: [snapshot.reference], affected: [snapshot.reference])
    let existingLists = try listSnapshots(context)
    let existingItems = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
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
    let categories = try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>())
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
    var after = CategorySnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: updatedAt,
      content: content, contentOrigins: before.contentOrigins
    )
    after.contentOrigins = plannerEditedContentOrigins(
      before.contentOrigins, editedFields: Set(fields.map(\.rawValue)),
      independent: after.independentContentOrigins)
    let snapshots = try categories.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
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
    category.applyContentOrigins(after.contentOrigins)
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
    let tags = try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>())
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
    var after = TagSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: updatedAt,
      content: content, contentOrigins: before.contentOrigins
    )
    after.contentOrigins = plannerEditedContentOrigins(
      before.contentOrigins, editedFields: Set(fields.map(\.rawValue)),
      independent: after.independentContentOrigins)
    let snapshots = try tags.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
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
    tag.applyContentOrigins(after.contentOrigins)
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
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
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
    var after = ListSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt,
      updatedAt: updatedAt,
      content: content, archived: archived, contentOrigins: before.contentOrigins
    )
    after.contentOrigins = plannerEditedContentOrigins(
      before.contentOrigins, editedFields: Set(fields.map(\.rawValue)),
      independent: after.independentContentOrigins)
    let snapshots = try lists.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
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
    if fields.contains(.manualEstimate) {
      list.manualEstimateData = try content.manualEstimate.map { try JSONEncoder().encode($0) }
    }
    list.archived = archived
    list.applyContentOrigins(after.contentOrigins)
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
    try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).map { try $0.value() }
  }

  private func itemEstimateSnapshots(
    _ context: ModelContext, itemIdentifiers: [UUID]? = nil
  ) throws -> [ContainerEstimateItemSnapshot] {
    var descriptor = FetchDescriptor<PlannerSchemaV18.Item>()
    if let itemIdentifiers {
      let optionalIdentifiers = itemIdentifiers.map(Optional.some)
      descriptor.predicate = #Predicate { optionalIdentifiers.contains($0.id) }
    }
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.estimateData, \.globalDone, \.archived]
    let snapshots = try context.fetch(descriptor).map { try $0.estimateSnapshot() }
    guard Set(snapshots.map(\.id)).count == snapshots.count else {
      throw PlannerFailure("readUnavailable", "Estimate Items have duplicate identities.")
    }
    return snapshots
  }

  private func listEstimateSnapshots(
    _ context: ModelContext, listIdentifiers: [UUID]? = nil
  ) throws -> [ContainerEstimateListSnapshot] {
    var descriptor = FetchDescriptor<PlannerSchemaV18.List>()
    if let listIdentifiers {
      let optionalIdentifiers = listIdentifiers.map(Optional.some)
      descriptor.predicate = #Predicate { optionalIdentifiers.contains($0.id) }
    }
    descriptor.propertiesToFetch = [\.id, \.lifetimeId, \.manualEstimateData, \.archived]
    let snapshots = try context.fetch(descriptor).map { try $0.estimateSnapshot() }
    guard Set(snapshots.map(\.id)).count == snapshots.count else {
      throw PlannerFailure("readUnavailable", "Estimate Lists have duplicate identities.")
    }
    return snapshots
  }

  private func membershipSnapshots(
    _ context: ModelContext, listIdentifiers: [UUID]? = nil
  ) throws -> [MembershipSnapshot] {
    var descriptor = FetchDescriptor<PlannerSchemaV18.Membership>()
    if let listIdentifiers {
      let optionalIdentifiers = listIdentifiers.map(Optional.some)
      descriptor.predicate = #Predicate { optionalIdentifiers.contains($0.listId) }
    }
    let snapshots = try context.fetch(descriptor).map {
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

  private func itineraryEntrySnapshots(
    _ context: ModelContext, itineraryIdentifiers: [UUID]? = nil
  ) throws -> [ItineraryEntrySnapshot] {
    var descriptor = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()
    if let itineraryIdentifiers {
      let optionalIdentifiers = itineraryIdentifiers.map(Optional.some)
      descriptor.predicate = #Predicate { optionalIdentifiers.contains($0.itineraryId) }
    }
    let entries = try context.fetch(descriptor).map {
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter {
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
    var descriptor = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>(
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
      entries: entries, contentOrigins: ownerSnapshot.contentOrigins
    )
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).map {
      if $0.id == itineraryId { return ownerAfter }
      return try $0.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
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
    var descriptor = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>(
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
      entries: ownerSnapshot.entries.filter { $0.id != entryId },
      contentOrigins: ownerSnapshot.contentOrigins
    )
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).map {
      if $0.id == itineraryId { return ownerAfter }
      return try $0.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let pendingRemovalMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .itineraryEntry(id: before.id, lifetimeId: before.lifetimeId), closedFamilyId: nil)
    let removalMarker = try closingRestorationFamilies([pendingRemovalMarker], context: context)[0]
    let markers = try deletionMarkers(context) + [removalMarker]
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)]
        + before.expandedCompletions.map { .reference($0.reference) })
    let removalProposalIdentifier = UUID()
    try archive.prepare(
      .init(
        proposalId: removalProposalIdentifier, originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    for completion in entry.expandedCompletions ?? [] { context.delete(completion) }
    context.delete(entry)
    try context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      do { try archive.discardPreparedProposal(removalProposalIdentifier) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The entry removal save failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
      throw PlannerFailure(
        "persistenceFailure",
        "The complete entry removal was not committed: \(error.localizedDescription)")
    }
    associationUndoSnapshots[operation.operationId] = .init(
      storeIdentity: identity, closingOperationId: operation.operationId, entry: before)
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
    let itineraries = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>())
    let owners = itineraries.filter { $0.id == itineraryId }
    guard owners.count == 1, let itinerary = owners.first else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let before = try itinerary.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
    let item: PlannerSchemaV18.Item?
    let list: PlannerSchemaV18.List?
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
      entries: entries, contentOrigins: before.contentOrigins
    )
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
      PlannerSchemaV18.ItineraryEntry(snapshot: entry, itinerary: itinerary, item: item, list: list)
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
      let evidence = try receipt.evidence()
      let digest = membershipCreationDigest(
        itemId: itemId, listId: listId, placement: placement, identity: identity,
        bindings: evidence.bindings, membershipEvidence: evidence.resolvedMembershipEvidence)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another addition.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: try RecoveryReceipt(receipt, checkpoint: nil),
        envelope: envelope)
    }
    let prepared = try archive.proposals().first { $0.originalOperationId == operation.operationId }
    if let prepared, let bindings = prepared.resolvedBindings,
      let membershipEvidence = prepared.resolvedMembershipEvidence
    {
      let digest = membershipCreationDigest(
        itemId: itemId, listId: listId, placement: placement, identity: identity,
        bindings: bindings, membershipEvidence: membershipEvidence)
      guard prepared.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another addition.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(prepared.summary))
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
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
    let resolvedPlacement = try resolveMembershipPlacement(
      placement, listId: listId, context: context)
    let insertionIndex = try associationInsertionIndex(resolvedPlacement, in: ordered)
    var bindings = [
      PlannerBoundIdentity(kind: "item", id: source.id, lifetimeId: source.lifetimeId),
      PlannerBoundIdentity(kind: "list", id: owner.id, lifetimeId: owner.lifetimeId),
    ]
    switch resolvedPlacement {
    case .before(let identifier), .after(let identifier):
      if let anchor = ordered.first(where: { $0.id == identifier }) {
        bindings.append(
          PlannerBoundIdentity(kind: "membership", id: anchor.id, lifetimeId: anchor.lifetimeId))
      }
    case .first, .last: break
    }
    if let proposal = prepared {
      let legacyDigest = membershipCreationDigest(
        itemId: itemId, listId: listId, placement: placement, identity: identity, bindings: bindings
      )
      guard proposal.payloadDigest == legacyDigest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another addition.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let existing = memberships.first { $0.item.id == itemId && $0.list.id == listId }
    let added: MembershipSnapshot?
    let evidenceMembership: MembershipSnapshot
    let reference: PlannerReferenceRead
    if let existing {
      added = nil
      evidenceMembership = existing
      reference = existing.reference
    } else {
      let rank = try associationInsertionRank(
        at: insertionIndex, ordered: ordered, associations: &memberships)
      let identifier = UUID()
      let membership = MembershipSnapshot(
        id: identifier, lifetimeId: identifier, list: bindings[1], item: bindings[0],
        rank: rank, localDone: false)
      added = membership
      evidenceMembership = membership
      reference = membership.reference
      memberships.append(membership)
    }
    let markers = try deletionMarkers(context)
    let lineage = try PlannerNativeLineage(context: context)
    let membershipEvidence: PlannerPortableMembershipProvenance
    if added != nil {
      membershipEvidence = try lineage.provenanceForNewMembership(
        evidenceMembership, markers: markers)
    } else {
      membershipEvidence =
        lineage.membershipProvenance.first {
          $0.membershipId == evidenceMembership.id
            && $0.membershipLifetimeId == evidenceMembership.lifetimeId
        } ?? evidenceMembership.baselineProvenance
    }
    let digest = membershipCreationDigest(
      itemId: itemId, listId: listId, placement: placement, identity: identity, bindings: bindings,
      membershipEvidence: [membershipEvidence])
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
        content: owner.content, archived: owner.archived, contentOrigins: owner.contentOrigins
      )
    }
    if added != nil, !membershipEvidence.observedRemovalIds.isEmpty {
      try plannerStageMembershipProvenance([membershipEvidence], context: context)
    }
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: try itinerarySnapshots(context),
        labelAssociations: try labelAssociationSnapshots(context), tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: itemSnapshots, lists: listSnapshots, memberships: memberships,
        deletionMarkers: markers),
      payloadDigest: digest, evidence: "preparedUnverified", resolvedBindings: bindings,
      resolvedMembershipEvidence: [membershipEvidence])
    try archive.prepare(proposal)
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    receipt.resultData = try JSONEncoder().encode(
      PlannerStoredOperationEvidence(
        result: result, bindings: bindings, resolvedMembershipEvidence: [membershipEvidence]))
    if let added {
      context.insert(PlannerSchemaV18.Membership(snapshot: added, list: list, item: item))
    }
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for record in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
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
      let evidence = try receipt.evidence()
      let digest = membershipRemovalDigest(
        listId: listId, membershipId: membershipId, identity: identity,
        bindings: evidence.bindings, membershipEvidence: evidence.resolvedMembershipEvidence)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another removal.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: try RecoveryReceipt(receipt, checkpoint: nil),
        envelope: envelope)
    }
    let prepared = try archive.proposals().first { $0.originalOperationId == operation.operationId }
    if let prepared, let bindings = prepared.resolvedBindings,
      let membershipEvidence = prepared.resolvedMembershipEvidence
    {
      let digest = membershipRemovalDigest(
        listId: listId, membershipId: membershipId, identity: identity,
        bindings: bindings, membershipEvidence: membershipEvidence)
      guard prepared.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another removal.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(prepared.summary))
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let record = try resolveMembership(
      listId: listId, membershipId: membershipId, context: context)
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
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
    let lineage = try PlannerNativeLineage(context: context)
    let removalProvenance =
      lineage.membershipProvenance.first {
        $0.membershipId == before.id && $0.membershipLifetimeId == before.lifetimeId
      }
      ?? PlannerPortableMembershipProvenance(
        membershipId: before.id, membershipLifetimeId: before.lifetimeId,
        list: .init(kind: .list, id: before.list.id, lifetimeId: before.list.lifetimeId),
        item: .init(kind: .item, id: before.item.id, lifetimeId: before.item.lifetimeId),
        observedRemovalIds: [])
    let digest = membershipRemovalDigest(
      listId: listId, membershipId: membershipId, identity: identity, bindings: bindings,
      membershipEvidence: [removalProvenance])
    if let proposal = prepared {
      let legacyDigest = membershipRemovalDigest(
        listId: listId, membershipId: membershipId, identity: identity, bindings: bindings)
      guard proposal.payloadDigest == legacyDigest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another removal.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let memberships = try membershipSnapshots(context).filter { $0.id != before.id }
    let ownerSnapshot = try owner.value()
    let updatedAt = Date()
    let itemSnapshots = try items.map { try $0.value() }
    let listSnapshots = try lists.map { list in
      if list.id != listId { return try list.value() }
      return ListSnapshot(
        id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
        createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt,
        content: ownerSnapshot.content, archived: ownerSnapshot.archived,
        contentOrigins: ownerSnapshot.contentOrigins
      )
    }
    let pendingRemovalMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .membership(membershipBinding), closedFamilyId: nil)
    let removalMarker = try closingRestorationFamilies([pendingRemovalMarker], context: context)[0]
    try plannerStageMembershipProvenance([removalProvenance], context: context)
    try plannerStageLineageRecord(
      PlannerPortableMembershipRemoval(deletionId: removalMarker.deletionId),
      identifier: removalMarker.deletionId, kind: "membershipRemoval",
      records: try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>()),
      context: context)
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
    let removalProposalIdentifier = UUID()
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: removalProposalIdentifier, originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: retainedItineraries,
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified", resolvedBindings: bindings,
        resolvedMembershipEvidence: [removalProvenance]))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    receipt.resultData = try JSONEncoder().encode(
      PlannerStoredOperationEvidence(
        result: result, bindings: bindings, resolvedMembershipEvidence: [removalProvenance]))
    for completion in expandedRecords { context.delete(completion) }
    context.delete(record)
    try context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
    owner.updatedAt = updatedAt
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      do { try archive.discardPreparedProposal(removalProposalIdentifier) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The membership removal save failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
      throw PlannerFailure(
        "persistenceFailure",
        "The complete membership removal was not committed: \(error.localizedDescription)")
    }
    associationUndoSnapshots[operation.operationId] = .init(
      storeIdentity: identity, closingOperationId: operation.operationId,
      membership: before, expandedStates: expandedSnapshots)
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

  private func executeAssociationRestoration(
    _ operation: PlannerOperation, snapshot: PlannerAssociationUndoSnapshot,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    let digest = snapshot.restorationDigest
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let evidence = try RecoveryReceipt(receipt, checkpoint: nil)
      guard evidence.datasetId == identity.datasetId,
        evidence.ownershipBinding == identity.ownershipBinding,
        receipt.payloadDigest == digest
      else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another restoration.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: evidence, envelope: envelope)
    }
    let recoveredIdentifiers = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { recoveredIdentifiers.contains($0) } ?? false })
    else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    guard snapshot.datasetId == identity.datasetId,
      snapshot.ownershipBinding == identity.ownershipBinding,
      associationUndoSnapshots[snapshot.closingOperationId]?.issuanceIdentifier
        == snapshot.issuanceIdentifier
    else {
      throw PlannerFailure(
        "associationUndoUnavailable", "This removal can no longer be undone in this app run.")
    }
    let current = try importReviewSnapshot(context).backup
    let graph = PlannerImportGraph(backup: current)
    guard
      current.deletionMarkers.contains(where: {
        $0.operationId == snapshot.closingOperationId
          && $0.target.importIdentity == snapshot.identity
      }), graph.liveIdentity(for: snapshot.identity) == nil,
      !current.restorationFamilies.contains(where: { $0.predecessor == snapshot.identity })
    else {
      throw PlannerFailure(
        "associationUndoUnavailable", "Newer relationship history prevents restoring this removal.")
    }
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another restoration.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let lifetimeIdentifier = UUID()
    let restoredReference: PlannerReferenceRead
    let ownerReference: PlannerEntityReference
    let bindings: [PlannerBoundIdentity]
    var restoredExpandedReferences: [PlannerReferenceRead] = []
    var restoredItineraryIdentifiers: Set<UUID> = []
    var additionalReferences: [PlannerReferenceRead] = []
    var additionalSources: [PlannerEntityReference] = []
    var additionalBindings: [PlannerBoundIdentity] = []
    var additionalRestorationFamilies: [PlannerPortableRestorationFamily] = []
    switch snapshot.originalRecord {
    case .ownedAssociationGroup(let group):
      let staged = try stageOwnedAssociationUndo(
        group, closingOperationId: snapshot.closingOperationId, operationId: operation.operationId,
        primary: snapshot.identity, primaryLifetime: lifetimeIdentifier,
        current: current, context: context)
      guard let first = staged.references.first else {
        throw PlannerFailure("associationUndoUnavailable", "This removal group is empty.")
      }
      restoredReference = first
      ownerReference = group.owner.reference
      bindings = staged.bindings
      additionalReferences = Array(staged.references.dropFirst())
      additionalRestorationFamilies = staged.families.filter { $0.predecessor != snapshot.identity }
    case .membership, .membershipMove:
      guard let original = snapshot.originalRecord.membership else {
        throw PlannerFailure(
          "associationUndoUnavailable", "The original membership is unavailable.")
      }
      var destinationRemoval: PlannerSchemaV18.Membership?
      if case .membershipMove(let move) = snapshot.originalRecord {
        destinationRemoval = try validatedMoveUndoDestination(
          move, current: current, context: context)
      }
      let memberships = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
      guard
        !memberships.contains(where: {
          $0.id == original.id
            || ($0.listId == original.list.id && $0.listLifetimeId == original.listLifetimeId
              && $0.itemId == original.item.id && $0.itemLifetimeId == original.itemLifetimeId)
        })
      else {
        throw PlannerFailure(
          "associationUndoUnavailable", "A newer membership is already using this Item and List.")
      }
      let owners = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).filter {
        $0.id == original.list.id && $0.lifetimeId == original.listLifetimeId
      }
      let sources = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter {
        $0.id == original.item.id && $0.lifetimeId == original.itemLifetimeId
      }
      guard owners.count == 1, let owner = owners.first,
        sources.count == 1, let source = sources.first
      else {
        throw PlannerFailure(
          "associationUndoUnavailable", "The original Item or List is no longer available.")
      }
      let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
      var expandedEntries:
        [(state: PlannerPortableExpandedCompletion, entry: PlannerSchemaV18.ItineraryEntry)] = []
      for state in snapshot.originalExpandedStates {
        let matches = entries.filter {
          $0.id == state.context.listEntryId && $0.lifetimeId == state.context.listEntryLifetimeId
            && $0.sourceKind == "list" && $0.sourceId == original.list.id
            && $0.sourceLifetimeId == original.listLifetimeId
        }
        guard state.context.membershipId == original.id,
          state.context.membershipLifetimeId == original.lifetimeId,
          matches.count == 1, let entry = matches.first
        else {
          throw PlannerFailure(
            "associationUndoUnavailable", "An original Itinerary entry is no longer available.")
        }
        _ = try entry.value()
        expandedEntries.append((state, entry))
      }
      if let destinationRemoval {
        let removed = try destinationRemoval.value()
        let marker = PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .membership(
            .init(kind: "membership", id: removed.id, lifetimeId: removed.lifetimeId)),
          closedFamilyId: nil)
        let closed = try closingRestorationFamilies([marker], context: context)[0]
        try context.insert(PlannerSchemaV4.DeletionMarker(closed))
        for completion in destinationRemoval.expandedCompletions ?? [] {
          context.delete(completion)
        }
        context.delete(destinationRemoval)
        let destinationOwners = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).filter {
          $0.id == removed.list.id && $0.lifetimeId == removed.list.lifetimeId
        }
        for destinationOwner in destinationOwners { destinationOwner.updatedAt = Date() }
        additionalReferences.append(removed.reference)
        additionalSources.append(.init(kind: .list, id: removed.list.id))
        additionalBindings.append(
          .init(kind: "membership", id: removed.id, lifetimeId: removed.lifetimeId))
        additionalBindings.append(removed.list)
        restoredItineraryIdentifiers.formUnion(
          current.itineraryEntries.filter {
            $0.source.kind == .list && $0.source.id == removed.list.id
              && $0.sourceLifetimeId == removed.list.lifetimeId
          }.map { $0.itinerary.id })
      }
      let restored = MembershipSnapshot(
        id: original.id, lifetimeId: lifetimeIdentifier,
        list: .init(kind: "list", id: original.list.id, lifetimeId: original.listLifetimeId),
        item: .init(kind: "item", id: original.item.id, lifetimeId: original.itemLifetimeId),
        rank: original.rank, localDone: original.localDone)
      let provenance = try PlannerNativeLineage(context: context)
        .provenanceForNewMembership(restored, markers: deletionMarkers(context))
      try plannerStageMembershipProvenance([provenance], context: context)
      let membership = PlannerSchemaV18.Membership(snapshot: restored, list: owner, item: source)
      context.insert(membership)
      for (state, entry) in expandedEntries {
        let entrySnapshot = try entry.value()
        context.insert(
          PlannerSchemaV18.ExpandedCompletion(
            listEntry: entry, membership: membership, localDone: state.localDone))
        restoredExpandedReferences.append(
          .expandedCompletion(
            itineraryId: entrySnapshot.itinerary.id, listEntryId: entrySnapshot.id,
            membershipId: original.id))
        restoredItineraryIdentifiers.insert(entrySnapshot.itinerary.id)
      }
      owner.updatedAt = Date()
      restoredReference = restored.reference
      ownerReference = original.list
      bindings = [
        .init(kind: "membership", id: original.id, lifetimeId: original.lifetimeId),
        restored.list, restored.item,
      ]
    case .itineraryEntry(let original):
      let owners = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).filter {
        $0.id == original.itinerary.id && $0.lifetimeId == original.itineraryLifetimeId
      }
      let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter {
        $0.id == original.source.id && $0.lifetimeId == original.sourceLifetimeId
      }
      let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).filter {
        $0.id == original.source.id && $0.lifetimeId == original.sourceLifetimeId
      }
      guard owners.count == 1, let owner = owners.first,
        (original.source.kind == .item && items.count == 1)
          || (original.source.kind == .list && lists.count == 1)
      else {
        throw PlannerFailure(
          "associationUndoUnavailable", "The original Itinerary or source is no longer available.")
      }
      let memberships = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
      var expandedMemberships:
        [(state: PlannerPortableExpandedCompletion, membership: PlannerSchemaV18.Membership)] = []
      for state in snapshot.originalExpandedStates {
        let matches = memberships.filter {
          $0.id == state.context.membershipId
            && $0.lifetimeId == state.context.membershipLifetimeId
            && $0.listId == original.source.id && $0.listLifetimeId == original.sourceLifetimeId
        }
        guard original.source.kind == .list,
          state.context.listEntryId == original.id,
          state.context.listEntryLifetimeId == original.lifetimeId,
          matches.count == 1, let membership = matches.first
        else {
          throw PlannerFailure(
            "associationUndoUnavailable", "An original List membership is no longer available.")
        }
        expandedMemberships.append((state, membership))
      }
      let restored = ItineraryEntrySnapshot(
        id: original.id, lifetimeId: lifetimeIdentifier,
        itinerary: .init(
          kind: "itinerary", id: original.itinerary.id, lifetimeId: original.itineraryLifetimeId),
        source: .init(
          kind: original.source.kind.rawValue, id: original.source.id,
          lifetimeId: original.sourceLifetimeId), rank: original.rank, localDone: original.localDone
      )
      let entry = PlannerSchemaV18.ItineraryEntry(
        snapshot: restored, itinerary: owner,
        item: original.source.kind == .item ? items.first : nil,
        list: original.source.kind == .list ? lists.first : nil)
      context.insert(entry)
      for (state, membership) in expandedMemberships {
        context.insert(
          PlannerSchemaV18.ExpandedCompletion(
            listEntry: entry, membership: membership, localDone: state.localDone))
        restoredExpandedReferences.append(
          .expandedCompletion(
            itineraryId: original.itinerary.id, listEntryId: original.id,
            membershipId: state.context.membershipId))
      }
      owner.updatedAt = Date()
      restoredReference = restored.reference
      ownerReference = original.itinerary
      bindings = [
        .init(kind: "itineraryEntry", id: original.id, lifetimeId: original.lifetimeId),
        restored.itinerary, restored.source,
      ]
    }
    let family = PlannerPortableRestorationFamily(
      familyId: plannerRestorationFamilyIdentifier(snapshot.identity),
      predecessor: snapshot.identity,
      candidates: [.init(lifetimeId: lifetimeIdentifier, operationId: operation.operationId)])
    for restoredFamily in [family] + additionalRestorationFamilies {
      try plannerStageLineageRecord(
        restoredFamily, identifier: restoredFamily.familyId, kind: "restorationFamily",
        records: context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>()), context: context)
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let itineraries = try itinerarySnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let memberships = try membershipSnapshots(context)
    let markers = try deletionMarkers(context)
    let lineage = try PlannerNativeLineage(context: context)
    let restorationProposalIdentifier = UUID()
    try archive.prepare(
      .init(
        proposalId: restorationProposalIdentifier, originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: .init(
          itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
          contextAliases: lineage.contextAliases, completionChanges: lineage.completionChanges,
          restorationFamilies: lineage.restorationFamilies,
          membershipProvenance: lineage.membershipProvenance,
          membershipRemovals: lineage.membershipRemovals),
        payloadDigest: digest, evidence: "preparedUnverified"))
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(restoredReference), .source(ownerReference)]
        + additionalReferences.map { .reference($0) }
        + additionalSources.map { .source($0) }
        + restoredExpandedReferences.map { .reference($0) }
        + restoredItineraryIdentifiers.sorted { $0.uuidString < $1.uuidString }.map {
          .source(.init(kind: .itinerary, id: $0))
        })
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings + additionalBindings)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      do { try archive.discardPreparedProposal(restorationProposalIdentifier) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The restoration save failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
      throw PlannerFailure(
        "persistenceFailure",
        "The association restoration was not committed: \(error.localizedDescription)")
    }
    do {
      let generation = try archive.publish(
        itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
        items: items, lists: lists, memberships: memberships, deletionMarkers: markers,
        contextAliases: lineage.contextAliases, completionChanges: lineage.completionChanges,
        restorationFamilies: lineage.restorationFamilies,
        membershipProvenance: lineage.membershipProvenance,
        membershipRemovals: lineage.membershipRemovals, receipts: receipts + [receipt])
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

  private func validatedMoveUndoDestination(
    _ move: PlannerMembershipMoveUndoRecord, current: PlannerPortableBackup, context: ModelContext
  ) throws -> PlannerSchemaV18.Membership? {
    guard let expected = move.createdDestinationMembership else { return nil }
    let destinationEntries = current.itineraryEntries.filter {
      $0.source.kind == .list && $0.source.id == expected.list.id
        && $0.sourceLifetimeId == expected.listLifetimeId
    }.map {
      PlannerPortableBoundIdentity(kind: .itineraryEntry, id: $0.id, lifetimeId: $0.lifetimeId)
    }
    let expanded = current.expandedCompletions.filter {
      $0.context.membershipId == expected.id
        && $0.context.membershipLifetimeId == expected.lifetimeId
    }.sorted { $0.context.orderingKey < $1.context.orderingKey }
    guard current.memberships.filter({ $0.id == expected.id }) == [expected],
      Set(destinationEntries) == Set(move.destinationEntries),
      expanded == move.destinationExpandedStates
    else {
      throw PlannerFailure(
        "associationUndoUnavailable",
        "Newer destination relationship changes prevent undoing this Move.")
    }
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).filter {
      $0.id == expected.id && $0.lifetimeId == expected.lifetimeId
    }
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure(
        "associationUndoUnavailable", "The Move destination is no longer available.")
    }
    return record
  }

  private func membershipRemovalDigest(
    listId: UUID, membershipId: UUID, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity],
    membershipEvidence: [PlannerPortableMembershipProvenance]? = nil
  ) -> String {
    var fields: [String: PlannerCanonicalValue] = [
      "command": .record([
        "type": .string("removeMembership"), "listId": .identity(listId),
        "membershipId": .identity(membershipId),
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ]
    var version: UInt8 = 1
    if let membershipEvidence {
      version = 3
      fields["resolvedMembershipEvidence"] = .ordered(
        plannerSortedMembershipEvidence(membershipEvidence).map(\.operationCanonicalValue))
    }
    let bytes =
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, version])
      + PlannerCanonicalValue.record(fields).encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v\(version):")
  }

  private func executeMembershipMove(
    _ operation: PlannerOperation, listId: UUID, membershipId: UUID,
    destinationListId: UUID, placement: PlannerPlacement,
    identity: PlannerStoreIdentity, context: ModelContext, archive: PlannerRecoveryArchive,
    receipts: [PlannerSchemaV1.Receipt], envelope: RecoveryEnvelope?
  ) throws -> PlannerOperationResult {
    if let receipt = receipts.first(where: { $0.operationId == operation.operationId }) {
      let evidence = try receipt.evidence()
      let digest = membershipMoveDigest(
        listId: listId, membershipId: membershipId, destinationListId: destinationListId,
        placement: placement, identity: identity, bindings: evidence.bindings,
        membershipEvidence: evidence.resolvedMembershipEvidence)
      guard receipt.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "This operation identity describes another move.")
      }
      return appliedResult(
        operationId: operation.operationId, evidence: try RecoveryReceipt(receipt, checkpoint: nil),
        envelope: envelope)
    }
    let prepared = try archive.proposals().first { $0.originalOperationId == operation.operationId }
    if let prepared, let bindings = prepared.resolvedBindings,
      let membershipEvidence = prepared.resolvedMembershipEvidence
    {
      let digest = membershipMoveDigest(
        listId: listId, membershipId: membershipId, destinationListId: destinationListId,
        placement: placement, identity: identity, bindings: bindings,
        membershipEvidence: membershipEvidence)
      guard prepared.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another move.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(prepared.summary))
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
    let record = try resolveMembership(
      listId: listId, membershipId: membershipId, context: context)
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
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
    let resolvedPlacement = try resolveMembershipPlacement(
      placement, listId: destinationListId, context: context)
    let insertionIndex = try associationInsertionIndex(resolvedPlacement, in: ordered)
    let existing = ordered.first {
      $0.item.id == before.item.id && $0.item.lifetimeId == before.item.lifetimeId
    }
    var bindings = [membershipBinding, before.list, before.item, destinationBinding]
    if let existing {
      bindings.append(
        PlannerBoundIdentity(kind: "membership", id: existing.id, lifetimeId: existing.lifetimeId))
    }
    switch resolvedPlacement {
    case .before(let identifier), .after(let identifier):
      if let anchor = ordered.first(where: { $0.id == identifier }) {
        bindings.append(
          PlannerBoundIdentity(kind: "membership", id: anchor.id, lifetimeId: anchor.lifetimeId))
      }
    case .first, .last: break
    }
    if let proposal = prepared {
      let legacyDigest = membershipMoveDigest(
        listId: listId, membershipId: membershipId, destinationListId: destinationListId,
        placement: placement, identity: identity, bindings: bindings)
      guard proposal.payloadDigest == legacyDigest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another move.")
      }
      return PlannerOperationResult(
        operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    memberships.removeAll { $0.id == before.id }
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
    let knownMarkers = try deletionMarkers(context)
    let lineage = try PlannerNativeLineage(context: context)
    let originProvenance =
      lineage.membershipProvenance.first {
        $0.membershipId == before.id && $0.membershipLifetimeId == before.lifetimeId
      } ?? before.baselineProvenance
    guard let destinationMembership = existing ?? added else {
      throw PlannerFailure("readUnavailable", "The Move destination membership is unavailable.")
    }
    let destinationProvenance: PlannerPortableMembershipProvenance
    if added != nil {
      destinationProvenance = try lineage.provenanceForNewMembership(
        destinationMembership, markers: knownMarkers)
    } else {
      destinationProvenance =
        lineage.membershipProvenance.first {
          $0.membershipId == destinationMembership.id
            && $0.membershipLifetimeId == destinationMembership.lifetimeId
        } ?? destinationMembership.baselineProvenance
    }
    let membershipEvidence = plannerSortedMembershipEvidence([
      originProvenance, destinationProvenance,
    ])
    let digest = membershipMoveDigest(
      listId: listId, membershipId: membershipId, destinationListId: destinationListId,
      placement: placement, identity: identity, bindings: bindings,
      membershipEvidence: membershipEvidence)
    let updatedAt = Date()
    let listSnapshots = try lists.map { list in
      if list.id == listId {
        return ListSnapshot(
          id: ownerSnapshot.id, lifetimeId: ownerSnapshot.lifetimeId,
          createdAt: ownerSnapshot.createdAt, updatedAt: updatedAt,
          content: ownerSnapshot.content, archived: ownerSnapshot.archived,
          contentOrigins: ownerSnapshot.contentOrigins
        )
      }
      if list.id == destinationListId, added != nil {
        return ListSnapshot(
          id: destinationSnapshot.id, lifetimeId: destinationSnapshot.lifetimeId,
          createdAt: destinationSnapshot.createdAt, updatedAt: updatedAt,
          content: destinationSnapshot.content, archived: destinationSnapshot.archived,
          contentOrigins: destinationSnapshot.contentOrigins
        )
      }
      return try list.value()
    }
    let itemSnapshots = try items.map { try $0.value() }
    let pendingRemovalMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .membership(membershipBinding), closedFamilyId: nil)
    let removalMarker = try closingRestorationFamilies([pendingRemovalMarker], context: context)[0]
    try plannerStageMembershipProvenance(membershipEvidence, context: context)
    try plannerStageLineageRecord(
      PlannerPortableMembershipRemoval(deletionId: removalMarker.deletionId),
      identifier: removalMarker.deletionId, kind: "membershipRemoval",
      records: try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>()),
      context: context)
    let markers = knownMarkers + [removalMarker]
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
    let moveProposalIdentifier = UUID()
    try archive.prepare(
      RecoveryPreparedProposal(
        proposalId: moveProposalIdentifier, originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: retainedItineraries,
          labelAssociations: try labelAssociationSnapshots(context),
          tags: try tagSnapshots(context), categories: try categorySnapshots(context),
          items: itemSnapshots, lists: listSnapshots, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified", resolvedBindings: bindings,
        resolvedMembershipEvidence: membershipEvidence))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    receipt.resultData = try JSONEncoder().encode(
      PlannerStoredOperationEvidence(
        result: result, bindings: bindings, resolvedMembershipEvidence: membershipEvidence))
    for completion in expandedRecords { context.delete(completion) }
    context.delete(record)
    if let added {
      context.insert(PlannerSchemaV18.Membership(snapshot: added, list: destination, item: source))
    }
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
      if let identifier = membership.id, let rank = ranks[identifier], membership.rank != rank {
        membership.rank = rank
      }
    }
    owner.updatedAt = updatedAt
    if added != nil { destination.updatedAt = updatedAt }
    try context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      do { try archive.discardPreparedProposal(moveProposalIdentifier) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The Move save failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
      throw PlannerFailure(
        "persistenceFailure",
        "The complete membership move was not committed: \(error.localizedDescription)")
    }
    let destinationEntries = retainedItineraries.flatMap(\.entries).filter {
      $0.source.kind == "list" && $0.source.id == destinationSnapshot.id
        && $0.source.lifetimeId == destinationSnapshot.lifetimeId
    }
    associationUndoSnapshots[operation.operationId] = .init(
      storeIdentity: identity, closingOperationId: operation.operationId,
      move: .init(
        original: before, createdDestination: added, destinationEntries: destinationEntries),
      expandedStates: expandedSnapshots)
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
    identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity],
    membershipEvidence: [PlannerPortableMembershipProvenance]? = nil
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
    var fields: [String: PlannerCanonicalValue] = [
      "command": .record([
        "type": .string("moveMembership"), "listId": .identity(listId),
        "membershipId": .identity(membershipId), "destinationListId": .identity(destinationListId),
        "placement": placementValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ]
    var version: UInt8 = 1
    if let membershipEvidence {
      version = 3
      fields["resolvedMembershipEvidence"] = .ordered(
        plannerSortedMembershipEvidence(membershipEvidence).map(\.operationCanonicalValue))
    }
    let bytes =
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, version])
      + PlannerCanonicalValue.record(fields).encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v\(version):")
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
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      let bindings = try proposal.contextualBindings(for: operation.command)
      let digest = membershipReorderingDigest(
        listId: listId, membershipId: membershipId, placement: placement, identity: identity,
        bindings: bindings)
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another contextual action.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
    }
    let completedIds = Set(envelope?.receipts.map(\.operationId) ?? [])
    guard receipts.allSatisfy({ $0.operationId.map { completedIds.contains($0) } ?? false }) else {
      throw PlannerFailure(
        "mutationBlocked", "A prior applied action still needs independent recovery.")
    }
    let record = try resolveMembership(
      listId: listId, membershipId: membershipId, context: context)
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
    let owners = lists.filter { $0.id == before.list.id && $0.lifetimeId == before.list.lifetimeId }
    let sources = items.filter {
      $0.id == before.item.id && $0.lifetimeId == before.item.lifetimeId
    }
    guard owners.count == 1, let owner = owners.first, sources.count == 1 else {
      throw PlannerFailure(
        "missingReference", "The membership's Item or List lifetime is unresolved.")
    }
    let resolvedPlacement = try resolveMembershipPlacement(
      placement, listId: listId, context: context)
    switch resolvedPlacement {
    case .before(let identifier), .after(let identifier):
      guard identifier != before.id else {
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
    let remaining = ordered.filter { $0.id != before.id }
    let insertionIndex = try associationInsertionIndex(resolvedPlacement, in: remaining)
    var desiredOrder = remaining.map(\.id)
    desiredOrder.insert(before.id, at: insertionIndex)
    let changed = desiredOrder != ordered.map(\.id)
    var bindings = [
      PlannerBoundIdentity(kind: "membership", id: before.id, lifetimeId: before.lifetimeId),
      before.list, before.item,
    ]
    switch resolvedPlacement {
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
    if changed {
      let rank = try associationInsertionRank(
        at: insertionIndex, ordered: remaining, associations: &memberships)
      guard let selectedIndex = memberships.firstIndex(where: { $0.id == before.id }) else {
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
        content: ownerSnapshot.content, archived: ownerSnapshot.archived,
        contentOrigins: ownerSnapshot.contentOrigins
      )
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
        payloadDigest: digest, evidence: "preparedUnverified", resolvedBindings: bindings,
        resolvedMembershipEvidence: []))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    let ranks = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.rank) })
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
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

  private func resolveMembershipPlacement(
    _ placement: PlannerPlacement, listId: UUID, context: ModelContext
  ) throws -> PlannerPlacement {
    let identifier: UUID
    switch placement {
    case .first, .last: return placement
    case .before(let anchor), .after(let anchor): identifier = anchor
    }
    let resolved: PlannerSchemaV18.Membership
    do {
      resolved = try resolveMembership(listId: listId, membershipId: identifier, context: context)
    } catch let failure as PlannerFailure where failure.code == "missingReference" {
      throw PlannerFailure(
        "missingReference", "The placement anchor is not in the destination container.",
        propertyPath: "/command/placement/associationId")
    }
    guard let canonicalIdentifier = resolved.id else {
      throw PlannerFailure("readUnavailable", "The resolved membership has no identity.")
    }
    switch placement {
    case .before: return .before(associationId: canonicalIdentifier)
    case .after: return .after(associationId: canonicalIdentifier)
    case .first, .last: return placement
    }
  }

  private func resolveMembership(
    listId: UUID, membershipId: UUID, context: ModelContext
  ) throws -> PlannerSchemaV18.Membership {
    let missing = PlannerFailure(
      "missingReference", "The selected membership is missing or unresolved.")
    var descriptor = FetchDescriptor<PlannerSchemaV18.Membership>(
      predicate: #Predicate { $0.id == membershipId })
    descriptor.fetchLimit = 2
    let direct = try context.fetch(descriptor)
    if !direct.isEmpty {
      guard direct.count == 1, let record = direct.first, record.listId == listId else {
        throw missing
      }
      return record
    }
    let lineage = try PlannerNativeLineage(context: context)
    let aliases = lineage.contextAliases.filter {
      $0.context.importContextIdentities.contains {
        $0.kind == .membership && $0.id == membershipId
      }
    }
    guard !aliases.isEmpty else { throw missing }
    let backup = try maintenanceSnapshot(context).validated().backup
    let canonical = try PlannerImportGraph(backup: backup).resolvedMembershipForAction(
      listIdentifier: listId, membershipIdentifier: membershipId)
    let identifier = canonical.id
    var canonicalDescriptor = FetchDescriptor<PlannerSchemaV18.Membership>(
      predicate: #Predicate { $0.id == identifier })
    canonicalDescriptor.fetchLimit = 2
    let records = try context.fetch(canonicalDescriptor)
    guard records.count == 1, let record = records.first,
      record.lifetimeId == canonical.lifetimeId, record.listId == listId
    else { throw missing }
    return record
  }

  private func resolveExpandedAppearance(
    itineraryId: UUID, listEntryId: UUID, membershipId: UUID,
    context: ModelContext
  ) throws -> (entry: PlannerSchemaV18.ItineraryEntry, membership: PlannerSchemaV18.Membership) {
    var entryDescriptor = FetchDescriptor<PlannerSchemaV18.ItineraryEntry>(
      predicate: #Predicate {
        $0.id == listEntryId && $0.itineraryId == itineraryId && $0.sourceKind == "list"
      })
    entryDescriptor.fetchLimit = 2
    let entries = try context.fetch(entryDescriptor)
    guard entries.count == 1, let entry = entries.first else {
      throw PlannerFailure(
        "missingReference", "The expanded itinerary appearance is missing or unresolved.")
    }
    let entryBinding = try entry.value()
    let membership = try resolveMembership(
      listId: entryBinding.source.id, membershipId: membershipId, context: context)
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
      }, contentOrigins: ownerSnapshot.contentOrigins
    )
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).map {
      itinerary in
      if itinerary.id == itineraryId { return ownerAfter }
      return try itinerary.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(after.reference), .source(ownerSnapshot.reference)])
    try PlannerNativeLineage(context: context).recordCompletionAssertions(
      [(.expandedListItem(binding), previous?.localDone ?? false)], done: done, context: context)
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels,
          tags: tags, categories: categories, items: items, lists: lists, memberships: memberships,
          deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified", resolvedBindings: bindings,
        resolvedMembershipEvidence: []))
    let receipt = try PlannerSchemaV1.Receipt(
      operation: operation, digest: digest, result: result, bindings: bindings)
    let existing = (records.entry.expandedCompletions ?? []).first {
      $0.membershipId == membership.id && $0.membershipLifetimeId == membership.lifetimeId
    }
    if let existing {
      existing.localDone = done
    } else if done {
      context.insert(
        PlannerSchemaV18.ExpandedCompletion(
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
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).filter {
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
      }, contentOrigins: ownerSnapshot.contentOrigins
    )
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).map {
      itinerary in
      if itinerary.id == itineraryId { return ownerAfter }
      return try itinerary.value()
    }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)])
    try PlannerNativeLineage(context: context).recordCompletionAssertions(
      [
        (
          .directItineraryItem(entryId: before.id, entryLifetimeId: before.lifetimeId),
          before.localDone ?? false
        )
      ],
      done: done, context: context)
    try archive.prepare(
      .init(
        proposalId: UUID(), originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: snapshots, labelAssociations: labels,
          tags: tags, categories: categories, items: items, lists: lists, memberships: memberships,
          deletionMarkers: markers), payloadDigest: digest, evidence: "preparedUnverified",
        resolvedBindings: bindings, resolvedMembershipEvidence: []))
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

  private struct ItineraryDeletionResolution {
    let record: PlannerSchemaV18.Itinerary
    let snapshot: ItinerarySnapshot
    let entries: [ItineraryEntrySnapshot]
    let associations: [LabelAssociationSnapshot]
    let expanded: [ExpandedCompletionSnapshot]
    let expandedBindings: [PlannerBoundIdentity]
    let entryRecords: [PlannerSchemaV18.ItineraryEntry]
    let associationRecords: [PlannerSchemaV18.LabelAssociation]
    let linkRecords: [PlannerSchemaV18.OwnedLink]
    let scheduleRecords: [PlannerSchemaV18.Schedule]
    let expandedRecords: [PlannerSchemaV18.ExpandedCompletion]

    var source: PlannerBoundIdentity {
      .init(kind: "itinerary", id: snapshot.id, lifetimeId: snapshot.lifetimeId)
    }

    var bindings: [PlannerBoundIdentity] {
      [source]
        + snapshot.links.map { .init(kind: "ownedLink", id: $0.id, lifetimeId: $0.lifetimeId) }
        + snapshot.schedules.map { .init(kind: "schedule", id: $0.id, lifetimeId: $0.lifetimeId) }
        + entries.flatMap {
          [.init(kind: "itineraryEntry", id: $0.id, lifetimeId: $0.lifetimeId), $0.source]
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
        + entries.map(\.reference) + expanded.map(\.reference)
    }

    var sourceDeletes: [PlannerEntityReference] {
      [snapshot.reference]
        + snapshot.schedules.sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .init(kind: .schedule, id: $0.id)
        }
    }
  }

  private func resolveItineraryDeletion(_ source: PlannerEntityReference, context: ModelContext)
    throws -> ItineraryDeletionResolution
  {
    let identifier = source.id
    var descriptor = FetchDescriptor<PlannerSchemaV18.Itinerary>(
      predicate: #Predicate { $0.id == identifier })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let snapshot = try record.value()
    let entries = try itineraryEntrySnapshots(context).filter { $0.itinerary.id == identifier }
      .sorted { $0.id.uuidString < $1.id.uuidString }
    let associations = try labelAssociationSnapshots(context).filter {
      $0.owner.kind == "itinerary" && $0.owner.id == identifier
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    let entryRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).filter
    {
      $0.itineraryId == identifier
    }
    let associationRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>())
      .filter { $0.ownerKind == "itinerary" && $0.ownerId == identifier }
    let linkRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()).filter {
      $0.ownerKind == "itinerary" && $0.ownerId == identifier
    }
    let scheduleRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()).filter {
      $0.sourceKind == "itinerary" && $0.sourceId == identifier
    }
    let links = try linkRecords.map {
      try $0.value(
        ownerId: identifier, ownerLifetimeId: snapshot.lifetimeId, ownerKind: "itinerary")
    }
    let schedules = try scheduleRecords.map {
      try $0.value(
        ownerId: identifier, ownerLifetimeId: snapshot.lifetimeId, ownerKind: "itinerary")
    }
    guard entries.allSatisfy({ $0.itinerary.lifetimeId == snapshot.lifetimeId }),
      associations.allSatisfy({ $0.owner.lifetimeId == snapshot.lifetimeId }),
      Set(entries.map(\.id)) == Set(snapshot.entries.map(\.id)),
      entryRecords.count == entries.count,
      Set(associations.map(\.id)) == Set(snapshot.labelAssociations.map(\.id)),
      associationRecords.count == associations.count,
      links.count == snapshot.links.count, Set(links.map(\.id)) == Set(snapshot.links.map(\.id)),
      schedules.count == snapshot.schedules.count,
      Set(schedules.map(\.id)) == Set(snapshot.schedules.map(\.id))
    else {
      throw PlannerFailure(
        "readUnavailable", "The Itinerary's complete deletion closure is unresolved.")
    }
    let entryIdentifiers = Set(entries.map(\.id))
    let expandedRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>())
      .filter { $0.listEntryId.map(entryIdentifiers.contains) == true }
    let expanded = try expandedRecords.map { try $0.value() }.sorted {
      $0.context.orderingKey < $1.context.orderingKey
    }
    let expectedContexts = entries.flatMap(\.expandedCompletions)
    guard Set(expanded.map(\.context)).count == expanded.count,
      Set(expanded.map(\.context)) == Set(expectedContexts.map(\.context)),
      expanded.count == entryRecords.flatMap({ $0.expandedCompletions ?? [] }).count
    else {
      throw PlannerFailure(
        "readUnavailable", "The Itinerary's expanded completion contexts are unresolved.")
    }
    let memberships = try membershipSnapshots(context)
    let expandedBindings = try expanded.flatMap { completion -> [PlannerBoundIdentity] in
      guard
        let membership = memberships.first(where: {
          $0.id == completion.context.membershipId
            && $0.lifetimeId == completion.context.membershipLifetimeId
        })
      else {
        throw PlannerFailure(
          "readUnavailable", "An expanded completion's membership is unresolved.")
      }
      return [
        .init(kind: "membership", id: membership.id, lifetimeId: membership.lifetimeId),
        membership.list, membership.item,
      ]
    }
    return .init(
      record: record, snapshot: snapshot, entries: entries, associations: associations,
      expanded: expanded, expandedBindings: expandedBindings, entryRecords: entryRecords,
      associationRecords: associationRecords, linkRecords: linkRecords,
      scheduleRecords: scheduleRecords, expandedRecords: expandedRecords)
  }

  private func executeItineraryDeletion(
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
    let resolution = try resolveItineraryDeletion(source, context: context)
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
    let removedAssociationIdentifiers = Set(resolution.associations.map(\.id))
    let itineraries = try itinerarySnapshots(context).filter { $0.id != source.id }
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let labels = try labelAssociationSnapshots(context).filter {
      !removedAssociationIdentifiers.contains($0.id)
    }
    let categories = try categorySnapshots(context)
    let tags = try tagSnapshots(context)
    let pendingNewMarkers =
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
      + resolution.snapshot.links.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .ownedLink(id: $0.id, lifetimeId: $0.lifetimeId), closedFamilyId: nil)
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
    let newMarkers = try closingRestorationFamilies(pendingNewMarkers, context: context)
    let markers = try deletionMarkers(context) + newMarkers
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: resolution.sourceDeletes.map { .source($0) }
        + resolution.removals.map { .reference($0) })
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
    for marker in newMarkers { try context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
    for record in resolution.expandedRecords { context.delete(record) }
    for record in resolution.entryRecords { context.delete(record) }
    for record in resolution.associationRecords { context.delete(record) }
    for record in resolution.linkRecords { context.delete(record) }
    for record in resolution.scheduleRecords { context.delete(record) }
    context.delete(resolution.record)
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Itinerary deletion was not committed: \(error.localizedDescription)")
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

  private struct ListDeletionResolution {
    let record: PlannerSchemaV18.List
    let snapshot: ListSnapshot
    let memberships: [MembershipSnapshot]
    let entries: [ItineraryEntrySnapshot]
    let expanded: [ExpandedCompletionSnapshot]
    let membershipRecords: [PlannerSchemaV18.Membership]
    let entryRecords: [PlannerSchemaV18.ItineraryEntry]
    let expandedRecords: [PlannerSchemaV18.ExpandedCompletion]

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
    var descriptor = FetchDescriptor<PlannerSchemaV18.List>(
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
    let membershipRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).filter
    {
      $0.listId == identifier
    }
    let entryRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).filter
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
    let expandedRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>())
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
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
        entries: value.entries.filter { !removedEntryIdentifiers.contains($0.id) },
        contentOrigins: value.contentOrigins
      )
    }
    let pendingNewMarkers =
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
    let newMarkers = try closingRestorationFamilies(pendingNewMarkers, context: context)
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
    for marker in newMarkers { try context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
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
    let record: PlannerSchemaV18.Item
    let snapshot: ItemSnapshot
    let memberships: [MembershipSnapshot]
    let entries: [ItineraryEntrySnapshot]
    let associations: [LabelAssociationSnapshot]
    let membershipRecords: [PlannerSchemaV18.Membership]
    let entryRecords: [PlannerSchemaV18.ItineraryEntry]
    let associationRecords: [PlannerSchemaV18.LabelAssociation]
    let linkRecords: [PlannerSchemaV18.OwnedLink]
    let scheduleRecords: [PlannerSchemaV18.Schedule]
    let expandedRecords: [PlannerSchemaV18.ExpandedCompletion]
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
    var descriptor = FetchDescriptor<PlannerSchemaV18.Item>(
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
    let membershipRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).filter
    { $0.itemId == identifier }
    let entryRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).filter
    { $0.sourceKind == "item" && $0.sourceId == identifier }
    let associationRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>())
      .filter { $0.ownerKind == "item" && $0.ownerId == identifier }
    let linkRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()).filter {
      $0.ownerKind == "item" && $0.ownerId == identifier
    }
    let scheduleRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()).filter {
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
    let expandedRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>())
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter {
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
    let listRecords = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
    let lists = try listRecords.map { record in
      let value = try record.value()
      guard affectedListIds.contains(value.id) else { return value }
      return ListSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: updatedAt, content: value.content, archived: value.archived,
        contentOrigins: value.contentOrigins
      )
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
        labelAssociations: value.labelAssociations, labels: value.labels, entries: entries,
        contentOrigins: value.contentOrigins
      )
    }
    let pendingNewMarkers =
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
      + resolution.snapshot.links.map {
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .ownedLink(id: $0.id, lifetimeId: $0.lifetimeId), closedFamilyId: nil)
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
    let newMarkers = try closingRestorationFamilies(pendingNewMarkers, context: context)
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
    for marker in newMarkers { try context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
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
    case category(PlannerSchemaV18.Category)
    case tag(PlannerSchemaV18.Tag)

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
    let records: [PlannerSchemaV18.LabelAssociation]
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
      var descriptor = FetchDescriptor<PlannerSchemaV18.Category>(
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
      var descriptor = FetchDescriptor<PlannerSchemaV18.Tag>(
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
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()).filter {
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { record in
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
        labels: value.labels.filter { $0.reference != source }, contentOrigins: value.contentOrigins
      )
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
        labels: value.labels.filter { $0.reference != source }, entries: value.entries,
        contentOrigins: value.contentOrigins
      )
    }
    let lists = try listSnapshots(context)
    let memberships = try membershipSnapshots(context)
    let sourceMarker = PortableDeletionMarker(
      deletionId: UUID(), operationId: operation.operationId,
      target: .source(resolution.source),
      closedFamilyId: nil)
    let pendingNewMarkers =
      [sourceMarker]
      + resolution.associations.map { association in
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .labelAssociation(id: association.id, lifetimeId: association.lifetimeId),
          closedFamilyId: nil)
      }
    let newMarkers = try closingRestorationFamilies(pendingNewMarkers, context: context)
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
    for marker in newMarkers { try context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
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
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      let bindings = try proposal.contextualBindings(for: operation.command)
      let digest = bulkCompletionDigest(
        scope: scope, done: done, identity: identity, bindings: bindings)
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another contextual action.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
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
    let changed = resolution.targets.contains { $0.localDone != done }
    let lists = try listSnapshots(context).map { value in
      guard resolution.list != nil, value.id == resolution.owner.id else { return value }
      return ListSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt,
        updatedAt: changed ? Date() : value.updatedAt, content: value.content,
        archived: value.archived, contentOrigins: value.contentOrigins
      )
    }
    let itineraries = try itinerarySnapshots(context).map { value in
      guard resolution.itinerary != nil, value.id == resolution.owner.id else { return value }
      return resolution.itineraryAfter(
        value, done: done, updatedAt: changed ? Date() : value.updatedAt)
    }
    let memberships = resolution.membershipsAfter(try membershipSnapshots(context), done: done)
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() }
    let labels = try labelAssociationSnapshots(context)
    let tags = try tagSnapshots(context)
    let categories = try categorySnapshots(context)
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.source(resolution.reference)]
        + resolution.targets.map { .reference($0.reference) })
    let proposalIdentifier = UUID()
    let completionAssertions = resolution.targets.map {
      (context: $0.completionContext, initialDone: $0.localDone)
    }
    try PlannerNativeLineage(context: context).recordCompletionAssertions(
      completionAssertions, done: done, context: context)
    try archive.prepare(
      .init(
        proposalId: proposalIdentifier, originalOperationId: operation.operationId,
        datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
        proposedBackup: PlannerDataSnapshot(
          itineraries: itineraries, labelAssociations: labels, tags: tags, categories: categories,
          items: items, lists: lists, memberships: memberships, deletionMarkers: markers),
        payloadDigest: digest, evidence: "preparedUnverified", resolvedBindings: bindings,
        resolvedMembershipEvidence: []))
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
      do { try archive.discardPreparedProposal(proposalIdentifier) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The bulk save failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
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
    if let proposal = try archive.proposals().first(where: {
      $0.originalOperationId == operation.operationId
    }) {
      let bindings = try proposal.contextualBindings(for: operation.command)
      let digest = appearanceCompletionDigest(
        appearance: appearance, done: done, identity: identity, bindings: bindings)
      guard proposal.payloadDigest == digest else {
        throw PlannerFailure(
          "operationPayloadMismatch", "Prepared evidence describes another contextual action.")
      }
      return .init(operationId: operation.operationId, outcome: .unverified(proposal.summary))
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
    let record = try resolveMembership(
      listId: listId, membershipId: membershipId, context: context)
    let before = try record.value()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let lists = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>())
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
        content: ownerSnapshot.content, archived: ownerSnapshot.archived,
        contentOrigins: ownerSnapshot.contentOrigins
      )
    }
    let markers = try deletionMarkers(context)
    let result = PlannerAppliedResult(
      generatedIdentities: [],
      affectedIdentities: [.reference(before.reference), .source(ownerSnapshot.reference)])
    try PlannerNativeLineage(context: context).recordCompletionAssertions(
      [
        (
          .listMembership(membershipId: before.id, membershipLifetimeId: before.lifetimeId),
          before.localDone
        )
      ],
      done: done, context: context)
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
        payloadDigest: digest, evidence: "preparedUnverified", resolvedBindings: bindings,
        resolvedMembershipEvidence: []))
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
    bindings: [PlannerBoundIdentity],
    membershipEvidence: [PlannerPortableMembershipProvenance]? = nil
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
    var fields: [String: PlannerCanonicalValue] = [
      "command": .record([
        "type": .string("addMembership"), "itemId": .identity(itemId), "listId": .identity(listId),
        "placement": placementValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ]
    var version: UInt8 = 1
    if let membershipEvidence {
      version = 3
      fields["resolvedMembershipEvidence"] = .ordered(
        plannerSortedMembershipEvidence(membershipEvidence).map(\.operationCanonicalValue))
    }
    let bytes =
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, version])
      + PlannerCanonicalValue.record(fields).encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v\(version):")
  }

  private func deletionMarkers(_ context: ModelContext) throws -> [PortableDeletionMarker] {
    try context.fetch(FetchDescriptor<PlannerSchemaV4.DeletionMarker>()).map { try $0.value() }
      + PlannerNativeLineage(context: context).deletionMarkers
  }

  private func closingRestorationFamilies(
    _ markers: [PortableDeletionMarker], context: ModelContext
  ) throws -> [PortableDeletionMarker] {
    let families = try PlannerNativeLineage(context: context).restorationFamilies
    return try markers.map { try $0.closingRestorationFamily(families) }
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
    var assignments = FetchDescriptor<PlannerSchemaV18.Schedule>(
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
    let pendingRemovalMarker: PortableDeletionMarker?
    if replacementForm == nil {
      pendingRemovalMarker = PortableDeletionMarker(
        deletionId: UUID(), operationId: operation.operationId,
        target: .source(
          PlannerBoundIdentity(kind: "schedule", id: before.id, lifetimeId: before.lifetimeId)),
        closedFamilyId: nil)
    } else {
      pendingRemovalMarker = nil
    }
    let removalMarker = try closingRestorationFamilies(
      [pendingRemovalMarker].compactMap { $0 }, context: context
    ).first
    let markers = try deletionMarkers(context) + [removalMarker].compactMap { $0 }
    let snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { item in
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
      try context.insert(PlannerSchemaV4.DeletionMarker(removalMarker))
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
    var snapshots = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map {
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
    let itineraries = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>())
    let matches = itineraries.filter { $0.id == sourceId }
    guard matches.count == 1, let itinerary = matches.first else {
      throw PlannerFailure("missingReference", "The selected Itinerary is missing or unresolved.")
    }
    let before = try itinerary.value()
    var selectedCategories: [PlannerSchemaV18.Category] = []
    var selectedTags: [PlannerSchemaV18.Tag] = []
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
    let updatedLinkIdentifiers = Set(updatedLinks.map(\.id))
    let removedLinks = before.links.filter { !updatedLinkIdentifiers.contains($0.id) }
    let pendingRemovalMarkers =
      removed.map { association in
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .labelAssociation(id: association.id, lifetimeId: association.lifetimeId),
          closedFamilyId: nil)
      }
      + removedLinks.map { link in
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .ownedLink(id: link.id, lifetimeId: link.lifetimeId), closedFamilyId: nil)
      }
    let removalMarkers = try closingRestorationFamilies(pendingRemovalMarkers, context: context)
    let markers = try deletionMarkers(context) + removalMarkers
    let associations =
      try labelAssociationSnapshots(context).filter {
        $0.owner.kind != "itinerary" || $0.owner.id != before.id
          || $0.owner.lifetimeId != before.lifetimeId
      } + updatedAssociations
    var after = ItinerarySnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt, updatedAt: now,
      input: updatedInput, archived: before.archived,
      links: updatedLinks, schedules: before.schedules,
      labelAssociations: updatedAssociations, labels: updatedLabels, entries: before.entries,
      contentOrigins: before.contentOrigins
    )
    after.contentOrigins = plannerEditedContentOrigins(
      before.contentOrigins, editedFields: Set(changedFields.map(\.rawValue)),
      independent: after.independentContentOrigins)
    let snapshots = try itineraries.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let previousLinkIdentifiers = Set(before.links.map(\.id))
    let generatedLinks = updatedLinks.filter { !previousLinkIdentifiers.contains($0.id) }.map {
      PlannerAppliedIdentity.reference(.ownedLink(id: $0.id, owner: before.reference))
    }
    let result = PlannerAppliedResult(
      generatedIdentities: added.map { .reference($0.reference) } + generatedLinks,
      affectedIdentities: [.source(before.reference)]
        + (removed + added).sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .reference($0.reference)
        } + removedLinks.map { .reference(.ownedLink(id: $0.id, owner: before.reference)) }
        + generatedLinks)
    let proposal = RecoveryPreparedProposal(
      proposalId: UUID(), originalOperationId: operation.operationId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding,
      proposedBackup: PlannerDataSnapshot(
        itineraries: snapshots,
        labelAssociations: associations, tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
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
    if changedFields.contains(.manualEstimate) {
      itinerary.manualEstimateData = try updatedInput.manualEstimate.map {
        try JSONEncoder().encode($0)
      }
    }
    if changedFields.contains(.links) {
      try itinerary.replaceLinks(with: updatedLinks, context: context)
    }
    if !changes.changedLabelKinds.isEmpty {
      try itinerary.replaceLabelAssociations(
        with: updatedAssociations, categories: selectedCategories, tags: selectedTags,
        context: context)
    }
    for marker in removalMarkers { try context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
    itinerary.applyContentOrigins(after.contentOrigins)
    itinerary.updatedAt = now
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      do { try archive.discardPreparedProposal(proposal.proposalId) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The Itinerary edit failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Itinerary edit was not committed: \(error.localizedDescription)")
    }
    associationUndoSnapshots[operation.operationId] = .init(
      storeIdentity: identity, closingOperationId: operation.operationId,
      group: .init(
        owner: .init(kind: .itinerary, id: before.id, lifetimeId: before.lifetimeId),
        originalLinks: before.links, removedLinks: removedLinks, removedLabels: removed))
    do {
      let generation = try archive.publish(
        itineraries: snapshots,
        labelAssociations: associations, tags: try tagSnapshots(context),
        categories: try categorySnapshots(context),
        items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let matches = items.filter { $0.id == sourceId }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure("missingReference", "The selected Item is missing or unresolved.")
    }
    let before = try item.value()
    var selectedCategories: [PlannerSchemaV18.Category] = []
    var selectedTags: [PlannerSchemaV18.Tag] = []
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
    let updatedLinkIdentifiers = Set(updatedLinks.map(\.id))
    let removedLinks = before.links.filter { !updatedLinkIdentifiers.contains($0.id) }
    let pendingRemovalMarkers =
      removed.map { association in
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .labelAssociation(id: association.id, lifetimeId: association.lifetimeId),
          closedFamilyId: nil)
      }
      + removedLinks.map { link in
        PortableDeletionMarker(
          deletionId: UUID(), operationId: operation.operationId,
          target: .ownedLink(id: link.id, lifetimeId: link.lifetimeId), closedFamilyId: nil)
      }
    let removalMarkers = try closingRestorationFamilies(pendingRemovalMarkers, context: context)
    let markers = try deletionMarkers(context) + removalMarkers
    let associations =
      try labelAssociationSnapshots(context).filter {
        $0.owner.kind != "item" || $0.owner.id != before.id
          || $0.owner.lifetimeId != before.lifetimeId
      } + updatedAssociations
    var after = ItemSnapshot(
      id: before.id, lifetimeId: before.lifetimeId, createdAt: before.createdAt, updatedAt: now,
      input: updatedInput, globalDone: before.globalDone, archived: before.archived,
      links: updatedLinks, schedules: before.schedules,
      labelAssociations: updatedAssociations, labels: updatedLabels,
      contentOrigins: before.contentOrigins
    )
    after.contentOrigins = plannerEditedContentOrigins(
      before.contentOrigins, editedFields: Set(changedFields.map(\.rawValue)),
      independent: after.independentContentOrigins)
    let snapshots = try items.map { record in
      if record.id == sourceId { return after }
      return try record.value()
    }
    let previousLinkIdentifiers = Set(before.links.map(\.id))
    let generatedLinks = updatedLinks.filter { !previousLinkIdentifiers.contains($0.id) }.map {
      PlannerAppliedIdentity.reference(.ownedLink(id: $0.id, owner: before.reference))
    }
    let result = PlannerAppliedResult(
      generatedIdentities: added.map { .reference($0.reference) } + generatedLinks,
      affectedIdentities: [.source(before.reference)]
        + (removed + added).sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .reference($0.reference)
        } + removedLinks.map { .reference(.ownedLink(id: $0.id, owner: before.reference)) }
        + generatedLinks)
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
    for marker in removalMarkers { try context.insert(PlannerSchemaV4.DeletionMarker(marker)) }
    item.applyContentOrigins(after.contentOrigins)
    item.updatedAt = now
    context.insert(receipt)
    do { try context.save() } catch {
      context.rollback()
      do { try archive.discardPreparedProposal(proposal.proposalId) } catch {
        throw PlannerFailure(
          "persistenceFailure",
          "The Item edit failed and its prepared evidence could not be cleared. Resolve operation status before retrying."
        )
      }
      throw PlannerFailure(
        "persistenceFailure",
        "The complete Item edit was not committed: \(error.localizedDescription)")
    }
    associationUndoSnapshots[operation.operationId] = .init(
      storeIdentity: identity, closingOperationId: operation.operationId,
      group: .init(
        owner: .init(kind: .item, id: before.id, lifetimeId: before.lifetimeId),
        originalLinks: before.links, removedLinks: removedLinks, removedLabels: removed))
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
    let itineraries = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>())
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
      labelAssociations: before.labelAssociations, labels: before.labels, entries: before.entries,
      contentOrigins: before.contentOrigins
    )
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
        items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
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
        items: try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.value() },
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
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
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
      labelAssociations: before.labelAssociations, labels: before.labels,
      contentOrigins: before.contentOrigins
    )
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
      identity.schemaVersion == 19
    else {
      throw PlannerFailure("staleDatasetSession", "The dataset session is no longer authorized.")
    }
    return identity
  }

  private func openContainer(initializing: Bool = false) throws -> ModelContainer {
    guard initializing || FileManager.default.fileExists(atPath: configuration.storeURL.path) else {
      nativeContainer = nil
      throw PlannerFailure(
        "unavailable", "The initialized dataset's store is missing; recovery remains separate.")
    }
    if let nativeContainer, let identity = try nativeStoreFileIdentity(),
      nativeContainer.fileNumber == identity.fileNumber,
      nativeContainer.systemNumber == identity.systemNumber
    {
      return nativeContainer.container
    }
    nativeContainer = nil
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let modelConfiguration = ModelConfiguration(
      schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self, configurations: [modelConfiguration])
    if let identity = try nativeStoreFileIdentity() {
      nativeContainer = (container, identity.fileNumber, identity.systemNumber)
    }
    return container
  }

  private func nativeStoreFileIdentity() throws -> (fileNumber: UInt64, systemNumber: UInt64)? {
    guard FileManager.default.fileExists(atPath: configuration.storeURL.path) else { return nil }
    let attributes = try FileManager.default.attributesOfItem(atPath: configuration.storeURL.path)
    guard let fileNumber = attributes[.systemFileNumber] as? NSNumber,
      let systemNumber = attributes[.systemNumber] as? NSNumber
    else {
      throw PlannerFailure("readUnavailable", "The native store file identity is unresolved.")
    }
    return (fileNumber.uint64Value, systemNumber.uint64Value)
  }

  private func recoveryArchive(
    _ identity: PlannerStoreIdentity, context: ModelContext? = nil
  ) -> PlannerRecoveryArchive {
    PlannerRecoveryArchive(
      rootURL: configuration.recoveryDirectoryURL, identity: identity, nativeContext: context)
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
        (1...19).contains(identity.schemaVersion), !identity.ownershipBinding.isEmpty
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
