import Foundation
import PlannerCore
import SwiftData
import Testing

struct AssociationUndoRecoveryTests {
  @Test(arguments: [false, true])
  func committedRemovalAndRestorationRepairRecoveryWithoutReapplying(restoring: Bool) async throws {
    let fixture = try await AssociationUndoFixture()
    let command: PlannerCommand
    let operationIdentifier: UUID
    if restoring {
      let removal = await fixture.remove()
      command = .restoreAssociation(snapshot: try #require(removal.associationUndoSnapshot))
      operationIdentifier = UUID()
    } else {
      command = fixture.removalCommand
      operationIdentifier = fixture.removalIdentifier
    }
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let response = await fixture.planner.execute(
      .init(operationId: operationIdentifier, session: fixture.session, command: command))
    guard case .applied(let applied, .incomplete) = response.outcome else {
      Issue.record("The committed association action must retain its applied outcome.")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    #expect((response.associationUndoSnapshot != nil) == !restoring)
    try obstruction.restore()
    let beforeRepair = try await fixture.export()
    let blocked = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .createItem(content: .init(title: "Must stay blocked"))))
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
    #expect(checkpoint == (restoring ? 6 : 5) && replayCheckpoint == checkpoint)
    #expect(try await fixture.export() == beforeRepair)
    if !restoring {
      let snapshot = try #require(replay.associationUndoSnapshot)
      _ = try await fixture.save(.restoreAssociation(snapshot: snapshot))
    }
    guard
      case .appearance(let retained) = await fixture.planner.read(
        session: fixture.session,
        request: .appearance(
          .listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier))),
      case .decoded(let decoded) = fixture.planner.decodeImport(try await fixture.export())
    else { throw CancellationError() }
    #expect(retained.localDone && retained.effectiveDone)
    #expect(decoded.backup.memberships.count == 1)
    #expect(decoded.backup.restorationFamilies.count == 1)
  }

  @Test func rejectedRecoveryPreparationKeepsTheIssuedUndoRetryable() async throws {
    let fixture = try await AssociationUndoFixture()
    let removal = await fixture.remove()
    let command = PlannerCommand.restoreAssociation(
      snapshot: try #require(removal.associationUndoSnapshot))
    let before = try await fixture.export()
    let recovery = fixture.configuration.recoveryDirectoryURL
    let retainedRecovery = fixture.directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recovery, to: retainedRecovery)
    try Data("Obstruct preparation.".utf8).write(to: recovery)
    let operationIdentifier = UUID()
    let failed = await fixture.planner.execute(
      .init(operationId: operationIdentifier, session: fixture.session, command: command))
    try FileManager.default.removeItem(at: recovery)
    try FileManager.default.moveItem(at: retainedRecovery, to: recovery)
    guard case .rejected(let failure) = failed.outcome,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(failure.code == "persistenceFailure")
    #expect(try await fixture.export() == before)
    let retry = await fixture.planner.execute(
      .init(operationId: operationIdentifier, session: fixture.session, command: command))
    guard case .applied(_, .complete) = retry.outcome else { throw CancellationError() }
  }
}
