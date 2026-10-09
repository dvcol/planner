import CryptoKit
import Foundation
import PlannerCore
import Testing

struct AllDayScheduleTests {
  @Test func inclusiveAllDayDatesRetainSourceIdentityAndIndependentRecoveryAfterReopen()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Tokyo Weekend", notes: "Keep",
              estimate: PlannerEstimate(minutes: 120, displayUnit: .hour))))
      )
      .outcome,
      let item = created.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("The source must exist before its all-day assignment.")
      return
    }
    let form = PlannerScheduleForm.allDay(
      start: PlannerCivilDate(year: 2026, month: 10, day: 9),
      end: PlannerCivilDate(year: 2026, month: 10, day: 11))
    let operationIdentifier = UUID()
    let operation = PlannerOperation(
      operationId: operationIdentifier, session: session,
      command: .createSchedule(source: item, form: form))
    guard
      case .applied(let scheduled, .complete(let checkpoint)) = await planner.execute(operation)
        .outcome,
      let schedule = scheduled.generated.first
    else {
      Issue.record("Inclusive Friday through Sunday must save as civil dates.")
      return
    }
    #expect(checkpoint == 2)
    let reopened = Planner(configuration: configuration(directory))
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.schedule(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Native and independent all-day data must survive reopening.")
      return
    }
    #expect(retained.source == schedule)
    #expect(retained.content.source == item)
    #expect(retained.content.form == form)
    #expect(retained.fieldHashes.count == 1)
    #expect(retained.fieldHashes[.form]?.value.hasPrefix("sha256-v1:") == true)
    #expect(retainedItem.fieldHashes == original.fieldHashes)
    #expect(retainedItem.updatedAt == original.updatedAt)
    #expect(retainedItem.content.notes == "Keep")
    #expect(retainedItem.content.estimate?.minutes == 120)
    #expect(recovery.decodedBackup.backup.schedules.first?.form == form)
    let savedSchedule = try #require(recovery.decodedBackup.backup.schedules.first)
    // Accepted literal all-day form bytes; only generated context identities are substituted.
    let fixtureInput =
      "506c616e6e65724669656c64486173680000000001000000000000400080000000000008010600000000000040008000000000000702000000000000400080000000000008720000000000000004666f726d1800000000000000030000000000000003656e641501180000000000000003000000000000000364617912000000000000000b00000000000000056d6f6e746812000000000000000a0000000000000004796561721200000000000007ea00000000000000046b696e64100000000000000006616c6c44617900000000000000057374617274180000000000000003000000000000000364617912000000000000000900000000000000056d6f6e746812000000000000000a0000000000000004796561721200000000000007ea"
    let boundInput = fixtureInput.replacingOccurrences(
      of: "00000000000040008000000000000801",
      with: session.datasetId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    ).replacingOccurrences(
      of: "00000000000040008000000000000702",
      with: schedule.id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    ).replacingOccurrences(
      of: "00000000000040008000000000000872",
      with: savedSchedule.lifetimeId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    )
    let characters = Array(boundInput)
    let input = try Data(
      stride(from: 0, to: characters.count, by: 2).map { index in
        try #require(UInt8(String(characters[index...index + 1]), radix: 16))
      })
    let expectedHash = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    #expect(retained.fieldHashes[.form]?.value == "sha256-v1:" + expectedHash)

    #expect(namespace.preparedProposals.isEmpty)
    let portable = try #require(
      try JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let storedSchedule = try #require((portable["schedules"] as? [[String: Any]])?.first)
    let storedForm = try #require(storedSchedule["form"] as? [String: Any])
    #expect(Set(storedForm.keys) == ["kind", "start", "end"])
    #expect(storedForm["kind"] as? String == "allDay")
    #expect(
      NSDictionary(dictionary: try #require(storedForm["start"] as? [String: Any])).isEqual(to: [
        "year": 2026, "month": 10, "day": 9,
      ]))
    #expect(
      NSDictionary(dictionary: try #require(storedForm["end"] as? [String: Any])).isEqual(to: [
        "year": 2026, "month": 10, "day": 11,
      ]))
    guard
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: operation.command)
      ).outcome
    else {
      Issue.record("Exact all-day creation replay must retain its original identity.")
      return
    }
    #expect(replay.generated == [schedule])
    #expect(replayCheckpoint == checkpoint)
  }

  @Test func rowsSelectInclusiveCivilSpansAcrossTravelWithoutMergingTheGap() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Weekend")))
      ).outcome,
      let item = created.generated.first
    else {
      Issue.record("The source must exist before its separate civil spans.")
      return
    }
    let firstForm = PlannerScheduleForm.allDay(
      start: PlannerCivilDate(year: 2026, month: 10, day: 9),
      end: PlannerCivilDate(year: 2026, month: 10, day: 11))
    let secondForm = PlannerScheduleForm.allDay(
      start: PlannerCivilDate(year: 2026, month: 10, day: 16),
      end: PlannerCivilDate(year: 2026, month: 10, day: 18))
    guard
      case .applied(let firstResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: firstForm))
      ).outcome,
      let first = firstResult.generated.first,
      case .applied(let secondResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: secondForm))
      ).outcome,
      let second = secondResult.generated.first
    else {
      Issue.record("Both separate inclusive spans must save.")
      return
    }
    let samples: [(String, String, PlannerEntityReference, PlannerScheduleForm)] = [
      ("2026-10-09T01:30:00Z", "Asia/Tokyo", first, firstForm),
      ("2026-10-09T08:30:00Z", "Europe/Paris", first, firstForm),
      ("2026-10-11T14:59:59Z", "Asia/Tokyo", first, firstForm),
      ("2026-10-11T21:59:59Z", "Europe/Paris", first, firstForm),
      ("2026-10-11T15:00:00Z", "Asia/Tokyo", second, secondForm),
      ("2026-10-11T22:00:00Z", "Europe/Paris", second, secondForm),
      ("2026-10-15T01:30:00Z", "Asia/Tokyo", second, secondForm),
      ("2026-10-18T14:59:59Z", "Asia/Tokyo", second, secondForm),
      ("2026-10-19T01:30:00Z", "Asia/Tokyo", second, secondForm),
    ]
    for (instant, zone, expected, form) in samples {
      let presentation = PlannerRowPresentationContext(
        referenceInstant: try #require(ISO8601DateFormatter().date(from: instant)),
        displayTimeZone: zone)
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session, request: .items(PlannerItemQuery(rowPresentation: presentation)))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
        let row = window.rows.first
      else {
        Issue.record("An all-day row must be readable at the supplied travel/day boundary.")
        return
      }
      #expect(window.rowPresentation == presentation)
      #expect(
        row.scheduleSummary
          == .directItem(schedule: expected, owner: item, form: form, additionalCount: 1))
    }
    let timedForm = PlannerScheduleForm.timed(
      start: try #require(ISO8601DateFormatter().date(from: "2026-10-11T01:00:00Z")),
      end: try #require(ISO8601DateFormatter().date(from: "2026-10-11T02:00:00Z")),
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let timedResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: timedForm))
      ).outcome,
      let timed = timedResult.generated.first
    else {
      Issue.record("The overlapping timed assignment must save separately.")
      return
    }
    for (instant, expected, form) in [
      ("2026-10-11T01:30:00Z", timed, timedForm), ("2026-10-11T02:00:00Z", first, firstForm),
    ] {
      let presentation = PlannerRowPresentationContext(
        referenceInstant: try #require(ISO8601DateFormatter().date(from: instant)),
        displayTimeZone: "Asia/Tokyo")
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session, request: .items(PlannerItemQuery(rowPresentation: presentation)))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
        let row = window.rows.first
      else {
        Issue.record("Mixed timed/all-day rows must retain the selected actual record.")
        return
      }
      #expect(
        row.scheduleSummary
          == .directItem(schedule: expected, owner: item, form: form, additionalCount: 2))
    }
  }

  @Test func planningZoneChangesRejectAllDayFormsWithoutSavingOrInvalidatingRows() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
    let form = PlannerScheduleForm.allDay(
      start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Friday")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createSchedule(source: item, form: form))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let original)) = await planner.read(
        session: session, request: .source(schedule)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: Date(timeIntervalSinceReferenceDate: 813_200_400),
                displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record("The all-day Schedule and row generation must exist before the zone request.")
      return
    }
    let operationIdentifier = UUID()
    guard
      case .rejected(let reason) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session,
          command: .changeScheduleZone(
            scheduleId: schedule.id, planningTimeZone: "Europe/Paris",
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else {
      Issue.record("All-day dates have no planning timezone to change.")
      return
    }
    #expect(reason.code == "invalidInput")
    #expect(reason.propertyPath == "/command/planningTimeZone")
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.schedule(let retained)) = await planner.read(
        session: session, request: .source(schedule)),
      case .rows(let rows) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The invalid zone action must leave saved data and rows unchanged.")
      return
    }
    #expect(retained.content == original.content)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(
      rows.rows.first?.scheduleSummary
        == .directItem(schedule: schedule, owner: item, form: form, additionalCount: 0))
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func invalidGregorianDatesRejectTogetherAndCompleteFormConversionsKeepIdentity()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
    let leapDate = PlannerCivilDate(year: 2024, month: 2, day: 29)
    let originalForm = PlannerScheduleForm.allDay(start: leapDate, end: nil)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Leap day", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: originalForm))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let original)) = await planner.read(
        session: session, request: .source(schedule)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery()))),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let before) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 2))
    else {
      Issue.record("Leap-day start-only form and recovery must save before validation.")
      return
    }
    let invalidDates = [
      PlannerCivilDate(year: 2023, month: 2, day: 29),
      PlannerCivilDate(year: 1900, month: 2, day: 29),
      PlannerCivilDate(year: 2026, month: 4, day: 31), PlannerCivilDate(year: 0, month: 1, day: 1),
      PlannerCivilDate(year: -1, month: 1, day: 1),
      PlannerCivilDate(year: Int.max, month: 1, day: 1),
      PlannerCivilDate(year: 2026, month: 0, day: 1),
      PlannerCivilDate(year: 2026, month: 13, day: 1),
      PlannerCivilDate(year: 2026, month: 1, day: 0),
      PlannerCivilDate(year: 2026, month: 1, day: 32),
    ]
    var invalidForms = invalidDates.map {
      (PlannerScheduleForm.allDay(start: $0, end: nil), "start")
    }
    invalidForms.append(
      (.allDay(start: leapDate, end: PlannerCivilDate(year: 2023, month: 2, day: 29)), "end"))
    invalidForms.append(
      (.allDay(start: leapDate, end: PlannerCivilDate(year: 2024, month: 2, day: 28)), "end"))
    for (form, field) in invalidForms {
      for editing in [false, true] {
        let operationIdentifier = UUID()
        let command: PlannerCommand =
          editing
          ? .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: form),
            expectedFieldHashes: original.fieldHashes) : .createSchedule(source: item, form: form)
        guard
          case .rejected(let reason) = await planner.execute(
            PlannerOperation(operationId: operationIdentifier, session: session, command: command)
          ).outcome,
          case .noReliableEvidence = await planner.operationStatus(
            session: session, operationId: operationIdentifier)
        else {
          Issue.record("Invalid civil dates cannot save or create applied evidence.")
          return
        }
        #expect(reason.code == "invalidInput")
        #expect(
          reason.propertyPath == (editing ? "/command/changes/form/" : "/command/form/") + field)
      }
    }
    guard
      case .source(.schedule(let unchanged)) = await planner.read(
        session: session, request: .source(schedule)),
      case .rows(let originalRows) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let afterInvalid) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Rejected forms must preserve source and the existing row generation.")
      return
    }
    #expect(unchanged.content == original.content)
    #expect(unchanged.fieldHashes == original.fieldHashes)
    #expect(originalRows.rows.count == 1)
    #expect(afterInvalid.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
    #expect(afterInvalid.first?.preparedProposals.isEmpty == true)
    let explicitSameDay = PlannerScheduleForm.allDay(start: leapDate, end: leapDate)
    let sameDayIdentifier = UUID()
    let sameDayCommand = PlannerCommand.editSchedule(
      scheduleId: schedule.id, changes: PlannerScheduleChanges(form: explicitSameDay),
      expectedFieldHashes: original.fieldHashes)
    guard
      case .applied(_, .complete(let sameDayCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: sameDayIdentifier, session: session, command: sameDayCommand)
      ).outcome,
      case .source(.schedule(let sameDay)) = await planner.read(
        session: session, request: .source(schedule))
    else {
      Issue.record("An explicitly inclusive same-day end must be valid.")
      return
    }
    #expect(sameDayCheckpoint == 3)
    #expect(sameDay.content.form == explicitSameDay)
    #expect(sameDay.fieldHashes != original.fieldHashes)
    let timedForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400.25), end: nil,
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(_, .complete(let timedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: timedForm),
            expectedFieldHashes: sameDay.fieldHashes))
      ).outcome,
      case .source(.schedule(let timed)) = await planner.read(
        session: session, request: .source(schedule)),
      case .rejected(let stale) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: originalForm),
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else {
      Issue.record("Complete form conversion and stale protection must preserve the Schedule.")
      return
    }
    #expect(timedCheckpoint == 4)
    #expect(timed.source == schedule)
    #expect(timed.content.form == timedForm)
    #expect(stale.code == "staleEdit")
    guard case .staleScheduleEdit(let currentForm, let currentHash) = stale.details else {
      Issue.record("Stale conversion must return the complete current timed form/hash.")
      return
    }
    #expect(currentForm == timedForm)
    #expect(currentHash == timed.fieldHashes[.form])
    let centuryLeapForm = PlannerScheduleForm.allDay(
      start: PlannerCivilDate(year: 2000, month: 2, day: 29), end: nil)
    guard
      case .applied(_, .complete(let finalCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: centuryLeapForm),
            expectedFieldHashes: timed.fieldHashes))
      ).outcome,
      case .applied(_, .complete(let originalCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: sameDayIdentifier, session: session, command: sameDayCommand)
      ).outcome,
      case .source(.schedule(let retained)) = await planner.read(
        session: session, request: .source(schedule)),
      case .selected(let after) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: finalCheckpoint))
    else {
      Issue.record("Conversion back to civil dates and replay must preserve current data.")
      return
    }
    #expect(finalCheckpoint == 5)
    #expect(originalCheckpoint == 3)
    #expect(retained.source == schedule)
    #expect(retained.content.form == centuryLeapForm)
    #expect(
      after.decodedBackup.backup.schedules.first?.lifetimeId
        == before.decodedBackup.backup.schedules.first?.lifetimeId)
    #expect(after.decodedBackup.backup.schedules.first?.form == centuryLeapForm)
  }

  private func configuration(_ directory: URL) -> PlannerStorageConfiguration {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }
}
