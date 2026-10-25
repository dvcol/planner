import Foundation

enum PortableDeletionTarget: Codable {
  case source(PlannerBoundIdentity)
  case membership(PlannerBoundIdentity)
  case itineraryEntry(id: UUID, lifetimeId: UUID)
  case labelAssociation(id: UUID, lifetimeId: UUID)
  case ownedLink(id: UUID, lifetimeId: UUID)
  case expandedCompletion(PlannerExpandedContext)

  private enum CodingKeys: String, CodingKey {
    case kind, source, membership, id, lifetimeId, context
  }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    switch try fields.decode(String.self, forKey: .kind) {
    case "source":
      self = .source(try fields.decode(PlannerBoundIdentity.self, forKey: .source))
    case "membership":
      if fields.contains(.membership) {
        self = .membership(try fields.decode(PlannerBoundIdentity.self, forKey: .membership))
      } else {
        self = .membership(
          .init(
            kind: "membership", id: try fields.decode(UUID.self, forKey: .id),
            lifetimeId: try fields.decode(UUID.self, forKey: .lifetimeId)))
      }
    case "itineraryEntry":
      self = .itineraryEntry(
        id: try fields.decode(UUID.self, forKey: .id),
        lifetimeId: try fields.decode(UUID.self, forKey: .lifetimeId))
    case "labelAssociation":
      self = .labelAssociation(
        id: try fields.decode(UUID.self, forKey: .id),
        lifetimeId: try fields.decode(UUID.self, forKey: .lifetimeId))
    case "ownedLink":
      self = .ownedLink(
        id: try fields.decode(UUID.self, forKey: .id),
        lifetimeId: try fields.decode(UUID.self, forKey: .lifetimeId))
    case "expandedCompletion":
      self = .expandedCompletion(try fields.decode(PlannerExpandedContext.self, forKey: .context))
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
      try fields.encode(membership.id, forKey: .id)
      try fields.encode(membership.lifetimeId, forKey: .lifetimeId)
    case .itineraryEntry(let identifier, let lifetimeId):
      try fields.encode("itineraryEntry", forKey: .kind)
      try fields.encode(identifier, forKey: .id)
      try fields.encode(lifetimeId, forKey: .lifetimeId)
    case .labelAssociation(let identifier, let lifetimeId):
      try fields.encode("labelAssociation", forKey: .kind)
      try fields.encode(identifier, forKey: .id)
      try fields.encode(lifetimeId, forKey: .lifetimeId)
    case .ownedLink(let identifier, let lifetimeId):
      try fields.encode("ownedLink", forKey: .kind)
      try fields.encode(identifier, forKey: .id)
      try fields.encode(lifetimeId, forKey: .lifetimeId)
    case .expandedCompletion(let context):
      try fields.encode("expandedCompletion", forKey: .kind)
      try fields.encode(context, forKey: .context)
    }
  }
}

struct PortableDeletionMarker: Codable {
  let deletionId: UUID
  let operationId: UUID
  let target: PortableDeletionTarget
  let closedFamilyId: UUID?

  func closingRestorationFamily(_ families: [PlannerPortableRestorationFamily]) throws
    -> PortableDeletionMarker
  {
    let identity: PlannerPortableBoundIdentity
    switch target {
    case .source(let source), .membership(let source):
      guard let kind = PlannerPortableIdentityKind(rawValue: source.kind) else {
        throw PlannerFailure("readUnavailable", "The deletion identity kind cannot resolve.")
      }
      identity = .init(kind: kind, id: source.id, lifetimeId: source.lifetimeId)
    case .itineraryEntry(let identifier, let lifetimeIdentifier):
      identity = .init(kind: .itineraryEntry, id: identifier, lifetimeId: lifetimeIdentifier)
    case .labelAssociation(let identifier, let lifetimeIdentifier):
      identity = .init(kind: .labelAssociation, id: identifier, lifetimeId: lifetimeIdentifier)
    case .ownedLink(let identifier, let lifetimeIdentifier):
      identity = .init(kind: .ownedLink, id: identifier, lifetimeId: lifetimeIdentifier)
    case .expandedCompletion: return self
    }
    guard
      let family = families.first(where: {
        $0.predecessor.kind == identity.kind && $0.predecessor.id == identity.id
          && $0.candidates.contains { $0.lifetimeId == identity.lifetimeId }
      })
    else { return self }
    return .init(
      deletionId: deletionId, operationId: operationId, target: target,
      closedFamilyId: family.familyId)
  }

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
    labelAssociations: [PortableLabelAssociationRecord], entries: [PortableItineraryEntryRecord],
    ownedLinks: [PlannerPortableOwnedLink], expandedCompletions: [PortableExpandedCompletionRecord],
    allowsObservedExpandedAssertions: Bool = false
  )
    throws
    -> PlannerPortableDeletionMarker
  {
    switch target {
    case .ownedLink(let identifier, let lifetimeId):
      guard !ownedLinks.contains(where: { $0.id == identifier && $0.lifetimeId == lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The removed bookmark is still live or unsupported.")
      }
      return .init(
        deletionId: deletionId, operationId: operationId,
        target: .ownedLink(id: identifier, lifetimeId: lifetimeId), closedFamilyId: closedFamilyId)
    case .expandedCompletion(let context):
      guard closedFamilyId == nil,
        allowsObservedExpandedAssertions
          || !expandedCompletions.contains(where: { $0.context == context })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure",
          "The removed expanded completion is still live or unsupported.")
      }
      return .init(
        deletionId: deletionId, operationId: operationId,
        target: .expandedCompletion(context), closedFamilyId: nil)
    case .itineraryEntry(let identifier, let lifetimeId):
      guard !entries.contains(where: { $0.id == identifier && $0.lifetimeId == lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The removed itinerary entry is still live or unsupported.")
      }
      return .init(
        deletionId: deletionId, operationId: operationId,
        target: .itineraryEntry(id: identifier, lifetimeId: lifetimeId),
        closedFamilyId: closedFamilyId)
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
      guard !isLive else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The deletion target is unsupported or still live.")
      }
      return PlannerPortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .source(
          PlannerEntityReference(kind: kind, id: source.id), lifetimeId: source.lifetimeId),
        closedFamilyId: closedFamilyId)
    case .membership(let membership):
      /// Closed native copies reach consolidation; complete graph validation still rejects them.
      guard membership.kind == "membership" else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The removed membership kind is unsupported.")
      }
      return PlannerPortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .membership(id: membership.id, lifetimeId: membership.lifetimeId),
        closedFamilyId: closedFamilyId)
    case .labelAssociation(let identifier, let lifetimeId):
      guard
        !labelAssociations.contains(where: { $0.id == identifier && $0.lifetimeId == lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The removed label association is still live or unsupported.")
      }
      return PlannerPortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .labelAssociation(id: identifier, lifetimeId: lifetimeId),
        closedFamilyId: closedFamilyId)
    }
  }
}
