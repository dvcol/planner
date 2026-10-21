import Foundation
import PlannerCore
import Testing

struct NativeImportConflictReviewTests {
  @Test(arguments: [PlannerImportMode.skip, .overwrite])
  func globalCompletionImpactDescribesOnlyTheSelectedModeChanges(mode: PlannerImportMode)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    _ = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    var object = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    sources[0]["globalDone"] = true
    object["sources"] = sources
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: mode))
    else { throw CancellationError() }
    #expect(review.globalFlagsChanged == (mode == .overwrite))
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }

  @Test func incomingCompletionHistoryBelongsToItsWholeOwnerReview() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let item = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let list = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Weekend")))
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let membership = try #require((object["memberships"] as? [[String: Any]])?.first)
    let context: [String: Any] = [
      "kind": "listMembership", "membershipId": membership["id"]!,
      "membershipLifetimeId": membership["lifetimeId"]!,
    ]
    object["contextAliases"] = [
      [
        "aliasId": "00000000-0000-4000-8000-000000000871", "context": context,
        "canonicalContext": context, "initialDone": false, "currentChangeId": NSNull(),
      ]
    ]
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: decoded))
    guard case .reviewed(let review) = response else {
      Issue.record("Review portable completion history under its complete List owner.")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.unchanged.count == 1 && details.unchanged.first?.owner.id == item.id)
    #expect(
      details.skippedConflicts.count == 1 && details.skippedConflicts.first?.owner.id == list.id)
    #expect(details.skippedConflicts.first?.before?.changedFieldNames == ["contextAliases"])
    #expect(details.skippedConflicts.first?.propertyPaths.contains("/contextAliases/0") == true)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }

  @Test(arguments: [PlannerImportMode.skip, .overwrite])
  func reviewKeepsOrReplacesWholeOwnersAndImportsIndependentData(mode: PlannerImportMode)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let item = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let list = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Weekend")))
    let omitted = try await createSource(
      planner, session: session, command: .createTag(content: .init(name: "Keep me")))
    guard
      case .applied(let added, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipId, _, _)? = added.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: membershipId)),
            done: true))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    sources.removeAll { $0["id"] as? String == omitted.id.uuidString }
    let itemIndex = try #require(sources.firstIndex { $0["id"] as? String == item.id.uuidString })
    let listSource = try #require(sources.first { $0["id"] as? String == list.id.uuidString })
    var content = try #require(sources[itemIndex]["content"] as? [String: Any])
    content["title"] = "Backup museum"
    sources[itemIndex]["content"] = content
    sources.append([
      "kind": "item", "id": "00000000-0000-4000-8000-000000000103",
      "lifetimeId": "00000000-0000-4000-8000-000000000813",
      "createdAt": 10.25, "updatedAt": 20.125,
      "content": [
        "title": "Travel Adapter", "subtitle": NSNull(), "notes": NSNull(),
        "location": NSNull(), "estimate": NSNull(),
      ],
      "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
    ])
    object["sources"] = sources
    object["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000404",
        "lifetimeId": "00000000-0000-4000-8000-000000000404",
        "list": ["kind": "list", "id": list.id.uuidString, "lifetimeId": listSource["lifetimeId"]],
        "item": [
          "kind": "item", "id": "00000000-0000-4000-8000-000000000103",
          "lifetimeId": "00000000-0000-4000-8000-000000000813",
        ],
        "rank": "1024", "localDone": false,
      ]
    ]
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: decoded, mode: mode))
    guard case .reviewed(let review) = response else {
      Issue.record(
        "Review complete current owners in \(mode) without applying changes: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.count == 1 && details.imports.first?.after?.title == "Travel Adapter")
    #expect(details.unchanged.isEmpty && details.skippedDependents.isEmpty)
    #expect(details.restorations.isEmpty && details.incomingDeletions.isEmpty)
    let conflicts = mode == .skip ? details.skippedConflicts : details.replacements
    #expect(conflicts.count == 2)
    let itemConflict = try #require(conflicts.first { $0.owner.id == item.id })
    let listConflict = try #require(conflicts.first { $0.owner.id == list.id })
    #expect(itemConflict.before?.title == "Museum")
    #expect(itemConflict.after?.title == (mode == .skip ? "Museum" : "Backup museum"))
    #expect(itemConflict.before?.changedFieldNames == ["title"])
    #expect(listConflict.before?.changedFieldNames == ["memberships"])
    #expect(listConflict.before?.associationIds == [membershipId])
    if mode == .skip {
      #expect(details.replacements.isEmpty)
      #expect(conflicts.allSatisfy { $0.reasonCode == "matchingRecordConflict" })
      #expect(listConflict.after?.associationIds == [membershipId])
      #expect(
        details.referenceChanges.count == 1 && details.referenceChanges.first?.change == .retain)
    } else {
      #expect(details.skippedConflicts.isEmpty && conflicts.allSatisfy { $0.reasonCode == nil })
      #expect(
        listConflict.after?.associationIds == [
          UUID(uuidString: "00000000-0000-4000-8000-000000000404")!
        ])
      #expect(details.referenceChanges.map(\.change).contains(.remove))
      #expect(details.referenceChanges.map(\.change).contains(.add))
      #expect(details.referenceChanges.count == 2)
    }
    #expect(!review.targets.contains(.source(omitted)))
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(after == before)
  }

  private func createSource(
    _ planner: Planner, session: PlannerDatasetSession, command: PlannerCommand
  ) async throws -> PlannerEntityReference {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome,
      let source = result.generated.first
    else { throw CancellationError() }
    return source
  }
}
