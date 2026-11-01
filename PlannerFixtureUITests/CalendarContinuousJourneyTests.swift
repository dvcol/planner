import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class CalendarContinuousJourneyTests: XCTestCase {
    func testPortraitHandleChangesTheFourScalesAndPreservesFocus() throws {
      continueAfterFailure = false
      let application = openCalendar()
      let heading = application.buttons["saved.calendar.heading"].firstMatch
      let focus = heading.value as? String
      let handle = application.buttons["saved.calendar.navigator.toggle"].firstMatch
      XCTAssertTrue(handle.waitForExistence(timeout: 10))
      for (direction, expected) in [
        (-1.0, "Week"), (-1, "Day"), (1, "Week"), (1, "Month"), (1, "Year"),
      ] {
        let start = handle.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        start.press(
          forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 0, dy: direction * 80)))
        let changed = XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "value == %@", expected), object: handle)
        let outcome = XCTWaiter.wait(for: [changed], timeout: 5)
        XCTAssertEqual(handle.value as? String, expected)
        XCTAssertEqual(outcome, .completed)
        XCTAssertEqual(heading.value as? String, focus)
        XCTAssertTrue(application.scrollViews["saved.calendar.agenda"].firstMatch.exists)
        if expected == "Day" || expected == "Week" {
          let grid = application.savedCalendarTimeGrid()
          try assertSelectedDateVisible(in: grid)
          let clock = grid.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Current time ")
          ).firstMatch
          XCTAssertTrue(clock.exists)
          XCTAssertTrue(grid.frame.contains(CGPoint(x: clock.frame.midX, y: clock.frame.midY)))
        }
        capture("Portrait handle selects \(expected)")
      }
      application.buttons["saved.calendar.mode"].firstMatch.tap()
      XCTAssertFalse(application.buttons["Agenda"].exists)
      XCTAssertFalse(application.buttons["Quarter"].exists)
    }

    func testMonthExtendsItsWindowAndReadsAnOffscreenBooking() throws {
      continueAfterFailure = false
      let application = openCalendar()
      let month = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.date"
      ).firstMatch
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())
      let todayButton = dateButton(today, in: month)
      XCTAssertTrue(todayButton.isHittable)
      let monthStart = try XCTUnwrap(calendar.dateInterval(of: .month, for: today)?.start)
      let target = try XCTUnwrap(calendar.date(byAdding: .month, value: 8, to: monthStart))
      let targetButton = dateButton(target, in: month)
      scrollUntilVisible(targetButton, in: month, forward: true, limit: 18)
      XCTAssertEqual(targetButton.value as? String, "1 scheduled entry")
      capture("Month extends beyond its original window")
      targetButton.tap()
      let entry = application.scrollViews["saved.calendar.agenda"].buttons.matching(
        NSPredicate(format: "label == %@", "Next summer visit")
      ).firstMatch
      XCTAssertTrue(entry.waitForExistence(timeout: 5))
      XCTAssertTrue(entry.isHittable)
      let identifier = try XCTUnwrap(entry.identifier.split(separator: ".").last)
      entry.tap()
      XCTAssertTrue(
        application.descendants(matching: .any)
          .matching(identifier: "saved.item.schedule.\(identifier)").firstMatch
          .waitForExistence(timeout: 10))
    }

    func testYearExtendsItsWindowAndReturnsThroughEarlierYears() throws {
      continueAfterFailure = false
      let application = openCalendar()
      application.chooseSavedCalendarMode("Year")
      application.setSavedCalendarBookingList(visible: false)
      let year = application.scrollViews["saved.calendar.overview"].firstMatch
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())
      XCTAssertTrue(dateButton(today, in: year).isHittable)
      let target = try XCTUnwrap(
        calendar.date(
          from: .init(
            year: calendar.component(.year, from: today) + 4, month: 2, day: 1)))
      let targetButton = dateButton(target, in: year)
      scrollUntilVisible(targetButton, in: year, forward: true, limit: 24)
      XCTAssertEqual(targetButton.value as? String, "1 scheduled entry")
      capture("Year extends beyond its original window")
      let past = try XCTUnwrap(
        calendar.date(
          from: .init(
            year: calendar.component(.year, from: today) - 1, month: 2, day: 1)))
      scrollUntilVisible(dateButton(past, in: year), in: year, forward: false, limit: 30)
      capture("Year scrolls back through earlier years")
    }

    func testDayAndWeekContinueThroughAdjacentPeriodsWithoutPaging() throws {
      continueAfterFailure = false
      let application = openCalendar()
      XCUIDevice.shared.orientation = .landscapeLeft
      defer { XCUIDevice.shared.orientation = .portrait }
      for mode in ["Day", "Week"] {
        application.plannerElement("saved.calendar.today").activateForPlannerJourney()
        application.chooseSavedCalendarMode(mode)
        let grid = application.savedCalendarTimeGrid()
        let initial = try assertSelectedDateVisible(in: grid)
        XCTAssertEqual(initial, Calendar.current.startOfDay(for: Date()))
        grid.swipeUp()
        XCTAssertEqual(try assertSelectedDateVisible(in: grid), initial)
        grid.swipeDown()
        XCTAssertEqual(try assertSelectedDateVisible(in: grid), initial)
        var future = initial
        let beyondWindow = try XCTUnwrap(
          Calendar.current.date(byAdding: .day, value: mode == "Week" ? 49 : 16, to: initial))
        for _ in 0..<24 {
          grid.swipeLeft()
          future = try assertSelectedDateVisible(in: grid)
          if future >= beyondWindow { break }
        }
        XCTAssertGreaterThanOrEqual(future, beyondWindow)
        capture("\(mode) flows into its next period")
        var past = future
        for _ in 0..<14 {
          grid.swipeRight()
          past = try assertSelectedDateVisible(in: grid)
          if past < future { break }
        }
        XCTAssertLessThan(past, future)
        capture("\(mode) flows into its previous period")
      }
    }

    func testDarkCalendarShowsWeekendContrastAndCurrentTime() throws {
      continueAfterFailure = false
      XCUIDevice.shared.appearance = .dark
      defer { XCUIDevice.shared.appearance = .light }
      let application = openCalendar(dark: true)
      for mode in ["Day", "Week", "Month", "Year"] {
        application.chooseSavedCalendarMode(mode)
        if mode == "Day" || mode == "Week" {
          XCTAssertTrue(application.staticTexts["saved.calendar.current-time"].exists)
        }
        capture("Dark \(mode) weekend and clock review")
      }
    }

    private func openCalendar(dark: Bool = false) -> XCUIApplication {
      XCUIDevice.shared.orientation = .portrait
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "calendar-design", "--fixture-dataset", UUID().uuidString,
        "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
      ]
      if dark { application.launchArguments += ["-AppleInterfaceStyle", "Dark"] }
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Calendar")
      return application
    }

    @discardableResult
    private func assertSelectedDateVisible(in grid: XCUIElement) throws -> Date {
      let header = grid.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-heading"
      ).firstMatch
      let heading = header.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND selected == true", "saved.calendar.day-heading.")
      ).firstMatch
      XCTAssertTrue(heading.waitForExistence(timeout: 5))
      let frame = heading.frame
      XCTAssertTrue(grid.frame.contains(CGPoint(x: frame.midX, y: frame.midY)))
      XCTAssertLessThan(
        frame.maxY, grid.frame.minY + 120,
        "The focused date heading must stay pinned above its hours.")
      let fields = heading.identifier.replacingOccurrences(
        of: "saved.calendar.day-heading.", with: ""
      )
      .split(separator: "-").compactMap { Int($0) }
      XCTAssertEqual(fields.count, 3)
      return try XCTUnwrap(
        Calendar.current.date(from: .init(year: fields[0], month: fields[1], day: fields[2])))
    }

    private func dateButton(_ date: Date, in view: XCUIElement) -> XCUIElement {
      let fields = Calendar.current.dateComponents([.year, .month, .day], from: date)
      return view.buttons[
        "saved.calendar.mini-day.\(fields.year ?? 0)-\(fields.month ?? 0)-\(fields.day ?? 0)"
      ].firstMatch
    }

    private func scrollUntilVisible(
      _ target: XCUIElement, in view: XCUIElement, forward: Bool, limit: Int
    ) {
      for _ in 0..<limit {
        if target.exists && target.isHittable { break }
        if forward { view.swipeUp() } else { view.swipeDown() }
      }
      XCTAssertTrue(
        target.isHittable, "Continuous scrolling must reach dates beyond the initial read window.")
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
