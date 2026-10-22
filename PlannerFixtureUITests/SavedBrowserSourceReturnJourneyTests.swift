import XCTest

@MainActor
final class SavedBrowserSourceReturnJourneyTests: XCTestCase {
  func testDeletedContainingListKeepsItsGuideOpenAndReturnsToLists() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    list.activateForPlannerJourney()
    let appearance = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    appearance.activateForPlannerJourney()
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<3 {
      if link.exists && link.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.deleteWeekend").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Deleted Weekend from another writer"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Deleted containing List leaves its guide open"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts[
        "The original List entry is no longer available. Returned to Lists."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerListRow("Weekend").exists)
    XCTAssertFalse(application.buttons[appearanceIdentifier].exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Deleted containing List returns to Lists"
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "Deleted containing List preserves its shared Todo Item"
    retained.lifetime = .keepAlways
    add(retained)
  }

  func testRemovedListAppearanceReturnsToItsListAndPreservesTheSharedItem() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    list.activateForPlannerJourney()
    let appearance = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    appearance.activateForPlannerJourney()
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<3 {
      if link.exists && link.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.removeMembership").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Removed Hotel from Weekend"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Removed List appearance leaves the original guide open"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts[
        "The original List entry is no longer available. Returned to the List."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Weekend"].exists)
    XCTAssertFalse(application.buttons[appearanceIdentifier].exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Removed browser appearance returns to its original List"
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertNotEqual(source.identifier, appearanceIdentifier)
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "Removed browser appearance preserves its shared Todo Item"
    retained.lifetime = .keepAlways
    add(retained)
  }

  func testDeletedSourceKeepsItsGuideOpenAndReturnsToItsSurvivingCollection() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 20))
    source.activateForPlannerJourney()
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<3 {
      if link.exists && link.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.deleteHotel").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Deleted Hotel from another writer"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Deleted source leaves the original guide open"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts["The original item is no longer available. Returned to Items."].exists
    )
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.items.catalog")
        .firstMatch.exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Deleted browser source returns to the surviving Items collection"
    returned.lifetime = .keepAlways
    add(returned)
  }
}
