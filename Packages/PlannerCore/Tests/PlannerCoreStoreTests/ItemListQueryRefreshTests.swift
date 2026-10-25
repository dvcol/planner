import Foundation
import PlannerCore
import Testing

struct ItemListQueryRefreshTests {
  @Test func otherWriterMembershipRemovalAndReaddRefreshListGroupsWithoutRestoringLocalDone()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let firstCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "A")))
      ).outcome,
      let firstList = firstCreation.generated.first,
      case .applied(let secondCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "B")))
      ).outcome,
      let secondList = secondCreation.generated.first,
      case .applied(let itemCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = itemCreation.generated.first,
      case .applied(let firstAddition, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: firstList.id, placement: .last))
      ).outcome,
      case .membership(let firstMembership, _, _)? = firstAddition.generatedReferences.first,
      case .applied(let secondAddition, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: secondList.id, placement: .last))
      ).outcome,
      case .membership(let secondMembership, _, _)? = secondAddition.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(
              .listMembership(listId: firstList.id, membershipId: firstMembership)), done: true))
      ).outcome,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalSecondList)) = await planner.read(
        session: session, request: .source(secondList))
    else {
      Issue.record("Save one source in two independent List contexts.")
      return
    }
    let anyGroup = PlannerItemQuery.IdentityGroup(ids: [firstList.id, secondList.id])
    let allGroup = PlannerItemQuery.IdentityGroup(ids: [firstList.id, secondList.id], match: .all)
    guard
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(lists: allGroup))))
    else {
      Issue.record("Issue the initial All-membership snapshot.")
      return
    }
    #expect(issued.rows == [.source(item)])
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .editList(
            sourceId: secondList.id, changes: .init(name: .set("Renamed B")),
            expectedFieldHashes: originalSecondList.fieldHashes))
      ).outcome,
      case .failed(let staleRename) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .snapshot(let renamed) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(lists: allGroup))))
    else {
      Issue.record(
        "List renames invalidate old windows without changing membership identity matches.")
      return
    }
    #expect(staleRename.code == "staleSnapshot")
    #expect(renamed.rows == [.source(item)])
    let removalIdentifier = UUID()
    let removeFirst = PlannerCommand.removeMembership(
      listId: firstList.id, membershipId: firstMembership)
    guard
      case .applied(let removal, .complete(let removalCheckpoint)) = await otherWriter.execute(
        PlannerOperation(
          operationId: removalIdentifier, session: otherSession, command: removeFirst)
      ).outcome,
      case .failed(let staleRemoval) = await planner.read(
        session: session, request: .rows(generation: renamed.generation, offset: 0, limit: 1)),
      case .snapshot(let survivingAny) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(lists: anyGroup)))),
      case .snapshot(let incompleteAll) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(lists: allGroup)))),
      case .snapshot(let stillListed) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .inbox))))
    else {
      Issue.record(
        "Removing one membership preserves the remaining Any match and excludes Inbox/All.")
      return
    }
    #expect(removalCheckpoint == 8)
    #expect(staleRemoval.code == "staleSnapshot")
    #expect(survivingAny.rows == [.source(item)])
    #expect(incompleteAll.rows.isEmpty)
    #expect(stillListed.rows.isEmpty)
    guard
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .removeMembership(listId: secondList.id, membershipId: secondMembership))
      ).outcome,
      case .snapshot(let unlisted) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .inbox)))),
      case .snapshot(let removedGroups) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(lists: anyGroup)))),
      case .applied(let readdition, .complete(let readdCheckpoint)) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .addMembership(itemId: item.id, listId: firstList.id, placement: .last))
      ).outcome,
      case .membership(let freshMembership, _, _)? = readdition.generatedReferences.first,
      case .applied(let replay, .complete(let replayCheckpoint)) = await otherWriter.execute(
        PlannerOperation(
          operationId: removalIdentifier, session: otherSession, command: removeFirst)
      ).outcome,
      case .snapshot(let readded) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(scope: .list(firstList.id), lists: anyGroup, sort: .init(mode: .manual))))),
      case .rows(let rowWindow) = await planner.read(
        session: session, request: .rows(generation: readded.generation, offset: 0, limit: 1)),
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record(
        "Ordinary re-add restores a fresh Todo context; old removal replay preserves it.")
      return
    }
    #expect(unlisted.rows == [.source(item)])
    #expect(removedGroups.rows.isEmpty)
    #expect(readdCheckpoint == 10)
    #expect(freshMembership != firstMembership)
    #expect(freshMembership != secondMembership)
    #expect(replay.affected == removal.affected)
    #expect(replayCheckpoint == removalCheckpoint)
    #expect(
      readded.rows == [
        .appearance(
          source: item,
          appearance: .listMembership(listId: firstList.id, membershipId: freshMembership))
      ])
    #expect(readded.progress.first?.doneCount == 0)
    #expect(readded.progress.first?.totalCount == 1)
    #expect(rowWindow.rows.first?.localDone == false)
    #expect(rowWindow.rows.first?.globalDone == false)
    #expect(rowWindow.rows.first?.effectiveDone == false)
    #expect(retained.updatedAt == original.updatedAt)
    #expect(retained.fieldHashes == original.fieldHashes)
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 10)
      )
    else {
      Issue.record("Membership queries and receipt replay retain the latest acknowledged graph.")
      return
    }
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 10)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(recovery.decodedBackup.backup.memberships.count == 1)
    #expect(recovery.decodedBackup.backup.deletionMarkers.count == 2)
  }
}
