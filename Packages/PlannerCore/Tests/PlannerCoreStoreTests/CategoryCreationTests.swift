import CryptoKit
import Foundation
import PlannerCore
import Testing

struct CategoryCreationTests {
  @Test func categoryNamesAreNotUniquenessKeysAndInvalidCreationLeavesNoEvidence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize.")
      return
    }
    let invalidContents: [(PlannerCategoryContentInput, String)] = [
      (PlannerCategoryContentInput(name: ""), "/command/content/name"),
      (PlannerCategoryContentInput(name: " \n\t"), "/command/content/name"),
      (
        PlannerCategoryContentInput(
          name: "Food",
          color: PlannerColor(
            red: -0.01, green: 0, blue: 0, alpha: 1)), "/command/content/color/red"
      ),
      (
        PlannerCategoryContentInput(
          name: "Food",
          color: PlannerColor(
            red: 0, green: 0, blue: 0, alpha: 1.01)), "/command/content/color/alpha"
      ),
      (
        PlannerCategoryContentInput(
          name: "Food",
          color: PlannerColor(
            red: .nan, green: 0, blue: 0, alpha: 1)), "/command/content/color/red"
      ),
    ]
    for (content, propertyPath) in invalidContents {
      guard
        case .rejected(let failure) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createCategory(content: content))
        ).outcome
      else {
        Issue.record("Invalid Category input must reject before saving.")
        return
      }
      #expect(failure.code == "invalidInput")
      #expect(failure.propertyPath == propertyPath)
    }
    guard
      case .listedNamespaces(let emptyNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      let emptyNamespace = emptyNamespaces.first
    else {
      Issue.record("The independent namespace must remain inspectable.")
      return
    }
    #expect(emptyNamespace.acknowledgedSnapshot == nil)
    #expect(emptyNamespace.preparedProposals.isEmpty)
    var categories: [PlannerEntityReference] = []
    for _ in 0..<2 {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createCategory(
              content: PlannerCategoryContentInput(name: "Café food", iconName: "")))
        ).outcome, let reference = created.generated.first
      else {
        Issue.record("Equal Category names must remain separate generated identities.")
        return
      }
      categories.append(reference)
    }
    guard
      case .snapshot(let catalog) = await planner.query(
        PlannerQuery(
          session: session,
          request: .catalog(
            PlannerCatalogQuery(sourceKind: .category, text: "FOOD cafe", archive: .all)))),
      case .failed(let invalidFilter) = await planner.query(
        PlannerQuery(
          session: session,
          request: .catalog(PlannerCatalogQuery(sourceKind: .category, archive: .archived)))),
      case .source(.category(let read)) = await planner.read(
        session: session, request: .source(categories[0]))
    else {
      Issue.record("Insensitive cumulative name search must retain both distinct Categories.")
      return
    }
    #expect(catalog.matchingCount == 2)
    #expect(
      catalog.rows
        == categories.sorted { $0.id.uuidString < $1.id.uuidString }.map {
          .source($0)
        })
    #expect(read.content.color == nil)
    #expect(read.content.iconName == "")
    #expect(invalidFilter.code == "invalidInput")
    #expect(invalidFilter.propertyPath == "/query/archive")
  }

  @Test func categoryCreationSurvivesReopenAndRemainsRecoverableAfterAnotherCommand() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize before creating a shared Category.")
      return
    }
    let content = PlannerCategoryContentInput(
      name: " Food ", color: PlannerColor(red: 0.125, green: 0.5, blue: 0.75, alpha: 1),
      iconName: "fork.knife")
    let operationIdentifier = UUID()
    let command = PlannerCommand.createCategory(content: content)
    let creation = await planner.execute(
      PlannerOperation(operationId: operationIdentifier, session: session, command: command))
    guard
      case .applied(let created, .complete(let categoryCheckpoint)) = creation.outcome,
      let category = created.generated.first,
      case .source(.category(let original)) = await planner.read(
        session: session, request: .source(category)),
      case .applied(_, .complete(let itemCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Museum", notes: "Keep")))
      ).outcome
    else {
      Issue.record(
        "Category and subsequent Item creation must save with recovery: \(creation.outcome)")
      return
    }
    #expect(category.kind == .category)
    #expect(created.generated == [category])
    #expect(created.affected == [category])
    #expect(categoryCheckpoint == 1)
    #expect(itemCheckpoint == 2)
    #expect(original.content == content)
    #expect(Set(original.fieldHashes.keys) == [.name, .color, .iconName])
    #expect(original.state.globalDone == nil)
    #expect(original.state.archived == nil)
    #expect(original.references.isEmpty)

    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.category(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(category)),
      case .snapshot(let catalog) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .catalog(
            PlannerCatalogQuery(sourceKind: .category, text: "food", archive: .all)))),
      case .rows(let window) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: catalog.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: itemCheckpoint)),
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome
    else {
      Issue.record(
        "Reopen, discovery, replay and the later recovery copy must retain the Category.")
      return
    }
    #expect(retained.source == category)
    #expect(retained.content == content)
    #expect(retained.createdAt == original.createdAt)
    #expect(retained.updatedAt == original.updatedAt)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(catalog.matchingCount == 1)
    #expect(catalog.rows == [.source(category)])
    #expect(window.rows.first?.title == " Food ")
    #expect(window.rows.first?.globalDone == nil)
    #expect(window.rows.first?.archived == nil)
    #expect(replayed.generated == [category])
    #expect(replayedCheckpoint == 1)
    #expect(recovery.decodedBackup.backup.sources.count == 2)
    guard
      case .category(let portable) = recovery.decodedBackup.backup.sources.first(where: {
        $0.id == category.id
      })
    else {
      Issue.record("The complete backup must retain the Category as its own typed source.")
      return
    }
    #expect(portable.content == content)
    #expect(portable.createdAt == retained.createdAt)
    #expect(portable.updatedAt == retained.updatedAt)
    #expect(namespace.preparedProposals.isEmpty)
    let framing =
      "506c616e6e65724669656c64486173680000000001"
      + session.datasetId.uuidString.replacingOccurrences(of: "-", with: "") + "04"
      + category.id.uuidString.replacingOccurrences(of: "-", with: "")
      + retained.sourceLifetimeId.uuidString.replacingOccurrences(of: "-", with: "")
      + "00000000000000046e616d6510000000000000000620466f6f6420"
    let characters = Array(framing)
    let framedBytes = try Data(
      stride(from: 0, to: characters.count, by: 2).map { index in
        try #require(UInt8(String(characters[index...index + 1]), radix: 16))
      })
    let expectedNameHash = SHA256.hash(data: framedBytes).map { String(format: "%02x", $0) }
      .joined()
    #expect(retained.fieldHashes[.name]?.value == "sha256-v1:" + expectedNameHash)
    let backup = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let records = try #require(backup["sources"] as? [[String: Any]])
    let categoryRecord = try #require(records.first { $0["kind"] as? String == "category" })
    #expect(categoryRecord["globalDone"] is NSNull)
    #expect(categoryRecord["archived"] is NSNull)
    #expect(
      Set(try #require(categoryRecord["content"] as? [String: Any]).keys) == [
        "name", "color", "iconName",
      ])
  }
}
