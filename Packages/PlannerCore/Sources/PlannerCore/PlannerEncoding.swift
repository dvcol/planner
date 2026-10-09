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
      "links": .ordered([]), "categoryIds": .identitySet([]), "tagIds": .identitySet([]),
    ])
  }

  func fieldHashes(datasetId: UUID, itemId: UUID, lifetimeId: UUID) -> [PlannerItemField:
    PlannerFieldHash]
  {
    guard case .record(let fields) = canonicalContent else { return [:] }
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
    guard links.isEmpty, categoryIds.isEmpty, tagIds.isEmpty else {
      throw PlannerFailure(
        "unavailable", "This first local fixture does not yet implement owned links or labels.")
    }
  }

  var readContent: PlannerItemContent {
    PlannerItemContent(
      title: title, subtitle: subtitle, notes: notes, location: location, estimate: estimate,
      links: [], categoryIds: [], tagIds: []
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
