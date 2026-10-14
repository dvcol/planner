import XCTest

#if os(iOS)
  @MainActor
  final class CalendarRepeatedTimeJourneyTests: XCTestCase {
    func testRepeatedClockTimesKeepSeparateReadableAppointmentsInDayView() throws {
      continueAfterFailure = false
      let application = try openNovemberCalendar(scenario: "calendar-repeated-times")
      let modes = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.mode"
      ).firstMatch
      modes.buttons["Day"].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 5))
      let appointments = grid.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed.2026-11-1."))
      XCTAssertTrue(appointments.firstMatch.waitForExistence(timeout: 10))
      XCTAssertEqual(appointments.count, 2)
      let values = appointments.allElementsBoundByIndex
      XCTAssertEqual(Set(values.map(\.identifier)).count, 2)
      for _ in 0..<6 {
        if values.allSatisfy(\.isHittable) { break }
        grid.swipeDown()
      }
      XCTAssertTrue(values.allSatisfy(\.isHittable))
      XCTAssertFalse(values[0].frame.intersects(values[1].frame))
      let descriptions = try values.map { try XCTUnwrap($0.value as? String) }
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Distinct 01:30 appointments on the New York fall-back day"
      capture.lifetime = .keepAlways
      add(capture)
      XCTAssertNotEqual(descriptions[0], descriptions[1])
      XCTAssertTrue(descriptions.allSatisfy { $0.contains("1:30") })
      XCTAssertTrue(descriptions.contains { $0.hasSuffix("EDT") })
      XCTAssertTrue(descriptions.contains { $0.hasSuffix("EST") })
      for mode in ["Week", "Month"] {
        modes.buttons[mode].activateForPlannerJourney()
        let entries: XCUIElementQuery
        if mode == "Month" {
          entries = application.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.schedule."))
        } else {
          XCTAssertTrue(grid.waitForExistence(timeout: 5))
          entries = grid.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed.2026-11-1."))
        }
        XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(entries.count, 2)
        let entriesInMode = entries.allElementsBoundByIndex
        for _ in 0..<6 {
          if entriesInMode.allSatisfy(\.isHittable) { break }
          if mode == "Month" {
            application.scrollViews.firstMatch.swipeUp()
          } else {
            grid.swipeDown()
          }
        }
        XCTAssertTrue(entriesInMode.allSatisfy(\.isHittable))
        let valuesInMode = try entriesInMode.map { try XCTUnwrap($0.value as? String) }
        XCTAssertEqual(Set(valuesInMode), Set(descriptions))
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Distinct 01:30 appointments in \(mode)"
        capture.lifetime = .keepAlways
        add(capture)
      }
    }
    func testLateStartOnlyCardCanBeScrolledFullyIntoTheDayViewport() throws {
      continueAfterFailure = false
      let application = try openNovemberCalendar(scenario: "calendar-late-point")
      let modes = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.mode"
      ).firstMatch
      modes.buttons["Day"].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 5))
      let appointment = grid.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed.2026-11-1.")
      ).firstMatch
      XCTAssertTrue(appointment.waitForExistence(timeout: 10))
      for _ in 0..<12 {
        if appointment.isHittable, appointment.frame.maxY <= grid.frame.maxY { break }
        grid.swipeUp()
      }
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "23:59 start-only appointment at the bottom of the Day grid"
      capture.lifetime = .keepAlways
      add(capture)
      XCTAssertTrue(appointment.isHittable)
      XCTAssertGreaterThanOrEqual(appointment.frame.minY, grid.frame.minY)
      XCTAssertLessThanOrEqual(appointment.frame.maxY, grid.frame.maxY)
      XCTAssertEqual(appointment.label, "Late museum")
      XCTAssertTrue((appointment.value as? String)?.contains("11:59") == true)
    }

    private func openNovemberCalendar(scenario: String) throws -> XCUIApplication {
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", scenario, "--fixture-dataset", UUID().uuidString,
        "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Calendar"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Calendar")
      application.plannerElement("saved.calendar.zone.open").activateForPlannerJourney()
      let followsDevice = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.zone.follow-device"
      ).firstMatch
      XCTAssertTrue(followsDevice.waitForPlannerBooleanState(true))
      followsDevice.switches.firstMatch.tap()
      XCTAssertTrue(followsDevice.waitForPlannerBooleanState(false))
      application.plannerElement("saved.calendar.zone.choose").activateForPlannerJourney()
      let search = application.searchFields.firstMatch
      XCTAssertTrue(search.waitForExistence(timeout: 5))
      search.activateForPlannerJourney()
      search.typeText("America/New_York")
      application.plannerElement("saved.schedule.zone.option.America/New_York")
        .activateForPlannerJourney()
      application.plannerElement("saved.calendar.zone.done").activateForPlannerJourney()
      let picker = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.date"
      ).firstMatch
      XCTAssertTrue(picker.waitForExistence(timeout: 5))
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
      let today = calendar.dateComponents([.year, .month], from: Date())
      let year = try XCTUnwrap(today.year)
      let month = try XCTUnwrap(today.month)
      let monthDifference = (2026 - year) * 12 + 11 - month
      let direction = monthDifference >= 0 ? "next" : "previous"
      for _ in 0..<abs(monthDifference) {
        let navigation = picker.buttons.matching(
          NSPredicate(format: "label CONTAINS[c] %@", direction)
        ).firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 5), application.debugDescription)
        navigation.activateForPlannerJourney()
      }
      let firstDay = picker.buttons.containing(.staticText, identifier: "1").firstMatch
      XCTAssertTrue(firstDay.waitForExistence(timeout: 5), application.debugDescription)
      firstDay.activateForPlannerJourney()
      return application
    }
  }
#endif
