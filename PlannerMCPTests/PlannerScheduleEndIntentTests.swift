import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerScheduleEndIntentTests: XCTestCase {
  func testAppliedEndClearWithIncompleteRecoveryRetainsTheChangeAndBlocksAnotherMutation()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.allDay.id, fixture.timed.id])
    let clear = ClearPlannerScheduleEndIntent()
    clear.schedule = try XCTUnwrap(choices.first)
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let _: Void = try await clear.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    guard
      case .source(.schedule(let applied)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.allDay))
    else { return XCTFail("The cleared end remains applied despite incomplete recovery.") }
    XCTAssertEqual(
      applied.content.form, .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil))
    clear.schedule = try XCTUnwrap(choices.last)
    do {
      let _: Void = try await clear.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block a second mutation.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    guard
      case .appliedRecoveryIncomplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { return XCTFail("Restoring archive access must expose the original incomplete receipt.") }
    await fixture.store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .source(.schedule(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.allDay)),
      case .source(.schedule(let timed)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed))
    else { return XCTFail("Explicit retry must acknowledge the original edit only.") }
    XCTAssertEqual(after.content, applied.content)
    XCTAssertEqual(after.fieldHashes, applied.fieldHashes)
    XCTAssertEqual(
      timed.content.form,
      .timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
  }

  func testUnavailableStorageRejectsEndClearingWithoutAcknowledgingASave() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let contents = Data("Keep storage obstructed.".utf8)
    try contents.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let clear = ClearPlannerScheduleEndIntent()
    clear.schedule = try PlannerScheduleEntity(
      schedule: .init(kind: .schedule, id: UUID()), owner: .init(kind: .item, id: UUID()),
      title: "Cached",
      form: .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)))
    do {
      let _: Void = try await clear.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a cleared end.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledEndClearPreservesTheSavedGraph() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.allDay.id])
    let clear = ClearPlannerScheduleEndIntent()
    clear.schedule = try XCTUnwrap(choices.first)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the all-day end before cancellation.") }
    let task = Task { @MainActor in
      let _: Void = try await clear.callAsFunction(donate: false)
    }
    task.cancel()
    do {
      try await task.value
      XCTFail("A precancelled action cannot clear the end.")
    } catch is CancellationError {
    } catch { XCTFail("Expected cancellation, received \(error).") }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The cancelled action must leave saved data readable.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testMissingWrongKindAndRemovedBookingsRejectWithoutChangingData() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeSchedule(scheduleId: fixture.outside.id))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the saved graph after removing one booking.") }
    for identifier in [fixture.item.id, fixture.itinerary.id, fixture.outside.id, UUID()] {
      let clear = ClearPlannerScheduleEndIntent()
      clear.schedule = try PlannerScheduleEntity(
        schedule: .init(kind: .schedule, id: identifier), owner: fixture.item,
        title: "Cached",
        form: .timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
      do {
        let _: Void = try await clear.callAsFunction(donate: false)
        XCTFail("An invalid booking cannot fall back to an owner or another Schedule.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Read the unchanged saved graph after every rejection.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testAlreadyAbsentEndsRemainAbsentForBothFormsAfterRepeatedClears() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id, fixture.outside.id])
    XCTAssertEqual(choices.count, 2)
    for choice in choices {
      let clear = ClearPlannerScheduleEndIntent()
      clear.schedule = choice
      let _: Void = try await clear.callAsFunction(donate: false)
      let _: Void = try await clear.callAsFunction(donate: false)
    }
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let timed)) = await reopened.read(
        session: session, request: .source(fixture.timed)),
      case .source(.schedule(let allDay)) = await reopened.read(
        session: session, request: .source(fixture.outside))
    else { return XCTFail("Clearing an absent end cannot lose either saved booking.") }
    XCTAssertEqual(
      timed.content.form,
      .timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
    XCTAssertEqual(
      allDay.content.form, .allDay(start: .init(year: 2026, month: 10, day: 12), end: nil))
    XCTAssertEqual(timed.content.source, fixture.item)
    XCTAssertEqual(allDay.content.source, fixture.item)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testClearingCurrentAllDayEndIgnoresCachedTimedFormAndPreservesArchivedItinerary()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.allDay.id])
    let cached = try XCTUnwrap(choices.first)
    let currentStart = PlannerCivilDate(year: 2027, month: 1, day: 31)
    guard
      case .source(.schedule(let initial)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.allDay)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .editSchedule(
            scheduleId: fixture.allDay.id,
            changes: .init(
              form: .allDay(start: currentStart, end: .init(year: 2027, month: 2, day: 2))),
            expectedFieldHashes: initial.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setArchive(source: fixture.itinerary, archived: true))
      ).outcome,
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else { return XCTFail("Save the archived owner's current inclusive all-day span.") }
    cached.allDay = false
    cached.start = fixture.instant
    cached.end = fixture.instant.addingTimeInterval(7200)
    cached.startDay = nil
    cached.endDay = nil
    cached.planningTimeZone = PlannerTimeZoneEntity(identifier: "Asia/Tokyo")
    let clear = ClearPlannerScheduleEndIntent()
    clear.schedule = cached
    let _: Void = try await clear.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let current)) = await reopened.read(
        session: session, request: .source(fixture.allDay)),
      case .source(.itinerary(let after)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.schedule(let timed)) = await reopened.read(
        session: session, request: .source(fixture.timed))
    else { return XCTFail("Read the original identities after clearing the all-day end.") }
    XCTAssertEqual(current.source, fixture.allDay)
    XCTAssertEqual(current.content.source, fixture.itinerary)
    XCTAssertEqual(current.content.form, .allDay(start: currentStart, end: nil))
    XCTAssertEqual(after.content.title, "Tokyo Weekend")
    XCTAssertEqual(after.state.archived, true)
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(
      timed.content.form,
      .timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testClearingTimedEndPreservesCurrentFractionalStartZoneOwnerAndOtherBookings() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let cached = try XCTUnwrap(choices.first)
    let start = try Date.ISO8601FormatStyle().parse("2026-11-01T06:30:00Z").addingTimeInterval(0.75)
    guard
      case .source(.schedule(let initial)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .editSchedule(
            scheduleId: fixture.timed.id,
            changes: .init(
              form: .timed(
                start: start, end: start.addingTimeInterval(3600.125),
                planningTimeZone: "America/New_York")),
            expectedFieldHashes: initial.fieldHashes))
      ).outcome,
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { return XCTFail("Save the current repeated-hour span before clearing only its end.") }
    let clear = ClearPlannerScheduleEndIntent()
    clear.schedule = cached
    let _: Void = try await clear.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let current)) = await reopened.read(
        session: session, request: .source(fixture.timed)),
      case .source(.item(let after)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.schedule(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.allDay)),
      case .source(.schedule(let outside)) = await reopened.read(
        session: session, request: .source(fixture.outside))
    else { return XCTFail("Reopen the same booking, source and other bookings after clearing.") }
    XCTAssertEqual(current.source, fixture.timed)
    XCTAssertEqual(current.content.source, fixture.item)
    XCTAssertEqual(
      current.content.form,
      .timed(start: start, end: nil, planningTimeZone: "America/New_York"))
    XCTAssertEqual(after.content.title, before.content.title)
    XCTAssertEqual(after.content.notes, before.content.notes)
    XCTAssertEqual(after.state.globalDone, before.state.globalDone)
    XCTAssertEqual(after.state.archived, before.state.archived)
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.content.estimate?.minutes, 90)
    XCTAssertEqual(
      itinerary.content.form,
      .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)))
    XCTAssertEqual(
      outside.content.form, .allDay(start: .init(year: 2026, month: 10, day: 12), end: nil))
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
}
