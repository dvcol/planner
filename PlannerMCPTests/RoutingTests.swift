import Foundation
import MCP
import Testing

@testable import Planner

@Suite
struct RoutingTests {
  @Test
  func unrecognizedPathCannotDispatchAnAuthorizedPing() async {
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
      path: "/admin"
    )

    let response = await handler.handleRequest(request)

    #expect(response.statusCode == 404)
    #expect(response.headers["X-Planner-Access-Window"] == nil)
  }
}
