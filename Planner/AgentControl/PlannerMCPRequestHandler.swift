#if os(macOS)
  import Foundation
  import MCP

  actor PlannerMCPRequestHandler {
    private var credential: String?
    private let accessWindowIdentifier: UUID

    init(credential: String, accessWindowIdentifier: UUID) {
      self.credential = credential
      self.accessWindowIdentifier = accessWindowIdentifier
    }

    func revokeAccess() {
      credential = nil
    }

    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
      guard request.path == "/mcp" else {
        return .error(statusCode: 404, .invalidRequest("Not Found"))
      }

      guard let credential, request.header("Authorization") == "Bearer \(credential)" else {
        return .error(statusCode: 401, .invalidRequest("Unauthorized"))
      }

      if let body = request.body,
        let initialization = try? JSONDecoder().decode(Request<Initialize>.self, from: body),
        initialization.method == Initialize.name,
        !Version.supported.contains(initialization.params.protocolVersion)
      {
        return .error(
          statusCode: 400,
          .invalidRequest(
            "Unsupported protocol version: \(initialization.params.protocolVersion). Supported: \(Version.supported.sorted().joined(separator: ", "))"
          )
        )
      }

      let transport = StatelessHTTPServerTransport()
      let server = Server(name: "Planner MCP prototype", version: "0.0.1")

      do {
        try await server.start(transport: transport)
      } catch {
        await server.stop()
        return .error(statusCode: 500, .internalError("MCP service is unavailable"))
      }

      let response = await transport.handleRequest(request)
      await server.stop()

      guard case .data(let responseData, var responseHeaders) = response else {
        return response
      }

      responseHeaders["X-Planner-Access-Window"] = accessWindowIdentifier.uuidString
      return .data(responseData, headers: responseHeaders)
    }
  }
#endif
