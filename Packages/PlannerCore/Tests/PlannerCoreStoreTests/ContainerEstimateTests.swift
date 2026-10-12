import Foundation
import PlannerCore
import Testing

struct ContainerEstimateTests {
  @Test func automaticListTotalsRetainFullPlanAndFollowCompletionAndArchiveAfterReopen()
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
    let list = try #require(
      try await save(.createList(content: .init(name: "Morning"))).generated.first)
    var appearances: [PlannerAppearance] = []
    for item in [museum, lunch] {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
            .generatedReferences.first)
      else { throw CancellationError() }
      appearances.append(.listMembership(listId: list.id, membershipId: identifier))
    }
    guard
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(original.estimates.calculatedEstimate == .exact(minutes: 180))
    #expect(original.estimates.fullEstimate == .exact(minutes: 180))
    #expect(original.estimates.remainingEstimate == .exact(minutes: 180))
    #expect(original.estimates.completedExceedsTotal == false)
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: true))
    guard
      case .source(.list(let partial)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(partial.estimates.fullEstimate == .exact(minutes: 180))
    #expect(partial.estimates.remainingEstimate == .exact(minutes: 60))
    _ = try await save(.setArchive(source: lunch, archived: true))
    guard
      case .source(.list(let finished)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(finished.estimates.fullEstimate == .exact(minutes: 180))
    #expect(finished.estimates.remainingEstimate == .exact(minutes: 0))
    _ = try await save(.setArchive(source: lunch, archived: false))
    guard
      case .source(.list(let unarchived)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(unarchived.estimates.remainingEstimate == .exact(minutes: 60))
    _ = try await save(.setArchive(source: list, archived: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let retainedLunch) = await reopened.read(
        session: reopenedSession, request: .appearance(appearances[1]))
    else { throw CancellationError() }
    #expect(retained.estimates.fullEstimate == .exact(minutes: 180))
    #expect(retained.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(retained.progress.state == .partial)
    #expect(retained.references == original.references)
    #expect(retainedLunch.globalDone == false)
    #expect(retainedLunch.localDone == false)
    #expect(retainedLunch.archived == false)
  }

  @Test func missingFinishedEstimatesDoNotInventTimeInAutomaticRemaining() async throws {
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
    let museum = try #require(
      try await save(
        .createItem(
          content: .init(title: "Museum", estimate: .init(minutes: 120, displayUnit: .hour)))
      ).generated.first)
    let lunch = try #require(
      try await save(.createItem(content: .init(title: "Lunch"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Morning"))).generated.first)
    for item in [museum, lunch] {
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    guard
      case .source(.list(let partial)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(
      partial.estimates.fullEstimate == .lowerBound(minutes: 120, missingEstimateCount: 1))
    #expect(
      partial.estimates.remainingEstimate == .lowerBound(minutes: 120, missingEstimateCount: 1))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: lunch.id), done: true))
    guard
      case .source(.list(let knownRemaining)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let retainedLunch)) = await planner.read(
        session: session, request: .source(lunch))
    else { throw CancellationError() }
    #expect(knownRemaining.estimates.fullEstimate == partial.estimates.fullEstimate)
    #expect(knownRemaining.estimates.remainingEstimate == .exact(minutes: 120))
    #expect(retainedLunch.content.estimate == nil)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: museum.id), done: true))
    guard
      case .source(.list(let finished)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(finished.estimates.fullEstimate == partial.estimates.fullEstimate)
    #expect(finished.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(finished.progress.state == .complete)
  }

  @Test func emptyAndOverflowingAutomaticTotalsPreserveValidProgressAndSourceEstimates()
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
    let list = try #require(
      try await save(.createList(content: .init(name: "Capacity"))).generated.first)
    guard
      case .source(.list(let empty)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(empty.estimates.fullEstimate == .exact(minutes: 0))
    #expect(empty.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(empty.progress.state == .empty)
    let large = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Large", estimate: .init(minutes: Int64.max, displayUnit: .minute)))
      ).generated.first)
    let small = try #require(
      try await save(
        .createItem(
          content: .init(title: "Small", estimate: .init(minutes: 1, displayUnit: .minute)))
      ).generated.first)
    for item in [large, small] {
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    guard
      case .source(.list(let overflow)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let originalLarge)) = await planner.read(
        session: session, request: .source(large))
    else { throw CancellationError() }
    #expect(overflow.estimates.calculatedEstimate == .unavailable)
    #expect(overflow.estimates.fullEstimate == .unavailable)
    #expect(overflow.estimates.remainingEstimate == .unavailable)
    #expect(overflow.progress.state == .partial)
    #expect(originalLarge.content.estimate?.minutes == Int64.max)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: large.id), done: true))
    guard
      case .source(.list(let partial)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(partial.estimates.fullEstimate == .unavailable)
    #expect(partial.estimates.remainingEstimate == .exact(minutes: 1))
    #expect(partial.progress.state == .partial)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: small.id), done: true))
    guard
      case .source(.list(let finished)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(finished.estimates.fullEstimate == .unavailable)
    #expect(finished.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(finished.progress.state == .complete)
    #expect(finished.references == overflow.references)
  }

  @Test func itineraryAutomaticTotalsCountEachAppearanceAndKeepCompletionContextIndependent()
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
    let list = try #require(
      try await save(.createList(content: .init(name: "Morning"))).generated.first)
    var memberships: [UUID] = []
    for item in [museum, lunch] {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
            .generatedReferences.first)
      else { throw CancellationError() }
      memberships.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: memberships[0])),
        done: true))
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let scheduleForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    let schedule = try #require(
      try await save(.createSchedule(source: itinerary, form: scheduleForm)).generated.first)
    var entries: [UUID] = []
    for source in [museum, list, list] {
      guard
        case .itineraryEntry(let identifier, _, _) = try #require(
          try await save(
            .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
          )
          .generatedReferences.first)
      else { throw CancellationError() }
      entries.append(identifier)
    }
    guard
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(original.estimates.calculatedEstimate == .exact(minutes: 480))
    #expect(original.estimates.fullEstimate == .exact(minutes: 480))
    #expect(original.estimates.remainingEstimate == .exact(minutes: 480))
    let firstExpanded = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entries[1], membershipId: memberships[0])
    _ = try await save(.setCompletion(scope: .appearance(firstExpanded), done: true))
    guard
      case .source(.itinerary(let partial)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(partial.estimates.fullEstimate == .exact(minutes: 480))
    #expect(partial.estimates.remainingEstimate == .exact(minutes: 360))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: museum.id), done: true))
    guard
      case .source(.itinerary(let globallyDone)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(globallyDone.estimates.remainingEstimate == .exact(minutes: 120))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: museum.id), done: false))
    _ = try await save(.setArchive(source: list, archived: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let retired)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(retired.estimates.fullEstimate == .exact(minutes: 480))
    #expect(retired.estimates.remainingEstimate == .exact(minutes: 120))
    #expect(retired.references == partial.references)
    _ = try await save(.setArchive(source: list, archived: false))
    guard
      case .source(.itinerary(let restored)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(restored.estimates.remainingEstimate == .exact(minutes: 360))
    guard
      case .source(.item(let originalMuseum)) = await planner.read(
        session: session, request: .source(museum))
    else { throw CancellationError() }
    _ = try await save(
      .editItem(
        sourceId: museum.id,
        changes: .init(estimate: .set(.init(minutes: 150, displayUnit: .hour))),
        expectedFieldHashes: originalMuseum.fieldHashes))
    guard
      case .snapshot(let filtered) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .itinerary(itinerary.id), completion: .todo, archive: .all,
              duration: .init(minimumMinutes: 140), sort: .init(mode: .manual))))),
      case .source(.itinerary(let live)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(filtered.matchingCount == 2)
    #expect(live.estimates.fullEstimate == .exact(minutes: 570))
    #expect(live.estimates.remainingEstimate == .exact(minutes: 420))
    #expect(live.fieldHashes == restored.fieldHashes)
    #expect(live.updatedAt == restored.updatedAt)
    _ = try await save(.setArchive(source: itinerary, archived: true))
    guard
      case .source(.itinerary(let ownArchive)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(ownArchive.estimates.fullEstimate == .exact(minutes: 570))
    #expect(ownArchive.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(ownArchive.progress.state == .partial)
    guard
      case .source(.schedule(let retainedSchedule)) = await planner.read(
        session: session, request: .source(schedule))
    else { throw CancellationError() }
    #expect(retainedSchedule.content.form == scheduleForm)
  }
}
