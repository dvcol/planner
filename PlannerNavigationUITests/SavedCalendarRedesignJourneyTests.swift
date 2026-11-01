import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class SavedCalendarRedesignJourneyTests: XCTestCase {
    func testCalendarModesKeepExactSchedulesAndPutLandscapeAgendaOnLeft() throws {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      defer { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.tap()
      title.typeText("Museum morning")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      application.openPlannerSection("Calendar")
      application.chooseSavedCalendarMode("Agenda")
      let schedule = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.schedule.")
      ).firstMatch
      XCTAssertTrue(schedule.waitForExistence(timeout: 10))
      let identifier = schedule.identifier.replacingOccurrences(
        of: "saved.calendar.schedule.", with: "")
      let value = try XCTUnwrap(schedule.value as? String)
      capture("Portrait agenda", application: application)
      application.plannerElement("saved.calendar.navigator.toggle").activateForPlannerJourney()
      let navigator = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.date"
      ).firstMatch
      XCTAssertEqual(
        navigator.buttons.matching(
          NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.mini-day.")
        ).count, 7)
      capture("Collapsed week navigator", application: application)
      application.plannerElement("saved.calendar.navigator.toggle").activateForPlannerJourney()
      XCTAssertGreaterThan(
        navigator.buttons.matching(
          NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.mini-day.")
        ).count, 7)

      for mode in ["Month", "Quarter", "Year", "Day", "Week"] {
        application.chooseSavedCalendarMode(mode)
        let control = application.descendants(matching: .any)
          .matching(identifier: "saved.calendar.mode").firstMatch
        XCTAssertEqual(control.value as? String, mode)
        if mode == "Day" || mode == "Week" {
          let grid = application.savedCalendarTimeGrid()
          XCTAssertTrue(
            grid.buttons.matching(
              NSPredicate(format: "identifier ENDSWITH %@", identifier)
            ).firstMatch.waitForExistence(timeout: 10))
        } else if mode == "Month" {
          XCTAssertTrue(
            application.buttons.matching(
              NSPredicate(format: "identifier ENDSWITH %@", identifier)
            ).firstMatch.waitForExistence(timeout: 10))
        } else {
          let overview = application.scrollViews["saved.calendar.overview"]
          XCTAssertTrue(overview.waitForExistence(timeout: 5))
          XCTAssertTrue(overview.buttons.firstMatch.exists)
        }
        capture("Portrait \(mode)", application: application)
      }
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
      capture("Landscape week with left agenda", application: application)
      application.chooseSavedCalendarMode("Agenda")
      let sameSchedule = application.buttons["saved.calendar.schedule.\(identifier)"].firstMatch
      XCTAssertTrue(sameSchedule.waitForExistence(timeout: 10))
      XCTAssertEqual(sameSchedule.value as? String, value)
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
      let retainedSchedule = application.descendants(matching: .any)
        .matching(identifier: "saved.item.schedule.\(identifier)").firstMatch
      for _ in 0..<6 {
        if retainedSchedule.exists { break }
        application.swipeUp()
      }
      XCTAssertTrue(retainedSchedule.waitForExistence(timeout: 10))
    }

    func testCalendarAddUsesSelectedDateAndExistingBookingEditor() throws {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.tap()
      title.typeText("Garden visit")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      application.openPlannerSection("Calendar")
      application.buttons["DatePicker.NextMonth"].activateForPlannerJourney()
      let scheduledMonth = try XCTUnwrap(
        Calendar.current.date(byAdding: .month, value: 1, to: Date()))
      application.plannerElement("saved.calendar.add").activateForPlannerJourney()
      let owner = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.owner.")
      ).firstMatch
      XCTAssertTrue(owner.waitForExistence(timeout: 10))
      owner.activateForPlannerJourney()
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      application.chooseSavedCalendarMode("Agenda")
      let schedule = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.schedule.")
      ).firstMatch
      XCTAssertTrue(schedule.waitForExistence(timeout: 10))
      XCTAssertEqual(schedule.label, "Garden visit")
      XCTAssertTrue(
        (schedule.value as? String)?.contains(
          scheduledMonth.formatted(.dateTime.month(.abbreviated))) == true)
      schedule.activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    }

    private func capture(_ name: String, application: XCUIApplication) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
