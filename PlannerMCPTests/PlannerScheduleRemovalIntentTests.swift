import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerScheduleRemovalIntentTests: XCTestCase {
  func testRemovingAnArchivedItineraryBookingPreservesItsRouteAndDirectItemBookings()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setArchive(source: fixture.itinerary, archived: true))
      ).outcome,
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else { return XCTFail("Save the archived plan and its route before removing its booking.") }
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.allDay.id])
    let removal = RemovePlannerScheduleIntent()
    removal.schedule = try XCTUnwrap(choices.first)
    let _: Void = try await removal.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let after)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.schedule(let timed)) = await reopened.read(
        session: session, request: .source(fixture.timed)),
      case .source(.schedule(let outside)) = await reopened.read(
        session: session, request: .source(fixture.outside)),
      case .failed(let missing) = await reopened.read(
        session: session, request: .source(fixture.allDay))
    else { return XCTFail("Removing a plan booking must preserve its source and child bookings.") }
    XCTAssertEqual(missing.code, "missingReference")
    XCTAssertEqual(after.content.title, "Tokyo Weekend")
    XCTAssertEqual(after.state.archived, true)
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(
      after.references,
      before.references.filter {
        if case .schedule(let identifier, _) = $0 { return identifier != fixture.allDay.id }
        return true
      })
    XCTAssertEqual(timed.content.source, fixture.item)
    XCTAssertEqual(outside.content.source, fixture.item)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testRemovalRejectsMissingWrongKindAndAlreadyRemovedIdentitiesWithoutOtherChanges()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let cached = try XCTUnwrap(choices.first)
    let removal = RemovePlannerScheduleIntent()
    removal.schedule = cached
    let _: Void = try await removal.callAsFunction(donate: false)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Retain the planner after the first removal.") }
    for identifier in [fixture.timed.id, fixture.item.id, fixture.itinerary.id, UUID()] {
      removal.schedule = try PlannerScheduleEntity(
        schedule: .init(kind: .schedule, id: identifier), owner: fixture.item,
        title: cached.title, form: .timed(start: fixture.instant, end: nil, planningTimeZone: "UTC")
      )
      do {
        let _: Void = try await removal.callAsFunction(donate: false)
        XCTFail("An invalid Schedule choice cannot target its owner or another booking.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Rejected removals must preserve surviving data.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testPrecancelledRemovalPreservesTheBookingAndItsOwner() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let removal = RemovePlannerScheduleIntent()
    removal.schedule = try XCTUnwrap(choices.first)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancellation must preserve the existing booking.") }
    let task = Task { @MainActor in
      let _: Void = try await removal.callAsFunction(donate: false)
    }
    task.cancel()
    do {
      try await task.value
      XCTFail("A precancelled invocation cannot remove a Schedule.")
    } catch is CancellationError {
    } catch { XCTFail("Expected cancellation, received \(error).") }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancelled removal must leave readable data.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testUnavailableStorageRejectsRemovalWithoutClaimingSuccess() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let contents = Data("Keep unavailable storage obstructed.".utf8)
    try contents.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let removal = RemovePlannerScheduleIntent()
    removal.schedule = try PlannerScheduleEntity(
      schedule: .init(kind: .schedule, id: UUID()), owner: .init(kind: .item, id: UUID()),
      title: "Cached", form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil))
    do {
      let _: Void = try await removal.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge Schedule removal.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedRemovalWithIncompleteRecoveryBlocksAnotherRemovalUntilExplicitRetry()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id, fixture.outside.id])
    XCTAssertEqual(choices.map(\.id), [fixture.timed.id, fixture.outside.id])
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let removal = RemovePlannerScheduleIntent()
    removal.schedule = try XCTUnwrap(choices.first)
    let _: Void = try await removal.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    guard
      case .failed(let absent) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed)),
      case .source(.schedule(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.outside))
    else { return XCTFail("The first removal is applied even though recovery is incomplete.") }
    XCTAssertEqual(absent.code, "missingReference")
    removal.schedule = try XCTUnwrap(choices.last)
    do {
      let _: Void = try await removal.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block another removal.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    await fixture.store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .source(.schedule(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.outside)),
      case .failed(let stillAbsent) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed))
    else {
      return XCTFail("Explicit retry must complete the original removal without repeating it.")
    }
    XCTAssertEqual(after.fieldHashes, retained.fieldHashes)
    XCTAssertEqual(stillAbsent.code, "missingReference")
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
  }

  func testRemovingOneItemBookingPreservesItsOwnerOtherBookingsAndItineraryReference()
    async throws
  {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true))
      ).outcome
    else { return XCTFail("The Item's independent state must be saved first.") }
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.timed.id])
    let removal = RemovePlannerScheduleIntent()
    removal.schedule = try XCTUnwrap(choices.first)
    let _: Void = try await removal.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.schedule(let other)) = await reopened.read(
        session: session, request: .source(fixture.outside)),
      case .source(.schedule(let retained)) = await reopened.read(
        session: session, request: .source(fixture.allDay)),
      case .failed(let missing) = await reopened.read(
        session: session, request: .source(fixture.timed))
    else { return XCTFail("Only the selected booking should be absent after reopening.") }
    XCTAssertEqual(missing.code, "missingReference")
    XCTAssertEqual(item.content.title, "Museum")
    XCTAssertEqual(item.content.estimate?.minutes, 90)
    XCTAssertEqual(item.state.globalDone, true)
    XCTAssertEqual(item.state.archived, false)
    XCTAssertEqual(other.content.source, fixture.item)
    XCTAssertEqual(retained.content.source, fixture.itinerary)
    XCTAssertTrue(
      itinerary.references.contains {
        if case .itineraryEntry(_, _, let source) = $0 { return source == fixture.item }
        return false
      })
    let remaining = try await query.suggestedEntities()
    XCTAssertEqual(Set(remaining.map(\.id)), [fixture.outside.id, fixture.allDay.id])
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
}
