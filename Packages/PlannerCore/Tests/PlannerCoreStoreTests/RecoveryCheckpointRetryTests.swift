import Foundation
import PlannerCore
import SwiftData
import Testing

struct RecoveryCheckpointRetryTests {
  @Test func knownAppliedCompletionRetryRepairsRecoveryWithoutReapplyingAndUnblocksLaterEdits()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first
    else { throw CancellationError() }
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    guard
      case .applied(let applied, .incomplete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .setCompletion(scope: .globalItem(itemId: source.id), done: true))
      ).outcome
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let before)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .snapshot(let query) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all)))),
      case .rejected(let blocked) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editItem(
            sourceId: source.id, changes: .init(notes: .set("Must stay blocked")),
            expectedFieldHashes: [.notes: try #require(before.fieldHashes[.notes])]))
      ).outcome
    else { throw CancellationError() }
    #expect(blocked.code == "mutationBlocked")
    #expect(before.state.globalDone == true)
    let response = await reopened.retryRecovery(
      session: reopenedSession, operationId: operationIdentifier)
    guard case .applied(let recoveredResult, .complete(let checkpoint)) = response.outcome else {
      Issue.record("Repair only the known applied completion checkpoint: \(response)")
      return
    }
    #expect(response.operationId == operationIdentifier)
    #expect(recoveredResult == applied)
    #expect(checkpoint == 2)
    guard
      case .source(.item(let after)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .rows(let retainedRows) = await reopened.read(
        session: reopenedSession, request: .rows(generation: query.generation, offset: 0, limit: 1)),
      case .appliedRecoveryComplete(let statusResult, let statusCheckpoint) =
        await reopened.operationStatus(session: reopenedSession, operationId: operationIdentifier),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(after.source == before.source && after.sourceLifetimeId == before.sourceLifetimeId)
    #expect(after.content.title == "Hotel" && after.content.notes == "Original notes")
    #expect(after.state.globalDone == true && after.state.archived == false)
    #expect(after.updatedAt == before.updatedAt && after.fieldHashes == before.fieldHashes)
    #expect(retainedRows.rows.count == 1)
    #expect(statusResult == applied && statusCheckpoint == checkpoint)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(selection.decodedBackup.backup.items.first?.id == source.id)
    #expect(selection.decodedBackup.backup.items.first?.globalDone == true)
    guard
      case .applied(_, .complete(let nextCheckpoint)) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editItem(
            sourceId: source.id, changes: .init(notes: .set("Friday booking")),
            expectedFieldHashes: [.notes: try #require(after.fieldHashes[.notes])]))
      ).outcome,
      case .applied(let repeatedResult, .complete(let repeatedCheckpoint)) =
        await reopened.retryRecovery(session: reopenedSession, operationId: operationIdentifier)
        .outcome,
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .listed(let latestNamespace) = await reopened.inspectRecovery(
        request: .namespace(namespaceId: namespace.namespaceId))
    else { throw CancellationError() }
    #expect(nextCheckpoint == 3)
    #expect(repeatedResult == applied && repeatedCheckpoint == checkpoint)
    #expect(retained.content.notes == "Friday booking" && retained.state.globalDone == true)
    #expect(latestNamespace.acknowledgedSnapshot?.checkpointGeneration == nextCheckpoint)
  }
}
