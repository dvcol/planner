import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerScheduleZoneIntentTests: XCTestCase {
  func testZoneChangeAcceptsACurrentTimedItineraryDespiteItsCachedAllDayPresentation()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.allDay.id])
    let cached = try XCTUnwrap(choices.first)
    XCTAssertTrue(cached.allDay)
    let end = fixture.instant.addingTimeInterval(3600.5)
    guard
      case .source(.schedule(let initial)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.allDay)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .editSchedule(
            scheduleId: fixture.allDay.id,
            changes: .init(
              form: .timed(start: fixture.instant, end: end, planningTimeZone: "Asia/Tokyo")),
            expectedFieldHashes: initial.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setArchive(source: fixture.itinerary, archived: true))
      ).outcome,
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else {
      return XCTFail(
        "The archived Itinerary must now have a timed booking under its original UUID.")
    }
    let change = SetPlannerScheduleTimeZoneIntent()
    change.schedule = cached
    change.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Europe/Paris"))
    let _: Void = try await change.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let current)) = await reopened.read(
        session: session, request: .source(fixture.allDay)),
      case .source(.itinerary(let after)) = await reopened.read(
        session: session, request: .source(fixture.itinerary))
    else {
      return XCTFail("Read the exact current Schedule and its live Itinerary after reopening.")
    }
    XCTAssertEqual(current.content.source, fixture.itinerary)
    XCTAssertEqual(
      current.content.form,
      .timed(start: fixture.instant, end: end, planningTimeZone: "Europe/Paris"))
    XCTAssertEqual(after.state.archived, true)
    XCTAssertEqual(after.content.title, "Tokyo Weekend")
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.references, before.references)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testZoneChangeUsesCurrentRepeatedHourSpanAndTheTimeZoneIdentity() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let cached = try XCTUnwrap(choices.first)
    let start = try Date.ISO8601FormatStyle().parse("2026-11-01T06:30:00Z").addingTimeInterval(
      0.125)
    let end = try Date.ISO8601FormatStyle().parse("2026-11-01T07:30:00Z").addingTimeInterval(0.75)
    guard
      case .source(.schedule(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .editSchedule(
            scheduleId: fixture.timed.id,
            changes: .init(
              form: .timed(start: start, end: end, planningTimeZone: "America/New_York")),
            expectedFieldHashes: before.fieldHashes))
      ).outcome
    else {
      return XCTFail("Save an explicit repeated-hour occurrence before changing only its zone.")
    }
    let change = SetPlannerScheduleTimeZoneIntent()
    change.schedule = cached
    let zone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Etc/UTC"))
    zone.identifier = "Cached presentation, not a zone identifier"
    zone.name = "Cached timezone name"
    change.planningTimeZone = zone
    let _: Void = try await change.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let current)) = await reopened.read(
        session: session, request: .source(fixture.timed))
    else {
      return XCTFail("The current timed form must survive reopening under its exact identity.")
    }
    XCTAssertEqual(
      current.content.form,
      .timed(start: start, end: end, planningTimeZone: "Etc/UTC"))
    XCTAssertEqual(current.source, fixture.timed)
    XCTAssertEqual(current.content.source, fixture.item)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testZoneChangeRejectsCurrentAllDayMissingWrongKindAndRemovedSchedules() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let cached = try XCTUnwrap(choices.first)
    guard
      case .source(.schedule(let timed)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .editSchedule(
            scheduleId: fixture.timed.id,
            changes: .init(form: .allDay(start: .init(year: 2026, month: 11, day: 1), end: nil)),
            expectedFieldHashes: timed.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeSchedule(scheduleId: fixture.outside.id))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The cached timed choice must now name an all-day form.") }
    let change = SetPlannerScheduleTimeZoneIntent()
    change.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Europe/Paris"))
    for identifier in [cached.id, fixture.allDay.id, fixture.outside.id, fixture.item.id, UUID()] {
      change.schedule = try PlannerScheduleEntity(
        schedule: .init(kind: .schedule, id: identifier), owner: fixture.item,
        title: "Cached",
        form: .timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
      do {
        let _: Void = try await change.callAsFunction(donate: false)
        XCTFail(
          "Invalid/currently all-day choices cannot be converted or redirected by a zone edit.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Rejected zone edits cannot change the saved graph.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testPrecancelledZoneChangePreservesEverySavedValue() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let change = SetPlannerScheduleTimeZoneIntent()
    change.schedule = try XCTUnwrap(choices.first)
    change.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Europe/Paris"))
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancel must preserve the original zone and instants.") }
    let task = Task { @MainActor in
      let _: Void = try await change.callAsFunction(donate: false)
    }
    task.cancel()
    do {
      try await task.value
      XCTFail("A precancelled zone-only edit cannot mutate a booking.")
    } catch is CancellationError {
    } catch { XCTFail("Expected cancellation, received \(error).") }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancelled edits must leave readable data.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testUnavailableStorageRejectsAZoneChangeWithoutAcknowledgingIt() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let contents = Data("Keep storage obstructed.".utf8)
    try contents.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let change = SetPlannerScheduleTimeZoneIntent()
    change.schedule = try PlannerScheduleEntity(
      schedule: .init(kind: .schedule, id: UUID()), owner: .init(kind: .item, id: UUID()),
      title: "Cached", form: .timed(start: Date(), end: nil, planningTimeZone: "Asia/Tokyo"))
    change.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Europe/Paris"))
    do {
      let _: Void = try await change.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a zone edit.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedZoneChangeWithIncompleteRecoveryPreservesItsInstantsAndBlocksAnotherEdit()
    async throws
  {
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
    let change = SetPlannerScheduleTimeZoneIntent()
    change.schedule = schedule
    change.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Europe/Paris"))
    let _: Void = try await change.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    guard
      case .source(.schedule(let applied)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed))
    else { return XCTFail("The applied zone edit must remain readable.") }
    XCTAssertEqual(
      applied.content.form,
      .timed(start: fixture.instant, end: nil, planningTimeZone: "Europe/Paris"))
    change.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "UTC"))
    do {
      let _: Void = try await change.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block the next zone edit.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    await fixture.store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .source(.schedule(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed))
    else { return XCTFail("Retry must complete only the original edit.") }
    XCTAssertEqual(after.content.form, applied.content.form)
    XCTAssertEqual(after.fieldHashes, applied.fieldHashes)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
  }

  func testChangingPlanningZonePreservesTheExactStartOnlyInstantAndOtherBookings() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let change = SetPlannerScheduleTimeZoneIntent()
    change.schedule = try XCTUnwrap(choices.first)
    change.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Europe/Paris"))
    let _: Void = try await change.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.schedule(let current)) = await reopened.read(
        session: session, request: .source(fixture.timed)),
      case .source(.schedule(let outside)) = await reopened.read(
        session: session, request: .source(fixture.outside)),
      case .source(.schedule(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.allDay)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item))
    else { return XCTFail("A zone-only edit must retain every saved source and booking identity.") }
    XCTAssertEqual(current.source, fixture.timed)
    XCTAssertEqual(current.content.source, fixture.item)
    XCTAssertEqual(
      current.content.form,
      .timed(start: fixture.instant, end: nil, planningTimeZone: "Europe/Paris"))
    XCTAssertEqual(
      outside.content.form,
      .allDay(start: .init(year: 2026, month: 10, day: 12), end: nil))
    XCTAssertEqual(
      itinerary.content.form,
      .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)))
    XCTAssertEqual(item.content.estimate?.minutes, 90)
    XCTAssertEqual(item.state.globalDone, false)
    XCTAssertEqual(item.state.archived, false)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
}
