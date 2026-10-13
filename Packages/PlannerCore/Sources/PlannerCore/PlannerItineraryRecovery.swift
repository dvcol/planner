import Foundation

public struct PlannerPortableItinerary: Sendable {
  public let id: UUID
  public let lifetimeId: UUID
  public let createdAt: Date
  public let updatedAt: Date
  public let content: PlannerItineraryContent
  public let archived: Bool
  public let contentOrigins: [String: String]
}

struct PortableItineraryContent: Codable {
  let title: String
  let notes: String?
  let color: PlannerColor?
  let iconName: String?
  let location: PlannerOwnedLocation?
  let manualEstimate: PlannerEstimate?

  init(_ input: PlannerItineraryContentInput) {
    title = input.title
    notes = input.notes
    color = input.color
    iconName = input.iconName
    location = input.location
    manualEstimate = input.manualEstimate
  }

  var input: PlannerItineraryContentInput {
    .init(
      title: title, notes: notes, color: color, iconName: iconName, location: location,
      manualEstimate: manualEstimate)
  }

  enum CodingKeys: String, CodingKey {
    case title, notes, color, iconName, location, manualEstimate
  }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    title = try fields.decode(String.self, forKey: .title)
    notes = try fields.decodeIfPresent(String.self, forKey: .notes)
    color = try fields.decodeIfPresent(PlannerColor.self, forKey: .color)
    iconName = try fields.decodeIfPresent(String.self, forKey: .iconName)
    location = try fields.decodeIfPresent(PlannerOwnedLocation.self, forKey: .location)
    manualEstimate = try fields.decodeIfPresent(
      PortableEstimateRecord.self, forKey: .manualEstimate)?.value
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(title, forKey: .title)
    try fields.encode(notes, forKey: .notes)
    try fields.encode(color, forKey: .color)
    try fields.encode(iconName, forKey: .iconName)
    try fields.encode(location, forKey: .location)
    try fields.encode(manualEstimate.map(PortableEstimateRecord.init), forKey: .manualEstimate)
  }
}

struct PortableItineraryRecord: Codable {
  let kind: PlannerEntityKind
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PortableItineraryContent
  let archived: Bool
  let contentOrigins: [String: String]

  init(_ itinerary: ItinerarySnapshot) {
    kind = .itinerary
    id = itinerary.id
    lifetimeId = itinerary.lifetimeId
    createdAt = itinerary.createdAt
    updatedAt = itinerary.updatedAt
    content = PortableItineraryContent(itinerary.input)
    archived = itinerary.archived
    contentOrigins = itinerary.contentOrigins ?? itinerary.independentContentOrigins
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
    content = try fields.decode(PortableItineraryContent.self, forKey: .content)
    archived = try fields.decode(Bool.self, forKey: .archived)
    contentOrigins = try fields.decode([String: String].self, forKey: .contentOrigins)
    guard try fields.decode(Bool?.self, forKey: .globalDone) == nil else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Itineraries have no global completion flag.")
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

  func validated() throws -> PlannerPortableItinerary {
    guard kind == .itinerary, createdAt.timeIntervalSinceReferenceDate.isFinite,
      updatedAt.timeIntervalSinceReferenceDate.isFinite
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot has invalid Itinerary identity or dates.")
    }
    try content.input.validate()
    let expected = PortableItineraryRecord(
      ItinerarySnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        input: content.input, archived: archived)
    ).contentOrigins
    try plannerValidateContentOrigins(contentOrigins, expected: expected)
    return PlannerPortableItinerary(
      id: id, lifetimeId: lifetimeId, createdAt: createdAt,
      updatedAt: updatedAt, content: content.input.readContent(links: []), archived: archived,
      contentOrigins: contentOrigins)
  }
}
