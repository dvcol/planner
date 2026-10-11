import Foundation
import PlannerCore
import Testing

struct ListDeletionTests {
  @Test func reviewedListDeletionRemovesItsReferencesAndKeepsItsSourceItemsAndRemainingRoute()
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
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
      guard case .applied(let result, .complete) = outcome else {
        Issue.record("Save the graph through public commands: \(outcome)")
        throw CancellationError()
      }
      return result
    }
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Culture"))).generated.first)
    let tag = try #require(
      try await save(.createTag(content: .init(name: "Rainy day"))).generated.first)
    var items: [PlannerEntityReference] = []
    for title in ["Museum", "Park"] {
      let item = try #require(
        try await save(
          .createItem(
            content: .init(
              title: title, notes: "Keep \(title) booking",
              links: [.init(originalUrl: "https://example.com/tickets", label: "\(title) tickets")],
              categoryIds: [category.id], tagIds: [tag.id]))
        ).generated.first)
      items.append(item)
    }
    _ = try await save(.setArchive(source: items[1], archived: true))
    let removedList = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food", notes: "Remove this List")))
        .generated.first)
    let retainedList = try #require(
      try await save(.createList(content: .init(name: "Wishlist", notes: "Keep this List")))
        .generated.first)
    var memberships: [UUID] = []
    for (item, list) in [
      (items[0], removedList), (items[1], removedList), (items[0], retainedList),
    ] {
      guard
        case .membership(let identifier, _, _)? = try await save(
          .addMembership(itemId: item.id, listId: list.id, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      memberships.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: removedList.id, membershipId: memberships[0])),
        done: true))
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Tokyo Weekend", notes: "Keep the route",
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    var entries: [UUID] = []
    for source in [items[0], removedList, removedList, retainedList, items[1]] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    let removedAppearances = [
      PlannerAppearance.expandedListItem(
        itineraryId: itinerary.id, listEntryId: entries[1], membershipId: memberships[0]),
      .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entries[2], membershipId: memberships[1]),
    ]
    let retainedAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entries[3], membershipId: memberships[2])
    for appearance in [
      PlannerAppearance.directItineraryItem(itineraryId: itinerary.id, entryId: entries[0])
    ] + removedAppearances + [retainedAppearance] {
      _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    }
    let itemSchedule = try #require(
      try await save(
        .createSchedule(
          source: items[0],
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
            planningTimeZone: "Asia/Tokyo"))
      ).generated.first)
    let itinerarySchedule = try #require(
      try await save(
        .createSchedule(
          source: itinerary,
          form: .allDay(
            start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))
        )
      ).generated.first)
    guard
      case .source(.list(let beforeRemovedList)) = await planner.read(
        session: session, request: .source(removedList)),
      case .source(.list(let beforeRetainedList)) = await planner.read(
        session: session, request: .source(retainedList)),
      case .source(.itinerary(let beforeItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let beforeMuseum)) = await planner.read(
        session: session, request: .source(items[0])),
      case .source(.item(let beforePark)) = await planner.read(
        session: session, request: .source(items[1])),
      case .source(.schedule(let beforeItemSchedule)) = await planner.read(
        session: session, request: .source(itemSchedule)),
      case .source(.schedule(let beforeItinerarySchedule)) = await planner.read(
        session: session, request: .source(itinerarySchedule)),
      case .listedNamespaces(let beforeNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      let beforeNamespace = beforeNamespaces.first,
      let beforeCheckpoint = beforeNamespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let beforeRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: beforeNamespace.namespaceId, checkpointGeneration: beforeCheckpoint)),
      case .list(let beforePortableList)? = beforeRecovery.decodedBackup.backup.sources.first(
        where: {
          $0.kind == .list && $0.id == removedList.id
        })
    else { throw CancellationError() }
    #expect(beforeRemovedList.progress.doneCount == 1 && beforeRemovedList.progress.totalCount == 2)
    #expect(beforeItinerary.progress.doneCount == 4 && beforeItinerary.progress.totalCount == 7)
    let command = PlannerCommand.deleteSource(source: removedList)
    let prepared = await planner.prepareReview(session: session, command: command)
    guard case .reviewed(let review) = prepared else {
      Issue.record("Core must review the List and its complete removal set: \(prepared)")
      return
    }
    let expandedReferences = [
      PlannerReferenceRead.expandedCompletion(
        itineraryId: itinerary.id, listEntryId: entries[1], membershipId: memberships[0]),
      .expandedCompletion(
        itineraryId: itinerary.id, listEntryId: entries[2], membershipId: memberships[1]),
    ]
    #expect(review.impact.sourceDeletes == [removedList])
    let expectedRemovals = beforeRemovedList.references + expandedReferences
    #expect(
      review.impact.referenceRemovals.count == expectedRemovals.count
        && expectedRemovals.allSatisfy { review.impact.referenceRemovals.contains($0) })
    #expect(review.targetCount == 7 && !review.globalFlagsChanged)
    let operationId = UUID()
    guard
      case .applied(let applied, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: operationId, session: session, command: command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .source(.list(let afterList)) = await planner.read(
        session: session, request: .source(retainedList)),
      case .source(.itinerary(let afterItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let afterMuseum)) = await planner.read(
        session: session, request: .source(items[0])),
      case .source(.item(let afterPark)) = await planner.read(
        session: session, request: .source(items[1])),
      case .source(.schedule(let afterItemSchedule)) = await planner.read(
        session: session, request: .source(itemSchedule)),
      case .source(.schedule(let afterItinerarySchedule)) = await planner.read(
        session: session, request: .source(itinerarySchedule)),
      case .appearance(let afterAppearance) = await planner.read(
        session: session, request: .appearance(retainedAppearance)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(applied.affectedReferences == review.impact.referenceRemovals)
    #expect(afterList.content == beforeRetainedList.content)
    #expect(afterList.fieldHashes == beforeRetainedList.fieldHashes)
    #expect(afterList.updatedAt == beforeRetainedList.updatedAt)
    #expect(afterList.progress.doneCount == 0 && afterList.progress.totalCount == 1)
    #expect(afterItinerary.content == beforeItinerary.content)
    #expect(afterItinerary.progress.doneCount == 2 && afterItinerary.progress.totalCount == 3)
    #expect(afterAppearance.localDone == true && afterAppearance.globalDone == false)
    for (before, after) in [(beforeMuseum, afterMuseum), (beforePark, afterPark)] {
      #expect(
        after.content.title == before.content.title && after.content.notes == before.content.notes)
      #expect(after.content.links == before.content.links)
      #expect(after.content.categoryIds == before.content.categoryIds)
      #expect(after.content.tagIds == before.content.tagIds)
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
      #expect(after.state.globalDone == before.state.globalDone)
      #expect(after.state.archived == before.state.archived)
    }
    #expect(afterItemSchedule.content == beforeItemSchedule.content)
    #expect(afterItinerarySchedule.content == beforeItinerarySchedule.content)
    let backup = recovery.decodedBackup.backup
    #expect(backup.sources.count == 6 && backup.labelAssociations.count == 6)
    #expect(backup.memberships.count == 1 && backup.memberships.first?.id == memberships[2])
    #expect(
      backup.itineraryEntries.sorted { $0.rank < $1.rank }.map(\.id)
        == [entries[0], entries[3], entries[4]])
    #expect(backup.expandedCompletions.count == 1)
    #expect(backup.schedules.count == 2)
    #expect(backup.deletionMarkers.count == 5)
    #expect(
      backup.deletionMarkers.contains {
        $0.target == .source(removedList, lifetimeId: beforePortableList.lifetimeId)
      })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .failed(let missingList) = await reopened.read(
        session: reopenedSession, request: .source(removedList)),
      case .source(.itinerary(let restoredItinerary)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .applied(let replay, .complete) = await reopened.execute(
        .init(operationId: operationId, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(missingList.code == "missingReference")
    #expect(restoredItinerary.progress.doneCount == 2 && restoredItinerary.progress.totalCount == 3)
    #expect(replay == applied)
    for appearance in removedAppearances {
      guard
        case .failed(let missing) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else {
        Issue.record("The removed List's expanded appearances must stay absent.")
        return
      }
      #expect(missing.code == "missingReference")
    }
  }
}
