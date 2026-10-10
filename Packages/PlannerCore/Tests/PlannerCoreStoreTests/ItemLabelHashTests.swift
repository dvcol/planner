import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ItemLabelHashTests {
  @Test func labelSelectionHashesUseLabelIdentityAndLifetimeWithoutMetadata() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let categoryCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createCategory(content: PlannerCategoryContentInput(name: "Food")))
      ).outcome,
      let category = categoryCreation.generated.first,
      case .source(.category(let categoryRead)) = await planner.read(
        session: session, request: .source(category)),
      case .applied(let tagCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createTag(content: PlannerTagContentInput(name: "Food")))
      ).outcome,
      let tag = tagCreation.generated.first,
      case .source(.tag(let tagRead)) = await planner.read(
        session: session, request: .source(tag)),
      case .applied(let itemCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", categoryIds: [category.id], tagIds: [tag.id])))
      ).outcome,
      let item = itemCreation.generated.first,
      case .source(.item(let itemRead)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Read an Item's bound label selections through the public source interface.")
      return
    }
    let header =
      "506c616e6e65724669656c64486173680000000001"
      + identityHex(session.datasetId) + "01" + identityHex(item.id)
      + identityHex(itemRead.sourceLifetimeId)
    let categoryFraming =
      header
      + "000000000000000b63617465676f7279496473"
      + "1700000000000000011800000000000000020000000000000002696414"
      + identityHex(category.id) + "000000000000000a6c69666574696d65496414"
      + identityHex(categoryRead.sourceLifetimeId)
    let tagFraming =
      header
      + "0000000000000006746167496473"
      + "1700000000000000011800000000000000020000000000000002696414"
      + identityHex(tag.id) + "000000000000000a6c69666574696d65496414"
      + identityHex(tagRead.sourceLifetimeId)
    #expect(itemRead.fieldHashes[.categoryIds]?.value == hash(categoryFraming))
    #expect(itemRead.fieldHashes[.tagIds]?.value == hash(tagFraming))
    #expect(itemRead.fieldHashes[.categoryIds] != itemRead.fieldHashes[.tagIds])
  }

  private func identityHex(_ identity: UUID) -> String {
    identity.uuidString.replacingOccurrences(of: "-", with: "")
  }

  private func hash(_ framing: String) -> String {
    let characters = Array(framing)
    let bytes = Data(
      stride(from: 0, to: characters.count, by: 2).map { index in
        UInt8(String(characters[index...index + 1]), radix: 16)!
      })
    return "sha256-v1:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
  }
}
