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
        requireContainerNavigation(application)
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

      func testDestinationWindowsKeepOffscreenAddAndMoveSelectionsAndTheirSavedContexts() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let application = XCUIApplication()
        application.launchArguments = [
          "--fixture", "container-windows", "--fixture-dataset", UUID().uuidString,
        ]
        application.launchSavedPlannerJourney()
        requireContainerNavigation(application)
        openCatalog("Items", application: application)
        let source = application.savedPlannerItemRows("Window source").firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 15))
        let sourceIdentifier = source.identifier
        source.activateForPlannerJourney()
        application.plannerElement("saved.item.actions").activateForPlannerJourney()
        application.plannerElement("Add to list").activateForPlannerJourney()
        let firstDestination = destinationRow("Window List 001", application: application)
        XCTAssertTrue(firstDestination.waitForExistence(timeout: 15))
        let firstListIdentifier = firstDestination.identifier
        firstDestination.activateForPlannerJourney()
        let choices = application.collectionViews["saved.membership.destinations"]
        let lastDestination = destinationRow("Window List 193", application: application)
        scrollCatalog(choices, to: lastDestination, towardEnd: true, application: application)
        let lastListIdentifier = lastDestination.identifier
        let add = application.plannerElement("saved.item.list.add")
        XCTAssertTrue(add.isEnabled)
        capture("Windowed Add keeps its first destination selected while the last page is visible")
        add.activateForPlannerJourney()
        XCTAssertTrue(add.waitForNonExistence(timeout: 15))
        openCatalog("Lists", application: application)
        let firstList = application.plannerElement(
          firstListIdentifier.replacingOccurrences(
            of: "saved.membership.destination.", with: "saved.list."))
        XCTAssertTrue(firstList.waitForExistence(timeout: 15))
        firstList.activateForPlannerJourney()
        let originalAppearance = application.savedPlannerItemRows("Window source").firstMatch
        XCTAssertTrue(originalAppearance.waitForExistence(timeout: 15))
        let originalAppearanceIdentifier = originalAppearance.identifier
        let completion = application.buttons[
          originalAppearanceIdentifier.replacingOccurrences(
            of: "saved.appearance.", with: "saved.appearance.completion.")]
        completion.activateForPlannerJourney()
        XCTAssertTrue(completion.waitForPlannerValue("Completed"))
        originalAppearance.activateForPlannerJourney()
        application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
        application.plannerElement("Move to list").activateForPlannerJourney()
        XCTAssertTrue(choices.waitForExistence(timeout: 15))
        XCTAssertFalse(firstDestination.exists)
        scrollCatalog(choices, to: lastDestination, towardEnd: true, application: application)
        XCTAssertEqual(lastDestination.identifier, lastListIdentifier)
        lastDestination.activateForPlannerJourney()
        let earliestMoveDestination = destinationRow("Window List 002", application: application)
        scrollCatalog(
          choices, to: earliestMoveDestination, towardEnd: false, application: application)
        let move = application.plannerElement("saved.membership.move")
        XCTAssertTrue(move.isEnabled)
        capture("Windowed Move retains its last destination after revisiting the first page")
        move.activateForPlannerJourney()
        XCTAssertTrue(move.waitForNonExistence(timeout: 15))
        application.terminate()
        application.launchSavedPlannerJourney()
        openCatalog("Lists", application: application)
        let catalog = application.collectionViews["saved.lists.catalog"]
        let finalList = containerRow("Window List 193", kind: "list", application: application)
        scrollCatalog(catalog, to: finalList, towardEnd: true, application: application)
        XCTAssertEqual(
          finalList.identifier,
          lastListIdentifier.replacingOccurrences(
            of: "saved.membership.destination.", with: "saved.list."))
        finalList.activateForPlannerJourney()
        let movedAppearance = application.savedPlannerItemRows("Window source").firstMatch
        XCTAssertTrue(movedAppearance.waitForExistence(timeout: 15))
        XCTAssertNotEqual(movedAppearance.identifier, originalAppearanceIdentifier)
        let movedCompletion = application.buttons[
          movedAppearance.identifier.replacingOccurrences(
            of: "saved.appearance.", with: "saved.appearance.completion.")]
        XCTAssertTrue(movedCompletion.waitForPlannerValue("To do"))
        movedAppearance.activateForPlannerJourney()
        XCTAssertTrue(
          application.staticTexts["Window source notes"].firstMatch.waitForExistence(timeout: 10))
        capture(
          "Windowed destination operations retain the original source and a new Todo appearance")
        openCatalog("Items", application: application)
        XCTAssertTrue(source.waitForExistence(timeout: 15))
        XCTAssertEqual(source.identifier, sourceIdentifier)
        XCTAssertEqual(application.savedPlannerItemRows("Window source").count, 1)
      }

      func testCaptureFilterAndItineraryListWindowsRetainOffscreenChoices() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let application = XCUIApplication()
        application.launchArguments = [
          "--fixture", "container-windows", "--fixture-dataset", UUID().uuidString,
        ]
        application.launchSavedPlannerJourney()
        requireContainerNavigation(application)
        openCatalog("Items", application: application)
        application.openSavedPlannerCaptureEditor()
        let input = application.textFields["saved.capture.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.activateForPlannerJourney()
        input.typeText("Window capture")
        application.plannerElement("saved.capture.review").activateForPlannerJourney()
        let form = application.collectionViews["saved.capture.form"]
        XCTAssertTrue(form.waitForExistence(timeout: 15))
        let firstCaptureList = choiceRow(
          "Window List 001", prefix: "saved.capture.list.", application: application)
        scrollCatalog(form, to: firstCaptureList, towardEnd: true, application: application)
        let firstListIdentifier = firstCaptureList.identifier.replacingOccurrences(
          of: "saved.capture.list.", with: "")
        XCTAssertTrue(firstCaptureList.waitForPlannerBooleanState(false))
        firstCaptureList.switches.firstMatch.activateForPlannerJourney()
        XCTAssertTrue(firstCaptureList.waitForPlannerBooleanState(true))
        let lastCaptureList = choiceRow(
          "Window List 193", prefix: "saved.capture.list.", application: application)
        scrollCatalog(form, to: lastCaptureList, towardEnd: true, application: application)
        let lastListIdentifier = lastCaptureList.identifier.replacingOccurrences(
          of: "saved.capture.list.", with: "")
        let captureAdd = application.plannerElement("saved.capture.add")
        XCTAssertTrue(captureAdd.isEnabled)
        capture("Windowed Capture keeps its first destination while showing the final List page")
        captureAdd.activateForPlannerJourney()
        XCTAssertTrue(captureAdd.waitForNonExistence(timeout: 15))
        openCatalog("Items", application: application)
        let source = application.savedPlannerItemRows("Window capture").firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 15))
        let sourceIdentifier = source.identifier
        application.plannerElement("saved.items.filters").activateForPlannerJourney()
        application.revealSavedPlannerFilter("saved.filters.lists")
        application.plannerElement("saved.filters.lists").activateForPlannerJourney()
        let filterChoices = application.collectionViews["saved.filters.list.choices"]
        XCTAssertTrue(filterChoices.waitForExistence(timeout: 15))
        let filterChoice = choiceRow(
          "Window List 001", prefix: "saved.filters.list.", application: application)
        XCTAssertTrue(filterChoice.waitForExistence(timeout: 15))
        XCTAssertEqual(filterChoice.identifier, "saved.filters.list.\(firstListIdentifier)")
        XCTAssertTrue(filterChoice.waitForPlannerBooleanState(false))
        filterChoice.switches.firstMatch.activateForPlannerJourney()
        XCTAssertTrue(filterChoice.waitForPlannerBooleanState(true))
        let finalFilterChoice = choiceRow(
          "Window List 193", prefix: "saved.filters.list.", application: application)
        scrollCatalog(
          filterChoices, to: finalFilterChoice, towardEnd: true, application: application)
        XCTAssertEqual(finalFilterChoice.identifier, "saved.filters.list.\(lastListIdentifier)")
        capture("Windowed List filters keep the offscreen first List selected")
        application.plannerElement("saved.filters.lists.done").activateForPlannerJourney()
        application.plannerElement("saved.filters.done").activateForPlannerJourney()
        XCTAssertTrue(source.waitForExistence(timeout: 15))
        XCTAssertEqual(source.identifier, sourceIdentifier)
        XCTAssertFalse(application.savedPlannerItemRows("Window source").firstMatch.exists)
        XCTAssertEqual(application.savedPlannerItemRows("Window capture").count, 1)
        openCatalog("Itineraries", application: application)
        let itinerary = containerRow(
          "Window Itinerary 001", kind: "itinerary", application: application)
        XCTAssertTrue(itinerary.waitForExistence(timeout: 15))
        let itineraryIdentifier = itinerary.identifier
        itinerary.activateForPlannerJourney()
        application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
        let entryChoices = application.collectionViews["saved.itinerary.entry.choices"]
        XCTAssertTrue(entryChoices.waitForExistence(timeout: 15))
        let firstEntryChoice = choiceRow(
          "Window List 001", prefix: "saved.itinerary.entry.choice.list.", application: application)
        scrollCatalog(entryChoices, to: firstEntryChoice, towardEnd: true, application: application)
        XCTAssertEqual(
          firstEntryChoice.identifier, "saved.itinerary.entry.choice.list.\(firstListIdentifier)")
        firstEntryChoice.activateForPlannerJourney()
        let entryAdd = application.plannerElement("saved.itinerary.entry.add")
        capture("Windowed Itinerary List selection before scrolling offscreen")
        requireEnabled(entryAdd, application: application)
        let lastEntryChoice = choiceRow(
          "Window List 193", prefix: "saved.itinerary.entry.choice.list.", application: application)
        scrollCatalog(entryChoices, to: lastEntryChoice, towardEnd: true, application: application)
        XCTAssertEqual(
          lastEntryChoice.identifier, "saved.itinerary.entry.choice.list.\(lastListIdentifier)")
        capture("Windowed Itinerary List selection after scrolling offscreen")
        requireEnabled(entryAdd, application: application)
        entryAdd.activateForPlannerJourney()
        XCTAssertTrue(entryAdd.waitForNonExistence(timeout: 15))
        let appearance = choiceRow(
          "Window capture", prefix: "saved.itinerary.appearance.", application: application)
        XCTAssertTrue(appearance.waitForExistence(timeout: 15))
        let appearanceIdentifier = appearance.identifier
        let completion = application.buttons[
          appearanceIdentifier.replacingOccurrences(
            of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")]
        XCTAssertTrue(completion.waitForPlannerValue("To do"))
        XCTAssertTrue(application.staticTexts["0 of 2 items done"].firstMatch.exists)
        application.terminate()
        application.launchSavedPlannerJourney()
        openCatalog("Itineraries", application: application)
        XCTAssertTrue(itinerary.waitForExistence(timeout: 15))
        XCTAssertEqual(itinerary.identifier, itineraryIdentifier)
        itinerary.activateForPlannerJourney()
        XCTAssertTrue(appearance.waitForExistence(timeout: 15))
        XCTAssertEqual(appearance.identifier, appearanceIdentifier)
        XCTAssertTrue(completion.waitForPlannerValue("To do"))
        capture("Windowed Capture and Itinerary choices retain their saved contextual identities")
      }

      func testItineraryListSelectionSurvivesPresentationEviction() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let application = XCUIApplication()
        application.launchArguments = [
          "--fixture", "container-windows", "--fixture-dataset", UUID().uuidString,
        ]
        application.launchSavedPlannerJourney()
        requireContainerNavigation(application)
        openCatalog("Itineraries", application: application)
        let itinerary = containerRow(
          "Window Itinerary 001", kind: "itinerary", application: application)
        XCTAssertTrue(itinerary.waitForExistence(timeout: 15))
        itinerary.activateForPlannerJourney()
        application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
        let choices = application.collectionViews["saved.itinerary.entry.choices"]
        XCTAssertTrue(choices.waitForExistence(timeout: 15))
        let first = choiceRow(
          "Window List 001", prefix: "saved.itinerary.entry.choice.list.", application: application)
        scrollCatalog(choices, to: first, towardEnd: true, application: application)
        first.activateForPlannerJourney()
        let add = application.plannerElement("saved.itinerary.entry.add")
        capture("Windowed isolated Itinerary List selection before eviction")
        requireEnabled(add, application: application)
        let last = choiceRow(
          "Window List 193", prefix: "saved.itinerary.entry.choice.list.", application: application)
        scrollCatalog(choices, to: last, towardEnd: true, application: application)
        capture("Windowed isolated Itinerary List selection after eviction")
        requireEnabled(add, application: application)
        add.activateForPlannerJourney()
        XCTAssertTrue(add.waitForNonExistence(timeout: 15))
        capture("Windowed isolated Itinerary saved List branch")
        let hierarchy = XCTAttachment(string: application.debugDescription)
        hierarchy.name = "Windowed Itinerary saved-branch hierarchy"
        hierarchy.lifetime = .keepAlways
        self.add(hierarchy)
        let entry = application.descendants(matching: .any).matching(
          NSPredicate(
            format: "identifier MATCHES %@", "saved[.]itinerary[.]entry[.][0-9A-Fa-f-]{36}"
          )
        ).containing(.staticText, identifier: "Window List 001").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        let entryIdentifier = entry.identifier
        application.terminate()
        application.launchSavedPlannerJourney()
        openCatalog("Itineraries", application: application)
        itinerary.activateForPlannerJourney()
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        XCTAssertEqual(entry.identifier, entryIdentifier)
        capture("Windowed isolated Itinerary preserves its selected source entry after relaunch")
      }

      private func requireContainerNavigation(_ application: XCUIApplication) {
        let ready = application.buttons.matching(
          NSPredicate(
            format: "identifier IN %@ OR label IN %@",
            ["saved.section.lists", "list.bullet"], ["Lists", "Show Sidebar"]
          )
        ).firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 60))
        capture("Windowed catalog initial adaptive navigation")
      }

      private func requireEnabled(_ control: XCUIElement, application: XCUIApplication) {
        let result = XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "enabled == true"), object: control)
          ], timeout: 5)
        if result != .completed {
          let hierarchy = XCTAttachment(string: application.debugDescription)
          hierarchy.name = "Windowed Itinerary disabled-action hierarchy"
          hierarchy.lifetime = .keepAlways
          add(hierarchy)
        }
        XCTAssertEqual(result, .completed)
      }

      private func choiceRow(_ title: String, prefix: String, application: XCUIApplication)
        -> XCUIElement
      {
        application.descendants(matching: .any).matching(
          NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", prefix, title
          )
        ).firstMatch
      }

      private func destinationRow(_ title: String, application: XCUIApplication) -> XCUIElement {
        application.descendants(matching: .any).matching(
          NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "saved.membership.destination.",
            title
          )
        ).firstMatch
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
              .filter { $0.isHittable && $0.frame.intersects(catalog.frame) }.map(\.frame.maxY)
              .max()
              ?? catalog.frame.minY
            let tabs = application.tabBars.firstMatch
            let bottomBoundary =
              tabs.exists && tabs.isHittable ? tabs.frame.minY : catalog.frame.maxY
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
      var listSort: XCUIElement {
        application.savedPlannerCatalogSortControl(identifierPrefix: "saved.lists")
      }
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
        let sort = application.savedPlannerCatalogSortControl(
          identifierPrefix: "saved.\(section.lowercased())")
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
      var listSort: XCUIElement {
        application.savedPlannerCatalogSortControl(identifierPrefix: "saved.lists")
      }
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
      application.plannerElement("Edit item").activateForPlannerJourney()
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
      let identifier = "saved.\(section.lowercased()).archive"
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
        let nestedSort = application.collectionViews.buttons.matching(
          NSPredicate(format: "label BEGINSWITH %@", "Sort: ")
        ).firstMatch
        if option.exists || nestedSort.exists {
          application.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.12, dy: 0.8)
          ).tap()
          XCTAssertTrue(option.waitForNonExistence(timeout: 5), journeyDescription(application))
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
        application.dismissSavedPlannerCatalogOverflow()
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
