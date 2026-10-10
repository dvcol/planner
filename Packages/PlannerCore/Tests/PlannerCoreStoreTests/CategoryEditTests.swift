import Foundation
import PlannerCore
import Testing

struct CategoryEditTests {
  @Test func optionalColorEditsAndInvalidCategoryPatchesPreserveIndependentRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createCategory(
            content: PlannerCategoryContentInput(
              name: "Food",
              color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1), iconName: "fork.knife")))
      ).outcome,
      let category = created.generated.first,
      case .source(.category(let original)) = await planner.read(
        session: session, request: .source(category))
    else {
      Issue.record("Create the original Category before optional and invalid edits.")
      return
    }
    let colorHash = try #require(original.fieldHashes[.color])
    let invalid: [(PlannerCategoryChanges, [PlannerCategoryField: PlannerFieldHash], String)] = [
      (PlannerCategoryChanges(), [:], "/command/changes"),
      (PlannerCategoryChanges(name: .clear), original.fieldHashes, "/command/changes/name"),
      (PlannerCategoryChanges(name: .set(" \n\t")), original.fieldHashes, "/command/changes/name"),
      (PlannerCategoryChanges(iconName: .set("")), [:], "/command/expectedFieldHashes/iconName"),
      (
        PlannerCategoryChanges(color: .set(PlannerColor(red: .nan, green: 0, blue: 0, alpha: 1))),
        original.fieldHashes, "/command/changes/color/red"
      ),
      (
        PlannerCategoryChanges(color: .clear), [.color: PlannerFieldHash(value: "invalid")],
        "/command/expectedFieldHashes/color"
      ),
    ]
    for (changes, hashes, propertyPath) in invalid {
      guard
        case .rejected(let rejected) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .editCategory(
              sourceId: category.id, changes: changes, expectedFieldHashes: hashes))
        ).outcome,
        case .source(.category(let unchanged)) = await planner.read(
          session: session, request: .source(category))
      else {
        Issue.record("Invalid patches must reject together while preserving the Category.")
        return
      }
      #expect(rejected.code == "invalidInput")
      #expect(rejected.propertyPath == propertyPath)
      #expect(unchanged.content == original.content)
      #expect(unchanged.updatedAt == original.updatedAt)
      #expect(unchanged.fieldHashes == original.fieldHashes)
    }
    guard
      case .applied(_, .complete(let clearedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editCategory(
            sourceId: category.id, changes: PlannerCategoryChanges(color: .clear),
            expectedFieldHashes: [.color: colorHash]))
      ).outcome,
      case .source(.category(let cleared)) = await planner.read(
        session: session, request: .source(category))
    else {
      Issue.record("A current optional color guard must permit an explicit clear.")
      return
    }
    #expect(clearedCheckpoint == 2)
    #expect(cleared.content.color == nil)
    let clearedHash = try #require(cleared.fieldHashes[.color])
    let newColor = PlannerColor(red: 1, green: 0, blue: 0, alpha: 0.5)
    guard
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editCategory(
            sourceId: category.id, changes: PlannerCategoryChanges(color: .set(newColor)),
            expectedFieldHashes: [.color: clearedHash]))
      ).outcome,
      case .source(.category(let final)) = await planner.read(
        session: session, request: .source(category)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .category(let portable)? = recovery.decodedBackup.backup.sources.first
    else {
      Issue.record("The replacement color must save with a complete typed recovery record.")
      return
    }
    #expect(checkpoint == 3)
    #expect(final.content.name == "Food")
    #expect(final.content.iconName == "fork.knife")
    #expect(final.content.color == newColor)
    #expect(final.fieldHashes[.name] == original.fieldHashes[.name])
    #expect(final.fieldHashes[.iconName] == original.fieldHashes[.iconName])
    #expect(portable.content == final.content)
    #expect(portable.updatedAt == final.updatedAt)
    #expect(namespace.preparedProposals.isEmpty)
  }

  @Test func categoryEditsGuardOnlyChangedFieldsAndRejectAStalePatchTogether() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let originalColor = PlannerColor(red: 0.125, green: 0.5, blue: 0.75, alpha: 1)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createCategory(
            content: PlannerCategoryContentInput(
              name: "Food", color: originalColor, iconName: "fork.knife")))
      ).outcome,
      let category = created.generated.first,
      case .source(.category(let original)) = await planner.read(
        session: session, request: .source(category))
    else {
      Issue.record("Save and read the Category before applying guarded changes.")
      return
    }
    let nameHash = try #require(original.fieldHashes[.name])
    let colorHash = try #require(original.fieldHashes[.color])
    let iconHash = try #require(original.fieldHashes[.iconName])
    let nameOperation = UUID()
    let nameCommand = PlannerCommand.editCategory(
      sourceId: category.id,
      changes: PlannerCategoryChanges(name: .set(" Dining ")),
      expectedFieldHashes: [.name: nameHash])
    guard
      case .applied(let renamed, .complete(let nameCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: nameOperation, session: session, command: nameCommand)
      ).outcome,
      case .applied(_, .complete(let iconCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editCategory(
            sourceId: category.id, changes: PlannerCategoryChanges(iconName: .clear),
            expectedFieldHashes: [.iconName: iconHash]))
      ).outcome,
      case .source(.category(let current)) = await planner.read(
        session: session, request: .source(category)),
      case .rejected(let stale) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editCategory(
            sourceId: category.id,
            changes: PlannerCategoryChanges(
              name: .set("Stale name"),
              color: .set(PlannerColor(red: 1, green: 0, blue: 0, alpha: 1))),
            expectedFieldHashes: [.name: nameHash, .color: colorHash]))
      ).outcome,
      case .staleCategoryEdit(let conflicts, let values, let hashes) = stale.details
    else {
      Issue.record(
        "An independent field edit must succeed while a stale compound patch rejects together.")
      return
    }
    #expect(renamed.generated.isEmpty)
    #expect(renamed.affected == [category])
    #expect(nameCheckpoint == 2)
    #expect(iconCheckpoint == 3)
    #expect(current.content.name == " Dining ")
    #expect(current.content.iconName == nil)
    #expect(current.content.color == originalColor)
    #expect(stale.code == "staleEdit")
    #expect(conflicts == [.name])
    #expect(values[.name] == .string(" Dining "))
    #expect(values[.color] == nil)
    #expect(hashes[.name] == current.fieldHashes[.name])
    #expect(hashes[.color] == nil)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.category(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(category)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: nameOperation, session: reopenedSession, command: nameCommand)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: iconCheckpoint)),
      case .category(let portable)? = recovery.decodedBackup.backup.sources.first
    else {
      Issue.record(
        "Successful edits and original replay must survive reopening with complete recovery.")
      return
    }
    #expect(retained.content == current.content)
    #expect(retained.sourceLifetimeId == original.sourceLifetimeId)
    #expect(retained.createdAt == original.createdAt)
    #expect(retained.updatedAt == current.updatedAt)
    #expect(retained.fieldHashes == current.fieldHashes)
    #expect(retained.state.globalDone == nil)
    #expect(retained.state.archived == nil)
    #expect(replay == renamed)
    #expect(replayCheckpoint == 2)
    #expect(portable.content == retained.content)
    #expect(portable.updatedAt == retained.updatedAt)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(namespace.preparedProposals.isEmpty)
  }
}
