import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemPresenceQueryAdmissionTests {
  @Test func advertisedPresenceFiltersRejectNonBooleansWithoutChangingIssuedRows() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let content = PlannerItemContentInput(
      title: "Hotel", notes: "Retain original notes",
      location: .init(displayName: nil, formattedAddress: "Tokyo", coordinate: nil),
      links: [.init(originalUrl: "https://example.com/hotel")])
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: content))
      ).outcome,
      let item = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Save the acknowledged owned address/link before HTTP validation.")
      return
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func query(_ fields: [String: Any], isError: Bool = false) async throws -> [String: Any] {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_query",
              arguments: ["formatVersion": 1, "query": fields])), isError: isError)
      }
      let valid: [String: Any] = [
        "kind": "items", "scope": ["kind": "global"],
        "hasAddress": true, "hasLinks": true,
      ]
      let issued = try await query(valid)
      #expect(issued["matchingCount"] as? String == "1")
      let generation = try #require(issued["generation"] as? String)
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
        ])
      let originalWindow = try toolValue(
        try await httpSession.data(for: rowRequest), isError: false)
      var advertisementRequest = rowRequest
      advertisementRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let advertisement = try await httpSession.data(for: advertisementRequest)
      #expect((advertisement.1 as? HTTPURLResponse)?.statusCode == 200)
      let envelope = try #require(
        JSONSerialization.jsonObject(with: advertisement.0) as? [String: Any])
      let tools = try #require((envelope["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let queryTool = try #require(tools.first { $0["name"] as? String == "planner_query" })
      let properties = try #require(
        (queryTool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (properties["query"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let itemVariant = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "items"
        })
      let fields = try #require(itemVariant["properties"] as? [String: Any])
      for field in ["hasAddress", "hasLinks"] {
        let schema = try #require(fields[field] as? [String: Any])
        #expect(schema["type"] as? String == "boolean")
        #expect(schema["default"] as? Bool == false)
        let invalidValues: [Any] = [
          NSNull(), "false", 0, 1, 1.5, [] as [String], [:] as [String: Any],
        ]
        for value in invalidValues {
          let rejected = try await query(
            valid.merging([field: value]) { _, incoming in incoming }, isError: true)
          #expect(rejected["state"] as? String == "failed")
          #expect(rejected["generation"] == nil)
          #expect(rejected["rows"] == nil)
          let reason = try #require(rejected["reason"] as? [String: Any])
          #expect(reason["code"] as? String == "invalidInput")
          #expect(reason["propertyPath"] as? String == "/query/" + field)
        }
      }
      let retainedWindow = try toolValue(
        try await httpSession.data(for: rowRequest), isError: false)
      #expect(NSDictionary(dictionary: retainedWindow).isEqual(to: originalWindow))
      guard
        case .source(.item(let unchanged)) = await planner.read(
          session: session, request: .source(item)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Malformed read-only filters preserve saved content, bindings and recovery.")
        await listener.stop()
        return
      }
      #expect(unchanged.content.location == original.content.location)
      #expect(unchanged.content.links == original.content.links)
      #expect(unchanged.content.notes == original.content.notes)
      #expect(unchanged.content.title == original.content.title)
      #expect(unchanged.state.globalDone == original.state.globalDone)
      #expect(unchanged.state.archived == original.state.archived)
      #expect(unchanged.references == original.references)
      #expect(unchanged.fieldHashes == original.fieldHashes)
      #expect(unchanged.updatedAt == original.updatedAt)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func request(endpoint: URL, name: String, arguments: [String: Any]) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1,
      "method": "tools/call", "params": ["name": name, "arguments": arguments],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }

  private func toolValue(_ exchange: (Data, URLResponse), isError: Bool) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    try #require(tool["isError"] as? Bool == isError)
    let value = try #require(tool["structuredContent"] as? [String: Any])
    if !isError {
      let content = try #require(tool["content"] as? [[String: Any]])
      let text = try #require(content.first?["text"] as? String)
      let decodedText = try #require(
        JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
      #expect(NSDictionary(dictionary: decodedText).isEqual(to: value))
    }
    return value
  }
}
