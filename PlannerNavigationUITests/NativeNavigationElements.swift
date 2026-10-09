import XCTest

extension XCUIApplication {
  /// Native Mac rows and menus expose different accessibility roles from mobile navigation buttons.
  func plannerElement(_ identifier: String) -> XCUIElement {
    #if os(macOS)
      descendants(matching: .any)[identifier]
    #else
      buttons[identifier]
    #endif
  }

  func choosePrototypeLayout(_ title: String) {
    #if os(macOS)
      let prototypeMenu = menuBars.menuBarItems["Prototype"]
      XCTAssertTrue(prototypeMenu.waitForExistence(timeout: 5))
      prototypeMenu.click()
      menuItems["About navigation prototype"].click()
      XCTAssertTrue(
        staticTexts["Planner data is read-only. Only local view preferences are saved."]
          .waitForExistence(timeout: 5))
      plannerElement("prototype.information.close").click()
      prototypeMenu.click()
      let layout = menuItems[title]
      XCTAssertTrue(layout.waitForExistence(timeout: 5))
      layout.click()
    #else
      let information = buttons["prototype.information"]
      if !information.exists { plannerElement("Show Sidebar").tap() }
      XCTAssertTrue(
        information.waitForExistence(timeout: 5), windows.firstMatch.debugDescription)
      information.tap()
      XCTAssertTrue(
        staticTexts["Planner data is read-only. Only local view preferences are saved."].exists)
      let layout = buttons[title]
      XCTAssertTrue(layout.waitForExistence(timeout: 5))
      layout.tap()
      buttons["prototype.information.close"].tap()
    #endif
  }

  func openPlannerSection(_ title: String) {
    #if os(macOS)
      let section = plannerElement("nav.\(title.lowercased())")
    #else
      /// Native floating tabs expose both their cell and child Button with the same label.
      let section = buttons[title].firstMatch
    #endif
    if !section.exists {
      let sidebar = plannerElement("Show Sidebar")
      XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
      sidebar.activateForPlannerJourney()
    }
    XCTAssertTrue(section.waitForExistence(timeout: 5))
    section.activateForPlannerJourney()
    #if os(iOS)
      let sidebar = buttons["Show Sidebar"]
      if sidebar.exists { sidebar.tap() }
    #endif
  }

  func openItemDiagnostics() {
    plannerElement("detail.actions").activateForPlannerJourney()
    plannerElement("Prototype diagnostics").activateForPlannerJourney()
    XCTAssertTrue(plannerElement("detail.diagnostics.close").waitForExistence(timeout: 5))
  }

  func closeItemDiagnostics() {
    plannerElement("detail.diagnostics.close").activateForPlannerJourney()
  }
}

extension XCUIElement {
  var plannerProgressFraction: Double? {
    #if os(macOS)
      value as? Double
    #else
      guard let percentage = value as? String else { return nil }
      let percentageFormatter = NumberFormatter()
      percentageFormatter.numberStyle = .percent
      return percentageFormatter.number(from: percentage)?.doubleValue
    #endif
  }

  var plannerControlTitle: String {
    #if os(macOS)
      title
    #else
      label
    #endif
  }

  func activateForPlannerJourney() {
    #if os(macOS)
      click()
    #else
      tap()
    #endif
  }
}
