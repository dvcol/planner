import Foundation
import PlannerCore
import Testing

struct NativeImportOverwriteDeletionReviewTests {
  enum ReferenceTargetCase: CaseIterable {
    case membership, itineraryEntry, ownedLink, labelAssociation, expandedCompletion, expandedTodo
  }

  @Test(arguments: ReferenceTargetCase.allCases)
  func overwriteRemovesOnlyTheLiveReferenceAndItsDependentContexts(targetCase: ReferenceTargetCase)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let emptyBackup) = await planner.exportData(session: session)
    else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Culture"))).generated.first)
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Current Item",
            links: [.init(originalUrl: "https://example.com/booking")], categoryIds: [category.id]))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Current List"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Current Itinerary"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    guard case .exported(let beforeCompletion) = await planner.exportData(session: session),
      case .decoded(let graph) = planner.decodeImport(beforeCompletion),
      let membership = graph.backup.memberships.first,
      let entry = graph.backup.itineraryEntries.first
    else { throw CancellationError() }
    if targetCase != .expandedTodo {
      _ = try await save(
        .setCompletion(
          scope: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id, listEntryId: entry.id, membershipId: membership.id)),
          done: true))
    }
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let current = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var object = try #require(JSONSerialization.jsonObject(with: emptyBackup) as? [String: Any])
    let target: [String: Any]
    let expectedOwner: PlannerEntityReference
    let expectedTitle: String
    switch targetCase {
    case .expandedCompletion, .expandedTodo:
      target = [
        "kind": "expandedCompletion",
        "context": [
          "listEntryId": entry.id.uuidString, "listEntryLifetimeId": entry.lifetimeId.uuidString,
          "membershipId": membership.id.uuidString,
          "membershipLifetimeId": membership.lifetimeId.uuidString,
        ],
      ]
      expectedOwner = itinerary
      expectedTitle = "Current Itinerary"
    case .membership, .itineraryEntry, .ownedLink, .labelAssociation:
      let group: String
      let kind: String
      switch targetCase {
      case .membership:
        group = "memberships"
        kind = "membership"
        expectedOwner = list
        expectedTitle = "Current List"
      case .itineraryEntry:
        group = "itineraryEntries"
        kind = "itineraryEntry"
        expectedOwner = itinerary
        expectedTitle = "Current Itinerary"
      case .ownedLink:
        group = "ownedLinks"
        kind = "ownedLink"
        expectedOwner = item
        expectedTitle = "Current Item"
      case .labelAssociation:
        group = "labelAssociations"
        kind = "labelAssociation"
        expectedOwner = item
        expectedTitle = "Current Item"
      case .expandedCompletion, .expandedTodo: throw CancellationError()
      }
      let reference = try #require((current[group] as? [[String: Any]])?.first)
      target = [
        "kind": kind, "id": try #require(reference["id"]),
        "lifetimeId": try #require(reference["lifetimeId"]),
      ]
    }
    object["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000893",
        "operationId": "00000000-0000-4000-8000-000000000993",
        "target": target, "closedFamilyId": NSNull(),
      ]
    ]
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: .overwrite))
    guard case .reviewed(let review) = response else {
      Issue.record("Review the selected reference closure without deleting its owner: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.skippedConflicts.isEmpty && details.skippedDependents.isEmpty)
    #expect(details.incomingDeletions.count == 1)
    #expect(details.incomingDeletions.first?.owner?.id == expectedOwner.id)
    #expect(details.incomingDeletions.first?.before?.title == expectedTitle)
    #expect(details.incomingDeletions.first?.after?.title == expectedTitle)
    #expect(details.incomingDeletions.first?.propertyPaths == ["/deletionMarkers/0"])
    #expect(review.impact.sourceDeletes.isEmpty && !review.globalFlagsChanged)
    #expect(review.targets.contains(.source(expectedOwner)))
    let expandedReference = PlannerReferenceRead.expandedCompletion(
      itineraryId: itinerary.id, listEntryId: entry.id, membershipId: membership.id)
    let expectedRemovals: [PlannerReferenceRead]
    switch targetCase {
    case .membership:
      expectedRemovals = [
        .membership(id: membership.id, list: list, item: item), expandedReference,
      ]
    case .itineraryEntry:
      expectedRemovals = [
        .itineraryEntry(id: entry.id, itinerary: itinerary, source: list), expandedReference,
      ]
    case .ownedLink:
      let link = try #require((current["ownedLinks"] as? [[String: Any]])?.first)
      let identifierString = try #require(link["id"] as? String)
      let identifier = try #require(UUID(uuidString: identifierString))
      expectedRemovals = [.ownedLink(id: identifier, owner: item)]
    case .labelAssociation:
      let association = try #require((current["labelAssociations"] as? [[String: Any]])?.first)
      let identifierString = try #require(association["id"] as? String)
      let identifier = try #require(UUID(uuidString: identifierString))
      expectedRemovals = [.labelAssociation(id: identifier, owner: item, label: category)]
    case .expandedCompletion, .expandedTodo:
      expectedRemovals = [expandedReference]
    }
    #expect(review.impact.referenceRemovals == expectedRemovals)
    #expect(details.referenceChanges.count == expectedRemovals.count)
    #expect(details.referenceChanges.allSatisfy { $0.change == .remove })
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }
  @Test(arguments: [PlannerEntityKind.list, .itinerary, .category, .tag])
  func overwriteIncomingNamedSourceClosurePreservesSharedSources(sourceKind: PlannerEntityKind)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let emptyBackup) = await planner.exportData(session: session)
    else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Culture"))).generated.first)
    let tag = try #require(
      try await save(.createTag(content: .init(name: "Rainy day"))).generated.first)
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Museum", links: [.init(originalUrl: "https://example.com/item")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(
            title: "Weekend", links: [.init(originalUrl: "https://example.com/route")],
            categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    for source in [item, list] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    guard case .exported(let beforeCompletion) = await planner.exportData(session: session),
      case .decoded(let graph) = planner.decodeImport(beforeCompletion),
      let membership = graph.backup.memberships.first,
      let entry = graph.backup.itineraryEntries.first(where: { $0.source == list })
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entry.id, membershipId: membership.id)),
        done: true))
    var schedules: [PlannerEntityReference] = []
    for source in [item, itinerary] {
      schedules.append(
        try #require(
          try await save(
            .createSchedule(
              source: source,
              form: .timed(
                start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
                planningTimeZone: "Asia/Tokyo"))
          ).generated.first))
    }
    let deleted = try #require([list, itinerary, category, tag].first { $0.kind == sourceKind })
    guard case .exported(let before) = await planner.exportData(session: session),
      case .reviewed(let nativeDelete) = await planner.prepareReview(
        session: session, command: .deleteSource(source: deleted))
    else { throw CancellationError() }
    let currentObject = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let sourceObject = try #require(
      (currentObject["sources"] as? [[String: Any]])?.first {
        $0["id"] as? String == deleted.id.uuidString
      })
    var object = try #require(JSONSerialization.jsonObject(with: emptyBackup) as? [String: Any])
    object["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000893",
        "operationId": "00000000-0000-4000-8000-000000000993",
        "target": [
          "kind": "source",
          "source": [
            "kind": deleted.kind.rawValue, "id": deleted.id.uuidString,
            "lifetimeId": try #require(sourceObject["lifetimeId"]),
          ],
        ], "closedFamilyId": NSNull(),
      ]
    ]
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: .overwrite))
    guard case .reviewed(let review) = response else {
      Issue.record("Review the complete named-source deletion closure: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(
      details.incomingDeletions.count == 1
        && details.incomingDeletions.first?.owner?.id == deleted.id)
    #expect(details.skippedConflicts.isEmpty && details.skippedDependents.isEmpty)
    #expect(!review.globalFlagsChanged)
    #expect(review.impact.sourceDeletes == nativeDelete.impact.sourceDeletes)
    #expect(review.impact.referenceRemovals == nativeDelete.impact.referenceRemovals)
    let expectedRemovalCount: Int
    switch sourceKind {
    case .list: expectedRemovalCount = 3
    case .itinerary: expectedRemovalCount = 7
    case .category, .tag: expectedRemovalCount = 2
    default: throw CancellationError()
    }
    #expect(review.impact.referenceRemovals.count == expectedRemovalCount)
    #expect(details.referenceChanges.count == expectedRemovalCount)
    #expect(details.referenceChanges.allSatisfy { $0.change == .remove })
    #expect(
      !review.impact.sourceDeletes.contains(item)
        && !review.impact.sourceDeletes.contains(schedules[0]))
    if sourceKind == .itinerary {
      #expect(review.impact.sourceDeletes == [itinerary, schedules[1]])
    } else {
      #expect(review.impact.sourceDeletes == [deleted])
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }

  enum OwnedTargetCase: CaseIterable {
    case item, schedule, repeatedItem, repeatedSchedule, itemAndSchedule, representedSchedule
  }

  @Test(arguments: OwnedTargetCase.allCases)
  func overwriteIncomingItemOrScheduleClosureReviewsOnlyTheSelectedRemoval(
    targetCase: OwnedTargetCase
  )
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let emptyBackup) = await planner.exportData(session: session)
    else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Current museum",
            links: [.init(originalUrl: "https://example.com/booking")]))
      ).generated.first)
    let schedule = try #require(
      try await save(
        .createSchedule(
          source: item,
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
            planningTimeZone: "Asia/Tokyo"))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Keep List"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Keep itinerary"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before),
      let museum = current.backup.items.first,
      case .reviewed(let nativeDelete) = await planner.prepareReview(
        session: session, command: .deleteSource(source: item)),
      case .listedNamespaces(let beforeNamespaces) = await planner.inspectRecovery(
        request: .namespaces), let beforeNamespace = beforeNamespaces.first,
      let beforeCheckpoint = beforeNamespace.acknowledgedSnapshot?.checkpointGeneration
    else { throw CancellationError() }
    let deletesItem =
      targetCase == .item || targetCase == .repeatedItem || targetCase == .itemAndSchedule
    let target = deletesItem ? item : schedule
    let targetLifetime: UUID
    if deletesItem {
      targetLifetime = museum.lifetimeId
    } else {
      targetLifetime = try #require(current.backup.schedules.first).lifetimeId
    }
    var object = try #require(JSONSerialization.jsonObject(with: emptyBackup) as? [String: Any])
    object["sources"] = [
      [
        "kind": "tag", "id": "00000000-0000-4000-8000-000000000601",
        "lifetimeId": "00000000-0000-4000-8000-000000000861", "createdAt": 10.25,
        "updatedAt": 20.125,
        "content": ["name": "Independent Tag", "color": NSNull(), "iconName": NSNull()],
        "globalDone": NSNull(), "archived": NSNull(), "contentOrigins": ["name": "independent"],
      ]
    ]
    if targetCase == .representedSchedule {
      let currentObject = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
      var currentSource = try #require(
        (currentObject["sources"] as? [[String: Any]])?.first {
          $0["id"] as? String == item.id.uuidString
        })
      var content = try #require(currentSource["content"] as? [String: Any])
      content["title"] = "Incoming museum"
      currentSource["content"] = content
      var sources = try #require(object["sources"] as? [[String: Any]])
      sources.append(currentSource)
      object["sources"] = sources
      object["ownedLinks"] = currentObject["ownedLinks"]
    }
    object["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000893",
        "operationId": "00000000-0000-4000-8000-000000000993",
        "target": [
          "kind": "source",
          "source": [
            "kind": target.kind.rawValue, "id": target.id.uuidString,
            "lifetimeId": targetLifetime.uuidString,
          ],
        ], "closedFamilyId": NSNull(),
      ]
    ]
    if targetCase == .repeatedItem || targetCase == .repeatedSchedule
      || targetCase == .itemAndSchedule
    {
      var markers = try #require(object["deletionMarkers"] as? [[String: Any]])
      var secondMarker = try #require(markers.first)
      secondMarker["deletionId"] = "00000000-0000-4000-8000-000000000894"
      if targetCase == .itemAndSchedule {
        secondMarker["target"] = [
          "kind": "source",
          "source": [
            "kind": "schedule", "id": schedule.id.uuidString,
            "lifetimeId": try #require(current.backup.schedules.first).lifetimeId.uuidString,
          ],
        ]
      }
      markers.append(secondMarker)
      object["deletionMarkers"] = markers
    }
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: .overwrite))
    guard case .reviewed(let review) = response else {
      Issue.record("Review the complete selected deletion closure before Overwrite: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.count == 1 && details.imports.first?.after?.title == "Independent Tag")
    #expect(details.incomingDeletions.count == (targetCase == .itemAndSchedule ? 2 : 1))
    #expect(details.incomingDeletions.allSatisfy { $0.owner?.id == item.id })
    #expect(details.incomingDeletions.first?.before?.title == "Current museum")
    let expectedPaths: [String]
    if targetCase == .repeatedItem || targetCase == .repeatedSchedule {
      expectedPaths = ["/deletionMarkers/0", "/deletionMarkers/1"]
    } else {
      expectedPaths = ["/deletionMarkers/0"]
    }
    #expect(details.incomingDeletions.first?.propertyPaths == expectedPaths)
    #expect(
      details.skippedConflicts.isEmpty && details.skippedDependents.isEmpty
        && details.restorations.isEmpty)
    if deletesItem {
      #expect(details.incomingDeletions.allSatisfy { $0.after == nil })
      #expect(Set(review.impact.sourceDeletes) == [item, schedule])
      #expect(review.impact.sourceDeletes.count == 2)
      #expect(review.impact.referenceRemovals.count == 4)
      #expect(Set(review.impact.sourceDeletes) == Set(nativeDelete.impact.sourceDeletes))
      #expect(review.impact.referenceRemovals == nativeDelete.impact.referenceRemovals)
      #expect(details.referenceChanges.count == 4)
    } else {
      if targetCase == .representedSchedule {
        #expect(details.incomingDeletions.first?.after?.title == "Incoming museum")
        #expect(
          details.incomingDeletions.first?.after?.changedFieldNames == ["schedules", "title"])
      } else {
        #expect(details.incomingDeletions.first?.after?.title == "Current museum")
        #expect(details.incomingDeletions.first?.after?.changedFieldNames == ["schedules"])
      }
      #expect(details.incomingDeletions.first?.before?.associationIds.contains(schedule.id) == true)
      #expect(details.incomingDeletions.first?.after?.associationIds.contains(schedule.id) == false)
      #expect(review.impact.sourceDeletes == [schedule])
      #expect(review.impact.referenceRemovals == [.schedule(id: schedule.id, source: item)])
      #expect(details.referenceChanges.filter { $0.change == .remove }.count == 1)
      if targetCase == .representedSchedule {
        #expect(details.replacements.count == 1 && details.replacements.first?.owner.id == item.id)
        #expect(details.referenceChanges.count == 2)
      }
    }
    if targetCase != .representedSchedule {
      #expect(details.referenceChanges.allSatisfy { $0.change == .remove })
    }
    #expect(
      !review.impact.sourceDeletes.contains(list)
        && !review.impact.sourceDeletes.contains(itinerary))
    guard case .exported(let after) = await planner.exportData(session: session),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces), let afterNamespace = afterNamespaces.first
    else {
      throw CancellationError()
    }
    #expect(before == after)
    #expect(beforeNamespace.namespaceId == afterNamespace.namespaceId)
    #expect(afterNamespace.acknowledgedSnapshot?.checkpointGeneration == beforeCheckpoint)
  }
}
