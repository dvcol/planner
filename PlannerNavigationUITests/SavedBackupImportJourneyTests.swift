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

  #endif

  func testLabelAppearancePreservesCustomValuesAndClearsOnlyExplicitChanges() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSettings(application)
    selectBackup("Planner label appearance backup.json", application: application)
    #if os(macOS)
      let additions = application.plannerElement("saved.import.summary.additions")
    #else
      let additions = application.staticTexts["saved.import.summary.additions"]
    #endif
    XCTAssertTrue(additions.waitForExistence(timeout: 15))
    #if os(macOS)
      XCTAssertEqual(additions.value as? String, "7")
    #else
      XCTAssertEqual(additions.label, "Additions, 7")
    #endif
    application.plannerElement("saved.import.confirm").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
    application.plannerElement("saved.import.close").activateForPlannerJourney()
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    let categoryIdentifier = "saved.category.00000000-0000-4000-8000-000000000501"
    let tagIdentifier = "saved.tag.00000000-0000-4000-8000-000000000601"
    for (kind, identifier, newName) in [
      ("category", categoryIdentifier, "Dining custom"), ("tag", tagIdentifier, "Weather custom"),
    ] {
      let row = application.plannerElement(identifier)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      row.activateForPlannerJourney()
      let name = application.textFields["saved.\(kind).name"]
      XCTAssertTrue(name.waitForExistence(timeout: 10))
      XCTAssertEqual(
        application.plannerElement("saved.\(kind).icon").value as? String, "Current icon")
      let color = labelColorToggle(kind, application: application)
      XCTAssertTrue(color.waitForPlannerBooleanState(true))
      name.activateForPlannerJourney()
      #if os(macOS)
        name.typeKey("a", modifierFlags: .command)
      #else
        let oldName = try XCTUnwrap(name.value as? String)
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldName.count))
      #endif
      name.typeText(newName)
      application.plannerElement("saved.\(kind).save").activateForPlannerJourney()
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      #if os(macOS)
        XCTAssertTrue(row.label == newName || row.value as? String == newName)
      #else
        XCTAssertEqual(row.label, newName)
      #endif
    }
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    let unchangedFilename = exportBackup(application)
    let unchanged = XCTAttachment(string: unchangedFilename)
    unchanged.name = "Label appearance name-only delivered backup filename"
    unchanged.lifetime = .keepAlways
    add(unchanged)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    application.plannerElement(categoryIdentifier).activateForPlannerJourney()
    let icon = application.plannerElement("saved.category.icon")
    let color = labelColorToggle("category", application: application)
    XCTAssertTrue(icon.waitForExistence(timeout: 10))
    XCTAssertEqual(icon.value as? String, "Current icon")
    XCTAssertTrue(color.waitForPlannerBooleanState(true))
    recordImport(
      application, name: "Imported custom symbol and color remain after name-only Save")
    color.activateForPlannerJourney()
    icon.activateForPlannerJourney()
    application.plannerElement("Default").activateForPlannerJourney()
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    application.plannerElement(categoryIdentifier).activateForPlannerJourney()
    XCTAssertTrue(icon.waitForExistence(timeout: 10))
    XCTAssertEqual(icon.value as? String, "Current icon")
    XCTAssertTrue(color.waitForPlannerBooleanState(true))
    color.activateForPlannerJourney()
    icon.activateForPlannerJourney()
    application.plannerElement("Default").activateForPlannerJourney()
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(categoryIdentifier).waitForExistence(timeout: 10))
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    let clearedFilename = exportBackup(application)
    XCTAssertNotEqual(clearedFilename, unchangedFilename)
    let cleared = XCTAttachment(string: clearedFilename)
    cleared.name = "Label appearance cleared delivered backup filename"
    cleared.lifetime = .keepAlways
    add(cleared)
    closeSettings(application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    application.plannerElement(categoryIdentifier).activateForPlannerJourney()
    XCTAssertTrue(icon.waitForExistence(timeout: 10))
    XCTAssertEqual(icon.value as? String, "Default")
    XCTAssertTrue(color.waitForPlannerBooleanState(false))
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    application.plannerElement(tagIdentifier).activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.tag.icon").waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement("saved.tag.icon").value as? String, "Current icon")
    XCTAssertTrue(
      labelColorToggle("tag", application: application).waitForPlannerBooleanState(true))
    recordImport(application, name: "Only the explicitly cleared Category loses its appearance")
    application.plannerElement("saved.tag.cancel").activateForPlannerJourney()
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    closeSettings(application)
    application.openPlannerSection("Items")
    let museum = application.plannerElement("saved.item.00000000-0000-4000-8000-000000000101")
    XCTAssertTrue(museum.waitForExistence(timeout: 15))
    museum.activateForPlannerJourney()
    let category = application.staticTexts["Dining custom"]
    let tag = application.staticTexts["Weather custom"]
    XCTAssertTrue(category.waitForExistence(timeout: 10))
    XCTAssertTrue(tag.waitForExistence(timeout: 10))
    #if os(iOS)
      let tabBar = application.tabBars.firstMatch
      if tabBar.exists {
        let form = try XCTUnwrap(
          application.collectionViews.allElementsBoundByIndex.first {
            $0.isHittable
          })
        form.swipeUp(velocity: .slow)
      }
    #endif
    for label in [category, tag] {
      XCTAssertTrue(label.waitForPlannerHittability())
      XCTAssertTrue(application.windows.firstMatch.frame.contains(label.frame))
      #if os(iOS)
        if tabBar.exists { XCTAssertLessThanOrEqual(label.frame.maxY, tabBar.frame.minY) }
      #endif
    }
    recordImport(application, name: "Live shared labels remain in the original Item details")
  }

  #if os(iOS)
    func testFullGraphFileImportPreservesScopedStateAndExportsItsSavedData() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      selectBackup("Planner full graph backup.json", application: application)
      let additions = application.staticTexts["saved.import.summary.additions"]
      XCTAssertTrue(additions.waitForExistence(timeout: 15))
      XCTAssertEqual(additions.label, "Additions, 7")
      recordImport(application, name: "Full graph backup reviews all seven source additions")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      let filename = exportBackup(application)
      let exportedFilename = XCTAttachment(string: filename)
      exportedFilename.name = "Full graph delivered backup filename"
      exportedFilename.lifetime = .keepAlways
      add(exportedFilename)
      recordImport(application, name: "Full graph backup is delivered through the native exporter")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let museum = application.plannerElement("saved.item.00000000-0000-4000-8000-000000000101")
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      XCTAssertEqual(museum.label, "Nezu Museum")
      XCTAssertTrue((museum.value as? String)?.contains("Food") == true)
      XCTAssertTrue((museum.value as? String)?.contains("rainy-day") == true)
      museum.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
      let globalCompletion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(globalCompletion.waitForExistence(timeout: 5))
      XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
      recordImport(
        application, name: "Full graph Item keeps its shared labels notes and global Todo")
      application.openPlannerSection("Lists")
      openImportedCatalogRow(
        application.savedPlannerListRow("Tokyo Food"), application: application)
      let listFilters = application.plannerElement("saved.list.filters")
      application.chooseSavedPlannerStateFilter("All completion states", control: listFilters)
      application.chooseSavedPlannerStateFilter("All archive states", control: listFilters)
      XCTAssertTrue(application.staticTexts["2 of 2 items finished"].waitForExistence(timeout: 10))
      XCTAssertTrue(
        application.plannerElement(
          "saved.appearance.completion.00000000-0000-4000-8000-000000000401"
        )
        .waitForPlannerValue("Completed"))
      recordImport(application, name: "Full graph List retains local Done and archived progress")
      application.openPlannerSection("Lists")
      openImportedCatalogRow(application.savedPlannerListRow("Wishlist"), application: application)
      XCTAssertTrue(
        application.plannerElement(
          "saved.appearance.completion.00000000-0000-4000-8000-000000000403"
        )
        .waitForPlannerValue("To do"))
      recordImport(
        application, name: "Full graph second List keeps its independent Todo appearance")
      application.openPlannerSection("Itineraries")
      openImportedCatalogRow(
        application.plannerElement("saved.itinerary.row.00000000-0000-4000-8000-000000000301"),
        application: application)
      XCTAssertTrue(application.staticTexts["1 of 3 items finished"].waitForExistence(timeout: 10))
      recordImport(
        application, name: "Full graph Itinerary keeps its independent three appearances")
    }

    func testApprovedRestorationImportsKeepCurrentFamiliesAndOverwritePredecessorValues() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      selectBackup("Planner approved current family.json", application: application)
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      selectBackup("Planner unknown candidate.json", application: application)
      let additions = application.staticTexts["saved.import.summary.additions"]
      revealImportElement(additions, application: application)
      XCTAssertEqual(additions.label, "Additions, 1")
      let conflicts = application.staticTexts["saved.import.summary.conflicts"]
      revealImportElement(conflicts, application: application)
      XCTAssertEqual(conflicts.label, "Skipped conflicts, 1")
      let dependents = application.staticTexts["saved.import.summary.dependents"]
      revealImportElement(dependents, application: application)
      XCTAssertEqual(dependents.label, "Skipped dependents, 2")
      let tour = application.plannerElement(
        "saved.import.entry.dependents.list.00000000-0000-4000-8000-000000000277")
      revealImportElement(tour, application: application)
      for _ in 0..<4 {
        if tour.frame.maxY < application.windows.firstMatch.frame.maxY - 100 { break }
        application.collectionViews["saved.import.form"].swipeUp(velocity: .slow)
      }
      tour.activateForPlannerJourney()
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Approved import dependency hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      recordImport(
        application, name: "Approved import Skip explains unavailable candidate dependencies")
      let explanation = application.staticTexts[
        "A required record is unavailable in this import, so this dependent record is skipped."]
      revealImportElement(explanation, application: application)
      XCTAssertTrue(explanation.exists)
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      let skipped = XCTAttachment(string: exportBackup(application))
      skipped.name = "Approved import Skip delivered backup filename"
      skipped.lifetime = .keepAlways
      add(skipped)
      selectBackup("Planner closed predecessor.json", application: application)
      application.plannerElement("saved.import.mode").activateForPlannerJourney()
      application.plannerElement("Overwrite").activateForPlannerJourney()
      let replacements = application.staticTexts["saved.import.summary.replacements"]
      revealImportElement(replacements, application: application)
      XCTAssertEqual(replacements.label, "Replacements, 1")
      recordImport(application, name: "Approved import Overwrite reviews the current live owner")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      let overwritten = XCTAttachment(string: exportBackup(application))
      overwritten.name = "Approved import Overwrite delivered backup filename"
      overwritten.lifetime = .keepAlways
      add(overwritten)
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let museum = application.plannerElement("saved.item.00000000-0000-4000-8000-000000000101")
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      museum.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
      recordImport(application, name: "Approved import restored values survive relaunch")
      application.openPlannerSection("Lists")
      openImportedCatalogRow(
        application.savedPlannerListRow("Tokyo Food"), application: application)
      let filters = application.plannerElement("saved.list.filters")
      application.chooseSavedPlannerStateFilter("All completion states", control: filters)
      application.chooseSavedPlannerStateFilter("All archive states", control: filters)
      XCTAssertTrue(application.staticTexts["2 of 2 items finished"].waitForExistence(timeout: 10))
      XCTAssertTrue(
        application.plannerElement(
          "saved.appearance.completion.00000000-0000-4000-8000-000000000401"
        )
        .waitForPlannerValue("Completed"))
      recordImport(
        application, name: "Approved import preserves the omitted List and local completion")
    }

    func testFullGraphSkipPreservesCurrentOwnersAndOverwriteReplacesScopedState() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      selectBackup("Planner full graph backup.json", application: application)
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()

      for mode in ["Skip", "Overwrite"] {
        selectBackup("Planner conflicting graph backup.json", application: application)
        if mode == "Overwrite" {
          application.plannerElement("saved.import.mode").activateForPlannerJourney()
          application.plannerElement("Overwrite").activateForPlannerJourney()
        }
        let additions = application.staticTexts["saved.import.summary.additions"]
        revealImportElement(additions, application: application)
        XCTAssertEqual(additions.label, mode == "Skip" ? "Additions, 1" : "Additions, 0")
        let impactIdentifier = mode == "Skip" ? "conflicts" : "replacements"
        let impact = application.staticTexts["saved.import.summary." + impactIdentifier]
        revealImportElement(impact, application: application)
        XCTAssertEqual(impact.label, mode == "Skip" ? "Skipped conflicts, 2" : "Replacements, 2")
        recordImport(application, name: "Conflicting graph \(mode) reviews two complete owners")
        application.plannerElement("saved.import.confirm").activateForPlannerJourney()
        XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
        application.plannerElement("saved.import.close").activateForPlannerJourney()
        let filename = exportBackup(application)
        let attachment = XCTAttachment(string: filename)
        attachment.name = "Conflicting graph \(mode) delivered backup filename"
        attachment.lifetime = .keepAlways
        add(attachment)
      }

      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.openPlannerSection("Lists")
      openImportedCatalogRow(
        application.savedPlannerListRow("Revised Tokyo Food"), application: application)
      let filters = application.plannerElement("saved.list.filters")
      application.chooseSavedPlannerStateFilter("All completion states", control: filters)
      application.chooseSavedPlannerStateFilter("All archive states", control: filters)
      XCTAssertTrue(
        application.plannerElement(
          "saved.appearance.completion.00000000-0000-4000-8000-000000000401"
        ).waitForPlannerValue("To do"))
      XCTAssertTrue(application.staticTexts["1 of 2 items finished"].waitForExistence(timeout: 10))
      recordImport(
        application, name: "Conflicting graph Overwrite retains the exact List appearance")
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(
        application.plannerElement("saved.item.00000000-0000-4000-8000-000000000103")
          .waitForExistence(timeout: 15))
      let museum = application.plannerElement("saved.item.00000000-0000-4000-8000-000000000101")
      XCTAssertTrue(museum.waitForExistence(timeout: 10))
      museum.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Incoming museum notes"].waitForExistence(timeout: 10))
      recordImport(
        application,
        name: "Conflicting graph keeps the addition and overwritten notes after relaunch")
    }

    func testDeletedGraphItemNeedsExplicitRestorationAndKeepsItsIndependentAppearances() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      selectBackup("Planner full graph backup.json", application: application)
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.openPlannerSection("Items")
      let museum = application.plannerElement("saved.item.00000000-0000-4000-8000-000000000101")
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      museum.activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("saved.item.delete").activateForPlannerJourney()
      let deletion = application.plannerElement("saved.item.delete.confirm")
      XCTAssertTrue(deletion.waitForExistence(timeout: 10))
      deletion.activateForPlannerJourney()
      XCTAssertTrue(deletion.waitForNonExistence(timeout: 10))
      application.openPlannerSection("Lists")
      openSettings(application)
      selectBackup("Planner full graph backup.json", application: application)
      application.plannerElement("saved.import.mode").activateForPlannerJourney()
      application.plannerElement("Overwrite").activateForPlannerJourney()
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      let authorizationFailure = application.staticTexts[
        "Deleted data needs separate reviewed restoration."]
      revealImportElement(authorizationFailure, application: application)
      XCTAssertTrue(authorizationFailure.waitForExistence(timeout: 15))
      XCTAssertFalse(application.staticTexts["saved.import.applied"].exists)
      recordImport(application, name: "Graph restoration requires separate authorization")
      let closeReview = application.plannerElement("saved.import.close")
      closeReview.activateForPlannerJourney()
      XCTAssertTrue(closeReview.waitForNonExistence(timeout: 10))
      let closeSettings = application.plannerElement("saved.settings.done")
      XCTAssertTrue(closeSettings.waitForPlannerHittability())
      closeSettings.activateForPlannerJourney()
      XCTAssertTrue(closeSettings.waitForNonExistence(timeout: 10))
      application.openPlannerSection("Items")
      let itemFilters = application.plannerElement("saved.items.filters")
      application.chooseSavedPlannerStateFilter("All completion states", control: itemFilters)
      application.chooseSavedPlannerStateFilter("All archive states", control: itemFilters)
      XCTAssertTrue(
        application.plannerElement("saved.item.00000000-0000-4000-8000-000000000102")
          .waitForExistence(timeout: 15))
      XCTAssertFalse(museum.exists)
      recordImport(application, name: "Graph restoration rejection leaves the Item deleted")
      application.openPlannerSection("Lists")
      openSettings(application)
      selectBackup("Planner full graph backup.json", application: application)
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
      recordImport(application, name: "Graph restoration explicitly reviews the deleted Item")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.import.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      museum.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
      let completion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(completion.waitForExistence(timeout: 5))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      XCTAssertTrue(
        application.descendants(matching: .any).matching(
          identifier: "saved.item.schedule.00000000-0000-4000-8000-000000000701"
        ).firstMatch.waitForExistence(timeout: 10))
      recordImport(
        application, name: "Graph restoration retains shared Item and Schedule identities")
      application.openPlannerSection("Lists")
      openImportedCatalogRow(
        application.savedPlannerListRow("Tokyo Food"), application: application)
      XCTAssertTrue(
        application.plannerElement(
          "saved.appearance.completion.00000000-0000-4000-8000-000000000401"
        ).waitForPlannerValue("Completed"))
      recordImport(application, name: "Graph restoration retains the first membership Done state")
      application.openPlannerSection("Lists")
      openImportedCatalogRow(application.savedPlannerListRow("Wishlist"), application: application)
      XCTAssertTrue(
        application.plannerElement(
          "saved.appearance.completion.00000000-0000-4000-8000-000000000403"
        ).waitForPlannerValue("To do"))
      application.openPlannerSection("Itineraries")
      openImportedCatalogRow(
        application.plannerElement("saved.itinerary.row.00000000-0000-4000-8000-000000000301"),
        application: application)
      XCTAssertTrue(application.staticTexts["1 of 3 items finished"].waitForExistence(timeout: 10))
      recordImport(
        application, name: "Graph restoration keeps the other planning contexts independent")
    }

    private func openImportedCatalogRow(_ row: XCUIElement, application: XCUIApplication) {
      if !row.waitForExistence(timeout: 2) || !row.isHittable {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists {
          sidebar.activateForPlannerJourney()
        } else {
          let back = application.navigationBars.buttons["BackButton"].firstMatch
          if back.exists { back.activateForPlannerJourney() }
        }
      }
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      row.activateForPlannerJourney()
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
      return (tagIdentifier: tagIdentifier, filename: exportBackup(application))
    }

    private func exportBackup(_ application: XCUIApplication) -> String {
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
      return filename
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

  #if os(macOS)
    private func selectBackup(_ filename: String, application: XCUIApplication) {
      XCTAssertEqual(filename, "Planner label appearance backup.json")
      let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/native-label-appearance-backup.json")
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.path))
      application.plannerElement("saved.settings.import").activateForPlannerJourney()
      let open = application.sheets["open-panel"].buttons["OKButton"]
      XCTAssertTrue(open.waitForExistence(timeout: 10))
      navigateNativeFilePanel(to: fixture.path, application: application)
      open.activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.import.confirm").waitForExistence(timeout: 15))
    }

    private func exportBackup(_ application: XCUIApplication) -> String {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlannerNativeLabelExports-" + UUID().uuidString, isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
      } catch {
        XCTFail("Cannot create the test-owned export directory: \(error)")
      }
      let filename = "Planner label appearance export.json"
      let destination = directory.appendingPathComponent(filename)
      application.plannerElement("saved.settings.export").activateForPlannerJourney()
      let save = application.sheets["save-panel"].buttons["OKButton"]
      XCTAssertTrue(save.waitForExistence(timeout: 10))
      navigateNativeFilePanel(to: directory.path, application: application)
      let name = application.textFields["saveAsNameTextField"]
      recordFileFields(application, name: "Native Mac export filename fields")
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      name.activateForPlannerJourney()
      name.typeKey("a", modifierFlags: .command)
      name.typeText(filename)
      save.activateForPlannerJourney()
      let exported = application.plannerElement("saved.settings.exported")
      XCTAssertTrue(exported.waitForExistence(timeout: 10))
      XCTAssertEqual(exported.value as? String, filename)
      XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
      return destination.path
    }

    private func navigateNativeFilePanel(to path: String, application: XCUIApplication) {
      application.typeKey("g", modifierFlags: [.command, .shift])
      recordFileFields(application, name: "Native Mac Go to Folder fields")
      let field = application.textFields["PathTextField"]
      XCTAssertTrue(field.waitForExistence(timeout: 5))
      field.activateForPlannerJourney()
      field.typeKey("a", modifierFlags: .command)
      field.typeText(path + "\n")
      XCTAssertTrue(field.waitForNonExistence(timeout: 5))
    }

    private func recordFileFields(_ application: XCUIApplication, name: String) {
      let controls = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "elementType == %d OR elementType == %d",
          XCUIElement.ElementType.textField.rawValue,
          XCUIElement.ElementType.comboBox.rawValue)
      ).allElementsBoundByIndex
      let attachment = XCTAttachment(
        string: controls.map {
          "Identifier: \($0.identifier); element type: \($0.elementType.rawValue)"
        }.joined(separator: "\n"))
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  #endif

  private func labelColorToggle(_ kind: String, application: XCUIApplication) -> XCUIElement {
    #if os(macOS)
      application.switches["saved.\(kind).color.enabled"]
    #else
      application.switches["saved.\(kind).color.enabled"].switches.firstMatch
    #endif
  }

  private func closeSettings(_ application: XCUIApplication) {
    #if os(macOS)
      application.typeKey("w", modifierFlags: .command)
    #else
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
    #endif
  }

  func testCancelingNativeBackupImportKeepsSettingsAvailableAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSettings(application)
    let importBackup = application.plannerElement("saved.settings.import")
    XCTAssertTrue(importBackup.waitForExistence(timeout: 10))
    importBackup.activateForPlannerJourney()
    #if os(macOS)
      let cancel = application.sheets["open-panel"].buttons["CancelButton"]
    #else
      let cancel = application.buttons.matching(NSPredicate(format: "label == %@", "Cancel"))
        .firstMatch
    #endif
    XCTAssertTrue(cancel.waitForExistence(timeout: 10))
    #if os(macOS)
      let panel = application.sheets["open-panel"]
      let observation = XCTAttachment(
        string:
          "Open panel: \(panel.exists)\nCancel control: \(panel.buttons["CancelButton"].exists)\n")
      observation.name = "Native Mac import Cancel controls"
      observation.lifetime = .keepAlways
      add(observation)
    #else
      recordImport(application, name: "Native backup import picker")
    #endif
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
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = XCUIScreen.main.screenshot()
    #endif
    let capture = XCTAttachment(screenshot: screenshot)
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
