import XCTest

#if os(iOS)
  @MainActor
  final class ItineraryLocationJourneyTests: XCTestCase {
    func testItineraryOwnedLocationStagesSaveCancelClearAndRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "catalog-overflow", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      openCatalog(application)
      application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
      let title = application.textFields["saved.itinerary.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Meeting route")
      let notes = application.textFields["saved.itinerary.notes"]
      notes.activateForPlannerJourney()
      notes.typeText("Keep these route notes")
      let name = application.textFields["saved.itinerary.location.name"]
      let address = application.textFields["saved.itinerary.location.address"]
      reveal(name, application: application)
      name.activateForPlannerJourney()
      name.typeText("Meeting entrance")
      reveal(address, application: application)
      address.activateForPlannerJourney()
      address.typeText("Fixture no matches")
      application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
      let savedName = application.staticTexts["Meeting entrance"].firstMatch
      reveal(savedName, application: application)
      XCTAssertTrue(application.staticTexts["Fixture no matches"].firstMatch.exists)
      capture("Itinerary displays its saved owned location")
      openCatalog(application)
      let row = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@",
          "saved.itinerary.row.", "Meeting route")
      ).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      let identity = row.identifier
      row.activateForPlannerJourney()
      application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
      XCTAssertFalse(application.plannerElement("saved.itinerary.save").isEnabled)
      reveal(address, application: application)
      replace(address, with: "Canceled address")
      application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
      reveal(savedName, application: application)
      XCTAssertTrue(application.staticTexts["Fixture no matches"].firstMatch.exists)
      XCTAssertFalse(application.staticTexts["Canceled address"].exists)
      application.terminate()
      application.launchSavedPlannerJourney()
      openCatalog(application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      reveal(savedName, application: application)
      XCTAssertTrue(application.staticTexts["Fixture no matches"].firstMatch.exists)
      application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
      reveal(name, application: application)
      replace(name, with: "")
      reveal(address, application: application)
      replace(address, with: "")
      application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep these route notes"].firstMatch.waitForExistence(timeout: 10))
      XCTAssertFalse(savedName.exists)
      XCTAssertFalse(application.staticTexts["Fixture no matches"].exists)
      application.terminate()
      application.launchSavedPlannerJourney()
      openCatalog(application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep these route notes"].firstMatch.waitForExistence(timeout: 10))
      XCTAssertFalse(savedName.exists)
      capture("Itinerary location is cleared while its identity and notes survive")
    }

    private func openCatalog(_ application: XCUIApplication) {
      application.openPlannerSection("Itineraries")
      let create = application.plannerElement("saved.itinerary.new")
      if !create.waitForExistence(timeout: 2) {
        let back = application.navigationBars.buttons["BackButton"].firstMatch
        if back.exists { back.activateForPlannerJourney() }
      }
      if !create.exists {
        let sidebar = application.buttons["Show Sidebar"]
        if sidebar.exists { sidebar.activateForPlannerJourney() }
      }
      XCTAssertTrue(create.waitForExistence(timeout: 10), application.debugDescription)
    }

    private func reveal(_ element: XCUIElement, application: XCUIApplication) {
      for _ in 0..<8 {
        if element.exists, element.isHittable,
          application.windows.firstMatch.frame.contains(element.frame)
        {
          break
        }
        let scroll = application.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: 0.8))
          .press(
            forDuration: 0.05,
            thenDragTo: scroll.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: 0.25)))
      }
      XCTAssertTrue(element.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertTrue(element.isHittable)
    }

    private func replace(_ field: XCUIElement, with value: String) {
      field.activateForPlannerJourney()
      let existing = field.value as? String ?? ""
      field.typeText(
        String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + value)
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
