import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItemFindIntentTests: XCTestCase {
  func testFindReadsAppliedContentWithoutAcknowledgingIncompleteRecovery() async throws {
    let fixture = try await makeItemFindIntentFixture()
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(for: [fixture.items[0].id])
    let edit = EditPlannerItemIntent()
    edit.item = try XCTUnwrap(choices.first)
    edit.notes = "Recovery searchable notes"
    let obstruction = IntentRecoverySaveObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let _: Void = try await edit.callAsFunction(donate: false)
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(fixture.store.recoveryBlocked)
    let operationIdentifier = try XCTUnwrap(
      fixture.store.incompleteRecoveryOperationIdentifiers.first)
    guard
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.items[0]))
    else { return XCTFail("The applied edit must remain readable during the recovery fault.") }
    let find = FindPlannerItemsIntent()
    find.text = "SEARCHABLE"
    let all: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(all.map(\.id), [fixture.items[0].id])
    find.scope = .inbox
    let inbox: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(inbox.map(\.id), [fixture.items[0].id])
    XCTAssertEqual(fixture.store.incompleteRecoveryOperationIdentifiers, [operationIdentifier])
    XCTAssertTrue(fixture.store.recoveryBlocked)
    guard
      case .source(.item(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.items[0]))
    else { return XCTFail("Find must retain the applied notes and source state.") }
    XCTAssertEqual(after.content.notes, "Recovery searchable notes")
    XCTAssertEqual(after.fieldHashes, before.fieldHashes)
    XCTAssertEqual(after.references, before.references)
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    guard
      case .appliedRecoveryIncomplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { return XCTFail("Reads cannot acknowledge the original incomplete operation.") }
    await fixture.store.retryIncompleteRecovery()
    guard
      case .appliedRecoveryComplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { return XCTFail("Explicit recovery must acknowledge only the original edit.") }
    let recovered: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(recovered.map(\.id), all.map(\.id))
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testFilteredInboxFindReadsEveryPageAndRefreshesAfterAnotherWriter() async throws {
    let fixture = try await makeItemFindIntentFixture()
    var visits: [PlannerEntityReference] = []
    for visitIndex in 0..<69 {
      let saved = try await fixture.apply(
        .createItem(content: .init(title: String(format: "Visit %02d", visitIndex))))
      visits.append(try XCTUnwrap(saved.generated.first(where: { $0.kind == .item })))
    }
    let savedList = try await fixture.apply(.createList(content: .init(name: "Chosen visits")))
    let list = try XCTUnwrap(savedList.generated.first(where: { $0.kind == .list }))
    for item in visits.prefix(2) {
      _ = try await fixture.apply(
        .addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record all 73 Items before paged native reads.") }
    let find = FindPlannerItemsIntent()
    find.scope = .inbox
    find.text = "VISIT"
    find.completion = .todo
    find.archive = .active
    find.direction = .descending
    let matches: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(matches.count, 67)
    XCTAssertEqual(matches.map(\.id), visits.dropFirst(2).reversed().map(\.id))
    XCTAssertEqual(Set(matches.map(\.id)).count, 67)
    XCTAssertEqual(matches.first?.title, "Visit 68")
    XCTAssertEqual(matches.last?.title, "Visit 02")
    guard case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Paged Find must retain every saved record.") }
    XCTAssertEqual(unchanged, before)
    let other = PlannerCore.Planner(configuration: fixture.configuration)
    let last = try XCTUnwrap(visits.last)
    guard case .ready(let otherSession) = await other.bootstrap(),
      case .applied(_, .complete) = await other.execute(
        .init(
          operationId: UUID(), session: otherSession,
          command: .setCompletion(scope: .globalItem(itemId: last.id), done: true))
      ).outcome,
      case .exported(let changed) = await other.exportData(session: otherSession)
    else { return XCTFail("A second real writer must complete the last visit.") }
    let refreshed: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(refreshed.count, 66)
    XCTAssertEqual(refreshed.map(\.id), visits.dropFirst(2).dropLast().reversed().map(\.id))
    find.completion = .all
    let all: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(all.count, 67)
    XCTAssertEqual(all.first?.id, last.id)
    XCTAssertEqual(all.first?.done, true)
    guard case .exported(let after) = await other.exportData(session: otherSession)
    else { return XCTFail("Refreshed Find must not rewrite the other writer's saved change.") }
    XCTAssertEqual(after, changed)
  }

  func testUnavailableStorageThrowsForEveryFindScopeInsteadOfReturningNoMatches() async throws {
    let (_, configuration, store) = try makePlannerIntentStorage()
    let obstruction = configuration.storeURL.deletingLastPathComponent()
    let contents = Data("Keep query storage unavailable.".utf8)
    try contents.write(to: obstruction)
    AppDependencyManager.shared.add(dependency: store)
    let find = FindPlannerItemsIntent()
    find.text = "No matching data"
    for scope in [PlannerItemFindScope.allItems, .inbox] {
      find.scope = scope
      do {
        let _: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
        XCTFail("Unavailable storage cannot become a successful empty Find result.")
      } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
    XCTAssertEqual(try Data(contentsOf: obstruction), contents)
    XCTAssertFalse(store.isReady)
    XCTAssertFalse(store.isSaving)
  }

  func testPrecancelledEmptyFindAndEntityQueriesThrowWithoutChangingData() async throws {
    let fixture = try await makeItemFindIntentFixture()
    await fixture.store.open()
    let find = FindPlannerItemsIntent()
    find.text = "Nothing matches this text"
    let query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record saved data before cancelling empty-result reads.") }
    let invocations: [@MainActor () async throws -> Void] = [
      { let _: [PlannerItemEntity] = try await find.callAsFunction(donate: false) },
      { _ = try await query.entities(matching: "Nothing matches this text") },
      { _ = try await query.entities(for: []) },
    ]
    for invocation in invocations {
      let task = Task { @MainActor in try await invocation() }
      task.cancel()
      do {
        try await task.value
        XCTFail("A precancelled read must throw even when no Item matches.")
      } catch is CancellationError {
      } catch { XCTFail("Expected cancellation, received \(error).") }
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Cancellation must leave saved data readable.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
  }

  func testInboxAndSortingPreserveManualOrderAndUseGlobalCompletion() async throws {
    let fixture = try await makeItemFindIntentFixture()
    let savedList = try await fixture.apply(.createList(content: .init(name: "Tokyo Food")))
    let list = try XCTUnwrap(savedList.generated.first(where: { $0.kind == .list }))
    let added = try await fixture.apply(
      .addMembership(itemId: fixture.items[0].id, listId: list.id, placement: .last))
    guard case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first else {
      return XCTFail("The List association must have its own saved identity.")
    }
    _ = try await fixture.apply(
      .addMembership(itemId: fixture.items[1].id, listId: list.id, placement: .first))
    _ = try await fixture.apply(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier)),
        done: true))
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.items[0]))
    else { return XCTFail("Read the Item before editing its own notes.") }
    _ = try await fixture.apply(
      .editItem(
        sourceId: fixture.items[0].id, changes: .init(notes: .set("Tokyo updated")),
        expectedFieldHashes: current.fieldHashes))
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record saved manual order and local states before sorted reads.") }
    let find = FindPlannerItemsIntent()
    find.scope = .inbox
    let inbox: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(inbox.map(\.id), [fixture.items[2].id, fixture.items[3].id])
    find.scope = .allItems
    find.direction = .descending
    let reverseTitle: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseTitle.map(\.id), fixture.items.reversed().map(\.id))
    find.sort = .created
    find.direction = .ascending
    let created: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(created.map(\.id), fixture.items.map(\.id))
    find.direction = .descending
    let reverseCreated: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseCreated.map(\.id), fixture.items.reversed().map(\.id))
    find.sort = .lastUpdated
    find.direction = .ascending
    let updated: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(updated.map(\.id), [3, 1, 2, 0].map { fixture.items[$0].id })
    find.direction = .descending
    let reverseUpdated: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseUpdated.map(\.id), [0, 2, 1, 3].map { fixture.items[$0].id })
    find.sort = .duration
    find.direction = .ascending
    let estimates: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(estimates.map(\.id), [2, 0, 3, 1].map { fixture.items[$0].id })
    find.direction = .descending
    let reverseEstimates: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(reverseEstimates.map(\.id), [3, 0, 2, 1].map { fixture.items[$0].id })
    find.sort = .title
    find.direction = .ascending
    find.completion = .todo
    let todo: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(todo.map(\.id), [0, 2, 3].map { fixture.items[$0].id })
    XCTAssertEqual(todo.first?.done, false)
    find.completion = .done
    let done: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(done.map(\.id), [fixture.items[1].id])
    find.archive = .archived
    let archivedDone: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertTrue(archivedDone.isEmpty)
    find.completion = .all
    let archived: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(archived.map(\.id), [fixture.items[2].id])
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Read the saved graph after every sorting/filtering combination.") }
    XCTAssertEqual(after, before)
  }

  func testFindItemsCombinesTextCompletionAndArchiveWithoutChangingSavedData() async throws {
    let fixture = try await makeItemFindIntentFixture()
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Record the saved data before finding Items.") }
    let find = FindPlannerItemsIntent()
    let all: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(all.map(\.id), fixture.items.map(\.id))
    XCTAssertEqual(all.map(\.title), ["A Museum", "B Museum", "C Museum", "D Osaka"])
    find.text = "TOKYO"
    find.completion = .todo
    find.archive = .active
    let narrowed: [PlannerItemEntity] = try await find.callAsFunction(donate: false)
    XCTAssertEqual(narrowed.map(\.id), [fixture.items[0].id])
    XCTAssertEqual(narrowed.first?.done, false)
    XCTAssertEqual(narrowed.first?.archived, false)
    find.text = "No matching notes"
    let empty = try await find.callAsFunction(donate: false)
    XCTAssertTrue(empty.isEmpty)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { return XCTFail("Finding Items must leave the saved graph readable and unchanged.") }
    XCTAssertEqual(after, before)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }
}

private struct ItemFindIntentFixture {
  let configuration: PlannerStorageConfiguration
  let store: SavedPlannerStore
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let items: [PlannerEntityReference]

  @MainActor func apply(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    let result = await planner.execute(
      .init(operationId: UUID(), session: session, command: command))
    guard case .applied(let saved, .complete) = result.outcome else {
      XCTFail("Save the real fixture command before exercising Item finding.")
      throw CancellationError()
    }
    return saved
  }
}

@MainActor
private func makeItemFindIntentFixture() async throws -> ItemFindIntentFixture {
  let (_, configuration, store) = try makePlannerIntentStorage()
  AppDependencyManager.shared.add(dependency: store)
  let planner = PlannerCore.Planner(configuration: configuration)
  guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
  var items: [PlannerEntityReference] = []
  let estimates: [Int64?] = [90, nil, 30, 120]
  for (itemIndex, title) in ["A Museum", "B Museum", "C Museum", "D Osaka"].enumerated() {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: title, notes: title == "D Osaka" ? "Osaka" : "Tokyo",
              estimate: estimates[itemIndex].map { .init(minutes: $0, displayUnit: .minute) })))
      )
      .outcome,
      let item = result.generated.first(where: { $0.kind == .item })
    else { throw CancellationError() }
    items.append(item)
  }
  guard
    case .applied(_, .complete) = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .setCompletion(scope: .globalItem(itemId: items[1].id), done: true))
    ).outcome,
    case .applied(_, .complete) = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .setArchive(source: items[2], archived: true))
    ).outcome
  else { throw CancellationError() }
  return .init(
    configuration: configuration, store: store, planner: planner, session: session, items: items)
}
