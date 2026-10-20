import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerTagIntentTests: XCTestCase {
  func testCreateTagReturnsSavedIdentityAndPreservesItsContentAfterReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerTagIntent()
    creation.name = "rainy-day"
    let tag = try await creation.callAsFunction(donate: false)
    XCTAssertEqual(tag.name, "rainy-day")
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.tag(let current)) = await reopened.read(
        session: session, request: .source(.init(kind: .tag, id: tag.id))),
      case .snapshot(let catalog) = await reopened.query(
        .init(session: session, request: .catalog(.init(sourceKind: .tag, archive: .all))))
    else { return XCTFail("The returned Tag must be readable from reopened real storage.") }
    XCTAssertEqual(current.source.id, tag.id)
    XCTAssertEqual(current.content.name, "rainy-day")
    XCTAssertNil(current.content.color)
    XCTAssertNil(current.content.iconName)
    XCTAssertNil(current.state.archived)
    XCTAssertNil(current.state.globalDone)
    XCTAssertTrue(current.references.isEmpty)
    XCTAssertEqual(catalog.rows, [.source(.init(kind: .tag, id: tag.id))])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testIdentityAndGetReturnLiveNamesWithoutConfusingSameNameCategories() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerTagIntent()
    creation.name = "rainy-day"
    let cached = try await creation.callAsFunction(donate: false)
    creation.name = "Second tag"
    let second = try await creation.callAsFunction(donate: false)
    let categoryCreation = CreatePlannerCategoryIntent()
    categoryCreation.name = "Second tag"
    let category = try await categoryCreation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.tag(let original)) = await planner.read(
        session: session, request: .source(.init(kind: .tag, id: cached.id))),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editTag(
            sourceId: cached.id, changes: .init(name: .set("Renamed tag")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else {
      return XCTFail("The canonical shared Tag must change before resolving its cached entity.")
    }
    let query = PlannerTagEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(
      for: [second.id, UUID(), cached.id, second.id, category.id, cached.id])
    XCTAssertEqual(resolved.map(\.id), [second.id, cached.id])
    XCTAssertEqual(resolved.map(\.name), ["Second tag", "Renamed tag"])
    let reading = GetPlannerTagIntent()
    reading.tag = cached
    let current = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(current.id, cached.id)
    XCTAssertEqual(current.name, "Renamed tag")
    reading.tag = .init(id: category.id, name: "Second tag")
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("A Category cannot substitute for a Tag with the same name.")
    } catch { XCTAssertTrue(error.localizedDescription.contains("no longer available")) }
    reading.tag = .init(id: UUID(), name: "Missing")
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Get Tag cannot invent a missing source.")
    } catch { XCTAssertTrue(error.localizedDescription.contains("no longer available")) }
    let categoryReading = GetPlannerCategoryIntent()
    categoryReading.category = category
    let retainedCategory = try await categoryReading.callAsFunction(donate: false)
    XCTAssertEqual(retainedCategory.name, "Second tag")
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }
  func testTagChoicesUseCanonicalInsensitiveCumulativeSearchAndReadEveryPage() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var identifiers: [UUID] = []
    for index in 0..<65 {
      guard
        case .applied(let created, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createTag(content: .init(name: String(format: "Café %02d rainy", index))))
        ).outcome, let source = created.generated.first
      else { return XCTFail("Every canonical Tag must save before querying choices.") }
      identifiers.append(source.id)
    }
    let query = PlannerTagEntityQuery()
    query.plannerStore = store
    let matches = try await query.entities(matching: "RAINY cafe")
    XCTAssertEqual(matches.map(\.id), identifiers)
    XCTAssertEqual(matches.first?.name, "Café 00 rainy")
    XCTAssertEqual(matches.last?.name, "Café 64 rainy")
    XCTAssertEqual(Set(matches.map(\.id)).count, 65)
    let suggestions = try await query.suggestedEntities()
    XCTAssertEqual(suggestions.map(\.id), identifiers)
    let absent = try await query.entities(matching: "cafe nonexistent")
    XCTAssertTrue(absent.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testSameNameTagsKeepDistinctIdentitiesAndCanonicalTieOrder() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerTagIntent()
    creation.name = "Museums"
    let first = try await creation.callAsFunction(donate: false)
    let second = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(first.id, second.id)
    let query = PlannerTagEntityQuery()
    query.plannerStore = store
    let choices = try await query.entities(matching: "MUSEUMS")
    let expectedIdentifiers = [first.id, second.id].sorted { firstIdentifier, secondIdentifier in
      firstIdentifier.uuidString < secondIdentifier.uuidString
    }
    XCTAssertEqual(choices.map(\.id), expectedIdentifiers)
    XCTAssertEqual(choices.map(\.name), ["Museums", "Museums"])
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.tag(let firstSource)) = await reopened.read(
        session: session, request: .source(.init(kind: .tag, id: first.id))),
      case .source(.tag(let secondSource)) = await reopened.read(
        session: session, request: .source(.init(kind: .tag, id: second.id)))
    else { return XCTFail("Same-name Tags must retain separate saved sources.") }
    XCTAssertEqual(firstSource.content.name, "Museums")
    XCTAssertEqual(secondSource.content.name, "Museums")
    XCTAssertNotEqual(firstSource.sourceLifetimeId, secondSource.sourceLifetimeId)
    XCTAssertTrue(firstSource.references.isEmpty)
    XCTAssertTrue(secondSource.references.isEmpty)
  }

  func testInvalidAndPrecancelledCreationLeaveNoSavedTags() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerTagIntent()
    creation.name = " \n\t "
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("A blank Tag name cannot acknowledge creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    creation.name = "Cancelled before invocation"
    let request = Task { try await creation.callAsFunction(donate: false) }
    request.cancel()
    do {
      _ = try await request.value
      XCTFail("A cancelled invocation must not start Tag creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let query = PlannerTagEntityQuery()
    query.plannerStore = store
    let choices = try await query.suggestedEntities()
    XCTAssertTrue(choices.isEmpty)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(session: session, request: .catalog(.init(sourceKind: .tag, archive: .all))))
    else { return XCTFail("Invalid/cancelled requests must leave inspectable storage.") }
    XCTAssertTrue(catalog.rows.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testDeletedTagStaysMissingWithoutAffectingTheSurvivingSource() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerTagIntent()
    creation.name = "Removed tag"
    let removed = try await creation.callAsFunction(donate: false)
    creation.name = "Surviving tag"
    let survivor = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .tag, id: removed.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: source),
          reviewToken: review.reviewToken)
      ).outcome
    else { return XCTFail("Native reviewed deletion must remove the selected Tag first.") }
    let query = PlannerTagEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(for: [removed.id, survivor.id, UUID()])
    XCTAssertEqual(resolved.map(\.id), [survivor.id])
    let reading = GetPlannerTagIntent()
    reading.tag = removed
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Get cannot recreate a deleted Tag or substitute another source.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .tag, archive: .all))))
    else { return XCTFail("The Tag catalog must remain readable after native deletion.") }
    XCTAssertEqual(catalog.rows, [.source(.init(kind: .tag, id: survivor.id))])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testUnavailableStorageThrowsForChoicesIdentityGetAndCreation() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let query = PlannerTagEntityQuery()
    query.plannerStore = store
    func requireUnavailable(_ request: () async throws -> [PlannerTagEntity]) async {
      do {
        _ = try await request()
        XCTFail("Unavailable storage must not become empty successful Tag data.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    await requireUnavailable { try await query.suggestedEntities() }
    await requireUnavailable { try await query.entities(matching: "Museums") }
    await requireUnavailable { try await query.entities(for: [UUID()]) }
    let reading = GetPlannerTagIntent()
    reading.tag = .init(id: UUID(), name: "Unavailable")
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("An unavailable store cannot acknowledge a successful Tag read.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let creation = CreatePlannerTagIntent()
    creation.name = "Cannot save here"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("An unavailable store cannot acknowledge Tag creation.")
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
    let creation = CreatePlannerTagIntent()
    creation.name = "Recovery tag"
    let applied = try await creation.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    let query = PlannerTagEntityQuery()
    query.plannerStore = store
    let readable = try await query.suggestedEntities()
    XCTAssertEqual(readable.map(\.id), [applied.id])
    creation.name = "Blocked tag"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block another creation without duplicating the Tag.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.tag(let retained)) = await reopened.read(
        session: session, request: .source(.init(kind: .tag, id: applied.id)))
    else { return XCTFail("The returned Tag must remain saved despite incomplete recovery.") }
    XCTAssertEqual(retained.content.name, "Recovery tag")
    XCTAssertNil(retained.state.globalDone)
    XCTAssertNil(retained.state.archived)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete(let recovered, _) = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.tag(let afterRecovery)) = await reopened.read(
        session: session, request: .source(.init(kind: .tag, id: applied.id)))
    else { return XCTFail("Native retry must acknowledge the original Tag creation.") }
    XCTAssertEqual(recovered.generated, [.init(kind: .tag, id: applied.id)])
    XCTAssertEqual(afterRecovery.createdAt, retained.createdAt)
    XCTAssertEqual(afterRecovery.updatedAt, retained.updatedAt)
    let afterRecoveryChoices = try await query.suggestedEntities()
    XCTAssertEqual(afterRecoveryChoices.map(\.id), [applied.id])
    creation.name = "Allowed tag"
    let next = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(next.id, applied.id)
    let finalChoices = try await query.suggestedEntities()
    XCTAssertEqual(finalChoices.map(\.id), [next.id, applied.id])
    XCTAssertFalse(store.isSaving)
  }
}
