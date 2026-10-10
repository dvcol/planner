import Foundation
import PlannerCore
import Testing

struct ItemLabelEditTests {
  @Test func independentLabelPatchesRetainReferencesRejectStaleChangesAndReplayExactly()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Open the local dataset before assigning labels.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome, let source = created.generated.first
      else {
        Issue.record("Create each source with complete independent recovery.")
        throw MissingResult()
      }
      return source
    }
    let food = try await create(.createCategory(content: PlannerCategoryContentInput(name: "Food")))
    let culture = try await create(
      .createCategory(content: PlannerCategoryContentInput(name: "Culture")))
    let rain = try await create(.createTag(content: PlannerTagContentInput(name: "Rain")))
    let travel = try await create(.createTag(content: PlannerTagContentInput(name: "Travel")))
    let item = try await create(
      .createItem(
        content: PlannerItemContentInput(
          title: "Hotel", notes: "Keep", categoryIds: [food.id], tagIds: [rain.id])))
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Read the Item's original label guards.")
      return
    }
    let categoryOperation = UUID()
    let categoryCommand = PlannerCommand.editItem(
      sourceId: item.id, changes: PlannerItemChanges(categoryIds: .set([food.id, culture.id])),
      expectedFieldHashes: original.fieldHashes)
    let categoryOutcome = await planner.execute(
      PlannerOperation(
        operationId: categoryOperation, session: session, command: categoryCommand)
    ).outcome
    guard case .applied(let categoryResult, .complete(let categoryCheckpoint)) = categoryOutcome,
      case .source(.item(let withCulture)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("A guarded label selection must save completely: \(categoryOutcome)")
      return
    }
    #expect(categoryCheckpoint == 6)
    #expect(withCulture.content.categoryIds == [food.id, culture.id])
    #expect(withCulture.content.tagIds == [rain.id])
    #expect(withCulture.content.notes == "Keep")
    #expect(withCulture.updatedAt > original.updatedAt)
    #expect(withCulture.fieldHashes[.categoryIds] != original.fieldHashes[.categoryIds])
    #expect(withCulture.fieldHashes[.tagIds] == original.fieldHashes[.tagIds])
    #expect(original.references.allSatisfy { withCulture.references.contains($0) })
    #expect(categoryResult.generated.isEmpty)
    #expect(categoryResult.generatedReferences.count == 1)
    #expect(categoryResult.generatedReferences.allSatisfy { withCulture.references.contains($0) })
    let rainReference = try #require(
      original.references.first { reference in
        guard case .labelAssociation(_, _, let label) = reference else { return false }
        return label == rain
      })
    guard case .labelAssociation(let rainAssociation, _, _) = rainReference else {
      Issue.record("The original Rain selection has an association identity.")
      return
    }
    let tagOutcome = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id,
          changes: PlannerItemChanges(tagIds: .set([travel.id])),
          expectedFieldHashes: original.fieldHashes))
    ).outcome
    guard case .applied(let tagResult, .complete(let tagCheckpoint)) = tagOutcome,
      case .source(.item(let withTravel)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.tag(let detachedRain)) = await planner.read(
        session: session, request: .source(rain))
    else {
      Issue.record("A changed Category must not invalidate an independent Tag guard: \(tagOutcome)")
      return
    }
    #expect(tagCheckpoint == 7)
    #expect(withTravel.content.categoryIds == [food.id, culture.id])
    #expect(withTravel.content.tagIds == [travel.id])
    #expect(withTravel.fieldHashes[.categoryIds] == withCulture.fieldHashes[.categoryIds])
    #expect(withTravel.fieldHashes[.tagIds] != original.fieldHashes[.tagIds])
    #expect(!withTravel.references.contains(rainReference))
    #expect(detachedRain.content.name == "Rain")
    #expect(detachedRain.references.isEmpty)
    #expect(tagResult.generatedReferences.count == 1)
    #expect(tagResult.affectedReferences.contains(rainReference))
    let staleOperation = UUID()
    let stale = await planner.execute(
      PlannerOperation(
        operationId: staleOperation, session: session,
        command: .editItem(
          sourceId: item.id,
          changes: PlannerItemChanges(notes: .set("Must not save"), categoryIds: .set([])),
          expectedFieldHashes: original.fieldHashes))
    ).outcome
    guard case .rejected(let reason) = stale,
      case .staleEdit(let fields, let currentValues, let currentHashes) = reason.details,
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("One stale selection must reject the entire notes/Category patch: \(stale)")
      return
    }
    #expect(reason.code == "staleEdit")
    #expect(fields == [.categoryIds])
    #expect(currentValues.count == 1)
    #expect(currentHashes == [.categoryIds: try #require(withTravel.fieldHashes[.categoryIds])])
    #expect(retained.content.title == "Hotel")
    #expect(retained.content.notes == "Keep")
    #expect(retained.content.categoryIds == [food.id, culture.id])
    #expect(retained.content.tagIds == [travel.id])
    #expect(retained.updatedAt == withTravel.updatedAt)
    #expect(retained.fieldHashes == withTravel.fieldHashes)
    #expect(retained.references == withTravel.references)
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleOperation)
    else {
      Issue.record("A stale rejection must not claim a saved operation.")
      return
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: categoryOperation, session: reopenedSession, command: categoryCommand)
      ).outcome,
      case .source(.item(let reopenedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: tagCheckpoint))
    else {
      Issue.record("Reopen/replay must retain the later Tag edit and its complete recovery.")
      return
    }
    #expect(replayed == categoryResult)
    #expect(replayCheckpoint == categoryCheckpoint)
    #expect(reopenedItem.content.title == "Hotel")
    #expect(reopenedItem.content.notes == "Keep")
    #expect(reopenedItem.content.categoryIds == [food.id, culture.id])
    #expect(reopenedItem.content.tagIds == [travel.id])
    #expect(reopenedItem.references == withTravel.references)
    #expect(reopenedItem.fieldHashes == withTravel.fieldHashes)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == tagCheckpoint)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(recovery.decodedBackup.backup.labelAssociations.count == 3)
    #expect(
      recovery.decodedBackup.backup.items.first?.content.categoryIds == [food.id, culture.id])
    #expect(recovery.decodedBackup.backup.items.first?.content.tagIds == [travel.id])
    let graph = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    #expect(markers.count == 1)
    let target = try #require(markers.first?["target"] as? [String: Any])
    #expect(Set(target.keys) == ["kind", "id", "lifetimeId"])
    #expect(target["kind"] as? String == "labelAssociation")
    #expect(target["id"] as? String == rainAssociation.uuidString)
    #expect(target["lifetimeId"] as? String == rainAssociation.uuidString)
  }

  private struct MissingResult: Error {}
}
