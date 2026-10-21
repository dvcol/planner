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
    XCTAssertFalse(categoryRow(named: "Canceled category", in: application).exists)
    XCTAssertTrue(application.staticTexts["No Categories yet"].exists)

    newCategory(application)
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Food")
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    let food = categoryRow(named: "Food", in: application)
    XCTAssertTrue(food.waitForExistence(timeout: 10))
    XCTAssertFalse(name.exists)
    recordScreenshot(application, name: "Saved native Category")

    food.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Canceled rename", application: application)
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    XCTAssertTrue(food.waitForExistence(timeout: 5))
    XCTAssertFalse(categoryRow(named: "Canceled rename", in: application).exists)
    food.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Dining", application: application)
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    XCTAssertTrue(categoryRow(named: "Dining", in: application).waitForExistence(timeout: 10))
    XCTAssertFalse(food.exists)
    XCTAssertFalse(name.exists)

    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openCategories(application)
    XCTAssertTrue(categoryRow(named: "Dining", in: application).waitForExistence(timeout: 10))
    XCTAssertFalse(categoryRow(named: "Food", in: application).exists)
    XCTAssertFalse(categoryRow(named: "Canceled category", in: application).exists)
    XCTAssertFalse(categoryRow(named: "Canceled rename", in: application).exists)
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
    let category = categoryRow(named: "Culture", in: application)
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
      let useColor = application.switches["saved.category.color.enabled"]
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
    let category = categoryRow(named: "Colored category", in: application)
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
    #if os(macOS)
      let useColor = application.switches["saved.category.color.enabled"]
    #else
      let useColor = application.switches["saved.category.color.enabled"].switches.firstMatch
    #endif
    XCTAssertTrue(useColor.waitForExistence(timeout: 5))
    useColor.activateForPlannerJourney()
    setNativeHexColor("4080C0", application: application)
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    let category = categoryRow(named: "Native selected color", in: application)
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
    openNativeColorPicker(application)
    #if os(macOS)
      let panel = application.windows["Colors"]
      XCTAssertTrue(panel.textFields["red"].waitForPlannerValue("32"), panel.debugDescription)
      XCTAssertTrue(panel.textFields["green"].waitForPlannerValue("64"), panel.debugDescription)
      XCTAssertTrue(panel.textFields["blue"].waitForPlannerValue("96"), panel.debugDescription)
    #else
      XCTAssertTrue(application.textFields["sliderRed"].waitForPlannerValue("32"))
      XCTAssertTrue(application.textFields["sliderGreen"].waitForPlannerValue("64"))
      XCTAssertTrue(application.textFields["sliderBlue"].waitForPlannerValue("96"))
    #endif
    recordScreenshot(application, name: "Native edited color survives Save and relaunch")
    dismissNativeColorPicker(application)
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
  }

  private func openNativeColorPicker(_ application: XCUIApplication) {
    let color = application.plannerElement("saved.category.color")
    XCTAssertTrue(color.waitForExistence(timeout: 5))
    #if os(macOS)
      color.activateForPlannerJourney()
      let panel = application.windows["Colors"]
      XCTAssertTrue(panel.waitForExistence(timeout: 5))
      application.activate()
      panel.buttons["Color Sliders"].activateForPlannerJourney()
      panel.popUpButtons.firstMatch.activateForPlannerJourney()
      panel.menuItems["RGB Sliders"].activateForPlannerJourney()
    #else
      color.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
      XCTAssertTrue(application.otherElements["UIColorPicker"].waitForExistence(timeout: 5))
      application.buttons["Sliders"].activateForPlannerJourney()
    #endif
  }

  private func setNativeHexColor(_ value: String, application: XCUIApplication) {
    openNativeColorPicker(application)
    #if os(macOS)
      let fields = application.windows["Colors"].textFields
    #else
      let fields = application.textFields
    #endif
    let hexadecimal = fields.matching(
      NSPredicate(format: "value MATCHES %@", "[0-9A-Fa-f]{6}")
    ).firstMatch
    XCTAssertTrue(hexadecimal.waitForExistence(timeout: 5), hexadecimal.debugDescription)
    hexadecimal.activateForPlannerJourney()
    #if os(macOS)
      hexadecimal.typeKey("a", modifierFlags: .command)
      hexadecimal.typeText(value)
    #else
      hexadecimal.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + value)
    #endif
    XCTAssertTrue(hexadecimal.waitForPlannerValue(value))
    hexadecimal.typeText("\n")
    #if os(macOS)
      let hierarchy = XCTAttachment(string: application.windows["Colors"].debugDescription)
    #else
      let hierarchy = XCTAttachment(string: application.debugDescription)
    #endif
    hierarchy.name = "Native ColorPicker after explicit RGB input"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    recordScreenshot(application, name: "Native system color selection")
    dismissNativeColorPicker(application)
  }

  private func dismissNativeColorPicker(_ application: XCUIApplication) {
    #if os(macOS)
      let panel = application.windows["Colors"]
      XCTAssertTrue(panel.waitForExistence(timeout: 5))
      panel.buttons["_XCUI:CloseWindow"].activateForPlannerJourney()
      XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
    #else
      let picker = application.otherElements["UIColorPicker"].firstMatch
      XCTAssertTrue(picker.waitForExistence(timeout: 5))
      let close = application.buttons["close"].firstMatch
      if close.exists {
        close.activateForPlannerJourney()
      } else {
        let dismissRegion = application.otherElements["UIColorPickerView"]
          .otherElements["PopoverDismissRegion"].firstMatch
        XCTAssertTrue(dismissRegion.waitForPlannerHittability())
        dismissRegion.activateForPlannerJourney()
      }
      XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
    #endif
  }

  private func categoryRow(named name: String, in application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND (label == %@ OR value == %@)",
        "saved.category.", name, name)
    ).firstMatch
  }

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
