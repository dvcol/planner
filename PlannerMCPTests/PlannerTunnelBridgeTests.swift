import Darwin
import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class PlannerTunnelBridgeTests: XCTestCase {
  private let credential = String(repeating: "A", count: 43)

  func testSignedBridgeReadsEditsAndResolvesAnOperationThroughNativeMCP() async throws {
    try await Task.detached {
      try PlannerAgentTunnelProcess.validateExecutable(helper: .bridge)
    }.value
    let fixture = try makePlannerIntentStorage()
    let (planner, session) = try await fixture.store.appIntentContext()
    let handler = PlannerMCPRequestHandler(
      credential: credential, accessWindowIdentifier: UUID(), planner: planner,
      datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let connection = BridgeConnection()
    let input = connection.input
    let output = connection.output
    let child = connection.child
    child.executableURL = PlannerAgentTunnelProcess.Helper.bridge.executable
    child.environment = try environment(
      owner: .identity(pid: getpid()), endpoint: endpoint, directory: directory)
    child.standardInput = input
    child.standardOutput = output
    child.standardError = FileHandle.nullDevice
    try child.run()
    try output.fileHandleForWriting.close()
    addTeardownBlock {
      if child.isRunning { child.terminate() }
      child.waitUntilExit()
      try? input.fileHandleForWriting.close()
      try? output.fileHandleForReading.close()
      await listener.stop()
      await planner.close()
      try? FileManager.default.removeItem(at: directory)
    }
    let initialized = try await connection.exchange(
      [
        "jsonrpc": "2.0", "id": "initialize", "method": "initialize",
        "params": [
          "protocolVersion": "2025-11-25", "clientInfo": ["name": "Bridge test", "version": "1"],
          "capabilities": [:],
        ],
      ])
    XCTAssertEqual(initialized["id"] as? String, "initialize")
    XCTAssertNil(initialized["error"])
    let operationId = UUID().uuidString
    let created = try await connection.tool(
      "planner_execute",
      arguments: [
        "formatVersion": 1, "operationId": operationId,
        "command": [
          "type": "createItem", "content": ["title": "Bridge fixture", "notes": "Initial"],
        ],
      ])
    XCTAssertEqual(created["state"] as? String, "applied")
    let result = try XCTUnwrap(created["result"] as? [String: Any])
    let generated = try XCTUnwrap(result["generated"] as? [[String: Any]])
    let identifier = try XCTUnwrap(generated.first?["id"] as? String)
    let readArguments: [String: Any] = [
      "formatVersion": 1,
      "request": ["kind": "source", "source": ["kind": "item", "id": identifier]],
    ]
    let read = try await connection.tool(
      "planner_read", arguments: readArguments)
    let value = try XCTUnwrap(read["value"] as? [String: Any])
    let hashes = try XCTUnwrap(value["fieldHashes"] as? [String: String])
    let editId = UUID().uuidString
    let edited = try await connection.tool(
      "planner_execute",
      arguments: [
        "formatVersion": 1, "operationId": editId,
        "command": [
          "type": "editItem", "sourceId": identifier,
          "changes": ["notes": "Saved through bridge\nSecond line"], "expectedFieldHashes": hashes,
        ],
      ])
    XCTAssertEqual(edited["state"] as? String, "applied")
    let fresh = try await connection.tool(
      "planner_read", arguments: readArguments)
    let freshValue = try XCTUnwrap(fresh["value"] as? [String: Any])
    let content = try XCTUnwrap(freshValue["content"] as? [String: Any])
    XCTAssertEqual(content["notes"] as? String, "Saved through bridge\nSecond line")
    let status = try await connection.tool(
      "planner_operation_status", arguments: ["formatVersion": 1, "operationId": editId])
    XCTAssertEqual(status["state"] as? String, "appliedRecoveryComplete")
    await handler.revokeAccess()
    try input.fileHandleForWriting.write(
      contentsOf: Data(#"{"jsonrpc":"2.0","id":99,"method":"ping"}"#.utf8) + Data([10]))
    await waitForExit(child)
    XCTAssertFalse(child.isRunning, "Loss of local admission must close the stdio bridge.")
  }

  func testOfficialRuntimeAndBridgeExitForOwnerBridgeAndRuntimeLoss() async throws {
    let handler = PlannerMCPRequestHandler(credential: credential, accessWindowIdentifier: UUID())
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    addTeardownBlock { await listener.stop() }
    for loss in ["owner", "bridge", "runtime"] {
      let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let owner = Process()
      owner.executableURL = URL(fileURLWithPath: "/bin/sleep")
      owner.arguments = ["60"]
      owner.environment = [:]
      try owner.run()
      let runtime = Process()
      runtime.executableURL = PlannerAgentTunnelProcess.executable
      let quotedBridge =
        "'"
        + PlannerAgentTunnelProcess.Helper.bridge.executable.path.replacingOccurrences(
          of: "'", with: "'\\''") + "'"
      runtime.arguments = [
        "run", "--control-plane.tunnel-id", "tunnel_0123456789abcdef0123456789abcdef",
        "--control-plane.base-url", "https://127.0.0.1:9", "--mcp.command",
        "command=" + quotedBridge,
        "--mcp.stdio-failure-policy", "exit", "--health.listen-addr", "127.0.0.1:0",
        "--log.level", "warn", "--log.format", "json",
      ]
      var variables = try environment(
        owner: .identity(pid: owner.processIdentifier), endpoint: endpoint, directory: directory)
      variables["CONTROL_PLANE_API_KEY"] = "disposable-loopback-proof-key"
      runtime.environment = variables
      runtime.standardInput = FileHandle.nullDevice
      runtime.standardOutput = FileHandle.nullDevice
      runtime.standardError = FileHandle.nullDevice
      try runtime.run()
      addTeardownBlock {
        if runtime.isRunning { runtime.terminate() }
        runtime.waitUntilExit()
        if owner.isRunning { owner.terminate() }
        owner.waitUntilExit()
        try? FileManager.default.removeItem(at: directory)
      }
      let bridgeFile = directory.appending(path: "bridge.json")
      let deadline = Date().addingTimeInterval(5)
      while !FileManager.default.fileExists(atPath: bridgeFile.path) && runtime.isRunning
        && Date() < deadline
      {
        try await Task.sleep(for: .milliseconds(50))
      }
      guard let stateData = try? Data(contentsOf: bridgeFile),
        let bridge = try? JSONDecoder().decode(PlannerAgentTunnelProcess.self, from: stateData)
      else {
        XCTFail("The signed bridge must start through the official runtime for \(loss) loss.")
        continue
      }
      try await Task.detached { try bridge.validate(helper: .bridge) }.value
      XCTAssertTrue(try bridge.isRunning())
      XCTAssertTrue(runtime.isRunning)
      if loss == "owner" {
        owner.terminate()
      } else if loss == "bridge" {
        XCTAssertEqual(kill(bridge.pid, SIGKILL), 0)
      } else {
        runtime.terminate()
      }
      await waitForExit(runtime)
      let bridgeDeadline = Date().addingTimeInterval(5)
      while try bridge.isRunning(), Date() < bridgeDeadline {
        try await Task.sleep(for: .milliseconds(50))
      }
      XCTAssertFalse(runtime.isRunning, "Runtime survived \(loss) loss.")
      XCTAssertFalse(try bridge.isRunning(), "Bridge survived \(loss) loss.")
    }
  }

  private func environment(owner: PlannerAgentTunnelProcess, endpoint: URL, directory: URL) throws
    -> [String: String]
  {
    [
      "PLANNER_AGENT_OWNER": String(decoding: try JSONEncoder().encode(owner), as: UTF8.self),
      "PLANNER_MCP_ENDPOINT": endpoint.absoluteString,
      "PLANNER_MCP_AUTHORIZATION": "Bearer " + credential,
      "PLANNER_MCP_PROTOCOL_VERSION": "2025-11-25",
      "PLANNER_AGENT_BRIDGE_STATE_FILE": directory.appending(path: "bridge.json").path,
      "HOME": NSHomeDirectory(), "TMPDIR": directory.path, "PATH": "/usr/bin:/bin",
    ]
  }

  private func waitForExit(_ child: Process) async {
    let deadline = Date().addingTimeInterval(8)
    while child.isRunning && Date() < deadline { try? await Task.sleep(for: .milliseconds(50)) }
  }

}

@MainActor
private final class BridgeConnection {
  let child = Process()
  let input = Pipe()
  let output = Pipe()

  func tool(
    _ name: String, arguments: [String: Any]
  ) async throws -> [String: Any] {
    let envelope = try await exchange(
      [
        "jsonrpc": "2.0", "id": UUID().uuidString, "method": "tools/call",
        "params": ["name": name, "arguments": arguments],
      ])
    let result = try XCTUnwrap(envelope["result"] as? [String: Any])
    return try XCTUnwrap(result["structuredContent"] as? [String: Any])
  }

  func exchange(_ request: [String: Any])
    async throws -> [String: Any]
  {
    let timeout = Task {
      try? await Task.sleep(for: .seconds(5))
      if !Task.isCancelled && child.isRunning { child.terminate() }
    }
    defer { timeout.cancel() }
    try input.fileHandleForWriting.write(
      contentsOf: JSONSerialization.data(withJSONObject: request) + Data([10]))
    let reader = output.fileHandleForReading
    let data = await Task.detached {
      var data = Data()
      while true {
        let bytes = reader.availableData
        if bytes.isEmpty { break }
        data.append(bytes)
        if let newline = data.firstIndex(of: 10) { return Data(data[..<newline]) }
      }
      return data
    }.value
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
