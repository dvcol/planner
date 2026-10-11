import XCTest

@MainActor
final class SavedItineraryBulkJourneyTests: XCTestCase {
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
    application.plannerElement("Archive Item").activateForPlannerJourney()
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
    assertProgress("2 of 3 items done", application: application)
    openBulkReview(done: true, application: application)
    application.plannerElement("saved.itinerary.bulk.confirm").activateForPlannerJourney()
    assertProgress("3 of 3 items done", application: application)
    openBulkReview(done: false, application: application)
    XCTAssertTrue(
      application.staticTexts["Items completed globally will still appear done."].exists)
    application.plannerElement("saved.itinerary.bulk.confirm").activateForPlannerJourney()
    assertProgress("2 of 3 items done", application: application)
    XCTAssertEqual(itineraryRows(application).allElementsBoundByIndex.map(\.identifier), identities)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].exists)

    openItem("Hotel", application: application)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openItem("Museum", application: application)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Archived"].exists)
    openSection("Lists", application: application)
    selectContainer(prefix: "saved.list.", title: "Food stops", application: application)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))

    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    assertProgress("2 of 3 items done", application: application)
    XCTAssertEqual(itineraryRows(application).allElementsBoundByIndex.map(\.identifier), identities)
    recordScreenshot(application, name: "Native Itinerary bulk completion after relaunch")
  }

  private func createItem(_ title: String, application: XCUIApplication) {
    openSection("Items", application: application)
    reveal("saved.item.new", application: application).activateForPlannerJourney()
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
    openSection("Lists", application: application)
    reveal("saved.list.new", application: application).activateForPlannerJourney()
    let field = application.textFields["saved.list.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText("Food stops")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    let addition = application.plannerElement("saved.list.add")
    if addition.exists {
      addition.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5), application.debugDescription)
      overflow.activateForPlannerJourney()
      application.plannerElement("Add existing Item").activateForPlannerJourney()
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
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.entry.choice.", title)
    ).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
    application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    XCTAssertTrue(addition.waitForExistence(timeout: 10))
  }

  private func openBulkReview(done: Bool, application: XCUIApplication) {
    reveal("saved.itinerary.actions", application: application).activateForPlannerJourney()
    let action = application.plannerElement(done ? "Mark all Done" : "Mark all Undone")
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
    let action = application.plannerElement(done ? "Mark all Done" : "Mark all Undone")
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
    reveal("saved.items.filters", application: application).activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
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
    #else
      let section = application.buttons[title].firstMatch
    #endif
    XCTAssertTrue(section.waitForExistence(timeout: 10))
    section.activateForPlannerJourney()
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
    XCTAssertTrue(application.staticTexts[value].waitForExistence(timeout: 10))
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
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
