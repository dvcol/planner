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
      application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
      XCTAssertFalse(application.plannerElement("saved.itinerary.save").isEnabled)
      reveal(name, application: application)
      XCTAssertEqual(name.value as? String, "Place name")
      reveal(address, application: application)
      XCTAssertEqual(address.value as? String, "Address")
      application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    }

    func testPinnedItineraryKeepsOrRemovesPinOnlyAfterSaveAndSurvivesRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "pinned-itinerary", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      openCatalog(application)
      let row = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@",
          "saved.itinerary.row.", "Museum route")
      ).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      let identity = row.identifier
      row.activateForPlannerJourney()
      let child = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@",
          "saved.itinerary.appearance.", "Route child")
      ).firstMatch
      reveal(child, application: application)
      let childIdentity = child.identifier
      let completion = application.plannerElement(
        childIdentity.replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      let map = application.descendants(matching: .any).matching(identifier: "map.location")
        .firstMatch
      reveal(map, application: application)
      capture("Itinerary details display their saved coordinate map")
      application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
      let save = application.plannerElement("saved.itinerary.save")
      XCTAssertFalse(save.isEnabled)
      let pin = application.descendants(matching: .any).matching(
        identifier: "saved.itinerary.location.pin"
      ).firstMatch
      chooseRemove(pin, application: application)
      application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
      reveal(map, application: application)
      application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
      let name = application.textFields["saved.itinerary.location.name"]
      let address = application.textFields["saved.itinerary.location.address"]
      reveal(name, application: application)
      replace(name, with: "Updated route entrance")
      reveal(address, application: application)
      replace(address, with: "Fixture no matches")
      save.activateForPlannerJourney()
      reveal(map, application: application)
      XCTAssertTrue(application.staticTexts["Updated route entrance"].firstMatch.exists)
      XCTAssertTrue(application.staticTexts["Fixture no matches"].firstMatch.exists)
      application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
      XCTAssertFalse(save.isEnabled)
      chooseRemove(pin, application: application)
      capture("Itinerary pin removal remains staged until Save")
      save.activateForPlannerJourney()
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "exists == false"), object: map)
          ], timeout: 5), .completed)
      application.terminate()
      application.launchSavedPlannerJourney()
      openCatalog(application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      let notes = application.staticTexts["Keep these route notes"].firstMatch
      XCTAssertTrue(notes.waitForExistence(timeout: 10))
      let savedName = application.staticTexts["Updated route entrance"].firstMatch
      reveal(savedName, application: application)
      XCTAssertTrue(application.staticTexts["Fixture no matches"].firstMatch.exists)
      XCTAssertFalse(map.exists)
      reveal(child, application: application)
      XCTAssertEqual(child.identifier, childIdentity)
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      capture("Itinerary address and child remain after saved pin removal and relaunch")
    }

    private func chooseRemove(_ pin: XCUIElement, application: XCUIApplication) {
      reveal(pin, application: application)
      pin.activateForPlannerJourney()
      let remove = application.plannerElement("Remove saved pin")
      XCTAssertTrue(remove.waitForExistence(timeout: 5), application.debugDescription)
      remove.activateForPlannerJourney()
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
        let surfaces =
          application.scrollViews.allElementsBoundByIndex
          + application.collectionViews.allElementsBoundByIndex
        guard let scroll = surfaces.last(where: { $0.isHittable && $0.frame.height > 200 }) else {
          XCTFail("No visible form scroll surface: \(application.debugDescription)")
          return
        }
        let keyboard = application.keyboards.firstMatch
        let bottom =
          keyboard.exists ? min(scroll.frame.maxY, keyboard.frame.minY) : scroll.frame.maxY
        let visibleHeight = bottom - scroll.frame.minY
        let origin = scroll.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(.init(dx: scroll.frame.width - 10, dy: visibleHeight * 0.8))
        let finish = origin.withOffset(.init(dx: scroll.frame.width - 10, dy: visibleHeight * 0.25))
        if element.exists && element.frame.minY < scroll.frame.minY + 50 {
          finish.press(forDuration: 0.05, thenDragTo: start)
        } else {
          start.press(forDuration: 0.05, thenDragTo: finish)
        }
      }
      XCTAssertTrue(element.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertTrue(element.isHittable, application.debugDescription)
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
