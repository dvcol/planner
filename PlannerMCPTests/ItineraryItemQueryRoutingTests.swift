import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryItemQueryRoutingTests {
  @Test func itineraryScopeOverHTTPKeepsExactAppearancesFullProgressAndStrictAdmission()
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
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep notes"))).generated
        .first)
    let museum = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: hotel.id, listId: list.id, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let directEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: hotel, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let listEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: museum, placement: .last))
    _ = try await save(.setArchive(source: museum, archived: true))
    _ = try await save(
      .setCompletion(
        scope: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: directEntryId)),
        done: true))
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: datasetSession, request: .source(itinerary)),
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
      let queryVariants = try #require(querySchema["oneOf"] as? [[String: Any]])
      let items = try #require(
        queryVariants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "items"
        })
      let scopeSchema = try #require(
        (items["properties"] as? [String: Any])?["scope"] as? [String: Any])
      let scopeVariants = try #require(scopeSchema["oneOf"] as? [[String: Any]])
      let itineraryScope = try #require(
        scopeVariants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "itinerary"
        })
      #expect(itineraryScope["additionalProperties"] as? Bool == false)
      #expect(
        Set(try #require(itineraryScope["required"] as? [String])) == ["kind", "itineraryId"])
      #expect(
        Set(try #require(itineraryScope["properties"] as? [String: Any]).keys) == [
          "kind", "itineraryId",
        ])
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
      let scope: [String: Any] = ["kind": "itinerary", "itineraryId": itinerary.id.uuidString]
      let todo = try await call(
        "planner_query",
        arguments: ["formatVersion": 1, "query": ["kind": "items", "scope": scope]])
      #expect(todo["matchingCount"] as? String == "1")
      let identities = try #require(todo["rows"] as? [[String: Any]])
      let appearance = try #require(identities.first?["appearance"] as? [String: Any])
      #expect(appearance["kind"] as? String == "expandedListItem")
      #expect(appearance["itineraryId"] as? String == itinerary.id.uuidString)
      #expect(appearance["listEntryId"] as? String == listEntryId.uuidString)
      #expect(appearance["membershipId"] as? String == membershipId.uuidString)
      let progress = try #require((todo["progress"] as? [[String: Any]])?.first)
      #expect(progress["totalCount"] as? String == "3" && progress["doneCount"] as? String == "1")
      let generation = try #require(todo["generation"] as? String)
      let window = try await call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
        ])
      let row = try #require((window["rows"] as? [[String: Any]])?.first)
      #expect(
        row["globalDone"] as? Bool == false && row["localDone"] as? Bool == false
          && row["effectiveDone"] as? Bool == false)
      let rowIdentity = try #require(row["identity"] as? [String: Any])
      let issuedIdentity = try #require(identities.first)
      #expect(NSDictionary(dictionary: rowIdentity).isEqual(to: issuedIdentity))
      let all = try await call(
        "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": ["kind": "items", "scope": scope, "completion": "all", "archive": "all"],
        ])
      #expect(all["matchingCount"] as? String == "3")
      let allRows = try #require(all["rows"] as? [[String: Any]])
      #expect(
        allRows.filter { ($0["source"] as? [String: Any])?["id"] as? String == hotel.id.uuidString }
          .count == 2)
      let invalidScopes: [(value: [String: Any], code: String, path: String?)] = [
        (["kind": "itinerary"], "invalidInput", "/query/scope/itineraryId"),
        (["kind": "itinerary", "itineraryId": "bad"], "invalidInput", "/query/scope/itineraryId"),
        (
          ["kind": "itinerary", "itineraryId": NSNull()], "invalidInput", "/query/scope/itineraryId"
        ),
        (
          [
            "kind": "itinerary", "itineraryId": itinerary.id.uuidString,
            "listId": list.id.uuidString,
          ], "unknownField", "/query/scope/listId"
        ),
        (
          ["kind": "global", "itineraryId": itinerary.id.uuidString], "unknownField",
          "/query/scope/itineraryId"
        ),
        (["kind": "unknown"], "invalidInput", "/query/scope/kind"),
        (["kind": "itinerary", "itineraryId": hotel.id.uuidString], "missingReference", nil),
      ]
      for testCase in invalidScopes {
        let rejected = try await call(
          "planner_query",
          arguments: ["formatVersion": 1, "query": ["kind": "items", "scope": testCase.value]],
          isError: true)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == testCase.code)
        #expect(reason["propertyPath"] as? String == testCase.path)
      }
      guard
        case .source(.itinerary(let retained)) = await planner.read(
          session: datasetSession, request: .source(itinerary)),
        case .selected(let retainedRecovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
        case .listedNamespaces(let retainedNamespaces) = await planner.inspectRecovery(
          request: .namespaces)
      else { throw CancellationError() }
      #expect(retained.references == before.references && retained.updatedAt == before.updatedAt)
      #expect(retainedRecovery.portableData == originalRecovery.portableData)
      #expect(retainedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func explicitManualItineraryHTTPQueriesKeepRouteOrderAndAlphabeticalDefaults() async throws
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
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Zulu Hotel"))).generated.first)
    let museum = try #require(
      try await save(.createItem(content: .init(title: "Beta Museum"))).generated.first)
    let cafe = try #require(
      try await save(.createItem(content: .init(title: "Alpha Cafe"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    for source in [museum, cafe] {
      _ = try await save(.addMembership(itemId: source.id, listId: list.id, placement: .last))
    }
    var entryIdentifiers: [UUID] = []
    for source in [hotel, list, hotel] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entryIdentifiers.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .directItineraryItem(itineraryId: itinerary.id, entryId: entryIdentifiers[0])), done: true
      ))
    _ = try await save(.setArchive(source: cafe, archived: true))
    guard
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
      let scope: [String: Any] = ["kind": "itinerary", "itineraryId": itinerary.id.uuidString]
      let baseQuery: [String: Any] = [
        "kind": "items", "scope": scope, "completion": "all", "archive": "all",
      ]
      let alphabetical = try await call(
        "planner_query", arguments: ["formatVersion": 1, "query": baseQuery])
      var manualQuery = baseQuery
      manualQuery["sort"] = ["mode": "manual", "direction": "ascending"]
      let manual = try await call(
        "planner_query", arguments: ["formatVersion": 1, "query": manualQuery])
      let alphabeticalRows = try #require(alphabetical["rows"] as? [[String: Any]])
      let manualRows = try #require(manual["rows"] as? [[String: Any]])
      #expect(
        alphabeticalRows.map { ($0["source"] as? [String: Any])?["id"] as? String }
          == [cafe.id.uuidString, museum.id.uuidString, hotel.id.uuidString, hotel.id.uuidString])
      #expect(
        manualRows.map { ($0["source"] as? [String: Any])?["id"] as? String }
          == [hotel.id.uuidString, museum.id.uuidString, cafe.id.uuidString, hotel.id.uuidString])
      let firstAppearance = try #require(manualRows.first?["appearance"] as? [String: Any])
      let lastAppearance = try #require(manualRows.last?["appearance"] as? [String: Any])
      #expect(firstAppearance["entryId"] as? String == entryIdentifiers[0].uuidString)
      #expect(lastAppearance["entryId"] as? String == entryIdentifiers[2].uuidString)
      let generation = try #require(manual["generation"] as? String)
      let window = try await call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "1", "limit": "2"],
        ])
      let hydratedRows = try #require(window["rows"] as? [[String: Any]])
      #expect(hydratedRows.map { $0["title"] as? String } == ["Beta Museum", "Alpha Cafe"])
      #expect(hydratedRows.map { $0["archived"] as? Bool } == [false, true])
      #expect(
        hydratedRows.map { $0["identity"] as? NSDictionary }
          == [NSDictionary(dictionary: manualRows[1]), NSDictionary(dictionary: manualRows[2])])
      var filteredQuery = manualQuery
      filteredQuery["completion"] = "todo"
      filteredQuery["archive"] = "active"
      let filtered = try await call(
        "planner_query", arguments: ["formatVersion": 1, "query": filteredQuery])
      let filteredRows = try #require(filtered["rows"] as? [[String: Any]])
      #expect(
        filteredRows.map(NSDictionary.init(dictionary:)) == [
          NSDictionary(dictionary: manualRows[1]), NSDictionary(dictionary: manualRows[3]),
        ])
      for snapshot in [alphabetical, manual, filtered] {
        let progress = try #require((snapshot["progress"] as? [[String: Any]])?.first)
        #expect(progress["doneCount"] as? String == "1" && progress["totalCount"] as? String == "4")
      }
      for (invalidScope, direction) in [
        (scope, "descending"), (["kind": "global"], "ascending"), (["kind": "inbox"], "ascending"),
      ] {
        var invalidQuery = baseQuery
        invalidQuery["scope"] = invalidScope
        invalidQuery["sort"] = ["mode": "manual", "direction": direction]
        let rejected = try await call(
          "planner_query", arguments: ["formatVersion": 1, "query": invalidQuery], isError: true)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == "invalidInput")
        #expect(reason["propertyPath"] as? String == "/query/sort")
      }
      let retainedWindow = try await call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "1", "limit": "2"],
        ])
      #expect(NSDictionary(dictionary: retainedWindow).isEqual(to: window))
      guard
        case .selected(let retainedRecovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
        case .listedNamespaces(let retainedNamespaces) = await planner.inspectRecovery(
          request: .namespaces)
      else { throw CancellationError() }
      #expect(retainedRecovery.portableData == originalRecovery.portableData)
      #expect(retainedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
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
