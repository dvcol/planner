import XCTest

@MainActor
final class SavedItineraryFilterJourneyTests: XCTestCase {
  func testSearchKeepsMatchingHeadersOrChildrenAndPreservesFullRepeatedProgressAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createLabels(application)
    createItem("Zulu Hotel", application: application)
    createItem("Beta Museum", application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
    selectLabels(
      "categories", names: ["Culture"], prefix: "saved.item.edit", application: application)
    selectLabels("tags", names: ["Rain"], prefix: "saved.item.edit", application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Culture"].firstMatch.waitForExistence(timeout: 10))
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Food stops")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    let addItem = application.plannerElement("saved.list.add")
    if addItem.exists {
      addItem.activateForPlannerJourney()
    } else {
      application.buttons["OverflowBarButtonItem"].firstMatch.activateForPlannerJourney()
      application.plannerElement("Add existing item").activateForPlannerJourney()
    }
    let museum = application.staticTexts["Beta Museum"].firstMatch
    XCTAssertTrue(museum.waitForExistence(timeout: 5))
    museum.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Beta Museum").firstMatch.waitForExistence(timeout: 10))
    application.openPlannerSection("Itineraries")
    reveal("saved.itinerary.new", application: application).activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for source in ["Zulu Hotel", "Food stops", "Food stops"] {
      application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
      let choice = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.entry.choice.",
          source)
      ).firstMatch
      XCTAssertTrue(choice.waitForExistence(timeout: 5))
      choice.activateForPlannerJourney()
      application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.itinerary.entry.new").waitForExistence(timeout: 10))
    }
    let rows = itineraryRows(application)
    revealFixtureRows(3, application: application)
    XCTAssertEqual(rows.count, 3)
    let originalIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    let entries = originalIdentifiers.map { identifier in
      let suffix = identifier.replacingOccurrences(of: "saved.itinerary.appearance.", with: "")
      return application.descendants(matching: .any).matching(
        identifier: "saved.itinerary.entry." + String(suffix.split(separator: ".")[0])
      ).firstMatch
    }
    let firstCompletion = completion(originalIdentifiers[1], application: application)
    let secondCompletion = completion(originalIdentifiers[2], application: application)
    firstCompletion.activateForPlannerJourney()
    XCTAssertTrue(firstCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(secondCompletion.waitForPlannerValue("To do"))
    let search = application.searchFields["Search this Itinerary"]
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5), application.debugDescription)
    rows.element(boundBy: 1).activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Completed"].waitForExistence(timeout: 10),
      application.debugDescription)
    let keepsDetail = search.isHittable
    if !keepsDetail { application.plannerElement("BackButton").activateForPlannerJourney() }
    replaceText(search, with: "food stops", application: application)
    XCTAssertTrue(rows.firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertTrue(entries[0].waitForNonExistence(timeout: 5))
    XCTAssertTrue(entries[1].waitForExistence(timeout: 5), application.debugDescription)
    XCTAssertTrue(entries[2].exists)
    XCTAssertTrue(application.staticTexts["Matching 0 of 3 items"].exists)
    assertFullProgress(application)
    recordScreenshot(
      application, name: "Matching List headers and selected appearance after search")
    XCTAssertTrue(application.staticTexts["No matching items"].firstMatch.exists)
    if keepsDetail {
      XCTAssertTrue(application.staticTexts["Culture"].exists)
      XCTAssertTrue(application.staticTexts["Rain"].exists)
    }
    recordScreenshot(
      application, name: "Matching List headers retain full progress with no matching children")
    let filters = application.plannerElement("saved.itinerary.filters")
    XCTAssertTrue(filters.waitForExistence(timeout: 5))
    for restriction in [
      "saved.filters.hasAddress", "saved.filters.hasLinks", "saved.filters.duration.enabled",
    ] {
      filters.activateForPlannerJourney()
      application.revealSavedPlannerFilter(restriction)
      let toggle = application.descendants(matching: .any).matching(identifier: restriction)
        .firstMatch
      XCTAssertTrue(toggle.waitForExistence(timeout: 5))
      #if os(iOS)
        toggle.switches.firstMatch.activateForPlannerJourney()
      #else
        toggle.activateForPlannerJourney()
      #endif
      application.plannerElement("saved.filters.done").activateForPlannerJourney()
      XCTAssertTrue(entries[1].waitForNonExistence(timeout: 10))
      XCTAssertFalse(entries[2].exists)
      XCTAssertTrue(application.staticTexts["No matching entries"].exists)
      XCTAssertEqual(
        application.progressIndicators["saved.itinerary.progress"].label, "1 of 3 items done")
      recordScreenshot(
        application, name: "Item-only restrictions cannot retain a matching List header")
      filters.activateForPlannerJourney()
      application.plannerElement("saved.filters.clear").activateForPlannerJourney()
      application.plannerElement("saved.filters.done").activateForPlannerJourney()
      XCTAssertTrue(entries[1].waitForExistence(timeout: 10))
      XCTAssertTrue(entries[2].exists)
      XCTAssertEqual(filters.label, "All")
    }
    filters.activateForPlannerJourney()
    selectLabels("tags", names: ["Rain"], prefix: "saved.filters", application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(entries[1].waitForNonExistence(timeout: 10))
    XCTAssertFalse(entries[2].exists)
    filters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    application.chooseSavedPlannerStateFilter("Done", control: filters)
    XCTAssertTrue(entries[1].waitForExistence(timeout: 10))
    XCTAssertFalse(entries[2].exists)
    application.chooseSavedPlannerStateFilter("Todo", control: filters)
    XCTAssertTrue(entries[2].waitForExistence(timeout: 10))
    XCTAssertFalse(entries[1].exists)
    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    replaceText(search, with: "beta museum", application: application)
    let firstMatchingRow = application.buttons[originalIdentifiers[1]]
    if !firstMatchingRow.waitForExistence(timeout: 2) {
      entries[1].staticTexts["Food stops"].firstMatch.activateForPlannerJourney()
    }
    XCTAssertTrue(firstMatchingRow.waitForExistence(timeout: 10))
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
    revealFixtureRows(2, application: application)
    XCTAssertEqual(
      rows.allElementsBoundByIndex.map(\.identifier), Array(originalIdentifiers.dropFirst()))
    XCTAssertTrue(entries[0].waitForNonExistence(timeout: 5))
    XCTAssertTrue(entries[1].exists)
    XCTAssertTrue(entries[2].exists)
    XCTAssertTrue(application.staticTexts["Matching 2 of 3 items"].exists)
    assertFullProgress(application)
    recordScreenshot(
      application, name: "Matching children retain both independent List appearances")
    filters.activateForPlannerJourney()
    selectLabels(
      "categories", names: ["Culture"], prefix: "saved.filters", application: application)
    selectLabels(
      "tags", names: ["Rain", "Indoor"], prefix: "saved.filters", application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    revealFixtureRows(2, application: application)
    XCTAssertEqual(rows.count, 2)
    assertFullProgress(application)
    filters.activateForPlannerJourney()
    application.revealSavedPlannerFilter("saved.filters.tag.match")
    application.plannerElement("saved.filters.tag.match").activateForPlannerJourney()
    application.plannerElement("All selected").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(rows.firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertFalse(entries[1].exists)
    XCTAssertFalse(entries[2].exists)
    assertFullProgress(application)
    if keepsDetail {
      XCTAssertTrue(application.staticTexts["Culture"].exists)
      XCTAssertTrue(application.staticTexts["Rain"].exists)
    }
    recordScreenshot(
      application,
      name: "Cumulative label All hides rows without changing progress or valid details")
    filters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    replaceText(search, with: "nowhere", application: application)
    XCTAssertTrue(rows.firstMatch.waitForNonExistence(timeout: 10))
    for entry in entries { XCTAssertFalse(entry.exists) }
    XCTAssertTrue(application.staticTexts["No matching entries"].exists)
    assertFullProgress(application)
    replaceText(search, with: "", application: application)
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
    revealFixtureRows(3, application: application)
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), originalIdentifiers)
    XCTAssertTrue(firstCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(secondCompletion.waitForPlannerValue("To do"))
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Itineraries")
    let retained = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Weekend route")
    ).firstMatch
    if !retained.waitForExistence(timeout: 2) {
      application.plannerElement("Show Sidebar").activateForPlannerJourney()
    }
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
    revealFixtureRows(3, application: application)
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), originalIdentifiers)
    XCTAssertTrue(firstCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(secondCompletion.waitForPlannerValue("To do"))
    assertFullProgress(application)
  }

  private func createLabels(_ application: XCUIApplication) {
    application.openPlannerSection("Lists")
    let manage = application.plannerElement("saved.categories.manage")
    if !manage.waitForExistence(timeout: 2) || !manage.isHittable {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(manage.waitForExistence(timeout: 10))
    manage.activateForPlannerJourney()
    for (kind, name) in [("Category", "Culture"), ("Tag", "Rain"), ("Tag", "Indoor")] {
      application.plannerElement("saved.labels.new").activateForPlannerJourney()
      application.plannerElement("New \(kind.lowercased())").activateForPlannerJourney()
      let field = application.textFields["saved.\(kind.lowercased()).name"]
      XCTAssertTrue(field.waitForExistence(timeout: 5))
      field.activateForPlannerJourney()
      field.typeText(name)
      application.plannerElement("saved.\(kind.lowercased()).save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
  }

  private func assertFullProgress(
    _ application: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
  ) {
    let progress = application.progressIndicators["saved.itinerary.progress"]
    for _ in 0..<4 {
      if progress.exists { break }
      application.swipeDown()
    }
    XCTAssertTrue(progress.waitForExistence(timeout: 5), file: file, line: line)
    XCTAssertEqual(progress.label, "1 of 3 items done", file: file, line: line)
  }

  private func selectLabels(
    _ kind: String, names: [String], prefix: String, application: XCUIApplication
  ) {
    if prefix == "saved.filters" { application.revealSavedPlannerFilter(prefix + "." + kind) }
    application.plannerElement(prefix + "." + kind).activateForPlannerJourney()
    for name in names {
      let toggle = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.label.", name)
      ).firstMatch
      XCTAssertTrue(toggle.waitForExistence(timeout: 5))
      #if os(iOS)
        toggle.switches.firstMatch.activateForPlannerJourney()
      #else
        toggle.activateForPlannerJourney()
      #endif
      XCTAssertTrue(toggle.waitForPlannerBooleanState(true))
    }
    application.plannerElement("saved.item.labels.done").activateForPlannerJourney()
  }

  private func createItem(_ title: String, application: XCUIApplication) {
    application.openPlannerSection("Items")
    application.openSavedPlannerNewItemEditor()
    let field = application.textFields["saved.item.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(title)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
  }

  private func reveal(_ identifier: String, application: XCUIApplication) -> XCUIElement {
    let element = application.plannerElement(identifier)
    if !element.waitForExistence(timeout: 2) {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(element.waitForExistence(timeout: 10), application.debugDescription)
    return element
  }

  private func itineraryRows(_ application: XCUIApplication) -> XCUIElementQuery {
    application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
  }

  private func revealFixtureRows(_ expectedCount: Int, application: XCUIApplication) {
    let rows = itineraryRows(application)
    let container = application.descendants(matching: .any).matching(
      identifier: "saved.itinerary.contents"
    ).firstMatch
    for _ in 0..<3 {
      if rows.count == expectedCount { return }
      #if os(macOS)
        container.scroll(byDeltaX: 0, deltaY: -200)
      #else
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.1, thenDragTo: end)
      #endif
      let ready = XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in rows.count == expectedCount }, object: nil)
        ], timeout: 3)
      if ready == .completed { return }
    }
    recordScreenshot(application, name: "Itinerary filter fixture row availability")
    let hierarchy = XCTAttachment(string: application.debugDescription)
    hierarchy.name = "Itinerary filter fixture native hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    XCTAssertEqual(rows.count, expectedCount)
  }

  private func completion(_ rowIdentifier: String, application: XCUIApplication) -> XCUIElement {
    application.plannerElement(
      rowIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
  }

  private func replaceText(_ field: XCUIElement, with value: String, application: XCUIApplication) {
    field.activateForPlannerJourney()
    #if os(macOS)
      field.typeKey("a", modifierFlags: .command)
    #else
      let previous = field.value as? String ?? ""
      if !previous.isEmpty, previous != field.placeholderValue {
        field.press(forDuration: 1)
        let selectAll = application.descendants(matching: .any).matching(
          NSPredicate(format: "label == %@ OR identifier == %@", "Select All", "Select All")
        ).firstMatch
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
        selectAll.activateForPlannerJourney()
      }
    #endif
    field.typeText(value.isEmpty ? XCUIKeyboardKey.delete.rawValue : value)
    if !value.isEmpty { XCTAssertTrue(field.waitForPlannerValue(value)) }
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    let capture = XCTAttachment(screenshot: application.screenshot())
    capture.name = name
    capture.lifetime = .keepAlways
    add(capture)
  }
}
