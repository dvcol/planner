import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class SavedItemWindowTests: XCTestCase {
  func testOpensWithOnePageAndKeepsEveryOrderedSourceIdentity() async throws {
    let fixture = try await makeFixture(itemCount: 65)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "first-page", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.sourceIdentifiers, fixture.identifiers)
    XCTAssertEqual(window.matchingCount, 65)
    for (index, title) in [(0, "Activity 000"), (63, "Activity 063")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("The initial page must be readable before the catalog is ready.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    guard case .loading = window.presentation(at: 64) else {
      XCTFail("The catalog must not accumulate all matching row presentations.")
      return
    }
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
    XCTAssertEqual(window.sourceIdentifiers, fixture.identifiers)
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Visible and neighboring pages must load through the same catalog.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
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
      XCTAssertEqual(item.id, fixture.identifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    for index in [128, 192] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Returning to the beginning must release the distant pages.")
        return
      }
    }
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
    XCTAssertEqual(window.sourceIdentifiers, Array(fixture.identifiers.dropFirst()))
    guard case .loaded(let lastItem) = window.presentation(at: 191) else {
      XCTFail("A stale page must refresh and retain the source that was visible before the change.")
      return
    }
    XCTAssertEqual(lastItem.id, fixture.identifiers[192])
    XCTAssertEqual(lastItem.row.title, "Activity 192")
    for index in window.sourceIdentifiers.indices {
      if case .loaded(let item) = window.presentation(at: index) {
        XCTAssertEqual(item.id, fixture.identifiers[index + 1])
        XCTAssertFalse(item.row.globalDone == true)
      }
    }
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
    XCTAssertTrue(window.sourceIdentifiers.isEmpty)
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
    XCTAssertEqual(window.sourceIdentifiers, expectedIdentifiers)
    XCTAssertEqual(window.matchingCount, 11)
    for (index, title) in [(0, "Activity 119"), (10, "Activity 011")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Replacement queries must return their own filtered and sorted presentations.")
        return
      }
      XCTAssertEqual(item.id, expectedIdentifiers[index])
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
    XCTAssertEqual(window.sourceIdentifiers, expectedIdentifiers)
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
    XCTAssertTrue(window.sourceIdentifiers.isEmpty)
    await window.reload(
      query: .init(text: "Absent museum", completion: .all, archive: .all),
      identity: .init(namespace: "empty-query", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.sourceIdentifiers.isEmpty)
    await window.requestRows(at: [0])
    XCTAssertEqual(window.state, .ready)
    await window.reload(
      query: .init(text: "ACTÍVITY 064", completion: .all, archive: .all),
      identity: .init(namespace: "corrected-query", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 1)
    XCTAssertEqual(window.sourceIdentifiers, [fixture.identifiers[64]])
    guard case .loaded(let item) = window.presentation(at: 0) else {
      XCTFail("A valid retry must show its own filtered Item rather than the prior query's page.")
      return
    }
    XCTAssertEqual(item.id, fixture.identifiers[64])
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
    XCTAssertEqual(window.sourceIdentifiers, fixture.identifiers)
    XCTAssertEqual(window.matchingCount, 193)
    for (index, title) in [(64, "Activity 064"), (128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Repeated visibility requests must leave one complete current window.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
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
    XCTAssertEqual(window.sourceIdentifiers, fixture.identifiers)
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("A pre-canceled visibility request must not release the current presentations.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
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
  }

  private func makeFixture(itemCount: Int) async throws -> Fixture {
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
    var sources: [[String: Any]] = []
    for index in 0..<itemCount {
      let identifier = UUID()
      expectedIdentifiers.append(identifier)
      sources.append([
        "kind": "item", "id": identifier.uuidString, "lifetimeId": UUID().uuidString,
        "createdAt": 813_000_000 + index, "updatedAt": 813_000_000 + index,
        "content": [
          "title": String(format: "Activity %03d", index), "subtitle": NSNull(),
          "notes": NSNull(), "location": NSNull(), "estimate": NSNull(),
        ],
        "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
      ])
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": [], "itineraryEntries": [], "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
    guard case .decoded(let backup) = planner.decodeImport(data),
      case .reviewed(let review) = await planner.prepareReview(
        session: datasetSession, command: .applyImport(backup: backup)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: datasetSession, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    return Fixture(
      directory: directory, planner: planner, session: datasetSession,
      identifiers: expectedIdentifiers)
  }
}
