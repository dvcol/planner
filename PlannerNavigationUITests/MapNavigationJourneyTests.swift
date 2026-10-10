import XCTest

@MainActor
final class MapNavigationJourneyTests: XCTestCase {
  func testOrdinaryDetailsShowTheSavedLocationMapWithoutChoosingAMapLayout() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--navigation-prototype"]
    application.launch()
    application.choosePrototypeLayout("Library first")
    application.openPlannerSection("Lists")
    application.plannerElement("list.00000000-0000-4000-8000-000000000202")
      .activateForPlannerJourney()
    application.plannerElement("appearance.00000000-0000-4000-8000-000000000403")
      .activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Wishlist"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.descendants(matching: .any)["map.location"].waitForExistence(timeout: 5),
      "A saved location must show its map in ordinary contextual details.")
    recordScreenshot(application, name: "Ordinary contextual detail with native map")
    application.openPlannerSection("Items")
    application.plannerElement("item.00000000-0000-4000-8000-000000000101")
      .activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any)["map.location"].waitForExistence(timeout: 5),
      "The same location must remain visible in the ordinary global Item details.")
    XCTAssertFalse(application.buttons["Inspect Item"].exists)
    recordScreenshot(application, name: "Ordinary global Item detail with native map")
  }

  func testSelectedAppearanceShowsItsMapAndDetailsTogetherWithoutInspection() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--navigation-prototype"]
    application.launch()
    application.choosePrototypeLayout("Map alongside list")
    application.openPlannerSection("Lists")
    application.plannerElement("list.00000000-0000-4000-8000-000000000201")
      .activateForPlannerJourney()
    application.plannerElement("filter.options").activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    application.plannerElement("filter.options").activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
    application.plannerElement("appearance.00000000-0000-4000-8000-000000000401")
      .activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Completed"].waitForExistence(timeout: 5),
      "Selecting the row must show details directly, without opening an inspection sheet.")
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
    XCTAssertFalse(application.buttons["Inspect Item"].exists)
    XCTAssertTrue(application.descendants(matching: .any)["map.location"].exists)
    application.openItemDiagnostics()
    XCTAssertTrue(application.staticTexts["Local: Done"].exists)
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000401"].exists)
    application.closeItemDiagnostics()
    recordScreenshot(application, name: "Map selected appearance 401")
    let genericItem = application.plannerElement("appearance.00000000-0000-4000-8000-000000000402")
    if !genericItem.exists { application.plannerElement("BackButton").activateForPlannerJourney() }
    genericItem.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No location"].waitForExistence(timeout: 5))
    recordScreenshot(application, name: "Generic Item without location")
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
