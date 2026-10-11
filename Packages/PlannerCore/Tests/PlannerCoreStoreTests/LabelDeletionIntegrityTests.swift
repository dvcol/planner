import CryptoKit
import Foundation
import PlannerCore
import Testing

struct LabelDeletionIntegrityTests {
  @Test(arguments: [PlannerEntityKind.category, .tag])
  func liveLabelClosureAndUnsupportedFamilyRejectTheEntireRecoverySnapshot(
    _ labelKind: PlannerEntityKind
  ) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
        storageMode: .localOnly))
    func createLabel(_ name: String) -> PlannerCommand {
      if labelKind == .category { return .createCategory(content: .init(name: name)) }
      return .createTag(content: .init(name: name))
    }
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let deletedResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: createLabel("Remove"))
      ).outcome,
      let deleted = deletedResult.generated.first,
      case .applied(let retainedResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: createLabel("Keep"))
      ).outcome,
      let retained = retainedResult.generated.first,
      case .source(let beforeSource) = await planner.read(
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
    let sourceLifetimeId: UUID
    switch beforeSource {
    case .category(let before): sourceLifetimeId = before.sourceLifetimeId
    case .tag(let before): sourceLifetimeId = before.sourceLifetimeId
    default: throw CancellationError()
    }
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
        "kind": labelKind.rawValue, "id": retained.id.uuidString,
        "lifetimeId": sourceLifetimeId.uuidString,
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
          "Reject recovery containing a live label closure or unsupported deletion metadata.")
        continue
      }
      #expect(failure.code == "recoveryIntegrityFailure")
    }
    try originalEnvelope.write(to: checkpointURL, options: .atomic)
    guard
      case .source(let afterSource) = await planner.read(
        session: session, request: .source(retained)),
      case .selected(let restored) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    switch (beforeSource, afterSource) {
    case (.category(let before), .category(let after)):
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
    case (.tag(let before), .tag(let after)):
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
    default: throw CancellationError()
    }
    #expect(restored.portableData == original.portableData)
  }
}
