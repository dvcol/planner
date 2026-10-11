import Foundation
import PlannerCore
import Testing

struct ItineraryItemQueryTests {
  @Test func itineraryQueriesRetainIndependentAppearancesFullProgressAndLiveMemberships()
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
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let presentation = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_924_000),
      displayTimeZone: "Asia/Tokyo")
    guard
      case .snapshot(let empty) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .itinerary(itinerary.id), completion: .all, archive: .all,
              rowPresentation: presentation))))
    else {
      Issue.record("A saved empty Itinerary must issue a contextual Item query with No items.")
      return
    }
    #expect(empty.rows.isEmpty && empty.matchingCount == 0)
    #expect(empty.progress.first?.state == .empty && empty.progress.first?.totalCount == 0)
    #expect(empty.progress.first?.doneCount == 0 && empty.rowPresentation == presentation)
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep notes"))).generated
        .first)
    let museum = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: hotel.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    func addEntry(_ source: PlannerEntityReference) async throws -> UUID {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      return identifier
    }
    let firstHotel = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: try await addEntry(hotel))
    let museumAppearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: try await addEntry(museum))
    let secondHotel = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: try await addEntry(hotel))
    let firstListEntryId = try await addEntry(list)
    let secondListEntryId = try await addEntry(list)
    let firstExpanded = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: firstListEntryId, membershipId: membershipId)
    let secondExpanded = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: secondListEntryId, membershipId: membershipId)
    for appearance in [
      firstHotel, firstExpanded,
      .listMembership(listId: list.id, membershipId: membershipId),
    ] {
      _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    }
    _ = try await save(.setArchive(source: museum, archived: true))
    func query(_ completion: PlannerItemQuery.Completion, _ archive: PlannerItemQuery.Archive)
      async throws -> PlannerQuerySnapshot
    {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .items(
              .init(
                scope: .itinerary(itinerary.id), completion: completion, archive: archive,
                rowPresentation: presentation))))
      else { throw CancellationError() }
      return snapshot
    }
    let all = try await query(.all, .all)
    let todo = try await query(.todo, .active)
    let done = try await query(.done, .all)
    let archived = try await query(.all, .archived)
    let hotelRows = [firstHotel, secondHotel, firstExpanded, secondExpanded].map {
      PlannerRowIdentity.appearance(source: hotel, appearance: $0)
    }
    #expect(all.rows == hotelRows + [.appearance(source: museum, appearance: museumAppearance)])
    #expect(todo.rows == [hotelRows[1], hotelRows[3]])
    #expect(done.rows == [hotelRows[0], hotelRows[2]])
    #expect(archived.rows == [.appearance(source: museum, appearance: museumAppearance)])
    for snapshot in [all, todo, done, archived] {
      #expect(snapshot.progress.count == 1 && snapshot.progress.first?.container == itinerary)
      #expect(snapshot.progress.first?.totalCount == 5 && snapshot.progress.first?.doneCount == 2)
      #expect(snapshot.progress.first?.state == .partial && snapshot.unresolvedReferences.isEmpty)
      #expect(snapshot.rowPresentation == presentation)
    }
    guard
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: all.generation, offset: 1, limit: 3))
    else { throw CancellationError() }
    #expect(window.rows.map(\.identity) == Array(hotelRows[1...3]))
    #expect(window.rows.map(\.effectiveDone) == [false, true, false])
    #expect(window.rows.allSatisfy { $0.globalDone == false && $0.archived == false })
    #expect(window.matchingCount == 5 && window.rowPresentation == presentation)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: true))
    let globallyDone = try await query(.todo, .active)
    #expect(globallyDone.rows.isEmpty)
    #expect(
      globallyDone.progress.first?.doneCount == 4 && globallyDone.progress.first?.totalCount == 5)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: false))
    let reopenedFlags = try await query(.done, .all)
    #expect(reopenedFlags.rows == done.rows)
    guard
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: all.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    _ = try await save(.setArchive(source: itinerary, archived: true))
    let archivedContainer = try await query(.all, .all)
    #expect(archivedContainer.rows == all.rows)
    #expect(archivedContainer.progress.first?.doneCount == 2)
    _ = try await save(.removeMembership(listId: list.id, membershipId: membershipId))
    let removed = try await query(.all, .all)
    #expect(
      removed.rows == [
        hotelRows[0], hotelRows[1], .appearance(source: museum, appearance: museumAppearance),
      ])
    #expect(removed.progress.first?.totalCount == 3 && removed.progress.first?.doneCount == 1)
    guard
      case .membership(let freshMembershipId, _, _)? = try await save(
        .addMembership(itemId: hotel.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    #expect(freshMembershipId != membershipId)
    let fresh = try await query(.done, .all)
    #expect(fresh.rows == [hotelRows[0]])
    #expect(fresh.progress.first?.totalCount == 5 && fresh.progress.first?.doneCount == 1)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let retained) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(.init(scope: .itinerary(itinerary.id), completion: .all, archive: .all))))
    else { throw CancellationError() }
    #expect(retained.matchingCount == 5)
    #expect(retained.progress.first?.doneCount == 1 && retained.progress.first?.totalCount == 5)
  }
}
