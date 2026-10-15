import XCTest

@MainActor
final class DeletionEmptyResultsJourneyTests: XCTestCase {
  func testDeletingTheLastVisibleItemKeepsTheEmptyCatalogWithoutSelectingAnArchivedItem() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "deletion-empty-results", "--fixture-dataset", UUID().uuidString,
    ]
    launch(application)
    application.openPlannerSection("Items")
    let visible = application.savedPlannerItemRows("Visible Item").firstMatch
    let hidden = application.savedPlannerItemRows("Hidden Item").firstMatch
    let filters = application.plannerElement("saved.items.filters")
    XCTAssertTrue(visible.waitForExistence(timeout: 20))
    XCTAssertFalse(hidden.exists)
    application.chooseSavedPlannerStateFilter("All archive states", control: filters)
    XCTAssertTrue(hidden.waitForExistence(timeout: 10))
    let hiddenIdentifier = hidden.identifier
    application.chooseSavedPlannerStateFilter("Active", control: filters)
    XCTAssertTrue(hidden.waitForNonExistence(timeout: 10))
    visible.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Visible saved notes"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    application.plannerElement("saved.item.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.item.delete.confirm").waitForNonExistence(timeout: 10))
    XCTAssertTrue(visible.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertFalse(hidden.exists)
    XCTAssertFalse(application.staticTexts["Hidden saved notes"].exists)
    XCTAssertFalse(application.plannerElement("saved.item.completion").exists)
    XCTAssertFalse(application.staticTexts["Item unavailable"].exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    capture(application, name: "Deleting the last visible Item leaves its filtered catalog empty")
    application.chooseSavedPlannerStateFilter("All archive states", control: filters)
    XCTAssertTrue(hidden.waitForExistence(timeout: 10))
    XCTAssertEqual(hidden.identifier, hiddenIdentifier)
    XCTAssertFalse(application.staticTexts["Hidden saved notes"].exists)
    XCTAssertFalse(application.plannerElement("saved.item.completion").exists)
    hidden.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Hidden saved notes"].waitForExistence(timeout: 10))
    application.terminate()
    launch(application)
    application.openPlannerSection("Items")
    application.chooseSavedPlannerStateFilter("All archive states", control: filters)
    XCTAssertTrue(hidden.waitForExistence(timeout: 10))
    XCTAssertEqual(hidden.identifier, hiddenIdentifier)
    XCTAssertFalse(visible.exists)
    hidden.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Hidden saved notes"].waitForExistence(timeout: 10))
    capture(application, name: "Archived Item remains available with its identity after relaunch")
  }

  func testDeletingTheLastVisibleListRetainsArchivedListsAndItsSourceItem() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "deletion-empty-results", "--fixture-dataset", UUID().uuidString,
    ]
    launch(application)
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Visible Item").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 20))
    let sourceIdentifier = source.identifier
    application.openPlannerSection("Lists")
    let visible = listRow("Visible List", application: application)
    let hidden = listRow("Hidden List", application: application)
    let archive = application.plannerElement("saved.lists.archive")
    XCTAssertTrue(visible.waitForExistence(timeout: 20))
    XCTAssertFalse(hidden.exists)
    chooseListArchive("All Lists", control: archive, application: application)
    XCTAssertTrue(hidden.waitForExistence(timeout: 10))
    let hiddenIdentifier = hidden.identifier
    hidden.activateForPlannerJourney()
    let hiddenItem = application.savedPlannerItemRows("Hidden Item").firstMatch
    application.chooseSavedPlannerStateFilter(
      "All archive states", control: application.plannerElement("saved.list.filters"))
    XCTAssertTrue(hiddenItem.waitForExistence(timeout: 10))
    let hiddenMembershipIdentifier = hiddenItem.identifier
    application.openPlannerSection("Lists")
    chooseListArchive("Active Lists", control: archive, application: application)
    XCTAssertTrue(hidden.waitForNonExistence(timeout: 10))
    visible.activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Visible Item").firstMatch.waitForExistence(timeout: 10))
    application.openSavedPlannerListActionsMenu()
    application.plannerElement("saved.list.delete").activateForPlannerJourney()
    application.plannerElement("saved.list.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.list.delete.confirm").waitForNonExistence(timeout: 10))
    XCTAssertTrue(visible.waitForNonExistence(timeout: 10))
    requireNoSelectedList(application)
    application.openPlannerSection("Lists")
    XCTAssertTrue(application.staticTexts["No Lists yet"].waitForExistence(timeout: 10))
    XCTAssertFalse(hidden.exists)
    XCTAssertFalse(hiddenItem.exists)
    XCTAssertFalse(application.plannerElement("saved.appearance.actions").exists)
    XCTAssertFalse(application.staticTexts["List unavailable"].exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    requireNoSelectedList(application)
    capture(application, name: "Deleting the last visible List leaves its active catalog empty")
    chooseListArchive("All Lists", control: archive, application: application)
    XCTAssertTrue(hidden.waitForExistence(timeout: 10))
    XCTAssertEqual(hidden.identifier, hiddenIdentifier)
    XCTAssertFalse(hiddenItem.exists)
    requireNoSelectedList(application)
    hidden.activateForPlannerJourney()
    application.chooseSavedPlannerStateFilter(
      "All archive states", control: application.plannerElement("saved.list.filters"))
    XCTAssertTrue(hiddenItem.waitForExistence(timeout: 10))
    XCTAssertEqual(hiddenItem.identifier, hiddenMembershipIdentifier)
    application.terminate()
    launch(application)
    application.openPlannerSection("Lists")
    chooseListArchive("All Lists", control: archive, application: application)
    XCTAssertTrue(hidden.waitForExistence(timeout: 10))
    XCTAssertEqual(hidden.identifier, hiddenIdentifier)
    XCTAssertFalse(visible.exists)
    hidden.activateForPlannerJourney()
    application.chooseSavedPlannerStateFilter(
      "All archive states", control: application.plannerElement("saved.list.filters"))
    XCTAssertTrue(hiddenItem.waitForExistence(timeout: 10))
    XCTAssertEqual(hiddenItem.identifier, hiddenMembershipIdentifier)
    capture(
      application, name: "Archived List and membership retain their identities after relaunch")
    application.openPlannerSection("Items")
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertEqual(source.identifier, sourceIdentifier)
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Visible saved notes"].waitForExistence(timeout: 10))
  }

  private func requireNoSelectedList(_ application: XCUIApplication) {
    XCTAssertTrue(
      application.plannerElement("saved.list.actions").waitForNonExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.list.addMenu").exists)
    XCTAssertFalse(application.staticTexts["Opening List"].exists)
    #if os(iOS)
      if application.windows.firstMatch.frame.width < 600 {
        XCTAssertFalse(application.navigationBars["Hidden List"].exists)
        return
      }
    #endif
    XCTAssertTrue(application.staticTexts["List deleted"].firstMatch.waitForExistence(timeout: 10))
  }

  private func listRow(_ title: String, application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.list.", title)
    ).firstMatch
  }

  private func chooseListArchive(
    _ title: String, control: XCUIElement, application: XCUIApplication
  ) {
    var menu = control
    #if os(iOS)
      if !menu.exists || !menu.isHittable {
        let overflow = application.navigationBars["Planner"].buttons["OverflowBarButtonItem"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        overflow.activateForPlannerJourney()
        if !menu.exists {
          menu =
            application.collectionViews.buttons.matching(
              NSPredicate(format: "label MATCHES %@", "^(Active|Archived|All)( Lists)?$")
            ).firstMatch
        }
      }
    #endif
    XCTAssertTrue(menu.waitForExistence(timeout: 5))
    menu.activateForPlannerJourney()
    application.plannerElement(title).activateForPlannerJourney()
  }

  private func launch(_ application: XCUIApplication) {
    application.launchSavedPlannerJourney()
    #if os(iOS)
      let itemsTab = application.buttons.matching(identifier: "square.stack").firstMatch
      XCTAssertTrue(itemsTab.waitForExistence(timeout: 20))
      XCTAssertTrue(itemsTab.waitForPlannerHittability())
    #endif
  }

  private func capture(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
