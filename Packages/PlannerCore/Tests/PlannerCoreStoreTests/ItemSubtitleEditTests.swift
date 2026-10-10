import Foundation
import PlannerCore
import Testing

struct ItemSubtitleEditTests {
  @Test func subtitleEditAndClearPreserveOtherContentAndSurviveReopenWithRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let operationIdentifier = UUID()
    let edited = await fixture.planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(subtitle: .set("Museum and garden")),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .applied(let result, .complete(let checkpoint)) = edited.outcome else {
      Issue.record("The guarded subtitle must save with complete local recovery: \(edited)")
      return
    }
    #expect(result.generated.isEmpty)
    #expect(result.affected == [fixture.item])
    let reopenedPlanner = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopenedPlanner.bootstrap(),
      case .source(.item(let current)) = await reopenedPlanner.read(
        session: reopenedSession, request: .source(fixture.item))
    else {
      Issue.record("The edited Item must reopen through its public source read.")
      return
    }
    #expect(current.content.subtitle == "Museum and garden")
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Original notes")
    #expect(current.content.location?.formattedAddress == "Meeting point A")
    #expect(current.content.estimate == PlannerEstimate(minutes: 91, displayUnit: .hour))
    #expect(current.state.globalDone == true)
    #expect(current.state.archived == true)
    #expect(current.source == fixture.item)
    #expect(current.createdAt == fixture.original.createdAt)
    #expect(current.fieldHashes[.title] == fixture.original.fieldHashes[.title])
    #expect(current.fieldHashes[.notes] == fixture.original.fieldHashes[.notes])
    #expect(current.fieldHashes[.location] == fixture.original.fieldHashes[.location])
    #expect(current.fieldHashes[.estimate] == fixture.original.fieldHashes[.estimate])
    #expect(current.fieldHashes[.subtitle] != fixture.original.fieldHashes[.subtitle])
    let status = await reopenedPlanner.operationStatus(
      session: reopenedSession, operationId: operationIdentifier)
    guard case .appliedRecoveryComplete(let savedResult, let savedCheckpoint) = status else {
      Issue.record("The subtitle save must retain complete operation evidence: \(status)")
      return
    }
    #expect(savedResult == result)
    #expect(savedCheckpoint == checkpoint)
    guard
      case .listedNamespaces(let namespaces) = await reopenedPlanner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("The independent recovery namespace must remain discoverable.")
      return
    }
    let namespace = try #require(namespaces.first)
    guard
      case .selected(let selection) = await reopenedPlanner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("The acknowledged subtitle backup must remain inspectable.")
      return
    }
    #expect(selection.decodedBackup.backup.items.first?.content.subtitle == "Museum and garden")
    let cleared = await reopenedPlanner.execute(
      PlannerOperation(
        operationId: UUID(), session: reopenedSession,
        command: .editItem(
          sourceId: fixture.item.id, changes: .init(subtitle: .clear),
          expectedFieldHashes: current.fieldHashes)))
    guard case .applied(_, .complete) = cleared.outcome else {
      Issue.record("Explicit subtitle clearing must save: \(cleared)")
      return
    }
    let clearedPlanner = Planner(configuration: fixture.configuration)
    guard case .ready(let clearedSession) = await clearedPlanner.bootstrap(),
      case .source(.item(let clearedItem)) = await clearedPlanner.read(
        session: clearedSession, request: .source(fixture.item))
    else {
      Issue.record("The cleared subtitle must reopen.")
      return
    }
    #expect(clearedItem.content.subtitle == nil)
    #expect(clearedItem.content.title == "Hotel")
    #expect(clearedItem.content.notes == "Original notes")
    #expect(clearedItem.content.estimate == PlannerEstimate(minutes: 91, displayUnit: .hour))
    #expect(clearedItem.state.globalDone == true)
    #expect(clearedItem.state.archived == true)
  }

  @Test func staleSubtitleRejectsWholePatchAndReplayRetainsTheOriginalOperation() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let operationIdentifier = UUID()
    let subtitleCommand = PlannerCommand.editItem(
      sourceId: fixture.item.id, changes: .init(subtitle: .set("Museum and garden")),
      expectedFieldHashes: fixture.original.fieldHashes)
    let edited = await fixture.planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: fixture.session, command: subtitleCommand))
    guard case .applied(let result, .complete) = edited.outcome,
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else {
      Issue.record("The current subtitle and its hash must save before the stale patch.")
      return
    }
    let stalePatch = await fixture.planner.execute(
      PlannerOperation(
        operationId: UUID(), session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(title: .set("Rejected title"), subtitle: .set("Old subtitle proposal")),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .rejected(let reason) = stalePatch.outcome,
      case .staleEdit(let fields, let values, let hashes) = reason.details
    else {
      Issue.record("The changed subtitle must reject the complete stale patch: \(stalePatch)")
      return
    }
    #expect(reason.code == "staleEdit")
    #expect(fields == [.subtitle])
    #expect(values == [.subtitle: .optionalString("Museum and garden")])
    #expect(hashes[.subtitle] == current.fieldHashes[.subtitle])
    guard
      case .source(.item(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else {
      Issue.record("The rejected patch must leave the Item readable.")
      return
    }
    #expect(retained.content.title == "Hotel")
    #expect(retained.content.subtitle == "Museum and garden")
    #expect(retained.updatedAt == current.updatedAt)
    #expect(retained.fieldHashes == current.fieldHashes)
    let titleEdit = await fixture.planner.execute(
      PlannerOperation(
        operationId: UUID(), session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id, changes: .init(title: .set("Tokyo Hotel")),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .applied(_, .complete) = titleEdit.outcome else {
      Issue.record("An unchanged title hash must permit the independent edit: \(titleEdit)")
      return
    }
    let replay = await fixture.planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: fixture.session, command: subtitleCommand))
    guard case .applied(let replayResult, .complete) = replay.outcome else {
      Issue.record("Exact subtitle replay must return the original evidence: \(replay)")
      return
    }
    #expect(replayResult == result)
    let differentPayload = await fixture.planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id, changes: .init(subtitle: .set("Different subtitle")),
          expectedFieldHashes: fixture.original.fieldHashes)))
    guard case .rejected(let mismatch) = differentPayload.outcome else {
      Issue.record("A changed subtitle cannot reuse the original operation: \(differentPayload)")
      return
    }
    #expect(mismatch.code == "operationPayloadMismatch")
    guard
      case .source(.item(let finalItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else {
      Issue.record("Replay and rejection must retain the current Item.")
      return
    }
    #expect(finalItem.content.title == "Tokyo Hotel")
    #expect(finalItem.content.subtitle == "Museum and garden")
    #expect(finalItem.content.notes == "Original notes")
    #expect(finalItem.state.globalDone == true)
    #expect(finalItem.state.archived == true)
  }

  private struct Fixture {
    let configuration: PlannerStorageConfiguration
    let planner: Planner
    let session: PlannerDatasetSession
    let item: PlannerEntityReference
    let original: PlannerItemSourceRead
  }

  private func makeFixture(directory: URL) async throws -> Fixture? {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real local dataset must initialize.")
      return nil
    }
    let creation = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: .init(
            title: "Hotel", subtitle: "Stay near the station", notes: "Original notes",
            location: .init(displayName: nil, formattedAddress: "Meeting point A", coordinate: nil),
            estimate: .init(minutes: 91, displayUnit: .hour)))))
    guard case .applied(let creationResult, .complete) = creation.outcome else {
      Issue.record("The Item fixture must save: \(creation)")
      return nil
    }
    let item = try #require(creationResult.generated.first)
    let completion = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .setCompletion(scope: .globalItem(itemId: item.id), done: true)))
    guard case .applied(_, .complete) = completion.outcome else {
      Issue.record("The fixture's global completion must save: \(completion)")
      return nil
    }
    let archive = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session, command: .setArchive(source: item, archived: true)))
    guard case .applied(_, .complete) = archive.outcome,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("The archived fixture must supply its current public field hashes.")
      return nil
    }
    return Fixture(
      configuration: configuration, planner: planner, session: session, item: item,
      original: original)
  }
}
