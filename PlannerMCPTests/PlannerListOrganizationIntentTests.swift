import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerListOrganizationIntentTests: XCTestCase {
  func testRemoveOnlyTheSelectedMembershipPreservesSharedItemOtherContextsOrderAndSchedule()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
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
    let museum = try await save(.createItem(content: .init(title: "Museum", notes: "Shared notes")))
    let item = try XCTUnwrap(museum.generated.first)
    let lunch = try await save(.createItem(content: .init(title: "Lunch")))
    let otherItem = try XCTUnwrap(lunch.generated.first)
    let first = try await save(.createList(content: .init(name: "Tokyo Food")))
    let sourceList = try XCTUnwrap(first.generated.first)
    let second = try await save(.createList(content: .init(name: "Wishlist")))
    let otherList = try XCTUnwrap(second.generated.first)
    let selected = try await save(
      .addMembership(itemId: item.id, listId: sourceList.id, placement: .last))
    let survivor = try await save(
      .addMembership(itemId: otherItem.id, listId: sourceList.id, placement: .last))
    let other = try await save(
      .addMembership(itemId: item.id, listId: otherList.id, placement: .last))
    guard case .membership(let removedIdentifier, _, _)? = selected.generatedReferences.first,
      case .membership(let survivorIdentifier, _, _)? = survivor.generatedReferences.first,
      case .membership(let otherIdentifier, _, _)? = other.generatedReferences.first
    else { return XCTFail("The fixture must retain each independent membership identity.") }
    let removedAppearance = PlannerAppearance.listMembership(
      listId: sourceList.id, membershipId: removedIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(removedAppearance), done: true))
    let createdPlan = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
    let itinerary = try XCTUnwrap(createdPlan.generated.first)
    let listEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: sourceList, placement: .last))
    let direct = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard case .itineraryEntry(let directIdentifier, _, _)? = direct.generatedReferences.first
    else { return XCTFail("The direct route appearance must survive membership removal.") }
    let scheduleForm = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
    let booking = try await save(.createSchedule(source: item, form: scheduleForm))
    let schedule = try XCTUnwrap(booking.generated.first)
    guard
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(item))
    else { return XCTFail("Shared content must be readable before organization changes.") }
    let removing = RemovePlannerItemFromListIntent()
    removing.item = .init(id: item.id, title: "Obsolete title", done: true, archived: true)
    removing.list = .init(id: sourceList.id, name: "Obsolete List", archived: true)
    let _: Void = try await removing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let after)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let savedList)) = await reopened.read(
        session: reopenedSession, request: .source(sourceList)),
      case .source(.list(let savedOther)) = await reopened.read(
        session: reopenedSession, request: .source(otherList)),
      case .source(.itinerary(let savedPlan)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.schedule(let savedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .appearance(let otherState) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: otherList.id, membershipId: otherIdentifier))),
      case .appearance(let directState) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .directItineraryItem(itineraryId: itinerary.id, entryId: directIdentifier))),
      case .failed(let removedFailure) = await reopened.read(
        session: reopenedSession, request: .appearance(removedAppearance))
    else { return XCTFail("Only the selected membership may disappear from reopened storage.") }
    XCTAssertEqual(after.content.title, "Museum")
    XCTAssertEqual(after.content.notes, "Shared notes")
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.state.globalDone, false)
    XCTAssertEqual(after.state.archived, false)
    XCTAssertEqual(
      savedList.references,
      [.membership(id: survivorIdentifier, list: sourceList, item: otherItem)]
        + listEntry.generatedReferences
    )
    XCTAssertEqual(savedList.content.name, "Tokyo Food")
    XCTAssertEqual(savedOther.references, other.generatedReferences)
    XCTAssertFalse(otherState.localDone)
    XCTAssertFalse(otherState.effectiveDone)
    XCTAssertFalse(directState.localDone)
    XCTAssertFalse(directState.effectiveDone)
    XCTAssertEqual(savedPlan.progress.totalCount, 2)
    XCTAssertEqual(savedPlan.progress.doneCount, 0)
    XCTAssertEqual(savedSchedule.content.form, scheduleForm)
    XCTAssertEqual(removedFailure.code, "missingReference")
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testMoveAtomicallyCreatesANewTodoMembershipAndPreservesOtherContextsSourceAndSchedule()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
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
    let museum = try await save(.createItem(content: .init(title: "Museum", notes: "Shared notes")))
    let item = try XCTUnwrap(museum.generated.first)
    let lunch = try await save(.createItem(content: .init(title: "Lunch")))
    let otherItem = try XCTUnwrap(lunch.generated.first)
    let first = try await save(.createList(content: .init(name: "From")))
    let sourceList = try XCTUnwrap(first.generated.first)
    let second = try await save(.createList(content: .init(name: "To")))
    let destinationList = try XCTUnwrap(second.generated.first)
    let third = try await save(.createList(content: .init(name: "Other")))
    let otherList = try XCTUnwrap(third.generated.first)
    let selected = try await save(
      .addMembership(itemId: item.id, listId: sourceList.id, placement: .last))
    let survivor = try await save(
      .addMembership(itemId: otherItem.id, listId: destinationList.id, placement: .last))
    let other = try await save(
      .addMembership(itemId: item.id, listId: otherList.id, placement: .last))
    guard case .membership(let originalIdentifier, _, _)? = selected.generatedReferences.first,
      case .membership(let otherIdentifier, _, _)? = other.generatedReferences.first
    else { return XCTFail("The original and unrelated memberships must have distinct identities.") }
    let originalAppearance = PlannerAppearance.listMembership(
      listId: sourceList.id, membershipId: originalIdentifier)
    let otherAppearance = PlannerAppearance.listMembership(
      listId: otherList.id, membershipId: otherIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(originalAppearance), done: true))
    _ = try await save(.setCompletion(scope: .appearance(otherAppearance), done: true))
    let createdPlan = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
    let itinerary = try XCTUnwrap(createdPlan.generated.first)
    let firstBranch = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: sourceList, placement: .last))
    let secondBranch = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: destinationList, placement: .last))
    guard case .itineraryEntry(let firstEntry, _, _)? = firstBranch.generatedReferences.first,
      case .itineraryEntry(let secondEntry, _, _)? = secondBranch.generatedReferences.first
    else { return XCTFail("Both source Lists must remain live route references.") }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: firstEntry, membershipId: originalIdentifier)),
        done: true))
    let form = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
    let booking = try await save(.createSchedule(source: item, form: form))
    let schedule = try XCTUnwrap(booking.generated.first)
    guard
      case .source(.item(let before)) = await planner.read(session: session, request: .source(item))
    else { return XCTFail("The shared Item must be readable before Move.") }
    let moving = MovePlannerItemBetweenListsIntent()
    moving.item = .init(id: item.id, title: "Obsolete title", done: true, archived: true)
    moving.sourceList = .init(id: sourceList.id, name: "Obsolete From", archived: true)
    moving.destinationList = .init(id: destinationList.id, name: "Obsolete To", archived: true)
    let _: Void = try await moving.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let savedSource)) = await reopened.read(
        session: reopenedSession, request: .source(sourceList)),
      case .source(.list(let savedDestination)) = await reopened.read(
        session: reopenedSession, request: .source(destinationList)),
      case .source(.list(let savedOther)) = await reopened.read(
        session: reopenedSession, request: .source(otherList)),
      case .source(.item(let after)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.itinerary(let savedPlan)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.schedule(let savedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule))
    else {
      return XCTFail("Both sides of Move and unrelated shared sources must survive reopening.")
    }
    let memberships = savedDestination.references.filter { reference in
      if case .membership = reference { return true }
      return false
    }
    guard case .membership(let newIdentifier, let owner, let source)? = memberships.last,
      case .appearance(let newState) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: destinationList.id, membershipId: newIdentifier))),
      case .appearance(let newBranchState) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: secondEntry, membershipId: newIdentifier))),
      case .appearance(let otherState) = await reopened.read(
        session: reopenedSession, request: .appearance(otherAppearance)),
      case .failed(let oldFailure) = await reopened.read(
        session: reopenedSession, request: .appearance(originalAppearance))
    else {
      return XCTFail("Move must remove the old context and create a separate destination context.")
    }
    XCTAssertEqual(savedSource.references, firstBranch.generatedReferences)
    XCTAssertEqual(memberships.count, 2)
    XCTAssertEqual(memberships.first, survivor.generatedReferences.first)
    XCTAssertTrue(
      savedDestination.references.contains(try XCTUnwrap(secondBranch.generatedReferences.first)))
    XCTAssertNotEqual(newIdentifier, originalIdentifier)
    XCTAssertEqual(owner, destinationList)
    XCTAssertEqual(source, item)
    XCTAssertFalse(newState.localDone)
    XCTAssertFalse(newState.effectiveDone)
    XCTAssertFalse(newBranchState.localDone)
    XCTAssertFalse(newBranchState.effectiveDone)
    XCTAssertEqual(savedOther.references, other.generatedReferences)
    XCTAssertTrue(otherState.localDone)
    XCTAssertTrue(otherState.effectiveDone)
    XCTAssertEqual(savedPlan.progress.totalCount, 2)
    XCTAssertEqual(savedPlan.progress.doneCount, 0)
    XCTAssertEqual(savedSchedule.content.form, form)
    XCTAssertEqual(after.content.notes, "Shared notes")
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.state.globalDone, false)
    XCTAssertEqual(after.state.archived, false)
    XCTAssertEqual(savedSource.content.name, "From")
    XCTAssertEqual(savedDestination.content.name, "To")
    XCTAssertEqual(oldFailure.code, "missingReference")
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testMoveToAnExistingDestinationKeepsItsMembershipOrderAndLocalCompletion() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
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
    let created = try await save(.createItem(content: .init(title: "Museum")))
    let item = try XCTUnwrap(created.generated.first)
    let firstChild = try await save(.createItem(content: .init(title: "Breakfast")))
    let firstItem = try XCTUnwrap(firstChild.generated.first)
    let lastChild = try await save(.createItem(content: .init(title: "Dinner")))
    let lastItem = try XCTUnwrap(lastChild.generated.first)
    let first = try await save(.createList(content: .init(name: "From")))
    let sourceList = try XCTUnwrap(first.generated.first)
    let second = try await save(.createList(content: .init(name: "To")))
    let destinationList = try XCTUnwrap(second.generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: sourceList.id, placement: .last))
    _ = try await save(
      .addMembership(itemId: firstItem.id, listId: destinationList.id, placement: .last))
    let existing = try await save(
      .addMembership(itemId: item.id, listId: destinationList.id, placement: .last))
    _ = try await save(
      .addMembership(itemId: lastItem.id, listId: destinationList.id, placement: .last))
    guard case .membership(let existingIdentifier, _, _)? = existing.generatedReferences.first
    else { return XCTFail("The existing destination must retain its own identity.") }
    let appearance = PlannerAppearance.listMembership(
      listId: destinationList.id, membershipId: existingIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    guard
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(destinationList))
    else { return XCTFail("The destination's original order must be readable before Move.") }
    let moving = MovePlannerItemBetweenListsIntent()
    moving.item = .init(id: item.id, title: "Museum", done: false, archived: false)
    moving.sourceList = .init(id: sourceList.id, name: "From", archived: false)
    moving.destinationList = .init(id: destinationList.id, name: "To", archived: false)
    let _: Void = try await moving.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let savedSource)) = await reopened.read(
        session: reopenedSession, request: .source(sourceList)),
      case .source(.list(let after)) = await reopened.read(
        session: reopenedSession, request: .source(destinationList)),
      case .appearance(let current) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance))
    else { return XCTFail("The source removal and unchanged destination must survive reopening.") }
    XCTAssertTrue(savedSource.references.isEmpty)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.references.count, 3)
    XCTAssertEqual(after.references.dropFirst().first, existing.generatedReferences.first)
    XCTAssertTrue(current.localDone)
    XCTAssertTrue(current.effectiveDone)
    XCTAssertFalse(current.globalDone)
    XCTAssertEqual(current.source, item)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testInvalidMissingAndDeletedOrganizationTargetsLeaveNoPartialMoveOrResurrectedData()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "Museum"
    let item = try await itemCreation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "From"
    let sourceList = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "To"
    let destinationList = try await listCreation.callAsFunction(donate: false)
    let adding = AddPlannerItemToListIntent()
    adding.item = item
    adding.list = sourceList
    let _: Void = try await adding.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let sourceReference = PlannerEntityReference(kind: .list, id: sourceList.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(sourceReference))
    else { return XCTFail("Invalid target checks require an actual surviving membership.") }
    func rejectRemoval(item selectedItem: PlannerItemEntity, list selectedList: PlannerListEntity)
      async
    {
      let removing = RemovePlannerItemFromListIntent()
      removing.item = selectedItem
      removing.list = selectedList
      do {
        let _: Void = try await removing.callAsFunction(donate: false)
        XCTFail("Removal cannot acknowledge an unavailable Item/List pair.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    func rejectMove(
      item selectedItem: PlannerItemEntity, from selectedSource: PlannerListEntity,
      to selectedDestination: PlannerListEntity
    ) async {
      let moving = MovePlannerItemBetweenListsIntent()
      moving.item = selectedItem
      moving.sourceList = selectedSource
      moving.destinationList = selectedDestination
      do {
        let _: Void = try await moving.callAsFunction(donate: false)
        XCTFail("An invalid Move must not remove its source or substitute another context.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    await rejectMove(item: item, from: sourceList, to: sourceList)
    for identifier in [UUID(), item.id] {
      let unavailable = PlannerListEntity(id: identifier, name: "Unavailable", archived: false)
      await rejectMove(item: item, from: sourceList, to: unavailable)
      await rejectMove(item: item, from: unavailable, to: destinationList)
      await rejectRemoval(item: item, list: unavailable)
    }
    let missingItem = PlannerItemEntity(id: UUID(), title: "Missing", done: false, archived: false)
    await rejectRemoval(item: missingItem, list: sourceList)
    await rejectMove(item: missingItem, from: sourceList, to: destinationList)
    await rejectRemoval(item: item, list: destinationList)
    await rejectMove(item: item, from: destinationList, to: sourceList)
    guard
      case .source(.list(let afterInvalid)) = await planner.read(
        session: session, request: .source(sourceReference)),
      case .source(.list(let untouchedDestination)) = await planner.read(
        session: session, request: .source(.init(kind: .list, id: destinationList.id)))
    else {
      return XCTFail("Rejected commands must leave the original source/destination readable.")
    }
    XCTAssertEqual(afterInvalid.references, before.references)
    XCTAssertEqual(afterInvalid.fieldHashes, before.fieldHashes)
    XCTAssertEqual(afterInvalid.updatedAt, before.updatedAt)
    XCTAssertTrue(untouchedDestination.references.isEmpty)
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
    try await delete(.init(kind: .list, id: destinationList.id))
    await rejectMove(item: item, from: sourceList, to: destinationList)
    await rejectRemoval(item: item, list: destinationList)
    try await delete(.init(kind: .item, id: item.id))
    await rejectRemoval(item: item, list: sourceList)
    await rejectMove(item: item, from: sourceList, to: destinationList)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(sourceReference)),
      case .snapshot(let lists) = await reopened.query(
        .init(session: reopenedSession, request: .catalog(.init(sourceKind: .list, archive: .all)))),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("Missing identities must stay absent in reopened real storage.") }
    XCTAssertEqual(lists.rows, [.source(sourceReference)])
    XCTAssertTrue(items.rows.isEmpty)
    XCTAssertTrue(retained.references.isEmpty)
    XCTAssertEqual(retained.content.name, "From")
    XCTAssertEqual(retained.progress.state, .empty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledRemovalAndMovePreserveTheOriginalMembershipAndDestination() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "Museum"
    let item = try await itemCreation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "From"
    let sourceList = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "To"
    let destinationList = try await listCreation.callAsFunction(donate: false)
    let adding = AddPlannerItemToListIntent()
    adding.item = item
    adding.list = sourceList
    let _: Void = try await adding.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let sourceReference = PlannerEntityReference(kind: .list, id: sourceList.id)
    let destinationReference = PlannerEntityReference(kind: .list, id: destinationList.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(sourceReference))
    else { return XCTFail("Cancellation requires a valid, otherwise actionable membership.") }
    let removing = RemovePlannerItemFromListIntent()
    removing.item = item
    removing.list = sourceList
    let removalRequest = Task {
      let _: Void = try await removing.callAsFunction(donate: false)
    }
    removalRequest.cancel()
    do {
      let _: Void = try await removalRequest.value
      XCTFail("A precancelled removal cannot acknowledge a membership change.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let moving = MovePlannerItemBetweenListsIntent()
    moving.item = item
    moving.sourceList = sourceList
    moving.destinationList = destinationList
    let moveRequest = Task {
      let _: Void = try await moving.callAsFunction(donate: false)
    }
    moveRequest.cancel()
    do {
      let _: Void = try await moveRequest.value
      XCTFail("A precancelled Move cannot acknowledge a membership change.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let after)) = await reopened.read(
        session: reopenedSession, request: .source(sourceReference)),
      case .source(.list(let destination)) = await reopened.read(
        session: reopenedSession, request: .source(destinationReference)),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("Both original Lists and the Item must survive cancelled actions.") }
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.references.count, 1)
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertTrue(destination.references.isEmpty)
    XCTAssertEqual(retained.content.title, "Museum")
    XCTAssertEqual(retained.state.globalDone, false)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedRemovalAndMoveRetainAtomicResultsDuringRecoveryFailureWithoutAutomaticReplay()
    async throws
  {
    for movesMembership in [false, true] {
      let (directory, configuration, store) = try makeStorage()
      defer { try? FileManager.default.removeItem(at: directory) }
      AppDependencyManager.shared.add(dependency: store)
      let itemCreation = CreatePlannerItemIntent()
      itemCreation.title = "Museum"
      itemCreation.notes = "Keep shared notes"
      let item = try await itemCreation.callAsFunction(donate: false)
      let listCreation = CreatePlannerListIntent()
      listCreation.name = "From"
      let sourceList = try await listCreation.callAsFunction(donate: false)
      listCreation.name = "To"
      let destinationList = try await listCreation.callAsFunction(donate: false)
      let adding = AddPlannerItemToListIntent()
      adding.item = item
      adding.list = sourceList
      let _: Void = try await adding.callAsFunction(donate: false)
      let planner = PlannerCore.Planner(configuration: configuration)
      let sourceReference = PlannerEntityReference(kind: .list, id: sourceList.id)
      let destinationReference = PlannerEntityReference(kind: .list, id: destinationList.id)
      guard case .ready(let session) = await planner.bootstrap(),
        case .source(.list(let original)) = await planner.read(
          session: session, request: .source(sourceReference)),
        case .membership(let originalIdentifier, _, _)? = original.references.first,
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .setCompletion(
              scope: .appearance(
                .listMembership(listId: sourceList.id, membershipId: originalIdentifier)),
              done: true))
        ).outcome
      else { return XCTFail("The original local Done membership must exist before the fault.") }
      let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      if movesMembership {
        let moving = MovePlannerItemBetweenListsIntent()
        moving.item = item
        moving.sourceList = sourceList
        moving.destinationList = destinationList
        let _: Void = try await moving.callAsFunction(donate: false)
      } else {
        let removing = RemovePlannerItemFromListIntent()
        removing.item = item
        removing.list = sourceList
        let _: Void = try await removing.callAsFunction(donate: false)
      }
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(store.recoveryBlocked)
      XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
      do {
        let _: Void = try await adding.callAsFunction(donate: false)
        XCTFail("Incomplete recovery must block ordinary re-add without replaying organization.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.list(let appliedSource)) = await reopened.read(
          session: reopenedSession, request: .source(sourceReference)),
        case .source(.list(let appliedDestination)) = await reopened.read(
          session: reopenedSession, request: .source(destinationReference)),
        case .source(.item(let retained)) = await reopened.read(
          session: reopenedSession, request: .source(.init(kind: .item, id: item.id)))
      else {
        return XCTFail(
          "Applied organization must remain durable despite missing recovery acknowledgment.")
      }
      XCTAssertTrue(appliedSource.references.isEmpty)
      XCTAssertEqual(appliedDestination.references.count, movesMembership ? 1 : 0)
      XCTAssertEqual(retained.content.notes, "Keep shared notes")
      XCTAssertEqual(retained.state.globalDone, false)
      if movesMembership {
        guard
          case .membership(let identifier, let owner, let source)? = appliedDestination.references
            .first,
          case .appearance(let current) = await reopened.read(
            session: reopenedSession,
            request: .appearance(
              .listMembership(listId: destinationList.id, membershipId: identifier)))
        else { return XCTFail("A committed Move must retain its new destination membership.") }
        XCTAssertEqual(owner, destinationReference)
        XCTAssertEqual(source, .init(kind: .item, id: item.id))
        XCTAssertNotEqual(identifier, originalIdentifier)
        XCTAssertFalse(current.localDone)
        XCTAssertFalse(current.effectiveDone)
      }
      await store.retryIncompleteRecovery()
      XCTAssertFalse(store.recoveryBlocked)
      XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier),
        case .source(.list(let recoveredSource)) = await reopened.read(
          session: reopenedSession, request: .source(sourceReference)),
        case .source(.list(let recoveredDestination)) = await reopened.read(
          session: reopenedSession, request: .source(destinationReference))
      else {
        return XCTFail(
          "Native retry must acknowledge the original action without executing it again.")
      }
      XCTAssertEqual(recoveredSource.references, appliedSource.references)
      XCTAssertEqual(recoveredDestination.references, appliedDestination.references)
      let _: Void = try await adding.callAsFunction(donate: false)
      guard
        case .source(.list(let finalSource)) = await reopened.read(
          session: reopenedSession, request: .source(sourceReference)),
        case .source(.list(let finalDestination)) = await reopened.read(
          session: reopenedSession, request: .source(destinationReference)),
        case .membership(let readdedIdentifier, _, _)? = finalSource.references.first,
        case .appearance(let readded) = await reopened.read(
          session: reopenedSession,
          request: .appearance(
            .listMembership(listId: sourceList.id, membershipId: readdedIdentifier)))
      else {
        return XCTFail("A later explicit re-add must create a fresh ordinary Todo membership.")
      }
      XCTAssertEqual(finalSource.references.count, 1)
      XCTAssertNotEqual(readdedIdentifier, originalIdentifier)
      XCTAssertFalse(readded.localDone)
      XCTAssertFalse(readded.effectiveDone)
      XCTAssertEqual(finalDestination.references, appliedDestination.references)
      XCTAssertFalse(store.isSaving)
    }
  }

  func testUnavailableStorageCannotAcknowledgeRemovalOrMove() async throws {
    let (directory, _, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let item = PlannerItemEntity(id: UUID(), title: "Museum", done: false, archived: false)
    let sourceList = PlannerListEntity(id: UUID(), name: "From", archived: false)
    let destinationList = PlannerListEntity(id: UUID(), name: "To", archived: false)
    let removing = RemovePlannerItemFromListIntent()
    removing.item = item
    removing.list = sourceList
    do {
      let _: Void = try await removing.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a removal.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let moving = MovePlannerItemBetweenListsIntent()
    moving.item = item
    moving.sourceList = sourceList
    moving.destinationList = destinationList
    do {
      let _: Void = try await moving.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a Move.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  private func makeStorage() throws -> (
    directory: URL, configuration: PlannerStorageConfiguration, store: SavedPlannerStore
  ) {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "PlannerListOrganizationIntentTests/\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    return (directory, configuration, SavedPlannerStore(configuration: configuration))
  }
}
