import Foundation
import PlannerCore
import Testing

struct CalendarWindowQueryTests {
  @Test func emptyCalendarWindowHasAReadableEmptyPage() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .calendar(
            .init(
              startDay: .init(year: 2026, month: 10, day: 9),
              endDay: .init(year: 2026, month: 10, day: 11),
              displayTimeZone: "Asia/Tokyo"))))
    else { throw CancellationError() }
    #expect(snapshot.session == session)
    #expect(snapshot.matchingCount == 0 && snapshot.rows.isEmpty)
    #expect(snapshot.rowPresentation == nil && snapshot.progress.isEmpty)
    #expect(snapshot.unresolvedReferences.isEmpty)
    guard
      case .calendarRows(let page) = await planner.read(
        session: session,
        request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
    else { throw CancellationError() }
    #expect(page.generation == snapshot.generation && page.offset == 0)
    #expect(page.matchingCount == 0 && page.rows.isEmpty)
  }

  @Test func timedWindowIncludesOverlapsAndStartOnlyEntriesAtExactBoundaries() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    let item = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    _ = try await save(.setArchive(source: itinerary, archived: true))
    func instant(_ value: String) throws -> Date {
      try #require(ISO8601DateFormatter().date(from: value))
    }
    let examples: [(start: String, end: String?, matches: Bool)] = [
      ("2026-10-08T15:00:00Z", nil, true),
      ("2026-10-11T14:59:59Z", nil, true),
      ("2026-10-08T14:59:59Z", nil, false),
      ("2026-10-11T15:00:00Z", nil, false),
      ("2026-10-08T14:00:00Z", "2026-10-08T15:00:00Z", false),
      ("2026-10-08T14:00:00Z", "2026-10-08T15:00:01Z", true),
      ("2026-10-11T14:59:59Z", "2026-10-11T16:00:00Z", true),
      ("2026-10-11T15:00:00Z", "2026-10-11T16:00:00Z", false),
      ("2026-10-01T00:00:00Z", "2026-10-20T00:00:00Z", true),
    ]
    var expected:
      [(schedule: PlannerEntityReference, owner: PlannerEntityReference, form: PlannerScheduleForm)] =
        []
    for (index, example) in examples.enumerated() {
      let owner = index.isMultiple(of: 2) ? item : itinerary
      let form = PlannerScheduleForm.timed(
        start: try instant(example.start), end: try example.end.map(instant),
        planningTimeZone: "Europe/Paris")
      let schedule = try #require(
        try await save(.createSchedule(source: owner, form: form)).generated.first)
      if example.matches { expected.append((schedule, owner, form)) }
    }
    expected.sort { $0.schedule.id.uuidString < $1.schedule.id.uuidString }
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .calendar(
            .init(
              startDay: .init(year: 2026, month: 10, day: 9),
              endDay: .init(year: 2026, month: 10, day: 11),
              displayTimeZone: "Asia/Tokyo")))),
      case .calendarRows(let page) = await planner.read(
        session: session,
        request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
    else { throw CancellationError() }
    #expect(snapshot.matchingCount == 5)
    #expect(snapshot.rows == expected.map { .source($0.schedule) })
    #expect(page.rows.map(\.schedule) == expected.map(\.schedule))
    #expect(page.rows.map(\.source) == expected.map(\.owner))
    #expect(page.rows.map(\.form) == expected.map(\.form))
    #expect(page.rows.map(\.title) == expected.map { $0.owner == item ? "Museum" : "Weekend" })
  }
  @Test(arguments: ["Asia/Tokyo", "Europe/Paris"])
  func allDayWindowUsesInclusiveCivilDatesAcrossDisplayZones(displayTimeZone: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let examples: [(start: Int, end: Int?, matches: Bool)] = [
      (9, nil, true), (11, nil, true), (8, nil, false), (12, nil, false),
      (8, 9, true), (11, 12, true), (8, 12, true), (6, 8, false), (12, 13, false),
    ]
    var expected: [(schedule: PlannerEntityReference, form: PlannerScheduleForm)] = []
    for example in examples {
      let form = PlannerScheduleForm.allDay(
        start: .init(year: 2026, month: 10, day: example.start),
        end: example.end.map { .init(year: 2026, month: 10, day: $0) })
      let schedule = try #require(
        try await save(.createSchedule(source: itinerary, form: form)).generated.first)
      if example.matches { expected.append((schedule, form)) }
    }
    expected.sort { $0.schedule.id.uuidString < $1.schedule.id.uuidString }
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .calendar(
            .init(
              startDay: .init(year: 2026, month: 10, day: 9),
              endDay: .init(year: 2026, month: 10, day: 11),
              displayTimeZone: displayTimeZone)))),
      case .calendarRows(let page) = await planner.read(
        session: session,
        request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
    else { throw CancellationError() }
    #expect(snapshot.matchingCount == 5)
    #expect(snapshot.rows == expected.map { .source($0.schedule) })
    #expect(page.rows.map(\.schedule) == expected.map(\.schedule))
    #expect(page.rows.map(\.form) == expected.map(\.form))
    #expect(page.rows.allSatisfy { $0.source == itinerary && $0.title == "Weekend" })
  }
}
