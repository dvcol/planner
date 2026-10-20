import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItineraryOrganizationIntentTests: XCTestCase {
  func testRepeatedItemAddsKeepLiveContentGlobalPrecedenceAndIndependentLocalStatesAfterReopen()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Hotel"
    creation.notes = "Original notes"
    let item = try await creation.callAsFunction(donate: false)
    let planCreation = CreatePlannerItineraryIntent()
    planCreation.title = "Tokyo Weekend"
    let itinerary = try await planCreation.callAsFunction(donate: false)
    let completion = SetPlannerItemCompletionIntent()
    completion.item = item
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    let adding = AddPlannerItemToItineraryIntent()
    adding.item = item
    adding.itinerary = itinerary
    let _: Void = try await adding.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let itinerarySource = PlannerEntityReference(kind: .itinerary, id: itinerary.id)
    let itemSource = PlannerEntityReference(kind: .item, id: item.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let first)) = await planner.read(
        session: session, request: .source(itinerarySource)),
      case .itineraryEntry(let firstIdentifier, let owner, let source)? = first.references.first
    else { return XCTFail("Adding must save a live route reference.") }
    XCTAssertEqual(owner, itinerarySource)
    XCTAssertEqual(source, itemSource)
    XCTAssertEqual(first.references.count, 1)
    let firstAppearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: firstIdentifier)
    guard
      case .appearance(let initial) = await planner.read(
        session: session, request: .appearance(firstAppearance))
    else { return XCTFail("The first appearance must be readable.") }
    XCTAssertTrue(initial.globalDone)
    XCTAssertFalse(initial.localDone)
    XCTAssertTrue(initial.effectiveDone)
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(firstAppearance), done: true))
      ).outcome
    else { return XCTFail("The first appearance can be completed locally.") }
    let _: Void = try await adding.callAsFunction(donate: false)
    completion.done = false
    let _: Void = try await completion.callAsFunction(donate: false)
    let editing = EditPlannerItemIntent()
    editing.item = item
    editing.notes = "Live Hotel notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let saved)) = await reopened.read(
        session: reopenedSession, request: .source(itinerarySource)),
      saved.references.count == 2,
      case .itineraryEntry(let secondIdentifier, let secondOwner, let secondSource) =
        saved.references[1],
      case .source(.item(let savedItem)) = await reopened.read(
        session: reopenedSession, request: .source(itemSource)),
      case .snapshot(let itemCatalog) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("Both entries and their single source must survive reopening.") }
    XCTAssertEqual(saved.references.first, first.references.first)
    XCTAssertNotEqual(secondIdentifier, firstIdentifier)
    XCTAssertEqual(secondOwner, itinerarySource)
    XCTAssertEqual(secondSource, itemSource)
    XCTAssertEqual(saved.progress.totalCount, 2)
    XCTAssertEqual(saved.progress.doneCount, 1)
    XCTAssertEqual(savedItem.content.notes, "Live Hotel notes")
    XCTAssertEqual(savedItem.state.globalDone, false)
    XCTAssertEqual(itemCatalog.rows, [.source(itemSource)])
    let secondAppearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: secondIdentifier)
    for (appearance, expectedLocalDone) in [(firstAppearance, true), (secondAppearance, false)] {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else { return XCTFail("Both original appearances must remain readable.") }
      XCTAssertEqual(current.content.notes, "Live Hotel notes")
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, expectedLocalDone)
      XCTAssertEqual(current.effectiveDone, expectedLocalDone)
    }
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testRepeatedListAddsPreserveRouteOrderAndLiveChildrenWithoutInheritingStandaloneCompletion()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "Museum"
    let museum = try await itemCreation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Tokyo Food"
    let list = try await listCreation.callAsFunction(donate: false)
    let membershipAddition = AddPlannerItemToListIntent()
    membershipAddition.item = museum
    membershipAddition.list = list
    let _: Void = try await membershipAddition.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let listSource = PlannerEntityReference(kind: .list, id: list.id)
    let museumSource = PlannerEntityReference(kind: .item, id: museum.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(listSource)),
      case .membership(let membershipIdentifier, _, _)? = originalList.references.first
    else { return XCTFail("The standalone membership must exist first.") }
    func save(_ command: PlannerCommand) async throws {
      guard
        case .applied(_, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    let standalone = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifier)
    try await save(.setCompletion(scope: .appearance(standalone), done: true))
    let planCreation = CreatePlannerItineraryIntent()
    planCreation.title = "Tokyo Weekend"
    let itinerary = try await planCreation.callAsFunction(donate: false)
    let itinerarySource = PlannerEntityReference(kind: .itinerary, id: itinerary.id)
    let addingList = AddPlannerListToItineraryIntent()
    addingList.list = list
    addingList.itinerary = itinerary
    let _: Void = try await addingList.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let first)) = await planner.read(
        session: session, request: .source(itinerarySource)),
      case .itineraryEntry(let firstIdentifier, _, let firstSource)? = first.references.first
    else { return XCTFail("Adding the List must save a live branch.") }
    XCTAssertEqual(firstSource, listSource)
    let firstAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: firstIdentifier, membershipId: membershipIdentifier)
    guard
      case .appearance(let initial) = await planner.read(
        session: session, request: .appearance(firstAppearance))
    else { return XCTFail("The branch child must start independently from standalone completion.") }
    XCTAssertFalse(initial.localDone)
    XCTAssertFalse(initial.effectiveDone)
    try await save(.setCompletion(scope: .appearance(firstAppearance), done: true))
    let addingItem = AddPlannerItemToItineraryIntent()
    addingItem.item = museum
    addingItem.itinerary = itinerary
    let _: Void = try await addingItem.callAsFunction(donate: false)
    let _: Void = try await addingList.callAsFunction(donate: false)
    itemCreation.title = "Lunch"
    let lunch = try await itemCreation.callAsFunction(donate: false)
    membershipAddition.item = lunch
    let _: Void = try await membershipAddition.callAsFunction(donate: false)
    let editing = EditPlannerItemIntent()
    editing.item = museum
    editing.notes = "Updated shared Museum notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    let completion = SetPlannerItemCompletionIntent()
    completion.item = museum
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let globallyDone)) = await planner.read(
        session: session, request: .source(itinerarySource))
    else { return XCTFail("Global completion must apply to every live Museum appearance.") }
    XCTAssertEqual(globallyDone.progress.doneCount, 3)
    XCTAssertEqual(globallyDone.progress.totalCount, 5)
    completion.done = false
    let _: Void = try await completion.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let saved)) = await reopened.read(
        session: reopenedSession, request: .source(itinerarySource)),
      case .source(.list(let savedList)) = await reopened.read(
        session: reopenedSession, request: .source(listSource))
    else { return XCTFail("The route and source List must survive reopening.") }
    let entries = saved.references.compactMap { reference -> (UUID, PlannerEntityReference)? in
      guard case .itineraryEntry(let identifier, let owner, let source) = reference,
        owner == itinerarySource
      else { return nil }
      return (identifier, source)
    }
    XCTAssertEqual(entries.map(\.1), [listSource, museumSource, listSource])
    guard entries.count == 3 else { return XCTFail("Repeated Lists must retain distinct entries.") }
    XCTAssertEqual(entries[0].0, firstIdentifier)
    XCTAssertEqual(Set(entries.map(\.0)).count, 3)
    XCTAssertEqual(saved.progress.totalCount, 5)
    XCTAssertEqual(saved.progress.doneCount, 1)
    XCTAssertEqual(saved.listEntrySummaries.count, 2)
    XCTAssertEqual(savedList.progress.totalCount, 2)
    XCTAssertEqual(savedList.progress.doneCount, 1)
    let secondAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entries[2].0, membershipId: membershipIdentifier)
    let directAppearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: entries[1].0)
    for (appearance, expectedLocalDone) in [
      (standalone, true), (firstAppearance, true), (directAppearance, false),
      (secondAppearance, false),
    ] {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else { return XCTFail("Each Museum appearance must keep its own completion context.") }
      XCTAssertEqual(current.source, museumSource)
      XCTAssertEqual(current.content.notes, "Updated shared Museum notes")
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, expectedLocalDone)
      XCTAssertEqual(current.effectiveDone, expectedLocalDone)
    }
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testMissingWrongKindAndDeletedSourcesOrDestinationsCannotCreateOrResurrectEntries()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "Museum"
    let item = try await itemCreation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Tokyo Food"
    let list = try await listCreation.callAsFunction(donate: false)
    let planCreation = CreatePlannerItineraryIntent()
    planCreation.title = "Surviving route"
    planCreation.notes = "Keep these notes"
    let survivor = try await planCreation.callAsFunction(donate: false)
    planCreation.title = "Deleted route"
    let removed = try await planCreation.callAsFunction(donate: false)
    func requireRejectedItem(_ source: PlannerItemEntity, itinerary: PlannerItineraryEntity) async {
      let adding = AddPlannerItemToItineraryIntent()
      adding.item = source
      adding.itinerary = itinerary
      do {
        let _: Void = try await adding.callAsFunction(donate: false)
        XCTFail("Add Item must reject an unavailable source or destination.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    func requireRejectedList(_ source: PlannerListEntity, itinerary: PlannerItineraryEntity) async {
      let adding = AddPlannerListToItineraryIntent()
      adding.list = source
      adding.itinerary = itinerary
      do {
        let _: Void = try await adding.callAsFunction(donate: false)
        XCTFail("Add List must reject an unavailable source or destination.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    for identifier in [UUID(), list.id] {
      await requireRejectedItem(
        .init(id: identifier, title: "Unavailable Item", done: false, archived: false),
        itinerary: survivor)
    }
    for identifier in [UUID(), item.id] {
      await requireRejectedList(
        .init(id: identifier, name: "Unavailable List", archived: false), itinerary: survivor)
    }
    for identifier in [UUID(), list.id] {
      let missing = PlannerItineraryEntity(
        id: identifier, title: "Unavailable route", archived: false)
      await requireRejectedItem(item, itinerary: missing)
      await requireRejectedList(list, itinerary: missing)
    }
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
    try await delete(.init(kind: .itinerary, id: removed.id))
    await requireRejectedItem(item, itinerary: removed)
    await requireRejectedList(list, itinerary: removed)
    try await delete(.init(kind: .item, id: item.id))
    try await delete(.init(kind: .list, id: list.id))
    await requireRejectedItem(item, itinerary: survivor)
    await requireRejectedList(list, itinerary: survivor)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let plans) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .itinerary, archive: .all)))
      ),
      case .snapshot(let lists) = await reopened.query(
        .init(session: reopenedSession, request: .catalog(.init(sourceKind: .list, archive: .all)))),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all)))),
      case .source(.itinerary(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .itinerary, id: survivor.id)))
    else { return XCTFail("Rejected additions must leave the surviving dataset readable.") }
    XCTAssertEqual(plans.rows, [.source(.init(kind: .itinerary, id: survivor.id))])
    XCTAssertTrue(items.rows.isEmpty)
    XCTAssertTrue(lists.rows.isEmpty)
    XCTAssertTrue(retained.references.isEmpty)
    XCTAssertEqual(retained.content.title, "Surviving route")
    XCTAssertEqual(retained.content.notes, "Keep these notes")
    XCTAssertEqual(retained.progress.state, .empty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledItemAndListAdditionsLeaveTheRouteAndSourcesUnchanged() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "Museum"
    let item = try await itemCreation.callAsFunction(donate: false)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Tokyo Food"
    let list = try await listCreation.callAsFunction(donate: false)
    let planCreation = CreatePlannerItineraryIntent()
    planCreation.title = "Unchanged route"
    let itinerary = try await planCreation.callAsFunction(donate: false)
    let source = PlannerEntityReference(kind: .itinerary, id: itinerary.id)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(source))
    else { return XCTFail("The initial empty route must exist before cancellation.") }
    let addingItem = AddPlannerItemToItineraryIntent()
    addingItem.item = item
    addingItem.itinerary = itinerary
    let itemRequest = Task {
      let _: Void = try await addingItem.callAsFunction(donate: false)
    }
    itemRequest.cancel()
    do {
      let _: Void = try await itemRequest.value
      XCTFail("A precancelled Item addition cannot acknowledge a new entry.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let addingList = AddPlannerListToItineraryIntent()
    addingList.list = list
    addingList.itinerary = itinerary
    let listRequest = Task {
      let _: Void = try await addingList.callAsFunction(donate: false)
    }
    listRequest.cancel()
    do {
      let _: Void = try await listRequest.value
      XCTFail("A precancelled List addition cannot acknowledge a new branch.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let after)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .item, id: item.id))),
      case .source(.list(let retainedList)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .list, id: list.id)))
    else { return XCTFail("Cancellation must preserve the actual original sources.") }
    XCTAssertTrue(after.references.isEmpty)
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.progress.state, .empty)
    XCTAssertEqual(retainedItem.content.title, "Museum")
    XCTAssertEqual(retainedList.content.name, "Tokyo Food")
    XCTAssertTrue(retainedList.references.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedItemAndListAdditionsSurviveIncompleteRecoveryWithoutAutomaticDuplicates()
    async throws
  {
    for addsList in [false, true] {
      let (directory, configuration, store) = try makeStorage()
      defer { try? FileManager.default.removeItem(at: directory) }
      AppDependencyManager.shared.add(dependency: store)
      let itemCreation = CreatePlannerItemIntent()
      itemCreation.title = "Museum"
      let item = try await itemCreation.callAsFunction(donate: false)
      let listCreation = CreatePlannerListIntent()
      listCreation.name = "Tokyo Food"
      let list = try await listCreation.callAsFunction(donate: false)
      let planCreation = CreatePlannerItineraryIntent()
      planCreation.title = "Destination route"
      let destination = try await planCreation.callAsFunction(donate: false)
      planCreation.title = "Other route"
      let other = try await planCreation.callAsFunction(donate: false)
      func add(to itinerary: PlannerItineraryEntity) async throws {
        if addsList {
          let adding = AddPlannerListToItineraryIntent()
          adding.list = list
          adding.itinerary = itinerary
          let _: Void = try await adding.callAsFunction(donate: false)
        } else {
          let adding = AddPlannerItemToItineraryIntent()
          adding.item = item
          adding.itinerary = itinerary
          let _: Void = try await adding.callAsFunction(donate: false)
        }
      }
      let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      try await add(to: destination)
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(store.recoveryBlocked)
      XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
      do {
        try await add(to: other)
        XCTFail(
          "Incomplete recovery must block another addition without silently retrying the first.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: configuration)
      let destinationSource = PlannerEntityReference(kind: .itinerary, id: destination.id)
      let otherSource = PlannerEntityReference(kind: .itinerary, id: other.id)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .source(.itinerary(let applied)) = await reopened.read(
          session: session, request: .source(destinationSource)),
        case .source(.itinerary(let untouched)) = await reopened.read(
          session: session, request: .source(otherSource)),
        case .itineraryEntry(_, let owner, let source)? = applied.references.first
      else {
        return XCTFail(
          "The applied route entry must remain readable after actual recovery failure.")
      }
      XCTAssertEqual(owner, destinationSource)
      let expectedSource: PlannerEntityReference
      if addsList {
        expectedSource = .init(kind: .list, id: list.id)
      } else {
        expectedSource = .init(kind: .item, id: item.id)
      }
      XCTAssertEqual(source, expectedSource)
      XCTAssertEqual(applied.references.count, 1)
      XCTAssertTrue(untouched.references.isEmpty)
      await store.retryIncompleteRecovery()
      XCTAssertFalse(store.recoveryBlocked)
      XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: session, operationId: operationIdentifier),
        case .source(.itinerary(let recovered)) = await reopened.read(
          session: session, request: .source(destinationSource))
      else {
        return XCTFail("Native retry must complete the original operation, not add another entry.")
      }
      XCTAssertEqual(recovered.references, applied.references)
      try await add(to: other)
      guard
        case .source(.itinerary(let finalDestination)) = await reopened.read(
          session: session, request: .source(destinationSource)),
        case .source(.itinerary(let finalOther)) = await reopened.read(
          session: session, request: .source(otherSource)),
        case .itineraryEntry(let nextIdentifier, let nextOwner, let nextSource)? = finalOther
          .references.first,
        case .itineraryEntry(let originalIdentifier, _, _)? = finalDestination.references.first
      else {
        return XCTFail("An explicit addition after native recovery must create its own entry.")
      }
      XCTAssertEqual(finalDestination.references, applied.references)
      XCTAssertEqual(finalOther.references.count, 1)
      XCTAssertNotEqual(nextIdentifier, originalIdentifier)
      XCTAssertEqual(nextOwner, otherSource)
      XCTAssertEqual(nextSource, expectedSource)
      XCTAssertFalse(store.isSaving)
    }
  }

  func testUnavailableStorageCannotAcknowledgeEitherItineraryAddition() async throws {
    let (directory, _, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let itinerary = PlannerItineraryEntity(id: UUID(), title: "Unavailable", archived: false)
    let addingItem = AddPlannerItemToItineraryIntent()
    addingItem.item = .init(id: UUID(), title: "Museum", done: false, archived: false)
    addingItem.itinerary = itinerary
    do {
      let _: Void = try await addingItem.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge an Item route entry.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let addingList = AddPlannerListToItineraryIntent()
    addingList.list = .init(id: UUID(), name: "Tokyo Food", archived: false)
    addingList.itinerary = itinerary
    do {
      let _: Void = try await addingList.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a List route entry.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  private func makeStorage() throws -> (
    directory: URL, configuration: PlannerStorageConfiguration, store: SavedPlannerStore
  ) {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "PlannerItineraryOrganizationIntentTests/\(UUID().uuidString)",
      directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    return (directory, configuration, SavedPlannerStore(configuration: configuration))
  }
}
