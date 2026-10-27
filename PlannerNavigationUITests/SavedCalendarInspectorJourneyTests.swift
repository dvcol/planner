import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class SavedCalendarInspectorJourneyTests: XCTestCase {
  func testCalendarDetailsCanHideAndReopenWithoutChangingTheSelectedSchedule() throws {
    try qualifyCalendarInspectorLayout(mode: "Month")
  }

  func testDayDetailsSurviveLayoutChangesWithoutChangingTheSelectedSchedule() throws {
    try qualifyCalendarInspectorLayout(mode: "Day")
  }

  func testWeekDetailsSurviveLayoutChangesWithoutChangingTheSelectedSchedule() throws {
    try qualifyCalendarInspectorLayout(mode: "Week")
  }

  private func qualifyCalendarInspectorLayout(mode: String) throws {
    #if os(iOS)
      guard UIDevice.current.userInterfaceIdiom == .pad else {
        throw XCTSkip("This journey qualifies the regular-width Calendar inspector.")
      }
    #endif
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    #if os(iOS)
      addTeardownBlock {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
      }
      XCUIDevice.shared.orientation = .landscapeLeft
    #endif
    application.launchSavedPlannerJourney()
    #if os(macOS)
      let window = application.windows.firstMatch
      let originalWidth = window.frame.width
      addTeardownBlock {
        await MainActor.run {
          guard application.state != .notRunning, window.exists else { return }
          SavedCalendarInspectorJourneyTests.resizePlannerWindow(window, width: originalWidth)
        }
      }
      Self.resizePlannerWindow(window, width: 1200)
    #else
      waitForPlannerWindowOrientation(application, landscape: true)
    #endif
    openSection("Items", in: application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Calendar inspector")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("The same saved Item")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = schedule.identifier
    let scheduleDescription = try XCTUnwrap(schedule.value as? String)
    openSection("Calendar", in: application)
    try selectSavedScheduleDate(application)
    let modes = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.mode"
    ).firstMatch
    XCTAssertTrue(modes.waitForExistence(timeout: 5))
    #if os(macOS)
      modes.radioButtons[mode].activateForPlannerJourney()
    #else
      modes.buttons[mode].activateForPlannerJourney()
    #endif
    let entry: XCUIElement
    if mode == "Month" {
      entry =
        application.descendants(matching: .any).matching(
          identifier: scheduleIdentifier.replacingOccurrences(
            of: "saved.item.schedule.", with: "saved.calendar.schedule.")
        ).firstMatch
    } else {
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 10))
      let identity = try XCTUnwrap(scheduleIdentifier.split(separator: ".").last)
      entry =
        grid.buttons.matching(
          NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
            "saved.calendar.timed.", "." + String(identity))
        ).firstMatch
      XCTAssertTrue(entry.waitForExistence(timeout: 10))
      revealTimedEntry(entry, in: grid, application: application)
    }
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertTrue(entry.waitForPlannerHittability())
    XCTAssertTrue(application.windows.firstMatch.frame.contains(entry.frame))
    let entryDescription = try XCTUnwrap(entry.value as? String)
    entry.activateForPlannerJourney()
    #if os(macOS)
      recordScreenshot(application, name: "Calendar inspector after native entry selection")
    #endif
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 10))
    let details = application.plannerElement("saved.calendar.details.toggle")
    XCTAssertTrue(details.waitForExistence(timeout: 5))
    let calendar = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.canvas"
    ).firstMatch
    XCTAssertTrue(calendar.exists)
    let calendarWidthWithDetails = calendar.frame.width
    let widthWithDetails = entry.frame.width
    XCTAssertGreaterThan(widthWithDetails, 0)
    recordScreenshot(application, name: "Native Calendar inspector presentation before closing")
    XCTAssertEqual(schedule.identifier, scheduleIdentifier)
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForNonExistence(timeout: 5))
    #if os(macOS)
      XCTAssertGreaterThan(calendar.frame.width, calendarWidthWithDetails + 100)
    #endif
    let layout = XCTAttachment(
      string:
        "Entry width with details: \(widthWithDetails)\nEntry width after hiding: \(entry.frame.width)\n"
        + "Calendar width with details: \(calendarWidthWithDetails)\n"
        + "Calendar width after hiding: \(calendar.frame.width)\n"
    )
    layout.name = "Calendar inspector layout observations"
    layout.lifetime = .keepAlways
    add(layout)
    XCTAssertEqual(details.label, "Show Details")
    XCTAssertTrue(details.waitForPlannerHittability())
    XCTAssertTrue(entry.isHittable)
    recordScreenshot(application, name: "Calendar uses the main width with its inspector hidden")
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.identifier, scheduleIdentifier)
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForNonExistence(timeout: 5))
    entry.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    recordScreenshot(application, name: "Calendar inspector retains the selected Schedule and Item")
    #if os(macOS)
      Self.resizePlannerWindow(window, width: 860)
    #else
      XCUIDevice.shared.orientation = .portrait
      waitForPlannerWindowOrientation(application, landscape: false)
    #endif
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.identifier, scheduleIdentifier)
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    recordScreenshot(
      application, name: "Selected Calendar details remain after narrowing the layout")
    assertInspectorContentVisible(application, schedule: schedule)
    XCTAssertEqual(entry.value as? String, entryDescription)
    #if os(macOS)
      Self.resizePlannerWindow(window, width: 820)
      assertInspectorContentVisible(application, schedule: schedule)
      XCTAssertEqual(schedule.identifier, scheduleIdentifier)
      XCTAssertEqual(schedule.value as? String, scheduleDescription)
      recordScreenshot(application, name: "Calendar panes fit the minimum window width")
    #endif
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForNonExistence(timeout: 5))
    #if os(macOS)
      Self.resizePlannerWindow(window, width: 1200)
    #else
      XCUIDevice.shared.orientation = .landscapeLeft
      waitForPlannerWindowOrientation(application, landscape: true)
    #endif
    XCTAssertEqual(details.label, "Show Details")
    XCTAssertTrue(details.waitForPlannerHittability())
    XCTAssertTrue(entry.waitForPlannerHittability())
    XCTAssertFalse(application.staticTexts["The same saved Item"].exists)
    recordScreenshot(
      application, name: "Calendar keeps its inspector hidden after widening the layout")
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.identifier, scheduleIdentifier)
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    assertInspectorContentVisible(application, schedule: schedule)
    XCTAssertEqual(entry.value as? String, entryDescription)
    recordScreenshot(
      application, name: "Calendar reopens the same Schedule after both layout changes")
    #if os(macOS)
      try verifyCalendarDivider(application)
      assertInspectorContentVisible(application, schedule: schedule)
      XCTAssertEqual(schedule.identifier, scheduleIdentifier)
      XCTAssertEqual(schedule.value as? String, scheduleDescription)
    #endif
    let identities = XCTAttachment(
      string:
        "Mode: \(mode)\nSchedule: \(scheduleIdentifier)\nSaved caption: \(scheduleDescription)\n"
        + "Calendar caption: \(entryDescription)")
    identities.name = "Calendar layout observed Schedule"
    identities.lifetime = .keepAlways
    add(identities)
  }

  private func selectSavedScheduleDate(_ application: XCUIApplication) throws {
    let picker = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.date"
    ).firstMatch
    XCTAssertTrue(picker.waitForExistence(timeout: 10))
    let marker = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
        "saved.calendar.day.", ".schedule-count")
    ).firstMatch
    if !marker.waitForExistence(timeout: 5) {
      picker.buttons["DatePicker.PreviousMonth"].activateForPlannerJourney()
    }
    XCTAssertTrue(marker.waitForExistence(timeout: 10))
    #if os(macOS)
      XCTAssertEqual(marker.value as? String, "1 scheduled entry")
    #else
      XCTAssertEqual(marker.label, "1 scheduled entry")
    #endif
    let components = marker.identifier.split(separator: ".")[3].split(separator: "-")
    XCTAssertEqual(components.count, 3)
    let day = try XCTUnwrap(Int(components[2]))
    #if os(macOS)
      let year = try XCTUnwrap(Int(components[0]))
      let month = try XCTUnwrap(Int(components[1]))
      let calendar = Calendar(identifier: .gregorian)
      let date = try XCTUnwrap(
        calendar.date(from: .init(year: year, month: month, day: day, hour: 12)))
      let format = Date.FormatStyle().weekday(.wide).month(.wide).day()
      picker.buttons[date.formatted(format)].firstMatch.activateForPlannerJourney()
    #else
      picker.buttons.containing(.staticText, identifier: String(day)).firstMatch
        .activateForPlannerJourney()
    #endif
  }

  private func revealTimedEntry(
    _ entry: XCUIElement, in grid: XCUIElement, application: XCUIApplication
  ) {
    for _ in 0..<12 {
      if entry.isHittable && application.windows.firstMatch.frame.contains(entry.frame) { return }
      if entry.frame.maxX > grid.frame.maxX {
        grid.swipeLeft()
      } else if entry.frame.minX < grid.frame.minX {
        grid.swipeRight()
      } else if entry.frame.minY < grid.frame.minY {
        grid.swipeDown()
      } else {
        grid.swipeUp()
      }
    }
  }

  private func assertInspectorContentVisible(
    _ application: XCUIApplication, schedule: XCUIElement
  ) {
    let retainedNotes = application.staticTexts["The same saved Item"].firstMatch
    #if os(macOS)
      let navigation = ["lists", "items", "inbox", "itineraries", "calendar"].map {
        application.plannerElement("saved.section.\($0)")
      }
      let geometry = XCTAttachment(
        string:
          "Window: \(application.windows.firstMatch.frame)\nNotes: \(retainedNotes.frame)\n"
          + "Schedule: \(schedule.frame)\n"
          + navigation.map { "\($0.identifier): \($0.frame)" }.joined(separator: "\n"))
      geometry.name = "Native Calendar inspector content bounds"
      geometry.lifetime = .keepAlways
      add(geometry)
      for destination in navigation {
        XCTAssertTrue(destination.waitForPlannerHittability())
        XCTAssertFalse(destination.frame.isEmpty)
        XCTAssertTrue(
          application.windows.firstMatch.frame.contains(destination.frame),
          "The sidebar destination must remain inside Planner's window: \(destination.identifier)")
      }
    #endif
    for content in [retainedNotes, schedule] {
      XCTAssertTrue(content.waitForPlannerHittability())
      XCTAssertFalse(content.frame.isEmpty)
      XCTAssertTrue(application.windows.firstMatch.frame.contains(content.frame))
    }
  }

  #if os(iOS)
    private func waitForPlannerWindowOrientation(
      _ application: XCUIApplication, landscape: Bool
    ) {
      let rotated = NSPredicate { _, _ in
        let frame = application.windows.firstMatch.frame
        return landscape ? frame.width > frame.height : frame.height > frame.width
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: rotated, object: application)], timeout: 5),
        .completed, "Planner's window must actually reach the requested orientation.")
    }
  #endif

  #if os(macOS)
    /// Exercises the native divider in both directions without changing the selected booking.
    private func verifyCalendarDivider(_ application: XCUIApplication) throws {
      let calendar = application.plannerElement("saved.calendar.canvas")
      let controls = XCTAttachment(string: application.splitters.debugDescription)
      controls.name = "Native Calendar divider controls"
      controls.lifetime = .keepAlways
      add(controls)
      let divider = try XCTUnwrap(
        application.splitters.allElementsBoundByIndex.first {
          $0.frame.height > 100 && abs($0.frame.midX - calendar.frame.maxX) < 8
        })
      for delta in [CGFloat(-40), 40] {
        let previousWidth = calendar.frame.width
        let coordinate = divider.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        coordinate.click(
          forDuration: 0.1, thenDragTo: coordinate.withOffset(.init(dx: delta, dy: 0)))
        let resized = NSPredicate { _, _ in
          abs(calendar.frame.width - previousWidth - delta) < 8
        }
        XCTAssertEqual(
          XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: resized, object: calendar)], timeout: 5),
          .completed, "The native divider must change Calendar's width by the requested amount.")
        recordScreenshot(application, name: "Calendar after native divider movement \(delta)")
      }
    }

    private static func resizePlannerWindow(_ window: XCUIElement, width: CGFloat) {
      let application = XCUIApplication()
      application.activate()
      let edge = window.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.8))
        .withOffset(.init(dx: -1, dy: 0))
      let target = edge.withOffset(.init(dx: width - window.frame.width, dy: 0))
      edge.click(forDuration: 0.1, thenDragTo: target)
      let resized = NSPredicate { _, _ in
        guard application.state != .notRunning else { return false }
        return abs(window.frame.width - width) < 8
      }
      let result = XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: resized, object: window)], timeout: 5)
      XCTAssertNotEqual(application.state, .notRunning, "Planner must survive Calendar resizing.")
      XCTContext.runActivity(named: "Native Calendar resize observation") { activity in
        let attachment = XCTAttachment(
          string: "Requested width: \(width)\nActual bounds: \(window.frame)\n")
        attachment.name = "Native Calendar resize observation"
        attachment.lifetime = .keepAlways
        activity.add(attachment)
      }
      XCTAssertEqual(
        result,
        .completed, "Planner's own window must actually reach the requested width.")
    }
  #endif

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = XCUIScreen.main.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func openSection(_ name: String, in application: XCUIApplication) {
    #if os(macOS)
      application.plannerElement("saved.section.\(name.lowercased())").activateForPlannerJourney()
    #else
      application.openPlannerSection(name)
    #endif
  }
}
