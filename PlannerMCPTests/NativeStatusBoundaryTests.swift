import Foundation
import PlannerCore
import Testing

@testable import Planner

struct NativeStatusBoundaryTests {
  @Test func authenticatedAgentCannotReadNativeDatasetStatusOrChangeItsAcknowledgement()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      )
      .outcome,
      let source = creation.generated.first,
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      var request = URLRequest(url: endpoint)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
      request.setValue(
        "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 1, "method": "tools/call",
        "params": [
          "name": "planner_read", "arguments": ["formatVersion": 1, "request": ["kind": "status"]],
        ],
      ])
      let exchange = try await httpSession.data(for: request)
      let response = try #require(exchange.1 as? HTTPURLResponse)
      #expect(response.statusCode == 200)
      let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
      let tool = try #require(envelope["result"] as? [String: Any])
      let structured = try #require(tool["structuredContent"] as? [String: Any])
      let reason = try #require(structured["reason"] as? [String: Any])
      #expect(tool["isError"] as? Bool == true)
      #expect(reason["code"] as? String == "invalidInput")
      #expect(reason["propertyPath"] as? String == "/request/kind")
      #expect(
        structured["recovery"] == nil && structured["account"] == nil && structured["cloud"] == nil)
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list",
      ])
      let catalogExchange = try await httpSession.data(for: request)
      let catalog = try #require(
        JSONSerialization.jsonObject(with: catalogExchange.0) as? [String: Any])
      let catalogResult = try #require(catalog["result"] as? [String: Any])
      let tools = try #require(catalogResult["tools"] as? [[String: Any]])
      let readTool = try #require(tools.first { $0["name"] as? String == "planner_read" })
      let schema = try #require(readTool["inputSchema"] as? [String: Any])
      let properties = try #require(schema["properties"] as? [String: Any])
      let readRequest = try #require(properties["request"] as? [String: Any])
      let alternatives = try #require(readRequest["oneOf"] as? [[String: Any]])
      let kinds = alternatives.flatMap { alternative -> [String] in
        guard let properties = alternative["properties"] as? [String: Any],
          let kind = properties["kind"] as? [String: Any]
        else { return [] }
        if let constant = kind["const"] as? String { return [constant] }
        return kind["enum"] as? [String] ?? []
      }
      #expect(Set(kinds) == ["source", "appearance", "rows", "mapRows", "calendarRows"])
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
    guard
      case .source(.item(let after)) = await planner.read(
        session: session, request: .source(source)),
      case .status(let nativeStatus) = await planner.read(session: session, request: .status),
      case .known(let retainedCheckpoint, let incomplete, let blocked) = nativeStatus.recovery
    else { throw CancellationError() }
    #expect(after.content.title == "Hotel" && after.content.notes == "Original notes")
    #expect(after.updatedAt == before.updatedAt && after.fieldHashes == before.fieldHashes)
    #expect(retainedCheckpoint == checkpoint && incomplete.isEmpty && !blocked)
  }
}
