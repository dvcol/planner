import Foundation
import PlannerCore
import Testing

struct ItineraryEntryPlacementTests {
  @Test func denseRepeatedEntryPlacementAndLiveListExpansionPreserveEveryAppearance() async throws {
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
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    func add(_ placement: PlannerPlacement, source: PlannerEntityReference) async throws
      -> PlannerReferenceRead
    {
      try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: placement)
        ).generatedReferences.first)
    }
    let first = try await add(.last, source: item)
    let last = try await add(.last, source: item)
    guard case .itineraryEntry(let firstId, _, _) = first,
      case .itineraryEntry(let lastId, _, _) = last
    else { throw CancellationError() }
    let leading = try await add(.first, source: item)
    let beforeLast = try await add(.before(associationId: lastId), source: item)
    var dense: [PlannerReferenceRead] = []
    for _ in 0..<14 { dense.append(try await add(.after(associationId: firstId), source: item)) }
    let expected = [leading, first] + dense.reversed() + [beforeLast, last]
    let list = try #require(
      try await save(.createList(content: .init(name: "Live list"))).generated.first)
    let listEntry = try await add(.last, source: list)
    guard case .itineraryEntry(let listEntryId, _, _) = listEntry,
      case .source(.itinerary(let initial)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .appearance(let firstRead) = await planner.read(
        session: session,
        request: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: firstId))),
      case .failed(let wrongOwner) = await planner.read(
        session: session,
        request: .appearance(.directItineraryItem(itineraryId: UUID(), entryId: firstId))),
      case .failed(let wrongKind) = await planner.read(
        session: session,
        request: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: listEntryId)))
    else { throw CancellationError() }
    #expect(initial.references == expected + [listEntry])
    #expect(initial.progress.totalCount == 18)
    #expect(firstRead.content.title == "Hotel")
    #expect(firstRead.source == item)
    #expect(firstRead.localDone == false)
    #expect(firstRead.effectiveDone == false)
    #expect(wrongOwner.code == "missingReference")
    #expect(wrongKind.code == "missingReference")
    let membership = try #require(
      try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
        .generatedReferences.first)
    guard case .membership(let membershipId, _, _) = membership else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipId)), done: true
      ))
    guard
      case .source(.itinerary(let expanded)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let itemRead)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(expanded.progress.totalCount == 19)
    #expect(expanded.progress.doneCount == 0)
    #expect(itemRead.references.count == 19)
    #expect(listRead.references == [membership, listEntry])
    _ = try await save(.removeMembership(listId: list.id, membershipId: membershipId))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(retained.references == expected + [listEntry])
    #expect(retained.progress.totalCount == 18)
    let entries = recovery.decodedBackup.backup.itineraryEntries.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.id.uuidString < $1.id.uuidString
    }
    let expectedIds = try (expected + [listEntry]).map { reference -> UUID in
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      return identifier
    }
    #expect(entries.map(\.id) == expectedIds)
    #expect(entries.allSatisfy { $0.id == $0.lifetimeId })
    #expect(entries.filter { $0.source.kind == .item }.allSatisfy { $0.localDone == false })
    #expect(entries.last?.localDone == nil)
    #expect(recovery.decodedBackup.backup.memberships.isEmpty)
  }
}
