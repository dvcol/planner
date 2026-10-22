import Foundation
import PlannerCore
import SQLite3
import Testing

struct MapReadIntegrityTests {
  @Test func unresolvedOwnedMapsLinkRejectsThePageInsteadOfOmittingItsLocationInput() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let writer = Planner(configuration: configuration)
    guard case .ready(let session) = await writer.bootstrap(),
      case .applied(let creation, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: "Museum", links: [.init(originalUrl: "https://maps.apple.com/?q=Museum")])))
      ).outcome,
      let item = creation.generated.first
    else { throw CancellationError() }
    var database: OpaquePointer?
    try #require(sqlite3_open(configuration.storeURL.path, &database) == SQLITE_OK)
    defer { sqlite3_close(database) }
    try #require(
      sqlite3_exec(
        database, "UPDATE ZOWNEDLINK SET ZOWNERLIFETIMEID = zeroblob(16);", nil, nil, nil)
        == SQLITE_OK)
    let reader = Planner(configuration: configuration)
    guard case .ready(let readSession) = await reader.bootstrap(),
      case .snapshot(let snapshot) = await reader.query(
        .init(
          session: readSession, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    #expect(snapshot.rows == [.source(item)])
    let response = await reader.read(
      session: readSession,
      request: .mapRows(generation: snapshot.generation, offset: 0, limit: 64))
    guard case .failed(let failure) = response else {
      Issue.record(
        "Reject the unresolved saved link instead of claiming a complete Map page: \(response)")
      return
    }
    #expect(failure.code == "readUnavailable")
  }
}
