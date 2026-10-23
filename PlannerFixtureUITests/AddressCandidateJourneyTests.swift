import XCTest

@MainActor
final class AddressCandidateJourneyTests: XCTestCase {
  func testCollectionMapChoicesStayTemporaryAndCanBeChanged() {
    continueAfterFailure = false
    let application = launchFixture()
    let row = application.savedPlannerItemRows("Ambiguous place").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let sourceIdentifier = row.identifier
    application.openSavedPlannerCatalogViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let locations = application.plannerElement("saved.map.locations")
    XCTAssertTrue(locations.waitForExistence(timeout: 10))
    locations.activateForPlannerJourney()
    let choice = application.buttons.matching(
      NSPredicate(format: "label == %@", "Ambiguous place")
    ).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    XCTAssertTrue(choice.waitForPlannerValue("Choose a place"))
    let options = application.buttons.matching(
      NSPredicate(format: "label == %@", "Location options for Ambiguous place")
    ).firstMatch
    XCTAssertTrue(options.waitForExistence(timeout: 5))
    options.activateForPlannerJourney()
    let matching = candidatePicker(application)
    XCTAssertTrue(matching.waitForExistence(timeout: 5))
    matching.activateForPlannerJourney()
    application.plannerElement("North entrance, 1 Fixture Way").activateForPlannerJourney()
    XCTAssertTrue(choice.waitForPlannerValue("Location available"))
    application.plannerElement("Close").activateForPlannerJourney()
    let north = application.buttons["saved.map.pin.35.662,139.717"]
    XCTAssertTrue(north.waitForExistence(timeout: 10))
    capture(application, name: "Collection Map uses the explicit temporary North choice")
    locations.activateForPlannerJourney()
    options.activateForPlannerJourney()
    matching.activateForPlannerJourney()
    application.plannerElement("South entrance, 2 Fixture Way").activateForPlannerJourney()
    application.plannerElement("Close").activateForPlannerJourney()
    XCTAssertTrue(application.buttons["saved.map.pin.35.655,139.717"].waitForExistence(timeout: 10))
    XCTAssertFalse(north.exists)
    capture(
      application, name: "Collection Map changes the same source to the temporary South choice")
    application.openSavedPlannerCatalogViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("List")
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(row.identifier, sourceIdentifier)
    row.activateForPlannerJourney()
    assertOwnedLocation("Fixture multiple matches", application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
    assertUnchangedLocationEditor("Fixture multiple matches", application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    XCTAssertEqual(row.identifier, sourceIdentifier)
    application.openSavedPlannerCatalogViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    locations.activateForPlannerJourney()
    XCTAssertTrue(choice.waitForPlannerValue("Choose a place"))
    XCTAssertFalse(application.buttons["saved.map.pin.35.655,139.717"].exists)
  }

  func testRepeatedMapAppearancesKeepIndependentTemporaryAddressChoices() {
    continueAfterFailure = false
    let application = launchFixture()
    application.openPlannerSection("Itineraries")
    let route = application.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.",
        "Ambiguous route")
    ).firstMatch
    XCTAssertTrue(route.waitForExistence(timeout: 10))
    let routeIdentifier = route.identifier
    route.activateForPlannerJourney()
    application.openSavedPlannerItineraryViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let locations = application.plannerElement("saved.map.locations")
    XCTAssertTrue(locations.waitForExistence(timeout: 10))
    locations.activateForPlannerJourney()
    let first = application.buttons["Ambiguous place · Stop 1"].firstMatch
    let second = application.buttons["Ambiguous place · Stop 2"].firstMatch
    XCTAssertTrue(first.waitForExistence(timeout: 10))
    XCTAssertTrue(second.exists)
    let firstIdentifier = first.identifier
    let secondIdentifier = second.identifier
    XCTAssertNotEqual(firstIdentifier, secondIdentifier)
    XCTAssertTrue(first.waitForPlannerValue("Choose a place"))
    XCTAssertTrue(second.waitForPlannerValue("Choose a place"))
    chooseMapPlace("South entrance, 2 Fixture Way", row: first, application: application)
    XCTAssertTrue(first.waitForPlannerValue("Location available"))
    XCTAssertTrue(second.waitForPlannerValue("Choose a place"))
    application.plannerElement("Close").activateForPlannerJourney()
    let south = application.buttons["saved.map.pin.35.655,139.717"]
    let north = application.buttons["saved.map.pin.35.662,139.717"]
    XCTAssertTrue(south.waitForExistence(timeout: 10))
    XCTAssertFalse(north.exists)
    locations.activateForPlannerJourney()
    XCTAssertEqual(first.identifier, firstIdentifier)
    XCTAssertEqual(second.identifier, secondIdentifier)
    chooseMapPlace("North entrance, 1 Fixture Way", row: second, application: application)
    application.plannerElement("Close").activateForPlannerJourney()
    XCTAssertTrue(north.waitForExistence(timeout: 10))
    XCTAssertTrue(south.exists)
    XCTAssertTrue(application.staticTexts["2 of 2 items located"].exists)
    capture(application, name: "Repeated Map appearances keep independent temporary place choices")
    locations.activateForPlannerJourney()
    chooseMapPlace("North entrance, 1 Fixture Way", row: first, application: application)
    application.plannerElement("Close").activateForPlannerJourney()
    XCTAssertTrue(north.waitForExistence(timeout: 10))
    XCTAssertEqual(north.label, "2 items")
    XCTAssertTrue(south.waitForNonExistence(timeout: 5))
    capture(application, name: "Repeated Map appearances can share the same chosen place")
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Itineraries")
    XCTAssertTrue(route.waitForExistence(timeout: 20))
    XCTAssertEqual(route.identifier, routeIdentifier)
    route.activateForPlannerJourney()
    application.openSavedPlannerItineraryViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    locations.activateForPlannerJourney()
    XCTAssertTrue(first.waitForPlannerValue("Choose a place"))
    XCTAssertTrue(second.waitForPlannerValue("Choose a place"))
    XCTAssertEqual(first.identifier, firstIdentifier)
    XCTAssertEqual(second.identifier, secondIdentifier)
  }

  private func chooseMapPlace(_ title: String, row: XCUIElement, application: XCUIApplication) {
    let optionsIdentifier = row.identifier.replacingOccurrences(
      of: "saved.map.location.", with: "saved.map.location.options.")
    let options = application.plannerElement(optionsIdentifier)
    XCTAssertTrue(options.waitForExistence(timeout: 5))
    options.activateForPlannerJourney()
    let picker = candidatePicker(application)
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.activateForPlannerJourney()
    let place = application.plannerElement(title)
    XCTAssertTrue(place.waitForExistence(timeout: 5))
    place.activateForPlannerJourney()
  }

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
    application.plannerElement("Edit item").activateForPlannerJourney()
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
    application.plannerElement("Edit item").activateForPlannerJourney()
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
    application.plannerElement("Edit item").activateForPlannerJourney()
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
    application.plannerElement("Edit item").activateForPlannerJourney()
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
