import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class SavedCalendarInspectorJourneyTests: XCTestCase {
  func testCalendarDetailsCanHideAndReopenWithoutChangingTheSelectedSchedule() throws {
    #if os(iOS)
      guard UIDevice.current.userInterfaceIdiom == .pad else {
        throw XCTSkip("This journey qualifies the regular-width Calendar inspector.")
      }
    #endif
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Items", in: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
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
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = schedule.identifier
    let scheduleDescription = try XCTUnwrap(schedule.value as? String)
    openSection("Calendar", in: application)
    let entry = application.descendants(matching: .any).matching(
      identifier: scheduleIdentifier.replacingOccurrences(
        of: "saved.item.schedule.", with: "saved.calendar.schedule.")
    ).firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    entry.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 10))
    let details = application.plannerElement("saved.calendar.details.toggle")
    XCTAssertTrue(details.waitForExistence(timeout: 5))
    let calendar = application.descendants(matching: .any).matching(
      identifier: "saved.calendar.canvas"
    ).firstMatch
    XCTAssertTrue(calendar.exists)
    let widthWithDetails = entry.frame.width
    XCTAssertGreaterThan(widthWithDetails, 0)
    let initialScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    initialScreenshot.name = "Native Calendar inspector presentation before closing"
    initialScreenshot.lifetime = .keepAlways
    add(initialScreenshot)
    XCTAssertEqual(schedule.identifier, scheduleIdentifier)
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForNonExistence(timeout: 5))
    let layout = XCTAttachment(
      string:
        "Entry width with details: \(widthWithDetails)\nEntry width after hiding: \(entry.frame.width)\n"
    )
    layout.name = "Calendar inspector layout observations"
    layout.lifetime = .keepAlways
    add(layout)
    XCTAssertEqual(details.label, "Show Details")
    XCTAssertTrue(details.waitForPlannerHittability())
    XCTAssertTrue(entry.isHittable)
    let wideScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    wideScreenshot.name = "Calendar uses the main width with its inspector hidden"
    wideScreenshot.lifetime = .keepAlways
    add(wideScreenshot)
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.identifier, scheduleIdentifier)
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    details.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForNonExistence(timeout: 5))
    entry.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["The same saved Item"].waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.value as? String, scheduleDescription)
    let selectedScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    selectedScreenshot.name = "Calendar inspector retains the selected Schedule and Item"
    selectedScreenshot.lifetime = .keepAlways
    add(selectedScreenshot)
  }

  private func openSection(_ name: String, in application: XCUIApplication) {
    #if os(macOS)
      application.plannerElement("saved.section.\(name.lowercased())").activateForPlannerJourney()
    #else
      application.openPlannerSection(name)
    #endif
  }
}
