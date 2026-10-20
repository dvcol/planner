import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItemIntentTests: XCTestCase {
  func testAppliedEditWithIncompleteRecoveryRetainsItsContentAndBlocksTheNextEdit()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Recovery museum"
    creation.notes = "Original notes"
    let item = try await creation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let editing = EditPlannerItemIntent()
    editing.item = item
    editing.title = "Updated museum"
    editing.notes = "Reviewed notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    editing.notes = "Blocked later edit"
    do {
      let _: Void = try await editing.callAsFunction(donate: false)
      XCTFail("The next edit must wait for the original edit's recovery copy.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let applied)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("The applied edit must survive reopening despite incomplete recovery.") }
    XCTAssertEqual(applied.content.title, "Updated museum")
    XCTAssertEqual(applied.content.notes, "Reviewed notes")
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.item(let recovered)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("Native recovery retry must acknowledge the original edit.") }
    XCTAssertEqual(recovered.fieldHashes, applied.fieldHashes)
    editing.notes = "Allowed after recovery"
    let _: Void = try await editing.callAsFunction(donate: false)
    guard
      case .source(.item(let final)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("An explicit later edit must succeed after native recovery.") }
    XCTAssertEqual(final.source.id, item.id)
    XCTAssertEqual(final.content.title, "Updated museum")
    XCTAssertEqual(final.content.notes, "Allowed after recovery")
    XCTAssertFalse(store.isSaving)
  }

  func testEditIntentRejectsInvalidRequestsAndMissingOrDeletedItemsWithoutPartialChanges()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Original museum"
    creation.notes = "Keep the original notes"
    let item = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .item, id: item.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(source))
    else { return XCTFail("The original Item must be readable before invalid requests.") }
    for (title, notes) in [(nil, nil), ("   ", "Must not apply")] as [(String?, String?)] {
      let editing = EditPlannerItemIntent()
      editing.item = item
      editing.title = title
      editing.notes = notes
      do {
        let _: Void = try await editing.callAsFunction(donate: false)
        XCTFail("Empty requests and invalid titles cannot acknowledge an edit.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    guard
      case .source(.item(let unchanged)) = await planner.read(
        session: session, request: .source(source))
    else { return XCTFail("Rejected edits must preserve the original Item.") }
    XCTAssertEqual(unchanged.content.title, "Original museum")
    XCTAssertEqual(unchanged.content.notes, "Keep the original notes")
    XCTAssertEqual(unchanged.fieldHashes, before.fieldHashes)
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: source),
          reviewToken: review.reviewToken)
      ).outcome
    else { return XCTFail("Native confirmed deletion must remove the original Item.") }
    let missing = PlannerItemEntity(id: UUID(), title: "Missing", done: false, archived: false)
    for unavailable in [item, missing] {
      let editing = EditPlannerItemIntent()
      editing.item = unavailable
      editing.notes = "Cannot recreate this Item"
      do {
        let _: Void = try await editing.callAsFunction(donate: false)
        XCTFail("Editing must not resurrect a missing or deleted Item.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("Rejected missing-identity edits must leave readable storage.") }
    XCTAssertTrue(items.rows.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testEditIntentCanRenameAndExplicitlyClearNotesTogether() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Original museum"
    creation.notes = "Remove these notes"
    let item = try await creation.callAsFunction(donate: false)
    let editing = EditPlannerItemIntent()
    editing.item = item
    editing.title = "Renamed museum"
    editing.notes = ""
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let current)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("The combined edit must retain the original saved Item.") }
    XCTAssertEqual(current.source.id, item.id)
    XCTAssertEqual(current.content.title, "Renamed museum")
    XCTAssertNil(current.content.notes)
  }

  func testTitleOnlyEditIntentKeepsOmittedNotesAfterReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Original museum"
    creation.notes = "Keep these notes"
    let item = try await creation.callAsFunction(donate: false)
    let editing = EditPlannerItemIntent()
    editing.item = item
    editing.title = "Revised museum"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let current)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("A title-only edit must retain the original saved Item.") }
    XCTAssertEqual(current.source.id, item.id)
    XCTAssertEqual(current.content.title, "Revised museum")
    XCTAssertEqual(current.content.notes, "Keep these notes")
  }

  func testNotesEditIntentPreservesLiveContentIdentityAndIndependentCompletionAfterReopen()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      return XCTFail("The real dataset must be ready for the editing fixture.")
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let location = PlannerOwnedLocation(
      displayName: "Museum", formattedAddress: "6-5-1 Minamiaoyama, Tokyo",
      coordinate: .init(latitude: 35.6622, longitude: 139.7171))
    let created = try await save(
      .createItem(
        content: .init(
          title: "Live museum", subtitle: "Opening hours vary", notes: "Original notes",
          location: location, estimate: .init(minutes: 90, displayUnit: .hour),
          links: [.init(originalUrl: "https://example.com/museum", label: "Visit guide")])))
    let source = try XCTUnwrap(created.generated.first)
    var appearances: [PlannerAppearance] = []
    for name in ["Tokyo", "Wishlist"] {
      let listCreation = try await save(.createList(content: .init(name: name)))
      let list = try XCTUnwrap(listCreation.generated.first)
      let membership = try await save(
        .addMembership(itemId: source.id, listId: list.id, placement: .last))
      guard case .membership(let identifier, _, _)? = membership.generatedReferences.first else {
        return XCTFail("Each saved membership must retain its own identity.")
      }
      appearances.append(.listMembership(listId: list.id, membershipId: identifier))
    }
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: true))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: source.id), done: true))
    _ = try await save(.setArchive(source: source, archived: true))
    guard
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(source))
    else { return XCTFail("The rich Item must be readable before editing.") }
    let editing = EditPlannerItemIntent()
    editing.item = PlannerItemEntity(
      id: source.id, title: "Cached obsolete title", done: false, archived: false)
    editing.notes = "Friday booking"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let after)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else { return XCTFail("The original edited Item must survive reopening.") }
    XCTAssertEqual(after.source, source)
    XCTAssertEqual(after.content.title, "Live museum")
    XCTAssertEqual(after.content.subtitle, "Opening hours vary")
    XCTAssertEqual(after.content.notes, "Friday booking")
    XCTAssertEqual(after.content.location, location)
    XCTAssertEqual(after.content.estimate, .init(minutes: 90, displayUnit: .hour))
    XCTAssertEqual(after.content.links, before.content.links)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.state.globalDone, true)
    XCTAssertEqual(after.state.archived, true)
    for (index, appearance) in appearances.enumerated() {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else { return XCTFail("Editing must preserve both original appearances.") }
      XCTAssertEqual(current.content.notes, "Friday booking")
      XCTAssertTrue(current.globalDone)
      XCTAssertTrue(current.archived)
      XCTAssertEqual(current.localDone, index == 0)
      XCTAssertTrue(current.effectiveDone)
    }
  }

  func testAppliedArchiveWithIncompleteRecoveryBlocksUnarchiveUntilNativeRecoveryRetry()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Recovery museum"
    creation.notes = "Keep the locally archived Item"
    let item = try await creation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let archive = SetPlannerItemArchiveIntent()
    archive.item = item
    archive.archived = true
    let _: Void = try await archive.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    XCTAssertFalse(store.isSaving)
    archive.archived = false
    do {
      let _: Void = try await archive.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block a later unarchive action.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let applied)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("The locally applied archive must survive reopening.") }
    XCTAssertEqual(applied.source.id, item.id)
    XCTAssertEqual(applied.content.title, "Recovery museum")
    XCTAssertEqual(applied.content.notes, "Keep the locally archived Item")
    XCTAssertEqual(applied.state.archived, true)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.item(let recovered)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else {
      return XCTFail("Native recovery retry must acknowledge the original archive operation.")
    }
    XCTAssertEqual(recovered.state.archived, true)
    XCTAssertEqual(recovered.fieldHashes, applied.fieldHashes)
    let _: Void = try await archive.callAsFunction(donate: false)
    guard
      case .source(.item(let unarchived)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id))),
      case .snapshot(let items) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("An explicit unarchive must succeed after recovery is complete.") }
    XCTAssertEqual(unarchived.state.archived, false)
    XCTAssertEqual(items.rows, [.source(.init(kind: .item, id: item.id))])
  }

  func testArchiveIntentRejectsMissingAndDeletedItemsWithoutResurrectingTheirIdentities()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Deleted museum"
    let deletedItem = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let deletedSource = PlannerEntityReference(kind: .item, id: deletedItem.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: deletedSource)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: deletedSource),
          reviewToken: review.reviewToken)
      ).outcome
    else { return XCTFail("The native reviewed deletion must remove the original Item.") }
    let missingItem = PlannerItemEntity(
      id: UUID(), title: "Missing museum", done: false, archived: false)
    for item in [deletedItem, missingItem] {
      for archived in [true, false] {
        let archive = SetPlannerItemArchiveIntent()
        archive.item = item
        archive.archived = archived
        do {
          let _: Void = try await archive.callAsFunction(donate: false)
          XCTFail("Archive cannot acknowledge a missing or deleted Item.")
        } catch {
          XCTAssertFalse(error.localizedDescription.isEmpty)
        }
      }
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("The real dataset must remain readable after rejected archive actions.") }
    XCTAssertTrue(items.rows.isEmpty)
    for item in [deletedItem, missingItem] {
      guard
        case .failed(let reason) = await reopened.read(
          session: reopenedSession, request: .source(.init(kind: .item, id: item.id)))
      else { return XCTFail("Rejected archive actions cannot recreate either identity.") }
      XCTAssertEqual(reason.code, "missingReference")
    }
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testArchiveIntentRetainsItemIdentityContentAndIndependentListCompletionAfterReopen()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.notes = "Keep the shared notes"
    let item = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      return XCTFail("The Item's real dataset must be ready.")
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let operation = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = operation.outcome else {
        throw CancellationError()
      }
      return result
    }
    var appearances: [PlannerAppearance] = []
    for name in ["Tokyo", "Wishlist"] {
      let listCreation = try await save(.createList(content: .init(name: name)))
      let list = try XCTUnwrap(listCreation.generated.first)
      let membership = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last))
      guard case .membership(let identifier, _, _)? = membership.generatedReferences.first else {
        return XCTFail("Each saved membership must retain its own identity.")
      }
      appearances.append(.listMembership(listId: list.id, membershipId: identifier))
    }
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: true))
    let archive = SetPlannerItemArchiveIntent()
    archive.item = item
    for archived in [true, false] {
      archive.archived = archived
      let _: Void = try await archive.callAsFunction(donate: false)
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.item(let source)) = await reopened.read(
          session: reopenedSession, request: .source(.init(kind: .item, id: item.id)))
      else { return XCTFail("Archive must preserve the original source after reopening.") }
      XCTAssertEqual(source.source.id, item.id)
      XCTAssertEqual(source.content.title, "Museum")
      XCTAssertEqual(source.content.notes, "Keep the shared notes")
      XCTAssertEqual(source.state.archived, archived)
      XCTAssertEqual(source.state.globalDone, false)
      for (index, appearance) in appearances.enumerated() {
        guard
          case .appearance(let current) = await reopened.read(
            session: reopenedSession, request: .appearance(appearance))
        else { return XCTFail("Archive must preserve both original memberships.") }
        XCTAssertEqual(current.archived, archived)
        XCTAssertFalse(current.globalDone)
        XCTAssertEqual(current.localDone, index == 0)
        XCTAssertEqual(current.effectiveDone, index == 0)
      }
    }
  }

  func testCreationCancelledBeforeInvocationLeavesNoSavedItem() async throws {
    let fixture = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: fixture.store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Cancelled before invocation"
    let request = Task { try await creation.callAsFunction(donate: false) }
    request.cancel()
    do {
      _ = try await request.value
      XCTFail("A cancelled invocation must not begin a new mutation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.suggestedEntities()
    XCTAssertTrue(choices.isEmpty)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testInvalidCreationAndMissingItemReadFailWithoutCreatingData() async throws {
    let fixture = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: fixture.store)
    let creation = CreatePlannerItemIntent()
    creation.title = "   "
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("A blank title cannot produce a saved Item.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let suggestions = try await query.suggestedEntities()
    XCTAssertTrue(suggestions.isEmpty)
    let reading = GetPlannerItemIntent()
    reading.item = PlannerItemEntity(id: UUID(), title: "Missing", done: false, archived: false)
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("A cached entity cannot invent a missing Item.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testUnavailableStorageThrowsInsteadOfReturningEmptyChoicesOrClaimingCreation() async throws {
    let fixture = try makePlannerIntentStorage()
    try Data("The store parent is a file, not a directory.".utf8).write(
      to: fixture.directory.appending(path: "store"))
    AppDependencyManager.shared.add(dependency: fixture.store)
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    do {
      _ = try await query.suggestedEntities()
      XCTFail("Unavailable storage must not become an empty successful result.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let creation = CreatePlannerItemIntent()
    creation.title = "Cannot save here"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(fixture.store.isReady)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertNotNil(fixture.store.openingFailure)
  }

  func testEntityChoicesReadBeyondOnePageInCanonicalOrder() async throws {
    let fixture = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var identities: [UUID] = []
    for index in 0..<65 {
      guard
        case .applied(let saved, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: String(format: "Visit %02d", index))))
        )
        .outcome,
        let item = saved.generated.first(where: { $0.kind == .item })
      else { return XCTFail("Every real fixture Item must save successfully.") }
      identities.append(item.id)
    }
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(matching: "VISIT")
    XCTAssertEqual(choices.map(\.id), identities)
    XCTAssertEqual(choices.first?.title, "Visit 00")
    XCTAssertEqual(choices.last?.title, "Visit 64")
    XCTAssertEqual(Set(choices.map(\.id)).count, 65)
  }

  func testAppliedCreationWithIncompleteRecoveryReturnsItsItemAndBlocksFurtherIntentChanges()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    await store.open()
    XCTAssertTrue(store.isReady)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let creation = CreatePlannerItemIntent()
    creation.title = "Recovery museum"
    let applied = try await creation.callAsFunction(donate: false)
    XCTAssertEqual(applied.title, "Recovery museum")
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    XCTAssertFalse(store.isSaving)
    creation.title = "Must not be created"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("An incomplete recovery copy must block a later Intent mutation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("The locally applied Item must remain readable.") }
    XCTAssertEqual(snapshot.rows, [.source(.init(kind: .item, id: applied.id))])
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    creation.title = "Allowed after recovery retry"
    let next = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(next.id, applied.id)
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: applied.id)))
    else { return XCTFail("Recovery retry must not replace the original applied Item.") }
    XCTAssertEqual(original.content.title, "Recovery museum")
  }

  func testConcurrentCreateIntentsKeepBothRequestsAndAwaitTheSameStoreOpening() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let firstCreation = CreatePlannerItemIntent()
    firstCreation.title = "Train tickets"
    let secondCreation = CreatePlannerItemIntent()
    secondCreation.title = "Hotel check-in"
    func invoke(_ intent: CreatePlannerItemIntent) async -> Result<PlannerItemEntity, any Error> {
      do { return .success(try await intent.callAsFunction(donate: false)) } catch {
        return .failure(error)
      }
    }
    async let firstResult = invoke(firstCreation)
    async let secondResult = invoke(secondCreation)
    let (firstOutcome, secondOutcome) = await (firstResult, secondResult)
    let outcomes = XCTAttachment(
      string: "First: \(firstOutcome)\nSecond: \(secondOutcome)\nSaving: \(store.isSaving)")
    outcomes.name = "Both actual Intent requests finish before fixture cleanup"
    outcomes.lifetime = .keepAlways
    add(outcomes)
    let firstItem = try firstOutcome.get()
    let secondItem = try secondOutcome.get()
    XCTAssertEqual(firstItem.title, "Train tickets")
    XCTAssertEqual(secondItem.title, "Hotel check-in")
    XCTAssertNotEqual(firstItem.id, secondItem.id)
    XCTAssertTrue(store.isReady)
    XCTAssertFalse(store.isSaving)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("Both real operations must remain readable after reopening.") }
    XCTAssertEqual(
      snapshot.rows,
      [
        .source(.init(kind: .item, id: secondItem.id)),
        .source(.init(kind: .item, id: firstItem.id)),
      ])
  }

  func testGlobalCompletionIntentPreservesIndependentListFlagsWhenTheItemIsReopened()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.notes = "Keep the shared notes"
    let item = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      return XCTFail("The Item's current real dataset must be ready.")
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let operation = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = operation.outcome else {
        throw CancellationError()
      }
      return result
    }
    var appearances: [PlannerAppearance] = []
    for name in ["Tokyo", "Wishlist"] {
      let listCreation = try await save(.createList(content: .init(name: name)))
      let list = try XCTUnwrap(listCreation.generated.first)
      let membership = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last))
      guard case .membership(let membershipIdentifier, _, _)? = membership.generatedReferences.first
      else { return XCTFail("The original List association must have its own identity.") }
      appearances.append(.listMembership(listId: list.id, membershipId: membershipIdentifier))
    }
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: true))
    let completion = SetPlannerItemCompletionIntent()
    completion.item = item
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    for (index, appearance) in appearances.enumerated() {
      guard
        case .appearance(let current) = await planner.read(
          session: session, request: .appearance(appearance))
      else { return XCTFail("The original appearance must remain readable.") }
      XCTAssertTrue(current.globalDone)
      XCTAssertTrue(current.effectiveDone)
      XCTAssertEqual(current.localDone, index == 0)
      XCTAssertEqual(current.content.notes, "Keep the shared notes")
    }
    completion.done = false
    let _: Void = try await completion.callAsFunction(donate: false)
    for (index, appearance) in appearances.enumerated() {
      guard
        case .appearance(let current) = await planner.read(
          session: session, request: .appearance(appearance))
      else { return XCTFail("Reopening cannot remove either original association.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, index == 0)
      XCTAssertEqual(current.effectiveDone, index == 0)
      XCTAssertFalse(current.archived)
    }
  }

  func testEntityQueriesResolveCurrentValuesAndCanonicalSearchWithoutInventingMissingItems()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Train tickets"
    creation.notes = "Collect at the station"
    let cached = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: cached.id))),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: cached.id, changes: .init(title: .set("Revised tickets")),
            expectedFieldHashes: current.fieldHashes))
      )
      .outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: cached.id), done: true))
      )
      .outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: .init(kind: .item, id: cached.id), archived: true))
      )
      .outcome
    else { return XCTFail("Real Core edits must prepare the changed source.") }
    let query = PlannerItemEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(for: [cached.id, cached.id, UUID()])
    XCTAssertEqual(resolved.map(\.id), [cached.id])
    XCTAssertEqual(resolved.first?.title, "Revised tickets")
    XCTAssertEqual(resolved.first?.done, true)
    XCTAssertEqual(resolved.first?.archived, true)
    let matches = try await query.entities(matching: "STATION")
    XCTAssertEqual(matches.map(\.id), [cached.id])
    let missing = try await query.entities(matching: "No such visit")
    XCTAssertTrue(missing.isEmpty)
    let suggestions = try await query.suggestedEntities()
    XCTAssertEqual(suggestions.map(\.id), [cached.id])
    let reading = GetPlannerItemIntent()
    reading.item = cached
    let refreshed = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(refreshed.id, cached.id)
    XCTAssertEqual(refreshed.title, "Revised tickets")
    XCTAssertTrue(refreshed.done)
    XCTAssertTrue(refreshed.archived)
  }

  func testCreateIntentReturnsTheSingleSavedIdentityAndPreservesContentAndRecoveryAfterReopen()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let intent = CreatePlannerItemIntent()
    intent.title = "Train tickets"
    intent.notes = "Collect at the station"
    let created = try await intent.callAsFunction(donate: false)
    XCTAssertEqual(created.title, "Train tickets")
    XCTAssertFalse(created.done)
    XCTAssertFalse(created.archived)
    XCTAssertTrue(store.isReady)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let saved)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: created.id))),
      case .snapshot(let items) = await reopened.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .status(let status) = await reopened.read(session: session, request: .status)
    else { return XCTFail("The returned Item must be readable from reopened real storage.") }
    XCTAssertEqual(items.rows, [.source(saved.source)])
    XCTAssertEqual(saved.source.id, created.id)
    XCTAssertEqual(saved.content.title, "Train tickets")
    XCTAssertEqual(saved.content.notes, "Collect at the station")
    guard case .known(let checkpoint, let incomplete, let blocked) = status.recovery else {
      return XCTFail("The actual recovery status must remain available.")
    }
    XCTAssertNotNil(checkpoint)
    XCTAssertTrue(incomplete.isEmpty)
    XCTAssertFalse(blocked)
  }

}

final class IntentRecoverySaveObstruction: @unchecked Sendable {
  private let lock = NSLock()
  private let storeURL: URL
  private let recoveryURL: URL
  private let retainedURL: URL
  private var obstructed = false

  init(configuration: PlannerStorageConfiguration) {
    storeURL = configuration.storeURL.standardizedFileURL
    recoveryURL = configuration.recoveryDirectoryURL
    retainedURL = recoveryURL.deletingLastPathComponent()
      .appendingPathComponent("retained-after-native-save")
  }

  var didObstruct: Bool { lock.withLock { obstructed } }

  func observe(_ notification: Notification) {
    guard let context = notification.object as? ModelContext,
      context.container.configurations.contains(where: { $0.url.standardizedFileURL == storeURL })
    else { return }
    lock.withLock {
      guard !obstructed else { return }
      do {
        try FileManager.default.moveItem(at: recoveryURL, to: retainedURL)
        try Data("Obstruct recovery after native save.".utf8).write(to: recoveryURL)
        obstructed = true
      } catch { return }
    }
  }

  func restore() throws {
    guard FileManager.default.fileExists(atPath: retainedURL.path) else { return }
    if FileManager.default.fileExists(atPath: recoveryURL.path) {
      try FileManager.default.removeItem(at: recoveryURL)
    }
    try FileManager.default.moveItem(at: retainedURL, to: recoveryURL)
  }
}
