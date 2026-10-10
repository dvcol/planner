import Foundation
import PlannerCore
import Testing

struct ItineraryEntryReorderingTests {
  @Test func reorderingRepeatedItemAndListEntriesRetainsAllLocalFlagsAcrossAnotherWriterAndReplay()
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
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    var references: [PlannerReferenceRead] = []
    var entryIds: [UUID] = []
    for source in [item, item, list, list] {
      let reference = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        )
        .generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      references.append(reference)
      entryIds.append(identifier)
    }
    let appearances: [PlannerAppearance] = [
      .directItineraryItem(itineraryId: itinerary.id, entryId: entryIds[0]),
      .directItineraryItem(itineraryId: itinerary.id, entryId: entryIds[1]),
      .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryIds[2], membershipId: membershipId),
      .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryIds[3], membershipId: membershipId),
    ]
    for appearance in [appearances[0], appearances[2]] {
      _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    }
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let originalItinerary)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    let reorder = PlannerOperation(
      operationId: UUID(), session: session,
      command: .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryIds[2], placement: .first))
    guard
      case .applied(let reordered, .complete(let checkpoint)) = await planner.execute(reorder)
        .outcome
    else {
      Issue.record("Moving a repeated List entry must retain its own completion context.")
      return
    }
    #expect(reordered.generatedIdentities.isEmpty)
    #expect(reordered.affected == [itinerary])
    #expect(reordered.affectedReferences == [references[2]])
    func orderedEntries(_ value: PlannerItinerarySourceRead) -> [PlannerReferenceRead] {
      value.references.filter {
        if case .itineraryEntry = $0 { return true }
        return false
      }
    }
    guard
      case .source(.itinerary(let firstOrder)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(
      orderedEntries(firstOrder) == [references[2], references[0], references[1], references[3]])
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        .init(
          operationId: UUID(), session: otherSession,
          command: .reorderItineraryEntry(
            itineraryId: itinerary.id, entryId: entryIds[0],
            placement: .after(associationId: entryIds[3])))
      ).outcome,
      case .source(.itinerary(let beforeSameOrder)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(
      orderedEntries(beforeSameOrder) == [
        references[2], references[1], references[3], references[0],
      ])
    _ = try await save(
      .reorderItineraryEntry(itineraryId: itinerary.id, entryId: entryIds[0], placement: .last))
    guard
      case .source(.itinerary(let sameOrder)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(sameOrder.updatedAt == beforeSameOrder.updatedAt)
    _ = try await save(
      .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryIds[3],
        placement: .before(associationId: entryIds[1])))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: reorder.operationId, session: reopenedSession, command: reorder.command)
      ).outcome,
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let retainedList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let currentCheckpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: currentCheckpoint))
    else { throw CancellationError() }
    #expect(replay == reordered && replayCheckpoint == checkpoint)
    #expect(
      orderedEntries(current) == [references[2], references[3], references[1], references[0]])
    #expect(current.progress.totalCount == 4 && current.progress.doneCount == 2)
    #expect(current.fieldHashes == originalItinerary.fieldHashes)
    #expect(current.createdAt == originalItinerary.createdAt)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedList.updatedAt == originalList.updatedAt)
    #expect(retainedList.fieldHashes == originalList.fieldHashes)
    for (index, appearance) in appearances.enumerated() {
      guard
        case .appearance(let value) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else { throw CancellationError() }
      #expect(value.localDone == (index == 0 || index == 2))
      #expect(value.effectiveDone == (index == 0 || index == 2))
    }
    let backup = recovery.decodedBackup.backup
    let entries = backup.itineraryEntries.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.id.uuidString < $1.id.uuidString
    }
    #expect(entries.map(\.id) == [entryIds[2], entryIds[3], entryIds[1], entryIds[0]])
    #expect(backup.expandedCompletions.count == 1)
    #expect(backup.expandedCompletions.first?.context.listEntryId == entryIds[2])
    #expect(backup.expandedCompletions.first?.localDone == true)
    #expect(backup.memberships.count == 1)
    #expect(backup.deletionMarkers.isEmpty)
  }
}
