import AppIntentsTesting
import XCTest

@MainActor
final class SavedAppIntentJourneyTests: XCTestCase {
  func testCreateIntentReturnsTheSameSavedItemReadByNativeDetailsAfterRelaunch() async throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let definitions = IntentDefinitions(bundleIdentifier: "org.example.PlannerMCPPrototype")
    let creation = definitions.intents["CreatePlannerItemIntent"].makeIntent(
      title: "Train tickets", notes: "Collect at the station")
    let response: ResolvedIntentResult
    do {
      response = try await creation.run()
    } catch {
      let failure = error as NSError
      if failure.domain == "AppIntentsServicesSecurityErrorDomain", failure.code == 803 {
        throw XCTSkip(
          "The installed Apple test service rejects this Customer runtime before Planner runs: \(failure.localizedDescription)"
        )
      }
      throw error
    }
    let item: AnyAppEntity = try response.value
    let title: String = try item.title
    let done: Bool = try item.done
    XCTAssertEqual(title, "Train tickets")
    XCTAssertFalse(done)
    let identifier = try XCTUnwrap(UUID(uuidString: item.identifier.instanceIdentifier))
    application.openPlannerSection("Items")
    let row = application.plannerElement("saved.item.\(identifier.uuidString)")
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Collect at the station"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    let read = definitions.intents["GetPlannerItemIntent"].makeIntent(item: item)
    let restoredResponse = try await read.run()
    let restored: AnyAppEntity = try restoredResponse.value
    let restoredTitle: String = try restored.title
    XCTAssertEqual(restored.identifier, item.identifier)
    XCTAssertEqual(restoredTitle, "Train tickets")
  }
}
