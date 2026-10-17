import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class SavedScheduleTimeInputTests: XCTestCase {
  func testResolvedOccurrencesPersistAndZoneOnlyEditsRetainExactSavedInstants() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerScheduleTimeFixtures").appendingPathComponent(
        UUID().uuidString)
    print("Planner Schedule-time fixture directory: \(directory.path)")
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    func readSchedule(_ source: PlannerEntityReference) async throws -> PlannerScheduleSourceRead {
      guard
        case .source(.schedule(let schedule)) = await planner.read(
          session: session, request: .source(source))
      else { throw CancellationError() }
      return schedule
    }
    let created = try await save(.createItem(content: .init(title: "Clock change visit")))
    let item = try XCTUnwrap(created.generated.first)
    let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
    let formatter = ISO8601DateFormatter()
    let earlierStart = try XCTUnwrap(formatter.date(from: "2026-11-01T05:45:00Z"))
    let earlierEnd = try XCTUnwrap(formatter.date(from: "2026-11-01T05:15:00Z"))
    let laterEnd = try XCTUnwrap(formatter.date(from: "2026-11-01T06:15:00Z"))
    var start = SavedScheduleTimeInput(proposedInstant: earlierStart, planningTimeZone: newYork)
    var end = SavedScheduleTimeInput(proposedInstant: laterEnd, planningTimeZone: newYork)
    XCTAssertTrue(start.selectOccurrence(earlierStart))
    XCTAssertTrue(end.selectOccurrence(laterEnd))
    let form = PlannerScheduleForm.timed(
      start: try XCTUnwrap(start.resolvedInstant), end: try XCTUnwrap(end.resolvedInstant),
      planningTimeZone: newYork.identifier)
    let scheduled = try await save(.createSchedule(source: item, form: form))
    let schedule = try XCTUnwrap(scheduled.generated.first)
    let saved = try await readSchedule(schedule)
    XCTAssertEqual(
      saved.content.form,
      .timed(
        start: earlierStart, end: laterEnd, planningTimeZone: "America/New_York"))
    XCTAssertTrue(end.selectOccurrence(earlierEnd))
    let rejected = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editSchedule(
          scheduleId: schedule.id,
          changes: .init(
            form: .timed(
              start: try XCTUnwrap(start.resolvedInstant), end: try XCTUnwrap(end.resolvedInstant),
              planningTimeZone: newYork.identifier)), expectedFieldHashes: saved.fieldHashes)))
    guard case .rejected(let reason) = rejected.outcome else {
      XCTFail("An earlier occurrence before Start must leave the saved Schedule unchanged.")
      return
    }
    XCTAssertEqual(reason.code, "invalidInput")
    let unchanged = try await readSchedule(schedule)
    XCTAssertEqual(unchanged.content.form, saved.content.form)
    XCTAssertEqual(unchanged.fieldHashes, saved.fieldHashes)

    let exactStart = earlierStart.addingTimeInterval(0.125)
    let exactEnd = laterEnd.addingTimeInterval(0.875)
    _ = try await save(
      .editSchedule(
        scheduleId: schedule.id,
        changes: .init(
          form: .timed(
            start: exactStart, end: exactEnd, planningTimeZone: newYork.identifier)),
        expectedFieldHashes: saved.fieldHashes))
    let exact = try await readSchedule(schedule)
    guard case .timed(let storedStart, let storedEnd, _) = exact.content.form else {
      XCTFail("The saved appointment must retain its timed form.")
      return
    }
    start = SavedScheduleTimeInput(savedInstant: storedStart, planningTimeZone: newYork)
    end = SavedScheduleTimeInput(savedInstant: try XCTUnwrap(storedEnd), planningTimeZone: newYork)
    start.setPickerValue(start.pickerValue.addingTimeInterval(45))
    start.changePlanningTimeZone(paris)
    end.changePlanningTimeZone(paris)
    _ = try await save(
      .editSchedule(
        scheduleId: schedule.id,
        changes: .init(
          form: .timed(
            start: try XCTUnwrap(start.resolvedInstant), end: try XCTUnwrap(end.resolvedInstant),
            planningTimeZone: paris.identifier)), expectedFieldHashes: exact.fieldHashes))
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else { throw CancellationError() }
    _ = try await save(
      .editItem(
        sourceId: item.id, changes: .init(notes: .set("Unrelated source edit")),
        expectedFieldHashes: originalItem.fieldHashes))
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.schedule(let readback)) = await reopened.read(
        session: reopenedSession, request: .source(schedule))
    else { throw CancellationError() }
    XCTAssertEqual(readback.source, schedule)
    XCTAssertEqual(readback.content.source, item)
    XCTAssertEqual(
      readback.content.form,
      .timed(
        start: exactStart, end: exactEnd, planningTimeZone: "Europe/Paris"))
  }

  func testNonexistentNewYorkMinuteStaysEnteredAndCannotResolve() throws {
    let planningTimeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let formatter = ISO8601DateFormatter()
    let proposedInstant = try XCTUnwrap(formatter.date(from: "2026-03-08T06:30:00Z"))
    let enteredCivilMinute = try XCTUnwrap(formatter.date(from: "2026-03-08T02:30:00Z"))
    var input = SavedScheduleTimeInput(
      proposedInstant: proposedInstant, planningTimeZone: planningTimeZone)
    input.setPickerValue(enteredCivilMinute)
    XCTAssertEqual(input.pickerValue, enteredCivilMinute)
    XCTAssertEqual(input.resolution, .nonexistent)
    XCTAssertNil(input.selectedOccurrence)
    XCTAssertNil(input.resolvedInstant)
  }

  func testRepeatedNewYorkMinuteRequiresAnExplicitCurrentOccurrence() throws {
    let planningTimeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let formatter = ISO8601DateFormatter()
    let earlier = try XCTUnwrap(formatter.date(from: "2026-11-01T05:30:00Z"))
    let later = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:00Z"))
    let civilMinute = try XCTUnwrap(formatter.date(from: "2026-11-01T01:30:00Z"))
    let nextCivilMinute = try XCTUnwrap(formatter.date(from: "2026-11-01T02:30:00Z"))
    let nextInstant = try XCTUnwrap(formatter.date(from: "2026-11-01T07:30:00Z"))
    var input = SavedScheduleTimeInput(
      proposedInstant: earlier, planningTimeZone: planningTimeZone)

    XCTAssertEqual(input.pickerValue, civilMinute)
    XCTAssertEqual(input.resolution, .repeated([earlier, later]))
    XCTAssertNil(input.selectedOccurrence)
    XCTAssertNil(input.resolvedInstant)
    XCTAssertFalse(input.selectOccurrence(nextInstant))
    XCTAssertNil(input.resolvedInstant)
    XCTAssertTrue(input.selectOccurrence(earlier))
    XCTAssertEqual(input.resolvedInstant, earlier)
    XCTAssertTrue(input.selectOccurrence(later))
    XCTAssertEqual(input.resolvedInstant, later)
    XCTAssertFalse(input.selectOccurrence(nextInstant))
    XCTAssertEqual(input.selectedOccurrence, later)
    XCTAssertEqual(input.resolvedInstant, later)

    input.setPickerValue(nextCivilMinute)
    XCTAssertEqual(input.resolution, .unique(nextInstant))
    XCTAssertFalse(input.selectOccurrence(later))
    XCTAssertEqual(input.resolvedInstant, nextInstant)
    input.setPickerValue(civilMinute)
    XCTAssertEqual(input.resolution, .repeated([earlier, later]))
    XCTAssertNil(input.selectedOccurrence)
    XCTAssertNil(input.resolvedInstant)
  }

  func testLordHoweRepeatFindsBothHalfHourOccurrences() throws {
    let planningTimeZone = try XCTUnwrap(TimeZone(identifier: "Australia/Lord_Howe"))
    let formatter = ISO8601DateFormatter()
    let earlier = try XCTUnwrap(formatter.date(from: "2026-04-04T14:45:00Z"))
    let later = try XCTUnwrap(formatter.date(from: "2026-04-04T15:15:00Z"))
    let civilMinute = try XCTUnwrap(formatter.date(from: "2026-04-05T01:45:00Z"))
    var input = SavedScheduleTimeInput(
      proposedInstant: earlier, planningTimeZone: planningTimeZone)

    XCTAssertEqual(input.pickerValue, civilMinute)
    XCTAssertEqual(input.resolution, .repeated([earlier, later]))
    XCTAssertNil(input.selectedOccurrence)
    XCTAssertNil(input.resolvedInstant)
    XCTAssertTrue(input.selectOccurrence(later))
    XCTAssertEqual(input.resolvedInstant, later)
  }

  func testUnchangedSavedOccurrenceRetainsFractionsUntilExplicitClockOrOccurrenceEdit() throws {
    let planningTimeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let formatter = ISO8601DateFormatter()
    let earlier = try XCTUnwrap(formatter.date(from: "2026-11-01T05:30:00Z"))
    let later = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:00Z"))
    let civilMinute = try XCTUnwrap(formatter.date(from: "2026-11-01T01:30:00Z"))
    let changedCivilMinute = try XCTUnwrap(formatter.date(from: "2026-11-01T01:31:00Z"))
    let changedEarlier = try XCTUnwrap(formatter.date(from: "2026-11-01T05:31:00Z"))
    let savedInstant = later.addingTimeInterval(0.125)
    var input = SavedScheduleTimeInput(
      savedInstant: savedInstant, planningTimeZone: planningTimeZone)

    XCTAssertEqual(input.pickerValue, civilMinute)
    XCTAssertEqual(input.selectedOccurrence, later)
    XCTAssertEqual(input.resolvedInstant, savedInstant)
    input.setPickerValue(civilMinute.addingTimeInterval(49.75))
    XCTAssertEqual(input.pickerValue, civilMinute)
    XCTAssertEqual(input.selectedOccurrence, later)
    XCTAssertEqual(input.resolvedInstant, savedInstant)
    XCTAssertTrue(input.selectOccurrence(later))
    XCTAssertEqual(input.resolvedInstant, savedInstant)

    input.setPickerValue(changedCivilMinute)
    XCTAssertNil(input.resolvedInstant)
    XCTAssertTrue(input.selectOccurrence(changedEarlier))
    XCTAssertEqual(input.resolvedInstant, changedEarlier)
    input.setPickerValue(civilMinute)
    XCTAssertNil(input.resolvedInstant)
    XCTAssertTrue(input.selectOccurrence(later))
    XCTAssertEqual(input.resolvedInstant, later)

    var changedOccurrence = SavedScheduleTimeInput(
      savedInstant: savedInstant, planningTimeZone: planningTimeZone)
    XCTAssertTrue(changedOccurrence.selectOccurrence(earlier))
    XCTAssertEqual(changedOccurrence.resolvedInstant, earlier)
    XCTAssertTrue(changedOccurrence.selectOccurrence(later))
    XCTAssertEqual(changedOccurrence.resolvedInstant, later)
  }

  func testPlanningZoneChangesDistinguishSavedAuthorityFromNewAndRescheduledInput() throws {
    let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
    let formatter = ISO8601DateFormatter()
    let earlier = try XCTUnwrap(formatter.date(from: "2026-11-01T05:30:00Z"))
    let later = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:00Z"))
    let newYorkCivilMinute = try XCTUnwrap(formatter.date(from: "2026-11-01T01:30:00Z"))
    let parisCivilMinute = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:00Z"))
    let savedInstant = earlier.addingTimeInterval(0.125)
    var saved = SavedScheduleTimeInput(savedInstant: savedInstant, planningTimeZone: .gmt)
    XCTAssertEqual(saved.resolvedInstant, savedInstant)
    saved.changePlanningTimeZone(newYork)
    XCTAssertEqual(saved.pickerValue, newYorkCivilMinute)
    XCTAssertEqual(saved.resolution, .repeated([earlier, later]))
    XCTAssertEqual(saved.selectedOccurrence, earlier)
    XCTAssertEqual(saved.resolvedInstant, savedInstant)
    saved.changePlanningTimeZone(paris)
    XCTAssertEqual(saved.pickerValue, parisCivilMinute)
    XCTAssertEqual(saved.resolvedInstant, savedInstant)
    saved.changePlanningTimeZone(newYork)
    XCTAssertEqual(saved.resolvedInstant, savedInstant)
    XCTAssertEqual(saved.selectedOccurrence, earlier)

    var proposed = SavedScheduleTimeInput(proposedInstant: earlier, planningTimeZone: .gmt)
    proposed.changePlanningTimeZone(newYork)
    XCTAssertEqual(proposed.pickerValue, newYorkCivilMinute)
    XCTAssertEqual(proposed.resolution, .repeated([earlier, later]))
    XCTAssertNil(proposed.selectedOccurrence)
    XCTAssertNil(proposed.resolvedInstant)

    var rescheduled = SavedScheduleTimeInput(savedInstant: savedInstant, planningTimeZone: .gmt)
    rescheduled.setPickerValue(earlier.addingTimeInterval(60))
    rescheduled.setPickerValue(earlier)
    XCTAssertEqual(rescheduled.resolvedInstant, earlier)
    rescheduled.changePlanningTimeZone(newYork)
    XCTAssertEqual(rescheduled.pickerValue, newYorkCivilMinute)
    XCTAssertEqual(rescheduled.resolution, .repeated([earlier, later]))
    XCTAssertNil(rescheduled.selectedOccurrence)
    XCTAssertNil(rescheduled.resolvedInstant)
  }

  func testUnresolvedCivilMinuteIsReinterpretedWhenItsPlanningZoneChanges() throws {
    let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
    let formatter = ISO8601DateFormatter()
    let proposed = try XCTUnwrap(formatter.date(from: "2026-03-08T06:30:00Z"))
    let civilMinute = try XCTUnwrap(formatter.date(from: "2026-03-08T02:30:00Z"))
    let tokyoInstant = try XCTUnwrap(formatter.date(from: "2026-03-07T17:30:00Z"))
    var input = SavedScheduleTimeInput(proposedInstant: proposed, planningTimeZone: newYork)
    input.setPickerValue(civilMinute)
    XCTAssertEqual(input.resolution, .nonexistent)
    input.changePlanningTimeZone(tokyo)
    XCTAssertEqual(input.pickerValue, civilMinute)
    XCTAssertEqual(input.resolution, .unique(tokyoInstant))
    XCTAssertEqual(input.resolvedInstant, tokyoInstant)
  }

  func testOrdinaryUniqueMinutesNormalizePickerSecondsWithoutGuessingAnotherMinute() throws {
    let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
    let formatter = ISO8601DateFormatter()
    let proposed = try XCTUnwrap(formatter.date(from: "2026-10-09T01:00:00Z"))
    let civilMinute = try XCTUnwrap(formatter.date(from: "2026-10-09T10:00:00Z"))
    let changedCivilMinute = try XCTUnwrap(formatter.date(from: "2026-10-09T10:01:00Z"))
    let changedInstant = try XCTUnwrap(formatter.date(from: "2026-10-09T01:01:00Z"))
    var input = SavedScheduleTimeInput(
      proposedInstant: proposed.addingTimeInterval(59.75), planningTimeZone: tokyo)
    XCTAssertEqual(input.pickerValue, civilMinute)
    XCTAssertEqual(input.resolution, .unique(proposed))
    XCTAssertEqual(input.resolvedInstant, proposed)
    input.setPickerValue(changedCivilMinute.addingTimeInterval(12.125))
    XCTAssertEqual(input.pickerValue, changedCivilMinute)
    XCTAssertEqual(input.resolution, .unique(changedInstant))
    XCTAssertEqual(input.resolvedInstant, changedInstant)
  }

  func testUnavailableInstantsRemainUnresolvedUntilCorrected() throws {
    let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let formatter = ISO8601DateFormatter()
    let civilMinute = try XCTUnwrap(formatter.date(from: "2026-11-01T02:30:00Z"))
    let resolved = try XCTUnwrap(formatter.date(from: "2026-11-01T07:30:00Z"))
    var input = SavedScheduleTimeInput(
      proposedInstant: Date(timeIntervalSinceReferenceDate: .infinity), planningTimeZone: .gmt)
    XCTAssertEqual(input.resolution, .unavailable)
    XCTAssertNil(input.resolvedInstant)
    input.changePlanningTimeZone(newYork)
    XCTAssertEqual(input.resolution, .unavailable)
    XCTAssertNil(input.resolvedInstant)
    input.setPickerValue(civilMinute)
    XCTAssertEqual(input.resolvedInstant, resolved)
    input.setPickerValue(Date(timeIntervalSinceReferenceDate: .nan))
    XCTAssertEqual(input.resolution, .unavailable)
    XCTAssertNil(input.selectedOccurrence)
    XCTAssertNil(input.resolvedInstant)
  }
}
