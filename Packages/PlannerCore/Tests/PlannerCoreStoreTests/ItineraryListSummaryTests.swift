import Foundation
import PlannerCore
import Testing

struct ItineraryListSummaryTests {
  @Test func repeatedListSummariesUseItineraryFlagsAndStayLiveAcrossFiltersArchiveAndReopen()
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
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let museum = try #require(
      try await save(
        .createItem(
          content: .init(title: "Museum", estimate: .init(minutes: 120, displayUnit: .hour)))
      ).generated.first)
    let lunch = try #require(
      try await save(
        .createItem(
          content: .init(title: "Lunch", estimate: .init(minutes: 60, displayUnit: .hour)))
      ).generated.first)
    let manual = PlannerEstimate(minutes: 240, displayUnit: .hour)
    let list = try #require(
      try await save(.createList(content: .init(name: "Morning", manualEstimate: manual))).generated
        .first)
    var membershipIdentifiers: [UUID] = []
    for item in [museum, lunch] {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
            .generatedReferences.first)
      else { throw CancellationError() }
      membershipIdentifiers.append(identifier)
    }
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Day"))).generated.first)
    var entryIdentifiers: [UUID] = []
    for _ in 0..<2 {
      guard
        case .itineraryEntry(let identifier, _, _) = try #require(
          try await save(
            .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
          ).generatedReferences.first)
      else { throw CancellationError() }
      entryIdentifiers.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .listMembership(listId: list.id, membershipId: membershipIdentifiers[0])), done: true))
    let firstMuseum = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entryIdentifiers[0],
      membershipId: membershipIdentifiers[0])
    _ = try await save(.setCompletion(scope: .appearance(firstMuseum), done: true))
    guard
      case .source(.itinerary(let partial)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(partial.listEntrySummaries.map(\.entryId) == entryIdentifiers)
    #expect(partial.listEntrySummaries.map(\.source) == [list, list])
    #expect(partial.listEntrySummaries.map(\.manualEstimate) == [manual, manual])
    #expect(partial.listEntrySummaries.map { $0.progress.doneCount } == [1, 0])
    #expect(
      partial.listEntrySummaries.map { $0.estimates.fullEstimate } == [
        .exact(minutes: 240), .exact(minutes: 240),
      ])
    #expect(
      partial.listEntrySummaries.map { $0.estimates.remainingEstimate } == [
        .exact(minutes: 120), .exact(minutes: 240),
      ])
    guard
      case .snapshot = await planner.query(
        .init(
          session: session, request: .items(.init(scope: .itinerary(itinerary.id), text: "Lunch")))),
      case .source(.itinerary(let filtered)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(
      filtered.listEntrySummaries.map { $0.estimates }
        == partial.listEntrySummaries.map { $0.estimates })
    _ = try await save(.setArchive(source: list, archived: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let retired)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .appearance(let retained) = await reopened.read(
        session: reopenedSession, request: .appearance(firstMuseum))
    else { throw CancellationError() }
    #expect(retired.listEntrySummaries.map { $0.progress.doneCount } == [1, 0])
    #expect(retired.listEntrySummaries.map { $0.progress.archivedCount } == [1, 2])
    #expect(retired.listEntrySummaries.map { $0.progress.state } == [.complete, .complete])
    #expect(
      retired.listEntrySummaries.map { $0.estimates.remainingEstimate } == [
        .exact(minutes: 0), .exact(minutes: 0),
      ])
    #expect(retained.localDone == true && retained.globalDone == false)
    #expect(retired.fieldHashes == partial.fieldHashes)
    #expect(retired.updatedAt == partial.updatedAt)
    _ = try await save(.setArchive(source: list, archived: false))
    guard
      case .source(.itinerary(let unarchived)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(
      unarchived.listEntrySummaries.map { $0.estimates.remainingEstimate } == [
        .exact(minutes: 120), .exact(minutes: 240),
      ])
  }
}
