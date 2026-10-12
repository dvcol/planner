import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeStatusAdmissionTests {
  @Test func appliedIncompleteStatusRetainsPriorCheckpointAndClearsOnlyAfterRecoveryRepair()
    async throws
  {
    let fixture = try await NativeStatusFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    guard
      case .applied(let creation, .incomplete) = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session,
          command: .createItem(content: .init(title: "Museum")))
      ).outcome,
      case .status(let unavailable) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .unavailable(let failure) = unavailable.recovery
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    #expect(!failure.message.isEmpty)
    try obstruction.restore()
    guard
      case .status(let pending) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(let checkpoint, let incomplete, let blocked) = pending.recovery,
      case .snapshot(let query) = await fixture.planner.query(
        .init(session: fixture.session, request: .items(.init()))),
      case .rejected(let blockReason) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItem(content: .init(title: "Must stay blocked")))
      ).outcome
    else { throw CancellationError() }
    #expect(checkpoint == 1 && incomplete == [operationIdentifier] && blocked)
    #expect(blockReason.code == "mutationBlocked")
    #expect(query.matchingCount == 2)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .status(let retained) = await reopened.read(session: reopenedSession, request: .status),
      case .known(let retainedCheckpoint, let retainedIncomplete, let retainedBlock) = retained
        .recovery,
      case .applied(let repairedResult, .complete(let repairedCheckpoint)) =
        await reopened.retryRecovery(
          session: reopenedSession, operationId: operationIdentifier
        ).outcome,
      case .status(let repaired) = await reopened.read(session: reopenedSession, request: .status),
      case .known(let currentCheckpoint, let currentIncomplete, let currentBlock) = repaired
        .recovery,
      case .rows(let rows) = await fixture.planner.read(
        session: fixture.session, request: .rows(generation: query.generation, offset: 0, limit: 2))
    else { throw CancellationError() }
    #expect(retainedCheckpoint == 1 && retainedIncomplete == [operationIdentifier] && retainedBlock)
    #expect(repairedResult == creation && repairedCheckpoint == 2)
    #expect(currentCheckpoint == 2 && currentIncomplete.isEmpty && !currentBlock)
    #expect(rows.rows.count == 2)
    #expect(repaired.cloud.state == .unknown && repaired.cloud.observedAt == nil)
  }

  @Test(arguments: [
    "unreadableRecovery", "malformedRecovery", "wrongOwnership", "mismatchedReceipt",
    "missingStore", "foreignSession", "separateDataset",
  ])
  func unavailableOrScopedStatusNeverClaimsSavedEmptyOrCrossDatasetEvidence(_ scenario: String)
    async throws
  {
    let fixture = try await NativeStatusFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let checkpointURL = fixture.configuration.recoveryDirectoryURL
      .appendingPathComponent(fixture.recovery.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-1.json")
    let originalBytes = try Data(contentsOf: checkpointURL)
    switch scenario {
    case "foreignSession":
      let foreignFacade = Planner(configuration: fixture.configuration)
      guard case .ready(let foreignSession) = await foreignFacade.bootstrap(),
        case .failed(let reason) = await fixture.planner.read(
          session: foreignSession, request: .status)
      else { throw CancellationError() }
      #expect(reason.code == "staleDatasetSession")
    case "separateDataset":
      let otherConfiguration = PlannerStorageConfiguration(
        storeURL: fixture.directory.appendingPathComponent("other-store/Planner.sqlite"),
        controlURL: fixture.directory.appendingPathComponent("other-control/writer"),
        recoveryDirectoryURL: fixture.directory.appendingPathComponent("other-recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      let other = Planner(configuration: otherConfiguration)
      guard case .ready(let otherSession) = await other.bootstrap(),
        case .status(let empty) = await other.read(session: otherSession, request: .status),
        case .known(let checkpoint, let incomplete, let blocked) = empty.recovery
      else { throw CancellationError() }
      #expect(checkpoint == nil && incomplete.isEmpty && !blocked)
    default:
      let recoveryDirectory = fixture.configuration.recoveryDirectoryURL
      let retainedDirectory = fixture.directory.appendingPathComponent("retained-recovery")
      if scenario == "missingStore" {
        try FileManager.default.removeItem(
          at: fixture.configuration.storeURL.deletingLastPathComponent())
      } else if scenario == "unreadableRecovery" {
        try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
        try Data("Unreadable recovery.".utf8).write(to: recoveryDirectory)
      } else if scenario == "malformedRecovery" {
        try Data("{ invalid checkpoint".utf8).write(to: checkpointURL, options: .atomic)
      } else {
        var envelope = try #require(
          JSONSerialization.jsonObject(with: originalBytes) as? [String: Any])
        if scenario == "wrongOwnership" {
          envelope["ownershipBinding"] = "different-owner"
        } else {
          var receipts = try #require(envelope["receipts"] as? [[String: Any]])
          receipts[0]["payloadDigest"] = "sha256-payload-v1:" + String(repeating: "0", count: 64)
          envelope["receipts"] = receipts
        }
        try JSONSerialization.data(withJSONObject: envelope).write(
          to: checkpointURL, options: .atomic)
      }
      guard
        case .status(let unavailable) = await fixture.planner.read(
          session: fixture.session, request: .status),
        case .unavailable(let reason) = unavailable.recovery,
        case .unknown = unavailable.account
      else { throw CancellationError() }
      #expect(!reason.message.isEmpty)
      #expect(unavailable.cloud.state == .unknown && unavailable.cloud.reason == nil)
      if ["wrongOwnership", "mismatchedReceipt"].contains(scenario) {
        #expect(reason.code == "recoveryIntegrityFailure")
      }
      if scenario == "missingStore" {
        #expect(!FileManager.default.fileExists(atPath: fixture.configuration.storeURL.path))
        return
      }
      if scenario == "unreadableRecovery" {
        try FileManager.default.removeItem(at: recoveryDirectory)
        try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
      } else {
        try originalBytes.write(to: checkpointURL, options: .atomic)
      }
    }
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source)),
      case .status(let retained) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(let checkpoint, let incomplete, let blocked) = retained.recovery
    else { throw CancellationError() }
    #expect(current.content.title == "Hotel" && current.content.notes == "Original notes")
    #expect(
      current.updatedAt == fixture.item.updatedAt && current.fieldHashes == fixture.item.fieldHashes
    )
    #expect(checkpoint == 1 && incomplete.isEmpty && !blocked)
  }

  @Test func preparedProposalDoesNotBecomeKnownAppliedPendingStatusOrChangeCurrentContent()
    async throws
  {
    let fixture = try await NativeStatusFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let proposalIdentifier = UUID()
    let operationIdentifier = UUID()
    var backup = try #require(
      JSONSerialization.jsonObject(with: fixture.recovery.portableData) as? [String: Any])
    var sources = try #require(backup["sources"] as? [[String: Any]])
    var content = try #require(sources[0]["content"] as? [String: Any])
    content["title"] = "Museum"
    sources[0]["content"] = content
    backup["sources"] = sources
    let proposal: [String: Any] = [
      "proposalId": proposalIdentifier.uuidString,
      "originalOperationId": operationIdentifier.uuidString,
      "datasetId": fixture.recovery.datasetId.uuidString,
      "ownershipBinding": fixture.recovery.ownershipBinding, "proposedBackup": backup,
      "payloadDigest": "sha256-payload-v1:" + String(repeating: "0", count: 64),
      "evidence": "preparedUnverified",
    ]
    let proposalURL = fixture.configuration.recoveryDirectoryURL
      .appendingPathComponent(fixture.recovery.namespaceId.uuidString)
      .appendingPathComponent("proposal-\(proposalIdentifier.uuidString).json")
    try JSONSerialization.data(withJSONObject: proposal).write(to: proposalURL, options: .atomic)
    guard
      case .preparedUnverified(let summary) = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(let checkpoint, let incomplete, let blocked) = status.recovery,
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    #expect(summary.proposalId == proposalIdentifier && summary.requiresFreshReview)
    #expect(checkpoint == 1 && incomplete.isEmpty && !blocked)
    #expect(current.content.title == "Hotel" && current.content.notes == "Original notes")
    #expect(
      current.updatedAt == fixture.item.updatedAt && current.fieldHashes == fixture.item.fieldHashes
    )
  }
}

private struct NativeStatusFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let source: PlannerEntityReference
  let item: PlannerItemSourceRead
  let recovery: PlannerRecoverySelection

  static func create() async throws -> Self {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let item)) = await planner.read(session: session, request: .source(source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return Self(
      directory: directory, configuration: configuration, planner: planner, session: session,
      source: source, item: item, recovery: recovery)
  }
}
