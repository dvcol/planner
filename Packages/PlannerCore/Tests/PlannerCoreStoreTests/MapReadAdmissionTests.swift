import Foundation
import PlannerCore
import Testing

struct MapReadAdmissionTests {
  @Test func emptyMapQueriesAndRejectedRequestsPreserveDataAndGeneration() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init())))
    else { throw CancellationError() }
    for (offset, limit): (Int64, Int64) in [(0, 1), (1, 64), (.max, .max)] {
      let result = await planner.read(
        session: session,
        request: .mapRows(generation: snapshot.generation, offset: offset, limit: limit))
      guard case .mapRows(let page) = result else {
        Issue.record("Read the empty Map page: \(result)")
        return
      }
      #expect(page.generation == snapshot.generation && page.offset == offset)
      #expect(page.matchingCount == 0 && page.rows.isEmpty)
      #expect(page.collection == nil && page.listBranches.isEmpty)
    }
    for (offset, limit): (Int64, Int64) in [(-1, 1), (0, 0), (0, -1)] {
      guard
        case .failed(let failure) = await planner.read(
          session: session,
          request: .mapRows(generation: snapshot.generation, offset: offset, limit: limit))
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput")
    }
    let day = PlannerCivilDate(year: 2026, month: 10, day: 9)
    for request in [
      PlannerQueryRequest.catalog(.init(sourceKind: .list)),
      .calendar(.init(startDay: day, endDay: day, displayTimeZone: "Asia/Tokyo")),
    ] {
      guard
        case .snapshot(let wrongKind) = await planner.query(
          .init(session: session, request: request)),
        case .failed(let failure) = await planner.read(
          session: session, request: .mapRows(generation: wrongKind.generation, offset: 0, limit: 1)
        )
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput")
    }
    guard case .ready(let otherSession) = await planner.bootstrap(),
      case .failed(let crossSession) = await planner.read(
        session: otherSession,
        request: .mapRows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .failed(let unknown) = await planner.read(
        session: session, request: .mapRows(generation: UUID(), offset: 0, limit: 1)),
      case .mapRows(let retained) = await planner.read(
        session: session, request: .mapRows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(crossSession.code == "staleSnapshot" && unknown.code == "staleSnapshot")
    #expect(retained.rows.isEmpty && retained.matchingCount == 0)
    #expect(before == after)
  }

  @Test func anotherWriterInvalidatesCachedMapInputsAndContextWithoutRetargeting() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand, writer: Planner, session: PlannerDatasetSession)
      async throws -> PlannerAppliedResult
    {
      let response = await writer.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("Save the Map change: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(
        .createItem(content: .init(title: "Museum")), writer: planner, session: session
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food")), writer: planner, session: session)
        .generated.first)
    let itinerary = try #require(
      try await save(
        .createItinerary(content: .init(title: "Route")), writer: planner, session: session
      ).generated.first)
    guard
      case .membership(let membership, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last), writer: planner,
        session: session
      ).generatedReferences.first
    else { throw CancellationError() }
    guard
      case .itineraryEntry(let directEntry, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last),
        writer: planner, session: session
      ).generatedReferences.first
    else { throw CancellationError() }
    guard
      case .itineraryEntry(let listEntry, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last),
        writer: planner, session: session
      ).generatedReferences.first
    else { throw CancellationError() }
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap() else {
      throw CancellationError()
    }
    func queryAndRead() async throws -> (snapshot: PlannerQuerySnapshot, page: PlannerMapRowWindow)
    {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .items(
              .init(scope: .itinerary(itinerary.id), completion: .all, archive: .all)))),
        case .mapRows(let page) = await planner.read(
          session: session, request: .mapRows(generation: snapshot.generation, offset: 0, limit: 64)
        )
      else { throw CancellationError() }
      return (snapshot, page)
    }
    func requireStale(_ generation: UUID) async throws {
      guard
        case .failed(let failure) = await planner.read(
          session: session, request: .mapRows(generation: generation, offset: 0, limit: 64))
      else { throw CancellationError() }
      #expect(failure.code == "staleSnapshot")
      #expect(
        failure.details == .staleSnapshot(requestedGeneration: generation, currentGeneration: nil))
    }
    var current = try await queryAndRead()
    #expect(current.page.rows.count == 2 && current.page.listBranches.first?.routePosition == 2)
    guard
      case .source(.item(let original)) = await otherWriter.read(
        session: otherSession, request: .source(item))
    else { throw CancellationError() }
    let location = PlannerOwnedLocation(
      displayName: "Saved entrance", formattedAddress: "1 Museum Way",
      coordinate: .init(latitude: 35, longitude: 139))
    _ = try await save(
      .editItem(
        sourceId: item.id,
        changes: .init(
          title: .set("Updated museum"), location: .set(location),
          links: .set([
            .init(originalUrl: "https://maps.apple.com/?q=Updated%20museum", label: "Entrance")
          ])), expectedFieldHashes: original.fieldHashes), writer: otherWriter,
      session: otherSession)
    try await requireStale(current.snapshot.generation)
    current = try await queryAndRead()
    #expect(
      current.page.rows.allSatisfy { $0.title == "Updated museum" && $0.ownedLocation == location })
    #expect(
      current.page.rows.allSatisfy {
        $0.mapsLinks.map(\.originalUrl) == ["https://maps.apple.com/?q=Updated%20museum"]
      })
    #expect(current.page.rows.map(\.identity) == current.snapshot.rows)
    _ = try await save(
      .reorderItineraryEntry(itineraryId: itinerary.id, entryId: listEntry, placement: .first),
      writer: otherWriter, session: otherSession)
    try await requireStale(current.snapshot.generation)
    current = try await queryAndRead()
    #expect(current.page.listBranches.first?.routePosition == 1)
    _ = try await save(
      .removeMembership(listId: list.id, membershipId: membership), writer: otherWriter,
      session: otherSession)
    try await requireStale(current.snapshot.generation)
    current = try await queryAndRead()
    #expect(
      current.page.rows.count == 1 && current.page.listBranches.first?.matchingChildCount == 0)
    #expect(
      current.page.rows.first?.identity
        == .appearance(
          source: item,
          appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: directEntry)))
    guard
      case .reviewed(let review) = await otherWriter.prepareReview(
        session: otherSession, command: .deleteSource(source: item)),
      case .applied(_, .complete) = await otherWriter.execute(
        .init(
          operationId: UUID(), session: otherSession, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    try await requireStale(current.snapshot.generation)
    let empty = try await queryAndRead()
    #expect(empty.page.rows.isEmpty && empty.page.matchingCount == 0)
    #expect(empty.page.listBranches.first?.entryId == listEntry)
  }
}
