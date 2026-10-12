import XCTest

@MainActor
final class SavedContainerEstimateJourneyTests: XCTestCase {
  func testMissingFinishedEstimateShowsUpperBoundThenResolvesAndFinishesWithoutClearingManualTotal()
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Museum", includeEstimate: true, application: application)
    createItem("Lunch", includeEstimate: false, application: application)
    openSection("Lists", application: application)
    reveal("saved.list.new", application: application).activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Morning")
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForExistence(timeout: 5))
    toggle(enabled)
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    for title in ["Museum", "Lunch"] {
      toolbarAction("saved.list.add", application: application).activateForPlannerJourney()
      let candidate = application.staticTexts[title].firstMatch
      XCTAssertTrue(candidate.waitForExistence(timeout: 5))
      candidate.activateForPlannerJourney()
      application.plannerElement("saved.membership.add").activateForPlannerJourney()
      XCTAssertTrue(
        application.savedPlannerItemRows(title).firstMatch.waitForExistence(timeout: 10))
    }
    let remaining = estimate("remaining", application: application)
    let full = estimate("full", application: application)
    let finishMuseum = application.buttons["Mark Museum done in this List"].firstMatch
    XCTAssertTrue(finishMuseum.waitForExistence(timeout: 5))
    finishMuseum.activateForPlannerJourney()
    XCTAssertTrue(remaining.waitForPlannerValue("0 minutes"))
    let exceeded = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.warning.exceeded"
    ).firstMatch
    XCTAssertTrue(exceeded.waitForExistence(timeout: 5))
    XCTAssertEqual(exceeded.label, "Finished estimates exceed the manual total")
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].exists)
    recordScreenshot(
      application, name: "Native zero remaining warns when the plan is still unfinished")
    openEditor(application)
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    for _ in 0..<3 { increment(quantity) }
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    let reopenMuseum = application.buttons["Mark Museum undone in this List"].firstMatch
    XCTAssertTrue(reopenMuseum.waitForExistence(timeout: 5))
    reopenMuseum.activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("240 minutes"))
    XCTAssertFalse(exceeded.exists)
    let finishLunch = application.buttons["Mark Lunch done in this List"].firstMatch
    XCTAssertTrue(finishLunch.waitForExistence(timeout: 5))
    finishLunch.activateForPlannerJourney()
    XCTAssertTrue(remaining.waitForPlannerValue("Up to 240 minutes; 1 finished estimate missing"))
    XCTAssertTrue(full.waitForPlannerValue("240 minutes"))
    let warning = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.warning.finished"
    ).firstMatch
    XCTAssertTrue(warning.waitForExistence(timeout: 5))
    XCTAssertTrue(warning.label.contains("1 finished estimate missing"))
    recordScreenshot(
      application, name: "Native remaining upper bound explains the missing finished estimate")
    openSection("Items", application: application)
    let lunch = application.savedPlannerItemRows("Lunch").firstMatch
    if lunch.exists { lunch.activateForPlannerJourney() }
    toolbarAction("saved.item.actions", application: application).activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    let itemEstimate = application.descendants(matching: .any).matching(
      identifier: "saved.item.edit.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(itemEstimate.waitForExistence(timeout: 5))
    toggle(itemEstimate)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    openSection("Lists", application: application)
    if !full.waitForExistence(timeout: 2) {
      let list = application.savedPlannerListRow("Morning")
      revealSidebarIfNeeded(application, element: list)
      XCTAssertTrue(list.waitForExistence(timeout: 5))
      list.activateForPlannerJourney()
    }
    XCTAssertTrue(remaining.waitForPlannerValue("180 minutes"))
    XCTAssertFalse(warning.exists)
    XCTAssertTrue(full.waitForPlannerValue("240 minutes"))
    XCTAssertTrue(finishMuseum.waitForExistence(timeout: 5))
    finishMuseum.activateForPlannerJourney()
    XCTAssertTrue(remaining.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(full.waitForPlannerValue("240 minutes"))
    XCTAssertTrue(full.label.contains("Manual"))
    recordScreenshot(
      application, name: "Native completed plan keeps the manual total and shows zero remaining")
  }

  func testItineraryManualEstimateSavesCancelsAndResetsWithoutChangingNotes() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    reveal("saved.itinerary.new", application: application).activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum day")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet at the museum")
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForExistence(timeout: 5))
    toggle(enabled)
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    for _ in 0..<3 { increment(quantity) }
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let full = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.full"
    ).firstMatch
    let remaining = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.remaining"
    ).firstMatch
    XCTAssertTrue(full.waitForPlannerValue("240 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("240 minutes"))
    XCTAssertTrue(full.label.contains("Manual"))
    toolbarAction("saved.itinerary.edit", application: application).activateForPlannerJourney()
    toggle(enabled)
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("240 minutes"))
    recordScreenshot(application, name: "Native Itinerary retains the manual total after cancel")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    let retained = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.", "Museum day")
    ).firstMatch
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    let identity = retained.identifier
    retained.activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("240 minutes"))
    toolbarAction("saved.itinerary.edit", application: application).activateForPlannerJourney()
    XCTAssertTrue(quantity.waitForPlannerValue("4"))
    toggle(enabled)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(application.staticTexts["Meet at the museum"].exists)
    XCTAssertFalse(full.label.contains("Manual"))
    recordScreenshot(application, name: "Native Itinerary resets to calculation and retains notes")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, identity)
    retained.activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(application.staticTexts["Meet at the museum"].exists)
  }

  func testListManualEstimateStagesExactRemainderCancelsAndResetsAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    reveal("saved.list.new", application: application).activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Morning")
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForExistence(timeout: 5))
    toggle(enabled)
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    increment(quantity)
    chooseUnit("Minutes", application: application)
    XCTAssertTrue(quantity.waitForPlannerValue("120"))
    for _ in 0..<5 { increment(quantity) }
    chooseUnit("Hours", application: application)
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    let remainder = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.remainder.minute"
    ).firstMatch
    XCTAssertTrue(remainder.waitForPlannerValue("5"))
    recordScreenshot(application, name: "Native List estimate keeps two hours and five minutes")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    let full = estimate("full", application: application)
    let remaining = estimate("remaining", application: application)
    XCTAssertTrue(full.waitForPlannerValue("125 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("125 minutes"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    XCTAssertTrue(full.label.contains("Manual"))
    openEditor(application)
    toggle(enabled)
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("125 minutes"))
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let retained = application.savedPlannerListRow("Morning")
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    let identity = retained.identifier
    retained.activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("125 minutes"))
    openEditor(application)
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    XCTAssertTrue(remainder.waitForPlannerValue("5"))
    toggle(enabled)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("0 minutes"))
    XCTAssertFalse(full.label.contains("Manual"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(
      application, name: "Native List resets to calculation without completing an empty plan")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, identity)
    retained.activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
  }

  private func openSection(_ title: String, application: XCUIApplication) {
    #if os(iOS)
      let identifier: String
      switch title {
      case "Lists": identifier = "list.bullet"
      case "Items": identifier = "square.stack"
      case "Itineraries": identifier = "point.topleft.down.to.point.bottomright.curvepath"
      default:
        XCTFail("Unknown Planner destination: " + title)
        return
      }
      let candidates = application.buttons.matching(identifier: identifier)
      XCTAssertTrue(candidates.firstMatch.waitForExistence(timeout: 5))
      guard let tab = candidates.allElementsBoundByIndex.first(where: \.isHittable) else {
        XCTFail("The native tab is not visible: " + title)
        return
      }
      tab.activateForPlannerJourney()
      let selected = NSPredicate(format: "selected == true")
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: selected, object: tab)], timeout: 5),
        .completed)
    #else
      application.openPlannerSection(title)
    #endif
  }

  private func estimate(_ metric: String, application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any).matching(identifier: "saved.list.estimate." + metric)
      .firstMatch
  }

  private func createItem(_ title: String, includeEstimate: Bool, application: XCUIApplication) {
    openSection("Items", application: application)
    reveal("saved.item.new", application: application).activateForPlannerJourney()
    let field = application.textFields["saved.item.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(title)
    if includeEstimate {
      let enabled = application.descendants(matching: .any).matching(
        identifier: "saved.item.estimate.enabled"
      ).firstMatch
      XCTAssertTrue(enabled.waitForExistence(timeout: 5))
      toggle(enabled)
      let quantity = application.descendants(matching: .any).matching(
        identifier: "saved.item.estimate.quantity"
      ).firstMatch
      XCTAssertTrue(quantity.waitForPlannerValue("1"))
      increment(quantity)
    }
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch.waitForExistence(timeout: 10))
  }

  private func toolbarAction(_ identifier: String, application: XCUIApplication) -> XCUIElement {
    let title: String
    switch identifier {
    case "saved.list.add": title = "Add existing Item"
    case "saved.item.actions": title = "Item actions"
    case "saved.itinerary.edit": title = "Edit Itinerary"
    default: title = identifier
    }
    let action = application.buttons.matching(
      NSPredicate(
        format: "identifier == %@ OR label == %@", identifier, title)
    ).firstMatch
    if !action.waitForExistence(timeout: 2) {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
    }
    XCTAssertTrue(action.waitForExistence(timeout: 5))
    return action
  }

  private func openEditor(_ application: XCUIApplication) {
    let actions = application.buttons.matching(
      NSPredicate(
        format: "identifier == %@ OR label == %@", "saved.list.actions", "List actions")
    ).firstMatch
    if !actions.waitForExistence(timeout: 2) {
      let overflow = application.plannerElement("More")
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
    }
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
    let edit = application.buttons.matching(
      NSPredicate(
        format: "identifier == %@ OR label == %@", "saved.list.estimate.edit", "Edit estimate")
    ).firstMatch
    XCTAssertTrue(edit.waitForExistence(timeout: 5))
    edit.activateForPlannerJourney()
  }

  private func chooseUnit(_ title: String, application: XCUIApplication) {
    application.plannerElement("saved.list.estimate.unit").activateForPlannerJourney()
    application.plannerElement(title).activateForPlannerJourney()
  }

  private func toggle(_ element: XCUIElement) {
    #if os(iOS)
      element.switches.firstMatch.activateForPlannerJourney()
    #else
      element.activateForPlannerJourney()
    #endif
  }

  private func increment(_ quantity: XCUIElement) {
    let button = quantity.buttons.matching(
      NSPredicate(format: "identifier ENDSWITH %@", "-Increment")
    ).firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    button.activateForPlannerJourney()
  }

  private func reveal(_ identifier: String, application: XCUIApplication) -> XCUIElement {
    let element = application.plannerElement(identifier)
    revealSidebarIfNeeded(application, element: element)
    XCTAssertTrue(element.waitForExistence(timeout: 10))
    return element
  }

  private func revealSidebarIfNeeded(_ application: XCUIApplication, element: XCUIElement) {
    if element.waitForExistence(timeout: 3) { return }
    application.plannerElement("Show Sidebar").activateForPlannerJourney()
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
