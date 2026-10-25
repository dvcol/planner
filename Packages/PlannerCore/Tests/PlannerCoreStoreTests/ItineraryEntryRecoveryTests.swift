import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ItineraryEntryRecoveryTests {
  @Test func malformedEntryRecordsRejectTheWholeRecoveryInputAndPreserveSavedData() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
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
    let list = try #require(
      try await save(.createList(content: .init(name: "Stops"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    for source in [item, list] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 5))
    else { throw CancellationError() }
    let checkpointURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-5.json")
    let originalEnvelope = try Data(contentsOf: checkpointURL)
    defer { try? originalEnvelope.write(to: checkpointURL, options: .atomic) }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: originalEnvelope) as? [String: Any])
    var payload = try #require(
      JSONSerialization.jsonObject(with: original.portableData) as? [String: Any])
    let entries = try #require(payload["itineraryEntries"] as? [[String: Any]])
    let itemIndex = try #require(
      entries.firstIndex { ($0["source"] as? [String: Any])?["kind"] as? String == "item" })
    let listIndex = try #require(
      entries.firstIndex { ($0["source"] as? [String: Any])?["kind"] as? String == "list" })
    var invalidCollections: [[[String: Any]]] = [entries + [entries[itemIndex]]]
    for (field, value) in [("rank", "00"), ("rank", "9223372036854775808")] {
      var changed = entries
      changed[itemIndex][field] = value
      invalidCollections.append(changed)
    }
    var missingItemState = entries
    missingItemState[itemIndex]["localDone"] = NSNull()
    invalidCollections.append(missingItemState)
    var invalidListState = entries
    invalidListState[listIndex]["localDone"] = true
    invalidCollections.append(invalidListState)
    for bindingField in ["source", "itinerary"] {
      var changed = entries
      var binding = try #require(changed[itemIndex][bindingField] as? [String: Any])
      binding["lifetimeId"] = UUID().uuidString
      changed[itemIndex][bindingField] = binding
      invalidCollections.append(changed)
    }
    var wrongKind = entries
    var source = try #require(wrongKind[itemIndex]["source"] as? [String: Any])
    source["kind"] = "schedule"
    wrongKind[itemIndex]["source"] = source
    invalidCollections.append(wrongKind)
    for invalidEntries in invalidCollections {
      payload["itineraryEntries"] = invalidEntries
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
        Issue.record("Reject malformed entries at the real recovery input boundary.")
        continue
      }
      #expect(failure.code == "recoveryIntegrityFailure")
    }
    try originalEnvelope.write(to: checkpointURL, options: .atomic)
    guard
      case .source(.itinerary(let retained)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 5)),
      case .listedNamespaces(let currentNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else { throw CancellationError() }
    #expect(retained.references == before.references)
    #expect(retained.fieldHashes == before.fieldHashes)
    #expect(retained.updatedAt == before.updatedAt)
    #expect(recovered.portableData == original.portableData)
    #expect(recovered.decodedBackup.backup.itineraryEntries.count == 2)
    #expect(currentNamespaces.first?.preparedProposals.isEmpty == true)
  }
}
