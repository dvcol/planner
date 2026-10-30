import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class SavedItemWindowTests: XCTestCase {
  func testMovingWindowsWithFiveThousandItemsAndTwoHundredLists() async throws {
    let seededAt = Date()
    let fixture = try await makeFixture(itemCount: 5_000, listName: "Scale plan", listCount: 200)
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let seededSeconds = Date().timeIntervalSince(seededAt)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    let openedAt = Date()
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), completion: .all, archive: .all, sort: .init(mode: .manual)),
      identity: .init(namespace: "scale-list", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 5_000)
    XCTAssertEqual(window.rowIdentities.count, 5_000)
    XCTAssertEqual(window.listSource?.progress.totalCount, 5_000)
    let firstIdentity = try XCTUnwrap(window.rowIdentities.first)
    let firstPageSeconds = Date().timeIntervalSince(openedAt)
    guard case .loaded = window.presentation(at: 0),
      case .loading = window.presentation(at: 64)
    else { return XCTFail("The initial List must load only its first page.") }

    await window.requestRows(at: [4_999])
    guard case .loaded(let last) = window.presentation(at: 4_999),
      case .loading = window.presentation(at: 0)
    else { return XCTFail("Reaching the last page must release the offscreen first page.") }
    XCTAssertEqual(
      last.row.identity,
      .appearance(
        source: .init(kind: .item, id: fixture.identifiers[4_999]),
        appearance: .listMembership(
          listId: listIdentifier, membershipId: fixture.membershipIdentifiers[4_999]))
    )
    XCTAssertEqual(window.rowIdentities.first, firstIdentity)
    XCTAssertEqual(window.listSource?.progress.totalCount, 5_000)

    await window.reload(
      catalogQuery: .init(sourceKind: .list),
      identity: .init(namespace: "scale-catalog", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 200)
    XCTAssertEqual(window.rowIdentities.count, 200)
    await window.requestRows(at: [199])
    guard case .loaded(let lastList) = window.presentation(at: 199),
      case .loading = window.presentation(at: 0)
    else { return XCTFail("The container catalog must also release offscreen presentations.") }
    XCTAssertEqual(lastList.row.title, "Scale plan 199")
    print(
      "PLANNER_SCALE \(seededSeconds) seconds importing; \(firstPageSeconds) seconds opening; \(Date().timeIntervalSince(openedAt)) seconds paging 5000 Items and 200 Lists"
    )
  }

  func testListCatalogOpensOnePageAndKeepsCompleteSourceIdentitiesAndEstimates() async throws {
    let fixture = try await makeFixture(itemCount: 0)
    var expectedSources: [PlannerEntityReference] = []
    for index in 0..<193 {
      let result = try await applyFixtureCommand(
        .createList(content: .init(name: String(format: "Plan %03d", index))), fixture: fixture)
      expectedSources.append(try XCTUnwrap(result.generated.first))
    }
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      catalogQuery: .init(sourceKind: .list),
      identity: .init(namespace: "list-catalog", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 193)
    XCTAssertEqual(window.rowIdentities, expectedSources.map { .source($0) })
    XCTAssertNil(window.listSource)
    XCTAssertNil(window.itineraryMetadata)
    for (index, expectedTitle) in [(0, "Plan 000"), (63, "Plan 063")] {
      guard case .loaded(let presentation) = window.presentation(at: index) else {
        XCTFail("The first catalog page must load before becoming ready.")
        return
      }
      XCTAssertEqual(presentation.row.identity, .source(expectedSources[index]))
      XCTAssertEqual(presentation.row.title, expectedTitle)
      XCTAssertEqual(presentation.row.archived, false)
      XCTAssertEqual(presentation.row.containerEstimates?.fullEstimate, .exact(minutes: 0))
    }
    guard case .loading = window.presentation(at: 64) else {
      XCTFail("The container catalog must retain only its initial page.")
      return
    }
    await window.requestRows(at: [128, 192])
    for index in [64, 128, 192] {
      guard case .loaded(let presentation) = window.presentation(at: index) else {
        XCTFail("Visible catalog pages and their neighbor must load.")
        return
      }
      XCTAssertEqual(presentation.row.identity, .source(expectedSources[index]))
    }
    guard case .loading = window.presentation(at: 0) else {
      XCTFail("Distant container presentations must be released.")
      return
    }
    await window.requestRows(at: [0])
    guard case .loaded(let revisited) = window.presentation(at: 0),
      case .loading = window.presentation(at: 192)
    else {
      XCTFail("Revisiting a catalog must load its original identities and release distant pages.")
      return
    }
    XCTAssertEqual(revisited.row.identity, .source(expectedSources[0]))
    XCTAssertEqual(window.rowIdentities, expectedSources.map { .source($0) })
  }

  func testItineraryCatalogKeepsItsQueryDuringStaleRefreshAndClearsPriorListMetadata()
    async throws
  {
    let fixture = try await makeFixture(itemCount: 1, listName: "Source List")
    var createdSources: [PlannerEntityReference] = []
    for index in (0..<65).reversed() {
      let created = try await applyFixtureCommand(
        .createItinerary(
          content: .init(
            title: String(format: "Route %03d", index),
            manualEstimate: .init(minutes: Int64(index + 1), displayUnit: .minute))),
        fixture: fixture)
      createdSources.append(try XCTUnwrap(created.generated.first))
    }
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(scope: .list(try XCTUnwrap(fixture.listIdentifier))),
      identity: .init(namespace: "containers", savedRevision: UUID()))
    XCTAssertNotNil(window.listSource)
    let expectedSources = Array(createdSources.reversed())
    await window.reload(
      catalogQuery: .init(sourceKind: .itinerary),
      identity: .init(namespace: "containers", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertNil(window.listSource)
    XCTAssertNil(window.itineraryMetadata)
    XCTAssertEqual(window.rowIdentities, expectedSources.map { .source($0) })
    _ = try await applyFixtureCommand(
      .setArchive(source: expectedSources[0], archived: true), fixture: fixture)
    await window.requestRows(at: [64])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 64)
    XCTAssertEqual(window.rowIdentities, expectedSources.dropFirst().map { .source($0) })
    guard case .loaded(let first) = window.presentation(at: 0) else {
      XCTFail("A stale catalog must refresh its original kind, archive policy and first page.")
      return
    }
    XCTAssertEqual(first.row.title, "Route 001")
    XCTAssertEqual(first.row.containerEstimates?.fullEstimate, .exact(minutes: 2))
    let examples: [(PlannerCatalogQuery.Sort, [PlannerEntityReference])] = [
      (.init(mode: .created), Array(createdSources.dropLast())),
      (.init(mode: .lastUpdated, direction: .descending), Array(expectedSources.dropFirst())),
      (.init(mode: .fullEstimate), Array(expectedSources.dropFirst())),
      (.init(mode: .title, direction: .descending), Array(createdSources.dropLast())),
    ]
    for (sort, expected) in examples {
      await window.reload(
        catalogQuery: .init(sourceKind: .itinerary, sort: sort),
        identity: .init(namespace: "sorted-containers", savedRevision: UUID()))
      XCTAssertEqual(window.state, .ready)
      XCTAssertEqual(window.rowIdentities, expected.map { .source($0) })
    }
    await window.reload(
      catalogQuery: .init(sourceKind: .itinerary, text: "routé 000", archive: .archived),
      identity: .init(namespace: "archived-containers", savedRevision: UUID()))
    XCTAssertEqual(window.rowIdentities, [.source(expectedSources[0])])
    await window.reload(
      catalogQuery: .init(sourceKind: .itinerary, text: "No match", archive: .all),
      identity: .init(namespace: "empty-containers", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    await window.reload(
      catalogQuery: .init(sourceKind: .item),
      identity: .init(namespace: "unsupported-containers", savedRevision: UUID()))
    guard case .failed = window.state else {
      XCTFail("Unsupported catalog kinds must not become empty successful catalogs.")
      return
    }
    window.cancel()
    XCTAssertEqual(window.state, .idle)
    XCTAssertTrue(window.rowIdentities.isEmpty)
  }

  func testItineraryRefreshKeepsRepeatedContextsThroughRouteMembershipAndSourceChanges()
    async throws
  {
    let fixture = try await makeFixture(itemCount: 65, listName: "Original activities")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let list = PlannerEntityReference(kind: .list, id: listIdentifier)
    let directSource = PlannerEntityReference(kind: .item, id: fixture.identifiers[0])
    let itinerary = try await createItinerary(
      title: "Changing route", sources: [list, list, directSource], fixture: fixture)
    let firstListEntry = itinerary.entryIdentifiers[0]
    let secondListEntry = itinerary.entryIdentifiers[1]
    let directEntry = itinerary.entryIdentifiers[2]
    _ = try await applyFixtureCommand(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.source.id, listEntryId: firstListEntry,
            membershipId: fixture.membershipIdentifiers[64])), done: true), fixture: fixture)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .itinerary(itinerary.source.id), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "changing-itinerary", savedRevision: UUID()))
    _ = try await applyFixtureCommand(
      .reorderItineraryEntry(
        itineraryId: itinerary.source.id, entryId: secondListEntry, placement: .first),
      fixture: fixture)
    await window.requestRows(at: [130])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.itineraryMetadata?.entries.map(\.id), [secondListEntry, firstListEntry, directEntry])
    XCTAssertEqual(window.matchingCount, 131)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].listSummary?.progress.doneCount, 0)
    XCTAssertEqual(window.itineraryMetadata?.entries[1].listSummary?.progress.doneCount, 1)
    await window.requestRows(at: [])
    _ = try await applyFixtureCommand(
      .removeMembership(listId: listIdentifier, membershipId: fixture.membershipIdentifiers[0]),
      fixture: fixture)
    await window.requestRows(at: [0])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 129)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.doneCount, 1)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].rowIdentities.count, 64)
    XCTAssertEqual(window.itineraryMetadata?.entries[1].rowIdentities.count, 64)
    await window.requestRows(at: [])
    _ = try await applyFixtureCommand(
      .reorderMembership(
        listId: listIdentifier, membershipId: fixture.membershipIdentifiers[64], placement: .first),
      fixture: fixture)
    guard
      case .source(.list(let currentList)) = await fixture.planner.read(
        session: fixture.session, request: .source(list)),
      case .source(.item(let currentItem)) = await fixture.planner.read(
        session: fixture.session, request: .source(directSource))
    else { throw CancellationError() }
    _ = try await applyFixtureCommand(
      .editList(
        sourceId: listIdentifier, changes: .init(name: .set("Renamed activities")),
        expectedFieldHashes: currentList.fieldHashes), fixture: fixture)
    _ = try await applyFixtureCommand(
      .editItem(
        sourceId: directSource.id, changes: .init(title: .set("Retained direct activity")),
        expectedFieldHashes: currentItem.fieldHashes), fixture: fixture)
    await window.requestRows(at: [0])
    await window.requestRows(at: [0, 64, 128])
    let reorderedIndices = [64] + Array(1...63)
    let expectedExpanded = [secondListEntry, firstListEntry].flatMap { entryIdentifier in
      reorderedIndices.map { index in
        PlannerRowIdentity.appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .expandedListItem(
            itineraryId: itinerary.source.id, listEntryId: entryIdentifier,
            membershipId: fixture.membershipIdentifiers[index]))
      }
    }
    let expectedDirect = PlannerRowIdentity.appearance(
      source: directSource,
      appearance: .directItineraryItem(itineraryId: itinerary.source.id, entryId: directEntry))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.rowIdentities, expectedExpanded + [expectedDirect])
    XCTAssertEqual(window.itineraryMetadata?.entries[0].list?.content.name, "Renamed activities")
    XCTAssertEqual(window.itineraryMetadata?.entries[1].list?.content.name, "Renamed activities")
    XCTAssertEqual(window.itineraryMetadata?.entries[0].list?.progress.doneCount, 0)
    for (index, expectedDone) in [(0, false), (64, true), (128, false)] {
      guard case .loaded(let presentation) = window.presentation(at: index) else {
        XCTFail("Surviving appearances must reload with their own identities and state.")
        return
      }
      XCTAssertEqual(presentation.row.identity, window.rowIdentities[index])
      XCTAssertEqual(presentation.row.effectiveDone, expectedDone)
      XCTAssertEqual(presentation.row.globalDone, false)
      if index == 128 { XCTAssertEqual(presentation.row.title, "Retained direct activity") }
    }
    await window.requestRows(at: [])
    _ = try await applyFixtureCommand(
      .removeItineraryEntry(itineraryId: itinerary.source.id, entryId: firstListEntry),
      fixture: fixture)
    await window.requestRows(at: [0])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.itineraryMetadata?.entries.map(\.id), [secondListEntry, directEntry])
    XCTAssertEqual(window.rowIdentities, Array(expectedExpanded.prefix(64)) + [expectedDirect])
    XCTAssertEqual(window.matchingCount, 65)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.doneCount, 0)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].listSummary?.progress.doneCount, 0)
  }

  func testEmptyItineraryAndEmptyListPublishTheirHeadersAndCancelClearsThem() async throws {
    let fixture = try await makeFixture(itemCount: 0, listName: "Empty activities")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let itinerary = try await createItinerary(title: "Empty route", sources: [], fixture: fixture)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    let query = PlannerItemQuery(
      scope: .itinerary(itinerary.source.id), completion: .all, archive: .all,
      sort: .init(mode: .manual))
    await window.reload(
      query: query, identity: .init(namespace: "empty-route", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    XCTAssertEqual(window.matchingCount, 0)
    let empty = try XCTUnwrap(window.itineraryMetadata)
    XCTAssertEqual(empty.itinerary.source, itinerary.source)
    XCTAssertEqual(empty.itinerary.progress.state, .empty)
    XCTAssertEqual(empty.itinerary.progress.totalCount, 0)
    XCTAssertTrue(empty.entries.isEmpty)
    let added = try await applyFixtureCommand(
      .addItineraryEntry(
        itineraryId: itinerary.source.id, source: .init(kind: .list, id: listIdentifier),
        placement: .last), fixture: fixture)
    guard case .itineraryEntry(let entryIdentifier, _, _)? = added.generatedReferences.first else {
      XCTFail("The empty List still needs its own saved itinerary entry.")
      return
    }
    await window.reload(
      query: query, identity: .init(namespace: "empty-route", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    let metadata = try XCTUnwrap(window.itineraryMetadata)
    XCTAssertEqual(metadata.itinerary.progress.state, .empty)
    XCTAssertEqual(metadata.entries.map(\.id), [entryIdentifier])
    XCTAssertEqual(metadata.visibleEntries.map(\.id), [entryIdentifier])
    XCTAssertTrue(metadata.entries[0].rowIdentities.isEmpty)
    XCTAssertTrue(metadata.entries[0].matchingRowIndices.isEmpty)
    XCTAssertTrue(metadata.entries[0].matchesHeader)
    XCTAssertEqual(metadata.entries[0].list?.content.name, "Empty activities")
    XCTAssertEqual(metadata.entries[0].listSummary?.progress.state, .empty)
    window.cancel()
    XCTAssertEqual(window.state, .idle)
    XCTAssertNil(window.itineraryMetadata)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "empty-source-catalog", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertNil(window.itineraryMetadata)
    XCTAssertTrue(window.rowIdentities.isEmpty)
  }

  func testRepeatedItineraryPagesRefreshIndependentCompletionAndArchivedBranches() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "Repeated activities")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let list = PlannerEntityReference(kind: .list, id: listIdentifier)
    let itinerary = try await createItinerary(
      title: "Repeated route", sources: [list, list], fixture: fixture)
    let expectedIdentities = itinerary.entryIdentifiers.flatMap { entryIdentifier in
      fixture.identifiers.enumerated().map { index, identifier in
        PlannerRowIdentity.appearance(
          source: .init(kind: .item, id: identifier),
          appearance: .expandedListItem(
            itineraryId: itinerary.source.id, listEntryId: entryIdentifier,
            membershipId: fixture.membershipIdentifiers[index]))
      }
    }
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .itinerary(itinerary.source.id), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "repeated-completion", savedRevision: UUID()))
    _ = try await applyFixtureCommand(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.source.id, listEntryId: itinerary.entryIdentifiers[0],
            membershipId: fixture.membershipIdentifiers[64])), done: true), fixture: fixture)
    await window.requestRows(at: [129])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.rowIdentities, expectedIdentities)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.totalCount, 130)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.doneCount, 1)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].listSummary?.progress.doneCount, 1)
    XCTAssertEqual(window.itineraryMetadata?.entries[1].listSummary?.progress.doneCount, 0)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].list?.progress.doneCount, 0)
    for (index, done) in [(64, true), (129, false)] {
      guard case .loaded(let presentation) = window.presentation(at: index) else {
        XCTFail("Each repeated membership needs its own loaded contextual completion.")
        return
      }
      XCTAssertEqual(presentation.row.identity, expectedIdentities[index])
      XCTAssertEqual(presentation.row.effectiveDone, done)
      XCTAssertFalse(presentation.row.globalDone == true)
    }
    guard case .loading = window.presentation(at: 0) else {
      XCTFail(
        "Refreshing an itinerary must release distant presentations while retaining metadata.")
      return
    }
    _ = try await applyFixtureCommand(
      .setCompletion(scope: .globalItem(itemId: fixture.identifiers[64]), done: true),
      fixture: fixture)
    await window.requestRows(at: [0])
    await window.requestRows(at: [129])
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.doneCount, 2)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].list?.progress.doneCount, 1)
    for index in [64, 129] {
      guard case .loaded(let presentation) = window.presentation(at: index) else {
        XCTFail("Global Done must be reflected in both current appearance pages.")
        return
      }
      XCTAssertEqual(presentation.row.identity, expectedIdentities[index])
      XCTAssertTrue(presentation.row.globalDone == true)
      XCTAssertTrue(presentation.row.effectiveDone == true)
    }
    _ = try await applyFixtureCommand(
      .setCompletion(scope: .globalItem(itemId: fixture.identifiers[64]), done: false),
      fixture: fixture)
    await window.requestRows(at: [0])
    await window.requestRows(at: [129])
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.doneCount, 1)
    for (index, done) in [(64, true), (129, false)] {
      guard case .loaded(let presentation) = window.presentation(at: index) else {
        XCTFail("Global Reopen must reveal the retained independent local states.")
        return
      }
      XCTAssertEqual(presentation.row.identity, expectedIdentities[index])
      XCTAssertFalse(presentation.row.globalDone == true)
      XCTAssertEqual(presentation.row.effectiveDone, done)
    }
    _ = try await applyFixtureCommand(.setArchive(source: list, archived: true), fixture: fixture)
    await window.requestRows(at: [0])
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.state, .complete)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.doneCount, 1)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.archivedCount, 129)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.finishedCount, 130)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].list?.state.archived, true)
    _ = try await applyFixtureCommand(.setArchive(source: list, archived: false), fixture: fixture)
    await window.requestRows(at: [129])
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.doneCount, 1)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.archivedCount, 0)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].listSummary?.progress.doneCount, 1)
    XCTAssertEqual(window.itineraryMetadata?.entries[1].listSummary?.progress.doneCount, 0)
    XCTAssertEqual(window.itineraryMetadata?.entries[0].list?.progress.doneCount, 0)
    XCTAssertEqual(window.rowIdentities, expectedIdentities)
    await window.requestRows(at: [])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.itineraryMetadata?.itinerary.progress.totalCount, 130)
    for index in [0, 64, 129] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail(
          "No visible child rows must release presentations without discarding branch metadata.")
        return
      }
    }
  }

  private func createItinerary(
    title: String, sources: [PlannerEntityReference], fixture: Fixture
  ) async throws -> (source: PlannerEntityReference, entryIdentifiers: [UUID]) {
    let created = try await applyFixtureCommand(
      .createItinerary(content: .init(title: title)), fixture: fixture)
    let itinerary = try XCTUnwrap(created.generated.first)
    var entryIdentifiers: [UUID] = []
    for source in sources {
      let result = try await applyFixtureCommand(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last),
        fixture: fixture)
      guard
        case .itineraryEntry(let identifier, let owner, let reference)? =
          result.generatedReferences.first, owner == itinerary, reference == source
      else { throw CancellationError() }
      entryIdentifiers.append(identifier)
    }
    return (itinerary, entryIdentifiers)
  }

  func testItineraryHeaderAndChildMatchesKeepFullProgressAndUnloadedIdentities() async throws {
    let fixture = try await makeFixture(itemCount: 4, listName: "Museum route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let created = try await applyFixtureCommand(
      .createItinerary(content: .init(title: "Filtered route")), fixture: fixture)
    let itinerary = try XCTUnwrap(created.generated.first)
    let item = PlannerEntityReference(kind: .item, id: fixture.identifiers[0])
    let list = PlannerEntityReference(kind: .list, id: listIdentifier)
    var entries: [UUID] = []
    for source in [item, list, item] {
      let result = try await applyFixtureCommand(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last),
        fixture: fixture)
      guard case .itineraryEntry(let identifier, _, _)? = result.generatedReferences.first else {
        XCTFail("The public add must identify its itinerary entry.")
        return
      }
      entries.append(identifier)
    }
    _ = try await applyFixtureCommand(
      .setCompletion(scope: .globalItem(itemId: fixture.identifiers[1]), done: true),
      fixture: fixture)
    _ = try await applyFixtureCommand(
      .setArchive(source: .init(kind: .item, id: fixture.identifiers[3]), archived: true),
      fixture: fixture)
    let children = fixture.identifiers.enumerated().map { index, identifier in
      PlannerRowIdentity.appearance(
        source: .init(kind: .item, id: identifier),
        appearance: .expandedListItem(
          itineraryId: itinerary.id, listEntryId: entries[1],
          membershipId: fixture.membershipIdentifiers[index]))
    }
    let first = PlannerRowIdentity.appearance(
      source: item, appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: entries[0])
    )
    let last = PlannerRowIdentity.appearance(
      source: item, appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: entries[2])
    )
    let examples: [(text: String, matches: [PlannerRowIdentity], visible: [UUID], header: Bool)] = [
      ("Museum route", [], [entries[1]], true),
      ("Activity 002", [children[2]], [entries[1]], false),
      ("No such activity", [], [], false),
      ("Activity", [first, children[0], children[2], last], entries, false),
    ]
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    for example in examples {
      await window.reload(
        query: .init(
          scope: .itinerary(itinerary.id), text: example.text, completion: .todo, archive: .active,
          sort: .init(mode: .manual)),
        identity: .init(namespace: "itinerary-matching", savedRevision: UUID()))
      XCTAssertEqual(window.state, .ready)
      XCTAssertEqual(window.rowIdentities, example.matches)
      XCTAssertEqual(window.matchingCount, Int64(example.matches.count))
      let metadata = try XCTUnwrap(window.itineraryMetadata)
      XCTAssertEqual(metadata.entries.map(\.id), entries)
      XCTAssertEqual(metadata.visibleEntries.map(\.id), example.visible)
      XCTAssertEqual(metadata.itinerary.progress.totalCount, 6)
      XCTAssertEqual(metadata.itinerary.progress.doneCount, 1)
      XCTAssertEqual(metadata.itinerary.progress.archivedCount, 1)
      XCTAssertEqual(
        metadata.itinerary.estimates.fullEstimate,
        .lowerBound(minutes: 0, missingEstimateCount: 6))
      let branch = metadata.entries[1]
      XCTAssertEqual(branch.rowIdentities, children)
      XCTAssertEqual(branch.matchesHeader, example.header)
      XCTAssertEqual(branch.list?.content.name, "Museum route")
      XCTAssertEqual(branch.listSummary?.progress.totalCount, 4)
      XCTAssertEqual(branch.listSummary?.progress.doneCount, 1)
      XCTAssertEqual(branch.listSummary?.progress.archivedCount, 1)
      for (index, identity) in example.matches.enumerated() {
        guard case .loaded(let row) = window.presentation(at: index) else {
          XCTFail("Matching presentations must remain available beside the complete metadata.")
          return
        }
        XCTAssertEqual(row.row.identity, identity)
        XCTAssertFalse(row.row.effectiveDone == true)
        XCTAssertFalse(row.row.archived == true)
      }
      if example.matches.isEmpty {
        guard case .loading = window.presentation(at: 0) else {
          XCTFail("Header matching must not retain presentations for hidden children.")
          return
        }
      }
    }
  }

  func testItineraryOpensOnePageAndKeepsRepeatedListMembershipsDistinct() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "Repeated activities")
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let created = try await applyFixtureCommand(
      .createItinerary(content: .init(title: "Repeated route")), fixture: fixture)
    let itinerary = try XCTUnwrap(created.generated.first)
    let item = PlannerEntityReference(kind: .item, id: fixture.identifiers[0])
    let list = PlannerEntityReference(kind: .list, id: listIdentifier)
    var entryIdentifiers: [UUID] = []
    for source in [item, list, list, item] {
      let added = try await applyFixtureCommand(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last),
        fixture: fixture)
      guard
        case .itineraryEntry(let identifier, let owner, let reference)? =
          added.generatedReferences.first
      else {
        XCTFail("Each public add must return its own itinerary entry.")
        return
      }
      XCTAssertEqual(owner, itinerary)
      XCTAssertEqual(reference, source)
      entryIdentifiers.append(identifier)
    }
    var expectedIdentities: [PlannerRowIdentity] = [
      .appearance(
        source: item,
        appearance: .directItineraryItem(
          itineraryId: itinerary.id, entryId: entryIdentifiers[0]))
    ]
    for entryIdentifier in [entryIdentifiers[1], entryIdentifiers[2]] {
      for (index, identifier) in fixture.identifiers.enumerated() {
        expectedIdentities.append(
          .appearance(
            source: .init(kind: .item, id: identifier),
            appearance: .expandedListItem(
              itineraryId: itinerary.id, listEntryId: entryIdentifier,
              membershipId: fixture.membershipIdentifiers[index])))
      }
    }
    expectedIdentities.append(
      .appearance(
        source: item,
        appearance: .directItineraryItem(
          itineraryId: itinerary.id, entryId: entryIdentifiers[3])))
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .itinerary(itinerary.id), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "repeated-itinerary-first-page", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    guard window.state == .ready else { return }
    XCTAssertEqual(window.matchingCount, 132)
    XCTAssertEqual(window.rowIdentities, expectedIdentities)
    let metadata = try XCTUnwrap(window.itineraryMetadata)
    XCTAssertEqual(metadata.itinerary.source, itinerary)
    XCTAssertEqual(metadata.itinerary.content.title, "Repeated route")
    XCTAssertEqual(metadata.itinerary.progress.totalCount, 132)
    XCTAssertEqual(metadata.itinerary.progress.doneCount, 0)
    XCTAssertEqual(
      metadata.itinerary.estimates.fullEstimate,
      .lowerBound(minutes: 0, missingEstimateCount: 132))
    XCTAssertEqual(metadata.entries.map(\.id), entryIdentifiers)
    XCTAssertEqual(metadata.entries.map(\.source), [item, list, list, item])
    XCTAssertEqual(metadata.visibleEntries.map(\.id), entryIdentifiers)
    let expectedRanges = [0..<1, 1..<66, 66..<131, 131..<132]
    for (index, entry) in metadata.entries.enumerated() {
      XCTAssertEqual(entry.rowIdentities, Array(expectedIdentities[expectedRanges[index]]))
      XCTAssertEqual(entry.matchingRowIndices, Array(expectedRanges[index]))
      if index == 1 || index == 2 {
        XCTAssertEqual(entry.list?.source, list)
        XCTAssertEqual(entry.list?.content.name, "Repeated activities")
        /// The shared List includes 65 memberships and its two incoming itinerary entries.
        XCTAssertEqual(entry.list?.references.count, 67)
        XCTAssertEqual(entry.listSummary?.entryId, entryIdentifiers[index])
        XCTAssertEqual(entry.listSummary?.source, list)
        XCTAssertEqual(entry.listSummary?.progress.totalCount, 65)
        XCTAssertEqual(entry.listSummary?.progress.doneCount, 0)
        XCTAssertEqual(
          entry.listSummary?.estimates.fullEstimate,
          .lowerBound(minutes: 0, missingEstimateCount: 65))
        XCTAssertTrue(entry.matchesHeader)
      } else {
        XCTAssertNil(entry.list)
        XCTAssertNil(entry.listSummary)
        XCTAssertFalse(entry.matchesHeader)
      }
    }
    for (index, title) in [(0, "Activity 000"), (1, "Activity 000"), (63, "Activity 062")] {
      guard case .loaded(let presentation) = window.presentation(at: index) else {
        XCTFail("A ready itinerary must expose its first page of exact appearances.")
        return
      }
      XCTAssertEqual(presentation.row.identity, expectedIdentities[index])
      XCTAssertEqual(presentation.row.title, title)
      XCTAssertFalse(presentation.row.effectiveDone == true)
    }
    for index in [64, 66, 131] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Opening an itinerary must not hydrate all repeated List appearances.")
        return
      }
    }
  }

  func testListOpensOnePageWithEveryMembershipIdentityAndItsFullHeader() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "Museum route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "list-first-page", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 65)
    let expectedIdentities = fixture.identifiers.enumerated().map { index, identifier in
      PlannerRowIdentity.appearance(
        source: .init(kind: .item, id: identifier),
        appearance: .listMembership(
          listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
    }
    XCTAssertEqual(window.rowIdentities, expectedIdentities)
    let list = try XCTUnwrap(window.listSource)
    XCTAssertEqual(list.source, .init(kind: .list, id: listIdentifier))
    XCTAssertEqual(list.content.name, "Museum route")
    XCTAssertEqual(list.progress.totalCount, 65)
    XCTAssertEqual(list.progress.doneCount, 0)
    XCTAssertEqual(list.references.count, 65)
    XCTAssertEqual(list.estimates.fullEstimate, .lowerBound(minutes: 0, missingEstimateCount: 65))
    for (index, title) in [(0, "Activity 000"), (63, "Activity 063")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("A ready List must include its first page of contextual Item presentations.")
        return
      }
      XCTAssertEqual(
        item.row.identity,
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index])))
      XCTAssertEqual(item.row.identity, expectedIdentities[index])
      XCTAssertEqual(item.row.title, title)
      XCTAssertFalse(item.row.effectiveDone == true)
    }
    guard case .loading = window.presentation(at: 64) else {
      XCTFail("Opening a List must not eagerly hydrate every membership.")
      return
    }
  }

  func testOpensWithOnePageAndKeepsEveryOrderedSourceIdentity() async throws {
    let fixture = try await makeFixture(itemCount: 65)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "first-page", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    XCTAssertEqual(window.matchingCount, 65)
    for (index, title) in [(0, "Activity 000"), (63, "Activity 063")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("The initial page must be readable before the catalog is ready.")
        return
      }
      XCTAssertEqual(item.row.identity, .source(.init(kind: .item, id: fixture.identifiers[index])))
      XCTAssertEqual(item.row.title, title)
    }
    guard case .loading = window.presentation(at: 64) else {
      XCTFail("The catalog must not accumulate all matching row presentations.")
      return
    }
  }

  func testListReleasesAndRevisitsMembershipPagesWhileKeepingItsFullHeader() async throws {
    let fixture = try await makeFixture(itemCount: 193, listName: "Long route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), completion: .all, archive: .all, sort: .init(mode: .manual)),
      identity: .init(namespace: "list-page-traversal", savedRevision: UUID()))
    let originalIdentities = window.rowIdentities
    XCTAssertEqual(originalIdentities.count, 193)
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 193)
    XCTAssertEqual(window.rowIdentities, originalIdentities)
    XCTAssertEqual(window.listSource?.source.id, listIdentifier)
    XCTAssertEqual(window.listSource?.references.count, 193)
    XCTAssertEqual(window.listSource?.progress.totalCount, 193)
    XCTAssertEqual(
      window.listSource?.estimates.fullEstimate, .lowerBound(minutes: 0, missingEstimateCount: 193))
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Visible and neighboring List pages must load their contextual memberships.")
        return
      }
      XCTAssertEqual(
        item.row.identity,
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index])))
      XCTAssertEqual(item.row.title, title)
      XCTAssertEqual(
        item.row.identity,
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index])))
    }
    for index in [0, 64] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Distant List presentations must be released without dropping their identities.")
        return
      }
    }
    await window.requestRows(at: [0])
    for (index, title) in [(0, "Activity 000"), (64, "Activity 064")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Returning to the beginning must reread the same memberships.")
        return
      }
      XCTAssertEqual(
        item.row.identity,
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index])))
      XCTAssertEqual(item.row.title, title)
    }
    for index in [128, 192] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Returning to the beginning must release the distant List pages.")
        return
      }
    }
    XCTAssertEqual(window.listSource?.progress.totalCount, 193)
  }

  func testLoadsVisibleAndNeighborPagesReleasesDistantRowsAndRevisitsTheirIdentities() async throws
  {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "page-traversal", savedRevision: UUID()))
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Visible and neighboring pages must load through the same catalog.")
        return
      }
      XCTAssertEqual(item.row.identity, .source(.init(kind: .item, id: fixture.identifiers[index])))
      XCTAssertEqual(item.row.title, title)
    }
    for index in [0, 64] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Distant row presentations must be released.")
        return
      }
    }
    await window.requestRows(at: [0])
    for (index, title) in [(0, "Activity 000"), (64, "Activity 064")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Revisiting a released page must reload its original Items.")
        return
      }
      XCTAssertEqual(item.row.identity, .source(.init(kind: .item, id: fixture.identifiers[index])))
      XCTAssertEqual(item.row.title, title)
    }
    for index in [128, 192] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Returning to the beginning must release the distant pages.")
        return
      }
    }
  }

  func testEmptyAndFilteredListsKeepTheirOwnHeaderAndCancelClearsIt() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "Filtered route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), text: "Absent museum", completion: .all, archive: .all),
      identity: .init(namespace: "filtered-list", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    XCTAssertEqual(window.listSource?.content.name, "Filtered route")
    XCTAssertEqual(window.listSource?.progress.totalCount, 65)
    XCTAssertEqual(window.listSource?.references.count, 65)
    XCTAssertEqual(
      window.listSource?.estimates.fullEstimate, .lowerBound(minutes: 0, missingEstimateCount: 65))
    let emptyList = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .createList(content: .init(name: "Empty route"))))
    guard case .applied(let created, .complete) = emptyList.outcome else {
      XCTFail("The real Planner must create the empty List fixture.")
      return
    }
    let emptyIdentifier = try XCTUnwrap(created.generated.first { $0.kind == .list }?.id)
    await window.reload(
      query: .init(scope: .list(emptyIdentifier), completion: .all, archive: .all),
      identity: .init(namespace: "empty-list", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    XCTAssertEqual(window.listSource?.source.id, emptyIdentifier)
    XCTAssertEqual(window.listSource?.content.name, "Empty route")
    XCTAssertEqual(window.listSource?.progress.state, .empty)
    XCTAssertEqual(window.listSource?.progress.totalCount, 0)
    XCTAssertEqual(window.listSource?.references.count, 0)
    XCTAssertEqual(window.listSource?.estimates.fullEstimate, .exact(minutes: 0))
    window.cancel()
    XCTAssertEqual(window.state, .idle)
    XCTAssertNil(window.listSource)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    await window.reload(
      query: .init(scope: .global, completion: .all, archive: .all),
      identity: .init(namespace: "global-after-list", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertNil(window.listSource)
    XCTAssertEqual(window.matchingCount, 65)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
  }

  func testRefreshesAStaleGenerationWithoutMixingItsRowsAndKeepsTheVisibleSource() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .todo, archive: .all),
      identity: .init(namespace: "saved-mutation", savedRevision: UUID()))
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setCompletion(scope: .globalItem(itemId: fixture.identifiers[0]), done: true))
      ).outcome
    else { throw CancellationError() }
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 192)
    XCTAssertEqual(
      window.rowIdentities,
      fixture.identifiers.dropFirst().map { .source(.init(kind: .item, id: $0)) })
    guard case .loaded(let lastItem) = window.presentation(at: 191) else {
      XCTFail("A stale page must refresh and retain the source that was visible before the change.")
      return
    }
    XCTAssertEqual(lastItem.row.identity, .source(.init(kind: .item, id: fixture.identifiers[192])))
    XCTAssertEqual(lastItem.row.title, "Activity 192")
    for index in window.rowIdentities.indices {
      if case .loaded(let item) = window.presentation(at: index) {
        XCTAssertEqual(
          item.row.identity, .source(.init(kind: .item, id: fixture.identifiers[index + 1])))
        XCTAssertFalse(item.row.globalDone == true)
      }
    }
  }

  func testSwitchingListsKeepsSharedItemMembershipsAndLocalCompletionIndependent() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "First route")
    let firstListIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(firstListIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "shared-item-lists", savedRevision: UUID()))
    _ = try await applyFixtureCommand(
      .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: firstListIdentifier, membershipId: fixture.membershipIdentifiers[64])),
        done: true),
      fixture: fixture)
    await window.requestRows(at: [64])
    XCTAssertEqual(window.listSource?.progress.doneCount, 1)
    guard case .loaded(let firstAppearance) = window.presentation(at: 64) else {
      XCTFail("An unloaded stale page must refresh the List's completion and header together.")
      return
    }
    XCTAssertEqual(
      firstAppearance.row.identity,
      .appearance(
        source: .init(kind: .item, id: fixture.identifiers[64]),
        appearance: .listMembership(
          listId: firstListIdentifier, membershipId: fixture.membershipIdentifiers[64])))
    XCTAssertTrue(firstAppearance.row.effectiveDone == true)
    XCTAssertFalse(firstAppearance.row.globalDone == true)
    let secondList = try await applyFixtureCommand(
      .createList(content: .init(name: "Second route")), fixture: fixture)
    let secondListIdentifier = try XCTUnwrap(secondList.generated.first { $0.kind == .list }?.id)
    let addition = try await applyFixtureCommand(
      .addMembership(
        itemId: fixture.identifiers[64], listId: secondListIdentifier, placement: .last),
      fixture: fixture)
    let secondMembershipIdentifier = try XCTUnwrap(
      addition.generatedReferences.compactMap {
        reference -> UUID? in
        guard case .membership(let identifier, let list, let item) = reference,
          list.id == secondListIdentifier, item.id == fixture.identifiers[64]
        else { return nil }
        return identifier
      }.first)
    await window.reload(
      query: .init(
        scope: .list(secondListIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "shared-item-lists", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.listSource?.content.name, "Second route")
    XCTAssertEqual(window.listSource?.progress.totalCount, 1)
    XCTAssertEqual(window.listSource?.progress.doneCount, 0)
    XCTAssertEqual(
      window.rowIdentities,
      [
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[64]),
          appearance: .listMembership(
            listId: secondListIdentifier, membershipId: secondMembershipIdentifier))
      ])
    guard case .loaded(let secondAppearance) = window.presentation(at: 0) else {
      XCTFail("The replacement List must load its own membership of the shared Item.")
      return
    }
    XCTAssertEqual(
      secondAppearance.row.identity,
      .appearance(
        source: .init(kind: .item, id: fixture.identifiers[64]),
        appearance: .listMembership(
          listId: secondListIdentifier, membershipId: secondMembershipIdentifier)))
    XCTAssertNotEqual(secondAppearance.row.identity, firstAppearance.row.identity)
    XCTAssertEqual(secondAppearance.row.title, "Activity 064")
    XCTAssertFalse(secondAppearance.row.effectiveDone == true)
    await window.reload(
      query: .init(
        scope: .list(firstListIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "shared-item-lists", savedRevision: UUID()))
    await window.requestRows(at: [64])
    XCTAssertEqual(window.listSource?.content.name, "First route")
    XCTAssertEqual(window.listSource?.progress.totalCount, 65)
    XCTAssertEqual(window.listSource?.progress.doneCount, 1)
    guard case .loaded(let revisited) = window.presentation(at: 64) else {
      XCTFail("Returning to the first List must retain that membership's local completion.")
      return
    }
    XCTAssertEqual(
      revisited.row.identity,
      .appearance(
        source: .init(kind: .item, id: fixture.identifiers[64]),
        appearance: .listMembership(
          listId: firstListIdentifier, membershipId: fixture.membershipIdentifiers[64])))
    XCTAssertTrue(revisited.row.effectiveDone == true)
    XCTAssertFalse(revisited.row.globalDone == true)
  }

  func testUnloadedListPageRefreshesManualOrderAndRemovedMembershipsWithItsHeader() async throws {
    let fixture = try await makeFixture(itemCount: 193, listName: "Changing route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), completion: .todo, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "saved-list-order", savedRevision: UUID()))
    _ = try await applyFixtureCommand(
      .reorderMembership(
        listId: listIdentifier, membershipId: fixture.membershipIdentifiers[192], placement: .first),
      fixture: fixture)
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 193)
    let reorderedIndices = [192] + Array(0..<192)
    XCTAssertEqual(
      window.rowIdentities,
      reorderedIndices.map { index in
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
      })
    XCTAssertEqual(window.listSource?.progress.totalCount, 193)
    XCTAssertEqual(window.listSource?.references.count, 193)
    guard case .loaded(let moved) = window.presentation(at: 0) else {
      XCTFail("A moved visible membership must remain loaded at its refreshed position.")
      return
    }
    XCTAssertEqual(
      moved.row.identity,
      .appearance(
        source: .init(kind: .item, id: fixture.identifiers[192]),
        appearance: .listMembership(
          listId: listIdentifier, membershipId: fixture.membershipIdentifiers[192])))
    XCTAssertEqual(moved.row.title, "Activity 192")
    _ = try await applyFixtureCommand(
      .removeMembership(listId: listIdentifier, membershipId: fixture.membershipIdentifiers[0]),
      fixture: fixture)
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 192)
    let survivingIndices = [192] + Array(1..<192)
    XCTAssertEqual(
      window.rowIdentities,
      survivingIndices.map { index in
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
      })
    XCTAssertEqual(window.listSource?.progress.totalCount, 192)
    XCTAssertEqual(window.listSource?.references.count, 192)
    XCTAssertEqual(
      window.listSource?.estimates.fullEstimate,
      .lowerBound(minutes: 0, missingEstimateCount: 192))
    guard case .loaded(let surviving) = window.presentation(at: 191) else {
      XCTFail("A surviving visible membership must remain loaded after another is removed.")
      return
    }
    XCTAssertEqual(
      surviving.row.identity,
      .appearance(
        source: .init(kind: .item, id: fixture.identifiers[191]),
        appearance: .listMembership(
          listId: listIdentifier, membershipId: fixture.membershipIdentifiers[191])))
    XCTAssertEqual(surviving.row.title, "Activity 191")
  }

  func testCancelsReleasesRowsAndReopensWithTheReplacementInboxQuery() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "before-leaving", savedRevision: UUID()))
    await window.requestRows(at: [128])
    window.cancel()
    XCTAssertEqual(window.state, .idle)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    XCTAssertEqual(window.matchingCount, 0)
    await window.requestRows(at: [128])
    guard case .loading = window.presentation(at: 128) else {
      XCTFail("A canceled catalog must release presentations and ignore later page requests.")
      return
    }
    await window.reload(
      query: .init(
        scope: .inbox, text: "Activity 11", completion: .todo, archive: .all,
        sort: .init(mode: .title, direction: .descending)),
      identity: .init(namespace: "replacement", savedRevision: UUID()))
    let expectedIndices = [119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 11]
    let expectedIdentifiers = expectedIndices.map { fixture.identifiers[$0] }
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, expectedIdentifiers.map { .source(.init(kind: .item, id: $0)) })
    XCTAssertEqual(window.matchingCount, 11)
    for (index, title) in [(0, "Activity 119"), (10, "Activity 011")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Replacement queries must return their own filtered and sorted presentations.")
        return
      }
      XCTAssertEqual(item.row.identity, .source(.init(kind: .item, id: expectedIdentifiers[index])))
      XCTAssertEqual(item.row.title, title)
    }
    let canceledReload = Task { @MainActor in
      await window.reload(
        query: .init(text: "No result", completion: .all, archive: .all),
        identity: .init(namespace: "canceled", savedRevision: UUID()))
    }
    canceledReload.cancel()
    await canceledReload.value
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, expectedIdentifiers.map { .source(.init(kind: .item, id: $0)) })
  }

  func testListCumulativeFiltersAndSortKeepFullProgressAndEstimateMetadata() async throws {
    let fixture = try await makeFixture(itemCount: 12, listName: "Mixed route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    _ = try await applyFixtureCommand(
      .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[1])), done: true),
      fixture: fixture)
    _ = try await applyFixtureCommand(
      .setArchive(source: .init(kind: .item, id: fixture.identifiers[3]), archived: true),
      fixture: fixture)
    _ = try await applyFixtureCommand(
      .reorderMembership(
        listId: listIdentifier, membershipId: fixture.membershipIdentifiers[9], placement: .first),
      fixture: fixture)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    let examples: [(PlannerItemQuery.Sort, [Int])] = [
      (.init(mode: .title), [0, 2, 4, 5, 6, 7, 8, 9]),
      (.init(mode: .title, direction: .descending), [9, 8, 7, 6, 5, 4, 2, 0]),
      (.init(mode: .manual), [9, 0, 2, 4, 5, 6, 7, 8]),
    ]
    for (sort, expectedIndices) in examples {
      await window.reload(
        query: .init(
          scope: .list(listIdentifier), text: "ACTÍVITY 00", completion: .todo, archive: .active,
          sort: sort),
        identity: .init(namespace: "filtered-sorted-list", savedRevision: UUID()))
      XCTAssertEqual(window.state, .ready)
      XCTAssertEqual(window.matchingCount, 8)
      let expectedIdentities = expectedIndices.map { index in
        PlannerRowIdentity.appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
      }
      XCTAssertEqual(window.rowIdentities, expectedIdentities)
      for (rowIndex, fixtureIndex) in expectedIndices.enumerated() {
        guard case .loaded(let item) = window.presentation(at: rowIndex) else {
          XCTFail("The filtered List must load the complete matching first page in Core order.")
          return
        }
        XCTAssertEqual(
          item.row.identity,
          .appearance(
            source: .init(kind: .item, id: fixture.identifiers[fixtureIndex]),
            appearance: .listMembership(
              listId: listIdentifier, membershipId: fixture.membershipIdentifiers[fixtureIndex])))
        XCTAssertEqual(item.row.identity, expectedIdentities[rowIndex])
        XCTAssertFalse(item.row.effectiveDone == true)
        XCTAssertFalse(item.row.archived == true)
      }
      XCTAssertEqual(window.listSource?.progress.totalCount, 12)
      XCTAssertEqual(window.listSource?.progress.doneCount, 1)
      XCTAssertEqual(window.listSource?.progress.archivedCount, 1)
      XCTAssertEqual(window.listSource?.references.count, 12)
      XCTAssertEqual(
        window.listSource?.estimates.fullEstimate,
        .lowerBound(minutes: 0, missingEstimateCount: 12))
      XCTAssertEqual(
        window.listSource?.estimates.remainingEstimate,
        .lowerBound(minutes: 0, missingEstimateCount: 10))
    }
  }

  func testDistinguishesQueryFailureFromEmptyResultsAndAcceptsAValidRetry() async throws {
    let fixture = try await makeFixture(itemCount: 65)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all, sort: .init(mode: .manual)),
      identity: .init(namespace: "invalid-query", savedRevision: UUID()))
    guard case .failed(let explanation) = window.state else {
      XCTFail(
        "An unsupported global Manual query must expose its failure, rather than empty results.")
      return
    }
    XCTAssertFalse(explanation.isEmpty)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    await window.reload(
      query: .init(text: "Absent museum", completion: .all, archive: .all),
      identity: .init(namespace: "empty-query", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    await window.requestRows(at: [0])
    XCTAssertEqual(window.state, .ready)
    await window.reload(
      query: .init(text: "ACTÍVITY 064", completion: .all, archive: .all),
      identity: .init(namespace: "corrected-query", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 1)
    XCTAssertEqual(window.rowIdentities, [.source(.init(kind: .item, id: fixture.identifiers[64]))])
    guard case .loaded(let item) = window.presentation(at: 0) else {
      XCTFail("A valid retry must show its own filtered Item rather than the prior query's page.")
      return
    }
    XCTAssertEqual(item.row.identity, .source(.init(kind: .item, id: fixture.identifiers[64])))
    XCTAssertEqual(item.row.title, "Activity 064")
  }

  func testConcurrentIdenticalVisibilityRequestsKeepOneConsistentWindow() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "concurrent-page-requests", savedRevision: UUID()))
    async let firstRequest: Void = window.requestRows(at: [128])
    async let repeatedRequest: Void = window.requestRows(at: [128])
    _ = await (firstRequest, repeatedRequest)
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    XCTAssertEqual(window.matchingCount, 193)
    for (index, title) in [(64, "Activity 064"), (128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Repeated visibility requests must leave one complete current window.")
        return
      }
      XCTAssertEqual(item.row.identity, .source(.init(kind: .item, id: fixture.identifiers[index])))
      XCTAssertEqual(item.row.title, title)
    }
    guard case .loading = window.presentation(at: 0) else {
      XCTFail("Concurrent requests must retain the same offscreen-page budget.")
      return
    }
  }

  func testPreCanceledVisibilityRequestPreservesTheCurrentWindow() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "canceled-visibility", savedRevision: UUID()))
    await window.requestRows(at: [192])
    let canceledRequest = Task { @MainActor in await window.requestRows(at: [0]) }
    canceledRequest.cancel()
    await canceledRequest.value
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 193)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("A pre-canceled visibility request must not release the current presentations.")
        return
      }
      XCTAssertEqual(item.row.identity, .source(.init(kind: .item, id: fixture.identifiers[index])))
      XCTAssertEqual(item.row.title, title)
    }
    guard case .loading = window.presentation(at: 0) else {
      XCTFail("A pre-canceled visibility request must not replace the current window.")
      return
    }
  }

  private struct Fixture {
    let directory: URL
    let planner: PlannerCore.Planner
    let session: PlannerDatasetSession
    let identifiers: [UUID]
    let listIdentifier: UUID?
    let membershipIdentifiers: [UUID]
  }

  private func applyFixtureCommand(_ command: PlannerCommand, fixture: Fixture) async throws
    -> PlannerAppliedResult
  {
    let result = await fixture.planner.execute(
      .init(operationId: UUID(), session: fixture.session, command: command))
    guard case .applied(let applied, .complete) = result.outcome else {
      XCTFail("The public fixture command must save completely: \(result.outcome)")
      throw CancellationError()
    }
    return applied
  }

  private func makeFixture(itemCount: Int, listName: String? = nil, listCount: Int = 1) async throws
    -> Fixture
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerItemWindowFixtures", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    print("Planner Item-window fixture directory: \(directory.path)")
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      throw CancellationError()
    }
    var expectedIdentifiers: [UUID] = []
    let listIdentifier = listName.map { _ in UUID() }
    let listLifetimeIdentifier = UUID()
    var membershipIdentifiers: [UUID] = []
    var memberships: [[String: Any]] = []
    var sources: [[String: Any]] = []
    for index in 0..<itemCount {
      let identifier = UUID()
      let lifetimeIdentifier = UUID()
      expectedIdentifiers.append(identifier)
      sources.append([
        "kind": "item", "id": identifier.uuidString, "lifetimeId": lifetimeIdentifier.uuidString,
        "createdAt": 813_000_000 + index, "updatedAt": 813_000_000 + index,
        "content": [
          "title": String(format: "Activity %03d", index), "subtitle": NSNull(),
          "notes": NSNull(), "location": NSNull(), "estimate": NSNull(),
        ],
        "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
      ])
      if let listIdentifier {
        let membershipIdentifier = UUID()
        membershipIdentifiers.append(membershipIdentifier)
        memberships.append([
          "id": membershipIdentifier.uuidString, "lifetimeId": UUID().uuidString,
          "list": [
            "kind": "list", "id": listIdentifier.uuidString,
            "lifetimeId": listLifetimeIdentifier.uuidString,
          ],
          "item": [
            "kind": "item", "id": identifier.uuidString,
            "lifetimeId": lifetimeIdentifier.uuidString,
          ],
          "rank": String(index * 1024), "localDone": false,
        ])
      }
    }
    if let listIdentifier, let listName {
      for index in 0..<listCount {
        sources.append([
          "kind": "list", "id": index == 0 ? listIdentifier.uuidString : UUID().uuidString,
          "lifetimeId": index == 0 ? listLifetimeIdentifier.uuidString : UUID().uuidString,
          "createdAt": 813_000_000, "updatedAt": 813_000_000,
          "content": [
            "name": index == 0 ? listName : listName + String(format: " %03d", index),
            "notes": NSNull(), "color": NSNull(),
            "iconName": NSNull(), "manualEstimate": NSNull(),
          ],
          "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
        ])
      }
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": memberships, "itineraryEntries": [], "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
    let decoded = planner.decodeImport(data)
    guard case .decoded(let backup) = decoded else {
      XCTFail("The public fixture import must decode: \(decoded)")
      throw CancellationError()
    }
    let reviewed = await planner.prepareReview(
      session: datasetSession, command: .applyImport(backup: backup))
    guard case .reviewed(let review) = reviewed else {
      XCTFail("The public fixture import must be reviewable: \(reviewed)")
      throw CancellationError()
    }
    let executed = await planner.execute(
      .init(
        operationId: UUID(), session: datasetSession, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = executed.outcome else {
      XCTFail("The public fixture import must save completely: \(executed.outcome)")
      throw CancellationError()
    }
    return Fixture(
      directory: directory, planner: planner, session: datasetSession,
      identifiers: expectedIdentifiers, listIdentifier: listIdentifier,
      membershipIdentifiers: membershipIdentifiers)
  }
}
