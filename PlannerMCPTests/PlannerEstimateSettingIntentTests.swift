import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerEstimateSettingIntentTests: XCTestCase {
  func testManualPlanEstimatesPreserveChildrenAndIndependentBudgets() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let listCreation = CreatePlannerListIntent()
    listCreation.name = "Food"
    let list = try await listCreation.callAsFunction(donate: false)
    let itemCreation = CreatePlannerItemIntent()
    itemCreation.title = "Lunch"
    itemCreation.list = list
    let item = try await itemCreation.callAsFunction(donate: false)
    let itineraryCreation = CreatePlannerItineraryIntent()
    itineraryCreation.title = "Weekend"
    let itinerary = try await itineraryCreation.callAsFunction(donate: false)
    let listSetting = SetPlannerListEstimateIntent()
    listSetting.list = list
    listSetting.quantity = 2
    listSetting.unit = .hour
    listSetting.additionalMinutes = 5
    let _: Void = try await listSetting.callAsFunction(donate: false)
    let itinerarySetting = SetPlannerItineraryEstimateIntent()
    itinerarySetting.itinerary = itinerary
    itinerarySetting.quantity = 1
    itinerarySetting.unit = .day
    itinerarySetting.additionalMinutes = 30
    let _: Void = try await itinerarySetting.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.list(let savedList)) = await reopened.read(
        session: session, request: .source(.init(kind: .list, id: list.id))),
      case .source(.itinerary(let savedItinerary)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id))),
      case .source(.item(let savedItem)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("Both manual estimates and their original sources must persist.") }
    XCTAssertEqual(savedList.content.manualEstimate, .init(minutes: 125, displayUnit: .hour))
    XCTAssertEqual(savedList.estimates.fullEstimate, .exact(minutes: 125))
    XCTAssertEqual(savedList.progress.totalCount, 1)
    XCTAssertEqual(savedList.progress.state, .partial)
    XCTAssertEqual(savedItinerary.content.manualEstimate, .init(minutes: 1_470, displayUnit: .day))
    XCTAssertEqual(savedItinerary.estimates.fullEstimate, .exact(minutes: 1_470))
    XCTAssertEqual(savedItinerary.progress.state, .empty)
    XCTAssertNil(savedItem.content.estimate)
    XCTAssertEqual(savedItem.content.title, "Lunch")
    XCTAssertFalse(store.recoveryBlocked)
  }

  func testItemMixedEstimatePreservesOwnedContentAndPersistsExactMinutes() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.subtitle = "Keep subtitle"
    creation.notes = "Keep notes\n東京"
    let item = try await creation.callAsFunction(donate: false)
    let setting = SetPlannerItemEstimateIntent()
    setting.item = item
    setting.quantity = 2
    setting.unit = .hour
    setting.additionalMinutes = 5
    let _: Void = try await setting.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let saved)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("The estimate must persist on the original Item.") }
    XCTAssertEqual(saved.content.estimate, .init(minutes: 125, displayUnit: .hour))
    XCTAssertEqual(saved.content.title, "Museum")
    XCTAssertEqual(saved.content.subtitle, "Keep subtitle")
    XCTAssertEqual(saved.content.notes, "Keep notes\n東京")
    XCTAssertEqual(saved.state.globalDone, false)
    XCTAssertEqual(saved.state.archived, false)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }
  func testEveryUnitAndTheFullIntegerRangePersistWithoutChangingOtherFields() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let values: [(PlannerEstimateUnitChoice, Int, Int, Int64, PlannerEstimateUnit)] = [
      (.minute, 1, 0, 1, .minute), (.hour, 2, 5, 125, .hour),
      (.day, 2, 5, 2_885, .day), (.week, 2, 5, 20_165, .week),
      (.month, 2, 5, 86_405, .month), (.year, 2, 5, 1_051_205, .year),
      (.year, 17_548_272_520_652, 84_607, Int64.max, .year),
      (.minute, Int.max, 0, Int64.max, .minute), (.hour, 0, 5, 5, .hour),
    ]
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      for (unit, quantity, additional, expectedMinutes, expectedUnit) in values {
        let before = try await readEstimateResetSources(fixture)
        try await setEstimate(for: source, quantity: quantity, unit: unit, additional: additional)
        let after = try await readEstimateResetSources(fixture)
        let expected = PlannerEstimate(minutes: expectedMinutes, displayUnit: expectedUnit)
        switch source.kind {
        case .item: XCTAssertEqual(after.item.content.estimate, expected)
        case .list: XCTAssertEqual(after.list.content.manualEstimate, expected)
        case .itinerary: XCTAssertEqual(after.itinerary.content.manualEstimate, expected)
        default: XCTFail("Only Item and plan estimates can be set.")
        }
        assertEstimateResetPreservesOtherFields(before, after, changedKind: source.kind)
        try await assertEstimateResetContextsAndBookings(
          fixture, planner: fixture.planner, session: fixture.session)
      }
    }
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let saved = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertEqual(saved.item.content.estimate, .init(minutes: 5, displayUnit: .hour))
    XCTAssertEqual(saved.list.content.manualEstimate, .init(minutes: 5, displayUnit: .hour))
    XCTAssertEqual(saved.itinerary.content.manualEstimate, .init(minutes: 5, displayUnit: .hour))
  }

  func testInvalidInputsAndMissingOrWrongKindSelectionsLeaveTheWholeGraphUnchanged() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let invalid: [(Int, PlannerEstimateUnitChoice, Int)] = [
      (-1, .hour, 5), (1, .hour, -1), (0, .minute, 0),
      (Int.max, .hour, 0), (Int.max, .minute, 1),
      (17_548_272_520_653, .year, 0), (17_548_272_520_652, .year, 84_608),
    ]
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      for (quantity, unit, additional) in invalid {
        do {
          try await setEstimate(for: source, quantity: quantity, unit: unit, additional: additional)
          XCTFail("Invalid or overflowing input must not acknowledge a saved estimate.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
      let wrongIdentifier = source.kind == .item ? fixture.list.id : fixture.item.id
      for identifier in [UUID(), wrongIdentifier] {
        do {
          try await setEstimate(for: .init(kind: source.kind, id: identifier))
          XCTFail("Missing or wrong-kind selections must not redirect an estimate change.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testPrecancelledActionsAndUnavailableStorageCannotAcknowledgeChanges() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      let task = Task { try await self.setEstimate(for: source) }
      task.cancel()
      do {
        try await task.value
        XCTFail("Precancelled actions must leave estimates unchanged.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await readEstimateResetSources(fixture)
    assertEstimateResetPreservesOtherFields(before, after, changedKind: nil)
    let (directory, _, unavailable) = try makePlannerIntentStorage()
    let obstruction = Data("Store parent is a file".utf8)
    try obstruction.write(to: directory.appending(path: "store"))
    AppDependencyManager.shared.add(dependency: unavailable)
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      do {
        try await setEstimate(for: source)
        XCTFail("Unavailable storage cannot acknowledge an estimate.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: directory.appending(path: "store")), obstruction)
    XCTAssertFalse(unavailable.isReady)
    XCTAssertFalse(unavailable.isSaving)
    XCTAssertNotNil(unavailable.openingFailure)
  }

  func testAppliedEstimatesSurviveIncompleteRecoveryAndCheckpointRetryWithoutReplay() async throws {
    for kind in [PlannerEntityKind.item, .list, .itinerary] {
      let fixture = try await makeEstimateResetIntentFixture()
      let source: PlannerEntityReference
      switch kind {
      case .item: source = fixture.item
      case .list: source = fixture.list
      default: source = fixture.itinerary
      }
      let before = try await readEstimateResetSources(fixture)
      await fixture.store.open()
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      try await setEstimate(for: source)
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      let operation = try XCTUnwrap(fixture.store.incompleteRecoveryOperationIdentifiers.first)
      do {
        try await setEstimate(for: source, quantity: 3)
        XCTFail("Later actions must wait for recovery of the applied estimate.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operation])
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
      let applied = try await readEstimateResetSources(fixture, planner: reopened, session: session)
      switch kind {
      case .item:
        XCTAssertEqual(applied.item.content.estimate, .init(minutes: 125, displayUnit: .hour))
      case .list:
        XCTAssertEqual(applied.list.content.manualEstimate, .init(minutes: 125, displayUnit: .hour))
      default:
        XCTAssertEqual(
          applied.itinerary.content.manualEstimate, .init(minutes: 125, displayUnit: .hour))
      }
      assertEstimateResetPreservesOtherFields(before, applied, changedKind: kind)
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: session, operationId: operation)
      else { return XCTFail("Retry must acknowledge the original estimate operation.") }
      let recovered = try await readEstimateResetSources(
        fixture, planner: reopened, session: session)
      assertEstimateResetPreservesOtherFields(applied, recovered, changedKind: nil)
      try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
    }
  }

  func testArchivedDoneSourcesAcceptEstimatesButDeletedSourcesCannotBeResurrected() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
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
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      let before = try await readEstimateResetSources(fixture)
      try await setEstimate(for: source)
      let after = try await readEstimateResetSources(fixture)
      assertEstimateResetPreservesOtherFields(before, after, changedKind: source.kind)
    }
    try await assertArchivedEstimateStates(fixture)
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      let command = PlannerCommand.deleteSource(source: source)
      guard
        case .reviewed(let review) = await fixture.planner.prepareReview(
          session: fixture.session, command: command),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: command,
            reviewToken: review.reviewToken)
        ).outcome,
        case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      do {
        try await setEstimate(for: source)
        XCTFail("A stale selection cannot recreate a deleted source.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      XCTAssertEqual(after, before)
    }
  }

  private func assertArchivedEstimateStates(
    _ fixture: EstimateResetIntentFixture
  ) async throws {
    let sources = try await readEstimateResetSources(fixture)
    XCTAssertEqual(sources.item.state.globalDone, true)
    XCTAssertEqual(sources.item.state.archived, true)
    XCTAssertEqual(sources.list.state.archived, true)
    XCTAssertEqual(sources.itinerary.state.archived, true)
    XCTAssertEqual(sources.list.estimates.remainingEstimate, .exact(minutes: 0))
    XCTAssertEqual(sources.itinerary.estimates.remainingEstimate, .exact(minutes: 0))
  }

  private func setEstimate(
    for source: PlannerEntityReference, quantity: Int = 2,
    unit: PlannerEstimateUnitChoice = .hour, additional: Int = 5
  ) async throws {
    switch source.kind {
    case .item:
      let intent = SetPlannerItemEstimateIntent()
      intent.item = .init(id: source.id, title: "Cached Item", done: true, archived: true)
      intent.quantity = quantity
      intent.unit = unit
      intent.additionalMinutes = additional
      let _: Void = try await intent.callAsFunction(donate: false)
    case .list:
      let intent = SetPlannerListEstimateIntent()
      intent.list = .init(id: source.id, name: "Cached List", archived: true)
      intent.quantity = quantity
      intent.unit = unit
      intent.additionalMinutes = additional
      let _: Void = try await intent.callAsFunction(donate: false)
    case .itinerary:
      let intent = SetPlannerItineraryEstimateIntent()
      intent.itinerary = .init(id: source.id, title: "Cached Itinerary", archived: true)
      intent.quantity = quantity
      intent.unit = unit
      intent.additionalMinutes = additional
      let _: Void = try await intent.callAsFunction(donate: false)
    default: throw CancellationError()
    }
  }
}
