import CryptoKit
import Foundation
import PlannerCore
import Testing

struct CategoryDeletionIntegrityTests {
  @Test func liveCategoryClosureAndUnsupportedFamilyRejectTheEntireRecoverySnapshot() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
        storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let deletedResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createCategory(content: .init(name: "Remove")))
      ).outcome,
      let deleted = deletedResult.generated.first,
      case .applied(let retainedResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createCategory(content: .init(name: "Keep")))
      ).outcome,
      let retained = retainedResult.generated.first,
      case .source(.category(let before)) = await planner.read(
        session: session, request: .source(retained)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: deleted)),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let checkpointURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-\(checkpoint).json")
    let originalEnvelope = try Data(contentsOf: checkpointURL)
    defer { try? originalEnvelope.write(to: checkpointURL, options: .atomic) }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: originalEnvelope) as? [String: Any])
    var payload = try #require(
      JSONSerialization.jsonObject(with: original.portableData) as? [String: Any])
    let marker = try #require((payload["deletionMarkers"] as? [[String: Any]])?.first)
    var live = marker
    live["target"] = [
      "kind": "source",
      "source": [
        "kind": "category", "id": retained.id.uuidString,
        "lifetimeId": before.sourceLifetimeId.uuidString,
      ],
    ]
    var family = marker
    family["closedFamilyId"] = UUID().uuidString
    for markers in [[live], [family], [marker, marker]] {
      payload["deletionMarkers"] = markers
      let bytes = try JSONSerialization.data(withJSONObject: payload)
      envelope["portablePayloadBase64"] = bytes.base64EncodedString()
      envelope["dataDigest"] =
        "sha256:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
      try JSONSerialization.data(withJSONObject: envelope).write(
        to: checkpointURL, options: .atomic)
      guard
        case .failed(let failure) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else {
        Issue.record(
          "Reject recovery containing a live Category closure or unsupported deletion metadata.")
        continue
      }
      #expect(failure.code == "recoveryIntegrityFailure")
    }
    try originalEnvelope.write(to: checkpointURL, options: .atomic)
    guard
      case .source(.category(let after)) = await planner.read(
        session: session, request: .source(retained)),
      case .selected(let restored) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
    #expect(restored.portableData == original.portableData)
  }
}
