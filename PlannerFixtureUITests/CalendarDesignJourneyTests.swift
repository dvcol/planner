import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class CalendarDesignJourneyTests: XCTestCase {
    func testReferenceLayoutsLinkAgendaAndGridAndOpenExactOwners() throws {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      defer { XCUIDevice.shared.orientation = .portrait }
      let application = openCalendarFixture()
      for mode in ["Agenda", "Day", "Week", "Month", "Quarter", "Year"] {
        application.chooseSavedCalendarMode(mode)
        capture("Portrait \(mode)")
      }
      application.chooseSavedCalendarMode("Week")
      XCUIDevice.shared.orientation = .landscapeLeft
      let rotated = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in
          let frame = application.windows.firstMatch.frame
          return frame.width > frame.height
        }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed)
      let sidebar = application.descendants(matching: .any)
        .matching(identifier: "saved.calendar.sidebar").firstMatch
      XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
      let grid = application.savedCalendarTimeGrid()
      XCTAssertLessThanOrEqual(sidebar.frame.maxX, grid.frame.minX + 1)
      let todayFields = Calendar.current.dateComponents([.year, .month, .day], from: Date())
      let todayIdentifier =
        "\(try XCTUnwrap(todayFields.year))-\(try XCTUnwrap(todayFields.month))-\(try XCTUnwrap(todayFields.day))"
      let todayHeading = grid.buttons["saved.calendar.day-heading.\(todayIdentifier)"]
      let span = grid.buttons.matching(
        NSPredicate(
          format: "label == %@ AND identifier BEGINSWITH %@", "City weekend",
          "saved.calendar.all-day.")
      ).firstMatch
      XCTAssertTrue(span.exists)
      XCTAssertLessThanOrEqual(span.frame.minX, todayHeading.frame.minX + 4)
      XCTAssertGreaterThanOrEqual(span.frame.maxX, todayHeading.frame.maxX - 4)
      capture("Landscape week and left agenda")
      let heading = application.buttons["saved.calendar.heading"].firstMatch
      let initialFocus = heading.value as? String
      let agenda = sidebar.scrollViews.firstMatch
      let initiallyVisible = visibleAgendaIdentifiers(agenda)
      grid.swipeUp()
      let timeChanged = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in
          heading.value as? String != initialFocus
        }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [timeChanged], timeout: 5), .completed)
      XCTAssertNotEqual(visibleAgendaIdentifiers(agenda), initiallyVisible)
      capture("Grid scroll updates agenda focus")
      let focusAfterGridScroll = heading.value as? String
      XCTAssertTrue(agenda.exists)
      agenda.swipeUp()
      let agendaChanged = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in
          heading.value as? String != focusAfterGridScroll
        }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [agendaChanged], timeout: 5), .completed)
      capture("Agenda scroll updates calendar focus")
      application.chooseSavedCalendarMode("Month")
      capture("Landscape month event grid")
      application.chooseSavedCalendarMode("Week")
      application.plannerElement("saved.calendar.today").activateForPlannerJourney()
      let entry = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.calendar.schedule.",
          "Museum visit")
      ).firstMatch
      for _ in 0..<8 {
        if entry.isHittable { break }
        agenda.swipeDown()
      }
      XCTAssertTrue(entry.isHittable)
      let scheduleIdentifier = try XCTUnwrap(entry.identifier.split(separator: ".").last)
      entry.activateForPlannerJourney()
      let exactSchedule = application.descendants(matching: .any)
        .matching(identifier: "saved.item.schedule.\(scheduleIdentifier)").firstMatch
      if !exactSchedule.waitForExistence(timeout: 3) { application.swipeUp() }
      XCTAssertTrue(exactSchedule.waitForExistence(timeout: 10))
      capture("Exact Item and Schedule details")
    }

    func testMultiDayItineraryBarOpensItsExactSavedPlan() throws {
      continueAfterFailure = false
      let application = openCalendarFixture()
      application.chooseSavedCalendarMode("Month")
      let span = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.calendar.span.", "City weekend"
        )
      ).firstMatch
      XCTAssertTrue(span.waitForExistence(timeout: 10))
      let identifier = try XCTUnwrap(span.identifier.split(separator: ".").last)
      span.activateForPlannerJourney()
      let schedule = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.schedule.\(identifier)").firstMatch
      for _ in 0..<6 {
        if schedule.exists { break }
        application.swipeUp()
      }
      XCTAssertTrue(schedule.waitForExistence(timeout: 10))
      capture("Exact Itinerary and multi-day Schedule details")
    }

    func testTimedGridOpensTheExactItemAndSchedule() throws {
      continueAfterFailure = false
      let application = openCalendarFixture()
      application.chooseSavedCalendarMode("Day")
      let grid = application.savedCalendarTimeGrid()
      let entry = grid.buttons.matching(NSPredicate(format: "label == %@", "Museum visit"))
        .firstMatch
      XCTAssertTrue(entry.waitForExistence(timeout: 10))
      for _ in 0..<6 {
        if entry.isHittable { break }
        grid.swipeDown()
      }
      XCTAssertTrue(entry.isHittable)
      capture("Day time grid before opening details")
      let identifier = try XCTUnwrap(entry.identifier.split(separator: ".").last)
      let headerBottom =
        grid.buttons.matching(
          NSPredicate(
            format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
            "saved.calendar.day-heading.", "saved.calendar.all-day.")
        ).allElementsBoundByIndex.map(\.frame.maxY).max() ?? grid.frame.minY
      let visibleFrame = entry.frame.intersection(
        CGRect(
          x: grid.frame.minX, y: headerBottom + 4, width: grid.frame.width,
          height: max(0, grid.frame.maxY - headerBottom - 4)))
      XCTAssertFalse(visibleFrame.isEmpty)
      entry.coordinate(withNormalizedOffset: .zero).withOffset(
        CGVector(dx: visibleFrame.midX - entry.frame.minX, dy: visibleFrame.midY - entry.frame.minY)
      ).tap()
      let schedule = application.descendants(matching: .any)
        .matching(identifier: "saved.item.schedule.\(identifier)").firstMatch
      for _ in 0..<6 {
        if schedule.exists { break }
        application.swipeUp()
      }
      XCTAssertTrue(schedule.waitForExistence(timeout: 10))
      capture("Exact Item opened from the time grid")
    }

    private func openCalendarFixture() -> XCUIApplication {
      XCUIDevice.shared.orientation = .portrait
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "calendar-design", "--fixture-dataset", UUID().uuidString,
        "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
      ]
      application.launchSavedPlannerJourney()
      let ready = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier == %@ OR label IN %@", "saved.section.calendar",
          ["Calendar", "Show Sidebar"])
      ).firstMatch
      XCTAssertTrue(ready.waitForExistence(timeout: 30))
      application.openPlannerSection("Calendar")
      return application
    }

    private func visibleAgendaIdentifiers(_ agenda: XCUIElement) -> [String] {
      let viewport = agenda.frame
      return agenda.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.schedule.")
      )
      .allElementsBoundByIndex.filter {
        $0.frame.midY >= viewport.minY && $0.frame.midY <= viewport.maxY
      }.map(\.identifier)
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
