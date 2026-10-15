import XCTest

#if os(iOS)
  @MainActor
  final class RecoveryCheckpointJourneyTests: XCTestCase {
    func testUnavailableRecoveryEvidenceBlocksChangesAndAllowsReadingAfterRecheck() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "unavailable-recovery", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      let museum = application.savedPlannerItemRows("Recovery museum").firstMatch
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      let museumIdentifier = museum.identifier
      XCTAssertFalse(application.plannerElement("saved.item.new").isEnabled)
      application.plannerElement("saved.recovery.status.open").activateForPlannerJourney()
      let status = application.staticTexts["saved.recovery.status"]
      XCTAssertTrue(status.waitForExistence(timeout: 10))
      XCTAssertEqual(status.label, "Recovery status unavailable")
      XCTAssertTrue(application.staticTexts["saved.recovery.failure"].exists)
      XCTAssertFalse(application.plannerElement("saved.recovery.retry").exists)
      XCTAssertTrue(application.plannerElement("saved.settings.export").isEnabled)
      XCTAssertFalse(application.plannerElement("saved.settings.import").isEnabled)
      let recheck = application.plannerElement("saved.recovery.status.refresh")
      recheck.activateForPlannerJourney()
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "enabled == true"), object: recheck)
          ], timeout: 10), .completed)
      XCTAssertEqual(status.label, "Recovery status unavailable")
      capture("Unavailable recovery evidence stays explicit after native recheck")
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(museumIdentifier).waitForExistence(timeout: 15))
      XCTAssertFalse(application.plannerElement("saved.item.new").isEnabled)
      application.plannerElement(museumIdentifier).activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Original recovery notes"].waitForExistence(timeout: 10))
      capture("Unreadable recovery evidence does not hide committed Item content")
    }

    func testRetryFailureKeepsSavedItemReadableAndChangesBlockedAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "recovery-retry-failure", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      let museum = application.savedPlannerItemRows("Recovery museum").firstMatch
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      let museumIdentifier = museum.identifier
      let recovery = application.plannerElement("saved.recovery.status.open")
      XCTAssertTrue(recovery.waitForExistence(timeout: 10))
      recovery.activateForPlannerJourney()
      let retry = application.plannerElement("saved.recovery.retry")
      XCTAssertTrue(retry.waitForExistence(timeout: 10))
      retry.activateForPlannerJourney()
      let failure = application.staticTexts["saved.recovery.failure"]
      XCTAssertTrue(failure.waitForExistence(timeout: 15))
      XCTAssertFalse(failure.label.isEmpty)
      XCTAssertEqual(
        application.staticTexts["saved.recovery.status"].label, "Recovery copy incomplete")
      XCTAssertTrue(retry.isEnabled)
      capture("Failed checkpoint retry reports the real file error and retains recovery block")
      application.plannerElement("saved.recovery.status.refresh").activateForPlannerJourney()
      XCTAssertTrue(retry.waitForExistence(timeout: 10))
      XCTAssertEqual(
        application.staticTexts["saved.recovery.status"].label, "Recovery copy incomplete")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      XCTAssertFalse(application.plannerElement("saved.item.new").isEnabled)
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(museumIdentifier).waitForExistence(timeout: 15))
      XCTAssertEqual(application.savedPlannerItemRows("Recovery museum").count, 1)
      XCTAssertTrue(recovery.exists)
      XCTAssertFalse(application.plannerElement("saved.item.new").isEnabled)
      application.plannerElement(museumIdentifier).activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Original recovery notes"].waitForExistence(timeout: 10))
      capture("Failed retry preserves one original Item after native relaunch")
    }

    func testRetryingRecoveryAfterRelaunchPreservesSavedItemAndUnblocksChanges() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "incomplete-recovery", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      let museum = application.savedPlannerItemRows("Recovery museum").firstMatch
      let hotel = application.savedPlannerItemRows("Existing hotel").firstMatch
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      XCTAssertTrue(hotel.exists)
      let museumIdentifier = museum.identifier
      let hotelIdentifier = hotel.identifier
      let recovery = application.plannerElement("saved.recovery.status.open")
      XCTAssertTrue(recovery.waitForExistence(timeout: 10))
      let newItem = application.plannerElement("saved.item.new")
      XCTAssertFalse(newItem.isEnabled)
      XCTAssertTrue(newItem.frame.intersection(recovery.frame).isEmpty)
      capture("Incomplete recovery keeps saved Items readable and changes disabled")
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(museumIdentifier).waitForExistence(timeout: 15))
      XCTAssertTrue(recovery.waitForExistence(timeout: 10))
      XCTAssertFalse(newItem.isEnabled)
      recovery.activateForPlannerJourney()
      let status = application.staticTexts["saved.recovery.status"]
      XCTAssertTrue(status.waitForExistence(timeout: 10))
      XCTAssertEqual(status.label, "Recovery copy incomplete")
      let retry = application.plannerElement("saved.recovery.retry")
      XCTAssertTrue(retry.isEnabled)
      capture("Native Settings offers checkpoint-only retry after relaunch")
      retry.activateForPlannerJourney()
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "label == %@", "Saved on this device"), object: status)
          ], timeout: 15), .completed)
      XCTAssertFalse(retry.exists)
      capture("Recovery checkpoint completes without applying the Item again")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      XCTAssertFalse(recovery.exists)
      XCTAssertTrue(newItem.isEnabled)
      application.openPlannerSection("Lists")
      application.plannerElement("saved.list.new").activateForPlannerJourney()
      let name = application.textFields["saved.list.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 10))
      name.activateForPlannerJourney()
      name.typeText("After recovery")
      application.plannerElement("saved.list.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      let laterList = application.savedPlannerListRow("After recovery")
      if !laterList.exists {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists {
          sidebar.activateForPlannerJourney()
        } else {
          application.navigationBars["After recovery"].buttons["BackButton"]
            .activateForPlannerJourney()
        }
      }
      XCTAssertTrue(laterList.waitForExistence(timeout: 10))
      let laterListIdentifier = laterList.identifier
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Lists")
      XCTAssertTrue(application.plannerElement(laterListIdentifier).waitForExistence(timeout: 15))
      XCTAssertEqual(application.plannerElement(laterListIdentifier).label, "After recovery")
      application.openPlannerSection("Items")
      XCTAssertEqual(application.plannerElement(hotelIdentifier).label, "Existing hotel")
      XCTAssertTrue(application.plannerElement(museumIdentifier).exists)
      XCTAssertEqual(application.savedPlannerItemRows("Recovery museum").count, 1)
      XCTAssertFalse(recovery.exists)
      application.plannerElement(museumIdentifier).activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Original recovery notes"].waitForExistence(timeout: 10))
      capture("Relaunch retains original Item identity and the later independent change")
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
