import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerTimedScheduleOptionsTests: XCTestCase {
  func testTimedChoicesExcludeAllDayAndKeepArchivedOwnersWithLiveTitles() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { throw CancellationError() }
    for command in [
      PlannerCommand.editItem(
        sourceId: fixture.item.id, changes: .init(title: .set("Renamed museum")),
        expectedFieldHashes: current.fieldHashes),
      .setArchive(source: fixture.item, archived: true),
    ] {
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let provider = PlannerTimedScheduleOptionsProvider()
    provider.plannerStore = fixture.store
    let choices = try await provider.results()
    XCTAssertEqual(choices.map(\.id), [fixture.timed.id])
    XCTAssertEqual(choices.first?.title, "Renamed museum")
    XCTAssertEqual(choices.first?.allDay, false)
    XCTAssertEqual(choices.first?.start, fixture.instant)
    XCTAssertEqual(choices.first?.planningTimeZone?.id, "Asia/Tokyo")
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
  }
  func testChoicesFollowCurrentFormConversionsAndRemovalWithoutChangingSources() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let provider = PlannerTimedScheduleOptionsProvider()
    provider.plannerStore = fixture.store
    let initial = try await provider.results()
    XCTAssertEqual(initial.map(\.id), [fixture.timed.id])
    guard
      case .source(.schedule(let oldTimed)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.timed)),
      case .source(.schedule(let oldAllDay)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.allDay))
    else { throw CancellationError() }
    for command in [
      PlannerCommand.editSchedule(
        scheduleId: fixture.timed.id,
        changes: .init(form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil)),
        expectedFieldHashes: oldTimed.fieldHashes),
      .editSchedule(
        scheduleId: fixture.allDay.id,
        changes: .init(form: .timed(start: fixture.instant, end: nil, planningTimeZone: "Etc/UTC")),
        expectedFieldHashes: oldAllDay.fieldHashes),
      .setArchive(source: fixture.itinerary, archived: true),
    ] {
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    let converted = try await provider.results()
    XCTAssertEqual(converted.map(\.id), [fixture.allDay.id])
    XCTAssertEqual(converted.first?.title, "Tokyo Weekend")
    XCTAssertEqual(converted.first?.sourceType, "Itinerary")
    XCTAssertEqual(converted.first?.planningTimeZone?.id, "Etc/UTC")
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeSchedule(scheduleId: fixture.allDay.id))
      ).outcome
    else { throw CancellationError() }
    let empty = try await provider.results()
    XCTAssertTrue(empty.isEmpty)
    let query = PlannerScheduleEntityQuery()
    query.plannerStore = fixture.store
    let ordinary = try await query.suggestedEntities()
    XCTAssertEqual(Set(ordinary.map(\.id)), [fixture.timed.id, fixture.outside.id])
    XCTAssertTrue(ordinary.allSatisfy(\.allDay))
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testPrecancelledAndUnavailableProviderReadsPreserveDataAndFailTruthfully() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let provider = PlannerTimedScheduleOptionsProvider()
    provider.plannerStore = fixture.store
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let task = Task { try await provider.results() }
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("A cancelled provider read must not report a complete choice list.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let obstruction = Data("Unavailable store parent".utf8)
    try obstruction.write(to: directory.appending(path: "store"))
    provider.plannerStore = unavailable
    do {
      _ = try await provider.results()
      XCTFail("An unavailable store must not masquerade as an empty timed list.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: directory.appending(path: "store")), obstruction)
    XCTAssertFalse(unavailable.isReady)
    XCTAssertNotNil(unavailable.openingFailure)
    XCTAssertFalse(unavailable.isSaving)
  }

  func testProviderReadsThroughIncompleteRecoveryWithoutAcknowledgingTheOperation() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    await fixture.store.open()
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let completion = SetPlannerItemCompletionIntent()
    completion.item = .init(id: fixture.item.id, title: "Cached", done: false, archived: false)
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operation = try XCTUnwrap(fixture.store.incompleteRecoveryOperationIdentifiers.first)
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let before) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    let provider = PlannerTimedScheduleOptionsProvider()
    provider.plannerStore = fixture.store
    let choices = try await provider.results()
    XCTAssertEqual(choices.map(\.id), [fixture.timed.id])
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operation])
    guard case .exported(let after) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    await fixture.store.retryIncompleteRecovery()
    XCTAssertFalse(fixture.store.recoveryBlocked)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operation)
    else { return XCTFail("Only explicit recovery can acknowledge this operation.") }
  }
}
