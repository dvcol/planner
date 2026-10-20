import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerListIntentTests: XCTestCase {
  func testAppliedAddWithIncompleteRecoveryRetainsItsMembershipAndBlocksAnotherDestination()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    let item = try await creation.callAsFunction(donate: false)
    var listCreation = CreatePlannerListIntent()
    listCreation.name = "Destination"
    let destination = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "Other"
    let other = try await listCreation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    var adding = AddPlannerItemToListIntent()
    adding.item = item
    adding.list = destination
    let _: Void = try await adding.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    adding.list = other
    do {
      let _: Void = try await adding.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block Add into another destination.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.list(let applied)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: destination.id))),
      case .source(.list(let untouched)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: other.id))),
      case .membership(_, let listSource, let itemSource)? = applied.references.first
    else { return XCTFail("The applied membership must survive incomplete recovery.") }
    XCTAssertEqual(listSource, .init(kind: .list, id: destination.id))
    XCTAssertEqual(itemSource, .init(kind: .item, id: item.id))
    XCTAssertEqual(applied.references.count, 1)
    XCTAssertTrue(untouched.references.isEmpty)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.list(let recovered)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: destination.id)))
    else { return XCTFail("Native retry must complete the original Add operation.") }
    XCTAssertEqual(recovered.references, applied.references)
    let _: Void = try await adding.callAsFunction(donate: false)
    guard
      case .source(.list(let finalOther)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: other.id))),
      case .snapshot(let items) = await reopened.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("An explicit second-destination Add must work after recovery retry.") }
    XCTAssertEqual(finalOther.references.count, 1)
    XCTAssertEqual(items.rows, [.source(.init(kind: .item, id: item.id))])
    XCTAssertFalse(store.isSaving)
  }

  func testDeletedAndMissingListOrItemIdentitiesCannotBeReadOrAddedBackImplicitly() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    let item = try await creation.callAsFunction(donate: false)
    var listCreation = CreatePlannerListIntent()
    listCreation.name = "Deleted destination"
    let deletedList = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "Surviving destination"
    let survivor = try await listCreation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func delete(_ source: PlannerEntityReference) async throws {
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .deleteSource(source: source)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: .deleteSource(source: source),
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    func requireRejected(item: PlannerItemEntity, list: PlannerListEntity) async {
      var adding = AddPlannerItemToListIntent()
      adding.item = item
      adding.list = list
      do {
        let _: Void = try await adding.callAsFunction(donate: false)
        XCTFail("Add Item must reject unavailable identities without recreating their sources.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    try await delete(.init(kind: .list, id: deletedList.id))
    let query = PlannerListEntityQuery()
    query.plannerStore = store
    let absent = try await query.entities(for: [deletedList.id])
    XCTAssertTrue(absent.isEmpty)
    var reading = GetPlannerListIntent()
    reading.list = deletedList
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("A cached deleted List cannot become a successful Get result.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
    await requireRejected(item: item, list: deletedList)
    await requireRejected(item: item, list: .init(id: UUID(), name: "Missing", archived: false))
    await requireRejected(
      item: .init(id: UUID(), title: "Missing", done: false, archived: false), list: survivor)
    try await delete(.init(kind: .item, id: item.id))
    await requireRejected(item: item, list: survivor)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let lists) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .list, archive: .all)))),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all)))),
      case .source(.list(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .list, id: survivor.id)))
    else { return XCTFail("Rejected operations must leave the surviving dataset readable.") }
    XCTAssertEqual(lists.rows, [.source(.init(kind: .list, id: survivor.id))])
    XCTAssertTrue(items.rows.isEmpty)
    XCTAssertTrue(retained.references.isEmpty)
    XCTAssertEqual(retained.content.name, "Surviving destination")
    XCTAssertEqual(retained.progress.state, .empty)
    XCTAssertFalse(store.recoveryBlocked)
  }

  func testInvalidAndPrecancelledListCreationLeaveNoSavedLists() async throws {
    let (directory, _, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "   "
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("A blank List name cannot acknowledge creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    creation.name = "Cancelled before invocation"
    let request = Task { try await creation.callAsFunction(donate: false) }
    request.cancel()
    do {
      _ = try await request.value
      XCTFail("A cancelled invocation must not start a List creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let query = PlannerListEntityQuery()
    query.plannerStore = store
    let choices = try await query.suggestedEntities()
    XCTAssertTrue(choices.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testRepeatedAddIntentKeepsAnExistingNonlastMembershipOrderAndLocalCompletion() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    let museum = try await creation.callAsFunction(donate: false)
    creation.title = "Lunch"
    let lunch = try await creation.callAsFunction(donate: false)
    var listCreation = CreatePlannerListIntent()
    listCreation.name = "Route"
    let list = try await listCreation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var references: [PlannerReferenceRead] = []
    for item in [museum, lunch] {
      guard
        case .applied(let added, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome, let reference = added.generatedReferences.first
      else { return XCTFail("Both existing relationships must save in the fixture's route order.") }
      references.append(reference)
    }
    guard case .membership(let museumIdentifier, _, _) = references[0],
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: museumIdentifier)),
            done: true))
      ).outcome
    else { return XCTFail("The first relationship must have its own local Done state.") }
    var adding = AddPlannerItemToListIntent()
    adding.item = museum
    adding.list = list
    let _: Void = try await adding.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let current)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .list, id: list.id))),
      case .appearance(let retained) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: museumIdentifier)))
    else { return XCTFail("Repeated Add must preserve the original ordered relationships.") }
    XCTAssertEqual(current.references, references)
    XCTAssertEqual(current.progress.totalCount, 2)
    XCTAssertEqual(current.progress.doneCount, 1)
    XCTAssertFalse(retained.globalDone)
    XCTAssertTrue(retained.localDone)
    XCTAssertTrue(retained.effectiveDone)
  }

  func testAppliedListCreationWithIncompleteRecoveryRetainsItsIdentityAndBlocksAnotherCreation()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
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
    var creation = CreatePlannerListIntent()
    creation.name = "Recovery food"
    creation.notes = "Keep the applied List"
    let applied = try await creation.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    let query = PlannerListEntityQuery()
    query.plannerStore = store
    let readable = try await query.suggestedEntities()
    XCTAssertEqual(readable.map(\.id), [applied.id])
    creation.name = "Blocked List"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block another creation rather than duplicate the List.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.list(let retained)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: applied.id)))
    else { return XCTFail("The returned List must remain saved despite incomplete recovery.") }
    XCTAssertEqual(retained.content.name, "Recovery food")
    XCTAssertEqual(retained.content.notes, "Keep the applied List")
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete(let recovered, _) = await reopened.operationStatus(
        session: session, operationId: operationIdentifier)
    else { return XCTFail("Native retry must acknowledge the original creation operation.") }
    XCTAssertEqual(recovered.generated, [.init(kind: .list, id: applied.id)])
    let afterRecovery = try await query.suggestedEntities()
    XCTAssertEqual(afterRecovery.map(\.id), [applied.id])
    creation.name = "Allowed List"
    let next = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(next.id, applied.id)
    let finalChoices = try await query.suggestedEntities()
    XCTAssertEqual(finalChoices.map(\.id), [next.id, applied.id])
    XCTAssertFalse(store.isSaving)
  }

  func testAddItemIntentCreatesALiveReferenceAndPreservesIndependentCompletionOnRepeatedAdd()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.notes = "Shared museum notes"
    let item = try await creation.callAsFunction(donate: false)
    var listCreation = CreatePlannerListIntent()
    listCreation.name = "Original List"
    let originalList = try await listCreation.callAsFunction(donate: false)
    listCreation.name = "Destination List"
    let destination = try await listCreation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let originalAdd = try await save(
      .addMembership(itemId: item.id, listId: originalList.id, placement: .last))
    guard case .membership(let originalIdentifier, _, _)? = originalAdd.generatedReferences.first
    else {
      return XCTFail("The existing List relationship must retain its own identity.")
    }
    let originalAppearance = PlannerAppearance.listMembership(
      listId: originalList.id, membershipId: originalIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(originalAppearance), done: true))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    var adding = AddPlannerItemToListIntent()
    adding.item = item
    adding.list = .init(id: destination.id, name: "Obsolete cached name", archived: true)
    let _: Void = try await adding.callAsFunction(donate: false)
    guard
      case .source(.list(let savedDestination)) = await planner.read(
        session: session, request: .source(.init(kind: .list, id: destination.id))),
      case .membership(let destinationIdentifier, let destinationSource, let itemSource)? =
        savedDestination.references.first
    else {
      return XCTFail("Add Item must create a reference to the same source in the chosen List.")
    }
    XCTAssertEqual(destinationSource, .init(kind: .list, id: destination.id))
    XCTAssertEqual(itemSource, .init(kind: .item, id: item.id))
    XCTAssertEqual(savedDestination.references.count, 1)
    let destinationAppearance = PlannerAppearance.listMembership(
      listId: destination.id, membershipId: destinationIdentifier)
    guard
      case .appearance(let inherited) = await planner.read(
        session: session, request: .appearance(destinationAppearance))
    else { return XCTFail("The new membership must expose its independent local completion.") }
    XCTAssertTrue(inherited.globalDone)
    XCTAssertFalse(inherited.localDone)
    XCTAssertTrue(inherited.effectiveDone)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: false))
    guard
      case .appearance(let reopenedDestination) = await planner.read(
        session: session, request: .appearance(destinationAppearance)),
      case .appearance(let retainedOriginal) = await planner.read(
        session: session, request: .appearance(originalAppearance))
    else { return XCTFail("Globally reopening must retain both independent memberships.") }
    XCTAssertFalse(reopenedDestination.effectiveDone)
    XCTAssertTrue(retainedOriginal.localDone)
    XCTAssertTrue(retainedOriginal.effectiveDone)
    _ = try await save(.setCompletion(scope: .appearance(destinationAppearance), done: true))
    let _: Void = try await adding.callAsFunction(donate: false)
    var editing = EditPlannerItemIntent()
    editing.item = item
    editing.notes = "Updated shared notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let finalDestination)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .list, id: destination.id))),
      case .snapshot(let allItems) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("The repeated Add and source edit must survive reopening.") }
    XCTAssertEqual(finalDestination.references, savedDestination.references)
    XCTAssertEqual(allItems.rows, [.source(.init(kind: .item, id: item.id))])
    for appearance in [originalAppearance, destinationAppearance] {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else { return XCTFail("Repeated Add must preserve both original relationship identities.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertTrue(current.localDone)
      XCTAssertTrue(current.effectiveDone)
      XCTAssertEqual(current.content.notes, "Updated shared notes")
    }
  }

  func testUnavailableStorageThrowsForListChoicesIdentityAndCreation() async throws {
    let (directory, _, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data("The store parent is a file.".utf8).write(to: directory.appending(path: "store"))
    AppDependencyManager.shared.add(dependency: store)
    let query = PlannerListEntityQuery()
    query.plannerStore = store
    func requireUnavailable(_ request: () async throws -> [PlannerListEntity]) async {
      do {
        _ = try await request()
        XCTFail("Unavailable storage must not become an empty successful List result.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    await requireUnavailable { try await query.suggestedEntities() }
    await requireUnavailable { try await query.entities(matching: "Food") }
    await requireUnavailable { try await query.entities(for: [UUID()]) }
    var creation = CreatePlannerListIntent()
    creation.name = "Cannot save here"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a new List.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
  }

  func testGetListIntentReturnsLiveValuesAndRejectsMissingIdentity() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "Original food"
    let cached = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .list, id: cached.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: cached.id, changes: .init(name: .set("Renamed food")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else { return XCTFail("The real List must change before resolving its cached Intent entity.") }
    var reading = GetPlannerListIntent()
    reading.list = cached
    let current = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(current.id, cached.id)
    XCTAssertEqual(current.name, "Renamed food")
    XCTAssertFalse(current.archived)
    reading.list = .init(id: UUID(), name: "Missing", archived: false)
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Get List must reject a missing identity instead of inventing an entity.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
  }

  func testListChoicesPreserveCanonicalSearchOrderArchivedSourcesAndEveryPage() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var identifiers: [UUID] = []
    for index in 0..<65 {
      guard
        case .applied(let created, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: String(format: "Plan %02d", index))))
        ).outcome, let source = created.generated.first
      else { return XCTFail("Every real List must save before querying its choices.") }
      identifiers.append(source.id)
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: .init(kind: .list, id: identifiers[0]), archived: true))
      ).outcome
    else { return XCTFail("The archived List must remain available by identity.") }
    let query = PlannerListEntityQuery()
    query.plannerStore = store
    let matches = try await query.entities(matching: "PLAN")
    XCTAssertEqual(matches.map(\.id), identifiers)
    XCTAssertEqual(matches.first?.name, "Plan 00")
    XCTAssertEqual(matches.first?.archived, true)
    XCTAssertEqual(matches.last?.name, "Plan 64")
    XCTAssertEqual(Set(matches.map(\.id)).count, 65)
    let suggestions = try await query.suggestedEntities()
    XCTAssertEqual(suggestions.map(\.id), identifiers)
    let missing = try await query.entities(matching: "No such plan")
    XCTAssertTrue(missing.isEmpty)
    let requested = try await query.entities(for: [
      identifiers[64], identifiers[0], identifiers[64],
    ])
    XCTAssertEqual(requested.map(\.id), [identifiers[64], identifiers[0]])
  }

  func testListEntityResolutionUsesCurrentNameAndArchiveWithoutInventingMissingIdentities()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "Tokyo Food"
    let cached = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .list, id: cached.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: cached.id, changes: .init(name: .set("Revised Tokyo Food")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: source, archived: true))
      ).outcome
    else { return XCTFail("Real Core edits must precede resolution of a cached List identity.") }
    let query = PlannerListEntityQuery()
    query.plannerStore = store
    let choices = try await query.entities(for: [cached.id, cached.id, UUID()])
    XCTAssertEqual(choices.map(\.id), [cached.id])
    XCTAssertEqual(choices.first?.name, "Revised Tokyo Food")
    XCTAssertEqual(choices.first?.archived, true)
    XCTAssertFalse(store.recoveryBlocked)
  }

  func testCreateListIntentReturnsTheSavedIdentityAndPreservesItsContentAfterReopen() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerListIntent()
    creation.name = "Tokyo Food"
    creation.notes = "Keep these places together"
    let list = try await creation.callAsFunction(donate: false)
    XCTAssertEqual(list.name, "Tokyo Food")
    XCTAssertFalse(list.archived)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.list(let current)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id))),
      case .snapshot(let catalog) = await reopened.query(
        .init(session: session, request: .catalog(.init(sourceKind: .list, archive: .all))))
    else { return XCTFail("The returned List must remain readable from reopened real storage.") }
    XCTAssertEqual(current.source.id, list.id)
    XCTAssertEqual(current.content.name, "Tokyo Food")
    XCTAssertEqual(current.content.notes, "Keep these places together")
    XCTAssertEqual(current.state.archived, false)
    XCTAssertEqual(current.progress.state, .empty)
    XCTAssertEqual(current.progress.totalCount, 0)
    XCTAssertTrue(current.references.isEmpty)
    XCTAssertEqual(catalog.rows, [.source(.init(kind: .list, id: list.id))])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  private func makeStorage() throws -> (
    directory: URL, configuration: PlannerStorageConfiguration, store: SavedPlannerStore
  ) {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "PlannerListIntentTests/\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    return (directory, configuration, SavedPlannerStore(configuration: configuration))
  }
}
