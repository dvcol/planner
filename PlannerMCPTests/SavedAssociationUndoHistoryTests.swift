import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class SavedAssociationUndoHistoryTests: XCTestCase {
  func testNativeMoveResponseRegistersOneWholeInverseWithItsActionName() async throws {
    let fixture = try await Fixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let creation = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .createList(content: .init(name: "Destination"))))
    guard case .applied(let created, .complete) = creation.outcome else {
      throw CancellationError()
    }
    let destination = try XCTUnwrap(created.generated.first)
    let response = await fixture.store.moveMembership(
      fixture.membershipIdentifiers[0], listIdentifier: fixture.list.id,
      destinationListIdentifier: destination.id, operationIdentifier: UUID())
    let moved = try XCTUnwrap(response)
    guard case .applied(_, .complete) = moved.outcome else { throw CancellationError() }
    let history = SavedAssociationUndoHistory()
    let manager = UndoManager()
    manager.groupsByEvent = false
    defer { history.clear() }
    manager.beginUndoGrouping()
    history.record(moved, name: "Move Item", store: fixture.store, manager: manager)
    manager.endUndoGrouping()
    XCTAssertEqual(manager.undoActionName, "Move Item")
    XCTAssertEqual(history.actionTitle, "Undo Move Item")
    manager.undo()
    try await waitForRestoration(history)
    let restored = try await fixture.memberships().sorted { $0.rank < $1.rank }
    XCTAssertEqual(restored.map(\.id), fixture.membershipIdentifiers)
    XCTAssertTrue(restored.allSatisfy { $0.list == fixture.list && $0.localDone })
    XCTAssertFalse(manager.canUndo)
    XCTAssertFalse(manager.canRedo)
    XCTAssertNil(history.actionTitle)
  }

  func testSeparateHistoriesRestoreOnlyTheirOwnRemovalAndPreserveOrdinaryUndo() async throws {
    let fixture = try await Fixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let firstHistory = SavedAssociationUndoHistory()
    let secondHistory = SavedAssociationUndoHistory()
    let firstManager = UndoManager()
    let secondManager = UndoManager()
    firstManager.groupsByEvent = false
    secondManager.groupsByEvent = false
    defer {
      firstHistory.clear()
      secondHistory.clear()
    }
    let ordinaryEdit = OrdinaryEdit()
    firstManager.beginUndoGrouping()
    firstManager.registerUndo(withTarget: ordinaryEdit) { $0.value = "Original" }
    firstManager.setActionName("Edit Title")
    firstManager.endUndoGrouping()

    try await fixture.remove(at: 0, history: firstHistory, manager: firstManager)
    try await fixture.remove(at: 1, history: secondHistory, manager: secondManager)
    XCTAssertEqual(firstManager.undoActionName, "Remove Museum")
    XCTAssertEqual(secondManager.undoActionName, "Remove Lunch")
    let removed = try await fixture.memberships()
    XCTAssertEqual(removed.count, 0)
    firstManager.undo()
    XCTAssertTrue(firstHistory.isRestoring)
    XCTAssertFalse(secondHistory.isRestoring)
    try await waitForRestoration(firstHistory)
    let restored = try await fixture.memberships()
    XCTAssertEqual(restored.map(\.id), [fixture.membershipIdentifiers[0]])
    XCTAssertTrue(try XCTUnwrap(restored.first).localDone)
    XCTAssertNil(firstHistory.actionTitle)
    XCTAssertEqual(secondHistory.actionTitle, "Undo Remove Lunch")
    XCTAssertFalse(firstManager.canRedo)
    XCTAssertEqual(firstManager.undoActionName, "Edit Title")

    secondHistory.clear()
    XCTAssertFalse(secondManager.canUndo)
    firstHistory.clear()
    XCTAssertTrue(firstManager.canUndo)
    firstManager.undo()
    XCTAssertEqual(ordinaryEdit.value, "Original")
    let afterOrdinaryUndo = try await fixture.memberships()
    XCTAssertEqual(afterOrdinaryUndo.map(\.id), [fixture.membershipIdentifiers[0]])
  }

  func testNativeUndoQueuesDistinctRemovalsAndDoesNotRegisterRedo() async throws {
    let fixture = try await Fixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let history = SavedAssociationUndoHistory()
    let manager = UndoManager()
    manager.groupsByEvent = false
    defer { history.clear() }
    let original = try await fixture.memberships()
    try await fixture.remove(at: 0, history: history, manager: manager)
    try await fixture.remove(at: 1, history: history, manager: manager)
    manager.undo()
    XCTAssertTrue(history.isRestoring)
    XCTAssertTrue(history.presentsControl)
    manager.undo()
    history.undo()
    try await waitForRestoration(history)
    let restored = try await fixture.memberships().sorted { $0.rank < $1.rank }
    XCTAssertEqual(restored.map(\.id), fixture.membershipIdentifiers)
    XCTAssertTrue(restored.allSatisfy(\.localDone))
    XCTAssertTrue(
      restored.allSatisfy { restoredMembership in
        original.contains {
          $0.id == restoredMembership.id && $0.lifetimeId != restoredMembership.lifetimeId
        }
      })
    XCTAssertNil(history.actionTitle)
    XCTAssertFalse(history.presentsControl)
    XCTAssertFalse(manager.canUndo)
    XCTAssertFalse(manager.canRedo)
  }

  func testRecoveryPreparationFailureRetainsRetryAndRestoresOnceAfterRepair() async throws {
    let fixture = try await Fixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let history = SavedAssociationUndoHistory()
    let manager = UndoManager()
    manager.groupsByEvent = false
    defer { history.clear() }
    try await fixture.remove(at: 0, history: history, manager: manager)
    try await fixture.remove(at: 1, history: history, manager: manager)
    let beforeFailure = try await fixture.backupData()
    let recovery = fixture.configuration.recoveryDirectoryURL
    let retainedRecovery = fixture.directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recovery, to: retainedRecovery)
    try Data("Block recovery preparation.".utf8).write(to: recovery)
    defer {
      if FileManager.default.fileExists(atPath: retainedRecovery.path) {
        try? FileManager.default.removeItem(at: recovery)
        try? FileManager.default.moveItem(at: retainedRecovery, to: recovery)
      }
    }
    manager.undo()
    manager.undo()
    try await waitForRestoration(history)
    XCTAssertEqual(history.actionTitle, "Retry Undo")
    XCTAssertTrue(history.presentsControl)
    XCTAssertNotNil(fixture.store.alertMessage)
    XCTAssertFalse(manager.canRedo)
    let afterFailure = try await fixture.backupData()
    XCTAssertEqual(afterFailure, beforeFailure)

    try FileManager.default.removeItem(at: recovery)
    try FileManager.default.moveItem(at: retainedRecovery, to: recovery)
    fixture.store.alertMessage = nil
    history.undo()
    XCTAssertTrue(history.isRestoring)
    history.undo()
    try await waitForRestoration(history)
    let restored = try await fixture.memberships()
    XCTAssertEqual(Set(restored.map(\.id)), Set(fixture.membershipIdentifiers))
    XCTAssertTrue(restored.allSatisfy(\.localDone))
    XCTAssertNil(history.actionTitle)
    XCTAssertFalse(manager.canUndo)
    XCTAssertFalse(manager.canRedo)
    let afterRepair = try await fixture.backupData()
    history.undo()
    let afterEmptyUndo = try await fixture.backupData()
    XCTAssertEqual(afterEmptyUndo, afterRepair)
  }

  func testNewerMembershipRejectsOldUndoWithExplanationAndPreservesCurrentData() async throws {
    let fixture = try await Fixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let history = SavedAssociationUndoHistory()
    let manager = UndoManager()
    manager.groupsByEvent = false
    defer { history.clear() }
    try await fixture.remove(at: 0, history: history, manager: manager)
    let added = await fixture.store.addMembership(
      itemId: fixture.items[0].id, listId: fixture.list.id, operationId: UUID())
    XCTAssertTrue(added)
    let current = try await fixture.memberships()
    let newer = try XCTUnwrap(current.first { $0.item == fixture.items[0] })
    XCTAssertNotEqual(newer.id, fixture.membershipIdentifiers[0])
    XCTAssertFalse(newer.localDone)
    let beforeUndo = try await fixture.backupData()
    manager.undo()
    try await waitForRestoration(history)
    XCTAssertNil(history.actionTitle)
    XCTAssertFalse(history.presentsControl)
    XCTAssertFalse(manager.canUndo)
    XCTAssertFalse(manager.canRedo)
    XCTAssertTrue(
      try XCTUnwrap(fixture.store.alertMessage).lowercased().contains("newer membership"))
    let afterUndo = try await fixture.backupData()
    XCTAssertEqual(afterUndo, beforeUndo)
  }

  func testExplicitUndoDeduplicatesRemovalAndPreservesOtherManagerTargets() async throws {
    let fixture = try await Fixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let history = SavedAssociationUndoHistory()
    let manager = UndoManager()
    manager.groupsByEvent = false
    defer { history.clear() }
    let ordinaryEdit = OrdinaryEdit()
    manager.beginUndoGrouping()
    manager.registerUndo(withTarget: ordinaryEdit) { $0.value = "Original" }
    manager.setActionName("Edit Title")
    manager.endUndoGrouping()
    let removal = try await fixture.remove(at: 0, history: history, manager: manager)
    history.record(removal, name: "Duplicate", store: fixture.store, manager: manager)
    XCTAssertEqual(manager.undoActionName, "Remove Museum")
    XCTAssertEqual(history.actionTitle, "Undo Remove Museum")
    history.undo()
    try await waitForRestoration(history)
    XCTAssertNil(history.actionTitle)
    XCTAssertEqual(manager.undoActionName, "Edit Title")
    XCTAssertFalse(manager.canRedo)
    let restored = try await fixture.memberships()
    XCTAssertEqual(Set(restored.map(\.id)), Set(fixture.membershipIdentifiers))
    manager.undo()
    XCTAssertEqual(ordinaryEdit.value, "Original")
    let afterOrdinaryUndo = try await fixture.memberships()
    XCTAssertEqual(afterOrdinaryUndo, restored)
  }

  private func waitForRestoration(_ history: SavedAssociationUndoHistory) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while history.isRestoring, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertFalse(history.isRestoring, "Association restoration must finish within the bound.")
  }

  private final class OrdinaryEdit {
    var value = "Changed"
  }

  @MainActor
  private struct Fixture {
    let directory: URL
    let configuration: PlannerStorageConfiguration
    let planner: PlannerCore.Planner
    let session: PlannerDatasetSession
    let store: SavedPlannerStore
    let list: PlannerEntityReference
    let items: [PlannerEntityReference]
    let membershipIdentifiers: [UUID]

    init() async throws {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlannerAssociationHistoryFixtures")
        .appendingPathComponent(UUID().uuidString)
      self.directory = directory
      let configuration = PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      self.configuration = configuration
      let planner = PlannerCore.Planner(configuration: configuration)
      self.planner = planner
      guard case .ready(let ready) = await planner.bootstrap() else {
        throw CancellationError()
      }
      session = ready
      func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
        let response = await planner.execute(
          .init(operationId: UUID(), session: ready, command: command))
        guard case .applied(let result, .complete) = response.outcome else {
          XCTFail("Fixture save must complete: \(response.outcome)")
          throw CancellationError()
        }
        return result
      }
      let listCreation = try await save(.createList(content: .init(name: "Activities")))
      let list = try XCTUnwrap(listCreation.generated.first)
      self.list = list
      var createdItems: [PlannerEntityReference] = []
      var createdMemberships: [UUID] = []
      for title in ["Museum", "Lunch"] {
        let itemCreation = try await save(.createItem(content: .init(title: title)))
        let item = try XCTUnwrap(itemCreation.generated.first)
        let membership = try await save(
          .addMembership(itemId: item.id, listId: list.id, placement: .last))
        guard case .membership(let identifier, _, _)? = membership.generatedReferences.first else {
          throw CancellationError()
        }
        _ = try await save(
          .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: identifier)),
            done: true))
        createdItems.append(item)
        createdMemberships.append(identifier)
      }
      items = createdItems
      membershipIdentifiers = createdMemberships
      let store = SavedPlannerStore(configuration: configuration)
      self.store = store
      await store.open()
      XCTAssertTrue(store.canCreate)
      XCTAssertEqual(store.currentDatasetIdentifier, ready.datasetId)
    }

    @discardableResult
    func remove(at index: Int, history: SavedAssociationUndoHistory, manager: UndoManager)
      async throws -> PlannerOperationResult
    {
      let response = await store.removeMembership(
        membershipIdentifiers[index], listIdentifier: list.id)
      let result = try XCTUnwrap(response)
      guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
      XCTAssertNotNil(result.associationUndoSnapshot)
      manager.beginUndoGrouping()
      history.record(
        result, name: index == 0 ? "Remove Museum" : "Remove Lunch", store: store,
        manager: manager)
      manager.endUndoGrouping()
      return result
    }

    func memberships() async throws -> [PlannerPortableMembership] {
      let data = try await backupData()
      guard case .decoded(let decoded) = planner.decodeImport(data)
      else { throw CancellationError() }
      return decoded.backup.memberships
    }

    func backupData() async throws -> Data {
      guard case .exported(let data) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      return data
    }
  }
}
