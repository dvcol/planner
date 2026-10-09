import Foundation
import PlannerCore
import Testing

struct RecoveryFailureTests {
  @Test func inaccessibleRecoveryRejectsCreationBeforeCommitAndRetainsAcknowledgedData()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
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
    #expect(selection.decodedBackup.backup.sources.count == 1)
    let recovered = try #require(selection.decodedBackup.backup.sources.first)
    #expect(recovered.id == source.id)
    #expect(recovered.content.title == "Hotel")
    #expect(recovered.content.notes == "Original notes")
    #expect(recovered.globalDone == false)
    #expect(recovered.archived == false)
  }
}
