import Foundation
import MCP
import Testing

@testable import Planner

@Suite
struct ListenerTests {
  @Test
  func stoppedListenerNoLongerAcceptsHTTPConnections() async throws {
    let requestHandler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
    )
    let listener = PlannerMCPLoopbackListener(requestHandler: requestHandler)
    let endpoint = try await listener.start(port: 0)
    await listener.stop()
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 5

    do {
      _ = try await session.data(for: request)
      Issue.record("The stopped listener accepted an HTTP connection")
    } catch let error as URLError {
      #expect(error.code == .cannotConnectToHost)
    }
  }

  @Test
  func stoppingListenerRevokesItsAccessWindow() async throws {
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
    )
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    _ = try await listener.start(port: 0)
    await listener.stop()
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

    #expect(response.statusCode == 401)
    #expect(response.headers["X-Planner-Access-Window"] == nil)
  }

  @Test
  func authenticatedPingTraversesARealLoopbackHTTPConnection() async throws {
    let requestHandler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
    )
    let listener = PlannerMCPLoopbackListener(requestHandler: requestHandler)
    let endpoint = try await listener.start(port: 0)
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"jsonrpc":"2.0","id":7,"method":"ping"}"#.utf8)
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5

    do {
      let (responseData, response) = try await session.data(for: request)
      await listener.stop()

      let httpResponse = try #require(response as? HTTPURLResponse)
      #expect(endpoint.host == "127.0.0.1")
      #expect(httpResponse.statusCode == 200)
      #expect(
        httpResponse.value(forHTTPHeaderField: "X-Planner-Access-Window")
          == "00000000-0000-4000-8000-000000000701")
      #expect(httpResponse.value(forHTTPHeaderField: "MCP-Session-Id") == nil)
      let envelope = try #require(
        JSONSerialization.jsonObject(with: responseData) as? [String: Any])
      #expect(envelope["jsonrpc"] as? String == "2.0")
      #expect(envelope["id"] as? Int == 7)
      let result = try #require(envelope["result"] as? [String: Any])
      #expect(result.isEmpty)
      #expect(envelope["error"] == nil)
    } catch {
      await listener.stop()
      throw error
    }
  }
}
