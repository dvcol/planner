import Foundation
import PlannerCore
import Testing

@testable import Planner

struct MembershipRowRoutingTests {
  @Test func contextualQueryAndWindowOverHTTPKeepExactAppearanceAndUnfilteredProgress()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdList, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let list = createdList.generated.first
    else {
      Issue.record("The real List must exist before its HTTP query.")
      return
    }
    var sources: [PlannerEntityReference] = []
    var memberships: [UUID] = []
    for title in ["Z Hotel", "Archived stop"] {
      guard
        case .applied(let createdItem, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(
              content: .init(
                title: title, notes: String(repeating: "Original notes. ", count: 1000),
                location: .init(
                  displayName: "Meeting point", formattedAddress: "Tokyo",
                  coordinate: .init(latitude: 35, longitude: 139)),
                estimate: .init(minutes: 120, displayUnit: .hour),
                links: [
                  .init(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
                  .init(originalUrl: "https://example.com/hotel", label: "Website"),
                ])))
        ).outcome,
        let item = createdItem.generated.first,
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = added.generatedReferences.first
      else {
        Issue.record("Shared Items and exact memberships must save through Core.")
        return
      }
      sources.append(item)
      memberships.append(membershipId)
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: sources[1].id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: sources[1], archived: true))
      ).outcome
    else {
      Issue.record("The hidden child must still count toward complete-scope progress.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let presentation: [String: Any] = [
      "referenceInstant": 813202200.0, "displayTimeZone": "Asia/Tokyo",
    ]
    let arguments: [String: Any] = [
      "formatVersion": 1,
      "query": [
        "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
        "sort": ["mode": "manual", "direction": "ascending"], "rowPresentation": presentation,
      ],
    ]
    do {
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
      let properties = try #require(querySchema["properties"] as? [String: Any])
      let scopeSchema = try #require(properties["scope"] as? [String: Any])
      let scopes = try #require(scopeSchema["oneOf"] as? [[String: Any]])
      #expect(scopes.count == 2)
      let listSchema = try #require(
        scopes.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "list"
        })
      #expect(listSchema["additionalProperties"] as? Bool == false)
      #expect(Set(try #require(listSchema["required"] as? [String])) == ["kind", "listId"])
      let sortSchema = try #require(properties["sort"] as? [String: Any])
      #expect(sortSchema["additionalProperties"] as? Bool == false)
      #expect(Set(try #require(sortSchema["required"] as? [String])) == ["mode", "direction"])
      let query = try success(
        try await httpSession.data(
          for:
            request(endpoint: endpoint, name: "planner_query", arguments: arguments)))
      #expect(
        Set(query.keys) == [
          "formatVersion", "generation", "matchingCount", "rows",
          "rowPresentation", "unresolvedReferences", "progress",
        ])
      #expect(query["matchingCount"] as? String == "1")
      #expect((query["unresolvedReferences"] as? [Any])?.isEmpty == true)
      let identity: [String: Any] = [
        "kind": "appearance", "source": ["kind": "item", "id": sources[0].id.uuidString],
        "appearance": [
          "kind": "listMembership", "listId": list.id.uuidString,
          "membershipId": memberships[0].uuidString,
        ],
      ]
      #expect(
        NSArray(array: try #require(query["rows"] as? [[String: Any]])).isEqual(to: [identity]))
      #expect(
        NSDictionary(dictionary: try #require(query["rowPresentation"] as? [String: Any]))
          .isEqual(to: presentation))
      let progress = try #require((query["progress"] as? [[String: Any]])?.first)
      #expect(
        NSDictionary(dictionary: progress).isEqual(to: [
          "container": ["kind": "list", "id": list.id.uuidString], "state": "partial",
          "doneCount": "1", "totalCount": "2",
        ]))
      let generation = try #require(query["generation"] as? String)
      let rowArguments: [String: Any] = [
        "formatVersion": 1,
        "request": [
          "kind": "rows", "generation": generation,
          "offset": "0", "limit": "1",
        ],
      ]
      let window = try success(
        try await httpSession.data(
          for:
            request(endpoint: endpoint, name: "planner_read", arguments: rowArguments)))
      let row = try #require((window["rows"] as? [[String: Any]])?.first)
      #expect(
        Set(row.keys) == [
          "identity", "title", "subtitle", "estimate", "globalDone",
          "localDone", "effectiveDone", "archived", "hasLocation", "hasLinks", "ownedLocation",
          "previewLink", "scheduleSummary",
        ])
      #expect(
        NSDictionary(dictionary: try #require(row["identity"] as? [String: Any]))
          .isEqual(to: identity))
      #expect(row["title"] as? String == "Z Hotel")
      #expect(row["globalDone"] as? Bool == false)
      #expect(row["localDone"] as? Bool == false)
      #expect(row["effectiveDone"] as? Bool == false)
      #expect(row["archived"] as? Bool == false)
      #expect(row["hasLocation"] as? Bool == true)
      #expect(row["hasLinks"] as? Bool == true)
      #expect((row["ownedLocation"] as? [String: Any])?["formattedAddress"] as? String == "Tokyo")
      #expect(
        (row["previewLink"] as? [String: Any])?["originalUrl"] as? String
          == "https://example.com/hotel")
      #expect((row["scheduleSummary"] as? [String: Any])?["kind"] as? String == "none")
      #expect(
        NSDictionary(dictionary: try #require(window["rowPresentation"] as? [String: Any]))
          .isEqual(to: presentation))
      let beyond = try success(
        try await httpSession.data(
          for:
            request(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1,
                "request": [
                  "kind": "rows", "generation": generation,
                  "offset": "1", "limit": "1",
                ],
              ])))
      #expect((beyond["rows"] as? [Any])?.isEmpty == true)
      #expect(beyond["matchingCount"] as? String == "1")
      guard
        case .source(.item(let original)) = await planner.read(
          session: session, request: .source(sources[0])),
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .editItem(
              sourceId: sources[0].id, changes: .init(notes: .set("Updated")),
              expectedFieldHashes: original.fieldHashes))
        ).outcome
      else {
        await listener.stop()
        Issue.record("A source edit must commit before checking stale HTTP windows.")
        return
      }
      let stale = try failure(
        try await httpSession.data(
          for:
            request(endpoint: endpoint, name: "planner_read", arguments: rowArguments)))
      #expect(stale["code"] as? String == "staleSnapshot")
      let refreshed = try success(
        try await httpSession.data(
          for:
            request(endpoint: endpoint, name: "planner_query", arguments: arguments)))
      #expect(refreshed["generation"] as? String != generation)
      #expect(
        NSArray(array: try #require(refreshed["rows"] as? [[String: Any]])).isEqual(to: [identity]))
      #expect(
        NSArray(array: try #require(refreshed["progress"] as? [[String: Any]]))
          .isEqual(to: [progress]))
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedContextScopesAndSortsPreserveSavedDataAndIssuedWindowOverHTTP() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdList, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let list = createdList.generated.first,
      case .applied(let createdItem, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .list(list.id)))))
    else {
      Issue.record("The exact List and issued projection must precede invalid HTTP queries.")
      return
    }
    let listScope: [String: Any] = ["kind": "list", "listId": list.id.uuidString]
    let titleSort: [String: Any] = ["mode": "title", "direction": "ascending"]
    var invalid: [([String: Any], String, String)] = [
      (["kind": "items", "scope": ["kind": "list"]], "invalidInput", "/query/scope/listId"),
      (
        ["kind": "items", "scope": ["kind": "list", "listId": item.id.uuidString]],
        "missingReference", ""
      ),
      (
        ["kind": "items", "scope": ["kind": "global", "listId": list.id.uuidString]],
        "unknownField", "/query/scope/listId"
      ),
      (
        ["kind": "items", "scope": ["kind": "inbox", "listId": list.id.uuidString]], "unknownField",
        "/query/scope/listId"
      ),
      (["kind": "items", "scope": ["kind": "itinerary"]], "invalidInput", "/query/scope/kind"),
      (
        [
          "kind": "items",
          "scope": listScope.merging(["weird/~": true]) { _, incoming in incoming },
        ], "unknownField", "/query/scope/weird~1~0"
      ),
      (
        [
          "kind": "items", "scope": listScope,
          "sort": ["mode": "manual", "direction": "descending"],
        ], "invalidInput", "/query/sort"
      ),
      (
        [
          "kind": "items", "scope": ["kind": "global"],
          "sort": ["mode": "manual", "direction": "ascending"],
        ], "invalidInput", "/query/sort"
      ),
      (
        [
          "kind": "items", "scope": ["kind": "inbox"],
          "sort": ["mode": "manual", "direction": "ascending"],
        ], "invalidInput", "/query/sort"
      ),
      (
        ["kind": "items", "scope": listScope, "sort": ["mode": "title"]], "invalidInput",
        "/query/sort/direction"
      ),
      (
        ["kind": "items", "scope": listScope, "sort": ["direction": "ascending"]], "invalidInput",
        "/query/sort/mode"
      ),
      (
        [
          "kind": "items", "scope": listScope,
          "sort": titleSort.merging(["weird/~": true]) { _, incoming in incoming },
        ], "unknownField", "/query/sort/weird~1~0"
      ),
      (
        [
          "kind": "items", "scope": listScope,
          "sort": ["mode": "created", "direction": "ascending"],
        ], "unavailable", "/query/sort/mode"
      ),
    ]
    for value in [NSNull(), "invalid", [Any]()] as [Any] {
      invalid.append((["kind": "items", "scope": value], "invalidInput", "/query/scope"))
      invalid.append(
        (["kind": "items", "scope": listScope, "sort": value], "invalidInput", "/query/sort"))
    }
    for value in [NSNull(), true, 1, "invalid"] as [Any] {
      invalid.append(
        (
          ["kind": "items", "scope": ["kind": "list", "listId": value]], "invalidInput",
          "/query/scope/listId"
        ))
      invalid.append(
        (
          [
            "kind": "items", "scope": listScope, "sort": ["mode": value, "direction": "ascending"],
          ], "invalidInput", "/query/sort/mode"
        ))
      invalid.append(
        (
          ["kind": "items", "scope": listScope, "sort": ["mode": "title", "direction": value]],
          "invalidInput", "/query/sort/direction"
        ))
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let rowArguments: [String: Any] = [
      "formatVersion": 1,
      "request": [
        "kind": "rows", "generation": snapshot.generation.uuidString, "offset": "0", "limit": "1",
      ],
    ]
    do {
      let before = try success(
        try await httpSession.data(
          for:
            request(endpoint: endpoint, name: "planner_read", arguments: rowArguments)))
      for (query, code, path) in invalid {
        let reason = try failure(
          try await httpSession.data(
            for:
              request(
                endpoint: endpoint, name: "planner_query",
                arguments: ["formatVersion": 1, "query": query])))
        #expect(reason["code"] as? String == code)
        if path.isEmpty {
          #expect(reason["propertyPath"] is NSNull)
        } else {
          #expect(reason["propertyPath"] as? String == path)
        }
      }
      let after = try success(
        try await httpSession.data(
          for:
            request(endpoint: endpoint, name: "planner_read", arguments: rowArguments)))
      #expect(NSDictionary(dictionary: after).isEqual(to: before))
      let caseVariant = try success(
        try await httpSession.data(
          for:
            request(
              endpoint: endpoint, name: "planner_query",
              arguments: [
                "formatVersion": 1,
                "query": [
                  "kind": "items",
                  "scope": ["kind": "list", "listId": list.id.uuidString.lowercased()],
                ],
              ])))
      #expect(caseVariant["matchingCount"] as? String == "1")
      await listener.stop()
      guard
        case .source(.list(let retained)) = await planner.read(
          session: session, request: .source(list)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Rejected queries must preserve the complete List and independent recovery.")
        return
      }
      #expect(retained.content == original.content)
      #expect(retained.updatedAt == original.updatedAt)
      #expect(retained.fieldHashes == original.fieldHashes)
      #expect(retained.references == original.references)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
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
    let content = try #require(result["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
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
    #expect(structured["state"] as? String == "failed")
    #expect(structured["rows"] == nil)
    return try #require(structured["reason"] as? [String: Any])
  }
}
