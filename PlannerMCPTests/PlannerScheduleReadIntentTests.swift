import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerScheduleReadIntentTests: XCTestCase {
  func testCalendarWindowIncludesOvernightOverlapAndExcludesAnEndAtItsStartBoundary()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let start = try Date.ISO8601FormatStyle().parse("2026-10-08T14:30:00Z")
    let end = try Date.ISO8601FormatStyle().parse("2026-10-08T16:30:00Z").addingTimeInterval(0.25)
    let midnight = try Date.ISO8601FormatStyle().parse("2026-10-08T15:00:00Z")
    guard
      case .applied(let overlapping, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(
            source: fixture.item,
            form: .timed(start: start, end: end, planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let overnight = overlapping.generated.first,
      case .applied(let ending, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(
            source: fixture.item,
            form: .timed(start: start, end: midnight, planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let excluded = ending.generated.first,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Both overnight and boundary-ending spans must be saved first.") }
    let reading = FindPlannerSchedulesIntent()
    reading.startDay = .init(year: 2026, month: 10, day: 9)
    reading.endDay = reading.startDay
    reading.displayTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    let schedules = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(schedules.map(\.id)), [overnight.id, fixture.timed.id, fixture.allDay.id])
    XCTAssertFalse(schedules.contains { $0.id == excluded.id })
    let current = try XCTUnwrap(schedules.first { $0.id == overnight.id })
    XCTAssertEqual(current.start, start)
    XCTAssertEqual(current.end, end)
    XCTAssertEqual(current.planningTimeZone?.id, "Asia/Tokyo")
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Date-window matching cannot change the saved spans.") }
    XCTAssertEqual(after, before)
  }

  func testUnavailableStorageFailsScheduleReadsWithoutSuccessfulEmptyResults() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let contents = Data("Keep the store path obstructed.".utf8)
    try contents.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let schedule = try PlannerScheduleEntity(
      schedule: .init(kind: .schedule, id: UUID()), owner: .init(kind: .item, id: UUID()),
      title: "Cached", form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil))
    let calendar = FindPlannerSchedulesIntent()
    calendar.startDay = .init(year: 2026, month: 10, day: 9)
    calendar.endDay = calendar.startDay
    let exact = GetPlannerScheduleIntent()
    exact.schedule = schedule
    let item = GetPlannerItemSchedulesIntent()
    item.item = .init(id: UUID(), title: "Cached", done: false, archived: false)
    let itinerary = GetPlannerItinerarySchedulesIntent()
    itinerary.itinerary = .init(id: UUID(), title: "Cached", archived: false)
    let itemOwner = GetPlannerScheduleItemIntent()
    itemOwner.schedule = schedule
    let itineraryOwner = GetPlannerScheduleItineraryIntent()
    itineraryOwner.schedule = schedule
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = store
    let operations: [@MainActor () async throws -> Void] = [
      { _ = try await calendar.callAsFunction(donate: false) },
      { _ = try await exact.callAsFunction(donate: false) },
      { _ = try await item.callAsFunction(donate: false) },
      { _ = try await itinerary.callAsFunction(donate: false) },
      { _ = try await itemOwner.callAsFunction(donate: false) },
      { _ = try await itineraryOwner.callAsFunction(donate: false) },
      { _ = try await query.entities(for: []) },
      { _ = try await query.entities(matching: "") },
      { _ = try await query.suggestedEntities() },
    ]
    for operation in operations {
      do {
        try await operation()
        XCTFail("Unavailable Planner storage cannot return an empty successful Schedule read.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testCalendarRejectsIncompleteInvalidAndNonGregorianDatesWithoutChangingData() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Invalid reads must start with saved data.") }
    var leapMonth = DateComponents(year: 2026, month: 10, day: 9)
    leapMonth.isLeapMonth = true
    let invalid: [DateComponents] = [
      .init(year: 2026, month: 10), .init(year: 2026, month: 2, day: 30),
      .init(era: 0, year: 2026, month: 10, day: 9),
      .init(calendar: Calendar(identifier: .islamic), year: 2026, month: 10, day: 9),
      leapMonth,
    ]
    for components in invalid {
      let reading = FindPlannerSchedulesIntent()
      reading.startDay = components
      reading.endDay = .init(year: 2026, month: 10, day: 11)
      do {
        _ = try await reading.callAsFunction(donate: false)
        XCTFail("An invalid civil date cannot silently become a different accepted date.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let reversed = FindPlannerSchedulesIntent()
    reversed.startDay = .init(year: 2026, month: 10, day: 11)
    reversed.endDay = .init(year: 2026, month: 10, day: 9)
    do {
      _ = try await reversed.callAsFunction(donate: false)
      XCTFail("An inclusive date window cannot end before its start.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Invalid inputs cannot damage saved Schedule data.") }
    XCTAssertEqual(after, before)
  }

  func testCalendarDisplayZoneChangesTimedDayMembershipWithoutChangingCivilDates() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let instant = try Date.ISO8601FormatStyle().parse("2026-10-08T15:30:00Z")
    guard
      case .applied(let saved, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(
            source: fixture.item,
            form: .timed(start: instant, end: nil, planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let early = saved.generated.first,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The early Tokyo appointment must be saved first.") }
    let reading = FindPlannerSchedulesIntent()
    reading.startDay = .init(year: 2026, month: 10, day: 9)
    reading.endDay = reading.startDay
    reading.displayTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    let tokyo = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(tokyo.map(\.id)), [early.id, fixture.timed.id, fixture.allDay.id])
    XCTAssertEqual(tokyo.first { $0.id == early.id }?.start, instant)
    reading.displayTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Europe/Paris"))
    let paris = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(paris.map(\.id)), [fixture.timed.id, fixture.allDay.id])
    XCTAssertEqual(paris.first { $0.id == fixture.allDay.id }?.startDay?.day, 9)
    XCTAssertEqual(paris.first { $0.id == fixture.allDay.id }?.endDay?.day, 11)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Changing the read window's zone cannot reschedule anything.") }
    XCTAssertEqual(after, before)
  }

  func testCalendarPreservesDistinctRepeatedHoursAndShortAndLongDayBoundaries() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let specifications: [(String, String?)] = [
      ("2026-11-01T05:30:00Z", "2026-11-01T06:45:00Z"),
      ("2026-11-01T06:30:00Z", nil),
      ("2026-11-02T04:30:00Z", nil),
      ("2026-11-02T05:00:00Z", nil),
      ("2026-03-09T03:30:00Z", nil),
      ("2026-03-09T04:00:00Z", nil),
    ]
    var identifiers: [UUID] = []
    var starts: [Date] = []
    for (startText, endText) in specifications {
      let start = try Date.ISO8601FormatStyle().parse(startText)
      let end = try endText.map { try Date.ISO8601FormatStyle().parse($0) }
      guard
        case .applied(let saved, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .createSchedule(
              source: fixture.item,
              form: .timed(start: start, end: end, planningTimeZone: "America/New_York")))
        ).outcome,
        let schedule = saved.generated.first
      else { return XCTFail("Each fixed instant must remain a separate saved Schedule.") }
      identifiers.append(schedule.id)
      starts.append(start)
    }
    let reading = FindPlannerSchedulesIntent()
    reading.startDay = .init(year: 2026, month: 11, day: 1)
    reading.endDay = reading.startDay
    reading.displayTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "America/New_York"))
    let fall = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(fall.map(\.id)), Set(identifiers.prefix(3)))
    let first = try XCTUnwrap(fall.first { $0.id == identifiers[0] })
    let second = try XCTUnwrap(fall.first { $0.id == identifiers[1] })
    XCTAssertEqual(first.start, starts[0])
    XCTAssertEqual(second.start, starts[1])
    XCTAssertEqual(first.end, try Date.ISO8601FormatStyle().parse("2026-11-01T06:45:00Z"))
    XCTAssertNil(second.end)
    XCTAssertNotEqual(first.when, second.when)
    reading.startDay = .init(year: 2026, month: 3, day: 8)
    reading.endDay = reading.startDay
    let spring = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(spring.map(\.id), [identifiers[4]])
    XCTAssertEqual(spring.first?.start, starts[4])
  }

  func testCalendarAndDirectScheduleReadsReturnEveryBookingBeyondOnePage() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    var expected: Set<UUID> = [fixture.timed.id, fixture.allDay.id]
    var direct: Set<UUID> = [fixture.timed.id, fixture.outside.id]
    for _ in 0..<70 {
      guard
        case .applied(let saved, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .createSchedule(
              source: fixture.item,
              form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil)))
        ).outcome,
        let schedule = saved.generated.first
      else { return XCTFail("Every repeated booking needs its own saved identity.") }
      expected.insert(schedule.id)
      direct.insert(schedule.id)
    }
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let all = try await query.suggestedEntities()
    XCTAssertEqual(all.count, 73)
    XCTAssertEqual(Set(all.map(\.id)), expected.union([fixture.outside.id]))
    let calendar = FindPlannerSchedulesIntent()
    calendar.startDay = .init(year: 2026, month: 10, day: 9)
    calendar.endDay = .init(year: 2026, month: 10, day: 11)
    calendar.displayTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    let entries = try await calendar.callAsFunction(donate: false)
    XCTAssertEqual(entries.count, 72)
    XCTAssertEqual(Set(entries.map(\.id)), expected)
    let parent = GetPlannerItemSchedulesIntent()
    parent.item = .init(id: fixture.item.id, title: "Cached", done: false, archived: false)
    let bookings = try await parent.callAsFunction(donate: false)
    XCTAssertEqual(bookings.count, 72)
    XCTAssertEqual(Set(bookings.map(\.id)), direct)
    calendar.startDay = .init(year: 2027, month: 1, day: 1)
    calendar.endDay = calendar.startDay
    let empty = try await calendar.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
  }

  func testMissingWrongKindAndRemovedSchedulesFailWithoutRedirectingOrChangingData() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let cached = try XCTUnwrap(choices.first)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeSchedule(scheduleId: fixture.timed.id))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Remove only the selected Schedule before reading stale choices.") }
    for identifier in [cached.id, fixture.item.id, UUID()] {
      let stale = try PlannerScheduleEntity(
        schedule: .init(kind: .schedule, id: identifier), owner: fixture.item,
        title: "Cached", form: .timed(start: fixture.instant, end: nil, planningTimeZone: "UTC"))
      for action in [ScheduleReadAction.schedule, .itemOwner, .itineraryOwner] {
        do {
          _ = try await readScheduleIdentifiers(action, fixture: fixture, schedule: stale)
          XCTFail("Missing, wrong-kind and removed Schedules cannot redirect to another object.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      let resolved = try await query.entities(for: [identifier])
      XCTAssertTrue(resolved.isEmpty)
    }
    for identifier in [fixture.itinerary.id, UUID()] {
      let reading = GetPlannerItemSchedulesIntent()
      reading.item = .init(id: identifier, title: "Cached", done: false, archived: false)
      do {
        _ = try await reading.callAsFunction(donate: false)
        XCTFail("A wrong-kind or missing Item cannot return successful empty Schedules.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    guard case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Rejected reads cannot change remaining Schedule data.") }
    XCTAssertEqual(unchanged, before)
    let emptyOwner = CreatePlannerItineraryIntent()
    emptyOwner.title = "Unscheduled"
    let itinerary = try await emptyOwner.callAsFunction(donate: false)
    let emptyReading = GetPlannerItinerarySchedulesIntent()
    emptyReading.itinerary = itinerary
    let empty = try await emptyReading.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
    guard
      case .source(.schedule(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.allDay)),
      case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Other Schedules must remain readable.") }
    XCTAssertEqual(retained.content.source, fixture.itinerary)
    XCTAssertNotEqual(after, before)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item))
    else { return XCTFail("Reading a removed Schedule cannot remove its Item.") }
    XCTAssertEqual(item.content.title, "Museum")
  }

  func testPrecancelledScheduleReadsPropagateCancellationWithoutChangingSavedData() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let schedule = try XCTUnwrap(choices.first)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancellation must preserve saved data.") }
    for action in ScheduleReadAction.allCases {
      let task = Task { @MainActor in
        try await readScheduleIdentifiers(action, fixture: fixture, schedule: schedule)
      }
      task.cancel()
      do {
        _ = try await task.value
        XCTFail("A precancelled Schedule read must throw.")
      } catch is CancellationError {
      } catch { XCTFail("Expected cancellation, received \(error).") }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancellation cannot damage storage.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testReadsDuringIncompleteRecoveryDoNotAcknowledgeOrRepeatTheAppliedEdit() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let schedule = try XCTUnwrap(choices.first)
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let edit = EditPlannerItemIntent()
    edit.item = .init(id: fixture.item.id, title: "Cached", done: false, archived: false)
    edit.title = "Applied despite incomplete recovery"
    let _: Void = try await edit.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    guard
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { return XCTFail("The applied edit must remain readable.") }
    for action in ScheduleReadAction.allCases {
      _ = try await readScheduleIdentifiers(action, fixture: fixture, schedule: schedule)
    }
    let current = try await query.entities(for: [fixture.timed.id])
    XCTAssertEqual(current.first?.title, "Applied despite incomplete recovery")
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    await fixture.store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .source(.item(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { return XCTFail("Only explicit recovery may acknowledge the original edit.") }
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testScheduleChoicesSearchCurrentOwnerTitlesAndKeepSeparateBookings() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let all = try await query.suggestedEntities()
    XCTAssertEqual(Set(all.map(\.id)), [fixture.timed.id, fixture.allDay.id, fixture.outside.id])
    let initial = try await query.entities(matching: "museum")
    XCTAssertEqual(Set(initial.map(\.id)), [fixture.timed.id, fixture.outside.id])
    let rename = EditPlannerItemIntent()
    rename.item = .init(id: fixture.item.id, title: "Cached title", done: false, archived: false)
    rename.title = "Musée rénové"
    let _: Void = try await rename.callAsFunction(donate: false)
    let changed = try await query.entities(matching: "MUSEE RENOVE")
    XCTAssertEqual(Set(changed.map(\.id)), [fixture.timed.id, fixture.outside.id])
    XCTAssertTrue(changed.allSatisfy { $0.title == "Musée rénové" })
    let previous = try await query.entities(matching: "Museum")
    XCTAssertTrue(previous.isEmpty)
    let itinerary = try await query.entities(matching: "weekend")
    XCTAssertEqual(itinerary.map(\.id), [fixture.allDay.id])
    let missing = try await query.entities(matching: "No such schedule")
    XCTAssertTrue(missing.isEmpty)
  }

  func testScheduleOwnerReadsReturnCurrentTypedOwnersAndNilForTheOtherSourceKind() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true))
      ).outcome,
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setArchive(source: fixture.itinerary, archived: true))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Schedule owners must keep their current saved state.") }
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let schedules = try await query.entities(for: [fixture.timed.id, fixture.allDay.id])
    for schedule in schedules {
      let itemReading = GetPlannerScheduleItemIntent()
      itemReading.schedule = schedule
      let item = try await itemReading.callAsFunction(donate: false)
      let itineraryReading = GetPlannerScheduleItineraryIntent()
      itineraryReading.schedule = schedule
      let itinerary = try await itineraryReading.callAsFunction(donate: false)
      if schedule.id == fixture.timed.id {
        XCTAssertEqual(item?.id, fixture.item.id)
        XCTAssertEqual(item?.title, "Museum")
        XCTAssertEqual(item?.done, true)
        XCTAssertEqual(item?.archived, false)
        XCTAssertNil(itinerary)
      } else {
        XCTAssertNil(item)
        XCTAssertEqual(itinerary?.id, fixture.itinerary.id)
        XCTAssertEqual(itinerary?.title, "Tokyo Weekend")
        XCTAssertEqual(itinerary?.archived, true)
      }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Reading typed owners cannot change their graph or states.") }
    XCTAssertEqual(after, before)
  }

  func testItinerarySchedulesRetainArchivedOwnerBookingsWithoutIncludingChildBookings()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setArchive(source: fixture.itinerary, archived: true))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Archiving an Itinerary must retain its bookings.") }
    let reading = GetPlannerItinerarySchedulesIntent()
    reading.itinerary = .init(id: fixture.itinerary.id, title: "Cached title", archived: false)
    let schedules = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(schedules.map(\.id), [fixture.allDay.id])
    XCTAssertEqual(schedules.first?.title, "Tokyo Weekend")
    XCTAssertEqual(schedules.first?.sourceType, "Itinerary")
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Reading must preserve the archived Itinerary and child Schedules.") }
    XCTAssertEqual(after, before)
  }

  func testCalendarWindowReturnsExactTimedAndInclusiveAllDayFormsWithoutChangingData()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The native Calendar read must start from saved Schedule forms.") }
    let zones = try await PlannerTimeZoneEntityQuery().entities(for: ["Asia/Tokyo"])
    let reading = FindPlannerSchedulesIntent()
    reading.startDay = .init(year: 2026, month: 10, day: 9)
    reading.endDay = .init(year: 2026, month: 10, day: 11)
    reading.displayTimeZone = try XCTUnwrap(zones.first)
    let schedules = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(schedules.map(\.id)), [fixture.timed.id, fixture.allDay.id])
    let timed = try XCTUnwrap(schedules.first { $0.id == fixture.timed.id })
    XCTAssertEqual(timed.title, "Museum")
    XCTAssertEqual(timed.sourceType, "Item")
    XCTAssertFalse(timed.allDay)
    XCTAssertEqual(timed.start, fixture.instant)
    XCTAssertNil(timed.end)
    XCTAssertNil(timed.startDay)
    XCTAssertNil(timed.endDay)
    XCTAssertEqual(timed.planningTimeZone?.id, "Asia/Tokyo")
    let allDay = try XCTUnwrap(schedules.first { $0.id == fixture.allDay.id })
    XCTAssertEqual(allDay.title, "Tokyo Weekend")
    XCTAssertEqual(allDay.sourceType, "Itinerary")
    XCTAssertTrue(allDay.allDay)
    XCTAssertNil(allDay.start)
    XCTAssertNil(allDay.end)
    XCTAssertNil(allDay.planningTimeZone)
    XCTAssertEqual(allDay.startDay?.year, 2026)
    XCTAssertEqual(allDay.startDay?.month, 10)
    XCTAssertEqual(allDay.startDay?.day, 9)
    XCTAssertEqual(allDay.endDay?.day, 11)
    XCTAssertNil(allDay.startDay?.hour)
    XCTAssertNil(allDay.startDay?.timeZone)
    XCTAssertNil(allDay.endDay?.hour)
    XCTAssertNil(allDay.endDay?.timeZone)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let after) = await reopened.exportData(session: session)
    else { return XCTFail("Native Calendar reads must preserve the reopened planner.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testExactScheduleReadKeepsItsIdentityWhenTheSourceTitleAndSavedFormChange() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let initial = try await query.entities(for: [
      fixture.outside.id, fixture.timed.id, fixture.timed.id, UUID(),
    ])
    XCTAssertEqual(initial.map(\.id), [fixture.outside.id, fixture.timed.id])
    let cached = try XCTUnwrap(initial.last)
    XCTAssertEqual(cached.start, fixture.instant)
    let rename = EditPlannerItemIntent()
    rename.item = .init(id: fixture.item.id, title: "Cached title", done: true, archived: true)
    rename.title = "Museum renamed"
    let _: Void = try await rename.callAsFunction(donate: false)
    guard
      case .source(.schedule(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .editSchedule(
            scheduleId: fixture.timed.id,
            changes: .init(
              form: .allDay(start: .init(year: 2026, month: 10, day: 10), end: nil)),
            expectedFieldHashes: before.fieldHashes))
      ).outcome,
      case .exported(let saved) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The same Schedule must support a saved form change.") }
    let reading = GetPlannerScheduleIntent()
    reading.schedule = cached
    let current = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(current.id, fixture.timed.id)
    XCTAssertEqual(current.title, "Museum renamed")
    XCTAssertEqual(current.sourceType, "Item")
    XCTAssertTrue(current.allDay)
    XCTAssertNil(current.start)
    XCTAssertNil(current.end)
    XCTAssertNil(current.planningTimeZone)
    XCTAssertEqual(current.startDay?.year, 2026)
    XCTAssertEqual(current.startDay?.month, 10)
    XCTAssertEqual(current.startDay?.day, 10)
    XCTAssertNil(current.endDay)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Reading current values must preserve the edited Schedule.") }
    XCTAssertEqual(after, saved)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testItemSchedulesIncludeDirectBookingsOnArchivedSourcesWithoutInheritedItineraryRecords()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setArchive(source: fixture.item, archived: true))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Archiving an Item must retain its owned and inherited Schedules.") }
    let reading = GetPlannerItemSchedulesIntent()
    reading.item = .init(id: fixture.item.id, title: "Cached Item", done: true, archived: false)
    let schedules = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(schedules.map(\.id)), [fixture.timed.id, fixture.outside.id])
    XCTAssertTrue(schedules.allSatisfy { $0.sourceType == "Item" && $0.title == "Museum" })
    XCTAssertFalse(schedules.contains { $0.id == fixture.allDay.id })
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The direct Schedule read must preserve every saved relationship.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
}

private enum ScheduleReadAction: CaseIterable {
  case calendar, schedule, item, itinerary, itemOwner, itineraryOwner, choices, search
}

@MainActor
private func readScheduleIdentifiers(
  _ action: ScheduleReadAction, fixture: ScheduleReadIntentFixture, schedule: PlannerScheduleEntity
) async throws -> [UUID] {
  switch action {
  case .calendar:
    let reading = FindPlannerSchedulesIntent()
    reading.startDay = .init(year: 2026, month: 10, day: 9)
    reading.endDay = .init(year: 2026, month: 10, day: 11)
    reading.displayTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    return try await reading.callAsFunction(donate: false).map(\.id)
  case .schedule:
    let reading = GetPlannerScheduleIntent()
    reading.schedule = schedule
    return try await [reading.callAsFunction(donate: false).id]
  case .item:
    let reading = GetPlannerItemSchedulesIntent()
    reading.item = .init(id: fixture.item.id, title: "Cached", done: false, archived: false)
    return try await reading.callAsFunction(donate: false).map(\.id)
  case .itinerary:
    let reading = GetPlannerItinerarySchedulesIntent()
    reading.itinerary = .init(id: fixture.itinerary.id, title: "Cached", archived: false)
    return try await reading.callAsFunction(donate: false).map(\.id)
  case .itemOwner:
    let reading = GetPlannerScheduleItemIntent()
    reading.schedule = schedule
    return try await reading.callAsFunction(donate: false).map { [$0.id] } ?? []
  case .itineraryOwner:
    let reading = GetPlannerScheduleItineraryIntent()
    reading.schedule = schedule
    return try await reading.callAsFunction(donate: false).map { [$0.id] } ?? []
  case .choices:
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    return try await query.suggestedEntities().map(\.id)
  case .search:
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    return try await query.entities(matching: "").map(\.id)
  }
}

struct ScheduleReadIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let timed: PlannerEntityReference
  let allDay: PlannerEntityReference
  let outside: PlannerEntityReference
  let instant: Date
}

@MainActor
func makeScheduleReadIntentFixture() async throws -> ScheduleReadIntentFixture {
  let (_, configuration, store) = try makePlannerIntentStorage()
  AppDependencyManager.shared.add(dependency: store)
  let planner = PlannerCore.Planner(configuration: configuration)
  guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
  func save(_ command: PlannerCommand) async throws -> PlannerEntityReference {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome,
      let source = result.generated.first
    else { throw CancellationError() }
    return source
  }
  let item = try await save(
    .createItem(content: .init(title: "Museum", estimate: .init(minutes: 90, displayUnit: .hour))))
  let itinerary = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
  guard
    case .applied(_, .complete) = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    ).outcome
  else { throw CancellationError() }
  let instant = try Date.ISO8601FormatStyle().parse("2026-10-09T01:00:00Z")
    .addingTimeInterval(0.125)
  let timed = try await save(
    .createSchedule(
      source: item, form: .timed(start: instant, end: nil, planningTimeZone: "Asia/Tokyo")))
  let allDay = try await save(
    .createSchedule(
      source: itinerary,
      form: .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))))
  let outside = try await save(
    .createSchedule(
      source: item, form: .allDay(start: .init(year: 2026, month: 10, day: 12), end: nil)))
  return .init(
    configuration: configuration, store: store, planner: planner, session: session,
    item: item, itinerary: itinerary, timed: timed, allDay: allDay, outside: outside,
    instant: instant)
}
