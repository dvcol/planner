import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ItineraryRecoveryIdentityTests {
  @Test func equalItemAndItineraryUUIDsKeepOwnedLinksAndLabelsInTheirDeclaredKinds() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory,
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the native graph before typed-owner recovery inputs.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let created, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = created.generated.first
      else { throw CancellationError() }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Food")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let item = try await create(
      .createItem(
        content: .init(
          title: "Hotel",
          links: [.init(originalUrl: "https://example.com/hotel")], categoryIds: [category.id])))
    let itinerary = try await create(
      .createItinerary(
        content: .init(
          title: "Tokyo",
          links: [.init(originalUrl: "https://example.com/route")], tagIds: [tag.id])))
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 4))
    else {
      Issue.record("Read the complete acknowledged graph before providing controlled input.")
      return
    }
    let checkpointURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-4.json")
    let originalEnvelope = try Data(contentsOf: checkpointURL)
    defer { try? originalEnvelope.write(to: checkpointURL, options: .atomic) }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: originalEnvelope) as? [String: Any])
    var payload = try #require(
      JSONSerialization.jsonObject(with: original.portableData) as? [String: Any])
    var sources = try #require(payload["sources"] as? [[String: Any]])
    let itineraryIndex = try #require(sources.firstIndex { $0["kind"] as? String == "itinerary" })
    sources[itineraryIndex]["id"] = item.id.uuidString
    payload["sources"] = sources
    for key in ["ownedLinks", "labelAssociations"] {
      var records = try #require(payload[key] as? [[String: Any]])
      for index in records.indices {
        var owner = try #require(records[index]["owner"] as? [String: Any])
        guard owner["kind"] as? String == "itinerary" else { continue }
        owner["id"] = item.id.uuidString
        records[index]["owner"] = owner
        if key == "ownedLinks" {
          #expect(records[index]["lifetimeId"] as? String == records[index]["id"] as? String)
        }
      }
      payload[key] = records
    }
    let bytes = try JSONSerialization.data(withJSONObject: payload)
    envelope["portablePayloadBase64"] = bytes.base64EncodedString()
    envelope["dataDigest"] =
      "sha256:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    try JSONSerialization.data(withJSONObject: envelope).write(to: checkpointURL, options: .atomic)
    guard
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 4)),
      let recoveredItem = recovered.decodedBackup.backup.items.first,
      let recoveredItinerary = recovered.decodedBackup.backup.sources.compactMap({
        source -> PlannerPortableItinerary? in
        guard case .itinerary(let value) = source else { return nil }
        return value
      }).first
    else {
      Issue.record("Equal UUIDs resolve by kind without mixing owned links or label selections.")
      return
    }
    #expect(recoveredItem.id == item.id)
    #expect(recoveredItinerary.id == item.id)
    #expect(recoveredItem.content.links.map(\.originalUrl) == ["https://example.com/hotel"])
    #expect(recoveredItinerary.content.links.map(\.originalUrl) == ["https://example.com/route"])
    #expect(recoveredItem.content.categoryIds == [category.id])
    #expect(recoveredItem.content.tagIds.isEmpty)
    #expect(recoveredItinerary.content.categoryIds.isEmpty)
    #expect(recoveredItinerary.content.tagIds == [tag.id])
    #expect(recovered.portableData == bytes)
    guard
      case .source(.itinerary(let nativeItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let nativeItem)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Controlled recovery inspection leaves native sources unchanged.")
      return
    }
    #expect(nativeItinerary.source == itinerary)
    #expect(nativeItinerary.content.links.map(\.originalUrl) == ["https://example.com/route"])
    #expect(nativeItem.content.links.map(\.originalUrl) == ["https://example.com/hotel"])
  }
}
