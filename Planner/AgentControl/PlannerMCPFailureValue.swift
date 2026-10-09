#if os(macOS)
  import MCP
  import PlannerCore

  enum PlannerMCPFailureValue {
    static func encode(_ reason: PlannerFailure) -> Value {
      let details: Value
      switch reason.details {
      case nil: details = .null
      case .staleSnapshot(let requestedGeneration, let currentGeneration):
        details = .object([
          "kind": .string("staleSnapshot"),
          "requestedGeneration": .string(requestedGeneration.uuidString),
          "currentGeneration": currentGeneration.map { .string($0.uuidString) } ?? .null,
        ])
      case .staleScheduleEdit(let form, let hash):
        details = .object([
          "kind": .string("staleEdit"), "conflictingFields": .array([.string("form")]),
          "currentValues": .object(["form": PlannerMCPRowValue.scheduleForm(form)]),
          "currentFieldHashes": .object(["form": .string(hash.value)]),
        ])
      case .staleListEdit(let fields, let values, let hashes):
        details = .object([
          "kind": .string("staleEdit"),
          "conflictingFields": .array(fields.map { .string($0.rawValue) }),
          "currentValues": .object(
            Dictionary(
              uniqueKeysWithValues: values.map { field, value in
                let encoded: Value
                switch value {
                case .string(let text): encoded = .string(text)
                case .optionalString(let text): encoded = text.map(Value.string) ?? .null
                case .optionalColor(let color):
                  encoded = color.map(PlannerMCPSourceTool.colorValue) ?? .null
                }
                return (field.rawValue, encoded)
              })),
          "currentFieldHashes": .object(
            Dictionary(
              uniqueKeysWithValues: hashes.map { ($0.key.rawValue, .string($0.value.value)) })),
        ])
      case .staleEdit(let fields, let values, let hashes):
        details = .object([
          "kind": .string("staleEdit"),
          "conflictingFields": .array(fields.map { .string($0.rawValue) }),
          "currentValues": .object(
            Dictionary(
              uniqueKeysWithValues: values.map { field, value in
                let encoded: Value
                switch value {
                case .string(let text): encoded = .string(text)
                case .optionalString(let text): encoded = text.map(Value.string) ?? .null
                case .optionalLocation(let location):
                  encoded = location.map(PlannerMCPSourceTool.locationValue) ?? .null
                case .links(let links): encoded = .array(links.map(PlannerMCPRowValue.link))
                }
                return (field.rawValue, encoded)
              })),
          "currentFieldHashes": .object(
            Dictionary(
              uniqueKeysWithValues: hashes.map { ($0.key.rawValue, .string($0.value.value)) })),
        ])
      }
      return .object([
        "code": .string(reason.code),
        "propertyPath": reason.propertyPath.map(Value.string) ?? .null,
        "message": .string(reason.message), "details": details,
      ])
    }
  }
#endif
