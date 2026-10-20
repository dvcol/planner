import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerContainerFindIntentTests: XCTestCase {
  func testContainerFindsReadAppliedChangesWithoutAcknowledgingIncompleteRecovery() async throws {
    for kind in [PlannerEntityKind.list, .itinerary] {
      let fixture = try await makeContainerFindSortFixture(kind: kind)
      let source = fixture.containers[0]
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      if kind == .list {
        let edit = EditPlannerListIntent()
        edit.list = .init(id: source.id, name: "Cached title", archived: false)
        edit.name = "Recovery searchable Plan"
        edit.notes = "Applied recovery notes"
        let _: Void = try await edit.callAsFunction(donate: false)
      } else {
        let edit = EditPlannerItineraryIntent()
        edit.itinerary = .init(id: source.id, title: "Cached title", archived: false)
        edit.title = "Recovery searchable Plan"
        edit.notes = "Applied recovery notes"
        let _: Void = try await edit.callAsFunction(donate: false)
      }
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      let before = await fixture.planner.read(session: fixture.session, request: .source(source))
      func findIdentifiers() async throws -> [UUID] {
        if kind == .list {
          let find = FindPlannerListsIntent()
          find.text = "Recovery searchable"
          let matches: [PlannerListEntity] = try await find.callAsFunction(donate: false)
          XCTAssertEqual(matches.first?.name, "Recovery searchable Plan")
          return matches.map(\.id)
        }
        let find = FindPlannerItinerariesIntent()
        find.text = "Recovery searchable"
        let matches: [PlannerItineraryEntity] = try await find.callAsFunction(donate: false)
        XCTAssertEqual(matches.first?.title, "Recovery searchable Plan")
        return matches.map(\.id)
      }
      let matches = try await findIdentifiers()
      XCTAssertEqual(matches, [source.id])
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
      XCTAssertTrue(fixture.store.recoveryBlocked)
      let after = await fixture.planner.read(session: fixture.session, request: .source(source))
      switch (before, after) {
      case (.source(.list(let initial)), .source(.list(let current))):
        XCTAssertEqual(current.content.notes, "Applied recovery notes")
        XCTAssertEqual(current.fieldHashes, initial.fieldHashes)
        XCTAssertEqual(current.references, initial.references)
        XCTAssertEqual(current.createdAt, initial.createdAt)
        XCTAssertEqual(current.updatedAt, initial.updatedAt)
        XCTAssertEqual(current.state.archived, initial.state.archived)
      case (.source(.itinerary(let initial)), .source(.itinerary(let current))):
        XCTAssertEqual(current.content.notes, "Applied recovery notes")
        XCTAssertEqual(current.fieldHashes, initial.fieldHashes)
        XCTAssertEqual(current.references, initial.references)
        XCTAssertEqual(current.createdAt, initial.createdAt)
        XCTAssertEqual(current.updatedAt, initial.updatedAt)
        XCTAssertEqual(current.state.archived, initial.state.archived)
      default: XCTFail("The applied source must remain readable during recovery failure.")
      }
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      guard
        case .appliedRecoveryIncomplete = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { return XCTFail("A native Find cannot acknowledge an incomplete saved edit.") }
      await fixture.store.retryIncompleteRecovery()
      guard
        case .appliedRecoveryComplete = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { return XCTFail("Explicit recovery must acknowledge only the original edit.") }
      let recovered = try await findIdentifiers()
      XCTAssertEqual(recovered, matches)
      XCTAssertFalse(fixture.store.recoveryBlocked)
    }
  }

  func testBothContainerFindsReadEveryPageAndRefreshAfterAnotherWriter() async throws {
    for kind in [PlannerEntityKind.list, .itinerary] {
      let (_, configuration, store) = try makePlannerIntentStorage()
      AppDependencyManager.shared.add(dependency: store)
      let planner = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
      var containers: [PlannerEntityReference] = []
      for containerIndex in 0..<65 {
        let title = String(format: "Plan %02d", containerIndex)
        let command: PlannerCommand
        if kind == .list {
          command = .createList(content: .init(name: title))
        } else {
          command = .createItinerary(content: .init(title: title))
        }
        guard
          case .applied(let saved, .complete) = await planner.execute(
            .init(operationId: UUID(), session: session, command: command)
          ).outcome
        else { return XCTFail("Save every plan before the multi-page native query.") }
        containers.append(try XCTUnwrap(saved.generated.first(where: { $0.kind == kind })))
      }
      let lists = FindPlannerListsIntent()
      lists.text = "PLAN"
      lists.direction = .descending
      let itineraries = FindPlannerItinerariesIntent()
      itineraries.text = "PLAN"
      itineraries.direction = .descending
      func readMatches() async throws -> [(identifier: UUID, title: String, archived: Bool)] {
        if kind == .list {
          let result: [PlannerListEntity] = try await lists.callAsFunction(donate: false)
          return result.map { ($0.id, $0.name, $0.archived) }
        }
        let result: [PlannerItineraryEntity] = try await itineraries.callAsFunction(donate: false)
        return result.map { ($0.id, $0.title, $0.archived) }
      }
      guard case .exported(let before) = await planner.exportData(session: session) else {
        return XCTFail("Record all 65 plans before paged native finding.")
      }
      let matches = try await readMatches()
      XCTAssertEqual(matches.count, 65)
      XCTAssertEqual(matches.map(\.identifier), containers.reversed().map(\.id))
      XCTAssertEqual(Set(matches.map(\.identifier)).count, 65)
      XCTAssertEqual(matches.first?.title, "Plan 64")
      XCTAssertEqual(matches.last?.title, "Plan 00")
      guard case .exported(let unchanged) = await planner.exportData(session: session) else {
        return XCTFail("Paged finding cannot mutate the saved plans.")
      }
      XCTAssertEqual(unchanged, before)
      let writer = PlannerCore.Planner(configuration: configuration)
      let movedTitle = containers[32]
      guard case .ready(let writerSession) = await writer.bootstrap() else {
        throw CancellationError()
      }
      let rename: PlannerCommand
      switch await writer.read(session: writerSession, request: .source(movedTitle)) {
      case .source(.list(let current)):
        rename = .editList(
          sourceId: movedTitle.id, changes: .init(name: .set("A changed Plan")),
          expectedFieldHashes: current.fieldHashes)
      case .source(.itinerary(let current)):
        rename = .editItinerary(
          sourceId: movedTitle.id, changes: .init(title: .set("A changed Plan")),
          expectedFieldHashes: current.fieldHashes)
      default: throw CancellationError()
      }
      guard
        case .applied(_, .complete) = await writer.execute(
          .init(operationId: UUID(), session: writerSession, command: rename)
        ).outcome,
        case .applied(_, .complete) = await writer.execute(
          .init(
            operationId: UUID(), session: writerSession,
            command: .setArchive(source: containers[0], archived: true))
        ).outcome,
        case .exported(let changed) = await writer.exportData(session: writerSession)
      else { return XCTFail("The second writer must save the rename and archive.") }
      let expected =
        containers.reversed().filter { $0.id != movedTitle.id }.map(\.id) + [movedTitle.id]
      let refreshed = try await readMatches()
      XCTAssertEqual(refreshed.map(\.identifier), expected)
      XCTAssertEqual(refreshed.last?.title, "A changed Plan")
      XCTAssertEqual(refreshed.first(where: { $0.identifier == containers[0].id })?.archived, true)
      lists.archive = .active
      itineraries.archive = .active
      let active = try await readMatches()
      XCTAssertEqual(active.count, 64)
      XCTAssertEqual(active.map(\.identifier), expected.filter { $0 != containers[0].id })
      guard case .exported(let after) = await writer.exportData(session: writerSession) else {
        return XCTFail("Refreshed native reads cannot rewrite the second writer's changes.")
      }
      XCTAssertEqual(after, changed)
    }
  }

  func testPrecancelledEmptyContainerFindsThrowWithoutChangingData() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session)
    else { return XCTFail("Record the empty saved dataset before cancelled queries.") }
    await store.open()
    let lists = FindPlannerListsIntent()
    let itineraries = FindPlannerItinerariesIntent()
    let invocations: [@MainActor () async throws -> Void] = [
      { let _: [PlannerListEntity] = try await lists.callAsFunction(donate: false) },
      { let _: [PlannerItineraryEntity] = try await itineraries.callAsFunction(donate: false) },
    ]
    for invocation in invocations {
      let request = Task { @MainActor in try await invocation() }
      request.cancel()
      do {
        try await request.value
        XCTFail("Precancelled native Finds cannot report successful empty results.")
      } catch is CancellationError {
      } catch { XCTFail("Expected cancellation, received \(error).") }
    }
    let emptyLists: [PlannerListEntity] = try await lists.callAsFunction(donate: false)
    let emptyItineraries: [PlannerItineraryEntity] = try await itineraries.callAsFunction(
      donate: false)
    XCTAssertTrue(emptyLists.isEmpty)
    XCTAssertTrue(emptyItineraries.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      return XCTFail("Cancellation cannot alter the empty dataset.")
    }
    XCTAssertEqual(after, before)
    XCTAssertFalse(store.isSaving)
  }

  func testUnavailableStorageThrowsForBothFindActionsRatherThanReturningNoMatches() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let contents = Data("Keep container query storage unavailable.".utf8)
    try contents.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let lists = FindPlannerListsIntent()
    lists.text = "No matching List"
    let itineraries = FindPlannerItinerariesIntent()
    itineraries.text = "No matching Itinerary"
    let invocations: [@MainActor () async throws -> Void] = [
      { let _: [PlannerListEntity] = try await lists.callAsFunction(donate: false) },
      { let _: [PlannerItineraryEntity] = try await itineraries.callAsFunction(donate: false) },
    ]
    for invocation in invocations {
      do {
        try await invocation()
        XCTFail("Unavailable storage cannot become a successful empty catalog.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testItineraryFindingCombinesFiltersAndEverySortWithoutChangingRoutesOrBookings() async throws
  {
    let fixture = try await makeContainerFindSortFixture(kind: .itinerary)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record Itinerary routes, completion and bookings before finding.") }
    let find = FindPlannerItinerariesIntent()
    let defaults: [PlannerItineraryEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(defaults.map(\.id), [4, 0, 6, 2, 3, 5, 1].map { fixture.containers[$0].id })
    let cases: [(PlannerCatalogFindSort, PlannerCatalogFindDirection, [Int])] = [
      (.title, .ascending, [4, 0, 6, 2, 3, 5, 1]),
      (.title, .descending, [1, 5, 3, 2, 6, 0, 4]),
      (.created, .ascending, [0, 1, 2, 3, 4, 5, 6]),
      (.created, .descending, [6, 5, 4, 3, 2, 1, 0]),
      (.lastUpdated, .ascending, [1, 2, 3, 4, 5, 6, 0]),
      (.lastUpdated, .descending, [0, 6, 5, 4, 3, 2, 1]),
      (.fullEstimate, .ascending, [4, 2, 6, 0, 1, 5, 3]),
      (.fullEstimate, .descending, [0, 6, 2, 4, 5, 1, 3]),
    ]
    for (mode, direction, positions) in cases {
      find.sort = mode
      find.direction = direction
      let matches: [PlannerItineraryEntity] = try await find.callAsFunction(donate: false)
      XCTAssertEqual(matches.map(\.id), positions.map { fixture.containers[$0].id })
    }
    guard
      case .exported(let afterSorts) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Catalog sorting must retain the saved Itinerary graph.") }
    XCTAssertEqual(afterSorts, before)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setArchive(source: fixture.containers[1], archived: true))
      ).outcome,
      case .exported(let beforeFilters) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Archive one partial plan before cumulative filter reads.") }
    find.sort = .fullEstimate
    find.direction = .ascending
    find.text = "PARTIAL"
    let partial: [PlannerItineraryEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(partial.map(\.id), [1, 5].map { fixture.containers[$0].id })
    find.archive = .active
    let active: [PlannerItineraryEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(active.map(\.id), [fixture.containers[5].id])
    find.archive = .archived
    let archived: [PlannerItineraryEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(archived.map(\.id), [fixture.containers[1].id])
    XCTAssertEqual(archived.first?.archived, true)
    find.text = "No matching Itinerary"
    let empty: [PlannerItineraryEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
    guard
      case .exported(let afterFilters) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cumulative filters must retain source state and bookings.") }
    XCTAssertEqual(afterFilters, beforeFilters)
  }

  func testListSortingUsesEveryModeAndRetainsEstimateGroupsAndSavedGraph() async throws {
    let fixture = try await makeContainerFindSortFixture(kind: .list)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the complete saved graph before sorting Lists.") }
    let find = FindPlannerListsIntent()
    let cases: [(PlannerCatalogFindSort, PlannerCatalogFindDirection, [Int])] = [
      (.title, .ascending, [4, 0, 6, 2, 3, 5, 1]),
      (.title, .descending, [1, 5, 3, 2, 6, 0, 4]),
      (.created, .ascending, [0, 1, 2, 3, 4, 5, 6]),
      (.created, .descending, [6, 5, 4, 3, 2, 1, 0]),
      (.lastUpdated, .ascending, [1, 2, 3, 4, 5, 6, 0]),
      (.lastUpdated, .descending, [0, 6, 5, 4, 3, 2, 1]),
      (.fullEstimate, .ascending, [4, 2, 6, 0, 1, 5, 3]),
      (.fullEstimate, .descending, [0, 6, 2, 4, 5, 1, 3]),
    ]
    for (mode, direction, positions) in cases {
      find.sort = mode
      find.direction = direction
      let matches: [PlannerListEntity] = try await find.callAsFunction(donate: false)
      XCTAssertEqual(matches.map(\.id), positions.map { fixture.containers[$0].id })
    }
    find.sort = .fullEstimate
    find.direction = .ascending
    find.text = "PARTIAL"
    let partial: [PlannerListEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(partial.map(\.id), [1, 5].map { fixture.containers[$0].id })
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Sorted List finding must preserve all saved source and context data.") }
    XCTAssertEqual(after, before)
  }

  func testListFindingCombinesTextAndArchiveWithoutChangingSavedData() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let create = CreatePlannerListIntent()
    var lists: [PlannerListEntity] = []
    for name in ["Café Tokyo", "Market Tokyo", "Cafe Osaka"] {
      create.name = name
      create.notes = "Saved notes"
      lists.append(try await create.callAsFunction(donate: false))
    }
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: .init(kind: .list, id: lists[1].id), archived: true))
      )
      .outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { return XCTFail("Seed and record the real Lists before native finding.") }
    let find = FindPlannerListsIntent()
    let all: [PlannerListEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(all.map(\.id), [2, 0, 1].map { lists[$0].id })
    find.text = "TOKYO"
    let tokyo: [PlannerListEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(tokyo.map(\.id), [0, 1].map { lists[$0].id })
    find.archive = .active
    let active: [PlannerListEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(active.map(\.id), [lists[0].id])
    find.archive = .archived
    let archived: [PlannerListEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(archived.map(\.id), [lists[1].id])
    XCTAssertEqual(archived.first?.archived, true)
    find.archive = .all
    find.text = "cAfE"
    let folded: [PlannerListEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(folded.map(\.id), [2, 0].map { lists[$0].id })
    find.text = "No matching List"
    let empty: [PlannerListEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      return XCTFail("Finding cannot change saved Lists or their references.")
    }
    XCTAssertEqual(after, before)
    XCTAssertFalse(store.isSaving)
  }
}

private struct ContainerFindSortFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let containers: [PlannerEntityReference]
}

@MainActor
private func makeContainerFindSortFixture(kind: PlannerEntityKind) async throws
  -> ContainerFindSortFixture
{
  let (_, configuration, store) = try makePlannerIntentStorage()
  AppDependencyManager.shared.add(dependency: store)
  let planner = PlannerCore.Planner(configuration: configuration)
  guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
  func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    guard
      case .applied(let saved, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return saved
  }
  var items: [PlannerEntityReference] = []
  let inputs: [(String, Int64?)] = [
    ("Museum", 180), ("Short", 120), ("Medium", 240), ("Long", 300),
    ("Missing", nil), ("Maximum", Int64.max), ("One", 1),
  ]
  for (title, minutes) in inputs {
    let saved = try await save(
      .createItem(
        content: .init(
          title: title, estimate: minutes.map { .init(minutes: $0, displayUnit: .minute) })))
    items.append(try XCTUnwrap(saved.generated.first(where: { $0.kind == .item })))
  }
  _ = try await save(.setCompletion(scope: .globalItem(itemId: items[0].id), done: true))
  _ = try await save(.setArchive(source: items[3], archived: true))
  _ = try await save(
    .createSchedule(
      source: items[0],
      form: .timed(
        start: Date(timeIntervalSinceReferenceDate: 813_000_000), end: nil,
        planningTimeZone: "Asia/Tokyo")))
  let plans: [(String, Int64?, [Int])] = [
    ("Long", nil, [3]), ("Partial short", nil, [1, 4]), ("Museum", nil, [0]),
    ("Overflow", nil, [5, 6]), ("Empty", nil, []), ("Partial long", nil, [2, 4]),
    ("Manual", 240, [4, 1]),
  ]
  var containers: [PlannerEntityReference] = []
  for (title, manualMinutes, children) in plans {
    let manualEstimate = manualMinutes.map { PlannerEstimate(minutes: $0, displayUnit: .hour) }
    let command: PlannerCommand
    switch kind {
    case .list: command = .createList(content: .init(name: title, manualEstimate: manualEstimate))
    case .itinerary:
      command = .createItinerary(content: .init(title: title, manualEstimate: manualEstimate))
    default: throw CancellationError()
    }
    let saved = try await save(command)
    let container = try XCTUnwrap(saved.generated.first(where: { $0.kind == kind }))
    containers.append(container)
    for childIndex in children {
      let appearance: PlannerAppearance
      if kind == .list {
        let addition = try await save(
          .addMembership(itemId: items[childIndex].id, listId: container.id, placement: .last))
        guard case .membership(let identifier, _, _)? = addition.generatedReferences.first else {
          throw CancellationError()
        }
        appearance = .listMembership(listId: container.id, membershipId: identifier)
      } else {
        let addition = try await save(
          .addItineraryEntry(itineraryId: container.id, source: items[childIndex], placement: .last)
        )
        guard case .itineraryEntry(let identifier, _, _)? = addition.generatedReferences.first
        else {
          throw CancellationError()
        }
        appearance = .directItineraryItem(itineraryId: container.id, entryId: identifier)
      }
      if title == "Partial short", childIndex == 1 {
        _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
      }
    }
  }
  if kind == .itinerary {
    _ = try await save(
      .createSchedule(
        source: containers[2],
        form: .allDay(
          start: .init(year: 2026, month: 10, day: 9),
          end: .init(year: 2026, month: 10, day: 11))))
  }
  let first = try XCTUnwrap(containers.first)
  switch await planner.read(session: session, request: .source(first)) {
  case .source(.list(let current)):
    _ = try await save(
      .editList(
        sourceId: first.id, changes: .init(notes: .set("Last edited")),
        expectedFieldHashes: current.fieldHashes))
  case .source(.itinerary(let current)):
    _ = try await save(
      .editItinerary(
        sourceId: first.id, changes: .init(notes: .set("Last edited")),
        expectedFieldHashes: current.fieldHashes))
  default: throw CancellationError()
  }
  return .init(
    configuration: configuration, store: store, planner: planner, session: session,
    containers: containers)
}
