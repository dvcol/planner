import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerEstimateResetIntentTests: XCTestCase {
  func testClearingItemEstimatePreservesContextsBookingsAndManualContainerBudgets() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    XCTAssertEqual(before.item.content.estimate, .init(minutes: 90, displayUnit: .hour))
    let clearing = ClearPlannerItemEstimateIntent()
    clearing.item = .init(id: fixture.item.id, title: "Cached Item", done: true, archived: true)
    let _: Void = try await clearing.callAsFunction(donate: false)
    let _: Void = try await clearing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertNil(after.item.content.estimate)
    XCTAssertEqual(after.lunch.content.estimate, .init(minutes: 30, displayUnit: .minute))
    XCTAssertEqual(after.list.content.manualEstimate, .init(minutes: 240, displayUnit: .hour))
    XCTAssertEqual(after.itinerary.content.manualEstimate, .init(minutes: 480, displayUnit: .hour))
    XCTAssertEqual(
      after.list.estimates.calculatedEstimate, .lowerBound(minutes: 30, missingEstimateCount: 1))
    XCTAssertEqual(after.list.estimates.fullEstimate, .exact(minutes: 240))
    XCTAssertEqual(
      after.list.estimates.remainingEstimate,
      .upperBound(minutes: 240, missingFinishedEstimateCount: 1))
    XCTAssertEqual(
      after.itinerary.estimates.calculatedEstimate,
      .lowerBound(minutes: 480, missingEstimateCount: 1))
    assertEstimateResetPreservesOtherFields(before, after, changedKind: .item)
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }
  func testListResetUsesLiveChildrenWithoutClearingTheItineraryManualBudget() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    XCTAssertEqual(before.list.content.manualEstimate, .init(minutes: 240, displayUnit: .hour))
    XCTAssertEqual(before.itinerary.estimates.calculatedEstimate, .exact(minutes: 570))
    let reset = UsePlannerListCalculatedEstimateIntent()
    reset.list = .init(id: fixture.list.id, name: "Cached List", archived: true)
    let _: Void = try await reset.callAsFunction(donate: false)
    let _: Void = try await reset.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertNil(after.list.content.manualEstimate)
    XCTAssertEqual(after.list.estimates.calculatedEstimate, .exact(minutes: 120))
    XCTAssertEqual(after.list.estimates.fullEstimate, .exact(minutes: 120))
    XCTAssertEqual(after.list.estimates.remainingEstimate, .exact(minutes: 30))
    XCTAssertEqual(after.itinerary.content.manualEstimate, .init(minutes: 480, displayUnit: .hour))
    XCTAssertEqual(after.itinerary.estimates.calculatedEstimate, .exact(minutes: 330))
    XCTAssertEqual(after.itinerary.estimates.fullEstimate, .exact(minutes: 480))
    XCTAssertEqual(after.itinerary.estimates.remainingEstimate, .exact(minutes: 390))
    assertEstimateResetPreservesOtherFields(before, after, changedKind: .list)
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }
  func testItineraryResetUsesRepeatedListBudgetsAndItsOwnCompletionContexts() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    XCTAssertEqual(before.itinerary.content.manualEstimate, .init(minutes: 480, displayUnit: .hour))
    XCTAssertEqual(before.itinerary.estimates.remainingEstimate, .exact(minutes: 390))
    let reset = UsePlannerItineraryCalculatedEstimateIntent()
    reset.itinerary = .init(id: fixture.itinerary.id, title: "Cached Itinerary", archived: true)
    let _: Void = try await reset.callAsFunction(donate: false)
    let _: Void = try await reset.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertNil(after.itinerary.content.manualEstimate)
    XCTAssertEqual(after.itinerary.estimates.calculatedEstimate, .exact(minutes: 570))
    XCTAssertEqual(after.itinerary.estimates.fullEstimate, .exact(minutes: 570))
    XCTAssertEqual(after.itinerary.estimates.remainingEstimate, .exact(minutes: 480))
    XCTAssertEqual(after.list.content.manualEstimate, .init(minutes: 240, displayUnit: .hour))
    XCTAssertEqual(after.list.estimates.fullEstimate, .exact(minutes: 240))
    XCTAssertEqual(after.list.estimates.remainingEstimate, .exact(minutes: 150))
    assertEstimateResetPreservesOtherFields(before, after, changedKind: .itinerary)
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }
  func testCalculatedResetRetainsMissingEstimateBoundsAcrossRepeatedListAppearances() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      try await resetEstimate(for: source)
    }
    let reopened = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let after = try await readEstimateResetSources(fixture, planner: reopened, session: session)
    XCTAssertNil(after.item.content.estimate)
    XCTAssertNil(after.list.content.manualEstimate)
    XCTAssertNil(after.itinerary.content.manualEstimate)
    XCTAssertEqual(
      after.list.estimates.fullEstimate, .lowerBound(minutes: 30, missingEstimateCount: 1))
    XCTAssertEqual(after.list.estimates.remainingEstimate, .exact(minutes: 30))
    XCTAssertEqual(
      after.itinerary.estimates.fullEstimate, .lowerBound(minutes: 60, missingEstimateCount: 3))
    XCTAssertEqual(
      after.itinerary.estimates.remainingEstimate, .lowerBound(minutes: 60, missingEstimateCount: 2)
    )
    try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
  }

  func testResettingEmptyContainersKeepsNoItemsAndCalculatedZero() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    for command in [
      PlannerCommand.createList(
        content: .init(
          name: "Empty List", notes: "Keep notes",
          manualEstimate: .init(minutes: 125, displayUnit: .hour))),
      .createItinerary(
        content: .init(
          title: "Empty Itinerary", notes: "Keep notes",
          manualEstimate: .init(minutes: 250, displayUnit: .hour))),
    ] {
      guard
        case .applied(let created, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = created.generated.first
      else { throw CancellationError() }
      try await resetEstimate(for: source)
      switch await planner.read(session: session, request: .source(source)) {
      case .source(.list(let list)):
        XCTAssertNil(list.content.manualEstimate)
        XCTAssertEqual(list.content.notes, "Keep notes")
        XCTAssertEqual(list.progress.state, .empty)
        XCTAssertEqual(list.progress.totalCount, 0)
        XCTAssertEqual(list.estimates.fullEstimate, .exact(minutes: 0))
        XCTAssertEqual(list.estimates.remainingEstimate, .exact(minutes: 0))
      case .source(.itinerary(let itinerary)):
        XCTAssertNil(itinerary.content.manualEstimate)
        XCTAssertEqual(itinerary.content.notes, "Keep notes")
        XCTAssertEqual(itinerary.progress.state, .empty)
        XCTAssertEqual(itinerary.progress.totalCount, 0)
        XCTAssertEqual(itinerary.estimates.fullEstimate, .exact(minutes: 0))
        XCTAssertEqual(itinerary.estimates.remainingEstimate, .exact(minutes: 0))
      default: XCTFail("Reset must preserve the original empty container.")
      }
    }
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testMissingWrongKindAndDeletedSelectionsRejectWithoutChangingOrResurrectingSources()
    async throws
  {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      let wrongIdentifier = source.kind == .item ? fixture.list.id : fixture.item.id
      for identifier in [UUID(), wrongIdentifier] {
        do {
          try await resetEstimate(for: .init(kind: source.kind, id: identifier))
          XCTFail("Missing or mismatched selections cannot reset a different source.")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      }
    }
    let unchanged = try await readEstimateResetSources(fixture)
    assertEstimateResetPreservesOtherFields(before, unchanged, changedKind: nil)
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
      do {
        try await resetEstimate(for: source)
        XCTFail("Estimate reset cannot recreate a deleted source.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      guard
        case .failed(let missing) = await fixture.planner.read(
          session: fixture.session, request: .source(source))
      else { return XCTFail("The deleted source must remain missing.") }
      XCTAssertEqual(missing.code, "missingReference")
    }
    guard
      case .source(.item(let lunch)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.lunch))
    else { throw CancellationError() }
    XCTAssertEqual(lunch.fieldHashes, before.lunch.fieldHashes)
    XCTAssertEqual(lunch.updatedAt, before.lunch.updatedAt)
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testPrecancelledResetsLeaveAllSourceFieldsTimestampsAndContextsUntouched() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    let before = try await readEstimateResetSources(fixture)
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      let request = Task { try await self.resetEstimate(for: source) }
      request.cancel()
      do {
        try await request.value
        XCTFail("A precancelled estimate reset cannot acknowledge a change.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    let after = try await readEstimateResetSources(fixture)
    assertEstimateResetPreservesOtherFields(before, after, changedKind: nil)
    try await assertEstimateResetContextsAndBookings(
      fixture, planner: fixture.planner, session: fixture.session)
  }

  func testUnavailableStorageRejectsEveryResetAndPreservesTheObstructingFile() async throws {
    let (directory, _, store) = try makePlannerIntentStorage()
    let parent = directory.appending(path: "store")
    let obstruction = Data("The store parent is a file.".utf8)
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    for kind in [PlannerEntityKind.item, .list, .itinerary] {
      do {
        try await resetEstimate(for: .init(kind: kind, id: UUID()))
        XCTFail("Unavailable storage cannot acknowledge an estimate reset.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

  func testIncompleteRecoveryRetainsEachAppliedResetAndAcknowledgesItWithoutReplay() async throws {
    for kind in [PlannerEntityKind.item, .list, .itinerary] {
      let fixture = try await makeEstimateResetIntentFixture()
      let source: PlannerEntityReference
      let laterSource: PlannerEntityReference
      switch kind {
      case .item:
        source = fixture.item
        laterSource = fixture.list
      case .list:
        source = fixture.list
        laterSource = fixture.itinerary
      default:
        source = fixture.itinerary
        laterSource = fixture.item
      }
      let before = try await readEstimateResetSources(fixture)
      await fixture.store.open()
      XCTAssertTrue(fixture.store.isReady)
      let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      try await resetEstimate(for: source)
      XCTAssertTrue(obstruction.didObstruct)
      XCTAssertTrue(fixture.store.recoveryBlocked)
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers.count, 1)
      let operationIdentifier = try XCTUnwrap(
        fixture.store.incompleteRecoveryOperationIdentifiers.first)
      do {
        try await resetEstimate(for: source)
        XCTFail("Another reset must remain blocked while the applied operation needs recovery.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
      XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      let reopened = PlannerCore.Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
      let applied = try await readEstimateResetSources(fixture, planner: reopened, session: session)
      assertEstimateWasReset(applied, kind: kind)
      assertEstimateResetPreservesOtherFields(before, applied, changedKind: kind)
      await fixture.store.retryIncompleteRecovery()
      XCTAssertFalse(fixture.store.recoveryBlocked)
      guard
        case .appliedRecoveryComplete = await reopened.operationStatus(
          session: session, operationId: operationIdentifier)
      else { return XCTFail("Native retry must acknowledge the original reset operation.") }
      let recovered = try await readEstimateResetSources(
        fixture, planner: reopened, session: session)
      assertEstimateResetPreservesOtherFields(applied, recovered, changedKind: nil)
      try await assertEstimateResetContextsAndBookings(fixture, planner: reopened, session: session)
      try await resetEstimate(for: laterSource)
      let later = try await readEstimateResetSources(fixture, planner: reopened, session: session)
      assertEstimateWasReset(later, kind: laterSource.kind)
      XCTAssertTrue(fixture.store.incompleteRecoveryOperationIdentifiers.isEmpty)
      XCTAssertFalse(fixture.store.isSaving)
    }
  }

  func testArchivedAndGloballyDoneSourcesRetainTheirStatesWhenEstimatesAreReset() async throws {
    let fixture = try await makeEstimateResetIntentFixture()
    for command in [
      PlannerCommand.setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true),
      .setArchive(source: fixture.item, archived: true),
      .setArchive(source: fixture.list, archived: true),
      .setArchive(source: fixture.itinerary, archived: true),
    ] {
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    for source in [fixture.item, fixture.list, fixture.itinerary] {
      let before = try await readEstimateResetSources(fixture)
      try await resetEstimate(for: source)
      let after = try await readEstimateResetSources(fixture)
      assertEstimateWasReset(after, kind: source.kind)
      assertEstimateResetPreservesOtherFields(before, after, changedKind: source.kind)
    }
    let after = try await readEstimateResetSources(fixture)
    XCTAssertEqual(after.item.state.globalDone, true)
    XCTAssertEqual(after.item.state.archived, true)
    XCTAssertEqual(after.list.state.archived, true)
    XCTAssertEqual(after.itinerary.state.archived, true)
    XCTAssertEqual(after.list.estimates.remainingEstimate, .exact(minutes: 0))
    XCTAssertEqual(after.itinerary.estimates.remainingEstimate, .exact(minutes: 0))
    for (branchIdentifier, expectedLocal) in [
      (fixture.firstBranchIdentifier, true), (fixture.secondBranchIdentifier, false),
    ] {
      guard
        case .appearance(let saved) = await fixture.planner.read(
          session: fixture.session,
          request: .appearance(
            .expandedListItem(
              itineraryId: fixture.itinerary.id, listEntryId: branchIdentifier,
              membershipId: fixture.membershipIdentifier)))
      else { throw CancellationError() }
      XCTAssertTrue(saved.globalDone)
      XCTAssertEqual(saved.localDone, expectedLocal)
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
    XCTAssertFalse(fixture.store.isSaving)
  }

  private func resetEstimate(for source: PlannerEntityReference) async throws {
    switch source.kind {
    case .item:
      let reset = ClearPlannerItemEstimateIntent()
      reset.item = .init(id: source.id, title: "Cached Item", done: false, archived: false)
      let _: Void = try await reset.callAsFunction(donate: false)
    case .list:
      let reset = UsePlannerListCalculatedEstimateIntent()
      reset.list = .init(id: source.id, name: "Cached List", archived: false)
      let _: Void = try await reset.callAsFunction(donate: false)
    case .itinerary:
      let reset = UsePlannerItineraryCalculatedEstimateIntent()
      reset.itinerary = .init(id: source.id, title: "Cached Itinerary", archived: false)
      let _: Void = try await reset.callAsFunction(donate: false)
    default: throw CancellationError()
    }
  }
}

@MainActor
private func assertEstimateWasReset(
  _ sources: EstimateResetSourceObservations, kind: PlannerEntityKind
) {
  switch kind {
  case .item: XCTAssertNil(sources.item.content.estimate)
  case .list: XCTAssertNil(sources.list.content.manualEstimate)
  case .itinerary: XCTAssertNil(sources.itinerary.content.manualEstimate)
  default: XCTFail("Only Item, List and Itinerary estimate settings can be reset.")
  }
}

private struct EstimateResetIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let lunch: PlannerEntityReference
  let list: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let membershipIdentifier: UUID
  let lunchMembershipIdentifier: UUID
  let firstBranchIdentifier: UUID
  let secondBranchIdentifier: UUID
  let directEntryIdentifier: UUID
  let itemSchedule: PlannerEntityReference
  let itinerarySchedule: PlannerEntityReference
}

private struct EstimateResetSourceObservations {
  let item: PlannerItemSourceRead
  let lunch: PlannerItemSourceRead
  let list: PlannerListSourceRead
  let itinerary: PlannerItinerarySourceRead
}

@MainActor
private func makeEstimateResetIntentFixture() async throws -> EstimateResetIntentFixture {
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
  let createdCategory = try await save(.createCategory(content: .init(name: "Museums")))
  let category = try XCTUnwrap(createdCategory.generated.first)
  let createdTag = try await save(.createTag(content: .init(name: "booked")))
  let tag = try XCTUnwrap(createdTag.generated.first)
  let createdItem = try await save(
    .createItem(
      content: .init(
        title: "Museum", subtitle: "Opening hours vary", notes: "Keep booking",
        location: .init(
          displayName: "Museum", formattedAddress: "Tokyo",
          coordinate: .init(latitude: 35.6622, longitude: 139.7171)),
        estimate: .init(minutes: 90, displayUnit: .hour),
        links: [.init(originalUrl: "https://example.com/museum", label: "Visit guide")],
        categoryIds: [category.id], tagIds: [tag.id])))
  let item = try XCTUnwrap(createdItem.generated.first)
  let createdLunch = try await save(
    .createItem(
      content: .init(
        title: "Lunch", notes: "Keep lunch", estimate: .init(minutes: 30, displayUnit: .minute))))
  let lunch = try XCTUnwrap(createdLunch.generated.first)
  let createdList = try await save(
    .createList(
      content: .init(
        name: "Tokyo Food", notes: "Keep List",
        manualEstimate: .init(minutes: 240, displayUnit: .hour))))
  let list = try XCTUnwrap(createdList.generated.first)
  let addedItem = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
  let addedLunch = try await save(
    .addMembership(itemId: lunch.id, listId: list.id, placement: .last))
  guard case .membership(let membershipIdentifier, _, _)? = addedItem.generatedReferences.first,
    case .membership(let lunchMembershipIdentifier, _, _)? = addedLunch.generatedReferences.first
  else { throw CancellationError() }
  _ = try await save(
    .setCompletion(
      scope: .appearance(
        .listMembership(
          listId: list.id, membershipId: membershipIdentifier)), done: true))
  let createdItinerary = try await save(
    .createItinerary(
      content: .init(
        title: "Tokyo Weekend", notes: "Keep route", categoryIds: [category.id], tagIds: [tag.id],
        manualEstimate: .init(minutes: 480, displayUnit: .hour))))
  let itinerary = try XCTUnwrap(createdItinerary.generated.first)
  let firstBranch = try await save(
    .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
  let secondBranch = try await save(
    .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
  let directEntry = try await save(
    .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
  guard
    case .itineraryEntry(let firstBranchIdentifier, _, _)? = firstBranch.generatedReferences.first,
    case .itineraryEntry(let secondBranchIdentifier, _, _)? = secondBranch.generatedReferences.first,
    case .itineraryEntry(let directEntryIdentifier, _, _)? = directEntry.generatedReferences.first
  else { throw CancellationError() }
  _ = try await save(
    .setCompletion(
      scope: .appearance(
        .expandedListItem(
          itineraryId: itinerary.id, listEntryId: firstBranchIdentifier,
          membershipId: membershipIdentifier)), done: true))
  let createdItemSchedule = try await save(
    .createSchedule(
      source: item,
      form: .timed(
        start: Date(timeIntervalSinceReferenceDate: 814_000_000),
        end: Date(timeIntervalSinceReferenceDate: 814_007_200), planningTimeZone: "Asia/Tokyo")))
  let itemSchedule = try XCTUnwrap(createdItemSchedule.generated.first)
  let createdItinerarySchedule = try await save(
    .createSchedule(
      source: itinerary,
      form: .allDay(
        start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21))))
  let itinerarySchedule = try XCTUnwrap(createdItinerarySchedule.generated.first)
  return .init(
    configuration: configuration, store: store, planner: planner, session: session,
    item: item, lunch: lunch, list: list, itinerary: itinerary,
    membershipIdentifier: membershipIdentifier,
    lunchMembershipIdentifier: lunchMembershipIdentifier,
    firstBranchIdentifier: firstBranchIdentifier, secondBranchIdentifier: secondBranchIdentifier,
    directEntryIdentifier: directEntryIdentifier, itemSchedule: itemSchedule,
    itinerarySchedule: itinerarySchedule)
}

@MainActor
private func readEstimateResetSources(
  _ fixture: EstimateResetIntentFixture, planner: PlannerCore.Planner? = nil,
  session: PlannerDatasetSession? = nil
) async throws -> EstimateResetSourceObservations {
  let planner = planner ?? fixture.planner
  let session = session ?? fixture.session
  guard
    case .source(.item(let item)) = await planner.read(
      session: session, request: .source(fixture.item)),
    case .source(.item(let lunch)) = await planner.read(
      session: session, request: .source(fixture.lunch)),
    case .source(.list(let list)) = await planner.read(
      session: session, request: .source(fixture.list)),
    case .source(.itinerary(let itinerary)) = await planner.read(
      session: session, request: .source(fixture.itinerary))
  else { throw CancellationError() }
  return .init(item: item, lunch: lunch, list: list, itinerary: itinerary)
}

@MainActor
private func assertEstimateResetPreservesOtherFields(
  _ before: EstimateResetSourceObservations, _ after: EstimateResetSourceObservations,
  changedKind: PlannerEntityKind?
) {
  var ignoredItemFields: Set<PlannerItemField> = []
  var ignoredListFields: Set<PlannerListField> = []
  var ignoredItineraryFields: Set<PlannerItineraryField> = []
  if changedKind == .item { ignoredItemFields = [.estimate] }
  if changedKind == .list { ignoredListFields = [.manualEstimate] }
  if changedKind == .itinerary { ignoredItineraryFields = [.manualEstimate] }
  XCTAssertEqual(
    after.item.fieldHashes.filter { !ignoredItemFields.contains($0.key) },
    before.item.fieldHashes.filter { !ignoredItemFields.contains($0.key) })
  XCTAssertEqual(
    after.list.fieldHashes.filter { !ignoredListFields.contains($0.key) },
    before.list.fieldHashes.filter { !ignoredListFields.contains($0.key) })
  XCTAssertEqual(
    after.itinerary.fieldHashes.filter { !ignoredItineraryFields.contains($0.key) },
    before.itinerary.fieldHashes.filter { !ignoredItineraryFields.contains($0.key) })
  XCTAssertEqual(after.lunch.fieldHashes, before.lunch.fieldHashes)
  XCTAssertEqual(after.lunch.updatedAt, before.lunch.updatedAt)
  XCTAssertEqual(after.item.sourceLifetimeId, before.item.sourceLifetimeId)
  XCTAssertEqual(after.itinerary.sourceLifetimeId, before.itinerary.sourceLifetimeId)
  XCTAssertEqual(after.item.source, before.item.source)
  XCTAssertEqual(after.list.source, before.list.source)
  XCTAssertEqual(after.itinerary.source, before.itinerary.source)
  XCTAssertEqual(after.item.createdAt, before.item.createdAt)
  XCTAssertEqual(after.list.createdAt, before.list.createdAt)
  XCTAssertEqual(after.itinerary.createdAt, before.itinerary.createdAt)
  XCTAssertEqual(after.item.state.globalDone, before.item.state.globalDone)
  XCTAssertEqual(after.item.state.archived, before.item.state.archived)
  XCTAssertEqual(after.list.state.archived, before.list.state.archived)
  XCTAssertEqual(after.itinerary.state.archived, before.itinerary.state.archived)
  XCTAssertEqual(after.item.references, before.item.references)
  XCTAssertEqual(after.list.references, before.list.references)
  XCTAssertEqual(after.itinerary.references, before.itinerary.references)
  if changedKind != .item { XCTAssertEqual(after.item.updatedAt, before.item.updatedAt) }
  if changedKind != .list { XCTAssertEqual(after.list.updatedAt, before.list.updatedAt) }
  if changedKind != .itinerary {
    XCTAssertEqual(after.itinerary.updatedAt, before.itinerary.updatedAt)
  }
}

@MainActor
private func assertEstimateResetContextsAndBookings(
  _ fixture: EstimateResetIntentFixture, planner: PlannerCore.Planner,
  session: PlannerDatasetSession
) async throws {
  let expectedAppearances: [(PlannerAppearance, Bool)] = [
    (.listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier), true),
    (
      .listMembership(listId: fixture.list.id, membershipId: fixture.lunchMembershipIdentifier),
      false
    ),
    (
      .expandedListItem(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.firstBranchIdentifier,
        membershipId: fixture.membershipIdentifier), true
    ),
    (
      .expandedListItem(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.secondBranchIdentifier,
        membershipId: fixture.membershipIdentifier), false
    ),
    (
      .directItineraryItem(
        itineraryId: fixture.itinerary.id, entryId: fixture.directEntryIdentifier), false
    ),
  ]
  for (appearance, expectedLocal) in expectedAppearances {
    guard
      case .appearance(let saved) = await planner.read(
        session: session, request: .appearance(appearance))
    else { return XCTFail("Estimate reset must retain every independent appearance.") }
    XCTAssertFalse(saved.globalDone)
    XCTAssertEqual(saved.localDone, expectedLocal)
  }
  guard
    case .source(.schedule(let itemSchedule)) = await planner.read(
      session: session, request: .source(fixture.itemSchedule)),
    case .source(.schedule(let itinerarySchedule)) = await planner.read(
      session: session, request: .source(fixture.itinerarySchedule))
  else { return XCTFail("Activity estimates and manual budgets must not remove booked Schedules.") }
  XCTAssertEqual(
    itemSchedule.content.form,
    .timed(
      start: Date(timeIntervalSinceReferenceDate: 814_000_000),
      end: Date(timeIntervalSinceReferenceDate: 814_007_200), planningTimeZone: "Asia/Tokyo"))
  XCTAssertEqual(
    itinerarySchedule.content.form,
    .allDay(
      start: .init(year: 2026, month: 10, day: 20), end: .init(year: 2026, month: 10, day: 21)))
  XCTAssertFalse(fixture.store.recoveryBlocked)
  XCTAssertFalse(fixture.store.isSaving)
}
