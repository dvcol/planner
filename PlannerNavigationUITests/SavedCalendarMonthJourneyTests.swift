import XCTest

@MainActor
final class SavedCalendarMonthJourneyTests: XCTestCase {
  func testMonthIndicatesTheDateOfASavedScheduleAndKeepsItsAgendaIdentity() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.plannerElement("saved.section.items").activateForPlannerJourney()
    #else
      application.openPlannerSection("Items")
    #endif
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Month museum")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    let allDay = application.descendants(matching: .any).matching(
      identifier: "saved.schedule.allDay"
    ).firstMatch
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
    #if os(macOS)
      application.plannerElement("saved.section.calendar").activateForPlannerJourney()
    #else
      application.openPlannerSection("Calendar")
    #endif
    let day = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
    let dateIdentifier =
      "\(try XCTUnwrap(day.year))-\(try XCTUnwrap(day.month))-\(try XCTUnwrap(day.day))"
    let indicator = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.day.\(dateIdentifier).schedule-count"
    ).firstMatch
    XCTAssertTrue(indicator.waitForExistence(timeout: 10))
    #if os(macOS)
      let nativeCount = XCTAttachment(
        string:
          "Identifier: \(indicator.identifier)\nLabel: \(indicator.label)\n"
          + "Value: \(indicator.value as? String ?? "<no text value>")\n")
      nativeCount.name = "Native Mac Month count representation"
      nativeCount.lifetime = .keepAlways
      add(nativeCount)
      XCTAssertEqual(indicator.value as? String, "1 scheduled entry")
    #else
      XCTAssertEqual(indicator.label, "1 scheduled entry")
    #endif
    let entry = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.schedule.\(scheduleIdentifier)"
    ).firstMatch
    XCTAssertTrue(entry.exists)
    XCTAssertEqual(entry.label, "Month museum")
    #if os(iOS)
      let picker = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.date"
      ).firstMatch
      XCTAssertLessThanOrEqual(picker.frame.width, 440)
      if application.frame.width >= 700 {
        XCTAssertGreaterThanOrEqual(entry.frame.minX, picker.frame.maxX)
      }
    #endif
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = XCUIScreen.main.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "Month indicates a saved Schedule's date and retains its agenda identity"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
