import AppIntents
import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class PlannerItemSubtitleIntentTests: XCTestCase {
  func testCreationPreservesExactSubtitleSeparatelyFromNotesAfterReopen() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.subtitle = "  Réservation · 金曜日  "
    creation.notes = "Keep booking details"
    let item = try await creation.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let saved)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
    else { return XCTFail("The created Item and subtitle must survive reopening.") }
    XCTAssertEqual(saved.source.id, item.id)
    XCTAssertEqual(saved.content.title, "Museum")
    XCTAssertEqual(saved.content.subtitle, "  Réservation · 金曜日  ")
    XCTAssertEqual(saved.content.notes, "Keep booking details")
    XCTAssertEqual(saved.state.globalDone, false)
    XCTAssertEqual(saved.state.archived, false)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testSubtitleOnlyEditPreservesOtherContentCompletionAndBookingAfterReopen() async throws {
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
    let created = try await save(
      .createItem(
        content: .init(
          title: "Museum", subtitle: "Old subtitle", notes: "Keep booking",
          location: .init(
            displayName: "Museum", formattedAddress: "Tokyo",
            coordinate: .init(latitude: 35.6622, longitude: 139.7171)),
          estimate: .init(minutes: 125, displayUnit: .hour),
          links: [.init(originalUrl: "https://example.com/museum", label: "Visit guide")])))
    let source = try XCTUnwrap(created.generated.first)
    let createdList = try await save(.createList(content: .init(name: "Wishlist")))
    let list = try XCTUnwrap(createdList.generated.first)
    let added = try await save(.addMembership(itemId: source.id, listId: list.id, placement: .last))
    guard case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first
    else { throw CancellationError() }
    let appearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    _ = try await save(.setArchive(source: source, archived: true))
    let form = PlannerScheduleForm.allDay(start: .init(year: 2026, month: 10, day: 20), end: nil)
    let createdSchedule = try await save(.createSchedule(source: source, form: form))
    let schedule = try XCTUnwrap(createdSchedule.generated.first)
    guard
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    let editing = EditPlannerItemIntent()
    editing.item = .init(id: source.id, title: "Cached title", done: true, archived: false)
    editing.subtitle = "Entrée sur réservation"
    let _: Void = try await editing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let after)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .appearance(let savedAppearance) = await reopened.read(
        session: reopenedSession, request: .appearance(appearance)),
      case .source(.schedule(let savedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule))
    else { return XCTFail("The original source, membership and booking must survive the edit.") }
    XCTAssertEqual(after.content.subtitle, "Entrée sur réservation")
    XCTAssertEqual(
      after.fieldHashes.filter { $0.key != .subtitle },
      before.fieldHashes.filter { $0.key != .subtitle })
    XCTAssertNotEqual(after.fieldHashes[.subtitle], before.fieldHashes[.subtitle])
    XCTAssertEqual(after.source, before.source)
    XCTAssertEqual(after.sourceLifetimeId, before.sourceLifetimeId)
    XCTAssertEqual(after.createdAt, before.createdAt)
    XCTAssertEqual(after.references, before.references)
    XCTAssertEqual(after.state.globalDone, false)
    XCTAssertEqual(after.state.archived, true)
    XCTAssertFalse(savedAppearance.globalDone)
    XCTAssertTrue(savedAppearance.localDone)
    XCTAssertEqual(savedSchedule.content.form, form)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testOmissionKeepsSubtitleAndCombinedTextEditsClearOrRejectTogether() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.subtitle = "Keep subtitle"
    creation.notes = "Original notes"
    let item = try await creation.callAsFunction(donate: false)
    let notesOnly = EditPlannerItemIntent()
    notesOnly.item = item
    notesOnly.notes = "Updated notes"
    let _: Void = try await notesOnly.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .item, id: item.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let beforeInvalid)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    XCTAssertEqual(beforeInvalid.content.subtitle, "Keep subtitle")
    XCTAssertEqual(beforeInvalid.content.notes, "Updated notes")
    let invalid = EditPlannerItemIntent()
    invalid.item = item
    invalid.title = "   "
    invalid.subtitle = "Must not apply"
    invalid.notes = "Must not apply"
    do {
      let _: Void = try await invalid.callAsFunction(donate: false)
      XCTFail("A rejected title must reject subtitle and notes in the same edit.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard
      case .source(.item(let unchanged)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    XCTAssertEqual(unchanged.fieldHashes, beforeInvalid.fieldHashes)
    XCTAssertEqual(unchanged.updatedAt, beforeInvalid.updatedAt)
    let clearing = EditPlannerItemIntent()
    clearing.item = item
    clearing.title = "Renamed museum"
    clearing.subtitle = ""
    clearing.notes = ""
    let _: Void = try await clearing.callAsFunction(donate: false)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let cleared)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else { return XCTFail("The explicit combined clear must survive reopening.") }
    XCTAssertEqual(cleared.source, source)
    XCTAssertEqual(cleared.content.title, "Renamed museum")
    XCTAssertNil(cleared.content.subtitle)
    XCTAssertNil(cleared.content.notes)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testCreationKeepsOmittedAndEmptySubtitlesDistinct() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    var identifiers: Set<UUID> = []
    for subtitle in [nil, ""] as [String?] {
      let creation = CreatePlannerItemIntent()
      creation.title = "Museum"
      creation.subtitle = subtitle
      let item = try await creation.callAsFunction(donate: false)
      XCTAssertTrue(identifiers.insert(item.id).inserted)
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .source(.item(let saved)) = await reopened.read(
          session: session, request: .source(.init(kind: .item, id: item.id)))
      else { throw CancellationError() }
      XCTAssertEqual(saved.content.subtitle, subtitle)
      XCTAssertNil(saved.content.notes)
    }
    XCTAssertEqual(identifiers.count, 2)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledSubtitleEditPreservesOriginalTextHashesAndTimestamp() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.subtitle = "Keep subtitle"
    let item = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    let source = PlannerEntityReference(kind: .item, id: item.id)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    let editing = EditPlannerItemIntent()
    editing.item = item
    editing.subtitle = "Cancelled subtitle"
    let request = Task {
      let _: Void = try await editing.callAsFunction(donate: false)
    }
    request.cancel()
    do {
      try await request.value
      XCTFail("A precancelled edit must not acknowledge a subtitle change.")
    } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    guard
      case .source(.item(let after)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    XCTAssertEqual(after.content.subtitle, "Keep subtitle")
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.updatedAt, before.updatedAt)
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertFalse(store.isSaving)
  }
}
