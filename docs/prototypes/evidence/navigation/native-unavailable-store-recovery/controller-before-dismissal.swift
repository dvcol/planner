import XCTest

#if os(iOS)
  @MainActor
  final class UnavailableStoreRecoveryJourneyTests: XCTestCase {
    func testUnavailableStoreKeepsItsRecoveryCopyReadableAfterRetryAndRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "unavailable-store", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      assertUnavailable(application)
      application.plannerElement("Try Again").activateForPlannerJourney()
      assertUnavailable(application)
      capture("Unavailable Planner offers recovery without creating a replacement dataset")
      let firstIdentities = inspectRecovery(application)
      application.plannerElement("saved.recovery.export").activateForPlannerJourney()
      let save = application.buttons.matching(NSPredicate(format: "label == %@", "Save"))
        .firstMatch
      XCTAssertTrue(save.waitForExistence(timeout: 10), application.debugDescription)
      capture("Unavailable-store recovery can open the native file exporter")
      let cancel = application.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", "Cancel")
      )
      .firstMatch
      XCTAssertTrue(cancel.waitForExistence(timeout: 5), application.debugDescription)
      cancel.activateForPlannerJourney()
      let export = application.plannerElement("saved.recovery.export")
      XCTAssertTrue(export.waitForExistence(timeout: 10))
      XCTAssertTrue(export.isEnabled)
      XCTAssertFalse(application.staticTexts["saved.recovery.exported"].exists)
      application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      application.plannerElement("saved.recovery.done").activateForPlannerJourney()
      assertUnavailable(application)
      application.terminate()
      application.launchSavedPlannerJourney()
      assertUnavailable(application)
      XCTAssertEqual(inspectRecovery(application), firstIdentities)
      capture("The same retained Item and Tag survive unavailable-store relaunch")
    }

    private func assertUnavailable(_ application: XCUIApplication) {
      XCTAssertTrue(application.staticTexts["Planner unavailable"].waitForExistence(timeout: 20))
      XCTAssertTrue(
        application.staticTexts[
          "The initialized dataset's store is missing; recovery remains separate."
        ].exists, application.debugDescription)
      XCTAssertTrue(application.plannerElement("saved.settings.recovery").isEnabled)
      XCTAssertFalse(application.plannerElement("saved.item.new").exists)
      XCTAssertFalse(application.staticTexts["Saved on this device"].exists)
    }

    private func inspectRecovery(_ application: XCUIApplication) -> [String] {
      application.plannerElement("saved.settings.recovery").activateForPlannerJourney()
      let snapshots = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.recovery.snapshot."))
      XCTAssertTrue(snapshots.firstMatch.waitForExistence(timeout: 15))
      XCTAssertEqual(snapshots.count, 1)
      let snapshotIdentifier = snapshots.firstMatch.identifier
      snapshots.firstMatch.activateForPlannerJourney()
      let evidence = application.staticTexts["saved.recovery.evidence"]
      XCTAssertTrue(evidence.waitForExistence(timeout: 10))
      XCTAssertEqual(evidence.label, "Saved snapshot")
      let item = recoverySource("Unavailable museum", kind: "item", application: application)
      let tag = recoverySource("Retained travel", kind: "tag", application: application)
      XCTAssertTrue(item.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertTrue(tag.exists)
      XCTAssertTrue(application.staticTexts["Label associations, 1"].exists)
      let restore = application.plannerElement("saved.recovery.restore.review")
      XCTAssertTrue(restore.exists)
      XCTAssertFalse(restore.isEnabled)
      XCTAssertTrue(application.plannerElement("saved.recovery.export").isEnabled)
      capture("Saved recovery remains readable while restore has no current destination")
      return [snapshotIdentifier, item.identifier, tag.identifier]
    }

    private func recoverySource(_ name: String, kind: String, application: XCUIApplication)
      -> XCUIElement
    {
      application.staticTexts.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
          "saved.recovery.source.\(kind).", name)
      ).firstMatch
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
