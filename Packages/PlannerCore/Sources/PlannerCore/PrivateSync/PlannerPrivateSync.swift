import CloudKit
import Foundation

/// A single private-database engine; local data and transport state commit through Core.
actor PlannerPrivateSync: CKSyncEngineDelegate {
  struct Binding: Sendable {
    let containerIdentifier: String
    let directory: URL
    let ownershipBinding: String
  }
  struct Client: Sendable {
    let load: @Sendable () async throws -> PlannerPrivateSyncState?
    let nodes: @Sendable () async throws -> [PlannerCloudNode]
    let persist:
      @Sendable (PlannerPrivateSyncState, PlannerCloudGraph.Changes?) async throws
        -> PlannerPrivateSyncPersistence
    let status: @Sendable (PlannerCloudObservation) async -> Void
    let accountChanged: @Sendable () async -> Void
  }

  private let client: Client
  private var state: PlannerPrivateSyncState
  private var lease: PlannerPrivateSyncLease?
  private var engine: CKSyncEngine?
  private var tail: Task<Void, Never>?
  private var networkTask: Task<Void, Never>?
  private var networkRequested = false
  private var sentNodes: [String: PlannerCloudNode] = [:]
  private var valid = true
  private var sendFailure: PlannerFailure?
  private var fetching = false
  private var sending = false
  private enum PersistenceState { case ready, reloadRequired, reloading }
  private var persistenceState = PersistenceState.ready

  private init(client: Client, state: PlannerPrivateSyncState, lease: PlannerPrivateSyncLease) {
    self.client = client
    self.state = state
    self.lease = lease
  }

  static func start(
    binding: Binding, client: Client
  ) async throws -> PlannerPrivateSync? {
    guard let lease = try PlannerPrivateSyncLease(directory: binding.directory) else { return nil }
    let state = try await client.load() ?? .init(ownershipBinding: binding.ownershipBinding)
    try state.validated(binding: binding.ownershipBinding)
    let worker = PlannerPrivateSync(client: client, state: state, lease: lease)
    await worker.initialize(
      database: CKContainer(identifier: binding.containerIdentifier).privateCloudDatabase)
    return worker
  }

  private func initialize(database: CKDatabase) async {
    let configuration = CKSyncEngine.Configuration(
      database: database,
      stateSerialization: state.serialization, delegate: self)
    engine = CKSyncEngine(configuration)
    if !state.zoneCreated {
      engine?.state.add(pendingDatabaseChanges: [
        .saveZone(CKRecordZone(zoneID: PlannerCloudNode.zoneID))
      ])
    }
    await localDataChanged()
    scheduleNetwork()
  }

  func stop() async {
    valid = false
    networkTask?.cancel()
    await engine?.cancelOperations()
    engine = nil
    lease = nil
  }

  func requestSync() async {
    guard valid else { return }
    if persistenceState == .reloading { return }
    if persistenceState == .reloadRequired {
      await reload()
      return
    }
    sendFailure = nil
    await localDataChanged()
    scheduleNetwork()
  }

  func localDataChanged() async {
    do {
      let changed = try await ordered { [self] in
        guard await isValid else { return false }
        try await finishIncoming()
        return try await enqueueLocalChanges()
      }
      if changed { scheduleNetwork() }
    } catch { await report(error) }
  }

  /// Failed inbox/state writes must not advance the engine beyond durable data.
  private func reload() async {
    guard let previous = engine else { return }
    persistenceState = .reloading
    defer {
      if persistenceState == .reloading { persistenceState = .reloadRequired }
    }
    networkRequested = false
    let previousNetwork = networkTask
    previousNetwork?.cancel()
    await previous.cancelOperations()
    await previousNetwork?.value
    await tail?.value
    guard valid else { return }
    do {
      let saved = try await client.load() ?? state
      try saved.validated(binding: state.ownershipBinding)
      guard valid else { return }
      state = saved
      engine = nil
      sentNodes.removeAll()
      fetching = false
      sending = false
      persistenceState = .ready
      sendFailure = nil
      await initialize(database: previous.database)
    } catch { await report(error) }
  }

  private var isValid: Bool { valid && persistenceState == .ready }

  /// Delegate events and local observations share one transaction queue across actor suspension.
  private func ordered<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
  ) async throws -> Value {
    let previous = tail
    let task = Task {
      await previous?.value
      return try await operation()
    }
    tail = Task { _ = try? await task.value }
    return try await task.value
  }

  func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
    guard valid, engine === syncEngine else { return }
    if case .accountChange(let change) = event {
      if case .signIn(let user) = change.changeType, matchesUser(user.recordName) {
        guard isValid else { return }
        if !state.zoneCreated {
          syncEngine.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: PlannerCloudNode.zoneID))
          ])
        }
        Task { await self.localDataChanged() }
        return
      }
      valid = false
      networkTask?.cancel()
      await client.accountChanged()
      Task { await self.stop() }
      return
    }
    guard isValid else { return }
    do {
      try await ordered { [self] in try await receive(event, engine: syncEngine) }
    } catch {
      if case .fetchedRecordZoneChanges = event { persistenceState = .reloadRequired }
      await report(error)
    }
  }

  private func matchesUser(_ recordName: String) -> Bool {
    let components = state.ownershipBinding.split(separator: ":")
    guard components.count == 3, components[0] == "private-cloud-v1" else { return false }
    let owner = plannerDigest(
      PlannerCanonicalValue.ordered([.string(String(components[1])), .string(recordName)])
        .encoded(), prefix: "")
    return owner == components[2]
  }

  private func receive(_ event: CKSyncEngine.Event, engine: CKSyncEngine) async throws {
    guard isValid else { return }
    switch event {
    case .stateUpdate(let update):
      var next = state
      next.serialization = update.stateSerialization
      try await persist(next)
    case .fetchedRecordZoneChanges(let changes):
      var next = state
      for modification in changes.modifications
      where modification.record.recordID.zoneID == PlannerCloudNode.zoneID {
        let node = try PlannerCloudNode(record: modification.record)
        next.incomingRecords[node.name] = try PlannerCloudNode.archive(modification.record)
        next.incomingDeletions.remove(node.name)
      }
      for deletion in changes.deletions where deletion.recordID.zoneID == PlannerCloudNode.zoneID {
        let name = deletion.recordID.recordName
        next.incomingRecords.removeValue(forKey: name)
        next.incomingDeletions.insert(name)
      }
      try await persist(next)
    case .didFetchChanges:
      fetching = false
      try await finishIncoming()
      if try await enqueueLocalChanges(), sendFailure == nil { scheduleNetwork() }
      await publishStatus()
    case .sentDatabaseChanges(let changes):
      if changes.savedZones.contains(where: { $0.zoneID == PlannerCloudNode.zoneID }) {
        var next = state
        next.zoneCreated = true
        try await persist(next)
      }
      for failure in changes.failedZoneSaves { await report(failure.error) }
    case .sentRecordZoneChanges(let changes):
      try await acceptSent(changes, engine: engine)
    case .fetchedDatabaseChanges(let changes):
      if state.zoneCreated
        && changes.deletions.contains(where: { $0.zoneID == PlannerCloudNode.zoneID })
      {
        sendFailure = .init(
          "privateCloudZoneRemoved",
          "The private cloud data area was removed. Local plans are preserved.")
        await publishStatus()
      }
    case .willFetchChanges:
      if sendFailure?.code == "privateSyncUnavailable" { sendFailure = nil }
      fetching = true
      await publishStatus()
    case .willSendChanges:
      if sendFailure?.code == "privateSyncUnavailable" { sendFailure = nil }
      sending = true
      await publishStatus()
    case .didSendChanges:
      sending = false
      if try await enqueueLocalChanges(), sendFailure == nil { scheduleNetwork() }
      await publishStatus()
    case .didFetchRecordZoneChanges(let result):
      if result.zoneID == PlannerCloudNode.zoneID, let error = result.error {
        await report(error)
      }
    default: break
    }
  }

  private func acceptSent(
    _ changes: CKSyncEngine.Event.SentRecordZoneChanges, engine: CKSyncEngine
  ) async throws {
    var next = state
    var acknowledged: [PlannerCloudNode] = []
    var bases: [String: PlannerCloudNode] = [:]
    var retryConflicts = false
    for record in changes.savedRecords {
      let node = try PlannerCloudNode(record: record)
      let previous = try state.serverRecords[node.name].map(PlannerCloudNode.restore)
      if let previous, let previousDate = previous.modificationDate,
        previousDate >= (record.modificationDate ?? .distantPast),
        previous.recordChangeTag != record.recordChangeTag
      {
        sentNodes.removeValue(forKey: node.name)
        continue
      }
      if let sent = sentNodes.removeValue(forKey: node.name) {
        bases[node.name] = sent
      } else if let previous {
        bases[node.name] = try PlannerCloudNode(record: previous)
      }
      acknowledged.append(node)
      next.serverRecords[node.name] = try PlannerCloudNode.archive(record)
      if let incoming = try next.incomingRecords[node.name].map(PlannerCloudNode.restore),
        (incoming.modificationDate ?? .distantPast) < (record.modificationDate ?? .distantPast)
      {
        next.incomingRecords.removeValue(forKey: node.name)
      }
    }
    for identifier in changes.deletedRecordIDs {
      next.serverRecords.removeValue(forKey: identifier.recordName)
    }
    for failure in changes.failedRecordSaves {
      switch failure.error.code {
      case .serverRecordChanged:
        guard let server = failure.error.serverRecord else { throw failure.error }
        next.incomingRecords[server.recordID.recordName] = try PlannerCloudNode.archive(server)
        retryConflicts = true
      case .unknownItem:
        next.incomingDeletions.insert(failure.record.recordID.recordName)
        engine.state.remove(pendingRecordZoneChanges: [.saveRecord(failure.record.recordID)])
        retryConflicts = true
      case .zoneNotFound where !state.zoneCreated:
        engine.state.add(pendingDatabaseChanges: [
          .saveZone(CKRecordZone(zoneID: PlannerCloudNode.zoneID))
        ])
        retryConflicts = true
      case .batchRequestFailed:
        break
      default:
        await report(failure.error)
      }
    }
    for error in changes.failedRecordDeletes.values { await report(error) }
    try await persist(
      next,
      applying: .init(
        upserts: acknowledged,
        deletions: Set(changes.deletedRecordIDs.map(\.recordName)), bases: bases))
    if retryConflicts, sendFailure == nil {
      // Conflicts join a complete fetch before relationship validation.
      scheduleNetwork()
    }
  }

  private func finishIncoming() async throws {
    guard isValid else { return }
    guard !state.incomingRecords.isEmpty || !state.incomingDeletions.isEmpty else {
      try await persist(state)
      return
    }
    var next = state
    let records = try next.incomingRecords.values.map(PlannerCloudNode.restore)
    let nodes = try records.map(PlannerCloudNode.init(record:))
    var bases: [String: PlannerCloudNode] = [:]
    for node in nodes {
      if let data = state.serverRecords[node.name] {
        bases[node.name] = try PlannerCloudNode(record: PlannerCloudNode.restore(data))
      }
    }
    for (name, data) in next.incomingRecords { next.serverRecords[name] = data }
    for name in next.incomingDeletions { next.serverRecords.removeValue(forKey: name) }
    let changes = PlannerCloudGraph.Changes(
      upserts: nodes, deletions: next.incomingDeletions, bases: bases)
    next.incomingRecords.removeAll()
    next.incomingDeletions.removeAll()
    try await persist(next, applying: changes)
  }

  private func enqueueLocalChanges() async throws -> Bool {
    guard isValid, let engine else { return false }
    let nodes = try await client.nodes()
    guard isValid else { return false }
    let local = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
    var changes: [CKSyncEngine.PendingRecordZoneChange] = []
    for node in nodes where !state.incomingDeletions.contains(node.name) {
      let previous = try state.serverRecords[node.name].map {
        try PlannerCloudNode(record: PlannerCloudNode.restore($0))
      }
      if node != previous {
        changes.append(.saveRecord(.init(recordName: node.name, zoneID: PlannerCloudNode.zoneID)))
      }
    }
    for name in state.serverRecords.keys where local[name] == nil {
      changes.append(.deleteRecord(.init(recordName: name, zoneID: PlannerCloudNode.zoneID)))
    }
    let pending = Set(engine.state.pendingRecordZoneChanges)
    let additions = changes.filter { !pending.contains($0) }
    if !additions.isEmpty { engine.state.add(pendingRecordZoneChanges: additions) }
    return !changes.isEmpty
  }

  func nextRecordZoneChangeBatch(
    _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.RecordZoneChangeBatch? {
    guard isValid, engine === syncEngine else { return nil }
    do {
      return try await ordered { [self] in try await batch(context, engine: syncEngine) }
    } catch {
      await report(error)
      return nil
    }
  }

  private func batch(
    _ context: CKSyncEngine.SendChangesContext, engine: CKSyncEngine
  ) async throws -> CKSyncEngine.RecordZoneChangeBatch? {
    guard isValid, sendFailure == nil else { return nil }
    let nodes = try await client.nodes()
    guard isValid else { return nil }
    let local = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
    let pending = engine.state.pendingRecordZoneChanges.filter {
      context.options.scope.contains($0)
    }.prefix(200)
    var saves: [CKRecord] = []
    var deletions: [CKRecord.ID] = []
    for change in pending {
      switch change {
      case .saveRecord(let identifier):
        if let node = local[identifier.recordName], !state.incomingDeletions.contains(node.name) {
          sentNodes[node.name] = node
          saves.append(
            try node.record(base: state.serverRecords[node.name].map(PlannerCloudNode.restore)))
        } else {
          engine.state.remove(pendingRecordZoneChanges: [change])
        }
      case .deleteRecord(let identifier):
        if local[identifier.recordName] == nil {
          deletions.append(identifier)
        } else {
          engine.state.remove(pendingRecordZoneChanges: [change])
        }
      @unknown default: break
      }
    }
    if saves.isEmpty && deletions.isEmpty { return nil }
    return .init(recordsToSave: saves, recordIDsToDelete: deletions, atomicByZone: true)
  }

  private func persist(
    _ next: PlannerPrivateSyncState, applying changes: PlannerCloudGraph.Changes? = nil
  ) async throws {
    guard isValid else { throw CancellationError() }
    let result: PlannerPrivateSyncPersistence
    do {
      result = try await client.persist(next, changes)
    } catch {
      if case nil = changes {
        persistenceState = .reloadRequired
      } else if next.incomingRecords.contains(where: { state.incomingRecords[$0.key] != $0.value })
        || !next.incomingDeletions.isSubset(of: state.incomingDeletions)
      {
        persistenceState = .reloadRequired
      }
      throw error
    }
    guard valid else { return }
    state = next
    if case .recoveryIncomplete(let reason) = result {
      sendFailure = reason
      await publishStatus()
    } else if sendFailure?.code == "privateSyncRecoveryIncomplete" {
      sendFailure = nil
    }
  }

  private func scheduleNetwork() {
    guard isValid else { return }
    if networkTask != nil {
      networkRequested = true
      return
    }
    networkTask = Task { [weak self] in await self?.synchronize() }
  }

  private func synchronize() async {
    defer {
      networkTask = nil
      if networkRequested {
        networkRequested = false
        scheduleNetwork()
      }
    }
    guard isValid, let engine else { return }
    do { try await engine.fetchChanges() } catch {
      await report(error)
    }
    guard isValid, !Task.isCancelled, sendFailure == nil else { return }
    do {
      try await engine.sendChanges(.init(scope: .zoneIDs([PlannerCloudNode.zoneID])))
      if isValid, !Task.isCancelled { try await engine.fetchChanges() }
    } catch { await report(error) }
  }

  private func report(_ error: any Error) async {
    guard valid else { return }
    if let error = error as? CKError {
      switch error.code {
      case .quotaExceeded:
        sendFailure = .init(
          "privateCloudStorageFull",
          "Private iCloud storage is full. New saves remain on this device.")
      case .zoneNotFound where !state.zoneCreated:
        return
      case .zoneNotFound, .userDeletedZone:
        sendFailure = .init(
          "privateCloudZoneRemoved",
          "The private cloud data area is unavailable. Local plans are preserved.")
      case .networkFailure, .networkUnavailable, .notAuthenticated,
        .accountTemporarilyUnavailable, .requestRateLimited, .serviceUnavailable,
        .zoneBusy, .operationCancelled, .serverResponseLost:
        sendFailure = .init(
          "privateSyncUnavailable",
          "Private synchronization is unavailable (CloudKit \(error.errorCode)). Local plans are preserved."
        )
      default:
        sendFailure = .init(
          "privateSyncNeedsAttention",
          "Private synchronization needs attention (CloudKit \(error.errorCode)). Local plans are preserved; correct the problem, then try Sync now."
        )
      }
    } else if let reason = error as? PlannerFailure {
      sendFailure = reason
    } else {
      sendFailure = .init(
        "privateSyncUnavailable",
        "Private synchronization could not finish. Local plans are preserved.")
    }
    await publishStatus()
  }

  private func publishStatus() async {
    let activity: PlannerCloudObservation.State
    if sendFailure != nil {
      activity = .error
    } else if fetching || sending || engine?.state.pendingRecordZoneChanges.isEmpty == false
      || engine?.state.pendingDatabaseChanges.isEmpty == false
    {
      activity = .inProgress
    } else {
      activity = .idle
    }
    await client.status(
      .init(
        state: activity, storeIdentity: state.ownershipBinding, eventId: UUID().uuidString,
        observedAt: .now, reason: sendFailure))
  }
}
