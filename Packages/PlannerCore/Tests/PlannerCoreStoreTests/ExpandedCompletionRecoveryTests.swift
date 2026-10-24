import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ExpandedCompletionRecoveryTests {
  @Test func duplicateDanglingAndCrossListContextsRejectTheWholeRecoveryInput() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory,
        processRole: .mainApplication, storageMode: .localOnly))
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
    let secondItem = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let firstList = try #require(
      try await save(.createList(content: .init(name: "A"))).generated.first)
    let secondList = try #require(
      try await save(.createList(content: .init(name: "B"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let membership = try #require(
      try await save(.addMembership(itemId: item.id, listId: firstList.id, placement: .last))
        .generatedReferences.first)
    let foreignMembership = try #require(
      try await save(.addMembership(itemId: secondItem.id, listId: secondList.id, placement: .last))
        .generatedReferences.first)
    var entryIds: [UUID] = []
    for source in [firstList, item] {
      let reference = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      entryIds.append(identifier)
    }
    guard case .membership(let membershipId, _, _) = membership,
      case .membership(let foreignMembershipId, _, _) = foreignMembership
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id,
            listEntryId: entryIds[0], membershipId: membershipId)), done: true))
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 10)
      )
    else { throw CancellationError() }
    let checkpointURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-10.json")
    let originalEnvelope = try Data(contentsOf: checkpointURL)
    defer { try? originalEnvelope.write(to: checkpointURL, options: .atomic) }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: originalEnvelope) as? [String: Any])
    let payload = try #require(
      JSONSerialization.jsonObject(with: original.portableData) as? [String: Any])
    let completions = try #require(payload["expandedCompletions"] as? [[String: Any]])
    let originalRecord = try #require(completions.first)
    let originalContext = try #require(originalRecord["context"] as? [String: Any])
    var invalidCollections = [completions + [originalRecord]]
    for field in ["listEntryId", "listEntryLifetimeId", "membershipId", "membershipLifetimeId"] {
      var context = originalContext
      context[field] = UUID().uuidString
      var record = originalRecord
      record["context"] = context
      invalidCollections.append([record])
    }
    var directContext = originalContext
    directContext["listEntryId"] = entryIds[1].uuidString
    directContext["listEntryLifetimeId"] = entryIds[1].uuidString
    var directRecord = originalRecord
    directRecord["context"] = directContext
    invalidCollections.append([directRecord])
    var foreignContext = originalContext
    foreignContext["membershipId"] = foreignMembershipId.uuidString
    foreignContext["membershipLifetimeId"] = foreignMembershipId.uuidString
    var foreignRecord = originalRecord
    foreignRecord["context"] = foreignContext
    invalidCollections.append([foreignRecord])
    var invalidPayloads = invalidCollections.map { invalidCompletions in
      var invalid = payload
      invalid["expandedCompletions"] = invalidCompletions
      return invalid
    }
    let membershipRecords = try #require(payload["memberships"] as? [[String: Any]])
    for bindingName in ["item", "list"] {
      for field in ["kind", "id", "lifetimeId"] {
        var invalidMemberships = membershipRecords
        var binding = try #require(invalidMemberships[0][bindingName] as? [String: Any])
        binding[field] = field == "kind" ? "itinerary" : UUID().uuidString
        invalidMemberships[0][bindingName] = binding
        var invalid = payload
        invalid["memberships"] = invalidMemberships
        invalidPayloads.append(invalid)
      }
    }
    var invalidMemberships = membershipRecords
    invalidMemberships[0]["rank"] = "01"
    var invalidRank = payload
    invalidRank["memberships"] = invalidMemberships
    invalidPayloads.append(invalidRank)
    for invalidPayload in invalidPayloads {
      let bytes = try JSONSerialization.data(withJSONObject: invalidPayload)
      envelope["portablePayloadBase64"] = bytes.base64EncodedString()
      envelope["dataDigest"] =
        "sha256:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
      try JSONSerialization.data(withJSONObject: envelope).write(
        to: checkpointURL, options: .atomic)
      guard
        case .failed(let failure) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 10))
      else {
        Issue.record("Reject the complete malformed membership or expanded-context input.")
        continue
      }
      #expect(failure.code == "recoveryIntegrityFailure")
    }
    try originalEnvelope.write(to: checkpointURL, options: .atomic)
    guard
      case .source(.itinerary(let retained)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 10)
      )
    else { throw CancellationError() }
    #expect(retained.references == before.references)
    #expect(retained.updatedAt == before.updatedAt)
    #expect(retained.progress.doneCount == 1)
    #expect(recovered.portableData == original.portableData)
    #expect(recovered.decodedBackup.backup.expandedCompletions.first?.localDone == true)
    #expect(
      recovered.decodedBackup.backup.expandedCompletions.first?.context.membershipId == membershipId
    )
  }
}
