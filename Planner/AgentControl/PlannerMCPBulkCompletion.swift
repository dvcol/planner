#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPBulkCompletion {
    struct Failure: Error {
      let code: String
      let path: String
      let message: String
    }

    static let schema: Value = .object([
      "type": .string("object"), "additionalProperties": .bool(false),
      "required": .array([.string("type"), .string("scope"), .string("done")]),
      "properties": .object([
        "type": .object(["type": .string("string"), "const": .string("setBulkCompletion")]),
        "done": .object(["type": .string("boolean")]),
        "scope": .object([
          "oneOf": .array([
            scopeSchema("list", identifiers: ["listId"]),
            scopeSchema("itinerary", identifiers: ["itineraryId"]),
            scopeSchema("itineraryListEntry", identifiers: ["itineraryId", "listEntryId"]),
          ])
        ]),
      ]),
    ])

    static func command(_ value: Value?) throws -> PlannerCommand {
      let fields = try object(
        value, allowed: ["type", "scope", "done"],
        required: ["type", "scope", "done"], path: "/command")
      guard fields["type"] == .string("setBulkCompletion") else {
        throw Failure(
          code: "invalidInput", path: "/command/type", message: "Expected setBulkCompletion.")
      }
      guard case .bool(let done) = fields["done"] else {
        throw Failure(
          code: "invalidInput", path: "/command/done", message: "Expected a completion Boolean.")
      }
      let scope = try object(
        fields["scope"],
        allowed: ["kind", "listId", "itineraryId", "listEntryId"], required: ["kind"],
        path: "/command/scope")
      switch scope["kind"] {
      case .string("list"):
        _ = try object(
          fields["scope"], allowed: ["kind", "listId"],
          required: ["kind", "listId"], path: "/command/scope")
        return .setBulkCompletion(
          scope: .list(listId: try identifier(scope["listId"], field: "listId")), done: done)
      case .string("itinerary"):
        _ = try object(
          fields["scope"], allowed: ["kind", "itineraryId"],
          required: ["kind", "itineraryId"], path: "/command/scope")
        return .setBulkCompletion(
          scope: .itinerary(
            itineraryId: try identifier(scope["itineraryId"], field: "itineraryId")), done: done)
      case .string("itineraryListEntry"):
        _ = try object(
          fields["scope"], allowed: ["kind", "itineraryId", "listEntryId"],
          required: ["kind", "itineraryId", "listEntryId"], path: "/command/scope")
        return .setBulkCompletion(
          scope: .itineraryListEntry(
            itineraryId: try identifier(scope["itineraryId"], field: "itineraryId"),
            listEntryId: try identifier(scope["listEntryId"], field: "listEntryId")), done: done)
      default:
        throw Failure(
          code: "invalidInput", path: "/command/scope/kind",
          message: "Expected list, itinerary or itineraryListEntry.")
      }
    }

    static func commandValue(_ command: PlannerCommand) throws -> Value {
      guard case .setBulkCompletion(let scope, let done) = command else {
        throw Failure(
          code: "invalidInput", path: "/command/type",
          message: "Expected a reviewable bulk command.")
      }
      let scopeValue: Value
      switch scope {
      case .list(let listId):
        scopeValue = .object(["kind": .string("list"), "listId": .string(listId.uuidString)])
      case .itinerary(let itineraryId):
        scopeValue = .object([
          "kind": .string("itinerary"), "itineraryId": .string(itineraryId.uuidString),
        ])
      case .itineraryListEntry(let itineraryId, let listEntryId):
        scopeValue = .object([
          "kind": .string("itineraryListEntry"),
          "itineraryId": .string(itineraryId.uuidString),
          "listEntryId": .string(listEntryId.uuidString),
        ])
      }
      return .object([
        "type": .string("setBulkCompletion"), "scope": scopeValue, "done": .bool(done),
      ])
    }

    static func object(_ value: Value?, allowed: Set<String>, required: Set<String>, path: String)
      throws -> [String: Value]
    {
      guard case .object(let fields) = value else {
        throw Failure(code: "invalidInput", path: path, message: "Expected an object.")
      }
      if let key = fields.keys.filter({ !allowed.contains($0) }).sorted().first {
        let escaped = key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw Failure(
          code: "unknownField", path: path + "/" + escaped, message: "This field is not allowed.")
      }
      if let key = required.sorted().first(where: { fields[$0] == nil }) {
        throw Failure(
          code: "invalidInput", path: path + "/" + key, message: "This field is required.")
      }
      return fields
    }

    private static func identifier(_ value: Value?, field: String) throws -> UUID {
      guard case .string(let encoded) = value, let identifier = UUID(uuidString: encoded) else {
        throw Failure(
          code: "invalidInput", path: "/command/scope/" + field, message: "Expected a UUID.")
      }
      return identifier
    }

    private static func scopeSchema(_ kind: String, identifiers: [String]) -> Value {
      var properties: [String: Value] = [
        "kind": .object(["type": .string("string"), "const": .string(kind)])
      ]
      for identifier in identifiers {
        properties[identifier] = .object(["type": .string("string"), "format": .string("uuid")])
      }
      return .object([
        "type": .string("object"), "additionalProperties": .bool(false),
        "required": .array((["kind"] + identifiers).map(Value.string)),
        "properties": .object(properties),
      ])
    }
  }
#endif
