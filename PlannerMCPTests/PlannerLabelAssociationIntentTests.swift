import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerLabelAssociationIntentTests: XCTestCase {
  func testItemCategoryAssignmentPreservesSharedLabelsAndOtherOwnerDataAfterReopen() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assign = SetPlannerItemCategoryIntent()
    assign.item = .init(id: fixture.item.id, title: "Cached Item", done: true, archived: false)
    assign.category = .init(id: fixture.extraCategory.id, name: "Cached Category")
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.category(let category)) = await reopened.read(
        session: session, request: .source(fixture.extraCategory))
    else { return XCTFail("The assignment and its shared sources must survive reopening.") }
    XCTAssertEqual(item.content.categoryIds, [fixture.category.id, fixture.extraCategory.id])
    XCTAssertEqual(item.content.tagIds, [fixture.tag.id])
    XCTAssertEqual(item.content.title, "Museum")
    XCTAssertEqual(item.content.notes, "Keep booking")
    XCTAssertEqual(item.state.globalDone, true)
    XCTAssertEqual(item.state.archived, false)
    XCTAssertEqual(item.labels.first { $0.reference == fixture.extraCategory }?.name, "Outdoors")
    XCTAssertEqual(category.content.name, "Outdoors")
    XCTAssertEqual(itinerary.content.categoryIds, [fixture.category.id])
    assign.assigned = false
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    guard
      case .source(.item(let detached)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.category(let retained)) = await reopened.read(
        session: session, request: .source(fixture.extraCategory))
    else { return XCTFail("Unassigning must retain both owner and shared label.") }
    XCTAssertEqual(detached.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(detached.content.tagIds, [fixture.tag.id])
    XCTAssertEqual(retained.content, category.content)
    XCTAssertEqual(retained.updatedAt, category.updatedAt)
    try await assertAssociationFixtureContextPreserved(fixture, planner: reopened, session: session)
  }
  func testItemTagAssignmentKeepsCategoriesAndItineraryLabelsIndependent() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assign = SetPlannerItemTagIntent()
    assign.item = .init(id: fixture.item.id, title: "Cached Item", done: false, archived: true)
    assign.tag = .init(id: fixture.extraTag.id, name: "Cached Tag")
    assign.assigned = true
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary))
    else {
      return XCTFail("Item Tag assignment must survive reopening without rebinding its itinerary.")
    }
    XCTAssertEqual(item.content.tagIds, [fixture.tag.id, fixture.extraTag.id])
    XCTAssertEqual(item.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(item.content.title, "Museum")
    XCTAssertEqual(item.content.notes, "Keep booking")
    XCTAssertEqual(item.state.globalDone, true)
    XCTAssertEqual(item.state.archived, false)
    XCTAssertEqual(item.labels.first { $0.reference == fixture.extraTag }?.name, "booked")
    XCTAssertEqual(itinerary.content.tagIds, [fixture.tag.id])
    assign.assigned = false
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    guard
      case .source(.item(let detached)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.tag(let retained)) = await reopened.read(
        session: session, request: .source(fixture.extraTag))
    else { return XCTFail("Unassigning a Tag must retain its shared source.") }
    XCTAssertEqual(detached.content.tagIds, [fixture.tag.id])
    XCTAssertEqual(detached.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(retained.content.name, "booked")
    try await assertAssociationFixtureContextPreserved(fixture, planner: reopened, session: session)
  }
  func testItineraryCategoryAssignmentPreservesRouteAndItemLabelsAfterReopen() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assign = SetPlannerItineraryCategoryIntent()
    assign.itinerary = .init(id: fixture.itinerary.id, title: "Cached Itinerary", archived: true)
    assign.category = .init(id: fixture.extraCategory.id, name: "Cached Category")
    assign.assigned = true
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item))
    else { return XCTFail("Itinerary Category assignment must retain its route and shared Items.") }
    XCTAssertEqual(itinerary.content.categoryIds, [fixture.category.id, fixture.extraCategory.id])
    XCTAssertEqual(itinerary.content.tagIds, [fixture.tag.id])
    XCTAssertEqual(itinerary.state.archived, false)
    XCTAssertEqual(
      itinerary.labels.first { $0.reference == fixture.extraCategory }?.name, "Outdoors")
    XCTAssertEqual(item.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(item.content.tagIds, [fixture.tag.id])
    assign.assigned = false
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let detached)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.category(let retained)) = await reopened.read(
        session: session, request: .source(fixture.extraCategory))
    else { return XCTFail("Unassigning must retain the route and shared Category.") }
    XCTAssertEqual(detached.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(detached.content.tagIds, [fixture.tag.id])
    XCTAssertEqual(retained.content.name, "Outdoors")
    try await assertAssociationFixtureContextPreserved(fixture, planner: reopened, session: session)
  }
  func testItineraryTagAssignmentPreservesCategoriesAndSharedItemsAfterReopen() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assign = SetPlannerItineraryTagIntent()
    assign.itinerary = .init(id: fixture.itinerary.id, title: "Cached Itinerary", archived: true)
    assign.tag = .init(id: fixture.extraTag.id, name: "Cached Tag")
    assign.assigned = true
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item))
    else { return XCTFail("Itinerary Tag assignment must preserve its shared Item references.") }
    XCTAssertEqual(itinerary.content.tagIds, [fixture.tag.id, fixture.extraTag.id])
    XCTAssertEqual(itinerary.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(itinerary.state.archived, false)
    XCTAssertEqual(itinerary.labels.first { $0.reference == fixture.extraTag }?.name, "booked")
    XCTAssertEqual(item.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(item.content.tagIds, [fixture.tag.id])
    assign.assigned = false
    let _: Void = try await assign.callAsFunction(donate: false)
    let _: Void = try await assign.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let detached)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.tag(let retained)) = await reopened.read(
        session: session, request: .source(fixture.extraTag))
    else { return XCTFail("Unassigning must retain the shared Tag and route.") }
    XCTAssertEqual(detached.content.tagIds, [fixture.tag.id])
    XCTAssertEqual(detached.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(retained.content.name, "booked")
    try await assertAssociationFixtureContextPreserved(fixture, planner: reopened, session: session)
  }
  func testMissingAndWrongKindSelectionsLeaveOwnersAndRelationshipsUnchanged() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let before = try await readAssociationOwners(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      let wrongOwnerIdentifier = owner.kind == .item ? fixture.itinerary.id : fixture.item.id
      for label in [fixture.category, fixture.tag] {
        let wrongLabelIdentifier = label.kind == .category ? fixture.tag.id : fixture.category.id
        for assigned in [true, false] {
          for (ownerIdentifier, labelIdentifier) in [
            (owner.id, UUID()), (owner.id, wrongLabelIdentifier),
            (UUID(), label.id), (wrongOwnerIdentifier, label.id),
          ] {
            do {
              try await setLabel(
                owner: .init(kind: owner.kind, id: ownerIdentifier),
                label: .init(kind: label.kind, id: labelIdentifier), assigned: assigned)
              XCTFail("Missing or mismatched selections cannot switch to another owner or label.")
            } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
          }
        }
      }
    }
    let after = try await readAssociationOwners(fixture)
    assertAssociationOwnersUnchanged(before, after)
    try await assertAssociationFixtureContextPreserved(
      fixture, planner: fixture.planner, session: fixture.session)
  }

  func testDeletedSelectionsCannotResurrectOwnersOrSharedLabels() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let before = try await readAssociationOwners(fixture)
    for label in [fixture.extraCategory, fixture.extraTag] {
      try await deleteAssociationFixtureSource(label, fixture: fixture)
      for owner in [fixture.item, fixture.itinerary] {
        for assigned in [true, false] {
          do {
            try await setLabel(owner: owner, label: label, assigned: assigned)
            XCTFail("Deleted labels must remain unavailable in either assignment direction.")
          } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        }
      }
      guard
        case .failed(let missing) = await fixture.planner.read(
          session: fixture.session, request: .source(label))
      else { return XCTFail("Assignment cannot recreate a deleted label.") }
      XCTAssertEqual(missing.code, "missingReference")
    }
    let afterLabelDeletion = try await readAssociationOwners(fixture)
    assertAssociationOwnersUnchanged(before, afterLabelDeletion)
    for owner in [fixture.item, fixture.itinerary] {
      try await deleteAssociationFixtureSource(owner, fixture: fixture)
      for label in [fixture.category, fixture.tag] {
        do {
          try await setLabel(owner: owner, label: label, assigned: true)
          XCTFail("Assignment cannot recreate a deleted owner or fall back to a different owner.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      guard
        case .failed(let missing) = await fixture.planner.read(
          session: fixture.session, request: .source(owner))
      else { return XCTFail("The deleted owner must stay missing.") }
      XCTAssertEqual(missing.code, "missingReference")
    }
    for label in [fixture.category, fixture.tag] {
      switch await fixture.planner.read(session: fixture.session, request: .source(label)) {
      case .source(.category(let category)): XCTAssertEqual(category.content.name, "Museums")
      case .source(.tag(let tag)): XCTAssertEqual(tag.content.name, "rainy-day")
      default: XCTFail("Owner deletion and rejected assignment must retain the shared labels.")
      }
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testPrecancelledAssignmentsAndUnassignmentsPreserveAllOwnerData() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let before = try await readAssociationOwners(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      for label in [fixture.category, fixture.tag] {
        for assigned in [true, false] {
          let request = Task {
            try await self.setLabel(owner: owner, label: label, assigned: assigned)
          }
          request.cancel()
          do {
            try await request.value
            XCTFail("Precancelled assignment must not acknowledge or change user data.")
          } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        }
      }
    }
    let after = try await readAssociationOwners(fixture)
    assertAssociationOwnersUnchanged(before, after)
    try await assertAssociationFixtureContextPreserved(
      fixture, planner: fixture.planner, session: fixture.session)
  }

  func testUnavailableStorageRejectsEveryAssignmentWithoutReplacingTheObstruction() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    for ownerKind in [PlannerEntityKind.item, .itinerary] {
      for labelKind in [PlannerEntityKind.category, .tag] {
        do {
          try await setLabel(
            owner: .init(kind: ownerKind, id: UUID()), label: .init(kind: labelKind, id: UUID()),
            assigned: true)
          XCTFail("Unavailable storage cannot acknowledge a label assignment.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testAppliedAssignmentsWithIncompleteRecoveryAreRetainedAndAcknowledgedWithoutReplay()
    async throws
  {
    for ownerKind in [PlannerEntityKind.item, .itinerary] {
      for labelKind in [PlannerEntityKind.category, .tag] {
        let fixture = try await makeLabelAssociationIntentFixture()
        let owner = ownerKind == .item ? fixture.item : fixture.itinerary
        let label = labelKind == .category ? fixture.extraCategory : fixture.extraTag
        await fixture.store.open()
        XCTAssertTrue(fixture.store.isReady)
        let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
        let observer = NotificationCenter.default.addObserver(
          forName: ModelContext.didSave, object: nil, queue: nil
        ) { notification in obstruction.observe(notification) }
        defer {
          NotificationCenter.default.removeObserver(observer)
          try? obstruction.restore()
        }
        try await setLabel(owner: owner, label: label, assigned: true)
        XCTAssertTrue(obstruction.didObstruct)
        XCTAssertTrue(fixture.store.recoveryBlocked)
        XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
        let operationIdentifier = try XCTUnwrap(
          fixture.store.incompleteRecoveryOperationIdentifiers.first)
        do {
          try await setLabel(owner: owner, label: label, assigned: false)
          XCTFail("Another mutation must remain blocked while the saved assignment needs recovery.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
        NotificationCenter.default.removeObserver(observer)
        try obstruction.restore()
        let reopened = PlannerCore.Planner(configuration: fixture.configuration)
        guard case .ready(let session) = await reopened.bootstrap() else {
          throw CancellationError()
        }
        let appliedOwners = try await readAssociationOwners(fixture)
        if ownerKind == .item {
          if labelKind == .category {
            XCTAssertEqual(appliedOwners.item.content.categoryIds, [fixture.category.id, label.id])
          } else {
            XCTAssertEqual(appliedOwners.item.content.tagIds, [fixture.tag.id, label.id])
          }
        } else if labelKind == .category {
          XCTAssertEqual(
            appliedOwners.itinerary.content.categoryIds, [fixture.category.id, label.id])
        } else {
          XCTAssertEqual(appliedOwners.itinerary.content.tagIds, [fixture.tag.id, label.id])
        }
        await fixture.store.retryIncompleteRecovery()
        XCTAssertFalse(fixture.store.recoveryBlocked)
        guard
          case .appliedRecoveryComplete = await reopened.operationStatus(
            session: session, operationId: operationIdentifier)
        else { return XCTFail("Retry must acknowledge the original applied assignment.") }
        let recoveredOwners = try await readAssociationOwners(fixture)
        assertAssociationOwnersUnchanged(appliedOwners, recoveredOwners)
        try await assertAssociationFixtureContextPreserved(
          fixture, planner: reopened, session: session)
        try await setLabel(owner: owner, label: label, assigned: false)
        XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
        XCTAssertFalse(fixture.store.isSaving)
      }
    }
  }

  private func setLabel(
    owner: PlannerEntityReference, label: PlannerEntityReference, assigned: Bool
  ) async throws {
    switch (owner.kind, label.kind) {
    case (.item, .category):
      let intent = SetPlannerItemCategoryIntent()
      intent.item = .init(id: owner.id, title: "Cached Item", done: false, archived: false)
      intent.category = .init(id: label.id, name: "Cached Category")
      intent.assigned = assigned
      let _: Void = try await intent.callAsFunction(donate: false)
    case (.item, .tag):
      let intent = SetPlannerItemTagIntent()
      intent.item = .init(id: owner.id, title: "Cached Item", done: false, archived: false)
      intent.tag = .init(id: label.id, name: "Cached Tag")
      intent.assigned = assigned
      let _: Void = try await intent.callAsFunction(donate: false)
    case (.itinerary, .category):
      let intent = SetPlannerItineraryCategoryIntent()
      intent.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: false)
      intent.category = .init(id: label.id, name: "Cached Category")
      intent.assigned = assigned
      let _: Void = try await intent.callAsFunction(donate: false)
    case (.itinerary, .tag):
      let intent = SetPlannerItineraryTagIntent()
      intent.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: false)
      intent.tag = .init(id: label.id, name: "Cached Tag")
      intent.assigned = assigned
      let _: Void = try await intent.callAsFunction(donate: false)
    default: throw CancellationError()
    }
  }
}

struct LabelAssociationIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let category: PlannerEntityReference
  let extraCategory: PlannerEntityReference
  let tag: PlannerEntityReference
  let extraTag: PlannerEntityReference
  let item: PlannerEntityReference
  let list: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let schedule: PlannerEntityReference
  let membershipIdentifier: UUID
  let secondMembershipIdentifier: UUID
  let entryIdentifier: UUID
  let repeatedEntryIdentifier: UUID
}

@MainActor
func makeLabelAssociationIntentFixture() async throws -> LabelAssociationIntentFixture {
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
  let createdCategory = try await save(.createCategory(content: .init(name: "Museums")))
  let category = try XCTUnwrap(createdCategory.generated.first)
  let createdExtraCategory = try await save(.createCategory(content: .init(name: "Outdoors")))
  let extraCategory = try XCTUnwrap(createdExtraCategory.generated.first)
  let createdTag = try await save(.createTag(content: .init(name: "rainy-day")))
  let tag = try XCTUnwrap(createdTag.generated.first)
  let createdExtraTag = try await save(.createTag(content: .init(name: "booked")))
  let extraTag = try XCTUnwrap(createdExtraTag.generated.first)
  let createdItem = try await save(
    .createItem(
      content: .init(
        title: "Museum", notes: "Keep booking", categoryIds: [category.id], tagIds: [tag.id])))
  let item = try XCTUnwrap(createdItem.generated.first)
  let createdLunch = try await save(.createItem(content: .init(title: "Lunch")))
  let lunch = try XCTUnwrap(createdLunch.generated.first)
  _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
  let createdList = try await save(.createList(content: .init(name: "Tokyo Food")))
  let list = try XCTUnwrap(createdList.generated.first)
  let addedMembership = try await save(
    .addMembership(itemId: item.id, listId: list.id, placement: .last))
  guard
    case .membership(let membershipIdentifier, _, _)? = addedMembership.generatedReferences.first
  else { throw CancellationError() }
  let addedLunchMembership = try await save(
    .addMembership(itemId: lunch.id, listId: list.id, placement: .last))
  guard
    case .membership(let secondMembershipIdentifier, _, _)? = addedLunchMembership
      .generatedReferences.first
  else { throw CancellationError() }
  let createdItinerary = try await save(
    .createItinerary(
      content: .init(
        title: "Tokyo Weekend", notes: "Keep route", categoryIds: [category.id], tagIds: [tag.id])))
  let itinerary = try XCTUnwrap(createdItinerary.generated.first)
  let addedEntry = try await save(
    .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
  guard case .itineraryEntry(let entryIdentifier, _, _)? = addedEntry.generatedReferences.first
  else { throw CancellationError() }
  let repeatedEntry = try await save(
    .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
  guard
    case .itineraryEntry(let repeatedEntryIdentifier, _, _)? = repeatedEntry.generatedReferences
      .first
  else { throw CancellationError() }
  _ = try await save(
    .setCompletion(
      scope: .appearance(
        .directItineraryItem(
          itineraryId: itinerary.id, entryId: entryIdentifier)), done: true))
  let createdSchedule = try await save(
    .createSchedule(
      source: itinerary,
      form: .allDay(
        start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))))
  let schedule = try XCTUnwrap(createdSchedule.generated.first)
  return .init(
    configuration: configuration, store: store, planner: planner, session: session,
    category: category, extraCategory: extraCategory, tag: tag, extraTag: extraTag,
    item: item, list: list, itinerary: itinerary, schedule: schedule,
    membershipIdentifier: membershipIdentifier,
    secondMembershipIdentifier: secondMembershipIdentifier,
    entryIdentifier: entryIdentifier, repeatedEntryIdentifier: repeatedEntryIdentifier)
}

@MainActor
private func assertAssociationFixtureContextPreserved(
  _ fixture: LabelAssociationIntentFixture, planner: PlannerCore.Planner,
  session: PlannerDatasetSession
) async throws {
  guard
    case .source(.list(let list)) = await planner.read(
      session: session, request: .source(fixture.list)),
    case .source(.itinerary(let itinerary)) = await planner.read(
      session: session, request: .source(fixture.itinerary)),
    case .appearance(let membership) = await planner.read(
      session: session,
      request: .appearance(
        .listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier))),
    case .appearance(let entry) = await planner.read(
      session: session,
      request: .appearance(
        .directItineraryItem(itineraryId: fixture.itinerary.id, entryId: fixture.entryIdentifier))),
    case .appearance(let repeatedEntry) = await planner.read(
      session: session,
      request: .appearance(
        .directItineraryItem(
          itineraryId: fixture.itinerary.id, entryId: fixture.repeatedEntryIdentifier))),
    case .source(.schedule(let schedule)) = await planner.read(
      session: session, request: .source(fixture.schedule))
  else { return XCTFail("Label edits must retain original organization, completion and bookings.") }
  XCTAssertEqual(list.content.name, "Tokyo Food")
  XCTAssertEqual(itinerary.content.title, "Tokyo Weekend")
  XCTAssertEqual(itinerary.content.notes, "Keep route")
  XCTAssertEqual(
    list.references.compactMap { reference -> UUID? in
      guard case .membership(let identifier, _, _) = reference else { return nil }
      return identifier
    }, [fixture.membershipIdentifier, fixture.secondMembershipIdentifier])
  XCTAssertEqual(
    itinerary.references.compactMap { reference -> UUID? in
      guard case .itineraryEntry(let identifier, _, _) = reference else { return nil }
      return identifier
    }, [fixture.entryIdentifier, fixture.repeatedEntryIdentifier])
  XCTAssertFalse(repeatedEntry.localDone)
  XCTAssertTrue(repeatedEntry.globalDone)
  XCTAssertFalse(membership.localDone)
  XCTAssertTrue(membership.globalDone)
  XCTAssertTrue(entry.localDone)
  XCTAssertTrue(entry.globalDone)
  XCTAssertEqual(
    schedule.content.form,
    .allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21)))
  XCTAssertFalse(fixture.store.recoveryBlocked)
  XCTAssertFalse(fixture.store.isSaving)
}

@MainActor
private func readAssociationOwners(_ fixture: LabelAssociationIntentFixture) async throws -> (
  item: PlannerItemSourceRead, itinerary: PlannerItinerarySourceRead
) {
  guard
    case .source(.item(let item)) = await fixture.planner.read(
      session: fixture.session, request: .source(fixture.item)),
    case .source(.itinerary(let itinerary)) = await fixture.planner.read(
      session: fixture.session, request: .source(fixture.itinerary))
  else { throw CancellationError() }
  return (item, itinerary)
}

@MainActor
private func assertAssociationOwnersUnchanged(
  _ before: (item: PlannerItemSourceRead, itinerary: PlannerItinerarySourceRead),
  _ after: (item: PlannerItemSourceRead, itinerary: PlannerItinerarySourceRead)
) {
  XCTAssertEqual(after.item.source, before.item.source)
  XCTAssertEqual(after.item.sourceLifetimeId, before.item.sourceLifetimeId)
  XCTAssertEqual(after.item.fieldHashes, before.item.fieldHashes)
  XCTAssertEqual(after.item.updatedAt, before.item.updatedAt)
  XCTAssertEqual(after.item.references, before.item.references)
  XCTAssertEqual(after.item.state.globalDone, before.item.state.globalDone)
  XCTAssertEqual(after.item.state.archived, before.item.state.archived)
  XCTAssertEqual(after.itinerary.source, before.itinerary.source)
  XCTAssertEqual(after.itinerary.sourceLifetimeId, before.itinerary.sourceLifetimeId)
  XCTAssertEqual(after.itinerary.content, before.itinerary.content)
  XCTAssertEqual(after.itinerary.fieldHashes, before.itinerary.fieldHashes)
  XCTAssertEqual(after.itinerary.updatedAt, before.itinerary.updatedAt)
  XCTAssertEqual(after.itinerary.references, before.itinerary.references)
  XCTAssertEqual(after.itinerary.state.archived, before.itinerary.state.archived)
}

@MainActor
private func deleteAssociationFixtureSource(
  _ source: PlannerEntityReference, fixture: LabelAssociationIntentFixture
) async throws {
  let command = PlannerCommand.deleteSource(source: source)
  guard
    case .reviewed(let review) = await fixture.planner.prepareReview(
      session: fixture.session, command: command),
    case .applied(_, .complete) = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session, command: command,
        reviewToken: review.reviewToken)
    ).outcome
  else { throw CancellationError() }
}
