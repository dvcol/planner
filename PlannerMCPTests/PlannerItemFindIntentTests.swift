import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItemFindIntentTests: XCTestCase {
  func testMissingCriteriaIdentitiesNeverFallBackToNamesAndRetainAnyAllSemantics() async throws {
    let fixture = try await makeItemFindIntentFixture()
    let createCategory = CreatePlannerCategoryIntent()
    createCategory.name = "Matching name"
    let category = try await createCategory.callAsFunction(donate: false)
    let createTag = CreatePlannerTagIntent()
    createTag.name = "Matching name"
    let tag = try await createTag.callAsFunction(donate: false)
    let createList = CreatePlannerListIntent()
    createList.name = "Matching name"
    let list = try await createList.callAsFunction(donate: false)
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.items[0]))
    else { return XCTFail("Read the Item before assigning its real matching identities.") }
    _ = try await fixture.apply(
      .editItem(
        sourceId: current.source.id,
        changes: .init(categoryIds: .set([category.id]), tagIds: .set([tag.id])),
        expectedFieldHashes: current.fieldHashes))
    _ = try await fixture.apply(
      .addMembership(itemId: current.source.id, listId: list.id, placement: .last))
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the real identities and their associations.") }
    let find = FindPlannerItemsIntent()
    find.categories = [category, .init(id: UUID(), name: category.name)]
    let anyCategory: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(anyCategory.map(\.id), [current.source.id])
    find.categoryMatch = .all
    let everyCategory: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(everyCategory.isEmpty)
    find.categories = [category]
    find.tags = [tag, .init(id: UUID(), name: tag.name)]
    let anyTag: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(anyTag.map(\.id), [current.source.id])
    find.tagMatch = .all
    let everyTag: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(everyTag.isEmpty)
    find.tags = [tag]
    find.lists = [list, .init(id: UUID(), name: list.name, archived: false)]
    let anyList: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(anyList.map(\.id), [current.source.id])
    find.listMatch = .all
    let everyList: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(everyList.isEmpty)
    find.categories = nil
    find.tags = nil
    find.lists = nil
    let unrestricted: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(unrestricted.map(\.id), fixture.items.map(\.id))
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Missing criterion identities cannot change or create data.") }
    XCTAssertEqual(after, before)
  }

  func testPresenceAndSchedulingDistinguishOwnedDataAndRetainedDirectOrInheritedBookings()
    async throws
  {
    let fixture = try await makeItemFindIntentFixture()
    let locations: [PlannerOwnedLocation] = [
      .init(displayName: "Museum", formattedAddress: "1-1 Tokyo", coordinate: nil),
      .init(
        displayName: nil, formattedAddress: nil, coordinate: .init(latitude: 35, longitude: 139)),
      .init(displayName: "Name only", formattedAddress: nil, coordinate: nil),
      .init(displayName: nil, formattedAddress: "1-1 Osaka", coordinate: nil),
    ]
    let links: [[PlannerLinkInput]] = [
      [.init(originalUrl: "https://example.com/museum")],
      [.init(originalUrl: "https://www.google.com/maps/search/?api=1&query=35%2C139")], [], [],
    ]
    for (itemIndex, item) in fixture.items.enumerated() {
      guard
        case .source(.item(let current)) = await fixture.planner.read(
          session: fixture.session, request: .source(item))
      else { return XCTFail("Read the source before assigning owned data.") }
      _ = try await fixture.apply(
        .editItem(
          sourceId: item.id,
          changes: .init(location: .set(locations[itemIndex]), links: .set(links[itemIndex])),
          expectedFieldHashes: current.fieldHashes))
    }
    let savedList = try await fixture.apply(.createList(content: .init(name: "Places")))
    let list = try XCTUnwrap(savedList.generated.first(where: { $0.kind == .list }))
    _ = try await fixture.apply(
      .addMembership(itemId: fixture.items[1].id, listId: list.id, placement: .last))
    let savedPlan = try await fixture.apply(.createItinerary(content: .init(title: "Past plan")))
    let itinerary = try XCTUnwrap(savedPlan.generated.first(where: { $0.kind == .itinerary }))
    _ = try await fixture.apply(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let inherited = try await fixture.apply(
      .createSchedule(
        source: itinerary, form: .allDay(start: .init(year: 2020, month: 1, day: 1), end: nil)))
    let inheritedSchedule = try XCTUnwrap(
      inherited.generated.first(where: { $0.kind == .schedule }))
    let start = try Date.ISO8601FormatStyle().parse("2020-01-01T01:00:00Z")
    _ = try await fixture.apply(
      .createSchedule(
        source: fixture.items[0],
        form: .timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")))
    _ = try await fixture.apply(.setArchive(source: list, archived: true))
    _ = try await fixture.apply(.setArchive(source: itinerary, archived: true))
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record owned data and past bookings before finding.") }
    let find = FindPlannerItemsIntent()
    find.hasAddress = true
    let addressed: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(addressed.map(\.id), [0, 3].map { fixture.items[$0].id })
    find.hasLinks = true
    let both: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(both.map(\.id), [fixture.items[0].id])
    find.hasAddress = false
    let linked: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(linked.map(\.id), [0, 1].map { fixture.items[$0].id })
    find.scheduling = .scheduled
    let scheduled: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(scheduled.map(\.id), [0, 1].map { fixture.items[$0].id })
    find.scope = .inbox
    let scheduledInbox: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(scheduledInbox.map(\.id), [fixture.items[0].id])
    find.scope = .allItems
    find.hasLinks = false
    find.scheduling = .unscheduled
    let unscheduled: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(unscheduled.map(\.id), [2, 3].map { fixture.items[$0].id })
    find.hasAddress = true
    let unscheduledAddress: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(unscheduledAddress.map(\.id), [fixture.items[3].id])
    find.hasLinks = true
    let noMatch: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(noMatch.isEmpty)
    guard case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Presence and scheduling reads cannot modify saved data.") }
    XCTAssertEqual(unchanged, before)
    let scheduleQuery = PlannerScheduleEntityQuery()
    scheduleQuery.plannerStore = fixture.store
    let choices = try await scheduleQuery.entities(for: [inheritedSchedule.id])
    let remove = RemovePlannerScheduleIntent()
    remove.schedule = try XCTUnwrap(choices.first)
    let _: Void = try await remove.callAsFunction(donate: false)
    find.hasAddress = false
    find.hasLinks = false
    let afterRemoval: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(afterRemoval.map(\.id), [1, 2, 3].map { fixture.items[$0].id })
    find.scheduling = .scheduled
    let directRemains: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(directRemains.map(\.id), [fixture.items[0].id])
  }

  func testTagAndListGroupsNarrowTogetherAndFollowMembershipChanges() async throws {
    let fixture = try await makeItemFindIntentFixture()
    let createTag = CreatePlannerTagIntent()
    createTag.name = "Trip"
    let firstTag = try await createTag.callAsFunction(donate: false)
    let secondTag = try await createTag.callAsFunction(donate: false)
    let createCategory = CreatePlannerCategoryIntent()
    createCategory.name = "Museum"
    let category = try await createCategory.callAsFunction(donate: false)
    let tagSets: [Set<UUID>] = [[firstTag.id], [secondTag.id], [firstTag.id, secondTag.id]]
    for (itemIndex, identifiers) in tagSets.enumerated() {
      guard
        case .source(.item(let current)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.items[itemIndex]))
      else { return XCTFail("Read the shared Item before assigning labels.") }
      _ = try await fixture.apply(
        .editItem(
          sourceId: current.source.id,
          changes: .init(categoryIds: .set([category.id]), tagIds: .set(identifiers)),
          expectedFieldHashes: current.fieldHashes))
    }
    let createList = CreatePlannerListIntent()
    createList.name = "Plans"
    let firstList = try await createList.callAsFunction(donate: false)
    let secondList = try await createList.callAsFunction(donate: false)
    for itemIndex in [0, 1, 3] {
      _ = try await fixture.apply(
        .addMembership(itemId: fixture.items[itemIndex].id, listId: firstList.id, placement: .last))
    }
    for itemIndex in [0, 2, 3] {
      _ = try await fixture.apply(
        .addMembership(itemId: fixture.items[itemIndex].id, listId: secondList.id, placement: .last)
      )
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the original shared labels and List memberships.") }
    let find = FindPlannerItemsIntent()
    find.tags = [firstTag, secondTag, firstTag]
    let anyTag: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(anyTag.map(\.id), [0, 1, 2].map { fixture.items[$0].id })
    find.tagMatch = .all
    let everyTag: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(everyTag.map(\.id), [fixture.items[2].id])
    find.tags = []
    find.lists = [firstList, secondList, firstList]
    let anyList: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(anyList.map(\.id), fixture.items.map(\.id))
    find.listMatch = .all
    let everyList: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(everyList.map(\.id), [0, 3].map { fixture.items[$0].id })
    find.lists = [secondList]
    find.categories = [category]
    find.tags = [firstTag]
    let combined: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(combined.map(\.id), [0, 2].map { fixture.items[$0].id })
    find.archive = .active
    find.completion = .todo
    let active: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(active.map(\.id), [fixture.items[0].id])
    find.text = "OSAKA"
    let excludedText: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(excludedText.isEmpty)
    find.text = ""
    find.scope = .inbox
    let impossibleInbox: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(impossibleInbox.isEmpty)
    find.scope = .allItems
    find.categories = []
    find.tags = []
    find.lists = []
    find.archive = .all
    find.completion = .all
    let unrestricted: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(unrestricted.map(\.id), fixture.items.map(\.id))
    guard case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Finding through shared references cannot mutate the graph.") }
    XCTAssertEqual(unchanged, before)
    _ = try await fixture.apply(
      .setArchive(source: .init(kind: .list, id: firstList.id), archived: true))
    find.lists = [firstList]
    let archivedList: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(archivedList.map(\.id), [0, 1, 3].map { fixture.items[$0].id })
    let remove = RemovePlannerItemFromListIntent()
    remove.item = .init(id: fixture.items[0].id, title: "Cached", done: false, archived: false)
    remove.list = firstList
    let _: Void = try await remove.callAsFunction(donate: false)
    let refreshed: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(refreshed.map(\.id), [1, 3].map { fixture.items[$0].id })
  }

  func testCategoryCriteriaUseSharedIdentitiesAndAnyAllMatchingAcrossLiveRenames() async throws {
    let fixture = try await makeItemFindIntentFixture()
    let create = CreatePlannerCategoryIntent()
    create.name = "Museum"
    let first = try await create.callAsFunction(donate: false)
    let second = try await create.callAsFunction(donate: false)
    XCTAssertNotEqual(first.id, second.id)
    let categorySets: [Set<UUID>] = [[first.id], [first.id, second.id], [second.id]]
    for (itemIndex, identifiers) in categorySets.enumerated() {
      guard
        case .source(.item(let current)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.items[itemIndex]))
      else { return XCTFail("Read the shared Item before assigning its Categories.") }
      _ = try await fixture.apply(
        .editItem(
          sourceId: current.source.id, changes: .init(categoryIds: .set(identifiers)),
          expectedFieldHashes: current.fieldHashes))
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the shared Category associations before finding.") }
    let find = FindPlannerItemsIntent()
    find.categories = [first, first]
    let firstMatches: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(firstMatches.map(\.id), [0, 1].map { fixture.items[$0].id })
    find.categories = [second]
    let secondMatches: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(secondMatches.map(\.id), [1, 2].map { fixture.items[$0].id })
    find.categories = [first, second]
    let any: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(any.map(\.id), [0, 1, 2].map { fixture.items[$0].id })
    find.categoryMatch = .all
    let every: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(every.map(\.id), [fixture.items[1].id])
    find.categories = []
    let unrestricted: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(unrestricted.map(\.id), fixture.items.map(\.id))
    find.categories = [first]
    find.completion = .todo
    let todo: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(todo.map(\.id), [fixture.items[0].id])
    find.categories = [second]
    find.archive = .archived
    let archived: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(archived.map(\.id), [fixture.items[2].id])
    guard case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Finding by label identities must not rewrite shared data.") }
    XCTAssertEqual(unchanged, before)
    let rename = RenamePlannerCategoryIntent()
    rename.category = first
    rename.name = "Art"
    let _: Void = try await rename.callAsFunction(donate: false)
    let categoryQuery = PlannerCategoryEntityQuery()
    categoryQuery.plannerStore = fixture.store
    let current = try await categoryQuery.entities(for: [first.id])
    XCTAssertEqual(current.first?.name, "Art")
    find.categories = [first]
    find.completion = .all
    find.archive = .all
    let renamed: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(renamed.map(\.id), firstMatches.map(\.id))
    XCTAssertEqual(first.name, "Museum")
  }

  func testFindReadsAppliedContentWithoutAcknowledgingIncompleteRecovery() async throws {
    let fixture = try await makeItemFindIntentFixture()
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.items[0].id])
    let edit = EditPlannerItemIntent()
    edit.item = try XCTUnwrap(choices.first)
    edit.notes = "Recovery searchable notes"
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let _: Void = try await edit.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    guard
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.items[0]))
    else { return XCTFail("The applied edit must remain readable during the recovery fault.") }
    let find = FindPlannerItemsIntent()
    find.text = "SEARCHABLE"
    let all: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(all.map(\.id), [fixture.items[0].id])
    find.scope = .inbox
    let inbox: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(inbox.map(\.id), [fixture.items[0].id])
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    XCTAssertTrue(fixture.store.recoveryBlocked)
    guard
      case .source(.item(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.items[0]))
    else { return XCTFail("Find must retain the applied notes and source state.") }
    XCTAssertEqual(after.content.notes, "Recovery searchable notes")
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.references, before.references)
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    guard
      case .appliedRecoveryIncomplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { return XCTFail("Reads cannot acknowledge the original incomplete operation.") }
    await fixture.store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { return XCTFail("Explicit recovery must acknowledge only the original edit.") }
    let recovered: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(recovered.map(\.id), all.map(\.id))
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testFilteredInboxFindReadsEveryPageAndRefreshesAfterAnotherWriter() async throws {
    let fixture = try await makeItemFindIntentFixture()
    var visits: [PlannerEntityReference] = []
    for visitIndex in 0..<69 {
      let saved = try await fixture.apply(
        .createItem(content: .init(title: String(format: "Visit %02d", visitIndex))))
      visits.append(try XCTUnwrap(saved.generated.first(where: { $0.kind == .item })))
    }
    let savedList = try await fixture.apply(.createList(content: .init(name: "Chosen visits")))
    let list = try XCTUnwrap(savedList.generated.first(where: { $0.kind == .list }))
    for item in visits.prefix(2) {
      _ = try await fixture.apply(
        .addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record all 73 Items before paged native reads.") }
    let find = FindPlannerItemsIntent()
    find.scope = .inbox
    find.text = "VISIT"
    find.completion = .todo
    find.archive = .active
    find.direction = .descending
    let matches: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(matches.count, 67)
    XCTAssertEqual(matches.map(\.id), visits.dropFirst(2).reversed().map(\.id))
    XCTAssertEqual(Set(matches.map(\.id)).count, 67)
    XCTAssertEqual(matches.first?.title, "Visit 68")
    XCTAssertEqual(matches.last?.title, "Visit 02")
    guard case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Paged Find must retain every saved record.") }
    XCTAssertEqual(unchanged, before)
    let other = PlannerCore.Planner(configuration: fixture.configuration)
    let last = try XCTUnwrap(visits.last)
    guard case .ready(let otherSession) = await other.bootstrap(),
      case .applied(_, .complete) = await other.execute(
        .init(
          operationId: UUID(), session: otherSession,
          command: .setCompletion(scope: .globalItem(itemId: last.id), done: true))
      ).outcome,
      case .exported(let changed) = await other.exportData(session: otherSession)
    else { return XCTFail("A second real writer must complete the last visit.") }
    let refreshed: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(refreshed.count, 66)
    XCTAssertEqual(refreshed.map(\.id), visits.dropFirst(2).dropLast().reversed().map(\.id))
    find.completion = .all
    let all: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(all.count, 67)
    XCTAssertEqual(all.first?.id, last.id)
    XCTAssertEqual(all.first?.done, true)
    guard case .exported(let after) = await other.exportData(session: otherSession)
    else { return XCTFail("Refreshed Find must not rewrite the other writer's saved change.") }
    XCTAssertEqual(after, changed)
  }

  func testUnavailableStorageThrowsForEveryFindScopeInsteadOfReturningNoMatches() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let contents = Data("Keep query storage unavailable.".utf8)
    try contents.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let find = FindPlannerItemsIntent()
    find.text = "No matching data"
    for scope in [PlannerItemFindScope.allItems, .inbox] {
      find.scope = scope
      do {
        let _: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
        XCTFail("Unavailable storage cannot become a successful empty Find result.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledEmptyFindAndEntityQueriesThrowWithoutChangingData() async throws {
    let fixture = try await makeItemFindIntentFixture()
    await fixture.store.open()
    let find = FindPlannerItemsIntent()
    find.text = "Nothing matches this text"
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record saved data before cancelling empty-result reads.") }
    let invocations: [@MainActor () async throws -> Void] = [
      { let _: [PlannerItemEntity] = try await find.callAsFunction(donate: false) },
      { _ = try await query.entities(matching: "Nothing matches this text") },
      { _ = try await query.entities(for: []) },
    ]
    for invocation in invocations {
      let task = Task { @MainActor in try await invocation() }
      task.cancel()
      do {
        try await task.value
        XCTFail("A precancelled read must throw even when no Item matches.")
      } catch is CancellationError {
      } catch { XCTFail("Expected cancellation, received \(error).") }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancellation must leave saved data readable.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testInboxAndSortingPreserveManualOrderAndUseGlobalCompletion() async throws {
    let fixture = try await makeItemFindIntentFixture()
    let savedList = try await fixture.apply(.createList(content: .init(name: "Tokyo Food")))
    let list = try XCTUnwrap(savedList.generated.first(where: { $0.kind == .list }))
    let added = try await fixture.apply(
      .addMembership(itemId: fixture.items[0].id, listId: list.id, placement: .last))
    guard case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first else {
      return XCTFail("The List association must have its own saved identity.")
    }
    _ = try await fixture.apply(
      .addMembership(itemId: fixture.items[1].id, listId: list.id, placement: .first))
    _ = try await fixture.apply(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier)),
        done: true))
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.items[0]))
    else { return XCTFail("Read the Item before editing its own notes.") }
    _ = try await fixture.apply(
      .editItem(
        sourceId: fixture.items[0].id, changes: .init(notes: .set("Tokyo updated")),
        expectedFieldHashes: current.fieldHashes))
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record saved manual order and local states before sorted reads.") }
    let find = FindPlannerItemsIntent()
    find.scope = .inbox
    let inbox: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(inbox.map(\.id), [fixture.items[2].id, fixture.items[3].id])
    find.scope = .allItems
    find.direction = .descending
    let reverseTitle: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseTitle.map(\.id), fixture.items.reversed().map(\.id))
    find.sort = .created
    find.direction = .ascending
    let created: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(created.map(\.id), fixture.items.map(\.id))
    find.direction = .descending
    let reverseCreated: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseCreated.map(\.id), fixture.items.reversed().map(\.id))
    find.sort = .lastUpdated
    find.direction = .ascending
    let updated: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(updated.map(\.id), [3, 1, 2, 0].map { fixture.items[$0].id })
    find.direction = .descending
    let reverseUpdated: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseUpdated.map(\.id), [0, 2, 1, 3].map { fixture.items[$0].id })
    find.sort = .duration
    find.direction = .ascending
    let estimates: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(estimates.map(\.id), [2, 0, 3, 1].map { fixture.items[$0].id })
    find.direction = .descending
    let reverseEstimates: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseEstimates.map(\.id), [3, 0, 2, 1].map { fixture.items[$0].id })
    find.sort = .title
    find.direction = .ascending
    find.completion = .todo
    let todo: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(todo.map(\.id), [0, 2, 3].map { fixture.items[$0].id })
    XCTAssertEqual(todo.first?.done, false)
    find.completion = .done
    let done: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(done.map(\.id), [fixture.items[1].id])
    find.archive = .archived
    let archivedDone: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(archivedDone.isEmpty)
    find.completion = .all
    let archived: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(archived.map(\.id), [fixture.items[2].id])
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Read the saved graph after every sorting/filtering combination.") }
    XCTAssertEqual(after, before)
  }

  func testFindItemsCombinesTextCompletionAndArchiveWithoutChangingSavedData() async throws {
    let fixture = try await makeItemFindIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the saved data before finding Items.") }
    let find = FindPlannerItemsIntent()
    let all: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(all.map(\.id), fixture.items.map(\.id))
    XCTAssertEqual(all.map(\.title), ["A Museum", "B Museum", "C Museum", "D Osaka"])
    find.text = "TOKYO"
    find.completion = .todo
    find.archive = .active
    let narrowed: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(narrowed.map(\.id), [fixture.items[0].id])
    XCTAssertEqual(narrowed.first?.done, false)
    XCTAssertEqual(narrowed.first?.archived, false)
    find.text = "No matching notes"
    let empty = try await find.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Finding Items must leave the saved graph readable and unchanged.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
}

private struct ItemFindIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let items: [PlannerEntityReference]

  @MainActor func apply(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    let result = await planner.execute(
      .init(operationId: UUID(), session: session, command: command))
    guard case .applied(let saved, .complete) = result.outcome else {
      XCTFail("Save the real fixture command before exercising Item finding.")
      throw CancellationError()
    }
    return saved
  }
}

@MainActor
private func makeItemFindIntentFixture() async throws -> ItemFindIntentFixture {
  let (_, configuration, store) = try makePlannerIntentStorage()
  AppDependencyManager.shared.add(dependency: store)
  let planner = PlannerCore.Planner(configuration: configuration)
  guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
  var items: [PlannerEntityReference] = []
  let estimates: [Int64?] = [90, nil, 30, 120]
  for (itemIndex, title) in ["A Museum", "B Museum", "C Museum", "D Osaka"].enumerated() {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: title, notes: title == "D Osaka" ? "Osaka" : "Tokyo",
              estimate: estimates[itemIndex].map { .init(minutes: $0, displayUnit: .minute) })))
      )
      .outcome,
      let item = result.generated.first(where: { $0.kind == .item })
    else { throw CancellationError() }
    items.append(item)
  }
  guard
    case .applied(_, .complete) = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .setCompletion(scope: .globalItem(itemId: items[1].id), done: true))
    ).outcome,
    case .applied(_, .complete) = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .setArchive(source: items[2], archived: true))
    ).outcome
  else { throw CancellationError() }
  return .init(
    configuration: configuration, store: store, planner: planner, session: session, items: items)
}
