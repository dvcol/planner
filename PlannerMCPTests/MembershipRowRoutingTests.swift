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
      let queryVariants = try #require(
        (schema["properties"] as? [String: Any])?["query"] as? [String: Any])
      let querySchemas = try #require(queryVariants["oneOf"] as? [[String: Any]])
      let querySchema = try #require(
        querySchemas.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "items"
        })
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

  @Test func localCompletionOverHTTPChangesOnlyExactAppearanceAndReplayRetainsLaterTodo()
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
      case .applied(let createdItem, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original")))
      ).outcome,
      let item = createdItem.generated.first
    else {
      Issue.record("The shared Item must save before HTTP contextual completion.")
      return
    }
    var lists: [PlannerEntityReference] = []
    var membershipIds: [UUID] = []
    for name in ["Tokyo", "Wishlist"] {
      guard
        case .applied(let createdList, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: name)))
        ).outcome,
        let list = createdList.generated.first,
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = added.generatedReferences.first
      else {
        Issue.record("Two exact memberships must exist before the agent changes one.")
        return
      }
      lists.append(list)
      membershipIds.append(membershipId)
    }
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalSecondList)) = await planner.read(
        session: session, request: .source(lists[1])),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .list(lists[0].id)))))
    else {
      Issue.record("Shared Item and other List must be read before checking isolation.")
      return
    }
    let appearance: [String: Any] = [
      "kind": "listMembership", "listId": lists[0].id.uuidString,
      "membershipId": membershipIds[0].uuidString,
    ]
    let command: [String: Any] = [
      "type": "setCompletion",
      "scope": [
        "kind": "appearance", "appearance": appearance,
      ], "done": true,
    ]
    let operationId = UUID()
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      var invalid: [([String: Any], String, String)] = [
        (
          command.merging([
            "scope": [
              "kind": "appearance",
              "appearance": appearance.merging(["kind": "listItem"]) { _, incoming in incoming },
            ]
          ]) { _, incoming in incoming }, "invalidInput", "/command/scope/appearance/kind"
        ),
        (
          command.merging([
            "scope": [
              "kind": "appearance",
              "appearance": appearance.merging(["listId": lists[1].id.uuidString]) { _, incoming in
                incoming
              },
            ]
          ]) { _, incoming in incoming }, "missingReference", ""
        ),
        (
          command.merging([
            "scope": [
              "kind": "appearance",
              "appearance": appearance.merging(["membershipId": item.id.uuidString]) {
                _, incoming in incoming
              },
            ]
          ]) { _, incoming in incoming }, "missingReference", ""
        ),
        (
          command.merging([
            "scope": ["kind": "appearance", "itemId": item.id.uuidString, "appearance": appearance]
          ]) { _, incoming in incoming }, "unknownField", "/command/scope/itemId"
        ),
        (
          command.merging(["expectedFieldHashes": [:]]) { _, incoming in incoming }, "unknownField",
          "/command/expectedFieldHashes"
        ),
      ]
      for key in ["kind", "listId", "membershipId"] {
        var omitted = appearance
        omitted.removeValue(forKey: key)
        invalid.append(
          (
            command.merging(["scope": ["kind": "appearance", "appearance": omitted]]) {
              _, incoming in incoming
            }, "invalidInput", "/command/scope/appearance/" + key
          ))
      }
      for value in [NSNull(), "invalid", [Any]()] as [Any] {
        invalid.append(
          (
            command.merging(["scope": ["kind": "appearance", "appearance": value]]) { _, incoming in
              incoming
            }, "invalidInput", "/command/scope/appearance"
          ))
      }
      for key in ["listId", "membershipId"] {
        for value in [NSNull(), true, 1, "invalid"] as [Any] {
          let malformed = appearance.merging([key: value]) { _, incoming in incoming }
          invalid.append(
            (
              command.merging(["scope": ["kind": "appearance", "appearance": malformed]]) {
                _, incoming in incoming
              }, "invalidInput", "/command/scope/appearance/" + key
            ))
        }
      }
      for key in ["sourceId", "weird/~"] {
        let malformed = appearance.merging([key: true]) { _, incoming in incoming }
        let escaped = key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        invalid.append(
          (
            command.merging(["scope": ["kind": "appearance", "appearance": malformed]]) {
              _, incoming in incoming
            }, "unknownField", "/command/scope/appearance/" + escaped
          ))
      }
      for value in [NSNull(), true, 1] as [Any] {
        let malformed = appearance.merging(["kind": value]) { _, incoming in incoming }
        invalid.append(
          (
            command.merging(["scope": ["kind": "appearance", "appearance": malformed]]) {
              _, incoming in incoming
            }, "invalidInput", "/command/scope/appearance/kind"
          ))
      }
      for value in [NSNull(), 1, "true"] as [Any] {
        invalid.append(
          (
            command.merging(["done": value]) { _, incoming in incoming }, "invalidInput",
            "/command/done"
          ))
      }
      let rowArguments: [String: Any] = [
        "formatVersion": 1,
        "request": [
          "kind": "rows", "generation": snapshot.generation.uuidString, "offset": "0", "limit": "1",
        ],
      ]
      let originalRows = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read", arguments: rowArguments)))
      for (invalidCommand, code, path) in invalid {
        let invalidOperationId = UUID()
        let rejected = try rejection(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1,
                "operationId": invalidOperationId.uuidString, "command": invalidCommand,
              ])))
        #expect(rejected["operationId"] as? String == invalidOperationId.uuidString)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        if path.isEmpty {
          #expect(reason["propertyPath"] is NSNull)
        } else {
          #expect(reason["propertyPath"] as? String == path)
        }
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: session, operationId: invalidOperationId)
        else {
          await listener.stop()
          Issue.record("Invalid local commands cannot create applied evidence or global fallback.")
          return
        }
      }
      let unchangedRows = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read", arguments: rowArguments)))
      #expect(NSDictionary(dictionary: unchangedRows).isEqual(to: originalRows))
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        await listener.stop()
        Issue.record("Rejected local commands must retain independent recovery.")
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 5)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      let completedRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": operationId.uuidString, "command": command,
        ])
      let completed = try success(try await httpSession.data(for: completedRequest))
      #expect(completed["state"] as? String == "applied")
      #expect(completed["operationId"] as? String == operationId.uuidString)
      #expect((completed["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "6")
      let result = try #require(completed["result"] as? [String: Any])
      #expect((result["generated"] as? [Any])?.isEmpty == true)
      let reference: [String: Any] = [
        "kind": "membership", "id": membershipIds[0].uuidString,
        "owner": ["kind": "list", "id": lists[0].id.uuidString],
        "source": ["kind": "item", "id": item.id.uuidString], "appearance": appearance,
      ]
      #expect(
        NSArray(array: try #require(result["affected"] as? [[String: Any]])).isEqual(to: [
          reference, ["kind": "list", "id": lists[0].id.uuidString],
        ]))
      let stale = try failure(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": [
                "kind": "rows", "generation": snapshot.generation.uuidString,
                "offset": "0", "limit": "1",
              ],
            ])))
      #expect(stale["code"] as? String == "staleSnapshot")
      let details = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1, "request": ["kind": "appearance", "appearance": appearance],
            ])))
      let detail = try #require(details["value"] as? [String: Any])
      #expect(detail["globalDone"] as? Bool == false)
      #expect(detail["localDone"] as? Bool == true)
      #expect(detail["effectiveDone"] as? Bool == true)
      let query = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1,
              "query": [
                "kind": "items", "scope": ["kind": "list", "listId": lists[0].id.uuidString],
              ],
            ])))
      #expect(query["matchingCount"] as? String == "0")
      #expect((query["progress"] as? [[String: Any]])?.first?["state"] as? String == "complete")
      guard
        case .appearance(let other) = await planner.read(
          session: session,
          request: .appearance(
            .listMembership(listId: lists[1].id, membershipId: membershipIds[1]))),
        case .source(.item(let retainedItem)) = await planner.read(
          session: session, request: .source(item)),
        case .source(.list(let retainedSecondList)) = await planner.read(
          session: session, request: .source(lists[1]))
      else {
        await listener.stop()
        Issue.record(
          "The shared Item and other context must remain unchanged after the HTTP write.")
        return
      }
      #expect(!other.localDone && !other.globalDone && !other.effectiveDone)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedItem.content.notes == "Original")
      #expect(retainedSecondList.updatedAt == originalSecondList.updatedAt)
      #expect(retainedSecondList.progress.doneCount == 0)
      let reopened = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": command.merging(["done": false]) { _, incoming in incoming },
            ])))
      #expect((reopened["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "7")
      let replayed = try success(try await httpSession.data(for: completedRequest))
      #expect(NSDictionary(dictionary: replayed).isEqual(to: completed))
      let retainedDetails = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1, "request": ["kind": "appearance", "appearance": appearance],
            ])))
      #expect((retainedDetails["value"] as? [String: Any])?["localDone"] as? Bool == false)
      #expect((retainedDetails["value"] as? [String: Any])?["effectiveDone"] as? Bool == false)
      let status = try success(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_operation_status",
            arguments: [
              "formatVersion": 1, "operationId": operationId.uuidString,
            ])))
      #expect(status["state"] as? String == "appliedRecoveryComplete")
      #expect(status["checkpointGeneration"] as? String == "6")
      #expect(
        NSDictionary(dictionary: try #require(status["result"] as? [String: Any])).isEqual(
          to: result))
      var listingRequest = try request(endpoint: endpoint, name: "planner_execute", arguments: [:])
      listingRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let listingExchange = try await httpSession.data(for: listingRequest)
      let listing = try #require(
        JSONSerialization.jsonObject(with: listingExchange.0) as? [String: Any])
      let tools = try #require((listing["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let tool = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let schema = try #require(tool["inputSchema"] as? [String: Any])
      let commandSchema = try #require(
        (schema["properties"] as? [String: Any])?["command"] as? [String: Any])
      let variants = try #require(commandSchema["oneOf"] as? [[String: Any]])
      let completionSchema = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "setCompletion"
        })
      let scopeSchema = try #require(
        (completionSchema["properties"] as? [String: Any])?["scope"] as? [String: Any])
      let scopes = try #require(scopeSchema["oneOf"] as? [[String: Any]])
      let localSchema = try #require(
        scopes.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "appearance"
        })
      #expect(localSchema["additionalProperties"] as? Bool == false)
      #expect(Set(try #require(localSchema["required"] as? [String])) == ["kind", "appearance"])
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
    let content = try #require(result["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let decoded = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: decoded).isEqual(to: structured))
    return structured
  }

  private func rejection(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let result = try #require(envelope["result"] as? [String: Any])
    #expect(result["isError"] as? Bool == true)
    let structured = try #require(result["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    #expect(structured["state"] as? String == "rejected")
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
