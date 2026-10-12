import XCTest

@MainActor
final class CatalogEstimateOverflowJourneyTests: XCTestCase {
  func testManualBudgetKeepsExactTotalsAndWarnsAboutUnavailableCalculation() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    let row = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.list.", "Overflow budget")
    ).firstMatch
    if !row.waitForExistence(timeout: 5) {
      let sidebar = application.buttons["Show Sidebar"].firstMatch
      XCTAssertTrue(sidebar.waitForExistence(timeout: 5), application.debugDescription)
      #if os(macOS)
        sidebar.click()
      #else
        sidebar.tap()
      #endif
    }
    XCTAssertTrue(row.waitForExistence(timeout: 20), application.debugDescription)
    let expected =
      "Active. Estimate, Manual, 240 minutes. Remaining, 240 minutes. Calculated, Estimate unavailable."
    let predicate = NSPredicate(format: "value == %@", expected)
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: predicate, object: row)], timeout: 5),
      .completed, application.debugDescription)
    let capture = XCTAttachment(screenshot: application.screenshot())
    capture.name = "Manual catalog budget warns about unavailable calculation"
    capture.lifetime = .keepAlways
    add(capture)
  }
}
