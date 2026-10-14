import Foundation
import PlannerCore
import Testing

@testable import Planner

struct CalendarWindowRoutingTests {
  @Test func calendarQueryAndTypedPagesExposeLiveOwnersAndSavedFormsOverHttp() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    let item = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let forms: [PlannerScheduleForm] = [
      .timed(
        start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
        planningTimeZone: "Asia/Tokyo"),
      .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)),
    ]
    let owners = [item, itinerary]
    var schedules: [PlannerEntityReference] = []
    for (owner, form) in zip(owners, forms) {
      schedules.append(
        try #require(try await save(.createSchedule(source: owner, form: form)).generated.first))
    }
    _ = try await save(.setArchive(source: itinerary, archived: true))
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func call(_ name: String, _ arguments: [String: Any]) async throws -> [String: Any] {
        let response = try await httpSession.data(
          for: request(
            endpoint: endpoint, method: "tools/call",
            parameters: ["name": name, "arguments": arguments]))
        let result = try result(response)
        #expect(result["isError"] as? Bool == false)
        let structured = try #require(result["structuredContent"] as? [String: Any])
        let text = try #require((result["content"] as? [[String: Any]])?.first?["text"] as? String)
        let encoded = try #require(
          JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect(NSDictionary(dictionary: encoded).isEqual(to: structured))
        return structured
      }
      let queried = try await call(
        "planner_query",
        [
          "formatVersion": 1,
          "query": [
            "kind": "calendar", "startDay": ["year": 2026, "month": 10, "day": 9],
            "endDay": ["year": 2026, "month": 10, "day": 11], "displayTimeZone": "Asia/Tokyo",
          ],
        ])
      #expect(queried["matchingCount"] as? String == "2")
      let generation = try #require(queried["generation"] as? String)
      let expected = schedules.map { $0.id.uuidString }.sorted()
      let identities = try #require(queried["rows"] as? [[String: Any]])
      #expect(
        identities.compactMap { ($0["source"] as? [String: Any])?["id"] as? String } == expected)
      let wireForms: [[String: Any]] = [
        ["kind": "timed", "start": 813_200_400, "end": NSNull(), "planningTimeZone": "Asia/Tokyo"],
        [
          "kind": "allDay", "start": ["year": 2026, "month": 10, "day": 9],
          "end": ["year": 2026, "month": 10, "day": 11],
        ],
      ]
      for offset in 0..<2 {
        let page = try await call(
          "planner_read",
          [
            "formatVersion": 1,
            "request": [
              "kind": "calendarRows", "generation": generation, "offset": String(offset),
              "limit": "1",
            ],
          ])
        #expect(
          page["kind"] as? String == "calendarRows" && page["matchingCount"] as? String == "2")
        #expect(
          page["generation"] as? String == generation && page["offset"] as? String == String(offset)
        )
        let rows = try #require(page["rows"] as? [[String: Any]])
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        let index = try #require(schedules.firstIndex { $0.id.uuidString == expected[offset] })
        #expect(
          row["schedule"] as? [String: String] == [
            "kind": "schedule", "id": schedules[index].id.uuidString,
          ])
        #expect(
          row["source"] as? [String: String] == [
            "kind": owners[index].kind.rawValue, "id": owners[index].id.uuidString,
          ])
        #expect(row["title"] as? String == ["Museum", "Weekend"][index])
        #expect(
          NSDictionary(dictionary: try #require(row["form"] as? [String: Any])).isEqual(
            to: wireForms[index]))
        #expect(Set(row.keys) == ["schedule", "source", "title", "form"])
      }
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func advertisedCalendarGrammarRejectsInvalidRequestsAndPreservesItsIssuedPage() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func call(_ name: String, _ arguments: [String: Any], isError: Bool = false) async throws
        -> [String: Any]
      {
        let result = try result(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, method: "tools/call",
              parameters: ["name": name, "arguments": arguments])))
        #expect(result["isError"] as? Bool == isError)
        return try #require(result["structuredContent"] as? [String: Any])
      }
      let advertisement = try result(
        try await httpSession.data(
          for: request(endpoint: endpoint, method: "tools/list", parameters: [:])))
      let tools = try #require(advertisement["tools"] as? [[String: Any]])
      let queryTool = try #require(tools.first { $0["name"] as? String == "planner_query" })
      let queryProperties = try #require(
        (queryTool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (queryProperties["query"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let calendar = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "calendar"
        })
      #expect(calendar["additionalProperties"] as? Bool == false)
      #expect(
        Set(try #require(calendar["required"] as? [String])) == [
          "kind", "startDay", "endDay", "displayTimeZone",
        ])
      let readTool = try #require(tools.first { $0["name"] as? String == "planner_read" })
      let readProperties = try #require(
        (readTool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let readVariants = try #require(
        (readProperties["request"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      #expect(
        readVariants.contains {
          ((($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["enum"] as? [String])?
            .contains("calendarRows") == true
        })
      let query: [String: Any] = [
        "kind": "calendar", "startDay": ["year": 2026, "month": 10, "day": 9],
        "endDay": ["year": 2026, "month": 10, "day": 11], "displayTimeZone": "Asia/Tokyo",
      ]
      let issued = try await call("planner_query", ["formatVersion": 1, "query": query])
      let generation = try #require(issued["generation"] as? String)
      for (fields, code, path) in [
        (
          ["displayTimeZone": "Invalid/Zone"] as [String: Any], "invalidInput",
          "/query/displayTimeZone"
        ),
        (["endDay": ["year": 2026, "month": 10, "day": 8]], "invalidInput", "/query/endDay"),
        (
          ["startDay": ["year": "2026", "month": 10, "day": 9]], "invalidInput",
          "/query/startDay/year"
        ),
        (["startDay": ["year": 2026, "month": 2, "day": 30]], "invalidInput", "/query/startDay"),
        (["archive": "all"], "unknownField", "/query/archive"),
      ] {
        let failed = try await call(
          "planner_query",
          ["formatVersion": 1, "query": query.merging(fields) { _, incoming in incoming }],
          isError: true)
        let reason = try #require(failed["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code && reason["propertyPath"] as? String == path)
      }
      let page: [String: Any] = [
        "kind": "calendarRows", "generation": generation, "offset": "0", "limit": "1",
      ]
      for (fields, path) in [
        (["generation": "invalid"], "/request/generation"), (["offset": "-1"], "/request/offset"),
        (["limit": "0"], "/request/limit"),
      ] {
        let failed = try await call(
          "planner_read",
          ["formatVersion": 1, "request": page.merging(fields) { _, incoming in incoming }],
          isError: true)
        let reason = try #require(failed["reason"] as? [String: Any])
        #expect(
          reason["code"] as? String == "invalidInput" && reason["propertyPath"] as? String == path)
      }
      let retained = try await call("planner_read", ["formatVersion": 1, "request": page])
      #expect(
        retained["matchingCount"] as? String == "0" && (retained["rows"] as? [Any])?.isEmpty == true
      )
      guard case .exported(let after) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      let beforeObject = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
      let afterObject = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
      #expect(NSDictionary(dictionary: beforeObject).isEqual(to: afterObject))
      guard
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: "Museum")))
        ).outcome
      else { throw CancellationError() }
      let stale = try await call(
        "planner_read", ["formatVersion": 1, "request": page], isError: true)
      #expect((stale["reason"] as? [String: Any])?["code"] as? String == "staleSnapshot")
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
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    return try #require(envelope["result"] as? [String: Any])
  }
}
