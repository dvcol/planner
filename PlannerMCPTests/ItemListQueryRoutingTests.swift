import Foundation
import PlannerCore
import Testing

@testable import Planner

@MainActor
struct ItemListQueryRoutingTests {
  @Test func listGroupsOverHTTPNarrowLiveMembershipsAndPreserveContextualProgress() async throws {
    let fixture = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real graph before querying live List groups over HTTP.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else {
        Issue.record("Save the HTTP fixture through public durable Core commands.")
        throw CancellationError()
      }
      return source
    }
    let food = try await create(.createCategory(content: .init(name: "Food")))
    let rain = try await create(.createTag(content: .init(name: "Rain")))
    let firstList = try await create(.createList(content: .init(name: "Stops")))
    let secondList = try await create(.createList(content: .init(name: "Stops")))
    let inputs = [
      PlannerItemContentInput(
        title: "Hotel", estimate: .init(minutes: 120, displayUnit: .hour), categoryIds: [food.id],
        tagIds: [rain.id]),
      PlannerItemContentInput(
        title: "Museum", estimate: .init(minutes: 120, displayUnit: .hour), tagIds: [rain.id]),
      PlannerItemContentInput(title: "Park", categoryIds: [food.id]),
      PlannerItemContentInput(title: "Inbox", categoryIds: [food.id], tagIds: [rain.id]),
    ]
    var sources: [PlannerEntityReference] = []
    for input in inputs { sources.append(try await create(.createItem(content: input))) }
    var firstListMemberships: [UUID] = []
    for (list, indices) in [(firstList, [0, 1]), (secondList, [0, 2])] {
      for index in indices {
        guard
          case .applied(let addition, .complete) = await planner.execute(
            PlannerOperation(
              operationId: UUID(), session: session,
              command: .addMembership(itemId: sources[index].id, listId: list.id, placement: .last))
          ).outcome,
          case .membership(let identifier, _, _)? = addition.generatedReferences.first
        else {
          Issue.record("Retain overlapping sources as distinct live List memberships.")
          return
        }
        if list.id == firstList.id { firstListMemberships.append(identifier) }
      }
    }
    for command: PlannerCommand in [
      .setCompletion(
        scope: .appearance(
          .listMembership(listId: firstList.id, membershipId: firstListMemberships[0])), done: true),
      .setArchive(source: firstList, archived: true),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Archive the container while preserving references and local Done.")
        return
      }
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func query(_ fields: [String: Any]) async throws -> [String: Any] {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_query",
              arguments: ["formatVersion": 1, "query": fields])))
      }
      let global: [String: Any] = ["kind": "items", "scope": ["kind": "global"]]
      let firstGroup: [String: Any] = [
        "ids": [firstList.id.uuidString.lowercased(), firstList.id.uuidString]
      ]
      let secondGroup: [String: Any] = ["ids": [secondList.id.uuidString]]
      let anyGroup: [String: Any] = [
        "ids": [firstList.id.uuidString, secondList.id.uuidString], "match": "any",
      ]
      let allGroup: [String: Any] = [
        "ids": [secondList.id.uuidString, firstList.id.uuidString], "match": "all",
      ]
      let examples: [([String: Any], [Int])] = [
        (["lists": firstGroup], [0, 1]),
        (["lists": secondGroup], [0, 2]),
        (["lists": anyGroup], [0, 1, 2]),
        (["lists": allGroup], [0]),
        (["lists": NSNull()], [0, 3, 1, 2]),
        (["lists": ["ids": [] as [String]]], [0, 3, 1, 2]),
        (["lists": ["ids": [] as [String], "match": "all"]], [0, 3, 1, 2]),
        (["scope": ["kind": "inbox"], "lists": anyGroup], []),
        (["scope": ["kind": "inbox"], "lists": ["ids": [] as [String]]], [3]),
        (
          [
            "text": "HOTEL", "categories": ["ids": [food.id.uuidString]],
            "tags": ["ids": [rain.id.uuidString]], "lists": anyGroup,
            "duration": [
              "minimumMinutes": "120", "maximumMinutes": "120", "includeUnknown": false,
            ],
          ], [0]
        ),
      ]
      for (overrides, expectedIndices) in examples {
        let snapshot = try await query(global.merging(overrides) { _, incoming in incoming })
        #expect(snapshot["matchingCount"] as? String == String(expectedIndices.count))
        let rows = try #require(snapshot["rows"] as? [[String: Any]])
        #expect(
          rows.compactMap { ($0["source"] as? [String: String])?["id"] }
            == expectedIndices.map { sources[$0].id.uuidString })
        #expect(rows.allSatisfy { $0["kind"] as? String == "source" })
      }
      let listQuery: [String: Any] = [
        "kind": "items", "scope": ["kind": "list", "listId": firstList.id.uuidString],
        "lists": secondGroup, "sort": ["mode": "manual", "direction": "ascending"],
      ]
      let ordinary = try await query(listQuery)
      #expect(ordinary["matchingCount"] as? String == "0")
      #expect((ordinary["rows"] as? [[String: Any]])?.isEmpty == true)
      let all = try await query(
        listQuery.merging(["completion": "all"]) { _, incoming in incoming })
      #expect(all["matchingCount"] as? String == "1")
      let rows = try #require(all["rows"] as? [[String: Any]])
      #expect(
        rows.first?["source"] as? [String: String] == [
          "kind": "item", "id": sources[0].id.uuidString,
        ])
      #expect(
        rows.first?["appearance"] as? [String: String] == [
          "kind": "listMembership", "listId": firstList.id.uuidString,
          "membershipId": firstListMemberships[0].uuidString,
        ])
      let done = try await query(
        listQuery.merging(["completion": "done", "lists": allGroup]) { _, incoming in incoming })
      #expect(done["matchingCount"] as? String == "1")
      let doneRows = try #require(done["rows"] as? [[String: Any]])
      #expect(NSArray(array: doneRows).isEqual(to: rows))
      for snapshot in [ordinary, all, done] {
        let progress = try #require((snapshot["progress"] as? [[String: Any]])?.first)
        #expect(progress["doneCount"] as? String == "1")
        #expect(progress["totalCount"] as? String == "2")
      }
      let generation = try #require(all["generation"] as? String)
      let window = try toolValue(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
            ])))
      let hydratedRows = try #require(window["rows"] as? [[String: Any]])
      #expect(hydratedRows.first?["title"] as? String == "Hotel")
      #expect(hydratedRows.first?["localDone"] as? Bool == true)
      #expect(hydratedRows.first?["globalDone"] as? Bool == false)
      #expect(hydratedRows.first?["effectiveDone"] as? Bool == true)
      let hydratedIdentity = try #require(hydratedRows.first?["identity"] as? [String: Any])
      let queriedIdentity = try #require(rows.first)
      #expect(NSDictionary(dictionary: hydratedIdentity).isEqual(to: queriedIdentity))
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("HTTP read filters leave independent recovery unchanged.")
        await listener.stop()
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 14)
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

  private func toolValue(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    try #require(tool["isError"] as? Bool == false)
    let value = try #require(tool["structuredContent"] as? [String: Any])
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let decodedText = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: decodedText).isEqual(to: value))
    return value
  }
}
