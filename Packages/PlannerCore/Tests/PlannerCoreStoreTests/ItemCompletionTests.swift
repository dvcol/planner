import Foundation
import PlannerCore
import Testing

struct ItemCompletionTests {
  @Test func globalReopenAndReplayRetainCurrentStateAndNoOpTimestamp() async throws {
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
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(title: "Hotel", notes: "Original notes")))
      ).outcome
    else {
      Issue.record("Hotel must be independently saved.")
      return
    }
    let source = try #require(creation.generated.first)
    let completionIdentifier = UUID()
    guard
      case .applied(let completedResult, .complete(let completedCheckpoint)) =
        await planner.execute(
          PlannerOperation(
            operationId: completionIdentifier, session: session,
            command: .setCompletion(scope: .globalItem(itemId: source.id), done: true))
        ).outcome,
      case .source(let completed) = await planner.read(session: session, request: .source(source))
    else {
      Issue.record("Hotel must be globally Done before Reopen.")
      return
    }
    #expect(completedCheckpoint == 2)
    guard
      case .applied(_, .complete(let noOpCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: source.id), done: true))
      ).outcome,
      case .source(let unchanged) = await planner.read(session: session, request: .source(source))
    else {
      Issue.record(
        "Repeating the current state under a new operation must remain a durable acknowledgement.")
      return
    }
    #expect(noOpCheckpoint == 3)
    #expect(unchanged.state.globalDone == true)
    #expect(unchanged.updatedAt == completed.updatedAt)
    #expect(unchanged.fieldHashes == completed.fieldHashes)
    guard
      case .applied(_, .complete(let reopenedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: source.id), done: false))
      ).outcome,
      case .source(let reopenedItem) = await planner.read(
        session: session, request: .source(source))
    else {
      Issue.record("Global Reopen must durably set Todo.")
      return
    }
    #expect(reopenedCheckpoint == 4)
    #expect(reopenedItem.state.globalDone == false)
    #expect(reopenedItem.state.archived == false)
    #expect(reopenedItem.fieldHashes == completed.fieldHashes)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayedResult, .complete(let replayedCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: completionIdentifier, session: reopenedSession,
          command: .setCompletion(scope: .globalItem(itemId: source.id), done: true))
      ).outcome
    else {
      Issue.record("Identical replay must return the original completion evidence.")
      return
    }
    #expect(replayedResult == completedResult)
    #expect(replayedCheckpoint == 2)
    guard
      case .rejected(let mismatch) = await reopened.execute(
        PlannerOperation(
          operationId: completionIdentifier, session: reopenedSession,
          command: .setCompletion(scope: .globalItem(itemId: source.id), done: false))
      ).outcome,
      case .rejected(let differentCommand) = await reopened.execute(
        PlannerOperation(
          operationId: completionIdentifier, session: reopenedSession,
          command: .setArchive(source: source, archived: true))
      ).outcome
    else {
      Issue.record(
        "The completed operation identity cannot be reused with another state or command.")
      return
    }
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(differentCommand.code == "operationPayloadMismatch")
    let missingOperationIdentifier = UUID()
    guard
      case .rejected(let missing) = await reopened.execute(
        PlannerOperation(
          operationId: missingOperationIdentifier, session: reopenedSession,
          command: .setCompletion(scope: .globalItem(itemId: UUID()), done: true))
      ).outcome,
      case .noReliableEvidence = await reopened.operationStatus(
        session: reopenedSession,
        operationId: missingOperationIdentifier)
    else {
      Issue.record("A missing Item must reject before recording an applied command.")
      return
    }
    #expect(missing.code == "missingReference")
    guard
      case .source(let current) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .snapshot(let query) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .items(PlannerItemQuery()))),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Replay and rejection must retain Hotel and its current independent checkpoint.")
      return
    }
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Original notes")
    #expect(current.state.globalDone == false)
    #expect(current.state.archived == false)
    #expect(current.updatedAt == reopenedItem.updatedAt)
    #expect(current.fieldHashes == reopenedItem.fieldHashes)
    #expect(query.rows == [.source(source)])
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func globalCompletionPreservesArchivedContentAfterReopenAndIndependentRecovery()
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
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
      return
    }
    let content = PlannerItemContentInput(
      title: "Hotel", subtitle: "Tokyo", notes: "Original notes",
      location: PlannerOwnedLocation(
        displayName: "Meeting point A", formattedAddress: "Tokyo",
        coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
      estimate: PlannerEstimate(minutes: 120, displayUnit: .hour))
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session, command: .createItem(content: content)))
    guard case .applied(let creation, .complete) = created.outcome else {
      Issue.record("Hotel must be independently saved.")
      return
    }
    let source = try #require(creation.generated.first)
    let archived = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .setArchive(source: source, archived: true)))
    guard case .applied(_, .complete) = archived.outcome,
      case .source(let before) = await planner.read(session: session, request: .source(source)),
      case .snapshot(let originalQuery) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery(archive: .all))))
    else {
      Issue.record("The fixture must start globally Todo and Archived.")
      return
    }
    #expect(before.state.globalDone == false)
    #expect(before.state.archived == true)
    #expect(originalQuery.rows == [.source(source)])
    let operationIdentifier = UUID()
    let completed = await planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: session,
        command: .setCompletion(scope: .globalItem(itemId: source.id), done: true)))
    guard case .applied(let result, .complete(let checkpoint)) = completed.outcome else {
      Issue.record(
        "Global completion must save the Item and acknowledge independent recovery: \(completed.outcome)"
      )
      return
    }
    #expect(result.generated.isEmpty)
    #expect(result.affected == [source])
    #expect(checkpoint == 3)
    guard
      case .failed(let stale) = await planner.read(
        session: session,
        request: .rows(generation: originalQuery.generation, offset: 0, limit: 1))
    else {
      Issue.record("Completion must invalidate the old Todo window.")
      return
    }
    #expect(stale.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(let current) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else {
      Issue.record("The completed archived Item must reopen.")
      return
    }
    #expect(current.source == source)
    #expect(current.state.globalDone == true)
    #expect(current.state.archived == true)
    #expect(current.content.title == content.title)
    #expect(current.content.subtitle == content.subtitle)
    #expect(current.content.notes == content.notes)
    #expect(current.content.location == content.location)
    #expect(current.content.estimate == content.estimate)
    #expect(current.createdAt == before.createdAt)
    #expect(current.updatedAt >= before.updatedAt)
    #expect(current.fieldHashes == before.fieldHashes)
    guard
      case .snapshot(let doneQuery) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(PlannerItemQuery(completion: .done, archive: .all)))),
      case .rows(let window) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: doneQuery.generation, offset: 0, limit: 1)),
      case .snapshot(let todoQuery) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .items(PlannerItemQuery(archive: .all))))
    else {
      Issue.record("Queries and row reads must observe saved completion.")
      return
    }
    #expect(doneQuery.rows == [.source(source)])
    #expect(todoQuery.matchingCount == 0)
    let row = try #require(window.rows.first)
    #expect(row.globalDone == true)
    #expect(row.localDone == nil)
    #expect(row.effectiveDone == true)
    #expect(row.archived == true)
    guard
      case .appliedRecoveryComplete(let recorded, let recordedCheckpoint) =
        await reopened.operationStatus(session: reopenedSession, operationId: operationIdentifier),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Completion must retain independently acknowledged operation evidence.")
      return
    }
    #expect(recorded == result)
    #expect(recordedCheckpoint == checkpoint)
    let namespace = try #require(namespaces.first)
    guard
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("The completed checkpoint must decode independently.")
      return
    }
    let recovered = try #require(selection.decodedBackup.backup.sources.first)
    #expect(recovered.id == source.id)
    #expect(recovered.globalDone == true)
    #expect(recovered.archived == true)
    #expect(recovered.content.title == content.title)
    #expect(recovered.content.notes == content.notes)
    #expect(recovered.content.location == content.location)
    #expect(recovered.content.estimate == content.estimate)
  }
}
