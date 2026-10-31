import CoreGraphics
import ImageIO
import XCTest

#if os(iOS)
  import UIKit
#endif

extension XCUIApplication {
  func activatePlannerFixtureWriterAction(_ identifier: String) {
    plannerElement("fixture.writer.menu").activateForPlannerJourney()
    let action = plannerElement(identifier)
    #if os(iOS)
      let window = windows.firstMatch
      for scrollDirection in [1.0, -1.0] {
        if action.exists && action.isHittable { break }
        for _ in 0..<6 {
          if action.exists && action.isHittable { break }
          guard let menu = collectionViews.allElementsBoundByIndex.last else {
            XCTFail("The native fixture action menu is unavailable.")
            return
          }
          let visibleFrame = menu.frame.intersection(window.frame).insetBy(dx: 4, dy: 12)
          guard visibleFrame.width > 0, visibleFrame.height > 44 else {
            XCTFail("The native fixture menu has no scrollable visible area.")
            return
          }
          let horizontalPosition = (visibleFrame.midX - window.frame.minX) / window.frame.width
          let upperPosition =
            (visibleFrame.minY + visibleFrame.height * 0.3 - window.frame.minY)
            / window.frame.height
          let lowerPosition =
            (visibleFrame.minY + visibleFrame.height * 0.7 - window.frame.minY)
            / window.frame.height
          let upper = window.coordinate(
            withNormalizedOffset: CGVector(dx: horizontalPosition, dy: upperPosition))
          let lower = window.coordinate(
            withNormalizedOffset: CGVector(dx: horizontalPosition, dy: lowerPosition))
          if scrollDirection > 0 {
            upper.press(forDuration: 0.05, thenDragTo: lower)
          } else {
            lower.press(forDuration: 0.05, thenDragTo: upper)
          }
        }
      }
    #endif
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    XCTAssertTrue(action.waitForPlannerHittability())
    action.activateForPlannerJourney()
  }

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

  func openSavedPlannerCollectionSearch() {
    openSavedPlannerMenu(identifier: "saved.collection.search", title: "Search")
  }

  func openSavedPlannerListAddMenu() {
    openSavedPlannerMenu(identifier: "saved.list.addMenu", title: "Add")
  }

  func savedPlannerListAddControl() -> XCUIElement {
    savedPlannerMenu(identifier: "saved.list.addMenu", title: "Add")
  }

  func chooseSavedPlannerCollectionRepresentation(_ title: String) {
    var option = plannerElement("saved.collection.show\(title)")
    if !option.exists {
      #if os(macOS)
        option = menuItems[title].firstMatch
      #else
        option = collectionViews.buttons[title].firstMatch
      #endif
    }
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.activateForPlannerJourney()
  }

  func openSavedPlannerItineraryViewMenu() {
    openSavedPlannerMenu(identifier: "saved.itinerary.representation", title: "View")
  }

  func savedPlannerItineraryEditControl() -> XCUIElement {
    savedPlannerMenu(identifier: "saved.itinerary.edit", title: "Edit itinerary")
  }

  func savedPlannerItineraryActionsControl() -> XCUIElement {
    savedPlannerMenu(identifier: "saved.itinerary.actions", title: "Itinerary actions")
  }

  func savedPlannerItineraryReorderControl() -> XCUIElement {
    savedPlannerMenu(identifier: "saved.itinerary.reorder", title: "Reorder entries")
  }

  func dismissSavedPlannerItineraryOverflow() {
    #if os(iOS)
      let edit = collectionViews.buttons["Edit itinerary"].firstMatch
      guard edit.exists else { return }
      let window = windows.firstMatch
      XCTAssertTrue(window.exists)
      window.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.6)).tap()
      XCTAssertTrue(edit.waitForNonExistence(timeout: 5))
    #endif
  }

  func openSavedPlannerListViewMenu() {
    openSavedPlannerMenu(identifier: "saved.list.representation", title: "View")
  }

  func openSavedPlannerCatalogViewMenu(identifierPrefix: String = "saved.items") {
    openSavedPlannerMenu(identifier: "\(identifierPrefix).representation", title: "View")
  }

  func savedPlannerCatalogSortControl(identifierPrefix: String = "saved.items") -> XCUIElement {
    if identifierPrefix == "saved.lists" {
      return savedPlannerSidebarControl(identifier: "saved.lists.sort", title: "Sort: ")
    }
    return savedPlannerMenu(identifier: "\(identifierPrefix).sort", title: "Sort")
  }

  func openSavedPlannerSettings() {
    #if os(macOS)
      typeKey(",", modifierFlags: .command)
    #else
      savedPlannerSidebarControl(identifier: "saved.settings.open", title: "Settings")
        .activateForPlannerJourney()
    #endif
  }

  func openSavedPlannerLabels() {
    savedPlannerSidebarControl(identifier: "saved.categories.manage", title: "Manage labels")
      .activateForPlannerJourney()
  }

  /// Keep sidebar actions tied to the Planner bar when another pane also has More.
  private func savedPlannerSidebarControl(identifier: String, title: String) -> XCUIElement {
    let direct = plannerElement(identifier)
    if direct.exists && direct.isHittable { return direct }
    #if os(macOS)
      let sidebar = windows.firstMatch.buttons["Show Sidebar"].firstMatch
      if sidebar.exists && sidebar.isHittable { sidebar.activateForPlannerJourney() }
      return savedPlannerMenu(identifier: identifier, title: title)
    #else
      let menuAction = collectionViews.buttons.matching(
        NSPredicate(format: "identifier == %@ OR label BEGINSWITH %@", identifier, title)
      ).firstMatch
      if menuAction.exists && menuAction.isHittable { return menuAction }
      openPlannerSection("Lists")
      for _ in 0..<3 {
        if direct.exists && direct.isHittable { return direct }
        let overflow = navigationBars["Plan 2Do"].buttons["OverflowBarButtonItem"].firstMatch
        if overflow.exists && overflow.isHittable {
          overflow.activateForPlannerJourney()
          XCTAssertTrue(menuAction.waitForExistence(timeout: 5))
          return menuAction
        }
        let sidebar = buttons["Show Sidebar"].firstMatch
        if sidebar.exists && sidebar.isHittable {
          sidebar.activateForPlannerJourney()
          continue
        }
        let back = navigationBars.buttons["BackButton"].firstMatch
        guard back.exists && back.isHittable else { break }
        back.activateForPlannerJourney()
      }
      XCTAssertTrue(direct.waitForExistence(timeout: 5))
      return direct
    #endif
  }

  func dismissSavedPlannerCatalogOverflow() {
    #if os(iOS)
      let sort = collectionViews.buttons.matching(
        NSPredicate(format: "label BEGINSWITH %@", "Sort: ")
      ).firstMatch
      guard sort.exists else { return }
      windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.6)).tap()
      XCTAssertTrue(sort.waitForNonExistence(timeout: 5))
    #endif
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
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .pad, !menu.isHittable,
        let sidebar = buttons.matching(identifier: "Hide Sidebar").allElementsBoundByIndex.first(
          where: \.isHittable)
      {
        sidebar.activateForPlannerJourney()
      }
    #endif
    if !menu.waitForExistence(timeout: 5) || !menu.waitForPlannerHittability() {
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
          XCTContext.runActivity(named: "Unavailable catalog toolbar") { activity in
            let window = windows.firstMatch
            guard window.exists else { return }
            let capture = XCTAttachment(screenshot: window.screenshot())
            capture.name = "Unavailable catalog toolbar owned window"
            capture.lifetime = .keepAlways
            activity.add(capture)
            let hierarchy = XCTAttachment(string: window.debugDescription)
            hierarchy.name = "Unavailable catalog toolbar owned-window hierarchy"
            hierarchy.lifetime = .keepAlways
            activity.add(hierarchy)
          }
          XCTFail("The selected catalog's \(title) menu is unavailable")
          return menu
        }
        contentBar.buttons["OverflowBarButtonItem"].firstMatch.activateForPlannerJourney()
        if !menu.exists {
          switch identifier {
          case "saved.list.sort", "saved.items.sort", "saved.inbox.sort":
            menu =
              collectionViews.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Sort: ")
              ).firstMatch
          case "saved.itinerary.reorder":
            menu =
              collectionViews.buttons.matching(
                NSPredicate(
                  format: "label == %@ OR label == %@ OR label == %@",
                  "Reorder entries", "Edit", "Done")
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
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .pad, !control.isHittable,
        let sidebar = buttons.matching(identifier: "Hide Sidebar").allElementsBoundByIndex.first(
          where: \.isHittable)
      {
        sidebar.activateForPlannerJourney()
      }
    #endif
    XCTAssertTrue(control.waitForPlannerHittability())
    control.activateForPlannerJourney()
    let picker = plannerElement(pickerIdentifier)
    let pickerExists = picker.waitForExistence(timeout: 5)
    if !pickerExists {
      XCTContext.runActivity(named: "Unavailable Planner state filter") { activity in
        let capture = XCTAttachment(screenshot: screenshot())
        capture.name = "Planner after the unavailable filter tap"
        capture.lifetime = .keepAlways
        activity.add(capture)
        let hierarchy = XCTAttachment(string: windows.firstMatch.debugDescription)
        hierarchy.name = "Unavailable Planner filter window hierarchy"
        hierarchy.lifetime = .keepAlways
        activity.add(hierarchy)
      }
    }
    XCTAssertTrue(pickerExists)
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
      if let identifier {
        let tabButtons = buttons.matching(identifier: identifier)
        if UIDevice.current.userInterfaceIdiom == .phone {
          _ = tabButtons.firstMatch.waitForPlannerHittability()
        }
        if let tab = tabButtons.allElementsBoundByIndex.first(where: \.isHittable) {
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
        if let overflow = navigationBars["Plan 2Do"].buttons.matching(
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
  #if os(macOS)
    func resizePlannerWindowForJourney(width: CGFloat) {
      XCUIApplication().activate()
      let edge = coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.8))
        .withOffset(.init(dx: -1, dy: 0))
      let target = edge.withOffset(.init(dx: width - frame.width, dy: 0))
      edge.click(forDuration: 0.1, thenDragTo: target)
      let resized = NSPredicate { _, _ in abs(self.frame.width - width) < 8 }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: resized, object: self)], timeout: 5),
        .completed, "Planner's own window must actually reach the requested width.")
    }
  #endif

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
