import Foundation

public struct PlannerColor: Sendable, Equatable, Codable {
  public let red: Double
  public let green: Double
  public let blue: Double
  public let alpha: Double

  public init(red: Double, green: Double, blue: Double, alpha: Double) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }
}

public struct PlannerListContentInput: Sendable, Equatable, Codable {
  public let name: String
  public let notes: String?
  public let color: PlannerColor?
  public let iconName: String?

  public init(
    name: String, notes: String? = nil, color: PlannerColor? = nil, iconName: String? = nil
  ) {
    self.name = name
    self.notes = notes
    self.color = color
    self.iconName = iconName
  }
}

public typealias PlannerListContent = PlannerListContentInput

public enum PlannerListField: String, Sendable, CaseIterable { case name, notes, color, iconName }

public enum PlannerContainerProgressState: String, Sendable {
  case empty, complete, partial, unresolved
}

public struct PlannerContainerProgress: Sendable {
  public let container: PlannerEntityReference
  public let state: PlannerContainerProgressState
  public let doneCount: Int64?
  public let totalCount: Int64?
}

public struct PlannerListSourceRead: Sendable {
  public let source: PlannerEntityReference
  public let content: PlannerListContent
  public let createdAt: Date
  public let updatedAt: Date
  public let fieldHashes: [PlannerListField: PlannerFieldHash]
  public let state: PlannerSourceState
  public let progress: PlannerContainerProgress
  public let references: [PlannerReferenceRead]
}

extension PlannerColor {
  func validate(propertyPath: String) throws {
    for (name, value) in [("red", red), ("green", green), ("blue", blue), ("alpha", alpha)] {
      guard value.isFinite, (0...1).contains(value) else {
        throw PlannerFailure(
          "invalidInput", "Expected a finite sRGB component in 0...1.",
          propertyPath: propertyPath + "/" + name)
      }
    }
  }

  var canonicalValue: PlannerCanonicalValue {
    .record([
      "red": .double(red), "green": .double(green), "blue": .double(blue), "alpha": .double(alpha),
    ])
  }
}

extension PlannerListContentInput {
  func validate() throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw PlannerFailure(
        "invalidInput", "A List name is required.", propertyPath: "/command/content/name")
    }
    try color?.validate(propertyPath: "/command/content/color")
  }

  var canonicalContent: PlannerCanonicalValue {
    .record([
      "name": .string(name), "notes": .optional(notes.map(PlannerCanonicalValue.string)),
      "color": .optional(color.map(\.canonicalValue)),
      "iconName": .optional(iconName.map(PlannerCanonicalValue.string)),
    ])
  }

  private enum CodingKeys: String, CodingKey { case name, notes, color, iconName }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(name, forKey: .name)
    try fields.encode(notes, forKey: .notes)
    try fields.encode(color, forKey: .color)
    try fields.encode(iconName, forKey: .iconName)
  }
}

struct ListSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PlannerListContentInput
  let archived: Bool

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .list, id: id) }

  func read(datasetId: UUID) -> PlannerListSourceRead {
    PlannerListSourceRead(
      source: reference, content: content, createdAt: createdAt, updatedAt: updatedAt,
      fieldHashes: fieldHashes(datasetId: datasetId),
      state: PlannerSourceState(globalDone: nil, archived: archived),
      progress: PlannerContainerProgress(
        container: reference, state: .empty, doneCount: 0, totalCount: 0), references: [])
  }
}
