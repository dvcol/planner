import XCTest

@MainActor
final class SavedItemEstimateJourneyTests: XCTestCase {
  func testMaximumDurationFiltersItemsAndInboxInclusivelyWithoutChangingSavedEstimates() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    let filters = application.plannerElement("saved.items.filters")
    filters.activateForPlannerJourney()
    let maximumEnabled = application.descendants(matching: .any).matching(
      identifier: "saved.filters.duration.enabled"
    ).firstMatch
    if !maximumEnabled.waitForExistence(timeout: 5) {
      recordEstimateScreenshot(application, name: "Native Filters is missing maximum duration")
      XCTFail("Native Filters must expose the accepted maximum-duration constraint")
      return
    }
    application.plannerElement("saved.filters.done").activateForPlannerJourney()

    for (title, minutes) in [
      ("Museum 119", 119), ("Museum 120", 120), ("Museum 121", 121),
      ("Museum unknown", nil), ("Park 60", 60),
    ] as [(String, Int?)] {
      createDurationItem(title, minutes: minutes, application: application)
    }
    openItems(application)
    XCTAssertTrue(
      application.savedPlannerItemRows("Park 60").firstMatch.waitForExistence(timeout: 10))
    let originalIdentifiers = [
      "Museum 119", "Museum 120", "Museum 121", "Museum unknown", "Park 60",
    ]
    .map { application.savedPlannerItemRows($0).firstMatch.identifier }
    XCTAssertEqual(Set(originalIdentifiers).count, 5)
    setTwoHourMaximum(filters, application: application)
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum 121").firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Museum unknown").firstMatch.exists)
    for title in ["Museum 119", "Museum 120", "Park 60"] {
      XCTAssertTrue(application.savedPlannerItemRows(title).firstMatch.exists)
    }
    recordEstimateScreenshot(
      application, name: "Inclusive two-hour maximum excludes long and unknown estimates")

    filters.activateForPlannerJourney()
    application.revealSavedPlannerFilter("saved.filters.duration.includeUnknown")
    let includeUnknown = application.descendants(matching: .any).matching(
      identifier: "saved.filters.duration.includeUnknown"
    ).firstMatch
    toggle(includeUnknown)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum unknown").firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Museum 121").firstMatch.exists)
    let search = application.searchFields.firstMatch
    #if os(iOS)
      if !search.exists { application.swipeDown() }
    #endif
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.activateForPlannerJourney()
    search.typeText("Museum")
    #if os(iOS)
      search.typeText("\n")
    #endif
    XCTAssertTrue(
      application.savedPlannerItemRows("Park 60").firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerItemRows("Museum 120").firstMatch.exists)
    XCTAssertTrue(application.savedPlannerItemRows("Museum unknown").firstMatch.exists)

    filters.activateForPlannerJourney()
    application.revealSavedPlannerFilter("saved.filters.duration.enabled")
    toggle(maximumEnabled)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum 121").firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Park 60").firstMatch.exists)
    XCTAssertEqual(search.value as? String, "Museum")
    XCTAssertEqual(filters.label, "Active")
    recordEstimateScreenshot(
      application, name: "Clearing only duration retains cumulative text search")

    application.openPlannerSection("Inbox")
    let inboxFilters = application.plannerElement("saved.inbox.filters")
    XCTAssertTrue(inboxFilters.waitForExistence(timeout: 5))
    setTwoHourMaximum(inboxFilters, application: application)
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum 120").firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Museum 121").firstMatch.exists)
    XCTAssertFalse(application.savedPlannerItemRows("Museum unknown").firstMatch.exists)
    inboxFilters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum unknown").firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(inboxFilters.label, "All")

    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    for (index, title) in ["Museum 119", "Museum 120", "Museum 121", "Museum unknown", "Park 60"]
      .enumerated()
    {
      let row = application.savedPlannerItemRows(title).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, originalIdentifiers[index])
    }
    application.savedPlannerItemRows("Museum 120").firstMatch.activateForPlannerJourney()
    let estimate = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    XCTAssertTrue(estimate.waitForPlannerValue("120 minutes"))
  }

  func testMaximumDurationPreservesListProgressOrderAndIndependentCompletionAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    for (title, minutes) in [("Museum 120", 120), ("Museum 121", 121), ("Museum unknown", nil)]
      as [(String, Int?)]
    {
      createDurationItem(title, minutes: minutes, application: application)
    }
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Duration plan")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for title in ["Museum 120", "Museum 121", "Museum unknown"] {
      application.openSavedPlannerListAddMenu()
      application.plannerElement("saved.list.add").activateForPlannerJourney()
      let candidate = application.staticTexts[title].firstMatch
      XCTAssertTrue(candidate.waitForExistence(timeout: 5))
      candidate.activateForPlannerJourney()
      application.plannerElement("saved.membership.add").activateForPlannerJourney()
      XCTAssertTrue(
        application.savedPlannerItemRows(title).firstMatch.waitForExistence(timeout: 10))
    }
    let titles = ["Museum 120", "Museum 121", "Museum unknown"]
    let originalIdentifiers = titles.map {
      application.savedPlannerItemRows($0).firstMatch.identifier
    }
    assertDurationListOrder(originalIdentifiers, application: application)
    let completion = application.plannerElement(
      originalIdentifiers[0].replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    let filters = application.plannerElement("saved.list.filters")
    setTwoHourMaximum(filters, application: application)
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum 121").firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Museum unknown").firstMatch.exists)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    let progress = application.progressIndicators["saved.list.progress"]
    XCTAssertEqual(progress.label, "1 of 3 items done")
    XCTAssertTrue(application.staticTexts["Showing 1 of 3 items"].exists)
    recordEstimateScreenshot(
      application, name: "Duration filters preserve full List progress and completed appearance")
    filters.activateForPlannerJourney()
    application.revealSavedPlannerFilter("saved.filters.duration.includeUnknown")
    toggle(
      application.descendants(matching: .any).matching(
        identifier: "saved.filters.duration.includeUnknown"
      ).firstMatch)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum unknown").firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Museum 121").firstMatch.exists)
    XCTAssertEqual(progress.label, "1 of 3 items done")
    filters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum 121").firstMatch.waitForExistence(timeout: 10))
    for (index, title) in titles.enumerated() {
      XCTAssertEqual(
        application.savedPlannerItemRows(title).firstMatch.identifier, originalIdentifiers[index])
    }
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertEqual(progress.label, "1 of 3 items done")
    assertDurationListOrder(originalIdentifiers, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let retainedList = application.savedPlannerListRow("Duration plan")
    if !retainedList.waitForExistence(timeout: 2) {
      application.plannerElement("Show Sidebar").activateForPlannerJourney()
    }
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    retainedList.activateForPlannerJourney()
    for (index, title) in titles.enumerated() {
      let row = application.savedPlannerItemRows(title).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, originalIdentifiers[index])
    }
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertEqual(progress.label, "1 of 3 items done")
    assertDurationListOrder(originalIdentifiers, application: application)
    recordEstimateScreenshot(
      application, name: "Unfiltered List retains contextual completion after relaunch")
  }

  private func assertDurationListOrder(_ identifiers: [String], application: XCUIApplication) {
    let rows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier IN %@", identifiers))
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), identifiers)
  }

  private func setTwoHourMaximum(_ filters: XCUIElement, application: XCUIApplication) {
    filters.activateForPlannerJourney()
    application.revealSavedPlannerFilter("saved.filters.duration.enabled")
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.filters.duration.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForPlannerBooleanState(false))
    toggle(enabled)
    application.revealSavedPlannerFilter("saved.filters.duration.quantity")
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.filters.duration.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("1"))
    increment(quantity)
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    recordEstimateScreenshot(
      application, name: "Native maximum-duration picker and explicit unknown choice")
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
  }

  private func createDurationItem(_ title: String, minutes: Int?, application: XCUIApplication) {
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let titleField = application.textFields["saved.item.title"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    titleField.activateForPlannerJourney()
    titleField.typeText(title)
    #if os(iOS)
      titleField.typeText("\n")
    #endif
    if let minutes {
      let enabled = application.descendants(matching: .any).matching(
        identifier: "saved.item.estimate.enabled"
      ).firstMatch
      XCTAssertTrue(enabled.waitForExistence(timeout: 5))
      toggle(enabled)
      let quantity = application.descendants(matching: .any).matching(
        identifier: "saved.item.estimate.quantity"
      ).firstMatch
      if minutes > 60 { increment(quantity) }
      chooseUnit("Minutes", application: application, prefix: "saved.item.estimate")
      if minutes == 121 { increment(quantity) }
      if minutes == 119 {
        let decrement = quantity.buttons.matching(
          NSPredicate(format: "identifier ENDSWITH %@", "-Decrement")
        ).firstMatch
        XCTAssertTrue(decrement.waitForExistence(timeout: 5))
        decrement.activateForPlannerJourney()
      }
      XCTAssertTrue(quantity.waitForPlannerValue(String(minutes)))
    }
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
  }

  func testEstimateShortcutsStageExactDurationsAndRetainOnlySavedChangesAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Shortcut estimate")
    #if os(iOS)
      title.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
    #endif
    XCTAssertTrue(title.waitForPlannerValue("Shortcut estimate"))
    chooseShortcut("Half-day (12 hours)", prefix: "saved.item.estimate", application: application)
    assertEstimateQuantity(
      "12", unit: "Hours", prefix: "saved.item.estimate", application: application)
    recordEstimateScreenshot(application, name: "Native Half-day shortcut stages twelve hours")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let summary = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    XCTAssertTrue(summary.waitForPlannerValue("720 minutes"))

    openEditor(application)
    chooseShortcut("Full-day (24 hours)", application: application)
    assertEstimateQuantity("1", unit: "Days", application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("720 minutes"))

    for (shortcut, quantity, minutes) in [
      ("Full-day (24 hours)", "1", "1[\\s,]?440 minutes"),
      ("Weekend (48 hours)", "2", "2[\\s,]?880 minutes"),
    ] {
      openEditor(application)
      chooseShortcut(shortcut, application: application)
      assertEstimateQuantity(quantity, unit: "Days", application: application)
      application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
      XCTAssertTrue(waitForEstimateValue(summary, matching: minutes))
    }
    recordEstimateScreenshot(application, name: "Saved Weekend estimate is forty-eight hours")
    openItems(application)
    let source = application.savedPlannerItemRows("Shortcut estimate")
    XCTAssertTrue(source.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(source.count, 1)
    let sourceIdentifier = source.firstMatch.identifier
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    XCTAssertTrue(source.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(source.count, 1)
    XCTAssertEqual(source.firstMatch.identifier, sourceIdentifier)
    source.firstMatch.activateForPlannerJourney()
    XCTAssertTrue(waitForEstimateValue(summary, matching: "2[\\s,]?880 minutes"))
    openEditor(application)
    assertEstimateQuantity("2", unit: "Days", application: application)
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.item.edit.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForPlannerBooleanState(true))
    toggle(enabled)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    XCTAssertTrue(source.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(source.count, 1)
    XCTAssertEqual(source.firstMatch.identifier, sourceIdentifier)
    source.firstMatch.activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
    XCTAssertEqual(
      application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
      ).count, 0)
  }

  private func chooseShortcut(
    _ title: String, prefix: String = "saved.item.edit.estimate", application: XCUIApplication
  ) {
    let shortcuts = application.plannerElement(prefix + ".shortcuts")
    XCTAssertTrue(shortcuts.waitForPlannerHittability())
    shortcuts.activateForPlannerJourney()
    let choice = application.plannerElement(title)
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
  }

  private func assertEstimateQuantity(
    _ quantity: String, unit: String, prefix: String = "saved.item.edit.estimate",
    application: XCUIApplication
  ) {
    let control = application.descendants(matching: .any).matching(
      identifier: prefix + ".quantity"
    ).firstMatch
    XCTAssertTrue(control.waitForPlannerValue(quantity))
    XCTAssertTrue(application.plannerElement(prefix + ".unit").label.contains(unit))
  }

  private func waitForEstimateValue(_ summary: XCUIElement, matching pattern: String) -> Bool {
    let predicate = NSPredicate(format: "value MATCHES %@", pattern)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: summary)], timeout: 5)
      == .completed
  }

  private func openEditor(_ application: XCUIApplication) {
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.item.edit.title"].waitForExistence(timeout: 5))
  }

  private func openItems(_ application: XCUIApplication) {
    #if os(macOS)
      let items = application.plannerElement("saved.section.items")
      XCTAssertTrue(items.waitForExistence(timeout: 5))
      items.activateForPlannerJourney()
    #else
      application.openPlannerSection("Items")
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists && back.isHittable { back.activateForPlannerJourney() }
    #endif
  }

  private func recordEstimateScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testYearEstimateShowsTwelveMonthsFiveDaysAndClearsOnlyAfterSave() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Year estimate")
    let enabled = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.enabled"
    ).firstMatch
    XCTAssertTrue(enabled.waitForExistence(timeout: 5))
    toggle(enabled)
    chooseUnit("Years", application: application, prefix: "saved.item.estimate")
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("0"))
    increment(quantity)
    let hourRemainder = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.remainder.hour"
    ).firstMatch
    XCTAssertTrue(hourRemainder.waitForPlannerValue("1"))
    let decrement = hourRemainder.buttons.matching(
      NSPredicate(format: "identifier ENDSWITH %@", "-Decrement")
    ).firstMatch
    XCTAssertTrue(decrement.waitForExistence(timeout: 5))
    decrement.activateForPlannerJourney()
    chooseUnit("Months", application: application, prefix: "saved.item.estimate")
    XCTAssertTrue(quantity.waitForPlannerValue("12"))
    let dayRemainder = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate.remainder.day"
    ).firstMatch
    XCTAssertTrue(dayRemainder.waitForPlannerValue("5"))
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "One year retains twelve months and five days"
    capture.lifetime = .keepAlways
    add(capture)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    let summary = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    XCTAssertTrue(waitForYearEstimate(summary), summary.debugDescription)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let row = application.savedPlannerItemRows("Year estimate").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertTrue((row.value as? String)?.contains("12 months · 5 days") == true)
    row.activateForPlannerJourney()
    XCTAssertTrue(waitForYearEstimate(summary))
    for shouldSave in [false, true] {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Edit item").activateForPlannerJourney()
      let unit = application.plannerElement("saved.item.edit.estimate.unit")
      XCTAssertTrue(unit.waitForExistence(timeout: 5))
      XCTAssertTrue(unit.label.contains("Months"))
      let enabled = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.enabled"
      ).firstMatch
      XCTAssertTrue(enabled.waitForPlannerBooleanState(true))
      toggle(enabled)
      let action = shouldSave ? "saved.item.edit.save" : "saved.item.edit.cancel"
      application.plannerElement(action).activateForPlannerJourney()
      if shouldSave {
        XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
      } else {
        XCTAssertTrue(waitForYearEstimate(summary))
      }
    }
    let schedules = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    XCTAssertEqual(schedules.count, 0)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(summary.waitForPlannerValue("No estimate"))
  }

  func testInlineEstimatePreservesRemainderThroughUnitChangesCancelSaveAndRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Estimated museum")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the booking notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    for shouldSave in [false, true] {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Edit item").activateForPlannerJourney()
      let enabled = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.enabled"
      ).firstMatch
      XCTAssertTrue(enabled.waitForExistence(timeout: 5), application.debugDescription)
      XCTAssertTrue(enabled.waitForPlannerBooleanState(false))
      toggle(enabled)
      let quantity = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.quantity"
      ).firstMatch
      XCTAssertTrue(quantity.waitForPlannerValue("1"), application.debugDescription)
      increment(quantity)
      XCTAssertTrue(quantity.waitForPlannerValue("2"))
      chooseUnit("Minutes", application: application)
      XCTAssertTrue(quantity.waitForPlannerValue("120"))
      for _ in 0..<5 { increment(quantity) }
      XCTAssertTrue(quantity.waitForPlannerValue("125"))
      chooseUnit("Hours", application: application)
      XCTAssertTrue(quantity.waitForPlannerValue("2"))
      let remainder = application.descendants(matching: .any).matching(
        identifier: "saved.item.edit.estimate.remainder.minute"
      ).firstMatch
      XCTAssertTrue(remainder.waitForPlannerValue("5"))
      let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
      capture.name = "Native inline estimate retains two hours and five minutes"
      capture.lifetime = .keepAlways
      add(capture)
      let action = shouldSave ? "saved.item.edit.save" : "saved.item.edit.cancel"
      application.plannerElement(action).activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
      let summary = application.descendants(matching: .any).matching(
        identifier: "saved.item.estimate"
      ).firstMatch
      XCTAssertTrue(summary.waitForPlannerValue(shouldSave ? "125 minutes" : "No estimate"))
      XCTAssertTrue(application.staticTexts["Keep the booking notes"].exists)
    }
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let row = application.savedPlannerItemRows("Estimated museum").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    let summary = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    XCTAssertTrue(summary.waitForPlannerValue("125 minutes"))
    XCTAssertTrue(application.staticTexts["Keep the booking notes"].exists)
  }

  private func chooseUnit(
    _ title: String, application: XCUIApplication, prefix: String = "saved.item.edit.estimate"
  ) {
    let unit = application.plannerElement(prefix + ".unit")
    XCTAssertTrue(unit.waitForExistence(timeout: 5))
    unit.activateForPlannerJourney()
    application.plannerElement(title).activateForPlannerJourney()
  }

  private func toggle(_ enabled: XCUIElement) {
    #if os(iOS)
      enabled.switches.firstMatch.activateForPlannerJourney()
    #else
      enabled.activateForPlannerJourney()
    #endif
  }

  private func increment(_ quantity: XCUIElement) {
    let button = quantity.buttons.matching(
      NSPredicate(format: "identifier ENDSWITH %@", "-Increment")
    ).firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 5), quantity.debugDescription)
    button.activateForPlannerJourney()
  }

  private func waitForYearEstimate(_ summary: XCUIElement) -> Bool {
    let predicate = NSPredicate(format: "value MATCHES %@", "525\\D?600 minutes")
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: summary)], timeout: 5)
      == .completed
  }
}
