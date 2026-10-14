#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPCaptureTool {
    private static let identifierSchema = Value.object([
      "type": .string("string"), "format": .string("uuid"),
    ])

    static let commandSchema = Value.object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array(
        ["type", "draftId", "draftGeneration", "choice", "listIds"].map(Value.string)),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("applyCapture")]),
        "draftId": identifierSchema, "draftGeneration": identifierSchema,
        "listIds": .object(["type": .string("array"), "items": identifierSchema]),
        "choice": .object([
          "oneOf": .array([
            .object([
              "type": .string("object"), "additionalProperties": .bool(false),
              "required": .array([.string("kind")]),
              "properties": .object([
                "kind": .object(["type": .string("string"), "const": .string("createNew")])
              ]),
            ]),
            .object([
              "type": .string("object"), "additionalProperties": .bool(false),
              "required": .array([.string("kind"), .string("itemId")]),
              "properties": .object([
                "kind": .object(["type": .string("string"), "const": .string("reuse")]),
                "itemId": identifierSchema,
              ]),
            ]),
          ])
        ]),
      ]),
    ])

    private static let inputIndexesSchema = Value.object([
      "type": .string("array"),
      "items": .object([
        "type": .string("string"), "pattern": .string("^(0|[1-9][0-9]*)$"),
      ]),
    ])

    static let definitions = [
      definition(
        "planner_update_capture",
        description:
          "Edit independently supplied draft fields or explicitly remove/retry input indices. Uses the current generation and returns a new one. Saves no Item; provider previews cannot be promoted by an origin flag.",
        properties: [
          "draftId": identifierSchema, "generation": identifierSchema,
          "changes": .object([
            "type": .string("object"), "additionalProperties": .bool(false),
            "properties": .object(PlannerMCPExecutionTool.itemChangesProperties),
          ]),
          "removeInputIndexes": inputIndexesSchema, "retryInputIndexes": inputIndexesSchema,
        ], required: ["draftId", "generation", "changes"], readOnly: false),
      definition(
        "planner_prepare_capture",
        description:
          "Prepare one editable capture draft from ordered URL/text inputs. Saves no Item or receipt; keeps exact original URLs. Provider previews are temporary. Apply requires a separate Core-issued review token.",
        properties: [
          "inputs": .object([
            "type": .string("array"),
            "items": .object([
              "type": .string("object"), "additionalProperties": .bool(false),
              "required": .array([.string("kind"), .string("value")]),
              "properties": .object([
                "kind": .object([
                  "type": .string("string"), "enum": .array([.string("url"), .string("text")]),
                ]),
                "value": .object(["type": .string("string")]),
              ]),
            ]),
          ])
        ], required: ["inputs"], readOnly: false),
      definition(
        "planner_lookup_capture",
        description:
          "Look up the selected Maps link in a current unsaved draft. Uses bounded HTTPS header requests; provider candidates stay temporary. Add never waits, and failed lookup retains the original bookmark. Retry is explicit.",
        properties: [
          "draftId": identifierSchema, "generation": identifierSchema, "linkId": identifierSchema,
        ], required: ["draftId", "generation", "linkId"], readOnly: false, openWorld: true),
      definition(
        "planner_read_capture",
        description: "Read an unsaved draft in the authorized dataset without applying it.",
        properties: ["draftId": identifierSchema], required: ["draftId"], readOnly: true),
      definition(
        "planner_cancel_capture",
        description:
          "Discard an unsaved draft. A committed operation stays applied; resolve its returned operation identity through operation status.",
        properties: ["draftId": identifierSchema, "generation": identifierSchema],
        required: ["draftId", "generation"], readOnly: false),
    ]

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      do {
        let required: Set<String>
        switch parameters.name {
        case "planner_prepare_capture": required = ["formatVersion", "inputs"]
        case "planner_read_capture": required = ["formatVersion", "draftId"]
        case "planner_cancel_capture": required = ["formatVersion", "draftId", "generation"]
        case "planner_lookup_capture":
          required = ["formatVersion", "draftId", "generation", "linkId"]
        case "planner_update_capture":
          required = ["formatVersion", "draftId", "generation", "changes"]
        default:
          return PlannerMCPSourceTool.failure(
            code: "unavailable", message: "This capture tool is unavailable.")
        }
        var allowed = required
        if parameters.name == "planner_update_capture" {
          allowed.formUnion(["removeInputIndexes", "retryInputIndexes"])
        }
        let fields = try PlannerMCPBulkCompletion.object(
          parameters.arguments.map(Value.object), allowed: allowed, required: required, path: "")
        guard fields["formatVersion"] == .int(1) else {
          return PlannerMCPSourceTool.failure(
            code: "unsupportedVersion", message: "Expected adapter format version 1.",
            path: "/formatVersion")
        }
        if parameters.name == "planner_prepare_capture" {
          let input = try directInput(fields["inputs"])
          return try encode(await planner.prepareCapture(session: session, input: .direct(input)))
        }
        let draftIdentifier = try identifier(fields["draftId"], path: "/draftId")
        if parameters.name == "planner_read_capture" {
          return try encode(await planner.readCapture(session: session, draftId: draftIdentifier))
        }
        let generation = try identifier(fields["generation"], path: "/generation")
        if parameters.name == "planner_lookup_capture" {
          return try encode(
            await planner.lookupCapture(
              session: session, draftId: draftIdentifier, generation: generation,
              linkId: identifier(fields["linkId"], path: "/linkId")))
        }
        if parameters.name == "planner_update_capture" {
          let edit = PlannerCaptureEdit(
            changes: try PlannerMCPExecutionTool.itemChanges(fields["changes"], path: "/changes"),
            removeInputIndexes: try inputIndexes(
              fields["removeInputIndexes"], path: "/removeInputIndexes"),
            retryInputIndexes: try inputIndexes(
              fields["retryInputIndexes"], path: "/retryInputIndexes"))
          return try encode(
            await planner.updateCapture(
              session: session, draftId: draftIdentifier, generation: generation, edit: edit))
        }
        switch await planner.cancelCapture(
          session: session, draftId: draftIdentifier, generation: generation)
        {
        case .cancelled:
          return try result(.object(["formatVersion": .int(1), "state": .string("cancelled")]))
        case .notCancellable(let operationIdentifier):
          return try result(
            .object([
              "formatVersion": .int(1), "state": .string("notCancellable"),
              "operationId": .string(operationIdentifier.uuidString),
            ]))
        case .rejected(let reason): return PlannerMCPSourceTool.failure(reason)
        }
      } catch let failure as PlannerMCPBulkCompletion.Failure {
        return PlannerMCPSourceTool.failure(
          code: failure.code, message: failure.message, path: failure.path)
      } catch let failure as PlannerMCPExecutionTool.AdmissionFailure {
        return PlannerMCPSourceTool.failure(
          code: failure.code, message: failure.message, path: failure.path)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "readUnavailable", message: "The capture result could not be encoded.")
      }
    }

    static func command(_ value: Value?) throws -> PlannerCommand {
      let fields = try PlannerMCPBulkCompletion.object(
        value,
        allowed: ["type", "draftId", "draftGeneration", "choice", "listIds"],
        required: ["type", "draftId", "draftGeneration", "choice", "listIds"], path: "/command")
      let choiceFields = try PlannerMCPBulkCompletion.object(
        fields["choice"],
        allowed: ["kind", "itemId"], required: ["kind"], path: "/command/choice")
      let choice: PlannerCaptureChoice
      switch choiceFields["kind"] {
      case .string("createNew"):
        _ = try PlannerMCPBulkCompletion.object(
          fields["choice"], allowed: ["kind"], required: ["kind"], path: "/command/choice")
        choice = .createNew
      case .string("reuse"):
        _ = try PlannerMCPBulkCompletion.object(
          fields["choice"], allowed: ["kind", "itemId"], required: ["kind", "itemId"],
          path: "/command/choice")
        choice = .reuse(
          itemId: try identifier(choiceFields["itemId"], path: "/command/choice/itemId"))
      default:
        throw PlannerMCPBulkCompletion.Failure(
          code: "invalidInput", path: "/command/choice/kind",
          message: "Expected createNew or reuse.")
      }
      guard case .array(let values) = fields["listIds"] else {
        throw PlannerMCPBulkCompletion.Failure(
          code: "invalidInput", path: "/command/listIds", message: "Expected List UUIDs.")
      }
      let identifiers = try Set(
        values.enumerated().map { index, value in
          try identifier(value, path: "/command/listIds/\(index)")
        })
      return .applyCapture(
        draftId: try identifier(fields["draftId"], path: "/command/draftId"),
        draftGeneration: try identifier(
          fields["draftGeneration"], path: "/command/draftGeneration"),
        choice: choice, listIds: identifiers)
    }

    static func commandValue(_ command: PlannerCommand) throws -> Value {
      guard
        case .applyCapture(let draftIdentifier, let generation, let choice, let listIdentifiers) =
          command
      else {
        throw PlannerMCPBulkCompletion.Failure(
          code: "invalidInput", path: "/command/type", message: "Expected applyCapture.")
      }
      let choiceValue: Value
      switch choice {
      case .createNew: choiceValue = .object(["kind": .string("createNew")])
      case .reuse(let identifier):
        choiceValue = .object(["kind": .string("reuse"), "itemId": .string(identifier.uuidString)])
      }
      return .object([
        "type": .string("applyCapture"), "draftId": .string(draftIdentifier.uuidString),
        "draftGeneration": .string(generation.uuidString), "choice": choiceValue,
        "listIds": .array(
          listIdentifiers.sorted { $0.uuidString < $1.uuidString }.map { .string($0.uuidString) }),
      ])
    }

    private static func inputIndexes(_ value: Value?, path: String) throws -> Set<Int64> {
      guard let value else { return [] }
      guard case .array(let values) = value else {
        throw PlannerMCPBulkCompletion.Failure(
          code: "invalidInput", path: path, message: "Expected input index Strings.")
      }
      return try Set(
        values.enumerated().map { offset, value in
          guard case .string(let text) = value, let index = Int64(text), index >= 0,
            String(index) == text
          else {
            throw PlannerMCPBulkCompletion.Failure(
              code: "invalidInput", path: path + "/\(offset)",
              message: "Expected a nonnegative canonical Int64 String.")
          }
          return index
        })
    }

    private static func directInput(_ value: Value?) throws -> [PlannerCaptureDirectInput] {
      guard case .array(let values) = value else {
        throw PlannerMCPBulkCompletion.Failure(
          code: "invalidInput", path: "/inputs", message: "Expected ordered capture inputs.")
      }
      return try values.enumerated().map { index, value in
        let path = "/inputs/\(index)"
        let fields = try PlannerMCPBulkCompletion.object(
          value, allowed: ["kind", "value"], required: ["kind", "value"], path: path)
        guard case .string(let text) = fields["value"] else {
          throw PlannerMCPBulkCompletion.Failure(
            code: "invalidInput", path: path + "/value", message: "Expected a String.")
        }
        switch fields["kind"] {
        case .string("url"): return .url(text)
        case .string("text"): return .text(text)
        default:
          throw PlannerMCPBulkCompletion.Failure(
            code: "invalidInput", path: path + "/kind", message: "Expected url or text.")
        }
      }
    }

    static func identifier(_ value: Value?, path: String) throws -> UUID {
      guard case .string(let text) = value, let identifier = UUID(uuidString: text) else {
        throw PlannerMCPBulkCompletion.Failure(
          code: "invalidInput", path: path, message: "Expected a UUID.")
      }
      return identifier
    }

    private static func encode(_ outcome: PlannerCaptureDraftResult) throws -> CallTool.Result {
      switch outcome {
      case .rejected(let reason): return PlannerMCPSourceTool.failure(reason)
      case .draft(let draft):
        return try result(
          .object([
            "formatVersion": .int(1), "draftId": .string(draft.draftId.uuidString),
            "generation": .string(draft.generation.uuidString),
            "content": contentValue(draft.content),
            "links": .array(draft.links.map(linkValue)), "saveAllowed": .bool(draft.saveAllowed),
            "inputIssues": .array(
              draft.inputIssues.map { issue in
                .object([
                  "inputIndex": .string(String(issue.inputIndex)),
                  "lane": .string(issue.lane.rawValue),
                  "state": .string(issue.state.rawValue), "message": .string(issue.message),
                  "blocksSave": .bool(issue.blocksSave),
                ])
              }),
            "preview": .object([
              "state": .string(draft.preview.state.rawValue),
              "linkId": draft.preview.linkId.map { .string($0.uuidString) } ?? .null,
              "candidate": draft.preview.candidate.map(candidateValue) ?? .null,
            ]),
            "reuseCandidates": .array(
              draft.reuseCandidates.map { candidate in
                .object([
                  "itemId": .string(candidate.itemId.uuidString), "title": .string(candidate.title),
                  "globalDone": .bool(candidate.globalDone), "archived": .bool(candidate.archived),
                  "matchingLinkIds": .array(
                    candidate.matchingLinkIds.map { .string($0.uuidString) }),
                  "matchingOriginalUrls": .array(candidate.matchingOriginalUrls.map(Value.string)),
                ])
              }),
          ]))
      }
    }

    static func contentValue(_ content: PlannerItemContentInput) -> Value {
      .object([
        "title": .string(content.title), "subtitle": content.subtitle.map(Value.string) ?? .null,
        "notes": content.notes.map(Value.string) ?? .null,
        "location": content.location.map(PlannerMCPSourceTool.locationValue) ?? .null,
        "estimate": content.estimate.map(PlannerMCPSourceTool.estimateValue) ?? .null,
        "links": .array(
          content.links.map { link in
            .object([
              "linkId": link.linkId.map { .string($0.uuidString) } ?? .null,
              "originalUrl": .string(link.originalUrl),
              "label": link.label.map(Value.string) ?? .null,
            ])
          }),
        "categoryIds": .array(
          content.categoryIds.sorted { $0.uuidString < $1.uuidString }.map {
            .string($0.uuidString)
          }),
        "tagIds": .array(
          content.tagIds.sorted { $0.uuidString < $1.uuidString }.map { .string($0.uuidString) }),
      ])
    }

    static func linkValue(_ link: PlannerCaptureDraftLink) -> Value {
      .object([
        "linkId": .string(link.linkId.uuidString), "originalUrl": .string(link.originalUrl),
        "label": link.label.map(Value.string) ?? .null, "kind": .string(link.kind.rawValue),
        "providerReference": link.providerReference.map { reference in
          .object(["kind": .string(reference.kind.rawValue), "value": .string(reference.value)])
        } ?? .null,
      ])
    }

    private static func candidateValue(_ candidate: PlannerCapturePreviewCandidate) -> Value {
      .object([
        "provider": .string(candidate.provider.rawValue),
        "displayName": candidate.displayName.map(Value.string) ?? .null,
        "formattedAddress": candidate.formattedAddress.map(Value.string) ?? .null,
        "coordinate": candidate.coordinate.map { coordinate in
          .object([
            "latitude": .double(coordinate.latitude), "longitude": .double(coordinate.longitude),
          ])
        } ?? .null,
        "providerReference": candidate.providerReference.map { reference in
          .object(["kind": .string(reference.kind.rawValue), "value": .string(reference.value)])
        } ?? .null,
        "uncertaintyReasons": .array(candidate.uncertaintyReasons.map(Value.string)),
        "attributionText": candidate.attributionText.map(Value.string) ?? .null,
      ])
    }

    private static func result(_ value: Value) throws -> CallTool.Result {
      let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
      return try CallTool.Result(
        content: [.text(text: text, annotations: nil, _meta: nil)], structuredContent: value,
        isError: false)
    }

    private static func definition(
      _ name: String, description: String, properties: [String: Value], required: [String],
      readOnly: Bool, openWorld: Bool = false
    ) -> Tool {
      var properties = properties
      properties["formatVersion"] = .object(["type": .string("integer"), "const": .int(1)])
      return Tool(
        name: name, description: description,
        inputSchema: .object([
          "type": .string("object"), "additionalProperties": .bool(false),
          "required": .array((["formatVersion"] + required).map(Value.string)),
          "properties": .object(properties),
        ]),
        annotations: .init(
          readOnlyHint: readOnly, destructiveHint: false, idempotentHint: readOnly,
          openWorldHint: openWorld))
    }
  }
#endif
