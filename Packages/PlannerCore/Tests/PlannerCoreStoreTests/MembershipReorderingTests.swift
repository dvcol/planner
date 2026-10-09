import Foundation
import PlannerCore
import Testing

struct MembershipReorderingTests {
  @Test func reorderingKeepsMembershipIdentityLocalStateAndSourceContentAcrossReopenAndReplay()
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
    let session = try #require(await readySession(planner))
    let list = try #require(
      await createSource(
        planner, session: session, command: .createList(content: .init(name: "Tokyo"))))
    let otherList = try #require(
      await createSource(
        planner, session: session, command: .createList(content: .init(name: "Wishlist"))))
    var items: [PlannerEntityReference] = []
    var memberships: [UUID] = []
    var originalItems: [PlannerItemSourceRead] = []
    for title in ["A", "B", "C"] {
      let item = try #require(
        await createSource(
          planner, session: session,
          command: .createItem(content: .init(title: title, notes: "Keep"))))
      guard
        case .source(.item(let original)) = await planner.read(
          session: session, request: .source(item)),
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = added.generatedReferences.first
      else { throw TestSetupFailure() }
      items.append(item)
      originalItems.append(original)
      memberships.append(membershipId)
    }
    guard
      case .applied(let otherAdded, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: items[0].id, listId: otherList.id, placement: .last))
      ).outcome,
      case .membership(let otherMembershipId, _, _)? = otherAdded.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: memberships[0])),
            done: true))
      ).outcome,
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all,
              archive: .all, sort: .init(mode: .manual)))))
    else { throw TestSetupFailure() }
    let operationId = UUID()
    let command = PlannerCommand.reorderMembership(
      listId: list.id, membershipId: memberships[2], placement: .first)
    let outcome = await planner.execute(
      PlannerOperation(operationId: operationId, session: session, command: command))
    guard case .applied(let firstReorder, .complete(let checkpoint)) = outcome.outcome else {
      Issue.record(
        "Reordering C first must save [C, A, B] through the public facade, received: \(outcome.outcome)"
      )
      return
    }
    #expect(checkpoint == 11)
    #expect(firstReorder.generatedIdentities.isEmpty)
    #expect(
      firstReorder.affectedReferences == [
        .membership(id: memberships[2], list: list, item: items[2])
      ])
    #expect(firstReorder.affected == [list])
    #expect(
      await orderedSources(planner, session: session, list: list.id) == [
        items[2].id, items[0].id, items[1].id,
      ])
    guard
      case .failed(let stale) = await planner.read(
        session: session,
        request: .rows(generation: issued.generation, offset: 0, limit: 3)),
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .reorderMembership(
            listId: list.id, membershipId: memberships[2],
            placement: .after(associationId: memberships[1])))
      ).outcome,
      case .source(.list(let beforeNoOp)) = await planner.read(
        session: session, request: .source(list)),
      case .applied(_, .complete(let latestCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .reorderMembership(
            listId: list.id, membershipId: memberships[2], placement: .last))
      ).outcome
    else { throw TestSetupFailure() }
    #expect(stale.code == "staleSnapshot")
    #expect(latestCheckpoint == 13)
    let reopened = Planner(configuration: configuration)
    let reopenedSession = try #require(await readySession(reopened))
    guard
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(operationId: operationId, session: reopenedSession, command: command)
      ).outcome,
      case .source(.list(let retainedList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let retainedLocal) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: memberships[0]))),
      case .appearance(let retainedOther) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: otherList.id, membershipId: otherMembershipId))
      ),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: latestCheckpoint))
    else { throw TestSetupFailure() }
    guard
      case .rejected(let changedReplay) = await reopened.execute(
        PlannerOperation(
          operationId: operationId, session: reopenedSession,
          command: .reorderMembership(
            listId: list.id, membershipId: memberships[2], placement: .last))
      ).outcome,
      case .appliedRecoveryComplete(let originalResult, let originalCheckpoint) =
        await reopened.operationStatus(
          session: reopenedSession, operationId: operationId)
    else { throw TestSetupFailure() }
    #expect(changedReplay.code == "operationPayloadMismatch")
    #expect(originalResult == firstReorder && originalCheckpoint == checkpoint)
    #expect(replay == firstReorder && replayCheckpoint == checkpoint)
    #expect(
      await orderedSources(reopened, session: reopenedSession, list: list.id) == items.map(\.id))
    #expect(retainedList.updatedAt == beforeNoOp.updatedAt)
    #expect(retainedList.updatedAt > originalList.updatedAt)
    #expect(retainedList.content == originalList.content)
    #expect(retainedList.fieldHashes == originalList.fieldHashes)
    #expect(retainedList.progress.doneCount == 1 && retainedList.progress.totalCount == 3)
    #expect(retainedLocal.localDone && retainedLocal.effectiveDone && !retainedLocal.globalDone)
    #expect(!retainedOther.localDone && !retainedOther.effectiveDone && !retainedOther.globalDone)
    #expect(
      Set(recovery.decodedBackup.backup.memberships.filter { $0.list == list }.map(\.id))
        == Set(memberships))
    #expect(namespace.preparedProposals.isEmpty)
    for (index, item) in items.enumerated() {
      guard
        case .source(.item(let retained)) = await reopened.read(
          session: reopenedSession, request: .source(item))
      else { throw TestSetupFailure() }
      #expect(
        retained.content.title == originalItems[index].content.title
          && retained.content.notes == "Keep")
      #expect(retained.updatedAt == originalItems[index].updatedAt)
      #expect(retained.fieldHashes == originalItems[index].fieldHashes)
    }
  }

  @Test func invalidReordersAndUnavailableRecoveryLeaveTheIssuedWindowAndEverySourceUnchanged()
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
    let session = try #require(await readySession(planner))
    let list = try #require(
      await createSource(
        planner, session: session,
        command: .createList(content: .init(name: "Tokyo"))))
    let otherList = try #require(
      await createSource(
        planner, session: session,
        command: .createList(content: .init(name: "Wishlist"))))
    var items: [PlannerEntityReference] = []
    var memberships: [UUID] = []
    for title in ["A", "B", "C"] {
      let item = try #require(
        await createSource(
          planner, session: session,
          command: .createItem(content: .init(title: title))))
      guard
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = added.generatedReferences.first
      else { throw TestSetupFailure() }
      items.append(item)
      memberships.append(membershipId)
    }
    guard
      case .applied(let otherAdded, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: items[0].id, listId: otherList.id, placement: .last))
      ).outcome,
      case .membership(let foreignMembershipId, _, _)? = otherAdded.generatedReferences.first,
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(items[0])),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))))
    else { throw TestSetupFailure() }
    let variants: [(UUID, UUID, PlannerPlacement, String, String?)] = [
      (otherList.id, memberships[0], .first, "missingReference", nil),
      (items[0].id, memberships[0], .first, "missingReference", nil),
      (list.id, items[0].id, .last, "missingReference", nil),
      (list.id, list.id, .last, "missingReference", nil),
      (UUID(), memberships[0], .first, "missingReference", nil),
      (list.id, UUID(), .last, "missingReference", nil),
      (
        list.id, memberships[0], .before(associationId: memberships[0]), "invalidInput",
        "/command/placement/associationId"
      ),
      (
        list.id, memberships[0], .after(associationId: memberships[0]), "invalidInput",
        "/command/placement/associationId"
      ),
      (
        list.id, memberships[0], .before(associationId: foreignMembershipId), "missingReference",
        "/command/placement/associationId"
      ),
      (
        list.id, memberships[0], .after(associationId: UUID()), "missingReference",
        "/command/placement/associationId"
      ),
    ]
    for (listId, membershipId, placement, expectedCode, expectedPath) in variants {
      let operationId = UUID()
      guard
        case .rejected(let failure) = await planner.execute(
          PlannerOperation(
            operationId: operationId, session: session,
            command: .reorderMembership(
              listId: listId, membershipId: membershipId, placement: placement))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationId),
        case .rows(let window) = await planner.read(
          session: session,
          request: .rows(generation: issued.generation, offset: 0, limit: 3))
      else { throw TestSetupFailure() }
      #expect(failure.code == expectedCode)
      #expect(failure.propertyPath == expectedPath)
      #expect(window.rows.map(\.title) == ["A", "B", "C"])
    }
    let retainedDirectory = directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
    try Data("Recovery is obstructed by a file.".utf8).write(to: recoveryDirectory)
    let failedOperationId = UUID()
    let failed = await planner.execute(
      PlannerOperation(
        operationId: failedOperationId, session: session,
        command: .reorderMembership(
          listId: list.id, membershipId: memberships[2], placement: .first)))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
    guard case .rejected = failed.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: failedOperationId),
      case .rows(let retainedWindow) = await planner.read(
        session: session,
        request: .rows(generation: issued.generation, offset: 0, limit: 3)),
      case .source(.list(let retainedList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(items[0])),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw TestSetupFailure() }
    #expect(retainedWindow.rows.map(\.title) == ["A", "B", "C"])
    #expect(retainedList.references == originalList.references)
    #expect(retainedList.updatedAt == originalList.updatedAt)
    #expect(retainedList.fieldHashes == originalList.fieldHashes)
    #expect(
      retainedItem.updatedAt == originalItem.updatedAt
        && retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 9)
    #expect(namespace.preparedProposals.isEmpty)
  }

  @Test func closeAnchorReordersRebalanceWithoutLosingAnAppearanceOrResettingCompletion()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let session = try #require(await readySession(planner))
    let list = try #require(
      await createSource(
        planner, session: session,
        command: .createList(content: .init(name: "Tokyo"))))
    var memberships: [UUID] = []
    for title in [
      "A", "B", "C", "M00", "M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08", "M09", "M10",
      "M11", "M12",
    ] {
      let item = try #require(
        await createSource(
          planner, session: session,
          command: .createItem(content: .init(title: title))))
      guard
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = added.generatedReferences.first
      else { throw TestSetupFailure() }
      memberships.append(membershipId)
    }
    let completedAppearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: memberships[6])
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(completedAppearance), done: true))
      ).outcome
    else { throw TestSetupFailure() }
    for membershipId in memberships.dropFirst(3) {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .reorderMembership(
              listId: list.id, membershipId: membershipId,
              placement: .after(associationId: memberships[0])))
        ).outcome
      else { throw TestSetupFailure() }
    }
    guard
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual))))),
      case .rows(let window) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 16)),
      case .appearance(let completed) = await planner.read(
        session: session, request: .appearance(completedAppearance)),
      case .source(.list(let retainedList)) = await planner.read(
        session: session, request: .source(list))
    else { throw TestSetupFailure() }
    #expect(
      window.rows.map(\.title) == [
        "A", "M12", "M11", "M10", "M09", "M08", "M07", "M06", "M05", "M04", "M03", "M02", "M01",
        "M00", "B", "C",
      ])
    #expect(retainedList.references.count == 16)
    #expect(
      Set(
        retainedList.references.map { reference -> UUID? in
          if case .membership(let identifier, _, _) = reference { return identifier }
          return nil
        }) == Set(memberships))
    #expect(completed.localDone && completed.effectiveDone && !completed.globalDone)
    #expect(retainedList.progress.doneCount == 1 && retainedList.progress.totalCount == 16)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .reorderMembership(
            listId: list.id, membershipId: memberships[2],
            placement: .before(associationId: memberships[1])))
      ).outcome,
      case .snapshot(let finalSnapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual))))),
      case .rows(let finalWindow) = await planner.read(
        session: session,
        request: .rows(generation: finalSnapshot.generation, offset: 0, limit: 16))
    else { throw TestSetupFailure() }
    #expect(
      finalWindow.rows.map(\.title) == [
        "A", "M12", "M11", "M10", "M09", "M08", "M07", "M06", "M05", "M04", "M03", "M02", "M01",
        "M00", "C", "B",
      ])

  }

  private struct TestSetupFailure: Error {}

  private func readySession(_ planner: Planner) async -> PlannerDatasetSession? {
    if case .ready(let session) = await planner.bootstrap() { return session }
    return nil
  }

  private func createSource(
    _ planner: Planner, session: PlannerDatasetSession, command: PlannerCommand
  )
    async -> PlannerEntityReference?
  {
    if case .applied(let result, .complete) = await planner.execute(
      PlannerOperation(operationId: UUID(), session: session, command: command)
    ).outcome {
      return result.generated.first
    }
    return nil
  }

  private func orderedSources(_ planner: Planner, session: PlannerDatasetSession, list: UUID) async
    -> [UUID]?
  {
    guard
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(scope: .list(list), completion: .all, archive: .all, sort: .init(mode: .manual))))
      )
    else { return nil }
    return snapshot.rows.compactMap { row in
      if case .appearance(let source, _) = row { return source.id }
      return nil
    }
  }
}
