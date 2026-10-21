import AppIntents
import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class PlannerScheduleCreationIntentTests: XCTestCase {
  func
    testTimedItemCreationUsesPlanningCivilTimeAndReturnsItsExactSavedIdentityWithoutAnInferredEnd()
    async throws
  {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    let action = CreatePlannerTimedItemScheduleIntent()
    action.item = .init(id: fixture.item.id, title: "Cached name", done: true, archived: true)
    action.start = DateComponents(
      calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "Europe/Paris"),
      year: 2026, month: 10, day: 9, hour: 10, minute: 0)
    action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    let created = try await action.callAsFunction(donate: false)
    let expectedStart = try Date.ISO8601FormatStyle().parse("2026-10-09T01:00:00Z")
    XCTAssertEqual(created.title, "Museum")
    XCTAssertEqual(created.sourceType, "Item")
    XCTAssertEqual(created.start, expectedStart)
    XCTAssertNil(created.end)
    XCTAssertEqual(created.planningTimeZone?.id, "Asia/Tokyo")
    XCTAssertNotEqual(created.id, fixture.itemSchedule.id)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let saved)) = await reopened.read(
        session: session, request: .source(.init(kind: .schedule, id: created.id)))
    else { return XCTFail("Return the exact Schedule identity that was durably saved.") }
    XCTAssertEqual(saved.content.source, fixture.item)
    XCTAssertEqual(
      saved.content.form,
      PlannerScheduleForm.timed(start: expectedStart, end: nil, planningTimeZone: "Asia/Tokyo"))
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(after.item.fieldHashes, before.item.fieldHashes)
    XCTAssertEqual(after.list.content, before.list.content)
    XCTAssertEqual(after.itinerary.fieldHashes, before.itinerary.fieldHashes)
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }
  func testContradictoryGregorianFieldsRejectBeforeCreatingABooking() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let action = CreatePlannerTimedItemScheduleIntent()
    action.item = .init(id: fixture.item.id, title: "Museum", done: false, archived: false)
    var fields = DateComponents(year: 2026, month: 10, day: 9, hour: 10, minute: 0)
    fields.weekday = 1
    action.start = fields
    action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    do {
      _ = try await action.callAsFunction(donate: false)
      XCTFail("Contradictory civil fields cannot silently normalize into a booking.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
  }
  func testRepeatedEndpointsRequireIndependentChoicesAndCompareResolvedInstants() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let repeated = DateComponents(year: 2026, month: 11, day: 1, hour: 1, minute: 30)
    let earlier = try await createTimed(
      fixture, start: repeated, zone: "America/New_York", startOccurrence: .earlier)
    let later = try await createTimed(
      fixture, start: repeated, zone: "America/New_York", startOccurrence: .later)
    XCTAssertEqual(earlier.start, try Date.ISO8601FormatStyle().parse("2026-11-01T05:30:00Z"))
    XCTAssertEqual(later.start, try Date.ISO8601FormatStyle().parse("2026-11-01T06:30:00Z"))
    XCTAssertNotEqual(earlier.id, later.id)
    let crossing = try await createTimed(
      fixture,
      start: .init(year: 2026, month: 11, day: 1, hour: 1, minute: 45),
      end: .init(year: 2026, month: 11, day: 1, hour: 1, minute: 15),
      zone: "America/New_York", startOccurrence: .earlier, endOccurrence: .later)
    XCTAssertEqual(crossing.start, try Date.ISO8601FormatStyle().parse("2026-11-01T05:45:00Z"))
    XCTAssertEqual(crossing.end, try Date.ISO8601FormatStyle().parse("2026-11-01T06:15:00Z"))
    let equalClock = try await createTimed(
      fixture, start: repeated, end: repeated,
      zone: "America/New_York", startOccurrence: .earlier, endOccurrence: .later)
    let equalClockStart = try XCTUnwrap(equalClock.start)
    XCTAssertEqual(equalClock.end?.timeIntervalSince(equalClockStart), 3600)
    let halfHour = DateComponents(year: 2026, month: 4, day: 5, hour: 1, minute: 45)
    let firstHalfHour = try await createTimed(
      fixture, start: halfHour,
      zone: "Australia/Lord_Howe", startOccurrence: .earlier)
    let secondHalfHour = try await createTimed(
      fixture, start: halfHour,
      zone: "Australia/Lord_Howe", startOccurrence: .later)
    XCTAssertEqual(firstHalfHour.start, try Date.ISO8601FormatStyle().parse("2026-04-04T14:45:00Z"))
    XCTAssertEqual(
      secondHalfHour.start, try Date.ISO8601FormatStyle().parse("2026-04-04T15:15:00Z"))
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    for created in [earlier, later, crossing, equalClock, firstHalfHour, secondHalfHour] {
      guard
        case .source(.schedule(let saved)) = await reopened.read(
          session: session, request: .source(.init(kind: .schedule, id: created.id)))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content.source, fixture.item)
      XCTAssertEqual(
        saved.content.form,
        PlannerScheduleForm.timed(
          start: try XCTUnwrap(created.start), end: created.end,
          planningTimeZone: try XCTUnwrap(created.planningTimeZone?.id)))
    }
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }

  func testSkippedAmbiguousIncompleteAndInvalidMinuteInputsNeverSaveOrNormalize() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    var leapMonth = DateComponents(year: 2026, month: 10, day: 9, hour: 10, minute: 0)
    leapMonth.isLeapMonth = true
    let invalid: [(DateComponents, String)] = [
      (.init(year: 2026, month: 3, day: 8, hour: 2, minute: 30), "America/New_York"),
      (.init(year: 2026, month: 11, day: 1, hour: 1, minute: 30), "America/New_York"),
      (.init(year: 2026, month: 10, day: 4, hour: 2, minute: 15), "Australia/Lord_Howe"),
      (.init(year: 2026, month: 4, day: 5, hour: 1, minute: 45), "Australia/Lord_Howe"),
      (.init(year: 2026, month: 10, day: 9), "Asia/Tokyo"),
      (.init(month: 10, day: 9, hour: 10, minute: 0), "Asia/Tokyo"),
      (.init(year: 2026, month: 2, day: 30, hour: 10, minute: 0), "Asia/Tokyo"),
      (.init(year: 2026, month: 10, day: 9, hour: 24, minute: 0), "Asia/Tokyo"),
      (.init(year: 2026, month: 10, day: 9, hour: 10, minute: 60), "Asia/Tokyo"),
      (.init(year: 2026, month: 10, day: 9, hour: 10, minute: 0, second: 1), "Asia/Tokyo"),
      (.init(year: 2026, month: 10, day: 9, hour: 10, minute: 0, nanosecond: 1), "Asia/Tokyo"),
      (.init(era: 0, year: 2026, month: 10, day: 9, hour: 10, minute: 0), "Asia/Tokyo"),
      (
        .init(
          calendar: Calendar(identifier: .islamic), year: 2026, month: 10, day: 9, hour: 10,
          minute: 0), "Asia/Tokyo"
      ),
      (leapMonth, "Asia/Tokyo"),
    ]
    for (fields, zone) in invalid {
      do {
        _ = try await createTimed(fixture, start: fields, zone: zone)
        XCTFail("Invalid or ambiguous civil input must fail before saving.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    do {
      _ = try await createTimed(
        fixture,
        start: .init(year: 2026, month: 11, day: 1, hour: 0, minute: 30),
        end: .init(year: 2026, month: 11, day: 1, hour: 1, minute: 30), zone: "America/New_York")
      XCTFail("A repeated End needs its own occurrence choice.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testTimedEndIsOptionalButMustBeStrictlyLaterWhenSupplied() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let start = DateComponents(year: 2026, month: 10, day: 9, hour: 10, minute: 0)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    for end in [start, DateComponents(year: 2026, month: 10, day: 9, hour: 9, minute: 59)] {
      do {
        _ = try await createTimed(fixture, start: start, end: end)
        XCTFail("Equal or earlier instants cannot become a supplied End.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    let sameDay = try await createTimed(
      fixture, start: start,
      end: .init(year: 2026, month: 10, day: 9, hour: 11, minute: 0))
    XCTAssertEqual(sameDay.end, try Date.ISO8601FormatStyle().parse("2026-10-09T02:00:00Z"))
    let overnight = try await createTimed(
      fixture, start: start,
      end: .init(year: 2026, month: 10, day: 10, hour: 0, minute: 0))
    XCTAssertEqual(overnight.end, try Date.ISO8601FormatStyle().parse("2026-10-09T15:00:00Z"))
  }

  func testAllDayCreationForBothOwnersPreservesInclusiveCivilDatesAndOptionalEnds() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let startDay = DateComponents(
      timeZone: TimeZone(identifier: "Asia/Tokyo"), year: 2026, month: 10, day: 9)
    let endDay = DateComponents(
      timeZone: TimeZone(identifier: "Europe/Paris"), year: 2026, month: 10, day: 11)
    let itemAction = CreatePlannerAllDayItemScheduleIntent()
    itemAction.item = .init(id: fixture.item.id, title: "Cached Item", done: false, archived: true)
    itemAction.startDay = startDay
    itemAction.endDay = endDay
    let itemBooking = try await itemAction.callAsFunction(donate: false)
    let itineraryAction = CreatePlannerAllDayItineraryScheduleIntent()
    itineraryAction.itinerary = .init(
      id: fixture.itinerary.id, title: "Cached Itinerary", archived: true)
    itineraryAction.startDay = startDay
    let itineraryBooking = try await itineraryAction.callAsFunction(donate: false)
    itineraryAction.endDay = startDay
    let explicitSingleDay = try await itineraryAction.callAsFunction(donate: false)
    XCTAssertEqual(itemBooking.title, "Museum")
    XCTAssertEqual(itemBooking.sourceType, "Item")
    XCTAssertEqual(itineraryBooking.title, "Tokyo Weekend")
    XCTAssertEqual(itineraryBooking.sourceType, "Itinerary")
    XCTAssertEqual(itemBooking.startDay, DateComponents(year: 2026, month: 10, day: 9))
    XCTAssertEqual(itemBooking.endDay, DateComponents(year: 2026, month: 10, day: 11))
    XCTAssertNil(itemBooking.start)
    XCTAssertNil(itemBooking.end)
    XCTAssertNil(itemBooking.planningTimeZone)
    XCTAssertNil(itineraryBooking.endDay)
    XCTAssertEqual(explicitSingleDay.endDay, DateComponents(year: 2026, month: 10, day: 9))
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    for (booking, owner, end) in [
      (itemBooking, fixture.item, PlannerCivilDate(year: 2026, month: 10, day: 11)),
      (itineraryBooking, fixture.itinerary, nil),
      (explicitSingleDay, fixture.itinerary, PlannerCivilDate(year: 2026, month: 10, day: 9)),
    ] {
      guard
        case .source(.schedule(let saved)) = await reopened.read(
          session: session,
          request: .source(.init(kind: .schedule, id: booking.id)))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content.source, owner)
      XCTAssertEqual(
        saved.content.form,
        PlannerScheduleForm.allDay(
          start: .init(year: 2026, month: 10, day: 9), end: end))
    }
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }

  func testTimedItineraryCreationAcceptsItsArchivedOwnerAndKeepsAllChildrenAndBookings()
    async throws
  {
    let fixture = try await makeEstimateResetIntentFixture()
    _ = try await fixture.store.executeAppIntent(
      .setArchive(source: fixture.itinerary, archived: true))
    let before = try await readEstimateResetSources(fixture)
    let action = CreatePlannerTimedItineraryScheduleIntent()
    action.itinerary = PlannerItineraryEntity(
      id: fixture.itinerary.id, title: "Cached", archived: false)
    action.start = .init(year: 2026, month: 10, day: 9, hour: 23, minute: 45)
    action.end = .init(year: 2026, month: 10, day: 10, hour: 0, minute: 15)
    action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    let created = try await action.callAsFunction(donate: false)
    XCTAssertEqual(created.title, "Tokyo Weekend")
    XCTAssertEqual(created.sourceType, "Itinerary")
    XCTAssertEqual(created.start, try Date.ISO8601FormatStyle().parse("2026-10-09T14:45:00Z"))
    XCTAssertEqual(created.end, try Date.ISO8601FormatStyle().parse("2026-10-09T15:15:00Z"))
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let saved)) = await reopened.read(
        session: session,
        request: .source(.init(kind: .schedule, id: created.id)))
    else { throw CancellationError() }
    XCTAssertEqual(saved.content.source, fixture.itinerary)
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(after.item.fieldHashes, before.item.fieldHashes)
    XCTAssertEqual(after.list.content, before.list.content)
    XCTAssertEqual(after.itinerary.fieldHashes, before.itinerary.fieldHashes)
    XCTAssertEqual(after.itinerary.state.archived, true)
    XCTAssertEqual(after.itinerary.progress.doneCount, before.itinerary.progress.doneCount)
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }

  private func createTimed(
    _ fixture: EstimateResetIntentFixture, start: DateComponents, end: DateComponents? = nil,
    zone: String = "Asia/Tokyo", startOccurrence: PlannerScheduleOccurrence? = nil,
    endOccurrence: PlannerScheduleOccurrence? = nil
  ) async throws -> PlannerScheduleEntity {
    let action = CreatePlannerTimedItemScheduleIntent()
    action.item = .init(id: fixture.item.id, title: "Cached", done: false, archived: false)
    action.start = start
    action.end = end
    action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: zone))
    action.startOccurrence = startOccurrence
    action.endOccurrence = endOccurrence
    return try await action.callAsFunction(donate: false)
  }
}
