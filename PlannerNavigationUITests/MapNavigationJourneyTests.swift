import XCTest

@MainActor
final class MapNavigationJourneyTests: XCTestCase {
  func testMapPinKeepsTheSelectedListAppearanceAndGenericItemsRemainVisible() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    openLayoutChooser(in: application)
    let mapLayout = application.plannerElement("Map alongside list")
    XCTAssertTrue(mapLayout.waitForExistence(timeout: 5))
    mapLayout.activateForPlannerJourney()
    openSection("Lists", in: application)
    application.plannerElement("list.00000000-0000-4000-8000-000000000201")
      .activateForPlannerJourney()
    application.plannerElement("filter.completion").activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    application.plannerElement("filter.archive").activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
    application.plannerElement("appearance.00000000-0000-4000-8000-000000000401")
      .activateForPlannerJourney()
    let pin = application.plannerElement("map.appearance.00000000-0000-4000-8000-000000000401")
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Map alongside selected List appearance")
    pin.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Local: Done"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    if !application.staticTexts["00000000-0000-4000-8000-000000000401"].exists {
      #if os(macOS)
        application.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -400)
      #else
        application.swipeUp()
      #endif
    }
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000401"].exists)
    recordScreenshot(application, name: "Map selected appearance 401")
    application.plannerElement("map.details.close").activateForPlannerJourney()
    let genericItem = application.plannerElement("appearance.00000000-0000-4000-8000-000000000402")
    if !genericItem.exists { application.plannerElement("BackButton").activateForPlannerJourney() }
    genericItem.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No location"].waitForExistence(timeout: 5))
    recordScreenshot(application, name: "Generic Item without location")
  }

  private func openLayoutChooser(in application: XCUIApplication) {
    let layouts = application.descendants(matching: .any)["prototype.layouts"]
    if !layouts.exists { application.plannerElement("Show Sidebar").activateForPlannerJourney() }
    XCTAssertTrue(layouts.waitForExistence(timeout: 5))
    layouts.activateForPlannerJourney()
  }

  private func openSection(_ title: String, in application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("nav.\(title.lowercased())")
    #else
      let section = application.plannerElement(title)
    #endif
    if !section.exists {
      let sidebar = application.plannerElement("Show Sidebar")
      XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
      sidebar.activateForPlannerJourney()
    }
    XCTAssertTrue(section.waitForExistence(timeout: 5))
    section.activateForPlannerJourney()
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
