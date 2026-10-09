import XCTest

@MainActor
final class SavedListJourneyTests: XCTestCase {
  func testListDraftCancellationAndCreationRemainDistinctAfterNativeRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launch()
    let newList = application.plannerElement("saved.list.new")
    revealSidebarIfNeeded(application, element: newList)
    XCTAssertTrue(newList.waitForExistence(timeout: 10))
    newList.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled plan")
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled plan"].exists)
    XCTAssertTrue(application.staticTexts["No Lists yet"].firstMatch.exists)

    newList.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Tokyo Weekend")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].isHittable)
    XCTAssertFalse(name.exists)
    XCTAssertTrue(application.staticTexts["Tokyo Weekend"].firstMatch.exists)
    recordScreenshot(application, name: "Saved native List with empty progress")

    application.terminate()
    application.launch()
    let retained = application.staticTexts["Tokyo Weekend"].firstMatch
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["No items"].isHittable)
    XCTAssertFalse(application.staticTexts["Canceled plan"].exists)
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Saved native List after relaunch")
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
