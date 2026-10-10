import Foundation
import PlannerCore
import Testing

struct ItemLabelEditValidationTests {
  @Test func invalidPatchesAreAtomicAndClearReaddKeepsClosedAssociationsSeparate() async throws {
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
      case .applied(let tagCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createTag(content: PlannerTagContentInput(name: "Food")))
      ).outcome,
      let tag = tagCreation.generated.first,
      case .applied(let itemCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Keep", categoryIds: [category.id], tagIds: [tag.id])))
      ).outcome,
      let item = itemCreation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Save the labelled Item before checking atomic rejection.")
      return
    }
    let missing = UUID()
    let invalid: [(PlannerItemChanges, [PlannerItemField: PlannerFieldHash], String, String)] = [
      (
        PlannerItemChanges(categoryIds: .clear), original.fieldHashes, "invalidInput",
        "/command/changes/categoryIds"
      ),
      (
        PlannerItemChanges(tagIds: .clear), original.fieldHashes, "invalidInput",
        "/command/changes/tagIds"
      ),
      (
        PlannerItemChanges(categoryIds: .set([tag.id])), original.fieldHashes, "missingReference",
        "/command/changes/categoryIds"
      ),
      (
        PlannerItemChanges(tagIds: .set([category.id])), original.fieldHashes, "missingReference",
        "/command/changes/tagIds"
      ),
      (
        PlannerItemChanges(notes: .set("Must not save"), categoryIds: .set([missing])),
        original.fieldHashes, "missingReference", "/command/changes/categoryIds"
      ),
      (
        PlannerItemChanges(categoryIds: .set([]), tagIds: .set([missing])), original.fieldHashes,
        "missingReference", "/command/changes/tagIds"
      ),
      (
        PlannerItemChanges(categoryIds: .set([])), [:], "invalidInput",
        "/command/expectedFieldHashes/categoryIds"
      ),
      (
        PlannerItemChanges(tagIds: .set([])), [.tagIds: PlannerFieldHash(value: "sha256-v2:bad")],
        "invalidInput", "/command/expectedFieldHashes/tagIds"
      ),
    ]
    for (changes, hashes, code, propertyPath) in invalid {
      let operationId = UUID()
      let outcome = await planner.execute(
        PlannerOperation(
          operationId: operationId, session: session,
          command: .editItem(sourceId: item.id, changes: changes, expectedFieldHashes: hashes))
      ).outcome
      guard case .rejected(let reason) = outcome,
        case .source(.item(let retained)) = await planner.read(
          session: session, request: .source(item)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Invalid label edits leave all content and associations unapplied: \(outcome)")
        return
      }
      #expect(reason.code == code)
      #expect(reason.propertyPath == propertyPath)
      #expect(retained.content.notes == "Keep")
      #expect(retained.content.categoryIds == [category.id])
      #expect(retained.content.tagIds == [tag.id])
      #expect(retained.references == original.references)
      #expect(retained.fieldHashes == original.fieldHashes)
      #expect(retained.updatedAt == original.updatedAt)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      guard
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationId)
      else {
        Issue.record("A rejected selection cannot claim a saved operation.")
        return
      }
    }
    let clearOperation = UUID()
    let clearCommand = PlannerCommand.editItem(
      sourceId: item.id,
      changes: PlannerItemChanges(categoryIds: .set([]), tagIds: .set([])),
      expectedFieldHashes: original.fieldHashes)
    guard
      case .applied(let cleared, .complete(let clearCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: clearOperation, session: session, command: clearCommand)
      ).outcome,
      case .source(.item(let empty)) = await planner.read(session: session, request: .source(item)),
      case .applied(let readded, .complete(let readdCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id,
            changes: PlannerItemChanges(categoryIds: .set([category.id]), tagIds: .set([tag.id])),
            expectedFieldHashes: empty.fieldHashes))
      ).outcome,
      case .source(.item(let restoredSelection)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Explicit empty selections clear their joins; ordinary re-add makes new joins.")
      return
    }
    #expect(clearCheckpoint == 4)
    #expect(empty.content.categoryIds.isEmpty)
    #expect(empty.content.tagIds.isEmpty)
    #expect(empty.labels.isEmpty)
    #expect(empty.references.isEmpty)
    #expect(cleared.generatedReferences.isEmpty)
    #expect(cleared.affectedReferences.count == 2)
    #expect(readdCheckpoint == 5)
    #expect(readded.generatedReferences.count == 2)
    #expect(restoredSelection.references.count == 2)
    #expect(restoredSelection.references.allSatisfy { !original.references.contains($0) })
    #expect(restoredSelection.fieldHashes == original.fieldHashes)
    #expect(restoredSelection.content.notes == "Keep")
    guard
      case .applied(let replayed, .complete(let replayCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: clearOperation, session: session, command: clearCommand)
      ).outcome,
      case .source(.item(let afterReplay)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: readdCheckpoint))
    else {
      Issue.record("Replaying the earlier clear cannot remove a later ordinary selection.")
      return
    }
    #expect(replayed == cleared)
    #expect(replayCheckpoint == clearCheckpoint)
    #expect(afterReplay.references == restoredSelection.references)
    #expect(afterReplay.fieldHashes == restoredSelection.fieldHashes)
    #expect(afterReplay.updatedAt == restoredSelection.updatedAt)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == readdCheckpoint)
    #expect(recovery.decodedBackup.backup.labelAssociations.count == 2)
    #expect(recovery.decodedBackup.backup.deletionMarkers.count == 2)
    for marker in recovery.decodedBackup.backup.deletionMarkers {
      guard case .labelAssociation(let identifier, let lifetimeId) = marker.target else {
        Issue.record("Cleared labels retain only their association closure.")
        return
      }
      #expect(identifier == lifetimeId)
      #expect(!recovery.decodedBackup.backup.labelAssociations.contains { $0.id == identifier })
      #expect(marker.operationId == clearOperation)
    }
    let stale = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(tagIds: .set([])),
          expectedFieldHashes: empty.fieldHashes))
    ).outcome
    guard case .rejected(let reason) = stale,
      case .staleEdit(let fields, let values, let hashes) = reason.details
    else {
      Issue.record("The empty-selection guard is stale after ordinary re-add.")
      return
    }
    #expect(fields == [.tagIds])
    #expect(values == [.tagIds: .identitySet([tag.id])])
    #expect(hashes == [.tagIds: try #require(restoredSelection.fieldHashes[.tagIds])])
    let changedPayload = await planner.execute(
      PlannerOperation(
        operationId: clearOperation, session: session,
        command: .editItem(
          sourceId: item.id,
          changes: PlannerItemChanges(categoryIds: .set([category.id]), tagIds: .set([])),
          expectedFieldHashes: original.fieldHashes))
    ).outcome
    guard case .rejected(let mismatch) = changedPayload,
      case .applied(_, .complete(let notesCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id,
            changes: PlannerItemChanges(notes: .set("Friday")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .applied(_, .complete(let laterCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createTag(content: PlannerTagContentInput(name: "Unrelated")))
      ).outcome,
      case .selected(let laterRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId,
          checkpointGeneration: laterCheckpoint)),
      case .source(.item(let laterItem)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Modified operation payloads reject; later writers preserve label closures.")
      return
    }
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(notesCheckpoint == 6)
    #expect(laterCheckpoint == 7)
    #expect(laterItem.content.notes == "Friday")
    #expect(laterItem.references == restoredSelection.references)
    #expect(laterItem.fieldHashes[.categoryIds] == original.fieldHashes[.categoryIds])
    #expect(laterItem.fieldHashes[.tagIds] == original.fieldHashes[.tagIds])
    #expect(laterRecovery.decodedBackup.backup.labelAssociations.count == 2)
    #expect(
      laterRecovery.decodedBackup.backup.deletionMarkers
        == recovery.decodedBackup.backup.deletionMarkers)
  }
}
