import CloudKit
import Foundation

/// A library has one invitation group and one sharing scope at a time.
public enum PlannerSharingScope: Sendable, Equatable, Hashable, Codable {
  case off
  case wholeLibrary
  case selectedLists(Set<UUID>)
}

/// The account, owner zone and invitation jointly identify a received library.
public struct PlannerSharedLibrary: Sendable, Equatable, Codable, Identifiable {
  public let ownerName: String
  public let zoneName: String
  public let shareName: String
  public let generation: UUID
  public let title: String
  public let scope: PlannerSharingScope
  public let canEdit: Bool

  public var id: String {
    plannerDigest(
      PlannerCanonicalValue.ordered([
        .string(ownerName), .string(zoneName), .string(shareName), .string(generation.uuidString),
      ]).encoded(), prefix: "shared_")
  }

  var zoneID: CKRecordZone.ID { .init(zoneName: zoneName, ownerName: ownerName) }
  var shareID: CKRecord.ID { .init(recordName: shareName, zoneID: zoneID) }

  var rootID: CKRecord.ID? {
    guard case .selectedLists = scope, shareName.hasPrefix("invitation_") else { return nil }
    return .init(
      recordName: "sharing_" + shareName.dropFirst("invitation_".count), zoneID: zoneID)
  }

  /// A received zone can contain several invitations; only this hierarchy belongs here.
  func contains(_ record: CKRecord) -> Bool {
    guard record.recordID.zoneID == zoneID else { return false }
    if case .wholeLibrary = scope { return true }
    guard let rootID else { return false }
    return record.parent?.recordID == rootID
  }

  init(share: CKShare, configuration: PlannerSharingConfiguration) throws {
    guard share.recordID.zoneID.zoneName == PlannerCloudNode.zoneID.zoneName,
      let participant = share.currentUserParticipant,
      participant.acceptanceStatus == .accepted, participant.role != .owner,
      participant.permission == .readOnly || participant.permission == .readWrite,
      share.publicPermission == .none, configuration.scope != .off
    else {
      throw PlannerFailure("sharingUnavailable", "This invitation does not grant library access.")
    }
    ownerName = share.recordID.zoneID.ownerName
    zoneName = share.recordID.zoneID.zoneName
    shareName = share.recordID.recordName
    generation = configuration.generation
    title = share[CKShare.SystemFieldKey.title] as? String ?? "Shared library"
    scope = configuration.scope
    canEdit = participant.permission == .readWrite
  }
}

/// Owner authority lives in a separate private zone, never inside the shared data area.
struct PlannerSharingConfiguration: Codable, Sendable, Equatable {
  let version: Int
  let scope: PlannerSharingScope
  let generation: UUID
  let isPreparing: Bool
  let revokingShareName: String?

  init(
    scope: PlannerSharingScope = .off, generation: UUID = UUID(), isPreparing: Bool = false,
    revokingShareName: String? = nil
  ) {
    version = 1
    self.scope = scope
    self.generation = generation
    self.isPreparing = isPreparing
    self.revokingShareName = revokingShareName
  }

  var rootName: String { "sharing_" + generation.uuidString.lowercased() }
  var shareName: String? {
    switch scope {
    case .off: nil
    case .wholeLibrary: CKRecordNameZoneWideShare
    case .selectedLists: "invitation_" + generation.uuidString.lowercased()
    }
  }

  func validated() throws {
    guard version == 1 else {
      throw PlannerFailure("unsupportedVersion", "Update Plan 2Do to use this sharing setup.")
    }
    if case .selectedLists(let identifiers) = scope, identifiers.isEmpty {
      throw PlannerFailure("invalidInput", "Choose at least one List to share.")
    }
  }
}

/// A non-authorizing preview; Apply always re-reads and validates the current graph.
public struct PlannerSharingPreview: Sendable {
  public let sources: [PlannerEntityReference]
  public let membershipCount: Int
  public let recordCount: Int
}
