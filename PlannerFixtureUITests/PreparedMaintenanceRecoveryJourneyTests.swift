import XCTest

#if os(iOS)
  @MainActor
  final class PreparedMaintenanceRecoveryJourneyTests: XCTestCase {
    func testPreparedCopyStaysUnverifiedThroughReviewAndLeavesSavedItemsUnchanged() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "prepared-maintenance-recovery", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let item = application.savedPlannerItemRows("Prepared museum").firstMatch
      XCTAssertTrue(item.waitForExistence(timeout: 15))
      let itemIdentifier = item.identifier
      application.openPlannerSection("Lists")
      let settings = application.plannerElement("saved.settings.open")
      if !settings.waitForExistence(timeout: 2) {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists {
          sidebar.activateForPlannerJourney()
        } else {
          let back = application.navigationBars.buttons["BackButton"].firstMatch
          if back.exists { back.activateForPlannerJourney() }
        }
      }
      XCTAssertTrue(settings.waitForExistence(timeout: 10))
      settings.activateForPlannerJourney()
      application.plannerElement("saved.settings.recovery").activateForPlannerJourney()
      let preparation = application.plannerElement(
        "saved.recovery.maintenance.00000000-0000-4000-8000-000000000941")
      XCTAssertTrue(preparation.waitForExistence(timeout: 15), application.debugDescription)
      capture("Prepared maintenance appears separately from the acknowledged snapshot")
      preparation.activateForPlannerJourney()
      let evidence = application.staticTexts["saved.recovery.evidence"]
      XCTAssertTrue(evidence.waitForExistence(timeout: 10))
      XCTAssertTrue(evidence.label.contains("Unverified recovery copy"), evidence.label)
      let review = application.plannerElement("saved.recovery.restore.review")
      reveal(review, in: application)
      XCTAssertTrue(review.isEnabled)
      review.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Unverified recovery copy"].waitForExistence(timeout: 10))
      let additions = application.staticTexts["saved.import.summary.additions"]
      XCTAssertTrue(additions.waitForExistence(timeout: 15), application.debugDescription)
      XCTAssertEqual(additions.label, "Additions, 0")
      capture("An unverified copy enters the existing explicit recovery review")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      application.plannerElement("saved.recovery.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(itemIdentifier).waitForExistence(timeout: 15))
      XCTAssertEqual(application.savedPlannerItemRows("Prepared museum").count, 1)
      application.plannerElement(itemIdentifier).activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Prepared recovery note"].waitForExistence(timeout: 10))
      capture("Canceling recovery review preserves the exact saved Item after relaunch")
    }

    private func reveal(_ element: XCUIElement, in application: XCUIApplication) {
      for _ in 0..<8 where !element.isHittable { application.swipeUp() }
      XCTAssertTrue(element.exists, application.debugDescription)
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
