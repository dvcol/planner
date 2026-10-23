import XCTest

@MainActor
final class SavedListReorderingJourneyTests: XCTestCase {
  func testFilteredManualDragRetainsHiddenMembershipCompletionAndOrderAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Hotel", application: application)
    createItem("Museum", application: application)
    createItem("Cafe", application: application)
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Tokyo")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    addItem("Hotel", application: application)
    addItem("Museum", application: application)
    addItem("Cafe", application: application)
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    let museum = application.savedPlannerItemRows("Museum").firstMatch
    let cafe = application.savedPlannerItemRows("Cafe").firstMatch
    let hotelIdentifier = hotel.identifier
    let museumIdentifier = museum.identifier
    let cafeIdentifier = cafe.identifier
    let hotelCompletion = application.buttons[
      hotelIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    hotelCompletion.activateForPlannerJourney()
    XCTAssertTrue(hotelCompletion.waitForPlannerValue("Completed"))
    let filters = application.plannerElement("saved.list.filters")
    application.chooseSavedPlannerStateFilter("Todo", control: filters)
    XCTAssertTrue(hotel.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    XCTAssertTrue(application.staticTexts["Showing 2 of 3 items"].exists)
    #if os(iOS)
      application.savedPlannerListEditControl().activateForPlannerJourney()
    #endif
    recordScreenshot(application, name: "Filtered List before native drag")
    dragItem(cafe, relativeTo: museum, before: true, application: application)
    recordScreenshot(application, name: "Filtered List after native drag")
    XCTAssertTrue(waitForOrder(cafe, before: museum), application.debugDescription)
    #if os(iOS)
      application.savedPlannerListEditControl().activateForPlannerJourney()
    #endif
    XCTAssertFalse(hotel.exists)
    XCTAssertEqual(museum.identifier, museumIdentifier)
    XCTAssertEqual(cafe.identifier, cafeIdentifier)
    recordScreenshot(application, name: "Filtered Manual drag keeps full List progress")
    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(waitForOrder(hotel, before: cafe))
    XCTAssertTrue(waitForOrder(cafe, before: museum))
    XCTAssertEqual(hotel.identifier, hotelIdentifier)
    XCTAssertTrue(hotelCompletion.waitForPlannerValue("Completed"))
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let list = application.savedPlannerListRow("Tokyo")
    revealSidebarIfNeeded(application, element: list)
    list.activateForPlannerJourney()
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(waitForOrder(hotel, before: cafe))
    XCTAssertTrue(waitForOrder(cafe, before: museum))
    XCTAssertEqual(hotel.identifier, hotelIdentifier)
    XCTAssertEqual(museum.identifier, museumIdentifier)
    XCTAssertEqual(cafe.identifier, cafeIdentifier)
    XCTAssertTrue(hotelCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    #if os(iOS)
      if application.windows.firstMatch.frame.width < 600 {
        let navigationTitle = application.navigationBars.staticTexts["Tokyo"].firstMatch
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5))
      }
    #endif
    recordScreenshot(
      application, name: "Hidden membership retained after filtered drag and relaunch")
  }

  func testManualMoveRetainsAppearanceCompletionDetailsAndOrderAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Hotel", application: application)
    createItem("Museum", application: application)
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Tokyo")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    addItem("Hotel", application: application)
    addItem("Museum", application: application)
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    let museum = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertLessThan(hotel.frame.minY, museum.frame.minY)
    let retainedIdentifier = hotel.identifier
    let completion = application.buttons[
      retainedIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    completion.activateForPlannerJourney()
    hotel.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].exists)
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
    #if os(macOS)
      hotel.rightClick()
    #else
      hotel.press(forDuration: 1)
    #endif
    let move = application.plannerElement("Move to end")
    XCTAssertTrue(move.waitForExistence(timeout: 5))
    move.activateForPlannerJourney()
    XCTAssertTrue(waitForOrder(museum, before: hotel))
    XCTAssertEqual(hotel.identifier, retainedIdentifier)
    hotel.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Notes for Hotel"].exists)
    recordScreenshot(application, name: "Saved List after Manual move")

    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let list = application.savedPlannerListRow("Tokyo")
    revealSidebarIfNeeded(application, element: list)
    list.activateForPlannerJourney()
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(waitForOrder(museum, before: hotel))
    XCTAssertEqual(hotel.identifier, retainedIdentifier)
    hotel.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Notes for Hotel"].exists)

    #if os(iOS)
      let backToList = application.plannerElement("BackButton")
      if backToList.exists { backToList.activateForPlannerJourney() }
      application.savedPlannerListEditControl().activateForPlannerJourney()
    #endif
    dragItem(hotel, relativeTo: museum, before: true, application: application)
    XCTAssertTrue(waitForOrder(hotel, before: museum))
    dragItem(hotel, relativeTo: museum, before: false, application: application)
    XCTAssertTrue(waitForOrder(museum, before: hotel))
    dragItem(hotel, relativeTo: museum, before: true, application: application)
    XCTAssertTrue(waitForOrder(hotel, before: museum))
    #if os(iOS)
      application.savedPlannerListEditControl().activateForPlannerJourney()
    #endif
    XCTAssertEqual(hotel.identifier, retainedIdentifier)
    hotel.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Notes for Hotel"].exists)
    recordScreenshot(application, name: "Saved List after native drag")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: list)
    list.activateForPlannerJourney()
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertTrue(waitForOrder(hotel, before: museum))
    XCTAssertEqual(hotel.identifier, retainedIdentifier)
    hotel.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Notes for Hotel"].exists)
  }

  private func createItem(_ title: String, application: XCUIApplication) {
    openSection("Items", application: application)
    application.openSavedPlannerNewItemEditor()
    let field = application.textFields["saved.item.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(title)
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Notes for \(title)")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Notes for \(title)"].waitForExistence(timeout: 10))
  }

  private func addItem(_ title: String, application: XCUIApplication) {
    application.openSavedPlannerListAddMenu()
    let add = application.plannerElement("saved.list.add")
    if add.exists {
      add.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5), application.debugDescription)
      overflow.activateForPlannerJourney()
      let overflowAdd = application.plannerElement("Add existing item")
      XCTAssertTrue(overflowAdd.waitForExistence(timeout: 5), application.debugDescription)
      overflowAdd.activateForPlannerJourney()
    }
    let candidate = application.staticTexts[title].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("saved.membership.add").waitForExistence(timeout: 2))
    XCTAssertTrue(application.savedPlannerItemRows(title).firstMatch.waitForExistence(timeout: 10))
  }

  private func openSection(_ title: String, application: XCUIApplication) {
    application.openPlannerSection(title)
  }

  private func revealSidebarIfNeeded(_ application: XCUIApplication, element: XCUIElement) {
    if element.waitForExistence(timeout: 3) { return }
    for _ in 0..<2 {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists {
        sidebar.activateForPlannerJourney()
      } else {
        let back = application.plannerElement("BackButton")
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.activateForPlannerJourney()
      }
      if element.waitForExistence(timeout: 3) { return }
    }
    XCTFail("Planner's native List navigation did not become available.")
  }

  private func waitForOrder(_ first: XCUIElement, before second: XCUIElement) -> Bool {
    let predicate = NSPredicate { _, _ in
      first.exists && second.exists && first.frame.minY < second.frame.minY
    }
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: first)], timeout: 5)
      == .completed
  }

  private func dragItem(
    _ item: XCUIElement, relativeTo target: XCUIElement, before: Bool,
    application: XCUIApplication
  ) {
    #if os(macOS)
      let destination = target.coordinate(
        withNormalizedOffset: CGVector(dx: 0.5, dy: before ? 0 : 1))
      item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .click(
          forDuration: 1, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 1)
    #else
      let row = application.cells.containing(.button, identifier: item.identifier).firstMatch
      let targetRow = application.cells.containing(.button, identifier: target.identifier)
        .firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      XCTAssertTrue(targetRow.waitForExistence(timeout: 5))
      let destination = targetRow.coordinate(
        withNormalizedOffset: CGVector(dx: 0.9, dy: before ? 0.1 : 0.9))
      let handle = row.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
        .firstMatch
      XCTAssertTrue(handle.waitForExistence(timeout: 5), application.debugDescription)
      handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .press(
          forDuration: 1, thenDragTo: destination, withVelocity: .slow,
          thenHoldForDuration: 1)
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
