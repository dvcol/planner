import Foundation
import PlannerCore
import Testing

struct ItineraryEntryCompletionTests {
  @Test func directCompletionIsIndependentAndGlobalReopenRevealsRetainedLocalState() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "A"))).generated.first)
    let other = try #require(
      try await save(.createItinerary(content: .init(title: "B"))).generated.first)
    var entries: [UUID] = []
    for owner in [itinerary, itinerary, other] {
      let reference = try #require(
        try await save(.addItineraryEntry(itineraryId: owner.id, source: item, placement: .last))
          .generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      entries.append(identifier)
    }
    let first = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: entries[0])
    let second = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: entries[1])
    let third = PlannerAppearance.directItineraryItem(itineraryId: other.id, entryId: entries[2])
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else { throw CancellationError() }
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(first), done: true))
    guard
      case .applied(let applied, .complete(let originalCheckpoint)) = await planner.execute(
        operation
      ).outcome
    else {
      Issue.record("Complete only the selected direct itinerary appearance.")
      return
    }
    guard
      case .source(.itinerary(let partial)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .appearance(let firstLocal) = await planner.read(
        session: session, request: .appearance(first)),
      case .appearance(let secondLocal) = await planner.read(
        session: session, request: .appearance(second)),
      case .appearance(let otherLocal) = await planner.read(
        session: session, request: .appearance(third)),
      case .source(.item(let afterLocal)) = await planner.read(
        session: session, request: .source(item))
    else { throw CancellationError() }
    #expect(partial.progress.doneCount == 1)
    #expect(partial.progress.totalCount == 2)
    #expect(firstLocal.localDone == true)
    #expect(firstLocal.effectiveDone == true)
    #expect(secondLocal.localDone == false)
    #expect(secondLocal.effectiveDone == false)
    #expect(otherLocal.effectiveDone == false)
    #expect(afterLocal.updatedAt == originalItem.updatedAt)
    #expect(afterLocal.fieldHashes == originalItem.fieldHashes)
    #expect(afterLocal.state.globalDone == false)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await save(.setCompletion(scope: .appearance(second), done: true))
    _ = try await save(.setCompletion(scope: .appearance(second), done: false))
    guard
      case .appearance(let inherited) = await planner.read(
        session: session, request: .appearance(second))
    else { throw CancellationError() }
    #expect(inherited.globalDone == true)
    #expect(inherited.localDone == false)
    #expect(inherited.effectiveDone == true)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: false))
    _ = try await save(.setArchive(source: item, archived: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .appearance(let retained) = await reopened.read(
        session: reopenedSession, request: .appearance(first)),
      case .appearance(let reopenedSecond) = await reopened.read(
        session: reopenedSession, request: .appearance(second)),
      case .appearance(let reopenedOther) = await reopened.read(
        session: reopenedSession, request: .appearance(third)),
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .rejected(let mismatch) = await reopened.execute(
        .init(
          operationId: operation.operationId, session: reopenedSession,
          command: .setCompletion(scope: .appearance(first), done: false))
      ).outcome,
      case .applied(let replay, .complete(let checkpoint)) = await reopened.execute(
        .init(
          operationId: operation.operationId,
          session: reopenedSession, command: operation.command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 12)
      )
    else { throw CancellationError() }
    #expect(retained.localDone == true)
    #expect(retained.globalDone == false)
    #expect(retained.effectiveDone == true)
    #expect(retained.archived == true)
    #expect(reopenedSecond.effectiveDone == false)
    #expect(reopenedOther.effectiveDone == false)
    #expect(current.progress.doneCount == 1)
    #expect(current.progress.totalCount == 2)
    #expect(replay == applied)
    #expect(checkpoint == originalCheckpoint)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(
      recovery.decodedBackup.backup.itineraryEntries.filter { $0.localDone == true }.map(\.id) == [
        entries[0]
      ])
    #expect(recovery.decodedBackup.backup.items.first?.globalDone == false)
    #expect(recovery.decodedBackup.backup.items.first?.archived == true)
    #expect(namespace.preparedProposals.isEmpty)
  }
}
