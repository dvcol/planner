import XCTest

@MainActor
final class SavedBackupImportJourneyTests: XCTestCase {
  #if os(iOS)
    func testRealBackupSkipAndOverwriteKeepTagIdentityAfterRelaunch() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      application.plannerElement("saved.labels.new").activateForPlannerJourney()
      application.plannerElement("New Tag").activateForPlannerJourney()
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

    private func selectBackup(_ filename: String, application: XCUIApplication) {
      application.plannerElement("saved.settings.import").activateForPlannerJourney()
      let documentName = String(filename.dropLast(".json".count))
      let document = application.descendants(matching: .any).matching(
        NSPredicate(format: "label BEGINSWITH %@", documentName)
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
      }
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Native picker for the actual exported file"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      XCTAssertTrue(document.waitForExistence(timeout: 15))
      document.activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.import.confirm").waitForExistence(timeout: 15))
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
      if !settings.waitForExistence(timeout: 2) {
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
