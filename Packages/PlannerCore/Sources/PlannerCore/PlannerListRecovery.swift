import Foundation

public struct PlannerPortableList: Sendable {
  public let id: UUID
  public let lifetimeId: UUID
  public let createdAt: Date
  public let updatedAt: Date
  public let content: PlannerListContent
  public let archived: Bool
  public let contentOrigins: [String: String]
}

public enum PlannerPortableSource: Sendable {
  case item(PlannerPortableItem)
  case list(PlannerPortableList)

  public var id: UUID {
    switch self {
    case .item(let item): item.id
    case .list(let list): list.id
    }
  }

  public var kind: PlannerEntityKind {
    switch self {
    case .item: .item
    case .list: .list
    }
  }
}

struct PortableListRecord: Codable {
  let kind: PlannerEntityKind
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PlannerListContent
  let archived: Bool
  let contentOrigins: [String: String]

  init(_ list: ListSnapshot) {
    kind = .list
    id = list.id
    lifetimeId = list.lifetimeId
    createdAt = list.createdAt
    updatedAt = list.updatedAt
    content = list.content
    archived = list.archived
    var origins = ["name": "independent"]
    if content.notes != nil { origins["notes"] = "independent" }
    contentOrigins = origins
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
    content = try fields.decode(PlannerListContent.self, forKey: .content)
    archived = try fields.decode(Bool.self, forKey: .archived)
    contentOrigins = try fields.decode([String: String].self, forKey: .contentOrigins)
    guard try fields.decode(Bool?.self, forKey: .globalDone) == nil else {
      throw PlannerFailure("recoveryIntegrityFailure", "Lists have no global completion flag.")
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
    try fields.encode(archived, forKey: .archived)
    try fields.encode(contentOrigins, forKey: .contentOrigins)
  }

  func validated() throws -> PlannerPortableList {
    guard kind == .list, createdAt.timeIntervalSinceReferenceDate.isFinite,
      updatedAt.timeIntervalSinceReferenceDate.isFinite
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot has invalid List identity or dates.")
    }
    try content.validate()
    let expected = PortableListRecord(
      ListSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        content: content, archived: archived)
    ).contentOrigins
    guard contentOrigins == expected else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot has inconsistent List content origins.")
    }
    return PlannerPortableList(
      id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt, content: content,
      archived: archived, contentOrigins: contentOrigins)
  }
}

enum PortableSourceRecord: Codable {
  case item(PortableItemRecord)
  case list(PortableListRecord)

  private enum CodingKeys: String, CodingKey { case kind }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    switch try fields.decode(PlannerEntityKind.self, forKey: .kind) {
    case .item: self = .item(try PortableItemRecord(from: decoder))
    case .list: self = .list(try PortableListRecord(from: decoder))
    default:
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The source kind is not supported by this snapshot slice.")
    }
  }

  func encode(to encoder: any Encoder) throws {
    switch self {
    case .item(let item): try item.encode(to: encoder)
    case .list(let list): try list.encode(to: encoder)
    }
  }

  var id: UUID {
    switch self {
    case .item(let item): item.id
    case .list(let list): list.id
    }
  }
}
