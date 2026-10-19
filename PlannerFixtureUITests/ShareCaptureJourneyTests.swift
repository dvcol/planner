import XCTest

@MainActor
final class ShareCaptureJourneyTests: XCTestCase {
  func testNativeProviderShareReviewCreatesNothingUntilSaveAndOpensTheSavedItem() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--share-extension-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.value as? String, "Saved link")
    recordShareScreenshot(
      application, name: "Native Share reviews held prose and the original link")
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertFalse(application.savedPlannerItemRows("Museum visit").firstMatch.exists)
    XCTAssertFalse(application.savedPlannerItemRows("Saved link").firstMatch.exists)
    application.terminate()
    application.launchSavedPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    title.activateForPlannerJourney()
    title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Saved link".count))
    title.typeText("Museum visit")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Museum visit").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    let identifier = row.identifier
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum visit"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.links.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
      ).firstMatch.waitForExistence(timeout: 10))
    recordShareScreenshot(application, name: "Reviewed Share saves one Item with its original link")
    application.terminate()
    application.launchSavedPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.capture.choice").waitForExistence(timeout: 10))
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertEqual(
      application.savedPlannerItemRows("Museum visit").firstMatch.identifier, identifier)
    XCTAssertEqual(application.savedPlannerItemRows("Museum visit").count, 1)
  }

  func testShareRequiresMainApplicationSetupBeforeReviewingOrSaving() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--share-extension-fixture", "--share-without-main-setup", "--fixture-dataset",
      UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Open Planner to prepare Share"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement("saved.capture.add").exists)
    XCTAssertFalse(application.plannerElement("saved.capture.title").exists)
    recordShareScreenshot(
      application, name: "Share requires the main app to initialize real Core storage")
    application.plannerElement("saved.share.cancel").activateForPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertFalse(application.savedPlannerItemRows("Saved link").firstMatch.exists)
  }

  private func recordShareScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
