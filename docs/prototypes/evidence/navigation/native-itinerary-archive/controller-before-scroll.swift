import XCTest

#if os(iOS)
  @MainActor
  final class ItineraryArchiveJourneyTests: XCTestCase {
    func testArchivedItineraryCanBeFoundAndUnarchivedWithoutChangingItsChildren() {
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
      application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
      let archive = application.plannerElement("Archive Itinerary")
      capture("Itinerary action menu before archive")
      XCTAssertTrue(archive.waitForExistence(timeout: 5), application.debugDescription)
      archive.activateForPlannerJourney()
      let archived = application.staticTexts["Archived Itinerary"].firstMatch
      reveal(archived, application: application)
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].exists)
      XCTAssertTrue(application.staticTexts["Keep these route notes"].exists)
      capture("Archived Itinerary retains its content and child progress")
      openCatalog(application)
      XCTAssertTrue(row.waitForNonExistence(timeout: 10))
      chooseArchive("Archived Itineraries", application: application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      XCTAssertTrue((row.value as? String)?.hasPrefix("Archived.") == true)
      chooseArchive("All Itineraries", application: application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      XCTAssertEqual(application.buttons.matching(identifier: identity).count, 1)
      capture("All Itineraries includes the archived source once")
      application.terminate()
      application.launchSavedPlannerJourney()
      openCatalog(application)
      XCTAssertTrue(row.waitForNonExistence(timeout: 10))
      chooseArchive("Archived Itineraries", application: application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      reveal(archived, application: application)
      XCTAssertTrue(application.staticTexts["Keep these route notes"].exists)
      let map = application.descendants(matching: .any).matching(identifier: "map.location")
        .firstMatch
      reveal(map, application: application)
      reveal(child, application: application)
      XCTAssertEqual(child.identifier, childIdentity)
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      application.openPlannerSection("Items")
      let source = application.savedPlannerItemRows("Route child").firstMatch
      XCTAssertTrue(source.waitForExistence(timeout: 10))
      source.activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.item.completion").waitForPlannerBooleanState(false))
      openCatalog(application)
      chooseArchive("Archived Itineraries", application: application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      row.activateForPlannerJourney()
      application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
      application.plannerElement("Unarchive Itinerary").activateForPlannerJourney()
      XCTAssertTrue(archived.waitForNonExistence(timeout: 10))
      reveal(child, application: application)
      XCTAssertEqual(child.identifier, childIdentity)
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      openCatalog(application)
      XCTAssertTrue(row.waitForNonExistence(timeout: 10))
      chooseArchive("Active Itineraries", application: application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      XCTAssertTrue((row.value as? String)?.hasPrefix("Active.") == true)
      application.terminate()
      application.launchSavedPlannerJourney()
      openCatalog(application)
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, identity)
      row.activateForPlannerJourney()
      reveal(child, application: application)
      XCTAssertEqual(child.identifier, childIdentity)
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      capture("Unarchived Itinerary retains the same Todo child after relaunch")
    }

    private func chooseArchive(_ title: String, application: XCUIApplication) {
      application.plannerElement("saved.itineraries.archive").activateForPlannerJourney()
      let option = application.plannerElement(title)
      XCTAssertTrue(option.waitForExistence(timeout: 5), application.debugDescription)
      option.activateForPlannerJourney()
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
          XCTFail("No visible scroll surface: \(application.debugDescription)")
          return
        }
        let start = scroll.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: 0.8))
        let finish = scroll.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: 0.25))
        if element.exists && element.frame.minY < scroll.frame.minY + 50 {
          finish.press(forDuration: 0.05, thenDragTo: start)
        } else {
          start.press(forDuration: 0.05, thenDragTo: finish)
        }
      }
      XCTAssertTrue(element.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertTrue(element.isHittable, application.debugDescription)
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
