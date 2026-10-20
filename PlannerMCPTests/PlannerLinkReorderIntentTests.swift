import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerLinkReorderIntentTests: XCTestCase {
  func testAllPositionsUseExactIdentitiesAndRetainEveryBookmarkForBothOwners() async throws {
    let fixture = try await makeReorderLinkIntentFixture()
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    for (owner, links, foreign) in [
      (fixture.item, itemLinks, itineraryLinks[0]),
      (fixture.itinerary, itineraryLinks, itemLinks[0]),
    ] {
      try await reorderLinkUsingIntent(
        owner: owner, link: links[2], position: .before, relativeLink: links[0])
      var current = try await readLinksUsingIntent(owner)
      XCTAssertEqual(current.map(\.id), [links[2].id, links[0].id, links[1].id])
      try await reorderLinkUsingIntent(
        owner: owner, link: links[0], position: .after, relativeLink: links[1])
      current = try await readLinksUsingIntent(owner)
      XCTAssertEqual(current.map(\.id), [links[2].id, links[1].id, links[0].id])
      try await reorderLinkUsingIntent(
        owner: owner, link: links[2], position: .last, relativeLink: foreign)
      current = try await readLinksUsingIntent(owner)
      XCTAssertEqual(current.map(\.id), [links[1].id, links[0].id, links[2].id])
      try await reorderLinkUsingIntent(
        owner: owner, link: links[2], position: .first, relativeLink: nil)
      current = try await readLinksUsingIntent(owner)
      XCTAssertEqual(current.map(\.id), [links[2].id, links[1].id, links[0].id])
      XCTAssertEqual(current.map(\.position), [1, 2, 3])
      XCTAssertEqual(
        current.map(\.originalURL),
        [links[2].originalURL, links[1].originalURL, links[0].originalURL])
      XCTAssertEqual(current.map(\.label), [links[2].label, links[1].label, links[0].label])
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
  func testInvalidTargetsAndRelativeBookmarksCannotPartiallyReorder() async throws {
    let fixture = try await makeReorderLinkIntentFixture()
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let before = try await readLinkIntentSources(fixture)
    for (owner, links, foreign) in [
      (fixture.item, itemLinks, itineraryLinks[0]),
      (fixture.itinerary, itineraryLinks, itemLinks[0]),
    ] {
      let invalidAnchors: [PlannerLinkEntity?] = [nil, foreign, links[0]]
      for position in [PlannerLinkReorderPosition.before, .after] {
        for anchor in invalidAnchors {
          do {
            try await reorderLinkUsingIntent(
              owner: owner, link: links[0], position: position, relativeLink: anchor)
            XCTFail("Before/After require a different live bookmark in the same owner.")
          } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        }
      }
      do {
        try await reorderLinkUsingIntent(
          owner: owner, link: foreign, position: .first, relativeLink: nil)
        XCTFail("A foreign target cannot move an owner's bookmarks.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    for (owner, links) in [(fixture.item, itemLinks), (fixture.itinerary, itineraryLinks)] {
      let current = try await readLinkIntentSources(fixture)
      let saved: [PlannerOwnedLinkRead]
      let moving: PlannerLinkEntity
      if owner.kind == .item {
        saved = current.item.content.links
        moving = links[1]
        XCTAssertEqual(links[0].originalURL, links[2].originalURL)
      } else {
        saved = current.itinerary.content.links
        moving = links[2]
        XCTAssertEqual(links[0].originalURL, links[1].originalURL)
      }
      let replacement = saved.dropFirst().map {
        PlannerLinkInput(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
      }
      try await replaceReorderFixtureLinks(owner: owner, links: replacement, fixture: fixture)
      let afterRemoval = try await readLinkIntentSources(fixture)
      do {
        try await reorderLinkUsingIntent(
          owner: owner, link: moving, position: .before, relativeLink: links[0])
        XCTFail("A removed anchor cannot resolve to its surviving same-URL sibling.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      try await assertLinkIntentSourcesUnchanged(afterRemoval, fixture: fixture)
    }
  }

  func testInactiveAnchorsAndCachedValuesNeverRestoreRemovedBookmarksOrOldContent() async throws {
    let fixture = try await makeReorderLinkIntentFixture()
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    for (owner, links, foreign) in [
      (fixture.item, itemLinks, itineraryLinks[0]),
      (fixture.itinerary, itineraryLinks, itemLinks[0]),
    ] {
      let before = try await readLinkIntentSources(fixture)
      let saved: [PlannerOwnedLinkRead]
      if owner.kind == .item {
        saved = before.item.content.links
      } else {
        saved = before.itinerary.content.links
      }
      let replacement = saved.reversed().map {
        PlannerLinkInput(
          linkId: $0.linkId, originalUrl: "https://example.com/current/" + $0.linkId.uuidString,
          label: "Newer label")
      }
      try await replaceReorderFixtureLinks(owner: owner, links: replacement, fixture: fixture)
      try await reorderLinkUsingIntent(
        owner: owner, link: links[0], position: .first, relativeLink: links[0])
      var current = try await readLinksUsingIntent(owner)
      XCTAssertEqual(current.map(\.id), [links[0].id, links[2].id, links[1].id])
      let retained = current.filter { $0.id != links[2].id }
      let coreInputs = saved.prefix(2).map {
        PlannerLinkInput(
          linkId: $0.linkId, originalUrl: "https://example.com/current/" + $0.linkId.uuidString,
          label: "Newer label")
      }
      try await replaceReorderFixtureLinks(owner: owner, links: coreInputs, fixture: fixture)
      try await reorderLinkUsingIntent(
        owner: owner, link: links[1], position: .first, relativeLink: links[2])
      current = try await readLinksUsingIntent(owner)
      XCTAssertEqual(current.map(\.id), [links[1].id, links[0].id])
      XCTAssertEqual(
        current.map(\.originalURL), [retained[1].originalURL, retained[0].originalURL])
      XCTAssertEqual(current.map(\.label), ["Newer label", "Newer label"])
      try await reorderLinkUsingIntent(
        owner: owner, link: links[1], position: .last, relativeLink: links[2])
      current = try await readLinksUsingIntent(owner)
      XCTAssertEqual(current.map(\.id), [links[0].id, links[1].id])
      try await reorderLinkUsingIntent(
        owner: owner, link: links[1], position: .last, relativeLink: foreign)
      let repeated = try await readLinksUsingIntent(owner)
      XCTAssertEqual(repeated.map(\.id), current.map(\.id))
      XCTAssertEqual(repeated.map(\.originalURL), current.map(\.originalURL))
      XCTAssertEqual(repeated.map(\.label), current.map(\.label))
    }
  }

  func testCancelledAndUnavailableReordersLeaveTheSavedCollectionUntouched() async throws {
    let fixture = try await makeReorderLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let targets = [(fixture.item, itemLinks[0]), (fixture.itinerary, itineraryLinks[0])]
    for (owner, link) in targets {
      let request = Task {
        try await reorderLinkUsingIntent(
          owner: owner, link: link, position: .last, relativeLink: nil)
      }
      request.cancel()
      do {
        try await request.value
        XCTFail("A precancelled reorder cannot apply.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    let (directory, _, _) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "blocked-store")
    let obstruction = Data("Retain this unavailable storage".utf8)
    try obstruction.write(to: parent)
    let configuration = PlannerStorageConfiguration(
      storeURL: parent.appending(path: "Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let store = SavedPlannerStore(configuration: configuration)
    AppDependencyManager.shared.add(dependency: store)
    for (owner, link) in targets {
      do {
        try await reorderLinkUsingIntent(
          owner: owner, link: link, position: .last, relativeLink: nil)
        XCTFail("Unavailable storage cannot report a saved reorder.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
    XCTAssertFalse(store.isReady)
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
  }

  func testReorderingArchivedPlansPreservesDataAndBookingsWhileRecoveryAcknowledgesOnce()
    async throws
  {
    for ownerKind in [PlannerEntityKind.item, .itinerary] {
      let fixture = try await makeReorderLinkIntentFixture()
      let owner: PlannerEntityReference
      if ownerKind == .item { owner = fixture.item } else { owner = fixture.itinerary }
      for command in [
        PlannerCommand.setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true),
        .setArchive(source: fixture.item, archived: true),
        .setArchive(source: fixture.itinerary, archived: true),
        .addItineraryEntry(
          itineraryId: fixture.itinerary.id, source: fixture.item, placement: .last),
      ] { try await applyLinkIntentFixtureCommand(fixture, command) }
      let form = PlannerScheduleForm.allDay(start: .init(year: 2026, month: 10, day: 21), end: nil)
      let scheduled = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(source: owner, form: form))
      ).outcome
      guard case .applied(let created, .complete) = scheduled,
        let schedule = created.generated.first
      else { throw CancellationError() }
      let before = try await readLinkIntentSources(fixture)
      let links = try await readLinksUsingIntent(owner)
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
      try await reorderLinkUsingIntent(
        owner: owner, link: links[2], position: .first, relativeLink: nil)
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      let reordered = try await readLinksUsingIntent(owner)
      XCTAssertEqual(reordered.map(\.id), [links[2].id, links[0].id, links[1].id])
      XCTAssertEqual(
        reordered.map(\.originalURL),
        [links[2].originalURL, links[0].originalURL, links[1].originalURL])
      let current = try await readLinkIntentSources(fixture)
      XCTAssertEqual(current.item.state.globalDone, true)
      XCTAssertEqual(current.item.state.archived, true)
      XCTAssertEqual(current.itinerary.state.archived, true)
      XCTAssertEqual(current.itinerary.progress.doneCount, before.itinerary.progress.doneCount)
      XCTAssertEqual(current.itinerary.progress.totalCount, before.itinerary.progress.totalCount)
      XCTAssertEqual(current.itinerary.estimates, before.itinerary.estimates)
      for (field, hash) in before.item.fieldHashes where field != .links {
        XCTAssertEqual(current.item.fieldHashes[field], hash)
      }
      for (field, hash) in before.itinerary.fieldHashes where field != .links {
        XCTAssertEqual(current.itinerary.fieldHashes[field], hash)
      }
      guard
        case .source(.schedule(let retainedSchedule)) = await fixture.planner.read(
          session: fixture.session, request: .source(schedule))
      else { throw CancellationError() }
      XCTAssertEqual(retainedSchedule.content.form, form)
      XCTAssertEqual(retainedSchedule.content.source, owner)
      try obstruction.restore()
      guard
        case .appliedRecoveryIncomplete(let applied, _) = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { throw CancellationError() }
      XCTAssertTrue(applied.generatedIdentities.isEmpty)
      XCTAssertEqual(applied.affected, [owner])
      do {
        try await reorderLinkUsingIntent(
          owner: owner, link: links[0], position: .last, relativeLink: nil)
        XCTFail("A second reorder must wait for recovery.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      try await assertLinkIntentSourcesUnchanged(current, fixture: fixture)
      NotificationCenter.default.removeObserver(observer)
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      try await assertLinkIntentSourcesUnchanged(current, fixture: fixture)
      guard
        case .appliedRecoveryComplete(let acknowledged, _) = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { throw CancellationError() }
      XCTAssertEqual(acknowledged, applied)
    }
  }

}

@MainActor
private func reorderLinkUsingIntent(
  owner: PlannerEntityReference, link: PlannerLinkEntity, position: PlannerLinkReorderPosition,
  relativeLink: PlannerLinkEntity?
) async throws {
  if owner.kind == .item {
    let reordering = ReorderPlannerItemLinkIntent()
    reordering.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    reordering.link = link
    reordering.position = position
    reordering.relativeLink = relativeLink
    let _: Void = try await reordering.callAsFunction(donate: false)
    return
  }
  let reordering = ReorderPlannerItineraryLinkIntent()
  reordering.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: true)
  reordering.link = link
  reordering.position = position
  reordering.relativeLink = relativeLink
  let _: Void = try await reordering.callAsFunction(donate: false)
}

@MainActor
private func makeReorderLinkIntentFixture() async throws -> LinkIntentFixture {
  let fixture = try await makeLinkIntentFixture()
  let before = try await readLinkIntentSources(fixture)
  try await applyLinkIntentFixtureCommand(
    fixture,
    .editItinerary(
      sourceId: fixture.itinerary.id,
      changes: .init(
        links: .set([
          .init(
            linkId: before.itinerary.content.links[0].linkId,
            originalUrl: "https://example.com/route", label: "First"),
          .init(originalUrl: "https://example.com/route", label: "Second"),
          .init(originalUrl: "https://example.com/last", label: nil),
        ])), expectedFieldHashes: before.itinerary.fieldHashes))
  return fixture
}

@MainActor
private func replaceReorderFixtureLinks(
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
