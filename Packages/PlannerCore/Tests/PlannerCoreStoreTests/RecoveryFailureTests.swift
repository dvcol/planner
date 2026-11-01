import Foundation
import PlannerCore
import Testing

struct RecoveryFailureTests {
  @Test(arguments: [23, 24, 25])
  func currentWriterCheckpointsRemainReadable(storageVersion: Int) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let result, .complete(let generation)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Retained sharing plan")))
      ).outcome,
      let source = result.generated.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    await planner.close()
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    for (filename, field, value) in [
      ("identity.json", "schemaVersion", storageVersion as Any),
      ("checkpoint-\(generation).json", "storageSchemaVersion", String(storageVersion) as Any),
    ] {
      let url = namespaceDirectory.appendingPathComponent(filename)
      var record = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
      record[field] = value
      try JSONSerialization.data(withJSONObject: record).write(to: url, options: .atomic)
    }
    let inspection = await planner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: namespace.namespaceId, checkpointGeneration: generation))
    guard case .selected(let selection) = inspection else {
      Issue.record("Supported writer checkpoint must remain readable: \(inspection)")
      return
    }
    let item = try #require(selection.decodedBackup.backup.items.first)
    #expect(item.id == source.id)
    #expect(item.content.title == "Retained sharing plan")
  }

  @Test func inaccessibleRecoveryRejectsCreationBeforeCommitAndRetainsAcknowledgedData()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let retainedRecoveryDirectory = directory.appendingPathComponent("retained-recovery")
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: recoveryDirectory,
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real local dataset must initialize.")
      return
    }
    let originalOperationIdentifier = UUID()
    let created = await planner.execute(
      PlannerOperation(
        operationId: originalOperationIdentifier, session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    guard case .applied(let originalResult, .complete(let checkpoint)) = created.outcome else {
      Issue.record("Hotel must have acknowledged independent recovery before the fault.")
      return
    }
    let source = try #require(originalResult.generated.first)
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source))
    else {
      Issue.record("Hotel must be readable before the fault.")
      return
    }

    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedRecoveryDirectory)
    try Data("A file obstructs the configured recovery directory.".utf8).write(
      to: recoveryDirectory)
    let failedOperationIdentifier = UUID()
    let attempted = await planner.execute(
      PlannerOperation(
        operationId: failedOperationIdentifier, session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Museum", notes: "Must remain unapplied"))))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedRecoveryDirectory, to: recoveryDirectory)

    guard case .rejected(let reason) = attempted.outcome else {
      Issue.record("Unreadable recovery must reject before creating Museum: \(attempted)")
      return
    }
    #expect(attempted.operationId == failedOperationIdentifier)
    #expect(reason.code == "persistenceFailure")
    #expect(!reason.message.isEmpty)

    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      Issue.record("The unchanged dataset must reopen after recovery access is restored.")
      return
    }
    guard
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else {
      Issue.record("The original Hotel must remain readable after the fault.")
      return
    }
    #expect(current.source == source)
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Original notes")
    #expect(current.state.globalDone == false)
    #expect(current.state.archived == false)
    #expect(current.createdAt == original.createdAt)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.fieldHashes == original.fieldHashes)
    guard
      case .snapshot(let snapshot) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .items(PlannerItemQuery())))
    else {
      Issue.record("The unchanged Item identities must be discoverable after reopening.")
      return
    }
    #expect(snapshot.matchingCount == 1)
    #expect(snapshot.rows == [.source(source)])
    guard
      case .noReliableEvidence = await reopened.operationStatus(
        session: reopenedSession, operationId: failedOperationIdentifier)
    else {
      Issue.record("The rejected precommit attempt must have no applied or prepared evidence.")
      return
    }
    guard
      case .appliedRecoveryComplete(let statusResult, let statusCheckpoint) =
        await reopened.operationStatus(
          session: reopenedSession, operationId: originalOperationIdentifier)
    else {
      Issue.record("Hotel's original acknowledged operation must remain complete.")
      return
    }
    #expect(statusResult == originalResult)
    #expect(statusCheckpoint == checkpoint)
    guard
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The retained independent recovery must remain publicly discoverable.")
      return
    }
    #expect(namespaces.count == 1)
    let namespace = try #require(namespaces.first)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    guard
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "The original acknowledged recovery snapshot must remain independently readable.")
      return
    }
    #expect(selection.decodedBackup.backup.items.count == 1)
    let recovered = try #require(selection.decodedBackup.backup.items.first)
    #expect(recovered.id == source.id)
    #expect(recovered.content.title == "Hotel")
    #expect(recovered.content.notes == "Original notes")
    #expect(recovered.globalDone == false)
    #expect(recovered.archived == false)
  }
}
