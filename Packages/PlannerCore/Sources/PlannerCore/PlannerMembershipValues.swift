import Foundation

protocol PlannerRankedAssociation {
  var id: UUID { get }
  var rank: Int64 { get set }
}

struct MembershipSnapshot: PlannerRankedAssociation {
  let id: UUID
  let lifetimeId: UUID
  let list: PlannerBoundIdentity
  let item: PlannerBoundIdentity
  var rank: Int64
  let localDone: Bool

  var reference: PlannerReferenceRead {
    .membership(
      id: id, list: PlannerEntityReference(kind: .list, id: list.id),
      item: PlannerEntityReference(kind: .item, id: item.id))
  }
}

public enum PlannerPlacement: Sendable {
  case first, last
  case before(associationId: UUID)
  case after(associationId: UUID)
}

func associationInsertionIndex<Association: PlannerRankedAssociation>(
  _ placement: PlannerPlacement, in ordered: [Association]
) throws -> Int {
  switch placement {
  case .first: return 0
  case .last: return ordered.count
  case .before(let identifier), .after(let identifier):
    guard let index = ordered.firstIndex(where: { $0.id == identifier }) else {
      throw PlannerFailure(
        "missingReference", "The placement anchor is not in the destination container.",
        propertyPath: "/command/placement/associationId")
    }
    if case .before = placement { return index }
    return index + 1
  }
}

func associationRank<Association: PlannerRankedAssociation>(
  at index: Int, in ordered: [Association]
) -> Int64? {
  if ordered.isEmpty { return 0 }
  if index == 0 {
    let (rank, overflow) = ordered[0].rank.subtractingReportingOverflow(1024)
    return overflow ? nil : rank
  }
  if index == ordered.count {
    let (rank, overflow) = ordered[index - 1].rank.addingReportingOverflow(1024)
    return overflow ? nil : rank
  }
  let left = ordered[index - 1].rank
  let (distance, overflow) = ordered[index].rank.subtractingReportingOverflow(left)
  guard !overflow, distance > 1 else { return nil }
  let (rank, additionOverflow) = left.addingReportingOverflow(distance / 2)
  return additionOverflow ? nil : rank
}

func associationInsertionRank<Association: PlannerRankedAssociation>(
  at index: Int, ordered: [Association], associations: inout [Association]
) throws -> Int64 {
  if let rank = associationRank(at: index, in: ordered) { return rank }
  var balanced = ordered
  for position in balanced.indices {
    let (rank, overflow) = Int64(position).multipliedReportingOverflow(by: 1024)
    guard !overflow else {
      throw PlannerFailure("invalidInput", "The saved order exceeds rank capacity.")
    }
    balanced[position].rank = rank
  }
  guard let rank = associationRank(at: index, in: balanced) else {
    throw PlannerFailure("invalidInput", "The saved order exceeds rank capacity.")
  }
  let ranks = Dictionary(uniqueKeysWithValues: balanced.map { ($0.id, $0.rank) })
  for position in associations.indices {
    if let rank = ranks[associations[position].id] { associations[position].rank = rank }
  }
  return rank
}

public enum PlannerAppearance: Sendable, Equatable, Codable {
  case listMembership(listId: UUID, membershipId: UUID)
  case directItineraryItem(itineraryId: UUID, entryId: UUID)
  case expandedListItem(itineraryId: UUID, listEntryId: UUID, membershipId: UUID)

  private enum CodingKeys: String, CodingKey {
    case kind, listId, membershipId, itineraryId, entryId, listEntryId
  }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    switch try fields.decode(String.self, forKey: .kind) {
    case "expandedListItem":
      self = .expandedListItem(
        itineraryId: try fields.decode(UUID.self, forKey: .itineraryId),
        listEntryId: try fields.decode(UUID.self, forKey: .listEntryId),
        membershipId: try fields.decode(UUID.self, forKey: .membershipId))
    case "listMembership":
      self = .listMembership(
        listId: try fields.decode(UUID.self, forKey: .listId),
        membershipId: try fields.decode(UUID.self, forKey: .membershipId))
    case "directItineraryItem":
      self = .directItineraryItem(
        itineraryId: try fields.decode(UUID.self, forKey: .itineraryId),
        entryId: try fields.decode(UUID.self, forKey: .entryId))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: fields, debugDescription: "Unsupported appearance kind.")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .expandedListItem(let itineraryId, let listEntryId, let membershipId):
      try fields.encode("expandedListItem", forKey: .kind)
      try fields.encode(itineraryId, forKey: .itineraryId)
      try fields.encode(listEntryId, forKey: .listEntryId)
      try fields.encode(membershipId, forKey: .membershipId)
    case .directItineraryItem(let itineraryId, let entryId):
      try fields.encode("directItineraryItem", forKey: .kind)
      try fields.encode(itineraryId, forKey: .itineraryId)
      try fields.encode(entryId, forKey: .entryId)
    case .listMembership(let listId, let membershipId):
      try fields.encode("listMembership", forKey: .kind)
      try fields.encode(listId, forKey: .listId)
      try fields.encode(membershipId, forKey: .membershipId)
    }
  }
}

public struct PlannerAppearanceRead: Sendable {
  public let appearance: PlannerAppearance
  public let source: PlannerEntityReference
  public let sourceLifetimeId: UUID
  public let content: PlannerItemContent
  public let globalDone: Bool
  public let localDone: Bool
  public let effectiveDone: Bool
  public let archived: Bool
  public let fieldHashes: [PlannerItemField: PlannerFieldHash]
}

extension PlannerReferenceRead: Codable {
  private enum CodingKeys: String, CodingKey { case kind, id, owner, source, appearance }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try fields.decode(String.self, forKey: .kind)
    if kind == "expandedCompletion" {
      guard
        case .expandedListItem(let itineraryId, let listEntryId, let membershipId) =
          try fields.decode(PlannerAppearance.self, forKey: .appearance)
      else {
        throw DecodingError.dataCorruptedError(
          forKey: .appearance, in: fields,
          debugDescription: "Invalid expanded completion appearance.")
      }
      self = .expandedCompletion(
        itineraryId: itineraryId, listEntryId: listEntryId, membershipId: membershipId)
      return
    }
    let identifier = try fields.decode(UUID.self, forKey: .id)
    let owner = try fields.decode(PlannerEntityReference?.self, forKey: .owner)
    let source = try fields.decode(PlannerEntityReference?.self, forKey: .source)
    let appearance = try fields.decode(PlannerAppearance?.self, forKey: .appearance)
    switch kind {
    case "itineraryEntry":
      guard let owner, owner.kind == .itinerary, let source, [.item, .list].contains(source.kind)
      else {
        throw DecodingError.dataCorruptedError(
          forKey: .source, in: fields, debugDescription: "Invalid itinerary entry reference.")
      }
      let expectedAppearance: PlannerAppearance? =
        source.kind == .item
        ? .directItineraryItem(itineraryId: owner.id, entryId: identifier) : nil
      guard appearance == expectedAppearance else {
        throw DecodingError.dataCorruptedError(
          forKey: .appearance, in: fields, debugDescription: "Invalid itinerary entry appearance.")
      }
      self = .itineraryEntry(id: identifier, itinerary: owner, source: source)
    case "ownedLink":
      guard let owner, [.item, .itinerary].contains(owner.kind), source == nil, appearance == nil
      else {
        throw DecodingError.dataCorruptedError(
          forKey: .owner, in: fields, debugDescription: "Invalid owned-link reference.")
      }
      self = .ownedLink(id: identifier, owner: owner)
    case "schedule":
      guard owner == nil, let source, [.item, .itinerary].contains(source.kind), appearance == nil
      else {
        throw DecodingError.dataCorruptedError(
          forKey: .source, in: fields, debugDescription: "Invalid Schedule reference.")
      }
      self = .schedule(id: identifier, source: source)
    case "labelAssociation":
      guard let owner, [.item, .itinerary].contains(owner.kind), let source,
        [.category, .tag].contains(source.kind), appearance == nil
      else {
        throw DecodingError.dataCorruptedError(
          forKey: .source, in: fields, debugDescription: "Invalid label association reference.")
      }
      self = .labelAssociation(id: identifier, owner: owner, label: source)
    case "membership":
      guard let owner, owner.kind == .list, let source, source.kind == .item,
        appearance == .listMembership(listId: owner.id, membershipId: identifier)
      else {
        throw DecodingError.dataCorruptedError(
          forKey: .appearance, in: fields, debugDescription: "Invalid List membership reference.")
      }
      self = .membership(id: identifier, list: owner, item: source)
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: fields, debugDescription: "Unsupported reference kind.")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    let kind: String
    let identifier: UUID
    let owner: PlannerEntityReference?
    let source: PlannerEntityReference?
    let appearance: PlannerAppearance?
    switch self {
    case .expandedCompletion(let itineraryId, let listEntryId, let membershipId):
      try fields.encode("expandedCompletion", forKey: .kind)
      try fields.encode(
        PlannerAppearance.expandedListItem(
          itineraryId: itineraryId, listEntryId: listEntryId, membershipId: membershipId),
        forKey: .appearance)
      return
    case .itineraryEntry(let value, let itinerary, let sourceValue):
      kind = "itineraryEntry"
      identifier = value
      owner = itinerary
      source = sourceValue
      appearance =
        sourceValue.kind == .item
        ? .directItineraryItem(itineraryId: itinerary.id, entryId: value) : nil
    case .ownedLink(let value, let ownerValue):
      kind = "ownedLink"
      identifier = value
      owner = ownerValue
      source = nil
      appearance = nil
    case .schedule(let value, let sourceValue):
      kind = "schedule"
      identifier = value
      owner = nil
      source = sourceValue
      appearance = nil
    case .labelAssociation(let value, let ownerValue, let labelValue):
      kind = "labelAssociation"
      identifier = value
      owner = ownerValue
      source = labelValue
      appearance = nil
    case .membership(let value, let list, let item):
      kind = "membership"
      identifier = value
      owner = list
      source = item
      appearance = .listMembership(listId: list.id, membershipId: value)
    }
    try fields.encode(kind, forKey: .kind)
    try fields.encode(identifier, forKey: .id)
    try fields.encode(owner, forKey: .owner)
    try fields.encode(source, forKey: .source)
    try fields.encode(appearance, forKey: .appearance)
  }
}
