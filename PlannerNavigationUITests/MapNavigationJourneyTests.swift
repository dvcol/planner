import XCTest

@MainActor
final class MapNavigationJourneyTests: XCTestCase {
  func testMapPinKeepsTheSelectedListAppearanceAndGenericItemsRemainVisible() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    openLayoutChooser(in: application)
    let mapLayout = application.buttons["Map alongside list"]
    XCTAssertTrue(mapLayout.waitForExistence(timeout: 5))
    mapLayout.tap()
    openSection("Lists", in: application)
    application.buttons["list.00000000-0000-4000-8000-000000000201"].tap()
    application.buttons["filter.completion"].tap()
    application.buttons["All completion states"].tap()
    application.buttons["filter.archive"].tap()
    application.buttons["All archive states"].tap()
    application.buttons["appearance.00000000-0000-4000-8000-000000000401"].tap()
    let pin = application.buttons["map.appearance.00000000-0000-4000-8000-000000000401"]
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Map alongside selected List appearance")
    pin.tap()
    XCTAssertTrue(application.staticTexts["Local: Done"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    if !application.staticTexts["00000000-0000-4000-8000-000000000401"].exists {
      application.swipeUp()
    }
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000401"].exists)
    recordScreenshot(application, name: "Map selected appearance 401")
    application.buttons["Close"].tap()
    let genericItem = application.buttons["appearance.00000000-0000-4000-8000-000000000402"]
    if !genericItem.exists { application.buttons["BackButton"].tap() }
    genericItem.tap()
    XCTAssertTrue(application.staticTexts["No location"].waitForExistence(timeout: 5))
    recordScreenshot(application, name: "Generic Item without location")
  }

  private func openLayoutChooser(in application: XCUIApplication) {
    let layouts = application.descendants(matching: .any)["prototype.layouts"]
    if !layouts.exists { application.buttons["Show Sidebar"].tap() }
    XCTAssertTrue(layouts.waitForExistence(timeout: 5))
    layouts.tap()
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
