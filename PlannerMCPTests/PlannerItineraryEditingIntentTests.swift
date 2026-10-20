import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItineraryEditingIntentTests: XCTestCase {
  func testEditPreservesRichContentRouteIndependentCompletionAndScheduleAfterReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let createdCategory = try await save(.createCategory(content: .init(name: "Travel")))
    let category = try XCTUnwrap(createdCategory.generated.first)
    let createdTag = try await save(.createTag(content: .init(name: "Weekend")))
    let tag = try XCTUnwrap(createdTag.generated.first)
    let color = PlannerColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1)
    let estimate = PlannerEstimate(minutes: 210, displayUnit: .hour)
    let location = PlannerOwnedLocation(
      displayName: "Hotel", formattedAddress: "Tokyo, Japan",
      coordinate: .init(latitude: 35.662, longitude: 139.717))
    let createdPlan = try await save(
      .createItinerary(
        content: .init(
          title: "Tokyo Weekend", notes: "Original route notes", color: color, iconName: "map",
          location: location,
          links: [.init(originalUrl: "https://example.com/route", label: "Route guide")],
          categoryIds: [category.id], tagIds: [tag.id], manualEstimate: estimate)))
    let itinerary = try XCTUnwrap(createdPlan.generated.first)
    let createdItem = try await save(
      .createItem(
        content: .init(
          title: "Hotel", notes: "Shared Hotel notes",
          estimate: .init(minutes: 60, displayUnit: .hour))))
    let item = try XCTUnwrap(createdItem.generated.first)
    let firstEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    let secondEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard
      case .itineraryEntry(let firstIdentifier, _, _)? = firstEntry.generatedReferences.first,
      case .itineraryEntry(let secondIdentifier, _, _)? = secondEntry.generatedReferences.first
    else { return XCTFail("Repeated references must retain their distinct entry identities.") }
    let firstAppearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: firstIdentifier)
    let secondAppearance = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: secondIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(firstAppearance), done: true))
    let scheduleForm = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))
    let createdSchedule = try await save(.createSchedule(source: itinerary, form: scheduleForm))
    let schedule = try XCTUnwrap(createdSchedule.generated.first)
    _ = try await save(.setArchive(source: itinerary, archived: true))
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(item))
    else { return XCTFail("The archived rich plan must be readable before editing.") }
    XCTAssertEqual(before.progress.doneCount, 1)
    XCTAssertEqual(before.progress.totalCount, 2)
    let editing = EditPlannerItineraryIntent()
    editing.itinerary = .init(id: itinerary.id, title: "Obsolete cached title", archived: false)
    editing.title = "Reviewed Tokyo Weekend"
    editing.notes = "Reviewed route notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let after)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.item(let afterItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.schedule(let afterSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .appearance(let firstState) = await reopened.read(
        session: reopenedSession, request: .appearance(firstAppearance)),
      case .appearance(let secondState) = await reopened.read(
        session: reopenedSession, request: .appearance(secondAppearance))
    else {
      return XCTFail("Original sources, route appearances and schedule must survive reopening.")
    }
    XCTAssertEqual(after.source, itinerary)
    XCTAssertEqual(after.sourceLifetimeId, before.sourceLifetimeId)
    XCTAssertEqual(after.content.title, "Reviewed Tokyo Weekend")
    XCTAssertEqual(after.content.notes, "Reviewed route notes")
    XCTAssertEqual(after.content.color, color)
    XCTAssertEqual(after.content.iconName, "map")
    XCTAssertEqual(after.content.location, location)
    XCTAssertEqual(after.content.links, before.content.links)
    XCTAssertEqual(after.content.categoryIds, [category.id])
    XCTAssertEqual(after.content.tagIds, [tag.id])
    XCTAssertEqual(after.content.manualEstimate, estimate)
    XCTAssertEqual(after.labels, before.labels)
    XCTAssertEqual(after.state.archived, true)
    XCTAssertNil(after.state.globalDone)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.progress.doneCount, 1)
    XCTAssertEqual(after.progress.totalCount, 2)
    XCTAssertEqual(after.estimates, before.estimates)
    XCTAssertEqual(afterItem.content.title, "Hotel")
    XCTAssertEqual(afterItem.content.notes, "Shared Hotel notes")
    XCTAssertEqual(afterItem.content.estimate, beforeItem.content.estimate)
    XCTAssertEqual(afterItem.fieldHashes, beforeItem.fieldHashes)
    XCTAssertEqual(afterItem.state.globalDone, false)
    XCTAssertEqual(afterItem.state.archived, false)
    XCTAssertEqual(afterItem.updatedAt, beforeItem.updatedAt)
    XCTAssertEqual(afterSchedule.source, schedule)
    XCTAssertEqual(afterSchedule.content.source, itinerary)
    XCTAssertEqual(afterSchedule.content.form, scheduleForm)
    XCTAssertFalse(firstState.globalDone)
    XCTAssertTrue(firstState.localDone)
    XCTAssertTrue(firstState.effectiveDone)
    XCTAssertFalse(secondState.globalDone)
    XCTAssertFalse(secondState.localDone)
    XCTAssertFalse(secondState.effectiveDone)
  }

  func testItineraryPartialEditsKeepOmittedFieldsAndExplicitlyClearNotes() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Original Itinerary"
    creation.notes = "Keep the notes"
    let itinerary = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let editing = EditPlannerItineraryIntent()
    editing.itinerary = itinerary
    editing.title = "Renamed Itinerary"
    let _: Void = try await editing.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let renamed)) = await planner.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("The same Itinerary must remain readable after a title-only edit.") }
    XCTAssertEqual(renamed.content.title, "Renamed Itinerary")
    XCTAssertEqual(renamed.content.notes, "Keep the notes")
    editing.title = nil
    editing.notes = "Updated notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let updated)) = await planner.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("A notes-only edit must retain the live renamed Itinerary.") }
    XCTAssertEqual(updated.content.title, "Renamed Itinerary")
    XCTAssertEqual(updated.content.notes, "Updated notes")
    editing.notes = ""
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let cleared)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else {
      return XCTFail("The renamed Itinerary must survive explicit notes clearing and reopening.")
    }
    XCTAssertEqual(cleared.source.id, itinerary.id)
    XCTAssertEqual(cleared.content.title, "Renamed Itinerary")
    XCTAssertNil(cleared.content.notes)
  }

  func testArchiveRetainsSourceReferencesIndependentFlagsAndScheduleThroughUnarchive() async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let createdItem = try await save(
      .createItem(
        content: .init(title: "Hotel", estimate: .init(minutes: 60, displayUnit: .hour))))
    let item = try XCTUnwrap(createdItem.generated.first)
    let createdList = try await save(.createList(content: .init(name: "Stays")))
    let list = try XCTUnwrap(createdList.generated.first)
    let membership = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .membership(let membershipIdentifier, _, _)? = membership.generatedReferences.first
    else { return XCTFail("The standalone membership must have its original identity.") }
    let standalone = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(standalone), done: true))
    let createdPlan = try await save(
      .createItinerary(
        content: .init(
          title: "Tokyo Weekend", notes: "Keep the route",
          manualEstimate: .init(minutes: 210, displayUnit: .hour))))
    let itinerary = try XCTUnwrap(createdPlan.generated.first)
    let firstEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    let listEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let secondEntry = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    let createdOtherPlan = try await save(.createItinerary(content: .init(title: "Other route")))
    let otherPlan = try XCTUnwrap(createdOtherPlan.generated.first)
    let otherEntry = try await save(
      .addItineraryEntry(itineraryId: otherPlan.id, source: item, placement: .last))
    guard
      case .itineraryEntry(let firstIdentifier, _, _)? = firstEntry.generatedReferences.first,
      case .itineraryEntry(let listEntryIdentifier, _, _)? = listEntry.generatedReferences.first,
      case .itineraryEntry(let secondIdentifier, _, _)? = secondEntry.generatedReferences.first,
      case .itineraryEntry(let otherIdentifier, _, _)? = otherEntry.generatedReferences.first
    else { return XCTFail("Each route entry must retain its independent identity.") }
    let first = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: firstIdentifier)
    let branch = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: listEntryIdentifier,
      membershipId: membershipIdentifier)
    let second = PlannerAppearance.directItineraryItem(
      itineraryId: itinerary.id, entryId: secondIdentifier)
    let other = PlannerAppearance.directItineraryItem(
      itineraryId: otherPlan.id, entryId: otherIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(first), done: true))
    let scheduleForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    let createdSchedule = try await save(.createSchedule(source: itinerary, form: scheduleForm))
    let schedule = try XCTUnwrap(createdSchedule.generated.first)
    guard
      case .source(.itinerary(let beforePlan)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.list(let beforeList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let beforeOther)) = await planner.read(
        session: session, request: .source(otherPlan))
    else { return XCTFail("Every original source must be readable before archive.") }
    XCTAssertEqual(beforePlan.progress.doneCount, 1)
    XCTAssertEqual(beforePlan.progress.totalCount, 3)
    XCTAssertEqual(beforePlan.estimates.fullEstimate, .exact(minutes: 210))
    XCTAssertEqual(beforePlan.estimates.remainingEstimate, .exact(minutes: 150))
    let archiving = SetPlannerItineraryArchiveIntent()
    archiving.itinerary = .init(id: itinerary.id, title: "Obsolete cached title", archived: true)
    for archived in [true, false] {
      archiving.archived = archived
      let _: Void = try await archiving.callAsFunction(donate: false)
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.itinerary(let afterPlan)) = await reopened.read(
          session: reopenedSession, request: .source(itinerary)),
        case .source(.list(let afterList)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .source(.item(let afterItem)) = await reopened.read(
          session: reopenedSession, request: .source(item)),
        case .source(.itinerary(let afterOther)) = await reopened.read(
          session: reopenedSession, request: .source(otherPlan)),
        case .source(.schedule(let afterSchedule)) = await reopened.read(
          session: reopenedSession, request: .source(schedule))
      else { return XCTFail("Archive must preserve every source and the retained schedule.") }
      XCTAssertEqual(afterPlan.state.archived, archived)
      XCTAssertNil(afterPlan.state.globalDone)
      XCTAssertEqual(afterPlan.sourceLifetimeId, beforePlan.sourceLifetimeId)
      XCTAssertEqual(afterPlan.content, beforePlan.content)
      XCTAssertEqual(afterPlan.references, beforePlan.references)
      XCTAssertEqual(afterPlan.progress.doneCount, 1)
      XCTAssertEqual(afterPlan.progress.archivedCount, 0)
      XCTAssertEqual(afterPlan.progress.totalCount, 3)
      XCTAssertEqual(afterPlan.estimates.fullEstimate, .exact(minutes: 210))
      XCTAssertEqual(
        afterPlan.estimates.remainingEstimate, .exact(minutes: archived ? 0 : 150))
      XCTAssertEqual(afterList.content, beforeList.content)
      XCTAssertEqual(afterList.references, beforeList.references)
      XCTAssertEqual(afterList.updatedAt, beforeList.updatedAt)
      XCTAssertEqual(afterItem.fieldHashes, beforeItem.fieldHashes)
      XCTAssertEqual(afterItem.state.globalDone, false)
      XCTAssertEqual(afterItem.state.archived, false)
      XCTAssertEqual(afterItem.updatedAt, beforeItem.updatedAt)
      XCTAssertEqual(afterOther.content, beforeOther.content)
      XCTAssertEqual(afterOther.references, beforeOther.references)
      XCTAssertEqual(afterOther.updatedAt, beforeOther.updatedAt)
      XCTAssertEqual(afterSchedule.content.source, itinerary)
      XCTAssertEqual(afterSchedule.content.form, scheduleForm)
      for appearance in [standalone, first, branch, second, other] {
        guard
          case .appearance(let current) = await reopened.read(
            session: reopenedSession, request: .appearance(appearance))
        else { return XCTFail("Every original appearance must remain readable.") }
        let expectedDone = appearance == standalone || appearance == first
        XCTAssertFalse(current.globalDone)
        XCTAssertEqual(current.localDone, expectedDone)
        XCTAssertEqual(current.effectiveDone, expectedDone)
      }
    }
  }

  func testInvalidItineraryEditsAndMissingOrDeletedTargetsLeaveNoPartialOrResurrectedData()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Original Itinerary"
    creation.notes = "Keep the original notes"
    let itinerary = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .itinerary, id: itinerary.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(source))
    else { return XCTFail("The original Itinerary must be readable before rejected edits.") }
    for (title, notes) in [(nil, nil), ("   ", "Must not apply")] as [(String?, String?)] {
      let editing = EditPlannerItineraryIntent()
      editing.itinerary = itinerary
      editing.title = title
      editing.notes = notes
      do {
        let _: Void = try await editing.callAsFunction(donate: false)
        XCTFail("An empty patch or blank required title cannot acknowledge an Itinerary edit.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
    }
    guard
      case .source(.itinerary(let unchanged)) = await planner.read(
        session: session, request: .source(source)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .deleteSource(source: source),
          reviewToken: review.reviewToken)
      ).outcome
    else {
      return XCTFail("Native reviewed deletion must follow the unchanged rejected-edit state.")
    }
    XCTAssertEqual(unchanged.content, before.content)
    XCTAssertEqual(unchanged.fieldHashes, before.fieldHashes)
    XCTAssertEqual(unchanged.updatedAt, before.updatedAt)
    for target in [
      itinerary, PlannerItineraryEntity(id: UUID(), title: "Missing", archived: false),
    ] {
      let editing = EditPlannerItineraryIntent()
      editing.itinerary = target
      editing.title = "Cannot recreate this Itinerary"
      do {
        let _: Void = try await editing.callAsFunction(donate: false)
        XCTFail("Editing cannot recreate a deleted or missing Itinerary.")
      } catch {
        XCTAssertFalse(error.localizedDescription.isEmpty)
      }
      for archived in [true, false] {
        let archiving = SetPlannerItineraryArchiveIntent()
        archiving.itinerary = target
        archiving.archived = archived
        do {
          let _: Void = try await archiving.callAsFunction(donate: false)
          XCTFail("Archive cannot recreate a deleted or missing Itinerary.")
        } catch {
          XCTAssertFalse(error.localizedDescription.isEmpty)
        }
      }
    }
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let catalog) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .itinerary, archive: .all)))
      )
    else { return XCTFail("Rejected missing-identity mutations must leave readable storage.") }
    XCTAssertTrue(catalog.rows.isEmpty)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedItineraryEditWithIncompleteRecoveryRetainsContentAndBlocksTheNextEdit()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Original Itinerary"
    creation.notes = "Original notes"
    let itinerary = try await creation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let editing = EditPlannerItineraryIntent()
    editing.itinerary = itinerary
    editing.title = "Updated Itinerary"
    editing.notes = "Reviewed notes"
    let _: Void = try await editing.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    editing.notes = "Blocked later edit"
    do {
      let _: Void = try await editing.callAsFunction(donate: false)
      XCTFail("An applied edit with incomplete recovery must block a later edit.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let applied)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("The actual Itinerary edit must remain saved after reopening.") }
    XCTAssertEqual(applied.content.title, "Updated Itinerary")
    XCTAssertEqual(applied.content.notes, "Reviewed notes")
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.itinerary(let recovered)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("Native retry must acknowledge the original Itinerary edit operation.") }
    XCTAssertEqual(recovered.fieldHashes, applied.fieldHashes)
    editing.notes = "Allowed after recovery"
    let _: Void = try await editing.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let final)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("An explicit later Itinerary edit must succeed after native recovery.") }
    XCTAssertEqual(final.source.id, itinerary.id)
    XCTAssertEqual(final.content.title, "Updated Itinerary")
    XCTAssertEqual(final.content.notes, "Allowed after recovery")
    XCTAssertFalse(store.isSaving)
  }

  func testAppliedItineraryArchiveWithIncompleteRecoveryBlocksUnarchiveUntilNativeRetry()
    async throws
  {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItineraryIntent()
    creation.title = "Recovery Itinerary"
    creation.notes = "Keep this empty Itinerary"
    let itinerary = try await creation.callAsFunction(donate: false)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let archiving = SetPlannerItineraryArchiveIntent()
    archiving.itinerary = itinerary
    archiving.archived = true
    let _: Void = try await archiving.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    let operationIdentifier = try XCTUnwrap(store.incompleteRecoveryOperationIdentifiers.first)
    archiving.archived = false
    do {
      let _: Void = try await archiving.callAsFunction(donate: false)
      XCTFail("Incomplete recovery must block Unarchive without reverting the applied archive.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.itinerary(let applied)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("The applied Itinerary archive must remain readable after reopening.") }
    XCTAssertEqual(applied.state.archived, true)
    XCTAssertEqual(applied.content.title, "Recovery Itinerary")
    XCTAssertEqual(applied.content.notes, "Keep this empty Itinerary")
    XCTAssertEqual(applied.progress.state, .empty)
    XCTAssertTrue(applied.references.isEmpty)
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    guard
      case .appliedRecoveryComplete = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .source(.itinerary(let recovered)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("Native retry must complete the original Itinerary archive operation.") }
    XCTAssertEqual(recovered.state.archived, true)
    XCTAssertEqual(recovered.content, applied.content)
    let _: Void = try await archiving.callAsFunction(donate: false)
    guard
      case .source(.itinerary(let unarchived)) = await reopened.read(
        session: session, request: .source(.init(kind: .itinerary, id: itinerary.id)))
    else { return XCTFail("An explicit Unarchive must succeed after native recovery retry.") }
    XCTAssertEqual(unarchived.state.archived, false)
    XCTAssertEqual(unarchived.progress.state, .empty)
    XCTAssertEqual(unarchived.content, applied.content)
    XCTAssertFalse(store.isSaving)
  }

  func testUnavailableStorageRejectsItineraryEditingAndArchiveWithoutAcknowledgingAChange()
    async throws
  {
    let (directory, _, store) = try makePlannerIntentStorage()
    let obstruction = Data("The store parent is a file.".utf8)
    let parent = directory.appending(path: "store")
    try obstruction.write(to: parent)
    AppDependencyManager.shared.add(dependency: store)
    let itinerary = PlannerItineraryEntity(id: UUID(), title: "Unavailable", archived: false)
    let editing = EditPlannerItineraryIntent()
    editing.itinerary = itinerary
    editing.title = "Cannot save here"
    do {
      let _: Void = try await editing.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a Itinerary edit.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    let archiving = SetPlannerItineraryArchiveIntent()
    archiving.itinerary = itinerary
    archiving.archived = true
    do {
      let _: Void = try await archiving.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge a Itinerary archive.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
    XCTAssertNotNil(store.openingFailure)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)
  }

}
