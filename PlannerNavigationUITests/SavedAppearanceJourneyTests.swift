import XCTest

@MainActor
final class SavedAppearanceJourneyTests: XCTestCase {
  func testRemovingAnUnselectedListItemFromItsRowMenuKeepsTheSharedItem() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(item.waitForPlannerHittability())
    #if os(macOS)
      item.rightClick()
    #else
      item.press(forDuration: 1)
    #endif
    let remove = application.plannerElement("Remove from List")
    XCTAssertTrue(remove.waitForExistence(timeout: 5))
    remove.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    XCTAssertFalse(application.progressIndicators["saved.list.progress"].exists)
    recordScreenshot(application, name: "Native row menu removes an unselected List membership")
    openSection("Items", application: application)
    revealSidebarIfNeeded(application, element: application.plannerElement("saved.item.new"))
    let retainedItem = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
    ).matching(
      NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Nezu Museum", "Nezu Museum")
    ).firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
  }

  func testRemovingASelectedListItemKeepsItsSourceAndOtherListStateWhileReAddStartsTodo() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let removedIdentifier = item.identifier
    let removedCompletion = application.buttons[
      removedIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    removedCompletion.activateForPlannerJourney()
    XCTAssertTrue(removedCompletion.waitForPlannerValue("Completed"))
    createList("Wishlist", application: application)
    addItem(application)
    let retainedIdentifier = item.identifier
    let retainedCompletion = application.buttons[
      retainedIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    retainedCompletion.activateForPlannerJourney()
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    openList("Tokyo Food", application: application)
    item.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 5))
    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    let remove = application.plannerElement("Remove from List")
    XCTAssertTrue(remove.waitForExistence(timeout: 5))
    remove.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["The Item remains available in Items."].exists)
    XCTAssertFalse(item.exists)
    XCTAssertFalse(application.progressIndicators["saved.list.progress"].exists)
    recordScreenshot(
      application, name: "Selected List item removed while shared source is retained")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let emptyList = application.savedPlannerListRow("Tokyo Food")
    revealSidebarIfNeeded(application, element: emptyList)
    emptyList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, retainedIdentifier)
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    viewGlobalItem(application)
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: emptyList)
    emptyList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    addItem(application)
    XCTAssertNotEqual(item.identifier, removedIdentifier)
    let replacementCompletion = application.buttons[
      item.identifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(replacementCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    recordScreenshot(
      application, name: "Ordinary List re-add starts Todo with the same shared Item")
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, retainedIdentifier)
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
  }

  func testArchivedItemWithoutAListCanBeFoundAndUnarchivedInTheItemsCatalog() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    let filters = application.plannerElement("saved.items.filters")
    revealSidebarIfNeeded(application, element: application.plannerElement("saved.item.new"))
    XCTAssertTrue(filters.waitForExistence(timeout: 5))
    XCTAssertEqual(filters.plannerControlTitle, "Active")
    filters.activateForPlannerJourney()
    application.plannerElement("Archived").activateForPlannerJourney()
    #if os(macOS)
      let archivedItem = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
      ).matching(
        NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Nezu Museum", "Nezu Museum")
      ).firstMatch
    #else
      let archivedItem = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
      ).matching(NSPredicate(format: "label CONTAINS %@", "Nezu Museum")).firstMatch
    #endif
    XCTAssertTrue(archivedItem.waitForExistence(timeout: 10))
    archivedItem.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Archived"].exists)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Unarchive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(application, name: "Unlisted archived Item restored through the Items catalog")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    revealSidebarIfNeeded(application, element: application.plannerElement("saved.item.new"))
    XCTAssertEqual(filters.plannerControlTitle, "Active")
    XCTAssertTrue(archivedItem.waitForExistence(timeout: 10))
    archivedItem.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
  }

  func testSavedListFiltersIncludeArchivedItemsAndKeepFullProgressWithNoMatches() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let completion = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.completion.")
    ).firstMatch
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    viewGlobalItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    openList("Tokyo Food", application: application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = item.identifier
    let filters = application.plannerElement("saved.list.filters")
    XCTAssertTrue(filters.waitForExistence(timeout: 5))
    XCTAssertEqual(filters.plannerControlTitle, "All")
    assertProgress(1, application: application)
    item.activateForPlannerJourney()
    let keepsSimultaneousDetail = filters.isHittable
    if !keepsSimultaneousDetail {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }

    filters.activateForPlannerJourney()
    application.plannerElement("Active").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    XCTAssertTrue(application.staticTexts["1 of 1 item done"].exists)
    XCTAssertTrue(application.staticTexts["Showing 0 of 1 item"].exists)
    assertProgress(1, application: application)
    if keepsSimultaneousDetail {
      XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
      XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    }
    filters.activateForPlannerJourney()
    application.plannerElement("Todo").activateForPlannerJourney()
    XCTAssertEqual(filters.plannerControlTitle, "Todo · Active")
    filters.activateForPlannerJourney()
    application.plannerElement("Archived").activateForPlannerJourney()
    XCTAssertEqual(filters.plannerControlTitle, "Todo · Archived")
    XCTAssertFalse(item.exists)
    assertProgress(1, application: application)
    recordScreenshot(
      application, name: "Saved cumulative filters with full progress and no matches")

    filters.activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertEqual(item.identifier, membershipIdentifier)
    XCTAssertEqual(filters.plannerControlTitle, "Archived")
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    filters.activateForPlannerJourney()
    application.plannerElement("Done").activateForPlannerJourney()
    XCTAssertEqual(filters.plannerControlTitle, "Done · Archived")
    completion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    assertProgress(0, application: application)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].exists)
    filters.activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    filters.activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertEqual(item.identifier, membershipIdentifier)
    XCTAssertEqual(filters.plannerControlTitle, "All")
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    recordScreenshot(application, name: "Saved archived Item visible with All filters")
  }

  func testItemArchivePreservesItsSavedListReferenceAndLocalCompletion() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let completion = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.completion.")
    ).firstMatch
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)

    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Saved archived Item retains List progress")
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    viewGlobalItem(application)
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Unarchive Item").activateForPlannerJourney()
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(
      application.staticTexts["Archived"].waitForNonExistence(timeout: 10))
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
  }

  func testListCompletionStaysLocalWhileGlobalCompletionOverridesAndReopeningRestoresIt() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let completion = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.completion.")
    ).firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Completed"].exists)
    recordScreenshot(application, name: "Saved List with contextual completion and details")

    createList("Wishlist", application: application)
    addItem(application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertFalse(completion.isEnabled)
    XCTAssertTrue(completion.label.contains("Completed globally"))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Saved List with globally completed Item")

    viewGlobalItem(application)
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    XCTAssertTrue(completion.isEnabled)
    assertProgress(0, application: application)
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertTrue(completion.isEnabled)
    assertProgress(1, application: application)

    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
  }

  func testListSelectionShowsContextualDetailsAndExplicitGlobalItemNavigation() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)

    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10),
      application.debugDescription)
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.staticTexts["Local: Todo"].exists)
    XCTAssertFalse(application.staticTexts["Prototype identity inspection"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Saved List appearance details")

    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    application.plannerElement("View Item").activateForPlannerJourney()
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForExistence(timeout: 10))
    XCTAssertEqual(globalCompletion.plannerBooleanState, false)
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    XCTAssertFalse(application.staticTexts["In Tokyo Food"].exists)

    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
  }

  private func createItem(_ application: XCUIApplication) {
    openSection("Items", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Nezu Museum")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet at the garden entrance")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
  }

  private func createList(_ title: String, application: XCUIApplication) {
    openSection("Lists", application: application)
    let create = application.plannerElement("saved.list.new")
    revealSidebarIfNeeded(application, element: create)
    create.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText(title)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
  }

  private func addItem(_ application: XCUIApplication) {
    application.plannerElement("saved.list.add").activateForPlannerJourney()
    let candidate = application.staticTexts["Nezu Museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("saved.membership.add").waitForExistence(timeout: 2))
    XCTAssertTrue(
      application.savedPlannerItemRows("Nezu Museum").firstMatch.waitForExistence(timeout: 10))
  }

  private func openList(_ title: String, application: XCUIApplication) {
    openSection("Lists", application: application)
    let list = application.savedPlannerListRow(title)
    revealSidebarIfNeeded(application, element: list)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    list.activateForPlannerJourney()
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertTrue(item.waitForPlannerHittability())
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

  private func viewGlobalItem(_ application: XCUIApplication) {
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(item.waitForPlannerHittability())
    item.activateForPlannerJourney()
    let actions = application.plannerElement("saved.appearance.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
    let viewItem = application.plannerElement("View Item")
    XCTAssertTrue(viewItem.waitForExistence(timeout: 5))
    viewItem.activateForPlannerJourney()
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

  private func assertProgress(_ expected: Double, application: XCUIApplication) {
    let progress = application.progressIndicators["saved.list.progress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    XCTAssertEqual(progress.plannerProgressFraction, expected)
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
