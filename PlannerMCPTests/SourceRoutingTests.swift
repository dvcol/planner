import Foundation
import PlannerCore
import Testing

@testable import Planner

struct SourceRoutingTests {
  @Test func concurrentSameIdentifierReadsReturnTheirOwnHotelAndMuseum() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly
      ))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    let hotel = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Hotel notes"))
      ))
    let museum = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Museum", notes: "Museum notes"))
      ))
    guard case .applied(let hotelResult, .complete) = hotel.outcome,
      case .applied(let museumResult, .complete) = museum.outcome
    else {
      Issue.record("Both real fixture Items must be independently saved.")
      return
    }
    let hotelIdentifier = try #require(hotelResult.generated.first?.id)
    let museumIdentifier = try #require(museumResult.generated.first?.id)
    let accessWindowIdentifier = UUID()
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: accessWindowIdentifier,
      planner: planner, datasetSession: datasetSession
    )
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let hotelRequest = try request(endpoint: endpoint, itemIdentifier: hotelIdentifier)
    let museumRequest = try request(endpoint: endpoint, itemIdentifier: museumIdentifier)
    do {
      async let hotelExchange = httpSession.data(for: hotelRequest)
      async let museumExchange = httpSession.data(for: museumRequest)
      let (hotelResponse, museumResponse) = try await (hotelExchange, museumExchange)
      await listener.stop()
      try expectItem(
        hotelResponse, identity: hotelIdentifier, title: "Hotel", notes: "Hotel notes",
        accessWindowIdentifier: accessWindowIdentifier)
      try expectItem(
        museumResponse, identity: museumIdentifier, title: "Museum", notes: "Museum notes",
        accessWindowIdentifier: accessWindowIdentifier)
      let queried = await planner.query(
        PlannerQuery(session: datasetSession, request: .items(PlannerItemQuery())))
      guard case .snapshot(let snapshot) = queried else {
        Issue.record("Read-only HTTP traffic must retain public query results: \(queried)")
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

  private func request(endpoint: URL, itemIdentifier: UUID) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 7, "method": "tools/call",
      "params": [
        "name": "planner_read",
        "arguments": [
          "formatVersion": 1,
          "request": [
            "kind": "source", "source": ["kind": "item", "id": itemIdentifier.uuidString],
          ],
        ],
      ],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }

  private func expectItem(
    _ exchange: (Data, URLResponse), identity: UUID, title: String, notes: String,
    accessWindowIdentifier: UUID
  ) throws {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    #expect(response.value(forHTTPHeaderField: "MCP-Session-Id") == nil)
    #expect(
      response.value(forHTTPHeaderField: "X-Planner-Access-Window")
        == accessWindowIdentifier.uuidString)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["id"] as? Int == 7)
    #expect(envelope["error"] == nil)
    let toolResult = try #require(envelope["result"] as? [String: Any])
    #expect(toolResult["isError"] as? Bool == false)
    let structured = try #require(toolResult["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    #expect(structured["kind"] as? String == "source")
    let value = try #require(structured["value"] as? [String: Any])
    let source = try #require(value["source"] as? [String: Any])
    #expect(source["kind"] as? String == "item")
    #expect(source["id"] as? String == identity.uuidString)
    let content = try #require(value["content"] as? [String: Any])
    #expect(content["title"] as? String == title)
    #expect(content["notes"] as? String == notes)
    let state = try #require(value["state"] as? [String: Any])
    #expect(state["globalDone"] as? Bool == false)
    #expect(state["archived"] as? Bool == false)
  }
}
