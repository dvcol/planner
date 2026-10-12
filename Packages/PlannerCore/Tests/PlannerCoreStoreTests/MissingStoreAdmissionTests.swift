import Foundation
import PlannerCore
import Testing

struct MissingStoreAdmissionTests {
  @Test func authorizedCreationCannotRecreateAMissingInitializedStoreOrReplaceRecovery()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeDirectory = directory.appendingPathComponent("store")
    let retainedDirectory = directory.appendingPathComponent("retained-store")
    let configuration = PlannerStorageConfiguration(
      storeURL: storeDirectory.appendingPathComponent("Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let originalOperationIdentifier = UUID()
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: originalOperationIdentifier, session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      )
      .outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let originalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    try FileManager.default.moveItem(at: storeDirectory, to: retainedDirectory)
    try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    let attemptedOperationIdentifier = UUID()
    let attempted = await planner.execute(
      .init(
        operationId: attemptedOperationIdentifier, session: session,
        command: .createItem(content: .init(title: "Museum", notes: "Must remain unapplied"))))
    guard case .rejected(let reason) = attempted.outcome else {
      Issue.record("A live session must not initialize replacement storage: \(attempted)")
      return
    }
    #expect(attempted.operationId == attemptedOperationIdentifier)
    #expect(reason.code == "unavailable" && !reason.message.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: configuration.storeURL.path))
    guard
      case .listed(let retainedNamespace) = await planner.inspectRecovery(
        request: .namespace(namespaceId: namespace.namespaceId)),
      case .selected(let retainedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .appliedRecoveryComplete(let retainedResult, let retainedCheckpoint) =
        await planner.operationStatus(
          session: session, operationId: originalOperationIdentifier)
    else { throw CancellationError() }
    #expect(retainedNamespace.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(retainedNamespace.preparedProposals.isEmpty)
    #expect(retainedRecovery.portableData == originalRecovery.portableData)
    #expect(retainedResult == creation && retainedCheckpoint == checkpoint)
    try FileManager.default.removeItem(at: storeDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: storeDirectory)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let restored)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .snapshot(let query) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init())))
    else { throw CancellationError() }
    #expect(
      restored.source == original.source && restored.sourceLifetimeId == original.sourceLifetimeId)
    #expect(restored.content.title == "Hotel" && restored.content.notes == "Original notes")
    #expect(
      restored.updatedAt == original.updatedAt && restored.fieldHashes == original.fieldHashes)
    #expect(query.matchingCount == 1 && query.rows == [.source(source)])
    guard
      case .source(.item(let sameFacadeRestored)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    #expect(sameFacadeRestored.content.title == original.content.title)
    #expect(sameFacadeRestored.fieldHashes == original.fieldHashes)
  }
}
