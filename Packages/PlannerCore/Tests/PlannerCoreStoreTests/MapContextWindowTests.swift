import Foundation
import PlannerCore
import Testing

struct MapContextWindowTests {
  @Test func contextualMapRowsRetainSavedPositionsAndHeaderOnlyBranches() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("Save the contextual Map fixture: \(response)")
        throw CancellationError()
      }
      return result
    }
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let museum = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let food = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let empty = try #require(
      try await save(.createList(content: .init(name: "Tokyo Empty"))).generated.first)
    func addMember(_ item: PlannerEntityReference) async throws -> UUID {
      guard
        case .membership(let identifier, _, _)? = try await save(
          .addMembership(itemId: item.id, listId: food.id, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      return identifier
    }
    let museumMembership = try await addMember(museum)
    let hotelMembership = try await addMember(hotel)
    func addEntry(_ source: PlannerEntityReference) async throws -> UUID {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      return identifier
    }
    let firstHotel = try await addEntry(hotel)
    let firstFood = try await addEntry(food)
    let secondFood = try await addEntry(food)
    let secondHotel = try await addEntry(hotel)
    let emptyEntry = try await addEntry(empty)
    guard case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let backup) = planner.decodeImport(before),
      case .source(.itinerary(let itinerarySource)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    let foodLifetime = try #require(backup.backup.lists.first { $0.id == food.id }?.lifetimeId)
    func page(_ query: PlannerItemQuery) async throws -> PlannerMapRowWindow {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(session: session, request: .items(query)))
      else { throw CancellationError() }
      let result = await planner.read(
        session: session, request: .mapRows(generation: snapshot.generation, offset: 0, limit: 64))
      guard case .mapRows(let window) = result else {
        Issue.record("Read the contextual Map inputs: \(result)")
        throw CancellationError()
      }
      #expect(window.rows.map(\.identity) == snapshot.rows)
      return window
    }
    let list = try await page(.init(scope: .list(food.id), completion: .all, archive: .all))
    #expect(list.collection?.source == food && list.collection?.title == "Tokyo Food")
    #expect(list.collection?.sourceLifetimeId == foodLifetime)
    #expect(list.listBranches.isEmpty && list.matchingCount == 2)
    #expect(list.rows.map(\.title) == ["Hotel", "Museum"])
    #expect(
      list.rows.map(\.placement) == [
        .listMembership(membershipId: hotelMembership, childPosition: 2),
        .listMembership(membershipId: museumMembership, childPosition: 1),
      ])
    let route = try await page(
      .init(scope: .itinerary(itinerary.id), completion: .all, archive: .all))
    #expect(route.collection?.source == itinerary && route.collection?.title == "Route")
    #expect(route.collection?.sourceLifetimeId == itinerarySource.sourceLifetimeId)
    #expect(route.matchingCount == 6)
    #expect(
      route.rows.map(\.identity) == [
        .appearance(
          source: hotel,
          appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: firstHotel)),
        .appearance(
          source: hotel,
          appearance: .expandedListItem(
            itineraryId: itinerary.id, listEntryId: firstFood, membershipId: hotelMembership)),
        .appearance(
          source: hotel,
          appearance: .expandedListItem(
            itineraryId: itinerary.id, listEntryId: secondFood, membershipId: hotelMembership)),
        .appearance(
          source: hotel,
          appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: secondHotel)),
        .appearance(
          source: museum,
          appearance: .expandedListItem(
            itineraryId: itinerary.id, listEntryId: firstFood, membershipId: museumMembership)),
        .appearance(
          source: museum,
          appearance: .expandedListItem(
            itineraryId: itinerary.id, listEntryId: secondFood, membershipId: museumMembership)),
      ])
    let branch = try #require(route.listBranches.first)
    #expect(branch.list.source == food && branch.list.title == "Tokyo Food")
    #expect(branch.list.sourceLifetimeId == foodLifetime)
    #expect(
      route.rows.map(\.placement) == [
        .itineraryItem(entryId: firstHotel, routePosition: 1),
        .itineraryListItem(
          entryId: firstFood, routePosition: 2, list: branch.list, membershipId: hotelMembership,
          childPosition: 2),
        .itineraryListItem(
          entryId: secondFood, routePosition: 3, list: branch.list, membershipId: hotelMembership,
          childPosition: 2),
        .itineraryItem(entryId: secondHotel, routePosition: 4),
        .itineraryListItem(
          entryId: firstFood, routePosition: 2, list: branch.list, membershipId: museumMembership,
          childPosition: 1),
        .itineraryListItem(
          entryId: secondFood, routePosition: 3, list: branch.list, membershipId: museumMembership,
          childPosition: 1),
      ])
    #expect(route.listBranches.map(\.entryId) == [firstFood, secondFood, emptyEntry])
    #expect(route.listBranches.map(\.routePosition) == [2, 3, 5])
    #expect(route.listBranches.map(\.matchesHeader) == [true, true, true])
    #expect(route.listBranches.map(\.matchingChildCount) == [2, 2, 0])
    for (text, itemOnly, expectedEntries, matchesHeader, counts) in [
      (
        "Tokyo", false, [firstFood, secondFood, emptyEntry], [true, true, true], [Int64(0), 0, 0]
      ),
      ("Museum", false, [firstFood, secondFood], [false, false], [Int64(1), 1]),
      ("Nothing", false, [], [], [Int64]()),
      ("Tokyo", true, [], [], [Int64]()),
    ] {
      let filtered = try await page(
        .init(
          scope: .itinerary(itinerary.id), text: text, completion: .all, archive: .all,
          hasLinks: itemOnly))
      #expect(filtered.listBranches.map(\.entryId) == expectedEntries)
      #expect(filtered.listBranches.map(\.matchesHeader) == matchesHeader)
      #expect(filtered.listBranches.map(\.matchingChildCount) == counts)
      #expect(filtered.matchingCount == counts.reduce(0, +))
      #expect(filtered.rows.allSatisfy { $0.title == "Museum" })
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
    for membership in [museumMembership, hotelMembership] {
      _ = try await save(
        .setCompletion(
          scope: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id, listEntryId: firstFood, membershipId: membership)),
          done: true))
    }
    let doneHeaders = try await page(
      .init(scope: .itinerary(itinerary.id), text: "Tokyo", completion: .done, archive: .all))
    #expect(doneHeaders.rows.isEmpty && doneHeaders.matchingCount == 0)
    #expect(doneHeaders.listBranches.map(\.entryId) == [firstFood])
    let todoHeaders = try await page(
      .init(scope: .itinerary(itinerary.id), text: "Tokyo", completion: .todo, archive: .all))
    #expect(todoHeaders.listBranches.map(\.entryId) == [secondFood, emptyEntry])
    _ = try await save(.setArchive(source: food, archived: true))
    let archivedBranches = try await page(
      .init(scope: .itinerary(itinerary.id), text: "Tokyo", completion: .done, archive: .all))
    #expect(archivedBranches.listBranches.map(\.entryId) == [firstFood, secondFood])
    #expect(archivedBranches.listBranches.map(\.matchingChildCount) == [0, 0])
  }
}
