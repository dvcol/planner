import XCTest

@MainActor
final class ShareCaptureJourneyTests: XCTestCase {
  func testUnconfiguredShareFailsWithoutInventingAPrivateStoreOrPromisingSetup() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--share-extension-fixture", "--share-without-group-configuration", "--fixture-dataset",
      UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    XCTAssertTrue(application.staticTexts["Share unavailable"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.staticTexts["Share cannot access Planner's data. Add the content in Planner."]
        .exists)
    XCTAssertFalse(application.plannerElement("saved.capture.add").exists)
    XCTAssertFalse(application.textFields["saved.capture.title"].exists)
    recordShareScreenshot(
      application, name: "Unconfigured Share cannot promise that opening Planner grants storage")
    application.buttons["Cancel"].firstMatch.activateForPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertFalse(application.savedPlannerItemRows("Saved link").firstMatch.exists)
  }

  func testShareWithExistingIncompleteRecoveryExplainsTheGateWithoutOfferingCapture() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--share-extension-fixture", "--share-existing-recovery-failure", "--fixture-dataset",
      UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Open Planner to review recovery"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement("saved.capture.add").exists)
    XCTAssertFalse(application.plannerElement("saved.capture.review").exists)
    XCTAssertFalse(application.textFields["saved.capture.title"].exists)
    recordShareScreenshot(
      application, name: "Share exposes the existing recovery gate before capture")
    application.plannerElement("saved.share.cancel").activateForPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(
      application.savedPlannerItemRows("Recovery museum").firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Saved link").firstMatch.exists)
  }

  func testShareKeepsAppliedCaptureOpenWithVisibleRecoveryFailureAndDoesNotCreateAgain() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--share-extension-fixture", "--share-recovery-failure", "--fixture-dataset",
      UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    XCTAssertTrue(application.textFields["saved.capture.title"].waitForExistence(timeout: 10))
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    let warning = application.staticTexts[
      "Your change is in local storage, but its recovery copy is incomplete. Further changes are paused."
    ]
    XCTAssertTrue(warning.waitForExistence(timeout: 10))
    recordShareScreenshot(
      application, name: "Applied Share must expose incomplete recovery before finishing")
    XCTAssertTrue(
      warning.isHittable, "The saved-but-incomplete outcome must be visible without scrolling.")
    XCTAssertFalse(application.plannerElement("saved.capture.add").isEnabled)
    let done = application.plannerElement("saved.capture.cancel")
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    XCTAssertEqual(done.label, "Done")
    done.activateForPlannerJourney()
    application.openPlannerSection("Items")
    let rows = application.savedPlannerItemRows("Saved link")
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(rows.count, 1)
    rows.firstMatch.activateForPlannerJourney()
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 10))
    XCTAssertFalse(completion.isEnabled)
    recordShareScreenshot(application, name: "Finishing incomplete Share retains one applied Item")
  }

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
    #if os(macOS)
      title.typeKey("a", modifierFlags: .command)
    #else
      title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Saved link".count))
    #endif
    title.typeText("Museum visit")
    XCTAssertTrue(title.waitForPlannerValue("Museum visit"))
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
