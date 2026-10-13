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
  public let manualEstimate: PlannerEstimate?

  public init(
    name: String, notes: String? = nil, color: PlannerColor? = nil, iconName: String? = nil,
    manualEstimate: PlannerEstimate? = nil
  ) {
    self.name = name
    self.notes = notes
    self.color = color
    self.iconName = iconName
    self.manualEstimate = manualEstimate
  }
}

public typealias PlannerListContent = PlannerListContentInput

public enum PlannerListField: String, Sendable, CaseIterable {
  case name, notes, color, iconName, manualEstimate
}

public enum PlannerListFieldValue: Sendable, Equatable {
  case string(String)
  case optionalString(String?)
  case optionalColor(PlannerColor?)
  case optionalEstimate(PlannerEstimate?)
}

public struct PlannerListChanges: Sendable {
  public let name: PlannerFieldChange<String>
  public let notes: PlannerFieldChange<String>
  public let color: PlannerFieldChange<PlannerColor>
  public let iconName: PlannerFieldChange<String>
  public let manualEstimate: PlannerFieldChange<PlannerEstimate>

  public init(
    name: PlannerFieldChange<String> = .unchanged,
    notes: PlannerFieldChange<String> = .unchanged,
    color: PlannerFieldChange<PlannerColor> = .unchanged,
    iconName: PlannerFieldChange<String> = .unchanged,
    manualEstimate: PlannerFieldChange<PlannerEstimate> = .unchanged
  ) {
    self.name = name
    self.notes = notes
    self.color = color
    self.iconName = iconName
    self.manualEstimate = manualEstimate
  }
}

public enum PlannerContainerProgressState: String, Sendable {
  case empty, complete, partial, unresolved
}

public struct PlannerContainerProgress: Sendable {
  public let container: PlannerEntityReference
  public let state: PlannerContainerProgressState
  public let doneCount: Int64?
  public let totalCount: Int64?
  public let archivedCount: Int64?

  public var finishedCount: Int64? {
    guard let doneCount, let archivedCount else { return nil }
    let (count, overflow) = doneCount.addingReportingOverflow(archivedCount)
    return overflow ? nil : count
  }

  init(
    container: PlannerEntityReference, state: PlannerContainerProgressState,
    doneCount: Int64?, totalCount: Int64?, archivedCount: Int64? = 0
  ) {
    self.container = container
    self.state = state
    self.doneCount = doneCount
    self.totalCount = totalCount
    self.archivedCount = doneCount == nil ? nil : archivedCount
  }
}

public struct PlannerListSourceRead: Sendable {
  public let source: PlannerEntityReference
  public let content: PlannerListContent
  public let createdAt: Date
  public let updatedAt: Date
  public let fieldHashes: [PlannerListField: PlannerFieldHash]
  public let state: PlannerSourceState
  public let progress: PlannerContainerProgress
  public let estimates: PlannerContainerEstimates
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
    try manualEstimate?.validate(propertyPath: "/command/content/manualEstimate")
  }

  var canonicalContent: PlannerCanonicalValue {
    var fields: [String: PlannerCanonicalValue] = [
      "name": .string(name), "notes": .optional(notes.map(PlannerCanonicalValue.string)),
      "color": .optional(color.map(\.canonicalValue)),
      "iconName": .optional(iconName.map(PlannerCanonicalValue.string)),
    ]
    /** Preserve creation replay for content written before this optional field existed. */
    if let manualEstimate { fields["manualEstimate"] = manualEstimate.canonicalValue }
    return .record(fields)
  }

  private enum CodingKeys: String, CodingKey { case name, notes, color, iconName, manualEstimate }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(name, forKey: .name)
    try fields.encode(notes, forKey: .notes)
    try fields.encode(color, forKey: .color)
    try fields.encode(iconName, forKey: .iconName)
    try fields.encode(manualEstimate.map(PortableEstimateRecord.init), forKey: .manualEstimate)
  }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    name = try fields.decode(String.self, forKey: .name)
    notes = try fields.decodeIfPresent(String.self, forKey: .notes)
    color = try fields.decodeIfPresent(PlannerColor.self, forKey: .color)
    iconName = try fields.decodeIfPresent(String.self, forKey: .iconName)
    manualEstimate = try fields.decodeIfPresent(
      PortableEstimateRecord.self, forKey: .manualEstimate)?.value
  }
}

extension PlannerListChanges {
  func validatedFields() throws -> [PlannerListField] {
    switch name {
    case .clear:
      throw PlannerFailure(
        "invalidInput", "A List name cannot be cleared.", propertyPath: "/command/changes/name")
    case .set(let value):
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PlannerFailure(
          "invalidInput", "A List name must contain text.", propertyPath: "/command/changes/name")
      }
    case .unchanged: break
    }
    if case .set(let value) = color { try value.validate(propertyPath: "/command/changes/color") }
    if case .set(let value) = manualEstimate {
      try value.validate(propertyPath: "/command/changes/manualEstimate")
    }
    var fields: [PlannerListField] = []
    if !name.isUnchanged { fields.append(.name) }
    if !notes.isUnchanged { fields.append(.notes) }
    if !color.isUnchanged { fields.append(.color) }
    if !iconName.isUnchanged { fields.append(.iconName) }
    if !manualEstimate.isUnchanged { fields.append(.manualEstimate) }
    guard !fields.isEmpty else {
      throw PlannerFailure(
        "invalidInput", "A List edit must contain at least one changed field.",
        propertyPath: "/command/changes")
    }
    return fields.sorted { $0.rawValue < $1.rawValue }
  }

  func applying(to content: PlannerListContent) -> PlannerListContent {
    var updatedName = content.name
    if case .set(let value) = name { updatedName = value }
    return PlannerListContent(
      name: updatedName, notes: optionalValue(notes, retaining: content.notes),
      color: optionalValue(color, retaining: content.color),
      iconName: optionalValue(iconName, retaining: content.iconName),
      manualEstimate: optionalValue(manualEstimate, retaining: content.manualEstimate))
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

struct ListSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PlannerListContentInput
  let archived: Bool

  var contentOrigins: [String: String]? = nil

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .list, id: id) }

  func fieldValue(_ field: PlannerListField) -> PlannerListFieldValue {
    switch field {
    case .name: .string(content.name)
    case .notes: .optionalString(content.notes)
    case .color: .optionalColor(content.color)
    case .iconName: .optionalString(content.iconName)
    case .manualEstimate: .optionalEstimate(content.manualEstimate)
    }
  }

  func read(
    datasetId: UUID, memberships: [MembershipSnapshot], items: [ContainerEstimateItemSnapshot],
    entries: [ItineraryEntrySnapshot] = []
  ) throws
    -> PlannerListSourceRead
  {
    let children = memberships.filter { $0.list.id == id }.sorted {
      if $0.rank != $1.rank { return $0.rank < $1.rank }
      return $0.id.uuidString < $1.id.uuidString
    }
    let summary = try ContainerEstimateListSnapshot(
      id: id, lifetimeId: lifetimeId, manualEstimate: content.manualEstimate, archived: archived
    ).progressAndEstimates(memberships: memberships, items: items)
    return PlannerListSourceRead(
      source: reference, content: content, createdAt: createdAt, updatedAt: updatedAt,
      fieldHashes: fieldHashes(datasetId: datasetId),
      state: PlannerSourceState(globalDone: nil, archived: archived),
      progress: summary.progress, estimates: summary.estimates,
      references: children.map(\.reference)
        + entries.filter {
          $0.source.kind == "list" && $0.source.id == id && $0.source.lifetimeId == lifetimeId
        }.sorted { $0.id.uuidString < $1.id.uuidString }.map(\.reference))
  }
}
