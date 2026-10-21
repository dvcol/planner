import AppIntents
import Foundation
import GeoToolbox
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerDeferredContentTests: XCTestCase {
  func testLightweightQueriesReadOwnedContentAndDatesWithoutChangingThePlanner() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let sources = try await readEstimateResetSources(fixture)
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let itemQuery = PlannerItemEntityQuery()
    itemQuery.plannerStore = fixture.store
    let listQuery = PlannerListEntityQuery()
    listQuery.plannerStore = fixture.store
    let itineraryQuery = PlannerItineraryEntityQuery()
    itineraryQuery.plannerStore = fixture.store
    let itemChoices = try await itemQuery.entities(matching: "Museum")
    let listChoices = try await listQuery.suggestedEntities()
    let itineraryChoices = try await itineraryQuery.entities(for: [fixture.itinerary.id])
    let item = try XCTUnwrap(itemChoices.first)
    let list = try XCTUnwrap(listChoices.first)
    let itinerary = try XCTUnwrap(itineraryChoices.first)
    let itemValues = try await (
      item.subtitle, item.notes, item.locationName, item.address, item.pin,
      item.created, item.lastUpdated
    )
    XCTAssertEqual(item.id, fixture.item.id)
    XCTAssertEqual(itemValues.0, "Opening hours vary")
    XCTAssertEqual(itemValues.1, "Keep booking")
    XCTAssertEqual(itemValues.2, "Museum")
    XCTAssertEqual(itemValues.3, "Tokyo")
    let pin = try XCTUnwrap(itemValues.4)
    XCTAssertNil(pin.commonName)
    XCTAssertEqual(pin.representations.count, 1)
    guard case .coordinate(let coordinate) = pin.representations[0] else {
      return XCTFail("Only the saved coordinate belongs in the Pin.")
    }
    XCTAssertEqual(coordinate.latitude, 35.6622)
    XCTAssertEqual(coordinate.longitude, 139.7171)
    XCTAssertEqual(itemValues.5, sources.item.createdAt)
    XCTAssertEqual(itemValues.6, sources.item.updatedAt)
    let listValues = try await (list.notes, list.created, list.lastUpdated)
    XCTAssertEqual(listValues.0, "Keep List")
    XCTAssertEqual(listValues.1, sources.list.createdAt)
    XCTAssertEqual(listValues.2, sources.list.updatedAt)
    let itineraryValues = try await (
      itinerary.notes, itinerary.locationName, itinerary.address, itinerary.pin,
      itinerary.created, itinerary.lastUpdated
    )
    XCTAssertEqual(itineraryValues.0, "Keep route")
    XCTAssertNil(itineraryValues.1)
    XCTAssertNil(itineraryValues.2)
    XCTAssertNil(itineraryValues.3)
    XCTAssertEqual(itineraryValues.4, sources.itinerary.createdAt)
    XCTAssertEqual(itineraryValues.5, sources.itinerary.updatedAt)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let after) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testItemNotesReadCurrentSavedTextWithoutChangingTheReturnedEntityIdentity() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.notes = "Original notes\n東京 🏛️"
    let item = try await creation.callAsFunction(donate: false)
    let initialNotes = try await item.notes
    XCTAssertEqual(initialNotes, "Original notes\n東京 🏛️")
    let edit = EditPlannerItemIntent()
    edit.item = item
    edit.notes = "Changed notes\nCafé"
    let _: Void = try await edit.callAsFunction(donate: false)
    let currentNotes = try await item.notes
    XCTAssertEqual(currentNotes, "Changed notes\nCafé")
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let saved)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("The getter must retain the original saved Item.") }
    XCTAssertEqual(saved.content.notes, "Changed notes\nCafé")
    XCTAssertEqual(saved.source.id, item.id)
    XCTAssertFalse(store.isSaving)
  }
  func testAbsentAndEmptyContentRemainDistinctAndMapsBookmarksDoNotInventPins() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let mapsURL = "https://www.google.com/maps/search/?api=1&query=35.6622%2C139.7171"
    let commands: [PlannerCommand] = [
      .createItem(
        content: .init(title: "Maps Item", notes: "", links: [.init(originalUrl: mapsURL)])),
      .createList(content: .init(name: "Empty List")),
      .createItinerary(
        content: .init(title: "Maps Itinerary", links: [.init(originalUrl: mapsURL)])),
    ]
    var sources: [PlannerEntityReference] = []
    for command in commands {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else { throw CancellationError() }
      sources.append(source)
    }
    let itemQuery = PlannerItemEntityQuery()
    itemQuery.plannerStore = store
    let listQuery = PlannerListEntityQuery()
    listQuery.plannerStore = store
    let itineraryQuery = PlannerItineraryEntityQuery()
    itineraryQuery.plannerStore = store
    let items = try await itemQuery.suggestedEntities()
    let lists = try await listQuery.entities(for: [sources[1].id])
    let itineraries = try await itineraryQuery.entities(matching: "Maps")
    let item = try XCTUnwrap(items.first)
    let list = try XCTUnwrap(lists.first)
    let itinerary = try XCTUnwrap(itineraries.first)
    guard case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let itemContent = try await (
      item.subtitle, item.notes, item.locationName, item.address, item.pin
    )
    XCTAssertNil(itemContent.0)
    XCTAssertEqual(itemContent.1, "")
    XCTAssertNil(itemContent.2)
    XCTAssertNil(itemContent.3)
    XCTAssertNil(itemContent.4)
    let listNotes = try await list.notes
    XCTAssertNil(listNotes)
    let itineraryContent = try await (
      itinerary.notes, itinerary.locationName, itinerary.address, itinerary.pin
    )
    XCTAssertNil(itineraryContent.0)
    XCTAssertNil(itineraryContent.1)
    XCTAssertNil(itineraryContent.2)
    XCTAssertNil(itineraryContent.3)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let after) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
  }

  func testOwnedLocationVariantsStayExactForPreviouslyReturnedItemsAndItineraries() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let itemQuery = PlannerItemEntityQuery()
    itemQuery.plannerStore = fixture.store
    let itineraryQuery = PlannerItineraryEntityQuery()
    itineraryQuery.plannerStore = fixture.store
    let items = try await itemQuery.entities(for: [fixture.item.id])
    let itineraries = try await itineraryQuery.suggestedEntities()
    let item = try XCTUnwrap(items.first)
    let itinerary = try XCTUnwrap(itineraries.first)
    let locations: [PlannerOwnedLocation?] = [
      nil, .init(displayName: nil, formattedAddress: nil, coordinate: nil),
      .init(displayName: "  Musée · 東京  ", formattedAddress: nil, coordinate: nil),
      .init(displayName: nil, formattedAddress: "Address only\nParis", coordinate: nil),
      .init(displayName: nil, formattedAddress: nil, coordinate: .init(latitude: 0, longitude: 0)),
      .init(
        displayName: nil, formattedAddress: nil, coordinate: .init(latitude: 90, longitude: 180)),
      .init(
        displayName: nil, formattedAddress: nil, coordinate: .init(latitude: -90, longitude: -180)),
      .init(
        displayName: "Saved name", formattedAddress: "Saved address",
        coordinate: .init(latitude: -0.0001, longitude: 179.9999)),
    ]
    for source in [fixture.item, fixture.itinerary] {
      for location in locations {
        let command: PlannerCommand
        switch await fixture.planner.read(session: fixture.session, request: .source(source)) {
        case .source(.item(let current)):
          let change: PlannerFieldChange<PlannerOwnedLocation> = location.map { .set($0) } ?? .clear
          command = .editItem(
            sourceId: source.id, changes: .init(location: change),
            expectedFieldHashes: current.fieldHashes)
        case .source(.itinerary(let current)):
          let change: PlannerFieldChange<PlannerOwnedLocation> = location.map { .set($0) } ?? .clear
          command = .editItinerary(
            sourceId: source.id, changes: .init(location: change),
            expectedFieldHashes: current.fieldHashes)
        default: throw CancellationError()
        }
        guard
          case .applied(_, .complete) = await fixture.planner.execute(
            .init(operationId: UUID(), session: fixture.session, command: command)
          ).outcome,
          case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
        else { throw CancellationError() }
        let actual: (String?, String?, PlaceDescriptor?)
        if source.kind == .item {
          actual = try await (item.locationName, item.address, item.pin)
        } else {
          actual = try await (itinerary.locationName, itinerary.address, itinerary.pin)
        }
        XCTAssertEqual(actual.0, location?.displayName)
        XCTAssertEqual(actual.1, location?.formattedAddress)
        if let expected = location?.coordinate {
          let pin = try XCTUnwrap(actual.2)
          XCTAssertNil(pin.commonName)
          XCTAssertEqual(pin.representations.count, 1)
          guard case .coordinate(let coordinate) = pin.representations[0] else {
            return XCTFail("An owned Pin must contain only its saved coordinate.")
          }
          XCTAssertEqual(coordinate.latitude, expected.latitude)
          XCTAssertEqual(coordinate.longitude, expected.longitude)
        } else {
          XCTAssertNil(actual.2)
        }
        guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
        else { throw CancellationError() }
        XCTAssertEqual(after, before)
      }
    }
  }

  func testArchivedDoneAndUpdatedSourcesRemainReadableAndDeletedGettersThrow() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let entities = try await loadDeferredEntities(fixture)
    let item = entities.item
    let list = entities.list
    let itinerary = entities.itinerary
    for command in [
      PlannerCommand.setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true),
      .setArchive(source: fixture.item, archived: true),
      .setArchive(source: fixture.list, archived: true),
      .setArchive(source: fixture.itinerary, archived: true),
    ] {
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    let current = try await readEstimateResetSources(fixture)
    let itemValues = try await (item.notes, item.lastUpdated)
    let listValues = try await (list.notes, list.lastUpdated)
    let itineraryValues = try await (itinerary.notes, itinerary.lastUpdated)
    XCTAssertEqual(itemValues.0, "Keep booking")
    XCTAssertEqual(listValues.0, "Keep List")
    XCTAssertEqual(itineraryValues.0, "Keep route")
    XCTAssertEqual(itemValues.1, current.item.updatedAt)
    XCTAssertEqual(listValues.1, current.list.updatedAt)
    XCTAssertEqual(itineraryValues.1, current.itinerary.updatedAt)
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      let command = PlannerCommand.deleteSource(source: source)
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: command),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    for selection in [
      DeferredContentSelection.item(entities.item), .list(entities.list),
      .itinerary(entities.itinerary),
    ] {
      do {
        _ = try await readNotes(selection)
        XCTFail("Deleted sources must throw rather than return absent content.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let listQuery = PlannerListEntityQuery()
    listQuery.plannerStore = fixture.store
    let itineraryQuery = PlannerItineraryEntityQuery()
    itineraryQuery.plannerStore = fixture.store
    let wrongListKind = try await listQuery.entities(for: [fixture.lunch.id])
    let wrongItineraryKind = try await itineraryQuery.entities(for: [fixture.lunch.id])
    XCTAssertTrue(wrongListKind.isEmpty)
    XCTAssertTrue(wrongItineraryKind.isEmpty)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
  }

  func testCancellationAndUnavailableStorageNeverMasqueradeAsAbsentContent() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let entities = try await loadDeferredEntities(fixture)
    let selections: [DeferredContentSelection] = [
      .item(entities.item), .list(entities.list),
      .itinerary(entities.itinerary),
    ]
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    for selection in selections {
      let task = Task { try await self.readNotes(selection) }
      task.cancel()
      do {
        _ = try await task.value
        XCTFail("A precancelled getter cannot return an absent optional value.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let obstruction = Data("Unavailable store parent".utf8)
    try obstruction.write(to: directory.appending(path: "store"))
    AppDependencyManager.shared.add(dependency: unavailable)
    let opening = GetPlannerItemIntent()
    opening.item = entities.item
    do {
      _ = try await opening.callAsFunction(donate: false)
      XCTFail("The real SDK invocation must fail to open the obstructed store.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    for selection in selections {
      do {
        _ = try await readNotes(selection)
        XCTFail("A failed read must not be reported as absent content.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: directory.appending(path: "store")), obstruction)
    XCTAssertFalse(unavailable.isReady)
    XCTAssertFalse(unavailable.isSaving)
    XCTAssertNotNil(unavailable.openingFailure)
  }

  func testReadsThroughIncompleteRecoveryKeepTheCheckpointUnacknowledged() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let entities = try await loadDeferredEntities(fixture)
    await fixture.store.open()
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let completion = SetPlannerItemCompletionIntent()
    completion.item = .init(id: fixture.item.id, title: "Cached", done: false, archived: false)
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operation = try XCTUnwrap(fixture.store.incompleteRecoveryOperationIdentifiers.first)
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    for (selection, expected) in [
      (DeferredContentSelection.item(entities.item), "Keep booking"),
      (.list(entities.list), "Keep List"),
      (.itinerary(entities.itinerary), "Keep route"),
    ] {
      let notes = try await readNotes(selection)
      XCTAssertEqual(notes, expected)
    }
    XCTAssertTrue(fixture.store.recoveryBlocked)
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operation])
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    await fixture.store.retryIncompleteRecovery()
    XCTAssertFalse(fixture.store.recoveryBlocked)
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operation)
    else { return XCTFail("Only explicit recovery can acknowledge the original operation.") }
  }

  private func loadDeferredEntities(_ fixture: EstimateResetIntentFixture) async throws -> (
    item: PlannerItemEntity, list: PlannerListEntity, itinerary: PlannerItineraryEntity
  ) {
    let itemQuery = PlannerItemEntityQuery()
    itemQuery.plannerStore = fixture.store
    let listQuery = PlannerListEntityQuery()
    listQuery.plannerStore = fixture.store
    let itineraryQuery = PlannerItineraryEntityQuery()
    itineraryQuery.plannerStore = fixture.store
    let items = try await itemQuery.entities(for: [fixture.item.id])
    let lists = try await listQuery.entities(for: [fixture.list.id])
    let itineraries = try await itineraryQuery.entities(for: [fixture.itinerary.id])
    return (
      try XCTUnwrap(items.first), try XCTUnwrap(lists.first), try XCTUnwrap(itineraries.first)
    )
  }

  private enum DeferredContentSelection {
    case item(PlannerItemEntity)
    case list(PlannerListEntity)
    case itinerary(PlannerItineraryEntity)
  }

  private func readNotes(_ selection: DeferredContentSelection) async throws -> String? {
    switch selection {
    case .item(let item): try await item.notes
    case .list(let list): try await list.notes
    case .itinerary(let itinerary): try await itinerary.notes
    }
  }
}
