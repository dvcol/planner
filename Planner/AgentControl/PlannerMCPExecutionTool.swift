#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPExecutionTool {
    static let definition = Tool(
      name: "planner_execute",
      description:
        "Create an Item with owned HTTP(S) bookmarks, edit its title/notes, complete/reopen it globally or archive/unarchive it through the local Planner prototype.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("operationId"), .string("command")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "operationId": .object(["type": .string("string"), "format": .string("uuid")]),
          "command": .object([
            "oneOf": .array([creationSchema, editSchema, archiveSchema, completionSchema])
          ]),
          "reviewToken": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
      ]),
      annotations: .init(
        readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    private static let creationSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("content")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("createItem")]),
        "content": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("title")]),
          "properties": .object([
            "title": .object(["type": .string("string")]),
            "notes": .object(["type": .array([.string("string"), .string("null")])]),
            "links": .object([
              "type": .string("array"),
              "items": .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("originalUrl"), .string("label")]),
                "properties": .object([
                  "linkId": .object([
                    "type": .array([.string("string"), .string("null")]), "format": .string("uuid"),
                  ]),
                  "originalUrl": .object(["type": .string("string"), "format": .string("uri")]),
                  "label": .object(["type": .array([.string("string"), .string("null")])]),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
    ])

    private static let editSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([
        .string("type"), .string("sourceId"), .string("changes"), .string("expectedFieldHashes"),
      ]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("editItem")]),
        "sourceId": .object(["type": .string("string"), "format": .string("uuid")]),
        "changes": .object([
          "type": .string("object"), "additionalProperties": .bool(false), "minProperties": .int(1),
          "properties": .object([
            "title": .object(["type": .string("string")]),
            "notes": .object(["type": .array([.string("string"), .string("null")])]),
          ]),
        ]),
        "expectedFieldHashes": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "properties": .object(
            Dictionary(
              uniqueKeysWithValues: PlannerItemField.allCases.map {
                (
                  $0.rawValue,
                  .object([
                    "type": .string("string"), "pattern": .string("^sha256-v1:[0-9a-f]{64}$"),
                  ])
                )
              })),
        ]),
      ]),
    ])

    private static let archiveSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("source"), .string("archived")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("setArchive")]),
        "source": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("kind"), .string("id")]),
          "properties": .object([
            "kind": .object(["type": .string("string"), "const": .string("item")]),
            "id": .object(["type": .string("string"), "format": .string("uuid")]),
          ]),
        ]),
        "archived": .object(["type": .string("boolean")]),
      ]),
    ])

    private static let completionSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("scope"), .string("done")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("setCompletion")]),
        "scope": .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array([.string("kind"), .string("itemId")]),
          "properties": .object([
            "kind": .object(["type": .string("string"), "const": .string("globalItem")]),
            "itemId": .object(["type": .string("string"), "format": .string("uuid")]),
          ]),
        ]),
        "done": .object(["type": .string("boolean")]),
      ]),
    ])

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      var operationIdentifier: UUID?
      do {
        let arguments = try object(
          parameters.arguments.map(Value.object),
          allowed: ["formatVersion", "operationId", "command", "reviewToken"],
          required: ["formatVersion", "operationId", "command"], path: "")
        guard case .string(let spelling) = arguments["operationId"],
          let identity = UUID(uuidString: spelling)
        else {
          throw AdmissionFailure("invalidInput", "/operationId", "Expected an operation UUID.")
        }
        operationIdentifier = identity
        guard arguments["formatVersion"] == .int(1) else {
          throw AdmissionFailure(
            "unsupportedVersion", "/formatVersion", "Expected adapter format version 1.")
        }
        guard case .object(let suppliedCommand) = arguments["command"],
          case .string(let commandType) = suppliedCommand["type"]
        else {
          throw AdmissionFailure("invalidInput", "/command/type", "Expected a command type.")
        }
        if ["deleteSource", "applyImport", "restoreRecovery"].contains(commandType) {
          throw AdmissionFailure(
            "forbiddenOperation", "/command/type",
            "Permanent deletion, import and recovery administration are native Planner actions.")
        }
        if let token = arguments["reviewToken"], token != .null {
          throw AdmissionFailure(
            "staleReview", "/reviewToken", "No review token is issued for this ordinary Item slice."
          )
        }
        let command: PlannerCommand
        switch commandType {
        case "createItem": command = try creationCommand(arguments["command"])
        case "editItem": command = try editCommand(arguments["command"])
        case "setArchive": command = try archiveCommand(arguments["command"])
        case "setCompletion": command = try completionCommand(arguments["command"])
        default:
          throw AdmissionFailure(
            "unavailable", "/command/type", "This command is not yet implemented by the prototype.")
        }
        let outcome = await planner.execute(
          PlannerOperation(operationId: identity, session: session, command: command))
        return try encoded(outcome)
      } catch let failure as AdmissionFailure {
        return rejection(
          operationIdentifier, code: failure.code, path: failure.path, message: failure.message)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "unavailable",
          message: "The operation outcome could not be encoded; inspect its status before retrying."
        )
      }
    }

    private static func completionCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "scope", "done"], required: ["type", "scope", "done"],
        path: "/command")
      let scope = try object(
        command["scope"], allowed: ["kind", "itemId", "appearance"], required: ["kind"],
        path: "/command/scope")
      if scope["kind"] == .string("appearance") {
        _ = try object(
          command["scope"], allowed: ["kind", "appearance"], required: ["kind", "appearance"],
          path: "/command/scope")
        throw AdmissionFailure(
          "unavailable", "/command/scope/kind",
          "Appearance-local completion is not implemented by this Item-only fixture.")
      }
      guard scope["kind"] == .string("globalItem") else {
        throw AdmissionFailure(
          "invalidInput", "/command/scope/kind", "Expected a completion scope.")
      }
      let globalScope = try object(
        command["scope"], allowed: ["kind", "itemId"], required: ["kind", "itemId"],
        path: "/command/scope")
      guard case .string(let spelling) = globalScope["itemId"],
        let itemIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/scope/itemId", "Expected an Item UUID.")
      }
      guard case .bool(let done) = command["done"] else {
        throw AdmissionFailure("invalidInput", "/command/done", "Expected a completion Boolean.")
      }
      return .setCompletion(scope: .globalItem(itemId: itemIdentifier), done: done)
    }

    private static func creationCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "content"], required: ["type", "content"],
        path: "/command")
      let content = try object(
        command["content"],
        allowed: [
          "title", "notes", "subtitle", "location", "estimate", "links", "categoryIds", "tagIds",
        ],
        required: ["title"], path: "/command/content")
      if let unsupported = Set(content.keys).subtracting(["title", "notes", "links"]).sorted().first
      {
        throw AdmissionFailure(
          "unavailable", "/command/content/" + unsupported,
          "This HTTP creation slice supports title, notes and owned links only.")
      }
      guard case .string(let title) = content["title"] else {
        throw AdmissionFailure(
          "invalidInput", "/command/content/title", "Expected a title String.")
      }
      let notes: String?
      switch content["notes"] {
      case nil, .null: notes = nil
      case .string(let value): notes = value
      default:
        throw AdmissionFailure(
          "invalidInput", "/command/content/notes", "Expected a notes String or null.")
      }
      return .createItem(
        content: PlannerItemContentInput(
          title: title, notes: notes, links: try linksInput(content["links"])))
    }

    private static func linksInput(_ value: Value?) throws -> [PlannerLinkInput] {
      guard let value else { return [] }
      guard case .array(let links) = value else {
        throw AdmissionFailure(
          "invalidInput", "/command/content/links", "Expected an ordered links array.")
      }
      return try links.enumerated().map { index, value in
        let path = "/command/content/links/\(index)"
        let fields = try object(
          value, allowed: ["linkId", "originalUrl", "label"], required: ["originalUrl", "label"],
          path: path)
        guard case .string(let originalUrl) = fields["originalUrl"] else {
          throw AdmissionFailure(
            "invalidInput", path + "/originalUrl", "Expected an original URL String.")
        }
        let label: String?
        switch fields["label"] {
        case .null: label = nil
        case .string(let value): label = value
        default:
          throw AdmissionFailure(
            "invalidInput", path + "/label", "Expected a label String or null.")
        }
        let linkIdentifier: UUID?
        switch fields["linkId"] {
        case nil, .null: linkIdentifier = nil
        case .string(let spelling):
          guard let parsedIdentifier = UUID(uuidString: spelling) else {
            throw AdmissionFailure(
              "invalidInput", path + "/linkId", "Expected a link UUID or null.")
          }
          linkIdentifier = parsedIdentifier
        default:
          throw AdmissionFailure("invalidInput", path + "/linkId", "Expected a link UUID or null.")
        }
        return PlannerLinkInput(linkId: linkIdentifier, originalUrl: originalUrl, label: label)
      }
    }

    private static func editCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "sourceId", "changes", "expectedFieldHashes"],
        required: ["type", "sourceId", "changes", "expectedFieldHashes"], path: "/command")
      guard case .string(let spelling) = command["sourceId"],
        let sourceIdentifier = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/sourceId", "Expected an Item UUID.")
      }
      let fieldNames = Set(PlannerItemField.allCases.map(\.rawValue))
      let changes = try object(
        command["changes"], allowed: fieldNames, required: [], path: "/command/changes")
      if let unsupported = Set(changes.keys).subtracting(["title", "notes"]).sorted().first {
        throw AdmissionFailure(
          "unavailable", "/command/changes/" + unsupported,
          "This edit slice supports title and notes only.")
      }
      let hashValues = try object(
        command["expectedFieldHashes"], allowed: fieldNames, required: [],
        path: "/command/expectedFieldHashes")
      var hashes: [PlannerItemField: PlannerFieldHash] = [:]
      for (name, value) in hashValues {
        guard let field = PlannerItemField(rawValue: name), case .string(let spelling) = value
        else {
          throw AdmissionFailure(
            "invalidInput", "/command/expectedFieldHashes/" + name, "Expected a field hash String.")
        }
        hashes[field] = PlannerFieldHash(value: spelling)
      }
      return .editItem(
        sourceId: sourceIdentifier,
        changes: PlannerItemChanges(
          title: try textChange(changes["title"], path: "/command/changes/title"),
          notes: try textChange(changes["notes"], path: "/command/changes/notes")),
        expectedFieldHashes: hashes)
    }

    private static func archiveCommand(_ value: Value?) throws -> PlannerCommand {
      let command = try object(
        value, allowed: ["type", "source", "archived"], required: ["type", "source", "archived"],
        path: "/command")
      let source = try object(
        command["source"], allowed: ["kind", "id"], required: ["kind", "id"],
        path: "/command/source")
      guard case .string(let spelling) = source["kind"],
        let kind = PlannerEntityKind(rawValue: spelling),
        [.item, .list, .itinerary].contains(kind)
      else {
        throw AdmissionFailure(
          "invalidInput", "/command/source/kind", "Expected Item, List or Itinerary source kind.")
      }
      guard case .string(let spelling) = source["id"], let identity = UUID(uuidString: spelling)
      else {
        throw AdmissionFailure("invalidInput", "/command/source/id", "Expected a source UUID.")
      }
      guard case .bool(let archived) = command["archived"] else {
        throw AdmissionFailure("invalidInput", "/command/archived", "Expected an archive Bool.")
      }
      return .setArchive(
        source: PlannerEntityReference(kind: kind, id: identity), archived: archived)
    }

    private static func textChange(_ value: Value?, path: String) throws -> PlannerFieldChange<
      String
    > {
      switch value {
      case nil: return .unchanged
      case .null: return .clear
      case .string(let text): return .set(text)
      default: throw AdmissionFailure("invalidInput", path, "Expected a String or null.")
      }
    }

    private static func encoded(_ outcome: PlannerOperationResult) throws -> CallTool.Result {
      var fields: [String: Value] = [
        "formatVersion": .int(1), "operationId": .string(outcome.operationId.uuidString),
      ]
      var rejected = false
      switch outcome.outcome {
      case .rejected(let reason):
        fields["state"] = .string("rejected")
        fields["reason"] = PlannerMCPFailureValue.encode(reason)
        rejected = true
      case .unverified(let proposal):
        fields["state"] = .string("unverified")
        fields["proposal"] = .object([
          "proposalId": .string(proposal.proposalId.uuidString),
          "originalOperationId": .string(proposal.originalOperationId.uuidString),
          "evidence": .string(proposal.evidence),
          "requiresFreshReview": .bool(proposal.requiresFreshReview),
        ])
      case .applied(let result, let recovery):
        fields["state"] = .string("applied")
        fields["result"] = .object([
          "generated": .array(result.generated.map(referenceValue)),
          "affected": .array(result.affected.map(referenceValue)),
          "progress": .array([]), "importSummary": .null,
        ])
        switch recovery {
        case .complete(let generation):
          fields["recovery"] = .object([
            "state": .string("complete"), "checkpointGeneration": .string(String(generation)),
          ])
        case .incomplete(let reason):
          fields["recovery"] = .object([
            "state": .string("incomplete"),
            "reason": PlannerMCPFailureValue.encode(reason),
          ])
        }
      }
      return try result(.object(fields), isError: rejected)
    }

    private static func referenceValue(_ source: PlannerEntityReference) -> Value {
      .object(["kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString)])
    }

    private static func rejection(
      _ operationIdentifier: UUID?, code: String, path: String?, message: String
    ) -> CallTool.Result {
      guard let operationIdentifier else {
        return PlannerMCPSourceTool.failure(code: code, message: message, path: path)
      }
      let value = Value.object([
        "formatVersion": .int(1), "operationId": .string(operationIdentifier.uuidString),
        "state": .string("rejected"), "reason": failureValue(code, path, message),
      ])
      do { return try result(value, isError: true) } catch {
        return CallTool.Result(
          content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
      }
    }

    private static func result(_ value: Value, isError: Bool) throws -> CallTool.Result {
      let serialized = try JSONEncoder().encode(value)
      return CallTool.Result(
        content: [
          .text(text: String(decoding: serialized, as: UTF8.self), annotations: nil, _meta: nil)
        ],
        structuredContent: Optional.some(value), isError: isError)
    }

    private static func failureValue(_ code: String, _ path: String?, _ message: String) -> Value {
      .object([
        "code": .string(code), "propertyPath": path.map(Value.string) ?? .null,
        "message": .string(message), "details": .null,
      ])
    }

    private static func object(
      _ value: Value?, allowed: Set<String>, required: Set<String>, path: String
    ) throws -> [String: Value] {
      guard case .object(let fields) = value else {
        throw AdmissionFailure("invalidInput", path, "Expected an object.")
      }
      if let unknown = Set(fields.keys).subtracting(allowed).sorted().first {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw AdmissionFailure(
          "unknownField", path + "/" + escaped, "Unknown property: \(unknown).")
      }
      if let missing = required.subtracting(fields.keys).sorted().first {
        throw AdmissionFailure(
          "invalidInput", path + "/" + missing, "Required property is missing: \(missing).")
      }
      return fields
    }

    private struct AdmissionFailure: Error {
      let code: String
      let path: String
      let message: String

      init(_ code: String, _ path: String, _ message: String) {
        self.code = code
        self.path = path
        self.message = message
      }
    }
  }
#endif
