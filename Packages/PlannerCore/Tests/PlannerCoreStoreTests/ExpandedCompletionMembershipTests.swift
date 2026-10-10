import Foundation
import PlannerCore
import Testing

struct ExpandedCompletionMembershipTests {
  @Test(arguments: ["remove", "moveNew", "moveExisting"])
  func closingMembershipClearsOnlyItsExpandedContextsAndOrdinaryReaddStartsTodo(mode: String)
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
    let sourceList = try #require(
      try await save(.createList(content: .init(name: "A"))).generated.first)
    let destinationList = try #require(
      try await save(.createList(content: .init(name: "B"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let sourceMembership = try #require(
      try await save(.addMembership(itemId: item.id, listId: sourceList.id, placement: .last))
        .generatedReferences.first)
    guard case .membership(let sourceMembershipId, _, _) = sourceMembership else {
      throw CancellationError()
    }
    var destinationMembershipId: UUID?
    if mode == "moveExisting" {
      let reference = try #require(
        try await save(
          .addMembership(itemId: item.id, listId: destinationList.id, placement: .last)
        ).generatedReferences.first)
      guard case .membership(let identifier, _, _) = reference else { throw CancellationError() }
      destinationMembershipId = identifier
    }
    var entryIds: [UUID] = []
    for list in [sourceList, sourceList, destinationList] {
      let reference = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
        ).generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      entryIds.append(identifier)
    }
    let originalAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entryIds[0], membershipId: sourceMembershipId)
    let completion = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(originalAppearance), done: true))
    guard
      case .applied(let completionResult, .complete(let completionCheckpoint)) =
        await planner.execute(completion).outcome
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id,
            listEntryId: entryIds[1], membershipId: sourceMembershipId)), done: true))
    if let destinationMembershipId {
      _ = try await save(
        .setCompletion(
          scope: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id,
              listEntryId: entryIds[2], membershipId: destinationMembershipId)), done: true))
    }
    let command: PlannerCommand
    if mode == "remove" {
      command = .removeMembership(listId: sourceList.id, membershipId: sourceMembershipId)
    } else {
      command = .moveMembership(
        listId: sourceList.id, membershipId: sourceMembershipId,
        destinationListId: destinationList.id, placement: .last)
    }
    guard
      case .applied(let closed, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else {
      Issue.record("Membership closure must atomically remove its expanded local contexts.")
      return
    }
    if mode == "moveNew" {
      guard case .membership(let identifier, _, _)? = closed.generatedReferences.first else {
        throw CancellationError()
      }
      destinationMembershipId = identifier
    }
    let readded = try #require(
      try await save(.addMembership(itemId: item.id, listId: sourceList.id, placement: .last))
        .generatedReferences.first)
    guard case .membership(let newMembershipId, _, _) = readded else { throw CancellationError() }
    #expect(newMembershipId != sourceMembershipId)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .appearance(let firstNew) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entryIds[0], membershipId: newMembershipId))),
      case .appearance(let secondNew) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entryIds[1], membershipId: newMembershipId))),
      case .failed(let missing) = await reopened.read(
        session: reopenedSession, request: .appearance(originalAppearance)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(
          operationId: completion.operationId,
          session: reopenedSession, command: completion.command)
      ).outcome,
      case .rejected(let staleAppearance) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .setCompletion(scope: .appearance(originalAppearance), done: true))
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(firstNew.localDone == false)
    #expect(secondNew.localDone == false)
    #expect(firstNew.effectiveDone == false)
    #expect(secondNew.effectiveDone == false)
    #expect(missing.code == "missingReference")
    #expect(staleAppearance.code == "missingReference")
    #expect(replay == completionResult)
    #expect(replayCheckpoint == completionCheckpoint)
    #expect(current.progress.totalCount == (mode == "remove" ? 2 : 3))
    #expect(current.progress.doneCount == (mode == "moveExisting" ? 1 : 0))
    #expect(
      recovery.decodedBackup.backup.expandedCompletions.allSatisfy {
        $0.context.membershipId != sourceMembershipId
      })
    #expect(
      recovery.decodedBackup.backup.expandedCompletions.count == (mode == "moveExisting" ? 1 : 0))
    #expect(
      recovery.decodedBackup.backup.deletionMarkers.contains { marker in
        if case .membership(let identifier, _) = marker.target {
          return identifier == sourceMembershipId
        }
        return false
      })
    #expect(namespace.preparedProposals.isEmpty)
    if let destinationMembershipId {
      guard
        case .appearance(let retained) = await reopened.read(
          session: reopenedSession,
          request: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id, listEntryId: entryIds[2],
              membershipId: destinationMembershipId)))
      else { throw CancellationError() }
      #expect(retained.localDone == (mode == "moveExisting"))
    }
  }
}
