#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPReviewTool {
    static let definition = Tool(
      name: "planner_prepare_review",
      description:
        "Review a full-context local completion action before applying it. Includes every independent appearance, including hidden/archived children. Global Item flags stay unchanged. Preparation saves no domain data. The token has no time-only expiry; changed payload, session or target lifetimes require a fresh review.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("command")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "command": PlannerMCPBulkCompletion.schema,
        ]),
      ]))

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    )
      async -> CallTool.Result
    {
      do {
        let fields = try PlannerMCPBulkCompletion.object(
          parameters.arguments.map(Value.object),
          allowed: ["formatVersion", "command"], required: ["formatVersion", "command"], path: "")
        guard fields["formatVersion"] == .int(1) else {
          return PlannerMCPSourceTool.failure(
            code: "unsupportedVersion", message: "Expected adapter format version 1.",
            path: "/formatVersion")
        }
        guard case .object(let suppliedCommand) = fields["command"],
          case .string(let kind) = suppliedCommand["type"]
        else {
          return PlannerMCPSourceTool.failure(
            code: "invalidInput", message: "Expected a command type.", path: "/command/type")
        }
        if ["deleteSource", "applyImport", "restoreRecovery"].contains(kind) {
          return PlannerMCPSourceTool.failure(
            code: "forbiddenOperation",
            message: "Deletion, import and recovery administration are native Planner actions.",
            path: "/command/type")
        }
        guard kind == "setBulkCompletion" else {
          return PlannerMCPSourceTool.failure(
            code: "invalidInput", message: "This command has no reviewable impact.",
            path: "/command/type")
        }
        let command = try PlannerMCPBulkCompletion.command(fields["command"])
        switch await planner.prepareReview(session: session, command: command) {
        case .failed(let failure): return PlannerMCPSourceTool.failure(failure)
        case .reviewed(let review):
          let value: Value = .object([
            "formatVersion": .int(1), "reviewId": .string(review.reviewId.uuidString),
            "reviewToken": .string(review.reviewToken.opaqueValue),
            "command": try PlannerMCPBulkCompletion.commandValue(review.command),
            "targets": .array(
              review.targets.map {
                .object([
                  "kind": .string("appearance"),
                  "appearance": PlannerMCPSourceTool.appearanceIdentityValue($0),
                ])
              }),
            "impact": .object([
              "kind": .string("bulkCompletion"), "targetCount": .string(String(review.targetCount)),
              "globalFlagsChanged": .bool(review.globalFlagsChanged), "sourceDeletes": .array([]),
              "referenceRemovals": .array([]), "importDetails": .null,
            ]),
          ])
          let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
          return try CallTool.Result(
            content: [.text(text: text, annotations: nil, _meta: nil)], structuredContent: value,
            isError: false)
        }
      } catch let failure as PlannerMCPBulkCompletion.Failure {
        return PlannerMCPSourceTool.failure(
          code: failure.code, message: failure.message, path: failure.path)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "readUnavailable", message: "The review could not be prepared or encoded.")
      }
    }
  }
#endif
