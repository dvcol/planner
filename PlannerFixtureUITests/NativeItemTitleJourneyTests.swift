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
