import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemLabelQueryRoutingTests {
  @Test func labelGroupsOverHTTPNarrowCumulativelyAndPreserveListAppearances() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real store before querying label groups over HTTP.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else {
        Issue.record("Save the complete query fixture through public Core commands.")
        throw CancellationError()
      }
      return source
    }
    let food = try await create(.createCategory(content: .init(name: "Food")))
    let culture = try await create(.createCategory(content: .init(name: "Food")))
    let rain = try await create(.createTag(content: .init(name: "Rain")))
    let travel = try await create(.createTag(content: .init(name: "Travel")))
    let list = try await create(.createList(content: .init(name: "Stops")))
    let inputs = [
      PlannerItemContentInput(
        title: "Alpha cafe", estimate: .init(minutes: 60, displayUnit: .hour),
        categoryIds: [food.id], tagIds: [rain.id]),
      PlannerItemContentInput(
        title: "Beta cafe", estimate: .init(minutes: 120, displayUnit: .hour),
        categoryIds: [food.id, culture.id], tagIds: [rain.id, travel.id]),
      PlannerItemContentInput(
        title: "Gamma cafe", estimate: .init(minutes: 180, displayUnit: .hour),
        categoryIds: [culture.id], tagIds: [travel.id]),
      PlannerItemContentInput(title: "Delta"),
      PlannerItemContentInput(
        title: "Epsilon cafe", estimate: .init(minutes: 90, displayUnit: .minute),
        categoryIds: [food.id], tagIds: [rain.id]),
    ]
    var sources: [PlannerEntityReference] = []
    var membershipIdentifiers: [UUID] = []
    for (index, input) in inputs.enumerated() {
      let item = try await create(.createItem(content: input))
      sources.append(item)
      if index > 2 { continue }
      guard
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("The List query must retain exact live membership identities.")
        return
      }
      membershipIdentifiers.append(membershipIdentifier)
    }
    for command: PlannerCommand in [
      .setCompletion(
        scope: .appearance(
          .listMembership(listId: list.id, membershipId: membershipIdentifiers[1])), done: true),
      .setArchive(source: sources[2], archived: true),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Save independent local completion and archive before HTTP filtering.")
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
      let global: [String: Any] = [
        "kind": "items", "scope": ["kind": "global"], "completion": "all", "archive": "all",
      ]
      let foodGroup: [String: Any] = ["ids": [food.id.uuidString.lowercased(), food.id.uuidString]]
      let categoryAny: [String: Any] = [
        "ids": [food.id.uuidString, culture.id.uuidString], "match": "any",
      ]
      let categoryAll: [String: Any] = [
        "ids": [culture.id.uuidString, food.id.uuidString], "match": "all",
      ]
      let rainGroup: [String: Any] = ["ids": [rain.id.uuidString]]
      let tagAll: [String: Any] = [
        "ids": [rain.id.uuidString, travel.id.uuidString], "match": "all",
      ]
      let examples: [([String: Any], [Int])] = [
        (["categories": foodGroup], [0, 1, 4]),
        (["categories": categoryAny], [0, 1, 4, 2]),
        (["categories": categoryAll], [1]),
        (["tags": rainGroup], [0, 1, 4]),
        (["tags": tagAll], [1]),
        (["categories": ["ids": [culture.id.uuidString]], "tags": rainGroup], [1]),
        (["scope": ["kind": "inbox"], "categories": foodGroup, "tags": rainGroup], [4]),
        (
          [
            "text": "CAFE", "categories": foodGroup, "tags": rainGroup,
            "duration": ["minimumMinutes": "90", "maximumMinutes": "150", "includeUnknown": false],
          ], [1, 4]
        ),
        (["categories": NSNull(), "tags": NSNull()], [0, 1, 3, 4, 2]),
        (
          [
            "categories": ["ids": [] as [String]], "tags": ["ids": [] as [String], "match": "all"],
          ], [0, 1, 3, 4, 2]
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
        "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
        "categories": categoryAny, "sort": ["mode": "manual", "direction": "ascending"],
      ]
      let ordinary = try await query(listQuery)
      #expect(ordinary["matchingCount"] as? String == "1")
      let ordinaryRows = try #require(ordinary["rows"] as? [[String: Any]])
      #expect(
        ordinaryRows.compactMap { ($0["appearance"] as? [String: String])?["membershipId"] } == [
          membershipIdentifiers[0].uuidString
        ])
      let all = try await query(
        listQuery.merging(["completion": "all", "archive": "all", "tags": tagAll]) { _, incoming in
          incoming
        })
      #expect(all["matchingCount"] as? String == "1")
      let rows = try #require(all["rows"] as? [[String: Any]])
      #expect(
        rows.first?["source"] as? [String: String] == [
          "kind": "item", "id": sources[1].id.uuidString,
        ])
      #expect(
        rows.first?["appearance"] as? [String: String] == [
          "kind": "listMembership", "listId": list.id.uuidString,
          "membershipId": membershipIdentifiers[1].uuidString,
        ])
      for snapshot in [ordinary, all] {
        let progress = try #require((snapshot["progress"] as? [[String: Any]])?.first)
        #expect(progress["doneCount"] as? String == "1")
        #expect(progress["totalCount"] as? String == "3")
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
      #expect(hydratedRows.first?["title"] as? String == "Beta cafe")
      #expect(hydratedRows.first?["localDone"] as? Bool == true)
      #expect(hydratedRows.first?["globalDone"] as? Bool == false)
      #expect(hydratedRows.first?["effectiveDone"] as? Bool == true)
      #expect(
        NSDictionary(dictionary: try #require(hydratedRows.first?["identity"] as? [String: Any]))
          .isEqual(to: try #require(rows.first)))
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Read-only HTTP queries leave independent recovery available.")
        await listener.stop()
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 15)
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
