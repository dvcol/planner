import Foundation
import PlannerCore
import Testing

struct ItineraryItemQueryAdmissionTests {
  @Test func missingItineraryAndInvalidQueriesPreserveTheIssuedWindowAndRecovery() async throws {
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
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route", notes: "Keep notes")))
        .generated.first)
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard
      case .snapshot(let issued) = await planner.query(
        .init(session: session, request: .items(.init(scope: .itinerary(itinerary.id))))),
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let originalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    for identifier in [item.id, list.id, UUID()] {
      guard
        case .failed(let failure) = await planner.query(
          .init(session: session, request: .items(.init(scope: .itinerary(identifier)))))
      else { throw CancellationError() }
      #expect(failure.code == "missingReference")
    }
    let invalid: [PlannerItemQuery] = [
      .init(scope: .itinerary(itinerary.id), duration: .init(minimumMinutes: -1)),
      .init(scope: .itinerary(itinerary.id), duration: .init(minimumMinutes: 5, maximumMinutes: 4)),
      .init(scope: .itinerary(itinerary.id), sort: .init(mode: .manual, direction: .descending)),
      .init(
        scope: .itinerary(itinerary.id),
        rowPresentation: .init(referenceInstant: Date(), displayTimeZone: "Not/AZone")),
    ]
    for query in invalid {
      guard
        case .failed(let failure) = await planner.query(
          .init(session: session, request: .items(query)))
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput")
    }
    for (offset, limit) in [(-1 as Int64, 1 as Int64), (0, 0)] {
      guard
        case .failed(let failure) = await planner.read(
          session: session,
          request: .rows(generation: issued.generation, offset: offset, limit: limit))
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput")
    }
    guard
      case .rows(let retainedWindow) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .source(.itinerary(let retained)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let retainedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let retainedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(retainedWindow.rows.map(\.identity) == issued.rows && retainedWindow.matchingCount == 1)
    #expect(retained.content == before.content && retained.fieldHashes == before.fieldHashes)
    #expect(retained.references == before.references && retained.updatedAt == before.updatedAt)
    #expect(retainedRecovery.portableData == originalRecovery.portableData)
    #expect(retainedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
  }
}
