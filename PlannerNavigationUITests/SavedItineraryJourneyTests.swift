import XCTest

@MainActor
final class SavedItineraryJourneyTests: XCTestCase {
  func testEmptyItineraryCanCancelAndSaveItsOwnStartOnlyScheduleAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Tokyo afternoon")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the route notes")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the route notes"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    let actions = application.plannerElement("saved.itinerary.actions")
    XCTAssertTrue(actions.isEnabled)
    actions.activateForPlannerJourney()
    let scheduleAction = application.plannerElement("Schedule Itinerary")
    XCTAssertTrue(scheduleAction.waitForExistence(timeout: 5))
    scheduleAction.activateForPlannerJourney()
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["This schedule has no end time."].exists)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule."))
    XCTAssertEqual(scheduleRows.count, 0)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    actions.activateForPlannerJourney()
    scheduleAction.activateForPlannerJourney()
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "Start only")
    let scheduleIdentity = schedule.identifier
    let description = schedule.value as? String
    XCTAssertFalse(description?.isEmpty ?? true)
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Native empty Itinerary saves its own appointment")
    openCatalog(application)
    let itinerary = itineraryRow(application, title: "Tokyo afternoon")
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    let itineraryIdentity = itinerary.identifier
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    XCTAssertEqual(itinerary.identifier, itineraryIdentity)
    itinerary.activateForPlannerJourney()
    let restored = application.descendants(matching: .any)
      .matching(identifier: scheduleIdentity).firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertEqual(restored.label, "Start only")
    XCTAssertEqual(restored.value as? String, description)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Native Itinerary appointment survives relaunch")
  }

  func testItineraryScheduleConversionAndConfirmedRemovalRetainOwnerAndOtherAssignment() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend appointments")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the route"].waitForExistence(timeout: 10))
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule."))
    let timedRows = scheduleRows.matching(NSPredicate(format: "label == %@", "Timed"))
    let startOnlyRows = scheduleRows.matching(NSPredicate(format: "label == %@", "Start only"))
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    let allDay = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.allDay").firstMatch
    for includesEnd in [false, true] {
      application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
      application.plannerElement("Schedule Itinerary").activateForPlannerJourney()
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
      if includesEnd { activateScheduleToggle(includeEnd) }
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      let row = includesEnd ? timedRows.firstMatch : startOnlyRows.firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
    }
    XCTAssertEqual(scheduleRows.count, 2)
    let retainedIdentity = startOnlyRows.firstMatch.identifier
    let retainedDescription = startOnlyRows.firstMatch.value as? String
    let convertedIdentity = timedRows.firstMatch.identifier
    let originalDescription = timedRows.firstMatch.value as? String
    let converted = application.descendants(matching: .any)
      .matching(identifier: convertedIdentity).firstMatch
    openScheduleMenu(converted)
    let editAction = application.plannerElement("Edit Schedule")
    XCTAssertTrue(editAction.waitForExistence(timeout: 5))
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    activateScheduleToggle(allDay)
    XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertTrue(converted.waitForExistence(timeout: 5))
    XCTAssertEqual(converted.label, "Timed")
    XCTAssertEqual(converted.value as? String, originalDescription)
    openScheduleMenu(converted)
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    activateScheduleToggle(allDay)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let allDayRows = scheduleRows.matching(NSPredicate(format: "label == %@", "All day"))
    XCTAssertTrue(allDayRows.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(allDayRows.firstMatch.identifier, convertedIdentity)
    XCTAssertEqual(scheduleRows.count, 2)
    let convertedDescription = converted.value as? String
    XCTAssertFalse(convertedDescription?.isEmpty ?? true)
    XCTAssertNotEqual(convertedDescription, originalDescription)
    openScheduleMenu(converted)
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    recordScreenshot(application, name: "Native Itinerary edit reloads its converted all-day form")
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    let itinerary = itineraryRow(application, title: "Weekend appointments")
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(converted.waitForExistence(timeout: 10))
    XCTAssertEqual(converted.label, "All day")
    XCTAssertEqual(converted.value as? String, convertedDescription)
    XCTAssertEqual(startOnlyRows.firstMatch.identifier, retainedIdentity)
    XCTAssertEqual(startOnlyRows.firstMatch.value as? String, retainedDescription)
    openScheduleMenu(converted)
    let removeAction = application.plannerElement("Remove Schedule")
    XCTAssertTrue(removeAction.waitForExistence(timeout: 5))
    removeAction.activateForPlannerJourney()
    let confirm = application.buttons["saved.schedule.remove.confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.staticTexts[
        "1 schedule will be removed. The Itinerary and its other schedules stay available."
      ].exists)
    recordScreenshot(application, name: "Native Itinerary schedule removal explains its scope")
    application.staticTexts["Weekend appointments"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    XCTAssertEqual(scheduleRows.count, 2)
    XCTAssertEqual(converted.value as? String, convertedDescription)
    openScheduleMenu(converted)
    removeAction.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.activateForPlannerJourney()
    XCTAssertTrue(converted.waitForNonExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(startOnlyRows.firstMatch.identifier, retainedIdentity)
    XCTAssertTrue(application.staticTexts["Keep the route"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Native Itinerary removal retains its other appointment")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(startOnlyRows.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(startOnlyRows.firstMatch.identifier, retainedIdentity)
    XCTAssertEqual(startOnlyRows.firstMatch.value as? String, retainedDescription)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertFalse(converted.exists)
    XCTAssertTrue(application.staticTexts["Keep the route"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    recordScreenshot(application, name: "Native Itinerary schedule removal survives relaunch")
  }

  private func openScheduleMenu(_ schedule: XCUIElement) {
    #if os(macOS)
      schedule.rightClick()
    #else
      schedule.press(forDuration: 1.2)
    #endif
  }

  private func activateScheduleToggle(_ element: XCUIElement) {
    #if os(macOS)
      element.click()
    #else
      let visibleSwitch = element.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
  }

  func testItineraryDraftsCancelAndGuardedTitleNotesPersistAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(application.staticTexts["No Itineraries yet"].waitForExistence(timeout: 5))
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    let notes = application.textFields["saved.itinerary.notes"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.itinerary.save").isEnabled)
    title.activateForPlannerJourney()
    title.typeText("Canceled plan")
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Itineraries yet"].waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["Canceled plan"].exists)

    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Tokyo Weekend")
    notes.activateForPlannerJourney()
    notes.typeText("Explore at our own pace")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Explore at our own pace"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    openCatalog(application)
    let originalRow = itineraryRow(application, title: "Tokyo Weekend")
    XCTAssertTrue(originalRow.waitForExistence(timeout: 10))
    let originalIdentifier = originalRow.identifier
    originalRow.activateForPlannerJourney()
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.itinerary.save").isEnabled)
    replaceText(title, with: "Canceled rename", application: application)
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Explore at our own pace"].waitForExistence(timeout: 5))
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    replaceText(title, with: "Tokyo Break", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Explore at our own pace"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    XCTAssertTrue(title.waitForPlannerValue("Tokyo Break"))
    replaceText(notes, with: "Museum and dinner", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum and dinner"].waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Saved native Itinerary details")

    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    let retainedRow = itineraryRow(application, title: "Tokyo Break")
    XCTAssertTrue(retainedRow.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedRow.identifier, originalIdentifier)
    XCTAssertFalse(itineraryRow(application, title: "Tokyo Weekend").exists)
    XCTAssertFalse(itineraryRow(application, title: "Canceled rename").exists)
    XCTAssertFalse(itineraryRow(application, title: "Canceled plan").exists)
    recordScreenshot(application, name: "Native Itinerary catalog after relaunch")
    retainedRow.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum and dinner"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)
  }

  private func openItineraries(_ application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("saved.section.itineraries")
    #else
      let section = application.buttons["Itineraries"].firstMatch
    #endif
    XCTAssertTrue(section.waitForExistence(timeout: 10), application.debugDescription)
    section.activateForPlannerJourney()
    openCatalog(application)
  }

  private func openCatalog(_ application: XCUIApplication) {
    let newItinerary = application.plannerElement("saved.itinerary.new")
    if !newItinerary.waitForExistence(timeout: 2) {
      let back = application.buttons["Itineraries"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
    }
    if !newItinerary.exists {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(newItinerary.waitForExistence(timeout: 10), application.debugDescription)
  }

  private func itineraryRow(_ application: XCUIApplication, title: String) -> XCUIElement {
    application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", title)
    ).firstMatch
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
