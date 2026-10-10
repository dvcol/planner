import Foundation

public struct PlannerCategoryContentInput: Sendable, Equatable, Codable {
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

public typealias PlannerCategoryContent = PlannerCategoryContentInput

public enum PlannerCategoryField: String, Sendable, CaseIterable { case name, color, iconName }

public enum PlannerCategoryFieldValue: Sendable, Equatable {
  case string(String)
  case optionalString(String?)
  case optionalColor(PlannerColor?)
}

public struct PlannerCategoryChanges: Sendable {
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

extension PlannerCategoryChanges {
  func validatedFields() throws -> [PlannerCategoryField] {
    switch name {
    case .clear:
      throw PlannerFailure(
        "invalidInput", "A Category name cannot be cleared.", propertyPath: "/command/changes/name")
    case .set(let value):
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PlannerFailure(
          "invalidInput", "A Category name must contain text.",
          propertyPath: "/command/changes/name")
      }
    case .unchanged: break
    }
    if case .set(let value) = color { try value.validate(propertyPath: "/command/changes/color") }
    var fields: [PlannerCategoryField] = []
    if !name.isUnchanged { fields.append(.name) }
    if !color.isUnchanged { fields.append(.color) }
    if !iconName.isUnchanged { fields.append(.iconName) }
    guard !fields.isEmpty else {
      throw PlannerFailure(
        "invalidInput", "A Category edit must contain at least one changed field.",
        propertyPath: "/command/changes")
    }
    return fields.sorted { $0.rawValue < $1.rawValue }
  }

  func applying(to content: PlannerCategoryContent) -> PlannerCategoryContent {
    var updatedName = content.name
    if case .set(let value) = name { updatedName = value }
    return PlannerCategoryContent(
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

public struct PlannerCategorySourceRead: Sendable {
  public let source: PlannerEntityReference
  public let sourceLifetimeId: UUID
  public let content: PlannerCategoryContent
  public let createdAt: Date
  public let updatedAt: Date
  public let fieldHashes: [PlannerCategoryField: PlannerFieldHash]
  public let state: PlannerSourceState
  public let references: [PlannerReferenceRead]
}

extension PlannerCategoryContentInput {
  func validate() throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw PlannerFailure(
        "invalidInput", "A Category name is required.", propertyPath: "/command/content/name")
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

struct CategorySnapshot {
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PlannerCategoryContent

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .category, id: id) }

  func fieldValue(_ field: PlannerCategoryField) -> PlannerCategoryFieldValue {
    switch field {
    case .name: .string(content.name)
    case .color: .optionalColor(content.color)
    case .iconName: .optionalString(content.iconName)
    }
  }

  func read(datasetId: UUID) -> PlannerCategorySourceRead {
    PlannerCategorySourceRead(
      source: reference, sourceLifetimeId: lifetimeId, content: content,
      createdAt: createdAt, updatedAt: updatedAt, fieldHashes: fieldHashes(datasetId: datasetId),
      state: PlannerSourceState(globalDone: nil, archived: nil), references: [])
  }
}
