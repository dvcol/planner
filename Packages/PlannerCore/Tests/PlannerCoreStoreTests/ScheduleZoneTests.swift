import Foundation
import PlannerCore
import Testing

struct ScheduleZoneTests {
  @Test func zoneValidationAndCompleteFormGuardPreserveStartOnlyAndLaterTimedForms() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let startOnly = PlannerScheduleForm.timed(
      start: start, end: nil, planningTimeZone: "Asia/Tokyo")
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
          command: .createSchedule(source: item, form: startOnly))
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
      Issue.record("The start-only Schedule must exist before validating zone edits.")
      return
    }
    let invalid: [(String, [PlannerScheduleField: PlannerFieldHash], String)] = [
      ("Invalid/Zone", original.fieldHashes, "/command/planningTimeZone"),
      ("UTC", [:], "/command/expectedFieldHashes/form"),
      (
        "UTC", [.form: PlannerFieldHash(value: "sha256-v1:invalid")],
        "/command/expectedFieldHashes/form"
      ),
    ]
    for (zone, hashes, path) in invalid {
      let operationIdentifier = UUID()
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: operationIdentifier, session: session,
            command: .changeScheduleZone(
              scheduleId: schedule.id, planningTimeZone: zone,
              expectedFieldHashes: hashes))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record("Invalid zone/hash must reject without an applied receipt.")
        return
      }
      #expect(reason.code == "invalidInput")
      #expect(reason.propertyPath == path)
    }
    guard
      case .rejected(let missing) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .changeScheduleZone(
            scheduleId: UUID(),
            planningTimeZone: "UTC", expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .source(.schedule(let unchanged)) = await planner.read(
        session: session, request: .source(schedule)),
      case .rows = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let untouchedNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("Invalid edits must retain the original Schedule, projection and checkpoint.")
      return
    }
    #expect(missing.code == "missingReference")
    #expect(unchanged.content.form == startOnly)
    #expect(unchanged.fieldHashes == original.fieldHashes)
    #expect(untouchedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
    #expect(untouchedNamespaces.first?.preparedProposals.isEmpty == true)
    guard
      case .applied(_, .complete(let changedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .changeScheduleZone(
            scheduleId: schedule.id, planningTimeZone: "UTC",
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .source(.schedule(let utc)) = await planner.read(
        session: session, request: .source(schedule))
    else {
      Issue.record("A zone edit must preserve the absent end without inventing one.")
      return
    }
    #expect(changedCheckpoint == 3)
    #expect(utc.content.form == .timed(start: start, end: nil, planningTimeZone: "UTC"))
    let laterForm = PlannerScheduleForm.timed(
      start: start.addingTimeInterval(3600),
      end: start.addingTimeInterval(7200), planningTimeZone: "UTC")
    guard
      case .applied(_, .complete(let laterCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: laterForm),
            expectedFieldHashes: utc.fieldHashes))
      ).outcome,
      case .source(.schedule(let current)) = await planner.read(
        session: session, request: .source(schedule)),
      case .snapshot(let currentSnapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: start, displayTimeZone: "UTC")))))
    else {
      Issue.record("An intervening start/end edit must save before the stale zone request.")
      return
    }
    let staleIdentifier = UUID()
    guard
      case .rejected(let stale) = await planner.execute(
        PlannerOperation(
          operationId: staleIdentifier, session: session,
          command: .changeScheduleZone(
            scheduleId: schedule.id, planningTimeZone: "Europe/Paris",
            expectedFieldHashes: utc.fieldHashes))
      ).outcome,
      case .staleScheduleEdit(let reportedForm, let reportedHash) = stale.details,
      case .source(.schedule(let retained)) = await planner.read(
        session: session, request: .source(schedule)),
      case .rows = await planner.read(
        session: session,
        request: .rows(generation: currentSnapshot.generation, offset: 0, limit: 1)),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleIdentifier),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The complete form guard must reject a zone edit after start/end change.")
      return
    }
    #expect(stale.code == "staleEdit")
    #expect(reportedForm == laterForm)
    #expect(reportedHash == current.fieldHashes[.form])
    #expect(retained.content.form == laterForm)
    #expect(retained.fieldHashes == current.fieldHashes)
    #expect(laterCheckpoint == 4)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func zoneChangePreservesInstantsAndItemDataAcrossReopenAndLaterReplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400.25)
    let end = Date(timeIntervalSinceReferenceDate: 813_204_000.75)
    let originalForm = PlannerScheduleForm.timed(
      start: start, end: end, planningTimeZone: "Asia/Tokyo")
    let parisForm = PlannerScheduleForm.timed(
      start: start, end: end, planningTimeZone: "Europe/Paris")
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: originalForm))
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
      Issue.record("The original fixed appointment must exist before changing its planning zone.")
      return
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.changeScheduleZone(
      scheduleId: schedule.id, planningTimeZone: "Europe/Paris",
      expectedFieldHashes: original.fieldHashes)
    guard
      case .applied(let changed, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session, command: command)
      ).outcome
    else {
      Issue.record("A current form hash must permit a timezone-only change.")
      return
    }
    #expect(checkpoint == 3)
    #expect(changed.generated.isEmpty)
    guard
      case .failed(let staleWindow) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("Changing the retained planning zone must invalidate the previous projection.")
      return
    }
    #expect(staleWindow.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.schedule(let current)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let before) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 2)),
      case .selected(let after) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 3))
    else {
      Issue.record(
        "The retained identity, instants and independent old/new forms must survive reopen.")
      return
    }
    #expect(current.source == schedule)
    #expect(current.content.source == item)
    #expect(current.content.form == parisForm)
    #expect(current.fieldHashes != original.fieldHashes)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(before.decodedBackup.backup.schedules.first?.form == originalForm)
    #expect(after.decodedBackup.backup.schedules.first?.form == parisForm)
    #expect(
      before.decodedBackup.backup.schedules.first?.lifetimeId
        == after.decodedBackup.backup.schedules.first?.lifetimeId)
    let laterForm = PlannerScheduleForm.timed(
      start: start.addingTimeInterval(3600), end: nil, planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(_, .complete(let laterCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: UUID(), session: reopenedSession,
          command: .editSchedule(
            scheduleId: schedule.id, changes: PlannerScheduleChanges(form: laterForm),
            expectedFieldHashes: current.fieldHashes))
      ).outcome,
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .source(.schedule(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .rejected(let mismatch) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession,
          command: .changeScheduleZone(
            scheduleId: schedule.id, planningTimeZone: "UTC",
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .listedNamespaces(let latestNamespaces) = await reopened.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("Exact zone replay must retain a later form; changed payload must reject.")
      return
    }
    #expect(laterCheckpoint == 4)
    #expect(replayed == changed)
    #expect(replayedCheckpoint == 3)
    #expect(retained.content.form == laterForm)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(latestNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(latestNamespaces.first?.preparedProposals.isEmpty == true)
  }
}
