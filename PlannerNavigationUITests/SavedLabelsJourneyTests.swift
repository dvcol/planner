import XCTest

@MainActor
final class SavedLabelsJourneyTests: XCTestCase {
  func testManageLabelsStagesTagCreationAndRenameAndRetainsIdentityAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    XCTAssertTrue(application.staticTexts["Manage Labels"].firstMatch.waitForExistence(timeout: 5))
    newTag(application)
    let name = application.textFields["saved.tag.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled Tag")
    application.plannerElement("saved.tag.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled Tag"].exists)
    newTag(application)
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Rain")
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    let rain = application.staticTexts["Rain"].firstMatch
    XCTAssertTrue(rain.waitForExistence(timeout: 10))
    let tag = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.tag.")
    ).matching(NSPredicate(format: "label == %@", "Rain")).firstMatch
    let identifier = tag.identifier
    XCTAssertFalse(identifier.isEmpty)
    rain.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Canceled rename", application: application)
    application.plannerElement("saved.tag.cancel").activateForPlannerJourney()
    XCTAssertTrue(rain.waitForExistence(timeout: 5))
    rain.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Wet weather", application: application)
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(identifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(identifier).label, "Wet weather")
    XCTAssertFalse(rain.exists)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openLabels(application)
    XCTAssertTrue(application.plannerElement(identifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(identifier).label, "Wet weather")
    XCTAssertFalse(application.staticTexts["Canceled Tag"].exists)
    XCTAssertFalse(application.staticTexts["Canceled rename"].exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Manage Labels with saved Tag after relaunch"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func openLabels(_ application: XCUIApplication) {
    let labels = application.plannerElement("saved.categories.manage")
    if !labels.waitForExistence(timeout: 3) {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(labels.waitForExistence(timeout: 10))
    labels.activateForPlannerJourney()
  }

  private func newTag(_ application: XCUIApplication) {
    application.plannerElement("saved.labels.new").activateForPlannerJourney()
    let tag = application.plannerElement("New Tag")
    XCTAssertTrue(tag.waitForExistence(timeout: 5))
    tag.activateForPlannerJourney()
  }

  private func replaceText(
    _ field: XCUIElement, with value: String, application: XCUIApplication
  ) {
    field.activateForPlannerJourney()
    #if os(macOS)
      field.typeKey("a", modifierFlags: .command)
    #else
      field.press(forDuration: 1)
      let selectAll = application.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@ OR identifier == %@", "Select All", "Select All")
      ).firstMatch
      XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
      selectAll.activateForPlannerJourney()
    #endif
    field.typeText(value)
    XCTAssertTrue(field.waitForPlannerValue(value))
  }
}
