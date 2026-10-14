import Foundation
import PlannerCore
import Testing

struct CalendarWindowTimeZoneTests {
  @Test func aMidnightClockChangeDoesNotExtendTheWindowIntoTheFollowingDay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Meeting")))
      ).outcome,
      let item = creation.generated.first
    else { throw CancellationError() }
    var schedules: [PlannerEntityReference] = []
    for instant in ["2018-11-05T01:59:59Z", "2018-11-05T02:30:00Z"] {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createSchedule(
              source: item,
              form: .timed(
                start: try #require(ISO8601DateFormatter().date(from: instant)), end: nil,
                planningTimeZone: "America/Sao_Paulo")))
        ).outcome,
        let schedule = creation.generated.first
      else { throw CancellationError() }
      schedules.append(schedule)
    }
    let day = PlannerCivilDate(year: 2018, month: 11, day: 4)
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .calendar(
            .init(startDay: day, endDay: day, displayTimeZone: "America/Sao_Paulo")))),
      case .calendarRows(let page) = await planner.read(
        session: session,
        request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
    else { throw CancellationError() }
    #expect(snapshot.matchingCount == 1)
    #expect(page.rows.map(\.schedule) == [schedules[0]])
  }

  @Test func aSkippedLocalDayCannotSilentlyQueryTheFollowingDay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let skippedDay = PlannerCivilDate(year: 2011, month: 12, day: 30)
    guard
      case .failed(let failure) = await planner.query(
        .init(
          session: session,
          request: .calendar(
            .init(startDay: skippedDay, endDay: skippedDay, displayTimeZone: "Pacific/Apia"))))
    else {
      Issue.record("An unavailable local day must fail instead of being normalized to December 31.")
      return
    }
    #expect(failure.code == "invalidInput" && failure.propertyPath == "/query/startDay")
  }

  @Test func daylightSavingDaysUseTheirRealBoundariesAndRetainBothRepeatedClockTimes() async throws
  {
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
      try await save(.createItem(content: .init(title: "Meeting"))).generated.first)
    let examples: [(day: PlannerCivilDate, instants: [(String, Bool)], count: Int64)] = [
      (
        .init(year: 2026, month: 3, day: 8),
        [
          ("2026-03-08T04:59:59Z", false), ("2026-03-08T05:00:00Z", true),
          ("2026-03-09T03:59:59Z", true), ("2026-03-09T04:00:00Z", false),
        ], 2
      ),
      (
        .init(year: 2026, month: 11, day: 1),
        [
          ("2026-11-01T03:59:59Z", false), ("2026-11-01T04:00:00Z", true),
          ("2026-11-01T05:30:00Z", true), ("2026-11-01T06:30:00Z", true),
          ("2026-11-02T04:59:59Z", true), ("2026-11-02T05:00:00Z", false),
        ], 4
      ),
    ]
    for example in examples {
      var expected: [(schedule: PlannerEntityReference, form: PlannerScheduleForm)] = []
      for (value, matches) in example.instants {
        let start = try #require(ISO8601DateFormatter().date(from: value))
        let form = PlannerScheduleForm.timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")
        let schedule = try #require(
          try await save(.createSchedule(source: item, form: form)).generated.first)
        if matches { expected.append((schedule, form)) }
      }
      expected.sort { $0.schedule.id.uuidString < $1.schedule.id.uuidString }
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .calendar(
              .init(startDay: example.day, endDay: example.day, displayTimeZone: "America/New_York")
            ))),
        case .calendarRows(let page) = await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
      else { throw CancellationError() }
      #expect(snapshot.matchingCount == example.count)
      #expect(snapshot.rows == expected.map { .source($0.schedule) })
      #expect(page.rows.map(\.schedule) == expected.map(\.schedule))
      #expect(page.rows.map(\.form) == expected.map(\.form))
    }
  }
  @Test func travelChangesTimedBucketingWithoutMovingAllDayDatesOrFillingMissingEnds() async throws
  {
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
      try await save(
        .createItem(
          content: .init(title: "Meeting", estimate: .init(minutes: 120, displayUnit: .hour)))
      )
      .generated.first)
    let forms: [PlannerScheduleForm] = [
      .timed(
        start: try #require(ISO8601DateFormatter().date(from: "2026-10-08T15:00:00Z")),
        end: nil, planningTimeZone: "Asia/Tokyo"),
      .timed(
        start: try #require(ISO8601DateFormatter().date(from: "2026-10-08T14:30:00Z")),
        end: nil, planningTimeZone: "Asia/Tokyo"),
      .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)),
    ]
    var schedules: [PlannerEntityReference] = []
    for form in forms {
      schedules.append(
        try #require(try await save(.createSchedule(source: item, form: form)).generated.first))
    }
    for (zone, day, indices) in [
      ("Asia/Tokyo", 9, [0, 2]), ("Europe/Paris", 9, [2]),
      ("Europe/Paris", 8, [0, 1]), ("Asia/Tokyo", 8, [1]),
    ] {
      let date = PlannerCivilDate(year: 2026, month: 10, day: day)
      let expected = indices.map { schedules[$0] }.sorted { $0.id.uuidString < $1.id.uuidString }
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .calendar(.init(startDay: date, endDay: date, displayTimeZone: zone)))),
        case .calendarRows(let page) = await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
      else { throw CancellationError() }
      #expect(snapshot.matchingCount == Int64(indices.count))
      #expect(page.rows.map(\.schedule) == expected)
      for entry in page.rows {
        let index = try #require(schedules.firstIndex(of: entry.schedule))
        #expect(entry.form == forms[index])
      }
    }
    for (schedule, form) in zip(schedules, forms) {
      guard
        case .source(.schedule(let retained)) = await planner.read(
          session: session, request: .source(schedule))
      else { throw CancellationError() }
      #expect(retained.content.form == form)
    }
  }
}
