import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ScheduleCatalogRoutingTests {
  @Test func advertisedScheduleCatalogReadsEachBoundAssignmentAndRejectsRestrictionsOverHttp()
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
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Hotel"))).generated.first)
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
    _ = try await save(.setArchive(source: item, archived: true))
    _ = try await save(.setArchive(source: itinerary, archived: true))
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
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let advertisement = try result(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, method: "tools/list", parameters: [:])))
      let tools = try #require(advertisement["tools"] as? [[String: Any]])
      let tool = try #require(tools.first { $0["name"] as? String == "planner_query" })
      let properties = try #require(
        (tool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (properties["query"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let variant = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["sourceKind"] as? [String: Any])?["const"]
            as? String == "schedule"
        })
      #expect(variant["additionalProperties"] as? Bool == false)
      #expect(
        Set(try #require(variant["required"] as? [String])) == ["kind", "sourceKind", "archive"])
      let scheduleProperties = try #require(variant["properties"] as? [String: Any])
      #expect((scheduleProperties["text"] as? [String: Any])?["const"] as? String == "")
      #expect((scheduleProperties["archive"] as? [String: Any])?["const"] as? String == "all")
      func call(_ name: String, _ arguments: [String: Any], isError: Bool = false) async throws
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
          let content = try #require(
            (response["content"] as? [[String: Any]])?.first?["text"] as? String)
          let encoded = try #require(
            JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any])
          #expect(NSDictionary(dictionary: encoded).isEqual(to: structured))
        }
        return structured
      }
      let catalog: [String: Any] = ["kind": "catalog", "sourceKind": "schedule", "archive": "all"]
      let queried = try await call("planner_query", ["formatVersion": 1, "query": catalog])
      #expect(queried["matchingCount"] as? String == "2" && queried["rowPresentation"] is NSNull)
      #expect((queried["progress"] as? [Any])?.isEmpty == true)
      #expect((queried["unresolvedReferences"] as? [Any])?.isEmpty == true)
      let identities = try #require(queried["rows"] as? [[String: Any]])
      let expected = schedules.map { $0.id.uuidString }.sorted()
      #expect(
        identities.compactMap { ($0["source"] as? [String: Any])?["id"] as? String } == expected)
      #expect(
        identities.allSatisfy { ($0["source"] as? [String: Any])?["kind"] as? String == "schedule" }
      )
      let generation = try #require(queried["generation"] as? String)
      func window(_ offset: String, isError: Bool = false) async throws -> [String: Any] {
        try await call(
          "planner_read",
          [
            "formatVersion": 1,
            "request": [
              "kind": "rows", "generation": generation, "offset": offset, "limit": "1",
            ],
          ], isError: isError)
      }
      let originalWindow = try await window("0")
      for offset in 0..<2 {
        let read = try await window(String(offset))
        let rows = try #require(read["rows"] as? [[String: Any]])
        #expect(rows.count == 1 && read["matchingCount"] as? String == "2")
        let row = try #require(rows.first)
        #expect(row["title"] as? String == "Hotel")
        #expect(
          ((row["identity"] as? [String: Any])?["source"] as? [String: Any])?["id"] as? String
            == expected[offset])
        #expect(
          row["globalDone"] is NSNull && row["localDone"] is NSNull
            && row["effectiveDone"] is NSNull && row["archived"] is NSNull)
        #expect(row["hasLocation"] as? Bool == false && row["hasLinks"] as? Bool == false)
        #expect((row["labels"] as? [Any])?.isEmpty == true)
        #expect((row["scheduleSummary"] as? [String: Any])?["kind"] as? String == "none")
      }
      let wireForms: [[String: Any]] = [
        ["kind": "timed", "start": 813_200_400, "end": NSNull(), "planningTimeZone": "Asia/Tokyo"],
        [
          "kind": "allDay", "start": ["year": 2026, "month": 10, "day": 9],
          "end": ["year": 2026, "month": 10, "day": 11],
        ],
      ]
      for (index, schedule) in schedules.enumerated() {
        let read = try await call(
          "planner_read",
          [
            "formatVersion": 1,
            "request": [
              "kind": "source", "source": ["kind": "schedule", "id": schedule.id.uuidString],
            ],
          ])
        let value = try #require(read["value"] as? [String: Any])
        let content = try #require(value["content"] as? [String: Any])
        #expect(
          NSDictionary(dictionary: try #require(content["source"] as? [String: Any])).isEqual(to: [
            "kind": owners[index].kind.rawValue, "id": owners[index].id.uuidString,
          ]))
        #expect(
          NSDictionary(dictionary: try #require(content["form"] as? [String: Any])).isEqual(
            to: wireForms[index]))
        #expect(Set(try #require(value["fieldHashes"] as? [String: Any]).keys) == ["form"])
      }
      let invalid: [([String: Any], String, String)] = [
        (["archive": "active"], "invalidInput", "/query/archive"),
        (["archive": "archived"], "invalidInput", "/query/archive"),
        (["archive": NSNull()], "invalidInput", "/query/archive"),
        (["text": "Hotel"], "invalidInput", "/query/text"),
        (["text": " "], "invalidInput", "/query/text"),
        (["text": NSNull()], "invalidInput", "/query/text"),
        (["text": true], "invalidInput", "/query/text"),
        (["completion": "all"], "unknownField", "/query/completion"),
        (["rowPresentation": NSNull()], "unknownField", "/query/rowPresentation"),
      ]
      for (fields, code, path) in invalid {
        let rejected = try await call(
          "planner_query",
          ["formatVersion": 1, "query": catalog.merging(fields) { _, incoming in incoming }],
          isError: true)
        #expect(rejected["generation"] == nil)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code && reason["propertyPath"] as? String == path)
      }
      let omittedArchive = try await call(
        "planner_query",
        ["formatVersion": 1, "query": ["kind": "catalog", "sourceKind": "schedule"]], isError: true)
      #expect(
        (omittedArchive["reason"] as? [String: Any])?["propertyPath"] as? String == "/query/archive"
      )
      #expect(NSDictionary(dictionary: try await window("0")).isEqual(to: originalWindow))
      guard
        case .listedNamespaces(let retainedNamespaces) = await planner.inspectRecovery(
          request: .namespaces),
        case .selected(let retainedRecovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      #expect(retainedRecovery.portableData == originalRecovery.portableData)
      #expect(retainedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
      let removed = try await call(
        "planner_execute",
        [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": ["type": "removeSchedule", "scheduleId": schedules[0].id.uuidString],
        ])
      #expect(removed["state"] as? String == "applied")
      let stale = try await window("0", isError: true)
      #expect((stale["reason"] as? [String: Any])?["code"] as? String == "staleSnapshot")
      let refreshed = try await call("planner_query", ["formatVersion": 1, "query": catalog])
      #expect(refreshed["matchingCount"] as? String == "1")
      #expect(
        (((refreshed["rows"] as? [[String: Any]])?.first?["source"]) as? [String: Any])?["id"]
          as? String == schedules[1].id.uuidString)
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
