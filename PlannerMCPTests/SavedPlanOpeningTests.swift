import AppIntents
import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class SavedPlanOpeningTests: XCTestCase {
  func testNewInactiveWindowDoesNotReplaceTheMostRecentlyFocusedRecipient() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let source = try await createOpeningPlan(.list, store: store)
    let opening = SavedPlanOpeningCoordinator()
    let focusedWindow = UUID()
    let newInactiveWindow = UUID()
    opening.register(windowIdentifier: focusedWindow, isActive: true, isReady: true)
    opening.register(windowIdentifier: focusedWindow, isActive: false, isReady: true)
    opening.register(windowIdentifier: newInactiveWindow, isActive: false, isReady: true)
    let request = try await opening.submit(source: source, store: store)
    XCTAssertEqual(request.windowIdentifier, focusedWindow)
    let inactiveClaim = try await opening.claim(windowIdentifier: newInactiveWindow, store: store)
    XCTAssertNil(inactiveClaim)
    let focusedClaim = try await opening.claim(windowIdentifier: focusedWindow, store: store)
    XCTAssertEqual(focusedClaim?.identifier, request.identifier)
  }

  func testConcurrentSubmissionAdmitsExactlyOneRequest() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let source = try await createOpeningPlan(.list, store: store)
    let opening = SavedPlanOpeningCoordinator()
    let first = Task { try await opening.submit(source: source, store: store) }
    let second = Task { try await opening.submit(source: source, store: store) }
    var admitted: [SavedPlanOpeningRequest] = []
    var rejected = 0
    for task in [first, second] {
      do { admitted.append(try await task.value) } catch {
        rejected += 1
        XCTAssertTrue(error.localizedDescription.contains("already"))
      }
    }
    XCTAssertEqual(admitted.count, 1)
    XCTAssertEqual(rejected, 1)
    XCTAssertEqual(opening.pending?.identifier, admitted.first?.identifier)
  }

  func testUnreadyWindowWaitsAndWrongResolutionCannotConsumeTheRequest() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let source = try await createOpeningPlan(.itinerary, store: store)
    let opening = SavedPlanOpeningCoordinator()
    let recipient = UUID()
    opening.register(windowIdentifier: recipient, isActive: true, isReady: false)
    let request = try await opening.submit(source: source, store: store)
    XCTAssertNil(opening.readyRequestIdentifier(for: recipient))
    let premature = try await opening.claim(windowIdentifier: recipient, store: store)
    XCTAssertNil(premature)
    opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
    XCTAssertEqual(opening.readyRequestIdentifier(for: recipient), request.identifier)
    _ = try await opening.claim(windowIdentifier: recipient, store: store)
    do {
      _ = try await opening.resolveNavigation(
        requestIdentifier: request.identifier, windowIdentifier: UUID(), store: store)
      XCTFail("A different window must not consume this request.")
    } catch { XCTAssertEqual(opening.pending?.identifier, request.identifier) }
    let resolved = try await opening.resolveNavigation(
      requestIdentifier: request.identifier, windowIdentifier: recipient, store: store)
    XCTAssertEqual(resolved, source)
  }

  func testMissingWrongKindPrecancelledAndUnavailableRequestsNeverQueueOrChangeData() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let source = try await createOpeningPlan(.list, store: store)
    let (planner, session) = try await store.appIntentContext()
    let before = try await openingBackup(planner, session: session)
    let opening = SavedPlanOpeningCoordinator()
    for invalid in [
      PlannerEntityReference(kind: .list, id: UUID()),
      .init(kind: .itinerary, id: source.id), .init(kind: .item, id: source.id),
    ] {
      do {
        _ = try await opening.submit(source: invalid, store: store)
        XCTFail("Opening must not substitute another plan or kind.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      XCTAssertNil(opening.pending)
    }
    let cancelled = Task { try await opening.submit(source: source, store: store) }
    cancelled.cancel()
    do {
      _ = try await cancelled.value
      XCTFail("Precancelled opening cannot enter the delivery queue.")
    } catch { XCTAssertNil(opening.pending) }
    let after = try await openingBackup(planner, session: session)
    XCTAssertEqual(after, before)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let obstruction = directory.appending(path: "store")
    let contents = Data("Store parent is a file".utf8)
    try contents.write(to: obstruction)
    do {
      _ = try await opening.submit(source: source, store: unavailable)
      XCTFail("Unavailable storage cannot acknowledge an opening request.")
    } catch { XCTAssertNil(opening.pending) }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
  }

  func testRenameAndArchiveKeepTheExactIdentityWhileARequestWaits() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let source = try await createOpeningPlan(.list, store: store)
    let sameName = try await createOpeningPlan(.list, store: store)
    let loaded = await store.readList(source.id)
    let original = try XCTUnwrap(loaded)
    let opening = SavedPlanOpeningCoordinator()
    let recipient = UUID()
    opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
    let request = try await opening.submit(source: source, store: store)
    _ = try await opening.claim(windowIdentifier: recipient, store: store)
    _ = try await store.executeAppIntent(
      .editList(
        sourceId: source.id, changes: .init(name: .set("Renamed exact plan")),
        expectedFieldHashes: original.fieldHashes))
    _ = try await store.executeAppIntent(.setArchive(source: source, archived: true))
    let resolved = try await opening.resolveNavigation(
      requestIdentifier: request.identifier, windowIdentifier: recipient, store: store)
    XCTAssertEqual(resolved, source)
    XCTAssertNotEqual(resolved, sameName)
    let current = await store.readList(source.id)
    XCTAssertEqual(current?.content.name, "Renamed exact plan")
    XCTAssertEqual(current?.state.archived, true)
  }

  func testDeletedAndExplicitlyRestoredPlansCannotConsumeAnOldRequest() async throws {
    for kind in [PlannerEntityKind.list, .itinerary] {
      let (_, _, store) = try makePlannerIntentStorage()
      let source = try await createOpeningPlan(kind, store: store)
      let (planner, session) = try await store.appIntentContext()
      let backup = try await openingBackup(planner, session: session)
      let opening = SavedPlanOpeningCoordinator()
      let recipient = UUID()
      opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
      let request = try await opening.submit(source: source, store: store)
      _ = try await opening.claim(windowIdentifier: recipient, store: store)
      try await executeReviewedOpeningSetup(.deleteSource(source: source), store: store)
      guard case .decoded(let decoded) = planner.decodeImport(backup) else {
        return XCTFail("The actual exported fixture must decode before explicit restoration.")
      }
      try await executeReviewedOpeningSetup(
        .applyImport(backup: decoded, mode: .overwrite, restoreDeletedData: true), store: store)
      do {
        _ = try await opening.resolveNavigation(
          requestIdentifier: request.identifier, windowIdentifier: recipient, store: store)
        XCTFail("A restored public identity has a new lifetime and needs a new opening request.")
      } catch { XCTAssertNil(opening.pending) }
      let newRequest = try await opening.submit(source: source, store: store)
      XCTAssertNotEqual(newRequest.sourceLifetimeIdentifier, request.sourceLifetimeIdentifier)
    }
  }

  func testDeletingTheTargetDuringADecisionNeverOpensASameNameSurvivor() async throws {
    for kind in [PlannerEntityKind.list, .itinerary] {
      let (_, _, store) = try makePlannerIntentStorage()
      let source = try await createOpeningPlan(kind, store: store)
      let survivor = try await createOpeningPlan(kind, store: store)
      let opening = SavedPlanOpeningCoordinator()
      let recipient = UUID()
      opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
      let request = try await opening.submit(source: source, store: store)
      _ = try await opening.claim(windowIdentifier: recipient, store: store)
      try await executeReviewedOpeningSetup(.deleteSource(source: source), store: store)
      do {
        _ = try await opening.resolveNavigation(
          requestIdentifier: request.identifier, windowIdentifier: recipient, store: store)
        XCTFail("Deletion must reject delayed navigation without choosing the same-name survivor.")
      } catch { XCTAssertNil(opening.pending) }
      let next = try await opening.submit(source: survivor, store: store)
      XCTAssertEqual(next.source, survivor)
    }
  }

  func testChangedDatasetRejectsDelayedNavigationWithoutChangingEitherDataset() async throws {
    let (_, _, originalStore) = try makePlannerIntentStorage()
    let source = try await createOpeningPlan(.itinerary, store: originalStore)
    let opening = SavedPlanOpeningCoordinator()
    let recipient = UUID()
    opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
    let request = try await opening.submit(source: source, store: originalStore)
    _ = try await opening.claim(windowIdentifier: recipient, store: originalStore)
    let (_, _, replacementStore) = try makePlannerIntentStorage()
    _ = try await createOpeningPlan(.list, store: replacementStore)
    let (planner, session) = try await replacementStore.appIntentContext()
    let before = try await openingBackup(planner, session: session)
    do {
      _ = try await opening.resolveNavigation(
        requestIdentifier: request.identifier, windowIdentifier: recipient, store: replacementStore)
      XCTFail("A delayed request cannot navigate against a different current dataset.")
    } catch { XCTAssertTrue(error.localizedDescription.contains("data changed")) }
    XCTAssertNil(opening.pending)
    let after = try await openingBackup(planner, session: session)
    XCTAssertEqual(after, before)
    let retained = await originalStore.readItinerary(source.id)
    XCTAssertNotNil(retained)
  }

  func testOpenItineraryIntentRetainsItsExactTargetAndRejectsMissingPlans() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let source = try await createOpeningPlan(.itinerary, store: store)
    let (planner, session) = try await store.appIntentContext()
    let before = try await openingBackup(planner, session: session)
    AppDependencyManager.shared.add(dependency: store)
    let opening = SavedPlanOpeningCoordinator()
    AppDependencyManager.shared.add(dependency: opening)
    let action = OpenPlannerItineraryIntent()
    action.target = .init(id: source.id, title: "Stale name", archived: false)
    try await executePlannerOpeningIntent(action)
    XCTAssertEqual(opening.pending?.source, source)
    XCTAssertFalse(try XCTUnwrap(opening.pending).isClaimed)
    let recipient = UUID()
    opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
    let identifier = try XCTUnwrap(opening.pending?.identifier)
    opening.cancel(requestIdentifier: identifier, windowIdentifier: recipient)
    action.target = .init(id: UUID(), title: "Opening fixture", archived: false)
    do {
      try await executePlannerOpeningIntent(action)
      XCTFail("A missing exact selection cannot use a surviving same-name Itinerary.")
    } catch { XCTAssertNil(opening.pending) }
    let after = try await openingBackup(planner, session: session)
    XCTAssertEqual(after, before)
  }

  func testOpenListIntentRequestsItsExactSavedIdentityWithoutClaimingNavigation() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let creation = CreatePlannerListIntent()
    creation.name = "Tokyo Food"
    AppDependencyManager.shared.add(dependency: store)
    let list = try await creation.callAsFunction(donate: false)
    let (planner, session) = try await store.appIntentContext()
    let before = try await openingBackup(planner, session: session)
    let opening = SavedPlanOpeningCoordinator()
    AppDependencyManager.shared.add(dependency: opening)
    let action = OpenPlannerListIntent()
    action.target = .init(id: list.id, name: "Stale title", archived: false)
    try await executePlannerOpeningIntent(action)
    XCTAssertEqual(opening.pending?.source, .init(kind: .list, id: list.id))
    XCTAssertFalse(try XCTUnwrap(opening.pending).isClaimed)
    XCTAssertNil(opening.pending?.windowIdentifier)
    let after = try await openingBackup(planner, session: session)
    XCTAssertEqual(after, before)
  }

  func testClosingOrCancellingTheRecipientNeverRedirectsItsPendingDraftDecision() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let creation = try await store.executeAppIntent(.createList(content: .init(name: "Origin")))
    guard case .applied(let applied, .complete) = creation.outcome else {
      return XCTFail("The source must be saved before testing its opening lifecycle.")
    }
    let source = try XCTUnwrap(applied.generated.first)
    let opening = SavedPlanOpeningCoordinator()
    let recipient = UUID()
    let other = UUID()
    opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
    opening.register(windowIdentifier: other, isActive: false, isReady: true)
    let request = try await opening.submit(source: source, store: store)
    _ = try await opening.claim(windowIdentifier: recipient, store: store)
    opening.cancel(requestIdentifier: request.identifier, windowIdentifier: other)
    XCTAssertEqual(opening.pending?.identifier, request.identifier)
    opening.unregister(windowIdentifier: recipient)
    XCTAssertNil(opening.pending)
    let redirected = try await opening.claim(windowIdentifier: other, store: store)
    XCTAssertNil(redirected)
    do {
      _ = try await opening.resolveNavigation(
        requestIdentifier: request.identifier, windowIdentifier: recipient, store: store)
      XCTFail("A closed recipient cannot finish navigating later.")
    } catch { XCTAssertNil(opening.pending) }
    let next = try await opening.submit(source: source, store: store)
    XCTAssertEqual(next.windowIdentifier, other)
    _ = try await opening.claim(windowIdentifier: other, store: store)
    opening.cancel(requestIdentifier: next.identifier, windowIdentifier: other)
    XCTAssertNil(opening.pending)
    let retry = try await opening.submit(source: source, store: store)
    XCTAssertNotEqual(retry.identifier, next.identifier)
  }

  func testForegroundRecipientKeepsItsRequestWhenAnotherOpeningArrives() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let creation = try await store.executeAppIntent(
      .createItinerary(content: .init(title: "Weekend")))
    guard case .applied(let applied, .complete) = creation.outcome else {
      return XCTFail("The Itinerary must be durably saved before opening.")
    }
    let source = try XCTUnwrap(applied.generated.first { $0.kind == .itinerary })
    let opening = SavedPlanOpeningCoordinator()
    let first = UUID()
    let second = UUID()
    opening.register(windowIdentifier: first, isActive: true, isReady: true)
    opening.register(windowIdentifier: second, isActive: false, isReady: true)
    opening.register(windowIdentifier: first, isActive: false, isReady: true)
    opening.register(windowIdentifier: second, isActive: true, isReady: true)
    let request = try await opening.submit(source: source, store: store)
    XCTAssertEqual(request.windowIdentifier, second)
    do {
      _ = try await opening.submit(source: source, store: store)
      XCTFail("A second external request must not replace a pending draft decision.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("already"))
    }
    XCTAssertEqual(opening.pending?.identifier, request.identifier)
    let otherClaim = try await opening.claim(windowIdentifier: first, store: store)
    XCTAssertNil(otherClaim)
    let claim = try await opening.claim(windowIdentifier: second, store: store)
    XCTAssertEqual(claim?.identifier, request.identifier)
  }

  func testColdRequestWaitsForOneReadyWindowAndResolvesOnlyItsExactPlan() async throws {
    let (_, _, store) = try makePlannerIntentStorage()
    let result = try await store.executeAppIntent(.createList(content: .init(name: "Tokyo Food")))
    guard case .applied(let applied, .complete) = result.outcome else {
      return XCTFail("The exact saved List must exist before requesting navigation.")
    }
    let source = try XCTUnwrap(applied.generated.first { $0.kind == .list })
    let opening = SavedPlanOpeningCoordinator()
    let request = try await opening.submit(source: source, store: store)
    XCTAssertEqual(opening.pending?.identifier, request.identifier)
    XCTAssertNil(opening.pending?.windowIdentifier)
    let recipient = UUID()
    let otherWindow = UUID()
    opening.register(windowIdentifier: recipient, isActive: true, isReady: true)
    opening.register(windowIdentifier: otherWindow, isActive: false, isReady: true)
    let otherClaim = try await opening.claim(windowIdentifier: otherWindow, store: store)
    XCTAssertNil(otherClaim)
    let claim = try await opening.claim(windowIdentifier: recipient, store: store)
    XCTAssertEqual(claim?.identifier, request.identifier)
    let repeatedClaim = try await opening.claim(windowIdentifier: recipient, store: store)
    XCTAssertNil(repeatedClaim)
    XCTAssertNotNil(opening.pending)
    let target = try await opening.resolveNavigation(
      requestIdentifier: request.identifier, windowIdentifier: recipient, store: store)
    XCTAssertEqual(target, source)
    XCTAssertNil(opening.pending)
  }
}

/// Keeps Apple's dependency initialization while disambiguating its void-returning overload.
@MainActor
private func executePlannerOpeningIntent<OpeningIntent: AppIntent>(_ intent: OpeningIntent)
  async throws where OpeningIntent.PerformResult.Value == Never
{
  try await intent.callAsFunction(donate: false)
}

@MainActor
private func createOpeningPlan(_ kind: PlannerEntityKind, store: SavedPlannerStore) async throws
  -> PlannerEntityReference
{
  let command: PlannerCommand
  switch kind {
  case .list: command = .createList(content: .init(name: "Opening fixture"))
  case .itinerary: command = .createItinerary(content: .init(title: "Opening fixture"))
  default: throw CancellationError()
  }
  let result = try await store.executeAppIntent(command)
  guard case .applied(let applied, .complete) = result.outcome,
    let source = applied.generated.first(where: { $0.kind == kind })
  else { throw CancellationError() }
  return source
}

@MainActor
private func executeReviewedOpeningSetup(_ command: PlannerCommand, store: SavedPlannerStore)
  async throws
{
  let (planner, session) = try await store.appIntentContext()
  guard case .reviewed(let review) = await planner.prepareReview(session: session, command: command)
  else { throw CancellationError() }
  let result = try await store.executeAppIntent(command, reviewToken: review.reviewToken)
  guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
}

private func openingBackup(_ planner: PlannerCore.Planner, session: PlannerDatasetSession)
  async throws -> Data
{
  guard case .exported(let data) = await planner.exportData(session: session) else {
    throw CancellationError()
  }
  return data
}
