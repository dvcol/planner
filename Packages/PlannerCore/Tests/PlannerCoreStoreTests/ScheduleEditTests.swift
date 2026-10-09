import Foundation
import PlannerCore
import Testing

struct ScheduleEditTests {
  @Test func staleFormRejectsReplacementAndReportsCurrentFormWithoutSaving() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let originalForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    let currentForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_214_800),
      end: Date(timeIntervalSinceReferenceDate: 813_218_400), planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
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
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: currentForm),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .source(.schedule(let current)) = await planner.read(
        session: session, request: .source(schedule)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: Date(timeIntervalSinceReferenceDate: 813_202_200),
                displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record("An intervening Schedule replacement must be saved before the stale request.")
      return
    }
    let operationIdentifier = UUID()
    guard
      case .rejected(let reason) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: originalForm),
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else {
      Issue.record("The stale prior form must reject the complete replacement.")
      return
    }
    #expect(reason.code == "staleEdit")
    guard case .staleScheduleEdit(let reportedForm, let reportedHash) = reason.details else {
      Issue.record("A stale Schedule rejection must return its complete current form and hash.")
      return
    }
    #expect(reportedForm == currentForm)
    #expect(reportedHash == current.fieldHashes[.form])
    guard
      case .source(.schedule(let unchanged)) = await planner.read(
        session: session, request: .source(schedule)),
      case .rows = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Rejection must keep the read generation usable and create no applied receipt.")
      return
    }
    #expect(unchanged.content.form == currentForm)
    #expect(unchanged.fieldHashes == current.fieldHashes)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func guardedFormReplacementKeepsScheduleIdentityAndSourceContentAcrossReopen() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let oldForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400),
      end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo")
    let newForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_214_800),
      end: Date(timeIntervalSinceReferenceDate: 813_218_400), planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Keep",
              links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])))
      )
      .outcome,
      let item = created.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: oldForm))
      )
      .outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let original)) = await planner.read(
        session: session, request: .source(schedule)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: Date(timeIntervalSinceReferenceDate: 813_202_200),
                displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record("Hotel and its real appointment must exist before editing the retained form.")
      return
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.editSchedule(
      scheduleId: schedule.id,
      changes: PlannerScheduleChanges(form: newForm), expectedFieldHashes: original.fieldHashes)
    guard
      case .applied(let edited, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session, command: command)
      ).outcome
    else {
      Issue.record("A current form hash must allow a complete replacement of the same Schedule.")
      return
    }
    #expect(checkpoint == 3)
    #expect(edited.generated.isEmpty)
    guard
      case .failed(let oldWindow) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("Changing a retained Schedule must invalidate its old date projection.")
      return
    }
    #expect(oldWindow.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.schedule(let current)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .source(.item(let currentItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let oldRecovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 2)),
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 3))
    else {
      Issue.record(
        "The original Schedule, replay receipt and before/after recovery must survive reopen.")
      return
    }
    #expect(current.source == schedule)
    #expect(current.content.source == item)
    #expect(current.content.form == newForm)
    #expect(current.fieldHashes[.form] != original.fieldHashes[.form])
    #expect(currentItem.content.links == originalItem.content.links)
    #expect(currentItem.content.notes == "Keep")
    #expect(currentItem.fieldHashes == originalItem.fieldHashes)
    #expect(currentItem.updatedAt == originalItem.updatedAt)
    #expect(replayed == edited)
    #expect(replayedCheckpoint == 3)
    #expect(recovery.decodedBackup.backup.schedules.count == 1)
    #expect(recovery.decodedBackup.backup.schedules.first?.id == schedule.id)
    #expect(recovery.decodedBackup.backup.schedules.first?.form == newForm)
    #expect(oldRecovery.decodedBackup.backup.schedules.first?.form == oldForm)
    #expect(
      recovery.decodedBackup.backup.schedules.first?.lifetimeId
        == oldRecovery.decodedBackup.backup.schedules.first?.lifetimeId)
    #expect(namespace.preparedProposals.isEmpty)
    guard
      case .applied(_, .complete(let laterCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: UUID(), session: reopenedSession,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: oldForm),
            expectedFieldHashes: current.fieldHashes))
      ).outcome,
      case .applied(let originalResult, .complete(let originalCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .source(.schedule(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .rejected(let mismatch) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: oldForm),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .listedNamespaces(let latestNamespaces) = await reopened.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("An exact replay must retain a later edit; a changed payload must reject.")
      return
    }
    #expect(laterCheckpoint == 4)
    #expect(originalResult == edited)
    #expect(originalCheckpoint == 3)
    #expect(retained.content.form == oldForm)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(latestNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(latestNamespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func invalidFormOrHashLeavesTheScheduleAndGenerationUnchanged() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let form = PlannerScheduleForm.timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
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
                referenceInstant: start, displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record(
        "The saved start-only Schedule and its projection must exist before invalid edits.")
      return
    }
    let invalidForms: [(PlannerScheduleForm, String)] = [
      (
        .timed(
          start: Date(timeIntervalSinceReferenceDate: .nan), end: nil,
          planningTimeZone: "Asia/Tokyo"), "/start"
      ),
      (
        .timed(
          start: Date(timeIntervalSinceReferenceDate: .infinity), end: nil,
          planningTimeZone: "Asia/Tokyo"), "/start"
      ),
      (.timed(start: start, end: start, planningTimeZone: "Asia/Tokyo"), "/end"),
      (
        .timed(start: start, end: start.addingTimeInterval(-1), planningTimeZone: "Asia/Tokyo"),
        "/end"
      ),
      (
        .timed(
          start: start, end: Date(timeIntervalSinceReferenceDate: .infinity),
          planningTimeZone: "Asia/Tokyo"), "/end"
      ),
      (.timed(start: start, end: nil, planningTimeZone: "Invalid/Zone"), "/planningTimeZone"),
    ]
    for (invalidForm, path) in invalidForms {
      let operationIdentifier = UUID()
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: operationIdentifier, session: session,
            command: .editSchedule(
              scheduleId: schedule.id, changes: PlannerScheduleChanges(form: invalidForm),
              expectedFieldHashes: original.fieldHashes))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record("Invalid form must reject before saving or recording an applied receipt.")
        return
      }
      #expect(reason.code == "invalidInput")
      #expect(reason.propertyPath == "/command/changes/form" + path)
    }
    for hashes: [PlannerScheduleField: PlannerFieldHash] in [
      [:], [.form: PlannerFieldHash(value: "sha256-v1:invalid")],
      [.form: PlannerFieldHash(value: "sha256-v1:" + String(repeating: "A", count: 64))],
    ] {
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .editSchedule(
              scheduleId: schedule.id, changes: PlannerScheduleChanges(form: form),
              expectedFieldHashes: hashes))
        ).outcome
      else {
        Issue.record("Missing or malformed complete-form hashes must reject.")
        return
      }
      #expect(reason.code == "invalidInput")
      #expect(reason.propertyPath == "/command/expectedFieldHashes/form")
    }
    guard
      case .rejected(let missing) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: UUID(), changes: PlannerScheduleChanges(form: form),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .source(.schedule(let unchanged)) = await planner.read(
        session: session, request: .source(schedule)),
      case .rows = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Rejected edits must retain the Schedule, snapshot and independent checkpoint.")
      return
    }
    #expect(missing.code == "missingReference")
    #expect(unchanged.content.form == form)
    #expect(unchanged.fieldHashes == original.fieldHashes)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }
}
