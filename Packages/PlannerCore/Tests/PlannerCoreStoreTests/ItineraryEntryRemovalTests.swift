import Foundation
import PlannerCore
import Testing

struct ItineraryEntryRemovalTests {
  @Test(arguments: ["item", "list"])
  func removingOneRepeatedEntryClosesItsContextAndRetainsSourcesAndOtherAppearances(kind: String)
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
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep notes")))
        .generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipId)), done: true
      ))
    let source = kind == "item" ? item : list
    var references: [PlannerReferenceRead] = []
    var entryIds: [UUID] = []
    for _ in 0..<3 {
      let reference = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      references.append(reference)
      entryIds.append(identifier)
    }
    func appearance(_ entryId: UUID) -> PlannerAppearance {
      if kind == "item" { return .directItineraryItem(itineraryId: itinerary.id, entryId: entryId) }
      return .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryId, membershipId: membershipId)
    }
    let completion = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(appearance(entryIds[0])), done: true))
    guard
      case .applied(let completed, .complete(let completedCheckpoint)) = await planner.execute(
        completion
      ).outcome
    else {
      throw CancellationError()
    }
    _ = try await save(.setCompletion(scope: .appearance(appearance(entryIds[2])), done: true))
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let originalItinerary)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(originalItinerary.progress.totalCount == 3)
    #expect(originalItinerary.progress.doneCount == 2)
    let removal = PlannerOperation(
      operationId: UUID(), session: session,
      command: .removeItineraryEntry(itineraryId: itinerary.id, entryId: entryIds[0]))
    guard
      case .applied(let removed, .complete(let checkpoint)) = await planner.execute(removal).outcome
    else {
      Issue.record(
        "Removing one entry must acknowledge its context closure without deleting the source.")
      return
    }
    #expect(removed.generatedIdentities.isEmpty)
    #expect(removed.affected == [itinerary])
    #expect(removed.affectedReferences.contains(references[0]))
    let readded = try #require(
      try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
      ).generatedReferences.first)
    guard case .itineraryEntry(let newEntryId, _, _) = readded else { throw CancellationError() }
    #expect(!entryIds.contains(newEntryId))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let retainedList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .appearance(let second) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance(entryIds[1]))),
      case .appearance(let third) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance(entryIds[2]))),
      case .appearance(let fresh) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance(newEntryId))),
      case .failed(let missing) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance(entryIds[0]))),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: removal.operationId, session: reopenedSession, command: removal.command)
      ).outcome,
      case .applied(let completionReplay, .complete(let completionReplayCheckpoint)) =
        await reopened.execute(
          .init(
            operationId: completion.operationId, session: reopenedSession,
            command: completion.command)
        ).outcome,
      case .rejected(let stale) = await reopened.execute(
        .init(operationId: UUID(), session: reopenedSession, command: completion.command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(retainedItem.content.title == "Hotel")
    #expect(retainedItem.content.notes == "Keep notes")
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedList.content == originalList.content)
    #expect(retainedList.updatedAt == originalList.updatedAt)
    #expect(retainedList.fieldHashes == originalList.fieldHashes)
    #expect(retainedList.progress.doneCount == 1)
    #expect(
      current.references.filter {
        if case .itineraryEntry = $0 { return true }
        return false
      } == [references[1], references[2], readded])
    #expect(current.progress.totalCount == 3)
    #expect(current.progress.doneCount == 1)
    #expect(!second.localDone && third.localDone && !fresh.localDone)
    #expect(!fresh.effectiveDone)
    #expect(missing.code == "missingReference")
    #expect(stale.code == "missingReference")
    #expect(replay == removed && replayCheckpoint == checkpoint)
    #expect(completionReplay == completed && completionReplayCheckpoint == completedCheckpoint)
    let backup = recovery.decodedBackup.backup
    #expect(backup.itineraryEntries.count == 2)
    #expect(Set(backup.itineraryEntries.map(\.id)) == Set([entryIds[1], entryIds[2]]))
    #expect(backup.memberships.count == 1)
    #expect(backup.expandedCompletions.count == (kind == "list" ? 1 : 0))
    #expect(backup.expandedCompletions.allSatisfy { $0.context.listEntryId == entryIds[2] })
    let marker = try #require(backup.deletionMarkers.first)
    #expect(backup.deletionMarkers.count == 1)
    #expect(marker.operationId == removal.operationId)
    #expect(marker.target == .itineraryEntry(id: entryIds[0], lifetimeId: entryIds[0]))
    let portable = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let target = try #require(
      (portable["deletionMarkers"] as? [[String: Any]])?.first?["target"] as? [String: Any])
    #expect(Set(target.keys) == ["kind", "id", "lifetimeId"])
    #expect(target["kind"] as? String == "itineraryEntry")
  }

  @Test(arguments: ["item", "list"])
  func undoRestoresOneRepeatedEntryAndItsIndependentCompletion(sourceKind: String) async throws {
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
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep shared notes")))
        .generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    guard
      case .membership(let membershipIdentifier, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier)),
        done: true))
    let source = sourceKind == "item" ? item : list
    var entryIdentifiers: [UUID] = []
    var references: [PlannerReferenceRead] = []
    for _ in 0..<2 {
      let reference = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        )
        .generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      entryIdentifiers.append(identifier)
      references.append(reference)
    }
    func appearance(_ entryIdentifier: UUID) -> PlannerAppearance {
      if sourceKind == "item" {
        return .directItineraryItem(itineraryId: itinerary.id, entryId: entryIdentifier)
      }
      return .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryIdentifier,
        membershipId: membershipIdentifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(appearance(entryIdentifiers[0])), done: true))
    guard case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    let originalMembership = try #require(
      original.backup.memberships.first {
        $0.id == membershipIdentifier
      })
    let originalEntry = try #require(
      original.backup.itineraryEntries.first {
        $0.id == entryIdentifiers[0]
      })
    let removal = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .removeItineraryEntry(itineraryId: itinerary.id, entryId: entryIdentifiers[0])))
    guard case .applied(_, .complete) = removal.outcome else { throw CancellationError() }
    let snapshot = try #require(removal.associationUndoSnapshot)
    _ = try await save(.restoreAssociation(snapshot: snapshot))
    guard
      case .appearance(let restored) = await planner.read(
        session: session, request: .appearance(appearance(entryIdentifiers[0]))),
      case .appearance(let other) = await planner.read(
        session: session, request: .appearance(appearance(entryIdentifiers[1]))),
      case .source(.list(let retainedList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let restoredItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .exported(let restoredData) = await planner.exportData(session: session),
      case .decoded(let restoredBackup) = planner.decodeImport(restoredData)
    else { throw CancellationError() }
    let restoredEntry = try #require(
      restoredBackup.backup.itineraryEntries.first {
        $0.id == entryIdentifiers[0]
      })
    #expect(restoredEntry.lifetimeId != originalEntry.lifetimeId)
    #expect(restoredEntry.rank == originalEntry.rank)
    #expect(restored.localDone && restored.effectiveDone)
    #expect(!other.localDone && !other.effectiveDone)
    #expect(retainedList.progress.doneCount == 1)
    #expect(retainedList.updatedAt == originalList.updatedAt)
    #expect(restoredItinerary.progress.doneCount == 1 && restoredItinerary.progress.totalCount == 2)
    #expect(
      restoredItinerary.references.filter {
        if case .itineraryEntry = $0 { return true }
        return false
      } == references)
    if sourceKind == "list" {
      let expanded = try #require(
        restoredBackup.backup.expandedCompletions.first {
          $0.context.listEntryId == entryIdentifiers[0]
        })
      #expect(expanded.context.listEntryLifetimeId == restoredEntry.lifetimeId)
      #expect(expanded.context.membershipLifetimeId == originalMembership.lifetimeId)
      #expect(expanded.localDone)
    }
  }
}
