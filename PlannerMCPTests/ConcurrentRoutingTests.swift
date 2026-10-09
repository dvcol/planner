import Foundation
import Testing

@testable import Planner

@Suite
struct ConcurrentRoutingTests {
  @Test
  func concurrentIntegerAndStringPingIdentifiersKeepTheirTypes() async throws {
    let requestHandler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
    )
    let listener = PlannerMCPLoopbackListener(requestHandler: requestHandler)
    let endpoint = try await listener.start(port: 0)
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    var integerRequest = URLRequest(url: endpoint)
    integerRequest.httpMethod = "POST"
    integerRequest.httpBody = Data(#"{"jsonrpc":"2.0","id":1,"method":"ping"}"#.utf8)
    integerRequest.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    integerRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    integerRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    integerRequest.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    integerRequest.timeoutInterval = 5
    var stringRequest = integerRequest
    stringRequest.httpBody = Data(#"{"jsonrpc":"2.0","id":"1","method":"ping"}"#.utf8)

    do {
      async let integerExchange = session.data(for: integerRequest)
      async let stringExchange = session.data(for: stringRequest)
      let (integerResponse, stringResponse) = try await (integerExchange, stringExchange)
      await listener.stop()

      let integerHTTPResponse = try #require(integerResponse.1 as? HTTPURLResponse)
      let stringHTTPResponse = try #require(stringResponse.1 as? HTTPURLResponse)
      #expect(integerHTTPResponse.statusCode == 200)
      #expect(stringHTTPResponse.statusCode == 200)
      #expect(integerHTTPResponse.value(forHTTPHeaderField: "MCP-Session-Id") == nil)
      #expect(stringHTTPResponse.value(forHTTPHeaderField: "MCP-Session-Id") == nil)
      #expect(
        integerHTTPResponse.value(forHTTPHeaderField: "X-Planner-Access-Window")
          == "00000000-0000-4000-8000-000000000701")
      #expect(
        stringHTTPResponse.value(forHTTPHeaderField: "X-Planner-Access-Window")
          == "00000000-0000-4000-8000-000000000701")
      let integerEnvelope = try #require(
        JSONSerialization.jsonObject(with: integerResponse.0) as? [String: Any])
      let stringEnvelope = try #require(
        JSONSerialization.jsonObject(with: stringResponse.0) as? [String: Any])
      #expect(integerEnvelope["id"] as? Int == 1)
      #expect(integerEnvelope["id"] as? String == nil)
      #expect(stringEnvelope["id"] as? String == "1")
      #expect(stringEnvelope["id"] as? Int == nil)
      #expect(integerEnvelope["error"] == nil)
      #expect(stringEnvelope["error"] == nil)
      let integerResult = try #require(integerEnvelope["result"] as? [String: Any])
      let stringResult = try #require(stringEnvelope["result"] as? [String: Any])
      #expect(integerResult.isEmpty)
      #expect(stringResult.isEmpty)
    } catch {
      await listener.stop()
      throw error
    }
  }
}
