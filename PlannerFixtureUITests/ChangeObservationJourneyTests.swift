import XCTest

@MainActor
final class ChangeObservationJourneyTests: XCTestCase {
  func testAnIndependentWriterMovesTheOpenCollectionMapPinWithoutChangingItsSource() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 20))
    let sourceIdentifier = source.identifier
    application.openSavedPlannerCatalogViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let original = application.buttons["saved.map.pin.35.662,139.717"]
    XCTAssertTrue(original.waitForExistence(timeout: 10))
    performFixtureAction(
      "fixture.writer.moveHotel", expecting: "Saved another-writer location", in: application)
    XCTAssertTrue(
      application.buttons["saved.map.pin.35.655,139.717"].waitForExistence(timeout: 15))
    XCTAssertTrue(original.waitForNonExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Independent writer refreshes the open collection Map"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.openSavedPlannerCatalogViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("List")
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertEqual(source.identifier, sourceIdentifier)
  }

  func testAChangedBindingOffersValidatedReconnectionWithoutReplacingTheDraft() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let origin = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(origin.waitForExistence(timeout: 20))
    origin.activateForPlannerJourney()
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.createItem").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    let notes = application.textFields["saved.item.notes"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    title.activateForPlannerJourney()
    title.typeText("Connection draft")
    notes.activateForPlannerJourney()
    notes.typeText("Retain connection notes")
    let save = application.plannerElement("saved.item.save")
    XCTAssertTrue(save.isEnabled)
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.changeBinding").activateForPlannerJourney()
    let legacyAlert = application.alerts.firstMatch
    if legacyAlert.waitForExistence(timeout: 2) {
      legacyAlert.buttons["OK"].activateForPlannerJourney()
    }
    let reconnect = application.plannerElement("saved.changes.retry")
    XCTAssertTrue(reconnect.waitForExistence(timeout: 15))
    XCTAssertFalse(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Connection draft")
    XCTAssertEqual(notes.value as? String, "Retain connection notes")
    performFixtureAction(
      "fixture.writer.restoreBinding", expecting: "Dataset binding restored", in: application)
    reconnect.activateForPlannerJourney()
    XCTAssertTrue(reconnect.waitForNonExistence(timeout: 15))
    XCTAssertTrue(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Connection draft")
    XCTAssertEqual(notes.value as? String, "Retain connection notes")
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Validated reconnection preserves the edited draft"
    attachment.lifetime = .keepAlways
    add(attachment)
    save.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Retain connection notes"].waitForExistence(timeout: 15))
  }

  func testRecoveryOnlyDamageAndRepairPreserveAnEditedDraftAndItsListDestination() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let origin = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(origin.waitForExistence(timeout: 20))
    let originIdentifier = origin.identifier
    origin.activateForPlannerJourney()
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.createItem").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    let notes = application.textFields["saved.item.notes"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    title.activateForPlannerJourney()
    title.typeText("Unsaved visit")
    XCTAssertTrue(notes.waitForExistence(timeout: 10))
    notes.activateForPlannerJourney()
    notes.typeText("Keep this draft")
    let save = application.plannerElement("saved.item.save")
    XCTAssertTrue(save.isEnabled)
    performFixtureAction(
      "fixture.writer.update", expecting: "Saved another-writer change", in: application)
    XCTAssertEqual(title.value as? String, "Unsaved visit")
    XCTAssertEqual(notes.value as? String, "Keep this draft")
    XCTAssertFalse(application.alerts.firstMatch.exists)
    performFixtureAction(
      "fixture.writer.damageRecovery", expecting: "Recovery checkpoint damaged", in: application)
    let recovery = application.plannerElement("saved.recovery.status.open")
    XCTAssertTrue(recovery.waitForExistence(timeout: 15))
    XCTAssertFalse(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Unsaved visit")
    XCTAssertEqual(notes.value as? String, "Keep this draft")
    let damaged = XCTAttachment(screenshot: application.screenshot())
    damaged.name = "Independent recovery damage preserves the edited draft"
    damaged.lifetime = .keepAlways
    add(damaged)
    performFixtureAction(
      "fixture.writer.repairRecovery", expecting: "Recovery checkpoint repaired", in: application)
    XCTAssertTrue(recovery.waitForNonExistence(timeout: 15))
    XCTAssertTrue(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Unsaved visit")
    XCTAssertEqual(notes.value as? String, "Keep this draft")
    let destination = application.descendants(matching: .any)
      .matching(identifier: "saved.item.destination").firstMatch
    XCTAssertTrue(
      destination.label.contains("Weekend") || (destination.value as? String) == "Weekend"
        || destination.staticTexts["Weekend"].exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Independent recovery repair preserves the edited draft"
    attachment.lifetime = .keepAlways
    add(attachment)
    save.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep this draft"].waitForExistence(timeout: 15))
    application.openPlannerSection("Lists")
    let savedOrigin = application.plannerElement(originIdentifier)
    if savedOrigin.exists && savedOrigin.isHittable { savedOrigin.activateForPlannerJourney() }
    let saved = application.buttons.matching(NSPredicate(format: "label == %@", "Unsaved visit"))
      .firstMatch
    if !saved.isHittable { application.plannerElement("BackButton").activateForPlannerJourney() }
    XCTAssertTrue(saved.waitForExistence(timeout: 10))
  }

  private func performFixtureAction(
    _ identifier: String, expecting status: String, in application: XCUIApplication
  ) {
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement(identifier).activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", status),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
  }

  func testAnIndependentWriterRefreshesTheSelectedItemWithoutNavigation() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let original = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(original.waitForExistence(timeout: 20))
    let sourceIdentifier = original.identifier
    original.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.update").activateForPlannerJourney()
    let status = application.staticTexts["fixture.writer.status"]
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Saved another-writer change"),
            object: status)
        ], timeout: 10), .completed)
    XCTAssertTrue(application.staticTexts["Other writer notes"].waitForExistence(timeout: 15))
    XCTAssertFalse(application.staticTexts["Original notes"].exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Independent writer refreshes the selected Item"
    attachment.lifetime = .keepAlways
    add(attachment)
    let updated = application.savedPlannerItemRows("Hotel updated").firstMatch
    if !updated.isHittable {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }
    XCTAssertTrue(updated.waitForExistence(timeout: 10))
    XCTAssertEqual(updated.identifier, sourceIdentifier)
  }
}
