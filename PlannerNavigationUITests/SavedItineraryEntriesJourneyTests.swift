import XCTest

@MainActor
final class SavedItineraryEntriesJourneyTests: XCTestCase {
  func testNativeSchedulingFiltersNarrowCatalogInboxAndListWithoutChangingProgress() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Hotel", notes: "Meet in the lobby", application: application)
    createItem("Plain", notes: "Keep for later", application: application)
    openSection("Itineraries", application: application)
    reveal(application, identifier: "saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
    chooseEntry("Hotel", application: application)
    application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Itinerary").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    XCTAssertTrue(itineraryRows(application).firstMatch.waitForExistence(timeout: 10))
    openItemCatalog(application)
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    let plain = application.savedPlannerItemRows("Plain").firstMatch
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(plain.exists)
    let catalogFilters = application.plannerElement("saved.items.filters")
    application.chooseSavedPlannerStateFilter("Scheduled", control: catalogFilters)
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(plain.waitForNonExistence(timeout: 10))
    XCTAssertEqual(catalogFilters.plannerControlTitle, "Active · Scheduled")
    recordScreenshot(application, name: "Native Scheduled catalog filter")
    application.chooseSavedPlannerStateFilter("Unscheduled", control: catalogFilters)
    XCTAssertTrue(plain.waitForExistence(timeout: 10))
    XCTAssertTrue(hotel.waitForNonExistence(timeout: 10))
    application.chooseSavedPlannerStateFilter("All scheduling states", control: catalogFilters)
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(plain.exists)
    openSection("Inbox", application: application)
    let inboxFilters = application.plannerElement("saved.inbox.filters")
    XCTAssertTrue(inboxFilters.waitForExistence(timeout: 10))
    application.chooseSavedPlannerStateFilter("Scheduled", control: inboxFilters)
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(plain.waitForNonExistence(timeout: 10))
    application.chooseSavedPlannerStateFilter("Unscheduled", control: inboxFilters)
    XCTAssertTrue(plain.waitForExistence(timeout: 10))
    XCTAssertTrue(hotel.waitForNonExistence(timeout: 10))
    XCTAssertEqual(inboxFilters.plannerControlTitle, "Todo · Active · Unscheduled")
    recordScreenshot(application, name: "Native Unscheduled Inbox filter")
    openSection("Lists", application: application)
    reveal(application, identifier: "saved.list.new").activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Review")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for itemTitle in ["Hotel", "Plain"] {
      openListAddition(application)
      let choice = application.staticTexts[itemTitle].firstMatch
      XCTAssertTrue(choice.waitForExistence(timeout: 5))
      choice.activateForPlannerJourney()
      application.plannerElement("saved.membership.add").activateForPlannerJourney()
      XCTAssertTrue(
        application.savedPlannerItemRows(itemTitle).firstMatch.waitForExistence(timeout: 10))
    }
    let hotelMembership = application.savedPlannerItemRows("Hotel").firstMatch
    let membershipIdentity = hotelMembership.identifier
    let check = application.plannerElement(
      membershipIdentity.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    check.activateForPlannerJourney()
    XCTAssertTrue(check.waitForPlannerValue("Completed"))
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].exists)
    let listFilters = application.plannerElement("saved.list.filters")
    application.chooseSavedPlannerStateFilter("Scheduled", control: listFilters)
    XCTAssertTrue(hotelMembership.waitForExistence(timeout: 10))
    XCTAssertTrue(plain.waitForNonExistence(timeout: 10))
    application.chooseSavedPlannerStateFilter("Todo", control: listFilters)
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].exists)
    XCTAssertTrue(application.staticTexts["Showing 0 of 2 items"].exists)
    XCTAssertEqual(listFilters.plannerControlTitle, "Todo · Scheduled")
    recordScreenshot(application, name: "Native cumulative scheduling filter retains full progress")
    listFilters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(hotelMembership.waitForExistence(timeout: 10))
    XCTAssertEqual(listFilters.plannerControlTitle, "All")
    XCTAssertTrue(check.waitForPlannerValue("Completed"))
    application.chooseSavedPlannerStateFilter("Unscheduled", control: listFilters)
    XCTAssertTrue(plain.waitForExistence(timeout: 10))
    XCTAssertTrue(hotelMembership.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].exists)
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let retainedList = application.savedPlannerListRow("Review")
    if !retainedList.waitForExistence(timeout: 2) {
      application.plannerElement("Show Sidebar").activateForPlannerJourney()
    }
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    retainedList.activateForPlannerJourney()
    XCTAssertTrue(hotelMembership.waitForExistence(timeout: 10))
    XCTAssertEqual(hotelMembership.identifier, membershipIdentity)
    XCTAssertTrue(check.waitForPlannerValue("Completed"))
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].exists)
    application.chooseSavedPlannerStateFilter("Scheduled", control: listFilters)
    XCTAssertTrue(hotelMembership.waitForExistence(timeout: 10))
    XCTAssertTrue(plain.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].exists)
    recordScreenshot(
      application, name: "Native scheduling filter retains membership after relaunch")
  }

  func testSavedRowsShowCurrentPlanDatesAndInheritedPlanningAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Hotel", notes: "Meet in the lobby", application: application)
    openItemCatalog(application)
    let globalRow = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(globalRow.waitForExistence(timeout: 10))
    let sourceRowIdentity = globalRow.identifier
    XCTAssertFalse((globalRow.value as? String ?? "").contains("Scheduled:"))
    openSection("Itineraries", application: application)
    reveal(application, identifier: "saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
    chooseEntry("Hotel", application: application)
    application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    let contextualRow = itineraryRows(application).firstMatch
    XCTAssertTrue(contextualRow.waitForExistence(timeout: 10))
    let appearanceIdentity = contextualRow.identifier
    XCTAssertFalse((contextualRow.value as? String ?? "").contains("Scheduled:"))
    application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Itinerary").activateForPlannerJourney()
    let allDay = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.allDay").firstMatch
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    #if os(macOS)
      allDay.click()
    #else
      let visibleSwitch = allDay.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
    XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule.")
    ).firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertTrue((contextualRow.value as? String ?? "").contains("Scheduled: Plan ·"))
    XCTAssertTrue((contextualRow.value as? String ?? "").contains("All day"))
    let contextualMetadata = contextualRow.value as? String
    XCTAssertEqual(contextualRow.identifier, appearanceIdentity)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].exists)
    recordScreenshot(application, name: "Native itinerary row shows its actual plan date")
    openItemCatalog(application)
    XCTAssertTrue(globalRow.waitForExistence(timeout: 10))
    XCTAssertEqual(globalRow.identifier, sourceRowIdentity)
    XCTAssertTrue((globalRow.value as? String ?? "").contains("In scheduled plan"))
    XCTAssertFalse((globalRow.value as? String ?? "").contains("All day"))
    recordScreenshot(application, name: "Native global Item row shows inherited planning")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItemCatalog(application)
    XCTAssertTrue(globalRow.waitForExistence(timeout: 10))
    XCTAssertEqual(globalRow.identifier, sourceRowIdentity)
    XCTAssertTrue((globalRow.value as? String ?? "").contains("In scheduled plan"))
    recordScreenshot(application, name: "Native inherited planning survives relaunch")
    openSection("Itineraries", application: application)
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Weekend route")
    ).firstMatch
    if !itinerary.waitForExistence(timeout: 2) {
      let sidebar = application.plannerElement("Show Sidebar")
      XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
      sidebar.activateForPlannerJourney()
    }
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(contextualRow.waitForExistence(timeout: 10))
    XCTAssertEqual(contextualRow.identifier, appearanceIdentity)
    XCTAssertEqual(contextualRow.value as? String, contextualMetadata)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].exists)
    recordScreenshot(application, name: "Native contextual plan row survives relaunch")
  }

  private func openItemCatalog(_ application: XCUIApplication) {
    openSection("Items", application: application)
    let back = application.navigationBars.buttons["Items"].firstMatch
    if back.exists { back.activateForPlannerJourney() }
    XCTAssertTrue(application.plannerElement("saved.item.new").waitForExistence(timeout: 10))
  }

  func testOrderedItemAndListEntriesKeepIndependentChecksAndDetailsAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Zulu Hotel", notes: "Meet in the lobby", application: application)
    createItem("Beta Museum", notes: "Garden entrance", application: application)
    openSection("Lists", application: application)
    reveal(application, identifier: "saved.list.new").activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Food stops")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openListAddition(application)
    let museum = application.staticTexts["Beta Museum"].firstMatch
    XCTAssertTrue(museum.waitForExistence(timeout: 5))
    museum.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Beta Museum").firstMatch.waitForExistence(timeout: 10))

    openSection("Itineraries", application: application)
    reveal(application, identifier: "saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    let addEntry = application.plannerElement("saved.itinerary.entry.new")
    XCTAssertTrue(addEntry.waitForExistence(timeout: 5))
    addEntry.activateForPlannerJourney()
    chooseEntry("Zulu Hotel", application: application)
    application.plannerElement("saved.itinerary.entry.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].exists)
    for source in ["Zulu Hotel", "Food stops", "Zulu Hotel"] {
      addEntry.activateForPlannerJourney()
      chooseEntry(source, application: application)
      application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
      XCTAssertTrue(addEntry.waitForExistence(timeout: 10))
    }
    let rows = itineraryRows(application)
    XCTAssertEqual(rows.count, 3)
    XCTAssertEqual(
      rows.allElementsBoundByIndex.map(\.label), ["Zulu Hotel", "Beta Museum", "Zulu Hotel"])
    let originalIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    XCTAssertTrue(application.staticTexts["2 direct items · 1 list"].exists)
    XCTAssertTrue(application.staticTexts["0 of 3 items done"].exists)
    let firstCheck = checkForRow(rows.element(boundBy: 0), application: application)
    let lastCheck = checkForRow(rows.element(boundBy: 2), application: application)
    firstCheck.activateForPlannerJourney()
    XCTAssertTrue(firstCheck.waitForPlannerValue("Completed"))
    XCTAssertEqual(lastCheck.value as? String, "To do")
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    recordScreenshot(application, name: "Native ordered itinerary with a List group")
    rows.element(boundBy: 1).activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Garden entrance"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Native itinerary appearance details")

    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    let retained = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Weekend route")
    ).firstMatch
    if !retained.waitForExistence(timeout: 2) {
      let sidebar = application.plannerElement("Show Sidebar")
      XCTAssertTrue(sidebar.waitForExistence(timeout: 5), application.debugDescription)
      sidebar.activateForPlannerJourney()
    }
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(itineraryRows(application).firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(
      itineraryRows(application).allElementsBoundByIndex.map(\.identifier), originalIdentifiers)
    XCTAssertEqual(
      itineraryRows(application).allElementsBoundByIndex.map(\.label),
      ["Zulu Hotel", "Beta Museum", "Zulu Hotel"])
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    XCTAssertEqual(
      checkForRow(itineraryRows(application).element(boundBy: 0), application: application).value
        as? String, "Completed")
    XCTAssertEqual(
      checkForRow(itineraryRows(application).element(boundBy: 2), application: application).value
        as? String, "To do")
  }

  private func createItem(_ title: String, notes: String, application: XCUIApplication) {
    openSection("Items", application: application)
    reveal(application, identifier: "saved.item.new").activateForPlannerJourney()
    let field = application.textFields["saved.item.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(title)
    let notesField = application.textFields["saved.item.notes"]
    notesField.activateForPlannerJourney()
    notesField.typeText(notes)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[notes].waitForExistence(timeout: 10))
  }

  private func openListAddition(_ application: XCUIApplication) {
    application.openSavedPlannerListAddMenu()
    let addItem = application.plannerElement("saved.list.add")
    if addItem.exists {
      addItem.activateForPlannerJourney()
      return
    }
    let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
    XCTAssertTrue(overflow.waitForExistence(timeout: 5), application.debugDescription)
    overflow.activateForPlannerJourney()
    let overflowAction = application.plannerElement("Add existing Item")
    XCTAssertTrue(overflowAction.waitForExistence(timeout: 5), application.debugDescription)
    overflowAction.activateForPlannerJourney()
  }

  private func openSection(_ title: String, application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("saved.section.\(title.lowercased())")
    #else
      let section = application.buttons[title].firstMatch
    #endif
    XCTAssertTrue(section.waitForExistence(timeout: 10))
    section.activateForPlannerJourney()
  }

  private func reveal(_ application: XCUIApplication, identifier: String) -> XCUIElement {
    let element = application.plannerElement(identifier)
    if !element.waitForExistence(timeout: 2) {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(element.waitForExistence(timeout: 10), application.debugDescription)
    return element
  }

  private func chooseEntry(_ title: String, application: XCUIApplication) {
    let choice = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.entry.choice.", title)
    ).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.itinerary.entry.add").isEnabled)
  }

  private func itineraryRows(_ application: XCUIApplication) -> XCUIElementQuery {
    application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
  }

  private func checkForRow(_ row: XCUIElement, application: XCUIApplication) -> XCUIElement {
    let identifier = row.identifier.replacingOccurrences(
      of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    return application.plannerElement(identifier)
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
