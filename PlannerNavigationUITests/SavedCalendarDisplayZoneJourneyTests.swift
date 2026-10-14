import XCTest

@MainActor
final class SavedCalendarDisplayZoneJourneyTests: XCTestCase {
  func testAllDayDatesSurviveAnOverrideAndReturningToTheDeviceZone() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Civil-date museum")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
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
    let savedSchedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = savedSchedule.identifier.replacingOccurrences(
      of: "saved.item.schedule.", with: "")
    let savedDescription = try XCTUnwrap(savedSchedule.value as? String)
    let day = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
    let dateIdentifier =
      "\(try XCTUnwrap(day.year))-\(try XCTUnwrap(day.month))-\(try XCTUnwrap(day.day))"
    openSection("Calendar", application: application)
    let entry = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.schedule.\(scheduleIdentifier)"
    ).firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    let calendarDescription = try XCTUnwrap(entry.value as? String)
    let overrideIdentifier = chooseDisplayZone(application: application)
    let indicator = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.day.\(dateIdentifier).schedule-count"
    ).firstMatch
    XCTAssertTrue(indicator.waitForExistence(timeout: 10))
    XCTAssertEqual(indicator.label, "1 scheduled entry")
    #if os(macOS)
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = try XCTUnwrap(TimeZone(identifier: overrideIdentifier))
      var originalDay = day
      originalDay.hour = 12
      let originalDate = try XCTUnwrap(calendar.date(from: originalDay))
      var format = Date.FormatStyle().weekday(.wide).month(.wide).day()
      format.calendar = calendar
      format.timeZone = calendar.timeZone
      application.buttons[originalDate.formatted(format)].firstMatch.activateForPlannerJourney()
    #else
      let picker = application.descendants(matching: .any).matching(
        identifier: "saved.calendar.date"
      ).firstMatch
      let date = picker.buttons.containing(.staticText, identifier: String(try XCTUnwrap(day.day)))
        .firstMatch
      XCTAssertTrue(date.waitForExistence(timeout: 5))
      date.activateForPlannerJourney()
    #endif
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertEqual(entry.value as? String, calendarDescription)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "All-day civil date stays fixed across Calendar display zones"
    capture.lifetime = .keepAlways
    add(capture)
    application.plannerElement("saved.calendar.zone.open").activateForPlannerJourney()
    let followsDevice = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.zone.follow-device"
    ).firstMatch
    XCTAssertTrue(followsDevice.waitForPlannerBooleanState(false))
    #if os(macOS)
      followsDevice.activateForPlannerJourney()
    #else
      followsDevice.switches.firstMatch.tap()
    #endif
    XCTAssertTrue(followsDevice.waitForPlannerBooleanState(true))
    application.plannerElement("saved.calendar.zone.done").activateForPlannerJourney()
    application.buttons["Today"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertEqual(entry.value as? String, calendarDescription)
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Calendar", application: application)
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertEqual(entry.value as? String, calendarDescription)
    openSection("Items", application: application)
    let item = application.savedPlannerItemRows("Civil-date museum").firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    item.activateForPlannerJourney()
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(savedSchedule.value as? String, savedDescription)
  }

  func testDisplayZonePersistsWithoutChangingTheSavedStartOnlySchedule() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Travelling museum")
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
    openSection("Calendar", application: application)
    let entry = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.schedule.\(scheduleIdentifier)"
    ).firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    let deviceDescription = try XCTUnwrap(entry.value as? String)
    XCTAssertTrue(deviceDescription.hasPrefix("Start only · "))
    _ = chooseDisplayZone(application: application)
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    let overrideDescription = try XCTUnwrap(entry.value as? String)
    XCTAssertNotEqual(overrideDescription, deviceDescription)
    XCTAssertTrue(overrideDescription.hasPrefix("Start only · "))
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "Native Calendar uses a local display time-zone override"
    capture.lifetime = .keepAlways
    add(capture)
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Calendar", application: application)
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    XCTAssertEqual(entry.value as? String, overrideDescription)
    openSection("Items", application: application)
    let item = application.savedPlannerItemRows("Travelling museum").firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    item.activateForPlannerJourney()
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(savedSchedule.label, "Start only")
    XCTAssertEqual(savedSchedule.value as? String, savedDescription)
  }

  private func chooseDisplayZone(application: XCUIApplication) -> String {
    let zoneControl = application.plannerElement("saved.calendar.zone.open")
    XCTAssertTrue(zoneControl.waitForExistence(timeout: 5))
    zoneControl.activateForPlannerJourney()
    let followsDevice = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.zone.follow-device"
    ).firstMatch
    XCTAssertTrue(followsDevice.waitForPlannerBooleanState(true))
    #if os(macOS)
      followsDevice.activateForPlannerJourney()
    #else
      followsDevice.switches.firstMatch.tap()
    #endif
    XCTAssertTrue(followsDevice.waitForPlannerBooleanState(false), application.debugDescription)
    let chooser = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.zone.choose"
    ).firstMatch
    XCTAssertTrue(chooser.waitForExistence(timeout: 5))
    chooser.activateForPlannerJourney()
    let overrideIdentifier =
      TimeZone.current.identifier == "America/Los_Angeles" ? "Asia/Tokyo" : "America/Los_Angeles"
    let search = application.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.activateForPlannerJourney()
    search.typeText(overrideIdentifier)
    let option = application.plannerElement("saved.schedule.zone.option.\(overrideIdentifier)")
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.activateForPlannerJourney()
    application.plannerElement("saved.calendar.zone.done").activateForPlannerJourney()
    return overrideIdentifier
  }

  private func openSection(_ name: String, application: XCUIApplication) {
    #if os(macOS)
      application.plannerElement("saved.section.\(name.lowercased())").activateForPlannerJourney()
    #else
      application.openPlannerSection(name)
    #endif
  }
}
