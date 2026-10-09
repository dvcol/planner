import CryptoKit
import Foundation

/// Version 1 uses tagged native values, never JSON encoder output, for fingerprints.
indirect enum PlannerCanonicalValue {
  case string(String)
  case boolean(Bool)
  case integer(Int64)
  case double(Double)
  case identity(UUID)
  case optional(PlannerCanonicalValue?)
  case ordered([PlannerCanonicalValue])
  case identitySet([PlannerCanonicalValue])
  case record([String: PlannerCanonicalValue])

  func encoded() -> Data {
    switch self {
    case .string(let value):
      let bytes = Data(value.utf8)
      return Data([0x10]) + unsigned(UInt64(bytes.count)) + bytes
    case .boolean(let value): return Data([0x11, value ? 1 : 0])
    case .integer(let value): return Data([0x12]) + unsigned(UInt64(bitPattern: value))
    case .double(let value): return Data([0x13]) + unsigned((value == 0 ? 0 : value).bitPattern)
    case .identity(let value): return Data([0x14]) + identityBytes(value)
    case .optional(let value):
      guard let value else { return Data([0x15, 0]) }
      return Data([0x15, 1]) + value.encoded()
    case .ordered(let values):
      return collection(tag: 0x16, bytes: values.map { $0.encoded() })
    case .identitySet(let values):
      return collection(
        tag: 0x17, bytes: values.map { $0.encoded() }.sorted { $0.lexicographicallyPrecedes($1) }
      )
    case .record(let fields):
      var result = Data([0x18]) + unsigned(UInt64(fields.count))
      for name in fields.keys.sorted() {
        let bytes = Data(name.utf8)
        result += unsigned(UInt64(bytes.count)) + bytes
        if let value = fields[name] { result += value.encoded() }
      }
      return result
    }
  }

  private func collection(tag: UInt8, bytes: [Data]) -> Data {
    var result = Data([tag]) + unsigned(UInt64(bytes.count))
    for element in bytes { result += element }
    return result
  }
}

private func unsigned(_ value: UInt64) -> Data {
  var bigEndian = value.bigEndian
  return withUnsafeBytes(of: &bigEndian) { Data($0) }
}

private func identityBytes(_ value: UUID) -> Data {
  var bytes = value.uuid
  return withUnsafeBytes(of: &bytes) { Data($0) }
}

func plannerDigest(_ data: Data, prefix: String) -> String {
  prefix + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

extension PlannerItemContentInput {
  var canonicalContent: PlannerCanonicalValue {
    .record([
      "title": .string(title), "subtitle": .optional(subtitle.map { .string($0) }),
      "notes": .optional(notes.map { .string($0) }),
      "location": .optional(location.map { $0.canonicalValue }),
      "estimate": .optional(estimate.map { $0.canonicalValue }),
      "links": .ordered(links.map(\.canonicalValue)), "categoryIds": .identitySet([]),
      "tagIds": .identitySet([]),
    ])
  }

  func fieldHashes(
    datasetId: UUID, itemId: UUID, lifetimeId: UUID, links: [PlannerOwnedLinkRead] = []
  ) -> [PlannerItemField:
    PlannerFieldHash]
  {
    guard case .record(var fields) = canonicalContent else { return [:] }
    fields["links"] = .ordered(links.map(\.canonicalValue))
    return Dictionary(
      uniqueKeysWithValues: PlannerItemField.allCases.compactMap { field in
        guard let value = fields[field.rawValue] else { return nil }
        let name = Data(field.rawValue.utf8)
        var data = Data("PlannerFieldHash".utf8)
        data += Data([0, 0, 0, 0, 1])
        data += identityBytes(datasetId)
        data += Data([1])
        data += identityBytes(itemId)
        data += identityBytes(lifetimeId)
        data += unsigned(UInt64(name.count))
        data += name
        data += value.encoded()
        return (field, PlannerFieldHash(value: plannerDigest(data, prefix: "sha256-v1:")))
      })
  }

  func payloadDigest(datasetId: UUID, ownershipBinding: String) -> String {
    let value = PlannerCanonicalValue.record([
      "command": .record(["type": .string("createItem"), "content": canonicalContent]),
      "datasetId": .identity(datasetId), "ownershipBinding": .string(ownershipBinding),
      "resolvedBindings": .identitySet([]),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }

  func validate() throws {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw PlannerFailure(
        "invalidInput", "An Item title must contain text.", propertyPath: "/command/content/title")
    }
    if let estimate, estimate.minutes <= 0 {
      throw PlannerFailure(
        "invalidInput", "An estimate must contain positive whole minutes.",
        propertyPath: "/command/content/estimate/minutes")
    }
    if let coordinate = location?.coordinate {
      guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
        (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude)
      else {
        throw PlannerFailure(
          "invalidInput", "Coordinates must be finite and within their geographic ranges.",
          propertyPath: "/command/content/location/coordinate")
      }
    }
    guard categoryIds.isEmpty, tagIds.isEmpty else {
      throw PlannerFailure("unavailable", "This local fixture does not yet implement labels.")
    }
    for (index, link) in links.enumerated() {
      let path = "/command/content/links/\(index)"
      guard link.linkId == nil else {
        throw PlannerFailure(
          "invalidInput", "New Item links cannot reuse an existing owned-link identity.",
          propertyPath: path + "/linkId")
      }
      _ = try link.validatedKind(propertyPath: path)
    }
  }

  func readContent(links: [PlannerOwnedLinkRead] = []) -> PlannerItemContent {
    PlannerItemContent(
      title: title, subtitle: subtitle, notes: notes, location: location, estimate: estimate,
      links: links, categoryIds: [], tagIds: []
    )
  }
}

extension PlannerOwnedLocation {
  var canonicalValue: PlannerCanonicalValue {
    .record([
      "displayName": .optional(displayName.map { .string($0) }),
      "formattedAddress": .optional(formattedAddress.map { .string($0) }),
      "coordinate": .optional(
        coordinate.map {
          .record(["latitude": .double($0.latitude), "longitude": .double($0.longitude)])
        }),
    ])
  }
}

extension PlannerEstimate {
  var canonicalValue: PlannerCanonicalValue {
    .record(["minutes": .integer(minutes), "displayUnit": .string(displayUnit.rawValue)])
  }
}

extension PlannerFieldChange {
  var isUnchanged: Bool {
    if case .unchanged = self { return true }
    return false
  }
}

extension PlannerItemChanges {
  func validatedFields() throws -> [PlannerItemField] {
    guard subtitle.isUnchanged, estimate.isUnchanged,
      links.isUnchanged, categoryIds.isUnchanged, tagIds.isUnchanged
    else {
      throw PlannerFailure(
        "unavailable", "This edit fixture currently supports title, notes and location only.")
    }
    switch title {
    case .clear:
      throw PlannerFailure(
        "invalidInput", "An Item title cannot be cleared.", propertyPath: "/command/changes/title")
    case .set(let value):
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PlannerFailure(
          "invalidInput", "An Item title must contain text.", propertyPath: "/command/changes/title"
        )
      }
    case .unchanged: break
    }
    if case .set(let value) = location, let coordinate = value.coordinate {
      guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
        (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude)
      else {
        throw PlannerFailure(
          "invalidInput", "Coordinates must be finite and within their geographic ranges.",
          propertyPath: "/command/changes/location/coordinate")
      }
    }
    var fields: [PlannerItemField] = []
    if !title.isUnchanged { fields.append(.title) }
    if !notes.isUnchanged { fields.append(.notes) }
    if !location.isUnchanged { fields.append(.location) }
    guard !fields.isEmpty else {
      throw PlannerFailure(
        "invalidInput", "An Item edit must contain at least one changed field.",
        propertyPath: "/command/changes")
    }
    return fields.sorted { $0.rawValue < $1.rawValue }
  }

  func applyingChanges(to input: PlannerItemContentInput) throws -> PlannerItemContentInput {
    var updatedTitle = input.title
    var updatedNotes = input.notes
    var updatedLocation = input.location
    switch title {
    case .set(let value): updatedTitle = value
    case .clear: throw PlannerFailure("invalidInput", "An Item title cannot be cleared.")
    case .unchanged: break
    }
    switch notes {
    case .set(let value): updatedNotes = value
    case .clear: updatedNotes = nil
    case .unchanged: break
    }
    switch location {
    case .set(let value): updatedLocation = value
    case .clear: updatedLocation = nil
    case .unchanged: break
    }
    return PlannerItemContentInput(
      title: updatedTitle, subtitle: input.subtitle, notes: updatedNotes,
      location: updatedLocation, estimate: input.estimate
    )
  }

  func editPayloadDigest(
    sourceId: UUID, fields: [PlannerItemField], hashes: [PlannerItemField: PlannerFieldHash],
    identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity]
  ) throws -> String {
    var changedValues: [String: PlannerCanonicalValue] = [:]
    if case .set(let value) = title { changedValues["title"] = .string(value) }
    switch notes {
    case .set(let value): changedValues["notes"] = .optional(.string(value))
    case .clear: changedValues["notes"] = .optional(nil)
    case .unchanged: break
    }
    switch location {
    case .set(let value): changedValues["location"] = .optional(value.canonicalValue)
    case .clear: changedValues["location"] = .optional(nil)
    case .unchanged: break
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
    let command = PlannerCanonicalValue.record([
      "type": .string("editItem"), "sourceId": .identity(sourceId),
      "changes": .record(changedValues), "expectedFieldHashes": .record(usedHashes),
    ])
    let value = PlannerCanonicalValue.record([
      "command": command, "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }
}
