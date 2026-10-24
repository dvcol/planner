import Foundation
import PlannerCore
import SwiftData
import Testing

struct CaptureApplyTests {
  @Test func reviewedReuseObservesStrictRemovalAndPreservesAnotherListsCompletionThroughReplay()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = captureApplyConfiguration(directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let originalUrl = "https://example.com/strict-reuse"
    let item = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createItem(
          content: .init(
            title: "Original", notes: "Keep shared notes",
            links: [.init(originalUrl: originalUrl)]))
      ).generated.first)
    let destination = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createList(content: .init(name: "Destination"))
      ).generated.first)
    let retainedList = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createList(content: .init(name: "Keep this context"))
      ).generated.first)
    let originalAddition = try await captureApplySave(
      planner, session: session,
      command: .addMembership(itemId: item.id, listId: destination.id, placement: .last))
    let retainedAddition = try await captureApplySave(
      planner, session: session,
      command: .addMembership(itemId: item.id, listId: retainedList.id, placement: .last))
    guard
      case .membership(let removedIdentifier, _, _) = originalAddition.generatedReferences.first,
      case .membership(let retainedIdentifier, _, _) = retainedAddition.generatedReferences.first
    else { throw CancellationError() }
    _ = try await captureApplySave(
      planner, session: session,
      command: .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: retainedList.id,
            membershipId: retainedIdentifier)), done: true))
    _ = try await captureApplySave(
      planner, session: session,
      command: .removeMembership(listId: destination.id, membershipId: removedIdentifier))
    guard case .exported(let beforeData) = await planner.exportData(session: session),
      case .decoded(let before) = planner.decodeImport(beforeData),
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(item)),
      case .draft(let draft) = await planner.prepareCapture(
        session: session,
        input: .direct([.url(originalUrl)])),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: draft.draftId, draftGeneration: draft.generation,
          choice: .reuse(itemId: item.id), listIds: [destination.id, retainedList.id]))
    else { throw CancellationError() }
    #expect(review.impact.captureDetails?.missingListIds == [destination.id])
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session,
        command: review.command, reviewToken: review.reviewToken))
    guard case .applied(let applied, .complete(let checkpoint)) = response.outcome,
      case .membership(let addedIdentifier, _, _) = applied.generatedReferences.first,
      case .exported(let savedData) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(savedData),
      case .appearance(let added) = await planner.read(
        session: session,
        request: .appearance(.listMembership(listId: destination.id, membershipId: addedIdentifier))
      ),
      case .appearance(let retained) = await planner.read(
        session: session,
        request: .appearance(
          .listMembership(listId: retainedList.id, membershipId: retainedIdentifier))),
      case .source(.item(let savedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else {
      Issue.record(
        "Reviewed reuse must create an informed membership after an ordinary Remove: \(response)")
      return
    }
    #expect(addedIdentifier != removedIdentifier && added.localDone == false)
    #expect(retained.localDone && savedItem.state.globalDone == false)
    #expect(
      savedItem.updatedAt == beforeItem.updatedAt && savedItem.fieldHashes == beforeItem.fieldHashes
    )
    let basis = try #require(
      saved.backup.membershipProvenance.first { $0.membershipId == addedIdentifier })
    #expect(basis.observedRemovalIds == before.backup.membershipRemovals.map(\.deletionId))
    #expect(
      saved.backup.membershipRemovals.map(\.deletionId)
        == before.backup.membershipRemovals.map(\.deletionId))
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let envelope = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf:
            namespaceDirectory.appendingPathComponent("checkpoint-\(checkpoint).json")))
        as? [String: Any])
    let receipts = try #require(envelope["receipts"] as? [[String: Any]])
    let receipt = try #require(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString })
    #expect((receipt["payloadDigest"] as? String)?.hasPrefix("sha256-payload-v3:") == true)
    let files = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory,
      includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("proposal-") }
    let candidates = try files.compactMap { file -> [String: Any]? in
      let value = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
      return value?["originalOperationId"] as? String == operationIdentifier.uuidString
        ? value : nil
    }
    let preparation = try #require(candidates.first)
    #expect(preparation["formatVersion"] as? Int == 2)
    #expect((preparation["resolvedMembershipEvidence"] as? [[String: Any]])?.count == 2)
    guard
      case .draft(let noOpDraft) = await planner.prepareCapture(
        session: session, input: .direct([.url(originalUrl)])),
      case .reviewed(let noOpReview) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: noOpDraft.draftId, draftGeneration: noOpDraft.generation,
          choice: .reuse(itemId: item.id), listIds: [destination.id, retainedList.id])),
      case .applied(let noOpResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: noOpReview.command,
          reviewToken: noOpReview.reviewToken)
      ).outcome,
      case .exported(let afterNoOp) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(noOpResult.generatedIdentities.isEmpty && afterNoOp == savedData)
    _ = try await captureApplySave(
      planner, session: session,
      command: .removeMembership(listId: destination.id, membershipId: addedIdentifier))
    _ = try await captureApplySave(
      planner, session: session,
      command: .addMembership(itemId: item.id, listId: destination.id, placement: .last))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let beforeReplay) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .exported(let afterReplay) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(replayed == applied && replayCheckpoint == checkpoint)
    #expect(afterReplay == beforeReplay)
  }

  @Test func ownedFieldsAndLabelsSaveToInboxAndAnEmptyReuseLeavesDataUnchanged() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(configuration: captureApplyConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let category = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createCategory(content: .init(name: "Food"))
      ).generated.first)
    let tag = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createTag(content: .init(name: "Weekend"))
      ).generated.first)
    let location = PlannerOwnedLocation(
      displayName: "My place", formattedAddress: "My address",
      coordinate: .init(latitude: 35, longitude: 139))
    guard
      case .draft(let prepared) = await planner.prepareCapture(
        session: session,
        input: .direct([.url("https://example.com/visit")])),
      case .draft(let draft) = await planner.updateCapture(
        session: session, draftId: prepared.draftId,
        generation: prepared.generation,
        edit: .init(
          changes: .init(
            subtitle: .set("My subtitle"), notes: .set("My notes"),
            location: .set(location), categoryIds: .set([category.id]), tagIds: .set([tag.id])))),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: draft.draftId, draftGeneration: draft.generation,
          choice: .createNew, listIds: [])),
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: review.command, reviewToken: review.reviewToken)
      ).outcome,
      let item = result.generated.first,
      case .source(.item(let saved)) = await planner.read(session: session, request: .source(item))
    else { throw CancellationError() }
    #expect(
      saved.content.subtitle == "My subtitle" && saved.content.notes == "My notes"
        && saved.content.location == location)
    #expect(
      Set(saved.labels.map(\.reference)) == [category, tag] && result.generatedReferences.count == 2
    )
    guard case .exported(let before) = await planner.exportData(session: session),
      case .draft(let reuseDraft) = await planner.prepareCapture(
        session: session,
        input: .direct([.url("https://example.com/visit")])),
      case .reviewed(let reuse) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: reuseDraft.draftId, draftGeneration: reuseDraft.generation,
          choice: .reuse(itemId: item.id), listIds: [])),
      let details = reuse.impact.captureDetails,
      case .applied(let reused, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: reuse.command, reviewToken: reuse.reviewToken)
      ).outcome,
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(
      details.missingLinks.isEmpty && details.missingListIds.isEmpty && details.createContent == nil
    )
    #expect(reused.generatedIdentities.isEmpty && after == before)
  }

  @Test(arguments: [
    "emptyDraft", "noToken", "editedDraft", "canceled", "archivedList", "deletedList",
    "changedLists", "changedSourceLinks", "archivedSource", "deletedSource", "changedMembership",
  ])
  func invalidOrChangedCaptureReviewMakesNoCaptureWrites(scenario: String) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(configuration: captureApplyConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let item = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createItem(
          content: .init(
            title: "Existing", links: [.init(originalUrl: "https://example.com/visit")]))
      ).generated.first)
    let firstList = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createList(content: .init(name: "First"))
      ).generated.first)
    let secondList = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createList(content: .init(name: "Second"))
      ).generated.first)
    guard
      case .draft(let draft) = await planner.prepareCapture(
        session: session,
        input: .direct([.url("https://example.com/visit")]))
    else { throw CancellationError() }
    var choice = PlannerCaptureChoice.createNew
    if ["changedSourceLinks", "archivedSource", "deletedSource", "changedMembership"].contains(
      scenario)
    {
      choice = .reuse(itemId: item.id)
    }
    var command = PlannerCommand.applyCapture(
      draftId: draft.draftId, draftGeneration: draft.generation,
      choice: choice, listIds: [firstList.id])
    guard
      case .reviewed(let review) = await planner.prepareReview(session: session, command: command)
    else { throw CancellationError() }
    var token: PlannerReviewToken? = review.reviewToken
    var expectedCode = "staleReview"
    switch scenario {
    case "emptyDraft":
      guard
        case .draft(let empty) = await planner.prepareCapture(session: session, input: .direct([]))
      else { throw CancellationError() }
      command = .applyCapture(
        draftId: empty.draftId, draftGeneration: empty.generation,
        choice: .createNew, listIds: [])
      expectedCode = "invalidInput"
    case "noToken": token = nil
    case "editedDraft":
      guard
        case .draft = await planner.updateCapture(
          session: session, draftId: draft.draftId,
          generation: draft.generation, edit: .init(changes: .init(title: .set("My updated title")))
        )
      else { throw CancellationError() }
    case "canceled":
      guard
        case .cancelled = await planner.cancelCapture(
          session: session, draftId: draft.draftId,
          generation: draft.generation)
      else { throw CancellationError() }
      expectedCode = "captureDraftUnavailable"
    case "archivedList":
      _ = try await captureApplySave(
        planner, session: session,
        command: .setArchive(source: firstList, archived: true))
    case "deletedList", "deletedSource":
      var source = firstList
      if scenario == "deletedSource" { source = item }
      guard
        case .reviewed(let deletion) = await planner.prepareReview(
          session: session,
          command: .deleteSource(source: source)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: deletion.command, reviewToken: deletion.reviewToken)
        ).outcome
      else { throw CancellationError() }
    case "changedLists":
      command = .applyCapture(
        draftId: draft.draftId, draftGeneration: draft.generation,
        choice: choice, listIds: [secondList.id])
    case "changedSourceLinks":
      guard
        case .source(.item(let read)) = await planner.read(session: session, request: .source(item)),
        let hash = read.fieldHashes[.links]
      else { throw CancellationError() }
      _ = try await captureApplySave(
        planner, session: session,
        command: .editItem(
          sourceId: item.id,
          changes: .init(links: .set([.init(originalUrl: "https://example.com/other")])),
          expectedFieldHashes: [.links: hash]))
    case "archivedSource":
      _ = try await captureApplySave(
        planner, session: session,
        command: .setArchive(source: item, archived: true))
    default:
      _ = try await captureApplySave(
        planner, session: session,
        command: .addMembership(itemId: item.id, listId: firstList.id, placement: .last))
    }
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session,
        command: command, reviewToken: token))
    guard case .rejected(let failure) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else {
      Issue.record("Invalid \(scenario) capture must reject without writes: \(response)")
      return
    }
    #expect(failure.code == expectedCode && before == after)
  }

  @Test(arguments: [false, true])
  func recoveryFailureRetainsTheWholeCaptureAndRetryDoesNotReapply(reusesItem: Bool) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = captureApplyConfiguration(directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let existing = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createItem(
          content: .init(
            title: "Existing", links: [.init(originalUrl: "https://example.com/original")]))
      ).generated.first)
    let list = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createList(content: .init(name: "Selected"))
      ).generated.first)
    guard
      case .draft(let draft) = await planner.prepareCapture(
        session: session,
        input: .direct([.url("https://example.com/original"), .url("https://example.com/extra")]))
    else { throw CancellationError() }
    var choice = PlannerCaptureChoice.createNew
    if reusesItem { choice = .reuse(itemId: existing.id) }
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: draft.draftId, draftGeneration: draft.generation,
          choice: choice, listIds: [list.id]))
    else { throw CancellationError() }
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) {
      obstruction.observe($0)
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session,
        command: review.command, reviewToken: review.reviewToken))
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    guard case .applied(let applied, .incomplete(let failure)) = response.outcome else {
      Issue.record(
        "Native save must retain the complete capture before failed publication: \(response)")
      return
    }
    try obstruction.restore()
    guard
      case .appliedRecoveryIncomplete(let status, _) = await planner.operationStatus(
        session: session,
        operationId: operationIdentifier),
      case .rejected(let blocked) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Must not apply")))
      ).outcome
    else { throw CancellationError() }
    #expect(
      failure.code == "recoveryIncomplete" && blocked.code == "mutationBlocked" && status == applied
    )
    guard case .exported(let saved) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let retried, .complete) = await reopened.retryRecovery(
        session: reopenedSession,
        operationId: operationIdentifier
      ).outcome,
      case .applied(let replayed, .complete) = await reopened.execute(
        .init(
          operationId: operationIdentifier,
          session: reopenedSession, command: review.command)
      ).outcome,
      case .exported(let after) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(retried == applied && replayed == applied && after == saved)
    #expect(
      applied.generatedReferences.count == 1 && applied.generated.count == (reusesItem ? 0 : 1))
    let graph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let memberships = try #require(graph["memberships"] as? [[String: Any]])
    #expect(memberships.count == 1)
  }

  @Test func appliedCaptureCannotBeCancelledOrRetargetedByChangedReplay() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(configuration: captureApplyConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session,
        input: .direct([.url("https://example.com/visit")])),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: draft.draftId, draftGeneration: draft.generation,
          choice: .createNew, listIds: []))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    guard
      case .applied(let applied, .complete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      let item = applied.generated.first,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let cancellation = await planner.cancelCapture(
      session: session, draftId: draft.draftId,
      generation: draft.generation)
    guard case .notCancellable(let savingOperationIdentifier) = cancellation else {
      Issue.record(
        "An applied capture must resolve operation status instead of cancellation: \(cancellation)")
      return
    }
    #expect(savingOperationIdentifier == operationIdentifier)
    guard
      case .rejected(let mismatch) = await planner.execute(
        .init(
          operationId: operationIdentifier,
          session: session,
          command: .applyCapture(
            draftId: draft.draftId, draftGeneration: draft.generation,
            choice: .reuse(itemId: item.id), listIds: []))
      ).outcome,
      case .rejected(let repeatedAdd) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: review.command, reviewToken: review.reviewToken)
      ).outcome,
      case .appliedRecoveryComplete(let status, _) = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(
      mismatch.code == "operationPayloadMismatch" && repeatedAdd.code == "captureDraftUnavailable")
    #expect(status == applied && before == after)
  }

  @Test func reviewedReuseAddsOnlyMissingLinksAndMembershipsAndRetainsOtherPlanningState()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(configuration: captureApplyConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let originalUrl = "https://example.com/original"
    let extraUrl = "https://example.com/extra"
    let item = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createItem(
          content: .init(
            title: "Existing title", notes: "Existing notes",
            links: [.init(originalUrl: originalUrl, label: "Existing label")]))
      ).generated.first)
    let firstList = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createList(content: .init(name: "First"))
      ).generated.first)
    let secondList = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .createList(content: .init(name: "Second"))
      ).generated.first)
    let membership = try #require(
      try await captureApplySave(
        planner, session: session,
        command: .addMembership(itemId: item.id, listId: firstList.id, placement: .last)
      )
      .generatedReferences.first)
    guard case .membership(let membershipIdentifier, _, _) = membership else {
      throw CancellationError()
    }
    let originalAppearance = PlannerAppearance.listMembership(
      listId: firstList.id,
      membershipId: membershipIdentifier)
    _ = try await captureApplySave(
      planner, session: session,
      command: .setCompletion(scope: .appearance(originalAppearance), done: true))
    _ = try await captureApplySave(
      planner, session: session,
      command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await captureApplySave(
      planner, session: session,
      command: .setArchive(source: item, archived: true))
    let schedule = try await captureApplySave(
      planner, session: session,
      command: .createSchedule(
        source: item,
        form: .timed(
          start: Date(timeIntervalSince1970: 1_800_000_000),
          end: nil, planningTimeZone: "Asia/Tokyo")))
    guard case .exported(let seed) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    var importedGraph = try #require(JSONSerialization.jsonObject(with: seed) as? [String: Any])
    var importedLinks = try #require(importedGraph["ownedLinks"] as? [[String: Any]])
    importedLinks[0]["rank"] = "1000"
    importedGraph["ownedLinks"] = importedLinks
    guard
      case .decoded(let imported) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: importedGraph)),
      case .reviewed(let importReview) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: imported, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: importReview.command, reviewToken: importReview.reviewToken)
      ).outcome
    else { throw CancellationError() }
    guard
      case .source(.item(let before)) = await planner.read(session: session, request: .source(item)),
      case .draft(let draft) = await planner.prepareCapture(
        session: session,
        input: .direct([.text("New title\nNew notes"), .url(originalUrl), .url(extraUrl)]))
    else { throw CancellationError() }
    let reviewResponse = await planner.prepareReview(
      session: session,
      command: .applyCapture(
        draftId: draft.draftId, draftGeneration: draft.generation,
        choice: .reuse(itemId: item.id), listIds: [firstList.id, secondList.id]))
    guard case .reviewed(let review) = reviewResponse, let details = review.impact.captureDetails
    else {
      Issue.record("Exact reuse must prepare missing additions: \(reviewResponse)")
      return
    }
    #expect(details.createContent == nil && details.missingLinks.map(\.originalUrl) == [extraUrl])
    #expect(details.missingListIds == [secondList.id])
    let response = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: review.command, reviewToken: review.reviewToken))
    guard case .applied(let applied, .complete) = response.outcome,
      case .source(.item(let after)) = await planner.read(session: session, request: .source(item)),
      case .appearance(let originalContext) = await planner.read(
        session: session,
        request: .appearance(originalAppearance)),
      case .membership(let newMembershipIdentifier, let destination, _)? = applied
        .generatedReferences.first,
      case .appearance(let newContext) = await planner.read(
        session: session,
        request: .appearance(
          .listMembership(listId: destination.id, membershipId: newMembershipIdentifier)))
    else { throw CancellationError() }
    #expect(applied.generated.isEmpty && applied.generatedReferences.count == 1)
    #expect(
      after.content.title == before.content.title && after.content.notes == before.content.notes)
    #expect(after.content.links.map(\.originalUrl) == [originalUrl, extraUrl])
    #expect(after.content.links.first?.linkId == before.content.links.first?.linkId)
    #expect(after.content.links.first?.label == "Existing label")
    #expect(
      after.state.globalDone == true && after.state.archived == true && originalContext.localDone)
    #expect(!newContext.localDone && newContext.globalDone && newContext.effectiveDone)
    #expect(
      schedule.generated.allSatisfy {
        after.references.contains(.schedule(id: $0.id, source: item))
      })
  }

  @Test(arguments: [false, true])
  func reviewedCaptureCreatesOneItemAndEverySelectedMembershipWithDurableReplay(
    usesExplicitTitle: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = captureApplyConfiguration(directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let firstList = try #require(
      try await captureApplySave(
        planner, session: session, command: .createList(content: .init(name: "First"))
      )
      .generated.first)
    let secondList = try #require(
      try await captureApplySave(
        planner, session: session, command: .createList(content: .init(name: "Second"))
      )
      .generated.first)
    guard case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url("https://example.com/%2f?x=%41")]))
    else { throw CancellationError() }
    var draft = prepared
    if usesExplicitTitle {
      guard
        case .draft(let edited) = await planner.updateCapture(
          session: session, draftId: draft.draftId, generation: draft.generation,
          edit: .init(changes: .init(title: .set("Saved link"))))
      else { throw CancellationError() }
      draft = edited
    }
    let command = PlannerCommand.applyCapture(
      draftId: draft.draftId, draftGeneration: draft.generation, choice: .createNew,
      listIds: [firstList.id, secondList.id])
    guard
      case .reviewed(let review) = await planner.prepareReview(session: session, command: command),
      let details = review.impact.captureDetails,
      case .exported(let stillBefore) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(review.impact.kind == .capture && !review.globalFlagsChanged)
    #expect(details.createContent?.title == "Saved link")
    #expect(details.missingLinks.map(\.originalUrl) == ["https://example.com/%2f?x=%41"])
    #expect(details.missingListIds == [firstList.id, secondList.id] && stillBefore == before)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: command,
        reviewToken: review.reviewToken))
    guard case .applied(let applied, .complete(let checkpoint)) = response.outcome,
      let item = applied.generated.first(where: { $0.kind == .item }),
      case .source(.item(let saved)) = await planner.read(session: session, request: .source(item)),
      case .exported(let after) = await planner.exportData(session: session),
      case .rejected(let noDraft) = await planner.readCapture(
        session: session, draftId: draft.draftId)
    else {
      Issue.record("Reviewed capture must save one complete recoverable action: \(response)")
      return
    }
    #expect(checkpoint > 0 && applied.generated.filter { $0.kind == .item }.count == 1)
    #expect(applied.generatedReferences.count == 2)
    #expect(
      saved.content.title == "Saved link" && saved.state.globalDone == false
        && saved.state.archived == false)
    #expect(saved.content.links.map(\.originalUrl) == ["https://example.com/%2f?x=%41"])
    #expect(!Set(saved.content.links.compactMap(\.linkId)).contains(draft.links[0].linkId))
    #expect(noDraft.code == "captureDraftUnavailable")
    for reference in applied.generatedReferences {
      guard case .membership(let membershipIdentifier, let list, _) = reference,
        case .appearance(let appearance) = await planner.read(
          session: session,
          request: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier))
        )
      else { throw CancellationError() }
      #expect(!appearance.localDone && !appearance.globalDone && !appearance.effectiveDone)
    }
    let graph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let sources = try #require(graph["sources"] as? [[String: Any]])
    let source = try #require(sources.first { $0["id"] as? String == item.id.uuidString })
    let origins = try #require(source["contentOrigins"] as? [String: String])
    let expectedOrigin = usesExplicitTitle ? "independent" : "appFallback"
    #expect(origins["title"] == expectedOrigin)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .exported(let replayExport) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(replayed == applied && replayExport == after)
  }
}

private func captureApplyConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
  .init(
    storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
    controlURL: directory.appendingPathComponent("control/writer"),
    recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
    processRole: .mainApplication, storageMode: .localOnly)
}

private func captureApplySave(
  _ planner: Planner, session: PlannerDatasetSession, command: PlannerCommand
) async throws -> PlannerAppliedResult {
  guard
    case .applied(let result, .complete) = await planner.execute(
      .init(operationId: UUID(), session: session, command: command)
    ).outcome
  else { throw CancellationError() }
  return result
}
