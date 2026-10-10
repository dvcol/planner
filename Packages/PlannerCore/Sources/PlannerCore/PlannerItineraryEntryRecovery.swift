import Foundation

public struct PlannerPortableItineraryEntry: Sendable, Equatable {
  public let id: UUID
  public let lifetimeId: UUID
  public let itinerary: PlannerEntityReference
  public let itineraryLifetimeId: UUID
  public let source: PlannerEntityReference
  public let sourceLifetimeId: UUID
  public let rank: Int64
  public let localDone: Bool?
}

struct PortableItineraryEntryRecord: Codable {
  let id: UUID
  let lifetimeId: UUID
  let itinerary: PlannerBoundIdentity
  let source: PlannerBoundIdentity
  let rank: String
  let localDone: Bool?

  init(_ entry: ItineraryEntrySnapshot) {
    id = entry.id
    lifetimeId = entry.lifetimeId
    itinerary = entry.itinerary
    source = entry.source
    rank = String(entry.rank)
    localDone = entry.localDone
  }

  private enum CodingKeys: String, CodingKey {
    case id, lifetimeId, itinerary, source, rank, localDone
  }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    id = try fields.decode(UUID.self, forKey: .id)
    lifetimeId = try fields.decode(UUID.self, forKey: .lifetimeId)
    itinerary = try fields.decode(PlannerBoundIdentity.self, forKey: .itinerary)
    source = try fields.decode(PlannerBoundIdentity.self, forKey: .source)
    rank = try fields.decode(String.self, forKey: .rank)
    localDone = try fields.decode(Bool?.self, forKey: .localDone)
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(id, forKey: .id)
    try fields.encode(lifetimeId, forKey: .lifetimeId)
    try fields.encode(itinerary, forKey: .itinerary)
    try fields.encode(source, forKey: .source)
    try fields.encode(rank, forKey: .rank)
    try fields.encode(localDone, forKey: .localDone)
  }

  func validated(
    items: [PortableItemRecord], lists: [PortableListRecord], itineraries: [PortableItineraryRecord]
  ) throws -> PlannerPortableItineraryEntry {
    let sourceKind: PlannerEntityKind
    let validSource: Bool
    switch source.kind {
    case "item":
      sourceKind = .item
      validSource =
        localDone != nil
        && items.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
    case "list":
      sourceKind = .list
      validSource =
        localDone == nil
        && lists.contains { $0.id == source.id && $0.lifetimeId == source.lifetimeId }
    default:
      throw PlannerFailure(
        "recoveryIntegrityFailure", "An itinerary entry source must be an Item or List.")
    }
    guard itinerary.kind == "itinerary", validSource,
      itineraries.contains(where: { $0.id == itinerary.id && $0.lifetimeId == itinerary.lifetimeId }
      ),
      let parsedRank = Int64(rank), String(parsedRank) == rank
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The entry has invalid bindings, completion or rank.")
    }
    return .init(
      id: id, lifetimeId: lifetimeId,
      itinerary: .init(kind: .itinerary, id: itinerary.id),
      itineraryLifetimeId: itinerary.lifetimeId,
      source: .init(kind: sourceKind, id: source.id), sourceLifetimeId: source.lifetimeId,
      rank: parsedRank, localDone: localDone)
  }
}
