import Foundation

public struct PlannerPortableCategory: Sendable {
  public let id: UUID
  public let lifetimeId: UUID
  public let createdAt: Date
  public let updatedAt: Date
  public let content: PlannerCategoryContent
  public let contentOrigins: [String: String]
}

struct PortableCategoryRecord: Codable {
  let kind: PlannerEntityKind
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PlannerCategoryContent
  let contentOrigins: [String: String]

  init(_ category: CategorySnapshot) {
    kind = .category
    id = category.id
    lifetimeId = category.lifetimeId
    createdAt = category.createdAt
    updatedAt = category.updatedAt
    content = category.content
    contentOrigins = ["name": "independent"]
  }

  private enum CodingKeys: String, CodingKey {
    case kind, id, lifetimeId, createdAt, updatedAt, content, globalDone, archived, contentOrigins
  }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    kind = try fields.decode(PlannerEntityKind.self, forKey: .kind)
    id = try fields.decode(UUID.self, forKey: .id)
    lifetimeId = try fields.decode(UUID.self, forKey: .lifetimeId)
    createdAt = try fields.decode(Date.self, forKey: .createdAt)
    updatedAt = try fields.decode(Date.self, forKey: .updatedAt)
    content = try fields.decode(PlannerCategoryContent.self, forKey: .content)
    contentOrigins = try fields.decode([String: String].self, forKey: .contentOrigins)
    guard try fields.decode(Bool?.self, forKey: .globalDone) == nil,
      try fields.decode(Bool?.self, forKey: .archived) == nil
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Categories have no completion or archive flag.")
    }
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(kind, forKey: .kind)
    try fields.encode(id, forKey: .id)
    try fields.encode(lifetimeId, forKey: .lifetimeId)
    try fields.encode(createdAt, forKey: .createdAt)
    try fields.encode(updatedAt, forKey: .updatedAt)
    try fields.encode(content, forKey: .content)
    try fields.encode(Bool?.none, forKey: .globalDone)
    try fields.encode(Bool?.none, forKey: .archived)
    try fields.encode(contentOrigins, forKey: .contentOrigins)
  }

  func validated() throws -> PlannerPortableCategory {
    guard kind == .category, createdAt.timeIntervalSinceReferenceDate.isFinite,
      updatedAt.timeIntervalSinceReferenceDate.isFinite, contentOrigins == ["name": "independent"]
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot has invalid Category identity, dates or origins.")
    }
    try content.validate()
    return PlannerPortableCategory(
      id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt, content: content,
      contentOrigins: contentOrigins)
  }
}
