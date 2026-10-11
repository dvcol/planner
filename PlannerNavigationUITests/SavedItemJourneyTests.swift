import XCTest

@MainActor
final class SavedItemJourneyTests: XCTestCase {
  func testCancelingScheduleDraftAndSavingStartOnlyAssignmentPreserveItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Garden visit")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet by the entrance")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Meet by the entrance"].waitForExistence(timeout: 10))
    let itemCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let scheduleAction = application.plannerElement("Schedule Item")
    XCTAssertTrue(scheduleAction.waitForExistence(timeout: 5))
    scheduleAction.activateForPlannerJourney()
    let startPicker = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.start").firstMatch
    XCTAssertTrue(startPicker.waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["This schedule has no end time."].exists)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertFalse(startPicker.waitForExistence(timeout: 2))
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Start only"))
    XCTAssertEqual(scheduleRows.count, 0)
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    scheduleAction.activateForPlannerJourney()
    XCTAssertTrue(startPicker.waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let savedSchedule = scheduleRows.firstMatch
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    let savedIdentifier = savedSchedule.identifier
    let savedDescription = savedSchedule.value as? String
    XCTAssertNotNil(savedDescription)
    XCTAssertFalse(startPicker.exists)
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet by the entrance"].exists)
    recordScreenshot(application, name: "Native saved start-only Item schedule")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retainedItem = application.savedPlannerItemRows("Garden visit").firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(savedSchedule.identifier, savedIdentifier)
    XCTAssertEqual(savedSchedule.value as? String, savedDescription)
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet by the entrance"].exists)
    recordScreenshot(application, name: "Native start-only Item schedule after relaunch")
  }

  func testItemDraftCancellationAndGlobalCompletionSurviveNativeRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    let newItem = application.plannerElement("saved.item.new")
    XCTAssertTrue(newItem.waitForExistence(timeout: 10))
    newItem.activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Canceled visit")
    application.plannerElement("saved.item.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled visit"].exists)

    newItem.activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Nezu Museum")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet at the garden entrance")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    XCTAssertFalse(title.exists)
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    XCTAssertEqual(completion.plannerBooleanState, false)
    activateCompletion(completion)
    XCTAssertTrue(completion.waitForPlannerBooleanState(true), application.debugDescription)
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Saved Item with global completion")

    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retained = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 5))
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    activateCompletion(completion)
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    XCTAssertFalse(application.staticTexts["Canceled visit"].exists)
    recordScreenshot(application, name: "Saved Item reopened globally after relaunch")
  }

  private func openItems(_ application: XCUIApplication) {
    #if os(macOS)
      let items = application.plannerElement("saved.section.items")
    #else
      let items = application.buttons["Items"].firstMatch
    #endif
    XCTAssertTrue(items.waitForExistence(timeout: 10))
    items.activateForPlannerJourney()
  }

  private func activateCompletion(_ element: XCUIElement) {
    #if os(macOS)
      element.click()
    #else
      let visibleSwitch = element.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
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
