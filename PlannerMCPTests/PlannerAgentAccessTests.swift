import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class PlannerAgentAccessTests: XCTestCase {
  /// Opt-in real Codex preflight uses disposable local data before a Production invitation is touched.
  func testAttendedCodexClientCreatesAndReadsThroughTheSignedHelper() async throws {
    let run = ProcessInfo.processInfo.environment["PLANNER_MCP_CLIENT_CHECK"] ?? ""
    try XCTSkipUnless(UUID(uuidString: run) != nil, "Requires an attended Codex client check.")
    let controlURL = try PlannerAgentConnection.controlURL()
    try XCTSkipIf(
      FileManager.default.fileExists(atPath: controlURL.path), "Stop existing agent access first.")
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    await access.enable(.init(planner: planner, session: session, controlURL: controlURL))
    addTeardownBlock {
      await access.stop()
      await planner.close()
    }
    guard case .on = access.state else { return XCTFail(access.notice ?? "Enable failed.") }
    print("PLANNER_MCP_CLIENT_READY")
    let deadline = Date().addingTimeInterval(120)
    repeat {
      if case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
        case .rows(let page) = await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: 0, limit: 64)),
        let row = page.rows.first(where: {
          $0.title == "Bridge client smoke " + String(run.prefix(8))
        }),
        case .source(let source) = row.identity,
        case .source(.item(let item)) = await planner.read(
          session: session, request: .source(source)),
        item.content.notes == "Codex verified MCP"
      {
        try await Task.sleep(for: .seconds(5))
        return
      }
      try await Task.sleep(for: .seconds(1))
    } while Date() < deadline
    XCTFail("The real Codex client did not complete the MCP exchange.")
  }

  func testRealKeychainAccessEditsTheBoundStoreAndStopRevokesOldCredentials() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    let port = try await availablePort()
    await access.enable(
      .init(planner: planner, session: session, controlURL: controlURL), port: port)
    addTeardownBlock {
      await access.stop()
      await planner.close()
    }
    guard case .on(let endpoint) = access.state else {
      return XCTFail(access.notice ?? "Signed Keychain access must enable the real listener.")
    }
    let first = try PlannerAgentConnection.read(from: controlURL)
    let credential = try PlannerAgentCredential.read(window: first.accessWindowId)
    let created = try await call(
      endpoint, credential: credential, tool: "planner_execute",
      arguments: [
        "formatVersion": 1, "operationId": UUID().uuidString,
        "command": ["type": "createItem", "content": ["title": "Bridge museum"]],
      ])
    XCTAssertEqual(created["state"] as? String, "applied")
    let generated = try XCTUnwrap(
      (created["result"] as? [String: Any])?["generated"] as? [[String: Any]])
    let identifier = try XCTUnwrap(generated.first?["id"] as? String)
    let source = PlannerEntityReference(
      kind: .item, id: try XCTUnwrap(UUID(uuidString: identifier)))
    guard
      case .source(.item(let item)) = await planner.read(
        session: session, request: .source(source))
    else { return XCTFail("MCP must write the app's exact bound store.") }
    XCTAssertEqual(item.content.title, "Bridge museum")

    await access.stop()
    XCTAssertEqual(access.state, .off)
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
    XCTAssertThrowsError(try PlannerAgentCredential.read(window: first.accessWindowId))
    await access.enable(
      .init(planner: planner, session: session, controlURL: controlURL), port: port)
    guard case .on = access.state else { return XCTFail(access.notice ?? "Re-enable failed.") }
    let second = try PlannerAgentConnection.read(from: controlURL)
    XCTAssertNotEqual(second.accessWindowId, first.accessWindowId)
    XCTAssertEqual(second.mainInstanceId, first.mainInstanceId)
    let rejected = try await exchange(endpoint, credential: credential, method: "ping")
    XCTAssertEqual(rejected.1.statusCode, 401)
    XCTAssertNil(rejected.1.value(forHTTPHeaderField: "X-Planner-Access-Window"))
    let currentCredential = try PlannerAgentCredential.read(window: second.accessWindowId)
    let ping = try await exchange(endpoint, credential: currentCredential, method: "ping")
    XCTAssertEqual(ping.1.statusCode, 200)
    XCTAssertEqual(
      ping.1.value(forHTTPHeaderField: "X-Planner-Access-Window"), second.accessWindowId.uuidString)

    await fixture.store.switchLibrary(to: nil)
    XCTAssertEqual(access.state, .off, "Changing the library must revoke existing agent access.")
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
  }

  func testOccupiedPortAndFailedPublicationNeverEnableAccess() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    let blocker = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "fixture", accessWindowIdentifier: UUID()))
    let occupied = try await blocker.start(port: 0)
    addTeardownBlock {
      await access.stop()
      await blocker.stop()
      await planner.close()
    }
    let port = try XCTUnwrap(URLComponents(url: occupied, resolvingAgainstBaseURL: false)?.port)
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    await access.enable(
      .init(planner: planner, session: session, controlURL: controlURL), port: UInt16(port))
    XCTAssertEqual(access.state, .unavailable)
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
    await blocker.stop()
    let file = fixture.directory.appending(path: "not-a-directory")
    try Data("occupied path".utf8).write(to: file)
    await access.enable(
      .init(planner: planner, session: session, controlURL: file.appending(path: "state.plist")),
      port: UInt16(port))
    XCTAssertEqual(access.state, .unavailable)
    let rebound = try await blocker.start(port: UInt16(port))
    XCTAssertEqual(rebound, occupied, "A failed publication must release its listener.")
  }

  func testStopDuringEnableCannotPublishOnAfterStop() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    let port = try await availablePort()
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    let enabling = Task {
      await access.enable(
        .init(planner: planner, session: session, controlURL: controlURL), port: port)
    }
    let deadline = Date().addingTimeInterval(5)
    while access.state == .off, Date() < deadline { await Task.yield() }
    XCTAssertNotEqual(access.state, .off)
    async let firstStop: Void = access.stop()
    async let secondStop: Void = access.stop()
    _ = await (firstStop, secondStop)
    await enabling.value
    XCTAssertEqual(access.state, .off)
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
    await planner.close()
  }

  func testReaderRejectsUntrustedStoredEndpointsBeforeCredentialAccess() throws {
    for raw in [
      "https://127.0.0.1:44444/mcp", "http://example.com:44444/mcp",
      "http://user@127.0.0.1:44444/mcp", "http://127.0.0.1:44444/mcp?next=other",
      "http://127.0.0.1:44444/other", "http://127.0.0.1/mcp",
    ] {
      let connection = PlannerAgentConnection(
        formatVersion: 1, mainInstanceId: UUID(), accessWindowId: UUID(),
        endpoint: try XCTUnwrap(URL(string: raw)), protocolVersion: "2025-11-25", state: "on")
      XCTAssertThrowsError(try connection.validated())
    }
  }

  private func availablePort() async throws -> UInt16 {
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "fixture", accessWindowIdentifier: UUID()))
    let endpoint = try await listener.start(port: 0)
    await listener.stop()
    return try XCTUnwrap(UInt16(exactly: try XCTUnwrap(endpoint.port)))
  }

  private func call(
    _ endpoint: URL, credential: String, tool: String, arguments: [String: Any]
  ) async throws -> [String: Any] {
    let exchange = try await exchange(
      endpoint, credential: credential, method: "tools/call",
      parameters: ["name": tool, "arguments": arguments])
    XCTAssertEqual(exchange.1.statusCode, 200)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    let result = try XCTUnwrap(object["result"] as? [String: Any])
    let content = try XCTUnwrap(result["content"] as? [[String: Any]])
    let text = try XCTUnwrap(content.first?["text"] as? String)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
  }

  private func exchange(
    _ endpoint: URL, credential: String, method: String, parameters: [String: Any] = [:]
  ) async throws -> (Data, HTTPURLResponse) {
    var request = URLRequest(url: endpoint, timeoutInterval: 10)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": UUID().uuidString, "method": method, "params": parameters,
    ])
    request.setValue("Bearer " + credential, forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let (data, response) = try await session.data(for: request)
    return (data, try XCTUnwrap(response as? HTTPURLResponse))
  }
}
