import Foundation
import PlannerCore
import Testing

struct ItineraryItemFilterTests {
  @Test func itineraryFiltersNarrowAppearancesCumulativelyAndSortsKeepUnknownDurationsLast()
    async throws
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
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Food"))).generated.first)
    let tag = try #require(try await save(.createTag(content: .init(name: "Rain"))).generated.first)
    let hotel = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Café Hotel", subtitle: "Tokyo", notes: "Keep notes",
            location: .init(
              displayName: "Hotel", formattedAddress: "Tokyo, Japan", coordinate: nil),
            estimate: .init(minutes: 120, displayUnit: .hour),
            links: [.init(originalUrl: "https://example.com/hotel")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    let museum = try #require(
      try await save(
        .createItem(
          content: .init(title: "Museum", estimate: .init(minutes: 90, displayUnit: .minute)))
      ).generated.first)
    let unknown = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Unknown",
            location: .init(
              displayName: "Pin", formattedAddress: nil,
              coordinate: .init(latitude: 35, longitude: 139)),
            links: [.init(originalUrl: "https://maps.apple.com/?q=Tokyo")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let otherList = try #require(
      try await save(.createList(content: .init(name: "Trip"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    for (item, destination) in [(hotel, list), (unknown, list), (hotel, otherList)] {
      _ = try await save(.addMembership(itemId: item.id, listId: destination.id, placement: .last))
    }
    for source in [hotel, museum, list] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    _ = try await save(.setArchive(source: museum, archived: true))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: museum.id), done: true))
    func query(_ query: PlannerItemQuery) async throws -> PlannerQuerySnapshot {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(session: session, request: .items(query)))
      else { throw CancellationError() }
      #expect(snapshot.progress.first?.totalCount == 4 && snapshot.progress.first?.doneCount == 1)
      return snapshot
    }
    func sourceIds(_ snapshot: PlannerQuerySnapshot) -> [UUID] {
      snapshot.rows.map { row in
        switch row {
        case .source(let source): source.id
        case .appearance(let source, _): source.id
        }
      }
    }
    let compound = try await query(
      .init(
        scope: .itinerary(itinerary.id), text: "  CAFE Tokyo  ", completion: .all, archive: .all,
        categories: .init(ids: [category.id], match: .all), tags: .init(ids: [tag.id], match: .all),
        lists: .init(ids: [list.id, otherList.id], match: .all),
        duration: .init(minimumMinutes: 90, maximumMinutes: 130), hasAddress: true, hasLinks: true))
    #expect(sourceIds(compound) == [hotel.id, hotel.id])
    let impossible = try await query(
      .init(
        scope: .itinerary(itinerary.id), completion: .all, archive: .all,
        categories: .init(ids: [UUID()], match: .any)))
    #expect(impossible.rows.isEmpty)
    let coordinateOnly = try await query(
      .init(
        scope: .itinerary(itinerary.id), text: "Unknown", completion: .all, archive: .all,
        hasAddress: true))
    #expect(coordinateOnly.rows.isEmpty)
    let mapsOnly = try await query(
      .init(
        scope: .itinerary(itinerary.id), text: "Unknown", completion: .all, archive: .all,
        hasLinks: true))
    #expect(sourceIds(mapsOnly) == [unknown.id])
    let unknownDuration = try await query(
      .init(
        scope: .itinerary(itinerary.id), completion: .all, archive: .all,
        duration: .init(minimumMinutes: 200, maximumMinutes: 300, includeUnknown: true)))
    #expect(sourceIds(unknownDuration) == [unknown.id])
    for (mode, direction, expected) in [
      (
        PlannerItemQuery.Sort.Mode.title, PlannerItemQuery.Sort.Direction.descending,
        [unknown.id, museum.id, hotel.id, hotel.id]
      ),
      (.duration, .ascending, [museum.id, hotel.id, hotel.id, unknown.id]),
      (.duration, .descending, [hotel.id, hotel.id, museum.id, unknown.id]),
      (.created, .ascending, [hotel.id, hotel.id, museum.id, unknown.id]),
      (.created, .descending, [unknown.id, museum.id, hotel.id, hotel.id]),
      (.lastUpdated, .descending, [museum.id, unknown.id, hotel.id, hotel.id]),
    ] {
      let sorted = try await query(
        .init(
          scope: .itinerary(itinerary.id), completion: .all, archive: .all,
          sort: .init(mode: mode, direction: direction)))
      #expect(sourceIds(sorted) == expected)
    }
    let active = try await query(.init(scope: .itinerary(itinerary.id), completion: .all))
    #expect(sourceIds(active) == [hotel.id, hotel.id, unknown.id])
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let before) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    _ = try await query(.init(scope: .itinerary(itinerary.id), completion: .all, archive: .all))
    guard
      case .listedNamespaces(let retainedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let after) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(after.portableData == before.portableData)
    #expect(retainedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
  }
}
