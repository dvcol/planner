import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItineraryItemIntentTests: XCTestCase {
  func testGetRetainsExactRepeatedDirectAppearanceAndReturnsLiveLocalState() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let createdItem = try await save(
      .createItem(content: .init(title: "Hotel", notes: "Shared notes")))
    let item = try XCTUnwrap(createdItem.generated.first)
    let createdItinerary = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
    let itinerary = try XCTUnwrap(createdItinerary.generated.first)
    let firstEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    let secondEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard case .itineraryEntry(let firstIdentifier, _, _)? = firstEntry.generatedReferences.first,
      case .itineraryEntry(let secondIdentifier, _, _)? = secondEntry.generatedReferences.first
    else { return XCTFail("Repeated Item stops must have distinct saved entry identities.") }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .directItineraryItem(itineraryId: itinerary.id, entryId: secondIdentifier)),
        done: true))
    let firstIdentity = "v1/direct/\(itinerary.id)/\(firstIdentifier)/\(item.id)"
    let secondIdentity = "v1/direct/\(itinerary.id)/\(secondIdentifier)/\(item.id)"
    let reading = GetPlannerItineraryItemIntent()
    reading.itinerary = .init(id: itinerary.id, title: "Cached route", archived: true)
    reading.item = .init(
      id: secondIdentity, title: "Cached Hotel", context: "Cached position", globallyDone: true,
      locallyDone: false, done: false, archived: true)
    let current = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(current.id, secondIdentity)
    XCTAssertEqual(current.title, "Hotel")
    XCTAssertEqual(current.context, "Tokyo Weekend · Stop 2")
    XCTAssertFalse(current.globallyDone)
    XCTAssertTrue(current.locallyDone)
    XCTAssertTrue(current.done)
    XCTAssertFalse(current.archived)
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(for: [secondIdentity, firstIdentity, secondIdentity])
    XCTAssertEqual(resolved.map(\.id), [secondIdentity, firstIdentity])
    XCTAssertEqual(resolved.map(\.context), ["Tokyo Weekend · Stop 2", "Tokyo Weekend · Stop 1"])
    XCTAssertEqual(resolved.map(\.locallyDone), [true, false])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testExpandedRepeatsKeepTheirIdentityWhileNamesAndSavedPositionsChange() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let createdMuseum = try await save(.createItem(content: .init(title: "Museum")))
    let museum = try XCTUnwrap(createdMuseum.generated.first)
    let createdLunch = try await save(.createItem(content: .init(title: "Lunch")))
    let lunch = try XCTUnwrap(createdLunch.generated.first)
    let createdList = try await save(.createList(content: .init(name: "Food")))
    let list = try XCTUnwrap(createdList.generated.first)
    let createdEmptyList = try await save(.createList(content: .init(name: "Empty stop")))
    let emptyList = try XCTUnwrap(createdEmptyList.generated.first)
    let museumMembership = try await save(
      .addMembership(itemId: museum.id, listId: list.id, placement: .last))
    let lunchMembership = try await save(
      .addMembership(itemId: lunch.id, listId: list.id, placement: .last))
    let createdItinerary = try await save(.createItinerary(content: .init(title: "Tokyo")))
    let itinerary = try XCTUnwrap(createdItinerary.generated.first)
    let direct = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: museum, placement: .last))
    let firstBranch = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: emptyList, placement: .last))
    let secondBranch = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    guard
      case .membership(let museumIdentifier, _, _)? = museumMembership.generatedReferences.first,
      case .membership(let lunchIdentifier, _, _)? = lunchMembership.generatedReferences.first,
      case .itineraryEntry(let directIdentifier, _, _)? = direct.generatedReferences.first,
      case .itineraryEntry(let firstIdentifier, _, _)? = firstBranch.generatedReferences.first,
      case .itineraryEntry(let secondIdentifier, _, _)? = secondBranch.generatedReferences.first,
      case .source(.item(let originalMuseum)) = await planner.read(
        session: session, request: .source(museum)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let originalItinerary)) = await planner.read(
        session: session, request: .source(itinerary))
    else { return XCTFail("Repeated List entries need their own complete saved identities.") }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: secondIdentifier, membershipId: museumIdentifier
          )),
        done: true))
    _ = try await save(.setArchive(source: museum, archived: true))
    _ = try await save(
      .editItem(
        sourceId: museum.id, changes: .init(title: .set("Nezu Museum")),
        expectedFieldHashes: originalMuseum.fieldHashes))
    _ = try await save(
      .editList(
        sourceId: list.id, changes: .init(name: .set("Tokyo Food")),
        expectedFieldHashes: originalList.fieldHashes))
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id, changes: .init(title: .set("Tokyo Weekend")),
        expectedFieldHashes: originalItinerary.fieldHashes))
    _ = try await save(
      .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: directIdentifier,
        placement: .before(associationId: secondIdentifier)))
    _ = try await save(
      .reorderMembership(listId: list.id, membershipId: lunchIdentifier, placement: .first))
    let secondMuseum =
      "v1/list/\(itinerary.id)/\(secondIdentifier)/\(museumIdentifier)/\(museum.id)"
    let firstLunch = "v1/list/\(itinerary.id)/\(firstIdentifier)/\(lunchIdentifier)/\(lunch.id)"
    let directMuseum = "v1/direct/\(itinerary.id)/\(directIdentifier)/\(museum.id)"
    let firstMuseum = "v1/list/\(itinerary.id)/\(firstIdentifier)/\(museumIdentifier)/\(museum.id)"
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(for: [
      secondMuseum, firstLunch, directMuseum, firstMuseum,
    ])
    XCTAssertEqual(resolved.map(\.id), [secondMuseum, firstLunch, directMuseum, firstMuseum])
    XCTAssertEqual(resolved.map(\.title), ["Nezu Museum", "Lunch", "Nezu Museum", "Nezu Museum"])
    XCTAssertEqual(
      resolved.map(\.context),
      [
        "Tokyo Weekend · Stop 4 · Tokyo Food · Item 2",
        "Tokyo Weekend · Stop 1 · Tokyo Food · Item 1",
        "Tokyo Weekend · Stop 3", "Tokyo Weekend · Stop 1 · Tokyo Food · Item 2",
      ])
    XCTAssertEqual(resolved.map(\.globallyDone), [false, false, false, false])
    XCTAssertEqual(resolved.map(\.locallyDone), [true, false, false, false])
    XCTAssertEqual(resolved.map(\.done), [true, false, false, false])
    XCTAssertEqual(resolved.map(\.archived), [true, false, true, true])
  }

  func testIdentityReadsCrossPagesNormalizeUUIDCaseAndNeverInventUnscopedChoices() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let createdItem = try await save(.createItem(content: .init(title: "Hotel")))
    let item = try XCTUnwrap(createdItem.generated.first)
    let createdItinerary = try await save(.createItinerary(content: .init(title: "Long route")))
    let itinerary = try XCTUnwrap(createdItinerary.generated.first)
    var identifiers: [String] = []
    for _ in 0..<65 {
      let created = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
      guard case .itineraryEntry(let entry, _, _)? = created.generatedReferences.first else {
        return XCTFail("Every repeated stop needs its own saved identity.")
      }
      identifiers.append("v1/direct/\(itinerary.id)/\(entry)/\(item.id)")
    }
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = store
    let reversedIdentifiers = Array(identifiers.reversed())
    let resolved = try await query.entities(
      for: reversedIdentifiers + [
        identifiers[0].lowercased(), "", "v2/direct/\(itinerary.id)/\(UUID())/\(item.id)",
        "v1/direct/invalid", "v1/list/\(itinerary.id)/\(UUID())/\(UUID())/\(item.id)",
      ])
    XCTAssertEqual(resolved.map(\.id), reversedIdentifiers)
    XCTAssertEqual(Set(resolved.map(\.id)).count, 65)
    XCTAssertEqual(resolved.first?.context, "Long route · Stop 65")
    XCTAssertEqual(resolved.last?.context, "Long route · Stop 1")
    XCTAssertTrue(resolved.allSatisfy { $0.title == "Hotel" && !$0.done })
    let suggestions = try await query.suggestedEntities()
    let search = try await query.entities(matching: "Hotel")
    XCTAssertTrue(suggestions.isEmpty)
    XCTAssertTrue(search.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testCompletionChangesOnlyTheSelectedAppearanceAndKeepsGlobalPrecedence() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let createdItem = try await save(
      .createItem(content: .init(title: "Hotel", notes: "Keep booking")))
    let item = try XCTUnwrap(createdItem.generated.first)
    let createdList = try await save(.createList(content: .init(name: "Food")))
    let list = try XCTUnwrap(createdList.generated.first)
    let createdMembership = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last))
    let createdItinerary = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
    let itinerary = try XCTUnwrap(createdItinerary.generated.first)
    var entries: [UUID] = []
    for source in [item, list, item, list] {
      let added = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
      guard case .itineraryEntry(let identifier, _, _)? = added.generatedReferences.first else {
        return XCTFail("Every route stop needs a distinct saved entry.")
      }
      entries.append(identifier)
    }
    guard case .membership(let membership, _, _)? = createdMembership.generatedReferences.first
    else {
      return XCTFail("The source List needs its own independent completion context.")
    }
    let standalone = PlannerAppearance.listMembership(listId: list.id, membershipId: membership)
    let direct = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: entries[0])
    let firstBranch = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entries[1], membershipId: membership)
    let otherDirect = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: entries[2])
    let selected = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entries[3], membershipId: membership)
    _ = try await save(.setCompletion(scope: .appearance(standalone), done: true))
    _ = try await save(.setCompletion(scope: .appearance(direct), done: true))
    let form = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
    let createdSchedule = try await save(.createSchedule(source: itinerary, form: form))
    let schedule = try XCTUnwrap(createdSchedule.generated.first)
    let manual = PlannerItemQuery(
      scope: .itinerary(itinerary.id), completion: .all, archive: .all, sort: .init(mode: .manual))
    guard
      case .source(.item(let before)) = await planner.read(session: session, request: .source(item)),
      case .snapshot(let beforeOrder) = await planner.query(
        .init(session: session, request: .items(manual)))
    else {
      return XCTFail("Shared content and saved route must be readable before the local action.")
    }
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = store
    let identity = "v1/list/\(itinerary.id)/\(entries[3])/\(membership)/\(item.id)"
    let resolved = try await query.entities(for: [identity])
    let completion = SetPlannerItineraryItemCompletionIntent()
    completion.itinerary = .init(id: itinerary.id, title: "Cached route", archived: true)
    completion.item = try XCTUnwrap(resolved.first)
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    guard
      case .source(.item(let afterLocal)) = await planner.read(
        session: session, request: .source(item)),
      case .appearance(let selectedDone) = await planner.read(
        session: session, request: .appearance(selected))
    else { return XCTFail("The exact selected local flag must change without editing the Item.") }
    XCTAssertEqual(afterLocal.fieldHashes, before.fieldHashes)
    XCTAssertEqual(afterLocal.updatedAt, before.updatedAt)
    XCTAssertFalse(selectedDone.globalDone)
    XCTAssertTrue(selectedDone.localDone)
    let global = SetPlannerItemCompletionIntent()
    global.item = .init(id: item.id, title: "Cached Hotel", done: false, archived: false)
    global.done = true
    let _: Void = try await global.callAsFunction(donate: false)
    completion.done = false
    let _: Void = try await completion.callAsFunction(donate: false)
    let masked = try await query.entities(for: [identity])
    XCTAssertEqual(masked.map(\.globallyDone), [true])
    XCTAssertEqual(masked.map(\.locallyDone), [false])
    XCTAssertEqual(masked.map(\.done), [true])
    global.done = false
    let _: Void = try await global.callAsFunction(donate: false)
    _ = try await save(.setArchive(source: list, archived: true))
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let savedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.itinerary(let savedItinerary)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.schedule(let savedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .snapshot(let afterOrder) = await reopened.query(
        .init(session: reopenedSession, request: .items(manual)))
    else { return XCTFail("The entire graph must survive reopening after local/global changes.") }
    for (appearance, expectedLocal) in [
      (standalone, true), (direct, true), (firstBranch, false), (otherDirect, false),
      (selected, false),
    ] {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else { return XCTFail("Every original context must survive.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, expectedLocal)
      XCTAssertEqual(current.effectiveDone, expectedLocal)
    }
    XCTAssertEqual(savedItem.content.title, "Hotel")
    XCTAssertEqual(savedItem.content.notes, "Keep booking")
    XCTAssertEqual(savedItem.state.archived, false)
    XCTAssertEqual(savedSchedule.content.form, form)
    XCTAssertEqual(afterOrder.rows, beforeOrder.rows)
    XCTAssertEqual(savedItinerary.progress.totalCount, 4)
    XCTAssertEqual(savedItinerary.progress.doneCount, 1)
    XCTAssertEqual(savedItinerary.progress.archivedCount, 2)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }
  func testMalformedForeignRemovedAndDeletedSelectionsCannotRetargetOrChangeGlobalState()
    async throws
  {
    let fixture = try await makeItineraryItemIntentFixture()
    let itemSource = PlannerEntityReference(kind: .item, id: fixture.item.id)
    let owner = PlannerEntityReference(kind: .itinerary, id: fixture.itinerary.id)
    func requireRejected(_ identifier: String, itinerary: PlannerItineraryEntity) async {
      let reading = GetPlannerItineraryItemIntent()
      reading.itinerary = itinerary
      reading.item = .init(
        id: identifier, title: "Cached", context: "Cached", globallyDone: false,
        locallyDone: false, done: false, archived: false)
      do {
        _ = try await reading.callAsFunction(donate: false)
        XCTFail("An invalid appearance must not resolve another target.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      let completion = SetPlannerItineraryItemCompletionIntent()
      completion.itinerary = itinerary
      completion.item = reading.item
      completion.done = true
      do {
        let _: Void = try await completion.callAsFunction(donate: false)
        XCTFail(
          "An invalid appearance cannot fall back to another appearance or global completion.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let foreignCreation = CreatePlannerItineraryIntent()
    foreignCreation.title = "Other route"
    let foreign = try await foreignCreation.callAsFunction(donate: false)
    await requireRejected(fixture.selection.id, itinerary: foreign)
    for identifier in [
      "", "v2/direct/\(fixture.itinerary.id)/\(fixture.entryIdentifier)/\(fixture.item.id)",
      "v1/direct/invalid", "v1/direct/\(fixture.itinerary.id)/\(fixture.entryIdentifier)/\(UUID())",
      "v1/direct/\(fixture.itinerary.id)/\(UUID())/\(fixture.item.id)",
      "v1/list/\(fixture.itinerary.id)/\(fixture.entryIdentifier)/\(UUID())/\(fixture.item.id)",
      fixture.selection.id + "/unexpected",
    ] { await requireRejected(identifier, itinerary: fixture.itinerary) }
    guard
      case .appearance(let originalAppearance) = await fixture.planner.read(
        session: fixture.session,
        request: .appearance(
          .directItineraryItem(
            itineraryId: fixture.itinerary.id, entryId: fixture.entryIdentifier))),
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(itemSource)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeItineraryEntry(
            itineraryId: fixture.itinerary.id, entryId: fixture.entryIdentifier))
      ).outcome
    else {
      return XCTFail("The original appearance must be removed before testing its cached identity.")
    }
    XCTAssertFalse(originalAppearance.globalDone)
    XCTAssertFalse(originalAppearance.localDone)
    let adding = AddPlannerItemToItineraryIntent()
    adding.item = fixture.item
    adding.itinerary = fixture.itinerary
    let _: Void = try await adding.callAsFunction(donate: false)
    await requireRejected(fixture.selection.id, itinerary: fixture.itinerary)
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = fixture.store
    let old = try await query.entities(for: [fixture.selection.id])
    XCTAssertTrue(old.isEmpty)
    guard
      case .source(.item(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(itemSource)),
      case .source(.itinerary(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner)),
      case .itineraryEntry(let replacement, _, _)? = current.references.first
    else {
      return XCTFail("Ordinary re-add must preserve the Item and create one new local Todo stop.")
    }
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.state.globalDone, false)
    XCTAssertNotEqual(replacement, fixture.entryIdentifier)
    let newIdentity = "v1/direct/\(fixture.itinerary.id)/\(replacement)/\(fixture.item.id)"
    let newSelection = try await query.entities(for: [newIdentity])
    XCTAssertEqual(newSelection.map(\.locallyDone), [false])
    XCTAssertEqual(newSelection.map(\.done), [false])
    for source in [itemSource, owner] {
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: .deleteSource(source: source)),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: .deleteSource(source: source),
            reviewToken: review.reviewToken)
        ).outcome
      else { return XCTFail("Native reviewed deletion must invalidate its original appearances.") }
      await requireRejected(newIdentity, itinerary: fixture.itinerary)
    }
    let deleted = try await query.entities(for: [newIdentity])
    XCTAssertTrue(deleted.isEmpty)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testDirectCompletionAndPrecancelledRequestsRetainTheExactSavedFlag() async throws {
    let fixture = try await makeItineraryItemIntentFixture()
    let completion = SetPlannerItineraryItemCompletionIntent()
    completion.itinerary = fixture.itinerary
    completion.item = fixture.selection
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = fixture.store
    let before = try await query.entities(for: [fixture.selection.id])
    XCTAssertEqual(before.map(\.globallyDone), [false])
    XCTAssertEqual(before.map(\.locallyDone), [true])
    completion.done = false
    let request = Task {
      let _: Void = try await completion.callAsFunction(donate: false)
    }
    request.cancel()
    do {
      let _: Void = try await request.value
      XCTFail("A cancelled local action cannot clear the saved flag.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let readRequest = Task { try await query.entities(for: [fixture.selection.id]) }
    readRequest.cancel()
    do {
      _ = try await readRequest.value
      XCTFail("A cancelled identity read cannot acknowledge an entity result.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let after = try await query.entities(for: [fixture.selection.id])
    XCTAssertEqual(after.map(\.locallyDone), [true])
    let _: Void = try await completion.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .appearance(let current) = await reopened.read(
        session: session,
        request: .appearance(
          .directItineraryItem(itineraryId: fixture.itinerary.id, entryId: fixture.entryIdentifier))
      )
    else { return XCTFail("A later explicit direct-stop Reopen must persist.") }
    XCTAssertFalse(current.globalDone)
    XCTAssertFalse(current.localDone)
    XCTAssertFalse(current.effectiveDone)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testUnavailableStorageRejectsIdentityChoicesGetAndCompletion() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let owner = PlannerItineraryEntity(id: UUID(), title: "Unavailable", archived: false)
    let selection = PlannerItineraryItemEntity(
      id: "v1/direct/\(owner.id)/\(UUID())/\(UUID())", title: "Unavailable", context: "Unavailable",
      globallyDone: false, locallyDone: false, done: false, archived: false)
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = store
    func requireUnavailable(_ request: () async throws -> [PlannerItineraryItemEntity]) async {
      do {
        _ = try await request()
        XCTFail("Unavailable storage must not become empty successful appearance data.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    await requireUnavailable { try await query.entities(for: [selection.id]) }
    await requireUnavailable { try await query.suggestedEntities() }
    await requireUnavailable { try await query.entities(matching: "Hotel") }
    let reading = GetPlannerItineraryItemIntent()
    reading.itinerary = owner
    reading.item = selection
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a live appearance.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let completion = SetPlannerItineraryItemCompletionIntent()
    completion.itinerary = owner
    completion.item = selection
    completion.done = true
    do {
      let _: Void = try await completion.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge completion.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testIncompleteRecoveryRetainsTheAppliedFlagAndRetriesTheOriginalOperation() async throws {
    let fixture = try await makeItineraryItemIntentFixture()
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let completion = SetPlannerItineraryItemCompletionIntent()
    completion.itinerary = fixture.itinerary
    completion.item = fixture.selection
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    let query = PlannerItineraryItemEntityQuery()
    query.plannerStore = fixture.store
    let applied = try await query.entities(for: [fixture.selection.id])
    XCTAssertEqual(applied.map(\.locallyDone), [true])
    XCTAssertEqual(applied.map(\.globallyDone), [false])
    completion.done = false
    do {
      let _: Void = try await completion.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block a subsequent local change.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    let owner = PlannerEntityReference(kind: .itinerary, id: fixture.itinerary.id)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let beforeRetry)) = await reopened.read(
        session: session, request: .source(owner))
    else { return XCTFail("The applied appearance must remain in real reopened storage.") }
    await fixture.store.retryIncompleteRecovery()
    XCTAssertFalse(fixture.store.recoveryBlocked)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.itinerary(let afterRetry)) = await reopened.read(
        session: session, request: .source(owner))
    else { return XCTFail("Native recovery must acknowledge the original completion operation.") }
    XCTAssertEqual(afterRetry.updatedAt, beforeRetry.updatedAt)
    XCTAssertEqual(afterRetry.references, beforeRetry.references)
    let retained = try await query.entities(for: [fixture.selection.id])
    XCTAssertEqual(retained.map(\.locallyDone), [true])
    let _: Void = try await completion.callAsFunction(donate: false)
    let changed = try await query.entities(for: [fixture.selection.id])
    XCTAssertEqual(changed.map(\.locallyDone), [false])
    XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
    XCTAssertFalse(fixture.store.isSaving)
  }
}

private struct ItineraryItemIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let item: PlannerItemEntity
  let itinerary: PlannerItineraryEntity
  let entryIdentifier: UUID
  let selection: PlannerItineraryItemEntity
}

@MainActor
private func makeItineraryItemIntentFixture() async throws -> ItineraryItemIntentFixture {
  let (_, configuration, store) = try makePlannerIntentStorage()
  AppDependencyManager.shared.add(dependency: store)
  let itemCreation = CreatePlannerItemIntent()
  itemCreation.title = "Hotel"
  itemCreation.notes = "Keep booking"
  let item = try await itemCreation.callAsFunction(donate: false)
  let itineraryCreation = CreatePlannerItineraryIntent()
  itineraryCreation.title = "Tokyo Weekend"
  let itinerary = try await itineraryCreation.callAsFunction(donate: false)
  let adding = AddPlannerItemToItineraryIntent()
  adding.item = item
  adding.itinerary = itinerary
  let _: Void = try await adding.callAsFunction(donate: false)
  let planner = PlannerCore.Planner(configuration: configuration)
  guard case .ready(let session) = await planner.bootstrap(),
    case .source(.itinerary(let current)) = await planner.read(
      session: session, request: .source(.init(kind: .itinerary, id: itinerary.id))),
    case .itineraryEntry(let entryIdentifier, _, _)? = current.references.first
  else { throw CancellationError() }
  return .init(
    configuration: configuration, store: store, planner: planner, session: session, item: item,
    itinerary: itinerary, entryIdentifier: entryIdentifier,
    selection: .init(
      id: "v1/direct/\(itinerary.id)/\(entryIdentifier)/\(item.id)", title: "Cached Hotel",
      context: "Cached position", globallyDone: false, locallyDone: false, done: false,
      archived: false))
}
