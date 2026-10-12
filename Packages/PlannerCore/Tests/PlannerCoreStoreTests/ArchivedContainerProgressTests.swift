import Foundation
import PlannerCore
import Testing

struct ArchivedContainerProgressTests {
  @Test func archivedChildFinishesListWithoutChangingDoneFlagsAndUnarchiveRestoresProgress()
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
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let lunch = try #require(
      try await save(.createItem(content: .init(title: "Lunch"))).generated.first)
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
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: true))
    guard
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(original.progress.state == .partial)
    #expect(original.progress.doneCount == 1)
    _ = try await save(.setArchive(source: lunch, archived: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let finished)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let retainedLunch) = await reopened.read(
        session: reopenedSession, request: .appearance(appearances[1]))
    else { throw CancellationError() }
    #expect(finished.progress.state == .complete)
    #expect(finished.progress.doneCount == 1)
    #expect(finished.progress.archivedCount == 1)
    #expect(finished.progress.finishedCount == 2)
    #expect(finished.progress.totalCount == 2)
    #expect(finished.references == original.references)
    #expect(retainedLunch.globalDone == false)
    #expect(retainedLunch.localDone == false)
    #expect(retainedLunch.effectiveDone == false)
    #expect(retainedLunch.archived == true)
    for completion in [PlannerItemQuery.Completion.todo, .done] {
      guard
        case .snapshot(let snapshot) = await reopened.query(
          .init(
            session: reopenedSession,
            request: .items(
              .init(scope: .list(list.id), completion: completion, archive: .all))))
      else { throw CancellationError() }
      #expect(snapshot.matchingCount == 1)
      #expect(snapshot.progress.first?.state == .complete)
      #expect(snapshot.progress.first?.doneCount == 1)
      #expect(snapshot.progress.first?.archivedCount == 1)
      #expect(snapshot.progress.first?.finishedCount == 2)
    }
    _ = try await save(.setCompletion(scope: .globalItem(itemId: lunch.id), done: true))
    guard
      case .source(.list(let overlapping)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(overlapping.progress.doneCount == 2)
    #expect(overlapping.progress.archivedCount == 0)
    #expect(overlapping.progress.finishedCount == 2)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: lunch.id), done: false))
    guard
      case .source(.list(let globallyReopened)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(globallyReopened.progress.doneCount == 1)
    #expect(globallyReopened.progress.archivedCount == 1)
    #expect(globallyReopened.progress.finishedCount == 2)
    _ = try await save(.setArchive(source: lunch, archived: false))
    guard
      case .source(.list(let restored)) = await planner.read(
        session: session, request: .source(list)),
      case .appearance(let restoredLunch) = await planner.read(
        session: session, request: .appearance(appearances[1]))
    else { throw CancellationError() }
    #expect(restored.progress.state == .partial)
    #expect(restored.progress.doneCount == 1)
    #expect(restored.references == original.references)
    #expect(restoredLunch.localDone == false)
    #expect(restoredLunch.effectiveDone == false)
  }

  @Test func archivedRepeatedListBranchesFinishOnlyTheirItineraryAppearances() async throws {
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
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let lunch = try #require(
      try await save(.createItem(content: .init(title: "Lunch"))).generated.first)
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
    _ = try await save(.setArchive(source: list, archived: true))
    guard
      case .source(.list(let own)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let partial)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .snapshot(let query) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .itinerary(itinerary.id), completion: .all, archive: .all))))
    else { throw CancellationError() }
    #expect(own.progress.state == .partial)
    #expect(own.progress.doneCount == 1)
    #expect(own.progress.archivedCount == 0)
    #expect(own.progress.finishedCount == 1)
    #expect(partial.progress.state == .partial)
    #expect(partial.progress.doneCount == 0)
    #expect(partial.progress.archivedCount == 4)
    #expect(partial.progress.finishedCount == 4)
    #expect(partial.progress.totalCount == 5)
    #expect(query.progress.first?.archivedCount == 4)
    #expect(query.progress.first?.finishedCount == 4)
    #expect(query.matchingCount == 5)
    let direct = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: entries[0])
    _ = try await save(.setCompletion(scope: .appearance(direct), done: true))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let finished)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .appearance(let expanded) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entries[1], membershipId: memberships[0])))
    else { throw CancellationError() }
    #expect(finished.progress.state == .complete)
    #expect(finished.progress.doneCount == 1)
    #expect(finished.progress.archivedCount == 4)
    #expect(finished.progress.finishedCount == 5)
    #expect(expanded.globalDone == false)
    #expect(expanded.localDone == false)
    #expect(expanded.effectiveDone == false)
    #expect(expanded.archived == false)
    _ = try await save(.setArchive(source: list, archived: false))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    guard
      case .source(.itinerary(let restored)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .snapshot(let filtered) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .itinerary(itinerary.id), completion: .todo, archive: .all)))
      )
    else { throw CancellationError() }
    #expect(restored.progress.state == .partial)
    #expect(restored.progress.doneCount == 1)
    #expect(restored.progress.archivedCount == 0)
    #expect(restored.progress.finishedCount == 1)
    #expect(restored.references == partial.references)
    #expect(filtered.matchingCount == 4)
    #expect(filtered.progress.first?.finishedCount == 1)
  }
}
