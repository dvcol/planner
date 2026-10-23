import Foundation
import PlannerCore
import Testing

struct ItemDeletionTests {
  @Test func reviewedItemDeletionRemovesItsCompleteClosureAndPreservesTheRemainingPlan()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
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
    let removedItem = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Deleted booking",
            links: [.init(originalUrl: "https://example.com/tickets", label: "Museum tickets")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    let retainedItem = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Park", notes: "Retained booking",
            links: [.init(originalUrl: "https://example.com/tickets", label: "Park tickets")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    _ = try await save(.setArchive(source: retainedItem, archived: true))
    let firstList = try #require(
      try await save(.createList(content: .init(name: "Wishlist", notes: "Keep this List")))
        .generated.first)
    let secondList = try #require(
      try await save(.createList(content: .init(name: "Rain plan"))).generated.first)
    var memberships: [UUID] = []
    for (item, list) in [
      (removedItem, firstList), (retainedItem, firstList), (removedItem, secondList),
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
        scope: .appearance(.listMembership(listId: firstList.id, membershipId: memberships[0])),
        done: true))
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Tokyo Weekend", notes: "Keep the route",
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    var entries: [UUID] = []
    for source in [removedItem, removedItem, firstList, secondList] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: entries[0])),
        done: true))
    let expandedAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entries[2], membershipId: memberships[0])
    _ = try await save(.setCompletion(scope: .appearance(expandedAppearance), done: true))
    var removedSchedules: [PlannerEntityReference] = []
    for end in [nil, Date(timeIntervalSinceReferenceDate: 813_204_000)] {
      let schedule = try #require(
        try await save(
          .createSchedule(
            source: removedItem,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: end,
              planningTimeZone: "Asia/Tokyo"))
        )
        .generated.first)
      removedSchedules.append(schedule)
    }
    let retainedSchedule = try #require(
      try await save(
        .createSchedule(
          source: itinerary,
          form: .allDay(
            start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))
        )
      )
      .generated.first)
    guard
      case .source(.item(let beforeRemovedItem)) = await planner.read(
        session: session, request: .source(removedItem)),
      case .source(.item(let beforeRetainedItem)) = await planner.read(
        session: session, request: .source(retainedItem)),
      case .source(.itinerary(let beforeItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.category(let beforeCategory)) = await planner.read(
        session: session, request: .source(category)),
      case .source(.tag(let beforeTag)) = await planner.read(
        session: session, request: .source(tag))
    else { throw CancellationError() }
    #expect(beforeItinerary.progress.doneCount == 2 && beforeItinerary.progress.totalCount == 5)
    let command = PlannerCommand.deleteSource(source: removedItem)
    let prepared = await planner.prepareReview(session: session, command: command)
    guard case .reviewed(let review) = prepared else {
      Issue.record("Core must review the Item and its complete removal set: \(prepared)")
      return
    }
    let expandedReference = PlannerReferenceRead.expandedCompletion(
      itineraryId: itinerary.id, listEntryId: entries[2], membershipId: memberships[0])
    #expect(
      review.impact.sourceDeletes == [removedItem]
        + removedSchedules.sorted { $0.id.uuidString < $1.id.uuidString })
    #expect(review.impact.referenceRemovals == beforeRemovedItem.references + [expandedReference])
    #expect(review.targetCount == 11 && !review.globalFlagsChanged)
    let operationId = UUID()
    guard
      case .applied(let applied, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: operationId, session: session, command: command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .source(.item(let afterRetainedItem)) = await planner.read(
        session: session, request: .source(retainedItem)),
      case .source(.itinerary(let afterItinerary)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.list(let afterFirstList)) = await planner.read(
        session: session, request: .source(firstList)),
      case .source(.list(let afterSecondList)) = await planner.read(
        session: session, request: .source(secondList)),
      case .source(.category(let afterCategory)) = await planner.read(
        session: session, request: .source(category)),
      case .source(.tag(let afterTag)) = await planner.read(
        session: session, request: .source(tag)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(applied.affectedReferences == review.impact.referenceRemovals)
    #expect(
      afterRetainedItem.content.title == "Park"
        && afterRetainedItem.content.notes == "Retained booking")
    #expect(afterRetainedItem.content.links == beforeRetainedItem.content.links)
    #expect(
      afterRetainedItem.content.categoryIds == [category.id]
        && afterRetainedItem.content.tagIds == [tag.id])
    #expect(afterRetainedItem.fieldHashes == beforeRetainedItem.fieldHashes)
    #expect(afterRetainedItem.updatedAt == beforeRetainedItem.updatedAt)
    #expect(afterRetainedItem.state.archived == true && afterRetainedItem.state.globalDone == false)
    #expect(afterFirstList.content.notes == "Keep this List")
    #expect(afterFirstList.progress.doneCount == 0 && afterFirstList.progress.totalCount == 1)
    #expect(afterSecondList.progress.state == .empty)
    #expect(afterItinerary.content == beforeItinerary.content)
    #expect(afterItinerary.progress.doneCount == 0 && afterItinerary.progress.totalCount == 1)
    #expect(
      afterCategory.fieldHashes == beforeCategory.fieldHashes
        && afterCategory.updatedAt == beforeCategory.updatedAt)
    #expect(
      afterTag.fieldHashes == beforeTag.fieldHashes && afterTag.updatedAt == beforeTag.updatedAt)
    let backup = recovery.decodedBackup.backup
    #expect(backup.sources.count == 6)
    #expect(backup.memberships.count == 1 && backup.memberships.first?.id == memberships[1])
    #expect(
      backup.itineraryEntries.sorted { $0.rank < $1.rank }.map(\.id) == Array(entries.suffix(2)))
    #expect(backup.expandedCompletions.isEmpty && backup.labelAssociations.count == 4)
    #expect(backup.schedules.count == 1 && backup.schedules.first?.id == retainedSchedule.id)
    #expect(backup.deletionMarkers.count == 10)
    #expect(
      Set(
        backup.deletionMarkers.compactMap { marker -> UUID? in
          guard case .ownedLink(let identifier, _) = marker.target else { return nil }
          return identifier
        })
        == Set(
          beforeRemovedItem.references.compactMap { reference -> UUID? in
            guard case .ownedLink(let identifier, _) = reference else { return nil }
            return identifier
          }))
    #expect(
      backup.deletionMarkers.contains {
        $0.target == .source(removedItem, lifetimeId: beforeRemovedItem.sourceLifetimeId)
      })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      throw CancellationError()
    }
    for source in [removedItem] + removedSchedules {
      guard
        case .failed(let failure) = await reopened.read(
          session: reopenedSession, request: .source(source))
      else {
        Issue.record("Deleted source must stay absent after reopening: \(source)")
        return
      }
      #expect(failure.code == "missingReference")
    }
    guard
      case .source(.itinerary(let restoredItinerary)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .failed(let removedAppearance) = await reopened.read(
        session: reopenedSession, request: .appearance(expandedAppearance)),
      case .applied(let replay, .complete) = await reopened.execute(
        .init(operationId: operationId, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(restoredItinerary.progress.doneCount == 0 && restoredItinerary.progress.totalCount == 1)
    #expect(removedAppearance.code == "missingReference")
    #expect(replay == applied)
  }
}
