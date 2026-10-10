import Foundation

public enum PlannerItineraryFieldValue: Sendable, Equatable {
  case string(String)
  case optionalString(String?)
  case optionalColor(PlannerColor?)
  case optionalLocation(PlannerOwnedLocation?)
  case links([PlannerOwnedLinkRead])
  case identitySet(Set<UUID>)
}

public struct PlannerItineraryChanges: Sendable {
  public let title: PlannerFieldChange<String>
  public let notes: PlannerFieldChange<String>
  public let color: PlannerFieldChange<PlannerColor>
  public let iconName: PlannerFieldChange<String>
  public let location: PlannerFieldChange<PlannerOwnedLocation>
  public let links: PlannerFieldChange<[PlannerLinkInput]>
  public let categoryIds: PlannerFieldChange<Set<UUID>>
  public let tagIds: PlannerFieldChange<Set<UUID>>

  public init(
    title: PlannerFieldChange<String> = .unchanged,
    notes: PlannerFieldChange<String> = .unchanged,
    color: PlannerFieldChange<PlannerColor> = .unchanged,
    iconName: PlannerFieldChange<String> = .unchanged,
    location: PlannerFieldChange<PlannerOwnedLocation> = .unchanged,
    links: PlannerFieldChange<[PlannerLinkInput]> = .unchanged,
    categoryIds: PlannerFieldChange<Set<UUID>> = .unchanged,
    tagIds: PlannerFieldChange<Set<UUID>> = .unchanged
  ) {
    self.title = title
    self.notes = notes
    self.color = color
    self.iconName = iconName
    self.location = location
    self.links = links
    self.categoryIds = categoryIds
    self.tagIds = tagIds
  }
}

extension PlannerItineraryChanges {
  func validatedFields() throws -> [PlannerItineraryField] {
    switch title {
    case .clear:
      throw PlannerFailure(
        "invalidInput", "An Itinerary title cannot be cleared.",
        propertyPath: "/command/changes/title")
    case .set(let value):
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PlannerFailure(
          "invalidInput", "An Itinerary title must contain text.",
          propertyPath: "/command/changes/title")
      }
    case .unchanged: break
    }
    if case .set(let value) = color { try value.validate(propertyPath: "/command/changes/color") }
    if case .set(let value) = location, let coordinate = value.coordinate {
      guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
        (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude)
      else {
        throw PlannerFailure(
          "invalidInput", "Coordinates must be finite and within their geographic ranges.",
          propertyPath: "/command/changes/location/coordinate")
      }
    }
    for (field, change) in [(PlannerItineraryField.categoryIds, categoryIds), (.tagIds, tagIds)] {
      if case .clear = change {
        throw PlannerFailure(
          "invalidInput", "A label selection must use an identity set, including an empty set.",
          propertyPath: "/command/changes/\(field.rawValue)")
      }
    }
    switch links {
    case .clear:
      throw PlannerFailure(
        "invalidInput", "An owned-links collection must use an array, including an empty array.",
        propertyPath: "/command/changes/links")
    case .set(let values):
      var identifiers: Set<UUID> = []
      for (index, link) in values.enumerated() {
        let path = "/command/changes/links/\(index)"
        if let identifier = link.linkId, !identifiers.insert(identifier).inserted {
          throw PlannerFailure(
            "invalidInput", "A replacement cannot repeat an owned-link identity.",
            propertyPath: path + "/linkId")
        }
        _ = try link.validatedKind(propertyPath: path)
      }
    case .unchanged: break
    }
    var fields: [PlannerItineraryField] = []
    if !title.isUnchanged { fields.append(.title) }
    if !notes.isUnchanged { fields.append(.notes) }
    if !color.isUnchanged { fields.append(.color) }
    if !iconName.isUnchanged { fields.append(.iconName) }
    if !location.isUnchanged { fields.append(.location) }
    if !links.isUnchanged { fields.append(.links) }
    if !categoryIds.isUnchanged { fields.append(.categoryIds) }
    if !tagIds.isUnchanged { fields.append(.tagIds) }
    guard !fields.isEmpty else {
      throw PlannerFailure(
        "invalidInput", "An Itinerary edit must contain at least one changed field.",
        propertyPath: "/command/changes")
    }
    return fields.sorted { $0.rawValue < $1.rawValue }
  }

  func applyingChanges(to input: PlannerItineraryContentInput) -> PlannerItineraryContentInput {
    var updatedTitle = input.title
    if case .set(let value) = title { updatedTitle = value }
    var updatedCategories = input.categoryIds
    if case .set(let values) = categoryIds { updatedCategories = values }
    var updatedTags = input.tagIds
    if case .set(let values) = tagIds { updatedTags = values }
    return .init(
      title: updatedTitle, notes: optionalValue(notes, retaining: input.notes),
      color: optionalValue(color, retaining: input.color),
      iconName: optionalValue(iconName, retaining: input.iconName),
      location: optionalValue(location, retaining: input.location), categoryIds: updatedCategories,
      tagIds: updatedTags)
  }

  private func optionalValue<Value: Sendable>(
    _ change: PlannerFieldChange<Value>, retaining current: Value?
  ) -> Value? {
    switch change {
    case .unchanged: current
    case .set(let value): value
    case .clear: nil
    }
  }

  func editPayloadDigest(
    sourceId: UUID, fields: [PlannerItineraryField],
    hashes: [PlannerItineraryField: PlannerFieldHash],
    identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity]
  ) throws -> String {
    var values: [String: PlannerCanonicalValue] = [:]
    if case .set(let value) = title { values["title"] = .string(value) }
    for (field, change) in [(PlannerItineraryField.notes, notes), (.iconName, iconName)] {
      switch change {
      case .set(let value): values[field.rawValue] = .optional(.string(value))
      case .clear: values[field.rawValue] = .optional(nil)
      case .unchanged: break
      }
    }
    switch color {
    case .set(let value): values["color"] = .optional(value.canonicalValue)
    case .clear: values["color"] = .optional(nil)
    case .unchanged: break
    }
    switch location {
    case .set(let value): values["location"] = .optional(value.canonicalValue)
    case .clear: values["location"] = .optional(nil)
    case .unchanged: break
    }
    if case .set(let inputs) = links { values["links"] = .ordered(inputs.map(\.canonicalValue)) }
    if case .set(let identifiers) = categoryIds {
      values["categoryIds"] = .identitySet(identifiers.map(PlannerCanonicalValue.identity))
    }
    if case .set(let identifiers) = tagIds {
      values["tagIds"] = .identitySet(identifiers.map(PlannerCanonicalValue.identity))
    }
    var usedHashes: [String: PlannerCanonicalValue] = [:]
    for field in fields {
      guard let hash = hashes[field] else {
        throw PlannerFailure(
          "invalidInput", "Every changed field requires its prior hash.",
          propertyPath: "/command/expectedFieldHashes/\(field.rawValue)")
      }
      usedHashes[field.rawValue] = .string(hash.value)
    }
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("editItinerary"), "sourceId": .identity(sourceId),
        "changes": .record(values), "expectedFieldHashes": .record(usedHashes),
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }
}

extension ItinerarySnapshot {
  func fieldValue(_ field: PlannerItineraryField) -> PlannerItineraryFieldValue {
    switch field {
    case .title: .string(input.title)
    case .notes: .optionalString(input.notes)
    case .color: .optionalColor(input.color)
    case .iconName: .optionalString(input.iconName)
    case .location: .optionalLocation(input.location)
    case .links: .links(links.map(\.read))
    case .categoryIds: .identitySet(input.categoryIds)
    case .tagIds: .identitySet(input.tagIds)
    }
  }
}

extension PlannerItineraryChanges {
  func linkBindings(in itinerary: ItinerarySnapshot) throws -> [PlannerBoundIdentity] {
    guard case .set(let inputs) = links else { return [] }
    return try inputs.enumerated().compactMap { index, input in
      guard let link = try retainedLink(input, index: index, in: itinerary) else { return nil }
      return PlannerBoundIdentity(kind: "ownedLink", id: link.id, lifetimeId: link.lifetimeId)
    }
  }

  func applyingLinks(to itinerary: ItinerarySnapshot) throws -> [OwnedLinkSnapshot] {
    guard case .set(let inputs) = links else { return itinerary.links }
    return try inputs.enumerated().map { index, input in
      let previous = try retainedLink(input, index: index, in: itinerary)
      let identifier = previous?.id ?? UUID()
      return OwnedLinkSnapshot(
        id: identifier, lifetimeId: previous?.lifetimeId ?? identifier, rank: Int64(index),
        originalUrl: input.originalUrl, label: input.label,
        kind: try input.validatedKind(propertyPath: "/command/changes/links/\(index)"))
    }
  }

  private func retainedLink(_ input: PlannerLinkInput, index: Int, in itinerary: ItinerarySnapshot)
    throws
    -> OwnedLinkSnapshot?
  {
    guard let identifier = input.linkId else { return nil }
    guard let existing = itinerary.links.first(where: { $0.id == identifier }) else {
      throw PlannerFailure(
        "invalidInput", "An existing owned link must belong to this Itinerary and its lifetime.",
        propertyPath: "/command/changes/links/\(index)/linkId")
    }
    return existing
  }
}

extension PlannerItineraryChanges {
  var changedLabelKinds: Set<String> {
    var kinds: Set<String> = []
    if case .set = categoryIds { kinds.insert("category") }
    if case .set = tagIds { kinds.insert("tag") }
    return kinds
  }

  func labelAssociationBindings(in itinerary: ItinerarySnapshot) -> [PlannerBoundIdentity] {
    itinerary.labelAssociations.filter { changedLabelKinds.contains($0.label.kind) }.map {
      PlannerBoundIdentity(kind: "labelAssociation", id: $0.id, lifetimeId: $0.lifetimeId)
    }
  }

  func applyingLabelAssociations(
    to itinerary: ItinerarySnapshot, selectedLabels: [PlannerBoundIdentity]
  )
    -> [LabelAssociationSnapshot]
  {
    let retained = itinerary.labelAssociations.filter { !changedLabelKinds.contains($0.label.kind) }
    let selected = selectedLabels.map { label in
      if let existing = itinerary.labelAssociations.first(where: {
        $0.label.kind == label.kind && $0.label.id == label.id
          && $0.label.lifetimeId == label.lifetimeId
      }) {
        return existing
      }
      let identifier = UUID()
      return LabelAssociationSnapshot(
        id: identifier, lifetimeId: identifier,
        owner: PlannerBoundIdentity(
          kind: "itinerary", id: itinerary.id, lifetimeId: itinerary.lifetimeId),
        label: label)
    }
    return (retained + selected).sorted { $0.id.uuidString < $1.id.uuidString }
  }
}
