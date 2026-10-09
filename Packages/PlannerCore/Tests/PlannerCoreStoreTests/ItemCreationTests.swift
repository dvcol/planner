import Foundation
import PlannerCore
import Testing

struct ItemCreationTests {
  @Test func savedItemSurvivesReopenWithIndependentAcknowledgedRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    let bootstrap = await planner.bootstrap()
    guard case .ready(let session) = bootstrap else {
      Issue.record("Explicit bootstrap must initialize a real local dataset: \(bootstrap)")
      return
    }
    let operationId = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000901"))
    let operation = PlannerOperation(
      operationId: operationId, session: session,
      command: .createItem(
        content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))
    )
    let created = await planner.execute(operation)
    #expect(created.operationId == operationId)
    guard case .applied(let result, .complete(let checkpoint)) = created.outcome else {
      Issue.record("Creation must have complete independent recovery: \(created)")
      return
    }
    #expect(checkpoint > 0)
    #expect(result.generated.count == 1)
    let item = try #require(result.generated.first)
    #expect(item.kind == .item)
    #expect(result.affected == [item])
    let initialRead = await planner.read(session: session, request: .source(item))
    let initialSource = try requireHotel(initialRead, identity: item)

    let reopenedPlanner = Planner(configuration: configuration)
    let reopenedBootstrap = await reopenedPlanner.bootstrap()
    guard case .ready(let reopenedSession) = reopenedBootstrap else {
      Issue.record("A new facade must reopen the dataset: \(reopenedBootstrap)")
      return
    }
    #expect(reopenedSession.datasetId == session.datasetId)
    #expect(reopenedSession.sessionId != session.sessionId)
    let reopenedRead = await reopenedPlanner.read(session: reopenedSession, request: .source(item))
    let reopenedSource = try requireHotel(reopenedRead, identity: item)
    #expect(reopenedSource.createdAt == initialSource.createdAt)
    #expect(reopenedSource.updatedAt == initialSource.updatedAt)
    #expect(reopenedSource.fieldHashes == initialSource.fieldHashes)
    let status = await reopenedPlanner.operationStatus(
      session: reopenedSession, operationId: operationId
    )
    guard case .appliedRecoveryComplete(let recordedResult, let recordedCheckpoint) = status else {
      Issue.record("Reopening must retain completed operation evidence: \(status)")
      return
    }
    #expect(recordedResult == result)
    #expect(recordedCheckpoint == checkpoint)
    let catalog = await reopenedPlanner.inspectRecovery(request: .namespaces)
    guard case .listedNamespaces(let namespaces) = catalog else {
      Issue.record("Native recovery discovery must read established namespaces: \(catalog)")
      return
    }
    #expect(namespaces.count == 1)
    let namespace = try #require(namespaces.first { $0.datasetId == session.datasetId })
    #expect(namespace.availability == .available)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(namespace.acknowledgedSnapshot?.integrity == "verified")
    let inspected = await reopenedPlanner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint
      )
    )
    guard case .selected(let selection) = inspected else {
      Issue.record("Completed recovery content must be independently readable: \(inspected)")
      return
    }
    #expect(selection.datasetId == session.datasetId)
    #expect(selection.evidence == .acknowledgedSnapshot)
    #expect(selection.checkpointGeneration == checkpoint)
    #expect(selection.proposalId == nil)
    #expect(selection.originalOperationId == nil)
    #expect(!selection.portableData.isEmpty)
    #expect(selection.decodedBackup.backup.sources.count == 1)
    let recoveredItem = try #require(selection.decodedBackup.backup.sources.first)
    #expect(recoveredItem.id == item.id)
    #expect(recoveredItem.kind == .item)
    #expect(recoveredItem.content.title == "Hotel")
    #expect(recoveredItem.content.notes == "Original notes")
    #expect(!recoveredItem.globalDone)
    #expect(!recoveredItem.archived)
    #expect(recoveredItem.content.links.isEmpty)
    #expect(recoveredItem.content.categoryIds.isEmpty)
    #expect(recoveredItem.content.tagIds.isEmpty)
    #expect(recoveredItem.contentOrigins == ["title": "independent", "notes": "independent"])
  }

  private func requireHotel(
    _ read: PlannerReadResult, identity: PlannerEntityReference
  ) throws -> PlannerSourceRead {
    guard case .source(let source) = read else {
      Issue.record("Hotel must be readable through the facade: \(read)")
      throw HotelReadFailure()
    }
    #expect(source.source == identity)
    #expect(source.content.title == "Hotel")
    #expect(source.content.notes == "Original notes")
    #expect(source.content.subtitle == nil)
    #expect(source.content.location == nil)
    #expect(source.content.estimate == nil)
    #expect(source.content.links.isEmpty)
    #expect(source.content.categoryIds.isEmpty)
    #expect(source.content.tagIds.isEmpty)
    #expect(source.state.globalDone == false)
    #expect(source.state.archived == false)
    #expect(source.labels.isEmpty)
    #expect(source.references.isEmpty)
    #expect(Set(source.fieldHashes.keys) == Set(PlannerItemField.allCases))
    #expect(source.fieldHashes.values.allSatisfy { $0.value.hasPrefix("sha256-v1:") })
    return source
  }

  private struct HotelReadFailure: Error {}
}
