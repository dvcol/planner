import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerLinkIntentTests: XCTestCase {
  func testAddingBookmarksReturnsExactSavedIdentitiesAndAuthoredValuesForBothOwnerKinds()
    async throws
  {
    let fixture = try await makeLinkIntentFixture()
    let original = try await readLinkIntentSources(fixture)
    let originalURL = "https://example.com/Guide?Ref=%2f&Ref=A#Room"
    let addingItem = AddPlannerItemLinkIntent()
    addingItem.item = .init(id: fixture.item.id, title: "Cached", done: true, archived: true)
    addingItem.originalURL = originalURL
    addingItem.label = "  Guide  "
    let itemLink = try await addingItem.callAsFunction(donate: false)
    let addingItinerary = AddPlannerItineraryLinkIntent()
    addingItinerary.itinerary = .init(id: fixture.itinerary.id, title: "Cached", archived: true)
    addingItinerary.originalURL = originalURL
    addingItinerary.label = ""
    let itineraryLink = try await addingItinerary.callAsFunction(donate: false)
    let current = try await readLinkIntentSources(fixture)
    let savedItemLink = try XCTUnwrap(current.item.content.links.last)
    let savedItineraryLink = try XCTUnwrap(current.itinerary.content.links.last)
    XCTAssertEqual(
      itemLink.id, "item:\(fixture.item.id.uuidString):\(savedItemLink.linkId.uuidString)")
    XCTAssertEqual(
      itineraryLink.id,
      "itinerary:\(fixture.itinerary.id.uuidString):\(savedItineraryLink.linkId.uuidString)")
    XCTAssertEqual(itemLink.originalURL, originalURL)
    XCTAssertEqual(itineraryLink.originalURL, originalURL)
    XCTAssertEqual(itemLink.url.absoluteString, originalURL)
    XCTAssertEqual(itineraryLink.url.absoluteString, originalURL)
    XCTAssertEqual(itemLink.label, "  Guide  ")
    XCTAssertEqual(itineraryLink.label, "")
    XCTAssertEqual(itemLink.ownerTitle, "Museum")
    XCTAssertEqual(itineraryLink.ownerTitle, "Weekend")
    XCTAssertEqual(itemLink.position, 4)
    XCTAssertEqual(itineraryLink.position, 2)
    XCTAssertNotEqual(savedItemLink.linkId, original.item.content.links[1].linkId)
    XCTAssertEqual(Array(current.item.content.links.dropLast()), original.item.content.links)
    XCTAssertEqual(
      Array(current.itinerary.content.links.dropLast()), original.itinerary.content.links)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolved = try await query.entities(for: [itemLink.id, itineraryLink.id])
    XCTAssertEqual(resolved.map(\.id), [itemLink.id, itineraryLink.id])
  }

  func testAddingDuplicateURLsWithNilLabelsPreservesContentStatesReferencesAndBookings()
    async throws
  {
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
      let response = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(source: owner, form: form)))
      guard case .applied(let applied, .complete) = response.outcome,
        let schedule = applied.generated.first
      else { throw CancellationError() }
      schedules.append(schedule)
    }
    let before = try await readLinkIntentSources(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      let first = try await addLinkUsingIntent(
        owner, originalURL: "https://example.com/duplicate", label: nil)
      let second = try await addLinkUsingIntent(
        owner, originalURL: "https://example.com/duplicate", label: nil)
      XCTAssertNotEqual(first.id, second.id)
      XCTAssertNil(first.label)
      XCTAssertNil(second.label)
      XCTAssertEqual(second.position, first.position + 1)
    }
    let after = try await readLinkIntentSources(fixture)
    XCTAssertEqual(Array(after.item.content.links.dropLast(2)), before.item.content.links)
    XCTAssertEqual(Array(after.itinerary.content.links.dropLast(2)), before.itinerary.content.links)
    XCTAssertEqual(after.item.sourceLifetimeId, before.item.sourceLifetimeId)
    XCTAssertEqual(after.itinerary.sourceLifetimeId, before.itinerary.sourceLifetimeId)
    func nonBookmarkReferences(_ references: [PlannerReferenceRead]) -> [PlannerReferenceRead] {
      references.filter {
        if case .ownedLink = $0 { return false }
        return true
      }
    }
    XCTAssertEqual(
      nonBookmarkReferences(after.item.references), nonBookmarkReferences(before.item.references))
    XCTAssertEqual(
      nonBookmarkReferences(after.itinerary.references),
      nonBookmarkReferences(before.itinerary.references))
    XCTAssertEqual(after.item.state.globalDone, true)
    XCTAssertEqual(after.item.state.archived, true)
    XCTAssertEqual(after.itinerary.state.archived, true)
    XCTAssertEqual(after.itinerary.progress.totalCount, before.itinerary.progress.totalCount)
    XCTAssertEqual(after.itinerary.progress.doneCount, before.itinerary.progress.doneCount)
    XCTAssertEqual(after.itinerary.progress.state, before.itinerary.progress.state)
    XCTAssertEqual(after.itinerary.estimates, before.itinerary.estimates)
    for (field, hash) in before.item.fieldHashes where field != .links {
      XCTAssertEqual(after.item.fieldHashes[field], hash)
    }
    for (field, hash) in before.itinerary.fieldHashes where field != .links {
      XCTAssertEqual(after.itinerary.fieldHashes[field], hash)
    }
    for (schedule, owner) in zip(schedules, [fixture.item, fixture.itinerary]) {
      guard
        case .source(.schedule(let saved)) = await fixture.planner.read(
          session: fixture.session, request: .source(schedule))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content.form, form)
      XCTAssertEqual(saved.content.source, owner)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testInvalidLinkInputsAndMissingOwnersDoNotApplyPartialEdits() async throws {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      for originalURL in [
        "", "not a URL", "file:///private/tmp/bookmark", "https:///no-host",
        "https://example.com/café",
      ] {
        do {
          _ = try await addLinkUsingIntent(owner, originalURL: originalURL, label: "Must not save")
          XCTFail("Invalid authored URL text cannot allocate a saved bookmark.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    for owner in [
      PlannerEntityReference(kind: .item, id: UUID()), .init(kind: .itinerary, id: UUID()),
      .init(kind: .item, id: fixture.itinerary.id), .init(kind: .itinerary, id: fixture.item.id),
    ] {
      do {
        _ = try await addLinkUsingIntent(owner, originalURL: "https://example.com/new", label: nil)
        XCTFail("A missing or mismatched typed owner cannot redirect an addition.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testPrecancelledAdditionsLeaveBothOwnersUntouched() async throws {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      let request = Task {
        try await addLinkUsingIntent(
          owner, originalURL: "https://example.com/cancelled", label: nil)
      }
      request.cancel()
      do {
        _ = try await request.value
        XCTFail("An addition cancelled before execution cannot report a saved Link.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testAdditionsFailWhenBootstrapStorageIsUnavailable() async throws {
    let (directory, _, _) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "blocked-store")
    let obstruction = Data("Keep this real filesystem obstruction".utf8)
    try obstruction.write(to: parent)
    let configuration = PlannerStorageConfiguration(
      storeURL: parent.appending(path: "Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let store = SavedPlannerStore(configuration: configuration)
    AppDependencyManager.shared.add(dependency: store)
    for owner in [
      PlannerEntityReference(kind: .item, id: UUID()), .init(kind: .itinerary, id: UUID()),
    ] {
      do {
        _ = try await addLinkUsingIntent(owner, originalURL: "https://example.com/new", label: nil)
        XCTFail("Unavailable storage cannot report a newly saved bookmark.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testAddedBookmarkIdentitySurvivesPostSaveRecoveryFailureWithoutASecondMutation() async throws
  {
    for ownerKind in [PlannerEntityKind.item, .itinerary] {
      let fixture = try await makeLinkIntentFixture()
      await fixture.store.open()
      XCTAssertTrue(fixture.store.isReady)
      let owner: PlannerEntityReference
      if ownerKind == .item { owner = fixture.item } else { owner = fixture.itinerary }
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
      let added = try await addLinkUsingIntent(
        owner, originalURL: "https://example.com/saved-before-failure", label: "Keep")
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      try obstruction.restore()
      guard
        case .appliedRecoveryIncomplete(let applied, _) = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else {
        return XCTFail(
          "The returned Link must belong to the locally applied edit awaiting recovery.")
      }
      let expected = applied.generatedReferences.compactMap { reference -> UUID? in
        guard case .ownedLink(let identifier, let savedOwner) = reference, savedOwner == owner
        else { return nil }
        return identifier
      }
      XCTAssertEqual(expected.count, 1)
      XCTAssertEqual(
        added.id,
        "\(owner.kind.rawValue):\(owner.id.uuidString):\(try XCTUnwrap(expected.first).uuidString)")
      let beforeRepair = try await readLinkIntentSources(fixture)
      let links = try await readLinksUsingIntent(owner)
      XCTAssertEqual(links.last?.id, added.id)
      do {
        _ = try await addLinkUsingIntent(
          owner, originalURL: "https://example.com/blocked", label: nil)
        XCTFail("Incomplete recovery must block another addition without losing the first Link.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      try await assertLinkIntentSourcesUnchanged(beforeRepair, fixture: fixture)
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      try await assertLinkIntentSourcesUnchanged(beforeRepair, fixture: fixture)
      guard
        case .appliedRecoveryComplete(let acknowledged, _) = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { throw CancellationError() }
      XCTAssertEqual(acknowledged, applied)
    }
  }

  func testItemLinkReadReturnsSavedOrderExactURLsAndDistinctDuplicateIdentitiesAfterReopen()
    async throws
  {
    let fixture = try await makeLinkIntentFixture()
    guard
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.item))
    else { throw CancellationError() }
    let reading = GetPlannerItemLinksIntent()
    reading.item = .init(id: fixture.item.id, title: "Cached title", done: true, archived: true)
    let links = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(links.count, 3)
    XCTAssertEqual(
      links.map(\.originalURL),
      [
        "https://maps.apple.com/?q=Nezu%20Museum&place-id=fixture-nezu",
        "https://example.com/Guide?Ref=%2f&Ref=A#Room",
        "https://maps.apple.com/?q=Nezu%20Museum&place-id=fixture-nezu",
      ])
    XCTAssertEqual(links.map(\.label), ["Visit", nil, "Visit"])
    XCTAssertEqual(links.map(\.ownerTitle), ["Museum", "Museum", "Museum"])
    XCTAssertEqual(links.map(\.position), [1, 2, 3])
    XCTAssertEqual(links[1].url.absoluteString, "https://example.com/Guide?Ref=%2f&Ref=A#Room")
    XCTAssertEqual(Set(links.map(\.id)).count, 3)
    XCTAssertEqual(
      links.map(\.id),
      before.content.links.map {
        "item:\(fixture.item.id.uuidString):\($0.linkId.uuidString)"
      })
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let after)) = await reopened.read(
        session: session, request: .source(fixture.item))
    else { return XCTFail("An ordinary Link read must preserve its owner after reopening.") }
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.content.links, before.content.links)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolved = try await query.entities(for: [links[2].id, links[0].id, links[2].id])
    XCTAssertEqual(resolved.map(\.id), [links[2].id, links[0].id])
    XCTAssertEqual(resolved.map(\.position), [3, 1])
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
  func testItineraryLinkReadKeepsItsOwnBookmarksSeparateFromReferencedItems() async throws {
    let fixture = try await makeLinkIntentFixture()
    let added = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .addItineraryEntry(
          itineraryId: fixture.itinerary.id, source: fixture.item, placement: .last)))
    guard case .applied(_, .complete) = added.outcome,
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.itinerary))
    else { throw CancellationError() }
    let reading = GetPlannerItineraryLinksIntent()
    reading.itinerary = .init(id: fixture.itinerary.id, title: "Cached route", archived: true)
    let links = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(links.count, 1)
    XCTAssertEqual(links[0].originalURL, "https://example.com/route")
    XCTAssertEqual(links[0].url.absoluteString, "https://example.com/route")
    XCTAssertEqual(links[0].label, "Route")
    XCTAssertEqual(links[0].ownerTitle, "Weekend")
    XCTAssertEqual(links[0].position, 1)
    XCTAssertEqual(
      links[0].id,
      "itinerary:\(fixture.itinerary.id.uuidString):\(before.content.links[0].linkId.uuidString)")
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let after)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item))
    else { return XCTFail("Reading itinerary bookmarks must retain its live source references.") }
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(item.content.links.count, 3)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolved = try await query.entities(for: [links[0].id])
    XCTAssertEqual(resolved.map(\.originalURL), ["https://example.com/route"])
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
  func testNativeURLsKeepExactEscapedTextAndDistinctUnicodeOrEmptyLabels() async throws {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    let original = "https://example.com/caf%C3%A9?note=%C3%A9t%C3%A9&Ref=%2f#entr%C3%A9e"
    let saved = before.item.content.links
    let replacement: [PlannerLinkInput] = [
      .init(linkId: saved[0].linkId, originalUrl: original, label: ""),
      .init(linkId: saved[1].linkId, originalUrl: saved[1].originalUrl, label: nil),
      .init(linkId: saved[2].linkId, originalUrl: saved[2].originalUrl, label: "  Réservé  "),
    ]
    try await applyLinkIntentFixtureCommand(
      fixture,
      .editItem(
        sourceId: fixture.item.id,
        changes: .init(links: .set(replacement)), expectedFieldHashes: before.item.fieldHashes))
    let current = try await readLinkIntentSources(fixture)
    let links = try await readLinksUsingIntent(fixture.item)
    XCTAssertEqual(links[0].originalURL, original)
    XCTAssertEqual(
      links[0].url.absoluteString,
      "https://example.com/caf%C3%A9?note=%C3%A9t%C3%A9&Ref=%2f#entr%C3%A9e")
    XCTAssertEqual(links.map(\.label), ["", nil, "  Réservé  "])
    XCTAssertEqual(links[0].id, "item:\(fixture.item.id.uuidString):\(saved[0].linkId.uuidString)")
    try await assertLinkIntentSourcesUnchanged(current, fixture: fixture)
  }

  func testIdentityResolutionRefreshesOwnerTitleURLLabelAndSavedPosition() async throws {
    let fixture = try await makeLinkIntentFixture()
    let originalItem = try await readLinksUsingIntent(fixture.item)
    let originalItinerary = try await readLinksUsingIntent(fixture.itinerary)
    let before = try await readLinkIntentSources(fixture)
    let saved = before.item.content.links
    try await applyLinkIntentFixtureCommand(
      fixture,
      .editItem(
        sourceId: fixture.item.id,
        changes: .init(
          title: .set("Renamed Museum"),
          links: .set([
            .init(
              linkId: saved[2].linkId, originalUrl: "https://example.com/updated", label: "Changed"),
            .init(
              linkId: saved[0].linkId, originalUrl: saved[0].originalUrl, label: saved[0].label),
            .init(
              linkId: saved[1].linkId, originalUrl: saved[1].originalUrl, label: saved[1].label),
          ])), expectedFieldHashes: before.item.fieldHashes))
    try await applyLinkIntentFixtureCommand(
      fixture,
      .editItinerary(
        sourceId: fixture.itinerary.id,
        changes: .init(title: .set("Renamed Weekend")),
        expectedFieldHashes: before.itinerary.fieldHashes))
    let current = try await readLinkIntentSources(fixture)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolved = try await query.entities(for: [
      originalItinerary[0].id, originalItem[0].id,
      originalItem[2].id, originalItinerary[0].id,
    ])
    XCTAssertEqual(
      resolved.map(\.id), [originalItinerary[0].id, originalItem[0].id, originalItem[2].id])
    XCTAssertEqual(
      resolved.map(\.ownerTitle), ["Renamed Weekend", "Renamed Museum", "Renamed Museum"])
    XCTAssertEqual(resolved.map(\.position), [1, 2, 1])
    XCTAssertEqual(resolved.map(\.label), ["Route", "Visit", "Changed"])
    XCTAssertEqual(resolved[2].url.absoluteString, "https://example.com/updated")
    XCTAssertEqual(resolved[2].originalURL, "https://example.com/updated")
    try await assertLinkIntentSourcesUnchanged(current, fixture: fixture)
  }

  func testMalformedForeignAndWrongKindIdentitiesNeverResolveByURLOrOtherOwner() async throws {
    let fixture = try await makeLinkIntentFixture()
    let current = try await readLinkIntentSources(fixture)
    let links = try await readLinksUsingIntent(fixture.item)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let linkIdentifier = current.item.content.links[0].linkId.uuidString
    let invalid = [
      "", "not-a-link", links[0].id + ":extra",
      "item::\(linkIdentifier)", "item:invalid:\(linkIdentifier)",
      "list:\(fixture.item.id.uuidString):\(linkIdentifier)",
      "itinerary:\(fixture.itinerary.id.uuidString):\(linkIdentifier)",
      "item:\(UUID().uuidString):\(linkIdentifier)",
    ]
    let missing = try await query.entities(for: invalid)
    XCTAssertTrue(missing.isEmpty)
    let resolved = try await query.entities(
      for: invalid + [links[1].id.lowercased(), links[0].id, links[1].id])
    XCTAssertEqual(resolved.map(\.id), [links[1].id, links[0].id])
    let suggestions = try await query.suggestedEntities()
    XCTAssertTrue(suggestions.isEmpty)
    for owner in [
      PlannerEntityReference(kind: .item, id: fixture.itinerary.id),
      .init(kind: .itinerary, id: fixture.item.id), .init(kind: .item, id: UUID()),
      .init(kind: .itinerary, id: UUID()),
    ] {
      do {
        _ = try await readLinksUsingIntent(owner)
        XCTFail("A missing or wrong-kind owner cannot appear to have an empty Link collection.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    try await assertLinkIntentSourcesUnchanged(current, fixture: fixture)
  }

  func testRemovedBookmarkAndDeletedOwnersStayMissingWithoutDuplicateURLFallback() async throws {
    let fixture = try await makeLinkIntentFixture()
    let original = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let before = try await readLinkIntentSources(fixture)
    let retained = before.item.content.links.dropFirst().map {
      PlannerLinkInput(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
    }
    try await applyLinkIntentFixtureCommand(
      fixture,
      .editItem(
        sourceId: fixture.item.id,
        changes: .init(links: .set(retained)), expectedFieldHashes: before.item.fieldHashes))
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let surviving = try await query.entities(for: [original[0].id, original[2].id])
    XCTAssertEqual(surviving.map(\.id), [original[2].id])
    XCTAssertEqual(surviving[0].position, 2)
    XCTAssertEqual(surviving[0].originalURL, original[0].originalURL)
    for owner in [fixture.item, fixture.itinerary] {
      let command = PlannerCommand.deleteSource(source: owner)
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: command),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(),
            session: fixture.session, command: command, reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
      do {
        _ = try await readLinksUsingIntent(owner)
        XCTFail("A deleted owner must not be recreated by reading its bookmarks.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let missing = try await query.entities(for: original.map(\.id) + itineraryLinks.map(\.id))
    XCTAssertTrue(missing.isEmpty)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testExistingEmptyOwnersReturnEmptyCollectionsWithoutReadFailure() async throws {
    let fixture = try await makeLinkIntentFixture()
    for command in [
      PlannerCommand.createItem(content: .init(title: "Empty Item")),
      .createItinerary(content: .init(title: "Empty Itinerary")),
    ] {
      let created = await fixture.planner.execute(
        .init(operationId: UUID(), session: fixture.session, command: command))
      guard case .applied(let result, .complete) = created.outcome,
        let owner = result.generated.first
      else { throw CancellationError() }
      let links = try await readLinksUsingIntent(owner)
      XCTAssertTrue(links.isEmpty)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testBothOwnersReturnEveryBookmarkBeyondTheFirstSixtyFour() async throws {
    let fixture = try await makeLinkIntentFixture()
    let input = (0..<130).map { index in
      PlannerLinkInput(
        originalUrl: "https://example.com/bookmark/\(index)", label: "Bookmark \(index)")
    }
    for command in [
      PlannerCommand.createItem(content: .init(title: "Long Item", links: input)),
      .createItinerary(content: .init(title: "Long Itinerary", links: input)),
    ] {
      let created = await fixture.planner.execute(
        .init(operationId: UUID(), session: fixture.session, command: command))
      guard case .applied(let result, .complete) = created.outcome,
        let owner = result.generated.first
      else { throw CancellationError() }
      let links = try await readLinksUsingIntent(owner)
      XCTAssertEqual(links.count, 130)
      XCTAssertEqual(Set(links.map(\.id)).count, 130)
      XCTAssertEqual([links[0].position, links[64].position, links[129].position], [1, 65, 130])
      XCTAssertEqual(links[129].originalURL, "https://example.com/bookmark/129")
      let query = PlannerLinkEntityQuery()
      query.plannerStore = fixture.store
      let resolved = try await query.entities(for: [links[129].id, links[64].id, links[0].id])
      XCTAssertEqual(resolved.map(\.position), [130, 65, 1])
    }
  }

  func testArchivedOwnerReadsPreserveIndependentCompletionAndBookings() async throws {
    let fixture = try await makeLinkIntentFixture()
    let listResult = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .createList(content: .init(name: "Wishlist"))))
    guard case .applied(let createdList, .complete) = listResult.outcome,
      let list = createdList.generated.first
    else { throw CancellationError() }
    let membershipResult = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .addMembership(itemId: fixture.item.id, listId: list.id, placement: .last)))
    guard case .applied(let added, .complete) = membershipResult.outcome,
      case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first
    else { throw CancellationError() }
    let appearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifier)
    for command in [
      PlannerCommand.setCompletion(scope: .appearance(appearance), done: true),
      .setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true),
      .setArchive(source: fixture.item, archived: true),
      .setArchive(source: fixture.itinerary, archived: true),
    ] {
      try await applyLinkIntentFixtureCommand(fixture, command)
    }
    let form = PlannerScheduleForm.allDay(start: .init(year: 2026, month: 10, day: 21), end: nil)
    let scheduled = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .createSchedule(source: fixture.item, form: form)))
    guard case .applied(let createdSchedule, .complete) = scheduled.outcome,
      let schedule = createdSchedule.generated.first
    else { throw CancellationError() }
    let before = try await readLinkIntentSources(fixture)
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    XCTAssertEqual(itemLinks.count, 3)
    XCTAssertEqual(itineraryLinks.count, 1)
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    guard
      case .appearance(let saved) = await fixture.planner.read(
        session: fixture.session, request: .appearance(appearance)),
      case .source(.schedule(let savedSchedule)) = await fixture.planner.read(
        session: fixture.session, request: .source(schedule))
    else { return XCTFail("A Link read must retain the owner's planning references.") }
    XCTAssertTrue(saved.globalDone)
    XCTAssertTrue(saved.localDone)
    XCTAssertEqual(savedSchedule.content.form, form)
    XCTAssertEqual(savedSchedule.content.source, fixture.item)
    try await applyLinkIntentFixtureCommand(
      fixture, .setCompletion(scope: .globalItem(itemId: fixture.item.id), done: false))
    guard
      case .appearance(let reopened) = await fixture.planner.read(
        session: fixture.session, request: .appearance(appearance))
    else { throw CancellationError() }
    XCTAssertFalse(reopened.globalDone)
    XCTAssertTrue(reopened.localDone)
  }

  func testPrecancelledReadsAndIdentityQueriesLeaveSourceDataUntouched() async throws {
    let fixture = try await makeLinkIntentFixture()
    let before = try await readLinkIntentSources(fixture)
    let links = try await readLinksUsingIntent(fixture.item)
    for owner in [fixture.item, fixture.itinerary] {
      let request = Task { try await readLinksUsingIntent(owner) }
      request.cancel()
      do {
        _ = try await request.value
        XCTFail("A precancelled bookmark read cannot report success.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolution = Task { try await query.entities(for: links.map(\.id)) }
    resolution.cancel()
    do {
      _ = try await resolution.value
      XCTFail("A precancelled identity read cannot return cached bookmark data.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
  }

  func testUnavailableStorageThrowsInsteadOfReturningEmptyBookmarksOrChoices() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    for kind in [PlannerEntityKind.item, .itinerary] {
      do {
        _ = try await readLinksUsingIntent(.init(kind: kind, id: UUID()))
        XCTFail("Unavailable storage cannot appear to contain an owner with no bookmarks.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let query = PlannerLinkEntityQuery()
    query.plannerStore = store
    do {
      _ = try await query.entities(for: ["malformed"])
      XCTFail("Unavailable storage cannot become an empty successful identity lookup.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    do {
      _ = try await query.suggestedEntities()
      XCTFail("Unavailable storage must fail even before an owner is selected.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testReadOnlyBookmarksRemainAvailableWithoutAcknowledgingIncompleteRecovery() async throws {
    let fixture = try await makeLinkIntentFixture()
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
    let editing = EditPlannerItemIntent()
    editing.item = .init(id: fixture.item.id, title: "Cached title", done: true, archived: true)
    editing.notes = "Awaiting recovery"
    let _: Void = try await editing.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    let before = try await readLinkIntentSources(fixture)
    let itemLinks = try await readLinksUsingIntent(fixture.item)
    let itineraryLinks = try await readLinksUsingIntent(fixture.itinerary)
    let query = PlannerLinkEntityQuery()
    query.plannerStore = fixture.store
    let resolved = try await query.entities(for: itemLinks.map(\.id) + itineraryLinks.map(\.id))
    XCTAssertEqual(resolved.count, 4)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    await fixture.store.retryIncompleteRecovery()
    XCTAssertFalse(fixture.store.recoveryBlocked)
    try await assertLinkIntentSourcesUnchanged(before, fixture: fixture)
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else {
      return XCTFail(
        "Native recovery must acknowledge the original edit without replaying Link reads.")
    }
  }
}

@MainActor
private func addLinkUsingIntent(
  _ owner: PlannerEntityReference, originalURL: String, label: String?
) async throws -> PlannerLinkEntity {
  if owner.kind == .item {
    let adding = AddPlannerItemLinkIntent()
    adding.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    adding.originalURL = originalURL
    adding.label = label
    return try await adding.callAsFunction(donate: false)
  }
  let adding = AddPlannerItineraryLinkIntent()
  adding.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: true)
  adding.originalURL = originalURL
  adding.label = label
  return try await adding.callAsFunction(donate: false)
}

struct LinkIntentSourceObservations {
  let item: PlannerItemSourceRead
  let itinerary: PlannerItinerarySourceRead
}

@MainActor
func readLinkIntentSources(_ fixture: LinkIntentFixture) async throws
  -> LinkIntentSourceObservations
{
  guard
    case .source(.item(let item)) = await fixture.planner.read(
      session: fixture.session, request: .source(fixture.item)),
    case .source(.itinerary(let itinerary)) = await fixture.planner.read(
      session: fixture.session, request: .source(fixture.itinerary))
  else { throw CancellationError() }
  return .init(item: item, itinerary: itinerary)
}

@MainActor
func assertLinkIntentSourcesUnchanged(
  _ before: LinkIntentSourceObservations, fixture: LinkIntentFixture
) async throws {
  let after = try await readLinkIntentSources(fixture)
  XCTAssertEqual(after.item.fieldHashes, before.item.fieldHashes)
  XCTAssertEqual(after.item.sourceLifetimeId, before.item.sourceLifetimeId)
  XCTAssertEqual(after.item.updatedAt, before.item.updatedAt)
  XCTAssertEqual(after.item.references, before.item.references)
  XCTAssertEqual(after.item.state.globalDone, before.item.state.globalDone)
  XCTAssertEqual(after.item.state.archived, before.item.state.archived)
  XCTAssertEqual(after.itinerary.fieldHashes, before.itinerary.fieldHashes)
  XCTAssertEqual(after.itinerary.sourceLifetimeId, before.itinerary.sourceLifetimeId)
  XCTAssertEqual(after.itinerary.updatedAt, before.itinerary.updatedAt)
  XCTAssertEqual(after.itinerary.references, before.itinerary.references)
  XCTAssertEqual(after.itinerary.state.archived, before.itinerary.state.archived)
  XCTAssertFalse(fixture.store.isSaving)
}

@MainActor
func applyLinkIntentFixtureCommand(_ fixture: LinkIntentFixture, _ command: PlannerCommand)
  async throws
{
  let result = await fixture.planner.execute(
    .init(
      operationId: UUID(),
      session: fixture.session, command: command))
  guard case .applied(_, .complete) = result.outcome else {
    XCTFail("Fixture command did not apply with complete recovery: \(result.outcome)")
    throw CancellationError()
  }
}

@MainActor
func readLinksUsingIntent(_ owner: PlannerEntityReference) async throws
  -> [PlannerLinkEntity]
{
  if owner.kind == .item {
    let reading = GetPlannerItemLinksIntent()
    reading.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    return try await reading.callAsFunction(donate: false)
  }
  let reading = GetPlannerItineraryLinksIntent()
  reading.itinerary = .init(id: owner.id, title: "Cached Itinerary", archived: true)
  return try await reading.callAsFunction(donate: false)
}

struct LinkIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let itinerary: PlannerEntityReference
}

@MainActor
func makeLinkIntentFixture() async throws -> LinkIntentFixture {
  let (_, configuration, store) = try makePlannerIntentStorage()
  AppDependencyManager.shared.add(dependency: store)
  let planner = PlannerCore.Planner(configuration: configuration)
  guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
  let links: [PlannerLinkInput] = [
    .init(
      originalUrl: "https://maps.apple.com/?q=Nezu%20Museum&place-id=fixture-nezu", label: "Visit"),
    .init(originalUrl: "https://example.com/Guide?Ref=%2f&Ref=A#Room", label: nil),
    .init(
      originalUrl: "https://maps.apple.com/?q=Nezu%20Museum&place-id=fixture-nezu", label: "Visit"),
  ]
  let commands: [PlannerCommand] = [
    .createItem(
      content: .init(
        title: "Museum", subtitle: "Booking", notes: "Keep notes",
        location: .init(
          displayName: "Saved place", formattedAddress: "Tokyo",
          coordinate: .init(latitude: 35.6622, longitude: 139.7171)),
        estimate: .init(minutes: 125, displayUnit: .hour), links: links)),
    .createItinerary(
      content: .init(
        title: "Weekend", notes: "Keep route notes",
        links: [.init(originalUrl: "https://example.com/route", label: "Route")],
        manualEstimate: .init(minutes: 480, displayUnit: .hour))),
  ]
  var sources: [PlannerEntityReference] = []
  for command in commands {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: command)
      ).outcome,
      let source = result.generated.first
    else { throw CancellationError() }
    sources.append(source)
  }
  return .init(
    configuration: configuration, store: store, planner: planner, session: session,
    item: sources[0], itinerary: sources[1])
}
