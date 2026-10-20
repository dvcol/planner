import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItemDestinationIntentTests: XCTestCase {
  func testCreationAppendsOneTodoAppearanceToTheSelectedListAfterReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Tokyo"
    let destination = try await listCreation.callAsFunction(donate: false)
    let other = try await listCreation.callAsFunction(donate: false)
    let creation = CreatePlannerItemIntent()
    creation.title = "Existing museum"
    let existing = try await creation.callAsFunction(donate: false)
    let adding = AddPlannerItemToListIntent()
    adding.item = existing
    adding.list = destination
    let _: Void = try await adding.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(.init(kind: .list, id: destination.id))),
      case .membership(let existingMembership, _, _)? = before.references.first
    else { return XCTFail("The destination must contain the original saved appearance.") }
    let existingAppearance = PlannerAppearance.listMembership(
      listId: destination.id, membershipId: existingMembership)
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(existingAppearance), done: true))
      ).outcome
    else { return XCTFail("The existing appearance must have its independent Done state.") }
    creation.title = "New museum"
    creation.subtitle = "  Réservation · 金曜日  "
    creation.notes = "Tickets booked\nKeep the original text"
    creation.list = .init(id: destination.id, name: "Obsolete cached name", archived: true)
    let item = try await creation.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let saved)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .item, id: item.id))),
      case .source(.list(let populated)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .list, id: destination.id))),
      case .source(.list(let untouched)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .list, id: other.id))),
      case .membership(let membership, let owner, let source)? = saved.references.first,
      case .appearance(let appearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: destination.id, membershipId: membership))),
      case .appearance(let retained) = await reopened.read(
        session: reopenedSession, request: .appearance(existingAppearance)),
      case .snapshot(let ordered) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(
            .init(
              scope: .list(destination.id), completion: .all, archive: .all,
              sort: .init(mode: .manual)))))
    else { return XCTFail("Creation must save the Item and its List appearance together.") }
    XCTAssertEqual(saved.content.title, "New museum")
    XCTAssertEqual(saved.content.subtitle, "  Réservation · 金曜日  ")
    XCTAssertEqual(saved.content.notes, "Tickets booked\nKeep the original text")
    XCTAssertEqual(owner, .init(kind: .list, id: destination.id))
    XCTAssertEqual(source, saved.source)
    XCTAssertEqual(saved.references.count, 1)
    XCTAssertEqual(populated.references.count, 2)
    XCTAssertEqual(populated.content.name, "Tokyo")
    XCTAssertTrue(untouched.references.isEmpty)
    XCTAssertFalse(appearance.globalDone)
    XCTAssertFalse(appearance.localDone)
    XCTAssertFalse(appearance.effectiveDone)
    XCTAssertTrue(retained.localDone)
    XCTAssertEqual(
      ordered.rows,
      [
        .appearance(source: .init(kind: .item, id: existing.id), appearance: existingAppearance),
        .appearance(
          source: saved.source,
          appearance: .listMembership(listId: destination.id, membershipId: membership)),
      ])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testOmittingOrClearingTheDestinationKeepsOrdinaryGlobalCreation() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Wishlist"
    let destination = try await listCreation.callAsFunction(donate: false)
    let creation = CreatePlannerItemIntent()
    creation.title = "Without a List"
    let omitted = try await creation.callAsFunction(donate: false)
    creation.list = destination
    creation.title = "In the List"
    let listed = try await creation.callAsFunction(donate: false)
    creation.list = nil
    creation.title = "Global again"
    let cleared = try await creation.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.list(let savedList)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: destination.id))),
      case .snapshot(let inbox) = await reopened.query(
        .init(
          session: session,
          request: .items(.init(scope: .inbox, completion: .all, archive: .all))))
    else { return XCTFail("Global creation must remain separate from the optional destination.") }
    XCTAssertEqual(savedList.references.count, 1)
    guard case .membership(_, let owner, let source)? = savedList.references.first else {
      return XCTFail("Only the destination-bearing invocation may create a membership.")
    }
    XCTAssertEqual(owner, savedList.source)
    XCTAssertEqual(source, .init(kind: .item, id: listed.id))
    XCTAssertEqual(
      inbox.rows,
      [.source(.init(kind: .item, id: cleared.id)), .source(.init(kind: .item, id: omitted.id))])
    XCTAssertFalse(store.recoveryBlocked)
  }

  func testInvalidDestinationsAndContentCreateNeitherAnOrphanItemNorAMembership() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Active"
    let active = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "Archived"
    let archived = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "Deleted"
    let deleted = try await listCreation.callAsFunction(donate: false)
    let creation = CreatePlannerItemIntent()
    creation.title = "Existing unrelated Item"
    let existing = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let deletedSource = PlannerEntityReference(kind: .list, id: deleted.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: .init(kind: .list, id: archived.id), archived: true))
      ).outcome,
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: deletedSource)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: deletedSource),
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { return XCTFail("Invalid destination fixtures must have their current saved states.") }
    creation.title = "Must not be created"
    creation.notes = "Must not leave partial data"
    for destination in [
      archived, deleted,
      .init(id: UUID(), name: "Missing", archived: false),
      .init(id: existing.id, name: "Wrong kind", archived: false),
    ] {
      creation.list = destination
      do {
        let _: PlannerItemEntity = try await creation.callAsFunction(donate: false)
        XCTFail("An unavailable destination must reject the entire ordinary creation.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    creation.list = active
    creation.title = "   "
    do {
      let _: PlannerItemEntity = try await creation.callAsFunction(donate: false)
      XCTFail("Invalid content cannot leave a membership or an Item behind.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let after) = await reopened.exportData(session: reopenedSession)
    else { return XCTFail("Rejected creations must leave readable current data.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledDestinationCreationPreservesTheDataset() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Wishlist"
    let destination = try await listCreation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session)
    else { return XCTFail("Cancellation must start from the saved empty destination.") }
    let creation = CreatePlannerItemIntent()
    creation.title = "Cancelled museum"
    creation.list = destination
    let task = Task { @MainActor in
      let _: PlannerItemEntity = try await creation.callAsFunction(donate: false)
    }
    task.cancel()
    do {
      try await task.value
      XCTFail("Precancelled creation must not save an Item or its membership.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      return XCTFail("The unchanged dataset must remain readable after cancellation.")
    }
    XCTAssertEqual(after, before)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testUnavailableBootstrapDoesNotAcknowledgeDestinationCreation() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let content = Data("Block ordinary store setup.".utf8)
    try content.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Unavailable museum"
    creation.list = .init(id: UUID(), name: "Wishlist", archived: false)
    do {
      let _: PlannerItemEntity = try await creation.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge an Item or its destination.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: obstruction), content)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testIncompleteRecoveryRetainsBothCreatedIdentitiesAndRepairsWithoutRepeatingCreation()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Wishlist"
    let destination = try await listCreation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let creation = CreatePlannerItemIntent()
    creation.title = "Recovery museum"
    creation.subtitle = "Retain the subtitle"
    creation.notes = "Retain the notes"
    creation.list = destination
    let item = try await creation.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    creation.title = "Must wait for recovery"
    do {
      let _: PlannerItemEntity = try await creation.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block the next destination-bearing creation.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let appliedItem)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id))),
      case .source(.list(let appliedList)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: destination.id))),
      case .membership(_, let owner, let source)? = appliedList.references.first
    else { return XCTFail("The applied Item and its original membership must survive reopening.") }
    XCTAssertEqual(appliedItem.content.title, "Recovery museum")
    XCTAssertEqual(appliedItem.content.subtitle, "Retain the subtitle")
    XCTAssertEqual(appliedItem.content.notes, "Retain the notes")
    XCTAssertEqual(appliedItem.references, appliedList.references)
    XCTAssertEqual(appliedList.references.count, 1)
    XCTAssertEqual(owner, appliedList.source)
    XCTAssertEqual(source, appliedItem.source)
    await store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.item(let recoveredItem)) = await reopened.read(
        session: session, request: .source(appliedItem.source)),
      case .source(.list(let recoveredList)) = await reopened.read(
        session: session, request: .source(appliedList.source)),
      case .snapshot(let items) = await reopened.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("Native recovery must acknowledge the original atomic creation.") }
    XCTAssertEqual(recoveredItem.fieldHashes, appliedItem.fieldHashes)
    XCTAssertEqual(recoveredItem.createdAt, appliedItem.createdAt)
    XCTAssertEqual(recoveredItem.updatedAt, appliedItem.updatedAt)
    XCTAssertEqual(recoveredItem.references, appliedItem.references)
    XCTAssertEqual(recoveredList.references, appliedList.references)
    XCTAssertEqual(recoveredList.updatedAt, appliedList.updatedAt)
    XCTAssertEqual(items.rows, [.source(appliedItem.source)])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    XCTAssertFalse(store.isSaving)
  }
}
