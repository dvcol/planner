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
    self.init(
      link, owner: PlannerBoundIdentity(kind: "item", id: owner.id, lifetimeId: owner.lifetimeId))
  }

  init(_ link: OwnedLinkSnapshot, owner: ItinerarySnapshot) {
    self.init(
      link,
      owner: PlannerBoundIdentity(kind: "itinerary", id: owner.id, lifetimeId: owner.lifetimeId))
  }

  private init(_ link: OwnedLinkSnapshot, owner: PlannerBoundIdentity) {
    id = link.id
    lifetimeId = link.lifetimeId
    self.owner = owner
    rank = String(link.rank)
    originalUrl = link.originalUrl
    label = link.label
    kind = link.kind
    providerReference = link.providerReference
  }

  func validated(sources: [PortableItemRecord], itineraries: [PortableItineraryRecord]) throws
    -> ValidatedPortableLink
  {
    let ownerKind: PlannerEntityKind
    switch owner.kind {
    case "item":
      guard sources.contains(where: { $0.id == owner.id && $0.lifetimeId == owner.lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The owned link has an unresolved Item owner.")
      }
      ownerKind = .item
    case "itinerary":
      guard itineraries.contains(where: { $0.id == owner.id && $0.lifetimeId == owner.lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The owned link has an unresolved Itinerary owner.")
      }
      ownerKind = .itinerary
    default:
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The owned link has an unsupported owner kind.")
    }
    guard
      let parsedRank = Int64(rank), String(parsedRank) == rank,
      providerReference?.isValid(for: kind) != false
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
      owner: PlannerEntityReference(kind: ownerKind, id: owner.id), id: id, rank: parsedRank,
      read: PlannerOwnedLinkRead(
        linkId: id, originalUrl: originalUrl, label: label, kind: kind,
        providerReference: providerReference))
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
  let owner: PlannerEntityReference
  let id: UUID
  let rank: Int64
  let read: PlannerOwnedLinkRead
}
