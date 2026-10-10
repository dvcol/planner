import Foundation
import PlannerCore
import Testing

struct ExpandedCompletionReplayTests {
  @Test func sameStateReorderAndReceiptReplayRetainTheLatestExpandedFlagAndSourceTimestamps()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
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
    let secondItem = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Stops"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let membership = try #require(
      try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
        .generatedReferences.first)
    _ = try await save(.addMembership(itemId: secondItem.id, listId: list.id, placement: .last))
    let reference = try #require(
      try await save(.addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
        .generatedReferences.first)
    guard case .membership(let membershipId, _, _) = membership,
      case .itineraryEntry(let entryId, _, _) = reference,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    let appearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entryId, membershipId: membershipId)
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(appearance), done: true))
    guard case .applied(let applied, .complete) = await planner.execute(operation).outcome,
      case .source(.itinerary(let changed)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.list(let unchangedList)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(unchangedList.updatedAt == originalList.updatedAt)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    guard
      case .source(.itinerary(let sameState)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(sameState.updatedAt == changed.updatedAt)
    _ = try await save(
      .reorderMembership(listId: list.id, membershipId: membershipId, placement: .last))
    guard
      case .appearance(let reordered) = await planner.read(
        session: session, request: .appearance(appearance))
    else { throw CancellationError() }
    #expect(reordered.localDone == true)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: false))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let beforeReplay)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .applied(let replay, .complete(let checkpoint)) = await reopened.execute(
        .init(
          operationId: operation.operationId,
          session: reopenedSession, command: operation.command)
      ).outcome,
      case .rejected(let mismatch) = await reopened.execute(
        .init(
          operationId: operation.operationId, session: reopenedSession,
          command: .setCompletion(scope: .appearance(appearance), done: false))
      ).outcome,
      case .appearance(let retained) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance)),
      case .source(.item(let currentItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 11)
      )
    else { throw CancellationError() }
    #expect(replay == applied)
    #expect(checkpoint == 8)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(retained.localDone == false)
    #expect(retained.effectiveDone == false)
    #expect(current.updatedAt == beforeReplay.updatedAt)
    #expect(current.fieldHashes == beforeReplay.fieldHashes)
    #expect(current.progress.doneCount == 0)
    #expect(current.progress.totalCount == 2)
    #expect(currentItem.updatedAt == originalItem.updatedAt)
    #expect(currentItem.fieldHashes == originalItem.fieldHashes)
    #expect(recovery.decodedBackup.backup.expandedCompletions.first?.localDone == false)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 11)
  }
}
