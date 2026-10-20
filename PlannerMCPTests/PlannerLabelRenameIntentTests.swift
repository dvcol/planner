import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerLabelRenameIntentTests: XCTestCase {
  func testCategoryRenameUpdatesLiveOwnerAndRowLabelsWithoutRewritingTheirData() async throws {
    let fixture = try await makeLabelRenameIntentFixture()
    guard
      case .source(.category(let original)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.item(let beforeItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item)),
      case .source(.itinerary(let beforeItinerary)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary)),
      case .source(.list(let beforeList)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.list))
    else { return XCTFail("The shared label and its owners must be readable before renaming.") }
    let rename = RenamePlannerCategoryIntent()
    rename.category = .init(id: fixture.category.id, name: "Cached Category")
    rename.name = "Art and museums"
    let _: Void = try await rename.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.category(let current)) = await reopened.read(
        session: session, request: .source(fixture.category)),
      case .source(.tag(let retainedTag)) = await reopened.read(
        session: session, request: .source(fixture.tag)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.list(let list)) = await reopened.read(
        session: session, request: .source(fixture.list)),
      case .source(.schedule(let booking)) = await reopened.read(
        session: session, request: .source(fixture.schedule)),
      case .snapshot(let snapshot) = await reopened.query(
        .init(
          session: session,
          request: .items(
            .init(completion: .all, archive: .all, categories: .init(ids: [fixture.category.id]))))),
      case .rows(let rows) = await reopened.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64))
    else { return XCTFail("Live label changes and unchanged owners must survive reopening.") }
    XCTAssertEqual(current.source, original.source)
    XCTAssertEqual(current.sourceLifetimeId, original.sourceLifetimeId)
    XCTAssertEqual(current.createdAt, original.createdAt)
    XCTAssertEqual(current.content.name, "Art and museums")
    XCTAssertEqual(current.content.color, original.content.color)
    XCTAssertEqual(current.content.iconName, original.content.iconName)
    XCTAssertEqual(current.references, original.references)
    XCTAssertEqual(retainedTag.content.name, "rainy-day")
    XCTAssertEqual(item.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(item.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(item.references, beforeItem.references)
    XCTAssertEqual(item.state.globalDone, false)
    XCTAssertEqual(item.state.archived, false)
    XCTAssertEqual(itinerary.content, beforeItinerary.content)
    XCTAssertEqual(itinerary.fieldHashes, beforeItinerary.fieldHashes)
    XCTAssertEqual(itinerary.updatedAt, beforeItinerary.updatedAt)
    XCTAssertEqual(itinerary.references, beforeItinerary.references)
    XCTAssertEqual(list.updatedAt, beforeList.updatedAt)
    XCTAssertEqual(list.references, beforeList.references)
    XCTAssertEqual(booking.content.form, fixture.form)
    XCTAssertEqual(item.labels.first { $0.reference == fixture.category }?.name, "Art and museums")
    XCTAssertEqual(
      itinerary.labels.first { $0.reference == fixture.category }?.name, "Art and museums")
    XCTAssertEqual(rows.rows.map(\.identity), [.source(fixture.item)])
    XCTAssertEqual(
      rows.rows.first?.labels.first { $0.reference == fixture.category }?.name, "Art and museums")
    for (appearance, expectedLocal) in [
      (
        PlannerAppearance.listMembership(
          listId: fixture.list.id, membershipId: fixture.membershipIdentifier), true
      ),
      (
        .directItineraryItem(itineraryId: fixture.itinerary.id, entryId: fixture.entryIdentifier),
        false
      ),
    ] {
      guard
        case .appearance(let saved) = await reopened.read(
          session: session, request: .appearance(appearance))
      else { return XCTFail("Label renaming cannot replace completion contexts.") }
      XCTAssertFalse(saved.globalDone)
      XCTAssertEqual(saved.localDone, expectedLocal)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
  func testTagRenamePreservesOtherLabelsAndAllOwnerBindingsAfterReopen() async throws {
    let fixture = try await makeLabelRenameIntentFixture()
    guard
      case .source(.tag(let original)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.tag)),
      case .source(.category(let beforeCategory)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.item(let beforeItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item)),
      case .source(.itinerary(let beforeItinerary)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else { return XCTFail("Tag renaming requires current shared-source and owner observations.") }
    let rename = RenamePlannerTagIntent()
    rename.tag = .init(id: fixture.tag.id, name: "Cached Tag")
    rename.name = "indoors"
    let _: Void = try await rename.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.tag(let current)) = await reopened.read(
        session: session, request: .source(fixture.tag)),
      case .source(.category(let category)) = await reopened.read(
        session: session, request: .source(fixture.category)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .snapshot(let snapshot) = await reopened.query(
        .init(
          session: session,
          request: .items(
            .init(completion: .all, archive: .all, tags: .init(ids: [fixture.tag.id]))))),
      case .rows(let rows) = await reopened.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64))
    else { return XCTFail("The renamed Tag must remain live across all original references.") }
    XCTAssertEqual(current.source, original.source)
    XCTAssertEqual(current.sourceLifetimeId, original.sourceLifetimeId)
    XCTAssertEqual(current.createdAt, original.createdAt)
    XCTAssertEqual(current.content.name, "indoors")
    XCTAssertEqual(current.content.color, original.content.color)
    XCTAssertEqual(current.content.iconName, original.content.iconName)
    XCTAssertEqual(current.fieldHashes[.color], original.fieldHashes[.color])
    XCTAssertEqual(current.fieldHashes[.iconName], original.fieldHashes[.iconName])
    XCTAssertNotEqual(current.fieldHashes[.name], original.fieldHashes[.name])
    XCTAssertEqual(current.references, original.references)
    XCTAssertEqual(category.content, beforeCategory.content)
    XCTAssertEqual(category.updatedAt, beforeCategory.updatedAt)
    XCTAssertEqual(category.references, beforeCategory.references)
    XCTAssertEqual(item.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(item.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(item.references, beforeItem.references)
    XCTAssertEqual(itinerary.content, beforeItinerary.content)
    XCTAssertEqual(itinerary.fieldHashes, beforeItinerary.fieldHashes)
    XCTAssertEqual(itinerary.updatedAt, beforeItinerary.updatedAt)
    XCTAssertEqual(itinerary.references, beforeItinerary.references)
    XCTAssertEqual(item.labels.first { $0.reference == fixture.tag }?.name, "indoors")
    XCTAssertEqual(itinerary.labels.first { $0.reference == fixture.tag }?.name, "indoors")
    XCTAssertEqual(rows.rows.map(\.identity), [.source(fixture.item)])
    XCTAssertEqual(rows.rows.first?.labels.first { $0.reference == fixture.tag }?.name, "indoors")
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
  func testRenamingToAnExistingNameKeepsBothLabelsAndOriginalOwnerBindings() async throws {
    for renamingCategory in [true, false] {
      let fixture = try await makeLabelRenameIntentFixture()
      let source = renamingCategory ? fixture.category : fixture.tag
      let command: PlannerCommand
      if renamingCategory {
        command = .createCategory(content: .init(name: "Shared name"))
      } else {
        command = .createTag(content: .init(name: "Shared name"))
      }
      guard
        case .applied(let created, .complete) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome,
        let duplicate = created.generated.first,
        case .source(.item(let before)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.item))
      else { return XCTFail("Duplicate-name qualification needs two independent labels.") }
      try await renameLabel(kind: source.kind, identifier: source.id, name: "Shared name")
      let identifiers: [UUID]
      if renamingCategory {
        let query = PlannerCategoryEntityQuery()
        query.plannerStore = fixture.store
        identifiers = try await query.entities(matching: "SHARED name").map(\.id)
      } else {
        let query = PlannerTagEntityQuery()
        query.plannerStore = fixture.store
        identifiers = try await query.entities(matching: "SHARED name").map(\.id)
      }
      XCTAssertEqual(Set(identifiers), [source.id, duplicate.id])
      XCTAssertEqual(identifiers.count, 2)
      guard
        case .source(.item(let after)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.item))
      else { throw CancellationError() }
      XCTAssertEqual(after.fieldHashes, before.fieldHashes)
      XCTAssertEqual(after.updatedAt, before.updatedAt)
      XCTAssertEqual(after.content.categoryIds, [fixture.category.id])
      XCTAssertEqual(after.content.tagIds, [fixture.tag.id])
      XCTAssertEqual(after.labels.first { $0.reference == source }?.name, "Shared name")
      XCTAssertFalse(after.labels.contains { $0.reference == duplicate })
    }
  }

  func testBlankWrongKindMissingAndDeletedLabelsCannotChangeOtherData() async throws {
    let fixture = try await makeLabelRenameIntentFixture()
    guard
      case .source(.category(let beforeCategory)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.tag(let beforeTag)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.tag)),
      case .source(.item(let beforeItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { throw CancellationError() }
    for source in [fixture.category, fixture.tag] {
      for name in ["", " \n\t "] {
        do {
          try await renameLabel(kind: source.kind, identifier: source.id, name: name)
          XCTFail("A required shared-label name cannot be blank.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      let otherLabel = source.kind == .category ? fixture.tag : fixture.category
      for identifier in [UUID(), fixture.item.id, otherLabel.id] {
        do {
          try await renameLabel(kind: source.kind, identifier: identifier, name: "Invalid target")
          XCTFail("Missing/wrong-kind labels cannot retarget.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    guard
      case .source(.category(let category)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.tag(let tag)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.tag)),
      case .source(.item(let item)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { return XCTFail("Invalid changes must leave the original graph readable.") }
    XCTAssertEqual(category.content, beforeCategory.content)
    XCTAssertEqual(category.updatedAt, beforeCategory.updatedAt)
    XCTAssertEqual(tag.content, beforeTag.content)
    XCTAssertEqual(tag.updatedAt, beforeTag.updatedAt)
    XCTAssertEqual(item.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(item.updatedAt, beforeItem.updatedAt)
    for source in [fixture.category, fixture.tag] {
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: .deleteSource(source: source)),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: .deleteSource(source: source),
            reviewToken: review.reviewToken)
        ).outcome,
        case .source(.item(let afterDelete)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.item))
      else { return XCTFail("Native reviewed deletion must invalidate the original label first.") }
      do {
        try await renameLabel(kind: source.kind, identifier: source.id, name: "Cannot resurrect")
        XCTFail("Renaming cannot restore a deleted label.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      guard
        case .source(.item(let afterRejected)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.item)),
        case .failed(let missing) = await fixture.planner.read(
          session: fixture.session, request: .source(source))
      else { return XCTFail("The deleted label must stay missing without further owner changes.") }
      XCTAssertEqual(missing.code, "missingReference")
      XCTAssertEqual(afterRejected.fieldHashes, afterDelete.fieldHashes)
      XCTAssertEqual(afterRejected.updatedAt, afterDelete.updatedAt)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testPrecancelledRenamesPreserveBothLabelNamesAndTimestamps() async throws {
    let fixture = try await makeLabelRenameIntentFixture()
    guard
      case .source(.category(let beforeCategory)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.tag(let beforeTag)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.tag))
    else { throw CancellationError() }
    for source in [fixture.category, fixture.tag] {
      let request = Task {
        try await self.renameLabel(kind: source.kind, identifier: source.id, name: "Cancelled")
      }
      request.cancel()
      do {
        try await request.value
        XCTFail("A precancelled rename cannot change a label.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    guard
      case .source(.category(let category)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.tag(let tag)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.tag))
    else { throw CancellationError() }
    XCTAssertEqual(category.content, beforeCategory.content)
    XCTAssertEqual(category.updatedAt, beforeCategory.updatedAt)
    XCTAssertEqual(tag.content, beforeTag.content)
    XCTAssertEqual(tag.updatedAt, beforeTag.updatedAt)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testUnavailableStorageRejectsBothRenamesWithoutReplacingTheObstruction() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    for kind in [PlannerEntityKind.category, .tag] {
      do {
        try await renameLabel(kind: kind, identifier: UUID(), name: "Cannot save")
        XCTFail("Unavailable storage cannot acknowledge a rename.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testIncompleteRecoveryRetainsEachAppliedRenameWithoutRewritingOwnersOrReplaying()
    async throws
  {
    for renamingCategory in [true, false] {
      let fixture = try await makeLabelRenameIntentFixture()
      let source = renamingCategory ? fixture.category : fixture.tag
      await fixture.store.open()
      XCTAssertTrue(fixture.store.isReady)
      guard
        case .source(.item(let beforeItem)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.item))
      else { throw CancellationError() }
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      try await renameLabel(kind: source.kind, identifier: source.id, name: "Applied rename")
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      do {
        try await renameLabel(kind: source.kind, identifier: source.id, name: "Blocked rename")
        XCTFail("Incomplete recovery must block another rename.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .source(.item(let appliedItem)) = await reopened.read(
          session: session, request: .source(fixture.item))
      else { return XCTFail("The applied rename must leave owners readable in reopened storage.") }
      XCTAssertEqual(appliedItem.fieldHashes, beforeItem.fieldHashes)
      XCTAssertEqual(appliedItem.updatedAt, beforeItem.updatedAt)
      let beforeRetry = await reopened.read(session: session, request: .source(source))
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: session, operationId: operationIdentifier)
      else { return XCTFail("Native retry must acknowledge the original rename operation.") }
      let afterRetry = await reopened.read(session: session, request: .source(source))
      switch (beforeRetry, afterRetry) {
      case (.source(.category(let before)), .source(.category(let after))):
        XCTAssertEqual(before.content.name, "Applied rename")
        XCTAssertEqual(after.content, before.content)
        XCTAssertEqual(after.updatedAt, before.updatedAt)
        XCTAssertEqual(after.references, before.references)
      case (.source(.tag(let before)), .source(.tag(let after))):
        XCTAssertEqual(before.content.name, "Applied rename")
        XCTAssertEqual(after.content, before.content)
        XCTAssertEqual(after.updatedAt, before.updatedAt)
        XCTAssertEqual(after.references, before.references)
      default: XCTFail("Recovery must retain the same typed label without replay.")
      }
      try await renameLabel(kind: source.kind, identifier: source.id, name: "Allowed rename")
      XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
      XCTAssertFalse(fixture.store.isSaving)
    }
  }

  private func renameLabel(kind: PlannerEntityKind, identifier: UUID, name: String) async throws {
    switch kind {
    case .category:
      let rename = RenamePlannerCategoryIntent()
      rename.category = .init(id: identifier, name: "Cached Category")
      rename.name = name
      let _: Void = try await rename.callAsFunction(donate: false)
    case .tag:
      let rename = RenamePlannerTagIntent()
      rename.tag = .init(id: identifier, name: "Cached Tag")
      rename.name = name
      let _: Void = try await rename.callAsFunction(donate: false)
    default: throw CancellationError()
    }
  }
}

private struct LabelRenameIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let category: PlannerEntityReference
  let tag: PlannerEntityReference
  let item: PlannerEntityReference
  let list: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let schedule: PlannerEntityReference
  let membershipIdentifier: UUID
  let entryIdentifier: UUID
  let form: PlannerScheduleForm
}

@MainActor
private func makeLabelRenameIntentFixture() async throws -> LabelRenameIntentFixture {
  let (_, configuration, store) = try makePlannerIntentStorage()
  AppDependencyManager.shared.add(dependency: store)
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
  let createdCategory = try await save(
    .createCategory(
      content: .init(
        name: "Museums", color: .init(red: 1, green: 0.5, blue: 0, alpha: 1),
        iconName: "building.columns")))
  let category = try XCTUnwrap(createdCategory.generated.first)
  let createdTag = try await save(
    .createTag(
      content: .init(
        name: "rainy-day", color: .init(red: 0, green: 0.5, blue: 1, alpha: 1),
        iconName: "cloud.rain")))
  let tag = try XCTUnwrap(createdTag.generated.first)
  let createdItem = try await save(
    .createItem(
      content: .init(
        title: "Museum", notes: "Keep booking", categoryIds: [category.id], tagIds: [tag.id])))
  let item = try XCTUnwrap(createdItem.generated.first)
  let createdList = try await save(.createList(content: .init(name: "Tokyo Food")))
  let list = try XCTUnwrap(createdList.generated.first)
  let createdMembership = try await save(
    .addMembership(itemId: item.id, listId: list.id, placement: .last))
  guard case .membership(let membership, _, _)? = createdMembership.generatedReferences.first else {
    throw CancellationError()
  }
  _ = try await save(
    .setCompletion(
      scope: .appearance(.listMembership(listId: list.id, membershipId: membership)), done: true))
  let createdItinerary = try await save(
    .createItinerary(
      content: .init(
        title: "Tokyo Weekend", notes: "Keep route", categoryIds: [category.id], tagIds: [tag.id])))
  let itinerary = try XCTUnwrap(createdItinerary.generated.first)
  let added = try await save(
    .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
  guard case .itineraryEntry(let entry, _, _)? = added.generatedReferences.first else {
    throw CancellationError()
  }
  let form = PlannerScheduleForm.allDay(
    start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
  let createdSchedule = try await save(.createSchedule(source: itinerary, form: form))
  let schedule = try XCTUnwrap(createdSchedule.generated.first)
  return .init(
    configuration: configuration, store: store, planner: planner, session: session,
    category: category, tag: tag, item: item, list: list, itinerary: itinerary, schedule: schedule,
    membershipIdentifier: membership, entryIdentifier: entry, form: form)
}
