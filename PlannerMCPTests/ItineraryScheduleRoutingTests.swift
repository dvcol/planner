import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryScheduleRoutingTests {
  @Test func rowWindowsOverHttpDistinguishDirectAppointmentsPlanSpansAndInheritedPlanning()
    async throws
  {
    let configuration = try await MainActor.run { try makePlannerIntentStorage().configuration }
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Trip"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    for source in [item, list] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    let direct = try #require(
      try await save(
        .createSchedule(
          source: item,
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
            planningTimeZone: "Asia/Tokyo"))
      )
      .generated.first)
    let plan = try #require(
      try await save(
        .createSchedule(
          source: itinerary,
          form: .allDay(
            start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))
        )
      )
      .generated.first)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    func rows(_ scope: [String: String]) async throws -> [[String: Any]] {
      let query = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1,
              "query": [
                "kind": "items", "scope": scope, "completion": "all", "archive": "all",
                "rowPresentation": [
                  "referenceInstant": 813202200.0, "displayTimeZone": "Asia/Tokyo",
                ],
              ],
            ])))
      let generation = try #require(query["generation"] as? String)
      let window = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "10"],
            ])))
      return try #require(window["rows"] as? [[String: Any]])
    }
    func remove(_ identifier: UUID) async throws {
      let result = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": ["type": "removeSchedule", "scheduleId": identifier.uuidString],
            ])))
      #expect(result["state"] as? String == "applied")
    }
    do {
      for scope in [["kind": "global"], ["kind": "list", "listId": list.id.uuidString]] {
        let window = try await rows(scope)
        #expect(window.count == 1)
        let summary = try #require(window.first?["scheduleSummary"] as? [String: Any])
        #expect(summary["kind"] as? String == "directItem")
        #expect((summary["schedule"] as? [String: Any])?["id"] as? String == direct.id.uuidString)
        #expect((summary["owner"] as? [String: Any])?["kind"] as? String == "item")
      }
      let contextual = try await rows(["kind": "itinerary", "itineraryId": itinerary.id.uuidString])
      #expect(contextual.count == 2)
      for row in contextual {
        let summary = try #require(row["scheduleSummary"] as? [String: Any])
        #expect(summary["kind"] as? String == "itinerarySpan")
        #expect(summary["additionalCount"] as? String == "0")
        #expect((summary["schedule"] as? [String: Any])?["id"] as? String == plan.id.uuidString)
        #expect((summary["owner"] as? [String: Any])?["id"] as? String == itinerary.id.uuidString)
        #expect((summary["owner"] as? [String: Any])?["kind"] as? String == "itinerary")
        let form = try #require(summary["form"] as? [String: Any])
        #expect(form["kind"] as? String == "allDay")
        #expect((form["end"] as? [String: Any])?["day"] as? Int == 11)
      }
      try await remove(direct.id)
      let inherited = try await rows(["kind": "global"])
      let inheritedSummary = try #require(inherited.first?["scheduleSummary"] as? [String: Any])
      #expect(NSDictionary(dictionary: inheritedSummary).isEqual(to: ["kind": "inScheduledPlan"]))
      try await remove(plan.id)
      let disconnected = try await rows(["kind": "global"])
      let disconnectedSummary = try #require(
        disconnected.first?["scheduleSummary"] as? [String: Any])
      #expect(NSDictionary(dictionary: disconnectedSummary).isEqual(to: ["kind": "none"]))
      #expect(disconnected.first?["globalDone"] as? Bool == false)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func itineraryScheduleUsesOwnedIdentityForHttpCreateReadEditReplayAndRemoval() async throws
  {
    let configuration = try await MainActor.run { try makePlannerIntentStorage().configuration }
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItinerary(content: .init(title: "Route", notes: "Keep")))
      ).outcome,
      let itinerary = created.generated.first
    else { throw CancellationError() }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let form: [String: Any] = [
      "kind": "allDay", "start": ["year": 2026, "month": 10, "day": 9],
      "end": ["year": 2026, "month": 10, "day": 11],
    ]
    let creation: [String: Any] = [
      "formatVersion": 1, "operationId": UUID().uuidString,
      "command": [
        "type": "createSchedule", "source": ["kind": "itinerary", "id": itinerary.id.uuidString],
        "form": form,
      ],
    ]
    do {
      let created = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      #expect(created["state"] as? String == "applied")
      let generated = try #require(
        (created["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      let identifier = try #require(generated.first?["id"] as? String)
      #expect(generated.first?["kind"] as? String == "schedule")
      let readArguments: [String: Any] = [
        "formatVersion": 1,
        "request": ["kind": "source", "source": ["kind": "schedule", "id": identifier]],
      ]
      let read = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let readValue = try #require(read["value"] as? [String: Any])
      let content = try #require(readValue["content"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(content["source"] as? [String: Any])).isEqual(
          to: ["kind": "itinerary", "id": itinerary.id.uuidString]))
      #expect(
        NSDictionary(dictionary: try #require(content["form"] as? [String: Any])).isEqual(to: form))
      let hashes = try #require(readValue["fieldHashes"] as? [String: Any])
      let replacement: [String: Any] = [
        "kind": "allDay", "start": ["year": 2026, "month": 10, "day": 9],
        "end": ["year": 2026, "month": 10, "day": 12],
      ]
      let edited = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editSchedule", "scheduleId": identifier, "changes": ["form": replacement],
                "expectedFieldHashes": hashes,
              ],
            ])))
      #expect(edited["state"] as? String == "applied")
      let replayed = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      #expect(
        NSDictionary(dictionary: try #require(replayed["result"] as? [String: Any])).isEqual(
          to: try #require(created["result"] as? [String: Any])))
      let current = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let currentContent = try #require(
        (current["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(currentContent["form"] as? [String: Any])).isEqual(
          to: replacement))
      let removal: [String: Any] = [
        "formatVersion": 1, "operationId": UUID().uuidString,
        "command": ["type": "removeSchedule", "scheduleId": identifier],
      ]
      let removed = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: removal)))
      #expect(removed["state"] as? String == "applied")
      let removedReplay = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: removal)))
      #expect(
        NSDictionary(dictionary: try #require(removedReplay["result"] as? [String: Any])).isEqual(
          to: try #require(removed["result"] as? [String: Any])))
      let checkpointSpelling = try #require(
        (removed["recovery"] as? [String: Any])?["checkpointGeneration"] as? String)
      let checkpoint = try #require(Int64(checkpointSpelling))
      guard
        case .source(.itinerary(let owner)) = await planner.read(
          session: session, request: .source(itinerary)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      #expect(owner.content.notes == "Keep")
      #expect(owner.progress.totalCount == 0)
      #expect(owner.references.isEmpty)
      #expect(recovery.decodedBackup.backup.schedules.isEmpty)
      #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
      #expect(namespace.preparedProposals.isEmpty)
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

  private func value(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == false)
    let structured = try #require(tool["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let decoded = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: decoded).isEqual(to: structured))
    return structured
  }
}
