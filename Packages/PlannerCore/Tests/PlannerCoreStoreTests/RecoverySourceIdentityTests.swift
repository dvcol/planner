import CryptoKit
import Foundation
import PlannerCore
import Testing

struct RecoverySourceIdentityTests {
  @Test func recoveryResolvesEqualUUIDsBySourceKindAndRetainsTypedAssociations() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory,
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the native store before inspecting portable source identities.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = creation.generated.first
      else {
        Issue.record("Save the real recovery fixture through public durable commands.")
        throw CancellationError()
      }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Food")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let list = try await create(.createList(content: .init(name: "Stops")))
    let item = try await create(
      .createItem(content: .init(title: "Hotel", categoryIds: [category.id], tagIds: [tag.id])))
    guard
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .source(.item(let nativeOriginal)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Read the acknowledged portable graph before preparing a controlled input.")
      return
    }
    let checkpointURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-\(checkpoint).json")
    let originalEnvelope = try Data(contentsOf: checkpointURL)
    defer { try? originalEnvelope.write(to: checkpointURL, options: .atomic) }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: originalEnvelope) as? [String: Any])
    var payload = try #require(
      JSONSerialization.jsonObject(with: original.portableData) as? [String: Any])
    var sources = try #require(payload["sources"] as? [[String: Any]])
    let commonIdentifier = item.id.uuidString
    for index in sources.indices { sources[index]["id"] = commonIdentifier }
    payload["sources"] = sources
    var associations = try #require(payload["labelAssociations"] as? [[String: Any]])
    for index in associations.indices {
      var label = try #require(associations[index]["label"] as? [String: Any])
      label["id"] = commonIdentifier
      associations[index]["label"] = label
    }
    payload["labelAssociations"] = associations
    var memberships = try #require(payload["memberships"] as? [[String: Any]])
    var membershipList = try #require(memberships[0]["list"] as? [String: Any])
    membershipList["id"] = commonIdentifier
    memberships[0]["list"] = membershipList
    payload["memberships"] = memberships
    let bytes = try JSONSerialization.data(withJSONObject: payload)
    envelope["portablePayloadBase64"] = bytes.base64EncodedString()
    envelope["dataDigest"] =
      "sha256:"
      + SHA256.hash(data: bytes).map {
        String(format: "%02x", $0)
      }.joined()
    try JSONSerialization.data(withJSONObject: envelope).write(to: checkpointURL, options: .atomic)
    guard
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Equal UUID bytes across different source kinds must resolve independently.")
      return
    }
    let backup = recovered.decodedBackup.backup
    #expect(backup.sources.count == 4)
    #expect(backup.items.first?.id == item.id)
    #expect(backup.lists.first?.id == item.id)
    #expect(backup.items.first?.content.title == "Hotel")
    #expect(backup.lists.first?.content.name == "Stops")
    #expect(backup.items.first?.content.categoryIds == [item.id])
    #expect(backup.items.first?.content.tagIds == [item.id])
    #expect(backup.labelAssociations.count == 2)
    #expect(backup.labelAssociations.contains { $0.label == .init(kind: .category, id: item.id) })
    #expect(backup.labelAssociations.contains { $0.label == .init(kind: .tag, id: item.id) })
    #expect(backup.memberships.first?.item == .init(kind: .item, id: item.id))
    #expect(backup.memberships.first?.list == .init(kind: .list, id: item.id))
    #expect(recovered.portableData == bytes)
    #expect(recovered.evidence == .acknowledgedSnapshot)
    #expect(recovered.checkpointGeneration == 5)
    guard
      case .source(.item(let nativeCurrent)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Recovery inspection must leave the saved native graph unchanged.")
      return
    }
    #expect(nativeCurrent.content.categoryIds == nativeOriginal.content.categoryIds)
    #expect(nativeCurrent.content.tagIds == nativeOriginal.content.tagIds)
    #expect(nativeCurrent.labels == nativeOriginal.labels)
    #expect(nativeCurrent.references == nativeOriginal.references)
    #expect(nativeCurrent.fieldHashes == nativeOriginal.fieldHashes)
    #expect(nativeCurrent.updatedAt == nativeOriginal.updatedAt)
  }
}
