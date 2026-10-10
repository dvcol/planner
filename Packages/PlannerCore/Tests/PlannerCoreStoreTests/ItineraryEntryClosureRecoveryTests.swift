import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ItineraryEntryClosureRecoveryTests {
  @Test func liveEntryClosureUnsupportedFamilyAndMalformedTargetsRejectWithoutChangingSavedData()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
        storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    var entryIds: [UUID] = []
    for _ in 0..<2 {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entryIds.append(identifier)
    }
    _ = try await save(.removeItineraryEntry(itineraryId: itinerary.id, entryId: entryIds[0]))
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 5))
    else { throw CancellationError() }
    let checkpointURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-5.json")
    let originalEnvelope = try Data(contentsOf: checkpointURL)
    defer { try? originalEnvelope.write(to: checkpointURL, options: .atomic) }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: originalEnvelope) as? [String: Any])
    var payload = try #require(
      JSONSerialization.jsonObject(with: original.portableData) as? [String: Any])
    let marker = try #require((payload["deletionMarkers"] as? [[String: Any]])?.first)
    let target = try #require(marker["target"] as? [String: Any])
    var live = marker
    live["target"] = [
      "kind": "itineraryEntry", "id": entryIds[1].uuidString, "lifetimeId": entryIds[1].uuidString,
    ]
    var family = marker
    family["closedFamilyId"] = UUID().uuidString
    var missingLifetime = marker
    missingLifetime["target"] = ["kind": "itineraryEntry", "id": entryIds[0].uuidString]
    var unsupported = marker
    unsupported["target"] = [
      "kind": "unknown", "id": entryIds[0].uuidString, "lifetimeId": entryIds[0].uuidString,
    ]
    let invalidCollections = [
      [live], [family], [missingLifetime], [unsupported], [marker, marker],
    ]
    for markers in invalidCollections {
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
            namespaceId: namespace.namespaceId, checkpointGeneration: 5))
      else {
        Issue.record("Reject the whole invalid closure input.")
        continue
      }
      #expect(failure.code == "recoveryIntegrityFailure")
    }
    try originalEnvelope.write(to: checkpointURL, options: .atomic)
    guard
      case .source(.itinerary(let retained)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 5))
    else { throw CancellationError() }
    #expect(retained.references == before.references)
    #expect(retained.updatedAt == before.updatedAt)
    #expect(recovered.portableData == original.portableData)
    #expect(Set(target.keys) == ["kind", "id", "lifetimeId"])
    #expect(recovered.decodedBackup.backup.itineraryEntries.count == 1)
  }
}
