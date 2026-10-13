import Foundation

public struct PlannerTagContentInput: Sendable, Equatable, Codable {
  public let name: String
  public let color: PlannerColor?
  public let iconName: String?

  public init(name: String, color: PlannerColor? = nil, iconName: String? = nil) {
    self.name = name
    self.color = color
    self.iconName = iconName
  }

  private enum CodingKeys: String, CodingKey { case name, color, iconName }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(name, forKey: .name)
    try fields.encode(color, forKey: .color)
    try fields.encode(iconName, forKey: .iconName)
  }
}

public typealias PlannerTagContent = PlannerTagContentInput

public enum PlannerTagField: String, Sendable, CaseIterable { case name, color, iconName }

public enum PlannerTagFieldValue: Sendable, Equatable {
  case string(String)
  case optionalString(String?)
  case optionalColor(PlannerColor?)
}

public struct PlannerTagChanges: Sendable {
  public let name: PlannerFieldChange<String>
  public let color: PlannerFieldChange<PlannerColor>
  public let iconName: PlannerFieldChange<String>

  public init(
    name: PlannerFieldChange<String> = .unchanged,
    color: PlannerFieldChange<PlannerColor> = .unchanged,
    iconName: PlannerFieldChange<String> = .unchanged
  ) {
    self.name = name
    self.color = color
    self.iconName = iconName
  }
}

extension PlannerTagChanges {
  func validatedFields() throws -> [PlannerTagField] {
    switch name {
    case .clear:
      throw PlannerFailure(
        "invalidInput", "A Tag name cannot be cleared.", propertyPath: "/command/changes/name")
    case .set(let value):
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PlannerFailure(
          "invalidInput", "A Tag name must contain text.",
          propertyPath: "/command/changes/name")
      }
    case .unchanged: break
    }
    if case .set(let value) = color { try value.validate(propertyPath: "/command/changes/color") }
    var fields: [PlannerTagField] = []
    if !name.isUnchanged { fields.append(.name) }
    if !color.isUnchanged { fields.append(.color) }
    if !iconName.isUnchanged { fields.append(.iconName) }
    guard !fields.isEmpty else {
      throw PlannerFailure(
        "invalidInput", "A Tag edit must contain at least one changed field.",
        propertyPath: "/command/changes")
    }
    return fields.sorted { $0.rawValue < $1.rawValue }
  }

  func applying(to content: PlannerTagContent) -> PlannerTagContent {
    var updatedName = content.name
    if case .set(let value) = name { updatedName = value }
    return PlannerTagContent(
      name: updatedName, color: optionalValue(color, retaining: content.color),
      iconName: optionalValue(iconName, retaining: content.iconName))
  }

  private func optionalValue<Value>(
    _ change: PlannerFieldChange<Value>, retaining current: Value?
  ) -> Value? {
    switch change {
    case .set(let value): value
    case .clear: nil
    case .unchanged: current
    }
  }
}

public struct PlannerTagSourceRead: Sendable {
  public let source: PlannerEntityReference
  public let sourceLifetimeId: UUID
  public let content: PlannerTagContent
  public let createdAt: Date
  public let updatedAt: Date
  public let fieldHashes: [PlannerTagField: PlannerFieldHash]
  public let state: PlannerSourceState
  public let references: [PlannerReferenceRead]
}

extension PlannerTagContentInput {
  func validate() throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw PlannerFailure(
        "invalidInput", "A Tag name is required.", propertyPath: "/command/content/name")
    }
    try color?.validate(propertyPath: "/command/content/color")
  }

  var canonicalContent: PlannerCanonicalValue {
    .record([
      "name": .string(name), "color": .optional(color.map(\.canonicalValue)),
      "iconName": .optional(iconName.map(PlannerCanonicalValue.string)),
    ])
  }
}

struct TagSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PlannerTagContent
  var associations: [LabelAssociationSnapshot] = []

  var contentOrigins: [String: String]? = nil

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .tag, id: id) }

  func fieldValue(_ field: PlannerTagField) -> PlannerTagFieldValue {
    switch field {
    case .name: .string(content.name)
    case .color: .optionalColor(content.color)
    case .iconName: .optionalString(content.iconName)
    }
  }

  func read(datasetId: UUID) -> PlannerTagSourceRead {
    PlannerTagSourceRead(
      source: reference, sourceLifetimeId: lifetimeId, content: content,
      createdAt: createdAt, updatedAt: updatedAt, fieldHashes: fieldHashes(datasetId: datasetId),
      state: PlannerSourceState(globalDone: nil, archived: nil),
      references: associations.sorted { $0.id.uuidString < $1.id.uuidString }.map(\.reference))
  }
}
