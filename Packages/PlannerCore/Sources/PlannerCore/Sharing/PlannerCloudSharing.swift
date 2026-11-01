import CloudKit
import Foundation

/// Sharing authority is stored only in the owner's private control zone.
public actor PlannerLibrarySharing {
  private static let controlZone = CKRecordZone.ID(zoneName: "PlannerControl-v1")
  private static let controlID = CKRecord.ID(recordName: "sharing", zoneID: controlZone)
  let container: CKContainer

  public init(containerIdentifier: String) {
    container = CKContainer(identifier: containerIdentifier)
  }

  public func acceptedLibraries() async throws -> [PlannerSharedLibrary] {
    guard try await container.accountStatus() == .available else {
      throw PlannerFailure("privateCloudUnavailable", "Private iCloud is unavailable.")
    }
    let database = container.sharedCloudDatabase
    let zones = try await database.allRecordZones()
    var libraries: [PlannerSharedLibrary] = []
    for zone in zones where zone.zoneID.zoneName == PlannerCloudNode.zoneID.zoneName {
      var token: CKServerChangeToken?
      var more = true
      while more {
        let page = try await database.recordZoneChanges(
          inZoneWith: zone.zoneID, since: token,
          desiredKeys: [CKShare.SystemFieldKey.title, "kind", "f_scopeData"], resultsLimit: 200)
        for result in page.modificationResultsByID.values {
          if let share = try result.get().record as? CKShare {
            libraries.append(try await verifiedLibrary(share: share))
          }
        }
        token = page.changeToken
        more = page.moreComing
      }
    }
    return libraries.sorted {
      if $0.title == $1.title { return $0.id < $1.id }
      return $0.title.localizedStandardCompare($1.title) == .orderedAscending
    }
  }

  public func accept(_ metadata: CKShare.Metadata) async throws -> PlannerSharedLibrary {
    guard metadata.containerIdentifier == container.containerIdentifier,
      metadata.share.publicPermission == .none
    else {
      throw PlannerFailure("invalidInput", "This invitation is not a private Plan 2Do library.")
    }
    let accepted = try await container.accept(metadata)
    guard
      let share = try await container.sharedCloudDatabase.record(for: accepted.recordID) as? CKShare
    else {
      throw PlannerFailure("sharingUnavailable", "The accepted invitation is unavailable.")
    }
    return try await verifiedLibrary(share: share)
  }

  public func accept(url: URL) async throws -> PlannerSharedLibrary {
    guard url.scheme == "https", ["icloud.com", "www.icloud.com"].contains(url.host?.lowercased())
    else { throw PlannerFailure("invalidInput", "Use an iCloud sharing invitation link.") }
    return try await accept(container.shareMetadata(for: url))
  }

  func verifiedLibrary(share: CKShare) async throws -> PlannerSharedLibrary {
    let configuration: PlannerSharingConfiguration
    if share.recordID.recordName == CKRecordNameZoneWideShare {
      guard let data = share["f_scopeData"] as? Data else {
        throw PlannerFailure("sharingUnavailable", "The shared library scope is unavailable.")
      }
      configuration = try JSONDecoder().decode(PlannerSharingConfiguration.self, from: data)
      try configuration.validated()
      guard configuration.scope == .wholeLibrary, !configuration.isPreparing else {
        throw PlannerFailure("sharingUnavailable", "The shared library scope has changed.")
      }
    } else {
      guard share.recordID.recordName.hasPrefix("invitation_") else {
        throw PlannerFailure("sharingUnavailable", "This invitation has an unsupported format.")
      }
      let root = try await container.sharedCloudDatabase.record(
        for: .init(
          recordName: "sharing_" + share.recordID.recordName.dropFirst("invitation_".count),
          zoneID: share.recordID.zoneID))
      guard root["kind"] as? String == "sharingRoot", let data = root["f_scopeData"] as? Data else {
        throw PlannerFailure("sharingUnavailable", "The shared library scope is unavailable.")
      }
      configuration = try JSONDecoder().decode(PlannerSharingConfiguration.self, from: data)
      try configuration.validated()
      guard !configuration.isPreparing, configuration.shareName == share.recordID.recordName,
        configuration.usesHierarchy
      else { throw PlannerFailure("sharingUnavailable", "The shared library scope has changed.") }
    }
    return try PlannerSharedLibrary(share: share, configuration: configuration)
  }

  func configuration() async throws -> PlannerSharingConfiguration {
    do {
      let record = try await container.privateCloudDatabase.record(for: Self.controlID)
      guard let data = record["f_scopeData"] as? Data else {
        throw PlannerFailure("sharingUnavailable", "The sharing configuration is unreadable.")
      }
      let configuration = try JSONDecoder().decode(PlannerSharingConfiguration.self, from: data)
      try configuration.validated()
      return configuration
    } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
      return .init()
    }
  }

  /// Revoke before changing hierarchy membership. A failed preparation leaves no active invite.
  func prepare(scope: PlannerSharingScope, records: [CKRecord], names: Set<String>) async throws
    -> CKShare?
  {
    let database = container.privateCloudDatabase
    let old = try await configuration()
    guard !old.isPreparing else {
      throw PlannerFailure("sharingBusy", "Finish or stop the pending sharing setup first.")
    }
    let next = PlannerSharingConfiguration(
      scope: scope, isPreparing: true, revokingShareName: old.shareName)
    try next.validated()
    _ = try await database.save(CKRecordZone(zoneID: Self.controlZone))
    var control: CKRecord
    do { control = try await database.record(for: Self.controlID) } catch let error as CKError
      where error.code == .unknownItem
    {
      control = CKRecord(recordType: PlannerCloudNode.recordType, recordID: Self.controlID)
    }
    control["kind"] = "sharingControl" as NSString
    control["formatVersion"] = NSNumber(value: 1)
    control["f_scopeData"] = try JSONEncoder().encode(next) as NSData
    control = try await database.save(control)
    if let name = old.shareName {
      do {
        _ = try await database.deleteRecord(
          withID: .init(recordName: name, zoneID: PlannerCloudNode.zoneID))
      } catch let error as CKError where error.code == .unknownItem {}
    }
    // All domain records retain their public identities and original owner zone.
    let rootID = CKRecord.ID(recordName: next.rootName, zoneID: PlannerCloudNode.zoneID)
    let root: CKRecord?
    if scope != .off {
      root = try await database.save(
        Self.root(configuration: .init(scope: scope, generation: next.generation)))
    } else {
      root = nil
    }
    for batch in stride(from: 0, to: records.count, by: 200) {
      let requested = Array(records[batch..<min(batch + 200, records.count)])
      let current = try await database.records(for: requested.map(\.recordID))
      let changes = try requested.map { record in
        guard let result = current[record.recordID] else {
          throw PlannerFailure("sharingUnavailable", "A plan record is unavailable for sharing.")
        }
        return try result.get()
      }
      for record in changes {
        if next.usesHierarchy, names.contains(record.recordID.recordName) {
          record.setParent(rootID)
        } else {
          record.setParent(nil as CKRecord.ID?)
        }
      }
      let result = try await database.modifyRecords(
        saving: changes, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
      try Self.validateSaveResults(result.saveResults)
    }
    let share: CKShare?
    switch scope {
    case .off:
      share = nil
    case .wholeLibrary, .selectedLists:
      guard let root, let shareName = next.shareName else {
        throw PlannerFailure("sharingUnavailable", "The sharing root is unavailable.")
      }
      let currentRoot = try await database.record(for: root.recordID)
      let invitation = CKShare(
        rootRecord: currentRoot,
        shareID: .init(recordName: shareName, zoneID: PlannerCloudNode.zoneID))
      invitation.publicPermission = .none
      let title = scope == .wholeLibrary ? "Plan 2Do library" : "Plan 2Do Lists"
      invitation[CKShare.SystemFieldKey.title] = title as NSString
      let result = try await database.modifyRecords(
        saving: [currentRoot, invitation], deleting: [], savePolicy: .ifServerRecordUnchanged,
        atomically: true)
      try Self.validateSaveResults(result.saveResults)
      share = try result.saveResults[invitation.recordID]?.get() as? CKShare
    }
    if scope != .off, share == nil {
      throw PlannerFailure("sharingUnavailable", "CloudKit did not return the saved invitation.")
    }
    let ready = PlannerSharingConfiguration(scope: scope, generation: next.generation)
    control["f_scopeData"] = try JSONEncoder().encode(ready) as NSData
    _ = try await database.save(control)
    return share
  }

  /// Atomic peers report cancellation; preserve the record error that caused the batch to fail.
  static func validateSaveResults(_ results: [CKRecord.ID: Result<CKRecord, any Error>]) throws {
    let failures = results.values.compactMap { result -> (any Error)? in
      if case .failure(let error) = result { return error }
      return nil
    }
    if let error = failures.first(where: { ($0 as? CKError)?.code != .batchRequestFailed })
      ?? failures.first
    {
      throw error
    }
  }

  /// Stop also recovers an interrupted preparation without deleting any plan records.
  func stop() async throws {
    let database = container.privateCloudDatabase
    let current = try await configuration()
    for name in Set([current.shareName, current.revokingShareName].compactMap({ $0 })) {
      do {
        _ = try await database.deleteRecord(
          withID: .init(recordName: name, zoneID: PlannerCloudNode.zoneID))
      } catch let error as CKError where error.code == .unknownItem {}
    }
    guard current.scope != .off || current.isPreparing else { return }
    let control = try await database.record(for: Self.controlID)
    control["f_scopeData"] = try JSONEncoder().encode(PlannerSharingConfiguration()) as NSData
    _ = try await database.save(control)
  }

  func invitation(configuration: PlannerSharingConfiguration) async throws -> CKShare? {
    guard let name = configuration.shareName else { return nil }
    guard !configuration.isPreparing else {
      throw PlannerFailure("sharingBusy", "Sharing setup is incomplete. Stop sharing to reset it.")
    }
    return try await container.privateCloudDatabase.record(
      for: .init(recordName: name, zoneID: PlannerCloudNode.zoneID)) as? CKShare
  }

  static func root(configuration: PlannerSharingConfiguration) throws -> CKRecord {
    let record = CKRecord(
      recordType: PlannerCloudNode.recordType,
      recordID: .init(recordName: configuration.rootName, zoneID: PlannerCloudNode.zoneID))
    record["kind"] = "sharingRoot" as NSString
    record["formatVersion"] = NSNumber(value: 1)
    record["f_scopeData"] = try JSONEncoder().encode(configuration) as NSData
    return record
  }
}
