import Foundation
import PlannerCore
import Testing

struct TagDeletionTests {
  @Test func reviewedTagDeletionPreservesDuplicateNamesAndTheOwnersCompletePlanningGraph()
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
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let outcome = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: command)
      ).outcome
      guard case .applied(let result, .complete) = outcome else {
        Issue.record("Save the planning graph through public commands: \(outcome)")
        throw CancellationError()
      }
      return result
    }
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Food"))).generated.first)
    let removedTag = try #require(
      try await save(.createTag(content: .init(name: "Rainy day"))).generated.first)
    let retainedTag = try #require(
      try await save(.createTag(content: .init(name: "Rainy day"))).generated.first)
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Keep the booking",
            links: [
              .init(originalUrl: "https://example.com/museum", label: "Tickets")
            ],
            categoryIds: [category.id], tagIds: [removedTag.id, retainedTag.id]))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Wishlist"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(
          itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    let membershipAppearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipId)
    _ = try await save(.setCompletion(scope: .appearance(membershipAppearance), done: true))
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Tokyo", notes: "Keep the route",
            links: [.init(originalUrl: "https://example.com/route", label: "Route")],
            categoryIds: [category.id], tagIds: [removedTag.id, retainedTag.id]))
      ).generated.first)
    for source in [item, item, list] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    _ = try await save(
      .createSchedule(
        source: item,
        form: .timed(
          start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
          planningTimeZone: "Asia/Tokyo")))
    _ = try await save(
      .createSchedule(
        source: itinerary,
        form: .allDay(
          start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await save(.setArchive(source: item, archived: true))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    guard
      case .source(.tag(let beforeTag)) = await planner.read(
        session: session, request: .source(removedTag)),
      case .source(.tag(let beforeRetainedTag)) = await planner.read(
        session: session, request: .source(retainedTag)),
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let beforeItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .appearance(let beforeMembership) = await planner.read(
        session: session, request: .appearance(membershipAppearance))
    else { throw CancellationError() }
    let command = PlannerCommand.deleteSource(source: removedTag)
    let prepared = await planner.prepareReview(session: session, command: command)
    guard case .reviewed(let review) = prepared else {
      Issue.record(
        "Core must review Tag deletion separately from its same-named neighbor: \(prepared)")
      return
    }
    #expect(review.impact.sourceDeletes == [removedTag])
    #expect(review.impact.referenceRemovals == beforeTag.references)
    #expect(review.targetCount == 3 && !review.globalFlagsChanged)
    let operationId = UUID()
    guard
      case .applied(let result, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: operationId, session: session, command: command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .source(.item(let afterItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let afterItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.tag(let afterRetainedTag)) = await planner.read(
        session: session, request: .source(retainedTag)),
      case .appearance(let afterMembership) = await planner.read(
        session: session, request: .appearance(membershipAppearance)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(afterItem.content.title == "Museum" && afterItem.content.notes == "Keep the booking")
    #expect(afterItem.content.links == beforeItem.content.links)
    #expect(
      afterItem.content.categoryIds == [category.id] && afterItem.content.tagIds == [retainedTag.id]
    )
    #expect(afterItem.state.globalDone == true && afterItem.state.archived == true)
    #expect(
      afterItem.createdAt == beforeItem.createdAt && afterItem.updatedAt > beforeItem.updatedAt)
    #expect(afterItem.fieldHashes[.categoryIds] == beforeItem.fieldHashes[.categoryIds])
    #expect(afterItem.fieldHashes[.tagIds] != beforeItem.fieldHashes[.tagIds])
    #expect(
      afterItinerary.content.title == "Tokyo" && afterItinerary.content.notes == "Keep the route")
    #expect(afterItinerary.content.links == beforeItinerary.content.links)
    #expect(
      afterItinerary.content.categoryIds == [category.id]
        && afterItinerary.content.tagIds == [retainedTag.id])
    #expect(
      afterItinerary.references
        == beforeItinerary.references.filter { !beforeTag.references.contains($0) })
    #expect(
      afterItem.references == beforeItem.references.filter { !beforeTag.references.contains($0) })
    #expect(afterItinerary.progress.doneCount == 3 && afterItinerary.progress.totalCount == 3)
    #expect(
      afterMembership.localDone == beforeMembership.localDone && afterMembership.localDone == true)
    #expect(afterRetainedTag.fieldHashes == beforeRetainedTag.fieldHashes)
    #expect(afterRetainedTag.updatedAt == beforeRetainedTag.updatedAt)
    let backup = recovery.decodedBackup.backup
    #expect(backup.labelAssociations.count == 4)
    #expect(backup.memberships.count == 1 && backup.memberships.first?.localDone == true)
    #expect(backup.itineraryEntries.count == 3 && backup.schedules.count == 2)
    #expect(backup.deletionMarkers.count == 3)
    #expect(
      backup.deletionMarkers.contains {
        $0.target == .source(removedTag, lifetimeId: beforeTag.sourceLifetimeId)
      })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .failed(let missing) = await reopened.read(
        session: reopenedSession, request: .source(removedTag)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(
          operationId: operationId, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(missing.code == "missingReference")
    #expect(replay == result && replayCheckpoint == checkpoint)
  }
}
