import CoreGraphics
import ImageIO
import XCTest

#if os(iOS)
  import UIKit
#endif

extension XCUIApplication {
  /// Check the colorful fixture pixels inside the preview rather than its availability label.
  func hasPaintedPlannerPreview(_ card: XCUIElement) -> Bool {
    guard card.exists else { return false }
    let cardFrame = card.frame
    let windowFrame = windows.firstMatch.frame
    guard !cardFrame.isEmpty, !windowFrame.isEmpty else { return false }
    let snapshot = screenshot().pngRepresentation
    guard let source = CGImageSourceCreateWithData(snapshot as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return false }
    let scale = CGFloat(image.width) / windowFrame.width
    let imageFrame = CGRect(
      x: cardFrame.minX * scale, y: cardFrame.minY * scale,
      width: cardFrame.width * scale, height: cardFrame.height * scale / 2)
    guard let top = image.cropping(to: imageFrame) else { return false }
    var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
    let drewImage = pixels.withUnsafeMutableBytes { buffer in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
          bytesPerRow: 32 * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue)
      else { return false }
      context.draw(top, in: CGRect(x: 0, y: 0, width: 32, height: 32))
      return true
    }
    guard drewImage else { return false }
    let coloredPixels = stride(from: 0, to: pixels.count, by: 4).filter { offset in
      let channels = [Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2])]
      return (channels.max() ?? 0) - (channels.min() ?? 0) > 40
    }.count
    return coloredPixels > 256
  }

  func openSavedPlannerCatalogAddMenu() {
    openSavedPlannerMenu(identifier: "saved.item.addMenu", title: "Add")
  }

  func openSavedPlannerNewItemEditor() {
    openSavedPlannerCatalogAddMenu()
    let newItem = plannerElement("saved.item.new")
    XCTAssertTrue(newItem.waitForExistence(timeout: 5))
    newItem.activateForPlannerJourney()
  }

  func openSavedPlannerCaptureEditor() {
    openSavedPlannerCatalogAddMenu()
    plannerElement("saved.capture.new").activateForPlannerJourney()
  }

  func openSavedPlannerListAddMenu() {
    openSavedPlannerMenu(identifier: "saved.list.addMenu", title: "Add")
  }

  func savedPlannerListAddControl() -> XCUIElement {
    savedPlannerMenu(identifier: "saved.list.addMenu", title: "Add")
  }

  func openSavedPlannerListActionsMenu() {
    openSavedPlannerMenu(identifier: "saved.list.actions", title: "List actions")
  }

  func savedPlannerListSortControl() -> XCUIElement {
    savedPlannerMenu(identifier: "saved.list.sort", title: "Sort")
  }

  func savedPlannerListEditControl() -> XCUIElement {
    savedPlannerMenu(identifier: "saved.list.edit", title: "Edit")
  }

  func dismissSavedPlannerListOverflow() {
    #if os(iOS)
      let editing = collectionViews.buttons.matching(
        NSPredicate(format: "label == %@ OR label == %@", "Edit", "Done")
      ).firstMatch
      guard editing.exists else { return }
      let title = navigationBars.staticTexts.firstMatch
      XCTAssertTrue(title.exists)
      title.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).tap()
      XCTAssertTrue(editing.waitForNonExistence(timeout: 5))
    #endif
  }

  private func openSavedPlannerMenu(identifier: String, title: String) {
    savedPlannerMenu(identifier: identifier, title: title).activateForPlannerJourney()
  }

  private func savedPlannerMenu(identifier: String, title: String) -> XCUIElement {
    var menu = plannerElement(identifier)
    if !menu.exists || !menu.isHittable {
      #if os(macOS)
        let overflow = windows.firstMatch.popUpButtons["more toolbar items"].firstMatch
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        overflow.activateForPlannerJourney()
      #else
        let contentBar = navigationBars.allElementsBoundByIndex.last {
          $0.identifier != "Planner"
            && $0.buttons["OverflowBarButtonItem"].firstMatch.isHittable
        }
        guard let contentBar else {
          XCTFail("The selected catalog's \(title) menu is unavailable")
          return menu
        }
        contentBar.buttons["OverflowBarButtonItem"].firstMatch.activateForPlannerJourney()
        if !menu.exists {
          switch identifier {
          case "saved.list.sort":
            menu =
              collectionViews.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Sort: ")
              ).firstMatch
          case "saved.list.edit":
            menu =
              collectionViews.buttons.matching(
                NSPredicate(format: "label == %@ OR label == %@", "Edit", "Done")
              ).firstMatch
          default:
            menu = collectionViews.buttons[title].firstMatch
          }
        }
      #endif
    }
    XCTAssertTrue(menu.waitForExistence(timeout: 5))
    return menu
  }

  func launchSavedPlannerJourney() {
    launch()
    #if os(macOS)
      if !windows.firstMatch.waitForExistence(timeout: 3) {
        menuBars.menuBarItems["File"].click()
        menuItems["New Window"].click()
        XCTAssertTrue(windows.firstMatch.waitForExistence(timeout: 5))
      }
      let restoredWindowCount = windows.count
      for _ in 1..<max(1, restoredWindowCount) {
        let identifier = windows.firstMatch.identifier
        let window = windows.matching(NSPredicate(format: "identifier == %@", identifier))
          .firstMatch
        window.buttons["_XCUI:CloseWindow"].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
      }
    #endif
  }

  #if os(macOS)
    func fillSavedPlannerWindowForJourney() {
      activate()
      menuBars.menuBarItems["Window"].click()
      let fill = menuItems.matching(identifier: "_zoomFill:").firstMatch
      XCTAssertTrue(fill.waitForExistence(timeout: 5))
      guard fill.isEnabled else {
        menuBars.menuBarItems["Window"].click()
        return
      }
      fill.click()
    }
  #endif

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
      let option = menuItems.matching(NSPredicate(format: "title == %@", title)).firstMatch
    #else
      let option = buttons.matching(
        NSPredicate(
          format: "(label == %@ OR identifier == %@) AND identifier != %@",
          title, title, "saved.filters.done")
      ).firstMatch
    #endif
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
      switch identifier {
      case "saved.list.estimate.edit", "saved.list.delete":
        let identified = buttons[identifier]
        if identified.exists { return identified }
        let title = identifier == "saved.list.delete" ? "Delete list" : "Edit list"
        return collectionViews.buttons[title].firstMatch
      default:
        return buttons[identifier]
      }
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
    let savedSection = plannerElement("saved.section.\(title.lowercased())")
    #if os(macOS)
      activate()
      let savedSectionExists = savedSection.waitForExistence(timeout: 5)
    #else
      var savedSectionExists = savedSection.exists
    #endif
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .pad {
        if !savedSection.exists {
          let sidebar = buttons["Show Sidebar"].firstMatch
          if sidebar.exists { sidebar.activateForPlannerJourney() }
        }
        let sidebarCatalog = collectionViews["saved.lists.catalog"].firstMatch
        if sidebarCatalog.exists && sidebarCatalog.isHittable {
          for _ in 0..<60 {
            if savedSection.exists && savedSection.isHittable { break }
            sidebarCatalog.swipeDown()
          }
        }
        savedSectionExists = savedSection.exists
      }
    #endif
    if savedSectionExists {
      XCTAssertTrue(savedSection.waitForPlannerHittability())
      savedSection.activateForPlannerJourney()
      return
    }
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

  func beginPlannerListCreation() {
    openPlannerSection("Lists")
    let create = plannerElement("saved.list.new")
    #if os(macOS)
      if create.exists && create.isHittable {
        create.activateForPlannerJourney()
        return
      }
      let overflow = windows.firstMatch.popUpButtons["more toolbar items"]
      XCTAssertTrue(overflow.waitForExistence(timeout: 5), windows.firstMatch.debugDescription)
      overflow.activateForPlannerJourney()
      let nativeCreate = overflow.menuItems["New list"]
      XCTAssertTrue(nativeCreate.waitForExistence(timeout: 5), windows.firstMatch.debugDescription)
      nativeCreate.activateForPlannerJourney()
    #else
      for _ in 0..<3 {
        if create.exists && create.isHittable {
          create.activateForPlannerJourney()
          return
        }
        if let overflow = navigationBars["Planner"].buttons.matching(
          identifier: "OverflowBarButtonItem"
        ).allElementsBoundByIndex.first(where: \.isHittable) {
          overflow.activateForPlannerJourney()
          let nativeCreate = plannerElement("New list")
          XCTAssertTrue(
            nativeCreate.waitForExistence(timeout: 5), windows.firstMatch.debugDescription)
          nativeCreate.activateForPlannerJourney()
          return
        }
        let sidebar = buttons["Show Sidebar"].firstMatch
        if sidebar.exists && sidebar.isHittable {
          sidebar.activateForPlannerJourney()
          continue
        }
        let back = buttons["BackButton"].firstMatch
        guard back.exists && back.isHittable else { break }
        back.activateForPlannerJourney()
      }
      XCTFail("Planner's native New List action is unavailable.")
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
      let nativeTitle = title
      if !nativeTitle.isEmpty { return nativeTitle }
      return label
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
