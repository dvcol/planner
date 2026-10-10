import Foundation
import PlannerCore
import Testing

struct MembershipMoveTests {
  @Test func movingCreatesANewTodoContextWithoutChangingTheSharedGloballyDoneItem() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize.")
      return
    }
    let item = try await source(
      planner, session: session,
      command: .createItem(content: .init(title: "Hotel", notes: "Shared notes")))
    let museum = try await source(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let originalList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let destinationList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Wishlist")))
    let originalMembership = try await membership(
      planner, session: session, item: item, list: originalList)
    let anchorMembership = try await membership(
      planner, session: session, item: museum, list: destinationList)
    _ = try await apply(
      planner, session: session,
      command: .setCompletion(
        scope: .appearance(
          .listMembership(listId: originalList.id, membershipId: originalMembership)), done: true))
    _ = try await apply(
      planner, session: session,
      command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else { throw FixtureFailure.unexpectedOutcome }
    let operationIdentifier = UUID()
    let command = PlannerCommand.moveMembership(
      listId: originalList.id, membershipId: originalMembership,
      destinationListId: destinationList.id, placement: .before(associationId: anchorMembership))
    let applied = try await apply(
      planner, session: session, command: command, operationId: operationIdentifier)
    guard
      case .membership(let destinationMembership, let owner, let sharedItem)? =
        applied.result.generatedReferences.first
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(applied.checkpoint == 9)
    #expect(destinationMembership != originalMembership)
    #expect(owner == destinationList && sharedItem == item)
    #expect(applied.result.generated.isEmpty)
    #expect(applied.result.affected == [originalList, destinationList])
    #expect(applied.result.affectedReferences.count == 2)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let emptiedList)) = await reopened.read(
        session: reopenedSession, request: .source(originalList)),
      case .source(.list(let destination)) = await reopened.read(
        session: reopenedSession, request: .source(destinationList)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .appearance(let newAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: destinationList.id, membershipId: destinationMembership))),
      case .failed(let missing) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: originalList.id, membershipId: originalMembership))),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: applied.checkpoint))
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(emptiedList.references.isEmpty)
    #expect(emptiedList.progress.state == .empty)
    #expect(emptiedList.progress.totalCount == 0)
    #expect(destination.progress.doneCount == 1 && destination.progress.totalCount == 2)
    #expect(!newAppearance.localDone && newAppearance.globalDone && newAppearance.effectiveDone)
    #expect(missing.code == "missingReference")
    #expect(retainedItem.content.title == "Hotel" && retainedItem.content.notes == "Shared notes")
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(
      await order(reopened, session: reopenedSession, list: destinationList) == [item, museum])
    #expect(recovery.decodedBackup.backup.items.count == 2)
    #expect(recovery.decodedBackup.backup.memberships.count == 2)
    #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
    #expect(
      recovery.decodedBackup.backup.deletionMarkers.first?.target
        == .membership(id: originalMembership, lifetimeId: originalMembership))
    _ = try await apply(
      reopened, session: reopenedSession,
      command: .setCompletion(scope: .globalItem(itemId: item.id), done: false))
    guard
      case .appearance(let reopenedAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: destinationList.id, membershipId: destinationMembership)))
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(!reopenedAppearance.localDone && !reopenedAppearance.effectiveDone)
    let replay = try await apply(
      reopened, session: reopenedSession, command: command, operationId: operationIdentifier)
    #expect(replay.result == applied.result && replay.checkpoint == applied.checkpoint)
    #expect(await order(reopened, session: reopenedSession, list: originalList) == [])
    #expect(
      await order(reopened, session: reopenedSession, list: destinationList) == [item, museum])
  }

  @Test func existingDestinationKeepsIdentityOrderAndCompletionAndReplayCannotRestoreIt()
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
      throw FixtureFailure.unexpectedOutcome
    }
    let item = try await source(
      planner, session: session, command: .createItem(content: .init(title: "Hotel")))
    let museum = try await source(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let originalList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let destinationList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Wishlist")))
    let otherList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Other")))
    let originalMembership = try await membership(
      planner, session: session, item: item, list: originalList)
    _ = try await membership(planner, session: session, item: museum, list: destinationList)
    let existingMembership = try await membership(
      planner, session: session, item: item, list: destinationList)
    let otherMembership = try await membership(
      planner, session: session, item: item, list: otherList)
    _ = try await apply(
      planner, session: session,
      command: .setCompletion(
        scope: .appearance(
          .listMembership(listId: destinationList.id, membershipId: existingMembership)), done: true
      ))
    guard
      case .source(.list(let originalDestination)) = await planner.read(
        session: session, request: .source(destinationList)),
      case .source(.list(let originalOtherList)) = await planner.read(
        session: session, request: .source(otherList)),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else { throw FixtureFailure.unexpectedOutcome }
    let operationIdentifier = UUID()
    let command = PlannerCommand.moveMembership(
      listId: originalList.id, membershipId: originalMembership,
      destinationListId: destinationList.id, placement: .first)
    let applied = try await apply(
      planner, session: session, command: command, operationId: operationIdentifier)
    #expect(applied.checkpoint == 11)
    #expect(applied.result.generatedIdentities.isEmpty)
    #expect(
      applied.result.affectedReferences == [
        .membership(id: originalMembership, list: originalList, item: item),
        .membership(id: existingMembership, list: destinationList, item: item),
      ])
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let retainedDestination)) = await reopened.read(
        session: reopenedSession, request: .source(destinationList)),
      case .source(.list(let retainedOtherList)) = await reopened.read(
        session: reopenedSession, request: .source(otherList)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .appearance(let retainedDestinationAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: destinationList.id, membershipId: existingMembership))),
      case .appearance(let retainedOtherAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: otherList.id, membershipId: otherMembership)))
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(retainedDestination.references == originalDestination.references)
    #expect(retainedDestination.updatedAt == originalDestination.updatedAt)
    #expect(retainedDestination.fieldHashes == originalDestination.fieldHashes)
    #expect(retainedDestinationAppearance.localDone && retainedDestinationAppearance.effectiveDone)
    #expect(!retainedDestinationAppearance.globalDone)
    #expect(
      await order(reopened, session: reopenedSession, list: destinationList) == [museum, item])
    #expect(retainedOtherList.references == originalOtherList.references)
    #expect(retainedOtherList.updatedAt == originalOtherList.updatedAt)
    #expect(!retainedOtherAppearance.localDone && !retainedOtherAppearance.effectiveDone)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    guard
      case .rejected(let mismatch) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession,
          command: .moveMembership(
            listId: originalList.id, membershipId: originalMembership,
            destinationListId: destinationList.id, placement: .last))
      ).outcome
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(mismatch.code == "operationPayloadMismatch")
    _ = try await apply(
      reopened, session: reopenedSession,
      command: .removeMembership(listId: destinationList.id, membershipId: existingMembership))
    let replay = try await apply(
      reopened, session: reopenedSession, command: command, operationId: operationIdentifier)
    #expect(replay.result == applied.result && replay.checkpoint == applied.checkpoint)
    #expect(await order(reopened, session: reopenedSession, list: originalList) == [])
    #expect(await order(reopened, session: reopenedSession, list: destinationList) == [museum])
    #expect(await order(reopened, session: reopenedSession, list: otherList) == [item])
  }

  @Test func invalidMoveAndRecoveryObstructionLeaveBothListsAndIssuedWindowsUnchanged() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let retainedRecoveryDirectory = directory.appendingPathComponent("retained-recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
        storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      throw FixtureFailure.unexpectedOutcome
    }
    let item = try await source(
      planner, session: session, command: .createItem(content: .init(title: "Hotel")))
    let museum = try await source(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let originalList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let destinationList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Wishlist")))
    let originalMembership = try await membership(
      planner, session: session, item: item, list: originalList)
    _ = try await membership(planner, session: session, item: museum, list: destinationList)
    guard
      case .source(.list(let originalOwner)) = await planner.read(
        session: session, request: .source(originalList)),
      case .source(.list(let originalDestination)) = await planner.read(
        session: session, request: .source(destinationList)),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(originalList.id), completion: .all, archive: .all,
              sort: .init(mode: .manual)))))
    else { throw FixtureFailure.unexpectedOutcome }
    let variants: [(UUID, UUID, UUID, PlannerPlacement, String, String?)] = [
      (
        originalList.id, originalMembership, originalList.id, .last, "invalidInput",
        "/command/destinationListId"
      ),
      (destinationList.id, originalMembership, originalList.id, .last, "missingReference", nil),
      (item.id, originalMembership, destinationList.id, .last, "missingReference", nil),
      (originalList.id, item.id, destinationList.id, .last, "missingReference", nil),
      (originalList.id, UUID(), destinationList.id, .last, "missingReference", nil),
      (originalList.id, originalMembership, UUID(), .last, "missingReference", nil),
      (originalList.id, originalMembership, item.id, .first, "missingReference", nil),
      (
        originalList.id, originalMembership, destinationList.id,
        .before(associationId: originalMembership), "missingReference",
        "/command/placement/associationId"
      ),
      (
        originalList.id, originalMembership, destinationList.id,
        .after(associationId: UUID()), "missingReference", "/command/placement/associationId"
      ),
    ]
    for (listIdentifier, membershipIdentifier, destinationIdentifier, placement, code, path)
      in variants
    {
      let operationIdentifier = UUID()
      guard
        case .rejected(let rejected) = await planner.execute(
          PlannerOperation(
            operationId: operationIdentifier, session: session,
            command: .moveMembership(
              listId: listIdentifier, membershipId: membershipIdentifier,
              destinationListId: destinationIdentifier, placement: placement))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else { throw FixtureFailure.unexpectedOutcome }
      #expect(rejected.code == code && rejected.propertyPath == path)
    }
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedRecoveryDirectory)
    try Data("Obstruct independent recovery.".utf8).write(to: recoveryDirectory)
    let failedOperationIdentifier = UUID()
    let failed = await planner.execute(
      PlannerOperation(
        operationId: failedOperationIdentifier, session: session,
        command: .moveMembership(
          listId: originalList.id, membershipId: originalMembership,
          destinationListId: destinationList.id, placement: .first)))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedRecoveryDirectory, to: recoveryDirectory)
    guard case .rejected(let rejected) = failed.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: failedOperationIdentifier),
      case .source(.list(let retainedOwner)) = await planner.read(
        session: session, request: .source(originalList)),
      case .source(.list(let retainedDestination)) = await planner.read(
        session: session, request: .source(destinationList)),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .rows(let retainedWindow) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(rejected.code == "persistenceFailure")
    #expect(retainedOwner.references == originalOwner.references)
    #expect(retainedOwner.updatedAt == originalOwner.updatedAt)
    #expect(retainedDestination.references == originalDestination.references)
    #expect(retainedDestination.updatedAt == originalDestination.updatedAt)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedWindow.rows.count == 1)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 6)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  private func apply(
    _ planner: Planner, session: PlannerDatasetSession, command: PlannerCommand,
    operationId: UUID = UUID()
  ) async throws -> (result: PlannerAppliedResult, checkpoint: Int64) {
    let result = await planner.execute(
      PlannerOperation(operationId: operationId, session: session, command: command))
    guard case .applied(let applied, .complete(let checkpoint)) = result.outcome else {
      Issue.record("The complete local action must save: \(result.outcome)")
      throw FixtureFailure.unexpectedOutcome
    }
    return (applied, checkpoint)
  }

  private func source(
    _ planner: Planner, session: PlannerDatasetSession, command: PlannerCommand
  ) async throws -> PlannerEntityReference {
    let applied = try await apply(planner, session: session, command: command)
    return try #require(applied.result.generated.first)
  }

  private func membership(
    _ planner: Planner, session: PlannerDatasetSession, item: PlannerEntityReference,
    list: PlannerEntityReference
  ) async throws -> UUID {
    let applied = try await apply(
      planner, session: session,
      command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .membership(let identifier, _, _)? = applied.result.generatedReferences.first else {
      throw FixtureFailure.unexpectedOutcome
    }
    return identifier
  }

  private func order(
    _ planner: Planner, session: PlannerDatasetSession, list: PlannerEntityReference
  ) async -> [PlannerEntityReference]? {
    guard
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))))
    else { return nil }
    return snapshot.rows.compactMap {
      if case .appearance(let source, _) = $0 { return source }
      return nil
    }
  }

  private enum FixtureFailure: Error { case unexpectedOutcome }
}
