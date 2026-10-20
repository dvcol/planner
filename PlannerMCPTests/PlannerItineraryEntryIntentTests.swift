import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItineraryEntryIntentTests: XCTestCase {
  func testRemovingOneRepeatedListEntryPreservesSourcesOtherContextsEmptyStopAndBooking()
    async throws
  {
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
      .createItem(content: .init(title: "Museum", notes: "Keep booking")))
    let item = try XCTUnwrap(createdItem.generated.first)
    let createdLunch = try await save(
      .createItem(content: .init(title: "Lunch", notes: "Keep lunch")))
    let lunch = try XCTUnwrap(createdLunch.generated.first)
    let createdList = try await save(.createList(content: .init(name: "Tokyo Food")))
    let list = try XCTUnwrap(createdList.generated.first)
    let createdEmpty = try await save(.createList(content: .init(name: "Empty stop")))
    let emptyList = try XCTUnwrap(createdEmpty.generated.first)
    let createdMembership = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last))
    let createdLunchMembership = try await save(
      .addMembership(itemId: lunch.id, listId: list.id, placement: .last))
    guard case .membership(let membership, _, _)? = createdMembership.generatedReferences.first,
      case .membership(let lunchMembership, _, _)? = createdLunchMembership.generatedReferences
        .first
    else {
      return XCTFail("The shared List needs its own saved membership.")
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membership)), done: true))
    let createdItinerary = try await save(
      .createItinerary(content: .init(title: "Tokyo Weekend", notes: "Keep route notes")))
    let itinerary = try XCTUnwrap(createdItinerary.generated.first)
    var entries: [UUID] = []
    for source in [item, list, emptyList, list] {
      let created = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
      guard case .itineraryEntry(let identifier, _, _)? = created.generatedReferences.first else {
        return XCTFail("Every top-level stop needs a distinct saved entry.")
      }
      entries.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entries[3], membershipId: membership)),
        done: true))
    let form = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
    let createdSchedule = try await save(.createSchedule(source: itinerary, form: form))
    let schedule = try XCTUnwrap(createdSchedule.generated.first)
    guard
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.item(let beforeLunch)) = await planner.read(
        session: session, request: .source(lunch)),
      case .source(.list(let beforeList)) = await planner.read(
        session: session, request: .source(list))
    else { return XCTFail("Shared sources must be readable before removing one reference.") }
    let removal = RemovePlannerItineraryEntryIntent()
    removal.itinerary = .init(id: itinerary.id, title: "Cached route", archived: true)
    removal.entry = .init(
      id: "v1/entry/\(itinerary.id)/\(entries[1])/list/\(list.id)", title: "Cached",
      context: "Cached", kind: .item, archived: true)
    let _: Void = try await removal.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let savedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.item(let savedLunch)) = await reopened.read(
        session: reopenedSession, request: .source(lunch)),
      case .source(.list(let savedList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.list(let savedEmpty)) = await reopened.read(
        session: reopenedSession, request: .source(emptyList)),
      case .source(.itinerary(let saved)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.schedule(let booking)) = await reopened.read(
        session: reopenedSession, request: .source(schedule))
    else {
      return XCTFail("Removing a reference must preserve its sources and other planning data.")
    }
    let route = saved.references.compactMap { reference -> UUID? in
      guard case .itineraryEntry(let identifier, _, _) = reference else { return nil }
      return identifier
    }
    XCTAssertEqual(route, [entries[0], entries[2], entries[3]])
    XCTAssertEqual(savedItem.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(savedItem.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(savedItem.state.globalDone, false)
    XCTAssertEqual(savedLunch.fieldHashes, beforeLunch.fieldHashes)
    XCTAssertEqual(savedLunch.updatedAt, beforeLunch.updatedAt)
    XCTAssertEqual(savedLunch.state.globalDone, false)
    XCTAssertEqual(savedList.fieldHashes, beforeList.fieldHashes)
    XCTAssertEqual(savedList.updatedAt, beforeList.updatedAt)
    let survivingReferences = beforeList.references.filter { reference in
      guard case .itineraryEntry(let identifier, _, _) = reference else { return true }
      return identifier != entries[1]
    }
    XCTAssertEqual(savedList.references, survivingReferences)
    XCTAssertEqual(savedList.progress.doneCount, 1)
    XCTAssertEqual(savedList.progress.totalCount, 2)
    XCTAssertEqual(savedEmpty.content.name, "Empty stop")
    XCTAssertEqual(saved.content.notes, "Keep route notes")
    XCTAssertEqual(saved.progress.totalCount, 3)
    XCTAssertEqual(saved.progress.doneCount, 1)
    XCTAssertEqual(booking.content.form, form)
    for (appearance, expectedLocal) in [
      (
        PlannerAppearance.directItineraryItem(itineraryId: itinerary.id, entryId: entries[0]), false
      ),
      (
        .expandedListItem(
          itineraryId: itinerary.id, listEntryId: entries[3], membershipId: membership), true
      ),
      (
        .expandedListItem(
          itineraryId: itinerary.id, listEntryId: entries[3], membershipId: lunchMembership), false
      ),
    ] {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else { return XCTFail("Surviving local contexts must remain readable.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, expectedLocal)
    }
    let query = PlannerItineraryEntryEntityQuery()
    query.plannerStore = store
    let emptyIdentity = "v1/entry/\(itinerary.id)/\(entries[2])/list/\(emptyList.id)"
    let secondIdentity = "v1/entry/\(itinerary.id)/\(entries[3])/list/\(list.id)"
    let directIdentity = "v1/entry/\(itinerary.id)/\(entries[0])/item/\(item.id)"
    let resolved = try await query.entities(for: [
      emptyIdentity, removal.entry.id, secondIdentity, directIdentity,
    ])
    XCTAssertEqual(resolved.map(\.id), [emptyIdentity, secondIdentity, directIdentity])
    XCTAssertEqual(resolved.map(\.title), ["Empty stop", "Tokyo Food", "Museum"])
    XCTAssertEqual(
      resolved.map(\.context),
      [
        "Tokyo Weekend · Stop 2 · List", "Tokyo Weekend · Stop 3 · List",
        "Tokyo Weekend · Stop 1 · Item",
      ])
    XCTAssertEqual(resolved.map(\.kind), [.list, .list, .item])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }
  func testBeforeReorderKeepsRepeatedItemIdentityCompletionEmptyStopAndBooking() async throws {
    let fixture = try await makeItineraryEntryIntentFixture()
    let form = PlannerScheduleForm.allDay(start: .init(year: 2026, month: 10, day: 20), end: nil)
    guard
      case .applied(let created, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(
            source: .init(kind: .itinerary, id: fixture.itinerary.id), form: form))
      ).outcome,
      let schedule = created.generated.first,
      case .source(.item(let beforeItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item)),
      case .source(.list(let beforeList)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.list))
    else { return XCTFail("The saved route needs real source and booking observations.") }
    let reorder = ReorderPlannerItineraryEntryIntent()
    reorder.itinerary = fixture.itinerary
    reorder.entry = fixture.entries[2]
    reorder.position = .before
    reorder.relativeEntry = fixture.entries[0]
    let _: Void = try await reorder.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let saved)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: fixture.itinerary.id))),
      case .source(.item(let afterItem)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.list(let afterList)) = await reopened.read(
        session: session, request: .source(fixture.list)),
      case .source(.schedule(let booking)) = await reopened.read(
        session: session, request: .source(schedule)),
      case .snapshot(let manual) = await reopened.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .itinerary(fixture.itinerary.id), completion: .all, archive: .all,
              sort: .init(mode: .manual)))))
    else { return XCTFail("Reordering must retain the entire graph after reopening.") }
    let route = saved.references.compactMap { reference -> UUID? in
      guard case .itineraryEntry(let identifier, _, _) = reference else { return nil }
      return identifier
    }
    XCTAssertEqual(
      route,
      [fixture.entryIdentifiers[2], fixture.entryIdentifiers[0], fixture.entryIdentifiers[1]])
    XCTAssertEqual(
      manual.rows,
      [
        .appearance(
          source: fixture.item,
          appearance: .directItineraryItem(
            itineraryId: fixture.itinerary.id, entryId: fixture.entryIdentifiers[2])),
        .appearance(
          source: fixture.item,
          appearance: .directItineraryItem(
            itineraryId: fixture.itinerary.id, entryId: fixture.entryIdentifiers[0])),
      ])
    XCTAssertEqual(afterItem.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(afterItem.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(afterList.fieldHashes, beforeList.fieldHashes)
    XCTAssertEqual(afterList.updatedAt, beforeList.updatedAt)
    XCTAssertEqual(afterList.references, beforeList.references)
    XCTAssertEqual(saved.progress.totalCount, 2)
    XCTAssertEqual(saved.progress.doneCount, 1)
    XCTAssertEqual(booking.content.form, form)
    for (entry, expectedLocal) in [
      (fixture.entryIdentifiers[0], true), (fixture.entryIdentifiers[2], false),
    ] {
      guard
        case .appearance(let current) = await reopened.read(
          session: session,
          request: .appearance(
            .directItineraryItem(itineraryId: fixture.itinerary.id, entryId: entry)))
      else { return XCTFail("Repeated stops must retain independent completion.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, expectedLocal)
    }
  }
  func testBeginningEndAndAfterRetainExactEntriesAndIgnoreInactiveRelativeSelections() async throws
  {
    let fixture = try await makeItineraryEntryIntentFixture()
    let reorder = ReorderPlannerItineraryEntryIntent()
    reorder.itinerary = fixture.itinerary
    reorder.entry = fixture.entries[1]
    reorder.position = .first
    reorder.relativeEntry = .init(
      id: "not-an-active-anchor", title: "Missing", context: "Missing", kind: .item, archived: false
    )
    func requireOrder(_ expected: [UUID]) async throws {
      let reopened = PlannerCore.Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .source(.itinerary(let current)) = await reopened.read(
          session: session, request: .source(.init(kind: .itinerary, id: fixture.itinerary.id)))
      else { return XCTFail("Every placement must persist before checking the next one.") }
      let route = current.references.compactMap { reference -> UUID? in
        guard case .itineraryEntry(let identifier, _, _) = reference else { return nil }
        return identifier
      }
      XCTAssertEqual(route, expected)
      XCTAssertEqual(current.progress.totalCount, 2)
      XCTAssertEqual(current.progress.doneCount, 1)
      for (entry, expectedLocal) in [
        (fixture.entryIdentifiers[0], true), (fixture.entryIdentifiers[2], false),
      ] {
        guard
          case .appearance(let appearance) = await reopened.read(
            session: session,
            request: .appearance(
              .directItineraryItem(itineraryId: fixture.itinerary.id, entryId: entry)))
        else { return XCTFail("Reordering cannot replace contextual identities.") }
        XCTAssertFalse(appearance.globalDone)
        XCTAssertEqual(appearance.localDone, expectedLocal)
      }
    }
    let _: Void = try await reorder.callAsFunction(donate: false)
    try await requireOrder([
      fixture.entryIdentifiers[1], fixture.entryIdentifiers[0], fixture.entryIdentifiers[2],
    ])
    reorder.position = .last
    reorder.relativeEntry = nil
    let _: Void = try await reorder.callAsFunction(donate: false)
    try await requireOrder([
      fixture.entryIdentifiers[0], fixture.entryIdentifiers[2], fixture.entryIdentifiers[1],
    ])
    reorder.entry = fixture.entries[0]
    reorder.position = .after
    reorder.relativeEntry = fixture.entries[2]
    let _: Void = try await reorder.callAsFunction(donate: false)
    try await requireOrder([
      fixture.entryIdentifiers[2], fixture.entryIdentifiers[0], fixture.entryIdentifiers[1],
    ])
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
  func testLiveEntryReadsIncludeEmptyOnlyRoutesAndEveryPageWithCurrentNames() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
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
    let createdList = try await save(.createList(content: .init(name: "Food")))
    let list = try XCTUnwrap(createdList.generated.first)
    let createdItem = try await save(.createItem(content: .init(title: "Hotel")))
    let item = try XCTUnwrap(createdItem.generated.first)
    let createdItinerary = try await save(.createItinerary(content: .init(title: "Old route")))
    let itinerary = try XCTUnwrap(createdItinerary.generated.first)
    var identifiers: [String] = []
    for _ in 0..<65 {
      let created = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
      guard case .itineraryEntry(let entry, _, _)? = created.generatedReferences.first else {
        throw CancellationError()
      }
      identifiers.append("v1/entry/\(itinerary.id)/\(entry)/list/\(list.id)")
    }
    let query = PlannerItineraryEntryEntityQuery()
    query.plannerStore = store
    let emptyOnly = try await query.entities(for: identifiers)
    XCTAssertEqual(emptyOnly.map(\.id), identifiers)
    XCTAssertEqual(emptyOnly.last?.context, "Old route · Stop 65 · List")
    XCTAssertTrue(emptyOnly.allSatisfy { $0.kind == .list && $0.title == "Food" })
    for _ in 0..<65 {
      let created = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
      guard case .itineraryEntry(let entry, _, _)? = created.generatedReferences.first else {
        throw CancellationError()
      }
      identifiers.append("v1/entry/\(itinerary.id)/\(entry)/item/\(item.id)")
    }
    guard
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let itemRead)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let ownerRead)) = await planner.read(
        session: session, request: .source(itinerary))
    else { return XCTFail("Shared source edits must use current field hashes.") }
    _ = try await save(
      .editList(
        sourceId: list.id, changes: .init(name: .set("Tokyo Food")),
        expectedFieldHashes: listRead.fieldHashes))
    _ = try await save(
      .editItem(
        sourceId: item.id, changes: .init(title: .set("Renamed Hotel")),
        expectedFieldHashes: itemRead.fieldHashes))
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id, changes: .init(title: .set("Tokyo Weekend")),
        expectedFieldHashes: ownerRead.fieldHashes))
    _ = try await save(.setArchive(source: list, archived: true))
    let expected = Array(identifiers.reversed())
    let resolved = try await query.entities(
      for: expected + [
        identifiers[0].lowercased(), "", "v1/direct/\(itinerary.id)/\(UUID())/\(item.id)",
      ])
    XCTAssertEqual(resolved.map(\.id), expected)
    XCTAssertEqual(resolved.count, 130)
    XCTAssertEqual(resolved.first?.context, "Tokyo Weekend · Stop 130 · Item")
    XCTAssertEqual(resolved.last?.context, "Tokyo Weekend · Stop 1 · List")
    XCTAssertEqual(resolved.filter { $0.kind == .list }.count, 65)
    XCTAssertTrue(
      resolved.filter { $0.kind == .list }.allSatisfy { $0.title == "Tokyo Food" && $0.archived })
    XCTAssertTrue(
      resolved.filter { $0.kind == .item }.allSatisfy {
        $0.title == "Renamed Hotel" && !$0.archived
      })
    let unscoped = try await query.suggestedEntities()
    let unscopedSearch = try await query.entities(matching: "Hotel")
    XCTAssertTrue(unscoped.isEmpty)
    XCTAssertTrue(unscopedSearch.isEmpty)
  }

  func testInvalidStaleForeignAndDeletedEntriesOrAnchorsNeverRetarget() async throws {
    let fixture = try await makeItineraryEntryIntentFixture()
    let owner = PlannerEntityReference(kind: .itinerary, id: fixture.itinerary.id)
    guard
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner)),
      case .source(.item(let beforeItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { return XCTFail("Invalid-input checks need the original persisted graph.") }
    func requireRemovalRejected(
      _ entry: PlannerItineraryEntryEntity, itinerary: PlannerItineraryEntity
    ) async {
      let removal = RemovePlannerItineraryEntryIntent()
      removal.itinerary = itinerary
      removal.entry = entry
      do {
        let _: Void = try await removal.callAsFunction(donate: false)
        XCTFail("Invalid removal cannot acknowledge or retarget.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    func requireReorderRejected(
      _ entry: PlannerItineraryEntryEntity, relative: PlannerItineraryEntryEntity?,
      position: PlannerItineraryReorderPosition = .before
    ) async {
      let reorder = ReorderPlannerItineraryEntryIntent()
      reorder.itinerary = fixture.itinerary
      reorder.entry = entry
      reorder.position = position
      reorder.relativeEntry = relative
      do {
        let _: Void = try await reorder.callAsFunction(donate: false)
        XCTFail("Invalid placement cannot append, retarget or change state.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    for identifier in [
      "", fixture.entries[0].id + "/extra",
      "v2/entry/\(fixture.itinerary.id)/\(fixture.entryIdentifiers[0])/item/\(fixture.item.id)",
      "v1/direct/\(fixture.itinerary.id)/\(fixture.entryIdentifiers[0])/\(fixture.item.id)",
      "v1/entry/\(fixture.itinerary.id)/\(fixture.entryIdentifiers[0])/tag/\(fixture.item.id)",
      "v1/entry/\(fixture.itinerary.id)/\(fixture.entryIdentifiers[0])/list/\(fixture.item.id)",
      "v1/entry/\(fixture.itinerary.id)/\(UUID())/item/\(fixture.item.id)",
      "v1/entry/\(fixture.itinerary.id)/\(fixture.entryIdentifiers[0])/item/\(UUID())",
    ] {
      let invalid = PlannerItineraryEntryEntity(
        id: identifier, title: "Cached", context: "Cached", kind: .item, archived: false)
      await requireRemovalRejected(invalid, itinerary: fixture.itinerary)
      await requireReorderRejected(invalid, relative: fixture.entries[1])
      await requireReorderRejected(fixture.entries[0], relative: invalid)
    }
    await requireReorderRejected(fixture.entries[0], relative: nil)
    await requireReorderRejected(fixture.entries[0], relative: nil, position: .after)
    await requireReorderRejected(fixture.entries[0], relative: fixture.entries[0])
    guard
      case .applied(let foreignCreation, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItinerary(content: .init(title: "Foreign route")))
      ).outcome,
      let foreignSource = foreignCreation.generated.first,
      case .applied(let foreignAddition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addItineraryEntry(
            itineraryId: foreignSource.id, source: fixture.item, placement: .last))
      ).outcome,
      case .itineraryEntry(let foreignIdentifier, _, _)? = foreignAddition.generatedReferences.first
    else {
      return XCTFail("Foreign selection checks require an actual independent route and entry.")
    }
    let foreign = PlannerItineraryEntity(
      id: foreignSource.id, title: "Foreign route", archived: false)
    await requireRemovalRejected(fixture.entries[0], itinerary: foreign)
    let foreignEntry = PlannerItineraryEntryEntity(
      id: "v1/entry/\(foreign.id)/\(foreignIdentifier)/item/\(fixture.item.id)", title: "Foreign",
      context: "Foreign", kind: .item, archived: false)
    await requireReorderRejected(fixture.entries[0], relative: foreignEntry)
    guard
      case .source(.itinerary(let afterInvalid)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner)),
      case .source(.item(let afterItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item)),
      case .source(.itinerary(let foreignRead)) = await fixture.planner.read(
        session: fixture.session, request: .source(foreignSource))
    else { return XCTFail("Rejected operations must leave the original graph readable.") }
    XCTAssertEqual(afterInvalid.references, before.references)
    XCTAssertEqual(afterInvalid.updatedAt, before.updatedAt)
    XCTAssertEqual(afterItem.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(afterItem.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(
      foreignRead.references,
      [.itineraryEntry(id: foreignIdentifier, itinerary: foreignSource, source: fixture.item)])
    XCTAssertEqual(foreignRead.progress.doneCount, 0)
    let removal = RemovePlannerItineraryEntryIntent()
    removal.itinerary = fixture.itinerary
    removal.entry = fixture.entries[2]
    let _: Void = try await removal.callAsFunction(donate: false)
    guard
      case .applied(let added, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addItineraryEntry(
            itineraryId: fixture.itinerary.id, source: fixture.item, placement: .last))
      ).outcome,
      case .itineraryEntry(let replacement, _, _)? = added.generatedReferences.first,
      case .appearance(let newAppearance) = await fixture.planner.read(
        session: fixture.session,
        request: .appearance(
          .directItineraryItem(itineraryId: fixture.itinerary.id, entryId: replacement)))
    else { return XCTFail("Ordinary re-add must create a new local Todo stop.") }
    XCTAssertNotEqual(replacement, fixture.entryIdentifiers[2])
    XCTAssertFalse(newAppearance.localDone)
    await requireRemovalRejected(fixture.entries[2], itinerary: fixture.itinerary)
    await requireReorderRejected(fixture.entries[2], relative: fixture.entries[0])
    await requireReorderRejected(fixture.entries[0], relative: fixture.entries[2])
    for source in [fixture.list, fixture.item, owner] {
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: .deleteSource(source: source)),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: .deleteSource(source: source),
            reviewToken: review.reviewToken)
        ).outcome
      else {
        return XCTFail("Native reviewed deletion must invalidate the selected source's entries.")
      }
      let invalidated = source.kind == .list ? fixture.entries[1] : fixture.entries[0]
      await requireRemovalRejected(invalidated, itinerary: fixture.itinerary)
      await requireReorderRejected(invalidated, relative: fixture.entries[2])
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testPrecancelledRemovalOrderingAndIdentityReadsLeaveTheRouteUntouched() async throws {
    let fixture = try await makeItineraryEntryIntentFixture()
    let owner = PlannerEntityReference(kind: .itinerary, id: fixture.itinerary.id)
    guard
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner))
    else { throw CancellationError() }
    let removal = RemovePlannerItineraryEntryIntent()
    removal.itinerary = fixture.itinerary
    removal.entry = fixture.entries[2]
    let removeRequest = Task { let _: Void = try await removal.callAsFunction(donate: false) }
    removeRequest.cancel()
    do {
      try await removeRequest.value
      XCTFail("Precancelled removal cannot change a route.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let reorder = ReorderPlannerItineraryEntryIntent()
    reorder.itinerary = fixture.itinerary
    reorder.entry = fixture.entries[2]
    reorder.position = .first
    let reorderRequest = Task { let _: Void = try await reorder.callAsFunction(donate: false) }
    reorderRequest.cancel()
    do {
      try await reorderRequest.value
      XCTFail("Precancelled ordering cannot change a route.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let query = PlannerItineraryEntryEntityQuery()
    query.plannerStore = fixture.store
    let readRequest = Task { try await query.entities(for: [fixture.entries[0].id]) }
    readRequest.cancel()
    do {
      _ = try await readRequest.value
      XCTFail("A cancelled read cannot acknowledge entry data.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard
      case .source(.itinerary(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner))
    else { throw CancellationError() }
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    let _: Void = try await removal.callAsFunction(donate: false)
    let surviving = try await query.entities(for: fixture.entries.map(\.id))
    XCTAssertEqual(surviving.map(\.id), [fixture.entries[0].id, fixture.entries[1].id])
  }

  func testUnavailableStorageRejectsChoicesRemovalAndOrdering() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let itinerary = PlannerItineraryEntity(id: UUID(), title: "Unavailable", archived: false)
    let entry = PlannerItineraryEntryEntity(
      id: "v1/entry/\(itinerary.id)/\(UUID())/item/\(UUID())", title: "Unavailable",
      context: "Unavailable", kind: .item, archived: false)
    let query = PlannerItineraryEntryEntityQuery()
    query.plannerStore = store
    func requireUnavailable(_ request: () async throws -> [PlannerItineraryEntryEntity]) async {
      do {
        _ = try await request()
        XCTFail("Unavailable storage cannot become empty successful entry data.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    await requireUnavailable { try await query.entities(for: [entry.id]) }
    await requireUnavailable { try await query.suggestedEntities() }
    await requireUnavailable { try await query.entities(matching: "Hotel") }
    let removal = RemovePlannerItineraryEntryIntent()
    removal.itinerary = itinerary
    removal.entry = entry
    do {
      let _: Void = try await removal.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge removal.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let reorder = ReorderPlannerItineraryEntryIntent()
    reorder.itinerary = itinerary
    reorder.entry = entry
    reorder.position = .last
    do {
      let _: Void = try await reorder.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge ordering.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testIncompleteRecoveryRetainsRemovalAndOrderingWithoutReplayingEither() async throws {
    for removingEntry in [true, false] {
      let fixture = try await makeItineraryEntryIntentFixture()
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
      if removingEntry {
        let removal = RemovePlannerItineraryEntryIntent()
        removal.itinerary = fixture.itinerary
        removal.entry = fixture.entries[2]
        let _: Void = try await removal.callAsFunction(donate: false)
      } else {
        let reorder = ReorderPlannerItineraryEntryIntent()
        reorder.itinerary = fixture.itinerary
        reorder.entry = fixture.entries[2]
        reorder.position = .before
        reorder.relativeEntry = fixture.entries[0]
        let _: Void = try await reorder.callAsFunction(donate: false)
      }
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      let blocked = ReorderPlannerItineraryEntryIntent()
      blocked.itinerary = fixture.itinerary
      blocked.entry = fixture.entries[0]
      blocked.position = .last
      do {
        let _: Void = try await blocked.callAsFunction(donate: false)
        XCTFail("Incomplete recovery must block the next route change.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: fixture.configuration)
      let owner = PlannerEntityReference(kind: .itinerary, id: fixture.itinerary.id)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .source(.itinerary(let beforeRetry)) = await reopened.read(
          session: session, request: .source(owner))
      else { return XCTFail("The applied route must survive actual recovery failure.") }
      let route = beforeRetry.references.compactMap { reference -> UUID? in
        guard case .itineraryEntry(let identifier, _, _) = reference else { return nil }
        return identifier
      }
      if removingEntry {
        XCTAssertEqual(route, [fixture.entryIdentifiers[0], fixture.entryIdentifiers[1]])
      } else {
        XCTAssertEqual(
          route,
          [fixture.entryIdentifiers[2], fixture.entryIdentifiers[0], fixture.entryIdentifiers[1]])
      }
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: session, operationId: operationIdentifier),
        case .source(.itinerary(let afterRetry)) = await reopened.read(
          session: session, request: .source(owner))
      else { return XCTFail("Native retry must acknowledge the original route operation.") }
      XCTAssertEqual(afterRetry.references, beforeRetry.references)
      XCTAssertEqual(afterRetry.updatedAt, beforeRetry.updatedAt)
      let _: Void = try await blocked.callAsFunction(donate: false)
      XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
      XCTAssertFalse(fixture.store.isSaving)
    }
  }
}

private struct ItineraryEntryIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let list: PlannerEntityReference
  let itinerary: PlannerItineraryEntity
  let entries: [PlannerItineraryEntryEntity]
  let entryIdentifiers: [UUID]
}

@MainActor
private func makeItineraryEntryIntentFixture() async throws -> ItineraryEntryIntentFixture {
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
  let createdItem = try await save(.createItem(content: .init(title: "Hotel", notes: "Keep notes")))
  let item = try XCTUnwrap(createdItem.generated.first)
  let createdList = try await save(.createList(content: .init(name: "Empty stop")))
  let list = try XCTUnwrap(createdList.generated.first)
  let createdItinerary = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
  let owner = try XCTUnwrap(createdItinerary.generated.first)
  var entries: [PlannerItineraryEntryEntity] = []
  var identifiers: [UUID] = []
  for source in [item, list, item] {
    let created = try await save(
      .addItineraryEntry(itineraryId: owner.id, source: source, placement: .last))
    guard case .itineraryEntry(let identifier, _, _)? = created.generatedReferences.first else {
      throw CancellationError()
    }
    identifiers.append(identifier)
    entries.append(
      .init(
        id: "v1/entry/\(owner.id)/\(identifier)/\(source.kind.rawValue)/\(source.id)",
        title: "Cached", context: "Cached", kind: source.kind == .list ? .list : .item,
        archived: false))
  }
  _ = try await save(
    .setCompletion(
      scope: .appearance(.directItineraryItem(itineraryId: owner.id, entryId: identifiers[0])),
      done: true))
  return .init(
    configuration: configuration, store: store, planner: planner, session: session, item: item,
    list: list, itinerary: .init(id: owner.id, title: "Cached route", archived: false),
    entries: entries, entryIdentifiers: identifiers)
}
