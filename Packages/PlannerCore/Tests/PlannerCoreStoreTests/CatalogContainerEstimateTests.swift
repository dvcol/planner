import Foundation
import PlannerCore
import Testing

struct CatalogContainerEstimateTests {
  @Test func itineraryCatalogBudgetsUseRepeatedContextualBranchesWithoutChangingSchedules()
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
    var items: [PlannerEntityReference] = []
    for (title, minutes) in [("Museum", Int64(120)), ("Lunch", 60), ("Hotel", 30)] {
      items.append(
        try #require(
          try await save(
            .createItem(
              content: .init(
                title: title, estimate: .init(minutes: minutes, displayUnit: .hour)))
          ).generated.first))
    }
    let list = try #require(
      try await save(
        .createList(
          content: .init(
            name: "Morning", manualEstimate: .init(minutes: 240, displayUnit: .hour)))
      ).generated.first)
    var memberships: [UUID] = []
    for item in items.prefix(2) {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(
            .addMembership(itemId: item.id, listId: list.id, placement: .last)
          ).generatedReferences.first)
      else { throw CancellationError() }
      memberships.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: list.id, membershipId: memberships[0])), done: true))
    let manual = PlannerEstimate(minutes: 600, displayUnit: .hour)
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Route", notes: "Keep route", manualEstimate: manual))
      ).generated.first)
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: items[2], placement: .last))
    var entries: [UUID] = []
    for _ in 0..<2 {
      guard
        case .itineraryEntry(let identifier, _, _) = try #require(
          try await save(
            .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
          )
          .generatedReferences.first)
      else { throw CancellationError() }
      entries.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entries[0], membershipId: memberships[0])),
        done: true))
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let schedule = try #require(
      try await save(
        .createSchedule(
          source: itinerary,
          form: .timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo"))
      ).generated.first)
    guard
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    func catalogRow() async throws -> PlannerRowRead {
      guard
        case .source(.itinerary(let before)) = await planner.read(
          session: session, request: .source(itinerary)),
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .catalog(.init(sourceKind: .itinerary, text: "Route", archive: .all)))),
        case .rows(let window) = await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
      else { throw CancellationError() }
      guard
        case .source(.itinerary(let after)) = await planner.read(
          session: session, request: .source(itinerary))
      else { throw CancellationError() }
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
      return try #require(window.rows.first)
    }
    let partial = try await catalogRow()
    #expect(partial.identity == .source(itinerary) && partial.manualEstimate == manual)
    #expect(partial.estimate == nil)
    #expect(partial.containerEstimates?.fullEstimate == .exact(minutes: 600))
    #expect(partial.containerEstimates?.calculatedEstimate == .exact(minutes: 510))
    #expect(partial.containerEstimates?.remainingEstimate == .exact(minutes: 480))
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entries[0], membershipId: memberships[1])),
        done: true))
    let finishedBranch = try await catalogRow()
    #expect(finishedBranch.containerEstimates?.remainingEstimate == .exact(minutes: 360))
    _ = try await save(.setArchive(source: list, archived: true))
    let retiredBranches = try await catalogRow()
    #expect(retiredBranches.containerEstimates?.remainingEstimate == .exact(minutes: 120))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: items[2].id), done: true))
    let finished = try await catalogRow()
    #expect(finished.containerEstimates?.remainingEstimate == .exact(minutes: 0))
    #expect(finished.containerEstimates?.fullEstimate == .exact(minutes: 600))
    guard
      case .source(.itinerary(let unchanged)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.schedule(let retainedSchedule)) = await planner.read(
        session: session, request: .source(schedule))
    else { throw CancellationError() }
    #expect(unchanged.content.notes == "Keep route")
    #expect(unchanged.fieldHashes == original.fieldHashes)
    let retainedRoute = unchanged.references.filter {
      guard case .itineraryEntry = $0 else { return false }
      return true
    }
    let originalRoute = original.references.filter {
      guard case .itineraryEntry = $0 else { return false }
      return true
    }
    #expect(retainedRoute == originalRoute)
    #expect(
      retainedSchedule.content.form
        == .timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo"))
  }

  @Test func listCatalogEstimatesKeepTheFullBudgetAcrossWindowsArchiveAndReopen() async throws {
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
          content: .init(
            title: "Museum", estimate: .init(minutes: 120, displayUnit: .hour)))
      ).generated.first)
    let lunch = try #require(
      try await save(.createItem(content: .init(title: "Lunch"))).generated.first)
    let manual = PlannerEstimate(minutes: 240, displayUnit: .hour)
    let list = try #require(
      try await save(
        .createList(
          content: .init(
            name: "Morning", notes: "Keep notes", manualEstimate: manual))
      ).generated.first)
    var museumMembership: UUID?
    for item in [museum, lunch] {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(
            .addMembership(itemId: item.id, listId: list.id, placement: .last)
          ).generatedReferences.first)
      else { throw CancellationError() }
      if item == museum { museumMembership = identifier }
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: list.id, membershipId: try #require(museumMembership))), done: true))
    guard
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list)),
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .catalog(.init(sourceKind: .list, text: "Morning", archive: .all)))),
      case .rows(let window) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
      case .rows(let empty) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 1, limit: 1))
    else { throw CancellationError() }
    let row = try #require(window.rows.first)
    let estimates = try #require(row.containerEstimates)
    #expect(window.matchingCount == 1 && window.rows.count == 1)
    #expect(row.identity == .source(list))
    #expect(row.manualEstimate == manual)
    #expect(row.estimate == nil)
    #expect(estimates.fullEstimate == .exact(minutes: 240))
    #expect(estimates.calculatedEstimate == .lowerBound(minutes: 120, missingEstimateCount: 1))
    #expect(estimates.remainingEstimate == .exact(minutes: 120))
    #expect(estimates == original.estimates)
    #expect(empty.rows.isEmpty && empty.matchingCount == 1)
    _ = try await save(.setArchive(source: lunch, archived: true))
    guard
      case .failed(let stale) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let refreshed) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .catalog(.init(sourceKind: .list, archive: .all)))),
      case .rows(let retained) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: refreshed.generation, offset: 0, limit: 1)),
      case .source(.list(let unchanged)) = await reopened.read(
        session: reopenedSession,
        request: .source(list)),
      case .snapshot(let items) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(.init(archive: .all)))),
      case .rows(let itemRows) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: items.generation, offset: 0, limit: 10))
    else { throw CancellationError() }
    let retainedRow = try #require(retained.rows.first)
    #expect(retainedRow.identity == .source(list) && retainedRow.manualEstimate == manual)
    #expect(retainedRow.containerEstimates?.fullEstimate == .exact(minutes: 240))
    #expect(retainedRow.containerEstimates?.remainingEstimate == .exact(minutes: 0))
    #expect(unchanged.content.notes == "Keep notes")
    #expect(
      unchanged.fieldHashes == original.fieldHashes && unchanged.updatedAt == original.updatedAt)
    #expect(itemRows.rows.allSatisfy { $0.containerEstimates == nil && $0.manualEstimate == nil })
    #expect(itemRows.rows.first { $0.identity == .source(museum) }?.estimate?.minutes == 120)
  }
}
