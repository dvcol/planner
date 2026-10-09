#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPSourceTool {
    static let definition = Tool(
      name: "planner_read", description: "Read a source Item from the local Planner prototype.",
      inputSchema: .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array([.string("formatVersion"), .string("request")]),
        "properties": .object([
          "formatVersion": .object(["type": .string("integer"), "const": .int(1)]),
          "request": .object([
            "type": .string("object"), "additionalProperties": .bool(false),
            "required": .array([.string("kind"), .string("source")]),
            "properties": .object([
              "kind": .object(["type": .string("string"), "const": .string("source")]),
              "source": .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("kind"), .string("id")]),
                "properties": .object([
                  "kind": .object(["type": .string("string"), "const": .string("item")]),
                  "id": .object(["type": .string("string"), "format": .string("uuid")]),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
      annotations: .init(
        readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    static func call(
      _ parameters: CallTool.Parameters, planner: PlannerCore.Planner,
      session: PlannerDatasetSession
    ) async -> CallTool.Result {
      guard parameters.name == "planner_read" else {
        return failure(
          code: "invalidInput", message: "This read-only prototype does not implement that tool.")
      }
      do {
        let arguments = try object(
          parameters.arguments.map(Value.object), keys: ["formatVersion", "request"], path: "")
        guard arguments["formatVersion"] == .int(1) else {
          throw AdmissionFailure(
            code: "unsupportedVersion", path: "/formatVersion",
            message: "Expected adapter format version 1.")
        }
        let request = try object(arguments["request"], keys: ["kind", "source"], path: "/request")
        guard request["kind"] == .string("source") else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/request/kind",
            message: "This prototype supports source reads.")
        }
        let source = try object(request["source"], keys: ["kind", "id"], path: "/request/source")
        guard source["kind"] == .string("item") else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/request/source/kind",
            message: "This prototype supports Item sources.")
        }
        guard case .string(let spelling) = source["id"], let identity = UUID(uuidString: spelling)
        else {
          throw AdmissionFailure(
            code: "invalidInput", path: "/request/source/id",
            message: "Expected a Planner Item UUID.")
        }
        let result = await planner.read(
          session: session, request: .source(PlannerEntityReference(kind: .item, id: identity)))
        switch result {
        case .failed(let reason):
          return failure(code: reason.code, message: reason.message, path: reason.propertyPath)
        case .source(let read):
          guard read.content.links.isEmpty, read.content.categoryIds.isEmpty,
            read.content.tagIds.isEmpty,
            read.labels.isEmpty, read.references.isEmpty
          else {
            return failure(
              code: "unavailable",
              message: "This first read slice does not yet encode source associations.")
          }
          return CallTool.Result(
            content: [.text(text: "Read \(read.content.title).", annotations: nil, _meta: nil)],
            structuredContent: .object([
              "formatVersion": .int(1), "kind": .string("source"), "value": sourceValue(read),
            ]),
            isError: false
          )
        }
      } catch let reason as AdmissionFailure {
        return failure(code: reason.code, message: reason.message, path: reason.path)
      } catch {
        return failure(code: "unavailable", message: "The Planner read could not be completed.")
      }
    }

    static func failure(code: String, message: String, path: String? = nil) -> CallTool.Result {
      CallTool.Result(
        content: [.text(text: message, annotations: nil, _meta: nil)],
        structuredContent: .object([
          "formatVersion": .int(1), "state": .string("failed"),
          "reason": .object([
            "code": .string(code), "propertyPath": path.map(Value.string) ?? .null,
            "message": .string(message), "details": .null,
          ]),
        ]), isError: true
      )
    }

    private static func object(_ value: Value?, keys: Set<String>, path: String) throws -> [String:
      Value]
    {
      guard case .object(let fields) = value else {
        throw AdmissionFailure(code: "invalidInput", path: path, message: "Expected an object.")
      }
      if let unknown = Set(fields.keys).subtracting(keys).sorted().first {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw AdmissionFailure(
          code: "unknownField", path: path + "/" + escaped, message: "Unknown property: \(unknown)."
        )
      }
      if let missing = keys.subtracting(fields.keys).sorted().first {
        throw AdmissionFailure(
          code: "invalidInput", path: path + "/" + missing,
          message: "Required property is missing: \(missing).")
      }
      return fields
    }

    private static func sourceValue(_ read: PlannerSourceRead) -> Value {
      .object([
        "source": .object([
          "kind": .string(read.source.kind.rawValue), "id": .string(read.source.id.uuidString),
        ]),
        "content": .object([
          "title": .string(read.content.title),
          "subtitle": read.content.subtitle.map(Value.string) ?? .null,
          "notes": read.content.notes.map(Value.string) ?? .null,
          "location": read.content.location.map(locationValue) ?? .null,
          "estimate": read.content.estimate.map { estimate in
            .object([
              "minutes": .string(String(estimate.minutes)),
              "displayUnit": .string(estimate.displayUnit.rawValue),
            ])
          } ?? .null,
          "links": .array([]), "categoryIds": .array([]), "tagIds": .array([]),
        ]),
        "createdAt": .double(read.createdAt.timeIntervalSinceReferenceDate),
        "updatedAt": .double(read.updatedAt.timeIntervalSinceReferenceDate),
        "fieldHashes": .object(
          Dictionary(
            uniqueKeysWithValues: read.fieldHashes.map {
              ($0.key.rawValue, .string($0.value.value))
            })),
        "state": .object([
          "globalDone": read.state.globalDone.map(Value.bool) ?? .null,
          "archived": read.state.archived.map(Value.bool) ?? .null,
        ]),
        "labels": .array([]), "references": .array([]), "progress": .null,
      ])
    }

    private static func locationValue(_ location: PlannerOwnedLocation) -> Value {
      .object([
        "displayName": location.displayName.map(Value.string) ?? .null,
        "formattedAddress": location.formattedAddress.map(Value.string) ?? .null,
        "coordinate": location.coordinate.map {
          .object(["latitude": .double($0.latitude), "longitude": .double($0.longitude)])
        } ?? .null,
      ])
    }

    private struct AdmissionFailure: Error {
      let code: String
      let path: String
      let message: String
    }
  }
#endif
