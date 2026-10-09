import Foundation

struct PortableOwnedLink: Codable {
  let id: UUID
  let lifetimeId: UUID
  let owner: PlannerBoundIdentity
  let rank: String
  let originalUrl: String
  let label: String?
  let kind: PlannerLinkKind
  let providerReference: PlannerProviderReference?

  enum CodingKeys: String, CodingKey {
    case id, lifetimeId, owner, rank, originalUrl, label, kind, providerReference
  }

  init(_ link: OwnedLinkSnapshot, owner: ItemSnapshot) {
    id = link.id
    lifetimeId = link.lifetimeId
    self.owner = PlannerBoundIdentity(kind: "item", id: owner.id, lifetimeId: owner.lifetimeId)
    rank = String(link.rank)
    originalUrl = link.originalUrl
    label = link.label
    kind = link.kind
    providerReference = nil
  }

  func validated(sources: [PortableItemRecord]) throws -> ValidatedPortableLink {
    guard owner.kind == "item",
      sources.contains(where: { $0.id == owner.id && $0.lifetimeId == owner.lifetimeId }),
      let parsedRank = Int64(rank), String(parsedRank) == rank,
      providerReference == nil
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The owned link has invalid ownership or values.")
    }
    let input = PlannerLinkInput(originalUrl: originalUrl, label: label)
    guard try input.validatedKind(propertyPath: "/ownedLinks") == kind else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The owned link classification is inconsistent.")
    }
    return ValidatedPortableLink(
      ownerId: owner.id, id: id, rank: parsedRank,
      read: PlannerOwnedLinkRead(
        linkId: id, originalUrl: originalUrl, label: label, kind: kind, providerReference: nil))
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(lifetimeId, forKey: .lifetimeId)
    try container.encode(owner, forKey: .owner)
    try container.encode(rank, forKey: .rank)
    try container.encode(originalUrl, forKey: .originalUrl)
    try container.encode(label, forKey: .label)
    try container.encode(kind, forKey: .kind)
    try container.encode(providerReference, forKey: .providerReference)
  }
}

struct ValidatedPortableLink {
  let ownerId: UUID
  let id: UUID
  let rank: Int64
  let read: PlannerOwnedLinkRead
}
