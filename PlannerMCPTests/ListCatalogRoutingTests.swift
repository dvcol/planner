import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ListCatalogRoutingTests {
  @Test func malformedCatalogRequestsPreserveSourceContentRecoveryAndIssuedWindowOverHTTP()
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
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Tokyo", notes: "Original notes")))
      ).outcome, let source = created.generated.first,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list))))
    else {
      Issue.record(
        "A saved List and its original catalog window must precede malformed HTTP reads.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let invalidVariants: [([String: Any], String, String)] = [
      (["sourceKind": "list"], "invalidInput", "/query/kind"),
      (["kind": "unknown", "sourceKind": "list"], "invalidInput", "/query/kind"),
      (["kind": "catalog"], "invalidInput", "/query/sourceKind"),
      (["kind": "catalog", "sourceKind": NSNull()], "invalidInput", "/query/sourceKind"),
      (["kind": "catalog", "sourceKind": true], "invalidInput", "/query/sourceKind"),
      (["kind": "catalog", "sourceKind": "item"], "invalidInput", "/query/sourceKind"),
      (["kind": "catalog", "sourceKind": "unknown"], "invalidInput", "/query/sourceKind"),
      (["kind": "catalog", "sourceKind": "list", "text": NSNull()], "invalidInput", "/query/text"),
      (["kind": "catalog", "sourceKind": "list", "text": 12], "invalidInput", "/query/text"),
      (
        ["kind": "catalog", "sourceKind": "list", "archive": NSNull()], "invalidInput",
        "/query/archive"
      ),
      (
        ["kind": "catalog", "sourceKind": "list", "archive": true], "invalidInput", "/query/archive"
      ),
      (
        ["kind": "catalog", "sourceKind": "list", "archive": "done"], "invalidInput",
        "/query/archive"
      ),
      (["kind": "catalog", "sourceKind": "itinerary"], "unavailable", "/query/sourceKind"),
      (
        ["kind": "catalog", "sourceKind": "category", "archive": "active"], "invalidInput",
        "/query/archive"
      ),
      (
        ["kind": "catalog", "sourceKind": "tag", "archive": "all"], "unavailable",
        "/query/sourceKind"
      ),
      (
        ["kind": "catalog", "sourceKind": "schedule", "archive": "all"], "unavailable",
        "/query/sourceKind"
      ),
      (
        ["kind": "items", "scope": ["kind": "global"], "sourceKind": "list"], "unknownField",
        "/query/sourceKind"
      ),
    ]
    var cases = invalidVariants
    for property in [
      "scope", "completion", "sort", "rowPresentation", "categories", "tags", "lists", "duration",
      "scheduled", "hasAddress", "hasLinks", "unexpected/~",
    ] {
      cases.append(
        (
          ["kind": "catalog", "sourceKind": "list", property: NSNull()], "unknownField",
          "/query/"
            + property.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
              of: "/", with: "~1")
        ))
    }
    do {
      for (query, expectedCode, expectedPath) in cases {
        let failed = try failure(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_query",
              arguments: ["formatVersion": 1, "query": query])))
        #expect(failed["code"] as? String == expectedCode)
        #expect(failed["propertyPath"] as? String == expectedPath)
        guard
          case .source(.list(let retained)) = await planner.read(
            session: session, request: .source(source)),
          case .rows(let retainedWindow) = await planner.read(
            session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
          case .listedNamespaces(let namespaces) = await planner.inspectRecovery(
            request: .namespaces)
        else {
          Issue.record(
            "Every malformed catalog request must retain saved data and its issued window.")
          await listener.stop()
          return
        }
        #expect(retained.content == original.content)
        #expect(retained.createdAt == original.createdAt)
        #expect(retained.updatedAt == original.updatedAt)
        #expect(retained.fieldHashes == original.fieldHashes)
        #expect(retainedWindow.rows.first?.identity == .source(source))
        #expect(retainedWindow.rows.first?.title == "Tokyo")
        #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
        #expect(namespaces.first?.preparedProposals.isEmpty == true)
      }
      #expect(cases.count == 29)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func catalogDiscoveryOverHTTPRetainsDuplicateIdentitiesAndCompactOriginalNames()
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
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The native dataset must initialize before HTTP catalog discovery.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for name in ["Zoo", "CAFÉ GUIDE", "cafe guide", "Cafe cafe"] {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createList(
              content: .init(
                name: name, notes: String(repeating: "Full original notes. ", count: 1000))))
        ).outcome, let source = created.generated.first
      else {
        Issue.record("Each List must save its independent identity and original content.")
        return
      }
      sources.append(source)
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: sources[0], archived: true))
      ).outcome
    else {
      Issue.record("Catalog archive filtering must use the saved container state.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let active = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1, "query": ["kind": "catalog", "sourceKind": "list"],
            ])))
      #expect(active["matchingCount"] as? String == "3")
      #expect(active["rowPresentation"] is NSNull)
      #expect((active["progress"] as? [Any])?.isEmpty == true)
      #expect((active["unresolvedReferences"] as? [Any])?.isEmpty == true)
      let activeRows = try #require(active["rows"] as? [[String: Any]])
      #expect(
        (activeRows.first?["source"] as? [String: Any])?["id"] as? String
          == sources[3].id.uuidString)
      let searched = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1,
              "query": [
                "kind": "catalog", "sourceKind": "list", "text": " CaFÉ  GuIdE\n",
                "archive": "active",
              ],
            ])))
      #expect(searched["matchingCount"] as? String == "2")
      let identities = try #require(searched["rows"] as? [[String: Any]])
      #expect(NSArray(array: identities).isEqual(to: Array(activeRows.suffix(2))))
      let sourceIdentifiers = identities.compactMap {
        ($0["source"] as? [String: Any])?["id"] as? String
      }
      #expect(sourceIdentifiers == [sources[1].id.uuidString, sources[2].id.uuidString].sorted())
      let generation = try #require(searched["generation"] as? String)
      var names: [String] = []
      for offset in 0...2 {
        let window = try success(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1,
                "request": [
                  "kind": "rows", "generation": generation, "offset": String(offset), "limit": "1",
                ],
              ])))
        #expect(window["rowPresentation"] is NSNull)
        let rows = try #require(window["rows"] as? [[String: Any]])
        if offset == 2 {
          #expect(rows.isEmpty)
          continue
        }
        let row = try #require(rows.first)
        #expect(
          Set(row.keys) == [
            "identity", "title", "subtitle", "estimate", "globalDone", "localDone", "effectiveDone",
            "archived", "hasLocation", "hasLinks", "ownedLocation", "previewLink",
            "scheduleSummary",
          ])
        #expect(
          NSDictionary(dictionary: try #require(row["identity"] as? [String: Any])).isEqual(
            to: identities[offset]))
        #expect(row["archived"] as? Bool == false)
        for property in [
          "subtitle", "estimate", "globalDone", "localDone", "effectiveDone", "ownedLocation",
          "previewLink",
        ] {
          #expect(row[property] is NSNull)
        }
        #expect(row["hasLocation"] as? Bool == false)
        #expect(row["hasLinks"] as? Bool == false)
        #expect((row["scheduleSummary"] as? [String: Any])?["kind"] as? String == "none")
        names.append(try #require(row["title"] as? String))
      }
      #expect(Set(names) == ["CAFÉ GUIDE", "cafe guide"])
      let archived = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1,
              "query": ["kind": "catalog", "sourceKind": "list", "archive": "archived"],
            ])))
      let archivedRows = try #require(archived["rows"] as? [[String: Any]])
      #expect(archivedRows.count == 1)
      #expect(
        (archivedRows.first?["source"] as? [String: Any])?["id"] as? String
          == sources[0].id.uuidString)
      var listingRequest = try request(endpoint: endpoint, name: "planner_query", arguments: [:])
      listingRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let listingExchange = try await httpSession.data(for: listingRequest)
      #expect((listingExchange.1 as? HTTPURLResponse)?.statusCode == 200)
      let listing = try #require(
        JSONSerialization.jsonObject(with: listingExchange.0) as? [String: Any])
      let tools = try #require((listing["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let tool = try #require(tools.first { $0["name"] as? String == "planner_query" })
      let schema = try #require(tool["inputSchema"] as? [String: Any])
      let querySchema = try #require(
        (schema["properties"] as? [String: Any])?["query"] as? [String: Any])
      let variants = try #require(querySchema["oneOf"] as? [[String: Any]])
      #expect(variants.count == 2)
      let catalog = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "catalog"
        })
      #expect(catalog["additionalProperties"] as? Bool == false)
      #expect(Set(try #require(catalog["required"] as? [String])) == ["kind", "sourceKind"])
      let properties = try #require(catalog["properties"] as? [String: Any])
      #expect(Set(properties.keys) == ["kind", "sourceKind", "text", "archive"])
      #expect((properties["sourceKind"] as? [String: Any])?["const"] as? String == "list")
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Read-only HTTP discovery must leave independent recovery intact.")
        await listener.stop()
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 5)
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
      "jsonrpc": "2.0", "id": 1, "method": "tools/call",
      "params": ["name": name, "arguments": arguments],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }

  private func success(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let result = try #require(envelope["result"] as? [String: Any])
    try #require(result["isError"] as? Bool == false)
    let structured = try #require(result["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    let text = try #require((result["content"] as? [[String: Any]])?.first?["text"] as? String)
    let decoded = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: decoded).isEqual(to: structured))
    return structured
  }

  private func failure(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let result = try #require(envelope["result"] as? [String: Any])
    #expect(result["isError"] as? Bool == true)
    let structured = try #require(result["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    #expect(structured["state"] as? String == "failed")
    #expect(structured["rows"] == nil)
    return try #require(structured["reason"] as? [String: Any])
  }
}
