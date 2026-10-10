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

  func read(datasetId: UUID) -> PlannerCategorySourceRead {
    PlannerCategorySourceRead(
      source: reference, sourceLifetimeId: lifetimeId, content: content,
      createdAt: createdAt, updatedAt: updatedAt, fieldHashes: fieldHashes(datasetId: datasetId),
      state: PlannerSourceState(globalDone: nil, archived: nil), references: [])
  }
}
