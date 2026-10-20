import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerRetainedLinkIntentTests: XCTestCase {
  func testEditsKeepExactBookmarkIdentitiesAndDoNotChangeDuplicateSiblingsOrOtherContent()
    async throws
  {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let originalURL = "https://booking.com/reviewed?Ref=%2f"
    let label = "  Réservé · 東京  "
    try await editRetainedLinkUsingIntent(
      owner: fixture.item, link: itemLinks[0], originalURL: originalURL, label: label)
    try await editRetainedLinkUsingIntent(
      owner: fixture.itinerary, link: itineraryLinks[0], originalURL: originalURL, label: label)
    let after = try await readLinkIntentSources(fixture)
    XCTAssertEqual(after.item.content.links.map(\.linkId), before.item.content.links.map(\.linkId))
    XCTAssertEqual(
      after.itinerary.content.links.map(\.linkId), before.itinerary.content.links.map(\.linkId))
    XCTAssertEqual(after.item.content.links[0].originalUrl, originalURL)
    XCTAssertEqual(after.itinerary.content.links[0].originalUrl, originalURL)
    XCTAssertEqual(after.item.content.links[0].label, label)
    XCTAssertEqual(after.itinerary.content.links[0].label, label)
    XCTAssertEqual(after.item.content.links[0].kind, .booking)
    XCTAssertEqual(after.itinerary.content.links[0].kind, .booking)
    XCTAssertNil(after.item.content.links[0].providerReference)
    XCTAssertEqual(
      Array(after.item.content.links.dropFirst()), Array(before.item.content.links.dropFirst()))
    XCTAssertEqual(after.item.references, before.item.references)
    XCTAssertEqual(after.itinerary.references, before.itinerary.references)
    for (field, hash) in before.item.fieldHashes where field != .links {
      XCTAssertEqual(after.item.fieldHashes[field], hash)
    }
    for (field, hash) in before.itinerary.fieldHashes where field != .links {
      XCTAssertEqual(after.itinerary.fieldHashes[field], hash)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let refreshed = try await query.entities(for: [itemLinks[0].id, itineraryLinks[0].id])
    XCTAssertEqual(refreshed.map(\.originalURL), [originalURL, originalURL])
    XCTAssertEqual(refreshed.map(\.label), [label, label])
  }
  func testUnsetFieldsUseCurrentValuesAndEmptyLabelsClearWithoutRestoringCachedOrder() async throws
  {
    let fixture = try await makeLinkIntentFixture()
    for owner in [fixture.item, fixture.itinerary] {
      let ownerLinks = try await readLinksUsingIntent(owner)
      let cached = try XCTUnwrap(ownerLinks.first)
      let before = try await readLinkIntentSources(fixture)
      let links: [PlannerOwnedLinkRead]
      if owner.kind == .item {
        links = before.item.content.links
      } else {
        links = before.itinerary.content.links
      }
      let replacement = links.reversed().map { link in
        if cached.id.hasSuffix(link.linkId.uuidString) {
          return PlannerLinkInput(
            linkId: link.linkId, originalUrl: "https://example.com/newer", label: "Newer label")
        }
        return .init(linkId: link.linkId, originalUrl: link.originalUrl, label: link.label)
      }
      try await replaceRetainedFixtureLinks(owner: owner, links: replacement, fixture: fixture)
      let savedOrder = try await readLinksUsingIntent(owner).map(\.id)
      try await editRetainedLinkUsingIntent(
        owner: owner, link: cached, originalURL: nil, label: "  Updated label  ")
      var current = try await readLinksUsingIntent(owner)
      var edited = try XCTUnwrap(current.first { $0.id == cached.id })
      XCTAssertEqual(current.map(\.id), savedOrder)
      XCTAssertEqual(edited.originalURL, "https://example.com/newer")
      XCTAssertEqual(edited.label, "  Updated label  ")
      try await editRetainedLinkUsingIntent(
        owner: owner, link: cached, originalURL: "https://example.com/reviewed", label: nil)
      current = try await readLinksUsingIntent(owner)
      edited = try XCTUnwrap(current.first { $0.id == cached.id })
      XCTAssertEqual(edited.originalURL, "https://example.com/reviewed")
      XCTAssertEqual(edited.label, "  Updated label  ")
      try await editRetainedLinkUsingIntent(owner: owner, link: cached, originalURL: nil, label: "")
      current = try await readLinksUsingIntent(owner)
      edited = try XCTUnwrap(current.first { $0.id == cached.id })
      XCTAssertNil(edited.label)
      XCTAssertEqual(edited.originalURL, "https://example.com/reviewed")
      XCTAssertEqual(current.map(\.id), savedOrder)
    }
  }

  func testForeignAndRemovedBookmarksNeverFallBackToTheirURLOrAnotherOwner() async throws {
    let fixture = try await makeLinkIntentFixture()
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let original = try await readLinkIntentSources(fixture)
    for (owner, link) in [(fixture.item, itineraryLinks[0]), (fixture.itinerary, itemLinks[0])] {
      do {
        try await editRetainedLinkUsingIntent(
          owner: owner, link: link, originalURL: nil, label: "Must not save")
        XCTFail("A bookmark must belong to the explicitly selected owner.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(original, fixture: fixture)
    XCTAssertEqual(itemLinks[0].originalURL, itemLinks[2].originalURL)
    let replacement = original.item.content.links.dropFirst().map {
      PlannerLinkInput(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
    }
    try await replaceRetainedFixtureLinks(owner: fixture.item, links: replacement, fixture: fixture)
    let afterRemoval = try await readLinkIntentSources(fixture)
    do {
      try await editRetainedLinkUsingIntent(
        owner: fixture.item, link: itemLinks[0], originalURL: nil,
        label: "Must not change the surviving duplicate")
      XCTFail("A removed identity cannot select its same-URL sibling.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    try await assertLinkIntentSourcesUnchanged(afterRemoval, fixture: fixture)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolved = try await query.entities(for: [itemLinks[0].id, itemLinks[2].id])
    XCTAssertEqual(resolved.map(\.id), [itemLinks[2].id])
  }

  func testInvalidOrPrecancelledEditsLeaveBothOwnersUntouched() async throws {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      let ownerLinks = try await readLinksUsingIntent(owner)
      let link = try XCTUnwrap(ownerLinks.first)
      do {
        try await editRetainedLinkUsingIntent(
          owner: owner, link: link, originalURL: nil, label: nil)
        XCTFail("An edit must specify a field to change.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      for originalURL in [
        "", "not a URL", "file:///private/tmp/link", "https:///no-host", "https://example.com/café",
      ] {
        do {
          try await editRetainedLinkUsingIntent(
            owner: owner, link: link, originalURL: originalURL, label: "Must not save")
          XCTFail("Invalid URL and valid label changes must reject together.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      let task = Task {
        try await editRetainedLinkUsingIntent(
          owner: owner, link: link, originalURL: nil, label: "Cancelled")
      }
      task.cancel()
      do {
        try await task.value
        XCTFail("Precancellation cannot apply a bookmark edit.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testEditingArchivedCompletedOwnersPreservesTheirSavedPlansAndBookings() async throws {
    let fixture = try await makeLinkIntentFixture()
    for command in [
      PlannerCommand.setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true),
      .setArchive(source: fixture.item, archived: true),
      .setArchive(source: fixture.itinerary, archived: true),
      .addItineraryEntry(itineraryId: fixture.itinerary.id, source: fixture.item, placement: .last),
    ] { try await applyLinkIntentFixtureCommand(fixture, command) }
    let form = PlannerScheduleForm.allDay(start: .init(year: 2026, month: 10, day: 21), end: nil)
    var schedules: [PlannerEntityReference] = []
    for owner in [fixture.item, fixture.itinerary] {
      let outcome = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(source: owner, form: form))
      ).outcome
      guard case .applied(let applied, .complete) = outcome, let schedule = applied.generated.first
      else { throw CancellationError() }
      schedules.append(schedule)
    }
    let before = try await readLinkIntentSources(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      let ownerLinks = try await readLinksUsingIntent(owner)
      let link = try XCTUnwrap(ownerLinks.first)
      try await editRetainedLinkUsingIntent(
        owner: owner, link: link, originalURL: nil, label: "Reviewed")
    }
    let after = try await readLinkIntentSources(fixture)
    XCTAssertEqual(after.item.state.globalDone, true)
    XCTAssertEqual(after.item.state.archived, true)
    XCTAssertEqual(after.itinerary.state.archived, true)
    XCTAssertEqual(after.item.references, before.item.references)
    XCTAssertEqual(after.itinerary.references, before.itinerary.references)
    XCTAssertEqual(after.itinerary.progress.doneCount, before.itinerary.progress.doneCount)
    XCTAssertEqual(after.itinerary.progress.totalCount, before.itinerary.progress.totalCount)
    XCTAssertEqual(after.itinerary.estimates, before.itinerary.estimates)
    for (schedule, owner) in zip(schedules, [fixture.item, fixture.itinerary]) {
      guard
        case .source(.schedule(let saved)) = await fixture.planner.read(
          session: fixture.session, request: .source(schedule))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content.form, form)
      XCTAssertEqual(saved.content.source, owner)
    }
  }

  func testUnscopedSearchStaysEmptyAndUnavailableStorageDoesNotBecomeSuccessfulChoicesOrEdits()
    async throws
  {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    let ownerLinks = try await readLinksUsingIntent(fixture.item)
    let link = try XCTUnwrap(ownerLinks.first)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let matches = try await query.entities(matching: "Visit")
    let suggestions = try await query.suggestedEntities()
    XCTAssertTrue(matches.isEmpty)
    XCTAssertTrue(suggestions.isEmpty)
    let search = Task { try await query.entities(matching: "Visit") }
    search.cancel()
    do {
      _ = try await search.value
      XCTFail("A cancelled search must fail even before choosing an owner.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    let (directory, _, _) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "blocked-store")
    let obstruction = Data("Retain this actual storage obstruction".utf8)
    try obstruction.write(to: parent)
    let configuration = PlannerStorageConfiguration(
      storeURL: parent.appending(path: "Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let store = SavedPlannerStore(configuration: configuration)
    AppDependencyManager.shared.add(dependency: store)
    query.plannerStore = store
    do {
      _ = try await query.entities(matching: "Visit")
      XCTFail("Unavailable storage cannot return a successful empty picker.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    do {
      try await editRetainedLinkUsingIntent(
        owner: fixture.item, link: link, originalURL: nil, label: "Must not save")
      XCTFail("Unavailable storage cannot claim a saved edit.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
    XCTAssertFalse(store.isReady)
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
  }

  func testPostSaveRecoveryFailureRetainsTheEditAndRepairDoesNotRepeatIt() async throws {
    for ownerKind in [PlannerEntityKind.item, .itinerary] {
      let fixture = try await makeLinkIntentFixture()
      let owner: PlannerEntityReference
      if ownerKind == .item { owner = fixture.item } else { owner = fixture.itinerary }
      let ownerLinks = try await readLinksUsingIntent(owner)
      let cached = try XCTUnwrap(ownerLinks.first)
      await fixture.store.open()
      XCTAssertTrue(fixture.store.isReady)
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) {
        notification in obstruction.observe(notification)
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      try await editRetainedLinkUsingIntent(
        owner: owner, link: cached, originalURL: nil, label: "Committed before recovery failure")
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      let identifier = try XCTUnwrap(fixture.store.incompleteRecoveryOperationIdentifiers.first)
      try obstruction.restore()
      guard
        case .appliedRecoveryIncomplete(let applied, _) = await fixture.planner.operationStatus(
          session: fixture.session, operationId: identifier)
      else {
        return XCTFail("The edit must remain applied while its independent recovery is incomplete.")
      }
      XCTAssertTrue(applied.generatedIdentities.isEmpty)
      XCTAssertEqual(applied.affected, [owner])
      let beforeRepair = try await readLinkIntentSources(fixture)
      let links = try await readLinksUsingIntent(owner)
      let edited = try XCTUnwrap(links.first { $0.id == cached.id })
      XCTAssertEqual(edited.label, "Committed before recovery failure")
      do {
        try await editRetainedLinkUsingIntent(
          owner: owner, link: cached, originalURL: nil, label: "Blocked second edit")
        XCTFail("Recovery must finish before another edit can run.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      try await assertLinkIntentSourcesUnchanged(beforeRepair, fixture: fixture)
      NotificationCenter.default.removeObserver(observer)
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      try await assertLinkIntentSourcesUnchanged(beforeRepair, fixture: fixture)
      guard
        case .appliedRecoveryComplete(let acknowledged, _) = await fixture.planner.operationStatus(
          session: fixture.session, operationId: identifier)
      else { throw CancellationError() }
      XCTAssertEqual(acknowledged, applied)
    }
  }

}

@MainActor
private func editRetainedLinkUsingIntent(
  owner: PlannerEntityReference, link: PlannerLinkEntity, originalURL: String?, label: String?
) async throws {
  if owner.kind == .item {
    let editing = EditPlannerItemLinkIntent()
    editing.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    editing.link = link
    editing.originalURL = originalURL
    editing.label = label
    let _: Void = try await editing.callAsFunction(donate: false)
    return
  }
  let editing = EditPlannerItineraryLinkIntent()
  editing.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: true)
  editing.link = link
  editing.originalURL = originalURL
  editing.label = label
  let _: Void = try await editing.callAsFunction(donate: false)
}

@MainActor
private func replaceRetainedFixtureLinks(
  owner: PlannerEntityReference, links: [PlannerLinkInput], fixture: LinkIntentFixture
) async throws {
  let source = try await readLinkIntentSources(fixture)
  let command: PlannerCommand
  if owner.kind == .item {
    command = .editItem(
      sourceId: owner.id, changes: .init(links: .set(links)),
      expectedFieldHashes: source.item.fieldHashes)
  } else {
    command = .editItinerary(
      sourceId: owner.id, changes: .init(links: .set(links)),
      expectedFieldHashes: source.itinerary.fieldHashes)
  }
  try await applyLinkIntentFixtureCommand(fixture, command)
}
