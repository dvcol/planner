import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerScheduleMutationSafetyTests: XCTestCase {
  func testAllCreationActionsRejectMissingWrongKindAndDeletedOwners() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await backup(planner: fixture.planner, session: fixture.session)
    for mode in CreationMode.allCases {
      for identifier in [UUID(), fixture.list.id] {
        do {
          _ = try await create(mode, fixture: fixture, ownerIdentifier: identifier)
          XCTFail("Missing and wrong-kind owners cannot produce a booking.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    let after = try await backup(planner: fixture.planner, session: fixture.session)
    XCTAssertEqual(after, before)
    for source in [fixture.item, fixture.itinerary] {
      let command = PlannerCommand.deleteSource(source: source)
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: command),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    let deleted = try await backup(planner: fixture.planner, session: fixture.session)
    for mode in CreationMode.allCases {
      do {
        _ = try await create(mode, fixture: fixture)
        XCTFail("A removed owner cannot be resurrected through Schedule creation.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let retained = try await backup(planner: fixture.planner, session: fixture.session)
    XCTAssertEqual(retained, deleted)
  }

  func testEveryCreationRejectsPrecancellationAndUnavailableStorage() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await backup(planner: fixture.planner, session: fixture.session)
    for mode in CreationMode.allCases {
      let request = Task { _ = try await self.create(mode, fixture: fixture) }
      request.cancel()
      do {
        try await request.value
        XCTFail("Precancelled creation must not save.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(planner: fixture.planner, session: fixture.session)
    XCTAssertEqual(after, before)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let contents = Data("The store parent is a file.".utf8)
    try contents.write(to: parent)
    AppDependencyManager.shared.add(dependency: unavailable)
    for mode in CreationMode.allCases {
      do {
        _ = try await create(mode, fixture: fixture)
        XCTFail("Unavailable storage cannot acknowledge a created Schedule.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertFalse(unavailable.isReady)
    XCTAssertEqual(try Data(contentsOf: parent), contents)
  }

  func testAllDayCreationRejectsInvalidIncompleteNonGregorianAndReversedDates() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await backup(planner: fixture.planner, session: fixture.session)
    let invalid: [DateComponents] = [
      .init(year: 2026, month: 10), .init(year: 2026, month: 2, day: 30),
      .init(year: 0, month: 10, day: 9), .init(era: 0, year: 2026, month: 10, day: 9),
      .init(calendar: Calendar(identifier: .islamic), year: 2026, month: 10, day: 9),
    ]
    for mode in [CreationMode.allDayItem, .allDayItinerary] {
      for start in invalid {
        do {
          _ = try await create(mode, fixture: fixture, start: start)
          XCTFail("Invalid all-day dates cannot normalize into saved dates.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      do {
        _ = try await create(
          mode, fixture: fixture,
          start: .init(year: 2026, month: 12, day: 2), end: .init(year: 2026, month: 12, day: 1))
        XCTFail("An inclusive End cannot precede Start.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(planner: fixture.planner, session: fixture.session)
    XCTAssertEqual(after, before)
  }

  func testEveryCreationFailsBeforeCommitWithoutAddingAnySchedule() async throws {
    for mode in CreationMode.allCases {
      let fixture = try await makeEstimateResetIntentFixture()
      await fixture.store.open()
      XCTAssertTrue(fixture.store.isReady)
      let before = try await backup(planner: fixture.planner, session: fixture.session)
      let recovery = fixture.configuration.recoveryDirectoryURL
      let retained = recovery.deletingLastPathComponent().appending(
        path: "retained-schedule-recovery")
      try FileManager.default.moveItem(at: recovery, to: retained)
      try Data("Obstruct recovery before native creation.".utf8).write(to: recovery)
      defer {
        try? FileManager.default.removeItem(at: recovery)
        try? FileManager.default.moveItem(at: retained, to: recovery)
      }
      do {
        _ = try await create(mode, fixture: fixture)
        XCTFail("A precommit failure cannot acknowledge a new Schedule.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      let after = try await backup(planner: fixture.planner, session: fixture.session)
      XCTAssertEqual(after, before)
      XCTAssertFalse(fixture.store.isSaving)
    }
  }

  func testEveryCreationReturnsItsAppliedIdentityWhenRecoveryIsIncomplete() async throws {
    for mode in CreationMode.allCases {
      let fixture = try await makeEstimateResetIntentFixture()
      await fixture.store.open()
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) {
        notification in obstruction.observe(notification)
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let created = try await create(mode, fixture: fixture)
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      do {
        _ = try await create(mode, fixture: fixture)
        XCTFail("Incomplete recovery blocks another creation.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .source(.schedule(let saved)) = await reopened.read(
          session: session,
          request: .source(.init(kind: .schedule, id: created.id)))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content.source, mode.owner(in: fixture))
      XCTAssertEqual(saved.content.form, expectedForm(allDay: mode.isAllDay))
      let beforeRepair = try await backup(planner: reopened, session: session)
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: session, operationId: operationIdentifier)
      else { return XCTFail("Repair must acknowledge the original creation.") }
      let afterRepair = try await backup(planner: reopened, session: session)
      XCTAssertEqual(afterRepair, beforeRepair)
      let query = PlannerScheduleEntityQuery()
      query.plannerStore = fixture.store
      let bookings = try await query.suggestedEntities()
      XCTAssertEqual(bookings.count, 3)
      XCTAssertEqual(bookings.filter { $0.id == created.id }.count, 1)
    }
  }

  func testReplacementsRejectMissingWrongKindAndRemovedSchedules() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    _ = try await fixture.store.executeAppIntent(.removeSchedule(scheduleId: fixture.outside.id))
    let before = try await backup(planner: fixture.planner, session: fixture.session)
    for mode in ReplacementMode.allCases {
      for identifier in [UUID(), fixture.item.id, fixture.itinerary.id, fixture.outside.id] {
        do {
          _ = try await replace(mode, fixture: fixture, scheduleIdentifier: identifier)
          XCTFail("Invalid Schedules cannot redirect replacement to another booking or owner.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    let after = try await backup(planner: fixture.planner, session: fixture.session)
    XCTAssertEqual(after, before)
  }

  func testInvalidReplacementFormsPreserveTheEntirePreviouslySavedForm() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let before = try await backup(planner: fixture.planner, session: fixture.session)
    for mode in ReplacementMode.allCases {
      for start in [
        DateComponents(year: 2026, month: 2, day: 30, hour: 10, minute: 0),
        DateComponents(year: 2026, month: 10),
      ] {
        do {
          _ = try await replace(mode, fixture: fixture, start: start)
          XCTFail("Invalid complete replacement must leave the old form intact.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      do {
        _ = try await replace(
          mode, fixture: fixture,
          end: .init(year: 2026, month: 11, day: 30, hour: 10, minute: 0))
        XCTFail("A replacement End cannot precede its new Start.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(planner: fixture.planner, session: fixture.session)
    XCTAssertEqual(after, before)
  }

  func testReplacementsRespectPrecancellationAndUnavailableStorage() async throws {
    let fixture = try await makeScheduleReadIntentFixture()
    let before = try await backup(planner: fixture.planner, session: fixture.session)
    for mode in ReplacementMode.allCases {
      let request = Task { _ = try await self.replace(mode, fixture: fixture) }
      request.cancel()
      do {
        try await request.value
        XCTFail("Precancelled replacements must not apply.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(planner: fixture.planner, session: fixture.session)
    XCTAssertEqual(after, before)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let contents = Data("The store parent is a file.".utf8)
    try contents.write(to: parent)
    AppDependencyManager.shared.add(dependency: unavailable)
    for mode in ReplacementMode.allCases {
      do {
        _ = try await replace(mode, fixture: fixture)
        XCTFail("Unavailable storage cannot acknowledge a replacement.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertFalse(unavailable.isReady)
    XCTAssertEqual(try Data(contentsOf: parent), contents)
  }

  func testReplacementsFailBeforeCommitWithoutChangingAnySavedForm() async throws {
    for mode in ReplacementMode.allCases {
      let fixture = try await makeScheduleReadIntentFixture()
      await fixture.store.open()
      XCTAssertTrue(fixture.store.isReady)
      let before = try await backup(planner: fixture.planner, session: fixture.session)
      let recovery = fixture.configuration.recoveryDirectoryURL
      let retained = recovery.deletingLastPathComponent().appending(
        path: "retained-replacement-recovery")
      try FileManager.default.moveItem(at: recovery, to: retained)
      try Data("Obstruct recovery before native replacement.".utf8).write(to: recovery)
      defer {
        try? FileManager.default.removeItem(at: recovery)
        try? FileManager.default.moveItem(at: retained, to: recovery)
      }
      do {
        _ = try await replace(mode, fixture: fixture)
        XCTFail("A precommit failure cannot acknowledge a replacement.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      let after = try await backup(planner: fixture.planner, session: fixture.session)
      XCTAssertEqual(after, before)
      XCTAssertFalse(fixture.store.isSaving)
    }
  }

  func testReplacementsRetainAppliedFormsWhenRecoveryIsIncomplete() async throws {
    for mode in ReplacementMode.allCases {
      let fixture = try await makeScheduleReadIntentFixture()
      await fixture.store.open()
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) {
        notification in obstruction.observe(notification)
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let replaced = try await replace(mode, fixture: fixture)
      XCTAssertEqual(replaced.id, fixture.allDay.id)
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      do {
        _ = try await replace(mode, fixture: fixture)
        XCTFail("Incomplete recovery blocks a second replacement.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .source(.schedule(let saved)) = await reopened.read(
          session: session, request: .source(fixture.allDay)),
        case .source(.schedule(let unchanged)) = await reopened.read(
          session: session, request: .source(fixture.timed))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content.source, fixture.itinerary)
      XCTAssertEqual(saved.content.form, expectedForm(allDay: mode == .allDay))
      XCTAssertEqual(
        unchanged.content.form,
        PlannerScheduleForm.timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
      let beforeRepair = try await backup(planner: reopened, session: session)
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: session, operationId: operationIdentifier)
      else { return XCTFail("Repair must acknowledge the original replacement.") }
      let afterRepair = try await backup(planner: reopened, session: session)
      XCTAssertEqual(afterRepair, beforeRepair)
    }
  }

  private enum CreationMode: CaseIterable {
    case timedItem, allDayItem, timedItinerary, allDayItinerary
    var isAllDay: Bool { self == .allDayItem || self == .allDayItinerary }
    func owner(in fixture: EstimateResetIntentFixture) -> PlannerEntityReference {
      switch self {
      case .timedItem, .allDayItem: fixture.item
      case .timedItinerary, .allDayItinerary: fixture.itinerary
      }
    }
  }
  private enum ReplacementMode: CaseIterable { case timed, allDay }

  private func create(
    _ mode: CreationMode, fixture: EstimateResetIntentFixture,
    ownerIdentifier: UUID? = nil, start: DateComponents? = nil, end: DateComponents? = nil
  ) async throws -> PlannerScheduleEntity {
    let owner = mode.owner(in: fixture)
    let identifier = ownerIdentifier ?? owner.id
    switch mode {
    case .timedItem:
      let action = CreatePlannerTimedItemScheduleIntent()
      action.item = .init(id: identifier, title: "Cached", done: true, archived: true)
      action.start = start ?? .init(year: 2026, month: 12, day: 1, hour: 10, minute: 0)
      action.end = end
      action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
      return try await action.callAsFunction(donate: false)
    case .timedItinerary:
      let action = CreatePlannerTimedItineraryScheduleIntent()
      action.itinerary = .init(id: identifier, title: "Cached", archived: true)
      action.start = start ?? .init(year: 2026, month: 12, day: 1, hour: 10, minute: 0)
      action.end = end
      action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
      return try await action.callAsFunction(donate: false)
    case .allDayItem:
      let action = CreatePlannerAllDayItemScheduleIntent()
      action.item = .init(id: identifier, title: "Cached", done: true, archived: true)
      action.startDay = start ?? .init(year: 2026, month: 12, day: 1)
      action.endDay = end
      return try await action.callAsFunction(donate: false)
    case .allDayItinerary:
      let action = CreatePlannerAllDayItineraryScheduleIntent()
      action.itinerary = .init(id: identifier, title: "Cached", archived: true)
      action.startDay = start ?? .init(year: 2026, month: 12, day: 1)
      action.endDay = end
      return try await action.callAsFunction(donate: false)
    }
  }

  private func replace(
    _ mode: ReplacementMode, fixture: ScheduleReadIntentFixture,
    scheduleIdentifier: UUID? = nil, start: DateComponents? = nil, end: DateComponents? = nil
  ) async throws -> PlannerScheduleEntity {
    let schedule = try PlannerScheduleEntity(
      schedule: .init(kind: .schedule, id: scheduleIdentifier ?? fixture.allDay.id),
      owner: fixture.item, title: "Cached",
      form: .timed(start: fixture.instant, end: nil, planningTimeZone: "Asia/Tokyo"))
    switch mode {
    case .timed:
      let action = SetPlannerScheduleTimedFormIntent()
      action.schedule = schedule
      action.start = start ?? .init(year: 2026, month: 12, day: 1, hour: 10, minute: 0)
      action.end = end
      action.planningTimeZone = try XCTUnwrap(PlannerTimeZoneEntity(identifier: "Asia/Tokyo"))
      return try await action.callAsFunction(donate: false)
    case .allDay:
      let action = SetPlannerScheduleAllDayFormIntent()
      action.schedule = schedule
      action.startDay = start ?? .init(year: 2026, month: 12, day: 1)
      action.endDay = end
      return try await action.callAsFunction(donate: false)
    }
  }

  private func expectedForm(allDay: Bool) -> PlannerScheduleForm {
    if allDay { return .allDay(start: .init(year: 2026, month: 12, day: 1), end: nil) }
    return .timed(
      start: Date(timeIntervalSince1970: 1_796_086_800), end: nil, planningTimeZone: "Asia/Tokyo")
  }

  private func backup(planner: PlannerCore.Planner, session: PlannerDatasetSession) async throws
    -> Data
  {
    guard case .exported(let data) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    return data
  }
}
