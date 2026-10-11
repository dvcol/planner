import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryCatalogRoutingTests {
  @Test func advertisedItineraryCatalogReturnsCompactOwnedPreviewsAndPreservesRecoveryOverHTTP()
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
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      throw CancellationError()
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: datasetSession, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let location = PlannerOwnedLocation(
      displayName: "Tokyo", formattedAddress: "Tokyo, Japan", coordinate: nil)
    var sources: [PlannerEntityReference] = []
    for content in [
      PlannerItineraryContentInput(
        title: "CAFÉ GUIDE", notes: "Keep notes", location: location,
        links: [.init(originalUrl: "https://example.com/guide", label: "Guide")]),
      .init(title: "cafe guide"), .init(title: "Weekend"),
    ] {
      sources.append(
        try #require(try await save(.createItinerary(content: content)).generated.first))
    }
    _ = try await save(.setArchive(source: sources[2], archived: true))
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: datasetSession, request: .source(sources[0])),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let originalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let listing = try result(
        try await httpSession.data(
          for: request(endpoint: endpoint, method: "tools/list", parameters: [:])))
      let tools = try #require(listing["tools"] as? [[String: Any]])
      let queryTool = try #require(tools.first { $0["name"] as? String == "planner_query" })
      let schema = try #require(queryTool["inputSchema"] as? [String: Any])
      let querySchema = try #require(
        (schema["properties"] as? [String: Any])?["query"] as? [String: Any])
      let variants = try #require(querySchema["oneOf"] as? [[String: Any]])
      let catalogSchema = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "catalog"
        })
      #expect(catalogSchema["additionalProperties"] as? Bool == false)
      let properties = try #require(catalogSchema["properties"] as? [String: Any])
      let sourceKind = try #require(properties["sourceKind"] as? [String: Any])
      #expect(Set(try #require(sourceKind["enum"] as? [String])) == ["list", "itinerary"])
      func call(_ name: String, arguments: [String: Any], isError: Bool = false) async throws
        -> [String: Any]
      {
        let response = try result(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, method: "tools/call",
              parameters: ["name": name, "arguments": arguments])))
        #expect(response["isError"] as? Bool == isError)
        let structured = try #require(response["structuredContent"] as? [String: Any])
        if !isError {
          let text = try #require(
            (response["content"] as? [[String: Any]])?.first?["text"] as? String)
          let encoded = try #require(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
          #expect(NSDictionary(dictionary: encoded).isEqual(to: structured))
        }
        return structured
      }
      func query(_ archive: String, text: String = "") async throws -> [String: Any] {
        try await call(
          "planner_query",
          arguments: [
            "formatVersion": 1,
            "query": [
              "kind": "catalog", "sourceKind": "itinerary", "archive": archive, "text": text,
            ],
          ])
      }
      let active = try await query("active")
      let archived = try await query("archived")
      let all = try await query("all")
      let searched = try await query("all", text: "GUIDE cafe")
      #expect(active["matchingCount"] as? String == "2")
      #expect(archived["matchingCount"] as? String == "1")
      #expect(all["matchingCount"] as? String == "3")
      #expect(searched["matchingCount"] as? String == "2")
      #expect(searched["rowPresentation"] is NSNull)
      let identities = try #require(searched["rows"] as? [[String: Any]])
      let identifiers = identities.compactMap { ($0["source"] as? [String: Any])?["id"] as? String }
      #expect(identifiers == [sources[0].id.uuidString, sources[1].id.uuidString].sorted())
      let generation = try #require(searched["generation"] as? String)
      let offset = try #require(identifiers.firstIndex(of: sources[0].id.uuidString))
      let window = try await call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": generation, "offset": String(offset), "limit": "1",
          ],
        ])
      let rows = try #require(window["rows"] as? [[String: Any]])
      #expect(rows.count == 1 && window["matchingCount"] as? String == "2")
      let row = try #require(rows.first)
      #expect(
        Set(row.keys) == [
          "identity", "title", "subtitle", "estimate", "globalDone", "localDone", "effectiveDone",
          "archived", "hasLocation", "hasLinks", "ownedLocation", "previewLink", "labels",
          "scheduleSummary",
        ])
      #expect((row["labels"] as? [Any])?.isEmpty == true)
      #expect(row["title"] as? String == "CAFÉ GUIDE")
      #expect(
        row["globalDone"] is NSNull && row["localDone"] is NSNull && row["effectiveDone"] is NSNull)
      #expect(row["hasLocation"] as? Bool == true && row["hasLinks"] as? Bool == true)
      #expect(
        (row["ownedLocation"] as? [String: Any])?["formattedAddress"] as? String == "Tokyo, Japan")
      #expect(
        (row["previewLink"] as? [String: Any])?["originalUrl"] as? String
          == "https://example.com/guide")
      #expect((row["scheduleSummary"] as? [String: Any])?["kind"] as? String == "none")
      for (field, value, code) in [
        ("text", true as Any, "invalidInput"), ("archive", "done" as Any, "invalidInput"),
        ("completion", "done" as Any, "unknownField"),
      ] {
        var invalid: [String: Any] = ["kind": "catalog", "sourceKind": "itinerary"]
        invalid[field] = value
        let rejected = try await call(
          "planner_query", arguments: ["formatVersion": 1, "query": invalid], isError: true)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == "/query/" + field)
      }
      guard
        case .source(.itinerary(let retained)) = await planner.read(
          session: datasetSession, request: .source(sources[0])),
        case .listedNamespaces(let currentNamespaces) = await planner.inspectRecovery(
          request: .namespaces),
        case .selected(let retainedRecovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      #expect(retained.content == before.content)
      #expect(retained.fieldHashes == before.fieldHashes && retained.updatedAt == before.updatedAt)
      #expect(retained.references == before.references)
      #expect(retainedRecovery.portableData == originalRecovery.portableData)
      #expect(currentNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func request(endpoint: URL, method: String, parameters: [String: Any]) throws
    -> URLRequest
  {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": method, "params": parameters,
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }

  private func result(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    return try #require(envelope["result"] as? [String: Any])
  }
}
