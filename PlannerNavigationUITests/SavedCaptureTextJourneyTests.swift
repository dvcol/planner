import XCTest

@MainActor
final class SavedCaptureTextJourneyTests: XCTestCase {
  func testPlainTextReviewPreservesItsTitleAndNotesWithoutInventingLinks() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.plannerElement("saved.section.items").activateForPlannerJourney()
    #else
      application.buttons["Items"].firstMatch.activateForPlannerJourney()
    #endif
    let capture = application.plannerElement("saved.capture.new")
    XCTAssertTrue(capture.waitForExistence(timeout: 10))
    capture.activateForPlannerJourney()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    input.typeText("Picnic idea\nBring lunch")
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.value as? String, "Picnic idea")
    XCTAssertEqual(application.textFields["saved.capture.notes"].value as? String, "Bring lunch")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Bring lunch"].waitForExistence(timeout: 10))
    XCTAssertEqual(
      application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
      ).count, 0)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Native plain text capture keeps independently supplied content"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
