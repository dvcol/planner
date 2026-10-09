import Foundation
import PlannerCore
import Testing

struct MembershipCompletionTests {
  @Test func invalidAppearancesAndPrecommitRecoveryFailureLeaveLocalAndGlobalStateUnchanged()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
        storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdItem, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: item, archived: true))
      ).outcome,
      case .applied(let createdList, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let list = createdList.generated.first,
      case .applied(let added, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipId, _, _)? = added.generatedReferences.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .list(list.id), archive: .all)))
      )
    else {
      Issue.record("The archived child and its independent List context must exist first.")
      return
    }
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: membershipId)
    for invalid in [
      PlannerAppearance.listMembership(listId: UUID(), membershipId: membershipId),
      .listMembership(listId: item.id, membershipId: membershipId),
      .listMembership(listId: list.id, membershipId: item.id),
      .listMembership(listId: list.id, membershipId: list.id),
      .listMembership(listId: list.id, membershipId: UUID()),
    ] {
      let operationId = UUID()
      guard
        case .rejected(let rejected) = await planner.execute(
          PlannerOperation(
            operationId: operationId, session: session,
            command: .setCompletion(scope: .appearance(invalid), done: true))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationId)
      else {
        Issue.record(
          "Invalid appearances cannot fall back to a global state action or save evidence.")
        return
      }
      #expect(rejected.code == "missingReference")
    }
    let retainedDirectory = directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
    try Data("Recovery is obstructed by a file.".utf8).write(to: recoveryDirectory)
    let failedOperationId = UUID()
    let failed = await planner.execute(
      PlannerOperation(
        operationId: failedOperationId, session: session,
        command: .setCompletion(scope: .appearance(appearance), done: true)))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
    guard case .rejected(let rejected) = failed.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: failedOperationId),
      case .appearance(let unchanged) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let retainedList)) = await planner.read(
        session: session, request: .source(list)),
      case .rows(let retainedWindow) = await planner.read(
        session: session,
        request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record(
        "A real precommit I/O failure must retain the original local/global state and window.")
      return
    }
    #expect(rejected.code == "persistenceFailure")
    #expect(!unchanged.localDone && !unchanged.effectiveDone && !unchanged.globalDone)
    #expect(unchanged.archived)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedList.updatedAt == originalList.updatedAt)
    #expect(retainedList.fieldHashes == originalList.fieldHashes)
    #expect(retainedList.references == originalList.references)
    #expect(retainedWindow.rows.count == 1)
    #expect(retainedWindow.rows.first?.localDone == false)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
    guard
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(appearance), done: true))
      ).outcome,
      case .appearance(let completed) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .source(.item(let stillArchived)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Restored recovery must allow local completion of the retained archived child.")
      return
    }
    #expect(checkpoint == 5)
    #expect(completed.localDone && completed.effectiveDone && !completed.globalDone)
    #expect(completed.archived)
    #expect(stillArchived.updatedAt == originalItem.updatedAt)
    #expect(stillArchived.fieldHashes == originalItem.fieldHashes)
  }

  @Test func localCompletionRetainsOtherContextAndGlobalPrecedenceThroughReopenAndReplay()
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
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original")))
      ).outcome,
      let item = created.generated.first
    else {
      Issue.record("The shared Item must save before contextual completion.")
      return
    }
    var lists: [PlannerEntityReference] = []
    var appearances: [PlannerAppearance] = []
    var references: [PlannerReferenceRead] = []
    for name in ["Tokyo", "Wishlist"] {
      guard
        case .applied(let createdList, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: name)))
        ).outcome,
        let list = createdList.generated.first,
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = added.generatedReferences.first,
        let reference = added.generatedReferences.first
      else {
        Issue.record("Two independent List appearances must reference the same Item.")
        return
      }
      lists.append(list)
      appearances.append(.listMembership(listId: list.id, membershipId: membershipId))
      references.append(reference)
    }
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalFirstList)) = await planner.read(
        session: session, request: .source(lists[0])),
      case .source(.list(let originalSecondList)) = await planner.read(
        session: session, request: .source(lists[1])),
      case .snapshot(let originalQuery) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .list(lists[0].id)))))
    else {
      Issue.record("Original content, times and Todo rows must be observable through public reads.")
      return
    }
    let operationId = UUID()
    let command = PlannerCommand.setCompletion(scope: .appearance(appearances[0]), done: true)
    guard
      case .applied(let completed, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(operationId: operationId, session: session, command: command)
      ).outcome
    else {
      Issue.record("Local completion must save only the exact List appearance and its receipt.")
      return
    }
    #expect(checkpoint == 6)
    #expect(completed.generatedIdentities.isEmpty)
    #expect(completed.affectedReferences == [references[0]])
    #expect(completed.affected == [lists[0]])
    guard
      case .appearance(let first) = await planner.read(
        session: session, request: .appearance(appearances[0])),
      case .appearance(let second) = await planner.read(
        session: session, request: .appearance(appearances[1])),
      case .source(.item(let unchangedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let firstList)) = await planner.read(
        session: session, request: .source(lists[0])),
      case .source(.list(let secondList)) = await planner.read(
        session: session, request: .source(lists[1])),
      case .snapshot(let filteredOut) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .list(lists[0].id))))),
      case .failed(let stale) = await planner.read(
        session: session,
        request: .rows(generation: originalQuery.generation, offset: 0, limit: 1))
    else {
      Issue.record(
        "Local completion must refresh derived observations without changing shared data.")
      return
    }
    #expect(first.localDone && first.effectiveDone && !first.globalDone)
    #expect(!second.localDone && !second.effectiveDone && !second.globalDone)
    #expect(unchangedItem.state.globalDone == false)
    #expect(unchangedItem.updatedAt == originalItem.updatedAt)
    #expect(unchangedItem.fieldHashes == originalItem.fieldHashes)
    #expect(unchangedItem.content.notes == "Original")
    #expect(firstList.updatedAt > originalFirstList.updatedAt)
    #expect(firstList.fieldHashes == originalFirstList.fieldHashes)
    #expect(firstList.progress.state == .complete)
    #expect(firstList.progress.doneCount == 1)
    #expect(secondList.updatedAt == originalSecondList.updatedAt)
    #expect(secondList.progress.state == .partial)
    #expect(secondList.progress.doneCount == 0)
    #expect(filteredOut.rows.isEmpty)
    #expect(filteredOut.progress.first?.state == .complete)
    #expect(stale.code == "staleSnapshot")
    guard
      case .applied(_, .complete(let noOpCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: UUID(), session: session, command: command)
      ).outcome,
      case .source(.list(let noOpList)) = await planner.read(
        session: session, request: .source(lists[0]))
    else {
      Issue.record("An explicit same-state action must preserve its container timestamp.")
      return
    }
    #expect(noOpCheckpoint == 7)
    #expect(noOpList.updatedAt == firstList.updatedAt)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(appearances[0]), done: false))
      ).outcome,
      case .appearance(let globallyCompleted) = await planner.read(
        session: session, request: .appearance(appearances[0])),
      case .appearance(let otherGloballyCompleted) = await planner.read(
        session: session, request: .appearance(appearances[1]))
    else {
      Issue.record("Clearing local state must retain globally Done precedence in every context.")
      return
    }
    #expect(globallyCompleted.globalDone && globallyCompleted.effectiveDone)
    #expect(!globallyCompleted.localDone)
    #expect(otherGloballyCompleted.globalDone && otherGloballyCompleted.effectiveDone)
    #expect(!otherGloballyCompleted.localDone)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(operationId: UUID(), session: session, command: command)
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: false))
      ).outcome,
      case .appearance(let locallyRetained) = await planner.read(
        session: session, request: .appearance(appearances[0])),
      case .appearance(let otherReopened) = await planner.read(
        session: session, request: .appearance(appearances[1])),
      case .source(.item(let globallyReopenedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .applied(_, .complete(let finalCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(appearances[0]), done: false))
      ).outcome
    else {
      Issue.record("Global Reopen must reveal retained independent local flags.")
      return
    }
    #expect(
      locallyRetained.localDone && locallyRetained.effectiveDone && !locallyRetained.globalDone)
    #expect(!otherReopened.localDone && !otherReopened.effectiveDone && !otherReopened.globalDone)
    #expect(finalCheckpoint == 12)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let originalCheckpoint)) = await reopened.execute(
        PlannerOperation(operationId: operationId, session: reopenedSession, command: command)
      ).outcome,
      case .appearance(let retainedTodo) = await reopened.read(
        session: reopenedSession, request: .appearance(appearances[0])),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .appliedRecoveryComplete(let recorded, let recordedCheckpoint) =
        await reopened.operationStatus(
          session: reopenedSession, operationId: operationId),
      case .rejected(let changedReplay) = await reopened.execute(
        PlannerOperation(
          operationId: operationId, session: reopenedSession,
          command: .setCompletion(scope: .appearance(appearances[0]), done: false))
      ).outcome,
      case .rejected(let changedScopeReplay) = await reopened.execute(
        PlannerOperation(
          operationId: operationId, session: reopenedSession,
          command: .setCompletion(scope: .appearance(appearances[1]), done: true))
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 12))
    else {
      Issue.record(
        "Reopen/replay must retain later local Todo and original durable operation evidence.")
      return
    }
    #expect(originalCheckpoint == 6)
    #expect(recordedCheckpoint == 6)
    #expect(replayed.affectedReferences == completed.affectedReferences)
    #expect(recorded.affectedReferences == completed.affectedReferences)
    #expect(!retainedTodo.localDone && !retainedTodo.effectiveDone && !retainedTodo.globalDone)
    #expect(retainedItem.updatedAt == globallyReopenedItem.updatedAt)
    #expect(retainedItem.fieldHashes == globallyReopenedItem.fieldHashes)
    #expect(changedReplay.code == "operationPayloadMismatch")
    #expect(changedScopeReplay.code == "operationPayloadMismatch")
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 12)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(recovery.decodedBackup.backup.memberships.count == 2)
    #expect(recovery.decodedBackup.backup.memberships.allSatisfy { !$0.localDone && $0.rank == 0 })
    #expect(recovery.decodedBackup.backup.items.first?.globalDone == false)
  }
}
