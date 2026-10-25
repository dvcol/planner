import Foundation
import PlannerCore
import Testing

struct ItineraryManualQueryTests {
  @Test func manualItineraryQueriesRetainRouteChildOrderAndIndependentCompletion() async throws {
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
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Zulu Hotel"))).generated.first)
    let museum = try #require(
      try await save(.createItem(content: .init(title: "Beta Museum"))).generated.first)
    let cafe = try #require(
      try await save(.createItem(content: .init(title: "Alpha Cafe"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    func addMembership(_ source: PlannerEntityReference) async throws -> UUID {
      guard
        case .membership(let identifier, _, _)? = try await save(
          .addMembership(itemId: source.id, listId: list.id, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      return identifier
    }
    let museumMembershipId = try await addMembership(museum)
    let cafeMembershipId = try await addMembership(cafe)
    func addEntry(_ source: PlannerEntityReference) async throws -> UUID {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      return identifier
    }
    let firstHotelEntryId = try await addEntry(hotel)
    let firstListEntryId = try await addEntry(list)
    let secondHotelEntryId = try await addEntry(hotel)
    let secondListEntryId = try await addEntry(list)
    let firstHotel = PlannerRowIdentity.appearance(
      source: hotel,
      appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: firstHotelEntryId))
    let secondHotel = PlannerRowIdentity.appearance(
      source: hotel,
      appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: secondHotelEntryId))
    let firstMuseumAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: firstListEntryId, membershipId: museumMembershipId)
    let firstMuseum = PlannerRowIdentity.appearance(
      source: museum, appearance: firstMuseumAppearance)
    let firstCafe = PlannerRowIdentity.appearance(
      source: cafe,
      appearance: .expandedListItem(
        itineraryId: itinerary.id, listEntryId: firstListEntryId, membershipId: cafeMembershipId))
    let secondMuseum = PlannerRowIdentity.appearance(
      source: museum,
      appearance: .expandedListItem(
        itineraryId: itinerary.id, listEntryId: secondListEntryId, membershipId: museumMembershipId)
    )
    let secondCafe = PlannerRowIdentity.appearance(
      source: cafe,
      appearance: .expandedListItem(
        itineraryId: itinerary.id, listEntryId: secondListEntryId, membershipId: cafeMembershipId))
    _ = try await save(.setCompletion(scope: .appearance(firstMuseumAppearance), done: true))
    _ = try await save(.setArchive(source: cafe, archived: true))
    func query(
      completion: PlannerItemQuery.Completion = .all, archive: PlannerItemQuery.Archive = .all,
      text: String = "", sort: PlannerItemQuery.Sort = .init(mode: .manual)
    ) async throws -> PlannerQuerySnapshot {
      let result = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .itinerary(itinerary.id), text: text, completion: completion, archive: archive,
              sort: sort))))
      guard case .snapshot(let snapshot) = result else {
        Issue.record(
          "The approved ascending Manual itinerary query must return a snapshot: \(result)")
        throw CancellationError()
      }
      return snapshot
    }
    let manual = try await query()
    #expect(
      manual.rows == [firstHotel, firstMuseum, firstCafe, secondHotel, secondMuseum, secondCafe])
    #expect(manual.matchingCount == 6)
    let alphabetical = try await query(sort: .init())
    #expect(
      alphabetical.rows == [
        firstCafe, secondCafe, firstMuseum, secondMuseum, firstHotel, secondHotel,
      ])
    let filtered = try await query(completion: .todo, archive: .active)
    #expect(filtered.rows == [firstHotel, secondHotel, secondMuseum])
    let narrowed = try await query(completion: .todo, archive: .active, text: "MUSEUM")
    #expect(narrowed.rows == [secondMuseum])
    for snapshot in [manual, alphabetical, filtered, narrowed] {
      #expect(snapshot.progress.first?.doneCount == 1 && snapshot.progress.first?.totalCount == 6)
      #expect(snapshot.progress.first?.state == .partial)
    }
    guard
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: manual.generation, offset: 1, limit: 2))
    else { throw CancellationError() }
    #expect(window.rows.map(\.identity) == [firstMuseum, firstCafe])
    #expect(window.rows.map(\.effectiveDone) == [true, false])
    #expect(window.rows.map(\.archived) == [false, true])
    #expect(window.matchingCount == 6)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: true))
    let globallyDone = try await query(completion: .todo, archive: .active)
    #expect(globallyDone.rows == [secondMuseum] && globallyDone.progress.first?.doneCount == 3)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: false))
    let globallyReopened = try await query(completion: .todo, archive: .active)
    #expect(
      globallyReopened.rows == filtered.rows && globallyReopened.progress.first?.doneCount == 1)
    _ = try await save(
      .reorderMembership(
        listId: list.id, membershipId: cafeMembershipId,
        placement: .before(associationId: museumMembershipId)))
    _ = try await save(
      .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: secondListEntryId,
        placement: .before(associationId: firstHotelEntryId)))
    let reordered = try await query()
    #expect(
      reordered.rows == [secondCafe, secondMuseum, firstHotel, firstCafe, firstMuseum, secondHotel])
    #expect(reordered.progress.first?.doneCount == 1 && reordered.progress.first?.totalCount == 6)
    guard
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: manual.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let retained) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(
            .init(
              scope: .itinerary(itinerary.id), completion: .all, archive: .all,
              sort: .init(mode: .manual)))))
    else { throw CancellationError() }
    #expect(retained.rows == reordered.rows)
    #expect(retained.progress.first?.doneCount == 1 && retained.progress.first?.totalCount == 6)
  }
}
