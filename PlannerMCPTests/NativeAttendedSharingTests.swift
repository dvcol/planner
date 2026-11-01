import Foundation
import PlannerCore
import XCTest

@MainActor
final class NativeAttendedSharingTests: XCTestCase {
  /// Uses the real recipient account and a separate local cache for explicitly supplied test plans.
  func testAttendedMacAcceptsAndSynchronizesTheIPhoneLibrary() async throws {
    let environment = ProcessInfo.processInfo.environment
    let run = environment["PLANNER_PRIVATE_SYNC_RUN"] ?? ""
    try XCTSkipUnless(UUID(uuidString: run) != nil, "Requires an attended sharing run.")
    continueAfterFailure = false
    let rawURL = try XCTUnwrap(environment["PLANNER_SHARING_INVITATION_URL"])
    let url = try XCTUnwrap(URL(string: rawURL))
    XCTAssertTrue(
      url.scheme == "https"
        && ["icloud.com", "www.icloud.com"].contains(url.host?.lowercased() ?? ""))
    let scope = environment["PLANNER_SHARING_EXPECTED_SCOPE"] ?? "selected"
    XCTAssertTrue(["selected", "whole"].contains(scope))
    let exchange = environment["PLANNER_SHARING_EXCHANGE"] ?? ""
    try XCTSkipUnless(UUID(uuidString: exchange) != nil, "Requires a fresh paired exchange.")
    let suffix = String(run.prefix(8))
    let sharedTitle = "Sharing check " + suffix
    let privateTitle = "Private check " + suffix
    let itemTitle = "Shared stop " + suffix
    let manager = PlannerLibrarySharing(containerIdentifier: "iCloud.dvcol.planner")
    let library = try await manager.accept(url: url)
    XCTAssertTrue(library.canEdit)
    if scope == "whole" {
      XCTAssertEqual(library.scope, .wholeLibrary)
    } else {
      guard case .selectedLists(let identifiers) = library.scope else {
        return XCTFail("Expected a selected-List invitation.")
      }
      XCTAssertEqual(identifiers.count, 1)
    }
    print("PLANNER_SHARING_PHASE recipient-accepted \(scope)")
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "PlannerAttendedSharing/" + run + "/" + library.id, directoryHint: .isDirectory)
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appending(path: "store/Planner.sqlite"),
        controlURL: directory.appending(path: "control/writer"),
        recoveryDirectoryURL: directory.appending(path: "recovery"),
        processRole: .mainApplication,
        storageMode: .privateCloud(containerIdentifier: "iCloud.dvcol.planner"),
        sharedLibrary: library))
    addTeardownBlock { await planner.close() }
    let opened = await planner.bootstrap()
    if case .unavailable(let failure) = opened { throw failure }
    guard case .ready(let session) = opened else {
      return XCTFail("The received library must open without replacing the Mac's personal plans.")
    }
    var lists: [PlannerRowRead] = []
    let initialDeadline = Date().addingTimeInterval(90)
    repeat {
      lists = try await rows(
        planner, session: session, request: .catalog(.init(sourceKind: .list, archive: .all)))
      if lists.contains(where: { $0.title == sharedTitle }) { break }
      try await Task.sleep(for: .seconds(2))
    } while Date() < initialDeadline
    XCTAssertTrue(lists.contains(where: { $0.title == sharedTitle }))
    if scope == "whole" {
      XCTAssertTrue(lists.contains(where: { $0.title == privateTitle }))
    } else {
      XCTAssertEqual(lists.map(\.title), [sharedTitle])
    }
    let items = try await rows(
      planner, session: session,
      request: .items(.init(completion: .all, archive: .all)))
    if scope == "selected" { XCTAssertEqual(items.map(\.title), [itemTitle]) }
    let matching = items.filter { $0.title == itemTitle }
    XCTAssertEqual(matching.count, 1)
    let row = try XCTUnwrap(matching.first)
    guard case .source(let source) = row.identity,
      case .source(.item(let item)) = await planner.read(session: session, request: .source(source))
    else { return XCTFail("The exact shared Item must be readable.") }
    let notes = "Edited on Mac sharing " + scope + " " + String(exchange.prefix(8))
    let hash = try XCTUnwrap(item.fieldHashes[.notes])
    let result = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: source.id, changes: .init(notes: .set(notes)),
          expectedFieldHashes: [.notes: hash])))
    guard case .applied(_, .complete) = result.outcome else {
      return XCTFail("The invited editor must save the shared Item through Core.")
    }
    print("PLANNER_SHARING_PHASE recipient-edited \(scope)")
    let reply = "Edited on iPhone sharing " + scope + " " + String(exchange.prefix(8))
    let deadline = Date().addingTimeInterval(180)
    repeat {
      if case .source(.item(let current)) = await planner.read(
        session: session, request: .source(source)),
        current.content.notes == reply
      {
        print("PLANNER_SHARING_PHASE bidirectional-sync-confirmed \(scope)")
        return
      }
      try await Task.sleep(for: .seconds(10))
      _ = await planner.bootstrap()
    } while Date() < deadline
    XCTFail("The recipient did not receive the iPhone's matching reply before the deadline.")
  }

  /// Reads canonical rows through the same generation-bound query used by the app.
  private func rows(
    _ planner: PlannerCore.Planner, session: PlannerDatasetSession, request: PlannerQueryRequest
  ) async throws -> [PlannerRowRead] {
    switch await planner.query(.init(session: session, request: request)) {
    case .failed(let failure): throw failure
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64))
      {
      case .rows(let page): return page.rows
      case .failed(let failure): throw failure
      default: throw CocoaError(.fileReadUnknown)
      }
    }
  }
}
