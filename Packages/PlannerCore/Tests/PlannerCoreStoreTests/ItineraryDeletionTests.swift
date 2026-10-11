import Foundation
import PlannerCore
import Testing

struct ItineraryDeletionTests {
  @Test func reviewedItineraryDeletionRemovesOwnedDataAndRetainsSourcesAndOtherPlansAfterReopening()
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
        Issue.record("Save the shared graph through public commands: \(outcome)")
        throw CancellationError()
      }
      return result
    }
    func recovery() async throws -> PlannerRecoverySelection {
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
        case .selected(let selection) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      return selection
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
    _ = try await save(.setCompletion(scope: .globalItem(itemId: items[1].id), done: true))
    var lists: [PlannerEntityReference] = []
    for name in ["Tokyo Food", "Wishlist"] {
      lists.append(
        try #require(try await save(.createList(content: .init(name: name))).generated.first))
    }
    var memberships: [UUID] = []
    for (item, list) in [(items[0], lists[0]), (items[1], lists[0]), (items[0], lists[1])] {
      guard
        case .membership(let identifier, _, _)? = try await save(
          .addMembership(itemId: item.id, listId: list.id, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      memberships.append(identifier)
    }
    let standaloneAppearance = PlannerAppearance.listMembership(
      listId: lists[0].id, membershipId: memberships[0])
    _ = try await save(.setCompletion(scope: .appearance(standaloneAppearance), done: true))
    let removedItinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Weekend", notes: "Delete the plan only",
            links: [
              .init(originalUrl: "https://example.com/route", label: "Route"),
              .init(originalUrl: "https://example.com/booking", label: "Booking"),
            ],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    let retainedItinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Rain plan", notes: "Keep the other route",
            links: [.init(originalUrl: "https://example.com/rain", label: "Rain route")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    var removedEntries: [UUID] = []
    for source in [items[0], lists[0], lists[0], lists[1]] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: removedItinerary.id, source: source, placement: .last)
        )
        .generatedReferences.first
      else { throw CancellationError() }
      removedEntries.append(identifier)
    }
    var retainedEntries: [UUID] = []
    for source in [items[1], lists[0], items[0]] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: retainedItinerary.id, source: source, placement: .last)
        )
        .generatedReferences.first
      else { throw CancellationError() }
      retainedEntries.append(identifier)
    }
    let removedAppearances: [PlannerAppearance] = [
      .directItineraryItem(itineraryId: removedItinerary.id, entryId: removedEntries[0]),
      .expandedListItem(
        itineraryId: removedItinerary.id, listEntryId: removedEntries[1],
        membershipId: memberships[0]),
      .expandedListItem(
        itineraryId: removedItinerary.id, listEntryId: removedEntries[2],
        membershipId: memberships[1]),
    ]
    let retainedAppearance = PlannerAppearance.expandedListItem(
      itineraryId: retainedItinerary.id, listEntryId: retainedEntries[1],
      membershipId: memberships[0])
    for appearance in removedAppearances + [retainedAppearance] {
      _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    }
    _ = try await save(.setArchive(source: removedItinerary, archived: true))
    let itemSchedule = try #require(
      try await save(
        .createSchedule(
          source: items[0],
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
            planningTimeZone: "Asia/Tokyo"))
      ).generated.first)
    let retainedSchedule = try #require(
      try await save(
        .createSchedule(
          source: retainedItinerary,
          form: .allDay(
            start: .init(year: 2026, month: 10, day: 12), end: .init(year: 2026, month: 10, day: 13)
          ))
      ).generated.first)
    var removedSchedules: [PlannerEntityReference] = []
    for form in [
      PlannerScheduleForm.timed(
        start: Date(timeIntervalSinceReferenceDate: 813_200_400),
        end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo"),
      .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)),
    ] {
      removedSchedules.append(
        try #require(
          try await save(.createSchedule(source: removedItinerary, form: form)).generated.first))
    }
    guard
      case .source(.itinerary(let beforeRemoved)) = await planner.read(
        session: session, request: .source(removedItinerary)),
      case .source(.itinerary(let beforeRetained)) = await planner.read(
        session: session, request: .source(retainedItinerary)),
      case .source(.item(let beforeMuseum)) = await planner.read(
        session: session, request: .source(items[0])),
      case .source(.item(let beforePark)) = await planner.read(
        session: session, request: .source(items[1])),
      case .source(.list(let beforeFood)) = await planner.read(
        session: session, request: .source(lists[0])),
      case .source(.list(let beforeWishlist)) = await planner.read(
        session: session, request: .source(lists[1])),
      case .source(.schedule(let beforeItemSchedule)) = await planner.read(
        session: session, request: .source(itemSchedule)),
      case .source(.schedule(let beforeRetainedSchedule)) = await planner.read(
        session: session, request: .source(retainedSchedule)),
      case .itinerary(let portableRemoved)? = try await recovery().decodedBackup.backup.sources
        .first(
          where: { $0.kind == .itinerary && $0.id == removedItinerary.id })
    else { throw CancellationError() }
    #expect(beforeRemoved.progress.doneCount == 4 && beforeRemoved.progress.totalCount == 6)
    #expect(beforeRetained.progress.doneCount == 3 && beforeRetained.progress.totalCount == 4)
    #expect(beforeFood.progress.doneCount == 2 && beforeFood.progress.totalCount == 2)
    let command = PlannerCommand.deleteSource(source: removedItinerary)
    let prepared = await planner.prepareReview(session: session, command: command)
    guard case .reviewed(let review) = prepared else {
      Issue.record("Core must review the complete Itinerary removal set: \(prepared)")
      return
    }
    #expect(
      review.impact.sourceDeletes == [removedItinerary]
        + removedSchedules.sorted { $0.id.uuidString < $1.id.uuidString })
    #expect(review.targetCount == 13 && !review.globalFlagsChanged)
    #expect(review.impact.referenceRemovals.count == 12)
    #expect(
      beforeRemoved.references.allSatisfy { review.impact.referenceRemovals.contains($0) })
    let operationIdentifier = UUID()
    guard
      case .applied(let applied, .complete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .source(.itinerary(let afterRetained)) = await planner.read(
        session: session, request: .source(retainedItinerary)),
      case .source(.item(let afterMuseum)) = await planner.read(
        session: session, request: .source(items[0])),
      case .source(.item(let afterPark)) = await planner.read(
        session: session, request: .source(items[1])),
      case .source(.list(let afterFood)) = await planner.read(
        session: session, request: .source(lists[0])),
      case .source(.list(let afterWishlist)) = await planner.read(
        session: session, request: .source(lists[1])),
      case .source(.schedule(let afterItemSchedule)) = await planner.read(
        session: session, request: .source(itemSchedule)),
      case .source(.schedule(let afterRetainedSchedule)) = await planner.read(
        session: session, request: .source(retainedSchedule)),
      case .appearance(let afterStandalone) = await planner.read(
        session: session, request: .appearance(standaloneAppearance)),
      case .appearance(let afterExpanded) = await planner.read(
        session: session, request: .appearance(retainedAppearance))
    else { throw CancellationError() }
    #expect(applied.affectedReferences == review.impact.referenceRemovals)
    #expect(afterRetained.content == beforeRetained.content)
    #expect(
      afterRetained.fieldHashes == beforeRetained.fieldHashes
        && afterRetained.updatedAt == beforeRetained.updatedAt)
    #expect(afterRetained.progress.doneCount == 3 && afterRetained.progress.totalCount == 4)
    for (before, after) in [(beforeMuseum, afterMuseum), (beforePark, afterPark)] {
      #expect(
        after.content.title == before.content.title && after.content.notes == before.content.notes)
      #expect(after.content.links == before.content.links)
      #expect(after.content.categoryIds == before.content.categoryIds)
      #expect(after.content.tagIds == before.content.tagIds)
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
      #expect(
        after.state.globalDone == before.state.globalDone
          && after.state.archived == before.state.archived)
    }
    for (before, after) in [(beforeFood, afterFood), (beforeWishlist, afterWishlist)] {
      #expect(after.content == before.content)
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
      #expect(
        after.progress.doneCount == before.progress.doneCount
          && after.progress.totalCount == before.progress.totalCount)
    }
    #expect(afterStandalone.localDone == true && afterStandalone.globalDone == false)
    #expect(afterExpanded.localDone == true && afterExpanded.globalDone == false)
    #expect(afterItemSchedule.content == beforeItemSchedule.content)
    #expect(afterRetainedSchedule.content == beforeRetainedSchedule.content)
    let backup = try await recovery().decodedBackup.backup
    #expect(backup.sources.count == 7 && backup.labelAssociations.count == 6)
    #expect(
      backup.memberships.map(\.id).sorted { $0.uuidString < $1.uuidString }
        == memberships.sorted { $0.uuidString < $1.uuidString })
    #expect(backup.itineraryEntries.sorted { $0.rank < $1.rank }.map(\.id) == retainedEntries)
    #expect(backup.expandedCompletions.count == 1)
    #expect(backup.schedules.count == 2 && backup.deletionMarkers.count == 9)
    #expect(
      backup.deletionMarkers.contains {
        $0.target == .source(removedItinerary, lifetimeId: portableRemoved.lifetimeId)
      })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      throw CancellationError()
    }
    for source in [removedItinerary] + removedSchedules {
      guard
        case .failed(let missing) = await reopened.read(
          session: reopenedSession, request: .source(source))
      else {
        Issue.record("Deleted Itinerary and owned appointments must remain absent.")
        return
      }
      #expect(missing.code == "missingReference")
    }
    for appearance in removedAppearances {
      guard
        case .failed(let missing) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else {
        Issue.record("Deleted Itinerary appearances must remain absent.")
        return
      }
      #expect(missing.code == "missingReference")
    }
    guard
      case .source(.itinerary(let restored)) = await reopened.read(
        session: reopenedSession, request: .source(retainedItinerary)),
      case .applied(let replay, .complete) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(restored.progress.doneCount == 3 && restored.progress.totalCount == 4)
    #expect(replay == applied)
  }
}
