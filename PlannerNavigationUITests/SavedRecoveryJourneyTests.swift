import XCTest

@MainActor
final class SavedRecoveryJourneyTests: XCTestCase {
  func testInspectingSavedRecoveryCopyPreservesCurrentTagAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    application.plannerElement("saved.labels.new").activateForPlannerJourney()
    application.plannerElement("New Tag").activateForPlannerJourney()
    let name = application.textFields["saved.tag.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.activateForPlannerJourney()
    name.typeText("Recovery travel tag")
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    let tag = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Recovery travel tag")
    ).firstMatch
    XCTAssertTrue(tag.waitForExistence(timeout: 10))
    let tagIdentifier = tag.identifier
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    let recovery = application.plannerElement("saved.settings.recovery")
    XCTAssertTrue(recovery.waitForExistence(timeout: 10))
    recovery.activateForPlannerJourney()
    let snapshot = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.recovery.snapshot.")
    ).firstMatch
    XCTAssertTrue(snapshot.waitForExistence(timeout: 15))
    snapshot.activateForPlannerJourney()
    let evidence = application.staticTexts["saved.recovery.evidence"]
    XCTAssertTrue(evidence.waitForExistence(timeout: 15))
    XCTAssertTrue(evidence.label.contains("Saved snapshot"))
    let sourceIdentifier = String(tagIdentifier.dropFirst("saved.tag.".count))
    let retainedSource = application.staticTexts["saved.recovery.source.tag.\(sourceIdentifier)"]
    XCTAssertTrue(retainedSource.waitForExistence(timeout: 10))
    XCTAssertTrue(retainedSource.label.contains("Recovery travel tag"))
    recordRecovery(name: "Native recovery inspection retains the saved Tag and evidence")
    application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
    application.plannerElement("saved.recovery.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(tagIdentifier).label, "Recovery travel tag")
    recordRecovery(name: "Recovery inspection leaves the current Tag intact after relaunch")
  }

  private func openSettings(_ application: XCUIApplication) {
    #if os(macOS)
      application.typeKey(",", modifierFlags: .command)
    #else
      let settings = application.plannerElement("saved.settings.open")
      if !settings.waitForExistence(timeout: 2) {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists { sidebar.activateForPlannerJourney() }
      }
      XCTAssertTrue(settings.waitForExistence(timeout: 10))
      settings.activateForPlannerJourney()
    #endif
    XCTAssertTrue(application.plannerElement("saved.settings.labels").waitForExistence(timeout: 10))
  }

  private func recordRecovery(name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
