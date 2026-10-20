import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerAssignedLabelIntentTests: XCTestCase {
  func testItemCategoriesReturnOnlyCurrentSharedAssignmentsWithDistinctIdentities() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assignment = SetPlannerItemCategoryIntent()
    assignment.item = .init(id: fixture.item.id, title: "Cached Item", done: false, archived: true)
    assignment.category = .init(id: fixture.extraCategory.id, name: "Cached Category")
    let _: Void = try await assignment.callAsFunction(donate: false)
    let rename = RenamePlannerCategoryIntent()
    rename.category = assignment.category
    rename.name = "Museums"
    let _: Void = try await rename.callAsFunction(donate: false)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The read fixture must have current saved shared-label names.") }
    let reading = GetPlannerItemCategoriesIntent()
    reading.item = assignment.item
    let categories = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(categories.map(\.id)), [fixture.category.id, fixture.extraCategory.id])
    XCTAssertEqual(categories.map(\.name), ["Museums", "Museums"])
    XCTAssertEqual(categories.count, 2)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let after) = await reopened.exportData(session: session)
    else { return XCTFail("Reading label assignments must preserve the saved planner.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testItemTagsReadArchivedOwnersAndReturnEmptyAfterOnlyTheirAssignmentsAreRemoved()
    async throws
  {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assignment = SetPlannerItemTagIntent()
    assignment.item = .init(id: fixture.item.id, title: "Cached Item", done: false, archived: false)
    assignment.tag = .init(id: fixture.extraTag.id, name: "Cached Tag")
    let _: Void = try await assignment.callAsFunction(donate: false)
    let rename = RenamePlannerTagIntent()
    rename.tag = assignment.tag
    rename.name = "rainy-day"
    let _: Void = try await rename.callAsFunction(donate: false)
    let archive = SetPlannerItemArchiveIntent()
    archive.item = assignment.item
    archive.archived = true
    let _: Void = try await archive.callAsFunction(donate: false)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The archived owner and its assigned Tags must be saved.") }
    let reading = GetPlannerItemTagsIntent()
    reading.item = assignment.item
    let tags = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(Set(tags.map(\.id)), [fixture.tag.id, fixture.extraTag.id])
    XCTAssertEqual(tags.map(\.name), ["rainy-day", "rainy-day"])
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("An archived owner's labels must remain readable without mutation.") }
    XCTAssertEqual(after, before)
    assignment.assigned = false
    let _: Void = try await assignment.callAsFunction(donate: false)
    assignment.tag = .init(id: fixture.tag.id, name: "Cached original Tag")
    let _: Void = try await assignment.callAsFunction(donate: false)
    let empty = try await reading.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary))
    else { return XCTFail("The empty Item assignment set must retain the shared sources.") }
    XCTAssertTrue(item.content.tagIds.isEmpty)
    XCTAssertEqual(item.content.categoryIds, [fixture.category.id])
    XCTAssertEqual(item.state.archived, true)
    XCTAssertEqual(item.state.globalDone, true)
    XCTAssertEqual(itinerary.content.tagIds, [fixture.tag.id])
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testItineraryCategoriesStayIndependentOfTheReferencedItemsAndReadSharedRenames()
    async throws
  {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assignItem = SetPlannerItemCategoryIntent()
    assignItem.item = .init(id: fixture.item.id, title: "Cached Item", done: false, archived: false)
    assignItem.category = .init(id: fixture.extraCategory.id, name: "Cached extra Category")
    let _: Void = try await assignItem.callAsFunction(donate: false)
    let rename = RenamePlannerCategoryIntent()
    rename.category = .init(id: fixture.category.id, name: "Cached shared Category")
    rename.name = "Culture · 文化"
    let _: Void = try await rename.callAsFunction(donate: false)
    let reading = GetPlannerItineraryCategoriesIntent()
    reading.itinerary = .init(id: fixture.itinerary.id, title: "Cached Itinerary", archived: true)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The Itinerary and referenced Item must have distinct assignments.") }
    let categories = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(categories.map(\.id), [fixture.category.id])
    XCTAssertEqual(categories.map(\.name), ["Culture · 文化"])
    let readItem = GetPlannerItemCategoriesIntent()
    readItem.item = assignItem.item
    let itemCategories = try await readItem.callAsFunction(donate: false)
    XCTAssertEqual(Set(itemCategories.map(\.id)), [fixture.category.id, fixture.extraCategory.id])
    XCTAssertEqual(itemCategories.first { $0.id == fixture.category.id }?.name, "Culture · 文化")
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Reading either owner must preserve the complete saved planner.") }
    XCTAssertEqual(after, before)
    let removal = SetPlannerItineraryCategoryIntent()
    removal.itinerary = reading.itinerary
    removal.category = rename.category
    removal.assigned = false
    let _: Void = try await removal.callAsFunction(donate: false)
    let empty = try await reading.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
    let retainedItemCategories = try await readItem.callAsFunction(donate: false)
    XCTAssertEqual(
      Set(retainedItemCategories.map(\.id)), [fixture.category.id, fixture.extraCategory.id])
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testItineraryTagsReadOnlyItsOwnAssignmentsDespiteRepeatedItemReferences() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    let assignment = SetPlannerItineraryTagIntent()
    assignment.itinerary = .init(
      id: fixture.itinerary.id, title: "Cached Itinerary", archived: false)
    assignment.tag = .init(id: fixture.extraTag.id, name: "Cached extra Tag")
    let _: Void = try await assignment.callAsFunction(donate: false)
    assignment.tag = .init(id: fixture.tag.id, name: "Cached original Tag")
    assignment.assigned = false
    let _: Void = try await assignment.callAsFunction(donate: false)
    let rename = RenamePlannerTagIntent()
    rename.tag = .init(id: fixture.extraTag.id, name: "Cached extra Tag")
    rename.name = "Réservé · 予約済み"
    let _: Void = try await rename.callAsFunction(donate: false)
    let archive = SetPlannerItineraryArchiveIntent()
    archive.itinerary = assignment.itinerary
    archive.archived = true
    let _: Void = try await archive.callAsFunction(donate: false)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("The archived Itinerary must have its own distinct saved Tag.") }
    let reading = GetPlannerItineraryTagsIntent()
    reading.itinerary = assignment.itinerary
    let tags = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(tags.map(\.id), [fixture.extraTag.id])
    XCTAssertEqual(tags.map(\.name), ["Réservé · 予約済み"])
    let readItem = GetPlannerItemTagsIntent()
    readItem.item = .init(id: fixture.item.id, title: "Cached Item", done: false, archived: false)
    let itemTags = try await readItem.callAsFunction(donate: false)
    XCTAssertEqual(itemTags.map(\.id), [fixture.tag.id])
    XCTAssertEqual(itemTags.map(\.name), ["rainy-day"])
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let after) = await reopened.exportData(session: session),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary))
    else { return XCTFail("The label reads must retain the saved route and shared Item.") }
    XCTAssertEqual(after, before)
    XCTAssertEqual(itinerary.state.archived, true)
    XCTAssertEqual(
      itinerary.references.compactMap { reference -> UUID? in
        guard case .itineraryEntry(let identifier, _, _) = reference else { return nil }
        return identifier
      }, [fixture.entryIdentifier, fixture.repeatedEntryIdentifier])
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testMissingWrongKindAndDeletedOwnersFailInsteadOfReturningEmptyOrSwitchingSources()
    async throws
  {
    let fixture = try await makeLabelAssociationIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Invalid reads must start from the saved reference graph.") }
    let unavailable: [PlannerEntityReference] = [
      .init(kind: .item, id: UUID()), .init(kind: .itinerary, id: UUID()),
      .init(kind: .item, id: fixture.itinerary.id), .init(kind: .itinerary, id: fixture.item.id),
    ]
    for owner in unavailable {
      for labelKind in [PlannerEntityKind.category, .tag] {
        do {
          _ = try await readAssignedLabelIdentifiers(owner: owner, labelKind: labelKind)
          XCTFail("An invalid owner cannot become an empty successful read or another source.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    guard case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Invalid owner reads must leave readable data.") }
    XCTAssertEqual(unchanged, before)
    for owner in [fixture.item, fixture.itinerary] {
      try await deleteAssignedLabelFixtureSource(owner, fixture: fixture)
    }
    guard case .exported(let deleted) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Confirmed source deletion must leave its surviving data readable.") }
    for owner in [fixture.item, fixture.itinerary] {
      for labelKind in [PlannerEntityKind.category, .tag] {
        do {
          _ = try await readAssignedLabelIdentifiers(owner: owner, labelKind: labelKind)
          XCTFail("Reading a deleted owner cannot resurrect it or reuse another source.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Rejected deleted-owner reads must preserve the surviving graph.") }
    XCTAssertEqual(after, deleted)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testConfirmedSharedLabelDeletionRefreshesBothOwnersWithoutDeletingThem() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    for label in [fixture.category, fixture.tag] {
      try await deleteAssignedLabelFixtureSource(label, fixture: fixture)
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Confirmed label deletion must preserve both source owners.") }
    for owner in [fixture.item, fixture.itinerary] {
      for labelKind in [PlannerEntityKind.category, .tag] {
        let identifiers = try await readAssignedLabelIdentifiers(owner: owner, labelKind: labelKind)
        XCTAssertTrue(identifiers.isEmpty)
      }
    }
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let after) = await reopened.exportData(session: session),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary))
    else { return XCTFail("Empty assignment reads must retain both owners and their route.") }
    XCTAssertEqual(after, before)
    XCTAssertEqual(item.content.notes, "Keep booking")
    XCTAssertEqual(item.state.globalDone, true)
    XCTAssertEqual(itinerary.content.notes, "Keep route")
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testPrecancelledLabelReadsPreserveSavedDataForEveryOwnerAndLabelKind() async throws {
    let fixture = try await makeLabelAssociationIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancelled reads must start from saved data.") }
    for owner in [fixture.item, fixture.itinerary] {
      for labelKind in [PlannerEntityKind.category, .tag] {
        let task = Task { @MainActor in
          try await readAssignedLabelIdentifiers(owner: owner, labelKind: labelKind)
        }
        task.cancel()
        do {
          _ = try await task.value
          XCTFail("A precancelled label read must propagate cancellation.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancelled reads must leave the graph readable.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testUnavailableBootstrapFailsAllLabelReadsWithoutAnEmptySuccess() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let content = Data("Keep unavailable storage obstructed.".utf8)
    try content.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    for ownerKind in [PlannerEntityKind.item, .itinerary] {
      for labelKind in [PlannerEntityKind.category, .tag] {
        do {
          _ = try await readAssignedLabelIdentifiers(
            owner: .init(kind: ownerKind, id: UUID()), labelKind: labelKind)
          XCTFail("Unavailable storage cannot return successful empty label assignments.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    XCTAssertEqual(try Data(contentsOf: obstruction), content)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testLabelReadsDuringIncompleteRecoveryDoNotAcknowledgeOrRepeatTheOriginalChange()
    async throws
  {
    let fixture = try await makeLabelAssociationIntentFixture()
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let assignment = SetPlannerItemTagIntent()
    assignment.item = .init(id: fixture.item.id, title: "Cached Item", done: false, archived: false)
    assignment.tag = .init(id: fixture.extraTag.id, name: "Cached Tag")
    let _: Void = try await assignment.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    guard
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { return XCTFail("The applied label edit must remain readable before recovery.") }
    for owner in [fixture.item, fixture.itinerary] {
      let categories = try await readAssignedLabelIdentifiers(owner: owner, labelKind: .category)
      let tags = try await readAssignedLabelIdentifiers(owner: owner, labelKind: .tag)
      XCTAssertEqual(categories, [fixture.category.id])
      if owner == fixture.item {
        XCTAssertEqual(Set(tags), [fixture.tag.id, fixture.extraTag.id])
      } else {
        XCTAssertEqual(tags, [fixture.tag.id])
      }
    }
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    await fixture.store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .source(.item(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else {
      return XCTFail("Explicit native recovery must acknowledge only its original operation.")
    }
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.labels, before.labels)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
  }
}

@MainActor
private func readAssignedLabelIdentifiers(
  owner: PlannerEntityReference, labelKind: PlannerEntityKind
) async throws -> [UUID] {
  switch (owner.kind, labelKind) {
  case (.item, .category):
    let reading = GetPlannerItemCategoriesIntent()
    reading.item = .init(id: owner.id, title: "Cached Item", done: false, archived: false)
    let values = try await reading.callAsFunction(donate: false)
    return values.map(\.id)
  case (.item, .tag):
    let reading = GetPlannerItemTagsIntent()
    reading.item = .init(id: owner.id, title: "Cached Item", done: false, archived: false)
    let values = try await reading.callAsFunction(donate: false)
    return values.map(\.id)
  case (.itinerary, .category):
    let reading = GetPlannerItineraryCategoriesIntent()
    reading.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: false)
    let values = try await reading.callAsFunction(donate: false)
    return values.map(\.id)
  case (.itinerary, .tag):
    let reading = GetPlannerItineraryTagsIntent()
    reading.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: false)
    let values = try await reading.callAsFunction(donate: false)
    return values.map(\.id)
  default: throw CancellationError()
  }
}

@MainActor
private func deleteAssignedLabelFixtureSource(
  _ source: PlannerEntityReference, fixture: LabelAssociationIntentFixture
) async throws {
  guard
    case .reviewed(let review) = await fixture.planner.prepareReview(
      session: fixture.session, command: .deleteSource(source: source)),
    case .applied(_, .complete) = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session, command: .deleteSource(source: source),
        reviewToken: review.reviewToken)
    ).outcome
  else { throw CancellationError() }
}
