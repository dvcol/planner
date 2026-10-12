import Foundation
import PlannerCore
import Testing

struct ManualContainerBudgetTests {
  enum FinishMethod: CaseIterable { case local, global, archive }

  @Test func emptyListBudgetDoesNotBlockFinishedItineraryAndOverflowNeverWraps() async throws {
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
      try await save(
        .createList(
          content: .init(name: "Travel", manualEstimate: .init(minutes: 60, displayUnit: .hour)))
      ).generated.first)
    guard
      case .source(.list(let empty)) = await planner.read(session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(empty.progress.state == .empty)
    #expect(empty.estimates.remainingEstimate == .exact(minutes: 60))
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(title: "Day", manualEstimate: .init(minutes: 120, displayUnit: .hour)))
      ).generated.first)
    let hotel = try #require(
      try await save(
        .createItem(
          content: .init(title: "Hotel", estimate: .init(minutes: 30, displayUnit: .minute)))
      ).generated.first)
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    guard
      case .itineraryEntry(let entry, _, _) = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: hotel, placement: .last)
        ).generatedReferences.first)
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: entry)),
        done: true))
    guard
      case .source(.itinerary(let finished)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(finished.estimates.calculatedEstimate == .exact(minutes: 90))
    #expect(finished.estimates.fullEstimate == .exact(minutes: 120))
    #expect(finished.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(finished.progress.state == .complete)
    _ = try await save(
      .editList(
        sourceId: list.id,
        changes: .init(manualEstimate: .set(.init(minutes: .max, displayUnit: .year))),
        expectedFieldHashes: empty.fieldHashes))
    var appearances: [PlannerAppearance] = []
    for name in ["First", "Second"] {
      let item = try #require(
        try await save(
          .createItem(
            content: .init(title: name, estimate: .init(minutes: .max, displayUnit: .year)))
        ).generated.first)
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
            .generatedReferences.first)
      else { throw CancellationError() }
      appearances.append(.listMembership(listId: list.id, membershipId: identifier))
    }
    guard
      case .source(.list(let overflow)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(overflow.estimates.calculatedEstimate == .unavailable)
    #expect(overflow.estimates.fullEstimate == .exact(minutes: .max))
    #expect(overflow.estimates.remainingEstimate == .exact(minutes: .max))
    for appearance in appearances {
      _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    }
    guard
      case .source(.list(let allFinished)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(allFinished.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(allFinished.estimates.completedExceedsTotal == true)
    #expect(allFinished.content.manualEstimate?.minutes == .max)
  }

  @Test func itineraryUsesEachLiveListBudgetOnceWithIndependentFinishedContributions() async throws
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
    func itineraryRead(_ source: PlannerEntityReference) async throws -> PlannerItinerarySourceRead
    {
      guard
        case .source(.itinerary(let read)) = await planner.read(
          session: session, request: .source(source))
      else { throw CancellationError() }
      return read
    }
    var items: [PlannerEntityReference] = []
    for (name, minutes) in [("Museum", Int64(120)), ("Lunch", Int64(60)), ("Hotel", Int64(30))] {
      items.append(
        try #require(
          try await save(
            .createItem(
              content: .init(title: name, estimate: .init(minutes: minutes, displayUnit: .minute)))
          ).generated.first))
    }
    let list = try #require(
      try await save(
        .createList(
          content: .init(name: "Morning", manualEstimate: .init(minutes: 240, displayUnit: .hour)))
      ).generated.first)
    var membershipIdentifiers: [UUID] = []
    for item in items.prefix(2) {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
            .generatedReferences.first)
      else { throw CancellationError() }
      membershipIdentifiers.append(identifier)
    }
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Day"))).generated.first)
    guard
      case .itineraryEntry(let listEntry, _, _) = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
        ).generatedReferences.first),
      case .itineraryEntry(let hotelEntry, _, _) = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: items[2], placement: .last)
        ).generatedReferences.first)
    else { throw CancellationError() }
    let museumAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: listEntry, membershipId: membershipIdentifiers[0])
    let lunchAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: listEntry, membershipId: membershipIdentifiers[1])
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .listMembership(listId: list.id, membershipId: membershipIdentifiers[0])), done: true))
    let original = try await itineraryRead(itinerary)
    #expect(original.estimates.calculatedEstimate == .exact(minutes: 270))
    #expect(original.estimates.remainingEstimate == .exact(minutes: 270))
    _ = try await save(.setCompletion(scope: .appearance(museumAppearance), done: true))
    let partial = try await itineraryRead(itinerary)
    #expect(partial.estimates.remainingEstimate == .exact(minutes: 150))
    _ = try await save(.setCompletion(scope: .appearance(lunchAppearance), done: true))
    let branchFinished = try await itineraryRead(itinerary)
    #expect(branchFinished.estimates.remainingEstimate == .exact(minutes: 30))
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id,
        changes: .init(manualEstimate: .set(.init(minutes: 300, displayUnit: .hour))),
        expectedFieldHashes: branchFinished.fieldHashes))
    let manual = try await itineraryRead(itinerary)
    #expect(manual.estimates.calculatedEstimate == .exact(minutes: 270))
    #expect(manual.estimates.fullEstimate == .exact(minutes: 300))
    #expect(manual.estimates.remainingEstimate == .exact(minutes: 60))
    _ = try await save(
      .setCompletion(
        scope: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: hotelEntry)),
        done: true))
    let finished = try await itineraryRead(itinerary)
    #expect(finished.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(finished.content.manualEstimate?.minutes == 300)
    _ = try await save(
      .setCompletion(
        scope: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: hotelEntry)),
        done: false))
    _ = try await save(.setCompletion(scope: .appearance(museumAppearance), done: false))
    guard
      case .source(.item(let lunch)) = await planner.read(
        session: session, request: .source(items[1]))
    else { throw CancellationError() }
    _ = try await save(
      .editItem(
        sourceId: items[1].id, changes: .init(estimate: .clear),
        expectedFieldHashes: lunch.fieldHashes))
    let uncertain = try await itineraryRead(itinerary)
    #expect(
      uncertain.estimates.remainingEstimate
        == .upperBound(minutes: 300, missingFinishedEstimateCount: 1))
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id, changes: .init(manualEstimate: .clear),
        expectedFieldHashes: uncertain.fieldHashes))
    let automatic = try await itineraryRead(itinerary)
    #expect(automatic.estimates.fullEstimate == .exact(minutes: 270))
    #expect(
      automatic.estimates.remainingEstimate
        == .upperBound(minutes: 270, missingFinishedEstimateCount: 1))
    _ = try await save(.setArchive(source: list, archived: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let retired)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .appearance(let museumState) = await reopened.read(
        session: reopenedSession, request: .appearance(museumAppearance))
    else { throw CancellationError() }
    #expect(retired.estimates.fullEstimate == .exact(minutes: 270))
    #expect(retired.estimates.remainingEstimate == .exact(minutes: 30))
    #expect(retired.progress.state == .partial)
    #expect(retired.references == automatic.references)
    #expect(museumState.localDone == false)
    #expect(museumState.globalDone == false)
    guard
      case .itineraryEntry(let secondListEntry, _, _) = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
        )
        .generatedReferences.first)
    else { throw CancellationError() }
    _ = try await save(.setArchive(source: list, archived: false))
    let repeated = try await itineraryRead(itinerary)
    #expect(repeated.estimates.fullEstimate == .exact(minutes: 510))
    #expect(
      repeated.estimates.remainingEstimate
        == .upperBound(minutes: 510, missingFinishedEstimateCount: 1))
    #expect(repeated.progress.totalCount == 5)
    guard
      case .appearance(let secondLunch) = await planner.read(
        session: session,
        request: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: secondListEntry,
            membershipId: membershipIdentifiers[1]))),
      case .source(.item(let hotel)) = await planner.read(
        session: session, request: .source(items[2]))
    else { throw CancellationError() }
    #expect(secondLunch.localDone == false)
    _ = try await save(
      .editItem(
        sourceId: items[2].id, changes: .init(estimate: .clear),
        expectedFieldHashes: hotel.fieldHashes))
    let mixedBounds = try await itineraryRead(itinerary)
    #expect(
      mixedBounds.estimates.fullEstimate == .lowerBound(minutes: 480, missingEstimateCount: 1))
    #expect(mixedBounds.estimates.remainingEstimate == .unavailable)
  }

  @Test(arguments: FinishMethod.allCases)
  func missingFinishedEstimateUsesUpperBoundUntilResolvedAndAllFinishedMeansZero(
    method: FinishMethod
  )
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
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let applied, .complete) = response.outcome else {
        Issue.record("The budget fixture must save with independent recovery: \(response)")
        throw CancellationError()
      }
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
      try await save(.createList(content: .init(name: "Morning", manualEstimate: manual))).generated
        .first)
    var appearances: [PlannerAppearance] = []
    for item in [museum, lunch] {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(
            .addMembership(itemId: item.id, listId: list.id, placement: .last)
          ).generatedReferences.first)
      else { throw CancellationError() }
      appearances.append(.listMembership(listId: list.id, membershipId: identifier))
    }
    switch method {
    case .local: _ = try await save(.setCompletion(scope: .appearance(appearances[1]), done: true))
    case .global:
      _ = try await save(.setCompletion(scope: .globalItem(itemId: lunch.id), done: true))
    case .archive: _ = try await save(.setArchive(source: lunch, archived: true))
    }
    guard
      case .source(.list(let partial)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let lunchBefore)) = await planner.read(
        session: session, request: .source(lunch))
    else { throw CancellationError() }
    #expect(
      partial.estimates.calculatedEstimate == .lowerBound(minutes: 120, missingEstimateCount: 1))
    #expect(partial.estimates.fullEstimate == .exact(minutes: 240))
    #expect(
      partial.estimates.remainingEstimate
        == .upperBound(minutes: 240, missingFinishedEstimateCount: 1))
    #expect(partial.progress.finishedCount == 1)
    #expect(lunchBefore.content.estimate == nil)
    _ = try await save(
      .editItem(
        sourceId: lunch.id,
        changes: .init(estimate: .set(.init(minutes: 60, displayUnit: .hour))),
        expectedFieldHashes: lunchBefore.fieldHashes))
    guard
      case .source(.list(let resolved)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(resolved.estimates.calculatedEstimate == .exact(minutes: 180))
    #expect(resolved.estimates.remainingEstimate == .exact(minutes: 180))
    #expect(resolved.content.manualEstimate == manual)
    #expect(resolved.fieldHashes == partial.fieldHashes)
    #expect(resolved.updatedAt == partial.updatedAt)
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let finished)) = await reopened.read(
        session: reopenedSession, request: .source(list))
    else { throw CancellationError() }
    #expect(finished.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(finished.estimates.fullEstimate == .exact(minutes: 240))
    #expect(finished.content.manualEstimate == manual)
    #expect(finished.progress.state == .complete)
    #expect(finished.references == partial.references)
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: false))
    guard
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editList(
            sourceId: list.id,
            changes: .init(manualEstimate: .set(.init(minutes: 30, displayUnit: .minute))),
            expectedFieldHashes: finished.fieldHashes))
      ).outcome,
      case .source(.list(let exceeded)) = await reopened.read(
        session: reopenedSession, request: .source(list))
    else { throw CancellationError() }
    #expect(exceeded.estimates.remainingEstimate == .exact(minutes: 0))
    #expect(exceeded.estimates.completedExceedsTotal == true)
    #expect(exceeded.progress.state == .partial)
    guard
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editList(
            sourceId: list.id, changes: .init(manualEstimate: .clear),
            expectedFieldHashes: exceeded.fieldHashes))
      ).outcome,
      case .source(.list(let calculated)) = await reopened.read(
        session: reopenedSession, request: .source(list))
    else { throw CancellationError() }
    #expect(calculated.estimates.fullEstimate == .exact(minutes: 180))
    #expect(calculated.estimates.remainingEstimate == .exact(minutes: 120))
    #expect(calculated.estimates.completedExceedsTotal == false)
  }
}
