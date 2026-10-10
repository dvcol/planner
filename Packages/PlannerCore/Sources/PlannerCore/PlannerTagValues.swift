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

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .tag, id: id) }

  func read(datasetId: UUID) -> PlannerTagSourceRead {
    PlannerTagSourceRead(
      source: reference, sourceLifetimeId: lifetimeId, content: content,
      createdAt: createdAt, updatedAt: updatedAt, fieldHashes: fieldHashes(datasetId: datasetId),
      state: PlannerSourceState(globalDone: nil, archived: nil), references: [])
  }
}
