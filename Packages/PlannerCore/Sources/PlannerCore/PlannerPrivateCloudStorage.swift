import CloudKit
import Foundation

/// Resolves account ownership without giving CloudKit control of the local domain store.
struct PlannerPrivateCloudStorage: Sendable {
  enum Account: Sendable {
    case available(owner: String)
    case unavailable(PlannerFailure)
    case notObserved

    var observation: PlannerAccountObservation {
      switch self {
      case .available: return .available
      case .unavailable(let reason): return .unavailable(reason)
      case .notObserved: return .unknown
      }
    }
  }

  private struct Selection: Codable {
    let version: Int
    let scope: String
    let owner: String
  }

  let containerIdentifier: String
  let scope: String
  let selectionURL: URL

  init(configuration: PlannerStorageConfiguration, containerIdentifier: String) throws {
    guard containerIdentifier.hasPrefix("iCloud."), containerIdentifier.utf8.count <= 255,
      containerIdentifier.dropFirst(7).split(separator: ".", omittingEmptySubsequences: false)
        .allSatisfy({ part in
          !part.isEmpty
            && part.utf8.allSatisfy {
              (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                || $0 == 45
            }
        })
    else {
      throw PlannerFailure(
        "invalidInput", "Private synchronization requires an iCloud container identifier.")
    }
    guard
      let environment = Bundle.main.object(forInfoDictionaryKey: "PlannerCloudEnvironment")
        as? String, ["Development", "Production"].contains(environment)
    else {
      throw PlannerFailure(
        "cloudConfigurationRequired", "The signed app must declare its CloudKit environment.")
    }
    self.containerIdentifier = containerIdentifier
    scope = plannerDigest(
      PlannerCanonicalValue.ordered([
        .string("PlannerPrivateCloud-v1"), .string(containerIdentifier), .string(environment),
      ]).encoded(), prefix: "")
    selectionURL = configuration.controlURL.deletingLastPathComponent()
      .appendingPathComponent("private-cloud/\(scope)/selected-account.json")
  }

  func account() async -> Account {
    do {
      let container = CKContainer(identifier: containerIdentifier)
      guard try await container.accountStatus() == .available else {
        return .unavailable(
          .init(
            "privateCloudUnavailable", "Private iCloud is unavailable; plans stay on this device."))
      }
      let record = try await container.userRecordID()
      let owner = plannerDigest(
        PlannerCanonicalValue.ordered([.string(scope), .string(record.recordName)]).encoded(),
        prefix: "")
      return .available(owner: owner)
    } catch {
      return .unavailable(
        .init(
          "privateCloudUnavailable",
          "Private iCloud access could not be verified; plans stay on this device."))
    }
  }

  /// The caller holds the common writer gate while reading or changing this selection.
  func selectedOwner() throws -> String? {
    guard FileManager.default.fileExists(atPath: selectionURL.path) else { return nil }
    do {
      let selection = try JSONDecoder().decode(
        Selection.self, from: Data(contentsOf: selectionURL))
      guard selection.version == 1, selection.scope == scope,
        selection.owner.utf8.count == 64,
        selection.owner.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
      else { throw ownershipFailure() }
      return selection.owner
    } catch {
      throw ownershipFailure()
    }
  }

  func select(owner: String) throws {
    try plannerWriteDurably(
      JSONEncoder().encode(Selection(version: 1, scope: scope, owner: owner)), to: selectionURL)
  }

  func binding(owner: String) -> String { "private-cloud-v1:\(scope):\(owner)" }

  func configuration(base: PlannerStorageConfiguration, owner: String?)
    -> PlannerStorageConfiguration
  {
    guard let owner else { return base }
    let suffix = "private-cloud/\(scope)/\(owner)"
    return .init(
      storeURL: base.storeURL.deletingLastPathComponent().appendingPathComponent(suffix)
        .appendingPathComponent(base.storeURL.lastPathComponent),
      controlURL: base.controlURL.deletingLastPathComponent().appendingPathComponent(suffix)
        .appendingPathComponent(base.controlURL.lastPathComponent),
      recoveryDirectoryURL: base.recoveryDirectoryURL.appendingPathComponent(suffix),
      processRole: base.processRole, storageMode: base.storageMode)
  }

  private func ownershipFailure() -> PlannerFailure {
    .init("ownershipUnverified", "The retained private-account selection cannot be verified.")
  }
}

/// NotificationCenter tokens are immutable and may be removed on any thread.
final class PlannerCloudAccountObservation: @unchecked Sendable {
  private let token: any NSObjectProtocol

  init(changed: @escaping @Sendable () -> Void) {
    token = NotificationCenter.default.addObserver(
      forName: .CKAccountChanged, object: nil, queue: nil
    ) { _ in changed() }
  }

  deinit { NotificationCenter.default.removeObserver(token) }
}
