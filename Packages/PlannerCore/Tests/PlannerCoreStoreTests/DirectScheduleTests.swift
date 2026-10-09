import Foundation
import PlannerCore
import Testing

struct DirectScheduleTests {

  @Test func contentBookmarkCompletionAndArchiveChangesPreserveIndependentSchedule() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
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
      let item = created.generated.first
    else {
      Issue.record("Hotel must exist before its independent Schedule.")
      return
    }
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createSchedule(source: item, form: form))
      )
      .outcome,
      let assignment = scheduled.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id, changes: PlannerItemChanges(title: .set("Tokyo Hotel")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .setArchive(source: item, archived: true))
      )
      .outcome,
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(item)),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id, changes: PlannerItemChanges(links: .set([])),
            expectedFieldHashes: current.fieldHashes))
      ).outcome
    else {
      Issue.record("Independent content and state actions must retain the saved assignment.")
      return
    }
    let reopened = Planner(configuration: configuration(directory))
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let oldRecovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 2)),
      case .selected(let newRecovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 6))
    else {
      Issue.record("Reopening and independent recovery must retain the Schedule across every edit.")
      return
    }
    #expect(checkpoint == 6)
    #expect(retained.references == [.schedule(id: assignment.id, source: item)])
    #expect(retained.content.title == "Tokyo Hotel")
    #expect(retained.content.notes == "Keep")
    #expect(retained.content.links.isEmpty)
    #expect(retained.state.globalDone == true)
    #expect(retained.state.archived == true)
    #expect(newRecovery.decodedBackup.backup.schedules.count == 1)
    #expect(newRecovery.decodedBackup.backup.schedules.first?.id == assignment.id)
    #expect(newRecovery.decodedBackup.backup.schedules.first?.form == form)
    #expect(
      newRecovery.decodedBackup.backup.schedules.first?.lifetimeId
        == oldRecovery.decodedBackup.backup.schedules.first?.lifetimeId)
    #expect(oldRecovery.decodedBackup.backup.sources.first?.content.links.count == 1)
    #expect(newRecovery.decodedBackup.backup.sources.first?.content.links.isEmpty == true)
    #expect(namespace.preparedProposals.isEmpty)
  }

  @Test func startOnlyStopsBeingNextWithoutBecomingAnEstimatedOngoingAppointment() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", estimate: PlannerEstimate(minutes: 120, displayUnit: .hour))))
      )
      .outcome,
      let item = created.generated.first
    else {
      Issue.record("A real Item must exist before its start-only appointment.")
      return
    }
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let firstForm = PlannerScheduleForm.timed(
      start: start, end: nil, planningTimeZone: "Asia/Tokyo")
    let futureForm = PlannerScheduleForm.timed(
      start: start.addingTimeInterval(14_400), end: nil, planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let firstCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: firstForm))
      ).outcome,
      let first = firstCreated.generated.first,
      case .applied(let futureCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: futureForm))
      ).outcome,
      let future = futureCreated.generated.first
    else {
      Issue.record("Each start-only appointment must save as its own record.")
      return
    }
    let expectations: [(TimeInterval, PlannerEntityReference, PlannerScheduleForm)] = [
      (0, first, firstForm), (1800, future, futureForm), (14_401, future, futureForm),
    ]
    for (seconds, selected, form) in expectations {
      let presentation = PlannerRowPresentationContext(
        referenceInstant: start.addingTimeInterval(seconds), displayTimeZone: "Europe/Paris")
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(PlannerItemQuery(rowPresentation: presentation)))),
        case .rows(let window) = await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
      else {
        Issue.record("The fixed query time must resolve the original Schedule pool.")
        return
      }
      #expect(
        window.rows.first?.scheduleSummary
          == .directItem(
            schedule: selected, owner: item, form: form, additionalCount: 1))
    }
  }

  @Test func invalidAppointmentsAndAlteredReplayLeaveSourceAndRecoveryUnchanged() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      )
      .outcome,
      let item = created.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery())))
    else {
      Issue.record("The source and its generation must exist before rejected assignments.")
      return
    }
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let invalidForms: [(PlannerScheduleForm, String)] = [
      (
        .timed(
          start: Date(timeIntervalSinceReferenceDate: .nan), end: nil,
          planningTimeZone: "Asia/Tokyo"), "/command/form/start"
      ),
      (
        .timed(
          start: Date(timeIntervalSinceReferenceDate: .infinity), end: nil,
          planningTimeZone: "Asia/Tokyo"), "/command/form/start"
      ),
      (.timed(start: start, end: start, planningTimeZone: "Asia/Tokyo"), "/command/form/end"),
      (
        .timed(
          start: start, end: start.addingTimeInterval(-1),
          planningTimeZone: "Asia/Tokyo"), "/command/form/end"
      ),
      (
        .timed(
          start: start, end: Date(timeIntervalSinceReferenceDate: .infinity),
          planningTimeZone: "Asia/Tokyo"), "/command/form/end"
      ),
      (
        .timed(start: start, end: nil, planningTimeZone: "Invalid/Zone"),
        "/command/form/planningTimeZone"
      ),
    ]
    for (form, path) in invalidForms {
      let operationIdentifier = UUID()
      let result = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session,
          command: .createSchedule(source: item, form: form)))
      guard case .rejected(let reason) = result.outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record("Invalid appointments must create neither a Schedule nor an applied receipt.")
        return
      }
      #expect(result.operationId == operationIdentifier)
      #expect(reason.code == "invalidInput")
      #expect(reason.propertyPath == path)
    }
    let form = PlannerScheduleForm.timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")
    let missingIdentifier = UUID()
    guard
      case .rejected(let missing) = await planner.execute(
        PlannerOperation(
          operationId: missingIdentifier, session: session,
          command: .createSchedule(
            source: PlannerEntityReference(kind: .item, id: UUID()), form: form))
      )
      .outcome,
      case .source(.item(let unchanged)) = await planner.read(
        session: session, request: .source(item)),
      case .rows = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else {
      Issue.record("Missing sources must not invalidate the retained generation or recovery.")
      return
    }
    #expect(missing.code == "missingReference")
    #expect(missing.propertyPath == "/command/source")
    #expect(unchanged.content.notes == "Keep")
    #expect(unchanged.references.isEmpty)
    #expect(unchanged.updatedAt == original.updatedAt)
    #expect(unchanged.fieldHashes == original.fieldHashes)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 1)
    #expect(namespace.preparedProposals.isEmpty)
    let operationIdentifier = UUID()
    guard
      case .applied(let scheduled, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session,
          command: .createSchedule(source: item, form: form))
      ).outcome,
      let assignment = scheduled.generated.first,
      case .rejected(let mismatch) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: start.addingTimeInterval(1), end: nil, planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 2))
    else {
      Issue.record("A changed replay must retain exactly one original Schedule and checkpoint.")
      return
    }
    #expect(checkpoint == 2)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(retained.references == [.schedule(id: assignment.id, source: item)])
    #expect(recovery.decodedBackup.backup.schedules.count == 1)
    #expect(recovery.decodedBackup.backup.schedules.first?.form == form)
  }

  private func configuration(_ directory: URL) -> PlannerStorageConfiguration {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  @Test func directDateSummarySelectsOngoingThenFutureThenPastWithStableOverlapTie() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      let item = created.generated.first
    else {
      Issue.record("The owned Item must exist before its independent assignments.")
      return
    }
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let firstForm = PlannerScheduleForm.timed(
      start: start, end: start.addingTimeInterval(3600), planningTimeZone: "Asia/Tokyo")
    let secondForm = PlannerScheduleForm.timed(
      start: start.addingTimeInterval(14_400), end: start.addingTimeInterval(18_000),
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let firstCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: firstForm))
      ).outcome,
      let first = firstCreated.generated.first,
      case .applied(let secondCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: secondForm))
      ).outcome,
      let second = secondCreated.generated.first
    else {
      Issue.record("Both real assignment identities must save independently.")
      return
    }
    let expectations:
      [(seconds: TimeInterval, schedule: PlannerEntityReference, form: PlannerScheduleForm)] = [
        (1800, first, firstForm),
        (3600, second, secondForm),
        (19_800, second, secondForm),
      ]
    for expected in expectations {
      let presentation = PlannerRowPresentationContext(
        referenceInstant: start.addingTimeInterval(expected.seconds), displayTimeZone: "Asia/Tokyo")
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session, request: .items(PlannerItemQuery(rowPresentation: presentation)))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
      else {
        Issue.record("Each fixed time must produce the declared single real Schedule summary.")
        return
      }
      #expect(
        window.rows.first?.scheduleSummary
          == .directItem(
            schedule: expected.schedule, owner: item, form: expected.form, additionalCount: 1))
    }
    let overlappingForm = PlannerScheduleForm.timed(
      start: start.addingTimeInterval(900), end: start.addingTimeInterval(2700),
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let thirdCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: overlappingForm))
      ).outcome,
      let third = thirdCreated.generated.first,
      case .applied(let fourthCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: overlappingForm))
      ).outcome,
      let fourth = fourthCreated.generated.first,
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: start.addingTimeInterval(1800), displayTimeZone: "Asia/Tokyo"))))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record(
        "Distinct equal-start overlapping assignments must both remain in the owner pool.")
      return
    }
    let expectedIdentity: PlannerEntityReference
    if third.id.uuidString.lexicographicallyPrecedes(fourth.id.uuidString) {
      expectedIdentity = third
    } else {
      expectedIdentity = fourth
    }
    #expect(
      window.rows.first?.scheduleSummary
        == .directItem(
          schedule: expectedIdentity, owner: item, form: overlappingForm, additionalCount: 3))
  }

  @Test func savedStartOnlyAppointmentKeepsItsInstantAndNoEstimatedEndAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes",
              estimate: PlannerEstimate(minutes: 120, displayUnit: .hour),
              links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])))
      )
      .outcome, let item = created.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Hotel must be independently saved before assigning an appointment.")
      return
    }
    // 9 October 2026, 10:00 Tokyo is 01:00 UTC, independently calculated from the 2001 epoch.
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let form = PlannerScheduleForm.timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")
    let operationIdentifier = UUID()
    let command = PlannerCommand.createSchedule(source: item, form: form)
    guard
      case .applied(let scheduled, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(operationId: operationIdentifier, session: session, command: command)
      )
      .outcome, let schedule = scheduled.generated.first,
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("A supplied start with no end must save without using the activity estimate.")
      return
    }
    #expect(schedule.kind == .schedule)
    #expect(checkpoint == 2)
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Original notes")
    #expect(current.content.estimate?.minutes == 120)
    #expect(current.content.links == original.content.links)
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(current.createdAt == original.createdAt)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.references.contains(.schedule(id: schedule.id, source: item)))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      Issue.record("The saved appointment must survive a fresh native store opening.")
      return
    }
    for zone in ["Asia/Tokyo", "Europe/Paris"] {
      let presentation = PlannerRowPresentationContext(
        referenceInstant: start, displayTimeZone: zone)
      guard
        case .snapshot(let snapshot) = await reopened.query(
          PlannerQuery(
            session: reopenedSession,
            request: .items(PlannerItemQuery(rowPresentation: presentation)))),
        case .rows(let window) = await reopened.read(
          session: reopenedSession,
          request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
      else {
        Issue.record("Both device display zones must read the same retained assignment.")
        return
      }
      #expect(window.rowPresentation == presentation)
      #expect(
        window.rows.first?.scheduleSummary
          == .directItem(
            schedule: schedule, owner: item, form: form, additionalCount: 0))
    }
    guard
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      )
      .outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 2))
    else {
      Issue.record("Replay and independent recovery must retain one original Schedule identity.")
      return
    }
    #expect(replayed == scheduled)
    #expect(replayedCheckpoint == 2)
    #expect(selection.decodedBackup.backup.schedules.count == 1)
    #expect(selection.decodedBackup.backup.schedules.first?.id == schedule.id)
    #expect(selection.decodedBackup.backup.schedules.first?.source == item)
    #expect(selection.decodedBackup.backup.schedules.first?.form == form)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 2)
    #expect(namespace.preparedProposals.isEmpty)
    let portable = try #require(
      JSONSerialization.jsonObject(with: selection.portableData) as? [String: Any])
    let schedules = try #require(portable["schedules"] as? [[String: Any]])
    let savedForm = try #require(schedules.first?["form"] as? [String: Any])
    #expect(savedForm["end"] is NSNull)
    #expect(savedForm["start"] as? Double == 813_200_400)
    #expect(savedForm["planningTimeZone"] as? String == "Asia/Tokyo")
  }
}
