import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ContainerCatalogSortRoutingTests {
  @Test func advertisedCatalogSortsReturnEveryOrderedPageWithoutChangingSavedData() async throws {
    let directory = fixtureDirectory()
    let planner = PlannerCore.Planner(configuration: configuration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      throw CancellationError()
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: datasetSession, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    var items: [PlannerEntityReference] = []
    for (title, minutes) in [
      ("Hour", Int64(60)), ("Two hours", 120), ("Half hour", 30),
      ("Unknown", nil), ("Maximum", Int64.max), ("One", 1),
    ] {
      let estimate = minutes.map { PlannerEstimate(minutes: $0, displayUnit: .minute) }
      items.append(
        try #require(
          try await save(.createItem(content: .init(title: title, estimate: estimate)))
            .generated.first))
    }
    let names = ["Zulu", "Alpha", "CAFÉ", "cafe", "Partial", "Overflow", "Other partial"]
    let itemIndices = [[0], [1], [], [3], [2, 3], [4, 5], [0, 3]]
    var catalogs: [(kind: String, sources: [PlannerEntityReference])] = []
    for kind in ["list", "itinerary"] {
      var sources: [PlannerEntityReference] = []
      for (index, name) in names.enumerated() {
        let manual: PlannerEstimate? = index == 3 ? .init(minutes: 90, displayUnit: .minute) : nil
        let command: PlannerCommand
        if kind == "list" {
          command = .createList(content: .init(name: name, manualEstimate: manual))
        } else {
          command = .createItinerary(content: .init(title: name, manualEstimate: manual))
        }
        let source = try #require(try await save(command).generated.first)
        for itemIndex in itemIndices[index] {
          if kind == "list" {
            _ = try await save(
              .addMembership(itemId: items[itemIndex].id, listId: source.id, placement: .last))
          } else {
            _ = try await save(
              .addItineraryEntry(itineraryId: source.id, source: items[itemIndex], placement: .last)
            )
          }
        }
        sources.append(source)
      }
      _ = try await save(.setArchive(source: sources[6], archived: true))
      switch await planner.read(session: datasetSession, request: .source(sources[0])) {
      case .source(.list(let value)):
        _ = try await save(
          .editList(
            sourceId: sources[0].id, changes: .init(notes: .set("Retained notes")),
            expectedFieldHashes: value.fieldHashes))
      case .source(.itinerary(let value)):
        _ = try await save(
          .editItinerary(
            sourceId: sources[0].id, changes: .init(notes: .set("Retained notes")),
            expectedFieldHashes: value.fieldHashes))
      default: throw CancellationError()
      }
      catalogs.append((kind, sources))
    }
    guard case .exported(let before) = await planner.exportData(session: datasetSession) else {
      throw CancellationError()
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let listing = try response(
        try await httpSession.data(
          for: request(endpoint, method: "tools/list", parameters: [:])))
      let tools = try #require(listing["tools"] as? [[String: Any]])
      let tool = try #require(tools.first { $0["name"] as? String == "planner_query" })
      let properties = try #require(
        (tool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (properties["query"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let catalogProperties = try #require(
        variants.compactMap { $0["properties"] as? [String: Any] }.first {
          (($0["sourceKind"] as? [String: Any])?["enum"] as? [String]) == ["list", "itinerary"]
        })
      let sort = catalogProperties["sort"] as? [String: Any]
      #expect(sort?["additionalProperties"] as? Bool == false)
      #expect(Set(sort?["required"] as? [String] ?? []) == ["mode", "direction"])
      let sortProperties = sort?["properties"] as? [String: Any]
      #expect(
        (sortProperties?["mode"] as? [String: Any])?["enum"] as? [String]
          == ["title", "created", "lastUpdated", "fullEstimate"])
      #expect(
        (sortProperties?["direction"] as? [String: Any])?["enum"] as? [String]
          == ["ascending", "descending"])
      for catalog in catalogs {
        let sources = catalog.sources
        let ties = [sources[2].id.uuidString, sources[3].id.uuidString].sorted()
        let alphabetical =
          [sources[1].id.uuidString] + ties
          + [6, 5, 4, 0].map { sources[$0].id.uuidString }
        var query: [String: Any] = [
          "kind": "catalog", "sourceKind": catalog.kind, "archive": "all",
        ]
        let original = try await call(httpSession, endpoint, name: "planner_query", query: query)
        #expect(try identifiers(original["rows"]) == alphabetical)
        for mode in ["title", "created", "lastUpdated", "fullEstimate"] {
          for direction in ["ascending", "descending"] {
            query["sort"] = ["mode": mode, "direction": direction]
            let snapshot = try await call(
              httpSession, endpoint, name: "planner_query", query: query)
            let expected: [String]
            switch (mode, direction) {
            case ("title", "ascending"): expected = alphabetical
            case ("title", _):
              expected =
                [0, 4, 5, 6].map { sources[$0].id.uuidString } + ties
                + [sources[1].id.uuidString]
            case ("created", "ascending"): expected = sources.map { $0.id.uuidString }
            case ("created", _): expected = sources.reversed().map { $0.id.uuidString }
            case ("lastUpdated", "ascending"):
              expected = [1, 2, 3, 4, 5, 6, 0].map { sources[$0].id.uuidString }
            case ("lastUpdated", _):
              expected = [0, 6, 5, 4, 3, 2, 1].map { sources[$0].id.uuidString }
            case ("fullEstimate", "ascending"):
              expected = [2, 0, 3, 1, 4, 6, 5].map { sources[$0].id.uuidString }
            default: expected = [1, 3, 0, 2, 6, 4, 5].map { sources[$0].id.uuidString }
            }
            #expect(try identifiers(snapshot["rows"]) == expected)
            #expect(snapshot["matchingCount"] as? String == "7")
            let generation = try #require(snapshot["generation"] as? String)
            var hydrated: [String] = []
            for offset in [0, 2, 4, 6, 7] {
              let window = try await call(
                httpSession, endpoint, name: "planner_read",
                query: [
                  "kind": "rows", "generation": generation, "offset": String(offset), "limit": "2",
                ])
              let rows = try #require(window["rows"] as? [[String: Any]])
              for row in rows {
                #expect(row["notes"] == nil && row["fieldHashes"] == nil)
                hydrated += try identifiers([row["identity"] as Any])
              }
              #expect(window["matchingCount"] as? String == "7")
            }
            #expect(hydrated == expected)
          }
        }
        query["text"] = "CAFE"
        query["archive"] = "active"
        query["sort"] = ["mode": "title", "direction": "descending"]
        let filtered = try await call(httpSession, endpoint, name: "planner_query", query: query)
        #expect(try identifiers(filtered["rows"]) == ties)
        let retainedGeneration = try #require(original["generation"] as? String)
        let retained = try await call(
          httpSession, endpoint, name: "planner_read",
          query: ["kind": "rows", "generation": retainedGeneration, "offset": "0", "limit": "2"])
        let retainedRows = try #require(retained["rows"] as? [[String: Any]])
        #expect(
          try identifiers(retainedRows.map { $0["identity"] as Any })
            == Array(alphabetical.prefix(2)))
      }
      guard case .exported(let after) = await planner.exportData(session: datasetSession) else {
        throw CancellationError()
      }
      #expect(after == before)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedAndUnsupportedSortsPreserveExistingQueriesAndSavedData() async throws {
    let directory = fixtureDirectory()
    let planner = PlannerCore.Planner(configuration: configuration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      throw CancellationError()
    }
    var sources: [PlannerEntityReference] = []
    for title in ["Zulu", "Alpha"] {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: datasetSession,
            command: .createItem(content: .init(title: title)))
        ).outcome
      else { throw CancellationError() }
      sources.append(try #require(applied.generated.first))
    }
    guard case .exported(let before) = await planner.exportData(session: datasetSession) else {
      throw CancellationError()
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let original = try await call(
        httpSession, endpoint, name: "planner_query",
        query: ["kind": "items", "scope": ["kind": "global"]])
      #expect(try identifiers(original["rows"]) == sources.reversed().map { $0.id.uuidString })
      let descending = try await call(
        httpSession, endpoint, name: "planner_query",
        query: [
          "kind": "items", "scope": ["kind": "global"],
          "sort": ["mode": "title", "direction": "descending"],
        ])
      #expect(try identifiers(descending["rows"]) == sources.map { $0.id.uuidString })
      let invalidSorts: [(value: Any, code: String, path: String)] = [
        (NSNull(), "invalidInput", "/query/sort"),
        (true, "invalidInput", "/query/sort"),
        ("created", "invalidInput", "/query/sort"),
        (["title", "ascending"], "invalidInput", "/query/sort"),
        ([String: String](), "invalidInput", "/query/sort/direction"),
        (["mode": "title"], "invalidInput", "/query/sort/direction"),
        (["direction": "ascending"], "invalidInput", "/query/sort/mode"),
        (["mode": NSNull(), "direction": "ascending"], "invalidInput", "/query/sort/mode"),
        (["mode": 1, "direction": "ascending"], "invalidInput", "/query/sort/mode"),
        (["mode": "manual", "direction": "ascending"], "invalidInput", "/query/sort/mode"),
        (["mode": "duration", "direction": "ascending"], "invalidInput", "/query/sort/mode"),
        (["mode": "title", "direction": "up"], "invalidInput", "/query/sort/direction"),
        (["mode": "title", "direction": false], "invalidInput", "/query/sort/direction"),
        (["mode": "title", "direction": NSNull()], "invalidInput", "/query/sort/direction"),
        (
          ["mode": "title", "direction": "ascending", "un~known/path": true], "unknownField",
          "/query/sort/un~0known~1path"
        ),
      ]
      for kind in ["list", "itinerary"] {
        for invalid in invalidSorts {
          let rejected = try await call(
            httpSession, endpoint, name: "planner_query",
            query: ["kind": "catalog", "sourceKind": kind, "sort": invalid.value], isError: true)
          let reason = try #require(rejected["reason"] as? [String: Any])
          #expect(reason["code"] as? String == invalid.code)
          #expect(reason["propertyPath"] as? String == invalid.path)
        }
      }
      for kind in ["category", "tag", "schedule"] {
        let query: [String: Any] = ["kind": "catalog", "sourceKind": kind, "archive": "all"]
        let omitted = try await call(httpSession, endpoint, name: "planner_query", query: query)
        #expect(try identifiers(omitted["rows"]) == [])
        #expect(omitted["matchingCount"] as? String == "0")
        for sort: Any in [
          ["mode": "title", "direction": "ascending"], NSNull(), [String: String](),
          ["mode": "manual", "direction": "ascending"],
        ] {
          var invalid = query
          invalid["sort"] = sort
          let rejected = try await call(
            httpSession, endpoint, name: "planner_query", query: invalid, isError: true)
          let reason = try #require(rejected["reason"] as? [String: Any])
          #expect(reason["code"] as? String == "invalidInput")
          #expect(reason["propertyPath"] as? String == "/query/sort")
        }
        let generation = try #require(omitted["generation"] as? String)
        let retained = try await call(
          httpSession, endpoint, name: "planner_read",
          query: ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"])
        #expect((retained["rows"] as? [Any])?.isEmpty == true)
      }
      let itemCatalog = try await call(
        httpSession, endpoint, name: "planner_query",
        query: ["kind": "catalog", "sourceKind": "item", "sort": NSNull()], isError: true)
      let itemReason = try #require(itemCatalog["reason"] as? [String: Any])
      #expect(itemReason["propertyPath"] as? String == "/query/sourceKind")
      #expect(itemReason["code"] as? String == "invalidInput")
      let generation = try #require(original["generation"] as? String)
      let retained = try await call(
        httpSession, endpoint, name: "planner_read",
        query: ["kind": "rows", "generation": generation, "offset": "0", "limit": "2"])
      let retainedRows = try #require(retained["rows"] as? [[String: Any]])
      #expect(
        try identifiers(retainedRows.map { $0["identity"] as Any })
          == sources.reversed().map { $0.id.uuidString })
      guard case .exported(let after) = await planner.exportData(session: datasetSession) else {
        throw CancellationError()
      }
      #expect(after == before)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func fixtureDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerContainerCatalogHTTPTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    print("Container catalog HTTP fixture: \(directory.path)")
    return directory
  }

  private func configuration(_ directory: URL) -> PlannerStorageConfiguration {
    .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  private func call(
    _ session: URLSession, _ endpoint: URL, name: String, query: [String: Any],
    isError: Bool = false
  ) async throws -> [String: Any] {
    let key = name == "planner_read" ? "request" : "query"
    let envelope = try response(
      try await session.data(
        for: request(
          endpoint, method: "tools/call",
          parameters: ["name": name, "arguments": ["formatVersion": 1, key: query]])))
    #expect(envelope["isError"] as? Bool == isError)
    let structured = try #require(envelope["structuredContent"] as? [String: Any])
    if envelope["isError"] as? Bool == false {
      let encoded = try #require(
        (envelope["content"] as? [[String: Any]])?.first?["text"] as? String)
      let decoded = try #require(
        JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any])
      #expect(NSDictionary(dictionary: decoded).isEqual(to: structured))
    }
    return structured
  }

  private func identifiers(_ value: Any?) throws -> [String] {
    let rows = try #require(value as? [[String: Any]])
    return try rows.map { row in
      try #require((row["source"] as? [String: Any])?["id"] as? String)
    }
  }

  private func request(_ endpoint: URL, method: String, parameters: [String: Any]) throws
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

  private func response(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    return try #require(envelope["result"] as? [String: Any])
  }
}
