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
      let exporterNavigation = application.navigationBars[
        "FullDocumentManagerViewControllerNavigationBar"]
      exporterNavigation.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.05))
        .press(
          forDuration: 0.05,
          thenDragTo: application.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.85)))
      XCTAssertTrue(save.waitForNonExistence(timeout: 10), application.debugDescription)
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
      let sourceIdentifiers = [item.identifier, tag.identifier]
      XCTAssertTrue(application.staticTexts["Label associations, 1"].exists)
      let detailControls = application.buttons.matching(
        NSPredicate(format: "label == %@", "Copy details")
      ).allElementsBoundByIndex
      guard let copyDetails = detailControls.last(where: \.isHittable) else {
        XCTFail("The selected recovery copy's details control is unavailable.")
        return []
      }
      copyDetails.activateForPlannerJourney()
      let generation = application.staticTexts.matching(
        NSPredicate(format: "label BEGINSWITH %@", "Saved generation,")
      ).firstMatch
      XCTAssertTrue(generation.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertEqual(generation.label, "Saved generation, 2")
      let savedGeneration = generation.label
      copyDetails.activateForPlannerJourney()
      let restore = application.plannerElement("saved.recovery.restore.review")
      XCTAssertTrue(restore.exists)
      XCTAssertFalse(restore.isEnabled)
      XCTAssertTrue(application.plannerElement("saved.recovery.export").isEnabled)
      capture("Saved recovery remains readable while restore has no current destination")
      return [snapshotIdentifier, savedGeneration] + sourceIdentifiers
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
