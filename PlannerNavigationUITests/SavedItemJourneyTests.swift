import XCTest

@MainActor
final class SavedItemJourneyTests: XCTestCase {
  func testItemRowsPreviewSavedAppointmentsAndAdditionalCountAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum appointments")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    returnToItemCatalog(application)
    let row = application.savedPlannerItemRows("Museum appointments").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    let identity = row.identifier
    XCTAssertFalse((row.value as? String ?? "").contains("Scheduled:"))
    for includesEnd in [false, true] {
      row.activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule Item").activateForPlannerJourney()
      let includeEnd = application.descendants(matching: .any)
        .matching(identifier: "saved.schedule.hasEnd").firstMatch
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
      if includesEnd { activateCompletion(includeEnd) }
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      let savedSchedule = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.",
          includesEnd ? "Timed" : "Start only")
      ).firstMatch
      XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
      returnToItemCatalog(application)
      let expectedMetadata = includesEnd ? "1 additional schedule" : "Scheduled:"
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "value CONTAINS %@", expectedMetadata), object: row)
          ], timeout: 10), .completed)
      XCTAssertEqual(row.identifier, identity)
      if !includesEnd {
        XCTAssertFalse((row.value as? String ?? "").contains("additional schedule"))
        recordScreenshot(application, name: "Native Item row shows a start-only appointment")
      }
    }
    let savedMetadata = row.value as? String
    XCTAssertNotNil(savedMetadata)
    XCTAssertTrue(savedMetadata?.contains("Scheduled:") == true)
    recordScreenshot(application, name: "Native Item row shows additional appointments")
    application.terminate()
    application.launchSavedPlannerJourney()
    returnToItemCatalog(application)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(row.identifier, identity)
    XCTAssertEqual(row.value as? String, savedMetadata)
    recordScreenshot(application, name: "Native Item appointment row after relaunch")
  }

  private func returnToItemCatalog(_ application: XCUIApplication) {
    openItems(application)
    let back = application.navigationBars.buttons["Items"].firstMatch
    if back.exists { back.activateForPlannerJourney() }
    XCTAssertTrue(application.plannerElement("saved.item.new").waitForExistence(timeout: 10))
  }

  func testConfirmedScheduleRemovalKeepsOtherAppointmentsAndSourceItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Garden appointments")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the meeting notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the meeting notes"].waitForExistence(timeout: 10))
    let startOnlySchedules = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Start only"))
    let timedSchedules = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Timed"))
    for includesEnd in [false, true] {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule Item").activateForPlannerJourney()
      let includeEnd = application.descendants(matching: .any)
        .matching(identifier: "saved.schedule.hasEnd").firstMatch
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
      if includesEnd { activateCompletion(includeEnd) }
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      let savedSchedule = includesEnd ? timedSchedules.firstMatch : startOnlySchedules.firstMatch
      XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    }
    let retainedIdentifier = startOnlySchedules.firstMatch.identifier
    openScheduleMenu(timedSchedules.firstMatch)
    let removeAction = application.plannerElement("Remove Schedule")
    XCTAssertTrue(removeAction.waitForExistence(timeout: 5))
    removeAction.activateForPlannerJourney()
    let confirm = application.buttons.matching(identifier: "saved.schedule.remove.confirm")
      .firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.staticTexts[
        "1 schedule will be removed. The Item and its other schedules stay available."
      ].exists)
    recordScreenshot(application, name: "Native schedule removal confirmation")
    application.staticTexts["Garden appointments"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    XCTAssertEqual(timedSchedules.count, 1)
    XCTAssertEqual(startOnlySchedules.count, 1)
    openScheduleMenu(timedSchedules.firstMatch)
    removeAction.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.activateForPlannerJourney()
    XCTAssertTrue(timedSchedules.firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertEqual(startOnlySchedules.count, 1)
    XCTAssertEqual(startOnlySchedules.firstMatch.identifier, retainedIdentifier)
    XCTAssertTrue(application.staticTexts["Keep the meeting notes"].exists)
    XCTAssertFalse(application.alerts["Planner"].waitForExistence(timeout: 2))
    recordScreenshot(application, name: "Native schedule removal preserves another appointment")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retainedItem = application.savedPlannerItemRows("Garden appointments").firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(startOnlySchedules.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(startOnlySchedules.firstMatch.identifier, retainedIdentifier)
    XCTAssertEqual(timedSchedules.count, 0)
    openScheduleMenu(startOnlySchedules.firstMatch)
    removeAction.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.activateForPlannerJourney()
    XCTAssertTrue(startOnlySchedules.firstMatch.waitForNonExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the meeting notes"].waitForExistence(timeout: 10))
    XCTAssertEqual(startOnlySchedules.count, 0)
    XCTAssertEqual(timedSchedules.count, 0)
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    XCTAssertFalse(application.alerts["Planner"].waitForExistence(timeout: 2))
    recordScreenshot(application, name: "Native Item remains after removing its last schedule")
  }

  private func openScheduleMenu(_ schedule: XCUIElement) {
    #if os(macOS)
      schedule.rightClick()
    #else
      schedule.press(forDuration: 1.2)
    #endif
  }

  func testOptionalScheduleEndCanBeClearedCanceledAndSavedAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Timed visit")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    XCTAssertTrue(includeEnd.waitForExistence(timeout: 5))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    let endPicker = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.end").firstMatch
    XCTAssertFalse(endPicker.exists)
    activateCompletion(includeEnd)
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    XCTAssertTrue(endPicker.waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["This schedule has no end time."].exists)
    activateCompletion(includeEnd)
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    XCTAssertFalse(endPicker.exists)
    XCTAssertTrue(application.staticTexts["This schedule has no end time."].exists)
    activateCompletion(includeEnd)
    XCTAssertTrue(endPicker.waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    let timedSchedules = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Timed"))
    XCTAssertEqual(timedSchedules.count, 0)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    activateCompletion(includeEnd)
    XCTAssertTrue(endPicker.waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let savedSchedule = timedSchedules.firstMatch
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(timedSchedules.count, 1)
    let identifier = savedSchedule.identifier
    let description = savedSchedule.value as? String
    XCTAssertNotNil(description)
    recordScreenshot(application, name: "Native saved Item schedule with optional end")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retainedItem = application.savedPlannerItemRows("Timed visit").firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(timedSchedules.count, 1)
    XCTAssertEqual(savedSchedule.identifier, identifier)
    XCTAssertEqual(savedSchedule.value as? String, description)
    let itemCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    recordScreenshot(application, name: "Native Item schedule with optional end after relaunch")
  }

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
