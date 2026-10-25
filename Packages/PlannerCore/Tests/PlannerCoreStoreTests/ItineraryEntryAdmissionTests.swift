import Foundation
import PlannerCore
import Testing

struct ItineraryEntryAdmissionTests {
  @Test func invalidSourcesOwnersAnchorsAndReusedPayloadsLeaveTheGraphAndRecoveryUnchanged()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
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
      try await save(.createItinerary(content: .init(title: "A"))).generated.first)
    let other = try #require(
      try await save(.createItinerary(content: .init(title: "B"))).generated.first)
    let foreign = try #require(
      try await save(.addItineraryEntry(itineraryId: other.id, source: item, placement: .last))
        .generatedReferences.first)
    guard case .itineraryEntry(let foreignId, _, _) = foreign else { throw CancellationError() }
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard case .applied(let applied, .complete) = await planner.execute(operation).outcome,
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    let cases: [(PlannerCommand, String, String?)] = [
      (
        .addItineraryEntry(itineraryId: itinerary.id, source: itinerary, placement: .last),
        "invalidInput", "/command/source/kind"
      ),
      (
        .addItineraryEntry(
          itineraryId: itinerary.id, source: .init(kind: .category, id: UUID()), placement: .last),
        "invalidInput", "/command/source/kind"
      ),
      (
        .addItineraryEntry(itineraryId: UUID(), source: item, placement: .last), "missingReference",
        nil
      ),
      (
        .addItineraryEntry(
          itineraryId: itinerary.id, source: .init(kind: .item, id: UUID()), placement: .last),
        "missingReference", nil
      ),
      (
        .addItineraryEntry(
          itineraryId: itinerary.id, source: .init(kind: .list, id: UUID()), placement: .last),
        "missingReference", nil
      ),
      (
        .addItineraryEntry(
          itineraryId: itinerary.id, source: item, placement: .before(associationId: foreignId)),
        "missingReference", "/command/placement/associationId"
      ),
      (
        .addItineraryEntry(
          itineraryId: itinerary.id, source: item, placement: .after(associationId: UUID())),
        "missingReference", "/command/placement/associationId"
      ),
    ]
    for (command, code, path) in cases {
      guard
        case .rejected(let failure) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Reject invalid entries before applying any graph or recovery changes.")
        return
      }
      #expect(failure.code == code)
      #expect(failure.propertyPath == path)
    }
    guard
      case .rejected(let mismatch) = await planner.execute(
        .init(
          operationId: operation.operationId, session: session,
          command: .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .first))
      ).outcome,
      case .applied(let replay, .complete(let checkpoint)) = await planner.execute(operation)
        .outcome,
      case .source(.itinerary(let current)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(replay == applied)
    #expect(checkpoint == 5)
    #expect(current.references == before.references)
    #expect(current.updatedAt == before.updatedAt)
    #expect(current.fieldHashes == before.fieldHashes)
    #expect(current.progress.totalCount == 1)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 5)
    #expect(namespace.preparedProposals.isEmpty)
  }
}
