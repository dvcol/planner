import CryptoKit
import Darwin
import Foundation
import PlannerCore
import Testing

struct RecoveryHeadSelectionTests {
  @Test func latestCheckpointUsesNumericGenerationOrder() async throws {
    let fixture = try await RecoveryHeadFixture.create()
    for generation: Int64 in [2, 10] {
      var envelope = fixture.envelope
      envelope["checkpointGeneration"] = String(generation)
      try fixture.write(envelope, generation: generation)
    }

    guard
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(let generation, let incomplete, let maintenance, let blocked) = status.recovery,
      case .selected(let selected) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: fixture.namespaceId, checkpointGeneration: 10))
    else {
      Issue.record("The numeric head must remain readable through public recovery APIs.")
      return
    }
    #expect(generation == 10)
    #expect(incomplete.isEmpty && maintenance.isEmpty && !blocked)
    #expect(selected.checkpointGeneration == 10)
    #expect(selected.decodedBackup.backup.items.first?.id == fixture.source.id)
  }

  @Test func mismatchedFilenameAndRecordedGenerationMakeRecoveryUnavailable() async throws {
    let fixture = try await RecoveryHeadFixture.create()
    var envelope = fixture.envelope
    envelope["checkpointGeneration"] = "3"
    try fixture.write(envelope, generation: 2)

    guard
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .unavailable(let failure) = status.recovery,
      case .failed(let selectionFailure) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: fixture.namespaceId, checkpointGeneration: 2))
    else {
      Issue.record("A checkpoint filename cannot disagree with its recorded generation.")
      return
    }
    #expect(failure.code == "recoveryIntegrityFailure")
    #expect(selectionFailure.code == "recoveryIntegrityFailure")
  }

  @Test(arguments: [false, true])
  func corruptHighestCheckpointNeverFallsBackToOlderData(duplicateSource: Bool) async throws {
    let fixture = try await RecoveryHeadFixture.create()
    var envelope = fixture.envelope
    envelope["checkpointGeneration"] = "2"
    if duplicateSource {
      envelope = try duplicatingSource(in: envelope)
    } else {
      envelope["dataDigest"] = "sha256:invalid"
    }
    try fixture.write(envelope, generation: 2)

    guard
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .unavailable(let failure) = status.recovery,
      case .failed(let selectionFailure) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: fixture.namespaceId, checkpointGeneration: 2)),
      case .selected(let older) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: fixture.namespaceId, checkpointGeneration: 1))
    else {
      Issue.record("A damaged current head must remain unavailable despite a valid older copy.")
      return
    }
    #expect(failure.code == "recoveryIntegrityFailure")
    #expect(selectionFailure.code == "recoveryIntegrityFailure")
    #expect(older.checkpointGeneration == 1)
    #expect(older.decodedBackup.backup.items.count == 1)
    #expect(older.decodedBackup.backup.items.first?.id == fixture.source.id)
  }

  @Test func olderCorruptPayloadDoesNotPoisonCurrentHeadButStillRejectsExplicitSelection()
    async throws
  {
    let fixture = try await RecoveryHeadFixture.create()
    var currentEnvelope = fixture.envelope
    currentEnvelope["checkpointGeneration"] = "2"
    try fixture.write(currentEnvelope, generation: 2)
    try fixture.write(duplicatingSource(in: fixture.envelope), generation: 1)

    guard
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(let generation, let incomplete, let maintenance, let blocked) = status.recovery,
      case .selected(let current) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: fixture.namespaceId, checkpointGeneration: 2)),
      case .failed(let olderFailure) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: fixture.namespaceId, checkpointGeneration: 1))
    else {
      Issue.record("Validate the selected head and independently reject damaged historical data.")
      return
    }
    #expect(generation == 2)
    #expect(incomplete.isEmpty && maintenance.isEmpty && !blocked)
    #expect(current.checkpointGeneration == 2)
    #expect(current.decodedBackup.backup.items.count == 1)
    #expect(current.decodedBackup.backup.items.first?.id == fixture.source.id)
    #expect(olderFailure.code == "recoveryIntegrityFailure")
  }
}

struct RecoveryHeaderCacheTests {
  @Test(arguments: RecoveryHeaderFault.allCases, [false, true])
  func warmedHeadersRejectReplacementAndPreservedModificationTime(
    fault: RecoveryHeaderFault, atomic: Bool
  ) async throws {
    let fixture = try await RecoveryHeadFixture.create()
    var current = fixture.envelope
    current["checkpointGeneration"] = "2"
    try fixture.write(current, generation: 2)
    let file: URL
    if fault.isProposal {
      file = try #require(
        FileManager.default.contentsOfDirectory(
          at: fixture.namespaceURL, includingPropertiesForKeys: nil
        )
        .first { $0.lastPathComponent.hasPrefix("proposal-") })
    } else {
      file = fixture.namespaceURL.appendingPathComponent("checkpoint-1.json")
    }
    var document = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    let original = try JSONSerialization.data(withJSONObject: document, options: .sortedKeys)
    try original.write(to: file, options: .atomic)
    guard
      case .status(let warm) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(2, _, _, false) = warm.recovery,
      case .listed = await fixture.planner.inspectRecovery(
        request: .namespace(namespaceId: fixture.namespaceId))
    else {
      Issue.record("The valid current head must warm both historical header kinds.")
      return
    }
    switch fault {
    case .checkpointOwner, .proposalOwner: document["datasetId"] = UUID().uuidString
    case .checkpointVersion: document["formatVersion"] = 9
    case .checkpointGeneration: document["checkpointGeneration"] = "9"
    case .proposalEvidence: document["evidence"] = "preparedUnverifieX"
    case .proposalIdentity: document["proposalId"] = UUID().uuidString
    }
    let damaged = try JSONSerialization.data(withJSONObject: document, options: .sortedKeys)
    #expect(damaged.count == original.count)
    if atomic {
      try damaged.write(to: file, options: .atomic)
    } else {
      let handle = try FileHandle(forUpdating: file)
      defer { try? handle.close() }
      var before = stat()
      #expect(fstat(handle.fileDescriptor, &before) == 0)
      try handle.write(contentsOf: damaged)
      let times = [before.st_atimespec, before.st_mtimespec]
      #expect(futimens(handle.fileDescriptor, times) == 0)
      var after = stat()
      #expect(fstat(handle.fileDescriptor, &after) == 0)
      #expect(before.st_ino == after.st_ino && before.st_size == after.st_size)
      #expect(before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec)
      #expect(before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec)
      #expect(
        before.st_ctimespec.tv_sec != after.st_ctimespec.tv_sec
          || before.st_ctimespec.tv_nsec != after.st_ctimespec.tv_nsec)
    }
    guard
      case .failed(let failure) = await fixture.planner.inspectRecovery(
        request: .namespace(namespaceId: fixture.namespaceId))
    else {
      Issue.record("Warm cached metadata must not hide a damaged historical header.")
      return
    }
    #expect(failure.code == "recoveryIntegrityFailure")
  }

  @Test func warmHeaderFollowsSymlinkTargetReplacement() async throws {
    let fixture = try await RecoveryHeadFixture.create()
    var current = fixture.envelope
    current["checkpointGeneration"] = "2"
    try fixture.write(current, generation: 2)
    let link = fixture.namespaceURL.appendingPathComponent("checkpoint-1.json")
    let target = fixture.namespaceURL.appendingPathComponent("retained-checkpoint.json")
    try FileManager.default.moveItem(at: link, to: target)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    guard
      case .status(let warm) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(2, _, _, false) = warm.recovery
    else {
      Issue.record("The original symlink target must be readable before warming.")
      return
    }
    var damaged = fixture.envelope
    damaged["datasetId"] = UUID().uuidString
    let replacement = fixture.namespaceURL.appendingPathComponent("replacement-target.json")
    try JSONSerialization.data(withJSONObject: damaged).write(to: replacement)
    try FileManager.default.removeItem(at: link)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: replacement)
    guard
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .unavailable(let failure) = status.recovery
    else {
      Issue.record("Retargeting a warmed symlink must invalidate its decoded header.")
      return
    }
    #expect(failure.code == "recoveryIntegrityFailure")
  }

  @Test func warmedCurrentHeadStillRejectsPayloadOnlyDamage() async throws {
    let fixture = try await RecoveryHeadFixture.create()
    guard
      case .status(let warm) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(1, _, _, false) = warm.recovery
    else {
      Issue.record("The real acknowledged head must be readable before warming.")
      return
    }
    var damaged = fixture.envelope
    damaged["dataDigest"] = "sha256:invalid"
    try fixture.write(damaged, generation: 1)
    guard
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .unavailable(let failure) = status.recovery
    else {
      Issue.record("A warm header cannot authorize a damaged current payload.")
      return
    }
    #expect(failure.code == "recoveryIntegrityFailure")
  }

  @Test func anotherPlannerCanAppendANewHeadAfterWarmReads() async throws {
    let fixture = try await RecoveryHeadFixture.create()
    guard
      case .status(let warm) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(1, _, _, false) = warm.recovery
    else {
      Issue.record("The first reader must warm the existing head.")
      return
    }
    let directory = fixture.namespaceURL.deletingLastPathComponent().deletingLastPathComponent()
    let writer = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await writer.bootstrap(),
      case .applied(_, .complete(2)) = await writer.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "New head")))
      )
      .outcome,
      case .status(let current) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(2, _, _, false) = current.recovery
    else {
      Issue.record("Warm readers must freshly enumerate a head appended by another Planner.")
      return
    }
  }

  @Test func independentNamespacesKeepTheirOwnWarmHeaders() async throws {
    let first = try await RecoveryHeadFixture.create()
    let second = try await RecoveryHeadFixture.create()
    let firstPlanner = first.planner
    let firstSession = first.session
    let secondPlanner = second.planner
    let secondSession = second.session
    for _ in 0..<2 {
      async let firstRead = firstPlanner.read(session: firstSession, request: .status)
      async let secondRead = secondPlanner.read(session: secondSession, request: .status)
      guard case .status(let firstStatus) = await firstRead,
        case .status(let secondStatus) = await secondRead,
        case .known(1, _, _, false) = firstStatus.recovery,
        case .known(1, _, _, false) = secondStatus.recovery
      else {
        Issue.record("Independent owners and namespaces must not share header authorization.")
        return
      }
    }
  }

  @Test func repeatedPublicStatusReadsValidateLargeRetainedHistory() async throws {
    let fixture = try await RecoveryHeadFixture.create()
    for generation: Int64 in 1...150 {
      var historical = fixture.envelope
      historical["checkpointGeneration"] = String(generation)
      historical["historicalPadding"] = String(repeating: "x", count: 131_072)
      try fixture.write(historical, generation: generation)
    }
    var current = fixture.envelope
    current["checkpointGeneration"] = "151"
    try fixture.write(current, generation: 151)
    var durations: [Double] = []
    for _ in 0..<2 {
      let start = ContinuousClock.now
      guard
        case .status(let status) = await fixture.planner.read(
          session: fixture.session, request: .status),
        case .known(151, _, _, false) = status.recovery
      else {
        Issue.record("Every cold or warm read must select and validate the numeric current head.")
        return
      }
      let duration = start.duration(to: .now).components
      durations.append(Double(duration.seconds) + Double(duration.attoseconds) / 1e18)
    }
    print("RECOVERY_HEADER_BENCHMARK seconds=\(durations)")
  }
}

enum RecoveryHeaderFault: CaseIterable, Sendable {
  case checkpointOwner, checkpointVersion, checkpointGeneration
  case proposalOwner, proposalEvidence, proposalIdentity

  var isProposal: Bool {
    switch self {
    case .proposalOwner, .proposalEvidence, .proposalIdentity: true
    case .checkpointOwner, .checkpointVersion, .checkpointGeneration: false
    }
  }
}

private struct RecoveryHeadFixture {
  let planner: Planner
  let session: PlannerDatasetSession
  let source: PlannerEntityReference
  let namespaceId: UUID
  let namespaceURL: URL
  let envelope: [String: Any]

  /// Creates an acknowledged checkpoint through the real native writer.
  static func create() async throws -> Self {
    let directory = try makePlannerStoreFixtureDirectory()
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory,
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let result, .complete(let generation)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Retained item")))
      ).outcome,
      let source = result.generated.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    #expect(generation == 1)
    let namespaceURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
    let envelope = try #require(
      JSONSerialization.jsonObject(
        with: Data(contentsOf: namespaceURL.appendingPathComponent("checkpoint-1.json")))
        as? [String: Any])
    return Self(
      planner: planner, session: session, source: source, namespaceId: namespace.namespaceId,
      namespaceURL: namespaceURL, envelope: envelope)
  }

  /// Writes a controlled checkpoint fault at the existing archive file boundary.
  func write(_ envelope: [String: Any], generation: Int64) throws {
    try JSONSerialization.data(withJSONObject: envelope).write(
      to: namespaceURL.appendingPathComponent("checkpoint-\(generation).json"), options: .atomic)
  }
}

/// Retains a correct digest while making the portable source graph invalid.
private func duplicatingSource(in envelope: [String: Any]) throws -> [String: Any] {
  var damagedEnvelope = envelope
  let encodedPayload = try #require(envelope["portablePayloadBase64"] as? String)
  let payload = try #require(Data(base64Encoded: encodedPayload))
  var backup = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
  let sources = try #require(backup["sources"] as? [[String: Any]])
  backup["sources"] = sources + [try #require(sources.first)]
  let damagedPayload = try JSONSerialization.data(withJSONObject: backup)
  damagedEnvelope["portablePayloadBase64"] = damagedPayload.base64EncodedString()
  damagedEnvelope["dataDigest"] =
    "sha256:" + SHA256.hash(data: damagedPayload).map { String(format: "%02x", $0) }.joined()
  return damagedEnvelope
}
