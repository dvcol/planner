import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class NativeItemTitleJourneyTests: XCTestCase {
    func testGlobalItemUsesItsNativeTitleWithoutRepeatingItInTheDetailForm() {
      continueAfterFailure = false
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "retired-membership", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let name = "Retired stop hotel"
      let source = application.savedPlannerItemRows(name).firstMatch
      XCTAssertTrue(source.waitForExistence(timeout: 15))
      let sourceIdentifier = source.identifier
      source.activateForPlannerJourney()
      let completion = application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
      XCTAssertTrue(completion.waitForExistence(timeout: 10))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let nativeTitle = application.navigationBars.staticTexts[name].firstMatch
      XCTAssertTrue(nativeTitle.waitForExistence(timeout: 10))
      XCTAssertEqual(nativeTitle.label, name)
      let detail = application.collectionViews.containing(
        .any, identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(detail.waitForExistence(timeout: 10), application.debugDescription)
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Global Item native title and detail Form"
      capture.lifetime = .keepAlways
      add(capture)
      XCTAssertEqual(
        detail.staticTexts.matching(NSPredicate(format: "label == %@", name)).count, 0,
        "The native Item title should not be repeated inside its detail Form.")
      XCTAssertTrue(
        application.staticTexts["Keep the original hotel note"].waitForExistence(timeout: 10))
      XCTAssertTrue(application.plannerElement("saved.item.actions").isHittable)
      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(sourceIdentifier).waitForExistence(timeout: 10))
      application.terminate()
    }

    func testListAppearanceUsesItsNativeTitleWithoutRepeatingItInTheDetailForm() {
      continueAfterFailure = false
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "retired-membership", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Lists")
      let list = application.savedPlannerListRow("Retired stop plan")
      XCTAssertTrue(list.waitForExistence(timeout: 15))
      list.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      application.openSavedPlannerListAddMenu()
      application.plannerElement("saved.list.add").activateForPlannerJourney()
      let name = "Retired stop hotel"
      let candidate = application.staticTexts[name].firstMatch
      XCTAssertTrue(candidate.waitForExistence(timeout: 10))
      candidate.activateForPlannerJourney()
      let add = application.plannerElement("saved.membership.add")
      XCTAssertTrue(add.isEnabled)
      add.activateForPlannerJourney()
      XCTAssertTrue(add.waitForNonExistence(timeout: 10))
      let appearance = application.savedPlannerItemRows(name).firstMatch
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      appearance.activateForPlannerJourney()
      let context = "In Retired stop plan"
      XCTAssertTrue(application.staticTexts[context].waitForExistence(timeout: 10))
      let nativeTitle = application.navigationBars.staticTexts[name].firstMatch
      XCTAssertTrue(nativeTitle.waitForExistence(timeout: 10))
      XCTAssertEqual(nativeTitle.label, name)
      let detail = application.collectionViews.containing(.staticText, identifier: context)
        .firstMatch
      XCTAssertTrue(detail.waitForExistence(timeout: 10), application.debugDescription)
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "List appearance native title and detail Form"
      capture.lifetime = .keepAlways
      self.add(capture)
      XCTAssertEqual(
        detail.staticTexts.matching(NSPredicate(format: "label == %@", name)).count, 0,
        "The native List appearance title should not be repeated inside its detail Form.")
      XCTAssertTrue(application.staticTexts["Keep the original hotel note"].exists)
      XCTAssertTrue(application.plannerElement("saved.appearance.actions").isHittable)
      application.terminate()
    }

    func testCalendarItemKeepsItsNativeTitleAndSavedContextAfterReturningFromItsGuide()
      async throws
    {
      continueAfterFailure = false
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
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
      let sourceRow = application.savedPlannerItemRows("Hotel").firstMatch
      XCTAssertTrue(sourceRow.waitForExistence(timeout: 15))
      let sourceIdentifier = sourceRow.identifier
      sourceRow.activateForPlannerJourney()
      let itemActions = application.plannerElement("saved.item.actions")
      XCTAssertTrue(itemActions.waitForExistence(timeout: 10))
      itemActions.activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      let saveSchedule = application.plannerElement("saved.schedule.save")
      XCTAssertTrue(saveSchedule.waitForExistence(timeout: 10))
      XCTAssertTrue(saveSchedule.isEnabled)
      saveSchedule.activateForPlannerJourney()
      let originalSchedule = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
      ).firstMatch
      XCTAssertTrue(originalSchedule.waitForExistence(timeout: 10))
      let scheduleIdentifier = originalSchedule.identifier
      let scheduleDescription = try XCTUnwrap(originalSchedule.value as? String)
      application.openPlannerSection("Calendar")
      let booking = application.descendants(matching: .any).matching(
        identifier: scheduleIdentifier.replacingOccurrences(
          of: "saved.item.schedule.", with: "saved.calendar.schedule.")
      ).firstMatch
      XCTAssertTrue(booking.waitForExistence(timeout: 10))
      booking.activateForPlannerJourney()
      let completion = application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
      XCTAssertTrue(completion.waitForExistence(timeout: 10))
      XCTAssertTrue(completion.isHittable)
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let nativeTitle = application.navigationBars.staticTexts["Hotel"].firstMatch
      XCTAssertTrue(nativeTitle.waitForExistence(timeout: 10))
      let detailForm = application.collectionViews.containing(
        .any, identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(detailForm.waitForExistence(timeout: 10), application.debugDescription)
      let selectedCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      selectedCapture.name = "Calendar Item has one native title and its original content"
      selectedCapture.lifetime = .keepAlways
      add(selectedCapture)
      let repeatedHeadings = detailForm.staticTexts.matching(
        NSPredicate(format: "label == %@", "Hotel")
      ).allElementsBoundByIndex.filter {
        $0.isHittable && $0.frame.maxY <= completion.frame.minY
      }
      XCTAssertEqual(
        repeatedHeadings.count, 0,
        "Calendar must retain the native Item title without repeating it inside the detail Form.")
      XCTAssertTrue(application.staticTexts["Original notes"].exists)
      let detailFrame = detailForm.frame
      XCTAssertGreaterThan(detailFrame.height, 200)
      let window = application.windows.firstMatch
      let windowOrigin = window.coordinate(withNormalizedOffset: .init(dx: 0, dy: 0))
      let lowerScrollPoint = windowOrigin.withOffset(
        .init(
          dx: detailFrame.maxX - window.frame.minX - 8,
          dy: detailFrame.minY - window.frame.minY + detailFrame.height * 0.8))
      let upperScrollPoint = windowOrigin.withOffset(
        .init(
          dx: detailFrame.maxX - window.frame.minX - 8,
          dy: detailFrame.minY - window.frame.minY + detailFrame.height * 0.25))
      let bookmark = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
      ).firstMatch
      for _ in 0..<8 where !bookmark.isHittable {
        lowerScrollPoint.press(forDuration: 0.05, thenDragTo: upperScrollPoint)
      }
      XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
      XCTAssertTrue(bookmark.isHittable)
      let bookmarkIdentifier = bookmark.identifier
      XCTAssertEqual(bookmark.value as? String, destination.absoluteString)
      bookmark.activateForPlannerJourney()
      let page = application.webViews.firstMatch
      XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
      XCTAssertTrue(server.requestLines.contains("GET /guide HTTP/1.1"))
      let returnToItem = application.plannerElement("saved.browser.return")
      XCTAssertEqual(returnToItem.label, "Return to item")
      returnToItem.activateForPlannerJourney()
      XCTAssertTrue(page.waitForNonExistence(timeout: 10))
      XCTAssertTrue(nativeTitle.waitForExistence(timeout: 10))
      XCTAssertFalse(application.alerts.firstMatch.exists)
      let retainedBookmark = application.descendants(matching: .any)
        .matching(identifier: bookmarkIdentifier).firstMatch
      for _ in 0..<8 where !retainedBookmark.isHittable {
        lowerScrollPoint.press(forDuration: 0.05, thenDragTo: upperScrollPoint)
      }
      XCTAssertTrue(retainedBookmark.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedBookmark.value as? String, destination.absoluteString)
      for _ in 0..<8 where !completion.isHittable {
        upperScrollPoint.press(forDuration: 0.05, thenDragTo: lowerScrollPoint)
      }
      XCTAssertTrue(completion.isHittable)
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let returnedHeadings = detailForm.staticTexts.matching(
        NSPredicate(format: "label == %@", "Hotel")
      ).allElementsBoundByIndex.filter {
        $0.isHittable && $0.frame.maxY <= completion.frame.minY
      }
      XCTAssertEqual(returnedHeadings.count, 0)
      XCTAssertTrue(application.staticTexts["Original notes"].exists)
      XCTAssertTrue(originalSchedule.waitForExistence(timeout: 10))
      XCTAssertEqual(originalSchedule.identifier, scheduleIdentifier)
      XCTAssertEqual(originalSchedule.value as? String, scheduleDescription)
      let returnedCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      returnedCapture.name = "Calendar guide returns to the same Item title and booking"
      returnedCapture.lifetime = .keepAlways
      add(returnedCapture)
      application.openPlannerSection("Items")
      if !application.plannerElement(sourceIdentifier).exists {
        let back = application.navigationBars.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), application.debugDescription)
        back.activateForPlannerJourney()
      }
      XCTAssertTrue(application.plannerElement(sourceIdentifier).waitForExistence(timeout: 10))
      application.terminate()
    }

    func testItineraryAppearanceUsesItsNativeTitleWithoutRepeatingItInTheDetailForm() {
      continueAfterFailure = false
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "pinned-itinerary", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Itineraries")
      let itinerary = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.",
          "Museum route")
      ).firstMatch
      XCTAssertTrue(itinerary.waitForExistence(timeout: 15))
      itinerary.activateForPlannerJourney()
      let itineraryTitle = application.staticTexts["saved.itinerary.title"].firstMatch
      XCTAssertTrue(itineraryTitle.waitForExistence(timeout: 15), application.debugDescription)
      XCTAssertEqual(itineraryTitle.label, "Museum route")
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))
      let itineraryContents = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.contents").firstMatch
      XCTAssertTrue(itineraryContents.waitForExistence(timeout: 10), application.debugDescription)
      let name = "Route child"
      let appearance = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.",
          name)
      ).firstMatch
      for _ in 0..<8 {
        if appearance.exists && appearance.isHittable { break }
        guard itineraryContents.frame.height > 200 else {
          XCTFail("The itinerary must have a visible List: \(application.debugDescription)")
          return
        }
        let start = itineraryContents.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: 0.8))
        let finish = itineraryContents.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: finish)
      }
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      XCTAssertTrue(appearance.isHittable)
      appearance.activateForPlannerJourney()
      let nativeTitle = application.navigationBars.staticTexts[name].firstMatch
      XCTAssertTrue(nativeTitle.waitForExistence(timeout: 10))
      XCTAssertEqual(nativeTitle.label, name)
      let detail = application.collectionViews.containing(
        .staticText, identifier: "Activity estimate"
      ).firstMatch
      XCTAssertTrue(detail.waitForExistence(timeout: 10), application.debugDescription)
      let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      capture.name = "Itinerary appearance native title and detail Form"
      capture.lifetime = .keepAlways
      add(capture)
      XCTAssertEqual(
        detail.staticTexts.matching(NSPredicate(format: "label == %@", name)).count, 0,
        "The native itinerary appearance title should not be repeated inside its detail Form.")
      XCTAssertTrue(detail.staticTexts["To do"].exists)
      XCTAssertTrue(detail.staticTexts["No estimate"].exists)
      application.terminate()
    }
  }
#endif
