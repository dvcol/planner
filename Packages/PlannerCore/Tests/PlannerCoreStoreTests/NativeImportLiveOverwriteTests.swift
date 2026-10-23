import Foundation
import PlannerCore
import Testing

struct NativeImportLiveOverwriteTests {
  @Test func olderOwnedLinksAndSchedulesNeedFreshRestorationAuthorization() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand, reviewToken: PlannerReviewToken? = nil) async throws
      -> PlannerAppliedResult
    {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command, reviewToken: reviewToken))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("Save the owned-reference workflow: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Original notes",
            links: [.init(originalUrl: "https://example.com/museum", label: "Guide")]))
      ).generated.first)
    _ = try await save(
      .createSchedule(
        source: item,
        form: .timed(
          start: Date(timeIntervalSinceReferenceDate: 813_200_400.125), end: nil,
          planningTimeZone: "Asia/Tokyo")))
    guard case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: item))
    else { throw CancellationError() }
    _ = try await save(deletion.command, reviewToken: deletion.reviewToken)
    var sourceOnlyObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    sourceOnlyObject["ownedLinks"] = []
    sourceOnlyObject["schedules"] = []
    guard
      case .decoded(let sourceOnly) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: sourceOnlyObject)),
      case .reviewed(let restoration) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: sourceOnly, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    _ = try await save(restoration.command, reviewToken: restoration.reviewToken)
    guard
      case .source(.item(let currentRead)) = await planner.read(
        session: session, request: .source(item))
    else { throw CancellationError() }
    _ = try await save(
      .editItem(
        sourceId: item.id, changes: .init(title: .set("Current museum")),
        expectedFieldHashes: [.title: try #require(currentRead.fieldHashes[.title])]))
    guard case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before),
      let currentItem = current.backup.items.first,
      let oldLink = original.backup.ownedLinks.first,
      let oldSchedule = original.backup.schedules.first,
      case .reviewed(let ordinary) = await planner.prepareReview(
        session: session, command: .applyImport(backup: original, mode: .overwrite))
    else { throw CancellationError() }
    let details = try #require(ordinary.impact.importDetails)
    #expect(details.restorations.isEmpty)
    #expect(details.replacements.map(\.owner.lifetimeId) == [currentItem.lifetimeId])
    #expect(
      Set(details.referenceChanges.filter { $0.change == .restore }.map(\.reference)) == [
        .ownedLink(id: oldLink.id, owner: item), .schedule(id: oldSchedule.id, source: item),
      ])
    let deniedOperationIdentifier = UUID()
    guard
      case .rejected = await planner.execute(
        .init(
          operationId: deniedOperationIdentifier, session: session, command: ordinary.command,
          reviewToken: ordinary.reviewToken)
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: deniedOperationIdentifier),
      case .rejected(let changedAuthorization) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true),
          reviewToken: ordinary.reviewToken)
      ).outcome,
      case .exported(let afterDenied) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(changedAuthorization.code == "staleReview")
    #expect(afterDenied == before)
    guard
      case .reviewed(let authorized) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: authorized.command,
        reviewToken: authorized.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let restored) = planner.decodeImport(after),
      let link = restored.backup.ownedLinks.first,
      let schedule = restored.backup.schedules.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Authorized references must restore onto the retained live owner: \(response)")
      return
    }
    #expect(link.id == oldLink.id && link.lifetimeId != oldLink.lifetimeId)
    #expect(schedule.id == oldSchedule.id && schedule.lifetimeId != oldSchedule.lifetimeId)
    #expect(link.owner.lifetimeId == currentItem.lifetimeId)
    #expect(schedule.sourceLifetimeId == currentItem.lifetimeId)
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let originalObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    var expectedSources = try #require(originalObject["sources"] as? [[String: Any]])
    expectedSources[0]["lifetimeId"] = currentItem.lifetimeId.uuidString
    expected["sources"] = expectedSources
    var expectedLinks = try #require(originalObject["ownedLinks"] as? [[String: Any]])
    expectedLinks[0]["lifetimeId"] = link.lifetimeId.uuidString
    var expectedLinkOwner = try #require(expectedLinks[0]["owner"] as? [String: Any])
    expectedLinkOwner["lifetimeId"] = currentItem.lifetimeId.uuidString
    expectedLinks[0]["owner"] = expectedLinkOwner
    expected["ownedLinks"] = expectedLinks
    var expectedSchedules = try #require(originalObject["schedules"] as? [[String: Any]])
    expectedSchedules[0]["lifetimeId"] = schedule.lifetimeId.uuidString
    var expectedScheduleOwner = try #require(expectedSchedules[0]["source"] as? [String: Any])
    expectedScheduleOwner["lifetimeId"] = currentItem.lifetimeId.uuidString
    expectedSchedules[0]["source"] = expectedScheduleOwner
    expected["schedules"] = expectedSchedules
    let referenceFamilies = restored.backup.restorationFamilies.filter {
      $0.predecessor.kind == .ownedLink || $0.predecessor.kind == .schedule
    }
    #expect(referenceFamilies.count == 2)
    for family in referenceFamilies {
      #expect(family.candidates.count == 1)
      let candidate = try #require(family.candidates.first)
      #expect(candidate.operationId == operationIdentifier)
      if family.predecessor.kind == .ownedLink {
        #expect(
          family.predecessor.id == oldLink.id && family.predecessor.lifetimeId == oldLink.lifetimeId
        )
        #expect(candidate.lifetimeId == link.lifetimeId)
      } else {
        #expect(
          family.predecessor.id == oldSchedule.id
            && family.predecessor.lifetimeId == oldSchedule.lifetimeId)
        #expect(candidate.lifetimeId == schedule.lifetimeId)
      }
    }
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let originalFamilies = try #require(expected["restorationFamilies"] as? [[String: Any]])
    let actualFamilies = try #require(actual["restorationFamilies"] as? [[String: Any]])
    #expect(
      originalFamilies.allSatisfy { originalFamily in
        actualFamilies.contains { NSDictionary(dictionary: $0).isEqual(to: originalFamily) }
      })
    expected["restorationFamilies"] = actualFamilies
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    let recoveryObject = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveryObject).isEqual(to: expected))
    #expect(result.importSummary?.restorations.isEmpty == true)
    #expect(result.importSummary?.replacements.first?.owner.lifetimeId == currentItem.lifetimeId)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(
          operationId: operationIdentifier, session: reopenedSession, command: authorized.command)
      ).outcome
    else { throw CancellationError() }
    #expect(reopenedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
  }

  @Test(arguments: [1, 2])
  func olderBackupOverwritesRestoredValuesWithoutReplacingTheLiveLifetimeOrOmittedList(
    restorationCount: Int
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("Save the real workflow before importing the old backup: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(
        .createItem(content: .init(title: "Museum", notes: "Original notes"))
      )
      .generated.first)
    guard case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      let originalItem = original.backup.items.first
    else { throw CancellationError() }
    for _ in 0..<restorationCount {
      guard
        case .reviewed(let deletion) = await planner.prepareReview(
          session: session, command: .deleteSource(source: item)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: deletion.command,
            reviewToken: deletion.reviewToken)
        ).outcome,
        case .reviewed(let restoration) = await planner.prepareReview(
          session: session,
          command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: restoration.command,
            reviewToken: restoration.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    let list = try #require(
      try await save(.createList(content: .init(name: "Other"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .exported(let organizedData) = await planner.exportData(session: session),
      case .decoded(let organized) = planner.decodeImport(organizedData),
      let membership = organized.backup.memberships.first,
      case .source(.item(let currentRead)) = await planner.read(
        session: session, request: .source(item))
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membership.id)),
        done: true))
    _ = try await save(
      .editItem(
        sourceId: item.id,
        changes: .init(title: .set("Current museum"), notes: .set("Current notes")),
        expectedFieldHashes: [
          .title: try #require(currentRead.fieldHashes[.title]),
          .notes: try #require(currentRead.fieldHashes[.notes]),
        ]))
    guard case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before),
      let currentItem = current.backup.items.first
    else { throw CancellationError() }
    #expect(currentItem.id == originalItem.id)
    #expect(currentItem.lifetimeId != originalItem.lifetimeId)
    #expect(current.backup.memberships.first?.localDone == true)
    let outcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: original, mode: .overwrite))
    guard case .reviewed(let review) = outcome else {
      Issue.record("Overwrite must target the restored live Item without restoring it: \(outcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    let replacement = try #require(details.replacements.first)
    #expect(details.replacements.count == 1)
    #expect(replacement.owner.id == item.id)
    #expect(replacement.owner.lifetimeId == currentItem.lifetimeId)
    #expect(replacement.before?.identity.lifetimeId == currentItem.lifetimeId)
    #expect(replacement.after?.identity.lifetimeId == currentItem.lifetimeId)
    #expect(replacement.before?.title == "Current museum")
    #expect(replacement.after?.title == "Museum")
    #expect(details.restorations.isEmpty && details.imports.isEmpty)
    guard case .exported(let afterReview) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterReview == before)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "Overwrite and its independent recovery must preserve the current graph: \(response)")
      return
    }
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let originalObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    var expectedItem = try #require((originalObject["sources"] as? [[String: Any]])?.first)
    expectedItem["lifetimeId"] = currentItem.lifetimeId.uuidString
    var expectedSources = try #require(expected["sources"] as? [[String: Any]])
    let itemIndex = try #require(
      expectedSources.firstIndex { $0["id"] as? String == item.id.uuidString })
    expectedSources[itemIndex] = expectedItem
    expected["sources"] = expectedSources
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recovery).isEqual(to: expected))
    #expect(result.importSummary?.replacements.first?.owner.lifetimeId == currentItem.lifetimeId)
    #expect(result.importSummary?.restorations.isEmpty == true)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeated) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: original, mode: .overwrite)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.impact.importDetails?.replacements.isEmpty == true)
    #expect(repeated.impact.importDetails?.restorations.isEmpty == true)
  }
}
