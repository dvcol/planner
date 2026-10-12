import Foundation

public struct PlannerItineraryContentInput: Sendable, Equatable {
  public let title: String
  public let notes: String?
  public let color: PlannerColor?
  public let iconName: String?
  public let location: PlannerOwnedLocation?
  public let links: [PlannerLinkInput]
  public let categoryIds: Set<UUID>
  public let tagIds: Set<UUID>
  public let manualEstimate: PlannerEstimate?

  public init(
    title: String, notes: String? = nil, color: PlannerColor? = nil, iconName: String? = nil,
    location: PlannerOwnedLocation? = nil, links: [PlannerLinkInput] = [],
    categoryIds: Set<UUID> = [], tagIds: Set<UUID> = [], manualEstimate: PlannerEstimate? = nil
  ) {
    self.title = title
    self.notes = notes
    self.color = color
    self.iconName = iconName
    self.location = location
    self.links = links
    self.categoryIds = categoryIds
    self.tagIds = tagIds
    self.manualEstimate = manualEstimate
  }
}

public struct PlannerItineraryContent: Sendable, Equatable {
  public let title: String
  public let notes: String?
  public let color: PlannerColor?
  public let iconName: String?
  public let location: PlannerOwnedLocation?
  public let links: [PlannerOwnedLinkRead]
  public let categoryIds: Set<UUID>
  public let tagIds: Set<UUID>
  public let manualEstimate: PlannerEstimate?
}

public enum PlannerItineraryField: String, Sendable, CaseIterable {
  case title, notes, color, iconName, location, links, categoryIds, tagIds, manualEstimate
}

public struct PlannerItineraryListEntrySummary: Sendable {
  public let entryId: UUID
  public let source: PlannerEntityReference
  public let manualEstimate: PlannerEstimate?
  public let progress: PlannerContainerProgress
  public let estimates: PlannerContainerEstimates
}

public struct PlannerItinerarySourceRead: Sendable {
  public let source: PlannerEntityReference
  public let sourceLifetimeId: UUID
  public let content: PlannerItineraryContent
  public let labels: [PlannerLabelRead]
  public let createdAt: Date
  public let updatedAt: Date
  public let fieldHashes: [PlannerItineraryField: PlannerFieldHash]
  public let state: PlannerSourceState
  public let progress: PlannerContainerProgress
  public let estimates: PlannerContainerEstimates
  public let listEntrySummaries: [PlannerItineraryListEntrySummary]
  public let references: [PlannerReferenceRead]
}

extension PlannerItineraryContentInput {
  func validate() throws {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw PlannerFailure(
        "invalidInput", "An Itinerary title must contain text.",
        propertyPath: "/command/content/title")
    }
    try color?.validate(propertyPath: "/command/content/color")
    try manualEstimate?.validate(propertyPath: "/command/content/manualEstimate")
    if let coordinate = location?.coordinate {
      guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
        (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude)
      else {
        throw PlannerFailure(
          "invalidInput", "Coordinates must be finite and within their geographic ranges.",
          propertyPath: "/command/content/location/coordinate")
      }
    }
    for (index, link) in links.enumerated() {
      let path = "/command/content/links/\(index)"
      guard link.linkId == nil else {
        throw PlannerFailure(
          "invalidInput", "New Itinerary links cannot reuse an existing owned-link identity.",
          propertyPath: path + "/linkId")
      }
      _ = try link.validatedKind(propertyPath: path)
    }
  }

  func readContent(links: [PlannerOwnedLinkRead]) -> PlannerItineraryContent {
    PlannerItineraryContent(
      title: title, notes: notes, color: color, iconName: iconName,
      location: location, links: links, categoryIds: categoryIds, tagIds: tagIds,
      manualEstimate: manualEstimate)
  }

  var canonicalContent: PlannerCanonicalValue {
    var fields: [String: PlannerCanonicalValue] = [
      "title": .string(title), "notes": .optional(notes.map(PlannerCanonicalValue.string)),
      "color": .optional(color.map(\.canonicalValue)),
      "iconName": .optional(iconName.map(PlannerCanonicalValue.string)),
      "location": .optional(location.map(\.canonicalValue)),
      "links": .ordered(links.map(\.canonicalValue)),
      "categoryIds": .identitySet(categoryIds.map(PlannerCanonicalValue.identity)),
      "tagIds": .identitySet(tagIds.map(PlannerCanonicalValue.identity)),
    ]
    /** Preserve creation replay for content written before this optional field existed. */
    if let manualEstimate { fields["manualEstimate"] = manualEstimate.canonicalValue }
    return .record(fields)
  }

  func payloadDigest(identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity]) -> String {
    let value = PlannerCanonicalValue.record([
      "command": .record(["type": .string("createItinerary"), "content": canonicalContent]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }
}

struct ItinerarySnapshot {
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let input: PlannerItineraryContentInput
  let archived: Bool
  var links: [OwnedLinkSnapshot] = []
  var schedules: [ScheduleSnapshot] = []
  var labelAssociations: [LabelAssociationSnapshot] = []
  var labels: [PlannerLabelRead] = []
  var entries: [ItineraryEntrySnapshot] = []

  var reference: PlannerEntityReference { .init(kind: .itinerary, id: id) }

  func read(
    datasetId: UUID, memberships: [MembershipSnapshot], items: [ContainerEstimateItemSnapshot],
    lists: [ContainerEstimateListSnapshot]
  ) throws -> PlannerItinerarySourceRead {
    let summary = try ContainerEstimateItinerarySnapshot(
      reference: reference, manualEstimate: input.manualEstimate, archived: archived,
      entries: entries
    ).progressAndEstimates(memberships: memberships, items: items, lists: lists)
    return try PlannerItinerarySourceRead(
      source: reference, sourceLifetimeId: lifetimeId,
      content: input.readContent(links: links.map(\.read)), labels: labels,
      createdAt: createdAt, updatedAt: updatedAt, fieldHashes: fieldHashes(datasetId: datasetId),
      state: PlannerSourceState(globalDone: nil, archived: archived),
      progress: summary.progress, estimates: summary.estimates,
      listEntrySummaries: summary.listEntrySummaries,
      references: labelAssociations.map(\.reference) + entries.map(\.reference)
        + entries.flatMap(\.expandedCompletions).map(\.reference)
        + schedules.sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .schedule(id: $0.id, source: reference)
        })
  }
}
