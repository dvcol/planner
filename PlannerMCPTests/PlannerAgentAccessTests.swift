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

    await access.stop()
    XCTAssertEqual(access.state, .off)
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
  }

  func testSavedChoiceResumesInANewStoreAndStopRemainsOffAfterReopening() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let controlURL = fixture.configuration.controlURL.deletingLastPathComponent()
      .appending(path: "AgentControlState.plist")
    let access = fixture.store.agentAccess
    let port = try await availablePort()
    await access.enable(
      .init(planner: planner, session: session, controlURL: controlURL), port: port)
    guard case .on(let endpoint) = access.state else {
      return XCTFail(access.notice ?? "Initial enable failed.")
    }
    let original = try PlannerAgentConnection.read(from: controlURL)
    let oldCredential = try PlannerAgentCredential.read(window: original.accessWindowId)
    await access.suspend()
    XCTAssertEqual(access.state, .suspended)
    XCTAssertTrue(access.isConfigured)
    XCTAssertThrowsError(try PlannerAgentCredential.read(window: original.accessWindowId))

    let reopened = SavedPlannerStore(configuration: fixture.configuration)
    let (reopenedPlanner, reopenedSession) = try await reopened.appIntentContext()
    let disabled = SavedPlannerStore(configuration: fixture.configuration)
    addTeardownBlock {
      await access.stop()
      await reopened.agentAccess.stop()
      await disabled.agentAccess.stop()
      await planner.close()
      await reopenedPlanner.close()
    }
    XCTAssertEqual(reopenedSession.datasetId, session.datasetId)
    XCTAssertEqual(reopenedSession.ownershipBinding, session.ownershipBinding)
    guard case .on(let restoredEndpoint) = reopened.agentAccess.state else {
      return XCTFail(reopened.agentAccess.notice ?? "The saved choice must resume on open.")
    }
    XCTAssertEqual(restoredEndpoint, endpoint)
    let restored = try PlannerAgentConnection.read(from: controlURL)
    XCTAssertNotEqual(restored.mainInstanceId, original.mainInstanceId)
    XCTAssertNotEqual(restored.accessWindowId, original.accessWindowId)
    let rejected = try await exchange(endpoint, credential: oldCredential, method: "ping")
    XCTAssertEqual(rejected.1.statusCode, 401)
    let currentCredential = try PlannerAgentCredential.read(window: restored.accessWindowId)
    let accepted = try await exchange(endpoint, credential: currentCredential, method: "ping")
    XCTAssertEqual(accepted.1.statusCode, 200)

    await reopened.agentAccess.stop()
    let (disabledPlanner, _) = try await disabled.appIntentContext()
    XCTAssertEqual(disabled.agentAccess.state, .off)
    XCTAssertFalse(disabled.agentAccess.isConfigured)
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
    await disabledPlanner.close()
  }

  func testStoreAutomaticallyRebindsWhenTheSameLibrarySessionIsInvalidated() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let controlURL = fixture.configuration.controlURL.deletingLastPathComponent()
      .appending(path: "AgentControlState.plist")
    let access = fixture.store.agentAccess
    let port = try await availablePort()
    await access.enable(
      .init(planner: planner, session: session, controlURL: controlURL), port: port)
    addTeardownBlock {
      await access.stop()
      await planner.close()
    }
    guard case .on(let endpoint) = access.state else {
      return XCTFail(access.notice ?? "Initial enable failed.")
    }
    let original = try PlannerAgentConnection.read(from: controlURL)
    let oldCredential = try PlannerAgentCredential.read(window: original.accessWindowId)
    await planner.close()
    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
      if access.isEnabled,
        let current = try? PlannerAgentConnection.read(from: controlURL),
        current.accessWindowId != original.accessWindowId
      {
        break
      }
      try await Task.sleep(for: .milliseconds(20))
    }
    guard case .on = access.state else {
      return XCTFail(access.notice ?? "A same-library refresh must resume agent access.")
    }
    let current = try PlannerAgentConnection.read(from: controlURL)
    XCTAssertNotEqual(current.accessWindowId, original.accessWindowId)
    XCTAssertEqual(current.mainInstanceId, original.mainInstanceId)
    XCTAssertThrowsError(try PlannerAgentCredential.read(window: original.accessWindowId))
    let rejected = try await exchange(endpoint, credential: oldCredential, method: "ping")
    XCTAssertEqual(rejected.1.statusCode, 401)
    let currentCredential = try PlannerAgentCredential.read(window: current.accessWindowId)
    let query = try await call(
      endpoint, credential: currentCredential, tool: "planner_query",
      arguments: [
        "formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]],
      ])
    XCTAssertNotNil(query["generation"], "MCP must use the refreshed live Core session.")
    let (_, refreshedSession) = try await fixture.store.appIntentContext()
    XCTAssertNotEqual(refreshedSession.sessionId, session.sessionId)
    XCTAssertEqual(refreshedSession.datasetId, session.datasetId)
    XCTAssertEqual(refreshedSession.ownershipBinding, session.ownershipBinding)
  }

  func testDifferentDatasetOrOwnerCannotInheritOrEraseTheSavedChoice() async throws {
    let firstFixture = try makePlannerIntentStorage()
    let secondFixture = try makePlannerIntentStorage()
    let (firstPlanner, firstSession) = try await firstFixture.store.appIntentContext()
    let (secondPlanner, secondSession) = try await secondFixture.store.appIntentContext()
    let access = firstFixture.store.agentAccess
    let port = try await availablePort()
    let controlURL = firstFixture.directory.appending(path: "AgentControlState.plist")
    let context = PlannerAgentAccess.Context(
      planner: firstPlanner, session: firstSession, controlURL: controlURL)
    await access.enable(context, port: port)
    addTeardownBlock {
      await access.stop()
      await firstPlanner.close()
      await secondPlanner.close()
    }
    guard case .on = access.state else { return XCTFail(access.notice ?? "Initial enable failed.") }
    let preferenceURL = firstFixture.directory.appending(path: "AgentControlPreference.plist")
    let savedChoice = try Data(contentsOf: preferenceURL)
    await access.resume(
      .init(planner: secondPlanner, session: secondSession, controlURL: controlURL))
    XCTAssertEqual(access.state, .off)
    XCTAssertFalse(access.isConfigured)
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
    XCTAssertEqual(try Data(contentsOf: preferenceURL), savedChoice)
    await access.stop()
    XCTAssertEqual(try Data(contentsOf: preferenceURL), savedChoice)

    var otherOwner = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: savedChoice, format: nil) as? [String: Any])
    otherOwner["ownershipBinding"] = "another-account"
    let otherOwnerData = try PropertyListSerialization.data(
      fromPropertyList: otherOwner, format: .binary, options: 0)
    try otherOwnerData.write(to: preferenceURL, options: .atomic)
    await access.resume(context)
    XCTAssertEqual(access.state, .off, "The same dataset ID cannot reuse another account's grant.")
    XCTAssertFalse(access.isConfigured)
    XCTAssertEqual(try Data(contentsOf: preferenceURL), otherOwnerData)
    try savedChoice.write(to: preferenceURL, options: .atomic)
    await access.resume(context)
    XCTAssertTrue(access.isEnabled, "Returning to the authorized dataset must retain its choice.")
  }

  func testStopFromAnOlderControllerPreservesTheNewerGrantForAnotherLibrary() async throws {
    let firstFixture = try makePlannerIntentStorage()
    let secondFixture = try makePlannerIntentStorage()
    let (firstPlanner, firstSession) = try await firstFixture.store.appIntentContext()
    let (secondPlanner, secondSession) = try await secondFixture.store.appIntentContext()
    let first = firstFixture.store.agentAccess
    let second = secondFixture.store.agentAccess
    let controlURL = firstFixture.directory.appending(path: "AgentControlState.plist")
    let firstContext = PlannerAgentAccess.Context(
      planner: firstPlanner, session: firstSession, controlURL: controlURL)
    let secondContext = PlannerAgentAccess.Context(
      planner: secondPlanner, session: secondSession, controlURL: controlURL)
    addTeardownBlock {
      await first.stop()
      await second.stop()
      await firstPlanner.close()
      await secondPlanner.close()
    }
    let port = try await availablePort()
    await first.enable(firstContext, port: port)
    XCTAssertTrue(first.isEnabled)
    await first.suspend()
    await second.enable(secondContext, port: port)
    guard case .on = second.state else { return XCTFail(second.notice ?? "New grant failed.") }
    let savedChoice = try Data(contentsOf: firstContext.preferenceURL)

    await first.stop()
    XCTAssertEqual(first.state, .off)
    XCTAssertFalse(first.isConfigured, "The older controller must refresh its cached choice.")
    XCTAssertEqual(try Data(contentsOf: firstContext.preferenceURL), savedChoice)
    XCTAssertTrue(second.isEnabled)

    await second.suspend()
    await second.resume(secondContext)
    XCTAssertTrue(second.isEnabled, "The newer library's saved grant must still resume.")
    XCTAssertEqual(try Data(contentsOf: firstContext.preferenceURL), savedChoice)
  }

  func testStopUsesTheCurrentSavedPortForTheSameLibrary() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let first = fixture.store.agentAccess
    let second = PlannerAgentAccess()
    let context = PlannerAgentAccess.Context(
      planner: planner, session: session,
      controlURL: fixture.directory.appending(path: "AgentControlState.plist"))
    addTeardownBlock {
      await first.stop()
      await second.stop()
      await planner.close()
    }
    let originalPort = try await availablePort()
    await first.enable(context, port: originalPort)
    XCTAssertTrue(first.isEnabled)
    let currentPort = try await availablePort()
    XCTAssertNotEqual(currentPort, originalPort)
    await first.suspend()
    await second.enable(context, port: currentPort)
    XCTAssertTrue(second.isEnabled)
    await second.suspend()

    await first.stop()
    XCTAssertFalse(first.isConfigured)
    let current = try XCTUnwrap(
      PropertyListSerialization.propertyList(
        from: Data(contentsOf: context.preferenceURL), format: nil) as? [String: Any])
    XCTAssertEqual(current["port"] as? UInt16, currentPort)
    XCTAssertEqual(current["enabled"] as? Bool, false)
    await second.resume(context)
    XCTAssertEqual(second.state, .off)
    XCTAssertFalse(second.isConfigured)
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
