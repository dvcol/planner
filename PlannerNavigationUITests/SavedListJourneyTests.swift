import XCTest

@MainActor
final class SavedListJourneyTests: XCTestCase {
  func testNewListNotesAreStagedAndRetainedAfterNativeRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    let notes = application.textFields["saved.list.notes"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled notes")
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    notes.activateForPlannerJourney()
    notes.typeText("This draft should not be saved")
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 5))

    application.beginPlannerListCreation()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Rainy afternoon")
    XCTAssertTrue(notes.waitForPlannerValue("Notes"))
    notes.activateForPlannerJourney()
    notes.typeText("Keep indoor options near the hotel")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    let list = application.savedPlannerListRow("Rainy afternoon")
    revealSidebarIfNeeded(application, element: list)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    let identifier = list.identifier
    list.activateForPlannerJourney()
    application.openSavedPlannerListActionsMenu()
    application.plannerElement("saved.list.estimate.edit").activateForPlannerJourney()
    XCTAssertTrue(notes.waitForPlannerValue("Keep indoor options near the hotel"))
    XCTAssertTrue(name.waitForPlannerValue("Rainy afternoon"))
    recordScreenshot(application, name: "List notes retained in the native editor after relaunch")
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled notes"].exists)
    application.openSavedPlannerListActionsMenu()
    application.plannerElement("saved.list.estimate.edit").activateForPlannerJourney()
    XCTAssertTrue(notes.waitForPlannerValue("Keep indoor options near the hotel"))
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    let retained = application.savedPlannerListRow("Rainy afternoon")
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, identifier)
  }

  func testListNotesEditingCancellationRenameAndClearRetainItsIdentityAndManualEstimate() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    let notes = application.textFields["saved.list.notes"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Indoor plan")
    notes.activateForPlannerJourney()
    notes.typeText("Original List notes")
    let estimateToggle = application.descendants(matching: .any)
      .matching(identifier: "saved.list.estimate.enabled").firstMatch
    XCTAssertTrue(estimateToggle.waitForExistence(timeout: 5))
    #if os(iOS)
      estimateToggle.switches.firstMatch.activateForPlannerJourney()
    #else
      estimateToggle.activateForPlannerJourney()
    #endif
    let quantity = application.descendants(matching: .any)
      .matching(identifier: "saved.list.estimate.quantity").firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    let fullEstimate = application.descendants(matching: .any)
      .matching(identifier: "saved.list.estimate.full").firstMatch
    XCTAssertTrue(fullEstimate.waitForPlannerValue("60 minutes"))
    application.terminate()
    application.launchSavedPlannerJourney()
    let original = application.savedPlannerListRow("Indoor plan")
    revealSidebarIfNeeded(application, element: original)
    XCTAssertTrue(original.waitForExistence(timeout: 10))
    let identifier = original.identifier
    original.activateForPlannerJourney()

    openEditor(application)
    XCTAssertTrue(notes.waitForPlannerValue("Original List notes"))
    XCTAssertFalse(application.plannerElement("saved.list.save").isEnabled)
    replaceText(notes, with: "Discard this edit", application: application)
    XCTAssertTrue(application.plannerElement("saved.list.save").isEnabled)
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    openEditor(application)
    XCTAssertTrue(notes.waitForPlannerValue("Original List notes"))
    replaceText(notes, with: "Indoor options\nBring an umbrella", application: application)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(fullEstimate.waitForPlannerValue("60 minutes"))
    openEditor(application)
    XCTAssertTrue(notes.waitForPlannerValue("Indoor options\nBring an umbrella"))
    XCTAssertTrue(name.waitForPlannerValue("Indoor plan"))
    replaceText(name, with: "Wet weather", application: application)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    let list = application.savedPlannerListRow("Wet weather")
    revealSidebarIfNeeded(application, element: list)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    XCTAssertEqual(list.identifier, identifier)
    list.activateForPlannerJourney()
    XCTAssertTrue(fullEstimate.waitForPlannerValue("60 minutes"))
    openEditor(application)
    XCTAssertTrue(notes.waitForPlannerValue("Indoor options\nBring an umbrella"))
    XCTAssertFalse(application.plannerElement("saved.list.save").isEnabled)
    recordScreenshot(application, name: "List multiline notes survive an independent name edit")
    replaceText(notes, with: "", application: application)
    XCTAssertTrue(application.plannerElement("saved.list.save").isEnabled)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(fullEstimate.waitForPlannerValue("60 minutes"))
    application.terminate()
    application.launchSavedPlannerJourney()
    let retained = application.savedPlannerListRow("Wet weather")
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, identifier)
    retained.activateForPlannerJourney()
    XCTAssertTrue(fullEstimate.waitForPlannerValue("60 minutes"))
    openEditor(application)
    XCTAssertTrue(notes.waitForPlannerValue("Notes"))
    XCTAssertTrue(name.waitForPlannerValue("Wet weather"))
    XCTAssertFalse(application.plannerElement("saved.list.save").isEnabled)
    recordScreenshot(
      application, name: "List notes clear without changing the saved manual estimate")
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
  }

  func testListDraftCancellationAndCreationRemainDistinctAfterNativeRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let newList = application.plannerElement("saved.list.new")
    revealSidebarIfNeeded(application, element: newList)
    XCTAssertTrue(newList.waitForExistence(timeout: 10))
    newList.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled plan")
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled plan"].exists)
    XCTAssertTrue(application.staticTexts["No Lists yet"].firstMatch.exists)

    newList.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Tokyo Weekend")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].isHittable)
    XCTAssertFalse(name.exists)
    XCTAssertTrue(application.staticTexts["Tokyo Weekend"].firstMatch.exists)
    recordScreenshot(application, name: "Saved native List with empty progress")

    application.terminate()
    application.launchSavedPlannerJourney()
    let retained = application.savedPlannerListRow("Tokyo Weekend")
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["No items"].isHittable)
    XCTAssertFalse(application.staticTexts["Canceled plan"].exists)
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Saved native List after relaunch")
  }

  private func openEditor(_ application: XCUIApplication) {
    application.openSavedPlannerListActionsMenu()
    application.plannerElement("saved.list.estimate.edit").activateForPlannerJourney()
  }

  private func replaceText(
    _ field: XCUIElement, with text: String, application: XCUIApplication
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
    field.typeText(XCUIKeyboardKey.delete.rawValue + text)
  }

  private func revealSidebarIfNeeded(_ application: XCUIApplication, element: XCUIElement) {
    if element.waitForExistence(timeout: 3) { return }
    let sidebar = application.plannerElement("Show Sidebar")
    XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
    sidebar.activateForPlannerJourney()
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
