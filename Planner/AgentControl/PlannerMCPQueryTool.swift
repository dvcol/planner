#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPQueryTool {
    static let definition = Tool(
      name: "planner_query",
      description: "Discover Item identities in the local Planner prototype.",
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
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("kind")]),
                "properties": .object([
                  "kind": .object([
                    "type": .string("string"),
                    "enum": .array([.string("global"), .string("inbox")]),
                  ])
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
            "duration", "scheduled", "hasAddress", "hasLinks", "sort",
          ], required: ["kind", "scope"], path: "/query")
        guard query["kind"] == .string("items") else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/kind",
            message: "This prototype supports Item queries.")
        }
        if let unsupported = Set(query.keys).subtracting(["kind", "scope", "completion", "archive"])
          .sorted().first
        {
          throw AdmissionFailure(
            code: "unavailable", path: "/query/" + unsupported,
            message: "This query slice supports scope, completion and archive only.")
        }
        let scope = try object(
          query["scope"], allowed: ["kind"], required: ["kind"], path: "/query/scope")
        let nativeScope: PlannerItemQuery.Scope
        switch scope["kind"] {
        case .string("global"): nativeScope = .global
        case .string("inbox"): nativeScope = .inbox
        default:
          throw AdmissionFailure(
            code: "invalidInput", path: "/query/scope/kind",
            message: "Expected global or inbox scope.")
        }
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
        let queried = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              PlannerItemQuery(scope: nativeScope, completion: completion, archive: archive))))
        switch queried {
        case .failed(let reason):
          return PlannerMCPSourceTool.failure(
            code: reason.code, message: reason.message, path: reason.propertyPath)
        case .snapshot(let snapshot):
          let value = Value.object([
            "formatVersion": .int(1), "generation": .string(snapshot.generation.uuidString),
            "matchingCount": .string(String(snapshot.matchingCount)),
            "rows": .array(
              snapshot.rows.map { row in
                switch row {
                case .source(let source):
                  return .object([
                    "kind": .string("source"),
                    "source": .object([
                      "kind": .string(source.kind.rawValue), "id": .string(source.id.uuidString),
                    ]),
                  ])
                }
              }),
            "unresolvedReferences": .array([]), "progress": .array([]),
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
