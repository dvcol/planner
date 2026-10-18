import Foundation
import PlannerCore
import Testing

struct AssociationUndoHistoryTests {
  @Test(arguments: ["membership", "entry"])
  func recreatedExpandedCounterpartsRejectTheWholeUndo(kind: String) async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let itinerary = try #require(
      try await fixture.save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let addition = try await fixture.save(
      .addItineraryEntry(itineraryId: itinerary.id, source: fixture.list, placement: .last))
    guard case .itineraryEntry(let entryIdentifier, _, _)? = addition.generatedReferences.first
    else { throw CancellationError() }
    _ = try await fixture.save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entryIdentifier,
            membershipId: fixture.membershipIdentifier)), done: true))
    let entryRemoval = PlannerCommand.removeItineraryEntry(
      itineraryId: itinerary.id, entryId: entryIdentifier)
    let removal: PlannerOperationResult
    if kind == "membership" {
      removal = await fixture.remove()
      _ = try await fixture.save(entryRemoval)
      _ = try await fixture.save(
        .addItineraryEntry(itineraryId: itinerary.id, source: fixture.list, placement: .last))
    } else {
      removal = await fixture.planner.execute(
        .init(operationId: UUID(), session: fixture.session, command: entryRemoval))
      _ = try await fixture.save(fixture.removalCommand)
      _ = try await fixture.save(
        .addMembership(itemId: fixture.item.id, listId: fixture.list.id, placement: .last))
    }
    let snapshot = try #require(removal.associationUndoSnapshot)
    let before = try await fixture.export()
    let response = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .rejected(let failure) = response.outcome else { throw CancellationError() }
    #expect(failure.code == "associationUndoUnavailable")
    #expect(try await fixture.export() == before)
  }

  @Test func anotherDatasetCannotConsumeTheIssuedUndoCapability() async throws {
    let original = try await AssociationUndoFixture()
    let other = try await AssociationUndoFixture()
    defer {
      try? FileManager.default.removeItem(at: original.directory)
      try? FileManager.default.removeItem(at: other.directory)
    }
    let removal = await original.remove()
    let snapshot = try #require(removal.associationUndoSnapshot)
    let before = try await other.export()
    let operationIdentifier = UUID()
    let response = await other.planner.execute(
      .init(
        operationId: operationIdentifier, session: other.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .rejected(let failure) = response.outcome,
      case .noReliableEvidence = await other.planner.operationStatus(
        session: other.session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(failure.code == "associationUndoUnavailable")
    #expect(try await other.export() == before)
    _ = try await original.save(.restoreAssociation(snapshot: snapshot))
    guard
      case .appearance(let restored) = await original.planner.read(
        session: original.session,
        request: .appearance(
          .listMembership(listId: original.list.id, membershipId: original.membershipIdentifier)))
    else { throw CancellationError() }
    #expect(restored.localDone && restored.effectiveDone)
  }

  @Test(arguments: ["item", "list"])
  func deletedOriginalBindingsRejectUndoWithoutChangingSurvivors(kind: String) async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let removal = await fixture.remove()
    let snapshot = try #require(removal.associationUndoSnapshot)
    let deleted = kind == "item" ? fixture.item : fixture.list
    let deletion = PlannerCommand.deleteSource(source: deleted)
    guard
      case .reviewed(let review) = await fixture.planner.prepareReview(
        session: fixture.session, command: deletion),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: deletion,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let before = try await fixture.export()
    let restoration = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .rejected(let failure) = restoration.outcome else { throw CancellationError() }
    #expect(failure.code == "associationUndoUnavailable")
    #expect(try await fixture.export() == before)
    let survivor = kind == "item" ? fixture.list : fixture.item
    guard
      case .source = await fixture.planner.read(
        session: fixture.session, request: .source(survivor))
    else { throw CancellationError() }
  }

  @Test func anotherRemovalRestoresOnlyItsOwnFreshLifetimeAndClosesOlderHistory() async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let firstRemoval = await fixture.remove()
    let firstSnapshot = try #require(firstRemoval.associationUndoSnapshot)
    _ = try await fixture.save(.restoreAssociation(snapshot: firstSnapshot))
    let secondRemoval = await fixture.planner.execute(
      .init(operationId: UUID(), session: fixture.session, command: fixture.removalCommand))
    let secondSnapshot = try #require(secondRemoval.associationUndoSnapshot)
    #expect(secondSnapshot.identity.id == firstSnapshot.identity.id)
    #expect(secondSnapshot.identity.lifetimeId != firstSnapshot.identity.lifetimeId)
    let before = try await fixture.export()
    let oldUndo = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .restoreAssociation(snapshot: firstSnapshot)))
    guard case .rejected(let failure) = oldUndo.outcome else { throw CancellationError() }
    #expect(failure.code == "associationUndoUnavailable")
    #expect(try await fixture.export() == before)
    _ = try await fixture.save(.restoreAssociation(snapshot: secondSnapshot))
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let data) = await reopened.exportData(session: session),
      case .decoded(let decoded) = reopened.decodeImport(data),
      case .appearance(let appearance) = await reopened.read(
        session: session,
        request: .appearance(
          .listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier)))
    else { throw CancellationError() }
    #expect(decoded.backup.memberships.count == 1)
    #expect(decoded.backup.restorationFamilies.count == 2)
    #expect(appearance.localDone && appearance.effectiveDone)
    #expect(decoded.backup.memberships.first?.lifetimeId != secondSnapshot.identity.lifetimeId)
  }

  @Test func issuanceEndsOnReopenButAppliedRestorationReplayPreservesLaterEdits() async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let removal = await fixture.remove()
    let snapshot = try #require(removal.associationUndoSnapshot)
    let replay = await fixture.remove()
    #expect(replay.associationUndoSnapshot?.closingOperationId == fixture.removalIdentifier)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      throw CancellationError()
    }
    let removalReplay = await reopened.execute(
      .init(
        operationId: fixture.removalIdentifier, session: reopenedSession,
        command: fixture.removalCommand))
    #expect(removalReplay.associationUndoSnapshot == nil)
    let expired = await reopened.execute(
      .init(
        operationId: UUID(), session: reopenedSession,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .rejected(let expiration) = expired.outcome,
      case .source(.item(let item)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { throw CancellationError() }
    #expect(expiration.code == "associationUndoUnavailable")
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.item.id, changes: .init(notes: .set("Edited after removal")),
        expectedFieldHashes: [.notes: try #require(item.fieldHashes[.notes])]))
    let restorationIdentifier = UUID()
    let restoration = await fixture.planner.execute(
      .init(
        operationId: restorationIdentifier, session: fixture.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .applied(let restored, .complete(let checkpoint)) = restoration.outcome,
      case .source(.item(let edited)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { throw CancellationError() }
    #expect(edited.content.notes == "Edited after removal")
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.item.id, changes: .init(notes: .set("Edited after restoration")),
        expectedFieldHashes: [.notes: try #require(edited.fieldHashes[.notes])]))
    let beforeReplay = try await fixture.export()
    let restorationReplay = await reopened.execute(
      .init(
        operationId: restorationIdentifier, session: reopenedSession,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .applied(let replayed, .complete(let replayCheckpoint)) = restorationReplay.outcome
    else { throw CancellationError() }
    #expect(replayed == restored && replayCheckpoint == checkpoint)
    let consumed = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .rejected(let consumedFailure) = consumed.outcome else {
      throw CancellationError()
    }
    #expect(consumedFailure.code == "associationUndoUnavailable")
    #expect(try await fixture.export() == beforeReplay)
  }

  @Test func newerMembershipRejectsOldUndoWithoutReplacingLocalState() async throws {
    let fixture = try await AssociationUndoFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let removal = await fixture.remove()
    let snapshot = try #require(removal.associationUndoSnapshot)
    let replacement = try await fixture.save(
      .addMembership(itemId: fixture.item.id, listId: fixture.list.id, placement: .last))
    guard case .membership(let replacementIdentifier, _, _)? = replacement.generatedReferences.first
    else { throw CancellationError() }
    let before = try await fixture.export()
    let response = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .rejected(let failure) = response.outcome,
      case .appearance(let retained) = await fixture.planner.read(
        session: fixture.session,
        request: .appearance(
          .listMembership(listId: fixture.list.id, membershipId: replacementIdentifier)))
    else { throw CancellationError() }
    #expect(failure.code == "associationUndoUnavailable")
    #expect(response.associationUndoSnapshot == nil)
    #expect(replacementIdentifier != fixture.membershipIdentifier)
    #expect(!retained.localDone && !retained.effectiveDone)
    #expect(try await fixture.export() == before)
  }
}

struct AssociationUndoFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let list: PlannerEntityReference
  let membershipIdentifier: UUID
  let removalIdentifier = UUID()

  init() async throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    configuration = .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    planner = Planner(configuration: configuration)
    guard case .ready(let ready) = await planner.bootstrap() else { throw CancellationError() }
    session = ready
    guard
      case .applied(let itemCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: ready,
          command: .createItem(content: .init(title: "Museum", notes: "Original notes")))
      ).outcome,
      let createdItem = itemCreation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: ready,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let createdList = listCreation.generated.first,
      case .applied(let membershipCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: ready,
          command: .addMembership(
            itemId: createdItem.id, listId: createdList.id, placement: .last))
      ).outcome,
      case .membership(let identifier, _, _)? = membershipCreation.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: ready,
          command: .setCompletion(
            scope: .appearance(
              .listMembership(listId: createdList.id, membershipId: identifier)), done: true))
      ).outcome
    else { throw CancellationError() }
    item = createdItem
    list = createdList
    membershipIdentifier = identifier
  }

  func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return result
  }

  func remove() async -> PlannerOperationResult {
    await planner.execute(
      .init(operationId: removalIdentifier, session: session, command: removalCommand))
  }

  var removalCommand: PlannerCommand {
    .removeMembership(listId: list.id, membershipId: membershipIdentifier)
  }

  func export() async throws -> Data {
    guard case .exported(let data) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    return data
  }
}
