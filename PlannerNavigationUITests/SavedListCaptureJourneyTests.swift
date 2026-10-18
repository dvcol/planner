import XCTest

@MainActor
final class SavedListCaptureJourneyTests: XCTestCase {
  func testArchivedListCreationActionsRemainDisabledInNativeOverflow() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createList("Archived destination", application: application)
    let list = application.savedPlannerListRow("Archived destination")
    if !list.exists || !list.isHittable { showListsSidebar(application) }
    XCTAssertTrue(list.waitForExistence(timeout: 5))
    #if os(macOS)
      list.rightClick()
    #else
      list.press(forDuration: 1)
    #endif
    application.plannerElement("Archive List").activateForPlannerJourney()
    XCTAssertTrue(list.waitForNonExistence(timeout: 10))
    openListArchiveFilter(application)
    application.plannerElement("All Lists").activateForPlannerJourney()
    openList("Archived destination", application: application)
    assertArchivedListCreationIsUnavailable(application)
  }

  func testListDestinationsRemainIndependentFromGlobalCaptureAndArchivedChoicesFallBack() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createList("North", application: application)
    createList("South", application: application)
    openGlobalCapture(application)
    prepareCapture("Global seed", inputText: "Global seed", application: application)
    chooseDestination("South", selected: true, application: application)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    openList("North", application: application)
    openListCapture(application)
    prepareCapture("North choice", inputText: "North choice", application: application)
    expectDestination("North", selected: true, application: application)
    expectDestination("South", selected: false, application: application)
    chooseDestination("South", selected: true, application: application)
    chooseDestination("North", selected: false, application: application)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openList("South", application: application)
    XCTAssertTrue(
      application.savedPlannerItemRows("North choice").firstMatch.waitForExistence(timeout: 10))
    openListCapture(application)
    prepareCapture("South choice", inputText: "South choice", application: application)
    expectDestination("South", selected: true, application: application)
    expectDestination("North", selected: false, application: application)
    chooseDestination("North", selected: true, application: application)
    chooseDestination("South", selected: false, application: application)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("North choice").firstMatch.waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("North", application: application)
    XCTAssertTrue(
      application.savedPlannerItemRows("South choice").firstMatch.waitForExistence(timeout: 10))
    openListCapture(application)
    prepareCapture("North check", inputText: "North check", application: application)
    expectDestination("North", selected: false, application: application)
    expectDestination("South", selected: true, application: application)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    openList("South", application: application)
    openListCapture(application)
    prepareCapture("South check", inputText: "South check", application: application)
    expectDestination("North", selected: true, application: application)
    expectDestination("South", selected: false, application: application)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    openGlobalCapture(application)
    prepareCapture("Global check", inputText: "Global check", application: application)
    expectDestination("North", selected: false, application: application)
    expectDestination("South", selected: true, application: application)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    openList("South", application: application)
    let archivedList = application.savedPlannerListRow("South")
    if !archivedList.exists || !archivedList.isHittable { showListsSidebar(application) }
    XCTAssertTrue(archivedList.waitForExistence(timeout: 5))
    #if os(macOS)
      archivedList.rightClick()
    #else
      archivedList.press(forDuration: 1)
    #endif
    application.plannerElement("Archive List").activateForPlannerJourney()
    XCTAssertTrue(archivedList.waitForNonExistence(timeout: 10))
    openListArchiveFilter(application)
    application.plannerElement("All Lists").activateForPlannerJourney()
    openList("South", application: application)
    assertArchivedListCreationIsUnavailable(application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("North", application: application)
    openListCapture(application)
    prepareCapture(
      "Missing destination", inputText: "Missing destination", application: application)
    expectDestination("North", selected: false, application: application)
    XCTAssertFalse(destination("South", application: application).exists)
    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Native List capture clears an archived remembered destination"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    XCTAssertEqual(application.savedPlannerItemRows("Missing destination").count, 0)
  }

  func testCurrentListCaptureStagesDestinationAndRetainsMembershipScopeAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createList("Weekend", application: application)
    openListCapture(application)
    prepareCapture("Cancelled List capture", application: application)
    let destination = destination("Weekend", application: application)
    reveal(destination, application: application)
    XCTAssertTrue(destination.waitForPlannerBooleanState(true))
    setDestination(destination, selected: false)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openListCapture(application)
    prepareCapture("List capture", application: application)
    reveal(destination, application: application)
    XCTAssertTrue(destination.waitForPlannerBooleanState(true))
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    let row = application.savedPlannerItemRows("List capture").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("List capture").count, 1)
    XCTAssertTrue(row.identifier.hasPrefix("saved.appearance."))
    XCTAssertEqual(application.savedPlannerItemRows("Cancelled List capture").count, 0)
    let membershipIdentifier = row.identifier
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Weekend"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement("saved.appearance.actions").exists)
    XCTAssertFalse(application.plannerElement("saved.item.completion").exists)
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    XCTAssertEqual(link.value as? String, "https://example.com/list-capture?keep=%41")
    let linkIdentifier = link.identifier
    #if os(macOS)
      let snapshot = application.windows.firstMatch.screenshot()
    #else
      let snapshot = application.screenshot()
    #endif
    let screenshot = XCTAttachment(screenshot: snapshot)
    screenshot.name = "Native List capture keeps membership detail scope"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Weekend", application: application)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(row.identifier, membershipIdentifier)
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Weekend"].waitForExistence(timeout: 5))
    let restoredLink = application.descendants(matching: .any)
      .matching(identifier: linkIdentifier).firstMatch
    XCTAssertTrue(restoredLink.waitForExistence(timeout: 5))
    XCTAssertEqual(restoredLink.value as? String, "https://example.com/list-capture?keep=%41")
  }

  private func createList(_ name: String, application: XCUIApplication) {
    let create = application.plannerElement("saved.list.new")
    #if os(macOS)
      application.plannerElement("saved.section.lists").activateForPlannerJourney()
      if create.exists && create.isHittable {
        create.activateForPlannerJourney()
      } else {
        let overflow = application.windows.firstMatch.popUpButtons["more toolbar items"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        overflow.activateForPlannerJourney()
        let nativeCreate = overflow.menuItems["New List"]
        XCTAssertTrue(nativeCreate.waitForExistence(timeout: 5))
        nativeCreate.activateForPlannerJourney()
      }
    #else
      if !create.waitForExistence(timeout: 3) || !create.isHittable {
        showListsSidebar(application)
      }
      if create.exists && create.isHittable {
        create.activateForPlannerJourney()
      } else {
        let overflow = application.navigationBars["Planner"].buttons["OverflowBarButtonItem"]
          .firstMatch
        XCTAssertTrue(overflow.waitForPlannerHittability())
        overflow.activateForPlannerJourney()
        let nativeCreate = application.plannerElement("New List")
        XCTAssertTrue(nativeCreate.waitForExistence(timeout: 5))
        nativeCreate.activateForPlannerJourney()
      }
    #endif
    let field = application.textFields["saved.list.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(name)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
  }

  private func openList(_ name: String, application: XCUIApplication) {
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow(name)
    if !list.waitForExistence(timeout: 3) || !list.isHittable { showListsSidebar(application) }
    XCTAssertTrue(list.waitForExistence(timeout: 5))
    list.activateForPlannerJourney()
    #if os(macOS)
      XCTAssertTrue(application.plannerElement("saved.list.actions").waitForExistence(timeout: 5))
    #else
      let toolbar = application.buttons.matching(
        NSPredicate(format: "identifier IN %@", ["saved.list.actions", "OverflowBarButtonItem"]))
      XCTAssertTrue(toolbar.firstMatch.waitForExistence(timeout: 5))
    #endif
  }

  private func showListsSidebar(_ application: XCUIApplication) {
    let sidebar = application.plannerElement("Show Sidebar")
    if sidebar.exists {
      sidebar.activateForPlannerJourney()
      return
    }
    let back = application.plannerElement("BackButton")
    XCTAssertTrue(back.exists)
    back.activateForPlannerJourney()
  }

  private func openGlobalCapture(_ application: XCUIApplication) {
    application.openPlannerSection("Items")
    let back = application.navigationBars.buttons["Items"].firstMatch
    if back.exists { back.activateForPlannerJourney() }
    application.openSavedPlannerCatalogAddMenu()
    let capture = application.plannerElement("saved.capture.new")
    XCTAssertTrue(capture.waitForExistence(timeout: 10))
    capture.activateForPlannerJourney()
  }

  private func assertArchivedListCreationIsUnavailable(_ application: XCUIApplication) {
    let creationControl = application.savedPlannerListAddControl()
    XCTAssertTrue(creationControl.waitForExistence(timeout: 5))
    guard creationControl.isEnabled else { return }
    creationControl.activateForPlannerJourney()
    let hierarchy = XCTAttachment(string: application.debugDescription)
    hierarchy.name = "Archived List native creation actions hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    for identifier in ["saved.list.createItem", "saved.list.add", "saved.list.capture"] {
      let action = application.plannerElement(identifier)
      XCTAssertTrue(action.waitForExistence(timeout: 5))
      XCTAssertFalse(action.isEnabled)
    }
  }

  private func openListArchiveFilter(_ application: XCUIApplication) {
    var filter = application.plannerElement("saved.lists.archive")
    #if os(iOS)
      if !filter.exists || !filter.isHittable {
        let overflow = application.navigationBars["Planner"].buttons["OverflowBarButtonItem"]
          .firstMatch
        XCTAssertTrue(overflow.waitForPlannerHittability())
        overflow.activateForPlannerJourney()
        if !filter.exists {
          filter = application.collectionViews.buttons["Active"].firstMatch
        }
      }
    #endif
    XCTAssertTrue(filter.waitForExistence(timeout: 5))
    filter.activateForPlannerJourney()
  }

  private func openListCapture(_ application: XCUIApplication) {
    application.openSavedPlannerListAddMenu()
    let capture = application.plannerElement("saved.list.capture")
    XCTAssertTrue(capture.waitForExistence(timeout: 5))
    capture.activateForPlannerJourney()
  }

  private func openListActions(_ application: XCUIApplication) {
    let actions = application.buttons.matching(
      NSPredicate(format: "identifier == %@ OR label == %@", "saved.list.actions", "List actions")
    ).firstMatch
    if !actions.exists {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
    }
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
  }

  private func prepareCapture(
    _ title: String, inputText: String = "https://example.com/list-capture?keep=%41",
    application: XCUIApplication
  ) {
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    input.typeText(inputText)
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    let field = application.textFields["saved.capture.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    #if os(macOS)
      field.typeKey("a", modifierFlags: .command)
      field.typeText(title)
    #else
      let original = field.value as? String ?? ""
      field.typeText(
        String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count) + title)
    #endif
    XCTAssertEqual(field.value as? String, title)
    #if os(iOS)
      field.typeText("\n")
    #endif
  }

  private func expectDestination(_ name: String, selected: Bool, application: XCUIApplication) {
    let control = destination(name, application: application)
    reveal(control, application: application)
    XCTAssertTrue(control.waitForPlannerBooleanState(selected))
  }

  private func chooseDestination(_ name: String, selected: Bool, application: XCUIApplication) {
    let control = destination(name, application: application)
    reveal(control, application: application)
    setDestination(control, selected: selected)
  }

  private func destination(_ name: String, application: XCUIApplication) -> XCUIElement {
    #if os(macOS)
      return application.groups.containing(.staticText, identifier: name)
        .children(matching: .switch).matching(
          NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.list.")
        ).firstMatch
    #else
      return application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.capture.list.", name)
      ).firstMatch
    #endif
  }

  private func setDestination(_ element: XCUIElement, selected: Bool) {
    #if os(macOS)
      element.activateForPlannerJourney()
    #else
      element.switches.firstMatch.activateForPlannerJourney()
    #endif
    XCTAssertTrue(element.waitForPlannerBooleanState(selected))
  }

  private func reveal(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<5 {
      if isVisible(element, application: application) { return }
      #if os(macOS)
        let form = application.windows.firstMatch.sheets.scrollViews.firstMatch
        XCTAssertTrue(form.exists)
        form.scroll(byDeltaX: 0, deltaY: -350)
      #else
        let form = application.collectionViews.allElementsBoundByIndex.last
        XCTAssertNotNil(form)
        form?.swipeUp()
      #endif
    }
    XCTAssertTrue(
      isVisible(element, application: application), application.windows.firstMatch.debugDescription)
  }

  private func isVisible(_ element: XCUIElement, application: XCUIApplication) -> Bool {
    guard element.exists && element.isHittable else { return false }
    #if os(macOS)
      return true
    #else
      let keyboard = application.keyboards.firstMatch
      let bottom = keyboard.exists ? keyboard.frame.minY : application.windows.firstMatch.frame.maxY
      return element.frame.maxY < bottom - 10
    #endif
  }
}
