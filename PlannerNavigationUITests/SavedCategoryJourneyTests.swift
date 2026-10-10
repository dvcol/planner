import XCTest

@MainActor
final class SavedCategoryJourneyTests: XCTestCase {
  func testCategoryCreationAndRenameStageCancelAndPersistAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openCategories(application)
    XCTAssertTrue(application.staticTexts["No Categories yet"].waitForExistence(timeout: 5))
    application.plannerElement("saved.category.new").activateForPlannerJourney()
    let name = application.textFields["saved.category.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled category")
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled category"].exists)
    XCTAssertTrue(application.staticTexts["No Categories yet"].exists)

    application.plannerElement("saved.category.new").activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Food")
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    let food = application.staticTexts["Food"].firstMatch
    XCTAssertTrue(food.waitForExistence(timeout: 10))
    XCTAssertFalse(name.exists)
    recordScreenshot(application, name: "Saved native Category")

    food.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Canceled rename", application: application)
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    XCTAssertTrue(food.waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["Canceled rename"].exists)
    food.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Dining", application: application)
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Dining"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(food.exists)
    XCTAssertFalse(name.exists)

    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openCategories(application)
    XCTAssertTrue(application.staticTexts["Dining"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Food"].exists)
    XCTAssertFalse(application.staticTexts["Canceled category"].exists)
    XCTAssertFalse(application.staticTexts["Canceled rename"].exists)
    recordScreenshot(application, name: "Native Category after relaunch")
  }

  private func openCategories(_ application: XCUIApplication) {
    let categories = application.plannerElement("saved.categories.manage")
    if !categories.waitForExistence(timeout: 3) {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(categories.waitForExistence(timeout: 10))
    categories.activateForPlannerJourney()
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

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = application.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
