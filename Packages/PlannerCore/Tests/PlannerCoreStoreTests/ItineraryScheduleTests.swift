import Foundation
import PlannerCore
import Testing

struct ItineraryScheduleTests {
  @Test func emptyItineraryScheduleRetainsOwnershipAndRecoveryAfterReopen() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let bootstrap = await planner.bootstrap()
    guard case .ready(let session) = bootstrap else {
      Issue.record("Scheduling requires a ready dataset: \(String(describing: bootstrap))")
      return
    }
    let creation = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .createItinerary(content: .init(title: "Tokyo afternoon", notes: "Keep")))
    )
    guard case .applied(let created, .complete) = creation.outcome,
      let itinerary = created.generated.first
    else {
      Issue.record(
        "The empty Itinerary must exist before scheduling it: \(String(describing: creation.outcome))"
      )
      return
    }
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    let operationIdentifier = UUID()
    let result = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session,
        command: .createSchedule(source: itinerary, form: form)))
    guard case .applied(let scheduled, .complete(let checkpoint)) = result.outcome,
      let schedule = scheduled.generated.first,
      case .source(.itinerary(let owner)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.schedule(let assignment)) = await planner.read(
        session: session, request: .source(schedule))
    else {
      Issue.record("An empty Itinerary must support its own durably saved, readable Schedule.")
      return
    }
    #expect(scheduled.affected.contains(itinerary))
    #expect(owner.content.title == "Tokyo afternoon")
    #expect(owner.content.notes == "Keep")
    #expect(owner.progress.totalCount == 0)
    #expect(owner.references == [.schedule(id: schedule.id, source: itinerary)])
    #expect(assignment.content.source == itinerary)
    #expect(assignment.content.form == form)

    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.schedule(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .source(.itinerary(let retainedOwner)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .applied(let replayed, .complete) = await reopened.execute(
        .init(
          operationId: operationIdentifier, session: reopenedSession,
          command: .createSchedule(source: itinerary, form: form))
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Reopen, replay and independent recovery must retain the Itinerary assignment.")
      return
    }
    #expect(retained.content == assignment.content)
    #expect(retained.fieldHashes == assignment.fieldHashes)
    #expect(retainedOwner.references == owner.references)
    #expect(replayed.generated == scheduled.generated)
    #expect(recovery.decodedBackup.backup.schedules.count == 1)
    #expect(recovery.decodedBackup.backup.schedules.first?.source == itinerary)
    let recoveredItinerary = recovery.decodedBackup.backup.sources.compactMap {
      source -> PlannerPortableItinerary? in
      guard case .itinerary(let value) = source else { return nil }
      return value
    }.first
    #expect(
      recovery.decodedBackup.backup.schedules.first?.sourceLifetimeId
        == recoveredItinerary?.lifetimeId)
    #expect(recovery.decodedBackup.backup.items.isEmpty)
    #expect(namespace.preparedProposals.isEmpty)
  }
  @Test func itineraryAssignmentCanBeEditedAndRemovedWithoutChangingItsChildren() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let result = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let applied, .complete) = result.outcome else {
        Issue.record("The complete action must save: \(String(describing: result.outcome))")
        throw CancellationError()
      }
      return applied
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route", notes: "Keep"))).generated
        .first)
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    let schedule = try #require(
      try await save(
        .createSchedule(
          source: itinerary,
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
            planningTimeZone: "Asia/Tokyo"))
      ).generated.first)
    guard
      case .source(.schedule(let original)) = await planner.read(
        session: session, request: .source(schedule)),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else { throw CancellationError() }
    let allDay = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))
    _ = try await save(
      .editSchedule(
        scheduleId: schedule.id, changes: .init(form: allDay),
        expectedFieldHashes: original.fieldHashes))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    guard
      case .source(.itinerary(let archived)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id, changes: .init(notes: .set("Updated")),
        expectedFieldHashes: archived.fieldHashes))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.schedule(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .source(.itinerary(let retainedOwner)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(retained.source == schedule)
    #expect(retained.content.source == itinerary)
    #expect(retained.content.form == allDay)
    #expect(retainedOwner.content.notes == "Updated")
    #expect(retainedOwner.state.archived == true)
    #expect(retainedOwner.progress.totalCount == 1)
    #expect(retainedOwner.progress.doneCount == 0)
    #expect(retainedOwner.references.contains(.schedule(id: schedule.id, source: itinerary)))
    let operationIdentifier = UUID()
    let removal = PlannerOperation(
      operationId: operationIdentifier, session: reopenedSession,
      command: .removeSchedule(scheduleId: schedule.id))
    guard
      case .applied(let removed, .complete(let checkpoint)) = await reopened.execute(removal)
        .outcome,
      case .applied(let replayed, .complete) = await reopened.execute(removal).outcome,
      case .failed(let missing) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .source(.itinerary(let unscheduled)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(removed.affected.count == 2)
    #expect(removed.affected.contains(itinerary))
    #expect(removed.affected.contains(schedule))
    #expect(replayed.affected == removed.affected)
    #expect(missing.code == "missingReference")
    #expect(unscheduled.content == retainedOwner.content)
    #expect(unscheduled.state.archived == true)
    #expect(unscheduled.progress.totalCount == 1)
    #expect(unscheduled.progress.doneCount == 0)
    #expect(unscheduled.references.count == 1)
    #expect(retainedItem.state.globalDone == false)
    #expect(retainedItem.references == originalItem.references)
    #expect(recovery.decodedBackup.backup.schedules.isEmpty)
    #expect(recovery.decodedBackup.backup.itineraryEntries.count == 1)
    #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
    #expect(namespace.preparedProposals.isEmpty)
  }

  @Test func itineraryZoneChangePreservesInstantsAndRejectsStaleOrInvalidReplacement() async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let end = Date(timeIntervalSinceReferenceDate: 813_204_000)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItinerary(content: .init(title: "Route")))
      ).outcome,
      let itinerary = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: itinerary,
            form: .timed(start: start, end: end, planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let original)) = await planner.read(
        session: session, request: .source(schedule)),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .changeScheduleZone(
            scheduleId: schedule.id, planningTimeZone: "Europe/Paris",
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .source(.schedule(let current)) = await planner.read(
        session: session, request: .source(schedule))
    else { throw CancellationError() }
    #expect(current.source == schedule)
    #expect(current.content.source == itinerary)
    #expect(
      current.content.form == .timed(start: start, end: end, planningTimeZone: "Europe/Paris"))
    #expect(current.fieldHashes[.form] != original.fieldHashes[.form])
    let staleIdentifier = UUID()
    let invalidIdentifier = UUID()
    guard
      case .rejected(let stale) = await planner.execute(
        .init(
          operationId: staleIdentifier, session: session,
          command: .editSchedule(
            scheduleId: schedule.id,
            changes: .init(form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil)),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .staleScheduleEdit(let reportedForm, let reportedHash) = stale.details,
      case .rejected(let invalid) = await planner.execute(
        .init(
          operationId: invalidIdentifier, session: session,
          command: .editSchedule(
            scheduleId: schedule.id,
            changes: .init(
              form: .timed(start: start, end: start, planningTimeZone: "Europe/Paris")),
            expectedFieldHashes: current.fieldHashes))
      ).outcome,
      case .source(.schedule(let unchanged)) = await planner.read(
        session: session, request: .source(schedule)),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleIdentifier),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: invalidIdentifier),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else { throw CancellationError() }
    #expect(stale.code == "staleEdit")
    #expect(reportedForm == current.content.form)
    #expect(reportedHash == current.fieldHashes[.form])
    #expect(invalid.code == "invalidInput")
    #expect(unchanged.content == current.content)
    #expect(unchanged.fieldHashes == current.fieldHashes)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

}
