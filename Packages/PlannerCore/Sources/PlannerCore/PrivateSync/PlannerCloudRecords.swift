import CloudKit
import Foundation

/// Values cross the Core actor; mutable CKRecords remain owned by the sync engine.
struct PlannerCloudNode: Codable, Sendable, Equatable {
  static let recordType = "PlannerNode_v1"
  static let zoneID = CKRecordZone.ID(zoneName: "Planner-v1", ownerName: CKCurrentUserDefaultName)

  let name: String
  let kind: String
  var fields: [String: Data]

  init(kind: String, identity: [Data], fields: [String: Data]) throws {
    guard !identity.isEmpty, identity.allSatisfy({ $0 != Data("null".utf8) }) else {
      throw PlannerFailure("readUnavailable", "A cloud record has unresolved identity.")
    }
    self.kind = kind
    self.fields = fields
    name = plannerDigest(
      PlannerCanonicalValue.ordered(
        [.string(kind)]
          + identity.map {
            .string($0.base64EncodedString())
          }
      ).encoded(), prefix: "p1_")
  }

  init(record: CKRecord) throws {
    guard record.recordType == Self.recordType, record.recordID.zoneID == Self.zoneID,
      (record["formatVersion"] as? NSNumber)?.intValue == 1,
      let kind = record["kind"] as? String
    else {
      throw PlannerFailure(
        "cloudRecordInvalid", "A private cloud record uses an unsupported format.")
    }
    name = record.recordID.recordName
    self.kind = kind
    var values: [String: Data] = [:]
    for key in record.allKeys() where key.hasPrefix("f_") {
      guard let value = record[key] as? Data else {
        throw PlannerFailure("cloudRecordInvalid", "A private cloud field has an invalid encoding.")
      }
      values[String(key.dropFirst(2))] = value
    }
    fields = values
  }

  func record(base: CKRecord?) throws -> CKRecord {
    let record: CKRecord
    if let base {
      record = try Self.restore(Self.archive(base))
      guard record.recordID.recordName == name else {
        throw PlannerFailure(
          "cloudRecordInvalid", "Private record metadata has a different identity.")
      }
    } else {
      record = CKRecord(
        recordType: Self.recordType, recordID: .init(recordName: name, zoneID: Self.zoneID))
    }
    record["formatVersion"] = NSNumber(value: 1)
    record["kind"] = kind as NSString
    for (key, value) in fields { record["f_" + key] = value as NSData }
    return record
  }

  /// Keep unsent field edits while accepting independent server changes.
  func merging(server: Self, base: Self?) throws -> Self {
    guard name == server.name, kind == server.kind else {
      throw PlannerFailure("cloudRecordInvalid", "Private cloud changes target different records.")
    }
    var merged = server
    for (key, value) in fields where value != base?.fields[key] { merged.fields[key] = value }
    if let localValue = fields["updatedAt"], let serverValue = server.fields["updatedAt"] {
      let decoder = JSONDecoder()
      if let localDate = try decoder.decode(Date?.self, from: localValue),
        let serverDate = try decoder.decode(Date?.self, from: serverValue)
      {
        merged.fields["updatedAt"] = serverDate > localDate ? serverValue : localValue
      }
    }
    return merged
  }

  static func archive(_ record: CKRecord) throws -> Data {
    try NSKeyedArchiver.archivedData(withRootObject: record, requiringSecureCoding: true)
  }

  static func restore(_ data: Data) throws -> CKRecord {
    guard let record = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: data)
    else {
      throw PlannerFailure("cloudRecordInvalid", "Private cloud record metadata is unreadable.")
    }
    return record
  }
}
