import XCTest

#if os(iOS)
  @MainActor
  final class RetainedRecoveryJourneyTests: XCTestCase {
    func testRecoverySkipAndOverwritePreserveCurrentDataAndRestoredIdentitiesAfterRelaunch() throws
    {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "conflicting-recovery", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      let museum = application.savedPlannerItemRows("Retained museum").firstMatch
      let hotel = application.savedPlannerItemRows("Current hotel").firstMatch
      XCTAssertTrue(museum.waitForExistence(timeout: 20))
      XCTAssertTrue(hotel.exists)
      let museumIdentifier = museum.identifier
      let hotelIdentifier = hotel.identifier
      museum.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Current museum notes"].waitForExistence(timeout: 10))
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let editedTag = tag("Edited retained tag", in: application).firstMatch
      let independentTag = tag("Current travel tag", in: application).firstMatch
      XCTAssertTrue(editedTag.waitForExistence(timeout: 10))
      XCTAssertTrue(independentTag.exists)
      let tagIdentifier = editedTag.identifier
      let independentTagIdentifier = independentTag.identifier
      application.plannerElement("saved.categories.done").activateForPlannerJourney()

      for overwrite in [false, true] {
        try selectRetainedCopy(application)
        let retainedItem = recoverySource("Retained museum", kind: "item", in: application)
        let retainedTag = recoverySource("Retained travel tag", kind: "tag", in: application)
        XCTAssertEqual(
          "saved.item." + retainedItem.identifier.dropFirst("saved.recovery.source.item.".count),
          museumIdentifier)
        XCTAssertEqual(
          "saved.tag." + retainedTag.identifier.dropFirst("saved.recovery.source.tag.".count),
          tagIdentifier)
        application.plannerElement("saved.recovery.restore.review").activateForPlannerJourney()
        let conflicts = application.staticTexts["saved.import.summary.conflicts"]
        revealReviewElement(conflicts, in: application)
        XCTAssertEqual(conflicts.label, "Skipped conflicts, 2")
        if overwrite {
          let mode = application.plannerElement("saved.import.mode")
          revealReviewElement(mode, in: application)
          mode.activateForPlannerJourney()
          application.plannerElement("Overwrite").activateForPlannerJourney()
          let replacements = application.staticTexts["saved.import.summary.replacements"]
          revealReviewElement(replacements, in: application)
          XCTAssertEqual(replacements.label, "Replacements, 2")
          let tagReplacement = application.buttons["Retained travel tag, Tag"].firstMatch
          revealReviewElement(tagReplacement, in: application)
          tagReplacement.activateForPlannerJourney()
          let before = application.staticTexts["Name, Edited retained tag"]
          revealReviewElement(before, in: application)
          XCTAssertTrue(before.isHittable)
          let after = application.staticTexts["Name, Retained travel tag"]
          revealReviewElement(after, in: application)
          XCTAssertTrue(after.isHittable)
          capture("Recovery Overwrite reviews current and retained Tag values")
        } else {
          capture("Recovery Skip keeps two current conflicts")
        }
        application.plannerElement("saved.import.confirm").activateForPlannerJourney()
        XCTAssertTrue(
          application.staticTexts["saved.recovery.restore.applied"].waitForExistence(timeout: 15))
        application.plannerElement("saved.import.close").activateForPlannerJourney()
        closeRecovery(application)
        application.terminate()
        application.launchSavedPlannerJourney()
        application.openPlannerSection("Items")
        XCTAssertTrue(application.plannerElement(hotelIdentifier).waitForExistence(timeout: 15))
        XCTAssertEqual(application.plannerElement(hotelIdentifier).label, "Current hotel")
        XCTAssertTrue(application.plannerElement(museumIdentifier).exists)
        XCTAssertEqual(application.savedPlannerItemRows("Retained museum").count, 1)
        application.plannerElement(museumIdentifier).activateForPlannerJourney()
        let expectedNotes = overwrite ? "Retained museum notes" : "Current museum notes"
        XCTAssertTrue(application.staticTexts[expectedNotes].waitForExistence(timeout: 10))
        openSettings(application)
        application.plannerElement("saved.settings.labels").activateForPlannerJourney()
        XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
        let expectedTag = overwrite ? "Retained travel tag" : "Edited retained tag"
        XCTAssertEqual(application.plannerElement(tagIdentifier).label, expectedTag)
        XCTAssertEqual(tag(expectedTag, in: application).count, 1)
        XCTAssertEqual(
          application.plannerElement(independentTagIdentifier).label, "Current travel tag")
        capture("Recovery \(overwrite ? "Overwrite" : "Skip") preserves identities after relaunch")
        application.plannerElement("saved.categories.done").activateForPlannerJourney()
      }
    }

    func testReviewCancelAndRestoreRetainedCopyPreservesIdentitiesAfterRelaunch() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "retained-recovery", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      let currentItem = application.savedPlannerItemRows("Current hotel").firstMatch
      XCTAssertTrue(currentItem.waitForExistence(timeout: 20))
      let currentItemIdentifier = currentItem.identifier
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let currentTag = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Current travel tag")
      ).firstMatch
      XCTAssertTrue(currentTag.waitForExistence(timeout: 10))
      let currentTagIdentifier = currentTag.identifier
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      try selectRetainedCopy(application)
      let retainedItem = recoverySource("Retained museum", kind: "item", in: application)
      let retainedTag = recoverySource("Retained travel tag", kind: "tag", in: application)
      let restoredItemIdentifier =
        "saved.item." + retainedItem.identifier.dropFirst("saved.recovery.source.item.".count)
      let restoredTagIdentifier =
        "saved.tag." + retainedTag.identifier.dropFirst("saved.recovery.source.tag.".count)
      let restore = application.plannerElement("saved.recovery.restore.review")
      XCTAssertTrue(restore.waitForExistence(timeout: 10))
      restore.activateForPlannerJourney()
      let destination = application.staticTexts["saved.recovery.restore.target"]
      XCTAssertTrue(destination.waitForExistence(timeout: 10))
      XCTAssertTrue(destination.label.contains("Current Planner"))
      let additions = application.staticTexts["saved.import.summary.additions"]
      XCTAssertTrue(additions.waitForExistence(timeout: 10))
      XCTAssertEqual(additions.label, "Additions, 2")
      capture("Native review targets Current Planner and lists two additions")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      closeRecovery(application)
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(currentItemIdentifier).waitForExistence(timeout: 10))
      XCTAssertFalse(application.savedPlannerItemRows("Retained museum").firstMatch.exists)
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(currentTagIdentifier).waitForExistence(timeout: 10))
      XCTAssertFalse(application.plannerElement(restoredTagIdentifier).exists)
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      try selectRetainedCopy(application)
      restore.activateForPlannerJourney()
      XCTAssertTrue(additions.waitForExistence(timeout: 10))
      let confirm = application.plannerElement("saved.import.confirm")
      XCTAssertEqual(confirm.label, "Restore")
      confirm.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["saved.recovery.restore.applied"].waitForExistence(timeout: 15))
      capture("Explicit native confirmation restores the reviewed copy")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      closeRecovery(application)
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(currentItemIdentifier).waitForExistence(timeout: 15))
      XCTAssertTrue(
        application.plannerElement(restoredItemIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(restoredItemIdentifier).label, "Retained museum")
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(currentTagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(currentTagIdentifier).label, "Current travel tag")
      XCTAssertTrue(application.plannerElement(restoredTagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(restoredTagIdentifier).label, "Retained travel tag")
      capture("Restored and current identities survive native relaunch together")
    }

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

    private func tag(_ name: String, in application: XCUIApplication) -> XCUIElementQuery {
      application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", name))
    }

    private func revealReviewElement(_ element: XCUIElement, in application: XCUIApplication) {
      for _ in 0..<8 {
        if element.exists && element.isHittable { return }
        application.collectionViews["saved.import.form"].swipeUp()
      }
      XCTAssertTrue(element.exists && element.isHittable)
    }

    private func selectRetainedCopy(_ application: XCUIApplication) throws {
      application.plannerElement("saved.settings.recovery").activateForPlannerJourney()
      let snapshots = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.recovery.snapshot."))
      XCTAssertTrue(snapshots.firstMatch.waitForExistence(timeout: 15))
      XCTAssertEqual(snapshots.count, 2)
      for index in 0..<2 {
        snapshots.element(boundBy: index).activateForPlannerJourney()
        XCTAssertTrue(
          application.staticTexts["saved.recovery.evidence"].waitForExistence(timeout: 10))
        if recoverySource("Retained travel tag", kind: "tag", in: application).exists { return }
        application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      }
      XCTFail("The retained Item/Tag copy must be available.")
      throw CancellationError()
    }

    private func closeRecovery(_ application: XCUIApplication) {
      application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      application.plannerElement("saved.recovery.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
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
