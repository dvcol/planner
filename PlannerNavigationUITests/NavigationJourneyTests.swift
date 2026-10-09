import XCTest

@MainActor
final class NavigationJourneyTests: XCTestCase {
  func testCumulativeFiltersSummarizeSelectionsWithoutChangingFullListProgress() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    application.openPlannerSection("Lists")
    application.plannerElement("list.00000000-0000-4000-8000-000000000201")
      .activateForPlannerJourney()

    XCTAssertTrue(application.progressIndicators["progress.container"].waitForExistence(timeout: 5))
    XCTAssertEqual(
      application.progressIndicators["progress.container"].plannerProgressFraction, 0.5)
    XCTAssertTrue(application.staticTexts["1 of 2 done"].exists)
    XCTAssertTrue(
      application.plannerElement("filter.options").plannerControlTitle.contains("Todo"),
      application.windows.firstMatch.debugDescription)
    XCTAssertTrue(
      application.plannerElement("filter.options").plannerControlTitle.contains("Active"))
    application.plannerElement("filter.options").activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("filter.options").plannerControlTitle.contains("Active"))
    XCTAssertFalse(
      application.plannerElement("filter.options").plannerControlTitle.contains("Todo"))
    XCTAssertTrue(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000401").exists)
    XCTAssertFalse(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000402").exists)

    application.plannerElement("filter.options").activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
    XCTAssertEqual(application.plannerElement("filter.options").plannerControlTitle, "All")
    XCTAssertTrue(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000402").exists)
    application.plannerElement("filter.options").activateForPlannerJourney()
    application.plannerElement("Done").activateForPlannerJourney()
    XCTAssertEqual(application.plannerElement("filter.options").plannerControlTitle, "Done")
    XCTAssertTrue(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000401").exists)
    XCTAssertFalse(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000402").exists)
    XCTAssertTrue(application.staticTexts["1 of 2 done"].exists)
    recordScreenshot(application, name: "Cumulative filters with native completion progress")
  }

  func testListAppearanceKeepsItsIdentityWhenOpeningTheSourceItem() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()

    application.openPlannerSection("Lists")
    application.plannerElement("list.00000000-0000-4000-8000-000000000201")
      .activateForPlannerJourney()

    #if os(macOS)
      recordScreenshot(application, name: "Mac native sidebar selection")
    #endif
    XCTAssertTrue(
      application.staticTexts["1 of 2 done"].waitForExistence(timeout: 5),
      application.windows.firstMatch.debugDescription)
    XCTAssertFalse(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000401").exists)
    XCTAssertFalse(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000402").exists)

    application.plannerElement("filter.options").activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    application.plannerElement("filter.options").activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
    application.plannerElement("appearance.00000000-0000-4000-8000-000000000401")
      .activateForPlannerJourney()

    XCTAssertTrue(application.staticTexts["List appearance"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000401"].exists)
    XCTAssertTrue(application.staticTexts["Local: Done"].exists)
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)

    #if os(macOS)
      application.typeKey(.downArrow, modifierFlags: [])
      XCTAssertTrue(
        application.staticTexts["00000000-0000-4000-8000-000000000402"].waitForExistence(timeout: 5)
      )
      XCTAssertTrue(application.staticTexts["Local: Todo"].exists)
      application.typeKey(.upArrow, modifierFlags: [])
      XCTAssertTrue(
        application.staticTexts["00000000-0000-4000-8000-000000000401"].waitForExistence(timeout: 5)
      )
    #endif

    recordScreenshot(application, name: "List appearance 401")

    application.plannerElement("Open source Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Source Item"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000101"].exists)
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    recordScreenshot(application, name: "Source Item 101")

    application.openPlannerSection("Itineraries")
    application.plannerElement("itinerary.00000000-0000-4000-8000-000000000301")
      .activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["0 of 3 done"].exists)
    recordScreenshot(application, name: "Tokyo Weekend initial progress")
  }

  func testPlanningLayoutKeepsItineraryAppearanceCompletionIndependent() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    application.choosePrototypeLayout("Itinerary first")
    XCTAssertFalse(application.staticTexts["Navigation prototype"].exists)
    XCTAssertFalse(
      application.windows.firstMatch.descendants(matching: .any)["prototype.layouts"].exists)
    let itinerary = application.plannerElement("itinerary.00000000-0000-4000-8000-000000000301")
    if !itinerary.exists { application.plannerElement("Show Sidebar").activateForPlannerJourney() }
    XCTAssertTrue(itinerary.waitForExistence(timeout: 5))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["0 of 3 done"].exists)
    recordScreenshot(application, name: "Itinerary first layout")
    application.plannerElement("appearance.00000000-0000-4000-8000-000000000451")
      .activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Local: Todo"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    XCTAssertTrue(application.staticTexts["00000000-0000-4000-8000-000000000451"].exists)
    recordScreenshot(application, name: "Independent itinerary appearance 451")
  }

  func testExpandedListAppearanceRetainsItsFullItineraryIdentityAndOwnCompletion() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    application.openPlannerSection("Itineraries")
    application.plannerElement("itinerary.00000000-0000-4000-8000-000000000301")
      .activateForPlannerJourney()
    application.plannerElement(
      "appearance.00000000-0000-4000-8000-000000000452/00000000-0000-4000-8000-000000000401"
    ).activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Itinerary list appearance"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Local: Todo"].exists)
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    XCTAssertTrue(
      application.staticTexts[
        "00000000-0000-4000-8000-000000000452/00000000-0000-4000-8000-000000000401"
      ].exists)
    recordScreenshot(application, name: "Expanded itinerary appearance 452 membership 401")
  }

  func testItineraryListCollapsePreservesProgressAndSurvivesRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    application.openPlannerSection("Itineraries")
    application.plannerElement("itinerary.00000000-0000-4000-8000-000000000301")
      .activateForPlannerJourney()
    #if os(macOS)
      let group = application.disclosureTriangles.firstMatch
    #else
      let group = application.descendants(matching: .any)
        .matching(identifier: "group.00000000-0000-4000-8000-000000000452").firstMatch
    #endif
    let expandedItem = application.plannerElement(
      "appearance.00000000-0000-4000-8000-000000000452/00000000-0000-4000-8000-000000000401"
    )
    XCTAssertTrue(group.waitForExistence(timeout: 5))
    XCTAssertTrue(expandedItem.exists)
    XCTAssertTrue(
      groupProgress(in: application).exists, application.windows.firstMatch.debugDescription)
    XCTAssertTrue(application.staticTexts["0 of 3 done"].exists)
    group.activateForPlannerJourney()
    XCTAssertFalse(expandedItem.exists)
    XCTAssertTrue(
      application.plannerElement("appearance.00000000-0000-4000-8000-000000000451").exists)
    XCTAssertTrue(groupProgress(in: application).exists)
    XCTAssertTrue(application.staticTexts["0 of 3 done"].exists)
    recordScreenshot(application, name: "Collapsed live List with unchanged progress")

    application.terminate()
    application.launch()
    application.openPlannerSection("Itineraries")
    application.plannerElement("itinerary.00000000-0000-4000-8000-000000000301")
      .activateForPlannerJourney()
    XCTAssertTrue(group.waitForExistence(timeout: 5))
    XCTAssertFalse(expandedItem.exists)
    group.activateForPlannerJourney()
    XCTAssertTrue(expandedItem.waitForExistence(timeout: 5))
    recordScreenshot(application, name: "Expanded live List after relaunch")
    expandedItem.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Local: Todo"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Global: Todo"].exists)
    XCTAssertTrue(
      application.staticTexts[
        "00000000-0000-4000-8000-000000000452/00000000-0000-4000-8000-000000000401"
      ].exists)
  }

  private func groupProgress(in application: XCUIApplication) -> XCUIElement {
    #if os(macOS)
      application.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "0 of 2 done", "0 of 2 done")
      ).firstMatch
    #else
      application.staticTexts["0 of 2 done"]
    #endif
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
