import XCTest

#if os(macOS)
  @MainActor
  final class SavedMacSettingsJourneyTests: XCTestCase {
    func testSettingsUsesTheMainResizableWindowAndReturnsToTheSelectedCollection() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.fillSavedPlannerWindowForJourney()
      application.plannerElement("saved.section.items").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.items.catalog").waitForExistence(timeout: 10))
      let window = application.windows.firstMatch
      let windowCount = application.windows.count
      application.openSavedPlannerSettings()
      let back = application.plannerElement("saved.settings.back")
      XCTAssertTrue(back.waitForExistence(timeout: 10))
      XCTAssertEqual(application.windows.count, windowCount)
      XCTAssertEqual(application.sheets.count, 0)
      let tunnel = application.textFields["saved.agent.tunnel.id"]
      XCTAssertTrue(tunnel.waitForExistence(timeout: 5))
      XCTAssertTrue(tunnel.isHittable)
      XCTAssertGreaterThan(tunnel.frame.width, 300)
      record(application, name: "Settings in the main window at full width")
      window.resizePlannerWindowForJourney(width: 1000)
      XCTAssertTrue(back.isHittable)
      XCTAssertTrue(tunnel.isHittable)
      XCTAssertTrue(window.frame.contains(tunnel.frame))
      record(application, name: "Native settings form after resizing the main window")
      back.activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.items.catalog").waitForExistence(timeout: 10))
      application.fillSavedPlannerWindowForJourney()
      let filledHeight = window.frame.height
      application.typeKey("f", modifierFlags: [.command, .control])
      let enteredFullScreen = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in window.frame.height > filledHeight + 10 }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [enteredFullScreen], timeout: 10), .completed)
      for identifier in [
        "saved.items.representation", "saved.items.filters", "saved.items.sort",
        "saved.item.addMenu",
      ] {
        XCTAssertTrue(
          application.plannerElement(identifier).waitForPlannerHittability(), identifier)
      }
      record(application, name: "Labeled collection actions remain visible in full screen")
      application.typeKey("f", modifierFlags: [.command, .control])
      let exitedFullScreen = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in abs(window.frame.height - filledHeight) < 8 }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [exitedFullScreen], timeout: 10), .completed)
      application.plannerElement("saved.section.settings").activateForPlannerJourney()
      XCTAssertTrue(back.waitForExistence(timeout: 5))
      application.plannerElement("saved.section.inbox").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.inbox.catalog").waitForExistence(timeout: 10))
      XCTAssertFalse(back.exists)
    }

    func testSettingsCommandReviewsAnUnsavedItemBeforeNavigating() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.fillSavedPlannerWindowForJourney()
      application.plannerElement("saved.section.items").activateForPlannerJourney()
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Unsaved settings navigation")
      application.openSavedPlannerSettings()
      let keep = application.buttons["Keep editing"].firstMatch
      XCTAssertTrue(keep.waitForExistence(timeout: 5))
      keep.activateForPlannerJourney()
      XCTAssertEqual(title.value as? String, "Unsaved settings navigation")
      XCTAssertFalse(application.plannerElement("saved.settings.back").exists)
      application.openSavedPlannerSettings()
      application.buttons["Discard"].firstMatch.activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.settings.back").waitForExistence(timeout: 5))
      record(application, name: "Settings command preserves the existing draft review")
    }

    private func record(_ application: XCUIApplication, name: String) {
      let screenshot = XCTAttachment(screenshot: application.screenshot())
      screenshot.name = name
      screenshot.lifetime = .keepAlways
      add(screenshot)
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "\(name) hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
  }
#endif
