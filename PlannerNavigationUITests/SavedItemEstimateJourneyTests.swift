import XCTest

@MainActor
final class SavedItemEstimateJourneyTests: XCTestCase {
  func testYearEstimateShowsTwelveMonthsFiveDaysAndClearsOnlyAfterSave() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Year estimate")
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForExistence(timeout: 5))
    toggle(enabled)
    chooseUnit("Years", application: application, prefix: "saved.item.estimate")
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("0"))
    increment(quantity)
    let hourRemainder = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.remainder.hour"
    ).firstMatch
    XCTAssertTrue(hourRemainder.waitForPlannerValue("1"))
    let decrement = hourRemainder.buttons.matching(
      NSPredicate(format: "identifier ENDSWITH %@", "-Decrement")
    ).firstMatch
    XCTAssertTrue(decrement.waitForExistence(timeout: 5))
    decrement.activateForPlannerJourney()
    chooseUnit("Months", application: application, prefix: "saved.item.estimate")
    XCTAssertTrue(quantity.waitForPlannerValue("12"))
    let dayRemainder = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.remainder.day"
    ).firstMatch
    XCTAssertTrue(dayRemainder.waitForPlannerValue("5"))
    let capture = XCTAttachment(screenshot: application.screenshot())
    capture.name = "One year retains twelve months and five days"
    capture.lifetime = .keepAlways
    add(capture)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let summary = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    XCTAssertTrue(waitForYearEstimate(summary), summary.debugDescription)
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Year estimate").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertTrue((row.value as? String)?.contains("12 months · 5 days") == true)
    row.activateForPlannerJourney()
    XCTAssertTrue(waitForYearEstimate(summary))
    for shouldSave in [false, true] {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Edit Item").activateForPlannerJourney()
      let unit = application.plannerElement("saved.item.edit.estimate.unit")
      XCTAssertTrue(unit.waitForExistence(timeout: 5))
      XCTAssertTrue(unit.label.contains("Months"))
      let enabled = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.enabled"
      ).firstMatch
      XCTAssertTrue(enabled.waitForPlannerBooleanState(true))
      toggle(enabled)
      let action = shouldSave ? "saved.item.edit.save" : "saved.item.edit.cancel"
      application.plannerElement(action).activateForPlannerJourney()
      if shouldSave {
        XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
      } else {
        XCTAssertTrue(waitForYearEstimate(summary))
      }
    }
    let schedules = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    XCTAssertEqual(schedules.count, 0)
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
  }

  func testInlineEstimatePreservesRemainderThroughUnitChangesCancelSaveAndRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Estimated museum")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the booking notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    for shouldSave in [false, true] {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Edit Item").activateForPlannerJourney()
      let enabled = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.enabled"
      ).firstMatch
      XCTAssertTrue(enabled.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertTrue(enabled.waitForPlannerBooleanState(false))
      toggle(enabled)
      let quantity = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.quantity"
      ).firstMatch
      XCTAssertTrue(quantity.waitForPlannerValue("1"), application.debugDescription)
      increment(quantity)
      XCTAssertTrue(quantity.waitForPlannerValue("2"))
      chooseUnit("Minutes", application: application)
      XCTAssertTrue(quantity.waitForPlannerValue("120"))
      for _ in 0..<5 { increment(quantity) }
      XCTAssertTrue(quantity.waitForPlannerValue("125"))
      chooseUnit("Hours", application: application)
      XCTAssertTrue(quantity.waitForPlannerValue("2"))
      let remainder = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.remainder.minute"
      ).firstMatch
      XCTAssertTrue(remainder.waitForPlannerValue("5"))
      let capture = XCTAttachment(screenshot: application.screenshot())
      capture.name = "Native inline estimate retains two hours and five minutes"
      capture.lifetime = .keepAlways
      add(capture)
      let action = shouldSave ? "saved.item.edit.save" : "saved.item.edit.cancel"
      application.plannerElement(action).activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
      let summary = application.descendants(matching: .any).matching(
        identifier: "saved.item.estimate"
      ).firstMatch
      XCTAssertTrue(summary.waitForPlannerValue(shouldSave ? "125 minutes" : "No estimate"))
      XCTAssertTrue(application.staticTexts["Keep the booking notes"].exists)
    }
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Estimated museum").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    let summary = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    XCTAssertTrue(summary.waitForPlannerValue("125 minutes"))
    XCTAssertTrue(application.staticTexts["Keep the booking notes"].exists)
  }

  private func chooseUnit(
    _ title: String, application: XCUIApplication, prefix: String = "saved.item.edit.estimate"
  ) {
    let unit = application.plannerElement(prefix + ".unit")
    XCTAssertTrue(unit.waitForExistence(timeout: 5))
    unit.activateForPlannerJourney()
    application.plannerElement(title).activateForPlannerJourney()
  }

  private func toggle(_ enabled: XCUIElement) {
    #if os(iOS)
      enabled.switches.firstMatch.activateForPlannerJourney()
    #else
      enabled.activateForPlannerJourney()
    #endif
  }

  private func increment(_ quantity: XCUIElement) {
    let button = quantity.buttons.matching(
      NSPredicate(format: "identifier ENDSWITH %@", "-Increment")
    ).firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 5), quantity.debugDescription)
    button.activateForPlannerJourney()
  }

  private func waitForYearEstimate(_ summary: XCUIElement) -> Bool {
    let predicate = NSPredicate(format: "value MATCHES %@", "525\\D?600 minutes")
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: summary)], timeout: 5)
      == .completed
  }
}
