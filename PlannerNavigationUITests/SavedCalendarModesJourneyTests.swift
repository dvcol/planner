import XCTest

@MainActor
final class SavedCalendarModesJourneyTests: XCTestCase {
  #if os(iOS)
    func testCalendarKeepsItsWeekAndScheduleThroughPhoneRotation() throws {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      defer { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Calendar")
      let modes = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.mode"
      ).firstMatch
      XCTAssertTrue(modes.waitForExistence(timeout: 10))
      captureCalendarRotation(application, name: "Empty native month in portrait")
      XCUIDevice.shared.orientation = .landscapeLeft
      waitForCalendarOrientation(application, landscape: true)
      captureCalendarRotation(application, name: "Empty native month in landscape")
      XCUIDevice.shared.orientation = .portrait
      waitForCalendarOrientation(application, landscape: false)
      application.openPlannerSection("Items")
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 10))
      title.activateForPlannerJourney()
      title.typeText("Rotating museum")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.schedule.save").waitForNonExistence(timeout: 10))
      let saved = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
      ).firstMatch
      try revealSavedSchedule(saved, application: application)
      let scheduleIdentifier = saved.identifier.replacingOccurrences(
        of: "saved.item.schedule.", with: "")
      let savedDescription = try XCTUnwrap(saved.value as? String)
      captureCalendarRotation(application, name: "Saved Item in portrait")
      XCUIDevice.shared.orientation = .landscapeLeft
      waitForCalendarOrientation(application, landscape: true)
      captureCalendarRotation(application, name: "Saved Item in landscape")
      XCUIDevice.shared.orientation = .portrait
      waitForCalendarOrientation(application, landscape: false)
      application.openPlannerSection("Calendar")
      modeControl("Week", in: modes).activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 10))
      let headings = grid.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.day-heading.")
      ).allElementsBoundByIndex
      XCTAssertEqual(headings.count, 7)
      for heading in headings {
        XCTAssertGreaterThanOrEqual(heading.frame.minX, grid.frame.minX)
        XCTAssertLessThanOrEqual(heading.frame.maxX, grid.frame.maxX)
      }
      captureCalendarRotation(application, name: "Week in portrait before rotation")
      XCUIDevice.shared.orientation = .landscapeLeft
      waitForCalendarOrientation(application, landscape: true)
      captureCalendarRotation(application, name: "Week in landscape after rotation")
      XCTAssertTrue(modeControl("Week", in: modes).isSelected)
      XCTAssertTrue(grid.waitForExistence(timeout: 10))
      let entry = grid.buttons.matching(
        NSPredicate(format: "identifier ENDSWITH %@", scheduleIdentifier)
      ).firstMatch
      for _ in 0..<5 {
        if entry.isHittable { break }
        if entry.frame.minY >= grid.frame.maxY {
          grid.swipeUp()
        } else if entry.frame.maxY <= grid.frame.minY {
          grid.swipeDown()
        } else {
          grid.swipeLeft()
        }
      }
      XCTAssertTrue(entry.waitForPlannerHittability())
      entry.activateForPlannerJourney()
      try revealSavedSchedule(saved, application: application)
      XCTAssertEqual(saved.value as? String, savedDescription)
      XCUIDevice.shared.orientation = .portrait
      waitForCalendarOrientation(application, landscape: false)
      try revealSavedSchedule(saved, application: application)
      XCTAssertEqual(saved.value as? String, savedDescription)
      captureCalendarRotation(application, name: "Exact Schedule survives return to portrait")
    }

    private func waitForCalendarOrientation(_ application: XCUIApplication, landscape: Bool) {
      let orientation = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in
          let frame = application.windows.firstMatch.frame
          return landscape ? frame.width > frame.height : frame.height > frame.width
        }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 10), .completed)
    }

    private func captureCalendarRotation(_ application: XCUIApplication, name: String) {
      let capture = XCTAttachment(screenshot: calendarScreenshot(application))
      capture.name = name
      capture.lifetime = .keepAlways
      add(capture)
    }
  #endif

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
    application.plannerElement("Schedule item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    for _ in 0..<9 {
      XCTAssertTrue(actions.waitForExistence(timeout: 10))
      actions.activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
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
    modeControl("Day", in: modes).activateForPlannerJourney()
    let grid = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.time-grid"
    ).firstMatch
    XCTAssertTrue(grid.waitForExistence(timeout: 5))
    let timed = grid.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed.")
    ).firstMatch
    XCTAssertTrue(timed.waitForExistence(timeout: 10))
    let capture = XCTAttachment(screenshot: calendarScreenshot(application))
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
    #if os(iOS)
      XCTAssertLessThanOrEqual(overflow.frame.maxY, application.windows.firstMatch.frame.maxY + 1)
    #endif
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
    let overflowCapture = XCTAttachment(screenshot: calendarScreenshot(application))
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
    #if os(macOS)
      let expectedDate = String(calendarDescription.dropFirst(10))
      let valueReady = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "value == %@", expectedDate), object: savedSchedule)
      XCTAssertEqual(XCTWaiter.wait(for: [valueReady], timeout: 5), .completed)
      let scheduleObservation = application.descendants(matching: .any).matching(
        identifier: "saved.item.schedule.\(scheduleIdentifier)"
      ).allElementsBoundByIndex.map { element in
        "type=\(element.elementType.rawValue) label=\(element.label) value=\(String(describing: element.value)) frame=\(element.frame) hittable=\(element.isHittable)"
      }.joined(separator: "\n")
      let observation = XCTAttachment(string: scheduleObservation)
      observation.name = "Selected saved Schedule native value and visibility"
      observation.lifetime = .keepAlways
      add(observation)
      let detailsCapture = XCTAttachment(screenshot: calendarScreenshot(application))
      detailsCapture.name = "Selected overflow Schedule in native details"
      detailsCapture.lifetime = .keepAlways
      add(detailsCapture)
    #endif
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
    application.plannerElement("Schedule item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
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
    try selectDay(calendar.component(.day, from: end), application: application)
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
    modeControl("Week", in: modes).activateForPlannerJourney()
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
    XCTAssertEqual(hourLabels.count, 1, "The week shares one time ruler.")
    let ruler = grid.descendants(matching: .any).matching(
      identifier: "saved.calendar.time-ruler"
    ).firstMatch
    XCTAssertTrue(ruler.exists)
    let rulerPosition = ruler.frame.minX
    XCTAssertGreaterThanOrEqual(rulerPosition, grid.frame.minX)
    XCTAssertLessThanOrEqual(ruler.frame.maxX, grid.frame.maxX)
    grid.swipeLeft()
    XCTAssertEqual(ruler.frame.minX, rulerPosition, accuracy: 1)
    let capture = XCTAttachment(screenshot: calendarScreenshot(application))
    capture.name = "All-day span above aligned Week hours"
    capture.lifetime = .keepAlways
    add(capture)
  }

  private func selectDay(_ day: Int, application: XCUIApplication) throws {
    let picker = application.descendants(matching: .any).matching(
      identifier: "saved.schedule.end"
    ).firstMatch
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    #if os(macOS)
      let calendar = Calendar(identifier: .gregorian)
      guard let date = calendar.date(bySetting: .day, value: day, of: Date()) else {
        XCTFail("The requested date must exist in the current month.")
        return
      }
      let format = DateFormatter()
      format.calendar = calendar
      format.dateStyle = .short
      format.timeStyle = .none
      let pattern = try XCTUnwrap(format.dateFormat)
      let components: [Character] = ["d", "M", "y"]
      let positions = try components.map { try XCTUnwrap(pattern.firstIndex(of: $0)) }
      let dayComponent = try XCTUnwrap(positions.sorted().firstIndex(of: positions[0]))
      picker.activateForPlannerJourney()
      for _ in 0..<2 { application.typeKey(.leftArrow, modifierFlags: []) }
      for _ in 0..<dayComponent { application.typeKey(.rightArrow, modifierFlags: []) }
      application.typeText(String(calendar.component(.day, from: date)))
      application.typeKey(.tab, modifierFlags: [])
      let popover = application.dialogs.firstMatch
      XCTAssertTrue(popover.exists)
      let editor = application.sheets.firstMatch
      XCTAssertTrue(editor.exists)
      editor.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2)).click()
      XCTAssertTrue(popover.waitForNonExistence(timeout: 5))
      let field = XCTAttachment(string: picker.debugDescription)
      field.name = "Native all-day End date after day-component entry"
      field.lifetime = .keepAlways
      add(field)
      let capture = XCTAttachment(screenshot: calendarScreenshot(application))
      capture.name = "Native all-day Schedule End date"
      capture.lifetime = .keepAlways
      add(capture)
    #else
      picker.buttons.firstMatch.activateForPlannerJourney()
      let selectedDay = application.buttons.containing(.staticText, identifier: String(day))
        .firstMatch
      XCTAssertTrue(selectedDay.waitForExistence(timeout: 5))
      selectedDay.activateForPlannerJourney()
      let dismissRegion = application.buttons.matching(identifier: "PopoverDismissRegion")
        .firstMatch
      XCTAssertTrue(dismissRegion.waitForExistence(timeout: 5))
      let toolbar = application.plannerElement("saved.schedule.cancel").coordinate(
        withNormalizedOffset: CGVector(dx: 1.4, dy: 0.5))
      toolbar.tap()
      XCTAssertTrue(dismissRegion.waitForNonExistence(timeout: 5))
    #endif
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
      application.plannerElement("Schedule item").activateForPlannerJourney()
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
      modeControl(mode, in: modes).activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 5))
      let entries = grid.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed."))
      XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 10))
      XCTAssertEqual(entries.count, 4)
      let heading = application.descendants(matching: .any)
        .matching(identifier: try dayHeadingIdentifier(for: Date())).firstMatch
      XCTAssertTrue(heading.waitForExistence(timeout: 5))
      XCTAssertGreaterThanOrEqual(heading.frame.minX, grid.frame.minX)
      let appointments = entries.allElementsBoundByIndex
      XCTAssertEqual(Set(appointments.map(\.identifier)).count, 4)
      let ruler = grid.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-ruler"
      ).firstMatch
      XCTAssertTrue(ruler.exists)
      for (index, appointment) in appointments.enumerated() {
        XCTAssertGreaterThanOrEqual(appointment.frame.width, 44)
        for _ in 0..<12 {
          let viewport = grid.frame.intersection(application.windows.firstMatch.frame)
          let minimumVisibleX = max(viewport.minX, ruler.frame.maxX)
          let appointmentCenter = appointment.frame.midX
          if appointmentCenter >= minimumVisibleX && appointmentCenter <= viewport.maxX { break }
          let scrollRight = appointmentCenter < minimumVisibleX
          let start = grid.coordinate(
            withNormalizedOffset: CGVector(dx: scrollRight ? 0.6 : 0.8, dy: 0.6))
          let end = grid.coordinate(
            withNormalizedOffset: CGVector(dx: scrollRight ? 0.8 : 0.6, dy: 0.6))
          start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(appointment.isHittable)
        for other in appointments.dropFirst(index + 1) {
          XCTAssertFalse(appointment.frame.intersects(other.frame))
        }
      }
      let capture = XCTAttachment(screenshot: calendarScreenshot(application))
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
    application.plannerElement("Schedule item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let savedSchedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    try revealSavedSchedule(savedSchedule, application: application)
    let scheduleIdentifier = savedSchedule.identifier.replacingOccurrences(
      of: "saved.item.schedule.", with: "")
    let savedDescription = try XCTUnwrap(savedSchedule.value as? String)
    XCTAssertFalse(savedDescription.isEmpty)
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
    let hierarchy = XCTAttachment(
      string: ["Day", "Week", "Month"].map { name in
        let control = modeControl(name, in: modes)
        return "Mode: \(name); type: \(control.elementType.rawValue); label: \(control.label)"
      }.joined(separator: "\n"))
    hierarchy.name = "Native Calendar mode selector hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    let capture = XCTAttachment(screenshot: calendarScreenshot(application))
    capture.name = "Native Calendar mode selector"
    capture.lifetime = .keepAlways
    add(capture)
    XCTAssertTrue(modes.waitForExistence(timeout: 5))
    for mode in ["Day", "Week"] {
      modeControl(mode, in: modes).activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 5))
      let capture = XCTAttachment(screenshot: calendarScreenshot(application))
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
      let ruler = grid.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-ruler"
      ).firstMatch
      XCTAssertTrue(ruler.exists)
      XCTAssertGreaterThanOrEqual(entry.frame.minX, ruler.frame.maxX - 1)
      if mode == "Week" {
        let heading = application.descendants(matching: .any)
          .matching(identifier: try dayHeadingIdentifier(for: Date())).firstMatch
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
    try revealSavedSchedule(savedSchedule, application: application)
    XCTAssertEqual(savedSchedule.value as? String, savedDescription)
  }

  /// The runner's locale can differ from the app's supported display language.
  private func dayHeadingIdentifier(for date: Date) throws -> String {
    let components = Calendar(identifier: .gregorian).dateComponents(
      [.year, .month, .day], from: date)
    let year = try XCTUnwrap(components.year)
    let month = try XCTUnwrap(components.month)
    let day = try XCTUnwrap(components.day)
    return "saved.calendar.day-heading.\(year)-\(month)-\(day)"
  }

  /// Reveals lazy Schedule rows before reading them at larger text sizes.
  private func revealSavedSchedule(_ schedule: XCUIElement, application: XCUIApplication) throws {
    #if os(iOS)
      if !schedule.waitForExistence(timeout: 3) {
        let details = application.collectionViews.containing(
          .any, identifier: "saved.item.completion"
        ).firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        for _ in 0..<6 {
          if schedule.exists { break }
          details.swipeUp()
        }
      }
    #endif
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
  }

  private func modeControl(_ name: String, in picker: XCUIElement) -> XCUIElement {
    #if os(macOS)
      picker.radioButtons[name]
    #else
      picker.buttons[name]
    #endif
  }

  private func calendarScreenshot(_ application: XCUIApplication) -> XCUIScreenshot {
    #if os(macOS)
      application.windows.firstMatch.screenshot()
    #else
      XCUIScreen.main.screenshot()
    #endif
  }

}
