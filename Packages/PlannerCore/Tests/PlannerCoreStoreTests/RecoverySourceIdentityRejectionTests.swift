import CryptoKit
import Foundation
import PlannerCore
import Testing

struct RecoverySourceIdentityRejectionTests {
  @Test func recoveryRejectsSameKindDuplicatesAndCrossKindReferenceSubstitution() async throws {
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
      Issue.record("Initialize the native store before recovery identity rejection cases.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = creation.generated.first
      else {
        Issue.record("Save the acknowledged graph through the public Core writer.")
        throw CancellationError()
      }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Food")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let item = try await create(
      .createItem(content: .init(title: "Hotel", categoryIds: [category.id], tagIds: [tag.id])))
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 3)),
      case .source(.item(let nativeOriginal)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Inspect the acknowledged graph before controlled malformed inputs.")
      return
    }
    let checkpointURL = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-3.json")
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
    let categoryRecord = try #require(sources.first { $0["kind"] as? String == "category" })
    let tagRecord = try #require(sources.first { $0["kind"] as? String == "tag" })
    var differentLifetimeCategory = categoryRecord
    differentLifetimeCategory["id"] = commonIdentifier.lowercased()
    differentLifetimeCategory["lifetimeId"] = UUID().uuidString
    var wrongLifetimeAssociations = associations
    let categoryAssociationIndex = try #require(
      wrongLifetimeAssociations.firstIndex {
        ($0["label"] as? [String: Any])?["kind"] as? String == "category"
      })
    var wrongLabel = try #require(
      wrongLifetimeAssociations[categoryAssociationIndex]["label"] as? [String: Any])
    wrongLabel["lifetimeId"] = tagRecord["lifetimeId"]
    wrongLifetimeAssociations[categoryAssociationIndex]["label"] = wrongLabel
    let invalidPayloads = [
      payload.merging(["sources": sources + [categoryRecord]]) { _, incoming in incoming },
      payload.merging(["sources": sources + [differentLifetimeCategory]]) { _, incoming in incoming
      },
      payload.merging(["sources": sources.filter { $0["kind"] as? String != "category" }]) {
        _, incoming in incoming
      },
      payload.merging(["labelAssociations": wrongLifetimeAssociations]) { _, incoming in incoming },
    ]
    for invalidPayload in invalidPayloads {
      let bytes = try JSONSerialization.data(withJSONObject: invalidPayload)
      envelope["portablePayloadBase64"] = bytes.base64EncodedString()
      envelope["dataDigest"] =
        "sha256:"
        + SHA256.hash(data: bytes).map {
          String(format: "%02x", $0)
        }.joined()
      try JSONSerialization.data(withJSONObject: envelope).write(
        to: checkpointURL, options: .atomic)
      guard
        case .failed(let reason) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 3))
      else {
        Issue.record("Invalid identities and typed bindings must reject the whole recovery input.")
        continue
      }
      #expect(reason.code == "recoveryIntegrityFailure")
      #expect(!reason.message.isEmpty)
    }
    try originalEnvelope.write(to: checkpointURL, options: .atomic)
    guard
      case .selected(let retained) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 3)),
      case .listedNamespaces(let currentNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .source(.item(let nativeCurrent)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Rejected inspections preserve the original native graph and recovery input.")
      return
    }
    #expect(retained.portableData == original.portableData)
    #expect(retained.decodedBackup.backup.items.first?.content.categoryIds == [category.id])
    #expect(retained.decodedBackup.backup.items.first?.content.tagIds == [tag.id])
    #expect(nativeCurrent.content.categoryIds == nativeOriginal.content.categoryIds)
    #expect(nativeCurrent.content.tagIds == nativeOriginal.content.tagIds)
    #expect(nativeCurrent.labels == nativeOriginal.labels)
    #expect(nativeCurrent.references == nativeOriginal.references)
    #expect(nativeCurrent.fieldHashes == nativeOriginal.fieldHashes)
    #expect(nativeCurrent.updatedAt == nativeOriginal.updatedAt)
    #expect(currentNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(currentNamespaces.first?.preparedProposals.isEmpty == true)
  }
}
