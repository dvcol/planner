import XCTest

/// Attended checks against installed TestFlight artifacts, without a fixture dataset or app reinstall.
@MainActor
final class ProductionMCPJourneyTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    let run = ProcessInfo.processInfo.environment["PLANNER_PRODUCTION_MCP_RUN"] ?? ""
    try XCTSkipUnless(UUID(uuidString: run) != nil, "Requires an attended Production MCP check.")
    continueAfterFailure = false
  }

  func testInstalledTestFlightCanBeInspected() {
    let application = XCUIApplication(bundleIdentifier: "com.apple.TestFlight")
    application.launch()
    record(application, name: "Installed TestFlight catalog")
  }

  #if os(iOS) && !targetEnvironment(simulator)
    func testProductionPhoneSharingCanBeInspectedWithoutChanges() {
      let application = XCUIApplication(bundleIdentifier: "dvcol.planner")
      application.activate()
      application.openSavedPlannerSettings()
      application.plannerElement("saved.settings.sharing").activateForPlannerJourney()
      XCTAssertTrue(application.buttons["saved.sharing.scope"].waitForExistence(timeout: 30))
      record(application, name: "Production owner sharing scope without changes")
    }

    func testProductionPhonePreparesWholeLibraryWithoutReplacingAnInvitation() {
      let application = XCUIApplication(bundleIdentifier: "dvcol.planner")
      application.activate()
      application.openSavedPlannerSettings()
      application.plannerElement("saved.settings.sharing").activateForPlannerJourney()
      let scope = application.buttons["saved.sharing.scope"]
      XCTAssertTrue(scope.waitForExistence(timeout: 30))
      record(application, name: "Production owner sharing scope before changes")
      if scope.staticTexts["Whole library"].exists {
        return
      }
      XCTAssertTrue(
        scope.staticTexts["Off"].exists,
        "An existing narrower invitation must be reviewed before replacement.")
      scope.activateForPlannerJourney()
      application.plannerElement("Whole library").activateForPlannerJourney()
      let apply = application.buttons["saved.sharing.apply"]
      let ready = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"), object: apply)
      XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
      apply.activateForPlannerJourney()
      XCTAssertTrue(
        application.otherElements["saved.sharing.invitation"].waitForExistence(timeout: 60))
      record(application, name: "Production whole-library invitation")
    }
  #endif

  #if os(macOS)
    func testProductionMacAcceptsTheExactInvitation() throws {
      let link = ProcessInfo.processInfo.environment["PLANNER_PRODUCTION_INVITATION"] ?? ""
      let url = try XCTUnwrap(URL(string: link))
      XCTAssertEqual(url.scheme, "https")
      XCTAssertTrue(["icloud.com", "www.icloud.com"].contains(url.host ?? ""))
      let application = XCUIApplication(bundleIdentifier: "dvcol.planner")
      application.activate()
      application.openSavedPlannerSettings()
      application.plannerElement("saved.settings.sharing").activateForPlannerJourney()
      let field = application.textFields["saved.sharing.join.url"]
      XCTAssertTrue(field.waitForExistence(timeout: 20))
      field.activateForPlannerJourney()
      field.typeKey("a", modifierFlags: .command)
      field.typeText(link)
      application.buttons["Accept invitation"].activateForPlannerJourney()
      let alert = application.alerts["Sharing"]
      XCTAssertTrue(alert.waitForExistence(timeout: 90))
      record(application, name: "Production invitation acceptance result")
      XCTAssertTrue(
        alert.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Library added."))
          .firstMatch.exists)
      alert.buttons["OK"].activateForPlannerJourney()
      record(application, name: "Production received libraries")
    }

    func testProductionMacSelectsTheReceivedLibraryAndEnablesMCP() throws {
      let identifier = ProcessInfo.processInfo.environment["PLANNER_PRODUCTION_LIBRARY"] ?? ""
      XCTAssertTrue(identifier.hasPrefix("saved.sharing.library.shared_"))
      let application = XCUIApplication(bundleIdentifier: "dvcol.planner")
      application.activate()
      application.openSavedPlannerSettings()
      application.plannerElement("saved.settings.sharing").activateForPlannerJourney()
      let library = application.buttons[identifier]
      XCTAssertTrue(library.waitForExistence(timeout: 30))
      XCTAssertTrue(library.label.contains("Can edit"))
      if library.isEnabled { library.activateForPlannerJourney() }
      let selected = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == false"), object: library)
      XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 30), .completed)
      application.buttons["Done"].activateForPlannerJourney()
      let enable = application.buttons["saved.agent.enable"]
      XCTAssertTrue(enable.waitForExistence(timeout: 10))
      enable.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["saved.agent.status"].waitForExistence(timeout: 20))
      XCTAssertTrue(application.staticTexts["saved.agent.connection"].exists)
      record(application, name: "Production shared-library MCP enabled")
    }
  #endif

  func testProductionMCPItemListAndBookingAppearInTheNativeApp() throws {
    let environment = ProcessInfo.processInfo.environment
    let listIdentifier = try XCTUnwrap(environment["PLANNER_PRODUCTION_LIST_ID"])
    let scheduleIdentifier = try XCTUnwrap(environment["PLANNER_PRODUCTION_SCHEDULE_ID"])
    let itemTitle = try XCTUnwrap(environment["PLANNER_PRODUCTION_ITEM_TITLE"])
    let listTitle = try XCTUnwrap(environment["PLANNER_PRODUCTION_LIST_TITLE"])
    let notes = try XCTUnwrap(environment["PLANNER_PRODUCTION_NOTES"])
    let application = XCUIApplication(bundleIdentifier: "dvcol.planner")
    application.activate()
    dismissSettings(application)
    application.openPlannerSection("Lists")
    let list = application.plannerElement("saved.list." + listIdentifier.uppercased())
    XCTAssertTrue(list.waitForExistence(timeout: 180), "The exact MCP-created List must arrive.")
    XCTAssertTrue(
      list.label.contains(listTitle) || (list.value as? String ?? "").contains(listTitle))
    list.activateForPlannerJourney()
    let item = application.savedPlannerItemRows(itemTitle).firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 30))
    item.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[notes].waitForExistence(timeout: 30))
    let schedule = application.plannerElement(
      "saved.item.schedule." + scheduleIdentifier.uppercased())
    XCTAssertTrue(schedule.waitForExistence(timeout: 30))
    let description = schedule.value as? String ?? ""
    XCTAssertTrue(description.contains("Tokyo"), description)
    record(application, name: "Production MCP Item, List and booking native readback")
    #if os(iOS)
      if let reply = environment["PLANNER_PRODUCTION_PHONE_REPLY"] {
        application.plannerElement("saved.item.actions").activateForPlannerJourney()
        application.plannerElement("Edit item").activateForPlannerJourney()
        let field = application.textFields["saved.item.edit.notes"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.activateForPlannerJourney()
        field.press(forDuration: 1)
        let selectAll = application.menuItems.matching(
          NSPredicate(format: "label IN %@", ["Select All", "Tout sélectionner"])
        ).firstMatch
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
        selectAll.activateForPlannerJourney()
        field.typeText(reply)
        XCTAssertTrue(field.waitForPlannerValue(reply))
        application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
        XCTAssertTrue(application.staticTexts[reply].waitForExistence(timeout: 15))
        record(application, name: "Production iPhone reply to the exact MCP Item")
      }
    #endif
  }

  private func dismissSettings(_ application: XCUIApplication) {
    #if os(macOS)
      let settings = application.windows.containing(.button, identifier: "saved.agent.stop")
        .firstMatch
      if settings.exists { settings.buttons["_XCUI:CloseWindow"].activateForPlannerJourney() }
    #else
      let sharingDone = application.navigationBars["Sharing"].buttons["Done"]
      if sharingDone.exists { sharingDone.activateForPlannerJourney() }
      let done = application.buttons["saved.settings.done"]
      if done.exists { done.activateForPlannerJourney() }
    #endif
  }

  private func record(_ application: XCUIApplication, name: String) {
    for attachment in [
      XCTAttachment(string: application.debugDescription),
      XCTAttachment(screenshot: application.screenshot()),
    ] {
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
}
