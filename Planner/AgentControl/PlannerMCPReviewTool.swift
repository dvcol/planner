#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPReviewTool {
    static let definition = Tool(
      name: "planner_prepare_review",
      description:
        "Review List-bound ordinary Item creation, a full-context local completion action or exact capture create/reuse proposal before applying it. Capture lists proposed new content or only missing links and memberships on reuse. Includes every independent appearance, including hidden/archived children. Global Item flags stay unchanged. Preparation saves no domain data. The token has no time-only expiry; changed payload, session or target lifetimes require a fresh review.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("command")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "command": .object([
            "oneOf": .array([
              PlannerMCPBulkCompletion.schema, PlannerMCPCaptureTool.commandSchema,
              PlannerMCPExecutionTool.creationSchema(requiresDestination: true),
            ])
          ]),
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
        guard ["setBulkCompletion", "applyCapture", "createItem"].contains(kind) else {
          return PlannerMCPSourceTool.failure(
            code: "invalidInput", message: "This command has no reviewable impact.",
            path: "/command/type")
        }
        let command: PlannerCommand
        if kind == "createItem" {
          command = try PlannerMCPExecutionTool.creationCommand(fields["command"])
          guard case .createItem(_, .some) = command else {
            return PlannerMCPSourceTool.failure(
              code: "invalidInput", message: "Creation review requires an active List destination.",
              path: "/command/listId")
          }
        } else if kind == "applyCapture" {
          command = try PlannerMCPCaptureTool.command(fields["command"])
        } else {
          command = try PlannerMCPBulkCompletion.command(fields["command"])
        }
        switch await planner.prepareReview(session: session, command: command) {
        case .failed(let failure): return PlannerMCPSourceTool.failure(failure)
        case .reviewed(let review):
          let value: Value = .object([
            "formatVersion": .int(1), "reviewId": .string(review.reviewId.uuidString),
            "reviewToken": .string(review.reviewToken.opaqueValue),
            "command": try commandValue(review.command),
            "targets": .array(
              try review.targets.map { target in
                switch target {
                case .source(let source):
                  return .object([
                    "kind": .string("source"),
                    "source": .object([
                      "kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString),
                    ]),
                  ])
                case .reference(let reference):
                  return .object([
                    "kind": .string("reference"),
                    "reference": PlannerMCPSourceTool.referenceValue(reference),
                  ])
                case .appearance(let appearance):
                  return .object([
                    "kind": .string("appearance"),
                    "appearance": PlannerMCPSourceTool.appearanceIdentityValue(appearance),
                  ])
                }
              }),
            "impact": .object([
              "kind": .string(review.impact.kind.rawValue),
              "targetCount": .string(String(review.targetCount)),
              "globalFlagsChanged": .bool(review.globalFlagsChanged), "sourceDeletes": .array([]),
              "referenceRemovals": .array([]), "importDetails": .null,
              "captureDetails": review.impact.captureDetails.map { details in
                .object([
                  "createContent": details.createContent.map(PlannerMCPCaptureTool.contentValue)
                    ?? .null,
                  "missingLinks": .array(details.missingLinks.map(PlannerMCPCaptureTool.linkValue)),
                  "missingListIds": .array(
                    details.missingListIds.sorted { $0.uuidString < $1.uuidString }.map {
                      .string($0.uuidString)
                    }),
                ])
              } ?? .null,
            ]),
          ])
          let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
          return try CallTool.Result(
            content: [.text(text: text, annotations: nil, _meta: nil)], structuredContent: value,
            isError: false)
        }
      } catch let failure as PlannerMCPExecutionTool.AdmissionFailure {
        return PlannerMCPSourceTool.failure(
          code: failure.code, message: failure.message, path: failure.path)
      } catch let failure as PlannerMCPBulkCompletion.Failure {
        return PlannerMCPSourceTool.failure(
          code: failure.code, message: failure.message, path: failure.path)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "readUnavailable", message: "The review could not be prepared or encoded.")
      }
    }

    private static func commandValue(_ command: PlannerCommand) throws -> Value {
      if case .createItem(let content, let listIdentifier?) = command {
        guard case .object(var fields) = PlannerMCPCaptureTool.contentValue(content) else {
          throw PlannerMCPBulkCompletion.Failure(
            code: "invalidInput", path: "/command/content",
            message: "Expected ordinary Item content.")
        }
        fields.removeValue(forKey: "subtitle")
        fields.removeValue(forKey: "estimate")
        return .object([
          "type": .string("createItem"), "listId": .string(listIdentifier.uuidString),
          "content": .object(fields),
        ])
      }
      if case .applyCapture = command { return try PlannerMCPCaptureTool.commandValue(command) }
      return try PlannerMCPBulkCompletion.commandValue(command)
    }
  }
#endif
