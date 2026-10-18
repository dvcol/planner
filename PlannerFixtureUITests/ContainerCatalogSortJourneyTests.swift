import XCTest

#if os(iOS) || os(macOS)
  @MainActor
  final class ContainerCatalogSortJourneyTests: XCTestCase {
    #if os(iOS)
      func testBothContainerCatalogsCrossPagesRevisitAndRetainSourceIdentitiesAfterRelaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let application = XCUIApplication()
        application.launchArguments = [
          "--fixture", "container-windows", "--fixture-dataset", UUID().uuidString,
        ]
        application.launchSavedPlannerJourney()
        XCTAssertTrue(application.buttons["Lists"].firstMatch.waitForExistence(timeout: 60))
        var lastIdentifiers: [String: String] = [:]
        for (section, kind, titleKind) in [
          ("Lists", "list", "List"), ("Itineraries", "itinerary", "Itinerary"),
        ] {
          openCatalog(section, application: application)
          let first = containerRow("Window \(titleKind) 001", kind: kind, application: application)
          XCTAssertTrue(first.waitForExistence(timeout: 15))
          let firstIdentifier = first.identifier
          let catalog = application.collectionViews["saved.\(section.lowercased()).catalog"]
          XCTAssertTrue(catalog.waitForExistence(timeout: 10))
          for index in [65, 129, 193] {
            let title = String(format: "Window %@ %03d", titleKind, index)
            let row = containerRow(title, kind: kind, application: application)
            scrollCatalog(catalog, to: row, towardEnd: true, application: application)
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            XCTAssertTrue(row.isHittable)
            if index == 193 { lastIdentifiers[kind] = row.identifier }
            capture("Windowed \(section) catalog reaches \(index)")
          }
          scrollCatalog(catalog, to: first, towardEnd: false, application: application)
          XCTAssertEqual(first.identifier, firstIdentifier)
          capture("Windowed \(section) catalog revisits its original first source")
        }
        application.terminate()
        application.launchSavedPlannerJourney()
        for (section, kind, titleKind) in [
          ("Lists", "list", "List"), ("Itineraries", "itinerary", "Itinerary"),
        ] {
          openCatalog(section, application: application)
          let first = containerRow("Window \(titleKind) 001", kind: kind, application: application)
          XCTAssertTrue(first.waitForExistence(timeout: 15))
          let catalog = application.collectionViews["saved.\(section.lowercased()).catalog"]
          let last = containerRow("Window \(titleKind) 193", kind: kind, application: application)
          scrollCatalog(catalog, to: last, towardEnd: true, application: application)
          XCTAssertEqual(last.identifier, lastIdentifiers[kind])
          last.activateForPlannerJourney()
          let expected = section == "Lists" ? "No items" : "Container itinerary notes 193"
          XCTAssertTrue(application.staticTexts[expected].firstMatch.waitForExistence(timeout: 10))
          capture("Windowed \(section) catalog retains exact final source after relaunch")
        }
      }

      private func containerRow(_ title: String, kind: String, application: XCUIApplication)
        -> XCUIElement
      {
        let prefix = kind == "list" ? "saved.list." : "saved.itinerary.row."
        return application.descendants(matching: .any).matching(
          NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", prefix, title)
        ).firstMatch
      }

      private func scrollCatalog(
        _ catalog: XCUIElement, to row: XCUIElement, towardEnd: Bool,
        application: XCUIApplication
      ) {
        for _ in 0..<60 {
          if row.exists, row.isHittable, catalog.frame.contains(row.frame) {
            let topBoundary =
              application.navigationBars.allElementsBoundByIndex
              .filter { $0.frame.intersects(catalog.frame) }.map(\.frame.maxY).max()
              ?? catalog.frame.minY
            let tabs = application.tabBars.firstMatch
            let bottomBoundary = tabs.exists ? tabs.frame.minY : catalog.frame.maxY
            if row.frame.minY >= topBoundary, row.frame.maxY <= bottomBoundary { return }
          }
          if towardEnd {
            catalog.swipeUp()
          } else {
            catalog.swipeDown()
          }
        }
        capture("Windowed container catalog failed to reveal its requested source")
        XCTFail("The requested container did not become fully visible.")
      }
    #endif

    func testCatalogsRememberSeparateNativeSortsAcrossRelaunchAndDatasetChanges() {
      continueAfterFailure = false
      let application = XCUIApplication()
      let firstDataset = UUID().uuidString
      launch(application, dataset: firstDataset)
      openCatalog("Lists", application: application)
      requireOrder(
        ["Alpha plan", "Manual plan", "Missing plan", "Zulu plan"], kind: "list",
        application: application)
      let listSort = application.plannerElement("saved.lists.sort")
      choose("Full estimate", menu: listSort, application: application)
      requireOrder(
        ["Alpha plan", "Zulu plan", "Manual plan", "Missing plan"], kind: "list",
        application: application)
      choose("Descending", menu: listSort, application: application)
      requireOrder(
        ["Manual plan", "Zulu plan", "Alpha plan", "Missing plan"], kind: "list",
        application: application)
      capture("Lists sorted by full estimate descending with incomplete plans last")
      choose("Last updated", menu: listSort, application: application)
      choose("Ascending", menu: listSort, application: application)
      requireOrder(
        ["Zulu plan", "Alpha plan", "Manual plan", "Missing plan"], kind: "list",
        application: application)
      requireSortSummary(
        "Sort: Last updated · Ascending", control: listSort, application: application)
      choose("Created", menu: listSort, application: application)
      choose("Descending", menu: listSort, application: application)
      requireOrder(
        ["Manual plan", "Missing plan", "Alpha plan", "Zulu plan"], kind: "list",
        application: application)
      requireSortSummary("Sort: Created · Descending", control: listSort, application: application)
      openCatalog("Itineraries", application: application)
      let itinerarySort = application.plannerElement("saved.itineraries.sort")
      requireSortSummary(
        "Sort: Title · Ascending", control: itinerarySort, application: application)
      choose("Full estimate", menu: itinerarySort, application: application)
      requireOrder(
        ["Alpha plan", "Zulu plan", "Manual plan", "Missing plan"], kind: "itinerary",
        application: application)
      capture("Itineraries keep their separate full estimate ascending choice")
      application.terminate()
      launch(application, dataset: firstDataset)
      openCatalog("Lists", application: application)
      requireSortSummary("Sort: Created · Descending", control: listSort, application: application)
      requireOrder(
        ["Manual plan", "Missing plan", "Alpha plan", "Zulu plan"], kind: "list",
        application: application)
      openCatalog("Itineraries", application: application)
      requireSortSummary(
        "Sort: Full estimate · Ascending", control: itinerarySort, application: application)
      requireOrder(
        ["Alpha plan", "Zulu plan", "Manual plan", "Missing plan"], kind: "itinerary",
        application: application)
      application.terminate()
      launch(application, dataset: UUID().uuidString)
      for section in ["Lists", "Itineraries"] {
        openCatalog(section, application: application)
        let sort = application.plannerElement("saved.\(section.lowercased()).sort")
        #if os(iOS)
          XCTAssertTrue(sort.waitForExistence(timeout: 10))
        #endif
        requireSortSummary("Sort: Title · Ascending", control: sort, application: application)
      }
      capture("A separate local dataset starts with alphabetical catalog defaults")
      application.terminate()
      launch(application, dataset: firstDataset)
      openCatalog("Lists", application: application)
      requireSortSummary("Sort: Created · Descending", control: listSort, application: application)
      openCatalog("Itineraries", application: application)
      requireSortSummary(
        "Sort: Full estimate · Ascending", control: itinerarySort, application: application)
      capture("Returning to the original dataset restores both catalog choices")
    }

    func testSharedEstimateEditsRefreshBothCatalogsWithoutReplacingValidSelection() {
      continueAfterFailure = false
      let application = XCUIApplication()
      launch(application, dataset: UUID().uuidString)
      openCatalog("Lists", application: application)
      let listSort = application.plannerElement("saved.lists.sort")
      choose("Full estimate", menu: listSort, application: application)
      requireOrder(
        ["Alpha plan", "Zulu plan", "Manual plan", "Missing plan"], kind: "list",
        application: application)
      application.savedPlannerListRow("Zulu plan").activateForPlannerJourney()
      let selectedActivity = application.savedPlannerItemRows("Zulu plan activity").firstMatch
      XCTAssertTrue(selectedActivity.waitForExistence(timeout: 15))
      if application.windows.firstMatch.frame.width > 600 {
        let sidebar = application.buttons["Show Sidebar"].firstMatch
        if sidebar.exists { sidebar.activateForPlannerJourney() }
        #if os(iOS)
          XCTAssertTrue(listSort.waitForExistence(timeout: 10))
        #endif
        choose("Descending", menu: listSort, application: application)
        requireOrder(
          ["Manual plan", "Zulu plan", "Alpha plan", "Missing plan"], kind: "list",
          application: application)
        XCTAssertTrue(selectedActivity.exists, journeyDescription(application))
        capture("Sorting the visible List catalog retains the selected Zulu plan contents")
      }
      openSection("Items", application: application)
      let alpha = application.savedPlannerItemRows("Alpha plan activity").firstMatch
      XCTAssertTrue(alpha.waitForExistence(timeout: 15))
      alpha.activateForPlannerJourney()
      let actions = application.plannerElement("saved.item.actions")
      XCTAssertTrue(actions.waitForExistence(timeout: 10))
      actions.activateForPlannerJourney()
      application.plannerElement("Edit Item").activateForPlannerJourney()
      let estimate = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.enabled"
      ).firstMatch
      XCTAssertTrue(estimate.waitForExistence(timeout: 10))
      #if os(macOS)
        let estimateToggle = estimate
      #else
        let estimateToggle = estimate.switches.firstMatch
      #endif
      XCTAssertTrue(estimateToggle.waitForPlannerBooleanState(true))
      estimateToggle.activateForPlannerJourney()
      XCTAssertTrue(estimateToggle.waitForPlannerBooleanState(false))
      application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
      XCTAssertTrue(estimate.waitForNonExistence(timeout: 10))
      openCatalog("Lists", application: application)
      choose("Ascending", menu: listSort, application: application)
      requireOrder(
        ["Zulu plan", "Manual plan", "Alpha plan", "Missing plan"], kind: "list",
        application: application)
      capture("Removing a shared Item estimate moves its List into the incomplete group")
      openCatalog("Itineraries", application: application)
      let itinerarySort = application.plannerElement("saved.itineraries.sort")
      choose("Full estimate", menu: itinerarySort, application: application)
      requireOrder(
        ["Zulu plan", "Manual plan", "Alpha plan", "Missing plan"], kind: "itinerary",
        application: application)
      choose("Last updated", menu: itinerarySort, application: application)
      choose("Descending", menu: itinerarySort, application: application)
      requireOrder(
        ["Missing plan", "Manual plan", "Alpha plan", "Zulu plan"], kind: "itinerary",
        application: application)
      capture("A shared Item edit preserves the Itineraries own Last updated order")
      let archive = application.plannerElement("saved.itineraries.archive")
      choose("Archived Itineraries", menu: archive, application: application)
      XCTAssertTrue(
        application.staticTexts["No matching Itineraries"].waitForExistence(timeout: 10))
      choose("All Itineraries", menu: archive, application: application)
      choose("Full estimate", menu: itinerarySort, application: application)
      choose("Active Itineraries", menu: archive, application: application)
      requireOrder(
        ["Manual plan", "Zulu plan", "Alpha plan", "Missing plan"], kind: "itinerary",
        application: application)
      requireSortSummary(
        "Sort: Full estimate · Descending", control: itinerarySort, application: application)
      capture("The final sort and archive choice publishes one consistent catalog")
    }

    private func launch(_ application: XCUIApplication, dataset: String) {
      application.launchArguments = ["--fixture", "catalog-sorting", "--fixture-dataset", dataset]
      application.launchSavedPlannerJourney()
      #if os(macOS)
        application.activate()
        XCTAssertTrue(
          application.wait(for: .runningForeground, timeout: 10), journeyDescription(application))
        XCTAssertTrue(
          application.plannerElement("saved.section.lists").waitForExistence(timeout: 30),
          journeyDescription(application))
      #else
        let ready = NSPredicate { _, _ in
          application.buttons["Lists"].firstMatch.exists
            || application.plannerElement("saved.section.lists").exists
            || application.plannerElement("Show Sidebar").exists
        }
        XCTAssertEqual(
          XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: ready, object: application)], timeout: 30),
          .completed, journeyDescription(application))
      #endif
    }

    private func openSection(_ section: String, application: XCUIApplication) {
      #if os(macOS)
        application.activate()
        XCTAssertTrue(
          application.wait(for: .runningForeground, timeout: 10), journeyDescription(application))
        let control = application.plannerElement("saved.section.\(section.lowercased())")
        XCTAssertTrue(control.waitForExistence(timeout: 10), journeyDescription(application))
        XCTAssertTrue(control.waitForPlannerHittability(), journeyDescription(application))
        control.activateForPlannerJourney()
      #else
        application.openPlannerSection(section)
      #endif
    }

    private func openCatalog(_ section: String, application: XCUIApplication) {
      openSection(section, application: application)
      let identifier = "saved.\(section.lowercased()).sort"
      let catalogControl = application.plannerElement(identifier)
      #if os(macOS)
        if !catalogControl.exists,
          application.windows.firstMatch.popUpButtons["more toolbar items"].exists
        {
          return
        }
      #endif
      for _ in 0..<3 {
        if catalogControl.exists && catalogControl.isHittable { return }
        let back = application.navigationBars.buttons["BackButton"].firstMatch
        let namedBack = application.navigationBars.buttons[section].firstMatch
        let sidebar = application.buttons["Show Sidebar"].firstMatch
        if back.exists && back.isHittable {
          back.activateForPlannerJourney()
        } else if namedBack.exists && namedBack.isHittable {
          namedBack.activateForPlannerJourney()
        } else if sidebar.exists && sidebar.isHittable {
          sidebar.activateForPlannerJourney()
        } else {
          break
        }
      }
      XCTAssertTrue(catalogControl.waitForExistence(timeout: 15), journeyDescription(application))
      XCTAssertTrue(catalogControl.waitForPlannerHittability(), journeyDescription(application))
    }

    /// Blank content below the four fixture rows dismisses menus without activating a toolbar action.
    private func choose(_ title: String, menu: XCUIElement, application: XCUIApplication) {
      let option = application.plannerElement(title)
      #if os(macOS)
        let needsMenu = !option.exists || !option.isHittable
      #else
        let needsMenu = !option.exists
      #endif
      if needsMenu {
        let resolved = revealCatalogControl(menu, optionTitle: title, application: application)
        XCTAssertTrue(resolved.element.waitForPlannerHittability(), journeyDescription(application))
        resolved.element.activateForPlannerJourney()
      }
      XCTAssertTrue(option.waitForExistence(timeout: 5), journeyDescription(application))
      option.activateForPlannerJourney()
      #if os(macOS)
        application.typeKey(.escape, modifierFlags: [])
        application.typeKey(.escape, modifierFlags: [])
      #else
        if option.exists {
          application.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.12, dy: 0.8)
          ).tap()
          XCTAssertTrue(menu.waitForPlannerHittability(), journeyDescription(application))
        }
      #endif
    }

    private func revealCatalogControl(
      _ control: XCUIElement, optionTitle: String? = nil, application: XCUIApplication
    ) -> (element: XCUIElement, openedOverflow: Bool) {
      #if os(macOS)
        application.activate()
        XCTAssertTrue(
          application.wait(for: .runningForeground, timeout: 10), journeyDescription(application))
        if control.exists && control.isHittable { return (control, false) }
        let overflow = application.windows.firstMatch.popUpButtons["more toolbar items"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 5), journeyDescription(application))
        overflow.activateForPlannerJourney()
        let titlePattern: String
        if optionTitle?.hasSuffix(" Itineraries") == true {
          titlePattern = "^(Active|Archived|All)( Itineraries)?$"
        } else {
          titlePattern = "^Sort:.*"
        }
        let nativeControl = overflow.menuItems.matching(
          NSPredicate(format: "title MATCHES %@", titlePattern)
        ).firstMatch
        XCTAssertTrue(nativeControl.waitForExistence(timeout: 5), journeyDescription(application))
        return (nativeControl, true)
      #else
        return (control, false)
      #endif
    }

    private func requireSortSummary(
      _ expected: String, control: XCUIElement, application: XCUIApplication
    ) {
      let resolved = revealCatalogControl(control, application: application)
      #if os(macOS)
        XCTAssertEqual(resolved.element.title, expected)
        if resolved.openedOverflow { application.typeKey(.escape, modifierFlags: []) }
      #else
        XCTAssertEqual(resolved.element.label, expected)
      #endif
    }

    private func requireOrder(_ titles: [String], kind: String, application: XCUIApplication) {
      #if os(macOS)
        application.activate()
        XCTAssertTrue(
          application.wait(for: .runningForeground, timeout: 10), journeyDescription(application))
      #endif
      let prefix = kind == "list" ? "saved.list." : "saved.itinerary.row."
      let rows = titles.map { title in
        application.descendants(matching: .any).matching(
          NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", prefix, title)
        ).firstMatch
      }
      let ordered = NSPredicate { _, _ in
        rows.allSatisfy { $0.exists && $0.isHittable }
          && zip(rows, rows.dropFirst()).allSatisfy { $0.0.frame.midY < $0.1.frame.midY }
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: ordered, object: application)], timeout: 15),
        .completed, journeyDescription(application))
    }

    private func journeyDescription(_ application: XCUIApplication) -> String {
      #if os(macOS)
        let windows = application.windows.allElementsBoundByIndex
        return "Planner fixture state: \(application.state.rawValue), windows: \(windows.count)\n"
          + windows.map(\.debugDescription).joined(separator: "\n")
      #else
        return application.debugDescription
      #endif
    }

    private func capture(_ name: String) {
      #if os(macOS)
        let screenshot = XCUIApplication().windows.firstMatch.screenshot()
      #else
        let screenshot = XCUIApplication().screenshot()
      #endif
      let attachment = XCTAttachment(screenshot: screenshot)
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
