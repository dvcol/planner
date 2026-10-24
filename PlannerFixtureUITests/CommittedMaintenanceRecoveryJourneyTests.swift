import XCTest

#if os(iOS)
  @MainActor
  final class CommittedMaintenanceRecoveryJourneyTests: XCTestCase {
    func testLaterNativeInputRetainsRecoveryRetryAndTheOriginalItemAfterRelaunch() {
      continueAfterFailure = false
      let application = launch("maintenance-late-input")
      let museum = application.savedPlannerItemRows("Maintenance museum").firstMatch
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      let museumIdentifier = museum.identifier
      XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
      openRecoveryStatus(in: application)
      let status = application.staticTexts["saved.recovery.status"]
      XCTAssertEqual(status.label, "Recovery copy incomplete")
      let retry = application.plannerElement("saved.recovery.retry")
      XCTAssertTrue(retry.waitForExistence(timeout: 10))
      XCTAssertTrue(retry.isEnabled)
      capture("Later native input retains committed recovery Retry after relaunch")
      retry.activateForPlannerJourney()
      let saved = XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Saved on this device"), object: status)
        ], timeout: 15)
      capture("Native recovery result after Retry with later input")
      XCTAssertEqual(saved, .completed, application.debugDescription)
      XCTAssertFalse(retry.exists)
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      let restored = application.plannerElement(museumIdentifier)
      XCTAssertTrue(restored.waitForExistence(timeout: 15))
      XCTAssertEqual(application.savedPlannerItemRows("Maintenance museum").count, 1)
      XCTAssertTrue(application.plannerElement("saved.item.addMenu").isEnabled)
      restored.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep the original maintenance note"].waitForExistence(
          timeout: 10))
      application.beginPlannerListCreation()
      let name = application.textFields["saved.list.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 10))
      name.activateForPlannerJourney()
      name.typeText("After later input")
      application.plannerElement("saved.list.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(museumIdentifier).waitForExistence(timeout: 15))
      XCTAssertEqual(application.savedPlannerItemRows("Maintenance museum").count, 1)
      XCTAssertFalse(application.plannerElement("saved.recovery.status.open").exists)
      application.plannerElement(museumIdentifier).activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep the original maintenance note"].waitForExistence(
          timeout: 10))
      capture("Recovered later input preserves the original Item after another save and relaunch")
      application.terminate()
    }

    func testCommittedMaintenanceRetriesAfterRelaunchWithoutRepeatingTheSavedData() {
      continueAfterFailure = false
      let application = launch("committed-maintenance-recovery")
      let museum = application.savedPlannerItemRows("Maintenance museum").firstMatch
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      let museumIdentifier = museum.identifier
      XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(museumIdentifier).waitForExistence(timeout: 15))
      openRecoveryStatus(in: application)
      let status = application.staticTexts["saved.recovery.status"]
      XCTAssertTrue(status.waitForExistence(timeout: 10))
      XCTAssertEqual(status.label, "Recovery copy incomplete")
      let retry = application.plannerElement("saved.recovery.retry")
      XCTAssertTrue(retry.waitForExistence(timeout: 10), application.debugDescription)
      XCTAssertTrue(retry.isEnabled)
      capture("Committed maintenance offers native recovery Retry after relaunch")
      retry.activateForPlannerJourney()
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "label == %@", "Saved on this device"), object: status)
          ],
          timeout: 15), .completed)
      XCTAssertFalse(retry.exists)
      capture("Maintenance recovery completes without repeating the pending user command")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.item.addMenu").isEnabled)
      XCTAssertEqual(application.savedPlannerItemRows("Maintenance museum").count, 1)
      application.beginPlannerListCreation()
      let name = application.textFields["saved.list.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 10))
      name.activateForPlannerJourney()
      name.typeText("After maintenance")
      application.plannerElement("saved.list.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(museumIdentifier).waitForExistence(timeout: 15))
      XCTAssertEqual(application.savedPlannerItemRows("Maintenance museum").count, 1)
      XCTAssertFalse(application.plannerElement("saved.recovery.status.open").exists)
      application.plannerElement(museumIdentifier).activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep the original maintenance note"].waitForExistence(
          timeout: 10))
      capture("A later native save and relaunch retain the original Item and note")
      application.terminate()
    }

    func testMaintenanceRetryFailureKeepsTheSavedDataReadableAndChangesBlocked() {
      continueAfterFailure = false
      let application = launch("maintenance-retry-failure")
      let museum = application.savedPlannerItemRows("Maintenance museum").firstMatch
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      let museumIdentifier = museum.identifier
      XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
      openRecoveryStatus(in: application)
      let retry = application.plannerElement("saved.recovery.retry")
      XCTAssertTrue(retry.waitForExistence(timeout: 10))
      retry.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.recovery.failure"].waitForExistence(timeout: 15))
      XCTAssertEqual(
        application.staticTexts["saved.recovery.status"].label,
        "Recovery copy incomplete")
      XCTAssertTrue(retry.isEnabled)
      capture("A real recovery write error leaves maintenance Retry available")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(museumIdentifier).waitForExistence(timeout: 15))
      XCTAssertEqual(application.savedPlannerItemRows("Maintenance museum").count, 1)
      XCTAssertTrue(application.plannerElement("saved.recovery.status.open").exists)
      XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
      application.plannerElement(museumIdentifier).activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep the original maintenance note"].waitForExistence(
          timeout: 10))
      capture("An unsuccessful maintenance Retry preserves saved content after relaunch")
      application.terminate()
    }

    private func openRecoveryStatus(in application: XCUIApplication) {
      if let sidebar = application.buttons.matching(
        NSPredicate(format: "label == %@", "Hide Sidebar")
      ).allElementsBoundByIndex.first(where: \.isHittable) {
        sidebar.activateForPlannerJourney()
      }
      let recovery = application.plannerElement("saved.recovery.status.open")
      XCTAssertTrue(recovery.waitForPlannerHittability())
      recovery.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.recovery.status"].waitForExistence(timeout: 10))
    }

    private func launch(_ fixture: String) -> XCUIApplication {
      let application = XCUIApplication()
      let identifier = UUID().uuidString
      let input = XCTAttachment(string: "Fixture: \(fixture)\nDataset: \(identifier)")
      input.name = "Committed maintenance fixture input"
      input.lifetime = .keepAlways
      add(input)
      application.launchArguments = [
        "--fixture", fixture, "--fixture-dataset", identifier,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      return application
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
