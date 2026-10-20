import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerListCompletionIntentTests: XCTestCase {
  func testListCompletionRetainsIndependentContextsAndGlobalPrecedenceThroughReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let createdItem = try await save(
      .createItem(content: .init(title: "Museum", notes: "Shared notes")))
    let item = try XCTUnwrap(createdItem.generated.first)
    let first = try await save(.createList(content: .init(name: "Tokyo Food")))
    let sourceList = try XCTUnwrap(first.generated.first)
    let second = try await save(.createList(content: .init(name: "Wishlist")))
    let otherList = try XCTUnwrap(second.generated.first)
    let membership = try await save(
      .addMembership(itemId: item.id, listId: sourceList.id, placement: .last))
    let otherMembership = try await save(
      .addMembership(itemId: item.id, listId: otherList.id, placement: .last))
    guard case .membership(let identifier, _, _)? = membership.generatedReferences.first,
      case .membership(let otherIdentifier, _, _)? = otherMembership.generatedReferences.first
    else { return XCTFail("The two Lists must have independent membership identities.") }
    let appearance = PlannerAppearance.listMembership(
      listId: sourceList.id, membershipId: identifier)
    let otherAppearance = PlannerAppearance.listMembership(
      listId: otherList.id, membershipId: otherIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(otherAppearance), done: true))
    let createdPlan = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
    let itinerary = try XCTUnwrap(createdPlan.generated.first)
    let direct = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    let branch = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: sourceList, placement: .last))
    guard case .itineraryEntry(let directIdentifier, _, _)? = direct.generatedReferences.first,
      case .itineraryEntry(let branchIdentifier, _, _)? = branch.generatedReferences.first
    else { return XCTFail("The direct and expanded itinerary contexts must exist.") }
    let directAppearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: directIdentifier)
    let expandedAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: branchIdentifier, membershipId: identifier)
    _ = try await save(.setCompletion(scope: .appearance(expandedAppearance), done: true))
    let form = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
    let booking = try await save(.createSchedule(source: item, form: form))
    let schedule = try XCTUnwrap(booking.generated.first)
    guard
      case .source(.item(let before)) = await planner.read(session: session, request: .source(item))
    else { return XCTFail("Shared content must be readable before local completion.") }
    let completion = SetPlannerItemListCompletionIntent()
    completion.item = .init(id: item.id, title: "Obsolete title", done: true, archived: true)
    completion.list = .init(id: sourceList.id, name: "Obsolete name", archived: true)
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    guard
      case .source(.item(let afterLocal)) = await planner.read(
        session: session, request: .source(item)),
      case .appearance(let locallyDone) = await planner.read(
        session: session, request: .appearance(appearance))
    else { return XCTFail("Only the selected local flag may change.") }
    XCTAssertEqual(afterLocal.fieldHashes, before.fieldHashes)
    XCTAssertEqual(afterLocal.updatedAt, before.updatedAt)
    XCTAssertEqual(afterLocal.state.globalDone, false)
    XCTAssertEqual(afterLocal.state.archived, false)
    XCTAssertTrue(locallyDone.localDone)
    XCTAssertTrue(locallyDone.effectiveDone)
    let globalCompletion = SetPlannerItemCompletionIntent()
    globalCompletion.item = completion.item
    globalCompletion.done = true
    let _: Void = try await globalCompletion.callAsFunction(donate: false)
    guard
      case .source(.item(let globallyDone)) = await planner.read(
        session: session, request: .source(item))
    else { return XCTFail("The explicit Item action must set global completion first.") }
    completion.done = false
    let _: Void = try await completion.callAsFunction(donate: false)
    guard
      case .source(.item(let afterLocalReopen)) = await planner.read(
        session: session, request: .source(item)),
      case .appearance(let masked) = await planner.read(
        session: session, request: .appearance(appearance))
    else { return XCTFail("Clearing local completion must retain global Done precedence.") }
    XCTAssertEqual(afterLocalReopen.updatedAt, globallyDone.updatedAt)
    XCTAssertTrue(masked.globalDone)
    XCTAssertFalse(masked.localDone)
    XCTAssertTrue(masked.effectiveDone)
    globalCompletion.done = false
    let _: Void = try await globalCompletion.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let savedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let savedList)) = await reopened.read(
        session: reopenedSession, request: .source(sourceList)),
      case .source(.itinerary(let savedPlan)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.schedule(let savedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule))
    else { return XCTFail("The full graph must survive reopening after global Reopen.") }
    for (context, expectedLocalDone) in [
      (appearance, false), (otherAppearance, true), (directAppearance, false),
      (expandedAppearance, true),
    ] {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(context))
      else { return XCTFail("Every original completion context must remain readable.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, expectedLocalDone)
      XCTAssertEqual(current.effectiveDone, expectedLocalDone)
      XCTAssertEqual(current.content.notes, "Shared notes")
    }
    XCTAssertEqual(savedItem.content.title, "Museum")
    XCTAssertEqual(savedItem.state.globalDone, false)
    XCTAssertEqual(savedItem.state.archived, false)
    XCTAssertEqual(savedList.content.name, "Tokyo Food")
    XCTAssertEqual(savedList.state.archived, false)
    XCTAssertEqual(savedList.progress.doneCount, 0)
    XCTAssertEqual(savedPlan.progress.totalCount, 2)
    XCTAssertEqual(savedPlan.progress.doneCount, 1)
    XCTAssertEqual(savedSchedule.content.form, form)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testMissingWrongKindRemovedAndDeletedPairsCannotFallBackToGlobalCompletion() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    let item = try await creation.callAsFunction(donate: false)
    creation.title = "Untouched lunch"
    let otherItem = try await creation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Tokyo Food"
    let list = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "Empty destination"
    let otherList = try await listCreation.callAsFunction(donate: false)
    let adding = AddPlannerItemToListIntent()
    adding.item = item
    adding.list = list
    let _: Void = try await adding.callAsFunction(donate: false)
    adding.item = otherItem
    let _: Void = try await adding.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let listReference = PlannerEntityReference(kind: .list, id: list.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(listReference)),
      case .membership(let identifier, _, _)? = before.references.first,
      case .membership(let otherIdentifier, _, _)? = before.references.last
    else { return XCTFail("Missing-pair checks require two actual untouched memberships.") }
    func requireRejected(item selectedItem: PlannerItemEntity, list selectedList: PlannerListEntity)
      async
    {
      let completion = SetPlannerItemListCompletionIntent()
      completion.item = selectedItem
      completion.list = selectedList
      completion.done = true
      do {
        let _: Void = try await completion.callAsFunction(donate: false)
        XCTFail("An unavailable pair cannot acknowledge completion or change its scope.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    await requireRejected(item: item, list: otherList)
    for unavailable in [UUID(), item.id] {
      await requireRejected(
        item: item, list: .init(id: unavailable, name: "Unavailable", archived: false))
    }
    for unavailable in [UUID(), list.id] {
      await requireRejected(
        item: .init(id: unavailable, title: "Unavailable", done: false, archived: false), list: list
      )
    }
    guard
      case .source(.list(let afterInvalid)) = await planner.read(
        session: session, request: .source(listReference)),
      case .source(.item(let unchanged)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("Rejected requests must preserve original data.") }
    XCTAssertEqual(afterInvalid.references, before.references)
    XCTAssertEqual(afterInvalid.updatedAt, before.updatedAt)
    XCTAssertEqual(afterInvalid.progress.doneCount, 0)
    XCTAssertEqual(unchanged.state.globalDone, false)
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: identifier))
      ).outcome
    else {
      return XCTFail("The selected association must be removed before testing its cached pair.")
    }
    await requireRejected(item: item, list: list)
    func delete(_ source: PlannerEntityReference) async throws {
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .deleteSource(source: source)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: .deleteSource(source: source),
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    try await delete(.init(kind: .list, id: otherList.id))
    await requireRejected(item: item, list: otherList)
    guard
      case .source(.item(let afterAbsentPair)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("Removing a membership must preserve its shared Item.") }
    XCTAssertEqual(afterAbsentPair.state.globalDone, false)
    try await delete(.init(kind: .item, id: item.id))
    await requireRejected(item: item, list: list)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(listReference)),
      case .appearance(let otherState) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: otherIdentifier))),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all)))),
      case .snapshot(let lists) = await reopened.query(
        .init(session: reopenedSession, request: .catalog(.init(sourceKind: .list, archive: .all))))
    else { return XCTFail("Only the surviving untouched Item/List context may remain.") }
    XCTAssertEqual(
      retained.references,
      [
        .membership(
          id: otherIdentifier, list: listReference, item: .init(kind: .item, id: otherItem.id))
      ])
    XCTAssertEqual(retained.progress.doneCount, 0)
    XCTAssertFalse(otherState.globalDone)
    XCTAssertFalse(otherState.localDone)
    XCTAssertFalse(otherState.effectiveDone)
    XCTAssertEqual(items.rows, [.source(.init(kind: .item, id: otherItem.id))])
    XCTAssertEqual(lists.rows, [.source(listReference)])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledLocalCompletionPreservesAValidTodoMembership() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    let item = try await creation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Tokyo Food"
    let list = try await listCreation.callAsFunction(donate: false)
    let adding = AddPlannerItemToListIntent()
    adding.item = item
    adding.list = list
    let _: Void = try await adding.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let reference = PlannerEntityReference(kind: .list, id: list.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(reference)),
      case .membership(let identifier, _, _)? = before.references.first
    else { return XCTFail("Cancellation must target an otherwise valid Todo membership.") }
    let completion = SetPlannerItemListCompletionIntent()
    completion.item = item
    completion.list = list
    completion.done = true
    let request = Task {
      let _: Void = try await completion.callAsFunction(donate: false)
    }
    request.cancel()
    do {
      let _: Void = try await request.value
      XCTFail("Pre-invocation cancellation cannot acknowledge a local completion change.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let after)) = await reopened.read(
        session: reopenedSession, request: .source(reference)),
      case .appearance(let current) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: identifier)))
    else { return XCTFail("The unchanged original context must survive reopening.") }
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.progress.doneCount, 0)
    XCTAssertFalse(current.globalDone)
    XCTAssertFalse(current.localDone)
    XCTAssertFalse(current.effectiveDone)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedLocalCompletionSurvivesRecoveryFailureAndBlocksLocalAndGlobalChanges()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.notes = "Keep shared notes"
    let item = try await creation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Tokyo Food"
    let list = try await listCreation.callAsFunction(donate: false)
    let adding = AddPlannerItemToListIntent()
    adding.item = item
    adding.list = list
    let _: Void = try await adding.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let itemReference = PlannerEntityReference(kind: .item, id: item.id)
    let listReference = PlannerEntityReference(kind: .list, id: list.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(itemReference)),
      case .source(.list(let beforeList)) = await planner.read(
        session: session, request: .source(listReference)),
      case .membership(let identifier, _, _)? = beforeList.references.first
    else { return XCTFail("The durable original sources must exist before the recovery fault.") }
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: identifier)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let completion = SetPlannerItemListCompletionIntent()
    completion.item = item
    completion.list = list
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    completion.done = false
    do {
      let _: Void = try await completion.callAsFunction(donate: false)
      XCTFail("An applied action with incomplete recovery must block local Reopen.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let globalCompletion = SetPlannerItemCompletionIntent()
    globalCompletion.item = item
    globalCompletion.done = true
    do {
      let _: Void = try await globalCompletion.callAsFunction(donate: false)
      XCTFail("The recovery block must also prevent a separate global Item mutation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .appearance(let applied) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance)),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(itemReference)),
      case .source(.list(let appliedList)) = await reopened.read(
        session: reopenedSession, request: .source(listReference))
    else {
      return XCTFail(
        "The applied local flag and independent shared content must survive the fault.")
    }
    XCTAssertTrue(applied.localDone)
    XCTAssertTrue(applied.effectiveDone)
    XCTAssertFalse(applied.globalDone)
    XCTAssertEqual(retained.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(retained.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(appliedList.references, beforeList.references)
    XCTAssertEqual(appliedList.progress.doneCount, 1)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier),
      case .source(.list(let recoveredList)) = await reopened.read(
        session: reopenedSession, request: .source(listReference))
    else {
      return XCTFail("Native retry must acknowledge the original local completion operation.")
    }
    XCTAssertEqual(recoveredList.references, appliedList.references)
    XCTAssertEqual(recoveredList.updatedAt, appliedList.updatedAt)
    XCTAssertEqual(recoveredList.progress.doneCount, 1)
    let _: Void = try await completion.callAsFunction(donate: false)
    guard
      case .appearance(let finalState) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance)),
      case .source(.list(let finalList)) = await reopened.read(
        session: reopenedSession, request: .source(listReference))
    else { return XCTFail("A subsequent explicit local Reopen must work after recovery.") }
    XCTAssertFalse(finalState.globalDone)
    XCTAssertFalse(finalState.localDone)
    XCTAssertFalse(finalState.effectiveDone)
    XCTAssertEqual(finalState.content.notes, "Keep shared notes")
    XCTAssertEqual(finalList.references, beforeList.references)
    XCTAssertEqual(finalList.progress.doneCount, 0)
    XCTAssertFalse(store.isSaving)
  }

  func testUnavailableStorageCannotAcknowledgeLocalCompletion() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let completion = SetPlannerItemListCompletionIntent()
    completion.item = .init(id: UUID(), title: "Museum", done: false, archived: false)
    completion.list = .init(id: UUID(), name: "Tokyo Food", archived: false)
    completion.done = true
    do {
      let _: Void = try await completion.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a local completion change.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

}
