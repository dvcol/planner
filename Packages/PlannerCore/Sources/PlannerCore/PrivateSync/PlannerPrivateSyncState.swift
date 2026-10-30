import CloudKit
import Darwin
import Foundation
import SwiftData

/// Private transport bookkeeping is local and excluded from Planner data backups.
enum PlannerPrivateSchemaV20: VersionedSchema {
  static let versionIdentifier = Schema.Version(20, 0, 0)
  static var models: [any PersistentModel.Type] { PlannerSchemaV19.models + [SyncState.self] }

  @Model final class SyncState {
    var ownershipBinding: String = ""
    var stateData: Data? = nil
    var statusData: Data? = nil
    var recoveryPending: Bool = false
    var syncedTransaction: Int64 = 0

    init(ownershipBinding: String, stateData: Data) {
      self.ownershipBinding = ownershipBinding
      self.stateData = stateData
    }
  }
}

enum PlannerPrivateMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    PlannerMigrationPlan.schemas + [PlannerPrivateSchemaV20.self]
  }
  static var stages: [MigrationStage] {
    PlannerMigrationPlan.stages + [
      .lightweight(fromVersion: PlannerSchemaV19.self, toVersion: PlannerPrivateSchemaV20.self)
    ]
  }
}

struct PlannerPrivateSyncState: Codable, Sendable {
  let version: Int
  let ownershipBinding: String
  var serialization: CKSyncEngine.State.Serialization?
  var serverRecords: [String: Data] = [:]
  var incomingRecords: [String: Data] = [:]
  var incomingDeletions: Set<String> = []
  var zoneCreated = false

  init(ownershipBinding: String) {
    version = 1
    self.ownershipBinding = ownershipBinding
  }

  func validated(binding: String) throws {
    guard version == 1, ownershipBinding == binding else {
      throw PlannerFailure(
        "ownershipUnverified", "Private synchronization state has different ownership.")
    }
    for (name, data) in serverRecords.merging(incomingRecords, uniquingKeysWith: { _, new in new })
    {
      guard try PlannerCloudNode.restore(data).recordID.recordName == name else {
        throw PlannerFailure(
          "cloudRecordInvalid", "Private synchronization metadata has inconsistent identity.")
      }
    }
  }
}

enum PlannerPrivateSyncPersistence: Sendable {
  case saved
  case recoveryIncomplete(PlannerFailure)
}

struct PlannerStoredCloudObservation: Codable {
  let activity: String
  let eventId: String?
  let observedAt: Date?
  let reasonCode: String?
  let reasonMessage: String?

  init(_ observation: PlannerCloudObservation) {
    switch observation.state {
    case .unknown: activity = "unknown"
    case .idle: activity = "idle"
    case .inProgress: activity = "inProgress"
    case .error: activity = "error"
    }
    eventId = observation.eventId
    observedAt = observation.observedAt
    reasonCode = observation.reason?.code
    reasonMessage = observation.reason?.message
  }

  func read(binding: String) -> PlannerCloudObservation {
    let state: PlannerCloudObservation.State
    switch activity {
    case "idle": state = .idle
    case "inProgress": state = .inProgress
    case "error": state = .error
    default: state = .unknown
    }
    let reason = reasonCode.flatMap { code in reasonMessage.map { PlannerFailure(code, $0) } }
    return .init(
      state: state, storeIdentity: binding, eventId: eventId, observedAt: observedAt, reason: reason
    )
  }
}

/// One main-app worker owns an account's engine; extensions never acquire this lease.
final class PlannerPrivateSyncLease: @unchecked Sendable {
  private let descriptor: Int32

  init?(directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("sync-worker.lock")
    let opened = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
    guard opened >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
      let code = errno
      close(opened)
      if code == EWOULDBLOCK { return nil }
      throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
    descriptor = opened
  }

  deinit {
    flock(descriptor, LOCK_UN)
    close(descriptor)
  }
}
