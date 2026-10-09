import Foundation
import PlannerCore
import Testing

@testable import Planner

struct QueryRoutingTests {
  @Test func queryDiscoversHotelBeforeMuseumWithoutChangingStoredItems() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    let museum = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(content: PlannerItemContentInput(title: "Museum"))))
    let hotel = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(content: PlannerItemContentInput(title: "Hotel"))))
    guard case .applied(let museumResult, .complete) = museum.outcome,
      case .applied(let hotelResult, .complete) = hotel.outcome
    else {
      Issue.record("The two fixture Items must be independently saved.")
      return
    }
    let museumIdentifier = try #require(museumResult.generated.first?.id)
    let hotelIdentifier = try #require(hotelResult.generated.first?.id)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": "tools/call",
      "params": [
        "name": "planner_query",
        "arguments": [
          "formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]],
        ],
      ],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    do {
      let exchange = try await httpSession.data(for: request)
      await listener.stop()
      let response = try #require(exchange.1 as? HTTPURLResponse)
      #expect(response.statusCode == 200)
      let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
      #expect(envelope["error"] == nil)
      let tool = try #require(envelope["result"] as? [String: Any])
      #expect(tool["isError"] as? Bool == false)
      let structured = try #require(tool["structuredContent"] as? [String: Any])
      #expect(structured["formatVersion"] as? Int == 1)
      let generation = try #require(structured["generation"] as? String)
      #expect(UUID(uuidString: generation) != nil)
      #expect(structured["matchingCount"] as? String == "2")
      let rows = try #require(structured["rows"] as? [[String: Any]])
      #expect(rows.count == 2)
      #expect(rows.allSatisfy { $0["kind"] as? String == "source" })
      let sources = try rows.map { try #require($0["source"] as? [String: Any]) }
      #expect(sources.allSatisfy { $0["kind"] as? String == "item" })
      #expect(
        sources.compactMap { $0["id"] as? String } == [
          hotelIdentifier.uuidString, museumIdentifier.uuidString,
        ])
      #expect((structured["unresolvedReferences"] as? [Any])?.isEmpty == true)
      #expect((structured["progress"] as? [Any])?.isEmpty == true)
      let content = try #require(tool["content"] as? [[String: Any]])
      let text = try #require(content.first?["text"] as? String)
      let textResult = try #require(
        JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
      #expect(NSDictionary(dictionary: textResult).isEqual(to: structured))
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: datasetSession, request: .items(PlannerItemQuery())))
      else {
        Issue.record("HTTP querying must retain native query results.")
        return
      }
      #expect(snapshot.matchingCount == 2)
      #expect(
        snapshot.rows == [
          .source(PlannerEntityReference(kind: .item, id: hotelIdentifier)),
          .source(PlannerEntityReference(kind: .item, id: museumIdentifier)),
        ])
    } catch {
      await listener.stop()
      throw error
    }
  }
}
