import XCTest

@MainActor
final class SavedCalendarModesJourneyTests: XCTestCase {
  func testDenseAllDaySchedulesKeepTimedAppointmentsAndEveryScheduleAccessible() throws {
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
    title.typeText("Dense all-day museum")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.actions")
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    for _ in 0..<9 {
      XCTAssertTrue(actions.waitForExistence(timeout: 10))
      actions.activateForPlannerJourney()
      application.plannerElement("Schedule Item").activateForPlannerJourney()
      let allDay = application.descendants(matching: .any).matching(
        identifier: "saved.schedule.allDay"
      ).firstMatch
      #if os(macOS)
        allDay.activateForPlannerJourney()
      #else
        allDay.switches.firstMatch.tap()
      #endif
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    }
    #if os(macOS)
      application.plannerElement("saved.section.calendar").activateForPlannerJourney()
    #else
      application.openPlannerSection("Calendar")
    #endif
    let modes = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.mode"
    ).firstMatch
    XCTAssertTrue(modes.waitForExistence(timeout: 5))
    modes.buttons["Day"].activateForPlannerJourney()
    let grid = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.time-grid"
    ).firstMatch
    XCTAssertTrue(grid.waitForExistence(timeout: 5))
    let timed = grid.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed.")
    ).firstMatch
    XCTAssertTrue(timed.waitForExistence(timeout: 10))
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "Dense all-day header preserves the timed appointment"
    capture.lifetime = .keepAlways
    add(capture)
    XCTAssertTrue(timed.isHittable)
    XCTAssertLessThan(timed.frame.minY, grid.frame.maxY)
    let more = grid.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.all-day.more.")
    ).firstMatch
    XCTAssertTrue(more.waitForExistence(timeout: 5))
    XCTAssertEqual(more.label, "7 more all-day schedules")
    more.activateForPlannerJourney()
    let overflow = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.all-day-overflow"
    ).firstMatch
    XCTAssertTrue(overflow.waitForExistence(timeout: 5))
    let schedules = overflow.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.all-day."))
    var scheduleIdentifiers: Set<String> = []
    for _ in 0..<8 {
      scheduleIdentifiers.formUnion(schedules.allElementsBoundByIndex.map(\.identifier))
      if scheduleIdentifiers.count == 9 { break }
      overflow.swipeUp()
    }
    XCTAssertEqual(scheduleIdentifiers.count, 9)
    let lastSchedule = try XCTUnwrap(schedules.allElementsBoundByIndex.last)
    let scheduleIdentifier = try XCTUnwrap(lastSchedule.identifier.split(separator: ".").last)
    let calendarDescription = try XCTUnwrap(lastSchedule.value as? String)
    for _ in 0..<5 {
      if lastSchedule.isHittable { break }
      overflow.swipeUp()
    }
    XCTAssertTrue(lastSchedule.isHittable)
    let overflowCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    overflowCapture.name = "Native overflow traversal reaches all nine Schedule identities"
    overflowCapture.lifetime = .keepAlways
    add(overflowCapture)
    lastSchedule.activateForPlannerJourney()
    XCTAssertTrue(overflow.waitForNonExistence(timeout: 5))
    let savedSchedule = application.descendants(matching: .any).matching(
      identifier: "saved.item.schedule.\(scheduleIdentifier)"
    ).firstMatch
    #if os(macOS)
      let details = application.scrollViews.firstMatch
    #else
      let details = application.collectionViews.firstMatch
    #endif
    XCTAssertTrue(details.waitForExistence(timeout: 10))
    for _ in 0..<8 {
      if savedSchedule.exists { break }
      details.swipeUp()
    }
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 5))
    XCTAssertEqual(savedSchedule.label, "All day")
    XCTAssertEqual(savedSchedule.value as? String, String(calendarDescription.dropFirst(10)))
  }

  func testAllDaySpanStaysVisibleAboveAlignedWeekHours() throws {
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
    title.typeText("Mixed museum")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.actions")
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    let allDay = application.descendants(matching: .any).matching(
      identifier: "saved.schedule.allDay"
    ).firstMatch
    #if os(macOS)
      allDay.activateForPlannerJourney()
    #else
      allDay.switches.firstMatch.tap()
    #endif
    let includesEnd = application.descendants(matching: .any).matching(
      identifier: "saved.schedule.hasEnd"
    ).firstMatch
    #if os(macOS)
      includesEnd.activateForPlannerJourney()
    #else
      includesEnd.switches.firstMatch.tap()
    #endif
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.startOfDay(for: Date())
    let week = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: today))
    let month = try XCTUnwrap(calendar.dateInterval(of: .month, for: today))
    let proposedEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: today))
    let lastWeekDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: week.end))
    let lastMonthDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: month.end))
    let end = min(proposedEnd, lastWeekDay, lastMonthDay)
    selectDay(calendar.component(.day, from: end), application: application)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    #if os(macOS)
      application.plannerElement("saved.section.calendar").activateForPlannerJourney()
    #else
      application.openPlannerSection("Calendar")
    #endif
    let modes = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.mode"
    ).firstMatch
    XCTAssertTrue(modes.waitForExistence(timeout: 5))
    modes.buttons["Week"].activateForPlannerJourney()
    let grid = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.time-grid"
    ).firstMatch
    XCTAssertTrue(grid.waitForExistence(timeout: 5))
    let banners = grid.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.all-day."))
    XCTAssertTrue(banners.firstMatch.waitForExistence(timeout: 10))
    let expectedDays = try XCTUnwrap(calendar.dateComponents([.day], from: today, to: end).day) + 1
    XCTAssertEqual(banners.count, expectedDays)
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
    let todayPrefix =
      "saved.calendar.all-day.\(try XCTUnwrap(todayComponents.year))-"
      + "\(try XCTUnwrap(todayComponents.month))-\(try XCTUnwrap(todayComponents.day))."
    let banner = banners.matching(NSPredicate(format: "identifier BEGINSWITH %@", todayPrefix))
      .firstMatch
    XCTAssertTrue(banner.isHittable)
    XCTAssertGreaterThanOrEqual(banner.frame.minY, grid.frame.minY)
    let timed = grid.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed.")
    ).firstMatch
    XCTAssertTrue(timed.exists)
    for _ in 0..<8 {
      if timed.isHittable { break }
      if timed.frame.minY >= grid.frame.maxY {
        grid.swipeUp()
      } else if timed.frame.maxY <= grid.frame.minY {
        grid.swipeDown()
      } else {
        grid.swipeLeft()
      }
    }
    XCTAssertTrue(timed.isHittable)
    var format = Date.FormatStyle(date: .omitted, time: .shortened)
    format.timeZone = calendar.timeZone
    let hour = try XCTUnwrap(
      calendar.date(
        bySettingHour: calendar.component(.hour, from: Date()), minute: 0, second: 0, of: today))
    let hourLabels = grid.staticTexts.matching(identifier: hour.formatted(format))
      .allElementsBoundByIndex
    XCTAssertGreaterThanOrEqual(hourLabels.count, 2)
    let positions = hourLabels.map { $0.frame.minY }
    XCTAssertLessThanOrEqual(try XCTUnwrap(positions.max()) - XCTUnwrap(positions.min()), 1)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "All-day span above aligned Week hours"
    capture.lifetime = .keepAlways
    add(capture)
  }

  private func selectDay(_ day: Int, application: XCUIApplication) {
    let picker = application.descendants(matching: .any).matching(
      identifier: "saved.schedule.end"
    ).firstMatch
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

  func testSimultaneousStartOnlyAppointmentsRemainSeparateAndUsableInDayView() throws {
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
    title.typeText("Overlap museum")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.actions")
    for _ in 0..<4 {
      XCTAssertTrue(actions.waitForExistence(timeout: 10))
      actions.activateForPlannerJourney()
      application.plannerElement("Schedule Item").activateForPlannerJourney()
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    }
    #if os(macOS)
      application.plannerElement("saved.section.calendar").activateForPlannerJourney()
    #else
      application.openPlannerSection("Calendar")
    #endif
    let modes = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.mode"
    ).firstMatch
    XCTAssertTrue(modes.waitForExistence(timeout: 5))
    for mode in ["Day", "Week"] {
      modes.buttons[mode].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 5))
      let entries = grid.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed."))
      XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 10))
      XCTAssertEqual(entries.count, 4)
      let heading = grid.staticTexts[Date().formatted(.dateTime.weekday().month().day())].firstMatch
      XCTAssertTrue(heading.waitForExistence(timeout: 5))
      XCTAssertGreaterThanOrEqual(heading.frame.minX, grid.frame.minX)
      let appointments = entries.allElementsBoundByIndex
      XCTAssertEqual(Set(appointments.map(\.identifier)).count, 4)
      for (index, appointment) in appointments.enumerated() {
        XCTAssertGreaterThanOrEqual(appointment.frame.width, 44)
        if !appointment.isHittable { grid.swipeLeft() }
        XCTAssertTrue(appointment.isHittable)
        for other in appointments.dropFirst(index + 1) {
          XCTAssertFalse(appointment.frame.intersects(other.frame))
        }
      }
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Independent overlapping start-only appointments in \(mode)"
      capture.lifetime = .keepAlways
      add(capture)
    }
  }

  func testDayAndWeekShowTheSavedStartOnlyEntryWithoutReschedulingIt() throws {
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
    title.typeText("Timed museum")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let savedSchedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = savedSchedule.identifier.replacingOccurrences(
      of: "saved.item.schedule.", with: "")
    let savedDescription = try XCTUnwrap(savedSchedule.value as? String)
    #if os(macOS)
      application.plannerElement("saved.section.calendar").activateForPlannerJourney()
    #else
      application.openPlannerSection("Calendar")
    #endif
    let monthEntry = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.schedule.\(scheduleIdentifier)"
    ).firstMatch
    XCTAssertTrue(monthEntry.waitForExistence(timeout: 10))
    let calendarDescription = try XCTUnwrap(monthEntry.value as? String)
    XCTAssertTrue(calendarDescription.hasPrefix("Start only · "))
    let modes = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.mode"
    ).firstMatch
    let hierarchy = XCTAttachment(string: application.debugDescription)
    hierarchy.name = "Native Calendar mode selector hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "Native Calendar mode selector"
    capture.lifetime = .keepAlways
    add(capture)
    XCTAssertTrue(modes.waitForExistence(timeout: 5))
    for mode in ["Day", "Week"] {
      modes.buttons[mode].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 5))
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Native \(mode) time grid"
      capture.lifetime = .keepAlways
      add(capture)
      let entry = grid.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
          "saved.calendar.timed.", scheduleIdentifier)
      ).firstMatch
      XCTAssertTrue(entry.waitForExistence(timeout: 10))
      XCTAssertEqual(entry.label, "Timed museum")
      XCTAssertEqual(entry.value as? String, calendarDescription)
      XCTAssertTrue(entry.isHittable)
      if mode == "Week" {
        let heading = grid.staticTexts[Date().formatted(.dateTime.weekday().month().day())]
          .firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(heading.frame.minY, grid.frame.minY)
        XCTAssertLessThanOrEqual(heading.frame.maxY, grid.frame.maxY)
      }
    }
    application.terminate()
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.plannerElement("saved.section.items").activateForPlannerJourney()
    #else
      application.openPlannerSection("Items")
    #endif
    let item = application.savedPlannerItemRows("Timed museum").firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    item.activateForPlannerJourney()
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(savedSchedule.value as? String, savedDescription)
  }
}
