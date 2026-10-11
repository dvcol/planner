import XCTest

@MainActor
final class SavedItineraryEntriesJourneyTests: XCTestCase {
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
