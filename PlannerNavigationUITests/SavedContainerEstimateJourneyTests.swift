import XCTest

@MainActor
final class SavedContainerEstimateJourneyTests: XCTestCase {
  func testListEstimateShortcutsStageCancelSaveAndResetAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    reveal("saved.list.new", application: application).activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Preset plan")
    #if os(iOS)
      name.typeText("\n")
    #endif
    XCTAssertTrue(name.waitForPlannerValue("Preset plan"))
    chooseShortcut("Half-day (12 hours)", application: application)
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("12"))
    XCTAssertTrue(application.plannerElement("saved.list.estimate.unit").label.contains("Hours"))
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    let full = estimate("full", application: application)
    XCTAssertTrue(full.waitForPlannerValue("720 minutes"))
    XCTAssertTrue(full.label.contains("Manual"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    openEditor(application)
    chooseShortcut("Full-day (24 hours)", application: application)
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    XCTAssertTrue(application.plannerElement("saved.list.estimate.unit").label.contains("Days"))
    application.plannerElement("saved.list.cancel").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("720 minutes"))
    openEditor(application)
    chooseShortcut("Weekend (48 hours)", application: application)
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    XCTAssertTrue(application.plannerElement("saved.list.estimate.unit").label.contains("Days"))
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    assertWeekendEstimate(full)
    recordScreenshot(application, name: "List Weekend shortcut saves a manual two-day estimate")
    let retained = revealCatalogRow(
      prefix: "saved.list.", title: "Preset plan", application: application)
    let identifier = retained.identifier
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, identifier)
    retained.activateForPlannerJourney()
    assertWeekendEstimate(full)
    openEditor(application)
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    XCTAssertTrue(application.plannerElement("saved.list.estimate.unit").label.contains("Days"))
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.list.estimate.enabled"
    ).firstMatch
    toggle(enabled)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertFalse(full.label.contains("Manual"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "List estimate shortcut clears back to calculation")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, identifier)
    retained.activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertFalse(full.label.contains("Manual"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
  }

  func testItineraryEstimateShortcutsStageCancelSaveAndResetAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    reveal("saved.itinerary.new", application: application).activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Preset itinerary")
    #if os(iOS)
      title.typeText("\n")
    #endif
    XCTAssertTrue(title.waitForPlannerValue("Preset itinerary"))
    chooseShortcut(
      "Half-day (12 hours)", accessibilityIdentifierPrefix: "saved.itinerary.estimate",
      application: application)
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.quantity"
    ).firstMatch
    let unit = application.plannerElement("saved.itinerary.estimate.unit")
    XCTAssertTrue(quantity.waitForPlannerValue("12"))
    XCTAssertTrue(unit.label.contains("Hours"))
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the meeting point")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let full = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.full"
    ).firstMatch
    let remaining = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.remaining"
    ).firstMatch
    XCTAssertTrue(full.waitForPlannerValue("720 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("720 minutes"))
    XCTAssertTrue(full.label.contains("Manual"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    let retained = revealCatalogRow(
      prefix: "saved.itinerary.", title: "Preset itinerary", application: application)
    let itineraryIdentifier = retained.identifier
    retained.activateForPlannerJourney()
    toolbarAction("saved.itinerary.edit", application: application).activateForPlannerJourney()
    chooseShortcut(
      "Full-day (24 hours)", accessibilityIdentifierPrefix: "saved.itinerary.estimate",
      application: application)
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    XCTAssertTrue(unit.label.contains("Days"))
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("720 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("720 minutes"))
    XCTAssertTrue(application.staticTexts["Keep the meeting point"].exists)
    toolbarAction("saved.itinerary.edit", application: application).activateForPlannerJourney()
    chooseShortcut(
      "Weekend (48 hours)", accessibilityIdentifierPrefix: "saved.itinerary.estimate",
      application: application)
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    XCTAssertTrue(unit.label.contains("Days"))
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    assertWeekendEstimate(full)
    assertWeekendEstimate(remaining)
    XCTAssertTrue(full.label.contains("Manual"))
    recordScreenshot(
      application, name: "Itinerary Weekend shortcut saves a manual two-day estimate")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, itineraryIdentifier)
    retained.activateForPlannerJourney()
    assertWeekendEstimate(full)
    assertWeekendEstimate(remaining)
    toolbarAction("saved.itinerary.edit", application: application).activateForPlannerJourney()
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    XCTAssertTrue(unit.label.contains("Days"))
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.estimate.enabled"
    ).firstMatch
    toggle(enabled)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("0 minutes"))
    XCTAssertFalse(full.label.contains("Manual"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    XCTAssertTrue(application.staticTexts["Keep the meeting point"].exists)
    recordScreenshot(application, name: "Itinerary shortcut resets to calculation and keeps notes")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(retained.identifier, itineraryIdentifier)
    retained.activateForPlannerJourney()
    XCTAssertTrue(full.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(remaining.waitForPlannerValue("0 minutes"))
    XCTAssertFalse(full.label.contains("Manual"))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    XCTAssertTrue(application.staticTexts["Keep the meeting point"].exists)
  }

  private func chooseShortcut(
    _ title: String, accessibilityIdentifierPrefix: String = "saved.list.estimate",
    application: XCUIApplication
  ) {
    let shortcuts = application.plannerElement(accessibilityIdentifierPrefix + ".shortcuts")
    XCTAssertTrue(shortcuts.waitForExistence(timeout: 5))
    shortcuts.activateForPlannerJourney()
    let shortcut = application.plannerElement(title)
    XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
    shortcut.activateForPlannerJourney()
  }

  private func assertWeekendEstimate(_ estimate: XCUIElement) {
    XCTAssertTrue(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value MATCHES %@", "2[\\s,]?880 minutes"),
            object: estimate)
        ], timeout: 5) == .completed)
  }

  func testRepeatedListPreviewsKeepIndependentItineraryBudgetsThroughHeaderFilteringAndRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem("Museum", includeEstimate: true, application: application)
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
    for _ in 0..<3 { increment(quantity) }
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    toolbarAction("saved.list.add", application: application).activateForPlannerJourney()
    let candidate = application.staticTexts["Museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    let completeStandalone = application.buttons["Mark Museum done in this List"].firstMatch
    XCTAssertTrue(completeStandalone.waitForExistence(timeout: 5))
    completeStandalone.activateForPlannerJourney()
    XCTAssertTrue(estimate("remaining", application: application).waitForPlannerValue("0 minutes"))
    let listCatalogRow = revealCatalogRow(
      prefix: "saved.list.", title: "Morning", application: application)
    XCTAssertTrue(
      listCatalogRow.waitForPlannerValue(
        "Active. Estimate, Manual, 240 minutes. Remaining, 0 minutes."))
    recordScreenshot(
      application, name: "List catalog shows manual full and completed remaining time")
    openSection("Itineraries", application: application)
    reveal("saved.itinerary.new", application: application).activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Repeated morning")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    for _ in 0..<2 {
      toolbarAction("saved.itinerary.entry.new", application: application)
        .activateForPlannerJourney()
      let choice = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.entry.choice.list.",
          "Morning")
      ).firstMatch
      XCTAssertTrue(choice.waitForExistence(timeout: 5))
      choice.activateForPlannerJourney()
      application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    }
    let remainingPreviews = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
        "saved.itinerary.entry.estimate.", ".remaining"))
    XCTAssertTrue(remainingPreviews.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(remainingPreviews.count, 2)
    let first = remainingPreviews.element(boundBy: 0)
    let second = remainingPreviews.element(boundBy: 1)
    XCTAssertTrue(first.waitForPlannerValue("240 minutes"))
    XCTAssertTrue(second.waitForPlannerValue("240 minutes"))
    let identities = remainingPreviews.allElementsBoundByIndex.map(\.identifier)
    let appearance = application.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.", "Museum")
    ).firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 5))
    let completionIdentifier = appearance.identifier.replacingOccurrences(
      of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    application.plannerElement(completionIdentifier).activateForPlannerJourney()
    XCTAssertTrue(first.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(second.waitForPlannerValue("240 minutes"))
    recordScreenshot(
      application, name: "Repeated List previews keep separate completion and budgets")
    let itineraryCatalogRow = revealCatalogRow(
      prefix: "saved.itinerary.row.", title: "Repeated morning", application: application)
    XCTAssertTrue(
      itineraryCatalogRow.waitForPlannerValue(
        "Estimate, 480 minutes. Remaining, 240 minutes."))
    recordScreenshot(
      application, name: "Itinerary catalog shows full and contextual remaining time")
    itineraryCatalogRow.activateForPlannerJourney()
    let search = application.searchFields.firstMatch
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.activateForPlannerJourney()
    search.typeText("Morning")
    XCTAssertTrue(
      application.staticTexts["No matching items"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(first.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(second.waitForPlannerValue("240 minutes"))
    recordScreenshot(
      application, name: "List header filtering preserves contextual estimate previews")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Itineraries", application: application)
    let retained = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.",
        "Repeated morning")
    ).firstMatch
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(first.waitForPlannerValue("0 minutes"))
    XCTAssertTrue(second.waitForPlannerValue("240 minutes"))
    XCTAssertEqual(remainingPreviews.allElementsBoundByIndex.map(\.identifier), identities)
    let retainedItineraryRow = revealCatalogRow(
      prefix: "saved.itinerary.row.", title: "Repeated morning", application: application)
    XCTAssertTrue(
      retainedItineraryRow.waitForPlannerValue(
        "Estimate, 480 minutes. Remaining, 240 minutes."))
  }

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
    let listCatalogRow = revealCatalogRow(
      prefix: "saved.list.", title: "Morning", application: application)
    XCTAssertTrue(
      listCatalogRow.waitForPlannerValue(
        "Active. Estimate, Manual, 240 minutes. Remaining, Up to 240 minutes; 1 finished estimate missing. Calculated, At least 120 minutes; 1 estimate missing."
      ))
    recordScreenshot(application, name: "List catalog warns that remaining time is an upper bound")
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
    let editedList = revealCatalogRow(
      prefix: "saved.list.", title: "Morning", application: application)
    editedList.activateForPlannerJourney()
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
      let section = application.plannerElement("saved.section." + title.lowercased())
      XCTAssertTrue(section.waitForExistence(timeout: 5))
      section.activateForPlannerJourney()
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
    if identifier == "saved.list.add" {
      application.openSavedPlannerListAddMenu()
      return application.plannerElement(identifier)
    }
    let title: String
    switch identifier {
    case "saved.list.add": title = "Add existing Item"
    case "saved.item.actions": title = "Item actions"
    case "saved.itinerary.edit": title = "Edit Itinerary"
    case "saved.itinerary.entry.new": title = "Add entry"
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
    application.openSavedPlannerListActionsMenu()
    let edit = application.plannerElement("saved.list.estimate.edit")
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

  private func revealCatalogRow(
    prefix: String, title: String, application: XCUIApplication
  ) -> XCUIElement {
    let row = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", prefix, title)
    ).firstMatch
    for _ in 0..<3 {
      if row.exists && row.isHittable { return row }
      if let back = application.buttons.matching(identifier: "BackButton").allElementsBoundByIndex
        .first(where: \.isHittable)
      {
        back.activateForPlannerJourney()
      } else if let sidebar = application.buttons.matching(identifier: "Show Sidebar")
        .allElementsBoundByIndex.first(where: \.isHittable)
      {
        sidebar.activateForPlannerJourney()
      } else {
        break
      }
    }
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertTrue(row.isHittable)
    return row
  }

  private func reveal(_ identifier: String, application: XCUIApplication) -> XCUIElement {
    var element = application.plannerElement(identifier)
    revealSidebarIfNeeded(application, element: element)
    #if os(iOS)
      if !element.waitForExistence(timeout: 2),
        let overflow = application.buttons.matching(identifier: "OverflowBarButtonItem")
          .allElementsBoundByIndex.first(where: \.isHittable)
      {
        overflow.activateForPlannerJourney()
        if !element.exists && identifier == "saved.list.new" {
          element = application.collectionViews.buttons["New List"].firstMatch
        }
      }
    #endif
    XCTAssertTrue(element.waitForExistence(timeout: 10))
    return element
  }

  private func revealSidebarIfNeeded(_ application: XCUIApplication, element: XCUIElement) {
    if element.waitForExistence(timeout: 3) { return }
    application.plannerElement("Show Sidebar").activateForPlannerJourney()
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
