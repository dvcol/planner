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
      let cancel = application.buttons.matching(NSPredicate(format: "label == %@", "Cancel"))
        .firstMatch
      if cancel.exists && cancel.isHittable {
        cancel.activateForPlannerJourney()
      } else {
        let exporterNavigation = application.navigationBars[
          "FullDocumentManagerViewControllerNavigationBar"]
        exporterNavigation.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.05))
          .press(
            forDuration: 0.05,
            thenDragTo: application.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.85)))
      }
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
      let explanation = application.staticTexts["saved.recovery.restore.unavailable"]
      XCTAssertTrue(explanation.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertEqual(
        explanation.label,
        "Restore is unavailable while Planner cannot open its saved data. You can still inspect or export this copy."
      )
      let item = recoverySource("Unavailable museum", kind: "item", application: application)
      let tag = recoverySource("Retained travel", kind: "tag", application: application)
      reveal(item, application: application)
      let itemIdentifier = item.identifier
      reveal(tag, application: application)
      let tagIdentifier = tag.identifier
      reveal(application.staticTexts["Label associations, 1"], application: application)
      guard let copyDetails = visibleCopyDetails(application) else { return [] }
      copyDetails.activateForPlannerJourney()
      let generation = application.staticTexts.matching(
        NSPredicate(format: "label BEGINSWITH %@", "Saved generation,")
      ).firstMatch
      reveal(generation, application: application)
      XCTAssertEqual(generation.label, "Saved generation, 2")
      let savedGeneration = generation.label
      guard let expandedDetails = visibleCopyDetails(application) else { return [] }
      expandedDetails.activateForPlannerJourney()
      let restore = application.plannerElement("saved.recovery.restore.review")
      reveal(restore, application: application)
      XCTAssertFalse(restore.isEnabled)
      XCTAssertTrue(application.plannerElement("saved.recovery.export").isEnabled)
      capture("Saved recovery remains readable while restore has no current destination")
      return [snapshotIdentifier, savedGeneration, itemIdentifier, tagIdentifier]
    }

    private func visibleCopyDetails(_ application: XCUIApplication) -> XCUIElement? {
      for _ in 0..<8 {
        guard
          let form = application.collectionViews.allElementsBoundByIndex.last(where: \.isHittable)
        else {
          XCTFail("The selected recovery Form is unavailable.")
          return nil
        }
        let controls = form.buttons.matching(
          NSPredicate(format: "label == %@", "Copy details")
        ).allElementsBoundByIndex
        let navigationBottom = application.navigationBars["Recovery Copy"].frame.maxY
        if let control = controls.last(where: {
          $0.isHittable && $0.frame.minY >= navigationBottom + 4
            && $0.frame.maxY <= form.frame.maxY
        }) {
          return control
        }
        scrollSelectedForm(application, towardStart: true)
      }
      XCTFail("The selected recovery copy's details control is unavailable.")
      return nil
    }

    private func reveal(_ element: XCUIElement, application: XCUIApplication) {
      for _ in 0..<8 {
        if isVisibleForReading(element, application: application) { return }
        let navigationBottom = application.navigationBars["Recovery Copy"].frame.maxY
        scrollSelectedForm(
          application, towardStart: element.exists && element.frame.minY < navigationBottom)
      }
      XCTAssertTrue(
        isVisibleForReading(element, application: application), application.debugDescription)
    }

    private func isVisibleForReading(_ element: XCUIElement, application: XCUIApplication) -> Bool {
      guard element.exists,
        let form = application.collectionViews.allElementsBoundByIndex.last(where: \.isHittable)
      else { return false }
      let frame = element.frame
      let navigationBottom = application.navigationBars["Recovery Copy"].frame.maxY
      return frame.width > 0 && frame.height > 0 && form.frame.contains(frame)
        && frame.minY >= navigationBottom + 4
    }

    private func scrollSelectedForm(_ application: XCUIApplication, towardStart: Bool = false) {
      guard let form = application.collectionViews.allElementsBoundByIndex.last(where: \.isHittable)
      else {
        XCTFail("The selected recovery Form is unavailable.")
        return
      }
      let start = form.coordinate(
        withNormalizedOffset: .init(dx: 0.95, dy: towardStart ? 0.3 : 0.78))
      let end = form.coordinate(
        withNormalizedOffset: .init(dx: 0.95, dy: towardStart ? 0.78 : 0.3))
      start.press(forDuration: 0.05, thenDragTo: end)
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
