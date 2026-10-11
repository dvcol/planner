import Foundation
import PlannerCore
import Testing

struct ItemSchedulingQueryTests {
  @Test func schedulingFiltersUseAnyRetainedAssignmentAndKeepFullContextualProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    var items: [PlannerEntityReference] = []
    for title in ["A Appointment", "B Direct plan", "C Live list", "D Unplanned"] {
      items.append(
        try #require(try await save(.createItem(content: .init(title: title))).generated.first))
    }
    let list = try #require(
      try await save(.createList(content: .init(name: "Stops"))).generated.first)
    let liveList = try #require(
      try await save(.createList(content: .init(name: "Live route"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Past trip"))).generated.first)
    let reviewPlan = try #require(
      try await save(.createItinerary(content: .init(title: "Unscheduled review"))).generated.first)
    var memberships: [PlannerAppearance] = []
    for item in items {
      guard
        case .membership(let identifier, _, _)? = try await save(
          .addMembership(itemId: item.id, listId: list.id, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      memberships.append(.listMembership(listId: list.id, membershipId: identifier))
      _ = try await save(
        .addItineraryEntry(itineraryId: reviewPlan.id, source: item, placement: .last))
    }
    _ = try await save(.addMembership(itemId: items[2].id, listId: liveList.id, placement: .last))
    for source in [items[1], liveList] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    let past = PlannerScheduleForm.allDay(start: .init(year: 2020, month: 1, day: 1), end: nil)
    _ = try await save(.createSchedule(source: items[0], form: past))
    _ = try await save(.createSchedule(source: itinerary, form: past))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    _ = try await save(.setArchive(source: liveList, archived: true))
    _ = try await save(.setArchive(source: items[2], archived: true))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: items[0].id), done: true))
    _ = try await save(.setCompletion(scope: .appearance(memberships[2]), done: true))
    let examples: [(PlannerItemQuery, [Int])] = [
      (.init(completion: .all, archive: .all), [0, 1, 2, 3]),
      (.init(completion: .all, archive: .all, scheduled: .scheduled), [0, 1, 2]),
      (.init(completion: .all, archive: .all, scheduled: .unscheduled), [3]),
      (.init(scheduled: .scheduled), [1]),
      (.init(completion: .done, scheduled: .scheduled), [0]),
      (.init(text: "Live", completion: .all, archive: .archived, scheduled: .scheduled), [2]),
      (
        .init(
          scope: .list(list.id), completion: .all, archive: .all, scheduled: .scheduled,
          sort: .init(mode: .manual)), [0, 1, 2]
      ),
      (
        .init(scope: .list(list.id), completion: .done, archive: .all, scheduled: .scheduled),
        [0, 2]
      ),
      (.init(scope: .list(list.id), completion: .all, archive: .all, scheduled: .unscheduled), [3]),
      (
        .init(
          scope: .itinerary(reviewPlan.id), completion: .all, archive: .all, scheduled: .scheduled),
        [0, 1, 2]
      ),
      (
        .init(
          scope: .itinerary(reviewPlan.id), completion: .all, archive: .all, scheduled: .unscheduled
        ), [3]
      ),
    ]
    for (query, expectedIndices) in examples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(session: session, request: .items(query))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 2))
      else { throw CancellationError() }
      let expected = expectedIndices.map { items[$0].id }
      let actual = snapshot.rows.map { identity in
        switch identity {
        case .source(let source), .appearance(let source, _): return source.id
        }
      }
      #expect(actual == expected)
      let windowIdentifiers = window.rows.map { row in
        switch row.identity {
        case .source(let source), .appearance(let source, _): return source.id
        }
      }
      #expect(windowIdentifiers == Array(expected.prefix(2)))
      switch query.scope {
      case .list:
        #expect(snapshot.progress.first?.doneCount == 2)
        #expect(snapshot.progress.first?.totalCount == 4)
      case .itinerary:
        #expect(snapshot.progress.first?.doneCount == 1)
        #expect(snapshot.progress.first?.totalCount == 4)
      default: break
      }
    }
  }
  @Test func schedulingRefreshTracksEverySurvivingPathWithoutTurningInboxIntoUnscheduled()
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
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let plain = try #require(
      try await save(.createItem(content: .init(title: "Plain"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Trip"))).generated.first)
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: hotel, placement: .last))
    func query(_ scope: PlannerItemQuery.Scope, _ scheduled: PlannerItemQuery.Scheduling)
      async throws -> PlannerQuerySnapshot
    {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(session: session, request: .items(.init(scope: scope, scheduled: scheduled))))
      else { throw CancellationError() }
      return snapshot
    }
    let original = try await query(.inbox, .unscheduled)
    #expect(original.rows == [.source(hotel), .source(plain)])
    let form = PlannerScheduleForm.allDay(start: .init(year: 2020, month: 1, day: 1), end: nil)
    let inherited = try #require(
      try await save(.createSchedule(source: itinerary, form: form)).generated.first)
    #expect(try await query(.inbox, .scheduled).rows == [.source(hotel)])
    #expect(try await query(.inbox, .unscheduled).rows == [.source(plain)])
    guard
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: original.generation, offset: 0, limit: 2))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    let direct = try #require(
      try await save(.createSchedule(source: hotel, form: form)).generated.first)
    _ = try await save(.removeSchedule(scheduleId: inherited.id))
    #expect(try await query(.global, .scheduled).rows == [.source(hotel)])
    _ = try await save(.removeSchedule(scheduleId: direct.id))
    #expect(try await query(.global, .scheduled).rows.isEmpty)
    #expect(try await query(.inbox, .unscheduled).rows == [.source(hotel), .source(plain)])
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: hotel.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    _ = try await save(.createSchedule(source: itinerary, form: form))
    #expect(try await query(.inbox, .all).rows == [.source(plain)])
    #expect(try await query(.global, .scheduled).rows == [.source(hotel)])
    _ = try await save(.removeMembership(listId: list.id, membershipId: membershipId))
    #expect(try await query(.inbox, .scheduled).rows == [.source(hotel)])
    let directEntries = await planner.read(session: session, request: .source(itinerary))
    guard case .source(.itinerary(let owner)) = directEntries,
      case .itineraryEntry(let entryId, _, _)? = owner.references.first
    else { throw CancellationError() }
    _ = try await save(.removeItineraryEntry(itineraryId: itinerary.id, entryId: entryId))
    #expect(try await query(.global, .unscheduled).rows == [.source(hotel), .source(plain)])
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let retained) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(scheduled: .unscheduled))))
    else { throw CancellationError() }
    #expect(retained.rows == [.source(hotel), .source(plain)])
  }
}
