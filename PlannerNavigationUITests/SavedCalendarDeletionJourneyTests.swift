import XCTest

@MainActor
final class SavedCalendarDeletionJourneyTests: XCTestCase {
  func testConfirmedItemDeletionClearsItsCalendarEntryAndSelectionAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.plannerElement("saved.section.items").activateForPlannerJourney()
    #else
      application.buttons["Items"].firstMatch.activateForPlannerJourney()
    #endif
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Calendar deletion")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    let allDay = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.allDay").firstMatch
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    #if os(macOS)
      allDay.activateForPlannerJourney()
    #else
      allDay.switches.firstMatch.tap()
    #endif
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = schedule.identifier
    let scheduleDescription = try XCTUnwrap(schedule.value as? String)
    let calendarIdentifier = scheduleIdentifier.replacingOccurrences(
      of: "saved.item.schedule.", with: "saved.calendar.schedule.")
    openCalendar(application)
    let entry = application.descendants(matching: .any)
      .matching(identifier: calendarIdentifier).firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    entry.activateForPlannerJourney()
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 saved reference"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.delete.cancel").activateForPlannerJourney()
    let retainedSchedule = application.descendants(matching: .any)
      .matching(identifier: scheduleIdentifier).firstMatch
    XCTAssertTrue(retainedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedSchedule.value as? String, scheduleDescription)
    XCTAssertTrue(actions.exists)
    actions.activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 saved reference"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.item.delete.confirm").waitForNonExistence(timeout: 10))
    XCTAssertTrue(entry.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No scheduled entries"].waitForExistence(timeout: 10))
    XCTAssertTrue(actions.waitForNonExistence(timeout: 5))
    let picker = application.descendants(matching: .any).matching(identifier: "saved.calendar.date")
      .firstMatch
    XCTAssertTrue(picker.exists)
    XCTAssertTrue(picker.buttons["DatePicker.NextMonth"].isHittable)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Confirmed Calendar Item deletion clears the invalid detail selection"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.terminate()
    application.launchSavedPlannerJourney()
    openCalendar(application)
    XCTAssertTrue(application.staticTexts["No scheduled entries"].waitForExistence(timeout: 10))
    XCTAssertFalse(entry.exists)
    #if os(macOS)
      application.plannerElement("saved.section.items").activateForPlannerJourney()
    #else
      application.buttons["Items"].firstMatch.activateForPlannerJourney()
    #endif
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    let filters = application.plannerElement("saved.items.filters")
    XCTAssertTrue(filters.waitForExistence(timeout: 5))
    filters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Items yet"].waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Calendar deletion").count, 0)
  }

  private func openCalendar(_ application: XCUIApplication) {
    #if os(macOS)
      let destination = application.plannerElement("saved.section.calendar")
    #else
      let destination = application.buttons["Calendar"].firstMatch
    #endif
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
  }
}
