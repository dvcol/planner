import XCTest

#if os(iOS)
  @MainActor
  final class ContainerCatalogSortJourneyTests: XCTestCase {
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
      XCTAssertTrue(listSort.waitForExistence(timeout: 10), application.debugDescription)
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
      XCTAssertEqual(listSort.label, "Sort: Last updated · Ascending")
      choose("Created", menu: listSort, application: application)
      choose("Descending", menu: listSort, application: application)
      requireOrder(
        ["Manual plan", "Missing plan", "Alpha plan", "Zulu plan"], kind: "list",
        application: application)
      XCTAssertEqual(listSort.label, "Sort: Created · Descending")
      openCatalog("Itineraries", application: application)
      let itinerarySort = application.plannerElement("saved.itineraries.sort")
      XCTAssertTrue(itinerarySort.waitForExistence(timeout: 10))
      XCTAssertEqual(itinerarySort.label, "Sort: Title · Ascending")
      choose("Full estimate", menu: itinerarySort, application: application)
      requireOrder(
        ["Alpha plan", "Zulu plan", "Manual plan", "Missing plan"], kind: "itinerary",
        application: application)
      capture("Itineraries keep their separate full estimate ascending choice")
      application.terminate()
      launch(application, dataset: firstDataset)
      openCatalog("Lists", application: application)
      XCTAssertEqual(listSort.label, "Sort: Created · Descending")
      requireOrder(
        ["Manual plan", "Missing plan", "Alpha plan", "Zulu plan"], kind: "list",
        application: application)
      openCatalog("Itineraries", application: application)
      XCTAssertEqual(itinerarySort.label, "Sort: Full estimate · Ascending")
      requireOrder(
        ["Alpha plan", "Zulu plan", "Manual plan", "Missing plan"], kind: "itinerary",
        application: application)
      application.terminate()
      launch(application, dataset: UUID().uuidString)
      for section in ["Lists", "Itineraries"] {
        openCatalog(section, application: application)
        let sort = application.plannerElement("saved.\(section.lowercased()).sort")
        XCTAssertTrue(sort.waitForExistence(timeout: 10))
        XCTAssertEqual(sort.label, "Sort: Title · Ascending")
      }
      capture("A separate local dataset starts with alphabetical catalog defaults")
      application.terminate()
      launch(application, dataset: firstDataset)
      openCatalog("Lists", application: application)
      XCTAssertEqual(listSort.label, "Sort: Created · Descending")
      openCatalog("Itineraries", application: application)
      XCTAssertEqual(itinerarySort.label, "Sort: Full estimate · Ascending")
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
        XCTAssertTrue(listSort.waitForExistence(timeout: 10))
        choose("Descending", menu: listSort, application: application)
        requireOrder(
          ["Manual plan", "Zulu plan", "Alpha plan", "Missing plan"], kind: "list",
          application: application)
        XCTAssertTrue(selectedActivity.exists, application.debugDescription)
        capture("Sorting the visible List catalog retains the selected Zulu plan contents")
      }
      application.openPlannerSection("Items")
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
      let estimateSwitch = estimate.switches.firstMatch
      XCTAssertTrue(estimateSwitch.waitForPlannerBooleanState(true))
      estimateSwitch.activateForPlannerJourney()
      XCTAssertTrue(estimateSwitch.waitForPlannerBooleanState(false))
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
      XCTAssertEqual(itinerarySort.label, "Sort: Full estimate · Descending")
      capture("The final sort and archive choice publishes one consistent catalog")
    }

    private func launch(_ application: XCUIApplication, dataset: String) {
      application.launchArguments = ["--fixture", "catalog-sorting", "--fixture-dataset", dataset]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(
        application.buttons.matching(identifier: "list.bullet").firstMatch.waitForExistence(
          timeout: 30),
        application.debugDescription)
    }

    private func openCatalog(_ section: String, application: XCUIApplication) {
      application.openPlannerSection(section)
      let identifier = "saved.\(section.lowercased()).sort"
      let catalogControl = application.plannerElement(identifier)
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
      XCTAssertTrue(catalogControl.waitForExistence(timeout: 15), application.debugDescription)
      XCTAssertTrue(catalogControl.waitForPlannerHittability(), application.debugDescription)
    }

    /// Blank content below the four fixture rows dismisses menus without activating a toolbar action.
    private func choose(_ title: String, menu: XCUIElement, application: XCUIApplication) {
      let option = application.plannerElement(title)
      if !option.exists {
        XCTAssertTrue(menu.waitForPlannerHittability(), application.debugDescription)
        menu.activateForPlannerJourney()
      }
      XCTAssertTrue(option.waitForExistence(timeout: 5), application.debugDescription)
      option.activateForPlannerJourney()
      if option.exists {
        application.windows.firstMatch.coordinate(
          withNormalizedOffset: CGVector(dx: 0.12, dy: 0.8)
        ).tap()
        XCTAssertTrue(menu.waitForPlannerHittability(), application.debugDescription)
      }
    }

    private func requireOrder(_ titles: [String], kind: String, application: XCUIApplication) {
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
        .completed, application.debugDescription)
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
