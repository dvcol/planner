import Foundation
import PlannerCore
import Testing

struct MembershipCreationTests {
  @Test func newMembershipReferencesOneItemWithoutCopyingContentOrCompletingIt() async throws {
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
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .applied(let listResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: PlannerListContentInput(name: "Tokyo Food")))
      ).outcome,
      let list = listResult.generated.first,
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Independent Item and List sources must save before creating a membership.")
      return
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.addMembership(itemId: item.id, listId: list.id, placement: .last)
    guard
      case .applied(let added, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      let reference = added.generatedReferences.first,
      case .membership(let identifier, let owner, let source) = reference
    else {
      Issue.record("Adding to a List must durably create one membership pointing at the same Item.")
      return
    }
    #expect(checkpoint == 3)
    #expect(added.generated.isEmpty)
    #expect(added.generatedIdentities == [.reference(reference)])
    #expect(owner == list)
    #expect(source == item)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let readList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.item(let readItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Membership, original receipt and source projections must survive reopening.")
      return
    }
    #expect(identifier != item.id)
    #expect(identifier != list.id)
    #expect(readList.references == [reference])
    #expect(readList.progress.state == .partial)
    #expect(readList.progress.doneCount == 0)
    #expect(readList.progress.totalCount == 1)
    #expect(readList.state.globalDone == nil)
    #expect(readList.content == originalList.content)
    #expect(readList.fieldHashes == originalList.fieldHashes)
    #expect(readItem.references == [reference])
    #expect(readItem.content.title == "Hotel")
    #expect(readItem.content.notes == "Keep")
    #expect(readItem.updatedAt == originalItem.updatedAt)
    #expect(readItem.fieldHashes == originalItem.fieldHashes)
    #expect(readItem.state.globalDone == false)
    #expect(replay == added)
    #expect(replayCheckpoint == checkpoint)
    #expect(recovery.decodedBackup.backup.items.count == 1)
    #expect(recovery.decodedBackup.backup.lists.count == 1)
    #expect(namespace.preparedProposals.isEmpty)
  }
  @Test func placementKeepsSourceIdentitiesAndRebalancesWithoutLosingOrder() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdList, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: PlannerListContentInput(name: "Route")))
      ).outcome,
      let list = createdList.generated.first
    else {
      Issue.record("A List is required for placement.")
      return
    }
    var items: [PlannerEntityReference] = []
    for title in ["A", "B", "C", "D", "E"] {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(content: PlannerItemContentInput(title: title)))
        ).outcome,
        let item = result.generated.first
      else {
        Issue.record("Placement sources must save.")
        return
      }
      items.append(item)
    }
    var references: [PlannerReferenceRead] = []
    for index in 0..<items.count {
      let placement: PlannerPlacement
      switch index {
      case 0, 1: placement = .last
      case 2: placement = .first
      case 3:
        guard case .membership(let anchor, _, _) = references[1] else {
          Issue.record("Missing B.")
          return
        }
        placement = .before(associationId: anchor)
      default:
        guard case .membership(let anchor, _, _) = references[0] else {
          Issue.record("Missing A.")
          return
        }
        placement = .after(associationId: anchor)
      }
      guard
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: items[index].id, listId: list.id, placement: placement))
        ).outcome,
        let reference = added.generatedReferences.first
      else {
        Issue.record("Every approved placement must save a reference at its requested position.")
        return
      }
      references.append(reference)
    }
    guard
      case .source(.list(let initial)) = await planner.read(
        session: session, request: .source(list)),
      case .membership(let anchor, _, _) = references[0]
    else {
      Issue.record("Saved order must be readable.")
      return
    }
    #expect(
      initial.references == [
        references[2], references[0], references[4], references[3], references[1],
      ])
    var inserted: [PlannerReferenceRead] = []
    for index in 0..<12 {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(content: PlannerItemContentInput(title: "Stop \(index)")))
        ).outcome,
        let item = result.generated.first,
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(
              itemId: item.id, listId: list.id, placement: .after(associationId: anchor)))
        ).outcome,
        let reference = added.generatedReferences.first
      else {
        Issue.record("Dense insertion must rebalance before the rank gap is exhausted.")
        return
      }
      inserted.append(reference)
    }
    let duplicateOperation = UUID()
    let duplicateCommand = PlannerCommand.addMembership(
      itemId: items[1].id, listId: list.id, placement: .first)
    guard
      case .applied(let duplicate, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: duplicateOperation, session: session, command: duplicateCommand)
      ).outcome,
      case .rejected(let mismatch) = await planner.execute(
        PlannerOperation(
          operationId: duplicateOperation, session: session,
          command: .addMembership(itemId: items[1].id, listId: list.id, placement: .last))
      ).outcome,
      case .source(.list(let current)) = await planner.read(
        session: session, request: .source(list)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Existing membership must remain in place without duplicate creation.")
      return
    }
    let expected =
      [references[2], references[0]] + inserted.reversed() + [
        references[4], references[3], references[1],
      ]
    #expect(current.references == expected)
    #expect(current.progress.totalCount == 17)
    #expect(duplicate.generatedIdentities.isEmpty)
    #expect(duplicate.affectedReferences == [references[1]])
    #expect(mismatch.code == "operationPayloadMismatch")
    let savedMemberships = recovery.decodedBackup.backup.memberships.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.id.uuidString < $1.id.uuidString
    }
    #expect(
      savedMemberships.map(\.id)
        == expected.map { reference in
          if case .membership(let identifier, _, _) = reference { return identifier }
          return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        })
    #expect(savedMemberships.allSatisfy { $0.id == $0.lifetimeId && !$0.localDone })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(list))
    else {
      Issue.record("Rebalanced order must survive relaunch.")
      return
    }
    #expect(retained.references == expected)
    #expect(retained.updatedAt == current.updatedAt)
  }

  @Test func listedItemLeavesInboxAndEveryWriterRetainsIndependentMemberships() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      let item = itemCreation.generated.first
    else {
      Issue.record("The shared Item must save.")
      return
    }
    var lists: [PlannerEntityReference] = []
    var references: [PlannerReferenceRead] = []
    for name in ["Tokyo", "Wishlist"] {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createList(content: PlannerListContentInput(name: name)))
        ).outcome,
        let list = created.generated.first,
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        let reference = added.generatedReferences.first
      else {
        Issue.record("Two Lists must reference the same Item.")
        return
      }
      lists.append(list)
      references.append(reference)
    }
    guard
      case .snapshot(let inbox) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(PlannerItemQuery(scope: .inbox, completion: .all, archive: .all)))),
      case .snapshot(let all) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(PlannerItemQuery(scope: .global, completion: .all, archive: .all))))
    else {
      Issue.record("Source queries must remain available.")
      return
    }
    #expect(inbox.matchingCount == 0)
    #expect(all.matchingCount == 1)
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(lists[0]))
    else {
      Issue.record("The original live source and container must be readable.")
      return
    }
    let commands: [PlannerCommand] = [
      .setCompletion(scope: .globalItem(itemId: item.id), done: true),
      .setArchive(source: item, archived: true),
      .setArchive(source: lists[0], archived: true),
      .editList(
        sourceId: lists[0].id, changes: PlannerListChanges(notes: .set("Booking")),
        expectedFieldHashes: originalList.fieldHashes),
      .editItem(
        sourceId: item.id,
        changes: PlannerItemChanges(
          title: .set("Hotel updated"),
          links: .set([PlannerLinkInput(originalUrl: "https://example.com/hotel")])),
        expectedFieldHashes: original.fieldHashes),
      .createItem(content: PlannerItemContentInput(title: "Unlisted")),
      .createList(content: PlannerListContentInput(name: "New empty List")),
    ]
    var checkpoints: [Int64] = []
    for command in commands {
      guard
        case .applied(_, .complete(let checkpoint)) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Existing writers must preserve saved memberships.")
        return
      }
      checkpoints.append(checkpoint)
    }
    guard
      case .applied(let scheduled, .complete(let creationCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
              planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let scheduleRead)) = await planner.read(
        session: session, request: .source(schedule)),
      case .applied(_, .complete(let zoneCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .changeScheduleZone(
            scheduleId: schedule.id, planningTimeZone: "Europe/Paris",
            expectedFieldHashes: scheduleRead.fieldHashes))
      ).outcome,
      case .source(.schedule(let changedSchedule)) = await planner.read(
        session: session, request: .source(schedule)),
      case .applied(_, .complete(let editCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: schedule.id,
            changes: PlannerScheduleChanges(
              form: .allDay(start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)),
            expectedFieldHashes: changedSchedule.fieldHashes))
      ).outcome,
      case .applied(_, .complete(let removalCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .removeSchedule(scheduleId: schedule.id))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else {
      Issue.record("All Schedule writers must retain List membership recovery.")
      return
    }
    checkpoints += [creationCheckpoint, zoneCheckpoint, editCheckpoint, removalCheckpoint]
    for checkpoint in checkpoints {
      guard
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else {
        Issue.record("Every acknowledged checkpoint must decode memberships.")
        return
      }
      let memberships = recovery.decodedBackup.backup.memberships
      #expect(memberships.count == 2)
      #expect(Set(memberships.map { $0.list.id }) == Set(lists.map(\.id)))
      #expect(memberships.allSatisfy { $0.item == item && $0.id == $0.lifetimeId && !$0.localDone })
    }
    for list in lists {
      guard
        case .source(.list(let completed)) = await planner.read(
          session: session, request: .source(list))
      else {
        Issue.record("Archived children remain part of progress.")
        return
      }
      #expect(completed.progress.state == .complete)
      #expect(completed.progress.doneCount == 1)
      #expect(completed.progress.totalCount == 1)
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: false))
      ).outcome
    else {
      Issue.record("Global Reopen must expose retained local Todo flags.")
      return
    }
    for (index, list) in lists.enumerated() {
      guard
        case .source(.list(let reopened)) = await planner.read(
          session: session, request: .source(list))
      else {
        Issue.record("Reopened contextual progress must remain available.")
        return
      }
      #expect(reopened.references == [references[index]])
      #expect(reopened.progress.state == .partial)
      #expect(reopened.progress.doneCount == 0)
      #expect(reopened.progress.totalCount == 1)
    }
    guard
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .snapshot(let refreshedInbox) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(PlannerItemQuery(scope: .inbox, completion: .all, archive: .all))))
    else {
      Issue.record("Source edits and the updated Inbox must remain readable.")
      return
    }
    #expect(retained.content.title == "Hotel updated")
    #expect(retained.content.links.count == 1)
    #expect(refreshedInbox.matchingCount == 1)
  }

  @Test func invalidSourcesAnchorsAndRecoveryFailureLeaveMembershipAdditionUnapplied() async throws
  {
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
      case .applied(let itemCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      let item = itemCreated.generated.first,
      case .applied(let listCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: PlannerListContentInput(name: "Target")))
      ).outcome,
      let list = listCreated.generated.first,
      case .applied(let otherCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: PlannerListContentInput(name: "Other")))
      ).outcome,
      let otherList = otherCreated.generated.first,
      case .applied(let memberCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: otherList.id, placement: .last))
      ).outcome,
      case .membership(let otherMembership, _, _)? = memberCreated.generatedReferences.first,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery())))
    else {
      Issue.record("The independent sources and foreign placement anchor must save.")
      return
    }
    let invalid: [PlannerCommand] = [
      .addMembership(itemId: UUID(), listId: list.id, placement: .last),
      .addMembership(itemId: item.id, listId: UUID(), placement: .last),
      .addMembership(
        itemId: item.id, listId: list.id, placement: .before(associationId: otherMembership)),
      .addMembership(itemId: item.id, listId: list.id, placement: .after(associationId: item.id)),
      .addMembership(
        itemId: item.id, listId: otherList.id, placement: .after(associationId: UUID())),
    ]
    for command in invalid {
      let identifier = UUID()
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: identifier, session: session, command: command)
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: identifier)
      else {
        Issue.record("Invalid identities and cross-List anchors cannot produce mutation evidence.")
        return
      }
      #expect(reason.code == "missingReference")
    }
    let retainedDirectory = directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
    try Data("Recovery is obstructed by a file.".utf8).write(to: recoveryDirectory)
    let obstructedIdentifier = UUID()
    let obstructed = await planner.execute(
      PlannerOperation(
        operationId: obstructedIdentifier,
        session: session,
        command: .addMembership(itemId: item.id, listId: list.id, placement: .last)))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
    guard case .rejected(let reason) = obstructed.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: obstructedIdentifier),
      case .source(.list(let retained)) = await planner.read(
        session: session, request: .source(list)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      case .rows(let rows) = await planner.read(
        session: session,
        request: .rows(generation: issued.generation, offset: 0, limit: 1))
    else {
      Issue.record("A genuine precommit I/O failure must preserve saved state and issued windows.")
      return
    }
    #expect(reason.code == "persistenceFailure")
    #expect(retained.references.isEmpty)
    #expect(retained.progress.state == .empty)
    #expect(retained.updatedAt == original.updatedAt)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(rows.rows.count == 1)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

}
