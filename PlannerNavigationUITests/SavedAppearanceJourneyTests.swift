import XCTest

@MainActor
final class SavedAppearanceJourneyTests: XCTestCase {
  func testListCompletionStaysLocalWhileGlobalCompletionOverridesAndReopeningRestoresIt() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let completion = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.completion.")
    ).firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Completed"].exists)
    recordScreenshot(application, name: "Saved List with contextual completion and details")

    createList("Wishlist", application: application)
    addItem(application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertFalse(completion.isEnabled)
    XCTAssertTrue(completion.label.contains("Completed globally"))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Saved List with globally completed Item")

    viewGlobalItem(application)
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    XCTAssertTrue(completion.isEnabled)
    assertProgress(0, application: application)
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertTrue(completion.isEnabled)
    assertProgress(1, application: application)

    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
  }

  func testListSelectionShowsContextualDetailsAndExplicitGlobalItemNavigation() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)

    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10),
      application.debugDescription)
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.staticTexts["Local: Todo"].exists)
    XCTAssertFalse(application.staticTexts["Prototype identity inspection"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Saved List appearance details")

    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    application.plannerElement("View Item").activateForPlannerJourney()
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForExistence(timeout: 10))
    XCTAssertEqual(globalCompletion.plannerBooleanState, false)
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    XCTAssertFalse(application.staticTexts["In Tokyo Food"].exists)

    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
  }

  private func createItem(_ application: XCUIApplication) {
    openSection("Items", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Nezu Museum")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet at the garden entrance")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
  }

  private func createList(_ title: String, application: XCUIApplication) {
    openSection("Lists", application: application)
    let create = application.plannerElement("saved.list.new")
    revealSidebarIfNeeded(application, element: create)
    create.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText(title)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
  }

  private func addItem(_ application: XCUIApplication) {
    application.plannerElement("saved.list.add").activateForPlannerJourney()
    let candidate = application.staticTexts["Nezu Museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("saved.membership.add").waitForExistence(timeout: 2))
    XCTAssertTrue(
      application.savedPlannerItemRows("Nezu Museum").firstMatch.waitForExistence(timeout: 10))
  }

  private func openList(_ title: String, application: XCUIApplication) {
    openSection("Lists", application: application)
    let list = application.savedPlannerListRow(title)
    revealSidebarIfNeeded(application, element: list)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    list.activateForPlannerJourney()
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertTrue(item.waitForPlannerHittability())
  }

  private func openSection(_ title: String, application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("saved.section.\(title.lowercased())")
    #else
      let section = application.buttons[title].firstMatch
    #endif
    XCTAssertTrue(section.waitForExistence(timeout: 10))
    section.activateForPlannerJourney()
  }

  private func revealSidebarIfNeeded(_ application: XCUIApplication, element: XCUIElement) {
    if element.waitForExistence(timeout: 3) { return }
    for _ in 0..<2 {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists {
        sidebar.activateForPlannerJourney()
      } else {
        let back = application.plannerElement("BackButton")
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.activateForPlannerJourney()
      }
      if element.waitForExistence(timeout: 3) { return }
    }
    XCTFail("Planner's native List navigation did not become available.")
  }

  private func viewGlobalItem(_ application: XCUIApplication) {
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(item.waitForPlannerHittability())
    item.activateForPlannerJourney()
    let actions = application.plannerElement("saved.appearance.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
    let viewItem = application.plannerElement("View Item")
    XCTAssertTrue(viewItem.waitForExistence(timeout: 5))
    viewItem.activateForPlannerJourney()
  }

  private func activateGlobalCompletion(_ element: XCUIElement) {
    #if os(macOS)
      element.click()
    #else
      let visibleSwitch = element.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
  }

  private func assertProgress(_ expected: Double, application: XCUIApplication) {
    let progress = application.progressIndicators["saved.list.progress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    XCTAssertEqual(progress.plannerProgressFraction, expected)
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = application.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

extension XCUIElement {
  fileprivate func waitForPlannerValue(_ expected: String) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: 5)
      == .completed
  }
}
