import Foundation
import PlannerCore
import Testing

struct ItemLabelCreationTests {
  @Test func itemLabelsRemainLiveReferencesAcrossRenameReplayReopenAndRecovery() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let categoryCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createCategory(
            content: PlannerCategoryContentInput(
              name: "Food", color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1),
              iconName: "fork.knife")))
      ).outcome,
      let category = categoryCreation.generated.first,
      case .applied(let tagCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createTag(content: PlannerTagContentInput(name: "Rainy day")))
      ).outcome,
      let tag = tagCreation.generated.first,
      case .source(.category(let categoryBefore)) = await planner.read(
        session: session, request: .source(category))
    else {
      Issue.record("Create the shared Category and Tag before selecting them on an Item.")
      return
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.createItem(
      content: PlannerItemContentInput(
        title: "Hotel", notes: "Keep", categoryIds: [category.id], tagIds: [tag.id]))
    let creation = await planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: session, command: command))
    guard case .applied(let created, .complete(let itemCheckpoint)) = creation.outcome,
      let item = created.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Create an Item with durable live label references: \(creation.outcome)")
      return
    }
    #expect(itemCheckpoint == 3)
    #expect(original.content.categoryIds == [category.id])
    #expect(original.content.tagIds == [tag.id])
    #expect(original.labels.count == 2)
    #expect(original.labels.first(where: { $0.reference == category })?.name == "Food")
    #expect(
      original.labels.first(where: { $0.reference == category })?.color
        == categoryBefore.content.color)
    #expect(original.labels.first(where: { $0.reference == category })?.iconName == "fork.knife")
    #expect(original.labels.first(where: { $0.reference == tag })?.name == "Rainy day")
    #expect(created.generatedReferences.count == 2)
    #expect(original.references.count == 2)
    #expect(created.generatedReferences.allSatisfy { original.references.contains($0) })

    guard
      case .applied(_, .complete(let renamedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editCategory(
            sourceId: category.id,
            changes: PlannerCategoryChanges(name: .set("Dining")),
            expectedFieldHashes: categoryBefore.fieldHashes))
      ).outcome,
      case .source(.item(let updated)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.category(let categoryAfter)) = await planner.read(
        session: session, request: .source(category))
    else {
      Issue.record(
        "Renaming the shared label must update its Item display through the same identity.")
      return
    }
    #expect(renamedCheckpoint == 4)
    #expect(updated.labels.first(where: { $0.reference == category })?.name == "Dining")
    #expect(updated.content.categoryIds == original.content.categoryIds)
    #expect(updated.content.tagIds == original.content.tagIds)
    #expect(updated.fieldHashes == original.fieldHashes)
    #expect(updated.updatedAt == original.updatedAt)
    #expect(updated.references == original.references)
    #expect(
      categoryAfter.references
        == original.references.filter { reference in
          guard case .labelAssociation(_, _, let label) = reference else { return false }
          return label == category
        })

    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession,
          command: command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: renamedCheckpoint))
    else {
      Issue.record(
        "Reopen, original receipt replay and independent recovery must retain the graph.")
      return
    }
    #expect(retained.content.categoryIds == [category.id])
    #expect(retained.content.tagIds == [tag.id])
    #expect(retained.labels.first(where: { $0.reference == category })?.name == "Dining")
    #expect(retained.labels.first(where: { $0.reference == tag })?.name == "Rainy day")
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(retained.updatedAt == original.updatedAt)
    #expect(retained.references == original.references)
    #expect(replayed == created)
    #expect(replayedCheckpoint == itemCheckpoint)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == renamedCheckpoint)
    #expect(namespace.preparedProposals.isEmpty)
    let graph = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let associations = try #require(graph["labelAssociations"] as? [[String: Any]])
    #expect(associations.count == 2)
    for association in associations {
      #expect(association["id"] as? String == association["lifetimeId"] as? String)
      let owner = try #require(association["owner"] as? [String: Any])
      #expect(owner["kind"] as? String == "item")
      #expect(owner["id"] as? String == item.id.uuidString)
      #expect(owner["lifetimeId"] as? String == original.sourceLifetimeId.uuidString)
    }
    let sources = try #require(graph["sources"] as? [[String: Any]])
    let itemRecord = try #require(sources.first { $0["id"] as? String == item.id.uuidString })
    let content = try #require(itemRecord["content"] as? [String: Any])
    #expect(content["categoryIds"] == nil)
    #expect(content["tagIds"] == nil)
    #expect(associations.allSatisfy { $0["name"] == nil && $0["color"] == nil })
  }
}
