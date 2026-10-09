import XCTest

@MainActor
final class NavigationJourneyTests: XCTestCase {
  func testListAppearanceKeepsItsIdentityWhenOpeningTheSourceItem() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()

    openSection("Lists", in: application)
    application.buttons["list.00000000-0000-4000-8000-000000000201"].tap()

    XCTAssertTrue(application.staticTexts["1 of 2 done"].exists)
    XCTAssertFalse(application.buttons["appearance.00000000-0000-4000-8000-000000000401"].exists)
    XCTAssertFalse(application.buttons["appearance.00000000-0000-4000-8000-000000000402"].exists)

    application.buttons["filter.completion"].tap()
    application.buttons["All completion states"].tap()
    application.buttons["filter.archive"].tap()
    application.buttons["All archive states"].tap()
    application.buttons["appearance.00000000-0000-4000-8000-000000000401"].tap()

    XCTAssertTrue(application.staticTexts["List appearance"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000401"].exists)
    XCTAssertTrue(application.staticTexts["Local: Done"].exists)
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)

    recordScreenshot(application, name: "List appearance 401")

    application.buttons["Open source Item"].tap()
    XCTAssertTrue(application.staticTexts["Source Item"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000101"].exists)
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    recordScreenshot(application, name: "Source Item 101")

    openSection("Itineraries", in: application)
    application.buttons["itinerary.00000000-0000-4000-8000-000000000301"].tap()
    XCTAssertTrue(application.staticTexts["0 of 3 done"].exists)
    recordScreenshot(application, name: "Tokyo Weekend initial progress")
  }

  private func openSection(_ title: String, in application: XCUIApplication) {
    if !application.buttons[title].exists {
      let sidebar = application.buttons["Show Sidebar"]
      XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
      sidebar.tap()
    }
    let section = application.buttons[title]
    XCTAssertTrue(section.waitForExistence(timeout: 5))
    section.tap()
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
