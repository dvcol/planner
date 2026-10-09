#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPQueryTool {
    static let definition = Tool(
      name: "planner_query",
      description:
        "Discover source or exact List appearance identities in the local Planner prototype.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("query")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "query": .object([
            "type": .string("object"), "additionalProperties": .bool(false),
            "required": .array([.string("kind"), .string("scope")]),
            "properties": .object([
              "kind": .object(["type": .string("string"), "const": .string("items")]),
              "scope": .object([
                "oneOf": .array([
                  .object([
                    "type": .string("object"), "additionalProperties": .bool(false),
                    "required": .array([.string("kind")]),
                    "properties": .object([
                      "kind": .object([
                        "type": .string("string"),
                        "enum": .array([.string("global"), .string("inbox")]),
                      ])
                    ]),
                  ]),
                  .object([
                    "type": .string("object"), "additionalProperties": .bool(false),
                    "required": .array([.string("kind"), .string("listId")]),
                    "properties": .object([
                      "kind": .object(["type": .string("string"), "const": .string("list")]),
                      "listId": .object(["type": .string("string"), "format": .string("uuid")]),
                    ]),
                  ]),
                ])
              ]),
              "sort": .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("mode"), .string("direction")]),
                "properties": .object([
                  "mode": .object([
                    "type": .string("string"),
                    "enum": .array([.string("title"), .string("manual")]),
                  ]),
                  "direction": .object([
                    "type": .string("string"),
                    "enum": .array([.string("ascending"), .string("descending")]),
                  ]),
                ]),
              ]),
              "rowPresentation": .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("referenceInstant"), .string("displayTimeZone")]),
                "properties": .object([
                  "referenceInstant": .object(["type": .string("number")]),
                  "displayTimeZone": .object(["type": .string("string")]),
                ]),
              ]),
              "completion": .object([
                "type": .string("string"),
                "enum": .array([.string("todo"), .string("done"), .string("all")]),
              ]),
              "archive": .object([
                "type": .string("string"),
                "enum": .array([.string("active"), .string("archived"), .string("all")]),
              ]),
            ]),
          ]),
        ]),
      ]),
      annotations: .init(
        readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false))

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      do {
        let arguments = try object(
          parameters.arguments.map(Value.object), allowed: ["formatVersion", "query"],
          required: ["formatVersion", "query"], path: "")
        guard arguments["formatVersion"] == .int(1) else {
          throw AdmissionFailure(
            code: "unsupportedVersion", path: "/formatVersion",
            message: "Expected adapter format version 1.")
        }
        let query = try object(
          arguments["query"],
          allowed: [
            "kind", "scope", "text", "completion", "archive", "categories", "tags", "lists",
            "duration", "scheduled", "hasAddress", "hasLinks", "sort", "rowPresentation",
          ], required: ["kind", "scope"], path: "/query")
        guard query["kind"] == .string("items") else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/kind",
            message: "This prototype supports Item queries.")
        }
        if let unsupported = Set(query.keys).subtracting([
          "kind", "scope", "completion", "archive", "sort", "rowPresentation",
        ])
        .sorted().first {
          throw AdmissionFailure(
            code: "unavailable", path: "/query/" + unsupported,
            message:
              "This query slice supports scope, completion, archive, sort and row presentation.")
        }
        let nativeScope = try scope(query["scope"])
        let sort = try sort(query["sort"])
        let completion: PlannerItemQuery.Completion
        switch query["completion"] {
        case nil, .string("todo"): completion = .todo
        case .string("done"): completion = .done
        case .string("all"): completion = .all
        default:
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/completion", message: "Expected todo, done or all.")
        }
        let archive: PlannerItemQuery.Archive
        switch query["archive"] {
        case nil, .string("active"): archive = .active
        case .string("archived"): archive = .archived
        case .string("all"): archive = .all
        default:
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/archive",
            message: "Expected active, archived or all.")
        }
        let presentation = try rowPresentation(query["rowPresentation"])
        let queried = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              PlannerItemQuery(
                scope: nativeScope, completion: completion, archive: archive,
                sort: sort, rowPresentation: presentation))))
        switch queried {
        case .failed(let reason):
          return PlannerMCPSourceTool.failure(reason)
        case .snapshot(let snapshot):
          let value = Value.object([
            "formatVersion": .int(1), "generation": .string(snapshot.generation.uuidString),
            "matchingCount": .string(String(snapshot.matchingCount)),
            "rows": .array(snapshot.rows.map(PlannerMCPRowValue.identity)),
            "rowPresentation": snapshot.rowPresentation.map(PlannerMCPRowValue.presentation)
              ?? .null,
            "unresolvedReferences": .array(
              snapshot.unresolvedReferences.map(PlannerMCPSourceTool.referenceValue)),
            "progress": .array(snapshot.progress.map(PlannerMCPSourceTool.progressValue)),
          ])
          let serialized = try JSONEncoder().encode(value)
          return CallTool.Result(
            content: [
              .text(text: String(decoding: serialized, as: UTF8.self), annotations: nil, _meta: nil)
            ],
            structuredContent: Optional.some(value), isError: false)
        }
      } catch let failure as AdmissionFailure {
        return PlannerMCPSourceTool.failure(
          code: failure.code, message: failure.message, path: failure.path)
      } catch {
        return PlannerMCPSourceTool.failure(
          code: "unavailable", message: "The Planner query could not be completed.")
      }
    }

    private static func scope(_ value: Value?) throws -> PlannerItemQuery.Scope {
      let fields = try object(
        value, allowed: ["kind", "listId"], required: ["kind"], path: "/query/scope")
      switch fields["kind"] {
      case .string("global"), .string("inbox"):
        _ = try object(value, allowed: ["kind"], required: ["kind"], path: "/query/scope")
        return fields["kind"] == .string("global") ? .global : .inbox
      case .string("list"):
        _ = try object(
          value, allowed: ["kind", "listId"], required: ["kind", "listId"], path: "/query/scope")
        guard case .string(let encoded) = fields["listId"],
          let identifier = UUID(uuidString: encoded)
        else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/scope/listId", message: "Expected a List UUID.")
        }
        return .list(identifier)
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/scope/kind",
          message: "Expected global, inbox or list scope.")
      }
    }

    private static func sort(_ value: Value?) throws -> PlannerItemQuery.Sort {
      guard let value else { return PlannerItemQuery.Sort() }
      let fields = try object(
        value, allowed: ["mode", "direction"], required: ["mode", "direction"], path: "/query/sort")
      guard case .string(let encodedMode) = fields["mode"],
        let mode = PlannerItemQuery.Sort.Mode(rawValue: encodedMode)
      else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/sort/mode", message: "Expected a declared sort mode.")
      }
      guard case .string(let encodedDirection) = fields["direction"],
        let direction = PlannerItemQuery.Sort.Direction(rawValue: encodedDirection)
      else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/sort/direction",
          message: "Expected ascending or descending.")
      }
      return PlannerItemQuery.Sort(mode: mode, direction: direction)
    }

    private static func rowPresentation(_ value: Value?) throws -> PlannerRowPresentationContext? {
      guard let value else { return nil }
      let fields = try object(
        value, allowed: ["referenceInstant", "displayTimeZone"],
        required: ["referenceInstant", "displayTimeZone"], path: "/query/rowPresentation")
      let referenceInstant: Double
      switch fields["referenceInstant"] {
      case .double(let number): referenceInstant = number
      case .int(let number): referenceInstant = Double(number)
      default:
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/rowPresentation/referenceInstant",
          message: "Expected a finite Foundation reference-date number.")
      }
      guard referenceInstant.isFinite else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/rowPresentation/referenceInstant",
          message: "Expected a finite Foundation reference-date number.")
      }
      guard case .string(let displayTimeZone) = fields["displayTimeZone"] else {
        throw AdmissionFailure(
          code: "invalidInput", path: "/query/rowPresentation/displayTimeZone",
          message: "Expected a timezone identifier.")
      }
      return PlannerRowPresentationContext(
        referenceInstant: Date(timeIntervalSinceReferenceDate: referenceInstant),
        displayTimeZone: displayTimeZone)
    }

    private static func object(
      _ value: Value?, allowed: Set<String>, required: Set<String>, path: String
    ) throws -> [String: Value] {
      guard case .object(let fields) = value else {
        throw AdmissionFailure(code: "invalidInput", path: path, message: "Expected an object.")
      }
      if let unknown = Set(fields.keys).subtracting(allowed).sorted().first {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw AdmissionFailure(
          code: "unknownField", path: path + "/" + escaped, message: "Unknown property: \(unknown)."
        )
      }
      if let missing = required.subtracting(fields.keys).sorted().first {
        throw AdmissionFailure(
          code: "invalidInput", path: path + "/" + missing,
          message: "Required property is missing: \(missing).")
      }
      return fields
    }

    private struct AdmissionFailure: Error {
      let code: String
      let path: String
      let message: String
    }
  }
#endif
