import XCTest

@MainActor
final class SavedCalendarOrderingJourneyTests: XCTestCase {
  func testOverlappingAllDayAssignmentsUseTheirDatesRatherThanIdentityOrder() throws {
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
    title.typeText("Ordered calendar")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    for _ in 0..<2 {
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
      selectDay(9, pickerIdentifier: "saved.schedule.start", application: application)
      let includesEnd = application.descendants(matching: .any)
        .matching(identifier: "saved.schedule.hasEnd").firstMatch
      #if os(macOS)
        includesEnd.activateForPlannerJourney()
      #else
        includesEnd.switches.firstMatch.tap()
      #endif
      selectDay(11, pickerIdentifier: "saved.schedule.end", application: application)
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      XCTAssertTrue(actions.waitForExistence(timeout: 10))
    }
    let schedules = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    XCTAssertEqual(schedules.count, 2)
    let identifiers = schedules.allElementsBoundByIndex.map(\.identifier).sorted()
    let earlierSchedule = application.descendants(matching: .any)
      .matching(identifier: identifiers[1]).firstMatch
    let earlierDescription = try XCTUnwrap(earlierSchedule.value as? String)
    let laterSchedule = application.descendants(matching: .any)
      .matching(identifier: identifiers[0]).firstMatch
    #if os(macOS)
      laterSchedule.rightClick()
    #else
      laterSchedule.press(forDuration: 1)
    #endif
    application.plannerElement("Edit Schedule").activateForPlannerJourney()
    selectDay(10, pickerIdentifier: "saved.schedule.start", application: application)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let changedCaption = XCTNSPredicateExpectation(
      predicate: NSPredicate(
        format: "exists == true AND value != nil AND value != %@", earlierDescription),
      object: laterSchedule)
    XCTAssertEqual(XCTWaiter.wait(for: [changedCaption], timeout: 10), .completed)
    let laterDescription = try XCTUnwrap(laterSchedule.value as? String)
    XCTAssertNotEqual(earlierDescription, laterDescription)
    #if os(macOS)
      application.plannerElement("saved.section.calendar").activateForPlannerJourney()
    #else
      application.buttons["Calendar"].firstMatch.activateForPlannerJourney()
    #endif
    let picker = application.descendants(matching: .any).matching(identifier: "saved.calendar.date")
      .firstMatch
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.buttons.containing(.staticText, identifier: "11").firstMatch.activateForPlannerJourney()
    let entries = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.schedule."))
    XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 10))
    let expected = identifiers.reversed().map {
      $0.replacingOccurrences(of: "saved.item.schedule.", with: "saved.calendar.schedule.")
    }
    XCTAssertEqual(entries.allElementsBoundByIndex.map(\.identifier), expected)
    XCTAssertEqual(
      entries.allElementsBoundByIndex.map { $0.value as? String },
      ["All day · " + earlierDescription, "All day · " + laterDescription])
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Overlapping all-day schedules retain chronological identity order"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func selectDay(
    _ day: Int, pickerIdentifier: String, application: XCUIApplication
  ) {
    let picker = application.descendants(matching: .any)
      .matching(identifier: pickerIdentifier).firstMatch
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.buttons.firstMatch.activateForPlannerJourney()
    let selectedDay = application.buttons.containing(.staticText, identifier: String(day))
      .firstMatch
    XCTAssertTrue(selectedDay.waitForExistence(timeout: 5))
    selectedDay.activateForPlannerJourney()
    let dismissRegion = application.buttons.matching(identifier: "PopoverDismissRegion").firstMatch
    XCTAssertTrue(dismissRegion.waitForExistence(timeout: 5))
    let toolbar = application.plannerElement("saved.schedule.cancel").coordinate(
      withNormalizedOffset: CGVector(dx: 1.4, dy: 0.5))
    #if os(macOS)
      toolbar.click()
    #else
      toolbar.tap()
    #endif
    XCTAssertTrue(dismissRegion.waitForNonExistence(timeout: 5))
  }
}
