import Foundation
import PlannerCore
import Testing

struct ItineraryEntryCompletionAdmissionTests {
  @Test func completionReplaySameStateAndInvalidAppearancesPreserveCurrentLocalFlags() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
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
      try await save(.createItinerary(content: .init(title: "Plan"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Empty"))).generated.first)
    let direct = try #require(
      try await save(.addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
        .generatedReferences.first)
    let listEntry = try #require(
      try await save(.addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
        .generatedReferences.first)
    guard case .itineraryEntry(let entryId, _, _) = direct,
      case .itineraryEntry(let listEntryId, _, _) = listEntry
    else { throw CancellationError() }
    let appearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: entryId)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(appearance), done: true))
    guard case .applied(let result, .complete) = await planner.execute(operation).outcome,
      case .source(.itinerary(let changed)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    guard
      case .source(.itinerary(let sameState)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(sameState.updatedAt == changed.updatedAt)
    #expect(sameState.fieldHashes == changed.fieldHashes)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: false))
    let invalid = [
      PlannerAppearance.directItineraryItem(itineraryId: UUID(), entryId: entryId),
      .directItineraryItem(itineraryId: itinerary.id, entryId: listEntryId),
      .directItineraryItem(itineraryId: itinerary.id, entryId: UUID()),
    ]
    for invalidAppearance in invalid {
      let operationId = UUID()
      guard
        case .rejected(let failure) = await planner.execute(
          .init(
            operationId: operationId, session: session,
            command: .setCompletion(scope: .appearance(invalidAppearance), done: true))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationId)
      else { throw CancellationError() }
      #expect(failure.code == "missingReference")
    }
    guard
      case .applied(let replay, .complete(let originalCheckpoint)) = await planner.execute(
        operation
      ).outcome,
      case .appearance(let retained) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else { throw CancellationError() }
    #expect(replay == result)
    #expect(originalCheckpoint == 7)
    #expect(retained.localDone == false)
    #expect(retained.globalDone == true)
    #expect(retained.effectiveDone == true)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 9)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: false))
    guard
      case .appearance(let reopened) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .source(.itinerary(let current)) = await planner.read(
        session: session, request: .source(itinerary)),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 10)
      )
    else { throw CancellationError() }
    #expect(reopened.effectiveDone == false)
    #expect(current.progress.doneCount == 0)
    #expect(current.progress.totalCount == 1)
    #expect(
      recovery.decodedBackup.backup.itineraryEntries.first { $0.id == entryId }?.localDone == false)
    #expect(
      recovery.decodedBackup.backup.itineraryEntries.first { $0.id == listEntryId }?.localDone
        == nil)
  }
}
