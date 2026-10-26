import AppIntentsTesting
import XCTest

@MainActor
final class SavedAppIntentJourneyTests: XCTestCase {
  #if os(iOS)
    func testInstalledShortcutsDiscoversTheFourPlannerAppShortcuts() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let shortcuts = openPlannerShortcutsCatalog()
      recordShortcutsWindow(shortcuts, name: "Installed Shortcuts Planner catalog")
    }

    func testSystemShortcutsFindReadsTheCurrentItemAndPreservesItThroughRelaunch() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      let itemTitle = "System read " + UUID().uuidString
      title.activateForPlannerJourney()
      title.typeText(itemTitle)
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      let completion = application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let itemBack = application.navigationBars.buttons["Items"].firstMatch
      if itemBack.exists { itemBack.activateForPlannerJourney() }
      let itemRow = application.savedPlannerItemRows(itemTitle).firstMatch
      XCTAssertTrue(itemRow.waitForExistence(timeout: 5))
      let itemIdentifier = itemRow.identifier

      let shortcuts = openPlannerShortcutsCatalog()
      shortcuts.buttons["checklist"].firstMatch.press(forDuration: 1)
      let newShortcut = shortcuts.buttons["New Shortcut"].firstMatch
      XCTAssertTrue(newShortcut.waitForExistence(timeout: 5))
      newShortcut.activateForPlannerJourney()
      let editor = shortcuts.buttons["Editor"].firstMatch
      if editor.waitForExistence(timeout: 5) { editor.activateForPlannerJourney() }
      XCTAssertTrue(
        shortcuts.staticTexts["Find Planner Items"].firstMatch.waitForExistence(timeout: 5))
      let actionsMenu = shortcuts.buttons.containing(
        NSPredicate(format: "label ENDSWITH %@", "Actions Menu")
      ).firstMatch
      actionsMenu.activateForPlannerJourney()
      let rename = shortcuts.buttons["Rename"].firstMatch
      XCTAssertTrue(rename.waitForExistence(timeout: 5))
      rename.activateForPlannerJourney()
      let workflowName = "Planner UI " + String(UUID().uuidString.prefix(8))
      let name = shortcuts.navigationBars.textFields.firstMatch
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      name.buttons["Clear text"].activateForPlannerJourney()
      name.typeText(workflowName + "\n")
      let search = shortcuts.searchFields["Search"].firstMatch
      search.activateForPlannerJourney()
      search.typeText("Show Result")
      let showContent = shortcuts.staticTexts["Show Content"].firstMatch
      XCTAssertTrue(showContent.waitForExistence(timeout: 5))
      showContent.activateForPlannerJourney()
      shortcuts.buttons["play"].firstMatch.activateForPlannerJourney()
      let resultService = XCUIApplication(bundleIdentifier: "com.apple.ShortcutsUI")
      XCTAssertTrue(resultService.staticTexts[itemTitle].firstMatch.waitForExistence(timeout: 20))
      recordShortcutsWindow(resultService, name: "Installed Shortcuts exact current Item result")
      resultService.buttons["Done"].firstMatch.activateForPlannerJourney()

      shortcuts.navigationBars.buttons["Back"].firstMatch.activateForPlannerJourney()
      let workflow = shortcuts.buttons["Play, " + workflowName].firstMatch
      if !workflow.exists {
        let library = shortcuts.navigationBars.buttons["Library"].firstMatch
        if library.exists { library.activateForPlannerJourney() }
        let allShortcuts = shortcuts.buttons["All Shortcuts"].firstMatch
        if allShortcuts.exists { allShortcuts.activateForPlannerJourney() }
      }
      XCTAssertTrue(workflow.waitForExistence(timeout: 5))
      workflow.press(forDuration: 1)
      shortcuts.buttons["Delete"].firstMatch.activateForPlannerJourney()
      let deleteShortcut = shortcuts.buttons["Delete Shortcut"].firstMatch
      XCTAssertTrue(deleteShortcut.waitForExistence(timeout: 5))
      deleteShortcut.activateForPlannerJourney()
      shortcuts.launch()
      let library = shortcuts.navigationBars.buttons["Library"].firstMatch
      if library.exists { library.activateForPlannerJourney() }
      let allShortcuts = shortcuts.buttons["All Shortcuts"].firstMatch
      XCTAssertTrue(allShortcuts.waitForExistence(timeout: 5))
      allShortcuts.activateForPlannerJourney()
      XCTAssertFalse(shortcuts.buttons["Play, " + workflowName].firstMatch.exists)

      application.activate()
      let savedRow = application.plannerElement(itemIdentifier)
      XCTAssertTrue(savedRow.waitForExistence(timeout: 5))
      savedRow.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(savedRow.waitForExistence(timeout: 5))
      savedRow.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    }

    private func openPlannerShortcutsCatalog() -> XCUIApplication {
      let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
      shortcuts.launch()
      XCTAssertEqual(shortcuts.state, .runningForeground)
      XCTAssertTrue(shortcuts.windows.firstMatch.waitForExistence(timeout: 10))
      let continueButton = shortcuts.buttons["Continue"].firstMatch
      if continueButton.exists { continueButton.activateForPlannerJourney() }
      let library = shortcuts.navigationBars.buttons["Library"].firstMatch
      if library.exists { library.activateForPlannerJourney() }
      let showSidebar = shortcuts.buttons["Show Sidebar"].firstMatch
      if showSidebar.exists { showSidebar.activateForPlannerJourney() }
      let planner = shortcuts.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", "Planner")
      ).firstMatch
      XCTAssertTrue(planner.waitForExistence(timeout: 10))
      planner.activateForPlannerJourney()
      for title in ["Create item", "Find items", "Find lists", "Find itineraries"] {
        XCTAssertTrue(shortcuts.staticTexts[title].firstMatch.waitForExistence(timeout: 5))
      }
      return shortcuts
    }

    private func recordShortcutsWindow(_ shortcuts: XCUIApplication, name: String) {
      let screenshot = XCTAttachment(screenshot: shortcuts.windows.firstMatch.screenshot())
      screenshot.name = name + " native window"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      let hierarchy = XCTAttachment(string: shortcuts.debugDescription)
      hierarchy.name = name + " native hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
  #endif

  func testCreateIntentReturnsTheSameSavedItemReadByNativeDetailsAfterRelaunch() async throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let definitions = IntentDefinitions(bundleIdentifier: "org.example.PlannerMCPPrototype")
    let creation = definitions.intents["CreatePlannerItemIntent"].makeIntent(
      title: "Train tickets", notes: "Collect at the station")
    let response: ResolvedIntentResult
    do {
      response = try await creation.run()
    } catch {
      let failure = error as NSError
      if failure.domain == "AppIntentsServicesSecurityErrorDomain", failure.code == 803 {
        throw XCTSkip(
          "The installed Apple test service rejects this Customer runtime before Planner runs: \(failure.localizedDescription)"
        )
      }
      throw error
    }
    let item: AnyAppEntity = try response.value
    let title: String = try item.title
    let done: Bool = try item.done
    XCTAssertEqual(title, "Train tickets")
    XCTAssertFalse(done)
    let identifier = try XCTUnwrap(UUID(uuidString: item.identifier.instanceIdentifier))
    application.openPlannerSection("Items")
    let row = application.plannerElement("saved.item.\(identifier.uuidString)")
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Collect at the station"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    let read = definitions.intents["GetPlannerItemIntent"].makeIntent(item: item)
    let restoredResponse = try await read.run()
    let restored: AnyAppEntity = try restoredResponse.value
    let restoredTitle: String = try restored.title
    XCTAssertEqual(restored.identifier, item.identifier)
    XCTAssertEqual(restoredTitle, "Train tickets")
  }
}
