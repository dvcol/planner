import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerListEditingIntentTests: XCTestCase {
  func testUnavailableStorageRejectsListEditingAndArchiveWithoutAcknowledgingAChange() async throws
  {
    let (directory, _, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let list = PlannerListEntity(id: UUID(), name: "Unavailable", archived: false)
    var editing = EditPlannerListIntent()
    editing.list = list
    editing.name = "Cannot save here"
    do {
      let _: Void = try await editing.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a List edit.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    var archiving = SetPlannerListArchiveIntent()
    archiving.list = list
    archiving.archived = true
    do {
      let _: Void = try await archiving.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a List archive.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testAppliedListArchiveWithIncompleteRecoveryBlocksUnarchiveUntilNativeRetry() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "Recovery List"
    creation.notes = "Keep this empty List"
    let list = try await creation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    var archiving = SetPlannerListArchiveIntent()
    archiving.list = list
    archiving.archived = true
    let _: Void = try await archiving.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    archiving.archived = false
    do {
      let _: Void = try await archiving.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block Unarchive without reverting the applied archive.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.list(let applied)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("The applied List archive must remain readable after reopening.") }
    XCTAssertEqual(applied.state.archived, true)
    XCTAssertEqual(applied.content.name, "Recovery List")
    XCTAssertEqual(applied.content.notes, "Keep this empty List")
    XCTAssertEqual(applied.progress.state, .empty)
    XCTAssertTrue(applied.references.isEmpty)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.list(let recovered)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("Native retry must complete the original List archive operation.") }
    XCTAssertEqual(recovered.state.archived, true)
    XCTAssertEqual(recovered.content, applied.content)
    let _: Void = try await archiving.callAsFunction(donate: false)
    guard
      case .source(.list(let unarchived)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("An explicit Unarchive must succeed after native recovery retry.") }
    XCTAssertEqual(unarchived.state.archived, false)
    XCTAssertEqual(unarchived.progress.state, .empty)
    XCTAssertEqual(unarchived.content, applied.content)
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedListEditWithIncompleteRecoveryRetainsContentAndBlocksTheNextEdit() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "Original List"
    creation.notes = "Original notes"
    let list = try await creation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    var editing = EditPlannerListIntent()
    editing.list = list
    editing.name = "Updated List"
    editing.notes = "Reviewed notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    editing.notes = "Blocked later edit"
    do {
      let _: Void = try await editing.callAsFunction(donate: false)
      XCTFail("An applied edit with incomplete recovery must block a later edit.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.list(let applied)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("The actual List edit must remain saved after reopening.") }
    XCTAssertEqual(applied.content.name, "Updated List")
    XCTAssertEqual(applied.content.notes, "Reviewed notes")
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.list(let recovered)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("Native retry must acknowledge the original List edit operation.") }
    XCTAssertEqual(recovered.fieldHashes, applied.fieldHashes)
    editing.notes = "Allowed after recovery"
    let _: Void = try await editing.callAsFunction(donate: false)
    guard
      case .source(.list(let final)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("An explicit later List edit must succeed after native recovery.") }
    XCTAssertEqual(final.source.id, list.id)
    XCTAssertEqual(final.content.name, "Updated List")
    XCTAssertEqual(final.content.notes, "Allowed after recovery")
    XCTAssertFalse(store.isSaving)
  }

  func testInvalidListEditsAndMissingOrDeletedTargetsLeaveNoPartialOrResurrectedData() async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "Original List"
    creation.notes = "Keep the original notes"
    let list = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .list, id: list.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(source))
    else { return XCTFail("The original List must be readable before rejected edits.") }
    for (name, notes) in [(nil, nil), ("   ", "Must not apply")] as [(String?, String?)] {
      var editing = EditPlannerListIntent()
      editing.list = list
      editing.name = name
      editing.notes = notes
      do {
        let _: Void = try await editing.callAsFunction(donate: false)
        XCTFail("An empty patch or blank required name cannot acknowledge a List edit.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    guard
      case .source(.list(let unchanged)) = await planner.read(
        session: session, request: .source(source)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: source),
          reviewToken: review.reviewToken)
      ).outcome
    else {
      return XCTFail("Native reviewed deletion must follow the unchanged rejected-edit state.")
    }
    XCTAssertEqual(unchanged.content, before.content)
    XCTAssertEqual(unchanged.fieldHashes, before.fieldHashes)
    XCTAssertEqual(unchanged.updatedAt, before.updatedAt)
    for target in [list, PlannerListEntity(id: UUID(), name: "Missing", archived: false)] {
      var editing = EditPlannerListIntent()
      editing.list = target
      editing.name = "Cannot recreate this List"
      do {
        let _: Void = try await editing.callAsFunction(donate: false)
        XCTFail("Editing cannot recreate a deleted or missing List.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
      for archived in [true, false] {
        var archiving = SetPlannerListArchiveIntent()
        archiving.list = target
        archiving.archived = archived
        do {
          let _: Void = try await archiving.callAsFunction(donate: false)
          XCTFail("Archive cannot recreate a deleted or missing List.")
        } catch {
          XCTAssertFalse(error.localizedDescription.isEmpty)
        }
      }
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .list, archive: .all))))
    else { return XCTFail("Rejected missing-identity mutations must leave readable storage.") }
    XCTAssertTrue(catalog.rows.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testListArchiveRetiresOnlyItsItineraryBranchAndRestoresIndependentStatesOnUnarchive()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let createdItem = try await save(
      .createItem(
        content: .init(
          title: "Museum", notes: "Shared museum notes",
          estimate: .init(minutes: 60, displayUnit: .hour))))
    let item = try XCTUnwrap(createdItem.generated.first)
    let createdList = try await save(.createList(content: .init(name: "Tokyo Food")))
    let list = try XCTUnwrap(createdList.generated.first)
    let added = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first else {
      return XCTFail("The List must retain its original membership identity.")
    }
    let standalone = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(standalone), done: true))
    let createdItinerary = try await save(
      .createItinerary(content: .init(title: "Tokyo Weekend")))
    let itinerary = try XCTUnwrap(createdItinerary.generated.first)
    let listEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let directEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard
      case .itineraryEntry(let listEntryIdentifier, _, _)? = listEntry.generatedReferences.first,
      case .itineraryEntry(let directEntryIdentifier, _, _)? = directEntry.generatedReferences.first,
      case .source(.list(let beforeList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let beforePlan)) = await planner.read(
        session: session, request: .source(itinerary))
    else { return XCTFail("The original live itinerary references must be readable.") }
    XCTAssertEqual(beforePlan.progress.doneCount, 0)
    XCTAssertEqual(beforePlan.progress.archivedCount, 0)
    XCTAssertEqual(beforePlan.progress.totalCount, 2)
    XCTAssertEqual(beforePlan.estimates.fullEstimate, .exact(minutes: 120))
    XCTAssertEqual(beforePlan.estimates.remainingEstimate, .exact(minutes: 120))
    let branch = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: listEntryIdentifier,
      membershipId: membershipIdentifier)
    let direct = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: directEntryIdentifier)
    var archiving = SetPlannerListArchiveIntent()
    archiving.list = .init(id: list.id, name: "Stale name", archived: true)
    for archived in [true, false] {
      archiving.archived = archived
      let _: Void = try await archiving.callAsFunction(donate: false)
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.list(let currentList)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .source(.itinerary(let currentPlan)) = await reopened.read(
          session: reopenedSession, request: .source(itinerary)),
        case .source(.item(let currentItem)) = await reopened.read(
          session: reopenedSession, request: .source(item)),
        case .appearance(let originalState) = await reopened.read(
          session: reopenedSession, request: .appearance(standalone))
      else { return XCTFail("Archive changes must preserve every source and original reference.") }
      XCTAssertEqual(currentList.state.archived, archived)
      XCTAssertEqual(currentList.references, beforeList.references)
      XCTAssertEqual(currentList.content, beforeList.content)
      XCTAssertEqual(currentPlan.references, beforePlan.references)
      XCTAssertEqual(currentPlan.progress.doneCount, 0)
      XCTAssertEqual(currentPlan.progress.archivedCount, archived ? 1 : 0)
      XCTAssertEqual(currentPlan.progress.totalCount, 2)
      XCTAssertEqual(currentPlan.progress.state, .partial)
      XCTAssertEqual(currentPlan.estimates.fullEstimate, .exact(minutes: 120))
      XCTAssertEqual(
        currentPlan.estimates.remainingEstimate, .exact(minutes: archived ? 60 : 120))
      XCTAssertEqual(currentItem.content.notes, "Shared museum notes")
      XCTAssertEqual(currentItem.state.globalDone, false)
      XCTAssertEqual(currentItem.state.archived, false)
      XCTAssertFalse(originalState.globalDone)
      XCTAssertTrue(originalState.localDone)
      for appearance in [branch, direct] {
        guard
          case .appearance(let current) = await reopened.read(
            session: reopenedSession, request: .appearance(appearance))
        else { return XCTFail("Both itinerary appearances must retain their original identities.") }
        XCTAssertFalse(current.globalDone)
        XCTAssertFalse(current.localDone)
        XCTAssertFalse(current.effectiveDone)
      }
    }
  }

  func testListPartialEditsKeepOmittedFieldsAndExplicitlyClearNotes() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "Original List"
    creation.notes = "Keep the notes"
    let list = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var editing = EditPlannerListIntent()
    editing.list = list
    editing.name = "Renamed List"
    let _: Void = try await editing.callAsFunction(donate: false)
    guard
      case .source(.list(let renamed)) = await planner.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("The same List must remain readable after a name-only edit.") }
    XCTAssertEqual(renamed.content.name, "Renamed List")
    XCTAssertEqual(renamed.content.notes, "Keep the notes")
    editing.name = nil
    editing.notes = "Updated notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    guard
      case .source(.list(let updated)) = await planner.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("A notes-only edit must retain the live renamed List.") }
    XCTAssertEqual(updated.content.name, "Renamed List")
    XCTAssertEqual(updated.content.notes, "Updated notes")
    editing.notes = ""
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let cleared)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("The renamed List must survive explicit notes clearing and reopening.") }
    XCTAssertEqual(cleared.source.id, list.id)
    XCTAssertEqual(cleared.content.name, "Renamed List")
    XCTAssertNil(cleared.content.notes)
  }

  func testListEditPreservesIdentityMetadataArchiveAndMembershipCompletionAfterReopen()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let color = PlannerColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1)
    let estimate = PlannerEstimate(minutes: 210, displayUnit: .hour)
    let createdList = try await save(
      .createList(
        content: .init(
          name: "Tokyo Food", notes: "Original List notes", color: color,
          iconName: "fork.knife", manualEstimate: estimate)))
    let list = try XCTUnwrap(createdList.generated.first)
    let createdItem = try await save(
      .createItem(content: .init(title: "Museum", notes: "Museum notes")))
    let item = try XCTUnwrap(createdItem.generated.first)
    let added = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .membership(let identifier, _, _)? = added.generatedReferences.first else {
      return XCTFail("The fixture must retain the original membership identity.")
    }
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: identifier)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    _ = try await save(.setArchive(source: list, archived: true))
    guard
      case .source(.list(let before)) = await planner.read(
        session: session, request: .source(list))
    else { return XCTFail("The rich archived List must be readable before its edit.") }
    var editing = EditPlannerListIntent()
    editing.list = .init(id: list.id, name: "Obsolete cached name", archived: false)
    editing.name = "Reviewed Tokyo Food"
    editing.notes = "Reviewed List notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let after)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let retained) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance))
    else { return XCTFail("The same List and membership must survive editing and reopening.") }
    XCTAssertEqual(after.source, list)
    XCTAssertEqual(after.content.name, "Reviewed Tokyo Food")
    XCTAssertEqual(after.content.notes, "Reviewed List notes")
    XCTAssertEqual(after.content.color, color)
    XCTAssertEqual(after.content.iconName, "fork.knife")
    XCTAssertEqual(after.content.manualEstimate, estimate)
    XCTAssertEqual(after.state.archived, true)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.progress.doneCount, before.progress.doneCount)
    XCTAssertEqual(after.estimates, before.estimates)
    XCTAssertEqual(retained.content.title, "Museum")
    XCTAssertEqual(retained.content.notes, "Museum notes")
    XCTAssertFalse(retained.globalDone)
    XCTAssertTrue(retained.localDone)
    XCTAssertTrue(retained.effectiveDone)
  }

  private func makeStorage() throws -> (
    directory: URL, configuration: PlannerStorageConfiguration, store: SavedPlannerStore
  ) {
    let directory = FileManager.default.temporaryDirectory
      .appending(
        path: "PlannerListEditingIntentTests/\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    return (directory, configuration, SavedPlannerStore(configuration: configuration))
  }
}
