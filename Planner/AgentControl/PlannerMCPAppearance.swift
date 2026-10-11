#if os(macOS)
  import Foundation
  import MCP
  import PlannerCore

  enum PlannerMCPAppearance {
    private static let variants: [(kind: String, identifierFields: [String])] = [
      ("listMembership", ["listId", "membershipId"]),
      ("directItineraryItem", ["itineraryId", "entryId"]),
      ("expandedListItem", ["itineraryId", "listEntryId", "membershipId"]),
    ]

    static let schema = Value.object([
      "oneOf": .array(
        variants.map { variant in
          var properties: [String: Value] = [
            "kind": .object(["type": .string("string"), "const": .string(variant.kind)])
          ]
          for field in variant.identifierFields {
            properties[field] = .object(["type": .string("string"), "format": .string("uuid")])
          }
          return .object([
            "type": .string("object"), "additionalProperties": .bool(false),
            "required": .array((["kind"] + variant.identifierFields).map(Value.string)),
            "properties": .object(properties),
          ])
        })
    ])

    static func decode(_ value: Value?, path: String) throws -> PlannerAppearance {
      guard case .object(let fields) = value else {
        throw Failure(code: "invalidInput", path: path, message: "Expected an appearance object.")
      }
      guard case .string(let kind) = fields["kind"],
        let variant = variants.first(where: { $0.kind == kind })
      else {
        throw Failure(
          code: "invalidInput", path: path + "/kind",
          message: "Expected a supported exact appearance kind.")
      }
      let required = Set(["kind"] + variant.identifierFields)
      if let unknown = Set(fields.keys).subtracting(required).sorted().first {
        let escaped = unknown.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
          of: "/", with: "~1")
        throw Failure(
          code: "unknownField", path: path + "/" + escaped, message: "Unknown property: \(unknown)."
        )
      }
      if let missing = required.subtracting(fields.keys).sorted().first {
        throw Failure(
          code: "invalidInput", path: path + "/" + missing,
          message: "Required property is missing: \(missing).")
      }
      func identifier(_ field: String) throws -> UUID {
        guard case .string(let spelling) = fields[field],
          let identifier = UUID(uuidString: spelling)
        else {
          throw Failure(
            code: "invalidInput", path: path + "/" + field, message: "Expected an appearance UUID.")
        }
        return identifier
      }
      switch kind {
      case "listMembership":
        return .listMembership(
          listId: try identifier("listId"), membershipId: try identifier("membershipId"))
      case "directItineraryItem":
        return .directItineraryItem(
          itineraryId: try identifier("itineraryId"), entryId: try identifier("entryId"))
      case "expandedListItem":
        return .expandedListItem(
          itineraryId: try identifier("itineraryId"),
          listEntryId: try identifier("listEntryId"), membershipId: try identifier("membershipId"))
      default:
        throw Failure(
          code: "invalidInput", path: path + "/kind",
          message: "Expected a supported exact appearance kind.")
      }
    }

    struct Failure: Error {
      let code: String
      let path: String
      let message: String
    }
  }
#endif
