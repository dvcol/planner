import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerLinkRemovalIntentTests: XCTestCase {
  func testRemovingOneBookmarkKeepsDuplicateSiblingAndBothOwnerSources() async throws {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    XCTAssertEqual(itemLinks[0].originalURL, itemLinks[2].originalURL)
    try await removeLinkUsingIntent(owner: fixture.item, link: itemLinks[0])
    try await removeLinkUsingIntent(owner: fixture.itinerary, link: itineraryLinks[0])
    let after = try await readLinkIntentSources(fixture)
    XCTAssertEqual(after.item.content.links, Array(before.item.content.links.dropFirst()))
    XCTAssertTrue(after.itinerary.content.links.isEmpty)
    XCTAssertEqual(after.item.sourceLifetimeId, before.item.sourceLifetimeId)
    XCTAssertEqual(after.itinerary.sourceLifetimeId, before.itinerary.sourceLifetimeId)
    let removedItemLink = PlannerReferenceRead.ownedLink(
      id: before.item.content.links[0].linkId, owner: fixture.item)
    let removedItineraryLink = PlannerReferenceRead.ownedLink(
      id: before.itinerary.content.links[0].linkId, owner: fixture.itinerary)
    XCTAssertEqual(after.item.references, before.item.references.filter { $0 != removedItemLink })
    XCTAssertEqual(
      after.itinerary.references, before.itinerary.references.filter { $0 != removedItineraryLink })
    for (field, hash) in before.item.fieldHashes where field != .links {
      XCTAssertEqual(after.item.fieldHashes[field], hash)
    }
    for (field, hash) in before.itinerary.fieldHashes where field != .links {
      XCTAssertEqual(after.itinerary.fieldHashes[field], hash)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolved = try await query.entities(for: [
      itemLinks[0].id, itineraryLinks[0].id, itemLinks[2].id,
    ])
    XCTAssertEqual(resolved.map(\.id), [itemLinks[2].id])
  }
  func testRemovalUsesCurrentIdentityAfterSavedContentAndOrderChanged() async throws {
    let fixture = try await makeLinkIntentFixture()
    for owner in [fixture.item, fixture.itinerary] {
      let cached = try await readLinksUsingIntent(owner)
      let target = try XCTUnwrap(cached.first)
      let source = try await readLinkIntentSources(fixture)
      let links: [PlannerOwnedLinkRead]
      if owner.kind == .item {
        links = source.item.content.links
      } else {
        links = source.itinerary.content.links
      }
      let replacement = links.reversed().map { link in
        if target.id.hasSuffix(link.linkId.uuidString) {
          return PlannerLinkInput(
            linkId: link.linkId, originalUrl: "https://example.com/newer-target",
            label: "Newer label")
        }
        return .init(linkId: link.linkId, originalUrl: link.originalUrl, label: link.label)
      }
      try await replaceRemovalFixtureLinks(owner: owner, links: replacement, fixture: fixture)
      let current = try await readLinksUsingIntent(owner)
      try await removeLinkUsingIntent(owner: owner, link: target)
      let after = try await readLinksUsingIntent(owner)
      XCTAssertEqual(after.map(\.id), current.filter { $0.id != target.id }.map(\.id))
      XCTAssertEqual(
        after.map(\.originalURL), current.filter { $0.id != target.id }.map(\.originalURL))
      XCTAssertEqual(after.map(\.label), current.filter { $0.id != target.id }.map(\.label))
    }
  }

  func testForeignAndAlreadyRemovedIdentitiesCannotRemoveAnotherBookmark() async throws {
    let fixture = try await makeLinkIntentFixture()
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let before = try await readLinkIntentSources(fixture)
    for (owner, link) in [(fixture.item, itineraryLinks[0]), (fixture.itinerary, itemLinks[0])] {
      do {
        try await removeLinkUsingIntent(owner: owner, link: link)
        XCTFail("A bookmark must belong to its selected owner.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    for (owner, link) in [(fixture.item, itemLinks[0]), (fixture.itinerary, itineraryLinks[0])] {
      try await removeLinkUsingIntent(owner: owner, link: link)
      let current = try await readLinkIntentSources(fixture)
      do {
        try await removeLinkUsingIntent(owner: owner, link: link)
        XCTFail("Repeating removal cannot select another bookmark with the same URL.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      try await assertLinkIntentSourcesUnchanged(current, fixture: fixture)
    }
  }

  func testCancelledAndUnavailableRemovalsCannotAcknowledgeAChange() async throws {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let targets = [(fixture.item, itemLinks[0]), (fixture.itinerary, itineraryLinks[0])]
    for (owner, link) in targets {
      let request = Task { try await removeLinkUsingIntent(owner: owner, link: link) }
      request.cancel()
      do {
        try await request.value
        XCTFail("A precancelled removal cannot apply.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    let (directory, _, _) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "blocked-store")
    let obstruction = Data("Keep this filesystem obstruction".utf8)
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
        try await removeLinkUsingIntent(owner: owner, link: link)
        XCTFail("Unavailable storage cannot report a removed Link.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
    XCTAssertFalse(store.isReady)
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
  }

  func testRemovalPreservesPlansWhileRecoveryIsRepairedWithoutRepeatingIt() async throws {
    for ownerKind in [PlannerEntityKind.item, .itinerary] {
      let fixture = try await makeLinkIntentFixture()
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
      guard case .applied(let createdSchedule, .complete) = scheduled,
        let schedule = createdSchedule.generated.first
      else { throw CancellationError() }
      let before = try await readLinkIntentSources(fixture)
      let links = try await readLinksUsingIntent(owner)
      let target = try XCTUnwrap(links.first)
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
      try await removeLinkUsingIntent(owner: owner, link: target)
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      let current = try await readLinkIntentSources(fixture)
      XCTAssertEqual(current.item.state.globalDone, true)
      XCTAssertEqual(current.item.state.archived, true)
      XCTAssertEqual(current.itinerary.state.archived, true)
      XCTAssertEqual(current.itinerary.progress.doneCount, before.itinerary.progress.doneCount)
      XCTAssertEqual(current.itinerary.progress.totalCount, before.itinerary.progress.totalCount)
      XCTAssertEqual(current.itinerary.estimates, before.itinerary.estimates)
      let remaining = try await readLinksUsingIntent(owner)
      XCTAssertEqual(remaining.map(\.id), links.dropFirst().map(\.id))
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
      XCTAssertEqual(applied.affectedReferences.count, 1)
      do {
        if ownerKind == .item {
          let adding = AddPlannerItemLinkIntent()
          adding.item = .init(id: owner.id, title: "Cached", done: false, archived: false)
          adding.originalURL = "https://example.com/blocked"
          let _: PlannerLinkEntity = try await adding.callAsFunction(donate: false)
        } else {
          let adding = AddPlannerItineraryLinkIntent()
          adding.itinerary = .init(id: owner.id, title: "Cached", archived: false)
          adding.originalURL = "https://example.com/blocked"
          let _: PlannerLinkEntity = try await adding.callAsFunction(donate: false)
        }
        XCTFail("Recovery must finish before another bookmark mutation can apply.")
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
private func removeLinkUsingIntent(owner: PlannerEntityReference, link: PlannerLinkEntity)
  async throws
{
  if owner.kind == .item {
    let removal = RemovePlannerItemLinkIntent()
    removal.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    removal.link = link
    let _: Void = try await removal.callAsFunction(donate: false)
    return
  }
  let removal = RemovePlannerItineraryLinkIntent()
  removal.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: true)
  removal.link = link
  let _: Void = try await removal.callAsFunction(donate: false)
}

@MainActor
private func replaceRemovalFixtureLinks(
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
