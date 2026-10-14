import XCTest

#if os(iOS)
  @MainActor
  final class RetainedRecoveryJourneyTests: XCTestCase {
    func testExportingRetainedCopyKeepsCurrentDatasetSeparateAfterRelaunch() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "retained-recovery", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let currentItem = application.savedPlannerItemRows("Current hotel").firstMatch
      XCTAssertTrue(currentItem.waitForExistence(timeout: 20))
      let currentItemIdentifier = currentItem.identifier
      XCTAssertFalse(application.savedPlannerItemRows("Retained museum").firstMatch.exists)
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let currentTag = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Current travel tag")
      ).firstMatch
      XCTAssertTrue(currentTag.waitForExistence(timeout: 10))
      let currentTagIdentifier = currentTag.identifier
      XCTAssertFalse(application.staticTexts["Retained travel tag"].exists)
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.recovery").activateForPlannerJourney()
      let snapshots = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.recovery.snapshot."))
      XCTAssertTrue(snapshots.firstMatch.waitForExistence(timeout: 15))
      XCTAssertEqual(snapshots.count, 2)
      var selectedNamespace: String?
      for index in 0..<2 {
        let candidate = snapshots.element(boundBy: index)
        let candidateIdentifier = candidate.identifier
        candidate.activateForPlannerJourney()
        XCTAssertTrue(
          application.staticTexts["saved.recovery.evidence"].waitForExistence(timeout: 10))
        let retainedTag = recoverySource("Retained travel tag", kind: "tag", in: application)
        if retainedTag.exists {
          selectedNamespace = String(
            candidateIdentifier.dropFirst("saved.recovery.snapshot.".count))
          break
        }
        application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      }
      let namespace = try XCTUnwrap(selectedNamespace)
      let retainedTag = recoverySource("Retained travel tag", kind: "tag", in: application)
      let retainedItem = recoverySource("Retained museum", kind: "item", in: application)
      XCTAssertTrue(retainedTag.exists)
      XCTAssertTrue(retainedItem.exists)
      XCTAssertFalse(recoverySource("Current travel tag", kind: "tag", in: application).exists)
      XCTAssertFalse(recoverySource("Current hotel", kind: "item", in: application).exists)
      let retainedTagIdentifier = String(
        retainedTag.identifier.dropFirst("saved.recovery.source.tag.".count))
      let retainedItemIdentifier = String(
        retainedItem.identifier.dropFirst("saved.recovery.source.item.".count))
      XCTAssertNotEqual("saved.tag." + retainedTagIdentifier, currentTagIdentifier)
      capture("Retained copy shows its own saved Item and Tag")
      application.plannerElement("saved.recovery.export").activateForPlannerJourney()
      let save = application.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch
      XCTAssertTrue(save.waitForExistence(timeout: 10))
      let localLocation = application.cells.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "DOC.sidebar.item.On My ")
      ).firstMatch
      if localLocation.exists && localLocation.isHittable {
        localLocation.activateForPlannerJourney()
      }
      capture("System picker exports the retained dataset")
      save.activateForPlannerJourney()
      let exported = application.staticTexts["saved.recovery.exported"]
      XCTAssertTrue(exported.waitForExistence(timeout: 10))
      let filename = String(exported.label.dropFirst("Recovery copy exported, ".count))
      XCTAssertEqual(filename, "Planner Saved Recovery \(namespace) Generation 2.json")
      let expectation = XCTAttachment(
        string:
          "Filename: \(filename)\nTag: \(retainedTagIdentifier)\nItem: \(retainedItemIdentifier)\nCurrent tag: \(currentTagIdentifier)\nCurrent item: \(currentItemIdentifier)"
      )
      expectation.name = "Public retained export expectation"
      expectation.lifetime = .keepAlways
      add(expectation)
      capture("Retained recovery export reports successful delivery")
      application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      application.plannerElement("saved.recovery.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(currentItemIdentifier).waitForExistence(timeout: 15))
      XCTAssertFalse(application.savedPlannerItemRows("Retained museum").firstMatch.exists)
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(currentTagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(currentTagIdentifier).label, "Current travel tag")
      XCTAssertFalse(application.staticTexts["Retained travel tag"].exists)
      capture("Current dataset stays separate after export and relaunch")
    }

    private func recoverySource(_ name: String, kind: String, in application: XCUIApplication)
      -> XCUIElement
    {
      application.staticTexts.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
          "saved.recovery.source.\(kind).", name)
      ).firstMatch
    }

    private func openSettings(_ application: XCUIApplication) {
      application.openPlannerSection("Lists")
      let settings = application.plannerElement("saved.settings.open")
      if !settings.waitForExistence(timeout: 2) {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists { sidebar.activateForPlannerJourney() }
      }
      XCTAssertTrue(settings.waitForExistence(timeout: 10))
      settings.activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.settings.labels").waitForExistence(timeout: 10))
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
