import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class RowReadabilityJourneyTests: XCTestCase {
  func testPopulatedRowsKeepNaturalHeightInTheSelectedList() {
    continueAfterFailure = false
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
    #endif
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "row-readability", "--fixture-dataset", UUID().uuidString,
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
      "-AppleInterfaceStyle", "Dark",
    ]
    application.launchSavedPlannerJourney()
    #if os(macOS)
      defer { application.terminate() }
    #endif
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .phone {
        XCTAssertTrue(application.buttons["saved.navigation"].waitForExistence(timeout: 30))
        application.openPlannerSection("Lists")
      }
    #endif
    let list = application.savedPlannerListRow("Festivals & events")
    if !list.waitForExistence(timeout: 10) {
      let sidebar = application.buttons["Show Sidebar"].firstMatch
      XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
      sidebar.activateForPlannerJourney()
    }
    XCTAssertTrue(list.waitForExistence(timeout: 30))
    list.activateForPlannerJourney()
    let first = application.savedPlannerItemRows("Asakusa Tori-no-Ichi").firstMatch
    XCTAssertTrue(first.waitForExistence(timeout: 20))
    first.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Controlled row-layout fixture."].waitForExistence(timeout: 10))
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .phone {
        application.plannerElement("BackButton").activateForPlannerJourney()
      }
    #endif
    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Populated rows with schedules, metadata, and preview images"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    let rowScreenshot = XCTAttachment(screenshot: first.screenshot())
    rowScreenshot.name = "Populated event row"
    rowScreenshot.lifetime = .keepAlways
    add(rowScreenshot)
    let measurement = XCTAttachment(string: "First row frame: \(first.frame).")
    measurement.name = "Populated row geometry"
    measurement.lifetime = .keepAlways
    add(measurement)
    XCTAssertLessThanOrEqual(
      first.frame.height, 200,
      "A normal-size event row must fit its text and thumbnail without empty vertical bands.")
  }
}
