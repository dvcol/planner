import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerListReorderIntentTests: XCTestCase {
  func testUnavailableStorageCannotAcknowledgeReordering() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let reordering = ReorderPlannerItemInListIntent()
    reordering.item = .init(id: UUID(), title: "Museum", done: false, archived: false)
    reordering.list = .init(id: UUID(), name: "Unavailable", archived: false)
    reordering.position = .first
    do {
      let _: Void = try await reordering.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a saved-order change.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testAppliedReorderSurvivesRecoveryFailureAndNativeRetryDoesNotReplayIt() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let first = try await save(.createItem(content: .init(title: "Alpha")))
    let alpha = try XCTUnwrap(first.generated.first)
    let second = try await save(
      .createItem(content: .init(title: "Beta", notes: "Keep shared notes")))
    let beta = try XCTUnwrap(second.generated.first)
    let created = try await save(.createList(content: .init(name: "Route choices")))
    let list = try XCTUnwrap(created.generated.first)
    let alphaMembership = try await save(
      .addMembership(itemId: alpha.id, listId: list.id, placement: .last))
    let betaMembership = try await save(
      .addMembership(itemId: beta.id, listId: list.id, placement: .last))
    guard case .membership(let identifier, _, _)? = betaMembership.generatedReferences.first
    else { return XCTFail("The selected membership must retain a stable identity.") }
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: identifier)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    guard
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(beta))
    else { return XCTFail("Shared content must be durable before the fault.") }
    await store.open()
    XCTAssertTrue(store.isReady)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let reordering = ReorderPlannerItemInListIntent()
    reordering.item = .init(id: beta.id, title: "Beta", done: false, archived: false)
    reordering.list = .init(id: list.id, name: "Route choices", archived: false)
    reordering.position = .before
    reordering.relativeItem = .init(id: alpha.id, title: "Alpha", done: false, archived: false)
    let _: Void = try await reordering.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    reordering.position = .last
    reordering.relativeItem = nil
    do {
      let _: Void = try await reordering.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block a second reorder without losing the applied order.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let appliedList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(beta)),
      case .appearance(let appliedState) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance))
    else {
      return XCTFail("The applied order and original shared data must survive recovery failure.")
    }
    XCTAssertEqual(
      appliedList.references,
      betaMembership.generatedReferences + alphaMembership.generatedReferences)
    XCTAssertEqual(retained.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(retained.updatedAt, beforeItem.updatedAt)
    XCTAssertTrue(appliedState.localDone)
    XCTAssertTrue(appliedState.effectiveDone)
    XCTAssertFalse(appliedState.globalDone)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier),
      case .source(.list(let recovered)) = await reopened.read(
        session: reopenedSession, request: .source(list))
    else {
      return XCTFail("Native retry must acknowledge the original operation without a new reorder.")
    }
    XCTAssertEqual(recovered.references, appliedList.references)
    XCTAssertEqual(recovered.updatedAt, appliedList.updatedAt)
    let _: Void = try await reordering.callAsFunction(donate: false)
    guard
      case .source(.list(let finalList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let finalState) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance))
    else { return XCTFail("An explicit subsequent End placement must work after native recovery.") }
    XCTAssertEqual(
      finalList.references, alphaMembership.generatedReferences + betaMembership.generatedReferences
    )
    XCTAssertTrue(finalState.localDone)
    XCTAssertTrue(finalState.effectiveDone)
    XCTAssertFalse(finalState.globalDone)
    XCTAssertEqual(finalState.content.notes, "Keep shared notes")
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledReorderKeepsAValidSavedOrderAndMembershipFlags() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let first = try await save(.createItem(content: .init(title: "Alpha")))
    let alpha = try XCTUnwrap(first.generated.first)
    let second = try await save(.createItem(content: .init(title: "Beta")))
    let beta = try XCTUnwrap(second.generated.first)
    let created = try await save(.createList(content: .init(name: "Route choices")))
    let list = try XCTUnwrap(created.generated.first)
    _ = try await save(.addMembership(itemId: alpha.id, listId: list.id, placement: .last))
    let selected = try await save(
      .addMembership(itemId: beta.id, listId: list.id, placement: .last))
    guard case .membership(let identifier, _, _)? = selected.generatedReferences.first,
      case .source(.list(let before)) = await planner.read(session: session, request: .source(list))
    else { return XCTFail("Cancellation must target an otherwise valid reorder.") }
    let reordering = ReorderPlannerItemInListIntent()
    reordering.item = .init(id: beta.id, title: "Beta", done: false, archived: false)
    reordering.list = .init(id: list.id, name: "Route choices", archived: false)
    reordering.position = .before
    reordering.relativeItem = .init(id: alpha.id, title: "Alpha", done: false, archived: false)
    let request = Task {
      let _: Void = try await reordering.callAsFunction(donate: false)
    }
    request.cancel()
    do {
      let _: Void = try await request.value
      XCTFail("Pre-invocation cancellation cannot acknowledge a saved-order change.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let after)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let state) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: identifier)))
    else { return XCTFail("The unchanged original order and context must survive reopening.") }
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertEqual(after.progress.doneCount, 0)
    XCTAssertFalse(state.globalDone)
    XCTAssertFalse(state.localDone)
    XCTAssertFalse(state.effectiveDone)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testInvalidMissingRemovedAndDeletedTargetsOrAnchorsLeaveNoPartialOrderOrMemberships()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let first = try await save(.createItem(content: .init(title: "Alpha")))
    let alpha = try XCTUnwrap(first.generated.first)
    let second = try await save(.createItem(content: .init(title: "Beta")))
    let beta = try XCTUnwrap(second.generated.first)
    let third = try await save(.createItem(content: .init(title: "Gamma")))
    let gamma = try XCTUnwrap(third.generated.first)
    let fourth = try await save(
      .createItem(content: .init(title: "Delta", notes: "Unrelated source")))
    let delta = try XCTUnwrap(fourth.generated.first)
    let created = try await save(.createList(content: .init(name: "Source")))
    let list = try XCTUnwrap(created.generated.first)
    let createdOther = try await save(.createList(content: .init(name: "Other")))
    let otherList = try XCTUnwrap(createdOther.generated.first)
    let firstMembership = try await save(
      .addMembership(itemId: alpha.id, listId: list.id, placement: .last))
    let selectedMembership = try await save(
      .addMembership(itemId: beta.id, listId: list.id, placement: .last))
    _ = try await save(.addMembership(itemId: gamma.id, listId: list.id, placement: .last))
    let foreignMembership = try await save(
      .addMembership(itemId: delta.id, listId: otherList.id, placement: .last))
    guard case .membership(let alphaIdentifier, _, _)? = firstMembership.generatedReferences.first,
      case .membership(let betaIdentifier, _, _)? = selectedMembership.generatedReferences.first
    else { return XCTFail("The original source memberships must exist before rejection checks.") }
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: betaIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    guard
      case .source(.list(let before)) = await planner.read(session: session, request: .source(list))
    else { return XCTFail("The original saved order must be readable.") }
    let selected = PlannerItemEntity(id: beta.id, title: "Beta", done: false, archived: false)
    let anchor = PlannerItemEntity(id: alpha.id, title: "Alpha", done: false, archived: false)
    let listEntity = PlannerListEntity(id: list.id, name: "Source", archived: false)
    func requireRejected(
      item: PlannerItemEntity, list: PlannerListEntity, position: PlannerListReorderPosition,
      relative: PlannerItemEntity?
    ) async {
      let reordering = ReorderPlannerItemInListIntent()
      reordering.item = item
      reordering.list = list
      reordering.position = position
      reordering.relativeItem = relative
      do {
        let _: Void = try await reordering.callAsFunction(donate: false)
        XCTFail("Invalid reorder input cannot change order, create a membership or change scope.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    for position in [PlannerListReorderPosition.before, .after] {
      await requireRejected(item: selected, list: listEntity, position: position, relative: nil)
      await requireRejected(
        item: selected, list: listEntity, position: position, relative: selected)
      await requireRejected(
        item: selected, list: listEntity, position: position,
        relative: .init(id: delta.id, title: "Foreign", done: false, archived: false))
      await requireRejected(
        item: selected, list: listEntity, position: position,
        relative: .init(id: UUID(), title: "Missing", done: false, archived: false))
      await requireRejected(
        item: selected, list: listEntity, position: position,
        relative: .init(id: list.id, title: "Wrong kind", done: false, archived: false))
    }
    for identifier in [UUID(), list.id] {
      await requireRejected(
        item: .init(id: identifier, title: "Unavailable", done: false, archived: false),
        list: listEntity, position: .first, relative: nil)
    }
    for identifier in [UUID(), beta.id] {
      await requireRejected(
        item: selected, list: .init(id: identifier, name: "Unavailable", archived: false),
        position: .first, relative: nil)
    }
    guard
      case .source(.list(let afterInvalid)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.list(let untouchedOther)) = await planner.read(
        session: session, request: .source(otherList))
    else { return XCTFail("Rejected requests must leave both Lists readable and unchanged.") }
    XCTAssertEqual(afterInvalid.references, before.references)
    XCTAssertEqual(afterInvalid.updatedAt, before.updatedAt)
    XCTAssertEqual(untouchedOther.references, foreignMembership.generatedReferences)
    _ = try await save(.removeMembership(listId: list.id, membershipId: alphaIdentifier))
    await requireRejected(item: selected, list: listEntity, position: .before, relative: anchor)
    func delete(_ source: PlannerEntityReference) async throws {
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .deleteSource(source: source)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: .deleteSource(source: source),
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    try await delete(gamma)
    await requireRejected(
      item: selected, list: listEntity, position: .after,
      relative: .init(id: gamma.id, title: "Deleted", done: false, archived: false))
    guard
      case .appearance(let unchanged) = await planner.read(
        session: session, request: .appearance(appearance))
    else {
      return XCTFail(
        "The selected context must remain complete while invalid anchors are rejected.")
    }
    XCTAssertTrue(unchanged.localDone)
    XCTAssertFalse(unchanged.globalDone)
    _ = try await save(.removeMembership(listId: list.id, membershipId: betaIdentifier))
    await requireRejected(item: selected, list: listEntity, position: .first, relative: nil)
    try await delete(beta)
    await requireRejected(item: selected, list: listEntity, position: .last, relative: nil)
    try await delete(otherList)
    await requireRejected(
      item: selected, list: .init(id: otherList.id, name: "Deleted", archived: false),
      position: .first, relative: nil)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.item(let retainedDelta)) = await reopened.read(
        session: reopenedSession, request: .source(delta)),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all)))),
      case .snapshot(let lists) = await reopened.query(
        .init(session: reopenedSession, request: .catalog(.init(sourceKind: .list, archive: .all))))
    else { return XCTFail("Removed/deleted references must stay absent without recreating data.") }
    XCTAssertTrue(retained.references.isEmpty)
    XCTAssertEqual(retained.progress.state, .empty)
    XCTAssertEqual(retainedDelta.content.notes, "Unrelated source")
    XCTAssertEqual(retainedDelta.state.globalDone, false)
    XCTAssertEqual(items.rows, [.source(alpha), .source(delta)])
    XCTAssertEqual(lists.rows, [.source(list)])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testBeginningEndAndAfterUseSavedOrderAndPreserveMembershipState() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let first = try await save(.createItem(content: .init(title: "Alpha")))
    let alpha = try XCTUnwrap(first.generated.first)
    let second = try await save(.createItem(content: .init(title: "Beta")))
    let beta = try XCTUnwrap(second.generated.first)
    let third = try await save(.createItem(content: .init(title: "Gamma")))
    let gamma = try XCTUnwrap(third.generated.first)
    let created = try await save(.createList(content: .init(name: "Route choices")))
    let list = try XCTUnwrap(created.generated.first)
    let alphaMembership = try await save(
      .addMembership(itemId: alpha.id, listId: list.id, placement: .last))
    let betaMembership = try await save(
      .addMembership(itemId: beta.id, listId: list.id, placement: .last))
    let gammaMembership = try await save(
      .addMembership(itemId: gamma.id, listId: list.id, placement: .last))
    guard case .membership(let betaIdentifier, _, _)? = betaMembership.generatedReferences.first
    else { return XCTFail("The selected membership must have a saved identity.") }
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: betaIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    let reordering = ReorderPlannerItemInListIntent()
    reordering.item = .init(id: beta.id, title: "Beta", done: false, archived: false)
    reordering.list = .init(id: list.id, name: "Route choices", archived: false)
    let inactiveSelection = PlannerItemEntity(
      id: UUID(), title: "Inactive missing relative Item", done: false, archived: false)
    let requests: [(PlannerListReorderPosition, PlannerItemEntity?, [PlannerReferenceRead])] = [
      (
        .first, inactiveSelection,
        betaMembership.generatedReferences + alphaMembership.generatedReferences
          + gammaMembership.generatedReferences
      ),
      (
        .last, nil,
        alphaMembership.generatedReferences + gammaMembership.generatedReferences
          + betaMembership.generatedReferences
      ),
      (
        .after, .init(id: alpha.id, title: "Alpha", done: false, archived: false),
        alphaMembership.generatedReferences + betaMembership.generatedReferences
          + gammaMembership.generatedReferences
      ),
    ]
    for (position, relativeItem, expectedReferences) in requests {
      reordering.position = position
      reordering.relativeItem = relativeItem
      let _: Void = try await reordering.callAsFunction(donate: false)
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.list(let current)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .appearance(let state) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else {
        return XCTFail("Every placement must persist its order under the original identities.")
      }
      XCTAssertEqual(current.references, expectedReferences)
      XCTAssertEqual(current.references.count, 3)
      XCTAssertEqual(current.progress.doneCount, 1)
      XCTAssertTrue(state.localDone)
      XCTAssertTrue(state.effectiveDone)
      XCTAssertFalse(state.globalDone)
      XCTAssertEqual(state.source, beta)
    }
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testBeforePlacementPreservesIdentitiesContextsContentEstimatesAndScheduleAfterReopen()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let createdAlpha = try await save(
      .createItem(
        content: .init(title: "Alpha", estimate: .init(minutes: 15, displayUnit: .minute))))
    let alpha = try XCTUnwrap(createdAlpha.generated.first)
    let createdMiddle = try await save(
      .createItem(
        content: .init(title: "Middle", estimate: .init(minutes: 30, displayUnit: .minute))))
    let middle = try XCTUnwrap(createdMiddle.generated.first)
    let createdZulu = try await save(
      .createItem(
        content: .init(
          title: "Zulu", notes: "Shared notes", estimate: .init(minutes: 45, displayUnit: .minute)))
    )
    let zulu = try XCTUnwrap(createdZulu.generated.first)
    let createdList = try await save(.createList(content: .init(name: "Tokyo Food")))
    let list = try XCTUnwrap(createdList.generated.first)
    let createdOther = try await save(.createList(content: .init(name: "Wishlist")))
    let otherList = try XCTUnwrap(createdOther.generated.first)
    let alphaMembership = try await save(
      .addMembership(itemId: alpha.id, listId: list.id, placement: .last))
    let middleMembership = try await save(
      .addMembership(itemId: middle.id, listId: list.id, placement: .last))
    let zuluMembership = try await save(
      .addMembership(itemId: zulu.id, listId: list.id, placement: .last))
    let otherMembership = try await save(
      .addMembership(itemId: zulu.id, listId: otherList.id, placement: .last))
    guard case .membership(let alphaIdentifier, _, _)? = alphaMembership.generatedReferences.first,
      case .membership(let middleIdentifier, _, _)? = middleMembership.generatedReferences.first,
      case .membership(let zuluIdentifier, _, _)? = zuluMembership.generatedReferences.first,
      case .membership(let otherIdentifier, _, _)? = otherMembership.generatedReferences.first
    else { return XCTFail("Each source membership must retain its own identity.") }
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: zuluIdentifier)
    let otherAppearance = PlannerAppearance.listMembership(
      listId: otherList.id, membershipId: otherIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    _ = try await save(.setArchive(source: alpha, archived: true))
    let createdPlan = try await save(.createItinerary(content: .init(title: "Tokyo Weekend")))
    let itinerary = try XCTUnwrap(createdPlan.generated.first)
    let listEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let directEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: zulu, placement: .last))
    guard
      case .itineraryEntry(let listEntryIdentifier, _, _)? = listEntry.generatedReferences.first,
      case .itineraryEntry(let directIdentifier, _, _)? = directEntry.generatedReferences.first
    else { return XCTFail("The route must retain direct and expanded references.") }
    let expanded = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: listEntryIdentifier, membershipId: zuluIdentifier)
    let direct = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: directIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(direct), done: true))
    let form = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
    let booking = try await save(.createSchedule(source: zulu, form: form))
    let schedule = try XCTUnwrap(booking.generated.first)
    guard
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(zulu)),
      case .source(.list(let beforeList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let beforePlan)) = await planner.read(
        session: session, request: .source(itinerary))
    else { return XCTFail("The rich graph must be readable before reordering.") }
    let reordering = ReorderPlannerItemInListIntent()
    reordering.item = .init(
      id: zulu.id, title: "Obsolete selected title", done: true, archived: true)
    reordering.list = .init(id: list.id, name: "Obsolete List name", archived: true)
    reordering.position = .before
    reordering.relativeItem = .init(
      id: middle.id, title: "Obsolete anchor title", done: true, archived: true)
    let _: Void = try await reordering.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let afterItem)) = await reopened.read(
        session: reopenedSession, request: .source(zulu)),
      case .source(.list(let afterList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.list(let afterOther)) = await reopened.read(
        session: reopenedSession, request: .source(otherList)),
      case .source(.itinerary(let afterPlan)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.schedule(let afterSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .snapshot(let manual) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual))))),
      case .snapshot(let alphabetical) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(.init(scope: .list(list.id), completion: .all, archive: .all))))
    else { return XCTFail("The saved order and unchanged graph must survive reopening.") }
    XCTAssertEqual(
      afterList.references,
      alphaMembership.generatedReferences + zuluMembership.generatedReferences
        + middleMembership.generatedReferences + listEntry.generatedReferences)
    XCTAssertEqual(afterList.content, beforeList.content)
    XCTAssertEqual(afterList.progress.doneCount, beforeList.progress.doneCount)
    XCTAssertEqual(afterList.progress.archivedCount, beforeList.progress.archivedCount)
    XCTAssertEqual(afterList.estimates.fullEstimate, beforeList.estimates.fullEstimate)
    XCTAssertEqual(afterList.estimates.remainingEstimate, beforeList.estimates.remainingEstimate)
    XCTAssertEqual(afterList.state.archived, false)
    XCTAssertEqual(afterOther.references, otherMembership.generatedReferences)
    XCTAssertEqual(afterPlan.references, beforePlan.references)
    XCTAssertEqual(afterPlan.progress.doneCount, beforePlan.progress.doneCount)
    XCTAssertEqual(afterPlan.estimates.fullEstimate, beforePlan.estimates.fullEstimate)
    XCTAssertEqual(afterPlan.estimates.remainingEstimate, beforePlan.estimates.remainingEstimate)
    XCTAssertEqual(afterItem.content.title, "Zulu")
    XCTAssertEqual(afterItem.content.notes, "Shared notes")
    XCTAssertEqual(afterItem.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(afterItem.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(afterItem.state.globalDone, false)
    XCTAssertEqual(afterItem.state.archived, false)
    XCTAssertEqual(afterSchedule.content.form, form)
    XCTAssertEqual(
      manual.rows,
      [
        .appearance(
          source: alpha, appearance: .listMembership(listId: list.id, membershipId: alphaIdentifier)
        ),
        .appearance(
          source: zulu, appearance: .listMembership(listId: list.id, membershipId: zuluIdentifier)),
        .appearance(
          source: middle,
          appearance: .listMembership(listId: list.id, membershipId: middleIdentifier)),
      ])
    XCTAssertEqual(
      alphabetical.rows,
      [
        .appearance(
          source: alpha, appearance: .listMembership(listId: list.id, membershipId: alphaIdentifier)
        ),
        .appearance(
          source: middle,
          appearance: .listMembership(listId: list.id, membershipId: middleIdentifier)),
        .appearance(
          source: zulu, appearance: .listMembership(listId: list.id, membershipId: zuluIdentifier)),
      ])
    for (context, expectedDone) in [
      (appearance, true), (otherAppearance, false), (expanded, false), (direct, true),
    ] {
      guard
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(context))
      else { return XCTFail("Reordering must preserve each completion context.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, expectedDone)
      XCTAssertEqual(current.effectiveDone, expectedDone)
    }
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }
}
