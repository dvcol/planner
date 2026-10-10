import Foundation
import PlannerCore
import Testing

struct ExpandedCompletionTests {
  @Test func expandedCompletionBelongsToOneListEntryAndRetainsGlobalPrecedenceAcrossRecovery()
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
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let secondItem = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Stops"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "A"))).generated.first)
    let other = try #require(
      try await save(.createItinerary(content: .init(title: "B"))).generated.first)
    let membership = try #require(
      try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
        .generatedReferences.first)
    _ = try await save(.addMembership(itemId: secondItem.id, listId: list.id, placement: .last))
    var entryIds: [UUID] = []
    for (owner, source) in [(itinerary, list), (itinerary, list), (itinerary, item), (other, list)]
    {
      let reference = try #require(
        try await save(.addItineraryEntry(itineraryId: owner.id, source: source, placement: .last))
          .generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      entryIds.append(identifier)
    }
    guard case .membership(let membershipId, _, _) = membership else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipId)), done: true
      ))
    let first = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entryIds[0], membershipId: membershipId)
    let second = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entryIds[1], membershipId: membershipId)
    let otherAppearance = PlannerAppearance.expandedListItem(
      itineraryId: other.id, listEntryId: entryIds[3], membershipId: membershipId)
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let originalItinerary)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(first), done: true))
    guard
      case .applied(let result, .complete(let firstCheckpoint)) = await planner.execute(operation)
        .outcome
    else {
      Issue.record("Complete only the selected child inside one itinerary List entry.")
      return
    }
    guard
      case .appearance(let firstRead) = await planner.read(
        session: session, request: .appearance(first)),
      case .appearance(let secondRead) = await planner.read(
        session: session, request: .appearance(second)),
      case .appearance(let otherRead) = await planner.read(
        session: session, request: .appearance(otherAppearance)),
      case .appearance(let directRead) = await planner.read(
        session: session,
        request: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: entryIds[2]))),
      case .source(.item(let unchangedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let partial)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(firstRead.localDone == true)
    #expect(firstRead.effectiveDone == true)
    #expect(secondRead.localDone == false)
    #expect(secondRead.effectiveDone == false)
    #expect(otherRead.effectiveDone == false)
    #expect(directRead.effectiveDone == false)
    #expect(unchangedItem.updatedAt == originalItem.updatedAt)
    #expect(unchangedItem.fieldHashes == originalItem.fieldHashes)
    #expect(partial.fieldHashes == originalItinerary.fieldHashes)
    #expect(partial.progress.doneCount == 1)
    #expect(partial.progress.totalCount == 5)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await save(.setCompletion(scope: .appearance(first), done: false))
    guard
      case .appearance(let inherited) = await planner.read(
        session: session, request: .appearance(first))
    else { throw CancellationError() }
    #expect(inherited.localDone == false)
    #expect(inherited.globalDone == true)
    #expect(inherited.effectiveDone == true)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: false))
    guard
      case .appearance(let reopenedFirst) = await planner.read(
        session: session, request: .appearance(first))
    else { throw CancellationError() }
    #expect(reopenedFirst.effectiveDone == false)
    _ = try await save(.setCompletion(scope: .appearance(first), done: true))
    _ = try await save(.setArchive(source: item, archived: true))
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id, changes: .init(notes: .set("Live plan")),
        expectedFieldHashes: [.notes: try #require(originalItinerary.fieldHashes[.notes])]))
    _ = try await save(.createTag(content: .init(name: "Rain")))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .appearance(let retained) = await reopened.read(
        session: reopenedSession, request: .appearance(first)),
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .applied(let replay, .complete(let checkpoint)) = await reopened.execute(
        .init(
          operationId: operation.operationId,
          session: reopenedSession, command: operation.command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 20)
      )
    else { throw CancellationError() }
    #expect(retained.localDone == true)
    #expect(retained.globalDone == false)
    #expect(retained.effectiveDone == true)
    #expect(retained.archived == true)
    #expect(current.content.notes == "Live plan")
    #expect(current.progress.doneCount == 1)
    #expect(current.progress.totalCount == 5)
    #expect(replay == result)
    #expect(checkpoint == firstCheckpoint)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 20)
    #expect(namespace.preparedProposals.isEmpty)
    let payload = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let completions = try #require(payload["expandedCompletions"] as? [[String: Any]])
    #expect(completions.count == 1)
    #expect(Set(try #require(completions.first).keys) == ["context", "localDone"])
    #expect(completions.first?["localDone"] as? Bool == true)
    let context = try #require(completions.first?["context"] as? [String: Any])
    #expect(context["listEntryId"] as? String == entryIds[0].uuidString)
    #expect(context["listEntryLifetimeId"] as? String == entryIds[0].uuidString)
    #expect(context["membershipId"] as? String == membershipId.uuidString)
    #expect(context["membershipLifetimeId"] as? String == membershipId.uuidString)
  }
}
