import Vision
import XCTest

#if os(iOS)
  @MainActor
  final class CalendarRepeatedTimeJourneyTests: XCTestCase {
    func testSpringSpanUsesLocalClockHeightAndAlignsWithOrdinaryDay() throws {
      continueAfterFailure = false
      let application = try openNovemberCalendar(
        scenario: "calendar-clock-alignment", month: 3, day: 8)
      let modes = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.mode"
      ).firstMatch
      modes.buttons["Day"].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      let appointment = grid.buttons.matching(
        NSPredicate(format: "label == %@", "Spring museum")
      ).firstMatch
      XCTAssertTrue(appointment.waitForExistence(timeout: 10))
      for _ in 0..<6 {
        if appointment.isHittable { break }
        grid.swipeDown()
      }
      XCTAssertTrue(appointment.isHittable)
      XCTAssertEqual(appointment.frame.height, 270, accuracy: 1)
      let boundary = grid.buttons.matching(NSPredicate(format: "label == %@", "Spring boundary"))
        .firstMatch
      XCTAssertTrue(boundary.waitForExistence(timeout: 10))
      XCTAssertEqual(boundary.frame.height, 180, accuracy: 1)
      modes.buttons["Week"].activateForPlannerJourney()
      XCTAssertTrue(appointment.waitForExistence(timeout: 10))
      let monday = grid.buttons.matching(NSPredicate(format: "label == %@", "Monday museum"))
        .firstMatch
      XCTAssertTrue(monday.waitForExistence(timeout: 10))
      XCTAssertEqual(appointment.frame.minY, monday.frame.minY, accuracy: 1)
      XCTAssertEqual(appointment.frame.height, monday.frame.height, accuracy: 1)
      for _ in 0..<6 {
        if appointment.isHittable { break }
        grid.swipeDown()
      }
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Spring clock-aligned Week appointments"
      capture.lifetime = .keepAlways
      add(capture)
      XCTAssertTrue(appointment.isHittable)
      let description = try XCTUnwrap(appointment.value as? String)
      XCTAssertTrue(description.contains("EST"), description)
      XCTAssertTrue(description.contains("EDT"), description)
    }

    func testAutumnSpanCoversItsClockSegmentsAndAlignsWithOrdinaryDay() throws {
      continueAfterFailure = false
      let application = try openNovemberCalendar(scenario: "calendar-clock-alignment")
      let modes = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.mode"
      ).firstMatch
      modes.buttons["Day"].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      let backward = grid.buttons.matching(NSPredicate(format: "label == %@", "Backward span"))
        .firstMatch
      let later = grid.buttons.matching(NSPredicate(format: "label == %@", "Autumn museum"))
        .firstMatch
      XCTAssertTrue(backward.waitForExistence(timeout: 10))
      XCTAssertTrue(later.waitForExistence(timeout: 10))
      XCTAssertEqual(backward.frame.height, 90, accuracy: 1)
      XCTAssertEqual(later.frame.minY - backward.frame.minY, 90, accuracy: 1)
      XCTAssertEqual(later.frame.height, 180, accuracy: 1)
      for _ in 0..<6 {
        if backward.isHittable { break }
        grid.swipeDown()
      }
      XCTAssertTrue(backward.isHittable)
      let description = try XCTUnwrap(backward.value as? String)
      let normalizedDescription = description.split(whereSeparator: \.isWhitespace).joined(
        separator: " ")
      XCTAssertTrue(normalizedDescription.contains("1:55 AM EDT"), description)
      XCTAssertTrue(normalizedDescription.contains("1:05 AM EST"), description)
      let identifier = try XCTUnwrap(backward.identifier.split(separator: ".").last)
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Backward span retains both endpoints on the aligned Day grid"
      capture.lifetime = .keepAlways
      add(capture)
      modes.buttons["Week"].activateForPlannerJourney()
      XCTAssertTrue(later.waitForExistence(timeout: 10))
      let monday = grid.buttons.matching(NSPredicate(format: "label == %@", "Monday autumn"))
        .firstMatch
      XCTAssertTrue(monday.waitForExistence(timeout: 10))
      XCTAssertEqual(later.frame.minY, monday.frame.minY, accuracy: 1)
      XCTAssertEqual(later.frame.height, monday.frame.height, accuracy: 1)
      modes.buttons["Day"].activateForPlannerJourney()
      for _ in 0..<6 {
        if backward.isHittable { break }
        grid.swipeDown()
      }
      backward.activateForPlannerJourney()
      let source = application.descendants(matching: .any).matching(
        identifier: "saved.item.schedule.\(identifier)"
      ).firstMatch
      XCTAssertTrue(source.waitForExistence(timeout: 10))
      let sourceDescription = try XCTUnwrap(source.value as? String)
      let normalizedSource = sourceDescription.split(whereSeparator: \.isWhitespace).joined(
        separator: " ")
      XCTAssertTrue(normalizedSource.contains("1:55 AM EDT"), sourceDescription)
      XCTAssertTrue(normalizedSource.contains("1:05 AM EST"), sourceDescription)
      XCTAssertTrue(sourceDescription.hasSuffix("America/New_York"), sourceDescription)
    }

    func testHalfHourForwardChangeAndOvernightClippingUseClockBounds() throws {
      continueAfterFailure = false
      let cases: [(zone: String, month: Int, day: Int, title: String)] = [
        ("Australia/Lord_Howe", 10, 4, "Island spring"),
        ("America/New_York", 5, 3, "Overnight museum"),
        ("America/Nuuk", 3, 28, "Midnight boundary"),
      ]
      for fixture in cases {
        let application = try openNovemberCalendar(
          scenario: "calendar-clock-alignment", zone: fixture.zone,
          month: fixture.month, day: fixture.day)
        let modes = application.descendants(matching: .any).matching(
          identifier: "saved.calendar.mode"
        ).firstMatch
        modes.buttons["Day"].activateForPlannerJourney()
        let grid = application.descendants(matching: .any).matching(
          identifier: "saved.calendar.time-grid"
        ).firstMatch
        let appointment = grid.buttons.matching(NSPredicate(format: "label == %@", fixture.title))
          .firstMatch
        XCTAssertTrue(appointment.waitForExistence(timeout: 10))
        XCTAssertEqual(appointment.frame.height, 180, accuracy: 1)
        for _ in 0..<12 {
          if appointment.isHittable, appointment.frame.minY >= grid.frame.minY,
            appointment.frame.maxY <= grid.frame.maxY
          {
            break
          }
          if appointment.frame.minY < grid.frame.minY {
            grid.swipeDown()
          } else {
            grid.swipeUp()
          }
        }
        XCTAssertTrue(appointment.isHittable)
        XCTAssertGreaterThanOrEqual(appointment.frame.minY, grid.frame.minY)
        XCTAssertLessThanOrEqual(appointment.frame.maxY, grid.frame.maxY)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Clock bounds for \(fixture.title)"
        capture.lifetime = .keepAlways
        add(capture)
        if fixture.zone == "Australia/Lord_Howe" {
          modes.buttons["Week"].activateForPlannerJourney()
          let monday = grid.buttons.matching(NSPredicate(format: "label == %@", "Island Monday"))
            .firstMatch
          XCTAssertTrue(monday.waitForExistence(timeout: 10))
          XCTAssertEqual(appointment.frame.minY, monday.frame.minY, accuracy: 1)
          XCTAssertEqual(appointment.frame.height, monday.frame.height, accuracy: 1)
        }
        application.terminate()
      }
    }

    func testHalfHourRepeatedClockTimesKeepIndependentLanes() throws {
      continueAfterFailure = false
      let application = try openNovemberCalendar(
        scenario: "calendar-clock-alignment", zone: "Australia/Lord_Howe", month: 4, day: 5)
      let modes = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.mode"
      ).firstMatch
      modes.buttons["Day"].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      let first = grid.buttons.matching(NSPredicate(format: "label == %@", "Island first"))
        .firstMatch
      let second = grid.buttons.matching(NSPredicate(format: "label == %@", "Island second"))
        .firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 10))
      XCTAssertTrue(second.waitForExistence(timeout: 10))
      XCTAssertNotEqual(first.identifier, second.identifier)
      XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
      XCTAssertFalse(first.frame.intersects(second.frame))
      for _ in 0..<6 {
        if first.isHittable && second.isHittable { break }
        grid.swipeDown()
      }
      XCTAssertTrue(first.isHittable)
      XCTAssertTrue(second.isHittable)
      XCTAssertNotEqual(first.value as? String, second.value as? String)
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Independent 01:45 appointments across Lord Howe half-hour change"
      capture.lifetime = .keepAlways
      add(capture)
    }

    func testShortBookedClockChangeSpanPaintsBothTimezoneNamesInWeekView() throws {
      continueAfterFailure = false
      let application = try openNovemberCalendar(scenario: "calendar-repeated-short-span")
      let modes = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.mode"
      ).firstMatch
      modes.buttons["Week"].activateForPlannerJourney()
      let grid = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.time-grid"
      ).firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 5))
      let appointment = grid.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.calendar.timed.2026-11-1.")
      ).firstMatch
      XCTAssertTrue(appointment.waitForExistence(timeout: 10))
      for _ in 0..<6 {
        if appointment.isHittable { break }
        grid.swipeDown()
      }
      XCTAssertTrue(appointment.isHittable)
      let screenshot = XCUIScreen.main.screenshot()
      let capture = XCTAttachment(screenshot: screenshot)
      capture.name = "Ten-minute booked span with both clock-change endpoints"
      capture.lifetime = .keepAlways
      add(capture)
      let visibleFrame = appointment.frame.intersection(application.frame)
      XCTAssertFalse(visibleFrame.isEmpty)
      let recognition = VNRecognizeTextRequest()
      recognition.recognitionLevel = .accurate
      recognition.recognitionLanguages = ["en-US"]
      recognition.usesLanguageCorrection = false
      recognition.regionOfInterest = CGRect(
        x: visibleFrame.minX / application.frame.width,
        y: 1 - visibleFrame.maxY / application.frame.height,
        width: visibleFrame.width / application.frame.width,
        height: visibleFrame.height / application.frame.height)
      let image = try XCTUnwrap(screenshot.image.cgImage)
      try VNImageRequestHandler(cgImage: image).perform([recognition])
      let recognizedText = (recognition.results ?? []).compactMap {
        $0.topCandidates(1).first?.string
      }.joined(separator: " ")
      let textCapture = XCTAttachment(string: recognizedText)
      textCapture.name = "Visible appointment text recognized by native Vision"
      textCapture.lifetime = .keepAlways
      add(textCapture)
      XCTAssertTrue(recognizedText.contains("EDT"), recognizedText)
      XCTAssertTrue(recognizedText.contains("EST"), recognizedText)
    }

    func testBookedSpanAcrossRepeatedClockTimeDescribesBothEndpoints() throws {
      continueAfterFailure = false
      let application = try openNovemberCalendar(scenario: "calendar-repeated-span")
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
      for _ in 0..<6 {
        if appointment.isHittable { break }
        grid.swipeDown()
      }
      XCTAssertTrue(appointment.isHittable)
      let description = try XCTUnwrap(appointment.value as? String)
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Booked span from 01:30 EDT to 01:30 EST"
      capture.lifetime = .keepAlways
      add(capture)
      XCTAssertTrue(description.contains("EDT"), description)
      XCTAssertTrue(description.contains("EST"), description)
      XCTAssertFalse(description.hasPrefix("Start only"))
      let scheduleIdentifier = try XCTUnwrap(appointment.identifier.split(separator: ".").last)
      for mode in ["Week", "Month"] {
        modes.buttons[mode].activateForPlannerJourney()
        let entry: XCUIElement
        if mode == "Month" {
          entry = application.buttons["saved.calendar.schedule.\(scheduleIdentifier)"].firstMatch
        } else {
          entry =
            grid.buttons.matching(
              NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                "saved.calendar.timed.2026-11-1.", String(scheduleIdentifier))
            ).firstMatch
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<6 {
          let tabBar = application.tabBars.firstMatch
          let bottomBarObscuresEntry =
            mode == "Month" && tabBar.exists && tabBar.frame.minY > application.frame.midY
            && entry.frame.maxY > tabBar.frame.minY
          if entry.isHittable && !bottomBarObscuresEntry { break }
          if mode == "Month" {
            application.scrollViews.firstMatch.swipeUp()
          } else {
            grid.swipeDown()
          }
        }
        XCTAssertTrue(entry.isHittable)
        if mode == "Month", application.tabBars.firstMatch.exists,
          application.tabBars.firstMatch.frame.minY > application.frame.midY
        {
          XCTAssertLessThanOrEqual(entry.frame.maxY, application.tabBars.firstMatch.frame.minY)
        }
        XCTAssertEqual(entry.value as? String, description)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Booked clock-change span in \(mode)"
        capture.lifetime = .keepAlways
        add(capture)
      }
      application.buttons["saved.calendar.schedule.\(scheduleIdentifier)"].firstMatch
        .activateForPlannerJourney()
      let sourceSchedule = application.descendants(matching: .any).matching(
        identifier: "saved.item.schedule.\(scheduleIdentifier)"
      ).firstMatch
      XCTAssertTrue(sourceSchedule.waitForExistence(timeout: 10))
      let sourceDescription = try XCTUnwrap(sourceSchedule.value as? String)
      let sourceCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      sourceCapture.name = "Retained source Schedule across the clock change"
      sourceCapture.lifetime = .keepAlways
      add(sourceCapture)
      XCTAssertTrue(sourceDescription.contains("EDT"), sourceDescription)
      XCTAssertTrue(sourceDescription.contains("EST"), sourceDescription)
      XCTAssertTrue(sourceDescription.hasSuffix("America/New_York"), sourceDescription)
    }

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
      let scheduleIdentifiers = try values.map {
        String(try XCTUnwrap($0.identifier.split(separator: ".").last))
      }
      for _ in 0..<6 {
        if values.allSatisfy(\.isHittable) { break }
        grid.swipeDown()
      }
      XCTAssertTrue(values.allSatisfy(\.isHittable))
      XCTAssertEqual(values[0].frame.minY, values[1].frame.minY, accuracy: 1)
      XCTAssertNotEqual(values[0].frame.minX, values[1].frame.minX)
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
      application.buttons["saved.calendar.schedule.\(scheduleIdentifiers[0])"].firstMatch
        .activateForPlannerJourney()
      let sourceSchedules = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
      XCTAssertTrue(sourceSchedules.firstMatch.waitForExistence(timeout: 10))
      XCTAssertEqual(sourceSchedules.count, 2)
      let sourceValues = sourceSchedules.allElementsBoundByIndex
      XCTAssertTrue(sourceValues.allSatisfy { $0.label == "Start only" })
      XCTAssertEqual(
        Set(
          sourceValues.map {
            $0.identifier.replacingOccurrences(of: "saved.item.schedule.", with: "")
          }),
        Set(scheduleIdentifiers))
      let sourceDescriptions = try sourceValues.map { try XCTUnwrap($0.value as? String) }
      let sourceCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      sourceCapture.name = "Independent start-only source Schedules in the repeated hour"
      sourceCapture.lifetime = .keepAlways
      add(sourceCapture)
      XCTAssertTrue(sourceDescriptions.contains { $0.contains("EDT") })
      XCTAssertTrue(sourceDescriptions.contains { $0.contains("EST") })
      XCTAssertTrue(sourceDescriptions.allSatisfy { $0.hasSuffix("America/New_York") })
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

    private func openNovemberCalendar(
      scenario: String, zone: String = "America/New_York", month targetMonth: Int = 11, day: Int = 1
    ) throws -> XCUIApplication {
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
      search.typeText(zone)
      application.plannerElement("saved.schedule.zone.option.\(zone)")
        .activateForPlannerJourney()
      application.plannerElement("saved.calendar.zone.done").activateForPlannerJourney()
      let picker = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.date"
      ).firstMatch
      XCTAssertTrue(picker.waitForExistence(timeout: 5))
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
      let today = calendar.dateComponents([.year, .month], from: Date())
      let year = try XCTUnwrap(today.year)
      let month = try XCTUnwrap(today.month)
      let monthDifference = (2026 - year) * 12 + targetMonth - month
      let direction = monthDifference >= 0 ? "next" : "previous"
      for _ in 0..<abs(monthDifference) {
        let navigation = picker.buttons.matching(
          NSPredicate(format: "label CONTAINS[c] %@", direction)
        ).firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 5), application.debugDescription)
        navigation.activateForPlannerJourney()
      }
      let firstDay = picker.buttons.containing(.staticText, identifier: String(day)).firstMatch
      XCTAssertTrue(firstDay.waitForExistence(timeout: 5), application.debugDescription)
      firstDay.activateForPlannerJourney()
      return application
    }
  }
#endif
