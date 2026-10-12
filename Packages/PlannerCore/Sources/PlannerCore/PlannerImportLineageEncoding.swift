import Foundation

extension PlannerPortableCompletionContext: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind, membershipId, membershipLifetimeId, entryId, entryLifetimeId
    case listEntryId, listEntryLifetimeId
  }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    switch try fields.decode(String.self, forKey: .kind) {
    case "listMembership":
      self = .listMembership(
        membershipId: try fields.decode(UUID.self, forKey: .membershipId),
        membershipLifetimeId: try fields.decode(UUID.self, forKey: .membershipLifetimeId))
    case "directItineraryItem":
      self = .directItineraryItem(
        entryId: try fields.decode(UUID.self, forKey: .entryId),
        entryLifetimeId: try fields.decode(UUID.self, forKey: .entryLifetimeId))
    case "expandedListItem":
      self = .expandedListItem(
        .init(
          listEntryId: try fields.decode(UUID.self, forKey: .listEntryId),
          listEntryLifetimeId: try fields.decode(UUID.self, forKey: .listEntryLifetimeId),
          membershipId: try fields.decode(UUID.self, forKey: .membershipId),
          membershipLifetimeId: try fields.decode(UUID.self, forKey: .membershipLifetimeId)))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: fields, debugDescription: "Unsupported completion context kind.")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .listMembership(let membershipIdentifier, let membershipLifetimeIdentifier):
      try fields.encode("listMembership", forKey: .kind)
      try fields.encode(membershipIdentifier, forKey: .membershipId)
      try fields.encode(membershipLifetimeIdentifier, forKey: .membershipLifetimeId)
    case .directItineraryItem(let entryIdentifier, let entryLifetimeIdentifier):
      try fields.encode("directItineraryItem", forKey: .kind)
      try fields.encode(entryIdentifier, forKey: .entryId)
      try fields.encode(entryLifetimeIdentifier, forKey: .entryLifetimeId)
    case .expandedListItem(let context):
      try fields.encode("expandedListItem", forKey: .kind)
      try fields.encode(context.listEntryId, forKey: .listEntryId)
      try fields.encode(context.listEntryLifetimeId, forKey: .listEntryLifetimeId)
      try fields.encode(context.membershipId, forKey: .membershipId)
      try fields.encode(context.membershipLifetimeId, forKey: .membershipLifetimeId)
    }
  }
}

extension PlannerPortableContextAlias {
  private enum CodingKeys: String, CodingKey {
    case aliasId, context, canonicalContext, initialDone, currentChangeId
  }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      aliasId: try fields.decode(UUID.self, forKey: .aliasId),
      context: try fields.decode(PlannerPortableCompletionContext.self, forKey: .context),
      canonicalContext: try fields.decode(
        PlannerPortableCompletionContext.self, forKey: .canonicalContext),
      initialDone: try fields.decode(Bool.self, forKey: .initialDone),
      currentChangeId: try fields.decodeIfPresent(UUID.self, forKey: .currentChangeId))
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(aliasId, forKey: .aliasId)
    try fields.encode(context, forKey: .context)
    try fields.encode(canonicalContext, forKey: .canonicalContext)
    try fields.encode(initialDone, forKey: .initialDone)
    try fields.encode(currentChangeId, forKey: .currentChangeId)
  }
}
