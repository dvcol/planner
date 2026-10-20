import XCTest

@MainActor
final class SavedBackupImportJourneyTests: XCTestCase {
  #if os(iOS)
    func testRestoredOriginatingListRequiresFreshReviewBeforeSavingItsRetainedItemDraft() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      guard application.windows.firstMatch.frame.width >= 600 else {
        throw XCTSkip("The originating List must remain beside its unsaved editor.")
      }
      application.beginPlannerListCreation()
      let name = application.textFields["saved.list.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      name.activateForPlannerJourney()
      name.typeText("Restored origin")
      application.plannerElement("saved.list.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      let origin = application.savedPlannerListRow("Restored origin")
      if !origin.exists || !origin.isHittable {
        application.plannerElement("Show Sidebar").activateForPlannerJourney()
      }
      XCTAssertTrue(origin.waitForExistence(timeout: 10))
      let originalListIdentifier = origin.identifier
      let backup = createAndExportTagBackup(application)
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      XCTAssertTrue(origin.waitForExistence(timeout: 10))
      origin.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      application.openSavedPlannerListAddMenu()
      application.plannerElement("saved.list.createItem").activateForPlannerJourney()
      let title = application.textFields["saved.item.title"]
      let notes = application.textFields["saved.item.notes"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Retained restored visit")
      notes.activateForPlannerJourney()
      notes.typeText("Preserve these fields across explicit List restoration")
      application.openSavedPlannerListActionsMenu()
      application.plannerElement("saved.list.delete").activateForPlannerJourney()
      let confirmation = application.plannerElement("saved.list.delete.confirm")
      XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
      confirmation.activateForPlannerJourney()
      XCTAssertTrue(confirmation.waitForNonExistence(timeout: 10))
      XCTAssertEqual(title.value as? String, "Retained restored visit")
      XCTAssertEqual(
        notes.value as? String, "Preserve these fields across explicit List restoration")
      openSettings(application)
      selectBackup(backup.filename, application: application)
      application.plannerElement("saved.import.mode").activateForPlannerJourney()
      application.plannerElement("Overwrite").activateForPlannerJourney()
      let restore = application.descendants(matching: .any).matching(
        identifier: "saved.import.restore"
      ).firstMatch
      revealImportElement(restore, application: application)
      restore.switches.firstMatch.activateForPlannerJourney()
      let restorations = application.staticTexts["saved.import.summary.restorations"]
      revealImportElement(restorations, application: application)
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "label == %@", "Restorations, 1"),
              object: restorations)
          ], timeout: 15), .completed)
      recordImport(
        application, name: "Manual backup explicitly reviews one restored originating List")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(
        application.descendants(matching: .any)["saved.import.applied"].waitForExistence(
          timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      XCTAssertEqual(title.value as? String, "Retained restored visit")
      XCTAssertEqual(
        notes.value as? String, "Preserve these fields across explicit List restoration")
      application.navigationBars["New item"].staticTexts["New item"].tap()
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      let review = application.plannerElement("Use this list")
      XCTAssertTrue(review.waitForExistence(timeout: 10))
      XCTAssertTrue(
        application.staticTexts[
          "The original List changed. Save to Restored origin instead? Your draft is preserved."
        ].exists)
      recordImport(
        application, name: "Restored List requires fresh destination review despite unchanged name")
      review.activateForPlannerJourney()
      XCTAssertTrue(title.exists)
      XCTAssertEqual(title.value as? String, "Retained restored visit")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      XCTAssertTrue(title.waitForNonExistence(timeout: 10))
      let appearance = application.savedPlannerItemRows("Retained restored visit").firstMatch
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      let appearanceIdentifier = appearance.identifier
      XCTAssertTrue(appearanceIdentifier.hasPrefix("saved.appearance."))
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Lists")
      XCTAssertTrue(origin.waitForExistence(timeout: 10))
      XCTAssertEqual(origin.identifier, originalListIdentifier)
      origin.activateForPlannerJourney()
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      XCTAssertEqual(appearance.identifier, appearanceIdentifier)
      XCTAssertTrue(
        application.plannerElement(
          appearanceIdentifier.replacingOccurrences(
            of: "saved.appearance.", with: "saved.appearance.completion.")
        ).waitForPlannerValue("To do"))
      appearance.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Preserve these fields across explicit List restoration"]
          .waitForExistence(timeout: 10))
      recordImport(
        application,
        name: "Restored originating List retains the reviewed Item and local Todo after relaunch")
    }

    func testRealBackupSkipAndOverwriteKeepTagIdentityAfterRelaunch() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let exportedBackup = createAndExportTagBackup(application)
      let tagIdentifier = exportedBackup.tagIdentifier
      let filename = exportedBackup.filename
      let name = application.textFields["saved.tag.name"]
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      application.plannerElement(tagIdentifier).activateForPlannerJourney()
      XCTAssertTrue(name.waitForExistence(timeout: 10))
      name.activateForPlannerJourney()
      let originalName = try XCTUnwrap(name.value as? String)
      name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalName.count))
      name.typeText("Current edited tag")
      application.plannerElement("saved.tag.save").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(tagIdentifier).label, "Current edited tag")
      application.plannerElement("saved.categories.done").activateForPlannerJourney()

      selectBackup(filename, application: application)
      let conflicts = application.staticTexts["saved.import.summary.conflicts"]
      XCTAssertTrue(conflicts.waitForExistence(timeout: 15))
      XCTAssertEqual(conflicts.label, "Skipped conflicts, 1")
      recordImport(application, name: "Default Skip reviews the current Tag conflict")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(
        application.descendants(matching: .any)["saved.import.applied"].waitForExistence(
          timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(tagIdentifier).label, "Current edited tag")
      application.plannerElement("saved.categories.done").activateForPlannerJourney()

      selectBackup(filename, application: application)
      XCTAssertTrue(conflicts.waitForExistence(timeout: 15))
      application.plannerElement("saved.import.mode").activateForPlannerJourney()
      application.plannerElement("Overwrite").activateForPlannerJourney()
      let replacements = application.staticTexts["saved.import.summary.replacements"]
      revealImportElement(replacements, application: application)
      XCTAssertTrue(replacements.waitForExistence(timeout: 15))
      XCTAssertEqual(replacements.label, "Replacements, 1")
      recordImport(application, name: "Overwrite reviews the represented Tag replacement")
      let replacement = application.buttons.matching(
        NSPredicate(format: "label == %@", "Original backup tag, Tag")
      ).firstMatch
      revealImportElement(replacement, application: application)
      replacement.activateForPlannerJourney()
      let beforeName = application.staticTexts["Name, Current edited tag"]
      revealImportElement(beforeName, application: application)
      XCTAssertTrue(beforeName.isHittable)
      recordImport(application, name: "Replacement before summary keeps the current Tag name")
      let afterName = application.staticTexts["Name, Original backup tag"]
      revealImportElement(afterName, application: application)
      XCTAssertTrue(afterName.isHittable)
      recordImport(application, name: "Replacement after summary shows the incoming Tag name")
      let backupDetails = application.buttons["Backup details"].firstMatch
      revealImportElement(backupDetails, application: application)
      backupDetails.activateForPlannerJourney()
      let recordIdentifier = String(tagIdentifier.dropFirst("saved.tag.".count))
      let identity = application.staticTexts["Record ID, \(recordIdentifier)"]
      revealImportElement(identity, application: application)
      XCTAssertTrue(identity.isHittable)
      recordImport(application, name: "Expandable backup details retain the exact Tag identity")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(
        application.descendants(matching: .any)["saved.import.applied"].waitForExistence(
          timeout: 15))
      recordImport(application, name: "Applied import retains the actual Core summary")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(tagIdentifier).label, "Original backup tag")
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(tagIdentifier).label, "Original backup tag")
      let restoredTags = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Original backup tag"))
      XCTAssertEqual(restoredTags.count, 1)
    }

    func testRestoringIntoEmptyDatasetAndReimportingKeepOneTagAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let exportedBackup = createAndExportTagBackup(application)
      application.terminate()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No Tags yet"].waitForExistence(timeout: 10))
      XCTAssertFalse(application.plannerElement(exportedBackup.tagIdentifier).exists)
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      selectBackup(exportedBackup.filename, application: application)
      let additions = application.staticTexts["saved.import.summary.additions"]
      XCTAssertTrue(additions.waitForExistence(timeout: 15))
      XCTAssertEqual(additions.label, "Additions, 1")
      recordImport(application, name: "Empty dataset reviews the backed-up Tag addition")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(
        application.descendants(matching: .any)["saved.import.applied"].waitForExistence(
          timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement(exportedBackup.tagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(
        application.plannerElement(exportedBackup.tagIdentifier).label, "Original backup tag")
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      selectBackup(exportedBackup.filename, application: application)
      let unchanged = application.staticTexts["saved.import.summary.unchanged"]
      XCTAssertTrue(unchanged.waitForExistence(timeout: 15))
      XCTAssertEqual(unchanged.label, "Unchanged, 1")
      XCTAssertEqual(additions.label, "Additions, 0")
      recordImport(application, name: "Reimport reviews one unchanged Tag and no additions")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(
        application.descendants(matching: .any)["saved.import.applied"].waitForExistence(
          timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let restoredTag = application.plannerElement(exportedBackup.tagIdentifier)
      XCTAssertTrue(restoredTag.waitForExistence(timeout: 10))
      XCTAssertEqual(restoredTag.label, "Original backup tag")
      let tags = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Original backup tag"))
      XCTAssertEqual(tags.count, 1)
      recordImport(
        application, name: "Restoration and repeated import retain one original Tag identity")
    }

    func testCancelingOverwriteReviewPreservesCurrentTagAfterRelaunch() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let exportedBackup = createAndExportTagBackup(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      application.plannerElement(exportedBackup.tagIdentifier).activateForPlannerJourney()
      let name = application.textFields["saved.tag.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 10))
      name.activateForPlannerJourney()
      let originalName = try XCTUnwrap(name.value as? String)
      name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalName.count))
      name.typeText("Keep current tag")
      application.plannerElement("saved.tag.save").activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement(exportedBackup.tagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(
        application.plannerElement(exportedBackup.tagIdentifier).label, "Keep current tag")
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      selectBackup(exportedBackup.filename, application: application)
      application.plannerElement("saved.import.mode").activateForPlannerJourney()
      application.plannerElement("Overwrite").activateForPlannerJourney()
      let replacements = application.staticTexts["saved.import.summary.replacements"]
      revealImportElement(replacements, application: application)
      XCTAssertTrue(replacements.waitForExistence(timeout: 15))
      XCTAssertEqual(replacements.label, "Replacements, 1")
      recordImport(application, name: "Cancel is available for a reviewed Tag replacement")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      let importBackup = application.plannerElement("saved.settings.import")
      XCTAssertTrue(importBackup.waitForPlannerHittability())
      XCTAssertTrue(importBackup.isEnabled)
      XCTAssertFalse(application.plannerElement("saved.import.applied").exists)
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let retainedTag = application.plannerElement(exportedBackup.tagIdentifier)
      XCTAssertTrue(retainedTag.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedTag.label, "Keep current tag")
      recordImport(application, name: "Canceled Overwrite retains the current Tag after relaunch")
    }

    func testMalformedBackupShowsFailureAndPreservesCurrentTagAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let exportedBackup = createAndExportTagBackup(application)
      selectBackupFile("Planner malformed backup.json", application: application)
      let failure = application.alerts["Backup import failed"]
      XCTAssertTrue(failure.waitForExistence(timeout: 15))
      XCTAssertTrue(failure.staticTexts["The backup contains an invalid JSON value."].exists)
      XCTAssertFalse(application.plannerElement("saved.import.confirm").exists)
      recordImport(application, name: "Malformed JSON shows a native failure before review")
      failure.buttons["OK"].activateForPlannerJourney()
      let importBackup = application.plannerElement("saved.settings.import")
      XCTAssertTrue(importBackup.waitForPlannerHittability())
      XCTAssertTrue(importBackup.isEnabled)
      selectBackup(exportedBackup.filename, application: application)
      let unchanged = application.staticTexts["saved.import.summary.unchanged"]
      XCTAssertTrue(unchanged.waitForExistence(timeout: 15))
      XCTAssertEqual(unchanged.label, "Unchanged, 1")
      recordImport(application, name: "A valid backup remains reviewable after malformed input")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let retainedTag = application.plannerElement(exportedBackup.tagIdentifier)
      XCTAssertTrue(retainedTag.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedTag.label, "Original backup tag")
      recordImport(application, name: "Rejected malformed input preserves the Tag after relaunch")
    }

    func testUnsupportedBackupVersionRejectsBeforeReviewAndPreservesCurrentTagAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let exportedBackup = createAndExportTagBackup(application)
      selectBackupFile("Planner unsupported version backup.json", application: application)
      let failure = application.alerts["Backup import failed"]
      XCTAssertTrue(failure.waitForExistence(timeout: 15))
      XCTAssertTrue(failure.staticTexts["Unsupported portable backup version."].exists)
      XCTAssertFalse(application.plannerElement("saved.import.confirm").exists)
      recordImport(application, name: "Unsupported backup version rejects before native review")
      failure.buttons["OK"].activateForPlannerJourney()
      let importBackup = application.plannerElement("saved.settings.import")
      XCTAssertTrue(importBackup.waitForPlannerHittability())
      XCTAssertTrue(importBackup.isEnabled)
      selectBackup(exportedBackup.filename, application: application)
      let unchanged = application.staticTexts["saved.import.summary.unchanged"]
      XCTAssertTrue(unchanged.waitForExistence(timeout: 15))
      XCTAssertEqual(unchanged.label, "Unchanged, 1")
      recordImport(application, name: "Valid backup remains reviewable after unsupported version")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let retainedTag = application.plannerElement(exportedBackup.tagIdentifier)
      XCTAssertTrue(retainedTag.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedTag.label, "Original backup tag")
      recordImport(application, name: "Unsupported backup leaves original Tag after relaunch")
    }

    func testUnresolvedBackupReferenceDisablesImportAndPreservesCurrentDataAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let exportedBackup = createAndExportTagBackup(application)
      selectBackupFile("Planner unresolved reference backup.json", application: application)
      let failure = application.staticTexts[
        "The imported reference cannot resolve in this dataset."]
      revealImportElement(failure, application: application)
      XCTAssertTrue(failure.waitForExistence(timeout: 15))
      let confirmation = application.plannerElement("saved.import.confirm")
      XCTAssertTrue(confirmation.exists)
      XCTAssertFalse(confirmation.isEnabled)
      let retry = application.plannerElement("Try again")
      revealImportElement(retry, application: application)
      XCTAssertTrue(retry.isEnabled)
      recordImport(application, name: "Unresolved backup reference blocks native confirmation")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      selectBackup(exportedBackup.filename, application: application)
      let unchanged = application.staticTexts["saved.import.summary.unchanged"]
      XCTAssertTrue(unchanged.waitForExistence(timeout: 15))
      XCTAssertEqual(unchanged.label, "Unchanged, 1")
      recordImport(application, name: "Valid backup remains reviewable after unresolved reference")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let retainedTag = application.plannerElement(exportedBackup.tagIdentifier)
      XCTAssertTrue(retainedTag.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedTag.label, "Original backup tag")
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.openPlannerSection("Lists")
      XCTAssertTrue(application.staticTexts["No Lists yet"].waitForExistence(timeout: 15))
      XCTAssertFalse(application.savedPlannerListRow("Unresolved backup list").exists)
      recordImport(application, name: "Rejected unresolved backup creates no List after relaunch")
    }

    private func createAndExportTagBackup(_ application: XCUIApplication) -> (
      tagIdentifier: String, filename: String
    ) {
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      application.plannerElement("saved.labels.new").activateForPlannerJourney()
      application.plannerElement("New tag").activateForPlannerJourney()
      let name = application.textFields["saved.tag.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      name.activateForPlannerJourney()
      name.typeText("Original backup tag")
      application.plannerElement("saved.tag.save").activateForPlannerJourney()
      let tag = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Original backup tag")
      ).firstMatch
      XCTAssertTrue(tag.waitForExistence(timeout: 10))
      let tagIdentifier = tag.identifier
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.export").activateForPlannerJourney()
      let save = application.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch
      XCTAssertTrue(save.waitForExistence(timeout: 10))
      chooseLocalFileLocation(application)
      save.activateForPlannerJourney()
      let replace = application.buttons.matching(NSPredicate(format: "label == %@", "Replace"))
        .firstMatch
      if replace.waitForExistence(timeout: 2) { replace.activateForPlannerJourney() }
      let exported = application.staticTexts["saved.settings.exported"]
      XCTAssertTrue(exported.waitForExistence(timeout: 10))
      let filename = String(exported.label.dropFirst("Backup exported, ".count))
      XCTAssertTrue(filename.hasSuffix(".json"))
      return (tagIdentifier: tagIdentifier, filename: filename)
    }

    private func selectBackup(_ filename: String, application: XCUIApplication) {
      selectBackupFile(filename, application: application)
      XCTAssertTrue(
        application.plannerElement("saved.import.confirm").waitForExistence(timeout: 15))
    }

    private func selectBackupFile(_ filename: String, application: XCUIApplication) {
      application.plannerElement("saved.settings.import").activateForPlannerJourney()
      let documentName = String(filename.dropLast(".json".count))
      let document = application.cells.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ OR label BEGINSWITH %@", filename, filename)
      ).firstMatch
      if !document.waitForExistence(timeout: 5) {
        chooseLocalFileLocation(application)
      }
      if !document.waitForExistence(timeout: 5) {
        let search = application.searchFields.firstMatch
        if !search.exists {
          let searchButton = application.buttons.matching(
            NSPredicate(format: "label == %@", "Search"))
          if let visibleSearchButton = searchButton.allElementsBoundByIndex.first(
            where: \.isHittable)
          {
            visibleSearchButton.activateForPlannerJourney()
          }
        }
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.activateForPlannerJourney()
        search.typeText(documentName + "\n")
        let filenameSearch = application.buttons.matching(
          NSPredicate(format: "label BEGINSWITH %@", "Name Contains")
        ).firstMatch
        if filenameSearch.waitForExistence(timeout: 2) && filenameSearch.isHittable {
          filenameSearch.activateForPlannerJourney()
        }
      }
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Native picker for the selected backup file"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      XCTAssertTrue(document.waitForExistence(timeout: 15))
      document.activateForPlannerJourney()
    }

    private func chooseLocalFileLocation(_ application: XCUIApplication) {
      let localLocation = application.cells.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "DOC.sidebar.item.On My ")
      ).firstMatch
      if localLocation.exists && localLocation.isHittable {
        localLocation.activateForPlannerJourney()
      }
    }
  #endif

  func testCancelingNativeBackupImportKeepsSettingsAvailableAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSettings(application)
    let importBackup = application.plannerElement("saved.settings.import")
    XCTAssertTrue(importBackup.waitForExistence(timeout: 10))
    importBackup.activateForPlannerJourney()
    let cancel = application.buttons.matching(NSPredicate(format: "label == %@", "Cancel"))
      .firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 10))
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "Native backup import picker"
    capture.lifetime = .keepAlways
    add(capture)
    cancel.activateForPlannerJourney()
    XCTAssertTrue(importBackup.waitForPlannerHittability())
    XCTAssertTrue(importBackup.isEnabled)
    XCTAssertFalse(application.alerts["Backup import failed"].exists)
    application.terminate()
    application.launchSavedPlannerJourney()
    openSettings(application)
    XCTAssertTrue(application.plannerElement("saved.settings.import").waitForExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement("saved.settings.export").isEnabled)
  }

  private func openSettings(_ application: XCUIApplication) {
    #if os(macOS)
      application.typeKey(",", modifierFlags: .command)
    #else
      let settings = application.plannerElement("saved.settings.open")
      if !settings.waitForExistence(timeout: 2) || !settings.isHittable {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists { sidebar.activateForPlannerJourney() }
      }
      XCTAssertTrue(settings.waitForExistence(timeout: 10))
      settings.activateForPlannerJourney()
    #endif
    XCTAssertTrue(application.plannerElement("saved.settings.labels").waitForExistence(timeout: 10))
  }

  private func recordImport(_ application: XCUIApplication, name: String) {
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = name
    capture.lifetime = .keepAlways
    add(capture)
  }

  private func revealImportElement(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<8 {
      if element.exists && element.isHittable { return }
      application.collectionViews["saved.import.form"].swipeUp()
    }
    XCTAssertTrue(element.exists && element.isHittable)
  }
}
