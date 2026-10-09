import Foundation
import Testing

@testable import Planner

@Suite
struct InitializationTests {
  @Test
  func repeatedIndependentInitializationsRetainRequestedSupportedVersions() async throws {
    let requestHandler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
    )
    let listener = PlannerMCPLoopbackListener(requestHandler: requestHandler)
    let endpoint = try await listener.start(port: 0)
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let fixtures = [
      InitializationExchange(
        body:
          #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","clientInfo":{"name":"Fixture A","version":"1"},"capabilities":{}}}"#,
        requestIdentifier: 1, protocolVersion: "2025-11-25"),
      InitializationExchange(
        body:
          #"{"jsonrpc":"2.0","id":2,"method":"initialize","params":{"protocolVersion":"2025-11-25","clientInfo":{"name":"Fixture A","version":"1"},"capabilities":{}}}"#,
        requestIdentifier: 2, protocolVersion: "2025-11-25"),
      InitializationExchange(
        body:
          #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"Fixture B","version":"1"},"capabilities":{}}}"#,
        requestIdentifier: 1, protocolVersion: "2024-11-05"),
    ]

    do {
      for fixture in fixtures {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = Data(fixture.body.utf8)
        request.setValue(
          "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5
        let (responseData, response) = try await session.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(httpResponse.value(forHTTPHeaderField: "MCP-Session-Id") == nil)
        #expect(
          httpResponse.value(forHTTPHeaderField: "X-Planner-Access-Window")
            == "00000000-0000-4000-8000-000000000701")
        let envelope = try #require(
          JSONSerialization.jsonObject(with: responseData) as? [String: Any])
        #expect(envelope["id"] as? Int == fixture.requestIdentifier)
        #expect(envelope["error"] == nil)
        let result = try #require(envelope["result"] as? [String: Any])
        #expect(result["protocolVersion"] as? String == fixture.protocolVersion)
        let capabilities = try #require(result["capabilities"] as? [String: Any])
        #expect(capabilities.isEmpty)
      }
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }
}

struct InitializationExchange {
  let body: String
  let requestIdentifier: Int
  let protocolVersion: String
}
