import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerBulkCompletionIntentTests: XCTestCase {
  func testReviewedListCompletionIncludesArchivedChildrenAndPreservesOtherContexts() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let archived = try await fixture.store.executeAppIntent(
      .setArchive(source: fixture.lunch, archived: true))
    guard case .applied(_, .complete) = archived.outcome else { throw CancellationError() }
    let before = try await readEstimateResetSources(fixture)
    let review = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .list(listId: fixture.list.id), done: true)
    XCTAssertEqual(review.targetCount, 2)
    let prepared = try await readEstimateResetSources(fixture)
    XCTAssertEqual(prepared.item.fieldHashes, before.item.fieldHashes)
    XCTAssertEqual(prepared.list.progress.doneCount, 1)
    let result = try await fixture.store.executeAppIntent(
      review.command, reviewToken: review.reviewToken)
    guard case .applied(_, .complete) = result.outcome else {
      return XCTFail("Reviewed bulk completion must durably apply its entire local scope.")
    }
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    for membership in [fixture.membershipIdentifier, fixture.lunchMembershipIdentifier] {
      guard
        case .appearance(let appearance) = await reopened.read(
          session: session,
          request: .appearance(.listMembership(listId: fixture.list.id, membershipId: membership)))
      else { throw CancellationError() }
      XCTAssertTrue(appearance.localDone)
      XCTAssertFalse(appearance.globalDone)
    }
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(after.item.fieldHashes, before.item.fieldHashes)
    XCTAssertEqual(after.lunch.fieldHashes, before.lunch.fieldHashes)
    XCTAssertEqual(after.list.content, before.list.content)
    XCTAssertEqual(after.itinerary.fieldHashes, before.itinerary.fieldHashes)
    XCTAssertEqual(after.itinerary.progress.doneCount, before.itinerary.progress.doneCount)
    XCTAssertEqual(after.itinerary.progress.totalCount, 5)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
  func testGlobalDoneTakesPrecedenceWithoutChangingRetainedLocalFlags() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let completed = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .list(listId: fixture.list.id), done: true)
    try await submit(completed, store: fixture.store)
    _ = try await fixture.store.executeAppIntent(
      .setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true))
    let reopened = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .list(listId: fixture.list.id), done: false)
    try await submit(reopened, store: fixture.store)
    let appearance = PlannerAppearance.listMembership(
      listId: fixture.list.id, membershipId: fixture.membershipIdentifier)
    guard
      case .appearance(let saved) = await fixture.planner.read(
        session: fixture.session, request: .appearance(appearance))
    else { throw CancellationError() }
    XCTAssertFalse(saved.localDone)
    XCTAssertTrue(saved.globalDone)
    XCTAssertTrue(saved.effectiveDone)
    _ = try await fixture.store.executeAppIntent(
      .setCompletion(scope: .globalItem(itemId: fixture.item.id), done: false))
    guard
      case .appearance(let undone) = await fixture.planner.read(
        session: fixture.session, request: .appearance(appearance))
    else { throw CancellationError() }
    XCTAssertFalse(undone.localDone)
    XCTAssertFalse(undone.effectiveDone)
  }

  func testItineraryAndRepeatedBranchReviewsKeepIndependentLocalContexts() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    let review = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .itinerary(itineraryId: fixture.itinerary.id), done: true)
    XCTAssertEqual(review.targetCount, 5)
    XCTAssertFalse(review.globalFlagsChanged)
    try await submit(review, store: fixture.store)
    try await assertLocalStates(fixture, expected: [true, false, true, true, true, true, true])
    let branch = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .itineraryListEntry(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.firstBranchIdentifier), done: false)
    XCTAssertEqual(branch.targetCount, 2)
    try await submit(branch, store: fixture.store)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    try await assertLocalStates(
      fixture, expected: [true, false, false, false, true, true, true],
      planner: reopened, session: session)
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(after.item.fieldHashes, before.item.fieldHashes)
    XCTAssertEqual(after.lunch.fieldHashes, before.lunch.fieldHashes)
    XCTAssertEqual(after.list.content, before.list.content)
    XCTAssertEqual(after.itinerary.content, before.itinerary.content)
    let retainedReferences = after.itinerary.references.filter {
      if case .expandedCompletion = $0 { return false }
      return true
    }
    let originalReferences = before.itinerary.references.filter {
      if case .expandedCompletion = $0 { return false }
      return true
    }
    XCTAssertEqual(retainedReferences, originalReferences)
    for reference in [fixture.itemSchedule, fixture.itinerarySchedule] {
      guard
        case .source(.schedule(let saved)) = await reopened.read(
          session: session, request: .source(reference)),
        case .source(.schedule(let original)) = await fixture.planner.read(
          session: fixture.session, request: .source(reference))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content, original.content)
    }
  }

  func testChangedTargetsRequireANewReviewAndMissingTokensApplyNothing() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let oldReview = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .list(listId: fixture.list.id), done: true)
    let creation = try await fixture.store.executeAppIntent(
      .createItem(content: .init(title: "Tea")))
    guard case .applied(let created, .complete) = creation.outcome,
      let tea = created.generated.first
    else { throw CancellationError() }
    _ = try await fixture.store.executeAppIntent(
      .addMembership(itemId: tea.id, listId: fixture.list.id, placement: .last))
    let before = try await backup(fixture)
    for token in [oldReview.reviewToken, nil] {
      let result = try await fixture.store.executeAppIntent(oldReview.command, reviewToken: token)
      guard case .rejected(let failure) = result.outcome else {
        return XCTFail("A changed or missing review cannot authorize bulk completion.")
      }
      XCTAssertEqual(failure.code, "staleReview")
      let after = try await backup(fixture)
      XCTAssertEqual(after, before)
    }
    let refreshed = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .list(listId: fixture.list.id), done: true)
    XCTAssertEqual(refreshed.targetCount, 3)
    let stillUnchanged = try await backup(fixture)
    XCTAssertEqual(stillUnchanged, before)
    try await submit(refreshed, store: fixture.store)
    let sources = try await readEstimateResetSources(fixture)
    XCTAssertEqual(sources.list.progress.doneCount, 3)
    XCTAssertEqual(sources.list.progress.totalCount, 3)
    XCTAssertFalse(sources.item.state.globalDone ?? true)
  }

  func testMissingWrongKindWrongParentAndRemovedBranchesNeverRedirectReviews() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await backup(fixture)
    for scope in [
      PlannerBulkScope.list(listId: UUID()), .list(listId: fixture.item.id),
      .itinerary(itineraryId: fixture.list.id),
      .itineraryListEntry(itineraryId: UUID(), listEntryId: fixture.firstBranchIdentifier),
      .itineraryListEntry(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.directEntryIdentifier),
    ] {
      do {
        _ = try await fixture.store.prepareAppIntentBulkCompletion(scope: scope, done: true)
        XCTFail("Invalid exact scopes must fail before any write.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(fixture)
    XCTAssertEqual(after, before)
    let removed = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .itineraryListEntry(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.firstBranchIdentifier), done: true)
    _ = try await fixture.store.executeAppIntent(
      .removeItineraryEntry(
        itineraryId: fixture.itinerary.id, entryId: fixture.firstBranchIdentifier))
    let withoutBranch = try await backup(fixture)
    let result = try await fixture.store.executeAppIntent(
      removed.command, reviewToken: removed.reviewToken)
    guard case .rejected(let failure) = result.outcome else { throw CancellationError() }
    XCTAssertEqual(failure.code, "missingReference")
    let retained = try await backup(fixture)
    XCTAssertEqual(retained, withoutBranch)
  }

  func testEmptyReviewsDoNotCompleteEmptyContainers() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    for command in [
      PlannerCommand.createList(content: .init(name: "Empty List")),
      .createItinerary(content: .init(title: "Empty Itinerary")),
    ] {
      let result = try await store.executeAppIntent(command)
      guard case .applied(let created, .complete) = result.outcome,
        let source = created.generated.first
      else { throw CancellationError() }
      let scope: PlannerBulkScope
      if source.kind == .list {
        scope = .list(listId: source.id)
      } else {
        scope = .itinerary(itineraryId: source.id)
      }
      let review = try await store.prepareAppIntentBulkCompletion(scope: scope, done: true)
      XCTAssertEqual(review.targetCount, 0)
      XCTAssertTrue(review.targets.isEmpty)
      try await submit(review, store: store)
      let (planner, session) = try await store.appIntentContext()
      switch await planner.read(session: session, request: .source(source)) {
      case .source(.list(let saved)): XCTAssertEqual(saved.progress.state, .empty)
      case .source(.itinerary(let saved)): XCTAssertEqual(saved.progress.state, .empty)
      default: XCTFail("The original empty container must survive.")
      }
    }
  }

  func testPrecancelledAndUnavailableReviewOrSubmissionPreserveData() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let scope = PlannerBulkScope.list(listId: fixture.list.id)
    let review = try await fixture.store.prepareAppIntentBulkCompletion(scope: scope, done: true)
    let before = try await backup(fixture)
    let preparation = Task {
      try await fixture.store.prepareAppIntentBulkCompletion(scope: scope, done: true)
    }
    preparation.cancel()
    do {
      _ = try await preparation.value
      XCTFail("Precancelled preparation must throw.")
    } catch { XCTAssertTrue(error is CancellationError) }
    let submission = Task {
      try await fixture.store.executeAppIntent(review.command, reviewToken: review.reviewToken)
    }
    submission.cancel()
    do {
      _ = try await submission.value
      XCTFail("Precancelled submission must throw.")
    } catch { XCTAssertTrue(error is CancellationError) }
    let after = try await backup(fixture)
    XCTAssertEqual(after, before)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let obstruction = Data("Store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    do {
      _ = try await unavailable.prepareAppIntentBulkCompletion(scope: scope, done: true)
      XCTFail("Unavailable storage cannot prepare a review.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    do {
      _ = try await unavailable.executeAppIntent(review.command, reviewToken: review.reviewToken)
      XCTFail("Unavailable storage cannot submit a change.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
    XCTAssertFalse(unavailable.isReady)
  }

  func testPrecommitFailureLeavesEveryTargetUnapplied() async throws {
    for scopeName in ["list", "itinerary", "branch"] {
      let fixture = try await makeEstimateResetIntentFixture()
      let scope = scope(for: scopeName, fixture: fixture)
      let review = try await fixture.store.prepareAppIntentBulkCompletion(scope: scope, done: true)
      let before = try await backup(fixture)
      let recovery = fixture.configuration.recoveryDirectoryURL
      let retained = recovery.deletingLastPathComponent().appending(path: "retained-bulk-recovery")
      try FileManager.default.moveItem(at: recovery, to: retained)
      try Data("Obstruct recovery before submission.".utf8).write(to: recovery)
      defer {
        try? FileManager.default.removeItem(at: recovery)
        try? FileManager.default.moveItem(at: retained, to: recovery)
      }
      let result = try await fixture.store.executeAppIntent(
        review.command, reviewToken: review.reviewToken)
      guard case .rejected(let failure) = result.outcome else { throw CancellationError() }
      XCTAssertEqual(failure.code, "persistenceFailure")
      let after = try await backup(fixture)
      XCTAssertEqual(after, before)
      try await assertLocalStates(
        fixture, expected: [true, false, true, false, false, false, false])
      XCTAssertFalse(fixture.store.isSaving)
    }
  }

  func testIncompleteRecoveryRetainsWholeBulkResultAndRepairsWithoutReapplying() async throws {
    for scopeName in ["list", "itinerary", "branch"] {
      let fixture = try await makeEstimateResetIntentFixture()
      let review = try await fixture.store.prepareAppIntentBulkCompletion(
        scope: scope(for: scopeName, fixture: fixture), done: true)
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let result = try await fixture.store.executeAppIntent(
        review.command, reviewToken: review.reviewToken)
      guard case .applied(_, .incomplete(let failure)) = result.outcome else {
        throw CancellationError()
      }
      XCTAssertEqual(failure.code, "recoveryIncomplete")
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [result.operationId])
      let expected: [Bool]
      switch scopeName {
      case "list": expected = [true, true, true, false, false, false, false]
      case "itinerary": expected = [true, false, true, true, true, true, true]
      default: expected = [true, false, true, true, false, false, false]
      }
      try await assertLocalStates(fixture, expected: expected)
      do {
        _ = try await fixture.store.prepareAppIntentBulkCompletion(
          scope: .list(listId: fixture.list.id), done: false)
        XCTFail("Preparation stays blocked during incomplete recovery.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      do {
        _ = try await fixture.store.executeAppIntent(.createItem(content: .init(title: "Blocked")))
        XCTFail("Ordinary writes stay blocked during incomplete recovery.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let beforeRepair = try await backup(fixture)
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      guard
        case .appliedRecoveryComplete = await fixture.planner.operationStatus(
          session: fixture.session, operationId: result.operationId)
      else { return XCTFail("Repair must acknowledge the original bulk operation.") }
      let afterRepair = try await backup(fixture)
      XCTAssertEqual(afterRepair, beforeRepair)
      try await assertLocalStates(fixture, expected: expected)
    }
  }

  func testListActionRejectsMissingAndWrongKindTargetsBeforeConfirmation() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await backup(fixture)
    for identifier in [UUID(), fixture.item.id] {
      let action = SetPlannerListChildCompletionIntent()
      action.list = .init(id: identifier, name: "Cached List", archived: true)
      action.completed = true
      do {
        let _: Void = try await action.callAsFunction(donate: false)
        XCTFail("An invalid List must fail before requesting confirmation.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(fixture)
    XCTAssertEqual(after, before)
  }

  func testItineraryActionsRejectWrongParentsKindsAndRemovedEntriesBeforeConfirmation() async throws
  {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await backup(fixture)
    for identifier in [UUID(), fixture.list.id] {
      let action = SetPlannerItineraryChildCompletionIntent()
      action.itinerary = .init(id: identifier, title: "Cached route", archived: false)
      action.completed = true
      do {
        let _: Void = try await action.callAsFunction(donate: false)
        XCTFail("An invalid Itinerary must fail before confirmation.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let identities = [
      "invalid",
      "v1/entry/\(UUID())/\(fixture.firstBranchIdentifier)/list/\(fixture.list.id)",
      "v1/entry/\(fixture.itinerary.id)/\(fixture.directEntryIdentifier)/item/\(fixture.item.id)",
      "v1/entry/\(fixture.itinerary.id)/\(UUID())/list/\(fixture.list.id)",
      "v1/entry/\(fixture.itinerary.id)/\(fixture.firstBranchIdentifier)/list/\(fixture.item.id)",
    ]
    for identity in identities {
      let action = SetPlannerItineraryListChildCompletionIntent()
      action.itinerary = .init(id: fixture.itinerary.id, title: "Cached", archived: false)
      action.entry = .init(
        id: identity, title: "Cached", context: "Cached", kind: .list, archived: false)
      action.completed = true
      do {
        let _: Void = try await action.callAsFunction(donate: false)
        XCTFail("An invalid exact List entry must fail before confirmation.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(fixture)
    XCTAssertEqual(after, before)
  }

  func testRestoredOwnersAndBranchesCannotReuseEarlierReviewAuthority() async throws {
    for scopeName in ["list", "itinerary", "branch"] {
      let fixture = try await makeEstimateResetIntentFixture()
      let original = try await backup(fixture)
      let review = try await fixture.store.prepareAppIntentBulkCompletion(
        scope: scope(for: scopeName, fixture: fixture), done: true)
      let removal: PlannerCommand
      if scopeName == "branch" {
        removal = .removeItineraryEntry(
          itineraryId: fixture.itinerary.id, entryId: fixture.firstBranchIdentifier)
        _ = try await fixture.store.executeAppIntent(removal)
      } else {
        let source = scopeName == "list" ? fixture.list : fixture.itinerary
        removal = .deleteSource(source: source)
        guard
          case .reviewed(let deletion) = await fixture.planner.prepareReview(
            session: fixture.session, command: removal),
          case .applied(_, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session, command: removal,
              reviewToken: deletion.reviewToken)
          ).outcome
        else { throw CancellationError() }
      }
      guard case .decoded(let incoming) = fixture.planner.decodeImport(original),
        case .reviewed(let restoration) = await fixture.planner.prepareReview(
          session: fixture.session,
          command: .applyImport(backup: incoming, mode: .overwrite, restoreDeletedData: true)),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: restoration.command,
            reviewToken: restoration.reviewToken)
        ).outcome
      else { throw CancellationError() }
      let restored = try await backup(fixture)
      let result = try await fixture.store.executeAppIntent(
        review.command, reviewToken: review.reviewToken)
      guard case .rejected(let reason) = result.outcome else {
        return XCTFail("A restored public identity needs fresh bulk review authority.")
      }
      XCTAssertEqual(reason.code, "staleReview")
      let unchanged = try await backup(fixture)
      XCTAssertEqual(unchanged, restored)
      try await assertLocalStates(
        fixture, expected: [true, false, true, false, false, false, false])
    }
  }

  func testBulkIntentsRespectPrecancelledTasksAndUnavailableStorageBeforeConfirmation() async throws
  {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await backup(fixture)
    for kind in ["list", "itinerary", "branch"] {
      let request = Task { try await self.invokeBulk(kind: kind, fixture: fixture) }
      request.cancel()
      do {
        try await request.value
        XCTFail("Precancelled bulk actions cannot request or apply changes.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await backup(fixture)
    XCTAssertEqual(after, before)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: unavailable)
    for kind in ["list", "itinerary", "branch"] {
      do {
        try await invokeBulk(kind: kind, fixture: fixture)
        XCTFail("Unavailable storage must fail before confirmation.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertFalse(unavailable.isReady)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testCompletingOneItineraryPreservesAnotherItineraryReferencingTheSameList() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let creation = try await fixture.store.executeAppIntent(
      .createItinerary(content: .init(title: "Another route")))
    guard case .applied(let created, .complete) = creation.outcome,
      let other = created.generated.first
    else { throw CancellationError() }
    let addition = try await fixture.store.executeAppIntent(
      .addItineraryEntry(itineraryId: other.id, source: fixture.list, placement: .last))
    guard case .applied(let added, .complete) = addition.outcome,
      case .itineraryEntry(let entryIdentifier, _, _)? = added.generatedReferences.first
    else { throw CancellationError() }
    let review = try await fixture.store.prepareAppIntentBulkCompletion(
      scope: .itinerary(itineraryId: fixture.itinerary.id), done: true)
    try await submit(review, store: fixture.store)
    for membershipIdentifier in [fixture.membershipIdentifier, fixture.lunchMembershipIdentifier] {
      guard
        case .appearance(let saved) = await fixture.planner.read(
          session: fixture.session,
          request: .appearance(
            .expandedListItem(
              itineraryId: other.id, listEntryId: entryIdentifier,
              membershipId: membershipIdentifier)))
      else { throw CancellationError() }
      XCTAssertFalse(saved.localDone)
      XCTAssertFalse(saved.globalDone)
      XCTAssertFalse(saved.effectiveDone)
    }
  }

  private func invokeBulk(kind: String, fixture: EstimateResetIntentFixture) async throws {
    switch kind {
    case "list":
      let action = SetPlannerListChildCompletionIntent()
      action.list = .init(id: fixture.list.id, name: "Cached", archived: false)
      action.completed = true
      let _: Void = try await action.callAsFunction(donate: false)
    case "itinerary":
      let action = SetPlannerItineraryChildCompletionIntent()
      action.itinerary = .init(id: fixture.itinerary.id, title: "Cached", archived: false)
      action.completed = true
      let _: Void = try await action.callAsFunction(donate: false)
    default:
      let action = SetPlannerItineraryListChildCompletionIntent()
      action.itinerary = .init(id: fixture.itinerary.id, title: "Cached", archived: false)
      action.entry = .init(
        id:
          "v1/entry/\(fixture.itinerary.id)/\(fixture.firstBranchIdentifier)/list/\(fixture.list.id)",
        title: "Cached", context: "Cached", kind: .list, archived: false)
      action.completed = true
      let _: Void = try await action.callAsFunction(donate: false)
    }
  }

  private func scope(for name: String, fixture: EstimateResetIntentFixture) -> PlannerBulkScope {
    switch name {
    case "list": .list(listId: fixture.list.id)
    case "itinerary": .itinerary(itineraryId: fixture.itinerary.id)
    default:
      .itineraryListEntry(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.firstBranchIdentifier)
    }
  }

  private func submit(_ review: PlannerReview, store: SavedPlannerStore) async throws {
    let result = try await store.executeAppIntent(review.command, reviewToken: review.reviewToken)
    guard case .applied(_, .complete) = result.outcome else {
      return XCTFail("A separately submitted current review must apply completely.")
    }
  }

  private func backup(_ fixture: EstimateResetIntentFixture) async throws -> Data {
    guard case .exported(let data) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    return data
  }

  private func assertLocalStates(
    _ fixture: EstimateResetIntentFixture, expected: [Bool],
    planner: PlannerCore.Planner? = nil, session: PlannerDatasetSession? = nil
  ) async throws {
    let planner = planner ?? fixture.planner
    let session = session ?? fixture.session
    let appearances: [PlannerAppearance] = [
      .listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier),
      .listMembership(listId: fixture.list.id, membershipId: fixture.lunchMembershipIdentifier),
      .expandedListItem(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.firstBranchIdentifier,
        membershipId: fixture.membershipIdentifier),
      .expandedListItem(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.firstBranchIdentifier,
        membershipId: fixture.lunchMembershipIdentifier),
      .expandedListItem(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.secondBranchIdentifier,
        membershipId: fixture.membershipIdentifier),
      .expandedListItem(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.secondBranchIdentifier,
        membershipId: fixture.lunchMembershipIdentifier),
      .directItineraryItem(
        itineraryId: fixture.itinerary.id, entryId: fixture.directEntryIdentifier),
    ]
    for (appearance, done) in zip(appearances, expected) {
      guard
        case .appearance(let saved) = await planner.read(
          session: session, request: .appearance(appearance))
      else { throw CancellationError() }
      XCTAssertEqual(saved.localDone, done)
      XCTAssertFalse(saved.globalDone)
    }
  }
}
