import Foundation
import PlannerCore
import Testing

struct ItemEstimateEditTests {
  @Test func estimateEditAndClearPreserveContentAndStartOnlyScheduleAcrossRecoveryAndReopen()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let operationIdentifier = UUID()
    let edited = await fixture.planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(estimate: .set(PlannerEstimate(minutes: 2_880, displayUnit: .day))),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .applied(let result, .complete(let checkpoint)) = edited.outcome else {
      Issue.record("The guarded estimate must save with complete recovery: \(edited)")
      return
    }
    #expect(result.generated.isEmpty)
    #expect(result.affected == [fixture.item])
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(fixture.item)),
      case .source(.schedule(let schedule)) = await reopened.read(
        session: reopenedSession, request: .source(fixture.schedule))
    else {
      Issue.record("The edited estimate and retained Schedule must reopen through public reads.")
      return
    }
    #expect(current.content.estimate == PlannerEstimate(minutes: 2_880, displayUnit: .day))
    #expect(current.content.title == "Hotel")
    #expect(current.content.subtitle == "Stay near the station")
    #expect(current.content.notes == "Original notes")
    #expect(current.content.location?.formattedAddress == "Meeting point A")
    #expect(current.state.globalDone == true)
    #expect(current.state.archived == true)
    #expect(current.createdAt == fixture.original.createdAt)
    #expect(current.references == fixture.original.references)
    #expect(current.fieldHashes[.title] == fixture.original.fieldHashes[.title])
    #expect(current.fieldHashes[.subtitle] == fixture.original.fieldHashes[.subtitle])
    #expect(current.fieldHashes[.notes] == fixture.original.fieldHashes[.notes])
    #expect(current.fieldHashes[.location] == fixture.original.fieldHashes[.location])
    #expect(current.fieldHashes[.estimate] != fixture.original.fieldHashes[.estimate])
    #expect(schedule.content.form == fixture.startOnlyForm)
    #expect(schedule.fieldHashes == fixture.originalSchedule.fieldHashes)
    #expect(schedule.source == fixture.schedule)
    guard
      case .appliedRecoveryComplete(let savedResult, let savedCheckpoint) =
        await reopened.operationStatus(session: reopenedSession, operationId: operationIdentifier),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The estimate edit must retain its original evidence and independent recovery.")
      return
    }
    #expect(savedResult == result)
    #expect(savedCheckpoint == checkpoint)
    let namespace = try #require(namespaces.first)
    guard
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("The independently acknowledged estimate backup must remain inspectable.")
      return
    }
    #expect(
      selection.decodedBackup.backup.items.first?.content.estimate
        == PlannerEstimate(minutes: 2_880, displayUnit: .day))
    let cleared = await reopened.execute(
      PlannerOperation(
        operationId: UUID(), session: reopenedSession,
        command: .editItem(
          sourceId: fixture.item.id, changes: .init(estimate: .clear),
          expectedFieldHashes: current.fieldHashes)))
    guard case .applied(_, .complete) = cleared.outcome else {
      Issue.record("No estimate must explicitly clear the saved value: \(cleared)")
      return
    }
    let clearedPlanner = Planner(configuration: fixture.configuration)
    guard case .ready(let clearedSession) = await clearedPlanner.bootstrap(),
      case .source(.item(let clearedItem)) = await clearedPlanner.read(
        session: clearedSession, request: .source(fixture.item)),
      case .source(.schedule(let retainedSchedule)) = await clearedPlanner.read(
        session: clearedSession, request: .source(fixture.schedule))
    else {
      Issue.record("Explicit estimate clearing must persist without changing the Schedule.")
      return
    }
    #expect(clearedItem.content.estimate == nil)
    #expect(clearedItem.content.title == "Hotel")
    #expect(clearedItem.content.subtitle == "Stay near the station")
    #expect(clearedItem.content.notes == "Original notes")
    #expect(clearedItem.state.globalDone == true)
    #expect(clearedItem.state.archived == true)
    #expect(retainedSchedule.content.form == fixture.startOnlyForm)
    #expect(retainedSchedule.fieldHashes == fixture.originalSchedule.fieldHashes)
  }

  @Test func staleEstimateRejectsWholePatchAndReplayRetainsTheOriginalRepresentation() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let operationIdentifier = UUID()
    let command = PlannerCommand.editItem(
      sourceId: fixture.item.id,
      changes: .init(estimate: .set(PlannerEstimate(minutes: 86_400, displayUnit: .month))),
      expectedFieldHashes: fixture.original.fieldHashes)
    guard
      case .applied(let result, .complete(let checkpoint)) = await fixture.planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: fixture.session, command: command)
      ).outcome,
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else {
      Issue.record("The current two-month estimate must save before the stale patch.")
      return
    }
    let staleOperationIdentifier = UUID()
    let stale = await fixture.planner.execute(
      PlannerOperation(
        operationId: staleOperationIdentifier, session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(
            title: .set("Rejected title"),
            estimate: .set(PlannerEstimate(minutes: 525_600, displayUnit: .year))),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .rejected(let reason) = stale.outcome,
      case .staleEdit(let fields, let values, let hashes) = reason.details
    else {
      Issue.record("A changed estimate must reject the complete stale patch: \(stale)")
      return
    }
    #expect(reason.code == "staleEdit")
    #expect(fields == [.estimate])
    #expect(values[.estimate] != nil)
    #expect(
      values[.estimate] == .optionalEstimate(PlannerEstimate(minutes: 86_400, displayUnit: .month)))
    #expect(hashes[.estimate] == current.fieldHashes[.estimate])
    guard
      case .source(.item(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item)),
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: staleOperationIdentifier)
    else {
      Issue.record("The stale patch must retain the Item without applied evidence.")
      return
    }
    #expect(retained.content.title == "Hotel")
    #expect(retained.content.estimate == PlannerEstimate(minutes: 86_400, displayUnit: .month))
    #expect(retained.updatedAt == current.updatedAt)
    #expect(retained.fieldHashes == current.fieldHashes)
    let cleared = await fixture.planner.execute(
      PlannerOperation(
        operationId: UUID(), session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id, changes: .init(estimate: .clear),
          expectedFieldHashes: current.fieldHashes)))
    guard case .applied(_, .complete) = cleared.outcome,
      case .applied(let replayResult, .complete(let replayCheckpoint)) =
        await fixture.planner.execute(
          PlannerOperation(
            operationId: operationIdentifier, session: fixture.session, command: command)
        ).outcome
    else {
      Issue.record("Exact old replay must retain explicit clearing and the original receipt.")
      return
    }
    #expect(replayResult == result)
    #expect(replayCheckpoint == checkpoint)
    let changedRepresentation = await fixture.planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(estimate: .set(PlannerEstimate(minutes: 86_400, displayUnit: .day))),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .rejected(let mismatch) = changedRepresentation.outcome,
      case .source(.item(let finalItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else {
      Issue.record("Changed display units cannot reuse an estimate operation.")
      return
    }
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(finalItem.content.estimate == nil)
    #expect(finalItem.content.title == "Hotel")
    #expect(finalItem.content.notes == "Original notes")
    #expect(finalItem.state.globalDone == true)
    #expect(finalItem.state.archived == true)
    let staleAfterClear = await fixture.planner.execute(
      PlannerOperation(
        operationId: UUID(), session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(estimate: .set(PlannerEstimate(minutes: 60, displayUnit: .hour))),
          expectedFieldHashes: current.fieldHashes)))
    guard case .rejected(let clearedReason) = staleAfterClear.outcome,
      case .staleEdit(let clearedFields, let clearedValues, let clearedHashes) = clearedReason
        .details
    else {
      Issue.record("A stale estimate must report its current explicit absence after clearing.")
      return
    }
    #expect(clearedFields == [.estimate])
    #expect(clearedValues == [.estimate: .optionalEstimate(nil)])
    #expect(clearedHashes[.estimate] == finalItem.fieldHashes[.estimate])
  }

  @Test(arguments: [Int64(0), Int64(-1), Int64.min])
  func nonPositiveEstimateRejectsWholePatchWithoutChangingSavedData(_ estimateMinutes: Int64)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let operationIdentifier = UUID()
    let invalid = await fixture.planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(
            title: .set("Must not save"),
            estimate: .set(PlannerEstimate(minutes: estimateMinutes, displayUnit: .minute))),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .rejected(let reason) = invalid.outcome,
      case .source(.item(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item)),
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .listedNamespaces(let namespaces) = await fixture.planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("Non-positive estimates must reject before any patch or receipt: \(invalid)")
      return
    }
    #expect(reason.code == "invalidInput")
    #expect(reason.propertyPath == "/command/changes/estimate/minutes")
    #expect(retained.content.title == "Hotel")
    #expect(retained.content.estimate == PlannerEstimate(minutes: 91, displayUnit: .hour))
    #expect(retained.updatedAt == fixture.original.updatedAt)
    #expect(retained.fieldHashes == fixture.original.fieldHashes)
    #expect(retained.references == fixture.original.references)
    #expect(retained.state.globalDone == true)
    #expect(retained.state.archived == true)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
  }

  @Test(arguments: [
    PlannerEstimate(minutes: 1, displayUnit: .minute),
    PlannerEstimate(minutes: 9_223_372_036_854_775_807, displayUnit: .year),
  ])
  func positiveEstimateBoundsPersistExactValuesThroughTitleEditAndReopen(
    _ expectedEstimate: PlannerEstimate
  ) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let operationIdentifier = UUID()
    let command = PlannerCommand.editItem(
      sourceId: fixture.item.id, changes: .init(estimate: .set(expectedEstimate)),
      expectedFieldHashes: fixture.original.fieldHashes)
    guard
      case .applied(let result, .complete(let checkpoint)) = await fixture.planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: fixture.session, command: command)
      ).outcome,
      case .applied(_, .complete) = await fixture.planner.execute(
        PlannerOperation(
          operationId: UUID(), session: fixture.session,
          command: .editItem(
            sourceId: fixture.item.id, changes: .init(title: .set("Tokyo Hotel")),
            expectedFieldHashes: fixture.original.fieldHashes))
      ).outcome
    else {
      Issue.record("Positive Int64 estimates and an independent title edit must save exactly.")
      return
    }
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(fixture.item)),
      case .applied(let replayResult, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .source(.item(let afterReplay)) = await reopened.read(
        session: reopenedSession, request: .source(fixture.item)),
      case .source(.schedule(let schedule)) = await reopened.read(
        session: reopenedSession, request: .source(fixture.schedule)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Estimate bounds must reopen with the original replay and independent recovery.")
      return
    }
    #expect(current.content.estimate == expectedEstimate)
    #expect(current.content.title == "Tokyo Hotel")
    #expect(current.content.subtitle == "Stay near the station")
    #expect(current.content.notes == "Original notes")
    #expect(current.state.globalDone == true)
    #expect(current.state.archived == true)
    #expect(schedule.content.form == fixture.startOnlyForm)
    #expect(replayResult == result)
    #expect(replayCheckpoint == checkpoint)
    #expect(afterReplay.content.estimate == expectedEstimate)
    #expect(afterReplay.content.title == "Tokyo Hotel")
    #expect(afterReplay.updatedAt == current.updatedAt)
    let namespace = try #require(namespaces.first)
    guard
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "The original estimate checkpoint must retain its exact minutes and display unit.")
      return
    }
    #expect(selection.decodedBackup.backup.items.first?.content.estimate == expectedEstimate)
  }

  private struct Fixture {
    let configuration: PlannerStorageConfiguration
    let planner: Planner
    let session: PlannerDatasetSession
    let item: PlannerEntityReference
    let original: PlannerItemSourceRead
    let schedule: PlannerEntityReference
    let originalSchedule: PlannerScheduleSourceRead
    let startOnlyForm: PlannerScheduleForm
  }

  private func makeFixture(directory: URL) async throws -> Fixture? {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let startOnlyForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: "Hotel", subtitle: "Stay near the station", notes: "Original notes",
              location: .init(
                displayName: nil, formattedAddress: "Meeting point A", coordinate: nil),
              estimate: .init(minutes: 91, displayUnit: .hour))))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: startOnlyForm))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: item, archived: true))
      ).outcome,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let originalSchedule)) = await planner.read(
        session: session, request: .source(schedule))
    else {
      Issue.record("The saved Item, states and start-only Schedule must initialize before editing.")
      return nil
    }
    return Fixture(
      configuration: configuration, planner: planner, session: session, item: item,
      original: original, schedule: schedule, originalSchedule: originalSchedule,
      startOnlyForm: startOnlyForm)
  }
}
