import XCTest

@MainActor
final class SavedLoadingJourneyTests: XCTestCase {
  func testFortyNativeItemsAndFourListsTraverseRefreshAndReopen() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let listTitles = (1...4).map { "Loading List \($0)" }
    for title in listTitles { createList(title, application: application) }
    openCatalog("Lists", application: application)
    let listIdentifiers = Dictionary(
      uniqueKeysWithValues: listTitles.map { title in
        let row = application.savedPlannerListRow(title)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        return (title, row.identifier)
      })
    let itemTitles = (1...40).map { String(format: "Loading Item %02d", $0) }
    for title in itemTitles { createItem(title, application: application) }
    openCatalog("Items", application: application)
    let catalog = itemCatalog(application)
    scrollToFirstItem(catalog, application: application)
    let forward = traverseItems(
      itemTitles, catalog: catalog, application: application, forward: true)
    capture(application, name: "Forty native Items traversed to the final row")
    let backward = traverseItems(
      Array(itemTitles.reversed()), catalog: catalog, application: application, forward: false)
    XCTAssertEqual(backward, forward)
    XCTAssertEqual(Set(forward.values).count, 40)
    for (index, title) in listTitles.enumerated() {
      openCatalog("Lists", application: application)
      application.savedPlannerListRow(title).activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      addFirstItem(itemTitles[index], application: application)
      let appearance = application.savedPlannerItemRows(itemTitles[index]).firstMatch
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      appearance.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts[itemTitles[index]].firstMatch.waitForExistence(timeout: 5))
    }
    openCatalog("Items", application: application)
    let filters = application.plannerElement("saved.items.filters")
    application.chooseSavedPlannerStateFilter("Todo", control: filters)
    let search = application.searchFields["Search Items"]
    if !search.exists { itemCatalog(application).swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.activateForPlannerJourney()
    search.typeText("Loading Item 40")
    let selectedRow = application.savedPlannerItemRows("Loading Item 40").firstMatch
    XCTAssertTrue(selectedRow.waitForExistence(timeout: 10))
    XCTAssertEqual(selectedRow.identifier, forward["Loading Item 40"])
    selectedRow.activateForPlannerJourney()
    let completion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    #if os(macOS)
      completion.activateForPlannerJourney()
    #else
      completion.switches.firstMatch.activateForPlannerJourney()
    #endif
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    XCTAssertTrue(application.staticTexts["Loading Item 40"].firstMatch.exists)
    capture(application, name: "Filtered-out Item keeps its valid completed detail selection")
    openCatalog("Items", application: application)
    XCTAssertTrue(selectedRow.waitForNonExistence(timeout: 10))
    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    XCTAssertTrue(selectedRow.waitForExistence(timeout: 10))
    XCTAssertEqual(selectedRow.identifier, forward["Loading Item 40"])
    application.terminate()
    application.launchSavedPlannerJourney()
    openCatalog("Lists", application: application)
    for (index, title) in listTitles.enumerated() {
      let listRow = application.savedPlannerListRow(title)
      XCTAssertTrue(listRow.waitForExistence(timeout: 10))
      XCTAssertEqual(listRow.identifier, listIdentifiers[title])
      listRow.activateForPlannerJourney()
      XCTAssertTrue(
        application.savedPlannerItemRows(itemTitles[index]).firstMatch.waitForExistence(timeout: 10)
      )
      openCatalog("Lists", application: application)
    }
    openCatalog("Items", application: application)
    let reopenedCatalog = itemCatalog(application)
    scrollToFirstItem(reopenedCatalog, application: application)
    let reopened = traverseItems(
      itemTitles, catalog: reopenedCatalog, application: application, forward: true)
    XCTAssertEqual(reopened, forward)
    selectedRow.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    capture(
      application, name: "Native dataset reopens all forty identities and the saved completion")
    let identities = XCTAttachment(
      string: forward.keys.sorted().map { "\($0): \(forward[$0]!)" }.joined(separator: "\n"))
    identities.name = "Forty traversed native source identities"
    identities.lifetime = .keepAlways
    add(identities)
  }

  private func createList(_ title: String, application: XCUIApplication) {
    openCatalog("Lists", application: application)
    application.plannerElement("saved.list.new").activateForPlannerJourney()
    let field = application.textFields["saved.list.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(title)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
  }

  private func createItem(_ title: String, application: XCUIApplication) {
    openCatalog("Items", application: application)
    application.openSavedPlannerNewItemEditor()
    let field = application.textFields["saved.item.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(title)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[title].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
  }

  private func addFirstItem(_ title: String, application: XCUIApplication) {
    application.openSavedPlannerListAddMenu()
    let addItem = application.plannerElement("saved.list.add")
    if addItem.waitForExistence(timeout: 5) {
      addItem.activateForPlannerJourney()
    } else {
      application.buttons["OverflowBarButtonItem"].firstMatch.activateForPlannerJourney()
      application.plannerElement("Add existing Item").activateForPlannerJourney()
    }
    let candidate = application.staticTexts[title].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.membership.add").waitForNonExistence(timeout: 10))
  }

  private func openCatalog(_ title: String, application: XCUIApplication) {
    application.openPlannerSection(title)
    #if os(iOS)
      let back = application.navigationBars.buttons[title].firstMatch
      if back.exists { back.activateForPlannerJourney() }
    #endif
    let newIdentifier = title == "Items" ? "saved.item.addMenu" : "saved.list.new"
    XCTAssertTrue(application.plannerElement(newIdentifier).waitForExistence(timeout: 10))
  }

  private func itemCatalog(_ application: XCUIApplication) -> XCUIElement {
    let rows = NSPredicate(
      format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "saved.item.", "Loading Item ")
    #if os(macOS)
      let catalog = application.tables.containing(rows).firstMatch
    #else
      let catalog = application.collectionViews.containing(rows).firstMatch
    #endif
    XCTAssertTrue(catalog.waitForExistence(timeout: 10))
    return catalog
  }

  private func scrollToFirstItem(_ catalog: XCUIElement, application: XCUIApplication) {
    let first = application.savedPlannerItemRows("Loading Item 01").firstMatch
    for _ in 0..<30 {
      if first.exists, first.isHittable, catalog.frame.contains(first.frame) { return }
      catalog.swipeDown()
    }
    XCTFail("The first of forty native Items did not become visible.")
  }

  private func traverseItems(
    _ expectedTitles: [String], catalog: XCUIElement, application: XCUIApplication, forward: Bool
  ) -> [String: String] {
    var identifiers: [String: String] = [:]
    var observedTitles: [String] = []
    for _ in 0..<30 {
      let visible = expectedTitles.compactMap { title -> XCUIElement? in
        let row = application.savedPlannerItemRows(title).firstMatch
        guard row.exists, row.isHittable, catalog.frame.contains(row.frame) else { return nil }
        return row
      }.sorted { forward ? $0.frame.minY < $1.frame.minY : $0.frame.minY > $1.frame.minY }
      XCTAssertFalse(visible.isEmpty)
      for row in visible {
        if let identifier = identifiers[row.label] {
          XCTAssertEqual(row.identifier, identifier)
        } else {
          identifiers[row.label] = row.identifier
          observedTitles.append(row.label)
        }
      }
      if identifiers.count == expectedTitles.count {
        XCTAssertEqual(observedTitles, expectedTitles)
        return identifiers
      }
      if forward { catalog.swipeUp() } else { catalog.swipeDown() }
    }
    XCTFail("Native traversal did not reach every expected Item: \(observedTitles)")
    return identifiers
  }

  private func capture(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
