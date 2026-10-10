import Foundation
import PlannerCore
import Testing

struct ItemLabelValidationTests {
  @Test func invalidLabelSelectionsLeaveNoOwnerOrAssociationAndDistinctNamesStaySeparate()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let firstCategory, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createCategory(content: PlannerCategoryContentInput(name: "Food")))
      ).outcome,
      let category = firstCategory.generated.first,
      case .applied(let tagCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createTag(content: PlannerTagContentInput(name: "Food")))
      ).outcome,
      let tag = tagCreation.generated.first
    else {
      Issue.record("Create valid labels before validating their selection bindings.")
      return
    }
    let invalid: [(Set<UUID>, Set<UUID>, String)] = [
      ([UUID()], [], "/command/content/categoryIds"),
      ([], [UUID()], "/command/content/tagIds"),
      ([tag.id], [], "/command/content/categoryIds"),
      ([], [category.id], "/command/content/tagIds"),
      ([category.id], [UUID()], "/command/content/tagIds"),
    ]
    for (categoryIdentifiers, tagIdentifiers, path) in invalid {
      let operationIdentifier = UUID()
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: operationIdentifier, session: session,
            command: .createItem(
              content: PlannerItemContentInput(
                title: "Hotel",
                categoryIds: categoryIdentifiers, tagIds: tagIdentifiers)))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record("Missing/wrong-kind labels must reject the whole Item before saving evidence.")
        return
      }
      #expect(reason.code == "missingReference")
      #expect(reason.propertyPath == path)
    }
    guard
      case .snapshot(let empty) = await planner.query(
        PlannerQuery(
          session: session, request: .items(PlannerItemQuery(scope: .global)))),
      case .source(.category(let retainedCategory)) = await planner.read(
        session: session, request: .source(category)),
      case .source(.tag(let retainedTag)) = await planner.read(
        session: session, request: .source(tag)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Invalid selections must leave the labels and empty Item catalog readable.")
      return
    }
    #expect(empty.matchingCount == 0)
    #expect(retainedCategory.references.isEmpty)
    #expect(retainedTag.references.isEmpty)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
    guard
      case .applied(let secondCategory, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createCategory(content: PlannerCategoryContentInput(name: "Food")))
      ).outcome,
      let otherCategory = secondCategory.generated.first,
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel",
              categoryIds: Set([category.id, category.id, otherCategory.id]), tagIds: [tag.id])))
      ).outcome,
      let item = creation.generated.first,
      case .source(.item(let read)) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Equal label names with distinct identities must remain separate selections.")
      return
    }
    #expect(read.content.categoryIds == [category.id, otherCategory.id])
    #expect(read.content.tagIds == [tag.id])
    #expect(read.labels.count == 3)
    #expect(read.labels.allSatisfy { $0.name == "Food" })
    #expect(read.references.count == 3)
    #expect(creation.generatedReferences.count == 3)
  }
}
