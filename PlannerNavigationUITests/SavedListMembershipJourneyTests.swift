import XCTest

@MainActor
final class SavedListMembershipJourneyTests: XCTestCase {
  func testExistingItemPickerExcludesArchivedSourcesAndReloadsAfterUnarchiving() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Nezu Museum")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the garden entrance notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Keep the garden entrance notes"].waitForExistence(timeout: 10))
    openSection("Items", application: application)
    let source = application.savedPlannerItemRows("Nezu Museum").firstMatch
    revealSidebarIfNeeded(application, element: source)
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    let sourceIdentifier = source.identifier
    source.activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))

    openSection("Lists", application: application)
    revealNewList(application).activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Garden visits")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.add").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Create an Item or unarchive one in Items, then add it to this List."]
        .waitForExistence(timeout: 10))
    let confirm = application.plannerElement("saved.membership.add")
    XCTAssertTrue(confirm.exists)
    XCTAssertFalse(confirm.isEnabled)
    XCTAssertFalse(application.staticTexts["Nezu Museum"].exists)
    recordScreenshot(application, name: "Archived source is absent from the loaded Item picker")
    application.plannerElement("saved.membership.cancel").activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)

    openSection("Items", application: application)
    let filters = application.plannerElement("saved.items.filters")
    revealSidebarIfNeeded(application, element: filters)
    XCTAssertTrue(filters.waitForExistence(timeout: 5))
    application.chooseSavedPlannerStateFilter("Archived", control: filters)
    let archivedSource = application.plannerElement(sourceIdentifier)
    XCTAssertTrue(archivedSource.waitForExistence(timeout: 10))
    archivedSource.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Unarchive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the garden entrance notes"].exists)

    openSection("Lists", application: application)
    let retainedList = application.savedPlannerListRow("Garden visits")
    revealSidebarIfNeeded(application, element: retainedList)
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    let listIdentifier = retainedList.identifier
    retainedList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.add").activateForPlannerJourney()
    let candidate = application.staticTexts["Nezu Museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 10))
    XCTAssertFalse(confirm.isEnabled)
    recordScreenshot(
      application, name: "Unarchived source becomes selectable in the reopened picker")
    candidate.activateForPlannerJourney()
    XCTAssertTrue(confirm.isEnabled)
    confirm.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForNonExistence(timeout: 10))
    let appearance = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    let appearanceIdentifier = appearance.identifier

    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: retainedList)
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedList.identifier, listIdentifier)
    retainedList.activateForPlannerJourney()
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertEqual(appearance.identifier, appearanceIdentifier)
    appearance.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Keep the garden entrance notes"].waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Unarchived source membership and notes survive relaunch")
    openSection("Items", application: application)
    revealSidebarIfNeeded(application, element: source)
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertEqual(source.identifier, sourceIdentifier)
    let identities = XCTAttachment(
      string:
        "Source: \(sourceIdentifier)\nList: \(listIdentifier)\nMembership: \(appearanceIdentifier)")
    identities.name = "Archive picker observed identities"
    identities.lifetime = .keepAlways
    add(identities)
  }

  func testExistingItemCanBeAddedToAListWithoutDuplicatingItsSourceAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
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
    openSection("Items", application: application)
    let source = application.savedPlannerItemRows("Nezu Museum").firstMatch
    revealSidebarIfNeeded(application, element: source)
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    let sourceIdentifier = source.identifier

    openSection("Lists", application: application)
    let newList = revealNewList(application)
    newList.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Tokyo Food")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))

    application.openSavedPlannerListAddMenu()
    let addItem = application.plannerElement("saved.list.add")
    XCTAssertTrue(addItem.waitForExistence(timeout: 5))
    addItem.activateForPlannerJourney()
    let candidate = application.staticTexts["Nezu Museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.cancel").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let retained = application.savedPlannerListRow("Tokyo Food")
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    addItem.activateForPlannerJourney()
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    let confirm = application.plannerElement("saved.membership.add")
    XCTAssertTrue(confirm.isEnabled)
    confirm.activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Nezu Museum").firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(confirm.exists)
    XCTAssertFalse(application.staticTexts["No items"].exists)
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    let appearanceIdentifier = application.savedPlannerItemRows("Nezu Museum").firstMatch.identifier

    application.openSavedPlannerListAddMenu()
    addItem.activateForPlannerJourney()
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    confirm.activateForPlannerJourney()
    XCTAssertFalse(confirm.waitForExistence(timeout: 2))
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertEqual(
      application.savedPlannerItemRows("Nezu Museum").firstMatch.identifier, appearanceIdentifier)

    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: retained)
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Nezu Museum").firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertEqual(
      application.savedPlannerItemRows("Nezu Museum").firstMatch.identifier, appearanceIdentifier)
    recordScreenshot(application, name: "Saved List with one shared Item after relaunch")
    openSection("Items", application: application)
    revealSidebarIfNeeded(application, element: source)
    XCTAssertTrue(
      application.savedPlannerItemRows("Nezu Museum").firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertEqual(source.identifier, sourceIdentifier)
    let identities = XCTAttachment(
      string: "Source: \(sourceIdentifier)\nMembership: \(appearanceIdentifier)")
    identities.name = "Existing Item picker observed identities"
    identities.lifetime = .keepAlways
    add(identities)
  }

  private func openSection(_ title: String, application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("saved.section.\(title.lowercased())")
      XCTAssertTrue(section.waitForExistence(timeout: 10))
      section.activateForPlannerJourney()
    #else
      application.openPlannerSection(title)
    #endif
  }

  private func revealNewList(_ application: XCUIApplication) -> XCUIElement {
    let newList = application.plannerElement("saved.list.new")
    if newList.waitForExistence(timeout: 3) { return newList }
    #if os(iOS)
      if let overflow = application.buttons.matching(identifier: "OverflowBarButtonItem")
        .allElementsBoundByIndex.first(where: \.isHittable)
      {
        overflow.activateForPlannerJourney()
        let menuAction = application.collectionViews.buttons["New List"].firstMatch
        XCTAssertTrue(menuAction.waitForExistence(timeout: 5))
        return menuAction
      }
    #endif
    revealSidebarIfNeeded(application, element: newList)
    XCTAssertTrue(newList.waitForExistence(timeout: 5))
    return newList
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
    XCTFail("Planner's native catalog navigation did not become available.")
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
