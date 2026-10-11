import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemSchedulingQueryRoutingTests {
  @Test func scheduledQueriesAdvertiseStrictAdmissionAndReturnSharedContextualResultsOverHttp()
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
    let guide = try #require(
      try await save(.createItem(content: .init(title: "Guide"))).generated.first)
    let hotel = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Hotel",
            location: .init(displayName: nil, formattedAddress: "Tokyo", coordinate: nil)))
      ).generated.first)
    let plain = try #require(
      try await save(.createItem(content: .init(title: "Plain"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Review"))).generated.first)
    let liveList = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Past trip"))).generated.first)
    for item in [guide, hotel, plain] {
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    _ = try await save(.addMembership(itemId: hotel.id, listId: liveList.id, placement: .last))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: liveList, placement: .last))
    let past = PlannerScheduleForm.allDay(start: .init(year: 2020, month: 1, day: 1), end: nil)
    _ = try await save(.createSchedule(source: guide, form: past))
    _ = try await save(.createSchedule(source: itinerary, form: past))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: guide.id), done: true))
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let base: [String: Any] = [
        "kind": "items", "scope": ["kind": "global"], "completion": "all", "archive": "all",
      ]
      func query(_ fields: [String: Any], isError: Bool = false) async throws -> [String: Any] {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_query",
              arguments: ["formatVersion": 1, "query": fields])),
          isError: isError)
      }
      func read(_ generation: String) async throws -> [String: Any] {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1,
                "request": [
                  "kind": "rows", "generation": generation, "offset": "0", "limit": "10",
                ],
              ])), isError: false)
      }
      let examples: [([String: Any], [String])] = [
        (["scheduled": "scheduled"], ["Guide", "Hotel"]),
        (["scheduled": "unscheduled"], ["Plain"]),
        ([:], ["Guide", "Hotel", "Plain"]),
        (["scheduled": "all"], ["Guide", "Hotel", "Plain"]),
        (["scheduled": "scheduled", "hasAddress": true, "text": "hotel"], ["Hotel"]),
        (["scheduled": "scheduled", "completion": "todo"], ["Hotel"]),
        (
          ["scope": ["kind": "list", "listId": list.id.uuidString], "scheduled": "unscheduled"],
          ["Plain"]
        ),
        (
          [
            "scope": ["kind": "itinerary", "itineraryId": itinerary.id.uuidString],
            "scheduled": "scheduled",
          ], ["Hotel"]
        ),
      ]
      for (criteria, expected) in examples {
        let result = try await query(base.merging(criteria) { _, incoming in incoming })
        #expect(result["matchingCount"] as? String == String(expected.count))
        let generation = try #require(result["generation"] as? String)
        let rows = try #require(try await read(generation)["rows"] as? [[String: Any]])
        #expect(rows.compactMap { $0["title"] as? String } == expected)
        if criteria["scope"] != nil, expected == ["Plain"] {
          let progress = try #require(result["progress"] as? [[String: Any]])
          #expect(progress.first?["doneCount"] as? String == "1")
          #expect(progress.first?["totalCount"] as? String == "3")
        }
      }
      let valid = try await query(base)
      let generation = try #require(valid["generation"] as? String)
      let originalWindow = try await read(generation)
      var advertisementRequest = try request(
        endpoint: endpoint, name: "planner_query", arguments: [:])
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
      let schema = try #require(
        (itemVariant["properties"] as? [String: Any])?["scheduled"] as? [String: Any])
      #expect(schema["type"] as? String == "string")
      #expect(schema["default"] as? String == "all")
      #expect(schema["enum"] as? [String] == ["scheduled", "unscheduled", "all"])
      for invalid: Any in [
        NSNull(), "past", "", true, 0, 1.5, [] as [String], [:] as [String: Any],
      ] {
        let rejected = try await query(
          base.merging(["scheduled": invalid]) { _, incoming in incoming }, isError: true)
        #expect(rejected["state"] as? String == "failed")
        #expect(rejected["generation"] == nil)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == "invalidInput")
        #expect(reason["propertyPath"] as? String == "/query/scheduled")
      }
      #expect(NSDictionary(dictionary: try await read(generation)).isEqual(to: originalWindow))
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
