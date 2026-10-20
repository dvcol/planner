import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerCategoryIntentTests: XCTestCase {
  func testCreateCategoryReturnsSavedIdentityAndPreservesItsContentAfterReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerCategoryIntent()
    creation.name = "Museums"
    let category = try await creation.callAsFunction(donate: false)
    XCTAssertEqual(category.name, "Museums")
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.category(let current)) = await reopened.read(
        session: session, request: .source(.init(kind: .category, id: category.id))),
      case .snapshot(let catalog) = await reopened.query(
        .init(session: session, request: .catalog(.init(sourceKind: .category, archive: .all))))
    else { return XCTFail("The returned Category must be readable from reopened real storage.") }
    XCTAssertEqual(current.source.id, category.id)
    XCTAssertEqual(current.content.name, "Museums")
    XCTAssertNil(current.content.color)
    XCTAssertNil(current.content.iconName)
    XCTAssertNil(current.state.archived)
    XCTAssertNil(current.state.globalDone)
    XCTAssertTrue(current.references.isEmpty)
    XCTAssertEqual(catalog.rows, [.source(.init(kind: .category, id: category.id))])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testSameNameCategoriesKeepDistinctIdentitiesAndCanonicalTieOrder() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerCategoryIntent()
    creation.name = "Museums"
    let first = try await creation.callAsFunction(donate: false)
    let second = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(first.id, second.id)
    let query = PlannerCategoryEntityQuery()
    query.plannerStore = store
    let choices = try await query.entities(matching: "MUSEUMS")
    let expectedIdentifiers = [first.id, second.id].sorted { firstIdentifier, secondIdentifier in
      firstIdentifier.uuidString < secondIdentifier.uuidString
    }
    XCTAssertEqual(choices.map(\.id), expectedIdentifiers)
    XCTAssertEqual(choices.map(\.name), ["Museums", "Museums"])
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.category(let firstSource)) = await reopened.read(
        session: session, request: .source(.init(kind: .category, id: first.id))),
      case .source(.category(let secondSource)) = await reopened.read(
        session: session, request: .source(.init(kind: .category, id: second.id)))
    else { return XCTFail("Same-name Categories must retain separate saved sources.") }
    XCTAssertEqual(firstSource.content.name, "Museums")
    XCTAssertEqual(secondSource.content.name, "Museums")
    XCTAssertNotEqual(firstSource.sourceLifetimeId, secondSource.sourceLifetimeId)
    XCTAssertTrue(firstSource.references.isEmpty)
    XCTAssertTrue(secondSource.references.isEmpty)
  }

  func testIdentityLookupAndGetReturnLiveNamesInRequestedOrderWithoutWrongKindSources() async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerCategoryIntent()
    creation.name = "Original category"
    let cached = try await creation.callAsFunction(donate: false)
    creation.name = "Second category"
    let second = try await creation.callAsFunction(donate: false)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "This is an Item, not a Category"
    let item = try await itemCreation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .category, id: cached.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.category(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editCategory(
            sourceId: cached.id, changes: .init(name: .set("Renamed category")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else {
      return XCTFail("The canonical shared Category must change before resolving its entity.")
    }
    let query = PlannerCategoryEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(
      for: [second.id, UUID(), cached.id, second.id, item.id, cached.id])
    XCTAssertEqual(resolved.map(\.id), [second.id, cached.id])
    XCTAssertEqual(resolved.map(\.name), ["Second category", "Renamed category"])
    let reading = GetPlannerCategoryIntent()
    reading.category = cached
    let current = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(current.id, cached.id)
    XCTAssertEqual(current.name, "Renamed category")
    reading.category = .init(id: UUID(), name: "Missing")
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Get Category must reject a missing identity without substituting another source.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testCategoryChoicesUseCanonicalInsensitiveCumulativeSearchAndReadEveryPage() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var identifiers: [UUID] = []
    for index in 0..<65 {
      guard
        case .applied(let created, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createCategory(
              content: .init(name: String(format: "Café %02d museums", index))))
        ).outcome, let source = created.generated.first
      else { return XCTFail("Every canonical Category must save before querying choices.") }
      identifiers.append(source.id)
    }
    let query = PlannerCategoryEntityQuery()
    query.plannerStore = store
    let matches = try await query.entities(matching: "MUSEUMS cafe")
    XCTAssertEqual(matches.map(\.id), identifiers)
    XCTAssertEqual(matches.first?.name, "Café 00 museums")
    XCTAssertEqual(matches.last?.name, "Café 64 museums")
    XCTAssertEqual(Set(matches.map(\.id)).count, 65)
    let suggestions = try await query.suggestedEntities()
    XCTAssertEqual(suggestions.map(\.id), identifiers)
    let absent = try await query.entities(matching: "cafe nonexistent")
    XCTAssertTrue(absent.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testInvalidAndPrecancelledCreationLeaveNoSavedCategories() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerCategoryIntent()
    creation.name = " \n\t "
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("A blank Category name cannot acknowledge creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    creation.name = "Cancelled before invocation"
    let request = Task { try await creation.callAsFunction(donate: false) }
    request.cancel()
    do {
      _ = try await request.value
      XCTFail("A cancelled invocation must not start Category creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let query = PlannerCategoryEntityQuery()
    query.plannerStore = store
    let choices = try await query.suggestedEntities()
    XCTAssertTrue(choices.isEmpty)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(session: session, request: .catalog(.init(sourceKind: .category, archive: .all))))
    else { return XCTFail("Invalid/cancelled requests must leave inspectable storage.") }
    XCTAssertTrue(catalog.rows.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testDeletedCategoryStaysMissingWithoutAffectingTheSurvivingSource() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerCategoryIntent()
    creation.name = "Removed category"
    let removed = try await creation.callAsFunction(donate: false)
    creation.name = "Surviving category"
    let survivor = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .category, id: removed.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: source),
          reviewToken: review.reviewToken)
      ).outcome
    else { return XCTFail("Native reviewed deletion must remove the selected Category first.") }
    let query = PlannerCategoryEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(for: [removed.id, survivor.id, UUID()])
    XCTAssertEqual(resolved.map(\.id), [survivor.id])
    let reading = GetPlannerCategoryIntent()
    reading.category = removed
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Get cannot recreate a deleted Category or substitute another source.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .category, archive: .all))))
    else { return XCTFail("The Category catalog must remain readable after native deletion.") }
    XCTAssertEqual(catalog.rows, [.source(.init(kind: .category, id: survivor.id))])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testUnavailableStorageThrowsForChoicesIdentityGetAndCreation() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let query = PlannerCategoryEntityQuery()
    query.plannerStore = store
    func requireUnavailable(_ request: () async throws -> [PlannerCategoryEntity]) async {
      do {
        _ = try await request()
        XCTFail("Unavailable storage must not become empty successful Category data.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    await requireUnavailable { try await query.suggestedEntities() }
    await requireUnavailable { try await query.entities(matching: "Museums") }
    await requireUnavailable { try await query.entities(for: [UUID()]) }
    let reading = GetPlannerCategoryIntent()
    reading.category = .init(id: UUID(), name: "Unavailable")
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("An unavailable store cannot acknowledge a successful Category read.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let creation = CreatePlannerCategoryIntent()
    creation.name = "Cannot save here"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("An unavailable store cannot acknowledge Category creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testAppliedCreationWithIncompleteRecoveryRetainsItsIdentityWithoutReplaying() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
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
    let creation = CreatePlannerCategoryIntent()
    creation.name = "Recovery category"
    let applied = try await creation.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    let query = PlannerCategoryEntityQuery()
    query.plannerStore = store
    let readable = try await query.suggestedEntities()
    XCTAssertEqual(readable.map(\.id), [applied.id])
    creation.name = "Blocked category"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block another creation without duplicating the Category.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.category(let retained)) = await reopened.read(
        session: session, request: .source(.init(kind: .category, id: applied.id)))
    else { return XCTFail("The returned Category must remain saved despite incomplete recovery.") }
    XCTAssertEqual(retained.content.name, "Recovery category")
    XCTAssertNil(retained.state.globalDone)
    XCTAssertNil(retained.state.archived)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete(let recovered, _) = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.category(let afterRecovery)) = await reopened.read(
        session: session, request: .source(.init(kind: .category, id: applied.id)))
    else { return XCTFail("Native retry must acknowledge the original Category creation.") }
    XCTAssertEqual(recovered.generated, [.init(kind: .category, id: applied.id)])
    XCTAssertEqual(afterRecovery.createdAt, retained.createdAt)
    XCTAssertEqual(afterRecovery.updatedAt, retained.updatedAt)
    let afterRecoveryChoices = try await query.suggestedEntities()
    XCTAssertEqual(afterRecoveryChoices.map(\.id), [applied.id])
    creation.name = "Allowed category"
    let next = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(next.id, applied.id)
    let finalChoices = try await query.suggestedEntities()
    XCTAssertEqual(finalChoices.map(\.id), [next.id, applied.id])
    XCTAssertFalse(store.isSaving)
  }
}
