import Foundation
import PlannerCore
import Testing

struct ListArchiveTests {
  @Test func archiveRetainsListContentAndOldReplayCannotUndoLaterUnarchive() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let scheduleResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .allDay(start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)))
      ).outcome,
      let schedule = scheduleResult.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let originalSchedule)) = await planner.read(
        session: session, request: .source(schedule)),
      case .applied(let listResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(
            content: PlannerListContentInput(name: "Tokyo Food", notes: "Original notes")))
      ).outcome,
      let list = listResult.generated.first,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("An empty List and unrelated saved Item/Schedule must precede archiving.")
      return
    }
    let archiveIdentifier = UUID()
    let archiveCommand = PlannerCommand.setArchive(source: list, archived: true)
    guard
      case .applied(let archivedResult, .complete(let archiveCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: archiveIdentifier, session: session, command: archiveCommand)
      ).outcome,
      case .source(.list(let archived)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Archiving a List must save its own state with independent recovery.")
      return
    }
    #expect(archiveCheckpoint == 4)
    #expect(archivedResult.generated.isEmpty)
    #expect(archivedResult.affected == [list])
    #expect(archived.state.archived == true)
    #expect(archived.state.globalDone == nil)
    #expect(archived.content == original.content)
    #expect(archived.fieldHashes == original.fieldHashes)
    #expect(archived.createdAt == original.createdAt)
    #expect(archived.updatedAt >= original.updatedAt)
    #expect(archived.progress.state == .empty)
    #expect(archived.progress.totalCount == 0)
    guard
      case .applied(_, .complete(let noOpCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: UUID(), session: session, command: archiveCommand)
      ).outcome,
      case .source(.list(let noOp)) = await planner.read(session: session, request: .source(list)),
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: list.id, changes: PlannerListChanges(notes: .set("Later notes")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .source(.list(let edited)) = await planner.read(session: session, request: .source(list)),
      case .applied(_, .complete(let unarchiveCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .setArchive(source: list, archived: false)
        )
      ).outcome
    else {
      Issue.record(
        "No-op Archive, editing an archived List and explicit Unarchive must save separately.")
      return
    }
    #expect(noOpCheckpoint == 5)
    #expect(noOp.updatedAt == archived.updatedAt)
    #expect(edited.state.archived == true)
    #expect(edited.content.notes == "Later notes")
    #expect(unarchiveCheckpoint == 7)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let beforeReplay)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: archiveIdentifier, session: reopenedSession, command: archiveCommand)
      ).outcome,
      case .rejected(let mismatch) = await reopened.execute(
        PlannerOperation(
          operationId: archiveIdentifier, session: reopenedSession,
          command: .setArchive(source: list, archived: false))
      ).outcome,
      case .source(.list(let afterReplay)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.schedule(let retainedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let archivedRecovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: archiveCheckpoint)),
      case .selected(let latestRecovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: unarchiveCheckpoint))
    else {
      Issue.record(
        "Reopened state and historical Archive replay must retain the later List and other data.")
      return
    }
    #expect(replay == archivedResult)
    #expect(replayCheckpoint == archiveCheckpoint)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(beforeReplay.state.archived == false)
    #expect(afterReplay.state.archived == false)
    #expect(afterReplay.state.globalDone == nil)
    #expect(afterReplay.content == beforeReplay.content)
    #expect(afterReplay.fieldHashes == beforeReplay.fieldHashes)
    #expect(afterReplay.updatedAt == beforeReplay.updatedAt)
    #expect(retainedItem.content.notes == "Keep")
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.state.archived == false)
    #expect(retainedSchedule.content == originalSchedule.content)
    #expect(retainedSchedule.fieldHashes == originalSchedule.fieldHashes)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == unarchiveCheckpoint)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(archivedRecovery.decodedBackup.backup.lists.first?.archived == true)
    #expect(archivedRecovery.decodedBackup.backup.lists.first?.content.notes == "Original notes")
    #expect(latestRecovery.decodedBackup.backup.lists.first?.archived == false)
    #expect(latestRecovery.decodedBackup.backup.lists.first?.content.notes == "Later notes")
    #expect(latestRecovery.decodedBackup.backup.sources.count == 2)
    #expect(latestRecovery.decodedBackup.backup.schedules.count == 1)
  }
  @Test func missingListAndObstructedRecoveryLeaveArchiveUnapplied() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
      storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let result, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: PlannerListContentInput(name: "Wishlist")))
      ).outcome,
      let list = result.generated.first,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("A saved List must precede invalid or obstructed Archive attempts.")
      return
    }
    let missingIdentifier = UUID()
    guard
      case .rejected(let missing) = await planner.execute(
        PlannerOperation(
          operationId: missingIdentifier, session: session,
          command: .setArchive(
            source: PlannerEntityReference(kind: .list, id: UUID()), archived: true))
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: missingIdentifier)
    else {
      Issue.record("Archiving a missing List must reject without saved or prepared evidence.")
      return
    }
    #expect(missing.code == "missingReference")
    let retainedDirectory = directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
    try Data("Recovery is obstructed by a file.".utf8).write(to: recoveryDirectory)
    let obstructedIdentifier = UUID()
    let obstructed = await planner.execute(
      PlannerOperation(
        operationId: obstructedIdentifier, session: session,
        command: .setArchive(source: list, archived: true)))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
    guard case .rejected(let reason) = obstructed.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: obstructedIdentifier),
      case .source(.list(let retained)) = await planner.read(
        session: session, request: .source(list)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Obstructed recovery must reject Archive before changing the saved List.")
      return
    }
    #expect(reason.code == "persistenceFailure")
    #expect(retained.state.archived == false)
    #expect(retained.state.globalDone == nil)
    #expect(retained.content == original.content)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(retained.updatedAt == original.updatedAt)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }
}
