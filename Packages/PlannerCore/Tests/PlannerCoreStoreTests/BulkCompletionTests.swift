import Foundation
import PlannerCore
import Testing

struct BulkCompletionTests {
  @Test func reviewedBulkChangesEveryScopedAppearanceAndRetainsGlobalAndOtherContextStates()
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
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep notes"))).generated
        .first)
    let museum = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    var memberships: [UUID] = []
    for item in [hotel, museum] {
      guard
        case .membership(let identifier, _, _)? = try await save(
          .addMembership(itemId: item.id, listId: list.id, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      memberships.append(identifier)
    }
    var entries: [UUID] = []
    for source in [hotel, hotel, list, list] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    _ = try await save(.setArchive(source: museum, archived: true))
    guard
      case .source(.item(let beforeHotel)) = await planner.read(
        session: session, request: .source(hotel))
    else { throw CancellationError() }
    func review(_ scope: PlannerBulkScope, done: Bool) async throws -> PlannerReview {
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .setBulkCompletion(scope: scope, done: done))
      else {
        Issue.record(
          "Core must issue an exact review of all contextual children, including archived ones.")
        throw CancellationError()
      }
      return review
    }
    func apply(_ review: PlannerReview, operationId: UUID = UUID()) async throws
      -> PlannerAppliedResult
    {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(
            operationId: operationId, session: session, command: review.command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    func progress(_ scope: PlannerItemQuery.Scope, done: Int64, total: Int64) async throws {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(session: session, request: .items(.init(scope: scope))))
      else { throw CancellationError() }
      #expect(snapshot.progress.first?.doneCount == done)
      #expect(snapshot.progress.first?.totalCount == total)
    }
    let listReview = try await review(.list(listId: list.id), done: true)
    #expect(listReview.targetCount == 2 && !listReview.globalFlagsChanged)
    #expect(
      listReview.targets == memberships.map { .listMembership(listId: list.id, membershipId: $0) })
    _ = try await apply(listReview)
    try await progress(.list(list.id), done: 2, total: 2)
    try await progress(.itinerary(itinerary.id), done: 0, total: 6)
    let entryReview = try await review(
      .itineraryListEntry(itineraryId: itinerary.id, listEntryId: entries[2]), done: true)
    #expect(entryReview.targetCount == 2)
    #expect(
      entryReview.targets
        == memberships.map {
          .expandedListItem(itineraryId: itinerary.id, listEntryId: entries[2], membershipId: $0)
        })
    _ = try await apply(entryReview)
    try await progress(.itinerary(itinerary.id), done: 2, total: 6)
    let allReview = try await review(.itinerary(itineraryId: itinerary.id), done: true)
    #expect(allReview.targetCount == 6 && allReview.targets.count == 6)
    let originalOperationId = UUID()
    let originalResult = try await apply(allReview, operationId: originalOperationId)
    try await progress(.itinerary(itinerary.id), done: 6, total: 6)
    guard
      case .source(.itinerary(let beforeNoop)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    _ = try await apply(try await review(.itinerary(itineraryId: itinerary.id), done: true))
    guard
      case .source(.itinerary(let afterNoop)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(afterNoop.updatedAt == beforeNoop.updatedAt)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: true))
    _ = try await apply(try await review(.itinerary(itineraryId: itinerary.id), done: false))
    try await progress(.itinerary(itinerary.id), done: 4, total: 6)
    try await progress(.list(list.id), done: 2, total: 2)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: false))
    try await progress(.itinerary(itinerary.id), done: 0, total: 6)
    guard
      case .source(.item(let retainedHotel)) = await planner.read(
        session: session, request: .source(hotel)),
      case .source(.item(let retainedMuseum)) = await planner.read(
        session: session, request: .source(museum))
    else { throw CancellationError() }
    #expect(retainedHotel.content.title == beforeHotel.content.title)
    #expect(retainedHotel.content.notes == beforeHotel.content.notes)
    #expect(retainedHotel.fieldHashes == beforeHotel.fieldHashes)
    #expect(retainedHotel.state.globalDone == false && retainedMuseum.state.globalDone == false)
    #expect(retainedMuseum.state.archived == true)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replay, .complete) = await reopened.execute(
        .init(
          operationId: originalOperationId, session: reopenedSession, command: allReview.command)
      ).outcome,
      case .snapshot(let retained) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(scope: .itinerary(itinerary.id)))))
    else { throw CancellationError() }
    #expect(replay == originalResult)
    #expect(retained.progress.first?.doneCount == 0 && retained.progress.first?.totalCount == 6)
  }
}
