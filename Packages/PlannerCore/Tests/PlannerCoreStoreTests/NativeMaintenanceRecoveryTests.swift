import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeMaintenanceRecoveryTests {
  @Test(arguments: [1, 2])
  func legacyAndEmptyMaintenanceEnvelopesRemainReadableWithoutMutation(envelopeVersion: Int)
    async throws
  {
    let fixture = try MaintenanceRecoveryFixture.create()
    let file = fixture.namespaceDirectory.appendingPathComponent("checkpoint-7.json")
    var envelope = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    envelope["formatVersion"] = envelopeVersion
    if envelopeVersion == 1 {
      envelope.removeValue(forKey: "maintenanceReceipts")
    } else {
      envelope["maintenanceReceipts"] = []
    }
    try JSONSerialization.data(withJSONObject: envelope).write(to: file, options: .atomic)
    let originalFiles = try fixture.files()
    let listed = await fixture.planner.inspectRecovery(
      request: .namespace(namespaceId: fixture.namespaceIdentifier))
    let selected = await fixture.planner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: fixture.namespaceIdentifier, checkpointGeneration: 7))
    guard case .listed(let view) = listed, case .selected(let selection) = selected else {
      Issue.record(
        "Both legacy and empty maintenance checkpoints remain readable: \(listed), \(selected)")
      return
    }
    #expect(view.acknowledgedSnapshot?.portableFormatVersion == 3)
    #expect(view.acknowledgedSnapshot?.checkpointGeneration == 7)
    #expect(selection.portableData == (try maintenanceFixtureData("informed-readd-v3")))
    #expect(selection.originalOperationId == nil && selection.proposalId == nil)
    #expect(try fixture.files() == originalFiles)
    #expect(!FileManager.default.fileExists(atPath: fixture.configuration.storeURL.path))
    #expect(!FileManager.default.fileExists(atPath: fixture.configuration.controlURL.path))
  }

  enum InvalidAcknowledgement: CaseIterable {
    case missingArray, nullArray, downgradedEnvelope, unsupportedEnvelope, duplicateIdentity
    case namespace, dataset, epoch, ownership, kind, rule, malformedRule
    case uppercaseDigest, shortDigest, commitState, zeroCheckpoint, futureCheckpoint,
      noncanonicalCheckpoint, numericCheckpoint
    case missingField, unknownField, malformedIdentity, nestedEvidence
  }

  @Test(arguments: InvalidAcknowledgement.allCases)
  func invalidMaintenanceEvidenceCannotAuthorizeRecoverySelection(scenario: InvalidAcknowledgement)
    async throws
  {
    let fixture = try MaintenanceRecoveryFixture.create()
    let file = fixture.namespaceDirectory.appendingPathComponent("checkpoint-7.json")
    var envelope = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    var records = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    switch scenario {
    case .missingArray, .nullArray, .downgradedEnvelope, .unsupportedEnvelope: break
    case .duplicateIdentity: records.append(records[0])
    case .namespace: records[0]["namespaceId"] = "00000000-0000-4000-8000-000000000921"
    case .dataset: records[0]["datasetId"] = "00000000-0000-4000-8000-000000000911"
    case .epoch: records[0]["epochId"] = "00000000-0000-4000-8000-000000000931"
    case .ownership: records[0]["ownershipBinding"] = "local:another-owner"
    case .kind: records[0]["kind"] = "unknownMaintenance"
    case .rule: records[0]["ruleVersion"] = 2
    case .malformedRule: records[0]["ruleVersion"] = "1"
    case .uppercaseDigest:
      records[0]["preparationDigest"] = "sha256:" + String(repeating: "A", count: 64)
    case .shortDigest: records[0]["preparationDigest"] = "sha256:abc"
    case .commitState: records[0]["commitState"] = "preparedUnverified"
    case .zeroCheckpoint: records[0]["checkpointGeneration"] = "0"
    case .futureCheckpoint: records[0]["checkpointGeneration"] = "8"
    case .noncanonicalCheckpoint: records[0]["checkpointGeneration"] = "07"
    case .numericCheckpoint: records[0]["checkpointGeneration"] = 7
    case .missingField: records[0].removeValue(forKey: "preparationDigest")
    case .unknownField: records[0]["operationId"] = "00000000-0000-4000-8000-000000000940"
    case .malformedIdentity: records[0]["maintenanceId"] = "not-an-identity"
    case .nestedEvidence: records[0] = ["evidence": records[0]]
    }
    envelope["maintenanceReceipts"] = records
    switch scenario {
    case .missingArray: envelope.removeValue(forKey: "maintenanceReceipts")
    case .nullArray: envelope["maintenanceReceipts"] = NSNull()
    case .downgradedEnvelope: envelope["formatVersion"] = 1
    case .unsupportedEnvelope: envelope["formatVersion"] = 3
    default: break
    }
    try JSONSerialization.data(withJSONObject: envelope).write(to: file, options: .atomic)
    let originalFiles = try fixture.files()
    let listed = await fixture.planner.inspectRecovery(
      request: .namespace(namespaceId: fixture.namespaceIdentifier))
    let selected = await fixture.planner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: fixture.namespaceIdentifier, checkpointGeneration: 7))
    guard case .failed(let listingFailure) = listed, case .failed(let selectionFailure) = selected
    else {
      Issue.record(
        "Malformed acknowledgement cannot supply a verified recovery view: \(listed), \(selected)")
      return
    }
    #expect(listingFailure.code == "recoveryIntegrityFailure")
    #expect(selectionFailure.code == "recoveryIntegrityFailure")
    #expect(try fixture.files() == originalFiles)
    #expect(!FileManager.default.fileExists(atPath: fixture.configuration.storeURL.path))
    #expect(!FileManager.default.fileExists(atPath: fixture.configuration.controlURL.path))
  }

  @Test(arguments: [false, true])
  func ordinaryWritesPreserveAcknowledgedMaintenanceAndOriginalCommandCheckpoints(
    failPublication: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(
        try maintenanceFixtureData("informed-readd-v3")),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite))
    else { throw CancellationError() }
    let original = PlannerOperation(
      operationId: UUID(), session: session, command: review.command,
      reviewToken: review.reviewToken)
    guard
      case .applied(let imported, .complete(let originalCheckpoint)) =
        await planner.execute(original).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let originalFile = namespaceDirectory.appendingPathComponent(
      "checkpoint-\(originalCheckpoint).json")
    var acknowledged = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: originalFile)) as? [String: Any])
    let identity = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: configuration.controlURL))
        as? [String: Any])
    let literal = try #require(
      JSONSerialization.jsonObject(with: maintenanceFixtureData("maintenance-recovery-v2"))
        as? [String: Any])
    var maintenance = try #require((literal["maintenanceReceipts"] as? [[String: Any]])?.first)
    for key in ["namespaceId", "datasetId", "epochId", "ownershipBinding"] {
      maintenance[key] = try #require(identity[key])
    }
    maintenance["checkpointGeneration"] = String(originalCheckpoint)
    acknowledged["formatVersion"] = 2
    acknowledged["maintenanceReceipts"] = [maintenance]
    let acknowledgedBytes = try JSONSerialization.data(withJSONObject: acknowledged)
    try acknowledgedBytes.write(to: originalFile, options: .atomic)
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    var observer: (any NSObjectProtocol)?
    if failPublication {
      observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
    }
    defer {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session,
        command: .createTag(content: .init(name: "Cloudy"))))
    guard case .applied(let saved, let recovery) = response.outcome else {
      Issue.record("The ordinary command must reach its truthful native save outcome: \(response)")
      return
    }
    let nextCheckpoint: Int64
    if failPublication {
      guard case .incomplete = recovery else { throw CancellationError() }
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      try obstruction.restore()
      guard
        case .applied(let retried, .complete(let checkpoint)) = await planner.retryRecovery(
          session: session, operationId: operationIdentifier
        ).outcome
      else { throw CancellationError() }
      #expect(retried == saved)
      nextCheckpoint = checkpoint
    } else {
      guard case .complete(let checkpoint) = recovery else { throw CancellationError() }
      nextCheckpoint = checkpoint
    }
    guard case .exported(let currentData) = await planner.exportData(session: session),
      case .selected(let selected) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: nextCheckpoint))
    else {
      Issue.record("A normal command must publish alongside acknowledged maintenance: \(response)")
      return
    }
    let published = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(nextCheckpoint).json")
        ))
        as? [String: Any])
    #expect(published["formatVersion"] as? Int == 2)
    let retained = try #require((published["maintenanceReceipts"] as? [[String: Any]])?.first)
    #expect(NSDictionary(dictionary: maintenance).isEqual(to: retained))
    let receipts = try #require(published["receipts"] as? [[String: Any]])
    #expect(
      Set(receipts.compactMap { $0["operationId"] as? String })
        == [original.operationId.uuidString, operationIdentifier.uuidString])
    #expect(
      receipts.first { $0["operationId"] as? String == original.operationId.uuidString }?[
        "checkpointGeneration"] as? String == String(originalCheckpoint))
    #expect(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString }?[
        "checkpointGeneration"] as? String == String(nextCheckpoint))
    #expect(nextCheckpoint == originalCheckpoint + 1)
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: selected.portableData) as? [String: Any])
    let exportedGraph = try #require(
      JSONSerialization.jsonObject(with: currentData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredGraph).isEqual(to: exportedGraph))
    #expect(try Data(contentsOf: originalFile) == acknowledgedBytes)
    let maintenanceIdentifier = try #require(
      UUID(uuidString: "00000000-0000-4000-8000-000000000940"))
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: maintenanceIdentifier),
      case .applied(let replayed, .complete(let replayCheckpoint)) =
        await planner.execute(original).outcome
    else {
      Issue.record("Maintenance must not become a command receipt or change original replay.")
      return
    }
    #expect(replayed == imported && replayCheckpoint == originalCheckpoint)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == currentData)
  }

  @Test func acknowledgedMaintenanceEnvelopeIsInspectableWithoutOpeningPlannerStorage() async throws
  {
    let fixture = try MaintenanceRecoveryFixture.create()
    let originalFiles = try fixture.files()
    let listed = await fixture.planner.inspectRecovery(
      request: .namespace(namespaceId: fixture.namespaceIdentifier))
    guard case .listed(let view) = listed else {
      Issue.record("Inspect the independently frozen maintenance checkpoint: \(listed)")
      return
    }
    #expect(view.availability == .available)
    #expect(view.acknowledgedSnapshot?.storageSchemaVersion == 19)
    #expect(view.acknowledgedSnapshot?.portableFormatVersion == 3)
    #expect(view.acknowledgedSnapshot?.checkpointGeneration == 7)
    #expect(view.preparedProposals.isEmpty)
    let selected = await fixture.planner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: fixture.namespaceIdentifier, checkpointGeneration: 7))
    guard case .selected(let selection) = selected else {
      Issue.record("Select the exact acknowledged portable bytes: \(selected)")
      return
    }
    #expect(selection.evidence == .acknowledgedSnapshot)
    #expect(selection.checkpointGeneration == 7)
    #expect(selection.proposalId == nil && selection.originalOperationId == nil)
    #expect(selection.portableData == (try maintenanceFixtureData("informed-readd-v3")))
    #expect(selection.decodedBackup.backup.membershipRemovals.count == 1)
    #expect(try fixture.files() == originalFiles)
    #expect(!FileManager.default.fileExists(atPath: fixture.configuration.storeURL.path))
    #expect(!FileManager.default.fileExists(atPath: fixture.configuration.controlURL.path))
  }
}

private struct MaintenanceRecoveryFixture {
  let planner: Planner
  let configuration: PlannerStorageConfiguration
  let namespaceIdentifier: UUID
  let namespaceDirectory: URL

  static func create() throws -> Self {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .shareExtension, storageMode: .localOnly)
    let namespaceIdentifier = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000920"))
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespaceIdentifier.uuidString)
    try FileManager.default.createDirectory(
      at: namespaceDirectory, withIntermediateDirectories: true)
    let identity: [String: Any] = [
      "schemaVersion": 19, "datasetId": "00000000-0000-4000-8000-000000000910",
      "namespaceId": namespaceIdentifier.uuidString,
      "epochId": "00000000-0000-4000-8000-000000000930",
      "ownershipBinding": "local:membership-fixture",
    ]
    try JSONSerialization.data(withJSONObject: identity).write(
      to: namespaceDirectory.appendingPathComponent("identity.json"), options: .atomic)
    try maintenanceFixtureData("maintenance-recovery-v2").write(
      to: namespaceDirectory.appendingPathComponent("checkpoint-7.json"), options: .atomic)
    return .init(
      planner: Planner(configuration: configuration), configuration: configuration,
      namespaceIdentifier: namespaceIdentifier, namespaceDirectory: namespaceDirectory)
  }

  func files() throws -> [String: Data] {
    let files = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil)
    return try Dictionary(
      uniqueKeysWithValues: files.map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
  }
}

private func maintenanceFixtureData(_ name: String) throws -> Data {
  #if SWIFT_PACKAGE
    let bundle = Bundle.module
  #else
    let bundle = Bundle(for: NativeMaintenanceRecoveryFixtureBundle.self)
  #endif
  let file = try #require(
    bundle.url(
      forResource: name, withExtension: "json", subdirectory: "Fixtures/MembershipConsolidation"))
  return try Data(contentsOf: file)
}

private final class NativeMaintenanceRecoveryFixtureBundle: NSObject {}
