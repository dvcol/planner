import AppIntents
import CoreLocation
import Foundation
import GeoToolbox
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerOwnedLocationIntentTests: XCTestCase {
  func testItemLocationTextEditKeepsItsPinAndOtherPlanningDataAfterReopen() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    let editing = EditPlannerItemLocationIntent()
    editing.item = .init(id: fixture.item.id, title: "Cached title", done: true, archived: true)
    editing.placeName = "  Musée · 東京  "
    editing.address = "New authored address"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readOwnedLocationSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(
      after.item.content.location,
      .init(
        displayName: "  Musée · 東京  ", formattedAddress: "New authored address",
        coordinate: .init(latitude: 35.6622, longitude: 139.7171)))
    assertOwnedLocationPreservesOtherData(before, after, changedKind: .item)
    try await assertOwnedLocationPlanningContexts(fixture, planner: reopened, session: session)
  }

  func testItineraryTextAndExplicitPinRemovalKeepItemLocationAndRouteState() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    let editing = EditPlannerItineraryLocationIntent()
    editing.itinerary = .init(id: fixture.itinerary.id, title: "Cached route", archived: true)
    editing.address = "  Rendez-vous · vendredi  "
    editing.removeSavedPin = true
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readOwnedLocationSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(
      after.itinerary.content.location,
      .init(
        displayName: "Meeting point", formattedAddress: "  Rendez-vous · vendredi  ",
        coordinate: nil))
    assertOwnedLocationPreservesOtherData(before, after, changedKind: .itinerary)
    try await assertOwnedLocationPlanningContexts(fixture, planner: reopened, session: session)
  }

  func testNativePinInputKeepsAuthoredItemTextAndIgnoresDescriptorAddressAndName() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    let setting = SetPlannerItemLocationPinIntent()
    setting.item = .init(id: fixture.item.id, title: "Cached title", done: true, archived: true)
    setting.location = PlaceDescriptor(
      representations: [
        .coordinate(.init(latitude: 51.5, longitude: -0.12)),
        .address("Provider address must not be adopted"),
      ], commonName: "Provider name must not be adopted")
    let _: Void = try await setting.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readOwnedLocationSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(
      after.item.content.location,
      .init(
        displayName: "Saved place",
        formattedAddress: "Original address", coordinate: .init(latitude: 51.5, longitude: -0.12)))
    assertOwnedLocationPreservesOtherData(before, after, changedKind: .item)
    try await assertOwnedLocationPlanningContexts(fixture, planner: reopened, session: session)
  }

  func testItineraryPinAcceptsMatchingDeviceAndCoordinatePointsWithoutChangingItemPin() async throws
  {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    let setting = SetPlannerItineraryLocationPinIntent()
    setting.itinerary = .init(id: fixture.itinerary.id, title: "Cached route", archived: true)
    setting.location = PlaceDescriptor(
      representations: [
        .deviceLocation(CLLocation(latitude: -33.86, longitude: 151.2)),
        .coordinate(.init(latitude: -33.86, longitude: 151.2)),
      ], commonName: "Ignore provider name")
    let _: Void = try await setting.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readOwnedLocationSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(
      after.itinerary.content.location,
      .init(
        displayName: "Meeting point",
        formattedAddress: "Meeting address", coordinate: .init(latitude: -33.86, longitude: 151.2)))
    assertOwnedLocationPreservesOtherData(before, after, changedKind: .itinerary)
    try await assertOwnedLocationPlanningContexts(fixture, planner: reopened, session: session)
  }
  func testClearingOwnedLocationsRetainsOriginalLinksAndAllPlanningContextsAfterReopen()
    async throws
  {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    let itemClearing = ClearPlannerItemLocationIntent()
    itemClearing.item = .init(
      id: fixture.item.id, title: "Cached title", done: true, archived: true)
    let _: Void = try await itemClearing.callAsFunction(donate: false)
    let _: Void = try await itemClearing.callAsFunction(donate: false)
    let afterItem = try await readOwnedLocationSources(fixture)
    XCTAssertNil(afterItem.item.content.location)
    XCTAssertEqual(
      afterItem.item.content.links.first?.originalUrl,
      "https://www.google.com/maps/search/?api=1&query=35.6622,139.7171")
    assertOwnedLocationPreservesOtherData(before, afterItem, changedKind: .item)
    let itineraryClearing = ClearPlannerItineraryLocationIntent()
    itineraryClearing.itinerary = .init(
      id: fixture.itinerary.id, title: "Cached route", archived: true)
    let _: Void = try await itineraryClearing.callAsFunction(donate: false)
    let _: Void = try await itineraryClearing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readOwnedLocationSources(fixture, planner: reopened, session: session)
    XCTAssertNil(after.item.content.location)
    XCTAssertNil(after.itinerary.content.location)
    XCTAssertEqual(after.itinerary.content.links.first?.originalUrl, "https://example.com/route")
    assertOwnedLocationPreservesOtherData(afterItem, after, changedKind: .itinerary)
    try await assertOwnedLocationPlanningContexts(fixture, planner: reopened, session: session)
  }
  func testExplicitEmptyTextClearsPreviouslySavedEmptyLocationFields() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    for owner in [fixture.item, fixture.itinerary] {
      let current = try await readOwnedLocationSources(fixture)
      let empty = PlannerOwnedLocation(displayName: "", formattedAddress: "", coordinate: nil)
      let command: PlannerCommand
      if owner.kind == .item {
        command = .editItem(
          sourceId: owner.id, changes: .init(location: .set(empty)),
          expectedFieldHashes: current.item.fieldHashes)
      } else {
        command = .editItinerary(
          sourceId: owner.id, changes: .init(location: .set(empty)),
          expectedFieldHashes: current.itinerary.fieldHashes)
      }
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
      let before = try await readOwnedLocationSources(fixture)
      if owner.kind == .item {
        let editing = EditPlannerItemLocationIntent()
        editing.item = .init(id: owner.id, title: "Cached", done: true, archived: true)
        editing.placeName = ""
        editing.address = ""
        let _: Void = try await editing.callAsFunction(donate: false)
      } else {
        let editing = EditPlannerItineraryLocationIntent()
        editing.itinerary = .init(id: owner.id, title: "Cached", archived: true)
        editing.placeName = ""
        editing.address = ""
        let _: Void = try await editing.callAsFunction(donate: false)
      }
      let after = try await readOwnedLocationSources(fixture)
      if owner.kind == .item {
        XCTAssertNil(after.item.content.location)
      } else {
        XCTAssertNil(after.itinerary.content.location)
      }
      assertOwnedLocationPreservesOtherData(before, after, changedKind: owner.kind)
    }
  }
  func testTextOmissionExplicitClearingAndNewAddressPreserveEachOwnersOtherFields() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    for owner in [fixture.item, fixture.itinerary] {
      let before = try await readOwnedLocationSources(fixture)
      let original = ownedLocation(before, kind: owner.kind)
      do {
        try await invokeOwnedLocationIntent(owner, operation: .text(nil, nil, false))
        XCTFail("An empty text edit must ask for a change rather than acknowledge a save.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      try await invokeOwnedLocationIntent(owner, operation: .text("", nil, false))
      let nameCleared = try await readOwnedLocationSources(fixture)
      XCTAssertNil(ownedLocation(nameCleared, kind: owner.kind)?.displayName)
      XCTAssertEqual(
        ownedLocation(nameCleared, kind: owner.kind)?.formattedAddress, original?.formattedAddress)
      XCTAssertEqual(ownedLocation(nameCleared, kind: owner.kind)?.coordinate, original?.coordinate)
      try await invokeOwnedLocationIntent(owner, operation: .text(nil, "", true))
      let cleared = try await readOwnedLocationSources(fixture)
      XCTAssertNil(ownedLocation(cleared, kind: owner.kind))
      try await invokeOwnedLocationIntent(owner, operation: .text(nil, "  新住所  ", false))
      let addressOnly = try await readOwnedLocationSources(fixture)
      XCTAssertEqual(
        ownedLocation(addressOnly, kind: owner.kind),
        .init(displayName: nil, formattedAddress: "  新住所  ", coordinate: nil))
      try await invokeOwnedLocationIntent(owner, operation: .text("New authored place", nil, false))
      let after = try await readOwnedLocationSources(fixture)
      XCTAssertEqual(
        ownedLocation(after, kind: owner.kind),
        .init(displayName: "New authored place", formattedAddress: "  新住所  ", coordinate: nil))
      assertOwnedLocationPreservesOtherData(before, after, changedKind: owner.kind)
    }
    try await assertOwnedLocationPlanningContexts(
      fixture, planner: fixture.planner, session: fixture.session)
  }

  func testAddressOnlyNativeLocationRejectsWithoutChangingEitherOwner() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    let address = PlaceDescriptor(
      representations: [.address("Tokyo, Japan")], commonName: "A name is not a point")
    for owner in [fixture.item, fixture.itinerary] {
      do {
        try await invokeOwnedLocationIntent(owner, operation: .pin(address))
        XCTFail("An address without a resolved point cannot replace a saved pin.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await readOwnedLocationSources(fixture)
    assertOwnedLocationPreservesOtherData(before, after, changedKind: nil)
    try await assertOwnedLocationPlanningContexts(
      fixture, planner: fixture.planner, session: fixture.session)
  }

  func testNativeCoordinateBoundsAndNewPinOnlyLocationsRemainExact() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    for owner in [fixture.item, fixture.itinerary] {
      try await invokeOwnedLocationIntent(owner, operation: .clear)
      let before = try await readOwnedLocationSources(fixture)
      for coordinate in [
        PlannerCoordinate(latitude: -90, longitude: -180),
        .init(latitude: 90, longitude: 180), .init(latitude: 0, longitude: 0),
      ] {
        let location = PlaceDescriptor(
          representations: [
            .coordinate(
              .init(
                latitude: coordinate.latitude, longitude: coordinate.longitude))
          ], commonName: "Not authored")
        try await invokeOwnedLocationIntent(owner, operation: .pin(location))
        let after = try await readOwnedLocationSources(fixture)
        XCTAssertEqual(
          ownedLocation(after, kind: owner.kind),
          .init(displayName: nil, formattedAddress: nil, coordinate: coordinate))
        assertOwnedLocationPreservesOtherData(before, after, changedKind: owner.kind)
      }
    }
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readOwnedLocationSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(
      after.item.content.location,
      .init(
        displayName: nil, formattedAddress: nil,
        coordinate: .init(latitude: 0, longitude: 0)))
    XCTAssertEqual(after.itinerary.content.location, after.item.content.location)
    try await assertOwnedLocationPlanningContexts(fixture, planner: reopened, session: session)
  }

  func testMissingMismatchedAndDeletedSelectionsNeverRetargetOrRecreateData() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    for kind in [PlannerEntityKind.item, .itinerary] {
      for identifier in [UUID(), fixture.list.id] {
        for operation in representativeOwnedLocationOperations() {
          do {
            try await invokeOwnedLocationIntent(
              .init(kind: kind, id: identifier), operation: operation)
            XCTFail("Missing or mismatched selections must not edit a different owner.")
          } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        }
      }
    }
    let unchanged = try await readOwnedLocationSources(fixture)
    assertOwnedLocationPreservesOtherData(before, unchanged, changedKind: nil)
    for owner in [fixture.item, fixture.itinerary] {
      let command = PlannerCommand.deleteSource(source: owner)
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: command),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(),
            session: fixture.session, command: command, reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
      for operation in representativeOwnedLocationOperations() {
        do {
          try await invokeOwnedLocationIntent(owner, operation: operation)
          XCTFail("A location action must not recreate a deleted owner.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      guard
        case .failed(let reason) = await fixture.planner.read(
          session: fixture.session, request: .source(owner))
      else { return XCTFail("A deleted owner must stay missing.") }
      XCTAssertEqual(reason.code, "missingReference")
    }
    guard
      case .source(.list(let list)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.list))
    else { return XCTFail("Deleting the source must retain its former List.") }
    XCTAssertEqual(list.content, before.list.content)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testPrecancelledActionsPreserveEveryLocationFieldTimestampAndContext() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    let before = try await readOwnedLocationSources(fixture)
    for owner in [fixture.item, fixture.itinerary] {
      for operation in representativeOwnedLocationOperations() {
        let request = Task { try await invokeOwnedLocationIntent(owner, operation: operation) }
        request.cancel()
        do {
          try await request.value
          XCTFail("A precancelled location action cannot acknowledge a change.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    let after = try await readOwnedLocationSources(fixture)
    assertOwnedLocationPreservesOtherData(before, after, changedKind: nil)
    try await assertOwnedLocationPlanningContexts(
      fixture, planner: fixture.planner, session: fixture.session)
  }

  func testUnavailableStorageRejectsAllLocationActionsWithoutRemovingTheObstruction() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    for kind in [PlannerEntityKind.item, .itinerary] {
      for operation in representativeOwnedLocationOperations() {
        do {
          try await invokeOwnedLocationIntent(.init(kind: kind, id: UUID()), operation: operation)
          XCTFail("Unavailable storage cannot acknowledge a location change.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testEveryAppliedLocationActionSurvivesRecoveryFailureAndNativeAcknowledgementWithoutReplay()
    async throws
  {
    for kind in [PlannerEntityKind.item, .itinerary] {
      for operation in representativeOwnedLocationOperations() {
        let fixture = try await makeOwnedLocationIntentFixture()
        let before = try await readOwnedLocationSources(fixture)
        var owner = fixture.item
        if kind == .itinerary { owner = fixture.itinerary }
        await fixture.store.open()
        XCTAssertTrue(fixture.store.isReady)
        let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
        let observer = NotificationCenter.default.addObserver(
          forName: ModelContext.didSave, object: nil, queue: nil
        ) {
          notification in obstruction.observe(notification)
        }
        defer {
          NotificationCenter.default.removeObserver(observer)
          try? obstruction.restore()
        }
        try await invokeOwnedLocationIntent(owner, operation: operation)
        XCTAssertTrue(obstruction.didObstruct)
        XCTAssertTrue(fixture.store.recoveryBlocked)
        XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
        let operationIdentifier = try XCTUnwrap(
          fixture.store.incompleteRecoveryOperationIdentifiers.first)
        do {
          try await invokeOwnedLocationIntent(
            owner, operation: .text("Must remain blocked", nil, false))
          XCTFail("Another change must stay blocked until the applied operation is recovered.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
        NotificationCenter.default.removeObserver(observer)
        try obstruction.restore()
        let reopened = PlannerCore.Planner(configuration: fixture.configuration)
        guard case .ready(let session) = await reopened.bootstrap() else {
          throw CancellationError()
        }
        let applied = try await readOwnedLocationSources(
          fixture, planner: reopened, session: session)
        XCTAssertNotEqual(ownedLocation(applied, kind: kind), ownedLocation(before, kind: kind))
        assertOwnedLocationPreservesOtherData(before, applied, changedKind: kind)
        await fixture.store.retryIncompleteRecovery()
        XCTAssertFalse(fixture.store.recoveryBlocked)
        guard
          case .appliedRecoveryComplete = await reopened.operationStatus(
            session: session, operationId: operationIdentifier)
        else {
          return XCTFail("Native retry must acknowledge the original applied location operation.")
        }
        let recovered = try await readOwnedLocationSources(
          fixture, planner: reopened, session: session)
        assertOwnedLocationPreservesOtherData(applied, recovered, changedKind: nil)
        try await assertOwnedLocationPlanningContexts(fixture, planner: reopened, session: session)
        try await invokeOwnedLocationIntent(owner, operation: .text("After recovery", nil, false))
        let later = try await readOwnedLocationSources(fixture, planner: reopened, session: session)
        XCTAssertEqual(ownedLocation(later, kind: kind)?.displayName, "After recovery")
        XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
      }
    }
  }

  func testLocationChangesKeepArchiveAndGlobalCompletionWithoutRewritingLocalFlags() async throws {
    let fixture = try await makeOwnedLocationIntentFixture()
    for command in [
      PlannerCommand.setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true),
      .setArchive(source: fixture.item, archived: true),
      .setArchive(source: fixture.itinerary, archived: true),
    ] {
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(),
            session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    for owner in [fixture.item, fixture.itinerary] {
      for operation in representativeOwnedLocationOperations() {
        let before = try await readOwnedLocationSources(fixture)
        try await invokeOwnedLocationIntent(owner, operation: operation)
        let after = try await readOwnedLocationSources(fixture)
        assertOwnedLocationPreservesOtherData(before, after, changedKind: owner.kind)
      }
    }
    for (index, appearance) in fixture.appearances.enumerated() {
      guard
        case .appearance(let saved) = await fixture.planner.read(
          session: fixture.session, request: .appearance(appearance))
      else { return XCTFail("Archived owners must retain their appearance identities.") }
      XCTAssertTrue(saved.globalDone)
      XCTAssertEqual(saved.localDone, index < 2)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }
}

private enum OwnedLocationIntentOperation {
  case text(String?, String?, Bool)
  case pin(PlaceDescriptor)
  case clear
}

private func representativeOwnedLocationOperations() -> [OwnedLocationIntentOperation] {
  [
    .text("Edited place", "Edited address", false),
    .pin(
      PlaceDescriptor(
        representations: [.coordinate(.init(latitude: 12.5, longitude: -34.5))], commonName: nil)),
    .clear,
  ]
}

@MainActor
private func invokeOwnedLocationIntent(
  _ owner: PlannerEntityReference, operation: OwnedLocationIntentOperation
) async throws {
  switch (owner.kind, operation) {
  case (.item, .text(let placeName, let address, let removeSavedPin)):
    let editing = EditPlannerItemLocationIntent()
    editing.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    editing.placeName = placeName
    editing.address = address
    editing.removeSavedPin = removeSavedPin
    let _: Void = try await editing.callAsFunction(donate: false)
  case (.itinerary, .text(let placeName, let address, let removeSavedPin)):
    let editing = EditPlannerItineraryLocationIntent()
    editing.itinerary = .init(id: owner.id, title: "Cached route", archived: true)
    editing.placeName = placeName
    editing.address = address
    editing.removeSavedPin = removeSavedPin
    let _: Void = try await editing.callAsFunction(donate: false)
  case (.item, .pin(let location)):
    let setting = SetPlannerItemLocationPinIntent()
    setting.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    setting.location = location
    let _: Void = try await setting.callAsFunction(donate: false)
  case (.itinerary, .pin(let location)):
    let setting = SetPlannerItineraryLocationPinIntent()
    setting.itinerary = .init(id: owner.id, title: "Cached route", archived: true)
    setting.location = location
    let _: Void = try await setting.callAsFunction(donate: false)
  case (.item, .clear):
    let clearing = ClearPlannerItemLocationIntent()
    clearing.item = .init(id: owner.id, title: "Cached Item", done: true, archived: true)
    let _: Void = try await clearing.callAsFunction(donate: false)
  case (.itinerary, .clear):
    let clearing = ClearPlannerItineraryLocationIntent()
    clearing.itinerary = .init(id: owner.id, title: "Cached route", archived: true)
    let _: Void = try await clearing.callAsFunction(donate: false)
  default: throw CancellationError()
  }
}

private func ownedLocation(_ observations: OwnedLocationSourceObservations, kind: PlannerEntityKind)
  -> PlannerOwnedLocation?
{
  if kind == .item { return observations.item.content.location }
  return observations.itinerary.content.location
}

private struct OwnedLocationIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let list: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let appearances: [PlannerAppearance]
  let schedules: [PlannerEntityReference]
}

private struct OwnedLocationSourceObservations {
  let item: PlannerItemSourceRead
  let list: PlannerListSourceRead
  let itinerary: PlannerItinerarySourceRead
}

@MainActor
private func makeOwnedLocationIntentFixture() async throws -> OwnedLocationIntentFixture {
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
  let category = try await save(.createCategory(content: .init(name: "Museum")))
  let tag = try await save(.createTag(content: .init(name: "Rainy day")))
  let categoryIdentifier = try XCTUnwrap(category.generated.first?.id)
  let tagIdentifier = try XCTUnwrap(tag.generated.first?.id)
  let createdItem = try await save(
    .createItem(
      content: .init(
        title: "Museum", subtitle: "Booking", notes: "Keep notes",
        location: .init(
          displayName: "Saved place", formattedAddress: "Original address",
          coordinate: .init(latitude: 35.6622, longitude: 139.7171)),
        estimate: .init(minutes: 125, displayUnit: .hour),
        links: [
          .init(
            originalUrl: "https://www.google.com/maps/search/?api=1&query=35.6622,139.7171",
            label: "Original Maps link"),
          .init(originalUrl: "https://example.com/museum", label: "Guide"),
        ],
        categoryIds: [categoryIdentifier], tagIds: [tagIdentifier])))
  let item = try XCTUnwrap(createdItem.generated.first)
  let createdList = try await save(.createList(content: .init(name: "Wishlist")))
  let list = try XCTUnwrap(createdList.generated.first)
  let membership = try await save(
    .addMembership(itemId: item.id, listId: list.id, placement: .last))
  guard case .membership(let membershipIdentifier, _, _)? = membership.generatedReferences.first
  else { throw CancellationError() }
  let createdItinerary = try await save(
    .createItinerary(
      content: .init(
        title: "Weekend", notes: "Keep route notes",
        location: .init(
          displayName: "Meeting point", formattedAddress: "Meeting address",
          coordinate: .init(latitude: 48.8584, longitude: 2.2945)),
        links: [.init(originalUrl: "https://example.com/route", label: "Route")],
        categoryIds: [categoryIdentifier], tagIds: [tagIdentifier],
        manualEstimate: .init(minutes: 480, displayUnit: .hour))))
  let itinerary = try XCTUnwrap(createdItinerary.generated.first)
  var appearances = [
    PlannerAppearance.listMembership(listId: list.id, membershipId: membershipIdentifier)
  ]
  for _ in 0..<2 {
    let added = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard case .itineraryEntry(let entryIdentifier, _, _)? = added.generatedReferences.first
    else { throw CancellationError() }
    appearances.append(.directItineraryItem(itineraryId: itinerary.id, entryId: entryIdentifier))
  }
  for appearance in appearances.prefix(2) {
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
  }
  var schedules: [PlannerEntityReference] = []
  for (source, form) in [
    (
      item,
      PlannerScheduleForm.timed(
        start: Date(timeIntervalSinceReferenceDate: 814_000_000),
        end: Date(timeIntervalSinceReferenceDate: 814_007_200), planningTimeZone: "Asia/Tokyo")
    ),
    (
      itinerary,
      .allDay(
        start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))
    ),
  ] {
    let created = try await save(.createSchedule(source: source, form: form))
    schedules.append(try XCTUnwrap(created.generated.first))
  }
  return .init(
    configuration: configuration, store: store, planner: planner, session: session,
    item: item, list: list, itinerary: itinerary, appearances: appearances, schedules: schedules)
}

@MainActor
private func readOwnedLocationSources(
  _ fixture: OwnedLocationIntentFixture,
  planner: PlannerCore.Planner? = nil, session: PlannerDatasetSession? = nil
) async throws -> OwnedLocationSourceObservations {
  let planner = planner ?? fixture.planner
  let session = session ?? fixture.session
  guard
    case .source(.item(let item)) = await planner.read(
      session: session, request: .source(fixture.item)),
    case .source(.list(let list)) = await planner.read(
      session: session, request: .source(fixture.list)),
    case .source(.itinerary(let itinerary)) = await planner.read(
      session: session, request: .source(fixture.itinerary))
  else { throw CancellationError() }
  return .init(item: item, list: list, itinerary: itinerary)
}

@MainActor
private func assertOwnedLocationPreservesOtherData(
  _ before: OwnedLocationSourceObservations,
  _ after: OwnedLocationSourceObservations, changedKind: PlannerEntityKind?
) {
  let ignoredItemFields: Set<PlannerItemField> = changedKind == .item ? [.location] : []
  var ignoredItineraryFields: Set<PlannerItineraryField> = []
  if changedKind == .itinerary { ignoredItineraryFields = [.location] }
  XCTAssertEqual(
    after.item.fieldHashes.filter { !ignoredItemFields.contains($0.key) },
    before.item.fieldHashes.filter { !ignoredItemFields.contains($0.key) })
  XCTAssertEqual(
    after.itinerary.fieldHashes.filter { !ignoredItineraryFields.contains($0.key) },
    before.itinerary.fieldHashes.filter { !ignoredItineraryFields.contains($0.key) })
  XCTAssertEqual(after.list.fieldHashes, before.list.fieldHashes)
  XCTAssertEqual(after.list.updatedAt, before.list.updatedAt)
  XCTAssertEqual(after.list.state.archived, before.list.state.archived)
  XCTAssertEqual(after.item.sourceLifetimeId, before.item.sourceLifetimeId)
  XCTAssertEqual(after.itinerary.sourceLifetimeId, before.itinerary.sourceLifetimeId)
  XCTAssertEqual(after.item.createdAt, before.item.createdAt)
  XCTAssertEqual(after.itinerary.createdAt, before.itinerary.createdAt)
  XCTAssertEqual(after.item.references, before.item.references)
  XCTAssertEqual(after.list.references, before.list.references)
  XCTAssertEqual(after.itinerary.references, before.itinerary.references)
  XCTAssertEqual(after.item.state.globalDone, before.item.state.globalDone)
  XCTAssertEqual(after.item.state.archived, before.item.state.archived)
  XCTAssertEqual(after.itinerary.state.archived, before.itinerary.state.archived)
  if changedKind != .item { XCTAssertEqual(after.item.updatedAt, before.item.updatedAt) }
  if changedKind != .itinerary {
    XCTAssertEqual(after.itinerary.updatedAt, before.itinerary.updatedAt)
  }
}

@MainActor
private func assertOwnedLocationPlanningContexts(
  _ fixture: OwnedLocationIntentFixture,
  planner: PlannerCore.Planner, session: PlannerDatasetSession
) async throws {
  for (index, appearance) in fixture.appearances.enumerated() {
    guard
      case .appearance(let saved) = await planner.read(
        session: session, request: .appearance(appearance))
    else { return XCTFail("Location editing must retain each independent appearance.") }
    XCTAssertFalse(saved.globalDone)
    XCTAssertEqual(saved.localDone, index < 2)
  }
  let forms: [PlannerScheduleForm] = [
    .timed(
      start: Date(timeIntervalSinceReferenceDate: 814_000_000),
      end: Date(timeIntervalSinceReferenceDate: 814_007_200), planningTimeZone: "Asia/Tokyo"),
    .allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21)),
  ]
  for (index, schedule) in fixture.schedules.enumerated() {
    guard
      case .source(.schedule(let saved)) = await planner.read(
        session: session, request: .source(schedule))
    else { return XCTFail("Location editing must retain booked Schedules.") }
    XCTAssertEqual(saved.content.form, forms[index])
    let owners = [fixture.item, fixture.itinerary]
    XCTAssertEqual(saved.content.source, owners[index])
  }
  XCTAssertFalse(fixture.store.recoveryBlocked)
  XCTAssertFalse(fixture.store.isSaving)
}
