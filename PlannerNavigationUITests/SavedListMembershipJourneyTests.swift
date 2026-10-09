import XCTest

@MainActor
final class SavedListMembershipJourneyTests: XCTestCase {
  func testExistingItemCanBeAddedToAListWithoutDuplicatingItsSourceAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launch()
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

    openSection("Lists", application: application)
    let newList = application.plannerElement("saved.list.new")
    revealSidebarIfNeeded(application, element: newList)
    newList.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Tokyo Food")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))

    let addItem = application.plannerElement("saved.list.add")
    XCTAssertTrue(addItem.waitForExistence(timeout: 5))
    addItem.activateForPlannerJourney()
    let candidate = application.staticTexts["Nezu Museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.cancel").activateForPlannerJourney()
    application.terminate()
    application.launch()
    openSection("Lists", application: application)
    let retained = application.staticTexts["Tokyo Food"].firstMatch
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    addItem.activateForPlannerJourney()
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    let confirm = application.plannerElement("saved.membership.add")
    XCTAssertTrue(confirm.isEnabled)
    confirm.activateForPlannerJourney()
    XCTAssertTrue(candidate.waitForExistence(timeout: 10))
    XCTAssertFalse(confirm.exists)
    XCTAssertFalse(application.staticTexts["No items"].exists)
    XCTAssertEqual(application.staticTexts.matching(identifier: "Nezu Museum").count, 1)

    addItem.activateForPlannerJourney()
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    confirm.activateForPlannerJourney()
    XCTAssertFalse(confirm.waitForExistence(timeout: 2))
    XCTAssertEqual(application.staticTexts.matching(identifier: "Nezu Museum").count, 1)

    application.terminate()
    application.launch()
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(candidate.waitForExistence(timeout: 10))
    XCTAssertEqual(application.staticTexts.matching(identifier: "Nezu Museum").count, 1)
    recordScreenshot(application, name: "Saved List with one shared Item after relaunch")
    openSection("Items", application: application)
    XCTAssertTrue(candidate.waitForExistence(timeout: 10))
    XCTAssertEqual(application.staticTexts.matching(identifier: "Nezu Museum").count, 1)
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
    let sidebar = application.plannerElement("Show Sidebar")
    XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
    sidebar.activateForPlannerJourney()
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
