import XCTest

@MainActor
final class DelayedLinkPreviewJourneyTests: XCTestCase {
  func testDelayedLinkResultCannotReplaceTheEditedURLPreview() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "link-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Delayed website").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let sourceIdentifier = row.identifier
    row.activateForPlannerJourney()
    let bookmark = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", "Saved website")
    ).firstMatch
    XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
    let bookmarkIdentifier = bookmark.identifier
    let linkIdentifier = bookmarkIdentifier.replacingOccurrences(of: "saved.item.link.", with: "")
    assertOwnedData(
      "https://fixtures.invalid/delayed", bookmark: bookmark, application: application)
    let loading = application.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Loading preview")
    ).firstMatch
    XCTAssertTrue(loading.waitForExistence(timeout: 5))
    let card = application.descendants(matching: .any).matching(
      identifier: "saved.item.preview.card." + linkIdentifier
    ).firstMatch
    XCTAssertFalse(card.exists)
    capture(application, name: "Controlled link stays pending before URL editing")
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
    let urlField = application.textFields["saved.item.edit.link.url." + linkIdentifier]
    reveal(urlField, application: application)
    XCTAssertTrue(urlField.waitForPlannerValue("https://fixtures.invalid/delayed"))
    urlField.activateForPlannerJourney()
    #if os(macOS)
      urlField.typeKey("a", modifierFlags: .command)
    #else
      urlField.press(forDuration: 1)
      let selectAll = application.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@ OR identifier == %@", "Select All", "Select All")
      ).firstMatch
      XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
      selectAll.activateForPlannerJourney()
    #endif
    urlField.typeText("https://fixtures.invalid/current")
    XCTAssertTrue(urlField.waitForPlannerValue("https://fixtures.invalid/current"))
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(card.waitForExistence(timeout: 10))
    XCTAssertTrue(card.waitForPlannerValue("Image available"))
    XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
    XCTAssertEqual(bookmark.identifier, bookmarkIdentifier)
    assertOwnedData(
      "https://fixtures.invalid/current", bookmark: bookmark, application: application)
    reveal(card, application: application)
    let rendered = NSPredicate { _, _ in application.hasPaintedPlannerPreview(card) }
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: rendered, object: card)], timeout: 10),
      .completed, "The released old no-image result must not replace the current painted image.")
    capture(application, name: "Current link image survives the released outdated result")
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
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    XCTAssertTrue(card.waitForPlannerValue("No image"))
    XCTAssertEqual(bookmark.identifier, bookmarkIdentifier)
    assertOwnedData(
      "https://fixtures.invalid/current", bookmark: bookmark, application: application)
    reveal(card, application: application)
    capture(application, name: "Relaunch keeps the saved URL and loads fresh no-image metadata")
  }

  private func assertOwnedData(
    _ expectedURL: String, bookmark: XCUIElement, application: XCUIApplication
  ) {
    XCTAssertTrue(bookmark.waitForPlannerValue(expectedURL))
    XCTAssertEqual(bookmark.label, "Saved website")
    XCTAssertTrue(application.staticTexts["Original notes"].exists)
    let completion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
  }

  private func reveal(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<6 {
      if element.exists && element.isHittable
        && application.windows.firstMatch.frame.contains(element.frame)
      {
        return
      }
      application.swipeUp()
    }
    XCTAssertTrue(element.exists && element.isHittable)
    XCTAssertTrue(application.windows.firstMatch.frame.contains(element.frame))
  }

  private func capture(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
