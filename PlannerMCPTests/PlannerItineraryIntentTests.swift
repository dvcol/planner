import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItineraryIntentTests: XCTestCase {
  func testCreateItineraryReturnsSavedIdentityAndPreservesItsContentAfterReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Tokyo Weekend"
    creation.notes = "Museum, lunch and a return to the Hotel"
    let itinerary = try await creation.callAsFunction(donate: false)
    XCTAssertEqual(itinerary.title, "Tokyo Weekend")
    XCTAssertFalse(itinerary.archived)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let current)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id))),
      case .snapshot(let catalog) = await reopened.query(
        .init(session: session, request: .catalog(.init(sourceKind: .itinerary, archive: .all))))
    else { return XCTFail("The returned Itinerary must be readable from reopened real storage.") }
    XCTAssertEqual(current.source.id, itinerary.id)
    XCTAssertEqual(current.content.title, "Tokyo Weekend")
    XCTAssertEqual(current.content.notes, "Museum, lunch and a return to the Hotel")
    XCTAssertEqual(current.state.archived, false)
    XCTAssertNil(current.state.globalDone)
    XCTAssertEqual(current.progress.state, .empty)
    XCTAssertEqual(current.progress.totalCount, 0)
    XCTAssertTrue(current.references.isEmpty)
    XCTAssertTrue(current.listEntrySummaries.isEmpty)
    XCTAssertEqual(catalog.rows, [.source(.init(kind: .itinerary, id: itinerary.id))])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testIdentityLookupDeduplicatesRequestsAndReturnsLiveValuesInRequestedOrder() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Original itinerary"
    let first = try await creation.callAsFunction(donate: false)
    creation.title = "Second itinerary"
    let second = try await creation.callAsFunction(donate: false)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "This is an Item, not an Itinerary"
    let item = try await itemCreation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .itinerary, id: first.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editItinerary(
            sourceId: first.id, changes: .init(title: .set("Renamed itinerary")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: source, archived: true))
      ).outcome
    else { return XCTFail("Canonical commands must change the source before entity lookup.") }
    let query = PlannerItineraryEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(
      for: [second.id, UUID(), first.id, second.id, item.id, first.id])
    XCTAssertEqual(resolved.map(\.id), [second.id, first.id])
    XCTAssertEqual(resolved.map(\.title), ["Second itinerary", "Renamed itinerary"])
    XCTAssertEqual(resolved.map(\.archived), [false, true])
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testGetItineraryReturnsLiveValuesAndRejectsMissingIdentity() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Original itinerary"
    let cached = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .itinerary, id: cached.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editItinerary(
            sourceId: cached.id, changes: .init(title: .set("Renamed itinerary")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else { return XCTFail("The canonical source must change before resolving a cached entity.") }
    let reading = GetPlannerItineraryIntent()
    reading.itinerary = cached
    let current = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(current.id, cached.id)
    XCTAssertEqual(current.title, "Renamed itinerary")
    XCTAssertFalse(current.archived)
    reading.itinerary = .init(id: UUID(), title: "Missing", archived: false)
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Get Itinerary must reject a missing identity rather than inventing a source.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
  }

  func testItineraryChoicesPreserveCanonicalSearchOrderArchivedSourcesAndEveryPage() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var identifiers: [UUID] = []
    for index in 0..<65 {
      guard
        case .applied(let created, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItinerary(content: .init(title: String(format: "Route %02d", index))))
        ).outcome, let source = created.generated.first
      else { return XCTFail("Every canonical Itinerary must save before querying choices.") }
      identifiers.append(source.id)
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: .init(kind: .itinerary, id: identifiers[0]), archived: true))
      ).outcome
    else { return XCTFail("The archived Itinerary must remain discoverable by identity.") }
    let query = PlannerItineraryEntityQuery()
    query.plannerStore = store
    let matches = try await query.entities(matching: "ROUTE")
    XCTAssertEqual(matches.map(\.id), identifiers)
    XCTAssertEqual(matches.first?.title, "Route 00")
    XCTAssertEqual(matches.first?.archived, true)
    XCTAssertEqual(matches.last?.title, "Route 64")
    XCTAssertEqual(Set(matches.map(\.id)).count, 65)
    let suggestions = try await query.suggestedEntities()
    XCTAssertEqual(suggestions.map(\.id), identifiers)
    let absent = try await query.entities(matching: "No such itinerary")
    XCTAssertTrue(absent.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testInvalidAndPrecancelledCreationLeaveNoSavedItineraries() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "   "
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("A blank Itinerary title cannot acknowledge creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    creation.title = "Cancelled before invocation"
    let request = Task { try await creation.callAsFunction(donate: false) }
    request.cancel()
    do {
      _ = try await request.value
      XCTFail("A cancelled invocation must not start an Itinerary creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let query = PlannerItineraryEntityQuery()
    query.plannerStore = store
    let choices = try await query.suggestedEntities()
    XCTAssertTrue(choices.isEmpty)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(session: session, request: .catalog(.init(sourceKind: .itinerary, archive: .all))))
    else {
      return XCTFail("The actual empty dataset must remain readable after rejected creation.")
    }
    XCTAssertTrue(catalog.rows.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testDeletedItineraryStaysMissingWithoutAffectingTheSurvivingSource() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Remove this route"
    let removed = try await creation.callAsFunction(donate: false)
    creation.title = "Surviving route"
    creation.notes = "Keep these notes"
    let survivor = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .itinerary, id: removed.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: source),
          reviewToken: review.reviewToken)
      ).outcome
    else { return XCTFail("Native reviewed deletion must remove the selected source first.") }
    let query = PlannerItineraryEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(for: [removed.id, survivor.id, UUID()])
    XCTAssertEqual(resolved.map(\.id), [survivor.id])
    let reading = GetPlannerItineraryIntent()
    reading.itinerary = removed
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("Get must not recreate a deleted Itinerary or substitute another source.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .itinerary, archive: .all)))
      ),
      case .source(.itinerary(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .itinerary, id: survivor.id)))
    else { return XCTFail("The surviving source must remain unchanged in reopened storage.") }
    XCTAssertEqual(catalog.rows, [.source(.init(kind: .itinerary, id: survivor.id))])
    XCTAssertEqual(retained.content.title, "Surviving route")
    XCTAssertEqual(retained.content.notes, "Keep these notes")
    XCTAssertEqual(retained.progress.state, .empty)
    XCTAssertFalse(store.recoveryBlocked)
  }

  func testSameTitleItinerariesKeepDistinctIdentitiesAndCanonicalTieOrder() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Same route"
    creation.notes = "First route notes"
    let first = try await creation.callAsFunction(donate: false)
    creation.notes = "Second route notes"
    let second = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(first.id, second.id)
    let query = PlannerItineraryEntityQuery()
    query.plannerStore = store
    let choices = try await query.entities(matching: "SAME route")
    let expectedIdentifiers = [first.id, second.id].sorted { firstIdentifier, secondIdentifier in
      firstIdentifier.uuidString < secondIdentifier.uuidString
    }
    XCTAssertEqual(choices.map(\.id), expectedIdentifiers)
    XCTAssertEqual(choices.map(\.title), ["Same route", "Same route"])
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let firstSource)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: first.id))),
      case .source(.itinerary(let secondSource)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: second.id)))
    else {
      return XCTFail("Same-title sources must remain independently readable after reopening.")
    }
    XCTAssertEqual(firstSource.content.notes, "First route notes")
    XCTAssertEqual(secondSource.content.notes, "Second route notes")
    XCTAssertTrue(firstSource.references.isEmpty)
    XCTAssertTrue(secondSource.references.isEmpty)
  }

  func testUnavailableStorageThrowsForChoicesIdentityGetAndCreation() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let query = PlannerItineraryEntityQuery()
    query.plannerStore = store
    func requireUnavailable(_ request: () async throws -> [PlannerItineraryEntity]) async {
      do {
        _ = try await request()
        XCTFail("Unavailable storage must not become empty successful Itinerary data.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    await requireUnavailable { try await query.suggestedEntities() }
    await requireUnavailable { try await query.entities(matching: "Route") }
    await requireUnavailable { try await query.entities(for: [UUID()]) }
    let reading = GetPlannerItineraryIntent()
    reading.itinerary = .init(id: UUID(), title: "Unavailable", archived: false)
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("An unavailable store cannot acknowledge a successful Itinerary read.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Cannot save here"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("An unavailable store cannot acknowledge a new Itinerary.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func
    testAppliedItineraryCreationWithIncompleteRecoveryRetainsItsIdentityAndBlocksAnotherCreation()
    async throws
  {
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
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Recovery route"
    creation.notes = "Keep the applied Itinerary"
    let applied = try await creation.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    let query = PlannerItineraryEntityQuery()
    query.plannerStore = store
    let readable = try await query.suggestedEntities()
    XCTAssertEqual(readable.map(\.id), [applied.id])
    creation.title = "Blocked Itinerary"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail(
        "Incomplete recovery must block another creation rather than duplicate the Itinerary.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let retained)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: applied.id)))
    else { return XCTFail("The returned Itinerary must remain saved despite incomplete recovery.") }
    XCTAssertEqual(retained.content.title, "Recovery route")
    XCTAssertEqual(retained.content.notes, "Keep the applied Itinerary")
    XCTAssertNil(retained.state.globalDone)
    XCTAssertEqual(retained.state.archived, false)
    XCTAssertEqual(retained.progress.state, .empty)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete(let recovered, _) = await reopened.operationStatus(
        session: session, operationId: operationIdentifier)
    else { return XCTFail("Native retry must acknowledge the original creation operation.") }
    XCTAssertEqual(recovered.generated, [.init(kind: .itinerary, id: applied.id)])
    let afterRecovery = try await query.suggestedEntities()
    XCTAssertEqual(afterRecovery.map(\.id), [applied.id])
    creation.title = "Allowed Itinerary"
    let next = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(next.id, applied.id)
    let finalChoices = try await query.suggestedEntities()
    XCTAssertEqual(finalChoices.map(\.id), [next.id, applied.id])
    XCTAssertFalse(store.isSaving)
  }

}
