import Foundation
import PlannerCore
import Testing

struct MembershipRemovalTests {
  @Test func removingOneAppearanceRetainsSharedContentAndOrdinaryReAddStartsTodo() async throws {
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
      command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep notes")))
    let firstList = try await source(
      planner, session: session,
      command: .createList(content: PlannerListContentInput(name: "Tokyo")))
    let secondList = try await source(
      planner, session: session,
      command: .createList(content: PlannerListContentInput(name: "Wishlist")))
    let removedReference = try await membership(
      planner, session: session, item: item, list: firstList)
    let retainedReference = try await membership(
      planner, session: session, item: item, list: secondList)
    guard case .membership(let removedIdentifier, _, _) = removedReference,
      case .membership(let retainedIdentifier, _, _) = retainedReference,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(
              .listMembership(listId: firstList.id, membershipId: removedIdentifier)), done: true))
      ).outcome,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalSecondList)) = await planner.read(
        session: session, request: .source(secondList))
    else {
      Issue.record("Both independent memberships must exist before removing one.")
      return
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.removeMembership(
      listId: firstList.id, membershipId: removedIdentifier)
    guard
      case .applied(let removed, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(operationId: operationIdentifier, session: session, command: command)
      ).outcome
    else {
      Issue.record("Removing one membership must apply and acknowledge independent recovery.")
      return
    }
    #expect(checkpoint == 7)
    #expect(removed.generatedIdentities.isEmpty)
    #expect(removed.affectedReferences == [removedReference])
    #expect(removed.affected == [firstList])
    let replacement = try await membership(planner, session: session, item: item, list: firstList)
    guard case .membership(let replacementIdentifier, _, _) = replacement else {
      Issue.record("Ordinary re-add must create a new membership.")
      return
    }
    #expect(replacementIdentifier != removedIdentifier)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let retainedList)) = await reopened.read(
        session: reopenedSession, request: .source(secondList)),
      case .appearance(let replacementAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: firstList.id, membershipId: replacementIdentifier))),
      case .appearance(let retainedAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: secondList.id, membershipId: retainedIdentifier))),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Reopening and replay must retain the new and unrelated memberships.")
      return
    }
    #expect(replay == removed)
    #expect(replayCheckpoint == checkpoint)
    #expect(retainedItem.content.title == "Hotel")
    #expect(retainedItem.content.notes == "Keep notes")
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedItem.state.globalDone == false)
    #expect(retainedItem.references.count == 2)
    #expect(retainedItem.references.contains(replacement))
    #expect(retainedItem.references.contains(retainedReference))
    #expect(retainedList.references == originalSecondList.references)
    #expect(retainedList.updatedAt == originalSecondList.updatedAt)
    #expect(!replacementAppearance.localDone && !replacementAppearance.effectiveDone)
    #expect(!retainedAppearance.localDone && !retainedAppearance.effectiveDone)
    #expect(recovery.decodedBackup.backup.memberships.count == 1)
    #expect(recovery.decodedBackup.backup.memberships.first?.id == retainedIdentifier)
    #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
    let marker = try #require(recovery.decodedBackup.backup.deletionMarkers.first)
    #expect(marker.operationId == operationIdentifier)
    #expect(marker.target == .membership(id: removedIdentifier, lifetimeId: removedIdentifier))
    let portable = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let encodedMarker = try #require((portable["deletionMarkers"] as? [[String: Any]])?.first)
    #expect(Set(encodedMarker.keys) == ["deletionId", "operationId", "target", "closedFamilyId"])
    let encodedTarget = try #require(encodedMarker["target"] as? [String: Any])
    #expect(Set(encodedTarget.keys) == ["kind", "membership"])
    #expect(encodedTarget["kind"] as? String == "membership")
    let encodedBinding = try #require(encodedTarget["membership"] as? [String: Any])
    #expect(Set(encodedBinding.keys) == ["kind", "id", "lifetimeId"])
    guard
      case .failed(let missing) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: firstList.id, membershipId: removedIdentifier))
      )
    else {
      Issue.record("The removed appearance must stay unavailable after replay.")
      return
    }
    #expect(missing.code == "missingReference")
  }

  @Test func invalidRemovalAndRecoveryObstructionRetainTheAppearanceAndIssuedWindow() async throws {
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
      Issue.record("The local dataset must initialize.")
      return
    }
    let item = try await source(
      planner, session: session, command: .createItem(content: .init(title: "Hotel")))
    let list = try await source(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let otherList = try await source(
      planner, session: session, command: .createList(content: .init(name: "Wishlist")))
    let reference = try await membership(planner, session: session, item: item, list: list)
    guard case .membership(let membershipIdentifier, _, _) = reference,
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))))
    else { throw FixtureFailure.unexpectedOutcome }
    for (listIdentifier, selectedIdentifier) in [
      (otherList.id, membershipIdentifier), (item.id, membershipIdentifier),
      (list.id, item.id), (list.id, list.id), (UUID(), membershipIdentifier), (list.id, UUID()),
    ] {
      let operationIdentifier = UUID()
      guard
        case .rejected(let rejected) = await planner.execute(
          PlannerOperation(
            operationId: operationIdentifier, session: session,
            command: .removeMembership(listId: listIdentifier, membershipId: selectedIdentifier))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else { throw FixtureFailure.unexpectedOutcome }
      #expect(rejected.code == "missingReference")
    }
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedRecoveryDirectory)
    try Data("Obstruct independent recovery.".utf8).write(to: recoveryDirectory)
    let failedOperationIdentifier = UUID()
    let failed = await planner.execute(
      PlannerOperation(
        operationId: failedOperationIdentifier, session: session,
        command: .removeMembership(listId: list.id, membershipId: membershipIdentifier)))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedRecoveryDirectory, to: recoveryDirectory)
    guard case .rejected(let rejected) = failed.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: failedOperationIdentifier),
      case .source(.list(let retainedList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .appearance(let retainedAppearance) = await planner.read(
        session: session,
        request: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier))),
      case .rows(let retainedWindow) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(rejected.code == "persistenceFailure")
    #expect(retainedList.references == [reference])
    #expect(retainedList.updatedAt == originalList.updatedAt)
    #expect(retainedList.progress.totalCount == 1 && retainedList.progress.doneCount == 0)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(!retainedAppearance.localDone && !retainedAppearance.effectiveDone)
    #expect(retainedWindow.rows.count == 1)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  private func source(
    _ planner: Planner, session: PlannerDatasetSession, command: PlannerCommand
  ) async throws -> PlannerEntityReference {
    guard
      case .applied(let result, .complete) = await planner.execute(
        PlannerOperation(operationId: UUID(), session: session, command: command)
      ).outcome
    else {
      Issue.record("Fixture source creation must save.")
      throw FixtureFailure.unexpectedOutcome
    }
    return try #require(result.generated.first)
  }

  private func membership(
    _ planner: Planner, session: PlannerDatasetSession, item: PlannerEntityReference,
    list: PlannerEntityReference
  ) async throws -> PlannerReferenceRead {
    guard
      case .applied(let result, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome
    else {
      Issue.record("Fixture membership creation must save.")
      throw FixtureFailure.unexpectedOutcome
    }
    return try #require(result.generatedReferences.first)
  }

  private enum FixtureFailure: Error { case unexpectedOutcome }
}
