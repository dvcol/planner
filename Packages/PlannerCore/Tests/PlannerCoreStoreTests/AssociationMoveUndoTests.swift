import Foundation
import PlannerCore
import SwiftData
import Testing

struct AssociationMoveUndoTests {
  @Test(arguments: [false, true])
  func committedMoveAndUndoRepairOnlyRecoveryWithoutRepeatingTheirChanges(restoring: Bool)
    async throws
  {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let creation = try await fixture.save(.createList(content: .init(name: "Destination")))
    let destination = try #require(creation.generated.first)
    let move = PlannerCommand.moveMembership(
      listId: fixture.list.id, membershipId: fixture.membershipIdentifier,
      destinationListId: destination.id, placement: .last)
    let command: PlannerCommand
    if restoring {
      let moved = await fixture.planner.execute(
        .init(operationId: UUID(), session: fixture.session, command: move))
      command = .restoreAssociation(snapshot: try #require(moved.associationUndoSnapshot))
    } else {
      command = move
    }
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let response = await fixture.planner.execute(
      .init(operationId: operationIdentifier, session: fixture.session, command: command))
    guard case .applied(let applied, .incomplete) = response.outcome else {
      Issue.record("The committed Move action must remain applied when recovery publication fails.")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    #expect((response.associationUndoSnapshot != nil) == !restoring)
    try obstruction.restore()
    let beforeRepair = try await fixture.export()
    let blocked = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .createItem(content: .init(title: "Must remain blocked"))))
    guard case .rejected(let failure) = blocked.outcome else { throw CancellationError() }
    #expect(failure.code == "mutationBlocked")
    let repair = await fixture.planner.retryRecovery(
      session: fixture.session, operationId: operationIdentifier)
    let replay = await fixture.planner.execute(
      .init(operationId: operationIdentifier, session: fixture.session, command: command))
    guard case .applied(let repaired, .complete(let checkpoint)) = repair.outcome,
      case .applied(let replayed, .complete(let replayCheckpoint)) = replay.outcome
    else { throw CancellationError() }
    #expect(repaired == applied && replayed == applied)
    #expect(checkpoint == (restoring ? 7 : 6) && replayCheckpoint == checkpoint)
    #expect(try await fixture.export() == beforeRepair)
    if !restoring {
      _ = try await fixture.save(
        .restoreAssociation(snapshot: try #require(replay.associationUndoSnapshot)))
    }
    guard case .decoded(let saved) = fixture.planner.decodeImport(try await fixture.export()) else {
      throw CancellationError()
    }
    #expect(saved.backup.memberships.count == 1)
    let original = try #require(saved.backup.memberships.first)
    #expect(original.id == fixture.membershipIdentifier && original.localDone)
    #expect(original.list == fixture.list)
  }

  @Test func moveUndoRestoresIndependentExpandedContextsWithoutCompletingOtherAppearances()
    async throws
  {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let routeCreation = try await fixture.save(.createItinerary(content: .init(title: "Route")))
    let route = try #require(routeCreation.generated.first)
    var entryIdentifiers: [UUID] = []
    for source in [fixture.list, fixture.list, fixture.item] {
      let addition = try await fixture.save(
        .addItineraryEntry(itineraryId: route.id, source: source, placement: .last))
      guard case .itineraryEntry(let identifier, _, _)? = addition.generatedReferences.first else {
        throw CancellationError()
      }
      entryIdentifiers.append(identifier)
    }
    let first = PlannerAppearance.expandedListItem(
      itineraryId: route.id, listEntryId: entryIdentifiers[0],
      membershipId: fixture.membershipIdentifier)
    let second = PlannerAppearance.expandedListItem(
      itineraryId: route.id, listEntryId: entryIdentifiers[1],
      membershipId: fixture.membershipIdentifier)
    let direct = PlannerAppearance.directItineraryItem(
      itineraryId: route.id, entryId: entryIdentifiers[2])
    _ = try await fixture.save(.setCompletion(scope: .appearance(first), done: true))
    let destinationCreation = try await fixture.save(
      .createList(content: .init(name: "Destination")))
    let destination = try #require(destinationCreation.generated.first)
    let moved = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .moveMembership(
          listId: fixture.list.id, membershipId: fixture.membershipIdentifier,
          destinationListId: destination.id, placement: .last)))
    let snapshot = try #require(moved.associationUndoSnapshot)
    _ = try await fixture.save(.restoreAssociation(snapshot: snapshot))
    for (appearance, expectedDone) in [(first, true), (second, false), (direct, false)] {
      guard
        case .appearance(let read) = await fixture.planner.read(
          session: fixture.session, request: .appearance(appearance))
      else { throw CancellationError() }
      #expect(read.source == fixture.item)
      #expect(read.localDone == expectedDone && read.effectiveDone == expectedDone)
      #expect(!read.globalDone)
    }
    guard
      case .source(.itinerary(let itinerary)) = await fixture.planner.read(
        session: fixture.session, request: .source(route))
    else { throw CancellationError() }
    #expect(itinerary.progress.doneCount == 1 && itinerary.progress.totalCount == 3)
  }

  @Test(arguments: ["completion", "order", "branch", "expanded", "replacement", "origin"])
  func newerRelationshipChangesRejectTheWholeMoveUndo(change: String) async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let creation = try await fixture.save(.createList(content: .init(name: "Destination")))
    let destination = try #require(creation.generated.first)
    let otherCreation = try await fixture.save(.createItem(content: .init(title: "Other")))
    let other = try #require(otherCreation.generated.first)
    _ = try await fixture.save(
      .addMembership(itemId: other.id, listId: destination.id, placement: .last))
    let routeCreation = try await fixture.save(.createItinerary(content: .init(title: "Route")))
    let route = try #require(routeCreation.generated.first)
    let branchCreation = try await fixture.save(
      .addItineraryEntry(itineraryId: route.id, source: destination, placement: .last))
    guard
      case .itineraryEntry(let branchIdentifier, _, _)? = branchCreation.generatedReferences.first
    else { throw CancellationError() }
    let moved = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .moveMembership(
          listId: fixture.list.id, membershipId: fixture.membershipIdentifier,
          destinationListId: destination.id, placement: .last)))
    guard case .applied(let result, .complete) = moved.outcome,
      case .membership(let destinationMembership, _, _)? = result.generatedReferences.first
    else { throw CancellationError() }
    let snapshot = try #require(moved.associationUndoSnapshot)
    switch change {
    case "completion":
      _ = try await fixture.save(
        .setCompletion(
          scope: .appearance(
            .listMembership(listId: destination.id, membershipId: destinationMembership)),
          done: true))
    case "order":
      _ = try await fixture.save(
        .reorderMembership(
          listId: destination.id, membershipId: destinationMembership, placement: .first))
    case "branch":
      _ = try await fixture.save(
        .addItineraryEntry(itineraryId: route.id, source: destination, placement: .last))
    case "expanded":
      _ = try await fixture.save(
        .setCompletion(
          scope: .appearance(
            .expandedListItem(
              itineraryId: route.id, listEntryId: branchIdentifier,
              membershipId: destinationMembership)), done: true))
    case "replacement":
      _ = try await fixture.save(
        .removeMembership(listId: destination.id, membershipId: destinationMembership))
      _ = try await fixture.save(
        .addMembership(itemId: fixture.item.id, listId: destination.id, placement: .last))
    case "origin":
      _ = try await fixture.save(
        .addMembership(itemId: fixture.item.id, listId: fixture.list.id, placement: .last))
    default: throw CancellationError()
    }
    let beforeUndo = try await fixture.export()
    let rejected = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .rejected(let failure) = rejected.outcome else {
      Issue.record("An unsafe Move inverse must reject as one action: \(change).")
      return
    }
    #expect(failure.code == "associationUndoUnavailable")
    #expect(try await fixture.export() == beforeUndo)
  }

  @Test func moveUndoPreservesAnExistingDestinationAndItsLaterLocalChanges() async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let creation = try await fixture.save(.createList(content: .init(name: "Destination")))
    let destination = try #require(creation.generated.first)
    let addition = try await fixture.save(
      .addMembership(itemId: fixture.item.id, listId: destination.id, placement: .last))
    guard case .membership(let destinationMembership, _, _)? = addition.generatedReferences.first
    else { throw CancellationError() }
    let appearance = PlannerAppearance.listMembership(
      listId: destination.id, membershipId: destinationMembership)
    _ = try await fixture.save(.setCompletion(scope: .appearance(appearance), done: true))
    let moved = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .moveMembership(
          listId: fixture.list.id, membershipId: fixture.membershipIdentifier,
          destinationListId: destination.id, placement: .last)))
    guard case .applied(let moveResult, .complete) = moved.outcome else {
      throw CancellationError()
    }
    #expect(moveResult.generatedReferences.isEmpty)
    let snapshot = try #require(moved.associationUndoSnapshot)
    _ = try await fixture.save(.setCompletion(scope: .appearance(appearance), done: false))
    guard case .decoded(let before) = fixture.planner.decodeImport(try await fixture.export())
    else {
      throw CancellationError()
    }
    let destinationBefore = try #require(
      before.backup.memberships.first { $0.id == destinationMembership })
    _ = try await fixture.save(.restoreAssociation(snapshot: snapshot))
    guard case .decoded(let after) = fixture.planner.decodeImport(try await fixture.export()) else {
      throw CancellationError()
    }
    #expect(after.backup.memberships.first { $0.id == destinationMembership } == destinationBefore)
    let restoredOrigin = try #require(
      after.backup.memberships.first { $0.id == fixture.membershipIdentifier })
    #expect(restoredOrigin.localDone && restoredOrigin.list == fixture.list)
    #expect(after.backup.memberships.count == 2)
  }

  @Test func moveUndoRestoresOriginAndRemovesOnlyItsCreatedDestination() async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let destinationCreation = try await fixture.save(
      .createList(content: .init(name: "Destination")))
    let destination = try #require(destinationCreation.generated.first)
    let otherCreation = try await fixture.save(.createItem(content: .init(title: "Other")))
    let other = try #require(otherCreation.generated.first)
    let otherAddition = try await fixture.save(
      .addMembership(itemId: other.id, listId: destination.id, placement: .last))
    guard case .membership(let otherMembership, _, _)? = otherAddition.generatedReferences.first,
      case .decoded(let original) = fixture.planner.decodeImport(try await fixture.export())
    else { throw CancellationError() }
    let originalMembership = try #require(
      original.backup.memberships.first { $0.id == fixture.membershipIdentifier })
    let moveIdentifier = UUID()
    let moveCommand = PlannerCommand.moveMembership(
      listId: fixture.list.id, membershipId: fixture.membershipIdentifier,
      destinationListId: destination.id, placement: .last)
    let moved = await fixture.planner.execute(
      .init(operationId: moveIdentifier, session: fixture.session, command: moveCommand))
    guard case .applied(_, .complete) = moved.outcome,
      case .source(.item(let item)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { throw CancellationError() }
    let snapshot = try #require(moved.associationUndoSnapshot)
    #expect(snapshot.identity.id == fixture.membershipIdentifier)
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.item.id, changes: .init(notes: .set("Edited after Move")),
        expectedFieldHashes: item.fieldHashes))
    let operationIdentifier = UUID()
    let operation = PlannerOperation(
      operationId: operationIdentifier, session: fixture.session,
      command: .restoreAssociation(snapshot: snapshot))
    let restored = await fixture.planner.execute(operation)
    guard case .applied(let result, .complete) = restored.outcome,
      case .decoded(let saved) = fixture.planner.decodeImport(try await fixture.export()),
      case .source(.item(let updatedItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { throw CancellationError() }
    let origin = try #require(
      saved.backup.memberships.first { $0.id == fixture.membershipIdentifier })
    #expect(origin.lifetimeId != originalMembership.lifetimeId)
    #expect(origin.rank == 0 && origin.localDone)
    #expect(origin.list == fixture.list && origin.item == fixture.item)
    #expect(
      saved.backup.memberships.filter { $0.list == destination }.map(\.id) == [otherMembership])
    #expect(
      updatedItem.content.notes == "Edited after Move" && updatedItem.state.globalDone == false)
    let beforeReplay = try await fixture.export()
    let replay = await fixture.planner.execute(operation)
    let moveReplay = await fixture.planner.execute(
      .init(operationId: moveIdentifier, session: fixture.session, command: moveCommand))
    guard case .applied(let replayed, .complete) = replay.outcome else {
      throw CancellationError()
    }
    #expect(replayed == result)
    #expect(moveReplay.associationUndoSnapshot?.closingOperationId == snapshot.closingOperationId)
    #expect(try await fixture.export() == beforeReplay)
  }
}
