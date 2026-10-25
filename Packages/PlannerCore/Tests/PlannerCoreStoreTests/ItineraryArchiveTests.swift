import Foundation
import PlannerCore
import Testing

struct ItineraryArchiveTests {
  @Test func itineraryArchiveAndUnarchivePreserveLiveContentReferencesAndEveryCompletionScope()
    async throws
  {
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
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Food"))).generated.first)
    let tag = try #require(try await save(.createTag(content: .init(name: "Rain"))).generated.first)
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Item notes"))).generated
        .first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Route", notes: "Original notes", iconName: "map",
            location: .init(
              displayName: "Tokyo", formattedAddress: "Tokyo, Japan",
              coordinate: .init(latitude: 35, longitude: 139)),
            links: [.init(originalUrl: "https://example.com/route", label: "Route")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    let other = try #require(
      try await save(.createItinerary(content: .init(title: "Other Route"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let directEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let listEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let otherEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: other.id, source: item, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    let direct = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: directEntryId)
    let expanded = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: listEntryId, membershipId: membershipId)
    for appearance in [direct, expanded] {
      _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    }
    guard
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let originalOther)) = await planner.read(
        session: session, request: .source(other))
    else { throw CancellationError() }
    #expect(original.progress.totalCount == 2 && original.progress.doneCount == 2)
    let archive = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setArchive(source: itinerary, archived: true))
    guard
      case .applied(let archivedResult, .complete(let archiveCheckpoint)) = await planner.execute(
        archive
      ).outcome,
      case .source(.itinerary(let archived)) = await planner.read(
        session: session, request: .source(itinerary))
    else {
      Issue.record(
        "Archive must persist only the Itinerary's archive state and acknowledge recovery.")
      return
    }
    #expect(archivedResult.generatedIdentities.isEmpty)
    #expect(archivedResult.affected == [itinerary])
    #expect(archived.state.archived == true && archived.state.globalDone == nil)
    #expect(archived.content == original.content)
    #expect(archived.labels == original.labels)
    #expect(archived.references == original.references)
    #expect(archived.fieldHashes == original.fieldHashes)
    #expect(archived.createdAt == original.createdAt)
    #expect(archived.progress.state == .complete)
    #expect(archived.progress.doneCount == 2 && archived.progress.totalCount == 2)
    _ = try await save(archive.command)
    guard
      case .source(.itinerary(let sameState)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(sameState.updatedAt == archived.updatedAt)
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id, changes: .init(notes: .set("Later notes")),
        expectedFieldHashes: [.notes: try #require(archived.fieldHashes[.notes])]))
    guard
      case .source(.itinerary(let edited)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(edited.state.archived == true)
    #expect(edited.content.notes == "Later notes")
    _ = try await save(.setArchive(source: itinerary, archived: false))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(
          operationId: archive.operationId, session: reopenedSession, command: archive.command)
      ).outcome,
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let retainedList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.itinerary(let retainedOther)) = await reopened.read(
        session: reopenedSession, request: .source(other)),
      case .appearance(let retainedDirect) = await reopened.read(
        session: reopenedSession, request: .appearance(direct)),
      case .appearance(let retainedExpanded) = await reopened.read(
        session: reopenedSession, request: .appearance(expanded)),
      case .appearance(let standalone) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: list.id, membershipId: membershipId))),
      case .appearance(let otherAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .directItineraryItem(itineraryId: other.id, entryId: otherEntryId))),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let currentCheckpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let archivedRecovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: archiveCheckpoint)),
      case .selected(let currentRecovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: currentCheckpoint))
    else { throw CancellationError() }
    #expect(replay == archivedResult && replayCheckpoint == archiveCheckpoint)
    #expect(current.state.archived == false && current.state.globalDone == nil)
    #expect(current.content == edited.content)
    #expect(current.fieldHashes == edited.fieldHashes)
    #expect(current.references == original.references)
    #expect(current.progress.doneCount == 2 && current.progress.totalCount == 2)
    #expect(retainedDirect.localDone && retainedExpanded.localDone)
    #expect(!retainedDirect.globalDone && !retainedExpanded.globalDone)
    #expect(!standalone.localDone && !standalone.effectiveDone)
    #expect(!otherAppearance.localDone && !otherAppearance.effectiveDone)
    #expect(retainedItem.state.archived == false && retainedItem.state.globalDone == false)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(
      retainedList.state.archived == false && retainedList.updatedAt == originalList.updatedAt)
    #expect(retainedList.fieldHashes == originalList.fieldHashes)
    #expect(
      retainedOther.state.archived == false && retainedOther.updatedAt == originalOther.updatedAt)
    #expect(retainedOther.references == originalOther.references)
    let oldBackup = archivedRecovery.decodedBackup.backup
    let currentBackup = currentRecovery.decodedBackup.backup
    func backedUpItinerary(_ backup: PlannerPortableBackup) -> PlannerPortableItinerary? {
      backup.sources.compactMap { source in
        guard case .itinerary(let value) = source, value.id == itinerary.id else { return nil }
        return value
      }.first
    }
    #expect(backedUpItinerary(oldBackup)?.archived == true)
    #expect(backedUpItinerary(oldBackup)?.content.notes == "Original notes")
    #expect(backedUpItinerary(currentBackup)?.archived == false)
    #expect(backedUpItinerary(currentBackup)?.content.notes == "Later notes")
    #expect(currentBackup.itineraryEntries.count == 3)
    #expect(currentBackup.expandedCompletions.count == 1)
    #expect(currentBackup.expandedCompletions.first?.localDone == true)
    #expect(currentBackup.memberships.count == 1 && currentBackup.deletionMarkers.isEmpty)
  }
}
