import XCTest

@MainActor
final class SavedItineraryBulkJourneyTests: XCTestCase {
  #if os(iOS)
    func testItineraryCompositionAndFilteredCountsPassNativeContrastAudit() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      createItem("Museum", application: application)
      createItem("Hotel", application: application)
      createList(application)
      application.openSavedPlannerListAddMenu()
      let addition = application.plannerElement("saved.list.add")
      XCTAssertTrue(addition.waitForExistence(timeout: 5))
      addition.activateForPlannerJourney()
      let hotel = application.staticTexts["Hotel"].firstMatch
      XCTAssertTrue(hotel.waitForExistence(timeout: 5))
      hotel.activateForPlannerJourney()
      application.plannerElement("saved.membership.add").activateForPlannerJourney()
      XCTAssertTrue(
        application.savedPlannerItemRows("Hotel").firstMatch.waitForExistence(timeout: 10))
      createItinerary(application)
      for source in ["Museum", "Food stops"] { addEntry(source, application: application) }
      let contents = application.descendants(matching: .any).matching(
        identifier: "saved.itinerary.contents"
      ).firstMatch
      for _ in 0..<3 {
        if itineraryRows(application).count == 3 { break }
        contents.swipeUp()
      }
      let originalIdentifiers = itineraryRows(application).allElementsBoundByIndex.map(\.identifier)
      XCTAssertEqual(originalIdentifiers.count, 3)
      XCTAssertEqual(
        itineraryRows(application).allElementsBoundByIndex.map(\.label),
        ["Museum", "Museum", "Hotel"])
      for identifier in originalIdentifiers.prefix(2) {
        let completedAppearance = application.plannerElement(
          identifier.replacingOccurrences(
            of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
        completedAppearance.activateForPlannerJourney()
        XCTAssertTrue(completedAppearance.waitForPlannerValue("Completed"))
      }
      let filters = application.plannerElement("saved.itinerary.filters")
      application.chooseSavedPlannerStateFilter("Todo", control: filters)
      XCTAssertTrue(waitForItineraryOrder([originalIdentifiers[2]], application: application))
      assertProgress("2 of 3 items done", application: application)
      XCTAssertTrue(application.staticTexts["1 direct item · 1 list"].exists)
      XCTAssertTrue(application.staticTexts["Matching 1 of 3 items"].exists)
      XCTAssertTrue(application.staticTexts["Matching 1 of 2 items"].exists)
      recordScreenshot(
        application, name: "Itinerary composition and filtered counts before native contrast audit")
      let previousValue = continueAfterFailure
      continueAfterFailure = true
      defer { continueAfterFailure = previousValue }
      try application.performAccessibilityAudit(for: .contrast)
    }
  #endif

  func testNativeUndoRestoresOneRepeatedItineraryEntry() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.fillSavedPlannerWindowForJourney()
    #endif
    createItem("Museum", application: application)
    createList(application)
    createItinerary(application)
    for _ in 0..<2 { addEntry("Food stops", application: application) }
    let originalIdentifiers = itineraryRows(application).allElementsBoundByIndex.map(\.identifier)
    XCTAssertEqual(originalIdentifiers.count, 2)
    application.plannerElement(
      originalIdentifiers[0].replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    ).activateForPlannerJourney()
    XCTAssertTrue(waitForItineraryOrder(originalIdentifiers, application: application))
    XCTAssertTrue(
      application.plannerElement(
        originalIdentifiers[0].replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
      ).waitForPlannerValue("Completed"))
    assertChecks(["Completed", "To do"], application: application)
    #if os(macOS)
      guard let entryIdentifier = originalIdentifiers[0].split(separator: ".").dropFirst(3).first
      else {
        XCTFail("The selected appearance must identify its containing itinerary entry.")
        return
      }
      let header = application.groups.matching(
        identifier: "saved.itinerary.entry.\(entryIdentifier)"
      ).firstMatch
      XCTAssertTrue(header.waitForExistence(timeout: 5))
      openEntryMenu(header)
    #else
      openEntryMenu(application.staticTexts["Food stops"].firstMatch)
    #endif
    application.plannerElement("Remove from itinerary").activateForPlannerJourney()
    XCTAssertTrue(
      waitForItineraryOrder([originalIdentifiers[1]], application: application))
    let filters = application.plannerElement("saved.itinerary.filters")
    application.chooseSavedPlannerStateFilter("Todo", control: filters)
    let originalFilterTitle = filters.plannerControlTitle
    XCTAssertTrue(originalFilterTitle.contains("Todo"))
    #if os(macOS)
      application.typeKey("z", modifierFlags: .command)
    #else
      let undo = application.plannerElement("saved.association.undo")
      XCTAssertTrue(undo.waitForExistence(timeout: 5))
      let tabs = application.tabBars.firstMatch
      if tabs.exists {
        let listsTab = tabs.buttons["Lists"]
        XCTAssertTrue(listsTab.exists)
        XCTAssertLessThanOrEqual(undo.frame.maxY, listsTab.frame.minY)
      }
      openSection("Calendar", application: application)
      XCTAssertTrue(
        application.otherElements["saved.calendar.canvas"].waitForExistence(timeout: 10))
      openItinerary(application)
      XCTAssertTrue(undo.waitForExistence(timeout: 5))
      recordScreenshot(application, name: "Native Itinerary removal offers scoped Undo")
      undo.activateForPlannerJourney()
    #endif
    let progress = application.progressIndicators["saved.itinerary.progress"]
    let restoredProgress = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "1 of 2 items done"), object: progress)
    XCTAssertEqual(XCTWaiter.wait(for: [restoredProgress], timeout: 10), .completed)
    XCTAssertTrue(waitForItineraryOrder([originalIdentifiers[1]], application: application))
    XCTAssertEqual(filters.plannerControlTitle, originalFilterTitle)
    recordScreenshot(
      application, name: "Native Itinerary Undo preserves Todo filtering and full progress")
    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    XCTAssertTrue(waitForItineraryOrder(originalIdentifiers, application: application))
    assertChecks(["Completed", "To do"], application: application)
    assertProgress("1 of 2 items done", application: application)
    recordScreenshot(application, name: "Native Undo restores one independent repeated List entry")
    application.terminate()
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.fillSavedPlannerWindowForJourney()
    #endif
    openItinerary(application)
    XCTAssertTrue(waitForItineraryOrder(originalIdentifiers, application: application))
    assertChecks(["Completed", "To do"], application: application)
    XCTAssertFalse(application.plannerElement("saved.association.undo").exists)
  }

  func testArchivedRepeatedListBranchesFinishProgressWithoutCompletingTheirItems() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Museum", application: application)
    createList(application)
    let membershipIdentifier = application.savedPlannerItemRows("Museum").firstMatch.identifier
    let membershipCompletion = application.plannerElement(
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    membershipCompletion.activateForPlannerJourney()
    assertProgress("1 of 1 item done", application: application)
    createItinerary(application)
    for source in ["Museum", "Food stops", "Food stops"] {
      addEntry(source, application: application)
    }
    let originalIdentifiers = itineraryRows(application).allElementsBoundByIndex.map(\.identifier)
    XCTAssertEqual(originalIdentifiers.count, 3)
    assertChecks(["To do", "To do", "To do"], application: application)
    assertProgress("0 of 3 items done", application: application)
    openSection("Lists", application: application)
    let list = application.savedPlannerListRow("Food stops")
    revealNavigation(to: list, application: application)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    openEntryMenu(list)
    application.plannerElement("Archive list").activateForPlannerJourney()
    openItinerary(application)
    assertProgress("2 of 3 items finished", application: application)
    XCTAssertTrue(application.staticTexts["0 done · 2 archived"].exists)
    XCTAssertEqual(
      itineraryRows(application).allElementsBoundByIndex.map(\.identifier), originalIdentifiers)
    assertChecks(["To do", "To do", "To do"], application: application)
    XCTAssertTrue(application.staticTexts["Archived List"].firstMatch.exists)
    recordScreenshot(
      application, name: "Archived repeated List branches finish progress with Todo checks")
    let search = application.searchFields["Search this Itinerary"]
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.activateForPlannerJourney()
    search.typeText("food stops")
    let filters = reveal("saved.itinerary.filters", application: application)
    application.chooseSavedPlannerStateFilter("Done", control: filters)
    XCTAssertTrue(
      application.staticTexts["No matching items"].firstMatch.waitForExistence(timeout: 10))
    let headers = originalIdentifiers.map { identifier in
      let entryIdentifier = identifier.components(separatedBy: ".")[3]
      return application.descendants(matching: .any).matching(
        identifier: "saved.itinerary.entry.\(entryIdentifier)"
      ).firstMatch
    }
    XCTAssertTrue(headers[0].waitForNonExistence(timeout: 5))
    XCTAssertTrue(headers[1].exists)
    XCTAssertTrue(headers[2].exists)
    XCTAssertTrue(application.staticTexts["Matching 0 of 3 items"].exists)
    recordScreenshot(application, name: "Done header filtering retains both archived branches")
    application.chooseSavedPlannerStateFilter("Todo", control: filters)
    XCTAssertTrue(application.staticTexts["No matching entries"].waitForExistence(timeout: 10))
    assertProgress("2 of 3 items finished", application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    assertProgress("2 of 3 items finished", application: application)
    assertChecks(["To do", "To do", "To do"], application: application)
    XCTAssertEqual(
      itineraryRows(application).allElementsBoundByIndex.map(\.identifier), originalIdentifiers)
    recordScreenshot(
      application, name: "Archived branches retain source identities and Todo checks after relaunch"
    )
    openItem("Museum", application: application)
    let globalCompletion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openSection("Lists", application: application)
    let archiveFilter = reveal("saved.lists.archive", application: application)
    archiveFilter.activateForPlannerJourney()
    application.plannerElement("All Lists").activateForPlannerJourney()
    revealNavigation(to: list, application: application)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    list.activateForPlannerJourney()
    assertProgress("1 of 1 item done", application: application)
    XCTAssertTrue(membershipCompletion.waitForPlannerValue("Completed"))
    revealNavigation(to: list, application: application)
    openEntryMenu(list)
    application.plannerElement("Unarchive list").activateForPlannerJourney()
    openItinerary(application)
    assertProgress("0 of 3 items done", application: application)
    assertChecks(["To do", "To do", "To do"], application: application)
    XCTAssertEqual(
      itineraryRows(application).allElementsBoundByIndex.map(\.identifier), originalIdentifiers)
    recordScreenshot(
      application,
      name: "Unarchive restores unfinished itinerary branches without changing source List Done")
  }

  func testRemovingRepeatedEntriesRetainsSourcesAndOtherLocalStatesAfterReaddition() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Museum", application: application)
    createList(application)
    let membershipIdentifier = application.savedPlannerItemRows("Museum").firstMatch.identifier
    let membershipCompletion = application.plannerElement(
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    membershipCompletion.activateForPlannerJourney()
    assertProgress("1 of 1 item done", application: application)
    createItinerary(application)
    for source in ["Museum", "Food stops", "Museum", "Food stops"] {
      addEntry(source, application: application)
    }
    let rows = itineraryRows(application)
    XCTAssertEqual(rows.count, 4)
    let originalIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    assertChecks(["To do", "To do", "To do", "To do"], application: application)
    for index in [0, 1, 3] {
      application.plannerElement(
        originalIdentifiers[index].replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
      ).activateForPlannerJourney()
    }
    assertProgress("3 of 4 items done", application: application)
    rows.element(boundBy: 1).activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].waitForExistence(timeout: 10))
    let back = application.plannerElement("BackButton")
    let detailsAlongsideRoute = !back.exists
    if back.exists { back.activateForPlannerJourney() }
    let firstListHeader = application.staticTexts["Food stops"].firstMatch
    openEntryMenu(firstListHeader)
    let removal = application.plannerElement("Remove from itinerary")
    XCTAssertTrue(removal.waitForExistence(timeout: 5))
    removal.activateForPlannerJourney()
    if detailsAlongsideRoute {
      XCTAssertTrue(
        application.staticTexts[
          "The selected entry was removed. The List and its Items remain available outside this Itinerary."
        ].waitForExistence(timeout: 10))
      application.plannerElement("OK").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Choose an Item"].waitForExistence(timeout: 10))
    }
    XCTAssertTrue(
      waitForItineraryOrder(
        [originalIdentifiers[0], originalIdentifiers[2], originalIdentifiers[3]],
        application: application))
    assertChecks(["Completed", "To do", "Completed"], application: application)
    assertProgress("2 of 3 items done", application: application)
    recordScreenshot(application, name: "Native List entry removal keeps other route occurrences")
    openEntryMenu(application.plannerElement(originalIdentifiers[0]))
    XCTAssertTrue(removal.waitForExistence(timeout: 5))
    removal.activateForPlannerJourney()
    XCTAssertTrue(
      waitForItineraryOrder(
        [originalIdentifiers[2], originalIdentifiers[3]], application: application))
    assertChecks(["To do", "Completed"], application: application)
    assertProgress("1 of 2 items done", application: application)
    for source in ["Food stops", "Museum"] { addEntry(source, application: application) }
    XCTAssertEqual(rows.count, 4)
    let finalIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    XCTAssertEqual(Array(finalIdentifiers.prefix(2)), Array(originalIdentifiers.suffix(2)))
    XCTAssertFalse(originalIdentifiers.contains(finalIdentifiers[2]))
    XCTAssertFalse(originalIdentifiers.contains(finalIdentifiers[3]))
    assertChecks(["To do", "Completed", "To do", "To do"], application: application)
    assertProgress("1 of 4 items done", application: application)
    recordScreenshot(application, name: "Native ordinary entry readdition starts fresh local Todo")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    XCTAssertTrue(waitForItineraryOrder(finalIdentifiers, application: application))
    assertChecks(["To do", "Completed", "To do", "To do"], application: application)
    assertProgress("1 of 4 items done", application: application)
    recordScreenshot(application, name: "Native removed and readded entries after relaunch")
    openItem("Museum", application: application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openSection("Lists", application: application)
    let list = application.savedPlannerListRow("Food stops")
    revealNavigation(to: list, application: application)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    reveal(list.identifier, application: application).activateForPlannerJourney()
    let filters = application.plannerElement("saved.list.filters")
    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    let retainedMembership = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(retainedMembership.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedMembership.identifier, membershipIdentifier)
    XCTAssertTrue(membershipCompletion.waitForPlannerValue("Completed"))
    assertProgress("1 of 1 item done", application: application)
  }

  func testNativeEntryDragPreservesListChildrenAndRepeatedCompletionAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Museum", application: application)
    createList(application)
    createItinerary(application)
    for source in ["Museum", "Food stops", "Museum"] {
      addEntry(source, application: application)
    }
    let rows = itineraryRows(application)
    XCTAssertEqual(rows.count, 3)
    let originalIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    let firstCompletion = originalIdentifiers[0].replacingOccurrences(
      of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    application.plannerElement(firstCompletion).activateForPlannerJourney()
    assertProgress("1 of 3 items done", application: application)
    assertChecks(["Completed", "To do", "To do"], application: application)
    #if os(iOS)
      let reorder = application.savedPlannerItineraryReorderControl()
      reorder.activateForPlannerJourney()
    #endif
    let lastItem = application.plannerElement(originalIdentifiers[2])
    let listEntryIdentifier = originalIdentifiers[1].components(separatedBy: ".")[3]
    let listEntry = application.descendants(matching: .any)
      .matching(identifier: "saved.itinerary.entry.\(listEntryIdentifier)").firstMatch
    dragEntry(lastItem, relativeTo: listEntry, before: true, application: application)
    XCTAssertTrue(
      waitForItineraryOrder(
        [originalIdentifiers[0], originalIdentifiers[2], originalIdentifiers[1]],
        application: application))
    assertChecks(["Completed", "To do", "To do"], application: application)
    assertProgress("1 of 3 items done", application: application)
    recordScreenshot(application, name: "Native direct entry dragged into the middle of a route")
    let firstItem = application.plannerElement(originalIdentifiers[0])
    dragEntry(listEntry, relativeTo: firstItem, before: true, application: application)
    XCTAssertTrue(
      waitForItineraryOrder(
        [originalIdentifiers[1], originalIdentifiers[0], originalIdentifiers[2]],
        application: application))
    assertChecks(["To do", "Completed", "To do"], application: application)
    assertProgress("0 of 1 item done", application: application)
    recordScreenshot(application, name: "Native List group dragged with its expanded child")
    dragEntry(firstItem, relativeTo: lastItem, before: false, application: application)
    let finalIdentifiers = [originalIdentifiers[1], originalIdentifiers[2], originalIdentifiers[0]]
    XCTAssertTrue(waitForItineraryOrder(finalIdentifiers, application: application))
    assertChecks(["To do", "To do", "Completed"], application: application)
    assertProgress("1 of 3 items done", application: application)
    #if os(iOS)
      application.savedPlannerItineraryReorderControl().activateForPlannerJourney()
    #endif
    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    XCTAssertTrue(waitForItineraryOrder(finalIdentifiers, application: application))
    assertChecks(["To do", "To do", "Completed"], application: application)
    assertProgress("1 of 3 items done", application: application)
    assertProgress("0 of 1 item done", application: application)
    recordScreenshot(application, name: "Native dragged route order and completion after relaunch")
    openItem("Museum", application: application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
  }

  private func dragEntry(
    _ entry: XCUIElement, relativeTo target: XCUIElement, before: Bool,
    application: XCUIApplication
  ) {
    XCTAssertTrue(entry.waitForExistence(timeout: 5))
    XCTAssertTrue(target.waitForExistence(timeout: 5))
    #if os(macOS)
      let origin = entry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      let destination = target.coordinate(
        withNormalizedOffset: CGVector(dx: 0.5, dy: before ? 0.1 : 0.9))
      origin.click(
        forDuration: 1, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 1)
    #else
      let row = application.cells.containing(.any, identifier: entry.identifier).firstMatch
      let targetRow = application.cells.containing(.any, identifier: target.identifier).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      XCTAssertTrue(targetRow.waitForExistence(timeout: 5))
      let handle = row.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
        .firstMatch
      XCTAssertTrue(handle.waitForExistence(timeout: 5), application.debugDescription)
      let destination = targetRow.coordinate(
        withNormalizedOffset: CGVector(dx: 0.9, dy: before ? 0.1 : 0.9))
      handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .press(forDuration: 1, thenDragTo: destination)
    #endif
  }

  func testNativeEntryReorderingPreservesRepeatedAppearanceCompletionAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Museum", application: application)
    createList(application)
    createItinerary(application)
    for source in ["Museum", "Museum", "Food stops"] {
      addEntry(source, application: application)
    }
    let rows = itineraryRows(application)
    XCTAssertEqual(rows.count, 3)
    let originalIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    let firstCompletion = originalIdentifiers[0].replacingOccurrences(
      of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    application.plannerElement(firstCompletion).activateForPlannerJourney()
    assertProgress("1 of 3 items done", application: application)
    assertChecks(["Completed", "To do", "To do"], application: application)
    let first = application.plannerElement(originalIdentifiers[0])
    openEntryMenu(first)
    let moveToEnd = application.plannerElement("Move to end")
    XCTAssertTrue(moveToEnd.waitForExistence(timeout: 5))
    XCTAssertTrue(moveToEnd.isEnabled)
    recordScreenshot(application, name: "Native Itinerary entry ordering menu")
    moveToEnd.activateForPlannerJourney()
    let afterDirectMove = [originalIdentifiers[1], originalIdentifiers[2], originalIdentifiers[0]]
    XCTAssertTrue(waitForItineraryOrder(afterDirectMove, application: application))
    assertChecks(["To do", "To do", "Completed"], application: application)
    assertProgress("1 of 3 items done", application: application)
    let listHeader = application.staticTexts["Food stops"].firstMatch
    XCTAssertTrue(listHeader.waitForExistence(timeout: 5))
    openEntryMenu(listHeader)
    let moveToBeginning = application.plannerElement("Move to beginning")
    XCTAssertTrue(moveToBeginning.waitForExistence(timeout: 5))
    XCTAssertTrue(moveToBeginning.isEnabled)
    moveToBeginning.activateForPlannerJourney()
    let finalIdentifiers = [originalIdentifiers[2], originalIdentifiers[1], originalIdentifiers[0]]
    XCTAssertTrue(waitForItineraryOrder(finalIdentifiers, application: application))
    assertChecks(["To do", "To do", "Completed"], application: application)
    assertProgress("1 of 3 items done", application: application)
    assertProgress("0 of 1 item done", application: application)
    recordScreenshot(application, name: "Native reordered List group and repeated Item entries")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    XCTAssertTrue(waitForItineraryOrder(finalIdentifiers, application: application))
    assertChecks(["To do", "To do", "Completed"], application: application)
    assertProgress("1 of 3 items done", application: application)
    assertProgress("0 of 1 item done", application: application)
    recordScreenshot(
      application, name: "Native Itinerary order and local completion after relaunch")
    openItem("Museum", application: application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
  }

  private func openEntryMenu(_ entry: XCUIElement) {
    #if os(macOS)
      entry.rightClick()
    #else
      entry.press(forDuration: 1.2)
    #endif
  }

  private func waitForItineraryOrder(
    _ identifiers: [String], application: XCUIApplication
  ) -> Bool {
    let rows = itineraryRows(application)
    let predicate = NSPredicate { _, _ in
      rows.allElementsBoundByIndex.map(\.identifier) == identifiers
    }
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: application)], timeout: 10)
      == .completed
  }

  func testRepeatedListEntryBulkCompletionStaysWithinTheReviewedEntry() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Museum", application: application)
    createList(application)
    createItinerary(application)
    for source in ["Food stops", "Food stops", "Museum"] {
      addEntry(source, application: application)
    }
    let rows = itineraryRows(application)
    let identities = rows.allElementsBoundByIndex.map(\.identifier)
    XCTAssertEqual(rows.count, 3)
    assertProgress("0 of 3 items done", application: application)
    openFirstListEntryReview(done: true, application: application)
    XCTAssertTrue(application.staticTexts["1 item in Food stops"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.staticTexts["Only completion in this List entry in the Itinerary changes."].exists
    )
    application.plannerElement("saved.itinerary.list.bulk.cancel").activateForPlannerJourney()
    assertProgress("0 of 3 items done", application: application)
    openFirstListEntryReview(done: true, application: application)
    recordScreenshot(application, name: "Native repeated List entry bulk review")
    application.plannerElement("saved.itinerary.list.bulk.confirm").activateForPlannerJourney()
    assertProgress("1 of 3 items done", application: application)
    assertChecks(["Completed", "To do", "To do"], application: application)
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), identities)
    openItem("Museum", application: application)
    let globalCompletion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openSection("Lists", application: application)
    selectContainer(prefix: "saved.list.", title: "Food stops", application: application)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))

    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    assertProgress("1 of 3 items done", application: application)
    assertChecks(["Completed", "To do", "To do"], application: application)
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), identities)
    recordScreenshot(application, name: "Native repeated List entry completion after relaunch")
    openFirstListEntryReview(done: false, application: application)
    application.plannerElement("saved.itinerary.list.bulk.confirm").activateForPlannerJourney()
    assertProgress("0 of 3 items done", application: application)
    assertChecks(["To do", "To do", "To do"], application: application)
  }

  func testItineraryBulkConfirmationPreservesGlobalAndStandaloneListCompletion() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Hotel", application: application)
    let globalCompletion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    createItem("Museum", application: application)
    createList(application)
    createItinerary(application)
    for source in ["Hotel", "Food stops", "Hotel"] { addEntry(source, application: application) }
    let identities = itineraryRows(application).allElementsBoundByIndex.map(\.identifier)
    XCTAssertEqual(itineraryRows(application).count, 3)
    assertProgress("2 of 3 items done", application: application)

    openItem("Museum", application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    openItinerary(application)
    XCTAssertEqual(itineraryRows(application).count, 3)
    openBulkReview(done: true, application: application)
    XCTAssertTrue(application.staticTexts["3 items in Weekend route"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Only completion in this Itinerary changes."].exists)
    XCTAssertTrue(
      application.staticTexts["Includes archived items and items hidden by filters."].exists)
    recordScreenshot(application, name: "Native Itinerary bulk confirmation")
    application.plannerElement("saved.itinerary.bulk.cancel").activateForPlannerJourney()
    assertProgress("3 of 3 items finished", application: application)
    openBulkReview(done: true, application: application)
    application.plannerElement("saved.itinerary.bulk.confirm").activateForPlannerJourney()
    assertProgress("3 of 3 items done", application: application)
    openBulkReview(done: false, application: application)
    XCTAssertTrue(
      application.staticTexts["Items completed globally will still appear done."].exists)
    application.plannerElement("saved.itinerary.bulk.confirm").activateForPlannerJourney()
    assertProgress("3 of 3 items finished", application: application)
    XCTAssertEqual(itineraryRows(application).allElementsBoundByIndex.map(\.identifier), identities)
    XCTAssertTrue(application.staticTexts["1 of 1 item finished"].exists)

    openItem("Hotel", application: application)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openItem("Museum", application: application)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Archived"].exists)
    openSection("Lists", application: application)
    selectContainer(prefix: "saved.list.", title: "Food stops", application: application)
    XCTAssertTrue(application.staticTexts["1 of 1 item finished"].waitForExistence(timeout: 10))

    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    assertProgress("3 of 3 items finished", application: application)
    XCTAssertEqual(itineraryRows(application).allElementsBoundByIndex.map(\.identifier), identities)
    recordScreenshot(application, name: "Native Itinerary bulk completion after relaunch")
  }

  private func createItem(_ title: String, application: XCUIApplication) {
    openSection("Items", application: application)
    application.openSavedPlannerNewItemEditor()
    let field = application.textFields["saved.item.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(title)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForExistence(timeout: 10))
  }

  private func createList(_ application: XCUIApplication) {
    application.beginPlannerListCreation()
    let field = application.textFields["saved.list.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText("Food stops")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    let addition = application.plannerElement("saved.list.add")
    if addition.exists {
      addition.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5), application.debugDescription)
      overflow.activateForPlannerJourney()
      application.plannerElement("Add existing item").activateForPlannerJourney()
    }
    let museum = application.staticTexts["Museum"].firstMatch
    XCTAssertTrue(museum.waitForExistence(timeout: 5))
    museum.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum").firstMatch.waitForExistence(timeout: 10))
  }

  private func createItinerary(_ application: XCUIApplication) {
    openSection("Itineraries", application: application)
    reveal("saved.itinerary.new", application: application).activateForPlannerJourney()
    let field = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText("Weekend route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
  }

  private func addEntry(_ title: String, application: XCUIApplication) {
    let addition = reveal("saved.itinerary.entry.new", application: application)
    addition.activateForPlannerJourney()
    let choice = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND (label == %@ OR value == %@)",
        "saved.itinerary.entry.choice.", title, title)
    ).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
    application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    XCTAssertTrue(addition.waitForExistence(timeout: 10))
  }

  private func openBulkReview(done: Bool, application: XCUIApplication) {
    reveal("saved.itinerary.actions", application: application).activateForPlannerJourney()
    let action = application.plannerElement(done ? "Mark all done" : "Mark all undone")
    XCTAssertTrue(action.waitForExistence(timeout: 5))
    action.activateForPlannerJourney()
  }

  private func openFirstListEntryReview(done: Bool, application: XCUIApplication) {
    let header = application.staticTexts["Food stops"].firstMatch
    XCTAssertTrue(header.waitForExistence(timeout: 5))
    #if os(macOS)
      header.rightClick()
    #else
      header.press(forDuration: 1)
    #endif
    let action = application.plannerElement(done ? "Mark all done" : "Mark all undone")
    XCTAssertTrue(action.waitForExistence(timeout: 5), application.debugDescription)
    action.activateForPlannerJourney()
  }

  private func assertChecks(_ values: [String], application: XCUIApplication) {
    let rows = itineraryRows(application)
    XCTAssertEqual(rows.count, values.count)
    for (index, value) in values.enumerated() {
      let identifier = rows.element(boundBy: index).identifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
      XCTAssertEqual(application.plannerElement(identifier).value as? String, value)
    }
  }

  private func openItem(_ title: String, application: XCUIApplication) {
    openSection("Items", application: application)
    application.chooseSavedPlannerStateFilter(
      "All archive states", control: reveal("saved.items.filters", application: application))
    let row = application.savedPlannerItemRows(title).firstMatch
    revealNavigation(to: row, application: application)
    XCTAssertTrue(row.waitForExistence(timeout: 10), application.debugDescription)
    row.activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForExistence(timeout: 10))
  }

  private func openItinerary(_ application: XCUIApplication) {
    openSection("Itineraries", application: application)
    #if os(iOS)
      if application.navigationBars["Weekend route"].waitForExistence(timeout: 5),
        application.collectionViews["saved.itinerary.contents"].exists
      {
        let sidebar = application.buttons["Hide Sidebar"].firstMatch
        if sidebar.exists && sidebar.isHittable { sidebar.activateForPlannerJourney() }
        return
      }
    #endif
    selectContainer(
      prefix: "saved.itinerary.row.", title: "Weekend route", application: application)
  }

  private func selectContainer(prefix: String, title: String, application: XCUIApplication) {
    let row = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", prefix, title)
    ).firstMatch
    revealNavigation(to: row, application: application)
    XCTAssertTrue(row.waitForExistence(timeout: 10), application.debugDescription)
    row.activateForPlannerJourney()
  }

  private func openSection(_ title: String, application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("saved.section.\(title.lowercased())")
      XCTAssertTrue(section.waitForExistence(timeout: 10))
      section.activateForPlannerJourney()
    #else
      application.openPlannerSection(title)
    #endif
  }

  private func reveal(_ identifier: String, application: XCUIApplication) -> XCUIElement {
    let element = application.plannerElement(identifier)
    revealNavigation(to: element, application: application)
    XCTAssertTrue(element.waitForExistence(timeout: 10), application.debugDescription)
    return element
  }

  private func revealNavigation(to element: XCUIElement, application: XCUIApplication) {
    if element.waitForExistence(timeout: 2) { return }
    for _ in 0..<2 {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists {
        sidebar.activateForPlannerJourney()
      } else {
        let back = application.plannerElement("BackButton")
        guard back.exists else { return }
        back.activateForPlannerJourney()
      }
      if element.waitForExistence(timeout: 2) { return }
    }
  }

  private func itineraryRows(_ application: XCUIApplication) -> XCUIElementQuery {
    application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
  }

  private func assertProgress(_ value: String, application: XCUIApplication) {
    let progress = application.progressIndicators["saved.itinerary.progress"]
    let expected = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", value), object: progress)
    XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 10), .completed)
  }

  private func activateGlobalCompletion(_ element: XCUIElement) {
    #if os(macOS)
      element.click()
    #else
      let visibleSwitch = element.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = application.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
