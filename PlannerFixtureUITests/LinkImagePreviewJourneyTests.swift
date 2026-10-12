import XCTest

@MainActor
final class LinkImagePreviewJourneyTests: XCTestCase {
  func testControlledImagePaintsRowThumbnailAndOwnedLinkCard() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--fixture", "link-image"]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20), application.debugDescription)
    let thumbnail = application.images.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.preview.thumbnail.")
    ).firstMatch
    XCTAssertTrue(thumbnail.waitForExistence(timeout: 5), application.debugDescription)
    assertImagePainted(thumbnail, application: application)
    row.activateForPlannerJourney()
    let bookmark = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", "Museum guide")
    ).firstMatch
    XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
    XCTAssertTrue(bookmark.waitForPlannerValue("https://fixtures.invalid/image"))
    let identifier = bookmark.identifier.replacingOccurrences(of: "saved.item.link.", with: "")
    let card = application.descendants(matching: .any).matching(
      identifier: "saved.item.preview.card." + identifier
    ).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    XCTAssertTrue(card.waitForPlannerValue("Image available"))
    assertImagePainted(card, application: application)
    let capture = XCTAttachment(screenshot: application.screenshot())
    capture.name = "Controlled image paints the native owned-link card"
    capture.lifetime = .keepAlways
    add(capture)
    XCTAssertTrue(application.staticTexts["Original notes"].exists)
  }

  private func assertImagePainted(_ card: XCUIElement, application: XCUIApplication) {
    let rendered = NSPredicate { _, _ in
      guard card.exists, application.windows.firstMatch.frame.contains(card.frame) else {
        return false
      }
      return application.hasPaintedPlannerPreview(card)
    }
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: rendered, object: card)], timeout: 10),
      .completed, "The controlled colorful image must paint inside the native preview.")
  }
}
