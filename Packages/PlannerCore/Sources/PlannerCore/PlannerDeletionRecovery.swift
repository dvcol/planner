import Foundation

enum PortableDeletionTarget: Codable {
  case source(PlannerBoundIdentity)
  case membership(PlannerBoundIdentity)
  case itineraryEntry(id: UUID, lifetimeId: UUID)
  case labelAssociation(id: UUID, lifetimeId: UUID)

  private enum CodingKeys: String, CodingKey { case kind, source, membership, id, lifetimeId }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    switch try fields.decode(String.self, forKey: .kind) {
    case "source":
      self = .source(try fields.decode(PlannerBoundIdentity.self, forKey: .source))
    case "membership":
      self = .membership(try fields.decode(PlannerBoundIdentity.self, forKey: .membership))
    case "itineraryEntry":
      self = .itineraryEntry(
        id: try fields.decode(UUID.self, forKey: .id),
        lifetimeId: try fields.decode(UUID.self, forKey: .lifetimeId))
    case "labelAssociation":
      self = .labelAssociation(
        id: try fields.decode(UUID.self, forKey: .id),
        lifetimeId: try fields.decode(UUID.self, forKey: .lifetimeId))
    default:
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The deletion target kind is unsupported.")
    }
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .source(let source):
      try fields.encode("source", forKey: .kind)
      try fields.encode(source, forKey: .source)
    case .membership(let membership):
      try fields.encode("membership", forKey: .kind)
      try fields.encode(membership, forKey: .membership)
    case .itineraryEntry(let identifier, let lifetimeId):
      try fields.encode("itineraryEntry", forKey: .kind)
      try fields.encode(identifier, forKey: .id)
      try fields.encode(lifetimeId, forKey: .lifetimeId)
    case .labelAssociation(let identifier, let lifetimeId):
      try fields.encode("labelAssociation", forKey: .kind)
      try fields.encode(identifier, forKey: .id)
      try fields.encode(lifetimeId, forKey: .lifetimeId)
    }
  }
}

struct PortableDeletionMarker: Codable {
  let deletionId: UUID
  let operationId: UUID
  let target: PortableDeletionTarget
  let closedFamilyId: UUID?

  private enum CodingKeys: String, CodingKey {
    case deletionId, operationId, target, closedFamilyId
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(deletionId, forKey: .deletionId)
    try fields.encode(operationId, forKey: .operationId)
    try fields.encode(target, forKey: .target)
    try fields.encode(closedFamilyId, forKey: .closedFamilyId)
  }

  func validated(
    items: [PortableItemRecord], lists: [PortableListRecord],
    itineraries: [PortableItineraryRecord],
    schedules: [PortableScheduleRecord],
    categories: [PlannerPortableCategory],
    tags: [PlannerPortableTag],
    memberships: [PortableMembershipRecord],
    labelAssociations: [PortableLabelAssociationRecord], entries: [PortableItineraryEntryRecord]
  )
    throws
    -> PlannerPortableDeletionMarker
  {
    switch target {
    case .itineraryEntry(let identifier, let lifetimeId):
      guard closedFamilyId == nil,
        !entries.contains(where: { $0.id == identifier && $0.lifetimeId == lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The removed itinerary entry is still live or unsupported.")
      }
      return .init(
        deletionId: deletionId, operationId: operationId,
        target: .itineraryEntry(id: identifier, lifetimeId: lifetimeId), closedFamilyId: nil)
    case .source(let source):
      let kind: PlannerEntityKind
      let isLive: Bool
      switch source.kind {
      case "item":
        kind = .item
        isLive = items.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
      case "list":
        kind = .list
        isLive = lists.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
      case "itinerary":
        kind = .itinerary
        isLive = itineraries.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
      case "schedule":
        kind = .schedule
        isLive = schedules.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
      case "category":
        kind = .category
        isLive = categories.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
      case "tag":
        kind = .tag
        isLive = tags.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
      default:
        throw PlannerFailure("recoveryIntegrityFailure", "The deletion source kind is unsupported.")
      }
      guard closedFamilyId == nil, !isLive else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The deletion target is unsupported or still live.")
      }
      return PlannerPortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .source(
          PlannerEntityReference(kind: kind, id: source.id), lifetimeId: source.lifetimeId),
        closedFamilyId: closedFamilyId)
    case .membership(let membership):
      guard membership.kind == "membership", closedFamilyId == nil,
        !memberships.contains(where: {
          $0.id == membership.id && $0.lifetimeId == membership.lifetimeId
        })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The removed membership is unsupported or still live.")
      }
      return PlannerPortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .membership(id: membership.id, lifetimeId: membership.lifetimeId),
        closedFamilyId: nil)
    case .labelAssociation(let identifier, let lifetimeId):
      guard closedFamilyId == nil,
        !labelAssociations.contains(where: { $0.id == identifier && $0.lifetimeId == lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The removed label association is still live or unsupported.")
      }
      return PlannerPortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .labelAssociation(id: identifier, lifetimeId: lifetimeId), closedFamilyId: nil)
    }
  }
}
