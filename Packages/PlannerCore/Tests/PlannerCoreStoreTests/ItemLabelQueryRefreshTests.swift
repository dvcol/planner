import Foundation
import PlannerCore
import Testing

struct ItemLabelQueryRefreshTests {
  @Test func liveLabelChangesInvalidateWindowsAndKeepQueriesBoundToIdentity() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
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
          command: .createCategory(content: .init(name: "Food")))
      ).outcome,
      let category = categoryCreation.generated.first,
      case .applied(let tagCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createTag(content: .init(name: "Food")))
      ).outcome,
      let tag = tagCreation.generated.first,
      case .applied(let itemCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(title: "Hotel", categoryIds: [category.id], tagIds: [tag.id])))
      ).outcome,
      let item = itemCreation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.category(let originalCategory)) = await planner.read(
        session: session, request: .source(category))
    else {
      Issue.record("Initialize live label sources and one exact Item binding.")
      return
    }
    let query = PlannerItemQuery(categories: .init(ids: [category.id]), tags: .init(ids: [tag.id]))
    guard
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .items(query)))
    else {
      Issue.record("Issue the initial identity-based filtered window.")
      return
    }
    #expect(issued.rows == [.source(item)])
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .editCategory(
            sourceId: category.id, changes: .init(name: .set("Dining")),
            expectedFieldHashes: originalCategory.fieldHashes))
      ).outcome,
      case .failed(let staleAfterRename) = await planner.read(
        session: session,
        request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .snapshot(let afterRename) = await planner.query(
        PlannerQuery(session: session, request: .items(query))),
      case .source(.item(let renamed)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record(
        "A committed label rename invalidates old windows but retains the identity match.")
      return
    }
    #expect(staleAfterRename.code == "staleSnapshot")
    #expect(afterRename.rows == [.source(item)])
    #expect(afterRename.generation != issued.generation)
    #expect(renamed.labels.first { $0.reference == category }?.name == "Dining")
    #expect(renamed.fieldHashes == original.fieldHashes)
    #expect(renamed.updatedAt == original.updatedAt)
    guard
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .editItem(
            sourceId: item.id, changes: .init(categoryIds: .set([])),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .failed(let staleAfterSelection) = await planner.read(
        session: session,
        request: .rows(generation: afterRename.generation, offset: 0, limit: 1)),
      case .snapshot(let removed) = await planner.query(
        PlannerQuery(session: session, request: .items(query))),
      case .snapshot(let retainedTag) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(.init(tags: .init(ids: [tag.id]))))),
      case .source(.item(let saved)) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record(
        "Committed selection edits update the next filtered generation without copying label state."
      )
      return
    }
    #expect(staleAfterSelection.code == "staleSnapshot")
    #expect(removed.matchingCount == 0)
    #expect(removed.rows.isEmpty)
    #expect(retainedTag.rows == [.source(item)])
    #expect(saved.content.categoryIds.isEmpty)
    #expect(saved.content.tagIds == [tag.id])
    #expect(saved.fieldHashes[.tagIds] == original.fieldHashes[.tagIds])
    #expect(saved.fieldHashes[.categoryIds] != original.fieldHashes[.categoryIds])
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 5))
    else {
      Issue.record("Read-only label queries retain the acknowledged data-only checkpoint.")
      return
    }
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 5)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(recovery.decodedBackup.backup.labelAssociations.count == 1)
    #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let reopenedTag) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(.init(tags: .init(ids: [tag.id]))))),
      case .snapshot(let reopenedCategory) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(.init(categories: .init(ids: [category.id])))))
    else {
      Issue.record("Reopening preserves effective selections for identity filters.")
      return
    }
    #expect(reopenedTag.rows == [.source(item)])
    #expect(reopenedCategory.rows.isEmpty)
  }
}
