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
    newCategory(application)
    let name = application.textFields["saved.category.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled category")
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled category"].exists)
    XCTAssertTrue(application.staticTexts["No Categories yet"].exists)

    newCategory(application)
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

  func testCategoryIconStagesCancelAndPersistsIndependentIconEditsAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openCategories(application)
    newCategory(application)
    let name = application.textFields["saved.category.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Culture")
    let icon = application.plannerElement("saved.category.icon")
    XCTAssertTrue(icon.waitForExistence(timeout: 5))
    icon.activateForPlannerJourney()
    application.plannerElement("Museum").activateForPlannerJourney()
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Categories yet"].waitForExistence(timeout: 5))
    newCategory(application)
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Culture")
    icon.activateForPlannerJourney()
    application.plannerElement("Museum").activateForPlannerJourney()
    recordScreenshot(application, name: "Native category symbol picker stages Museum")
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    let category = application.staticTexts["Culture"].firstMatch
    XCTAssertTrue(category.waitForExistence(timeout: 10))
    category.activateForPlannerJourney()
    XCTAssertTrue(icon.waitForExistence(timeout: 5))
    XCTAssertEqual(icon.value as? String, "Museum")
    icon.activateForPlannerJourney()
    application.plannerElement("Dining").activateForPlannerJourney()
    let save = application.plannerElement("saved.category.save")
    XCTAssertTrue(save.isEnabled)
    save.activateForPlannerJourney()
    XCTAssertTrue(category.waitForExistence(timeout: 10))
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openCategories(application)
    XCTAssertTrue(category.waitForExistence(timeout: 10))
    category.activateForPlannerJourney()
    XCTAssertTrue(icon.waitForExistence(timeout: 5))
    XCTAssertEqual(icon.value as? String, "Dining")
    recordScreenshot(application, name: "Native category symbol survives relaunch")
  }

  func testCategoryColorStagesSaveCancelAndClearAcrossRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openCategories(application)
    newCategory(application)
    let name = application.textFields["saved.category.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Colored category")
    #if os(macOS)
      let useColor = application.checkBoxes["saved.category.color.enabled"]
    #else
      let useColor = application.switches["saved.category.color.enabled"].switches.firstMatch
    #endif
    XCTAssertTrue(useColor.waitForExistence(timeout: 5))
    XCTAssertTrue(useColor.waitForPlannerBooleanState(false))
    useColor.activateForPlannerJourney()
    let color = application.descendants(matching: .any).matching(identifier: "saved.category.color")
      .firstMatch
    XCTAssertTrue(color.waitForExistence(timeout: 5))
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Categories yet"].waitForExistence(timeout: 5))
    newCategory(application)
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Colored category")
    useColor.activateForPlannerJourney()
    XCTAssertTrue(color.waitForExistence(timeout: 5))
    recordScreenshot(application, name: "Native optional category ColorPicker")
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    let category = application.staticTexts["Colored category"].firstMatch
    XCTAssertTrue(category.waitForExistence(timeout: 10))
    category.activateForPlannerJourney()
    XCTAssertTrue(useColor.waitForExistence(timeout: 5))
    XCTAssertTrue(useColor.waitForPlannerBooleanState(true))
    useColor.activateForPlannerJourney()
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    category.activateForPlannerJourney()
    XCTAssertTrue(useColor.waitForExistence(timeout: 5))
    XCTAssertTrue(useColor.waitForPlannerBooleanState(true))
    useColor.activateForPlannerJourney()
    let save = application.plannerElement("saved.category.save")
    XCTAssertTrue(save.isEnabled)
    save.activateForPlannerJourney()
    XCTAssertTrue(category.waitForExistence(timeout: 10))
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openCategories(application)
    category.activateForPlannerJourney()
    XCTAssertTrue(useColor.waitForExistence(timeout: 5))
    XCTAssertTrue(useColor.waitForPlannerBooleanState(false))
    XCTAssertFalse(color.exists)
    recordScreenshot(application, name: "Cleared category color remains absent after relaunch")
  }

  #if os(iOS)
    func testNativeColorPickerEditsPersistAcrossSaveAndRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openCategories(application)
      newCategory(application)
      let name = application.textFields["saved.category.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      name.activateForPlannerJourney()
      name.typeText("Native selected color")
      let useColor = application.switches["saved.category.color.enabled"].switches.firstMatch
      XCTAssertTrue(useColor.waitForExistence(timeout: 5))
      useColor.activateForPlannerJourney()
      setNativeHexColor("4080C0", application: application)
      application.plannerElement("saved.category.save").activateForPlannerJourney()
      let category = application.staticTexts["Native selected color"].firstMatch
      XCTAssertTrue(category.waitForExistence(timeout: 10))
      category.activateForPlannerJourney()
      XCTAssertTrue(useColor.waitForExistence(timeout: 5))
      setNativeHexColor("204060", application: application)
      application.plannerElement("saved.category.save").activateForPlannerJourney()
      XCTAssertTrue(category.waitForExistence(timeout: 10))
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      openCategories(application)
      category.activateForPlannerJourney()
      XCTAssertTrue(useColor.waitForExistence(timeout: 5))
      let color = application.descendants(matching: .any).matching(
        identifier: "saved.category.color"
      ).firstMatch
      color.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
      XCTAssertTrue(application.otherElements["UIColorPicker"].waitForExistence(timeout: 5))
      application.buttons["Sliders"].activateForPlannerJourney()
      XCTAssertTrue(application.textFields["sliderRed"].waitForPlannerValue("32"))
      XCTAssertTrue(application.textFields["sliderGreen"].waitForPlannerValue("64"))
      XCTAssertTrue(application.textFields["sliderBlue"].waitForPlannerValue("96"))
      recordScreenshot(application, name: "Native edited color survives Save and relaunch")
      application.buttons["close"].activateForPlannerJourney()
      application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    }

    private func setNativeHexColor(_ value: String, application: XCUIApplication) {
      let color = application.descendants(matching: .any).matching(
        identifier: "saved.category.color"
      ).firstMatch
      XCTAssertTrue(color.waitForExistence(timeout: 5))
      color.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
      XCTAssertTrue(application.otherElements["UIColorPicker"].waitForExistence(timeout: 5))
      application.buttons["Sliders"].activateForPlannerJourney()
      let hexadecimal = application.textFields.matching(
        NSPredicate(format: "value MATCHES %@", "[0-9A-Fa-f]{6}")
      ).firstMatch
      XCTAssertTrue(hexadecimal.waitForExistence(timeout: 5))
      hexadecimal.activateForPlannerJourney()
      hexadecimal.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + value)
      XCTAssertTrue(hexadecimal.waitForPlannerValue(value))
      hexadecimal.typeText("\n")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Native ColorPicker after explicit RGB input"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      recordScreenshot(application, name: "Native system color selection")
      application.buttons["close"].activateForPlannerJourney()
    }

  #endif

  private func newCategory(_ application: XCUIApplication) {
    application.plannerElement("saved.labels.new").activateForPlannerJourney()
    let category = application.plannerElement("New category")
    XCTAssertTrue(category.waitForExistence(timeout: 5))
    category.activateForPlannerJourney()
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
