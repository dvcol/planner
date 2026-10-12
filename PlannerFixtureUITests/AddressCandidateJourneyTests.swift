import XCTest

@MainActor
final class AddressCandidateJourneyTests: XCTestCase {
  func testEmptyAddressRetryKeepsOwnedLocationAfterRelaunch() {
    continueAfterFailure = false
    let application = launchFixture()
    let row = application.savedPlannerItemRows("Unmatched place").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let identifier = row.identifier
    row.activateForPlannerJourney()
    let empty = application.staticTexts["No matching places"]
    XCTAssertTrue(empty.waitForExistence(timeout: 5))
    XCTAssertFalse(previewMap(application).exists)
    assertOwnedLocation("Fixture no matches", application: application)
    let retry = application.plannerElement("Retry")
    reveal(retry, application: application)
    XCTAssertTrue(retry.isEnabled)
    capture(application, name: "Controlled empty address keeps the owned location")
    for _ in 0..<2 {
      retry.activateForPlannerJourney()
      XCTAssertTrue(empty.waitForExistence(timeout: 5))
      XCTAssertFalse(previewMap(application).exists)
      XCTAssertTrue(retry.isEnabled)
    }
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    XCTAssertEqual(row.identifier, identifier)
    row.activateForPlannerJourney()
    XCTAssertTrue(empty.waitForExistence(timeout: 5))
    assertOwnedLocation("Fixture no matches", application: application)
  }

  func testAmbiguousCandidatesStayTemporaryAndRequireExplicitSelection() {
    continueAfterFailure = false
    let application = launchFixture()
    let row = application.savedPlannerItemRows("Ambiguous place").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let identifier = row.identifier
    row.activateForPlannerJourney()
    let picker = candidatePicker(application)
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    let map = previewMap(application)
    XCTAssertFalse(map.exists)
    assertOwnedLocation("Fixture multiple matches", application: application)
    choose("North entrance, 1 Fixture Way", picker: picker, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(
      map.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", "North entrance")
      ).firstMatch.waitForExistence(timeout: 10))
    reveal(map, application: application)
    capture(application, name: "Explicit North candidate paints its temporary map pin")
    choose("Choose a place", picker: picker, application: application)
    XCTAssertTrue(map.waitForNonExistence(timeout: 5))
    choose("South entrance, 2 Fixture Way", picker: picker, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(
      map.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", "South entrance")
      ).firstMatch.waitForExistence(timeout: 10))
    reveal(map, application: application)
    capture(application, name: "Explicit South candidate replaces the temporary map pin")
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    assertUnchangedLocationEditor("Fixture multiple matches", application: application)
    capture(application, name: "Preview selection does not save candidate coordinates or text")
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    XCTAssertEqual(row.identifier, identifier)
    row.activateForPlannerJourney()
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    XCTAssertFalse(map.exists)
    assertOwnedLocation("Fixture multiple matches", application: application)
  }

  func testAddressFailureRecoversOneTemporaryPinAndPreservesOwnedLocationAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "address-retry", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Retry place").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let identifier = row.identifier
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Saved location"].waitForExistence(timeout: 5))
    assertOwnedLocation("Fixture retry address", application: application)
    let failure = application.staticTexts["Address preview unavailable"]
    XCTAssertTrue(failure.waitForExistence(timeout: 5))
    let map = previewMap(application)
    XCTAssertFalse(map.exists)
    XCTAssertFalse(candidatePicker(application).exists)
    let retry = application.plannerElement("Retry")
    reveal(retry, application: application)
    XCTAssertTrue(retry.isEnabled)
    capture(application, name: "Controlled address failure keeps its owned location")
    retry.activateForPlannerJourney()
    XCTAssertTrue(failure.waitForNonExistence(timeout: 5))
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(
      map.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", "Recovered entrance")
      ).firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(candidatePicker(application).exists)
    XCTAssertFalse(retry.exists)
    reveal(map, application: application)
    capture(application, name: "Controlled address Retry renders its sole temporary pin")
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    assertUnchangedLocationEditor("Fixture retry address", application: application)
    capture(application, name: "Recovered candidate leaves the owned editor unchanged")
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    XCTAssertEqual(row.identifier, identifier)
    row.activateForPlannerJourney()
    XCTAssertTrue(failure.waitForExistence(timeout: 5))
    XCTAssertFalse(map.exists)
    XCTAssertFalse(candidatePicker(application).exists)
    assertOwnedLocation("Fixture retry address", application: application)
  }

  func testDelayedAddressResultCannotReplaceTheEditedAddressPreview() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "address-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Delayed place").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let identifier = row.identifier
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Saved location"].waitForExistence(timeout: 5))
    assertOwnedLocation("Fixture delayed address", application: application)
    let loading = application.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Finding address")
    ).firstMatch
    XCTAssertTrue(loading.waitForExistence(timeout: 5))
    let map = previewMap(application)
    XCTAssertFalse(map.exists)
    capture(application, name: "Controlled address lookup stays pending before editing")
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    let address = application.textFields["saved.item.edit.location.address"]
    reveal(address, application: application)
    let originalValue = address.value as? String ?? ""
    address.activateForPlannerJourney()
    address.typeText(
      String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalValue.count)
        + "Fixture current address")
    XCTAssertTrue(address.waitForPlannerValue("Fixture current address"))
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Fixture current address"].waitForExistence(timeout: 5))
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    let currentPin = map.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Current entrance")
    ).firstMatch
    XCTAssertTrue(currentPin.waitForExistence(timeout: 10))
    let outdatedPin = map.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Outdated entrance")
    ).firstMatch
    XCTAssertFalse(outdatedPin.exists)
    XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["Fixture delayed address"].exists)
    reveal(map, application: application)
    capture(application, name: "Current address pin survives the released outdated result")
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    assertUnchangedLocationEditor("Fixture current address", application: application)
    capture(application, name: "Only the explicit address edit is saved")
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(currentPin.waitForExistence(timeout: 5))
    XCTAssertFalse(outdatedPin.exists)
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    XCTAssertEqual(row.identifier, identifier)
    row.activateForPlannerJourney()
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(
      map.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", "Reopened entrance")
      ).firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(outdatedPin.exists)
    assertOwnedLocation("Fixture current address", application: application)
  }

  private func assertUnchangedLocationEditor(
    _ expectedAddress: String, application: XCUIApplication
  ) {
    let addressField = application.textFields["saved.item.edit.location.address"]
    reveal(addressField, application: application)
    XCTAssertTrue(addressField.waitForPlannerValue(expectedAddress))
    XCTAssertTrue(
      application.textFields["saved.item.edit.location.name"].waitForPlannerValue("Saved location"))
    XCTAssertFalse(
      application.descendants(matching: .any).matching(identifier: "saved.item.edit.location.pin")
        .firstMatch.exists)
    XCTAssertFalse(application.plannerElement("saved.item.edit.save").isEnabled)
  }

  private func launchFixture() -> XCUIApplication {
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "address-candidates", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    return application
  }

  private func candidatePicker(_ application: XCUIApplication) -> XCUIElement {
    #if os(macOS)
      let controls = application.popUpButtons
    #else
      let controls = application.buttons
    #endif
    return controls.matching(NSPredicate(format: "label CONTAINS %@", "Matching places")).firstMatch
  }

  private func previewMap(_ application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any).matching(identifier: "saved.item.location.preview.map")
      .firstMatch
  }

  private func choose(_ choice: String, picker: XCUIElement, application: XCUIApplication) {
    reveal(picker, application: application)
    picker.activateForPlannerJourney()
    let option = application.plannerElement(choice)
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.activateForPlannerJourney()
  }

  private func assertOwnedLocation(_ address: String, application: XCUIApplication) {
    XCTAssertTrue(application.staticTexts["Saved location"].exists)
    XCTAssertTrue(application.staticTexts[address].exists)
    XCTAssertTrue(application.staticTexts["Original notes"].exists)
    let completion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
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
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    XCTAssertTrue(
      element.isHittable && application.windows.firstMatch.frame.contains(element.frame))
  }

  private func capture(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
