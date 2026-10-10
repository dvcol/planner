import Foundation
import PlannerCore
import Testing

struct TagEditTests {
  @Test func optionalColorEditsAndInvalidTagPatchesPreserveIndependentRecovery() async throws {
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
          command: .createTag(
            content: PlannerTagContentInput(
              name: "Food",
              color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1), iconName: "fork.knife")))
      ).outcome,
      let tag = created.generated.first,
      case .source(.tag(let original)) = await planner.read(
        session: session, request: .source(tag))
    else {
      Issue.record("Create the original Tag before optional and invalid edits.")
      return
    }
    let colorHash = try #require(original.fieldHashes[.color])
    let invalid: [(PlannerTagChanges, [PlannerTagField: PlannerFieldHash], String)] = [
      (PlannerTagChanges(), [:], "/command/changes"),
      (PlannerTagChanges(name: .clear), original.fieldHashes, "/command/changes/name"),
      (PlannerTagChanges(name: .set(" \n\t")), original.fieldHashes, "/command/changes/name"),
      (PlannerTagChanges(iconName: .set("")), [:], "/command/expectedFieldHashes/iconName"),
      (
        PlannerTagChanges(color: .set(PlannerColor(red: .nan, green: 0, blue: 0, alpha: 1))),
        original.fieldHashes, "/command/changes/color/red"
      ),
      (
        PlannerTagChanges(color: .clear), [.color: PlannerFieldHash(value: "invalid")],
        "/command/expectedFieldHashes/color"
      ),
    ]
    for (changes, hashes, propertyPath) in invalid {
      guard
        case .rejected(let rejected) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .editTag(
              sourceId: tag.id, changes: changes, expectedFieldHashes: hashes))
        ).outcome,
        case .source(.tag(let unchanged)) = await planner.read(
          session: session, request: .source(tag))
      else {
        Issue.record("Invalid patches must reject together while preserving the Tag.")
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
          command: .editTag(
            sourceId: tag.id, changes: PlannerTagChanges(color: .clear),
            expectedFieldHashes: [.color: colorHash]))
      ).outcome,
      case .source(.tag(let cleared)) = await planner.read(
        session: session, request: .source(tag))
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
          command: .editTag(
            sourceId: tag.id, changes: PlannerTagChanges(color: .set(newColor)),
            expectedFieldHashes: [.color: clearedHash]))
      ).outcome,
      case .source(.tag(let final)) = await planner.read(
        session: session, request: .source(tag)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .tag(let portable)? = recovery.decodedBackup.backup.sources.first
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

  @Test func tagEditsGuardOnlyChangedFieldsAndRejectAStalePatchTogether() async throws {
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
          command: .createTag(
            content: PlannerTagContentInput(
              name: "Food", color: originalColor, iconName: "fork.knife")))
      ).outcome,
      let tag = created.generated.first,
      case .source(.tag(let original)) = await planner.read(
        session: session, request: .source(tag))
    else {
      Issue.record("Save and read the Tag before applying guarded changes.")
      return
    }
    let nameHash = try #require(original.fieldHashes[.name])
    let colorHash = try #require(original.fieldHashes[.color])
    let iconHash = try #require(original.fieldHashes[.iconName])
    let nameOperation = UUID()
    let nameCommand = PlannerCommand.editTag(
      sourceId: tag.id,
      changes: PlannerTagChanges(name: .set(" Dining ")),
      expectedFieldHashes: [.name: nameHash])
    guard
      case .applied(let renamed, .complete(let nameCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: nameOperation, session: session, command: nameCommand)
      ).outcome,
      case .applied(_, .complete(let iconCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editTag(
            sourceId: tag.id, changes: PlannerTagChanges(iconName: .clear),
            expectedFieldHashes: [.iconName: iconHash]))
      ).outcome,
      case .source(.tag(let current)) = await planner.read(
        session: session, request: .source(tag)),
      case .rejected(let stale) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editTag(
            sourceId: tag.id,
            changes: PlannerTagChanges(
              name: .set("Stale name"),
              color: .set(PlannerColor(red: 1, green: 0, blue: 0, alpha: 1))),
            expectedFieldHashes: [.name: nameHash, .color: colorHash]))
      ).outcome,
      case .staleTagEdit(let conflicts, let values, let hashes) = stale.details
    else {
      Issue.record(
        "An independent field edit must succeed while a stale compound patch rejects together.")
      return
    }
    #expect(renamed.generated.isEmpty)
    #expect(renamed.affected == [tag])
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
      case .source(.tag(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(tag)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: nameOperation, session: reopenedSession, command: nameCommand)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: iconCheckpoint)),
      case .tag(let portable)? = recovery.decodedBackup.backup.sources.first
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
