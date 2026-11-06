import Darwin
import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class PlannerAgentTunnelTests: XCTestCase {
  private let tunnelId = "tunnel_0123456789abcdef0123456789abcdef"

  func testBundledUniversalHelperIsSignedAndRunsInsideTheAppSandbox() async throws {
    try await Task.detached { try PlannerAgentTunnelProcess.validateExecutable() }.value
    let child = Process()
    child.executableURL = PlannerAgentTunnelProcess.executable
    child.arguments = ["--version"]
    child.environment = [:]
    let output = Pipe()
    child.standardOutput = output
    child.standardError = FileHandle.nullDevice
    try child.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    child.waitUntilExit()
    XCTAssertEqual(child.terminationStatus, 0)
    XCTAssertTrue(String(decoding: data, as: UTF8.self).hasPrefix("0.0.19 "))
  }

  func testConnectionRotationIsDeviceKeychainOnlyAndCannotRebindAnOldTunnel() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    let context = PlannerAgentAccess.Context(
      planner: planner, session: session, controlURL: controlURL)
    let settingsURL = PlannerAgentTunnelConnection.settingsURL(for: controlURL)
    addTeardownBlock {
      try PlannerAgentTunnelConnection.remove(from: settingsURL)
      await planner.close()
    }
    let first = try PlannerAgentTunnelConnection.save(
      tunnelId: tunnelId, runtimeKey: "disposable-key-one", context: context)
    let otherOwner = PlannerAgentTunnelConnection.Binding(
      tunnelId: tunnelId, datasetId: session.datasetId, ownershipBinding: "another-owner")
    XCTAssertFalse(otherOwner.matches(session))
    XCTAssertEqual(try PlannerAgentTunnelKey.read(id: first.keyId), "disposable-key-one")
    XCTAssertFalse(
      String(decoding: try Data(contentsOf: settingsURL), as: UTF8.self).contains("disposable-key"))
    let second = try PlannerAgentTunnelConnection.save(
      tunnelId: tunnelId, runtimeKey: "disposable-key-two", context: context)
    XCTAssertNotEqual(first.keyId, second.keyId)
    XCTAssertThrowsError(try PlannerAgentTunnelKey.read(id: first.keyId))
    XCTAssertEqual(try PlannerAgentTunnelConnection.load(from: settingsURL), second)
    try PlannerAgentTunnelConnection.remove(from: settingsURL)
    XCTAssertThrowsError(try PlannerAgentTunnelKey.read(id: second.keyId))
    XCTAssertNil(try PlannerAgentTunnelConnection.load(from: settingsURL))

    let otherFixture = try makePlannerIntentStorage()
    let (otherPlanner, otherSession) = try await otherFixture.store.appIntentContext()
    addTeardownBlock { await otherPlanner.close() }
    let otherContext = PlannerAgentAccess.Context(
      planner: otherPlanner, session: otherSession, controlURL: controlURL)
    XCTAssertThrowsError(
      try PlannerAgentTunnelConnection.save(
        tunnelId: tunnelId, runtimeKey: "disposable-other-key", context: otherContext)
    ) { error in
      guard case PlannerAgentTunnelFailure.differentLibrary = error else {
        return XCTFail("An existing ChatGPT connection must never retarget another dataset.")
      }
    }
  }

  func testEnableStopRelaunchAndKeyRotationReapChildrenAndRotateMacCredentials() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    let context = PlannerAgentAccess.Context(
      planner: planner, session: session, controlURL: controlURL)
    let settingsURL = PlannerAgentTunnelConnection.settingsURL(for: controlURL)
    await access.resume(context)
    await access.saveTunnel(tunnelId: tunnelId, runtimeKey: "disposable-runtime-key")
    let reopened = PlannerAgentAccess()
    let disabled = PlannerAgentAccess()
    addTeardownBlock {
      await access.stop()
      await reopened.stop()
      await disabled.stop()
      try PlannerAgentTunnelConnection.remove(from: settingsURL)
      await planner.close()
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(credential: "unused", accessWindowIdentifier: UUID())
    )
    let availableEndpoint = try await listener.start(port: 0)
    let port = try XCTUnwrap(
      URLComponents(url: availableEndpoint, resolvingAgainstBaseURL: false)?.port)
    await listener.stop()
    await access.enable(context, port: UInt16(port))
    XCTAssertTrue(access.isEnabled, access.notice ?? "Local enable failed")
    guard access.tunnel.state != .unavailable else {
      XCTFail(access.tunnel.notice ?? "Tunnel startup failed")
      return
    }
    let first = try readProcess(controlURL)
    XCTAssertTrue(try first.isRunning(), access.tunnel.notice ?? "Remote launch failed")
    let firstConnection = try PlannerAgentConnection.read(from: controlURL)
    let oldCredential = try PlannerAgentCredential.read(window: firstConnection.accessWindowId)
    let firstKey = try XCTUnwrap(access.tunnel.connection?.keyId)
    await access.saveTunnel(tunnelId: tunnelId, runtimeKey: "disposable-rotated-key")
    XCTAssertFalse(try first.isRunning())
    XCTAssertThrowsError(try PlannerAgentTunnelKey.read(id: firstKey))
    let rotated = try readProcess(controlURL)
    XCTAssertNotEqual(rotated, first)

    let recordURL = controlURL.deletingLastPathComponent().appending(
      path: "AgentTunnelProcess.plist")
    let runningRecord = try PropertyListDecoder().decode(
      PlannerAgentTunnelProcess.Record.self, from: Data(contentsOf: recordURL))
    let pidFile = runningRecord.directory(relativeTo: recordURL).appending(path: "runtime.pid")
    for _ in 0..<40 {
      if FileManager.default.fileExists(atPath: pidFile.path) { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    let pidData = try Data(contentsOf: pidFile)
    XCTAssertEqual(
      String(decoding: pidData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
      String(rotated.pid))
    let bridgeFile = runningRecord.directory(relativeTo: recordURL).appending(path: "bridge.json")
    for _ in 0..<40 {
      if FileManager.default.fileExists(atPath: bridgeFile.path) { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    let bridge = try JSONDecoder().decode(
      PlannerAgentTunnelProcess.self, from: Data(contentsOf: bridgeFile))
    XCTAssertTrue(try bridge.isRunning())

    await access.suspend()
    XCTAssertFalse(try rotated.isRunning())
    XCTAssertFalse(try bridge.isRunning())
    XCTAssertEqual(access.state, .suspended)
    let pending = PlannerAgentTunnelProcess.Record(ownerId: UUID(), windowId: UUID())
    let pendingDirectory = pending.directory(relativeTo: recordURL)
    try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
    try pidData.write(to: pendingDirectory.appending(path: "runtime.pid"))
    try PropertyListEncoder().encode(pending).write(to: recordURL, options: .atomic)
    await reopened.resume(context)
    XCTAssertTrue(reopened.isEnabled, reopened.notice ?? "Saved choice did not resume")
    let restored = try readProcess(controlURL)
    XCTAssertFalse(FileManager.default.fileExists(atPath: pendingDirectory.path))
    XCTAssertTrue(try restored.isRunning())
    let restoredConnection = try PlannerAgentConnection.read(from: controlURL)
    XCTAssertNotEqual(restoredConnection.accessWindowId, firstConnection.accessWindowId)
    XCTAssertThrowsError(try PlannerAgentCredential.read(window: firstConnection.accessWindowId))
    let rejected = try await ping(restoredConnection.endpoint, credential: oldCredential)
    XCTAssertEqual(rejected, 401)
    await reopened.stop()
    XCTAssertFalse(try restored.isRunning())
    XCTAssertEqual(reopened.state, .off)
    XCTAssertFalse(reopened.isConfigured)
    await disabled.resume(context)
    XCTAssertFalse(
      disabled.isEnabled, "Stop must stay Off after relaunch with a saved private connection.")
    XCTAssertEqual(disabled.tunnel.state, .off)
    XCTAssertNotNil(
      disabled.tunnel.connection, "Stopping retains the one-time connection settings.")
    XCTAssertFalse(FileManager.default.fileExists(atPath: recordURL.path))
  }

  func testUnverifiedStalePIDCannotBlockRevocationOrBeKilled() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    let recordURL = controlURL.deletingLastPathComponent().appending(
      path: "AgentTunnelProcess.plist")
    let context = PlannerAgentAccess.Context(
      planner: planner, session: session, controlURL: controlURL)
    await access.resume(context)
    let unrelated = try PlannerAgentTunnelProcess.identity(pid: getpid())
    await access.saveTunnel(tunnelId: tunnelId, runtimeKey: "disposable-runtime-key")
    try PropertyListEncoder().encode(
      PlannerAgentTunnelProcess.Record(ownerId: UUID(), windowId: UUID(), identity: unrelated)
    ).write(to: recordURL)
    let port = try await availablePort()
    await access.enable(context, port: port)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: recordURL)
      await access.stop()
      try PlannerAgentTunnelConnection.remove(
        from: PlannerAgentTunnelConnection.settingsURL(for: controlURL))
      await planner.close()
    }
    XCTAssertTrue(access.isEnabled, "A failed remote cleanup must leave local access usable.")
    XCTAssertEqual(access.tunnel.state, .unavailable)
    XCTAssertTrue(try unrelated.isRunning())
    let original = try PlannerAgentConnection.read(from: controlURL)
    let oldCredential = try PlannerAgentCredential.read(window: original.accessWindowId)
    await access.stop()
    XCTAssertEqual(access.state, .off)
    XCTAssertThrowsError(try PlannerAgentCredential.read(window: original.accessWindowId))
    XCTAssertTrue(
      try unrelated.isRunning(), "A mismatched signed executable must never be signalled.")
    try FileManager.default.removeItem(at: recordURL)
    await access.enable(context, port: port)
    let rejected = try await ping(original.endpoint, credential: oldCredential)
    XCTAssertEqual(rejected, 401)
  }

  func testRapidTogglesChildFailureAndVerifiedStaleHelperRecovery() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    let settingsURL = PlannerAgentTunnelConnection.settingsURL(for: controlURL)
    let context = PlannerAgentAccess.Context(
      planner: planner, session: session, controlURL: controlURL)
    await access.resume(context)
    await access.saveTunnel(tunnelId: tunnelId, runtimeKey: "disposable-runtime-key")
    addTeardownBlock {
      await access.stop()
      try PlannerAgentTunnelConnection.remove(from: settingsURL)
      await planner.close()
    }
    let port = try await availablePort()
    for _ in 0..<3 {
      let enabling = Task { await access.enable(context, port: port) }
      await Task.yield()
      await access.stop()
      await enabling.value
      XCTAssertEqual(access.state, .off)
      XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
    }
    await access.enable(context, port: port)
    guard access.tunnel.state != .unavailable else {
      XCTFail(access.tunnel.notice ?? "Tunnel startup failed")
      return
    }
    let failed = try readProcess(controlURL)
    try failed.signal(SIGTERM)
    let deadline = Date().addingTimeInterval(5)
    while access.tunnel.state != .unavailable && Date() < deadline {
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTAssertEqual(access.tunnel.state, .unavailable)
    XCTAssertTrue(access.isEnabled)
    let local = try PlannerAgentConnection.read(from: controlURL)
    let credential = try PlannerAgentCredential.read(window: local.accessWindowId)
    let response = try await ping(local.endpoint, credential: credential)
    XCTAssertEqual(response, 200)

    await access.retryTunnel()
    let recovered = try readProcess(controlURL)
    XCTAssertTrue(try recovered.isRunning())
    XCTAssertNotEqual(failed, recovered)
    let reconciler = PlannerAgentTunnel()
    reconciler.configure(context)
    let reclaimed = await reconciler.stop(reconcile: true)
    XCTAssertFalse(reclaimed, "A different live controller must retain its grant.")
    XCTAssertTrue(try recovered.isRunning())
    await access.retryTunnel()
    let replacement = try readProcess(controlURL)
    XCTAssertTrue(try replacement.isRunning())
    XCTAssertNotEqual(recovered, replacement)
    await access.removeTunnel()
    XCTAssertFalse(try replacement.isRunning())
    XCTAssertTrue(access.isEnabled)
    XCTAssertNil(access.tunnel.connection)
  }

  func testQuitCannotBeReenabledByALateLibraryRefresh() async throws {
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let access = fixture.store.agentAccess
    let controlURL = fixture.directory.appending(path: "AgentControlState.plist")
    let context = PlannerAgentAccess.Context(
      planner: planner, session: session, controlURL: controlURL)
    await access.resume(context)
    await access.saveTunnel(tunnelId: tunnelId, runtimeKey: "disposable-runtime-key")
    addTeardownBlock {
      await access.stop()
      try PlannerAgentTunnelConnection.remove(
        from: PlannerAgentTunnelConnection.settingsURL(for: controlURL))
      await planner.close()
    }
    let port = try await availablePort()
    await access.enable(context, port: port)
    let child = try readProcess(controlURL)
    let closing = Task { await access.shutdown() }
    await Task.yield()
    await access.resume(context)
    await closing.value
    await access.resume(context)
    await access.enable(context, port: port)
    XCTAssertFalse(access.isEnabled)
    XCTAssertTrue(
      access.isConfigured, "Quit preserves the saved choice for the next application instance.")
    XCTAssertFalse(try child.isRunning())
    XCTAssertFalse(FileManager.default.fileExists(atPath: controlURL.path))
  }

  private func readProcess(_ controlURL: URL) throws -> PlannerAgentTunnelProcess {
    try XCTUnwrap(
      PropertyListDecoder().decode(
        PlannerAgentTunnelProcess.Record.self,
        from: Data(
          contentsOf: controlURL.deletingLastPathComponent().appending(
            path: "AgentTunnelProcess.plist"))
      ).identity)
  }

  private func availablePort() async throws -> UInt16 {
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(credential: "unused", accessWindowIdentifier: UUID())
    )
    let endpoint = try await listener.start(port: 0)
    let port = try XCTUnwrap(URLComponents(url: endpoint, resolvingAgainstBaseURL: false)?.port)
    await listener.stop()
    return UInt16(port)
  }

  private func ping(_ endpoint: URL, credential: String) async throws -> Int {
    var request = URLRequest(url: endpoint, timeoutInterval: 5)
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"jsonrpc":"2.0","id":1,"method":"ping"}"#.utf8)
    request.setValue("Bearer " + credential, forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let (_, response) = try await session.data(for: request)
    return try XCTUnwrap(response as? HTTPURLResponse).statusCode
  }
}
