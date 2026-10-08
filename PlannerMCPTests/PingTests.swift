import Foundation
import MCP
import Testing

@testable import Planner

@Suite
struct PingTests {
  @Test
  func authorizedPingPreservesSDKResultAndAdmittedAccessWindow() async throws {
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
    )
    let request = HTTPRequest(
      method: "POST",
      headers: [
        "Host": "127.0.0.1:44444",
        "Authorization": "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "MCP-Protocol-Version": "2025-11-25",
      ],
      body: Data(#"{"jsonrpc":"2.0","id":7,"method":"ping"}"#.utf8),
      path: "/mcp"
    )

    let response = await handler.handleRequest(request)

    #expect(response.statusCode == 200)
    #expect(response.headers["X-Planner-Access-Window"] == "00000000-0000-4000-8000-000000000701")
    #expect(response.headers["MCP-Session-Id"] == nil)

    let responseData = try #require(response.bodyData)
    let envelope = try #require(JSONSerialization.jsonObject(with: responseData) as? [String: Any])
    #expect(envelope["jsonrpc"] as? String == "2.0")
    #expect(envelope["id"] as? Int == 7)
    let result = try #require(envelope["result"] as? [String: Any])
    #expect(result.isEmpty)
    #expect(envelope["error"] == nil)
  }
}
