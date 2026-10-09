import Foundation
import Testing

@testable import Planner

@Suite
struct ValidationTests {
  @Test(arguments: [
    HTTPHeaderRejection(
      headerName: "Host", headerValue: "untrusted.example", expectedStatusCode: 421),
    HTTPHeaderRejection(headerName: "Accept", headerValue: "text/plain", expectedStatusCode: 406),
    HTTPHeaderRejection(
      headerName: "Content-Type", headerValue: "text/plain", expectedStatusCode: 415),
    HTTPHeaderRejection(
      headerName: "MCP-Protocol-Version", headerValue: "2099-01-01", expectedStatusCode: 400),
  ])
  func unsupportedHeadersAreRejectedOverLoopback(rejection: HTTPHeaderRejection) async throws {
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
    request.setValue(rejection.headerValue, forHTTPHeaderField: rejection.headerName)
    request.timeoutInterval = 5

    do {
      let (_, response) = try await session.data(for: request)
      await listener.stop()
      let httpResponse = try #require(response as? HTTPURLResponse)
      #expect(httpResponse.statusCode == rejection.expectedStatusCode)
      #expect(httpResponse.value(forHTTPHeaderField: "X-Planner-Access-Window") == nil)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test
  func untrustedOriginIsRejectedOverLoopback() async throws {
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
    request.setValue("https://untrusted.example", forHTTPHeaderField: "Origin")
    request.timeoutInterval = 5

    do {
      let (_, response) = try await session.data(for: request)
      await listener.stop()
      let httpResponse = try #require(response as? HTTPURLResponse)
      #expect(httpResponse.statusCode == 403)
      #expect(httpResponse.value(forHTTPHeaderField: "X-Planner-Access-Window") == nil)
    } catch {
      await listener.stop()
      throw error
    }
  }
}

struct HTTPHeaderRejection: Sendable {
  let headerName: String
  let headerValue: String
  let expectedStatusCode: Int
}
