import XCTest

@MainActor
final class PinnedAddressEditJourneyTests: XCTestCase {
  func testOpeningPinnedItemWithEmptyNameKeepsSaveDisabledUntilNotesChange() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--fixture", "pinned-empty-name"]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20), application.debugDescription)
    row.activateForPlannerJourney()
    openEditor(application)
    let save = application.plannerElement("saved.item.edit.save")
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    XCTAssertFalse(save.isEnabled, "Opening the editor must not change an untouched empty name.")
    let notes = application.textFields["saved.item.edit.notes"]
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    notes.activateForPlannerJourney()
    notes.typeText("Updated notes")
    XCTAssertTrue(save.isEnabled)
    save.activateForPlannerJourney()
    let savedNotes = application.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "Updated notes")
    ).firstMatch
    XCTAssertTrue(savedNotes.waitForExistence(timeout: 5))
    openEditor(application)
    XCTAssertFalse(save.isEnabled)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "map.location").firstMatch.exists
    )
  }

  func testPinnedAddressKeepsOrRemovesPinOnlyAfterSaveAndSurvivesRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "pinned-address", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20), application.debugDescription)
    let identity = row.identifier
    row.activateForPlannerJourney()
    let map = application.descendants(matching: .any).matching(identifier: "map.location")
      .firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    openEditor(application)
    let pin = application.descendants(matching: .any).matching(
      identifier: "saved.item.edit.location.pin"
    ).firstMatch
    chooseRemove(pin, application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(map.waitForExistence(timeout: 5))
    openEditor(application)
    let name = application.textFields["saved.item.edit.location.name"]
    let address = application.textFields["saved.item.edit.location.address"]
    reveal(name, application: application)
    replace(name, with: "Updated entrance")
    replace(address, with: "Updated address")
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Updated entrance"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.staticTexts["Updated address"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(map.exists)
    openEditor(application)
    chooseRemove(pin, application: application)
    let capture = XCTAttachment(screenshot: application.screenshot())
    capture.name = "Pin removal is staged alongside editable address fields"
    capture.lifetime = .keepAlways
    add(capture)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: map)
        ],
        timeout: 5) == .completed)
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(row.identifier, identity)
    row.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Updated entrance"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.staticTexts["Updated address"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Original notes"].exists)
    XCTAssertFalse(map.exists)
  }

  private func openEditor(_ application: XCUIApplication) {
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
  }

  private func chooseRemove(_ pin: XCUIElement, application: XCUIApplication) {
    reveal(pin, application: application)
    pin.activateForPlannerJourney()
    let remove = application.plannerElement("Remove saved pin")
    XCTAssertTrue(remove.waitForExistence(timeout: 5), application.debugDescription)
    remove.activateForPlannerJourney()
  }

  private func reveal(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<6 {
      if element.exists && element.isHittable
        && application.windows.firstMatch.frame.contains(element.frame)
      {
        break
      }
      application.swipeUp()
    }
    XCTAssertTrue(element.waitForExistence(timeout: 5), application.debugDescription)
    XCTAssertTrue(
      element.isHittable && application.windows.firstMatch.frame.contains(element.frame))
  }

  private func replace(_ field: XCUIElement, with value: String) {
    field.activateForPlannerJourney()
    let existing = field.value as? String ?? ""
    field.typeText(
      String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + value)
  }
}
