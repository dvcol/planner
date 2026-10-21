import AppIntents
import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class PlannerScheduleReplacementIntentTests: XCTestCase {
  func testTimedReplacementConvertsAllDayScheduleWithoutChangingItsOwnerOrOtherBookings()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let action = SetPlannerScheduleTimedFormIntent()
    action.schedule = try PlannerScheduleEntity(
      schedule: fixture.allDay, owner: fixture.item, title: "Cached wrong owner type",
      form: .timed(
        start: fixture.instant, end: fixture.instant.addingTimeInterval(3600),
        planningTimeZone: "Asia/Tokyo"))
    action.start = .init(year: 2026, month: 11, day: 1, hour: 1, minute: 30)
    action.startOccurrence = .later
    action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "America/New_York"))
    let replaced = try await action.callAsFunction(donate: false)
    let expected = try Date.ISO8601FormatStyle().parse("2026-11-01T06:30:00Z")
    XCTAssertEqual(replaced.id, fixture.allDay.id)
    XCTAssertEqual(replaced.title, "Tokyo Weekend")
    XCTAssertEqual(replaced.sourceType, "Itinerary")
    XCTAssertEqual(replaced.start, expected)
    XCTAssertNil(replaced.end)
    XCTAssertNil(replaced.startDay)
    XCTAssertNil(replaced.endDay)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let saved)) = await reopened.read(
        session: session, request: .source(fixture.allDay)),
      case .source(.schedule(let retained)) = await reopened.read(
        session: session, request: .source(fixture.timed)),
      case .source(.schedule(let outside)) = await reopened.read(
        session: session, request: .source(fixture.outside))
    else { throw CancellationError() }
    XCTAssertEqual(saved.content.source, fixture.itinerary)
    XCTAssertEqual(
      saved.content.form,
      PlannerScheduleForm.timed(start: expected, end: nil, planningTimeZone: "America/New_York"))
    XCTAssertEqual(
      retained.content.form,
      PlannerScheduleForm.timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
    XCTAssertEqual(
      outside.content.form,
      PlannerScheduleForm.allDay(start: .init(year: 2026, month: 10, day: 12), end: nil))
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let schedules = try await query.suggestedEntities()
    XCTAssertEqual(
      Set(schedules.map(\.id)), [fixture.timed.id, fixture.allDay.id, fixture.outside.id])
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
  func testAllDayReplacementConvertsTimedAndClearsAnExistingAllDayEndWithTheSameIdentity()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let action = SetPlannerScheduleAllDayFormIntent()
    action.schedule = try PlannerScheduleEntity(
      schedule: fixture.timed, owner: fixture.itinerary,
      title: "Cached wrong owner",
      form: .allDay(start: .init(year: 2026, month: 1, day: 1), end: nil))
    action.startDay = .init(
      timeZone: TimeZone(identifier: "Europe/Paris"), year: 2026, month: 12, day: 1)
    action.endDay = .init(year: 2026, month: 12, day: 3)
    let converted = try await action.callAsFunction(donate: false)
    XCTAssertEqual(converted.id, fixture.timed.id)
    XCTAssertEqual(converted.title, "Museum")
    XCTAssertEqual(converted.sourceType, "Item")
    XCTAssertTrue(converted.allDay)
    XCTAssertNil(converted.start)
    XCTAssertNil(converted.end)
    XCTAssertNil(converted.planningTimeZone)
    XCTAssertEqual(converted.startDay, DateComponents(year: 2026, month: 12, day: 1))
    XCTAssertEqual(converted.endDay, DateComponents(year: 2026, month: 12, day: 3))
    action.schedule = converted
    action.endDay = nil
    let cleared = try await action.callAsFunction(donate: false)
    XCTAssertEqual(cleared.id, converted.id)
    XCTAssertNil(cleared.endDay)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let saved)) = await reopened.read(
        session: session, request: .source(fixture.timed)),
      case .source(.schedule(let untouched)) = await reopened.read(
        session: session, request: .source(fixture.allDay))
    else { throw CancellationError() }
    XCTAssertEqual(saved.content.source, fixture.item)
    XCTAssertEqual(
      saved.content.form,
      PlannerScheduleForm.allDay(start: .init(year: 2026, month: 12, day: 1), end: nil))
    XCTAssertEqual(
      untouched.content.form,
      PlannerScheduleForm.allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)))
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
  func testReplacementKeepsIndependentOwnerEditsAndUsesItsLiveTitle() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .source(.itinerary(let original)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else { throw CancellationError() }
    _ = try await fixture.store.executeAppIntent(
      .editItinerary(
        sourceId: fixture.itinerary.id,
        changes: .init(title: .set("Renamed route"), notes: .set("Keep this independent edit")),
        expectedFieldHashes: original.fieldHashes))
    guard
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else { throw CancellationError() }
    let action = SetPlannerScheduleTimedFormIntent()
    action.schedule = try PlannerScheduleEntity(
      schedule: fixture.allDay, owner: fixture.itinerary,
      title: "Old route", form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil))
    action.start = .init(year: 2026, month: 12, day: 1, hour: 10, minute: 0)
    action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
    let replaced = try await action.callAsFunction(donate: false)
    XCTAssertEqual(replaced.title, "Renamed route")
    guard
      case .source(.itinerary(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else { throw CancellationError() }
    XCTAssertEqual(after.content.notes, "Keep this independent edit")
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.createdAt, before.createdAt)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
  }
}
