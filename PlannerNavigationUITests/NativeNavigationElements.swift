import CoreGraphics
import XCTest

extension XCUIApplication {
  func launchSavedPlannerJourney() {
    launch()
    #if os(macOS)
      if !windows.firstMatch.waitForExistence(timeout: 3) {
        menuBars.menuBarItems["File"].click()
        menuItems["New Window"].click()
        XCTAssertTrue(windows.firstMatch.waitForExistence(timeout: 5))
      }
    #endif
  }

  func savedPlannerItemRows(_ title: String) -> XCUIElementQuery {
    #if os(macOS)
      return descendants(matching: .any).matching(
        NSPredicate(
          format:
            "(identifier BEGINSWITH %@ OR identifier BEGINSWITH %@) AND (label == %@ OR value == %@)",
          "saved.item.", "saved.appearance.", title, title))
    #else
      buttons.matching(
        NSPredicate(
          format: "(identifier BEGINSWITH %@ OR identifier BEGINSWITH %@) AND label == %@",
          "saved.item.", "saved.appearance.", title))
    #endif
  }

  func savedPlannerListRow(_ title: String) -> XCUIElement {
    buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.list.", title)
    ).firstMatch
  }

  func chooseSavedPlannerStateFilter(_ title: String, control: XCUIElement) {
    let pickerIdentifier: String
    switch title {
    case "Todo", "Done", "All completion states":
      pickerIdentifier = "saved.filters.completion"
    case "Active", "Archived", "All archive states":
      pickerIdentifier = "saved.filters.archive"
    case "Scheduled", "Unscheduled", "All scheduling states":
      pickerIdentifier = "saved.filters.scheduled"
    default:
      XCTFail("Unknown Planner state filter: \(title)")
      return
    }
    control.activateForPlannerJourney()
    let picker = plannerElement(pickerIdentifier)
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.activateForPlannerJourney()
    #if os(macOS)
      let choices = descendants(matching: .any)
    #else
      let choices = buttons
    #endif
    let option = choices.matching(
      NSPredicate(
        format: "(label == %@ OR identifier == %@) AND identifier != %@",
        title, title, "saved.filters.done")
    ).firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    XCTAssertTrue(option.waitForPlannerHittability())
    option.activateForPlannerJourney()
    plannerElement("saved.filters.done").activateForPlannerJourney()
  }

  /// Keep filter controls below the native navigation bar before tapping them.
  func revealSavedPlannerFilter(_ identifier: String) {
    let control = descendants(matching: .any).matching(identifier: identifier).firstMatch
    #if os(iOS)
      let form = descendants(matching: .any).matching(identifier: "saved.filters.form").firstMatch
      XCTAssertTrue(form.waitForExistence(timeout: 5))
      let navigationBar = navigationBars["Filters"]
      XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
      for _ in 0..<8 {
        let visibleTop = navigationBar.frame.maxY + 4
        let visibleBottom = form.frame.maxY - 4
        if control.exists, control.isHittable,
          control.frame.minY >= visibleTop, control.frame.maxY <= visibleBottom
        {
          return
        }
        let needsDownwardScroll = control.exists && control.frame.midY < visibleTop
        let start = form.coordinate(
          withNormalizedOffset: CGVector(dx: 0.5, dy: needsDownwardScroll ? 0.4 : 0.8))
        let end = form.coordinate(
          withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        start.press(forDuration: 0.05, thenDragTo: end)
      }
      XCTFail("The filter control did not reach the visible Form: \(identifier)")
    #else
      XCTAssertTrue(control.waitForExistence(timeout: 5))
      XCTAssertTrue(control.waitForPlannerHittability())
    #endif
  }

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
    #if os(iOS)
      let identifier: String?
      switch title {
      case "Lists": identifier = "list.bullet"
      case "Items": identifier = "square.stack"
      case "Inbox": identifier = "tray"
      case "Itineraries": identifier = "point.topleft.down.to.point.bottomright.curvepath"
      default: identifier = nil
      }
      if let identifier,
        let tab = buttons.matching(identifier: identifier).allElementsBoundByIndex.first(
          where: \.isHittable)
      {
        tab.tap()
        XCTAssertEqual(
          XCTWaiter.wait(
            for: [
              XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "selected == true"), object: tab)
            ], timeout: 5), .completed)
        let sidebar = buttons["Show Sidebar"]
        if sidebar.exists { sidebar.tap() }
        return
      }
    #endif
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
  func waitForPlannerValue(_ expected: String) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: 5)
      == .completed
  }

  func waitForPlannerHittability() -> Bool {
    let predicate = NSPredicate(format: "hittable == true")
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: 5)
      == .completed
  }

  var plannerBooleanState: Bool? {
    if let number = value as? NSNumber {
      if number.intValue == 0 { return false }
      if number.intValue == 1 { return true }
      return nil
    }
    switch value as? String {
    case "0": return false
    case "1": return true
    default: return nil
    }
  }

  func waitForPlannerBooleanState(_ expected: Bool) -> Bool {
    let predicate = NSPredicate(
      format: "value == %@ OR value == %@", NSNumber(value: expected), expected ? "1" : "0")
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: 5)
      == .completed
  }

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
