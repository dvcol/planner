import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class ItineraryWindowJourneyTests: XCTestCase {
  func testRepeatedListPagesKeepIndependentChecksDetailsAndIdentitiesAfterRelaunch() throws {
    continueAfterFailure = false
    #if os(iOS)
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
    #endif
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "itinerary-windows", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    openRoute("Windowed route", application: application)
    XCTAssertTrue(application.staticTexts["0 of 132 items done"].waitForExistence(timeout: 15))
    XCTAssertTrue(application.staticTexts["2 direct items · 2 lists"].exists)
    capture(application, "Windowed itinerary starts with full progress and repeated List headers")
    let catalog = application.descendants(matching: .any)
      .matching(identifier: "saved.itinerary.contents").firstMatch
    let first = try revealActivity("Window Activity 065", in: catalog, application: application)
    let firstIdentifier = first.identifier
    let firstCompletion = completion(firstIdentifier, application: application)
    XCTAssertTrue(waitForCompletion(firstCompletion, done: false))
    capture(application, "Itinerary boundary appearance before local completion")
    firstCompletion.activateForPlannerJourney()
    let completed = waitForCompletion(firstCompletion, done: true)
    if !completed {
      capture(application, "Itinerary boundary completion refresh failure")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Itinerary boundary completion refresh hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertTrue(completed)
    XCTAssertTrue(firstCompletion.isHittable)
    capture(application, "First repeated List appearance stays visible after local completion")
    let second = try revealActivity(
      "Window Activity 065", excluding: firstIdentifier, in: catalog, application: application)
    let secondIdentifier = second.identifier
    XCTAssertNotEqual(firstIdentifier, secondIdentifier)
    XCTAssertTrue(
      waitForCompletion(completion(secondIdentifier, application: application), done: false))
    second.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Window itinerary notes 65"].waitForExistence(timeout: 10))
    #if os(iOS)
      let needsBackNavigation = UIDevice.current.userInterfaceIdiom == .phone
    #else
      let needsBackNavigation = false
    #endif
    if needsBackNavigation {
      #if os(iOS)
        let back = application.navigationBars.buttons["Windowed route"].firstMatch
        if back.waitForExistence(timeout: 5) {
          back.activateForPlannerJourney()
        } else {
          application.plannerElement("BackButton").activateForPlannerJourney()
        }
      #endif
      try revealFirstActivity(in: catalog, application: application)
    } else {
      try revealFirstActivity(in: catalog, application: application)
      XCTAssertTrue(application.staticTexts["Window itinerary notes 65"].exists)
      capture(
        application, "Selected itinerary appearance keeps details while its page is offscreen")
    }
    XCTAssertTrue(application.staticTexts["1 of 132 items done"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openRoute("Windowed route", application: application)
    XCTAssertTrue(application.staticTexts["1 of 132 items done"].waitForExistence(timeout: 15))
    let restoredFirst = try revealActivity(
      "Window Activity 065", in: catalog, application: application)
    XCTAssertEqual(restoredFirst.identifier, firstIdentifier)
    XCTAssertTrue(
      waitForCompletion(completion(firstIdentifier, application: application), done: true))
    let restoredSecond = try revealActivity(
      "Window Activity 065", excluding: firstIdentifier, in: catalog, application: application)
    XCTAssertEqual(restoredSecond.identifier, secondIdentifier)
    XCTAssertTrue(
      waitForCompletion(completion(secondIdentifier, application: application), done: false))
    capture(
      application, "Repeated itinerary pages retain exact independent appearances after relaunch")
  }

  private func openRoute(_ title: String, application: XCUIApplication) {
    let ready = NSPredicate { _, _ in
      application.plannerElement("saved.section.lists").exists
        || application.plannerElement("Show Sidebar").exists
        || application.buttons["Lists"].firstMatch.exists
    }
    let readiness = XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: ready, object: application)], timeout: 45)
    if readiness != .completed {
      capture(application, "Itinerary fixture navigation readiness failure")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Itinerary fixture readiness hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertEqual(readiness, .completed)
    application.openPlannerSection("Itineraries")
    let route = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", title)
    ).firstMatch
    XCTAssertTrue(route.waitForExistence(timeout: 15))
    route.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.entry.new").waitForExistence(timeout: 15))
  }

  private func activities(_ title: String, application: XCUIApplication) -> XCUIElementQuery {
    application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.", title))
  }

  private func revealActivity(
    _ title: String, excluding identifier: String? = nil, in catalog: XCUIElement,
    application: XCUIApplication
  ) throws -> XCUIElement {
    XCTAssertTrue(catalog.waitForExistence(timeout: 10))
    for _ in 0..<30 {
      if let row = activities(title, application: application).allElementsBoundByIndex.first(
        where: {
          $0.identifier != identifier && isFullyVisible($0, in: catalog, application: application)
        })
      {
        return row
      }
      catalog.swipeUp()
    }
    XCTFail("The next matching itinerary appearance did not become fully visible.")
    throw CancellationError()
  }

  private func revealFirstActivity(in catalog: XCUIElement, application: XCUIApplication) throws {
    let contentsReturned = catalog.waitForExistence(timeout: 15)
    if !contentsReturned {
      capture(application, "Itinerary boundary contents did not return after Back")
    }
    XCTAssertTrue(contentsReturned)
    for _ in 0..<40 {
      if let row = activities("Window Activity 001", application: application)
        .allElementsBoundByIndex.first(where: {
          isFullyVisible($0, in: catalog, application: application)
        })
      {
        let progress = application.staticTexts["1 of 132 items done"]
        if progress.exists && catalog.frame.contains(progress.frame)
          && row.identifier.split(separator: ".").count == 4
        {
          return
        }
      }
      catalog.swipeDown()
    }
    capture(application, "Itinerary boundary first-row visibility failure")
    let hierarchy = XCTAttachment(string: application.debugDescription)
    hierarchy.name = "Itinerary boundary first-row visibility hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    XCTFail("The direct first appearance and full itinerary progress did not return.")
    throw CancellationError()
  }

  private func isFullyVisible(
    _ row: XCUIElement, in catalog: XCUIElement, application: XCUIApplication
  ) -> Bool {
    guard row.exists, row.isHittable, catalog.frame.contains(row.frame) else { return false }
    #if os(iOS)
      let bars = application.navigationBars.allElementsBoundByIndex.filter {
        $0.frame.intersects(catalog.frame)
      }
      let topBoundary = bars.map(\.frame.maxY).max() ?? catalog.frame.minY
      guard row.frame.minY >= topBoundary else { return false }
      let tabBar = application.tabBars.firstMatch
      if tabBar.exists, row.frame.intersects(tabBar.frame) { return false }
    #endif
    return true
  }

  private func completion(_ rowIdentifier: String, application: XCUIApplication) -> XCUIElement {
    application.plannerElement(
      rowIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
  }

  private func waitForCompletion(_ control: XCUIElement, done: Bool) -> Bool {
    let action = done ? "undone" : "done"
    let expected = "Mark Window Activity 065 \(action) in this Itinerary"
    return XCTWaiter.wait(
      for: [
        XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "label == %@", expected), object: control)
      ], timeout: 15) == .completed
  }

  private func capture(_ application: XCUIApplication, _ name: String) {
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
