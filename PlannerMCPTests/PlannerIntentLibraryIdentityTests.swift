import AppIntents
import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor final class PlannerIntentLibraryIdentityTests: XCTestCase {
  func testSavedChoiceRejectsAnotherLibraryAndResolvesAfterReopeningItsOriginalLibrary()
    async throws
  {
    let first = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: first.store)
    let creation = CreatePlannerItemIntent()
    creation.title = "Original library Item"
    let saved = try await creation.callAsFunction(donate: false)
    XCTAssertTrue(saved.id.hasPrefix("library2|"))
    let identifier = try saved.sourceIdentifier(in: first.store)
    let query = PlannerItemEntityQuery()
    query.plannerStore = first.store
    let legacy = try await query.entities(for: [identifier.uuidString])
    XCTAssertEqual(legacy.map(\.id), [saved.id])

    let second = try makePlannerIntentStorage()
    AppDependencyManager.shared.add(dependency: second.store)
    let otherCreation = CreatePlannerItemIntent()
    otherCreation.title = "Other library Item"
    let other = try await otherCreation.callAsFunction(donate: false)
    XCTAssertNotEqual(saved.libraryBinding, other.libraryBinding)
    query.plannerStore = first.store
    let originalChoices = try await query.entities(for: [saved.id])
    XCTAssertEqual(originalChoices.map(\.id), [saved.id])
    let (planner, session) = try await second.store.appIntentContext()
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertThrowsError(try saved.sourceIdentifier(in: second.store))
    query.plannerStore = second.store
    do {
      _ = try await query.entities(for: [saved.id])
      XCTFail("A saved choice must not silently resolve against another library.")
    } catch { XCTAssertTrue(error.localizedDescription.contains("another library")) }
    let edit = EditPlannerItemIntent()
    edit.item = saved
    edit.title = "Must not be written"
    do {
      let _: Void = try await edit.callAsFunction(donate: false)
      XCTFail("A direct Intent invocation must also validate its library binding.")
    } catch { XCTAssertTrue(error.localizedDescription.contains("another library")) }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    XCTAssertEqual(after, before)

    let reopened = SavedPlannerStore(configuration: first.configuration)
    AppDependencyManager.shared.add(dependency: reopened)
    await reopened.open()
    query.plannerStore = reopened
    let resolved = try await query.entities(for: [saved.id])
    XCTAssertEqual(resolved.map(\.id), [saved.id])
    XCTAssertEqual(try resolved.first?.sourceIdentifier(in: reopened), identifier)
    let notes = try await resolved.first?.notes
    XCTAssertNil(notes)
    XCTAssertTrue(reopened.canChangeLibrary)
    try await reopened.beginAppIntentAction()
    XCTAssertFalse(reopened.canChangeLibrary)
    reopened.endAppIntentAction()
    XCTAssertTrue(reopened.canChangeLibrary)
  }
}
