import XCTest

@MainActor
final class SavedCalendarJourneyTests: XCTestCase {
  func testTimedCalendarCaptionRetainsTheSavedStartOnlyValueAfterRelaunch() throws {
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
    title.typeText("Timed calendar")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(schedule.label, "Start only")
    let savedDescription = try XCTUnwrap(schedule.value as? String)
    let dateDescription = savedDescription.components(separatedBy: " · ").dropLast().joined(
      separator: " · ")
    XCTAssertFalse(dateDescription.isEmpty)
    let identifier = schedule.identifier.replacingOccurrences(of: "saved.item.schedule.", with: "")
    openCalendar(application)
    let entry = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.schedule.\(identifier)").firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertEqual(entry.value as? String, "Start only · " + dateDescription)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Native Calendar retains a start-only appointment"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.terminate()
    application.launchSavedPlannerJourney()
    openCalendar(application)
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertEqual(entry.value as? String, "Start only · " + dateDescription)
  }

  func testCalendarItineraryEntryOpensItsExistingLiveDetails() {
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
    let childTitle = application.textFields["saved.item.title"]
    XCTAssertTrue(childTitle.waitForExistence(timeout: 5))
    childTitle.activateForPlannerJourney()
    childTitle.typeText("Calendar Hotel")
    let childNotes = application.textFields["saved.item.notes"]
    childNotes.activateForPlannerJourney()
    childNotes.typeText("Contextual hotel notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Contextual hotel notes"].waitForExistence(timeout: 10))
    #if os(macOS)
      application.plannerElement("saved.section.itineraries").activateForPlannerJourney()
    #else
      application.buttons["Itineraries"].firstMatch.activateForPlannerJourney()
    #endif
    let newItinerary = application.plannerElement("saved.itinerary.new")
    if !newItinerary.waitForExistence(timeout: 2) {
      application.plannerElement("Show Sidebar").activateForPlannerJourney()
    }
    XCTAssertTrue(newItinerary.waitForExistence(timeout: 5))
    newItinerary.activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Calendar route")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Live route notes")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Live route notes"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
    let choice = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@",
        "saved.itinerary.entry.choice.item.", "Calendar Hotel")
    ).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 10))
    choice.activateForPlannerJourney()
    application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    let childRow = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance.")
    ).firstMatch
    XCTAssertTrue(childRow.waitForExistence(timeout: 10))
    let childIdentifier = childRow.identifier
    application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Itinerary").activateForPlannerJourney()
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
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule.")
    ).firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let identifier = schedule.identifier.replacingOccurrences(
      of: "saved.itinerary.schedule.", with: "")
    openCalendar(application)
    let entry = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.schedule.\(identifier)").firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertTrue(entry.label.contains("Calendar route"))
    XCTAssertTrue((entry.value as? String)?.contains("All day") == true)
    entry.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Live route notes"].waitForExistence(timeout: 5))
    let actions = application.plannerElement("saved.itinerary.actions")
    if actions.exists {
      actions.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
      let itineraryActions = application.plannerElement("Itinerary actions")
      if itineraryActions.exists { itineraryActions.activateForPlannerJourney() }
    }
    let scheduleAction = application.plannerElement("Schedule Itinerary")
    XCTAssertTrue(scheduleAction.waitForExistence(timeout: 5))
    scheduleAction.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.schedule.cancel").waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    let retained = application.descendants(matching: .any)
      .matching(identifier: schedule.identifier).firstMatch
    XCTAssertTrue(retained.exists)
    let contextualRow = application.descendants(matching: .any)
      .matching(identifier: childIdentifier).firstMatch
    XCTAssertTrue(contextualRow.waitForExistence(timeout: 10))
    contextualRow.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Contextual hotel notes"].waitForExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.item.actions").exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Calendar opens native live Itinerary details"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testMonthAgendaUsesSavedAllDayIdentityAndFollowsNativeDateSelection() {
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
    title.typeText("Museum calendar")
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
    let scheduleIdentifier = schedule.identifier.replacingOccurrences(
      of: "saved.item.schedule.", with: "")
    openCalendar(application)
    let entry = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.schedule.\(scheduleIdentifier)").firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertTrue(entry.label.contains("Museum calendar"))
    let picker = application.descendants(matching: .any).matching(identifier: "saved.calendar.date")
      .firstMatch
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.buttons["DatePicker.NextMonth"].activateForPlannerJourney()
    let firstDay = picker.buttons.containing(.staticText, identifier: "1").firstMatch
    XCTAssertTrue(firstDay.waitForExistence(timeout: 5))
    XCTAssertTrue(
      firstDay.isSelected, "Browsing a month keeps the agenda's selected day in that month.")
    firstDay.activateForPlannerJourney()
    XCTAssertTrue(entry.waitForNonExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["No scheduled entries"].exists)
    application.buttons["Today"].activateForPlannerJourney()
    XCTAssertTrue(entry.waitForExistence(timeout: 5))
    XCTAssertTrue(entry.label.contains("Museum calendar"))
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Month Calendar agenda retains saved schedule identity"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.terminate()
    application.launchSavedPlannerJourney()
    openCalendar(application)
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertTrue(entry.label.contains("Museum calendar"))
    entry.activateForPlannerJourney()
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    #if os(macOS)
      completion.activateForPlannerJourney()
    #else
      completion.switches.firstMatch.tap()
    #endif
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    #if os(iOS)
      let back = application.navigationBars.buttons["Calendar"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
    #endif
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openCalendar(application)
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    entry.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
  }

  func testCalendarIsAMainDestinationWithNativeDateSelectionAndAnEmptyAgenda() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openCalendar(application)
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.calendar.date").firstMatch
        .waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["No scheduled entries"].waitForExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Native main Calendar with empty saved data"
    attachment.lifetime = .keepAlways
    add(attachment)
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
