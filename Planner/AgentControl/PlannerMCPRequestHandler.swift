#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  actor PlannerMCPRequestHandler {
    private var credential: String?
    private let accessWindowIdentifier: UUID
    private let dataset: (planner: PlannerCore.Planner, session: PlannerDatasetSession)?

    init(credential: String, accessWindowIdentifier: UUID) {
      self.credential = credential
      self.accessWindowIdentifier = accessWindowIdentifier
      dataset = nil
    }

    init(
      credential: String, accessWindowIdentifier: UUID,
      planner: PlannerCore.Planner, datasetSession: PlannerDatasetSession
    ) {
      self.credential = credential
      self.accessWindowIdentifier = accessWindowIdentifier
      dataset = (planner, datasetSession)
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
      var capabilities = Server.Capabilities()
      if dataset != nil { capabilities.tools = .init() }
      let server = Server(
        name: "Planner MCP prototype", version: "0.0.1", capabilities: capabilities)
      if dataset != nil {
        await server.withMethodHandler(ListTools.self) { _ in
          ListTools.Result(tools: [
            PlannerMCPSourceTool.definition, PlannerMCPExecutionTool.definition,
            PlannerMCPQueryTool.definition,
          ])
        }
        await server.withMethodHandler(CallTool.self) { [weak self] parameters in
          guard let self else {
            return PlannerMCPSourceTool.failure(
              code: "unavailable", message: "Planner is unavailable.")
          }
          return await self.callPlannerTool(parameters)
        }
      }

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

    private func callPlannerTool(_ parameters: CallTool.Parameters) async -> CallTool.Result {
      guard credential != nil, let dataset else {
        return PlannerMCPSourceTool.failure(
          code: "forbiddenOperation", message: "This agent access window is no longer active.")
      }
      if parameters.name == "planner_execute" {
        return await PlannerMCPExecutionTool.call(
          parameters, planner: dataset.planner, session: dataset.session)
      }
      if parameters.name == "planner_query" {
        return await PlannerMCPQueryTool.call(
          parameters, planner: dataset.planner, session: dataset.session)
      }
      return await PlannerMCPSourceTool.call(
        parameters, planner: dataset.planner, session: dataset.session)
    }
  }
#endif
