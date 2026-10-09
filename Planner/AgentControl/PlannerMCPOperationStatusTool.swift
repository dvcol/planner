#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPOperationStatusTool {
    static let definition = Tool(
      name: "planner_operation_status",
      description: "Inspect operation evidence in the local Planner prototype without retrying it.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("operationId")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "operationId": .object(["type": .string("string"), "format": .string("uuid")]),
        ]),
      ]),
      annotations: .init(
        readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false))

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      guard let arguments = parameters.arguments else {
        return PlannerMCPSourceTool.failure(
          code: "invalidInput", message: "Expected arguments.", path: "")
      }
      if let unknown = Set(arguments.keys).subtracting(["formatVersion", "operationId"]).sorted()
        .first
      {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        return PlannerMCPSourceTool.failure(
          code: "unknownField", message: "Unknown property: \(unknown).", path: "/" + escaped)
      }
      if let missing = Set(["formatVersion", "operationId"]).subtracting(arguments.keys).sorted()
        .first
      {
        return PlannerMCPSourceTool.failure(
          code: "invalidInput", message: "Required property is missing: \(missing).",
          path: "/" + missing)
      }
      guard arguments["formatVersion"] == .int(1) else {
        return PlannerMCPSourceTool.failure(
          code: "unsupportedVersion", message: "Expected adapter format version 1.",
          path: "/formatVersion")
      }
      guard case .string(let spelling) = arguments["operationId"],
        let operationIdentifier = UUID(uuidString: spelling)
      else {
        return PlannerMCPSourceTool.failure(
          code: "invalidInput", message: "Expected an operation UUID.", path: "/operationId")
      }
      let status = await planner.operationStatus(session: session, operationId: operationIdentifier)
      var fields: [String: Value] = [
        "formatVersion": .int(1), "operationId": .string(operationIdentifier.uuidString),
      ]
      var unavailable = false
      switch status {
      case .noReliableEvidence:
        fields["state"] = .string("noReliableEvidence")
      case .knownUnapplied(let reason):
        fields["state"] = .string("knownUnapplied")
        fields["reason"] = PlannerMCPFailureValue.encode(reason)
      case .unavailable(let reason):
        fields["state"] = .string("unavailable")
        fields["reason"] = PlannerMCPFailureValue.encode(reason)
        unavailable = true
      case .preparedUnverified(let proposal):
        fields["state"] = .string("preparedUnverified")
        fields["proposal"] = .object([
          "proposalId": .string(proposal.proposalId.uuidString),
          "originalOperationId": .string(proposal.originalOperationId.uuidString),
          "evidence": .string(proposal.evidence),
          "requiresFreshReview": .bool(proposal.requiresFreshReview),
        ])
      case .appliedRecoveryIncomplete(let result, let reason):
        fields["state"] = .string("appliedRecoveryIncomplete")
        fields["result"] = appliedValue(result)
        fields["reason"] = PlannerMCPFailureValue.encode(reason)
      case .appliedRecoveryComplete(let result, let generation):
        fields["state"] = .string("appliedRecoveryComplete")
        fields["result"] = appliedValue(result)
        fields["checkpointGeneration"] = .string(String(generation))
      }
      do {
        let value = Value.object(fields)
        let serialized = try JSONEncoder().encode(value)
        return CallTool.Result(
          content: [.text(text: String(decoding: serialized, as: UTF8.self))],
          structuredContent: Optional.some(value), isError: unavailable)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "unavailable", message: "The operation evidence could not be encoded.")
      }
    }

    private static func appliedValue(_ result: PlannerAppliedResult) -> Value {
      .object([
        "generated": .array(result.generated.map(referenceValue)),
        "affected": .array(result.affected.map(referenceValue)),
        "progress": .array([]), "importSummary": .null,
      ])
    }

    private static func referenceValue(_ source: PlannerEntityReference) -> Value {
      .object(["kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString)])
    }

  }
#endif
