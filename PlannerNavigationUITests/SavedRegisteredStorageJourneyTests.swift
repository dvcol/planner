import XCTest

#if os(iOS) && !targetEnvironment(simulator)
  @MainActor
  final class SavedRegisteredStorageJourneyTests: XCTestCase {
    /// Requires a disposable signed installation and uses the normal shared store.
    func testNormalAppSaveAndRelaunchRetainTheSameItemBeforeCleanup() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = []
      let title = "Shared storage check " + UUID().uuidString.prefix(8)
      let notes = "Created in shared storage"
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let empty = application.staticTexts.matching(
        NSPredicate(format: "label == %@ OR label == %@", "No Items yet", "No matching items")
      ).firstMatch
      XCTAssertTrue(empty.waitForExistence(timeout: 10))
      application.openSavedPlannerNewItemEditor()
      let titleField = application.textFields["saved.item.title"]
      XCTAssertTrue(titleField.waitForExistence(timeout: 5))
      titleField.activateForPlannerJourney()
      titleField.typeText(title)
      let notesField = application.textFields["saved.item.notes"]
      notesField.activateForPlannerJourney()
      notesField.typeText(notes)
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts[notes].waitForExistence(timeout: 10))
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      let row = application.savedPlannerItemRows(title).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertTrue(row.waitForPlannerHittability())
      let identity = row.identifier
      XCTAssertFalse(identity.isEmpty)

      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts[notes].waitForExistence(timeout: 10))
      let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
      capture.name = "Registered app retains its shared Item after normal relaunch"
      capture.lifetime = .keepAlways
      add(capture)

      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("saved.item.delete").activateForPlannerJourney()
      let confirmation = application.plannerElement("saved.item.delete.confirm")
      XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
      confirmation.activateForPlannerJourney()
      XCTAssertTrue(confirmation.waitForNonExistence(timeout: 10))
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(empty.waitForExistence(timeout: 10))
      XCTAssertTrue(row.waitForNonExistence(timeout: 10))
    }
  }
#endif
