import Foundation
import PlannerCore
import Testing

@testable import Planner

struct BulkCompletionRoutingTests {
  @Test func statelessHTTPReviewsAndAppliesExactLocalScopesWithoutChangingGlobalFlags()
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
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
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
    var membershipIds: [UUID] = []
    for item in [hotel, museum] {
      guard
        case .membership(let identifier, _, _)? = try await save(
          .addMembership(itemId: item.id, listId: list.id, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      membershipIds.append(identifier)
    }
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: hotel, placement: .last))
    guard
      case .itineraryEntry(let listEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(.setArchive(source: museum, archived: true))
    func recovery() async throws -> Data {
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
        case .selected(let selection) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      return selection.portableData
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let listing = try result(
        try await httpSession.data(
          for: request(endpoint: endpoint, method: "tools/list", parameters: [:])))
      let tools = try #require(listing["tools"] as? [[String: Any]])
      let prepareTool = try #require(
        tools.first { $0["name"] as? String == "planner_prepare_review" })
      let prepareSchema = try #require(prepareTool["inputSchema"] as? [String: Any])
      #expect(prepareSchema["additionalProperties"] as? Bool == false)
      #expect(
        Set(try #require(prepareSchema["required"] as? [String])) == ["formatVersion", "command"])
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
          #expect(NSDictionary(dictionary: structured).isEqual(to: encoded))
        }
        return structured
      }
      func command(_ scope: [String: Any], done: Bool) -> [String: Any] {
        ["type": "setBulkCompletion", "scope": scope, "done": done]
      }
      func review(_ command: [String: Any], count: String) async throws -> String {
        let before = try await recovery()
        let reviewed = try await call(
          "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
        #expect(reviewed["formatVersion"] as? Int == 1)
        #expect(UUID(uuidString: try #require(reviewed["reviewId"] as? String)) != nil)
        let targets = try #require(reviewed["targets"] as? [[String: Any]])
        let impact = try #require(reviewed["impact"] as? [String: Any])
        #expect(
          impact["kind"] as? String == "bulkCompletion" && impact["targetCount"] as? String == count
        )
        #expect(impact["globalFlagsChanged"] as? Bool == false)
        #expect((impact["sourceDeletes"] as? [Any])?.isEmpty == true)
        #expect(
          (impact["referenceRemovals"] as? [Any])?.isEmpty == true
            && impact["importDetails"] is NSNull)
        #expect(
          targets.count == Int(count)
            && targets.allSatisfy { $0["kind"] as? String == "appearance" })
        let normalized = try #require(reviewed["command"] as? [String: Any])
        #expect(NSDictionary(dictionary: command).isEqual(to: normalized))
        #expect(try await recovery() == before)
        return try #require(reviewed["reviewToken"] as? String)
      }
      func apply(_ command: [String: Any], token: String, operationId: UUID = UUID()) async throws
        -> [String: Any]
      {
        let applied = try await call(
          "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": operationId.uuidString, "command": command,
            "reviewToken": token,
          ])
        #expect(applied["state"] as? String == "applied")
        #expect((applied["recovery"] as? [String: Any])?["state"] as? String == "complete")
        return applied
      }
      func progress(_ scope: [String: Any], done: String, total: String) async throws {
        let queried = try await call(
          "planner_query",
          arguments: [
            "formatVersion": 1,
            "query": ["kind": "items", "scope": scope, "completion": "all", "archive": "all"],
          ])
        let progress = try #require((queried["progress"] as? [[String: Any]])?.first)
        #expect(
          progress["doneCount"] as? String == done && progress["totalCount"] as? String == total)
      }
      let listScope: [String: Any] = ["kind": "list", "listId": list.id.uuidString]
      let itineraryScope: [String: Any] = [
        "kind": "itinerary", "itineraryId": itinerary.id.uuidString,
      ]
      let listDone = command(listScope, done: true)
      let listToken = try await review(listDone, count: "2")
      let operationId = UUID()
      let rejected = try await call(
        "planner_execute",
        arguments: [
          "formatVersion": 1,
          "operationId": operationId.uuidString, "command": listDone,
        ], isError: true)
      #expect(rejected["state"] as? String == "rejected")
      #expect((rejected["reason"] as? [String: Any])?["code"] as? String == "staleReview")
      let applied = try await apply(listDone, token: listToken, operationId: operationId)
      try await progress(listScope, done: "2", total: "2")
      try await progress(itineraryScope, done: "0", total: "3")
      _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: true))
      let listUndone = command(listScope, done: false)
      _ = try await apply(listUndone, token: try await review(listUndone, count: "2"))
      try await progress(listScope, done: "1", total: "2")
      _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: false))
      try await progress(listScope, done: "0", total: "2")
      let itineraryDone = command(itineraryScope, done: true)
      _ = try await apply(itineraryDone, token: try await review(itineraryDone, count: "3"))
      try await progress(itineraryScope, done: "3", total: "3")
      try await progress(listScope, done: "0", total: "2")
      let entryUndone = command(
        [
          "kind": "itineraryListEntry", "itineraryId": itinerary.id.uuidString,
          "listEntryId": listEntryId.uuidString,
        ], done: false)
      _ = try await apply(entryUndone, token: try await review(entryUndone, count: "2"))
      try await progress(itineraryScope, done: "1", total: "3")
      let replay = try await call(
        "planner_execute",
        arguments: [
          "formatVersion": 1,
          "operationId": operationId.uuidString, "command": listDone,
        ])
      #expect(NSDictionary(dictionary: replay).isEqual(to: applied))
      try await progress(listScope, done: "0", total: "2")
      for (item, membershipId) in zip([hotel, museum], membershipIds) {
        guard
          case .source(.item(let source)) = await planner.read(
            session: session, request: .source(item)),
          case .appearance(let local) = await planner.read(
            session: session,
            request: .appearance(.listMembership(listId: list.id, membershipId: membershipId)))
        else { throw CancellationError() }
        #expect(source.state.globalDone == false && local.localDone == false)
        #expect(source.state.archived == (item == museum))
      }
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
    #expect(
      response.statusCode == 200 && response.value(forHTTPHeaderField: "Mcp-Session-Id") == nil)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    return try #require(envelope["result"] as? [String: Any])
  }
}
