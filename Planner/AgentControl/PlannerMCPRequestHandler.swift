#if os(macOS)
  import MCP

  actor PlannerMCPRequestHandler {
    private let credential: String

    init(credential: String) {
      self.credential = credential
    }

    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
      guard request.header("Authorization") == "Bearer \(credential)" else {
        return .error(statusCode: 401, .invalidRequest("Unauthorized"))
      }

      return .error(statusCode: 501, .internalError("MCP prototype is not implemented"))
    }
  }
#endif
