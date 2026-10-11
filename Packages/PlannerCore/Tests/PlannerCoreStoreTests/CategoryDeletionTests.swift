import Foundation
import PlannerCore
import Testing

struct CategoryDeletionTests {
  @Test func reviewedCategoryDeletionDetachesAllOwnersAndDurablyRetainsTheirData() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let outcome = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
      guard case .applied(let result, .complete) = outcome else {
        Issue.record("Save the fixture through the public Core commands: \(outcome)")
        throw CancellationError()
      }
      return result
    }
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Food"))).generated.first)
    let tag = try #require(
      try await save(.createTag(content: .init(name: "Rainy day"))).generated.first)
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Keep the booking", categoryIds: [category.id], tagIds: [tag.id]
          ))
      ).generated.first)
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Tokyo", notes: "Keep the route", categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await save(.setArchive(source: item, archived: true))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    guard
      case .source(.category(let beforeCategory)) = await planner.read(
        session: session, request: .source(category)),
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let beforeItinerary)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    let command = PlannerCommand.deleteSource(source: category)
    let prepared = await planner.prepareReview(session: session, command: command)
    guard case .reviewed(let review) = prepared else {
      Issue.record(
        "Core must review deletion of the Category and both owner associations: \(prepared)")
      return
    }
    #expect(review.impact.kind == .deleteSource)
    #expect(review.impact.sourceDeletes == [category])
    #expect(review.impact.referenceRemovals == beforeCategory.references)
    #expect(
      review.targets == [.source(category)] + beforeCategory.references.map { .reference($0) })
    #expect(review.targetCount == 3 && !review.globalFlagsChanged)
    let operationId = UUID()
    let outcome = await planner.execute(
      .init(
        operationId: operationId, session: session, command: command,
        reviewToken: review.reviewToken)
    ).outcome
    guard case .applied(let result, .complete(let checkpoint)) = outcome else {
      Issue.record(
        "The reviewed Category deletion must commit with independent recovery: \(outcome)")
      return
    }
    #expect(result.generatedIdentities.isEmpty)
    guard
      case .failed(let missing) = await planner.read(session: session, request: .source(category)),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let retainedItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(missing.code == "missingReference")
    #expect(retainedItem.sourceLifetimeId == beforeItem.sourceLifetimeId)
    #expect(retainedItem.createdAt == beforeItem.createdAt)
    #expect(retainedItem.updatedAt > beforeItem.updatedAt)
    #expect(
      retainedItem.content.title == "Museum" && retainedItem.content.notes == "Keep the booking")
    #expect(retainedItem.content.categoryIds.isEmpty && retainedItem.content.tagIds == [tag.id])
    #expect(retainedItem.state.globalDone == true && retainedItem.state.archived == true)
    #expect(retainedItinerary.sourceLifetimeId == beforeItinerary.sourceLifetimeId)
    #expect(retainedItinerary.createdAt == beforeItinerary.createdAt)
    #expect(retainedItinerary.updatedAt > beforeItinerary.updatedAt)
    #expect(
      retainedItinerary.content.title == "Tokyo"
        && retainedItinerary.content.notes == "Keep the route")
    #expect(
      retainedItinerary.content.categoryIds.isEmpty && retainedItinerary.content.tagIds == [tag.id])
    #expect(retainedItinerary.state.archived == true)
    #expect(recovered.decodedBackup.backup.labelAssociations.count == 2)
    let markers = recovered.decodedBackup.backup.deletionMarkers
    #expect(markers.count == 3)
    #expect(markers.allSatisfy { $0.operationId == operationId && $0.closedFamilyId == nil })
    #expect(
      markers.contains {
        $0.target == .source(category, lifetimeId: beforeCategory.sourceLifetimeId)
      })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(
          operationId: operationId, session: reopenedSession, command: command)
      ).outcome,
      case .source(.item(let reopenedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item))
    else { throw CancellationError() }
    #expect(replay.affectedIdentities == result.affectedIdentities)
    #expect(replayCheckpoint == checkpoint)
    #expect(
      reopenedItem.content.categoryIds.isEmpty && reopenedItem.content.notes == "Keep the booking")
  }
}
