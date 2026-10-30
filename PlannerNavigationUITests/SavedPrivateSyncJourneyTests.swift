#if os(iOS) && !targetEnvironment(simulator)
  import XCTest

  @MainActor
  final class SavedPrivateSyncJourneyTests: XCTestCase {
    /// Runs on an iPhone sharing its iCloud account with the paired iPad.
    func testPhysicalIPhoneCreatesAndReceivesTheIPadEditAndDeletion() throws {
      let runIdentifier = ProcessInfo.processInfo.environment["PLANNER_PRIVATE_SYNC_RUN"] ?? ""
      try XCTSkipUnless(
        UUID(uuidString: runIdentifier) != nil, "Requires an attended two-device sync run.")
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      clearFilters(application)
      search(application, for: runIdentifier)
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 10))
      title.activateForPlannerJourney()
      title.typeText("Sync visit " + runIdentifier)
      let notes = application.textFields["saved.item.notes"]
      notes.activateForPlannerJourney()
      notes.typeText("Created on iPhone")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Created on iPhone"].waitForExistence(timeout: 10))
      let initialBack = application.navigationBars.buttons["Items"].firstMatch
      if initialBack.exists { initialBack.activateForPlannerJourney() }
      let original = application.savedPlannerItemRows("Sync visit " + runIdentifier).firstMatch
      XCTAssertTrue(original.waitForExistence(timeout: 10))
      let identity = original.identifier
      print("PLANNER_SYNC_PHASE iPhone-created \(identity)")
      original.activateForPlannerJourney()
      capture(application, "Physical iPhone saves the synthetic sync Item")
      XCTAssertTrue(
        application.staticTexts["Edited on iPad"].waitForExistence(timeout: 180),
        "The open iPhone must receive the iPad edit.")
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Edit item").activateForPlannerJourney()
      let editedTitle = application.textFields["saved.item.edit.title"]
      XCTAssertTrue(editedTitle.waitForExistence(timeout: 10))
      editedTitle.activateForPlannerJourney()
      editedTitle.typeKey("a", modifierFlags: .command)
      editedTitle.typeText("Synced visit " + runIdentifier)
      XCTAssertTrue(editedTitle.waitForPlannerValue("Synced visit " + runIdentifier))
      XCTAssertTrue(
        application.textFields["saved.item.edit.notes"].waitForPlannerValue("Edited on iPad"))
      application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      let row = application.savedPlannerItemRows("Synced visit " + runIdentifier).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      XCTAssertTrue(
        row.waitForNonExistence(timeout: 180), "The open iPhone must receive the deletion.")
      capture(application, "Physical iPhone receives the exact Item deletion")
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      search(application, for: runIdentifier)
      XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 30))
      XCTAssertFalse(application.buttons.matching(identifier: identity).firstMatch.exists)
      clearSearch(application)
    }

    func testPhysicalPrivateSyncStatusAndExplicitRetry() throws {
      try XCTSkipUnless(
        ProcessInfo.processInfo.environment["PLANNER_PRIVATE_SYNC_RUN"] != nil,
        "Requires an attended private-sync run.")
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchSavedPlannerJourney()
      application.openSavedPlannerSettings()
      let status = application.staticTexts["saved.settings.sync.status"].firstMatch
      XCTAssertTrue(status.waitForExistence(timeout: 30))
      print("PLANNER_SYNC_STATUS before: \(status.label)")
      capture(application, "Physical private-sync status before explicit retry")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Physical private-sync Settings"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      let retry = application.plannerElement("saved.settings.sync.retry")
      XCTAssertTrue(retry.isEnabled)
      retry.activateForPlannerJourney()
      let finished = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"), object: retry)
      XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 30), .completed)
      print("PLANNER_SYNC_STATUS after: \(status.label)")
      capture(application, "Physical private-sync status after explicit retry")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.openPlannerSection("Items")
      capture(application, "Physical catalog after explicit private sync")
    }

    /// Uses normal installed storage and the paired iPhone's unique Item.
    func testPhysicalIPadReceivesEditsAndDeletesTheExactIPhoneItem() throws {
      let runIdentifier = ProcessInfo.processInfo.environment["PLANNER_PRIVATE_SYNC_RUN"] ?? ""
      try XCTSkipUnless(
        UUID(uuidString: runIdentifier) != nil, "Requires an attended two-device sync run.")
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      clearFilters(application)
      search(application, for: runIdentifier)
      let row = application.savedPlannerItemRows("Sync visit " + runIdentifier).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 180), "The iPad must receive the iPhone Item.")
      let identity = row.identifier
      print("PLANNER_SYNC_PHASE iPad-received \(identity)")
      row.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Created on iPhone"].waitForExistence(timeout: 10))
      capture(application, "Physical iPad receives the exact iPhone Item")
      editNotes(application, to: "Edited on iPad")
      let updated = application.savedPlannerItemRows("Synced visit " + runIdentifier).firstMatch
      XCTAssertTrue(
        updated.waitForExistence(timeout: 180), "The open iPad must receive the iPhone title edit.")
      XCTAssertEqual(updated.identifier, identity)
      XCTAssertTrue(application.staticTexts["Edited on iPad"].exists)
      capture(application, "iPhone title and iPad notes converge without relaunch")
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      search(application, for: runIdentifier)
      XCTAssertTrue(updated.waitForExistence(timeout: 30))
      XCTAssertEqual(updated.identifier, identity)
      updated.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Edited on iPad"].waitForExistence(timeout: 10))
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("saved.item.delete").activateForPlannerJourney()
      let confirmation = application.plannerElement("saved.item.delete.confirm")
      XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
      confirmation.activateForPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(updated.waitForNonExistence(timeout: 15))
      capture(application, "Physical iPad removes only the integrated-sync Item")
      clearSearch(application)
    }

    /// The human changes only Planner's iCloud switch at the announced phases.
    func testPhysicalIPadKeepsLocalEditsThroughPrivateICloudOffOn() throws {
      let runIdentifier = ProcessInfo.processInfo.environment["PLANNER_PRIVATE_SYNC_RUN"] ?? ""
      try XCTSkipUnless(
        UUID(uuidString: runIdentifier) != nil, "Requires an attended private-sync transition.")
      continueAfterFailure = false
      executionTimeAllowance = 2400
      let application = XCUIApplication()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      clearFilters(application)
      search(application, for: runIdentifier)
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 10))
      title.activateForPlannerJourney()
      title.typeText("Offline visit " + runIdentifier)
      let notes = application.textFields["saved.item.notes"]
      notes.activateForPlannerJourney()
      notes.typeText("Before private iCloud off")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Before private iCloud off"].waitForExistence(timeout: 10))
      let row = application.savedPlannerItemRows("Offline visit " + runIdentifier).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      let identity = row.identifier
      application.openSavedPlannerSettings()
      XCTAssertTrue(
        privateSyncStatus(application, title: "Up to date with iCloud").waitForExistence(
          timeout: 120))
      capture(application, "Private iCloud acknowledged the transition fixture")
      print("PLANNER_SYNC_PHASE ready-to-disable \(identity)")
      XCTAssertTrue(
        privateSyncStatus(application, title: "iCloud unavailable").waitForExistence(timeout: 900))
      capture(application, "Planner observes private iCloud disabled")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.openPlannerSection("Items")
      search(application, for: runIdentifier)
      XCTAssertTrue(row.waitForExistence(timeout: 30))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      editNotes(application, to: "Saved while private iCloud off")
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      search(application, for: runIdentifier)
      XCTAssertTrue(row.waitForExistence(timeout: 30))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Saved while private iCloud off"].waitForExistence(timeout: 10))
      capture(application, "Offline edit and exact Item survive actual app relaunch")
      application.openSavedPlannerSettings()
      XCTAssertTrue(
        privateSyncStatus(application, title: "iCloud unavailable").waitForExistence(timeout: 30))
      print("PLANNER_SYNC_PHASE ready-to-enable \(identity)")
      XCTAssertTrue(
        privateSyncStatus(application, title: "Up to date with iCloud").waitForExistence(
          timeout: 900))
      capture(application, "Private synchronization resumes after Planner is reenabled")
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      application.openPlannerSection("Items")
      search(application, for: runIdentifier)
      XCTAssertTrue(row.waitForExistence(timeout: 30))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Verified after private iCloud resumed"].waitForExistence(
          timeout: 180))
      capture(application, "The resumed iPad receives the iPhone's verification edit")
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("saved.item.delete").activateForPlannerJourney()
      let confirmation = application.plannerElement("saved.item.delete.confirm")
      XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
      confirmation.activateForPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(row.waitForNonExistence(timeout: 15))
      clearSearch(application)
    }

    func testPhysicalIPhoneVerifiesTheIPadEditAfterPrivateICloudResumes() throws {
      let runIdentifier = ProcessInfo.processInfo.environment["PLANNER_PRIVATE_SYNC_RUN"] ?? ""
      try XCTSkipUnless(
        UUID(uuidString: runIdentifier) != nil, "Requires an attended private-sync transition.")
      continueAfterFailure = false
      executionTimeAllowance = 2400
      let application = XCUIApplication()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      clearFilters(application)
      search(application, for: runIdentifier)
      let row = application.savedPlannerItemRows("Offline visit " + runIdentifier).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 180))
      let identity = row.identifier
      row.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Before private iCloud off"].waitForExistence(timeout: 10))
      print("PLANNER_SYNC_PHASE peer-has-transition-fixture \(identity)")
      capture(application, "iPhone receives the fixture before private access changes")
      XCTAssertTrue(
        application.staticTexts["Saved while private iCloud off"].waitForExistence(timeout: 2100))
      capture(application, "iPhone receives the iPad's queued offline edit")
      editNotes(application, to: "Verified after private iCloud resumed")
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      XCTAssertTrue(row.waitForNonExistence(timeout: 180))
      capture(application, "iPhone receives final transition-fixture cleanup")
      clearSearch(application)
    }

    private func privateSyncStatus(_ application: XCUIApplication, title: String) -> XCUIElement {
      application.staticTexts.matching(
        NSPredicate(format: "identifier == %@ AND label == %@", "saved.settings.sync.status", title)
      ).firstMatch
    }

    /// Qualifies native text replacement before deleting only an explicitly selected test Item.
    func testReplaceAndRemoveOnlyTheExactPrivateSyncFixture() throws {
      let environment = ProcessInfo.processInfo.environment
      let runIdentifier = environment["PLANNER_PRIVATE_SYNC_RUN"] ?? ""
      let sourceIdentifier = environment["PLANNER_PRIVATE_SYNC_FIXTURE_ID"] ?? ""
      try XCTSkipUnless(
        UUID(uuidString: runIdentifier) != nil && UUID(uuidString: sourceIdentifier) != nil,
        "Requires an explicit synthetic sync fixture for native cleanup.")
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      clearFilters(application)
      search(application, for: runIdentifier)
      let row = application.buttons["saved.item." + sourceIdentifier].firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 30))
      XCTAssertTrue(row.label.contains(runIdentifier))
      row.activateForPlannerJourney()
      editNotes(application, to: "Verified native replacement")
      capture(application, "Native Select All replaces the exact fixture's complete notes")
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("saved.item.delete").activateForPlannerJourney()
      let confirmation = application.plannerElement("saved.item.delete.confirm")
      XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
      confirmation.activateForPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(row.waitForNonExistence(timeout: 15))
      clearSearch(application)
    }

    private func editNotes(_ application: XCUIApplication, to value: String) {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Edit item").activateForPlannerJourney()
      let notes = application.textFields["saved.item.edit.notes"]
      XCTAssertTrue(notes.waitForExistence(timeout: 10))
      notes.activateForPlannerJourney()
      notes.typeKey("a", modifierFlags: .command)
      notes.typeText(value)
      XCTAssertTrue(notes.waitForPlannerValue(value))
      let save = application.plannerElement("saved.item.edit.save")
      XCTAssertTrue(
        save.waitForPlannerHittability(), "Save must be visible and unobstructed before submission."
      )
      save.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts[value].waitForExistence(timeout: 10))
    }

    private func clearFilters(_ application: XCUIApplication) {
      application.plannerElement("saved.items.filters").activateForPlannerJourney()
      let clear = application.plannerElement("saved.filters.clear")
      if clear.isEnabled { clear.activateForPlannerJourney() }
      application.plannerElement("saved.filters.done").activateForPlannerJourney()
    }

    private func search(_ application: XCUIApplication, for query: String) {
      clearSearch(application)
      let field = application.searchFields["Search Items"].firstMatch
      XCTAssertTrue(field.waitForExistence(timeout: 10))
      field.activateForPlannerJourney()
      field.typeText(query)
    }

    private func clearSearch(_ application: XCUIApplication) {
      let clear = application.searchFields["Search Items"].buttons["Clear text"].firstMatch
      if clear.exists { clear.activateForPlannerJourney() }
    }

    private func capture(_ application: XCUIApplication, _ name: String) {
      let attachment = XCTAttachment(screenshot: application.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
