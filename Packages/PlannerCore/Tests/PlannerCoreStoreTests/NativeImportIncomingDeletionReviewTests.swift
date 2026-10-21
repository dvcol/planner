import Foundation
import PlannerCore
import Testing

struct NativeImportIncomingDeletionReviewTests {
  enum LiveTargetCase: CaseIterable { case item, schedule, repeatedItem, representedSchedule }
  enum ReferenceTargetCase: CaseIterable {
    case membership, itineraryEntry, ownedLink, labelAssociation, expandedCompletion, expandedTodo
  }

  @Test(arguments: ReferenceTargetCase.allCases)
  func skipRetainsTheRealOwnerOfLiveReferenceDeletionTargets(targetCase: ReferenceTargetCase)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
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
      session: session, command: .applyImport(backup: incoming))
    guard case .reviewed(let review) = response else {
      Issue.record("Review a live reference deletion conflict: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(
      details.skippedConflicts.count == 1
        && details.skippedConflicts.first?.owner.id == expectedOwner.id)
    #expect(
      details.skippedConflicts.first?.before?.title == expectedTitle
        && details.skippedConflicts.first?.after?.title == expectedTitle)
    #expect(
      details.incomingDeletions.isEmpty
        && details.referenceChanges.allSatisfy { $0.change == .retain })
    #expect(!details.referenceChanges.isEmpty && review.impact.referenceRemovals.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }
  enum NamedSourceCase: CaseIterable {
    case list, itinerary, category, tag

    var creation: PlannerCommand {
      switch self {
      case .list: .createList(content: .init(name: "Current named source"))
      case .itinerary: .createItinerary(content: .init(title: "Current named source"))
      case .category: .createCategory(content: .init(name: "Current named source"))
      case .tag: .createTag(content: .init(name: "Current named source"))
      }
    }
  }

  @Test(arguments: NamedSourceCase.allCases)
  func skipRetainsLiveNamedSourcesAgainstIncomingDeletion(sourceCase: NamedSourceCase) async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let emptyBackup) = await planner.exportData(session: session),
      case .applied(let created, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: sourceCase.creation)
      ).outcome,
      let source = created.generated.first,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let currentObject = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let currentSource = try #require((currentObject["sources"] as? [[String: Any]])?.first)
    let lifetimeId = try #require(currentSource["lifetimeId"] as? String)
    var object = try #require(JSONSerialization.jsonObject(with: emptyBackup) as? [String: Any])
    object["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000893",
        "operationId": "00000000-0000-4000-8000-000000000993",
        "target": [
          "kind": "source",
          "source": [
            "kind": source.kind.rawValue, "id": source.id.uuidString, "lifetimeId": lifetimeId,
          ],
        ], "closedFamilyId": NSNull(),
      ]
    ]
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: incoming))
    else { throw CancellationError() }
    let details = try #require(review.impact.importDetails)
    #expect(
      details.skippedConflicts.count == 1 && details.skippedConflicts.first?.owner.id == source.id)
    #expect(
      details.skippedConflicts.first?.before?.title == "Current named source"
        && details.skippedConflicts.first?.after?.title == "Current named source")
    #expect(details.skippedConflicts.first?.reasonCode == "matchingRecordConflict")
    #expect(
      details.incomingDeletions.isEmpty && details.imports.isEmpty
        && details.referenceChanges.isEmpty)
    #expect(review.targets == [.source(source)] && review.impact.sourceDeletes.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }

  @Test(arguments: LiveTargetCase.allCases)
  func skipRetainsLiveOwnerAndItsReferencesWhileReviewingIndependentClosureMetadata(
    targetCase: LiveTargetCase
  )
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let emptyBackup) = await planner.exportData(session: session),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: "Current museum", notes: "Keep booking",
              links: [.init(originalUrl: "https://example.com/booking", label: "Tickets")])))
      )
      .outcome, let item = created.generated.first,
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
              planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before),
      let museum = current.backup.items.first
    else { throw CancellationError() }
    let schedule = try #require(current.backup.schedules.first)
    let targetSource: PlannerEntityReference
    let targetLifetime: UUID
    if targetCase == .schedule || targetCase == .representedSchedule {
      targetSource = .init(kind: .schedule, id: schedule.id)
      targetLifetime = schedule.lifetimeId
    } else {
      targetSource = item
      targetLifetime = museum.lifetimeId
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
      let currentSource = try #require((currentObject["sources"] as? [[String: Any]])?.first)
      var sources = try #require(object["sources"] as? [[String: Any]])
      sources.append(currentSource)
      object["sources"] = sources
    }
    object["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000893",
        "operationId": "00000000-0000-4000-8000-000000000993",
        "target": [
          "kind": "source",
          "source": [
            "kind": targetSource.kind.rawValue, "id": targetSource.id.uuidString,
            "lifetimeId": targetLifetime.uuidString,
          ],
        ], "closedFamilyId": NSNull(),
      ],
      [
        "deletionId": "00000000-0000-4000-8000-000000000894",
        "operationId": "00000000-0000-4000-8000-000000000994",
        "target": [
          "kind": "source",
          "source": [
            "kind": "tag", "id": "00000000-0000-4000-8000-000000000699",
            "lifetimeId": "00000000-0000-4000-8000-000000000899",
          ],
        ], "closedFamilyId": NSNull(),
      ],
    ]
    if targetCase == .repeatedItem {
      var markers = try #require(object["deletionMarkers"] as? [[String: Any]])
      var repeated = markers[0]
      repeated["deletionId"] = "00000000-0000-4000-8000-000000000895"
      repeated["operationId"] = "00000000-0000-4000-8000-000000000995"
      markers.append(repeated)
      object["deletionMarkers"] = markers
    }
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming))
    guard case .reviewed(let review) = response else {
      Issue.record("Skip the incoming closure of live X and review independent data: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.count == 1 && details.imports.first?.after?.title == "Independent Tag")
    #expect(
      details.skippedConflicts.count == 1 && details.skippedConflicts.first?.owner.id == item.id)
    let conflict = try #require(details.skippedConflicts.first)
    let expectedPaths: [String]
    switch targetCase {
    case .repeatedItem: expectedPaths = ["/deletionMarkers/0", "/deletionMarkers/2"]
    case .representedSchedule: expectedPaths = ["/sources/1", "/deletionMarkers/0"]
    case .item, .schedule: expectedPaths = ["/deletionMarkers/0"]
    }
    #expect(
      conflict.reasonCode == "matchingRecordConflict"
        && conflict.propertyPaths == expectedPaths)
    #expect(conflict.before?.title == "Current museum" && conflict.after?.title == "Current museum")
    #expect(
      conflict.before?.associationIds.count == 2
        && conflict.after?.associationIds == conflict.before?.associationIds)
    if targetCase == .representedSchedule {
      #expect(conflict.before?.changedFieldNames == ["ownedLinks", "schedules"])
      #expect(conflict.after?.changedFieldNames == ["ownedLinks", "schedules"])
    } else {
      #expect(
        conflict.before?.changedFieldNames.isEmpty == true
          && conflict.after?.changedFieldNames.isEmpty == true)
    }
    #expect(
      details.incomingDeletions.count == 1
        && details.incomingDeletions.first?.owner?.id.uuidString.hasSuffix("699") == true)
    #expect(details.incomingDeletions.first?.propertyPaths == ["/deletionMarkers/1"])
    #expect(
      details.referenceChanges.count == 2
        && details.referenceChanges.allSatisfy { $0.change == .retain })
    #expect(
      details.skippedDependents.isEmpty && details.unchanged.isEmpty && details.replacements.isEmpty
        && details.restorations.isEmpty)
    #expect(review.targets.contains(.source(item)))
    #expect(
      review.impact.sourceDeletes.isEmpty && review.impact.referenceRemovals.isEmpty
        && !review.globalFlagsChanged)
    guard case .exported(let after) = await planner.exportData(session: session),
      case .status(let status) = await planner.read(session: session, request: .status),
      case .known(let afterCheckpoint, let incomplete, let blocked) = status.recovery
    else { throw CancellationError() }
    #expect(before == after && afterCheckpoint == checkpoint && incomplete.isEmpty && !blocked)
  }
}
