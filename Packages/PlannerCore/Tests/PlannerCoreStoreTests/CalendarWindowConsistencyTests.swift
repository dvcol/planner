import Foundation
import PlannerCore
import SQLite3
import Testing

struct CalendarWindowConsistencyTests {
  @Test func duplicateScheduleIdentitiesOutsideTheWindowRejectTheWholeCalendarRead() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum")))
      ).outcome,
      let item = creation.generated.first
    else { throw CancellationError() }
    for day in [9, 10] {
      guard
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createSchedule(
              source: item,
              form: .allDay(start: .init(year: 2026, month: 10, day: day), end: nil)))
        ).outcome
      else { throw CancellationError() }
    }
    /// Create malformed native input at the storage I/O boundary; assertions use public reads.
    var database: OpaquePointer?
    try #require(sqlite3_open(configuration.storeURL.path, &database) == SQLITE_OK)
    defer { sqlite3_close(database) }
    try #require(
      sqlite3_exec(
        database, "UPDATE ZSCHEDULE SET ZID = (SELECT ZID FROM ZSCHEDULE LIMIT 1);", nil, nil, nil)
        == SQLITE_OK)
    let reader = Planner(configuration: configuration)
    guard case .ready(let readSession) = await reader.bootstrap() else { throw CancellationError() }
    let day = PlannerCivilDate(year: 2026, month: 10, day: 9)
    let response = await reader.query(
      .init(
        session: readSession,
        request: .calendar(.init(startDay: day, endDay: day, displayTimeZone: "Asia/Tokyo"))))
    guard case .failed(let failure) = response else {
      Issue.record("Reject duplicate identities across retained dates: \(response)")
      return
    }
    #expect(failure.code == "readUnavailable")
  }

  @Test func pagesAndRejectedWindowsPreserveTheCompleteSavedCalendar() async throws {
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
    var schedules: [PlannerEntityReference] = []
    for _ in 0..<3 {
      schedules.append(
        try #require(
          try await save(
            .createSchedule(
              source: item, form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil))
          )
          .generated.first))
    }
    let day = PlannerCivilDate(year: 2026, month: 10, day: 9)
    guard case .exported(let before) = await planner.exportData(session: session),
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .calendar(.init(startDay: day, endDay: day, displayTimeZone: "Asia/Tokyo"))))
    else { throw CancellationError() }
    let expected = schedules.sorted { $0.id.uuidString < $1.id.uuidString }
    #expect(snapshot.rows == expected.map(PlannerRowIdentity.source))
    var collected: [PlannerEntityReference] = []
    for (offset, count) in [(Int64(0), 2), (Int64(2), 1), (Int64(3), 0), (Int64.max, 0)] {
      guard
        case .calendarRows(let page) = await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: offset, limit: 2))
      else { throw CancellationError() }
      #expect(page.generation == snapshot.generation && page.offset == offset)
      #expect(page.matchingCount == 3 && page.rows.count == count)
      collected.append(contentsOf: page.rows.map(\.schedule))
    }
    #expect(collected == expected)
    for (offset, limit) in [(Int64(-1), Int64(1)), (0, 0), (0, -1)] {
      guard
        case .failed(let failure) = await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: offset, limit: limit))
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput")
    }
    let invalidQueries: [(query: PlannerCalendarQuery, path: String)] = [
      (
        .init(
          startDay: .init(year: 2026, month: 2, day: 30), endDay: day, displayTimeZone: "Asia/Tokyo"
        ), "/query/startDay"
      ),
      (
        .init(
          startDay: day, endDay: .init(year: 2026, month: 2, day: 30), displayTimeZone: "Asia/Tokyo"
        ), "/query/endDay"
      ),
      (
        .init(
          startDay: day, endDay: .init(year: 2026, month: 10, day: 8), displayTimeZone: "Asia/Tokyo"
        ), "/query/endDay"
      ),
      (
        .init(startDay: day, endDay: day, displayTimeZone: "Invalid/Zone"), "/query/displayTimeZone"
      ),
    ]
    for example in invalidQueries {
      guard
        case .failed(let failure) = await planner.query(
          .init(session: session, request: .calendar(example.query)))
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput" && failure.propertyPath == example.path)
    }
    guard
      case .calendarRows(let retained) = await planner.read(
        session: session,
        request: .calendarRows(generation: snapshot.generation, offset: 0, limit: Int64.max)),
      case .exported(let after) = await planner.exportData(session: session),
      case .snapshot(let unrelated) = await planner.query(
        .init(session: session, request: .items(.init()))),
      case .failed(let unrelatedFailure) = await planner.read(
        session: session,
        request: .calendarRows(generation: unrelated.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(retained.rows.map(\.schedule) == expected)
    let beforeObject = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let afterObject = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: beforeObject).isEqual(to: afterObject))
    #expect(unrelatedFailure.code == "staleSnapshot")
  }
  @Test func externalOwnerAndScheduleChangesInvalidatePagesAndDeletionRemovesTheEntry() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    let item = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let day = PlannerCivilDate(year: 2026, month: 10, day: 9)
    let schedule = try #require(
      try await save(.createSchedule(source: item, form: .allDay(start: day, end: nil))).generated
        .first)
    func snapshot() async throws -> PlannerQuerySnapshot {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .calendar(.init(startDay: day, endDay: day, displayTimeZone: "Asia/Tokyo"))))
      else { throw CancellationError() }
      return snapshot
    }
    func page(_ snapshot: PlannerQuerySnapshot) async throws -> PlannerCalendarRowWindow {
      guard
        case .calendarRows(let page) = await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
      else { throw CancellationError() }
      return page
    }
    func expectStale(_ snapshot: PlannerQuerySnapshot) async throws {
      guard
        case .failed(let failure) = await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: 0, limit: 20))
      else { throw CancellationError() }
      #expect(failure.code == "staleSnapshot")
    }
    let issued = try await snapshot()
    #expect(try await page(issued).rows.first?.title == "Museum")
    let writer = Planner(configuration: configuration)
    guard case .ready(let writerSession) = await writer.bootstrap(),
      case .source(.item(let original)) = await writer.read(
        session: writerSession, request: .source(item)),
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .editItem(
            sourceId: item.id, changes: .init(title: .set("Renamed Museum")),
            expectedFieldHashes: [.title: try #require(original.fieldHashes[.title])]))
      )
      .outcome
    else { throw CancellationError() }
    try await expectStale(issued)
    let renamed = try await snapshot()
    let renamedEntry = try #require(try await page(renamed).rows.first)
    #expect(renamedEntry.schedule == schedule && renamedEntry.source == item)
    #expect(
      renamedEntry.title == "Renamed Museum" && renamedEntry.form == .allDay(start: day, end: nil))
    let laterForm = PlannerScheduleForm.allDay(
      start: day, end: .init(year: 2026, month: 10, day: 11))
    guard
      case .source(.schedule(let originalSchedule)) = await writer.read(
        session: writerSession, request: .source(schedule)),
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .editSchedule(
            scheduleId: schedule.id, changes: .init(form: laterForm),
            expectedFieldHashes: originalSchedule.fieldHashes))
      )
      .outcome
    else { throw CancellationError() }
    try await expectStale(renamed)
    let edited = try await snapshot()
    #expect(try await page(edited).rows.first?.form == laterForm)
    let command = PlannerCommand.deleteSource(source: item)
    guard
      case .reviewed(let review) = await writer.prepareReview(
        session: writerSession, command: command),
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession, command: command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    try await expectStale(edited)
    let deleted = try await snapshot()
    #expect(deleted.matchingCount == 0 && deleted.rows.isEmpty)
    #expect(try await page(deleted).rows.isEmpty)
  }
}
