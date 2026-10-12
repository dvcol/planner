import Foundation
import PlannerCore
import Testing

struct NativeImportOmittedOwnerReviewTests {
  @Test(arguments: [PlannerImportMode.skip, .overwrite], [PlannerEntityKind.list, .itinerary])
  func omittedContainerKeepsMembershipsRouteAndCompletionHistory(
    mode: PlannerImportMode, ownerKind: PlannerEntityKind
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
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Current List"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Current route"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    guard case .exported(let graphBytes) = await planner.exportData(session: session),
      case .decoded(let graph) = planner.decodeImport(graphBytes),
      let membership = graph.backup.memberships.first,
      let entry = graph.backup.itineraryEntries.first
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entry.id, membershipId: membership.id)),
        done: true))
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let owner = ownerKind == .list ? list : itinerary
    var object = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    sources.removeAll { $0["id"] as? String == owner.id.uuidString }
    object["sources"] = sources
    let completionContext: [String: Any]
    let expectedPaths: [String]
    let expectedTitle: String
    if ownerKind == .list {
      var memberships = try #require(object["memberships"] as? [[String: Any]])
      memberships[0]["localDone"] = true
      object["memberships"] = memberships
      completionContext = [
        "kind": "listMembership", "membershipId": membership.id.uuidString,
        "membershipLifetimeId": membership.lifetimeId.uuidString,
      ]
      expectedPaths = ["/memberships/0", "/contextAliases/0", "/completionChanges/0"]
      expectedTitle = "Current List"
    } else {
      var expanded = try #require(object["expandedCompletions"] as? [[String: Any]])
      expanded[0]["localDone"] = false
      object["expandedCompletions"] = expanded
      var context = try #require(expanded[0]["context"] as? [String: Any])
      context["kind"] = "expandedListItem"
      completionContext = context
      expectedPaths = [
        "/itineraryEntries/0", "/expandedCompletions/0", "/contextAliases/0",
        "/completionChanges/0",
      ]
      expectedTitle = "Current route"
    }
    object["contextAliases"] = [
      [
        "aliasId": "00000000-0000-4000-8000-000000000871", "context": completionContext,
        "canonicalContext": completionContext, "initialDone": ownerKind == .itinerary,
        "currentChangeId": "00000000-0000-4000-8000-000000000872",
      ]
    ]
    object["completionChanges"] = [
      [
        "id": "00000000-0000-4000-8000-000000000872",
        "aliasId": "00000000-0000-4000-8000-000000000871", "context": completionContext,
        "done": ownerKind == .list, "observedChangeIds": [],
      ]
    ]
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: object))
    guard case .decoded(let incoming) = decoded else {
      Issue.record("Decode the complete omitted-container fixture: \(decoded)")
      return
    }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: mode))
    guard case .reviewed(let review) = response else {
      Issue.record(
        "Keep every omitted container record and history contribution unapplied: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    let skipped = try #require(details.skippedConflicts.first)
    #expect(details.skippedConflicts.count == 1 && skipped.owner.id == owner.id)
    #expect(skipped.reasonCode == "omittedOwner" && skipped.propertyPaths == expectedPaths)
    #expect(skipped.before?.title == expectedTitle && skipped.after?.title == expectedTitle)
    #expect(skipped.before?.associationIds == skipped.after?.associationIds)
    #expect(details.unchanged.count == 2 && details.imports.isEmpty && details.replacements.isEmpty)
    #expect(
      details.referenceChanges.count == 3
        && details.referenceChanges.allSatisfy { $0.change == .retain })
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }

  @Test(arguments: [PlannerImportMode.skip, .overwrite], [PlannerEntityKind.item, .schedule])
  func omittedOwnerNeverRestoresItsDeletedDataWhileIndependentSourcesRemainReviewable(
    mode: PlannerImportMode, deletedKind: PlannerEntityKind
  ) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand, reviewToken: PlannerReviewToken? = nil) async throws
      -> PlannerAppliedResult
    {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command, reviewToken: reviewToken)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Current museum",
            links: [.init(originalUrl: "https://example.com/current")]))
      ).generated.first)
    let schedule = try #require(
      try await save(
        .createSchedule(
          source: item,
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
            planningTimeZone: "Asia/Tokyo"))
      ).generated.first)
    guard case .exported(let olderBackup) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    if deletedKind == .item {
      guard
        case .reviewed(let deletion) = await planner.prepareReview(
          session: session, command: .deleteSource(source: item))
      else { throw CancellationError() }
      _ = try await save(deletion.command, reviewToken: deletion.reviewToken)
    } else {
      _ = try await save(.removeSchedule(scheduleId: schedule.id))
    }
    guard case .exported(let before) = await planner.exportData(session: session),
      case .status(let beforeStatus) = await planner.read(session: session, request: .status),
      case .known(let checkpoint, _, _) = beforeStatus.recovery
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: olderBackup) as? [String: Any])
    object["sources"] = [
      [
        "kind": "tag", "id": "00000000-0000-4000-8000-000000000601",
        "lifetimeId": "00000000-0000-4000-8000-000000000861", "createdAt": 10.25,
        "updatedAt": 20.125,
        "content": ["name": "Independent Tag", "color": NSNull(), "iconName": NSNull()],
        "globalDone": NSNull(), "archived": NSNull(), "contentOrigins": ["name": "independent"],
      ]
    ]
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: mode))
    guard case .reviewed(let review) = response else {
      Issue.record("Skip omitted-owner records without restoring closed identities: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    let skipped = try #require(details.skippedConflicts.first)
    #expect(details.skippedConflicts.count == 1 && skipped.owner.id == item.id)
    #expect(skipped.reasonCode == "omittedOwner")
    #expect(skipped.propertyPaths == ["/ownedLinks/0", "/schedules/0"])
    if deletedKind == .item {
      #expect(skipped.before == nil && skipped.after == nil)
      #expect(details.referenceChanges.isEmpty)
    } else {
      #expect(skipped.before?.title == "Current museum" && skipped.after?.title == "Current museum")
      #expect(skipped.after?.associationIds.contains(schedule.id) == false)
      #expect(
        details.referenceChanges.count == 1 && details.referenceChanges.first?.change == .retain)
    }
    #expect(details.imports.count == 1 && details.imports.first?.after?.title == "Independent Tag")
    #expect(
      details.restorations.isEmpty && details.replacements.isEmpty
        && details.skippedDependents.isEmpty)
    #expect(review.impact.sourceDeletes.isEmpty && review.impact.referenceRemovals.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session),
      case .status(let afterStatus) = await planner.read(session: session, request: .status),
      case .known(let afterCheckpoint, let incomplete, let blocked) = afterStatus.recovery
    else { throw CancellationError() }
    #expect(before == after && checkpoint == afterCheckpoint && incomplete.isEmpty && !blocked)
  }

  @Test(arguments: [PlannerImportMode.skip, .overwrite], [false, true])
  func omittedOwnerKeepsItsWholeCurrentDataAndReportsIncomingOwnedRecordsAsSkipped(
    mode: PlannerImportMode, incomingRecordsChanged: Bool
  ) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
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
            title: "Current museum", notes: "Keep Friday booking",
            links: [.init(originalUrl: "https://example.com/current", label: "Current tickets")],
            categoryIds: [category.id]))
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
      try await save(.createList(content: .init(name: "Keep Plan"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .exported(let before) = await planner.exportData(session: session),
      case .status(let beforeStatus) = await planner.read(session: session, request: .status),
      case .known(let checkpoint, _, _) = beforeStatus.recovery
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    sources.removeAll { $0["id"] as? String == item.id.uuidString }
    sources.append([
      "kind": "tag", "id": "00000000-0000-4000-8000-000000000601",
      "lifetimeId": "00000000-0000-4000-8000-000000000861", "createdAt": 10.25,
      "updatedAt": 20.125,
      "content": ["name": "Independent Tag", "color": NSNull(), "iconName": NSNull()],
      "globalDone": NSNull(), "archived": NSNull(), "contentOrigins": ["name": "independent"],
    ])
    object["sources"] = sources
    var links = try #require(object["ownedLinks"] as? [[String: Any]])
    let linkIdentifierString = try #require(links[0]["id"] as? String)
    let linkIdentifier = try #require(UUID(uuidString: linkIdentifierString))
    let associations = try #require(object["labelAssociations"] as? [[String: Any]])
    let associationIdentifierString = try #require(associations[0]["id"] as? String)
    let associationIdentifier = try #require(UUID(uuidString: associationIdentifierString))
    if incomingRecordsChanged {
      links[0]["originalUrl"] = "https://example.com/incoming"
      links[0]["label"] = "Incoming tickets"
      object["ownedLinks"] = links
      var schedules = try #require(object["schedules"] as? [[String: Any]])
      var form = try #require(schedules[0]["form"] as? [String: Any])
      form["start"] = 813_204_000.0
      schedules[0]["form"] = form
      object["schedules"] = schedules
    }
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: mode))
    guard case .reviewed(let review) = response else {
      Issue.record("Q73 preserves the omitted owner while reviewing independent data: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    let skipped = try #require(details.skippedConflicts.first)
    #expect(details.skippedConflicts.count == 1 && skipped.owner.id == item.id)
    #expect(skipped.reasonCode == "omittedOwner")
    #expect(skipped.propertyPaths == ["/labelAssociations/0", "/ownedLinks/0", "/schedules/0"])
    #expect(skipped.before?.title == "Current museum" && skipped.after?.title == "Current museum")
    let retainedIdentifiers = [associationIdentifier, linkIdentifier, schedule.id].sorted {
      $0.uuidString < $1.uuidString
    }
    #expect(skipped.before?.associationIds == retainedIdentifiers)
    #expect(skipped.after?.associationIds == retainedIdentifiers)
    #expect(details.imports.count == 1 && details.imports.first?.after?.title == "Independent Tag")
    #expect(
      details.unchanged.count == 2
        && Set(details.unchanged.map { $0.owner.id }) == [category.id, list.id])
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    #expect(details.skippedDependents.isEmpty && details.incomingDeletions.isEmpty)
    #expect(
      details.referenceChanges.count == 4
        && details.referenceChanges.allSatisfy { $0.change == .retain })
    #expect(review.impact.sourceDeletes.isEmpty && review.impact.referenceRemovals.isEmpty)
    #expect(!review.globalFlagsChanged && review.targets.contains(.source(item)))
    guard case .exported(let after) = await planner.exportData(session: session),
      case .status(let afterStatus) = await planner.read(session: session, request: .status),
      case .known(let afterCheckpoint, let incomplete, let blocked) = afterStatus.recovery
    else { throw CancellationError() }
    #expect(before == after && afterCheckpoint == checkpoint && incomplete.isEmpty && !blocked)
  }
}
