import Foundation
import PlannerCore
import PlannerPreviews
import XCTest

@testable import Planner

@MainActor
final class SavedMapCollectionTests: XCTestCase {
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
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "PlannerMapCollectionFixtures", directoryHint: .isDirectory)
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    print("Planner Map-collection fixture directory: \(directory.path)")
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appending(path: "store/Planner.sqlite"),
        controlURL: directory.appending(path: "control/writer"),
        recoveryDirectoryURL: directory.appending(path: "recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      throw CancellationError()
    }
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

  private func makePlanner() async throws -> (PlannerCore.Planner, PlannerDatasetSession) {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "PlannerMapCollectionFixtures", directoryHint: .isDirectory)
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    print("Planner Map-collection fixture directory: \(directory.path)")
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appending(path: "store/Planner.sqlite"),
        controlURL: directory.appending(path: "control/writer"),
        recoveryDirectoryURL: directory.appending(path: "recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
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

  func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate? {
    requests.append(originalURL)
    return nil
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
