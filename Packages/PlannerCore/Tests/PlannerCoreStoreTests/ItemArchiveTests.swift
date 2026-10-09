import Foundation
import PlannerCore
import Testing

struct ItemArchiveTests {
  @Test func unarchiveRestoresVisibilityAndOldArchiveReplayDoesNotReapplyItsState() async throws {
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
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    guard case .applied(let creation, .complete) = created.outcome else {
      Issue.record("Hotel must be independently saved.")
      return
    }
    let source = try #require(creation.generated.first)
    let archiveOperationIdentifier = UUID()
    let archived = await planner.execute(
      PlannerOperation(
        operationId: archiveOperationIdentifier, session: session,
        command: .setArchive(source: source, archived: true)))
    guard case .applied(let originalResult, .complete(let originalCheckpoint)) = archived.outcome
    else {
      Issue.record("Archive must complete before Unarchive.")
      return
    }
    let restored = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .setArchive(source: source, archived: false)))
    guard case .applied(let restoredResult, .complete(let restoredCheckpoint)) = restored.outcome
    else {
      Issue.record("Unarchive must complete independently.")
      return
    }
    #expect(restoredResult.generated.isEmpty)
    #expect(restoredResult.affected == [source])
    #expect(restoredCheckpoint == 3)
    guard
      case .source(.item(let unarchived)) = await planner.read(
        session: session, request: .source(source))
    else {
      Issue.record("Unarchive must retain Hotel.")
      return
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      Issue.record("The Item must reopen after Unarchive.")
      return
    }
    let replay = await reopened.execute(
      PlannerOperation(
        operationId: archiveOperationIdentifier, session: reopenedSession,
        command: .setArchive(source: source, archived: true)))
    guard case .applied(let replayResult, .complete(let replayCheckpoint)) = replay.outcome else {
      Issue.record("Known replay must retain the original completed outcome.")
      return
    }
    #expect(replayResult == originalResult)
    #expect(replayCheckpoint == originalCheckpoint)
    #expect(replayCheckpoint == 2)
    let mismatched = await reopened.execute(
      PlannerOperation(
        operationId: archiveOperationIdentifier, session: reopenedSession,
        command: .setArchive(source: source, archived: false)))
    guard case .rejected(let reason) = mismatched.outcome else {
      Issue.record("Changed payload under the same operation must reject.")
      return
    }
    #expect(reason.code == "operationPayloadMismatch")
    guard
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else {
      Issue.record("Replay and rejection must retain the current Item.")
      return
    }
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Original notes")
    #expect(current.state.archived == false)
    #expect(current.state.globalDone == false)
    #expect(current.updatedAt == unarchived.updatedAt)
    #expect(current.fieldHashes == unarchived.fieldHashes)
    guard
      case .snapshot(let ordinary) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(PlannerItemQuery())))
    else {
      Issue.record("Unarchive must restore ordinary visibility.")
      return
    }
    #expect(ordinary.matchingCount == 1)
    #expect(ordinary.rows == [.source(source)])
    guard
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The current independent checkpoint must remain available.")
      return
    }
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func archivingRetainsContentAndCompletionAcrossReopenAndIndependentRecovery() async throws {
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
        displayName: "Hotel", formattedAddress: "Tokyo address",
        coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
      estimate: PlannerEstimate(minutes: 91, displayUnit: .hour))
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(content: content)))
    guard case .applied(let creation, .complete) = created.outcome else {
      Issue.record("The fixture must be independently saved.")
      return
    }
    let source = try #require(creation.generated.first)
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source))
    else {
      Issue.record("The original Item must be readable.")
      return
    }
    let operationIdentifier = UUID()
    let archived = await planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: session,
        command: .setArchive(source: source, archived: true)))
    guard case .applied(let result, .complete(let checkpoint)) = archived.outcome else {
      Issue.record("Archive must complete independently: \(archived)")
      return
    }
    #expect(result.generated.isEmpty)
    #expect(result.affected == [source])
    #expect(checkpoint == 2)
    guard
      case .snapshot(let ordinary) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(PlannerItemQuery())))
    else {
      Issue.record("The ordinary query must remain available.")
      return
    }
    #expect(ordinary.matchingCount == 0)
    #expect(ordinary.rows.isEmpty)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      Issue.record("The archived Item must survive reopening.")
      return
    }
    guard
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else {
      Issue.record("Archive must retain the original Item identity.")
      return
    }
    #expect(current.source == source)
    #expect(current.content.title == "Hotel")
    #expect(current.content.subtitle == "Tokyo")
    #expect(current.content.notes == "Original notes")
    #expect(current.content.location == content.location)
    #expect(current.content.estimate == content.estimate)
    #expect(current.state.globalDone == false)
    #expect(current.state.archived == true)
    #expect(current.createdAt == original.createdAt)
    #expect(current.updatedAt >= original.updatedAt)
    #expect(current.fieldHashes == original.fieldHashes)
    guard
      case .snapshot(let archivedQuery) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(PlannerItemQuery(archive: .archived))))
    else {
      Issue.record("The archived query must discover the retained identity.")
      return
    }
    #expect(archivedQuery.matchingCount == 1)
    #expect(archivedQuery.rows == [.source(source)])
    guard
      case .appliedRecoveryComplete(let storedResult, let storedCheckpoint) =
        await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
    else {
      Issue.record("Archive must retain its completed operation evidence.")
      return
    }
    #expect(storedResult == result)
    #expect(storedCheckpoint == 2)
    guard
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The independent archive catalog must remain readable.")
      return
    }
    let namespace = try #require(namespaces.first)
    guard
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Archive requires an independently decodable acknowledged checkpoint.")
      return
    }
    #expect(selection.decodedBackup.backup.sources.count == 1)
    let recovered = try #require(selection.decodedBackup.backup.sources.first)
    #expect(recovered.id == source.id)
    #expect(recovered.archived == true)
    #expect(recovered.globalDone == false)
    #expect(recovered.content.title == "Hotel")
    #expect(recovered.content.notes == "Original notes")
    #expect(recovered.content.location == content.location)
    #expect(recovered.content.estimate == content.estimate)
  }
}
