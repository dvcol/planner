import CloudKit
import Foundation

/// A single private-database engine; local data and transport state commit through Core.
actor PlannerPrivateSync: CKSyncEngineDelegate {
  struct Binding: Sendable {
    let containerIdentifier: String
    let directory: URL
    let ownershipBinding: String
    var library: PlannerSharedLibrary? = nil
  }
  struct Client: Sendable {
    let load: @Sendable () async throws -> PlannerPrivateSyncState?
    let nodes: @Sendable () async throws -> [PlannerCloudNode]
    let persist:
      @Sendable (PlannerPrivateSyncState, PlannerCloudGraph.Changes?) async throws
        -> PlannerPrivateSyncPersistence
    let status: @Sendable (PlannerCloudObservation) async -> Void
    let validateSharing: @Sendable ([PlannerCloudNode], PlannerSharingScope) async throws -> Void
    let accountChanged: @Sendable () async -> Void
  }

  private let client: Client
  private let library: PlannerSharedLibrary?
  private let directory: URL
  private let zoneID: CKRecordZone.ID
  private let sharing: PlannerLibrarySharing
  private var sharingConfiguration = PlannerSharingConfiguration()
  private var verifiedWriteAccess = true
  private var isChangingSharing = false
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

  private init(
    binding: Binding, client: Client, state: PlannerPrivateSyncState, lease: PlannerPrivateSyncLease
  ) {
    self.client = client
    library = binding.library
    directory = binding.directory
    zoneID = binding.library?.zoneID ?? PlannerCloudNode.zoneID
    sharing = PlannerLibrarySharing(containerIdentifier: binding.containerIdentifier)
    self.state = state
    self.lease = lease
  }

  static func start(
    binding: Binding, client: Client
  ) async throws -> PlannerPrivateSync? {
    guard let lease = try PlannerPrivateSyncLease(directory: binding.directory) else { return nil }
    let accessRecord = binding.directory.appendingPathComponent("sharing-revoked")
    if binding.library != nil, FileManager.default.fileExists(atPath: accessRecord.path),
      try Data(contentsOf: accessRecord) != Data("verified".utf8)
    {
      throw PlannerFailure(
        "sharingRevoked", "Access to this library ended. Unsent edits stay on this device.")
    }
    let state = try await client.load() ?? .init(ownershipBinding: binding.ownershipBinding)
    try state.validated(binding: binding.ownershipBinding)
    let worker = PlannerPrivateSync(binding: binding, client: client, state: state, lease: lease)
    let container = CKContainer(identifier: binding.containerIdentifier)
    let database: CKDatabase
    if binding.library == nil {
      database = container.privateCloudDatabase
    } else {
      database = container.sharedCloudDatabase
    }
    await worker.initialize(database: database)
    return worker
  }

  private func initialize(database: CKDatabase) async {
    let configuration = CKSyncEngine.Configuration(
      database: database,
      stateSerialization: state.serialization, delegate: self)
    engine = CKSyncEngine(configuration)
    if library == nil && !state.zoneCreated {
      engine?.state.add(pendingDatabaseChanges: [
        .saveZone(CKRecordZone(zoneID: zoneID))
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
        if library == nil && !state.zoneCreated {
          syncEngine.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: zoneID))
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
    guard components.count >= 3, components[0] == "private-cloud-v1" else { return false }
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
      where modification.record.recordID.zoneID == zoneID
        && modification.record.recordType == PlannerCloudNode.recordType
        && modification.record["kind"] as? String != "sharingRoot"
      {
        if let library, !library.contains(modification.record) {
          let name = modification.record.recordID.recordName
          if next.serverRecords[name] != nil || next.incomingRecords[name] != nil {
            next.incomingRecords.removeValue(forKey: name)
            next.incomingDeletions.insert(name)
          }
          continue
        }
        let node = try PlannerCloudNode(record: modification.record, zoneID: zoneID)
        next.incomingRecords[node.name] = try PlannerCloudNode.archive(modification.record)
        next.incomingDeletions.remove(node.name)
      }
      for deletion in changes.deletions
      where deletion.recordID.zoneID == zoneID
        && state.serverRecords[deletion.recordID.recordName] != nil
      {
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
      if changes.savedZones.contains(where: { $0.zoneID == zoneID }) {
        var next = state
        next.zoneCreated = true
        try await persist(next)
      }
      for failure in changes.failedZoneSaves { await report(failure.error) }
    case .sentRecordZoneChanges(let changes):
      try await acceptSent(changes, engine: engine)
    case .fetchedDatabaseChanges(let changes):
      if state.zoneCreated
        && changes.deletions.contains(where: { $0.zoneID == zoneID })
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
      if result.zoneID == zoneID, let error = result.error {
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
    for record in changes.savedRecords where record["kind"] as? String != "sharingRoot" {
      let node = try PlannerCloudNode(record: record, zoneID: zoneID)
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
        bases[node.name] = try PlannerCloudNode(record: previous, zoneID: zoneID)
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
      case .zoneNotFound where library == nil && !state.zoneCreated:
        engine.state.add(pendingDatabaseChanges: [
          .saveZone(CKRecordZone(zoneID: zoneID))
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
    let nodes = try records.map { try PlannerCloudNode(record: $0, zoneID: zoneID) }
    var bases: [String: PlannerCloudNode] = [:]
    for node in nodes {
      if let data = state.serverRecords[node.name] {
        bases[node.name] = try PlannerCloudNode(
          record: PlannerCloudNode.restore(data), zoneID: zoneID)
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
    let allNodes = try await client.nodes()
    if library == nil, case .selectedLists(let lists) = sharingConfiguration.scope {
      let available = try Set(allNodes.filter { $0.kind == "list" }.map { try $0.uuid("id") })
      if !lists.isSubset(of: available) {
        scheduleNetwork()
        return false
      }
    }
    let nodes: [PlannerCloudNode]
    if let library, case .selectedLists = library.scope {
      let names = try PlannerSharingProjection(nodes: allNodes, scope: library.scope).names
      nodes = allNodes.filter { names.contains($0.name) }
    } else {
      nodes = allNodes
    }
    guard isValid else { return false }
    var changes: [CKSyncEngine.PendingRecordZoneChange] = []
    let projection = try PlannerSharingProjection(nodes: nodes, scope: sharingConfiguration.scope)
    for node in nodes where !state.incomingDeletions.contains(node.name) {
      let previous = try state.serverRecords[node.name].map {
        try PlannerCloudNode(record: PlannerCloudNode.restore($0), zoneID: zoneID)
      }
      let parent = desiredParent(for: node.name, projection: projection)
      let savedParent =
        try state.serverRecords[node.name].map {
          try PlannerCloudNode.restore($0).parent?.recordID
        } ?? nil
      if node != previous || (library == nil && savedParent != parent) {
        changes.append(.saveRecord(.init(recordName: node.name, zoneID: zoneID)))
      }
    }
    let allLocalNames = Set(allNodes.map(\.name))
    for name in state.serverRecords.keys where !allLocalNames.contains(name) {
      changes.append(.deleteRecord(.init(recordName: name, zoneID: zoneID)))
    }
    let pending = Set(engine.state.pendingRecordZoneChanges)
    let additions = changes.filter { !pending.contains($0) }
    if !additions.isEmpty { engine.state.add(pendingRecordZoneChanges: additions) }
    return !changes.isEmpty
  }

  func nextFetchChangesOptions(
    _ context: CKSyncEngine.FetchChangesContext, syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.FetchChangesOptions {
    var options = context.options
    options.scope = .zoneIDs([zoneID])
    options.prioritizedZoneIDs = options.prioritizedZoneIDs.filter { $0 == zoneID }
    return options
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
    guard isValid, sendFailure == nil, !isChangingSharing else { return nil }
    try await refreshSharingAuthority(database: engine.database)
    guard isValid, verifiedWriteAccess else { return nil }
    let allNodes = try await client.nodes()
    let nodes: [PlannerCloudNode]
    if let library, case .selectedLists = library.scope {
      let names = try PlannerSharingProjection(nodes: allNodes, scope: library.scope).names
      nodes = allNodes.filter { names.contains($0.name) }
    } else {
      nodes = allNodes
    }
    guard isValid else { return nil }
    let local = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
    let projection = try PlannerSharingProjection(nodes: nodes, scope: sharingConfiguration.scope)
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
          let record = try node.record(
            base: state.serverRecords[node.name].map(PlannerCloudNode.restore), zoneID: zoneID)
          if let root = library?.rootID {
            record.setParent(root)
          } else if library == nil {
            record.setParent(desiredParent(for: node.name, projection: projection))
          }
          saves.append(record)
        } else {
          engine.state.remove(pendingRecordZoneChanges: [change])
        }
      case .deleteRecord(let identifier):
        if !allNodes.contains(where: { $0.name == identifier.recordName }) {
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
    guard isValid, let engine, !isChangingSharing else { return }
    do {
      try await refreshSharingAuthority(database: engine.database)
      try await engine.fetchChanges(.init(scope: .zoneIDs([zoneID])))
    } catch {
      await report(error)
    }
    guard isValid, !Task.isCancelled, sendFailure == nil, verifiedWriteAccess else { return }
    do {
      try await engine.sendChanges(.init(scope: .zoneIDs([zoneID])))
      if isValid, !Task.isCancelled {
        try await engine.fetchChanges(.init(scope: .zoneIDs([zoneID])))
      }
    } catch { await report(error) }
  }

  /// Automatic engine sends must verify current authority too, not only explicit Sync now.
  private func refreshSharingAuthority(database: CKDatabase) async throws {
    if let library {
      guard let share = try await database.record(for: library.shareID) as? CKShare else {
        throw PlannerFailure("sharingAccessChanged", "This library invitation is unavailable.")
      }
      let verified = try await sharing.verifiedLibrary(share: share)
      verifiedWriteAccess = verified.canEdit
      guard verified == library else {
        throw PlannerFailure(
          "sharingAccessChanged", "This library's access changed. Select it again in Settings.")
      }
    } else {
      sharingConfiguration = try await sharing.configuration()
      guard !sharingConfiguration.isPreparing else {
        throw PlannerFailure("sharingBusy", "Finish or stop sharing setup before synchronizing.")
      }
      if sharingConfiguration.scope != .off {
        do {
          _ = try await sharing.invitation(configuration: sharingConfiguration)
        } catch let error as CKError where error.code == .unknownItem {
          // Apple's sharing controller can revoke the invitation independently of Planner.
          try await sharing.stop()
          sharingConfiguration = try await sharing.configuration()
        }
      }
      if case .selectedLists(let lists) = sharingConfiguration.scope {
        let nodes = try await client.nodes()
        let available = try Set(nodes.filter { $0.kind == "list" }.map { try $0.uuid("id") })
        if !lists.isSubset(of: available) {
          // Deleting a selected List changes the scope: revoke before sending its deletion.
          try await sharing.stop()
          sharingConfiguration = try await sharing.configuration()
        }
      }
    }
  }

  private func desiredParent(for name: String, projection: PlannerSharingProjection) -> CKRecord.ID?
  {
    guard library == nil, sharingConfiguration.usesHierarchy,
      projection.names.contains(name)
    else { return nil }
    return .init(recordName: sharingConfiguration.rootName, zoneID: zoneID)
  }

  func sharingStatus() async throws -> PlannerSharingConfiguration {
    guard library == nil else {
      throw PlannerFailure("sharingOwnerRequired", "Only the library owner can manage invitations.")
    }
    return try await sharing.configuration()
  }

  func sharingInvitation() async throws -> CKShare? {
    try await sharing.invitation(configuration: sharingStatus())
  }

  func changeSharing(scope: PlannerSharingScope) async throws -> CKShare? {
    guard library == nil, !isChangingSharing else {
      throw PlannerFailure(
        "sharingBusy", "Sharing is already being changed or belongs to another owner.")
    }
    await requestSync()
    await networkTask?.value
    guard isValid, let engine, sendFailure == nil,
      engine.state.pendingRecordZoneChanges.isEmpty,
      engine.state.pendingDatabaseChanges.isEmpty
    else {
      throw PlannerFailure("sharingUnavailable", "Finish private synchronization before sharing.")
    }
    isChangingSharing = true
    defer { isChangingSharing = false }
    let nodes = try await client.nodes()
    let projection = try PlannerSharingProjection(nodes: nodes, scope: scope)
    try await client.validateSharing(nodes, scope)
    let records = try nodes.map { node in
      guard let base = state.serverRecords[node.name] else {
        throw PlannerFailure("sharingUnavailable", "A plan has not finished uploading yet.")
      }
      return try node.record(base: PlannerCloudNode.restore(base), zoneID: zoneID)
    }
    let invitation = try await sharing.prepare(
      scope: scope, records: records, names: projection.names)
    sharingConfiguration = try await sharing.configuration()
    return invitation
  }

  func stopSharing() async throws {
    guard library == nil, !isChangingSharing else {
      throw PlannerFailure("sharingOwnerRequired", "Only the owner can stop sharing this library.")
    }
    isChangingSharing = true
    defer { isChangingSharing = false }
    try await sharing.stop()
    sharingConfiguration = try await sharing.configuration()
    sendFailure = nil
    scheduleNetwork()
  }

  private func revokeLocalAccess() async {
    do {
      try plannerWriteDurably(
        Data("revoked".utf8), to: directory.appendingPathComponent("sharing-revoked"))
    } catch {
      sendFailure = .init(
        "sharingRevoked", "Library access ended; close this library before continuing.")
    }
    valid = false
    await client.accountChanged()
    Task { await self.stop() }
  }

  private func report(_ error: any Error) async {
    guard valid else { return }
    if library != nil, (error as? PlannerFailure)?.code == "sharingAccessChanged" {
      await revokeLocalAccess()
      return
    }
    if let error = error as? CKError {
      if library != nil,
        [.zoneNotFound, .userDeletedZone, .unknownItem].contains(error.code)
      {
        await revokeLocalAccess()
        return
      }
      switch error.code {
      case .quotaExceeded:
        sendFailure = .init(
          "privateCloudStorageFull",
          "Private iCloud storage is full. New saves remain on this device.")
      case .zoneNotFound where library == nil && !state.zoneCreated:
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
