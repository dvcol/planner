import XCTest

@MainActor
final class LinkOutcomePreviewJourneyTests: XCTestCase {
  func testNoImageAndRetryKeepOwnedLinksAndCompletionAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "link-outcomes", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let sourceIdentifier = row.identifier
    row.activateForPlannerJourney()
    let plainLink = ownedLink("Plain website", application: application)
    let retryLink = ownedLink("Recoverable website", application: application)
    XCTAssertTrue(plainLink.waitForExistence(timeout: 5))
    XCTAssertTrue(retryLink.waitForExistence(timeout: 5))
    let plainIdentifier = plainLink.identifier
    let retryIdentifier = retryLink.identifier
    let plainCard = previewCard(for: plainLink, application: application)
    let recoveredCard = previewCard(for: retryLink, application: application)
    XCTAssertTrue(plainCard.waitForExistence(timeout: 5))
    XCTAssertTrue(plainCard.waitForPlannerValue("No image"))
    assertOwnedData(application, plainLink: plainLink, retryLink: retryLink)
    let failure = application.staticTexts["Preview unavailable"]
    XCTAssertTrue(failure.waitForExistence(timeout: 5))
    XCTAssertFalse(recoveredCard.exists)
    capture(application, name: "Controlled no-image success and retryable failure")
    let retry = application.plannerElement("Retry")
    for _ in 0..<3 {
      if retry.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(retry.waitForPlannerHittability())
    retry.activateForPlannerJourney()
    XCTAssertTrue(recoveredCard.waitForExistence(timeout: 5))
    XCTAssertTrue(recoveredCard.waitForPlannerValue("No image"))
    XCTAssertTrue(failure.waitForNonExistence(timeout: 5))
    XCTAssertEqual(plainLink.identifier, plainIdentifier)
    XCTAssertEqual(retryLink.identifier, retryIdentifier)
    XCTAssertTrue(plainLink.waitForPlannerValue("https://fixtures.invalid/plain"))
    XCTAssertTrue(retryLink.waitForPlannerValue("https://fixtures.invalid/retry"))
    capture(application, name: "Controlled Retry recovers without an image or owned edits")
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    XCTAssertEqual(row.identifier, sourceIdentifier)
    XCTAssertFalse(
      application.images.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.preview.thumbnail.")
      ).firstMatch.exists)
    row.activateForPlannerJourney()
    XCTAssertTrue(plainCard.waitForExistence(timeout: 5))
    XCTAssertTrue(plainCard.waitForPlannerValue("No image"))
    XCTAssertTrue(failure.waitForExistence(timeout: 5))
    XCTAssertFalse(recoveredCard.exists)
    XCTAssertEqual(plainLink.identifier, plainIdentifier)
    XCTAssertEqual(retryLink.identifier, retryIdentifier)
    assertOwnedData(application, plainLink: plainLink, retryLink: retryLink)
  }

  private func ownedLink(_ label: String, application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", label)
    ).firstMatch
  }

  private func previewCard(for link: XCUIElement, application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any).matching(
      identifier: link.identifier.replacingOccurrences(
        of: "saved.item.link.", with: "saved.item.preview.card.")
    ).firstMatch
  }

  private func assertOwnedData(
    _ application: XCUIApplication, plainLink: XCUIElement, retryLink: XCUIElement
  ) {
    XCTAssertTrue(plainLink.waitForPlannerValue("https://fixtures.invalid/plain"))
    XCTAssertTrue(retryLink.waitForPlannerValue("https://fixtures.invalid/retry"))
    XCTAssertTrue(application.staticTexts["Original notes"].exists)
    let completion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
  }

  private func capture(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
