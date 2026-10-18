import XCTest

@MainActor
final class SavedItemEstimateJourneyTests: XCTestCase {
  func testEstimateShortcutsStageExactDurationsAndRetainOnlySavedChangesAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Shortcut estimate")
    #if os(iOS)
      title.typeText("\n")
    #endif
    XCTAssertTrue(title.waitForPlannerValue("Shortcut estimate"))
    chooseShortcut("Half-day (12 hours)", prefix: "saved.item.estimate", application: application)
    assertEstimateQuantity(
      "12", unit: "Hours", prefix: "saved.item.estimate", application: application)
    recordEstimateScreenshot(application, name: "Native Half-day shortcut stages twelve hours")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let summary = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    XCTAssertTrue(summary.waitForPlannerValue("720 minutes"))

    openEditor(application)
    chooseShortcut("Full-day (24 hours)", application: application)
    assertEstimateQuantity("1", unit: "Days", application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("720 minutes"))

    for (shortcut, quantity, minutes) in [
      ("Full-day (24 hours)", "1", "1[\\s,]?440 minutes"),
      ("Weekend (48 hours)", "2", "2[\\s,]?880 minutes"),
    ] {
      openEditor(application)
      chooseShortcut(shortcut, application: application)
      assertEstimateQuantity(quantity, unit: "Days", application: application)
      application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
      XCTAssertTrue(waitForEstimateValue(summary, matching: minutes))
    }
    recordEstimateScreenshot(application, name: "Saved Weekend estimate is forty-eight hours")
    openItems(application)
    let source = application.savedPlannerItemRows("Shortcut estimate")
    XCTAssertTrue(source.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(source.count, 1)
    let sourceIdentifier = source.firstMatch.identifier
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    XCTAssertTrue(source.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(source.count, 1)
    XCTAssertEqual(source.firstMatch.identifier, sourceIdentifier)
    source.firstMatch.activateForPlannerJourney()
    XCTAssertTrue(waitForEstimateValue(summary, matching: "2[\\s,]?880 minutes"))
    openEditor(application)
    assertEstimateQuantity("2", unit: "Days", application: application)
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.item.edit.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForPlannerBooleanState(true))
    toggle(enabled)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    XCTAssertTrue(source.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(source.count, 1)
    XCTAssertEqual(source.firstMatch.identifier, sourceIdentifier)
    source.firstMatch.activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
    XCTAssertEqual(
      application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
      ).count, 0)
  }

  private func chooseShortcut(
    _ title: String, prefix: String = "saved.item.edit.estimate", application: XCUIApplication
  ) {
    let shortcuts = application.plannerElement(prefix + ".shortcuts")
    XCTAssertTrue(shortcuts.waitForPlannerHittability())
    shortcuts.activateForPlannerJourney()
    let choice = application.plannerElement(title)
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
  }

  private func assertEstimateQuantity(
    _ quantity: String, unit: String, prefix: String = "saved.item.edit.estimate",
    application: XCUIApplication
  ) {
    let control = application.descendants(matching: .any).matching(
      identifier: prefix + ".quantity"
    ).firstMatch
    XCTAssertTrue(control.waitForPlannerValue(quantity))
    XCTAssertTrue(application.plannerElement(prefix + ".unit").label.contains(unit))
  }

  private func waitForEstimateValue(_ summary: XCUIElement, matching pattern: String) -> Bool {
    let predicate = NSPredicate(format: "value MATCHES %@", pattern)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: summary)], timeout: 5)
      == .completed
  }

  private func openEditor(_ application: XCUIApplication) {
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.item.edit.title"].waitForExistence(timeout: 5))
  }

  private func openItems(_ application: XCUIApplication) {
    #if os(macOS)
      let items = application.plannerElement("saved.section.items")
      XCTAssertTrue(items.waitForExistence(timeout: 5))
      items.activateForPlannerJourney()
    #else
      application.openPlannerSection("Items")
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists && back.isHittable { back.activateForPlannerJourney() }
    #endif
  }

  private func recordEstimateScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testYearEstimateShowsTwelveMonthsFiveDaysAndClearsOnlyAfterSave() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
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
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
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
    openItems(application)
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
    openItems(application)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
  }

  func testInlineEstimatePreservesRemainderThroughUnitChangesCancelSaveAndRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
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
      let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
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
    openItems(application)
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
