import Foundation
import PlannerCore
import PlannerPreviews
import XCTest

@testable import Planner

@MainActor
final class SavedMapCollectionTests: XCTestCase {
  func testARealConcurrentWriteRestartsTheCollectionInsteadOfPublishingAStaleFailure() async throws
  {
    let (planner, session) = try await makePlanner()
    var sources: [PlannerEntityReference] = []
    for index in 0..<3 {
      sources.append(
        try await createItem(
          title: "Concurrent \(index)",
          location: .init(
            displayName: nil, formattedAddress: nil,
            coordinate: .init(latitude: Double(35 + index), longitude: Double(139 + index))),
          planner: planner, session: session))
    }
    let addresses = RecordingMapAddressProvider()
    let maps = RecordingMapLinkProvider()
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: addresses), mapsPreviews: .init(provider: maps))
    for attempt in 0..<8 {
      let load = Task {
        await collection.reload(
          planner: planner, session: session,
          query: .init(scope: .global, completion: .all, archive: .all),
          identity: .init(namespace: "concurrent-map-write", savedRevision: UUID()))
      }
      let write = Task {
        await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .setCompletion(
              scope: .globalItem(itemId: sources[0].id), done: attempt.isMultiple(of: 2))))
      }
      await load.value
      let result = await write.value
      guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
      XCTAssertEqual(
        collection.state, .ready, "A real concurrent save must refresh stale Map reads.")
      XCTAssertEqual(collection.rows.map(\.identity), sources.map { .source($0) })
      XCTAssertEqual(collection.matchingCount, 3)
      XCTAssertEqual(collection.locatedCount, 3)
    }
    XCTAssertTrue(addresses.requests.isEmpty)
    XCTAssertTrue(maps.requests.isEmpty)
  }

  func testFilteredListsKeepHeaderOnlyBranchesAndExactRepeatedContexts() async throws {
    let (planner, session) = try await makePlanner()
    let list = try await apply(
      .createList(content: .init(name: "Museum group")), planner: planner, session: session)
    let empty = try await apply(
      .createList(content: .init(name: "Empty group")), planner: planner, session: session)
    var sources: [PlannerEntityReference] = []
    var memberships: [UUID] = []
    for index in 0..<3 {
      let source = try await createItem(
        title: "Activity \(index)",
        location: .init(
          displayName: nil, formattedAddress: nil,
          coordinate: .init(latitude: Double(35 + index), longitude: Double(139 + index))),
        planner: planner, session: session)
      sources.append(source)
      let result = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: source.id, listId: list.id, placement: .last)))
      guard case .applied(let applied, .complete) = result.outcome,
        case .membership(let identifier, _, _)? = applied.generatedReferences.first
      else { throw CancellationError() }
      memberships.append(identifier)
    }
    for command: PlannerCommand in [
      .setCompletion(scope: .globalItem(itemId: sources[1].id), done: true),
      .setArchive(source: sources[2], archived: true),
    ] {
      let result = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
    }
    let itinerary = try await apply(
      .createItinerary(content: .init(title: "Filtered trip")), planner: planner, session: session)
    var entries: [UUID] = []
    for source in [list, list, sources[0]] {
      let result = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)))
      guard case .applied(let applied, .complete) = result.outcome,
        case .itineraryEntry(let identifier, _, _)? = applied.generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    let addresses = RecordingMapAddressProvider()
    let maps = RecordingMapLinkProvider()
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: addresses), mapsPreviews: .init(provider: maps))
    let identity = SavedItemWindowIdentity(namespace: "map-contexts", savedRevision: UUID())
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    await collection.reload(
      planner: planner, session: session,
      query: .init(
        scope: .list(list.id), completion: .todo, archive: .active, sort: .init(mode: .manual)),
      identity: identity)
    XCTAssertEqual(collection.state, .ready)
    XCTAssertEqual(collection.collection?.source, list)
    XCTAssertEqual(collection.collection?.title, "Museum group")
    XCTAssertEqual(collection.matchingCount, 1)
    XCTAssertEqual(
      collection.rows.map(\.identity),
      [
        .appearance(
          source: sources[0],
          appearance: .listMembership(listId: list.id, membershipId: memberships[0]))
      ])
    XCTAssertEqual(
      collection.rows.first?.placement,
      .listMembership(membershipId: memberships[0], childPosition: 1))
    XCTAssertTrue(collection.listBranches.isEmpty)
    await collection.reload(
      planner: planner, session: session,
      query: .init(
        scope: .itinerary(itinerary.id), text: "Museum group", completion: .all, archive: .all),
      identity: identity)
    XCTAssertEqual(collection.state, .ready)
    XCTAssertEqual(collection.collection?.source, itinerary)
    XCTAssertEqual(collection.matchingCount, 0)
    XCTAssertTrue(collection.rows.isEmpty)
    XCTAssertTrue(collection.groups.isEmpty)
    XCTAssertEqual(collection.listBranches.map(\.entryId), Array(entries.prefix(2)))
    XCTAssertEqual(collection.listBranches.map(\.routePosition), [1, 2])
    XCTAssertEqual(collection.listBranches.map(\.matchesHeader), [true, true])
    XCTAssertEqual(collection.listBranches.map(\.matchingChildCount), [0, 0])
    XCTAssertEqual(collection.listBranches.map { $0.list.source }, [list, list])
    await collection.reload(
      planner: planner, session: session,
      query: .init(
        scope: .itinerary(itinerary.id), text: "Activity", completion: .todo, archive: .active,
        sort: .init(mode: .manual)), identity: identity)
    let expected: [PlannerRowIdentity] = [
      .appearance(
        source: sources[0],
        appearance: .expandedListItem(
          itineraryId: itinerary.id, listEntryId: entries[0], membershipId: memberships[0])),
      .appearance(
        source: sources[0],
        appearance: .expandedListItem(
          itineraryId: itinerary.id, listEntryId: entries[1], membershipId: memberships[0])),
      .appearance(
        source: sources[0],
        appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: entries[2])),
    ]
    XCTAssertEqual(collection.rows.map(\.identity), expected)
    XCTAssertEqual(collection.matchingCount, 3)
    XCTAssertEqual(collection.listBranches.map(\.matchesHeader), [false, false])
    XCTAssertEqual(collection.listBranches.map(\.matchingChildCount), [1, 1])
    XCTAssertEqual(collection.groups.first?.rows.map(\.identity), expected)
    await collection.reload(
      planner: planner, session: session,
      query: .init(scope: .list(empty.id), completion: .all, archive: .all), identity: identity)
    XCTAssertEqual(collection.state, .ready)
    XCTAssertEqual(collection.collection?.source, empty)
    XCTAssertEqual(collection.matchingCount, 0)
    XCTAssertTrue(collection.rows.isEmpty)
    XCTAssertTrue(collection.listBranches.isEmpty)
    XCTAssertTrue(addresses.requests.isEmpty)
    XCTAssertTrue(maps.requests.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertEqual(after, before)
  }

  func testAnAddressChoiceCanChangeWithoutAnotherProviderLookup() async throws {
    let (planner, session) = try await makePlanner()
    let source = try await createItem(
      title: "Choose again",
      location: .init(displayName: nil, formattedAddress: "Two places", coordinate: nil),
      planner: planner, session: session)
    let first = PlannerAddressCandidate(
      id: "first", name: "First", address: nil, latitude: 35, longitude: 139)
    let second = PlannerAddressCandidate(
      id: "second", name: "Second", address: nil, latitude: 36, longitude: 140)
    let provider = RecordingMapAddressProvider()
    provider.candidatesByAddress["Two places"] = [first, second]
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: provider),
      mapsPreviews: .init(provider: RecordingMapLinkProvider()))
    await collection.reload(
      planner: planner, session: session,
      query: .init(scope: .global, completion: .all, archive: .all),
      identity: .init(namespace: "change-address-choice", savedRevision: UUID()))
    try await waitUntil {
      if case .addressCandidates = collection.resolution(for: .source(source)) { return true }
      return false
    }
    guard case .addressCandidates(let request, _) = collection.resolution(for: .source(source))
    else {
      throw CancellationError()
    }
    XCTAssertTrue(collection.chooseAddressCandidate(first, request: request, for: .source(source)))
    XCTAssertEqual(collection.addressChoices(for: .source(source))?.selectedCandidateId, "first")
    XCTAssertEqual(collection.groups.map(\.coordinate), [.init(latitude: 35, longitude: 139)])
    XCTAssertTrue(collection.chooseAddressCandidate(second, request: request, for: .source(source)))
    XCTAssertEqual(collection.addressChoices(for: .source(source))?.selectedCandidateId, "second")
    XCTAssertEqual(collection.groups.map(\.coordinate), [.init(latitude: 36, longitude: 140)])
    XCTAssertEqual(provider.requests, ["Two places"])
  }

  func testAddressAndMapsLookupsShareFourSlotsAcrossRealDatasetChanges() async throws {
    let (originalPlanner, originalSession) = try await makePlanner()
    let (nextPlanner, nextSession) = try await makePlanner()
    let addresses = HeldMapAddressProvider()
    let maps = HeldMapLinkProvider()
    var links: [Int: String] = [:]
    for index in 0..<8 {
      let planner = index < 6 ? originalPlanner : nextPlanner
      let session = index < 6 ? originalSession : nextSession
      if index.isMultiple(of: 2) {
        _ = try await createItem(
          title: "Place \(index)",
          location: .init(
            displayName: nil, formattedAddress: "Address \(index)", coordinate: nil),
          planner: planner, session: session)
      } else {
        let originalURL = "https://maps.apple.com/place?coordinate=\(30 + index),\(134 + index)"
        links[index] = originalURL
        let candidate = await PlannerMapsLinkResolver().preview(originalURL: originalURL)
        maps.candidatesByURL[originalURL] = try XCTUnwrap(candidate)
        _ = try await apply(
          .createItem(
            content: .init(title: "Place \(index)", links: [.init(originalUrl: originalURL)])),
          planner: planner, session: session)
      }
    }
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: addresses), mapsPreviews: .init(provider: maps))
    await collection.reload(
      planner: originalPlanner, session: originalSession,
      query: .init(scope: .global, completion: .all, archive: .all),
      identity: .init(namespace: "original-real-map-dataset", savedRevision: UUID()))
    try await waitUntil { addresses.requests.count + maps.requests.count == 4 }
    XCTAssertEqual(Set(addresses.requests), ["Address 0", "Address 2"])
    XCTAssertEqual(Set(maps.requests), [try XCTUnwrap(links[1]), try XCTUnwrap(links[3])])
    await collection.reload(
      planner: nextPlanner, session: nextSession,
      query: .init(scope: .global, completion: .all, archive: .all),
      identity: .init(namespace: "next-real-map-dataset", savedRevision: UUID()))
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertEqual(collection.rows.map(\.title), ["Place 6", "Place 7"])
    XCTAssertEqual(addresses.requests.count + maps.requests.count, 4)
    XCTAssertEqual(collection.locatedCount, 0)
    addresses.finish("Address 0")
    try await waitUntil { addresses.requests.contains("Address 6") }
    XCTAssertEqual(addresses.requests.count + maps.requests.count, 5)
    XCTAssertEqual(collection.locatedCount, 0)
    maps.finish(try XCTUnwrap(links[1]))
    try await waitUntil { maps.requests.contains(links[7] ?? "") }
    XCTAssertEqual(addresses.requests.count + maps.requests.count, 6)
    XCTAssertEqual(collection.locatedCount, 0)
    addresses.finishAll()
    maps.finishAll()
    try await waitUntil { collection.locatedCount == 2 }
    XCTAssertEqual(
      collection.groups.map(\.coordinate),
      [.init(latitude: 36, longitude: 140), .init(latitude: 37, longitude: 141)])
    XCTAssertFalse(addresses.requests.contains("Address 4"))
    XCTAssertFalse(maps.requests.contains(links[5] ?? ""))
    XCTAssertEqual(addresses.outstandingCount + maps.outstandingCount, 0)
  }

  func testMapsLinkChoiceIsTemporaryExactAndIndependentForRepeatedAppearances() async throws {
    let (planner, session) = try await makePlanner()
    let searchURL = "https://www.google.com/maps/search/?api=1&query=Museum"
    let pinURL = "https://maps.apple.com/place?name=Chosen&coordinate=37,141"
    let source = try await apply(
      .createItem(
        content: .init(
          title: "Two map links",
          links: [.init(originalUrl: searchURL), .init(originalUrl: pinURL)])),
      planner: planner, session: session)
    let itinerary = try await apply(
      .createItinerary(content: .init(title: "Two stops")), planner: planner, session: session)
    for _ in 0..<2 {
      let result = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addItineraryEntry(
            itineraryId: itinerary.id, source: source, placement: .last)))
      guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
    }
    let search = await PlannerMapsLinkResolver().preview(originalURL: searchURL)
    let pin = await PlannerMapsLinkResolver().preview(originalURL: pinURL)
    let maps = RecordingMapLinkProvider()
    maps.candidatesByURL[searchURL] = try XCTUnwrap(search)
    maps.candidatesByURL[pinURL] = try XCTUnwrap(pin)
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: RecordingMapAddressProvider()),
      mapsPreviews: .init(provider: maps))
    let query = PlannerItemQuery(
      scope: .itinerary(itinerary.id), completion: .all, archive: .all, sort: .init(mode: .manual))
    await collection.reload(
      planner: planner, session: session, query: query,
      identity: .init(namespace: "exact-link-choice", savedRevision: UUID()))
    guard collection.rows.count == 2 else { throw CancellationError() }
    let first = collection.rows[0]
    let second = collection.rows[1]
    try await waitUntil { collection.resolution(for: first.identity) == .unavailable }
    XCTAssertEqual(collection.resolution(for: second.identity), .unavailable)
    XCTAssertEqual(collection.locatedCount, 0, "A text search must never invent a coordinate.")
    XCTAssertEqual(collection.mapsPreview(for: first.identity)?.displayName, "Museum")
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let request = PlannerLinkPreviewRequest(
      source: .init(
        namespace: "exact-link-choice", sourceId: source.id,
        sourceLifetimeId: first.sourceLifetimeId), linkId: first.mapsLinks[1].linkId,
      originalURL: pinURL)
    let wrongURL = PlannerLinkPreviewRequest(
      source: request.source, linkId: request.linkId, originalURL: searchURL)
    XCTAssertFalse(collection.chooseMapsLink(wrongURL, for: first.identity))
    XCTAssertTrue(collection.chooseMapsLink(request, for: first.identity))
    try await waitUntil { collection.locatedCount == 1 }
    XCTAssertEqual(collection.resolution(for: second.identity), .unavailable)
    XCTAssertEqual(collection.groups.first?.rows.map(\.identity), [first.identity])
    XCTAssertEqual(collection.mapsPreview(for: first.identity)?.displayName, "Chosen")
    XCTAssertEqual(maps.requests, [searchURL, pinURL])
    XCTAssertTrue(collection.chooseMapsLink(request, for: second.identity))
    try await waitUntil { collection.locatedCount == 2 }
    XCTAssertEqual(
      collection.groups.first?.rows.map(\.identity), [first.identity, second.identity])
    XCTAssertEqual(
      maps.requests, [searchURL, pinURL], "The second appearance reuses the cached link.")
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertEqual(after, before)
    await collection.reload(
      planner: planner, session: session, query: query,
      identity: .init(namespace: "another-map-dataset", savedRevision: UUID()))
    XCTAssertFalse(collection.chooseMapsLink(request, for: first.identity))
    try await waitUntil { collection.resolution(for: first.identity) == .unavailable }
    XCTAssertEqual(collection.locatedCount, 0)
    XCTAssertEqual(maps.requests, [searchURL, pinURL, searchURL])
  }

  func testNameOnlyLocationUsesFirstMapsLinkAndRetainsItsSearchUncertainty() async throws {
    let (planner, session) = try await makePlanner()
    let firstURL = "https://www.google.com/maps/search/?api=1&query=35,139"
    let secondURL = "https://maps.apple.com/place?name=Second&coordinate=37,141"
    let linked = try await apply(
      .createItem(
        content: .init(
          title: "Named museum",
          location: .init(displayName: "Name only", formattedAddress: nil, coordinate: nil),
          links: [.init(originalUrl: firstURL), .init(originalUrl: secondURL)])),
      planner: planner, session: session)
    let pinned = try await apply(
      .createItem(
        content: .init(
          title: "Pinned museum",
          location: .init(
            displayName: nil, formattedAddress: nil,
            coordinate: .init(latitude: 33, longitude: 137)),
          links: [.init(originalUrl: secondURL)])), planner: planner, session: session)
    let addressed = try await apply(
      .createItem(
        content: .init(
          title: "Addressed museum",
          location: .init(displayName: nil, formattedAddress: "Owned address", coordinate: nil),
          links: [.init(originalUrl: secondURL)])), planner: planner, session: session)
    let itinerary = try await apply(
      .createItinerary(content: .init(title: "Linked route")), planner: planner, session: session)
    for source in [linked, pinned, addressed, linked] {
      let result = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addItineraryEntry(
            itineraryId: itinerary.id, source: source, placement: .last)))
      guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
    }
    let addresses = RecordingMapAddressProvider()
    addresses.candidatesByAddress["Owned address"] = [
      .init(id: "addressed", name: "Addressed museum", address: nil, latitude: 36, longitude: 140)
    ]
    let maps = RecordingMapLinkProvider()
    let candidate = await PlannerMapsLinkResolver().preview(originalURL: firstURL)
    maps.candidatesByURL[firstURL] = try XCTUnwrap(candidate)
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: addresses), mapsPreviews: .init(provider: maps))
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    await collection.reload(
      planner: planner, session: session,
      query: .init(
        scope: .itinerary(itinerary.id), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "linked-map-route", savedRevision: UUID()))
    try await waitUntil { collection.locatedCount == 4 }
    XCTAssertEqual(collection.matchingCount, 4)
    XCTAssertEqual(collection.noInputCount, 0)
    XCTAssertEqual(collection.unresolvedCount, 0)
    XCTAssertEqual(maps.requests, [firstURL])
    XCTAssertEqual(addresses.requests, ["Owned address"])
    XCTAssertEqual(
      collection.groups.map(\.coordinate),
      [
        .init(latitude: 35, longitude: 139), .init(latitude: 33, longitude: 137),
        .init(latitude: 36, longitude: 140),
      ])
    guard collection.rows.count == 4, collection.groups.count == 3 else {
      XCTFail("First-link resolution must locate both repeated appearances.")
      return
    }
    let first = collection.rows[0]
    let repeated = collection.rows[3]
    XCTAssertEqual(collection.groups[0].rows.map(\.identity), [first.identity, repeated.identity])
    XCTAssertEqual(collection.mapsPreview(for: first.identity)?.provider, .googleMaps)
    XCTAssertEqual(collection.mapsPreview(for: repeated.identity)?.attributionText, "Google Maps")
    XCTAssertEqual(
      collection.mapsPreview(for: first.identity)?.uncertaintyReasons,
      ["Place details haven't been verified for this search link."])
    XCTAssertNil(collection.mapsPreview(for: collection.rows[1].identity))
    XCTAssertNil(collection.mapsPreview(for: collection.rows[2].identity))
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertEqual(after, before)
  }

  func testAmbiguousAddressNeedsAnExactChoiceAndRejectsItAfterTheAddressChanges() async throws {
    let (planner, session) = try await makePlanner()
    let source = try await createItem(
      title: "Choose museum",
      location: .init(displayName: nil, formattedAddress: "Ambiguous address", coordinate: nil),
      planner: planner, session: session)
    let first = PlannerAddressCandidate(
      id: "first", name: "First museum", address: "First street", latitude: 35, longitude: 139)
    let second = PlannerAddressCandidate(
      id: "second", name: "Second museum", address: "Second street", latitude: 36, longitude: 140)
    let recovered = PlannerAddressCandidate(
      id: "recovered", name: "New museum", address: nil, latitude: 37, longitude: 141)
    let provider = RecordingMapAddressProvider()
    provider.candidatesByAddress["Ambiguous address"] = [first, second]
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: provider),
      mapsPreviews: .init(provider: RecordingMapLinkProvider()))
    let identity = SavedItemWindowIdentity(namespace: "map-address-choices", savedRevision: UUID())
    let query = PlannerItemQuery(scope: .global, completion: .all, archive: .all)
    await collection.reload(planner: planner, session: session, query: query, identity: identity)
    try await waitUntil {
      if case .addressCandidates = collection.resolution(for: .source(source)) { return true }
      return false
    }
    guard
      case .addressCandidates(let request, let candidates) = collection.resolution(
        for: .source(source))
    else {
      XCTFail("An ambiguous address must expose its actual candidates without choosing a pin.")
      return
    }
    XCTAssertEqual(candidates, [first, second])
    XCTAssertEqual(collection.locatedCount, 0)
    XCTAssertEqual(collection.unresolvedCount, 1)
    guard case .exported(let beforeChoice) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertFalse(
      collection.chooseAddressCandidate(recovered, request: request, for: .source(source)))
    XCTAssertTrue(
      collection.chooseAddressCandidate(second, request: request, for: .source(source)))
    XCTAssertEqual(collection.groups.map(\.coordinate), [.init(latitude: 36, longitude: 140)])
    guard case .exported(let afterChoice) = await planner.exportData(session: session),
      case .source(.item(let saved)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    XCTAssertEqual(afterChoice, beforeChoice)
    let edit = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: source.id,
          changes: .init(
            location: .set(
              .init(displayName: nil, formattedAddress: "New address", coordinate: nil))),
          expectedFieldHashes: saved.fieldHashes)))
    guard case .applied(_, .complete) = edit.outcome else { throw CancellationError() }
    await collection.reload(
      planner: planner, session: session, query: query,
      identity: .init(namespace: identity.namespace, savedRevision: UUID()))
    try await waitUntil { collection.resolution(for: .source(source)) == .unavailable }
    XCTAssertFalse(
      collection.chooseAddressCandidate(second, request: request, for: .source(source)))
    XCTAssertTrue(collection.groups.isEmpty)
    provider.candidatesByAddress["New address"] = [recovered]
    collection.retry(for: .source(source))
    try await waitUntil { collection.locatedCount == 1 }
    XCTAssertEqual(collection.groups.map(\.coordinate), [.init(latitude: 37, longitude: 141)])
    XCTAssertEqual(provider.requests, ["Ambiguous address", "New address", "New address"])
  }

  func testMapWaitsForTheSameAddressAlreadyLoadingInDetails() async throws {
    let (planner, session) = try await makePlanner()
    let source = try await createItem(
      title: "Shared address",
      location: .init(displayName: nil, formattedAddress: "Address 6", coordinate: nil),
      planner: planner, session: session)
    guard
      case .source(.item(let item)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    let provider = HeldMapAddressProvider()
    let previews = PlannerAddressPreviews(provider: provider)
    let request = PlannerAddressPreviewRequest(
      source: .init(
        namespace: "detail-in-flight", sourceId: source.id,
        sourceLifetimeId: item.sourceLifetimeId), address: "Address 6")
    let detail = Task { await previews.loadAddress(request) }
    try await waitUntil { provider.requests.count == 1 }
    let collection = SavedMapCollection(
      addressPreviews: previews, mapsPreviews: .init(provider: RecordingMapLinkProvider()))
    await collection.reload(
      planner: planner, session: session,
      query: .init(scope: .global, completion: .all, archive: .all),
      identity: .init(namespace: "detail-in-flight", savedRevision: UUID()))
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertEqual(collection.resolution(for: .source(source)), .loading)
    XCTAssertEqual(collection.unresolvedCount, 1)
    XCTAssertEqual(provider.requests, ["Address 6"])
    XCTAssertEqual(provider.outstandingCount, 1)
    provider.finishAll()
    await detail.value
    try await waitUntil { collection.locatedCount == 1 }
    XCTAssertEqual(
      collection.resolution(for: .source(source)),
      .located(.init(latitude: 36, longitude: 140)))
    XCTAssertEqual(provider.requests, ["Address 6"])
    XCTAssertEqual(provider.outstandingCount, 0)
  }

  func testUIDeadlineOffersRetryWithoutReleasingTheOccupiedProvider() async throws {
    let (planner, session) = try await makePlanner()
    let source = try await createItem(
      title: "Slow museum",
      location: .init(displayName: nil, formattedAddress: "Address 6", coordinate: nil),
      planner: planner, session: session)
    let provider = HeldMapAddressProvider()
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: provider),
      mapsPreviews: .init(provider: RecordingMapLinkProvider()))
    let load = Task {
      await collection.reload(
        planner: planner, session: session,
        query: .init(scope: .global, completion: .all, archive: .all),
        identity: .init(namespace: "map-deadline", savedRevision: UUID()))
    }
    try await waitUntil { provider.requests.count == 1 }
    XCTAssertEqual(collection.resolution(for: .source(source)), .loading)
    try await Task.sleep(for: .milliseconds(10_300))
    XCTAssertEqual(collection.state, .ready)
    XCTAssertEqual(collection.resolution(for: .source(source)), .unavailable)
    XCTAssertEqual(collection.unresolvedCount, 1)
    XCTAssertEqual(collection.locatedCount, 0)
    XCTAssertEqual(provider.outstandingCount, 1)
    collection.retry(for: .source(source))
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertEqual(
      provider.requests.count, 1, "Retry must wait for the occupied attempt to finish.")
    XCTAssertEqual(collection.locatedCount, 0)
    provider.finishAll()
    await load.value
    try await waitUntil { collection.locatedCount == 1 }
    XCTAssertEqual(provider.requests, ["Address 6", "Address 6"])
    XCTAssertEqual(
      collection.resolution(for: .source(source)),
      .located(.init(latitude: 36, longitude: 140)))
    XCTAssertEqual(collection.unresolvedCount, 0)
    XCTAssertEqual(provider.outstandingCount, 0)
    collection.cancel()
    XCTAssertNil(collection.resolution(for: .source(source)))
  }

  func testCancelledProvidersKeepTheirSlotsUntilTheyActuallyFinish() async throws {
    let (planner, session) = try await makePlanner()
    for index in 0..<8 {
      _ = try await createItem(
        title: index < 6 ? "First \(index)" : "Later \(index)",
        location: .init(
          displayName: nil, formattedAddress: "Address \(index)", coordinate: nil),
        planner: planner, session: session)
    }
    let provider = HeldMapAddressProvider()
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: provider),
      mapsPreviews: .init(provider: RecordingMapLinkProvider()))
    let original = Task {
      await collection.reload(
        planner: planner, session: session,
        query: .init(scope: .global, text: "First", completion: .all, archive: .all),
        identity: .init(namespace: "occupied-map-slots", savedRevision: UUID()))
    }
    try await waitUntil { provider.requests.count == 4 }
    XCTAssertEqual(provider.requests, ["Address 0", "Address 1", "Address 2", "Address 3"])
    XCTAssertEqual(collection.rows.count, 6)
    collection.cancel()
    XCTAssertEqual(collection.state, .idle)
    XCTAssertTrue(collection.rows.isEmpty)
    let replacement = Task {
      await collection.reload(
        planner: planner, session: session,
        query: .init(scope: .global, text: "Later", completion: .all, archive: .all),
        identity: .init(namespace: "occupied-map-slots", savedRevision: UUID()))
    }
    try await waitUntil { collection.rows.count == 2 }
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertEqual(
      provider.requests.count, 4, "Cancellation cannot free an occupied provider slot.")
    XCTAssertEqual(collection.locatedCount, 0)
    provider.finish("Address 0")
    try await waitUntil { provider.requests.contains("Address 6") }
    XCTAssertEqual(provider.requests.count, 5)
    XCTAssertEqual(
      collection.locatedCount, 0, "An obsolete provider result cannot locate a new row.")
    provider.finish("Address 1")
    try await waitUntil { provider.requests.contains("Address 7") }
    XCTAssertEqual(provider.requests.count, 6)
    provider.finishAll()
    await original.value
    await replacement.value
    try await waitUntil { collection.locatedCount == 2 }
    XCTAssertEqual(collection.rows.map(\.title), ["Later 6", "Later 7"])
    XCTAssertEqual(
      collection.groups.map(\.coordinate),
      [.init(latitude: 36, longitude: 140), .init(latitude: 37, longitude: 141)])
    XCTAssertFalse(provider.requests.contains("Address 4"))
    XCTAssertFalse(provider.requests.contains("Address 5"))
    XCTAssertEqual(provider.outstandingCount, 0)
  }

  func testAddressResolutionReusesDetailsCacheAndKeepsRepeatedAppearanceChoices() async throws {
    let (planner, session) = try await makePlanner()
    let cached = try await createItem(
      title: "Cached museum",
      location: .init(displayName: nil, formattedAddress: "Cached address", coordinate: nil),
      planner: planner, session: session)
    let fresh = try await createItem(
      title: "Fresh museum",
      location: .init(displayName: nil, formattedAddress: "Fresh address", coordinate: nil),
      planner: planner, session: session)
    let owned = try await createItem(
      title: "Owned museum",
      location: .init(
        displayName: nil, formattedAddress: "Never look up this address",
        coordinate: .init(latitude: 33, longitude: 137)), planner: planner, session: session)
    let itinerary = try await apply(
      .createItinerary(content: .init(title: "Museum route")), planner: planner, session: session)
    var entries: [UUID] = []
    for source in [cached, fresh, cached, fresh, owned] {
      let result = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addItineraryEntry(
            itineraryId: itinerary.id, source: source, placement: .last)))
      guard case .applied(let applied, .complete) = result.outcome,
        case .itineraryEntry(let identifier, _, _)? = applied.generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    guard
      case .source(.item(let cachedSource)) = await planner.read(
        session: session, request: .source(cached))
    else { throw CancellationError() }
    let addressProvider = RecordingMapAddressProvider()
    addressProvider.candidatesByAddress = [
      "Cached address": [
        .init(id: "cached", name: "Cached place", address: nil, latitude: 35, longitude: 139)
      ],
      "Fresh address": [
        .init(id: "fresh", name: "Fresh place", address: nil, latitude: 36, longitude: 140)
      ],
    ]
    let addressPreviews = PlannerAddressPreviews(provider: addressProvider)
    await addressPreviews.loadAddress(
      .init(
        source: .init(
          namespace: "address-route", sourceId: cached.id,
          sourceLifetimeId: cachedSource.sourceLifetimeId), address: "Cached address"))
    let mapsProvider = RecordingMapLinkProvider()
    let collection = SavedMapCollection(
      addressPreviews: addressPreviews, mapsPreviews: .init(provider: mapsProvider))
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    await collection.reload(
      planner: planner, session: session,
      query: .init(
        scope: .itinerary(itinerary.id), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "address-route", savedRevision: UUID()))
    try await waitUntil { collection.locatedCount == 5 }
    XCTAssertEqual(collection.state, .ready)
    XCTAssertEqual(collection.collection?.source, itinerary)
    XCTAssertEqual(collection.collection?.title, "Museum route")
    XCTAssertEqual(collection.matchingCount, 5)
    XCTAssertEqual(collection.unresolvedCount, 0)
    XCTAssertEqual(collection.noInputCount, 0)
    XCTAssertEqual(addressProvider.requests, ["Cached address", "Fresh address"])
    XCTAssertTrue(mapsProvider.requests.isEmpty)
    XCTAssertEqual(
      collection.groups.map(\.coordinate),
      [
        .init(latitude: 35, longitude: 139), .init(latitude: 36, longitude: 140),
        .init(latitude: 33, longitude: 137),
      ])
    guard collection.groups.count == 3 else {
      XCTFail("Both address previews and the owned coordinate must be located.")
      return
    }
    XCTAssertEqual(
      collection.groups[0].rows.map(\.identity),
      [0, 2].map {
        .appearance(
          source: cached,
          appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: entries[$0]))
      })
    XCTAssertEqual(
      collection.groups[1].rows.map(\.identity),
      [1, 3].map {
        .appearance(
          source: fresh,
          appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: entries[$0]))
      })
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertEqual(after, before)
  }

  func testCompleteCollectionKeepsOffscreenOwnedPinsAndExactGroupedChoices() async throws {
    let (planner, session) = try await makePlanner()
    let coordinates: [Int: PlannerCoordinate] = [
      0: .init(latitude: 35, longitude: 139),
      63: .init(latitude: 35, longitude: 139),
      64: .init(latitude: 36, longitude: 140),
      129: .init(latitude: 37, longitude: 141),
    ]
    var expectedSources: [PlannerEntityReference] = []
    for index in 0..<130 {
      let location: PlannerOwnedLocation? = coordinates[index].map { coordinate in
        .init(displayName: "Owned place \(index)", formattedAddress: nil, coordinate: coordinate)
      }
      let result = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(title: String(format: "Map Activity %03d", index), location: location))))
      guard case .applied(let applied, .complete) = result.outcome else {
        XCTFail("The real fixture Item must save completely: \(result.outcome)")
        return
      }
      expectedSources.append(try XCTUnwrap(applied.generated.first))
    }
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let addressProvider = RecordingMapAddressProvider()
    let mapsProvider = RecordingMapLinkProvider()
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: addressProvider), mapsPreviews: .init(provider: mapsProvider)
    )
    await collection.reload(
      planner: planner, session: session,
      query: .init(scope: .global, completion: .all, archive: .all),
      identity: .init(namespace: "owned-map-pins", savedRevision: UUID()))
    XCTAssertEqual(collection.state, .ready)
    XCTAssertEqual(collection.matchingCount, 130)
    XCTAssertEqual(collection.rows.map(\.identity), expectedSources.map { .source($0) })
    XCTAssertNil(collection.collection)
    XCTAssertTrue(collection.listBranches.isEmpty)
    XCTAssertEqual(collection.locatedCount, 4)
    XCTAssertEqual(collection.noInputCount, 126)
    XCTAssertEqual(collection.unresolvedCount, 0)
    XCTAssertEqual(
      collection.groups.map(\.coordinate),
      [
        .init(latitude: 35, longitude: 139), .init(latitude: 36, longitude: 140),
        .init(latitude: 37, longitude: 141),
      ])
    guard collection.rows.count == 130, collection.groups.count == 3 else {
      XCTFail("The complete Map must retain all rows and the three literal coordinate groups.")
      return
    }
    XCTAssertEqual(
      collection.groups[0].rows.map(\.identity),
      [.source(expectedSources[0]), .source(expectedSources[63])])
    XCTAssertEqual(collection.groups[1].rows.map(\.identity), [.source(expectedSources[64])])
    XCTAssertEqual(collection.groups[2].rows.map(\.identity), [.source(expectedSources[129])])
    for position in [0, 63, 64, 129] {
      XCTAssertEqual(collection.rows[position].ownedLocation?.coordinate, coordinates[position])
      XCTAssertEqual(collection.rows[position].title, String(format: "Map Activity %03d", position))
    }
    XCTAssertTrue(addressProvider.requests.isEmpty)
    XCTAssertTrue(mapsProvider.requests.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertEqual(after, before)
  }

  func testDirectionsKeepRepeatedAppearancesAndNeverBridgeMissingStops() async throws {
    let (planner, session) = try await makePlanner()
    let hotel = try await createItem(
      title: "Hotel",
      location: .init(
        displayName: nil, formattedAddress: nil,
        coordinate: .init(latitude: 35.668, longitude: 139.712)),
      planner: planner, session: session)
    let missing = try await apply(
      .createItem(content: .init(title: "Unknown stop")), planner: planner, session: session)
    let itinerary = try await apply(
      .createItinerary(content: .init(title: "Ordered route")), planner: planner, session: session)
    var entries: [UUID] = []
    for source in [hotel, hotel, missing, hotel] {
      let result = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addItineraryEntry(
            itineraryId: itinerary.id, source: source, placement: .last)))
      guard case .applied(let applied, .complete) = result.outcome,
        case .itineraryEntry(let identifier, _, _)? = applied.generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    let collection = SavedMapCollection(
      addressPreviews: .init(provider: RecordingMapAddressProvider()),
      mapsPreviews: .init(provider: RecordingMapLinkProvider()))
    await collection.reload(
      planner: planner, session: session,
      query: .init(
        scope: .itinerary(itinerary.id), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "route-gaps", savedRevision: UUID()))
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let directions = SavedMapDirections()
    let request = SavedMapDirections.Request(collection: collection, directions: directions)
    XCTAssertEqual(request.stops.map(\.title), ["Hotel", "Hotel", "Unknown stop", "Hotel"])
    XCTAssertEqual(
      request.stops.map(\.identity),
      zip([hotel, hotel, missing, hotel], entries).map {
        .appearance(
          source: $0, appearance: .directItineraryItem(itineraryId: itinerary.id, entryId: $1))
      })
    XCTAssertEqual(
      request.stops.map(\.coordinate),
      [
        .init(latitude: 35.668, longitude: 139.712),
        .init(latitude: 35.668, longitude: 139.712), nil,
        .init(latitude: 35.668, longitude: 139.712),
      ])
    await directions.reload(request)
    XCTAssertEqual(directions.legs.count, 3)
    guard case .sameLocation = directions.legs[0].outcome,
      case .missingLocation = directions.legs[1].outcome,
      case .missingLocation = directions.legs[2].outcome
    else {
      return XCTFail("Unknown stops must leave gaps; adjacent identical stops need no lookup.")
    }
    XCTAssertTrue(directions.routes.isEmpty)
    XCTAssertFalse(directions.isLoading)
    directions.mode = .driving
    XCTAssertTrue(directions.legs.isEmpty, "Changing travel mode must remove old route geometry.")
    directions.mode = .transit
    await directions.reload(.init(collection: collection, directions: directions))
    XCTAssertEqual(directions.legs.count, 3)
    directions.cancel()
    XCTAssertTrue(directions.legs.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertEqual(after, before, "Route planning must not modify saved plans or estimates.")
  }

  private func makePlanner() async throws -> (PlannerCore.Planner, PlannerDatasetSession) {
    let storage = try makePlannerIntentStorage()
    print("Planner Map-collection fixture directory: \(storage.directory.path)")
    let planner = PlannerCore.Planner(configuration: storage.configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    return (planner, session)
  }

  private func createItem(
    title: String, location: PlannerOwnedLocation, planner: PlannerCore.Planner,
    session: PlannerDatasetSession
  ) async throws -> PlannerEntityReference {
    try await apply(
      .createItem(content: .init(title: title, location: location)), planner: planner,
      session: session)
  }

  private func apply(
    _ command: PlannerCommand, planner: PlannerCore.Planner, session: PlannerDatasetSession
  ) async throws -> PlannerEntityReference {
    let result = await planner.execute(
      .init(operationId: UUID(), session: session, command: command))
    guard case .applied(let applied, .complete) = result.outcome else {
      XCTFail("Fixture command must save completely: \(result.outcome)")
      throw CancellationError()
    }
    return try XCTUnwrap(applied.generated.first)
  }

  private func waitUntil(_ predicate: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !predicate(), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(predicate(), "The production collection must publish the expected result.")
  }
}

@MainActor
private final class RecordingMapAddressProvider: PlannerAddressPreviewProvider {
  private(set) var requests: [String] = []
  var candidatesByAddress: [String: [PlannerAddressCandidate]] = [:]

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] {
    requests.append(address)
    return candidatesByAddress[address] ?? []
  }
}

@MainActor
private final class RecordingMapLinkProvider: PlannerMapsPreviewProvider {
  private(set) var requests: [String] = []
  var candidatesByURL: [String: PlannerCapturePreviewCandidate] = [:]

  func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate? {
    requests.append(originalURL)
    return candidatesByURL[originalURL]
  }
}

@MainActor
private final class HeldMapAddressProvider: PlannerAddressPreviewProvider {
  private(set) var requests: [String] = []
  private var continuations: [String: CheckedContinuation<[PlannerAddressCandidate], Never>] = [:]
  private var automaticallyFinish = false
  var outstandingCount: Int { continuations.count }

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] {
    requests.append(address)
    if automaticallyFinish { return candidates(for: address) }
    return await withCheckedContinuation { continuations[address] = $0 }
  }

  func finish(_ address: String) {
    continuations.removeValue(forKey: address)?.resume(returning: candidates(for: address))
  }

  func finishAll() {
    automaticallyFinish = true
    for address in Array(continuations.keys) { finish(address) }
  }

  private func candidates(for address: String) -> [PlannerAddressCandidate] {
    let position = Int(address.split(separator: " ").last ?? "0") ?? 0
    return [
      .init(
        id: address, name: address, address: nil,
        latitude: Double(30 + position), longitude: Double(134 + position))
    ]
  }
}

@MainActor
private final class HeldMapLinkProvider: PlannerMapsPreviewProvider {
  private(set) var requests: [String] = []
  var candidatesByURL: [String: PlannerCapturePreviewCandidate] = [:]
  private var continuations: [String: CheckedContinuation<PlannerCapturePreviewCandidate?, Never>] =
    [:]
  private var automaticallyFinish = false
  var outstandingCount: Int { continuations.count }

  func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate? {
    requests.append(originalURL)
    if automaticallyFinish { return candidatesByURL[originalURL] }
    return await withCheckedContinuation { continuations[originalURL] = $0 }
  }

  func finish(_ originalURL: String) {
    continuations.removeValue(forKey: originalURL)?.resume(returning: candidatesByURL[originalURL])
  }

  func finishAll() {
    automaticallyFinish = true
    for originalURL in Array(continuations.keys) { finish(originalURL) }
  }
}
