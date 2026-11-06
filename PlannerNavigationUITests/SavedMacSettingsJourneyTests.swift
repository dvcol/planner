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
      for identifier in ["saved.lists.sort", "saved.lists.archive"] {
        XCTAssertTrue(
          application.plannerElement(identifier).waitForPlannerHittability(), identifier)
      }
      application.plannerElement("saved.section.items").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.items.catalog").waitForExistence(timeout: 10))
      let window = application.windows.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "planner-main-")
      ).firstMatch
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
      application.menuBars.menuBarItems["View"].click()
      application.menuItems["Enter Full Screen"].click()
      application.menuBars.menuBarItems["View"].click()
      XCTAssertTrue(application.menuItems["Exit Full Screen"].waitForExistence(timeout: 10))
      application.menuBars.menuBarItems["View"].click()
      window.toolbars.firstMatch.hover()
      for identifier in [
        "saved.items.representation", "saved.items.filters", "saved.items.sort",
        "saved.item.addMenu",
      ] {
        XCTAssertTrue(
          application.plannerElement(identifier).waitForPlannerHittability(), identifier)
      }
      record(application, name: "Labeled collection actions remain visible in full screen")
      application.menuBars.menuBarItems["View"].click()
      application.menuItems["Exit Full Screen"].click()
      XCTAssertTrue(window.buttons["_XCUI:CloseWindow"].waitForExistence(timeout: 10))
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

    func testMenuBarOpensSettingsAndReopensTheMainWindow() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      let status = application.statusItems.firstMatch
      XCTAssertTrue(status.waitForExistence(timeout: 5))
      status.click()
      let menu = status.menus.firstMatch
      for title in ["Open Plan 2Do", "Go to", "New Item", "New List", "Settings…", "Quit Plan 2Do"]
      {
        XCTAssertTrue(menu.menuItems[title].waitForExistence(timeout: 5), title)
      }
      let screenshot = XCTAttachment(screenshot: menu.screenshot())
      screenshot.name = "Plan 2Do menu bar navigation and actions"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      menu.menuItems["Settings…"].click()
      XCTAssertTrue(application.plannerElement("saved.settings.back").waitForExistence(timeout: 10))
      let mainWindows = application.windows.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "planner-main-"))
      mainWindows.firstMatch.buttons["_XCUI:CloseWindow"].click()
      XCTAssertTrue(mainWindows.firstMatch.waitForNonExistence(timeout: 10))
      status.click()
      status.menus.firstMatch.menuItems["Open Plan 2Do"].click()
      XCTAssertTrue(mainWindows.firstMatch.waitForExistence(timeout: 10))
      XCTAssertTrue(application.plannerElement("saved.section.items").waitForPlannerHittability())
      record(application, name: "Menu bar reopens Planner after its last window closes")
    }

    private func record(_ application: XCUIApplication, name: String) {
      let window = application.windows.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "planner-main-")
      ).firstMatch
      let screenshot = XCTAttachment(screenshot: window.screenshot())
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
