#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  actor PlannerMCPRequestHandler {
    private var credential: String?
    private let accessWindowIdentifier: UUID
    private let dataset: (planner: PlannerCore.Planner, session: PlannerDatasetSession)?
    private var activeCalls: [UUID: Task<CallTool.Result, Never>] = [:]

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
      for call in activeCalls.values { call.cancel() }
    }

    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
      guard request.path == "/mcp" else {
        return .error(statusCode: 404, .invalidRequest("Not Found"))
      }

      guard let credential, request.header("Authorization") == "Bearer \(credential)" else {
        return .error(statusCode: 401, .invalidRequest("Unauthorized"))
      }

      let request = compatibleInitialization(request)

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
        name: "Plan 2Do", version: "1.0.0",
        instructions: """
          Read the selected library through planner_query and planner_read before editing. Use fresh field hashes from planner_read for edits and obtain the required planner_prepare_review or capture review token before reviewed changes. Use a new operationId for each changed payload. After an uncertain write, check planner_operation_status with the original operationId before retrying; reuse that ID only for the exact same payload. All changes apply to the currently authorized library.
          """, capabilities: capabilities)
      if dataset != nil {
        await server.withMethodHandler(ListTools.self) { _ in
          ListTools.Result(
            tools: [
              PlannerMCPSourceTool.definition, PlannerMCPExecutionTool.definition,
              PlannerMCPQueryTool.definition,
              PlannerMCPOperationStatusTool.definition, PlannerMCPReviewTool.definition,
            ] + PlannerMCPCaptureTool.definitions)
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

    /// SDK 0.12.1 only decodes string experimental values; this server implements no extensions.
    private func compatibleInitialization(_ request: HTTPRequest) -> HTTPRequest {
      guard let body = request.body,
        var envelope = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
        envelope["method"] as? String == Initialize.name,
        var parameters = envelope["params"] as? [String: Any],
        var capabilities = parameters["capabilities"] as? [String: Any],
        let experimental = capabilities["experimental"] as? [String: Any],
        experimental.values.contains(where: { !($0 is String) })
      else { return request }
      capabilities["experimental"] = experimental.filter { $0.value is String }
      parameters["capabilities"] = capabilities
      envelope["params"] = parameters
      guard let compatibleBody = try? JSONSerialization.data(withJSONObject: envelope) else {
        return request
      }
      return HTTPRequest(
        method: request.method, headers: request.headers, body: compatibleBody, path: request.path)
    }

    private func callPlannerTool(_ parameters: CallTool.Parameters) async -> CallTool.Result {
      let identifier = UUID()
      let task = Task { await dispatchPlannerTool(parameters) }
      activeCalls[identifier] = task
      defer { activeCalls.removeValue(forKey: identifier) }
      return await withTaskCancellationHandler {
        await task.value
      } onCancel: {
        task.cancel()
      }
    }

    private func dispatchPlannerTool(_ parameters: CallTool.Parameters) async -> CallTool.Result {
      guard credential != nil, let dataset else {
        return PlannerMCPSourceTool.failure(
          code: "forbiddenOperation", message: "This agent access window is no longer active.")
      }
      if parameters.name == "planner_execute" {
        return await PlannerMCPExecutionTool.call(
          parameters, planner: dataset.planner, session: dataset.session)
      }
      if parameters.name == "planner_prepare_review" {
        return await PlannerMCPReviewTool.call(
          parameters, planner: dataset.planner, session: dataset.session)
      }
      if parameters.name == "planner_query" {
        return await PlannerMCPQueryTool.call(
          parameters, planner: dataset.planner, session: dataset.session)
      }
      if parameters.name == "planner_operation_status" {
        return await PlannerMCPOperationStatusTool.call(
          parameters, planner: dataset.planner, session: dataset.session)
      }
      if PlannerMCPCaptureTool.definitions.contains(where: { $0.name == parameters.name }) {
        return await PlannerMCPCaptureTool.call(
          parameters, planner: dataset.planner, session: dataset.session)
      }
      return await PlannerMCPSourceTool.call(
        parameters, planner: dataset.planner, session: dataset.session)
    }
  }
#endif
