import XCTest

@MainActor
final class SavedItemDeletionJourneyTests: XCTestCase {
  func testItemDeletionReviewsSharedUsesAndPreservesTheRemainingRouteAfterCancelAndRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let removedItemIdentifier = createItem(
      "Museum", notes: "Museum booking", application: application)
    let retainedItemIdentifier = createItem("Park", notes: "Park booking", application: application)
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    application.plannerElement("saved.list.new").activateForPlannerJourney()
    let listName = application.textFields["saved.list.name"]
    XCTAssertTrue(listName.waitForExistence(timeout: 5))
    listName.activateForPlannerJourney()
    listName.typeText("Wishlist")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for title in ["Museum", "Park"] { addListItem(title, application: application) }
    let membershipIdentifier = application.savedPlannerItemRows("Park").firstMatch.identifier
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let itineraryTitle = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(itineraryTitle.waitForExistence(timeout: 5))
    itineraryTitle.activateForPlannerJourney()
    itineraryTitle.typeText("Weekend route")
    let itineraryNotes = application.textFields["saved.itinerary.notes"]
    itineraryNotes.activateForPlannerJourney()
    itineraryNotes.typeText("Keep the route booking")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for title in ["Museum", "Wishlist", "Museum"] {
      addItineraryEntry(title, application: application)
    }
    let rows = itineraryRows(application)
    XCTAssertEqual(rows.count, 4)
    let originalAppearanceIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    let parkAppearanceIdentifier = rows.matching(NSPredicate(format: "label == %@", "Park"))
      .firstMatch.identifier
    let parkIdentityComponents = parkAppearanceIdentifier.components(separatedBy: ".")
    XCTAssertEqual(parkIdentityComponents.count, 5)
    let listEntryIdentifier = "saved.itinerary.entry.\(parkIdentityComponents[3])"
    for identifier in Array(originalAppearanceIdentifiers.prefix(2)) {
      application.plannerElement(
        identifier.replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
      ).activateForPlannerJourney()
    }
    XCTAssertTrue(application.staticTexts["2 of 4 items done"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Itinerary").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.schedule.save").waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let itinerarySchedule = scheduleRows(application, sourceKind: "itinerary").firstMatch
    XCTAssertTrue(itinerarySchedule.waitForExistence(timeout: 10))
    let itineraryScheduleIdentifier = itinerarySchedule.identifier
    let itineraryScheduleDescription = itinerarySchedule.value as? String
    XCTAssertFalse(itineraryScheduleDescription?.isEmpty ?? true)
    openItem(removedItemIdentifier, application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.schedule.save").waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let itemSchedule = scheduleRows(application).firstMatch
    XCTAssertTrue(itemSchedule.waitForExistence(timeout: 10))
    let itemScheduleIdentifier = itemSchedule.identifier
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let deletion = application.plannerElement("saved.item.delete")
    XCTAssertTrue(deletion.waitForExistence(timeout: 5))
    deletion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["5 saved references"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Museum"].firstMatch.exists)
    recordScreenshot(
      application, name: "Item Delete reviews shared references and owned appointment")
    application.plannerElement("saved.item.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: itemScheduleIdentifier)
        .firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Museum booking"].exists)
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
    openItinerary(application)
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), originalAppearanceIdentifiers)
    XCTAssertTrue(application.staticTexts["2 of 4 items done"].exists)
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: itineraryScheduleIdentifier)
        .firstMatch.exists)
    openItem(removedItemIdentifier, application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    deletion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["5 saved references"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.item.delete.confirm").waitForNonExistence(timeout: 10))
    openCatalog("Items", creationIdentifier: "saved.item.new", application: application)
    XCTAssertTrue(
      application.plannerElement(removedItemIdentifier).waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement(retainedItemIdentifier).exists)
    recordScreenshot(application, name: "Confirmed Item deletion retains the other source")
    openItinerary(application)
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), [parkAppearanceIdentifier])
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: listEntryIdentifier).firstMatch
        .exists)
    XCTAssertTrue(
      application.staticTexts["0 of 1 item done"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Keep the route booking"].exists)
    XCTAssertEqual(
      application.descendants(matching: .any).matching(identifier: itineraryScheduleIdentifier)
        .firstMatch.value as? String,
      itineraryScheduleDescription)
    application.plannerElement(parkAppearanceIdentifier).activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Park booking"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement("saved.item.delete").exists)
    recordScreenshot(application, name: "Item deletion retains live List and Itinerary details")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), [parkAppearanceIdentifier])
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: listEntryIdentifier).firstMatch
        .exists)
    XCTAssertTrue(
      application.staticTexts["0 of 1 item done"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(
      application.descendants(matching: .any).matching(identifier: itineraryScheduleIdentifier)
        .firstMatch.value as? String,
      itineraryScheduleDescription)
    recordScreenshot(
      application, name: "Item deletion preserves the surviving route after relaunch")
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    let list = application.savedPlannerListRow("Wishlist")
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    list.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(membershipIdentifier).waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Museum").firstMatch.exists)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].firstMatch.exists)
    openItem(retainedItemIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Park booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
    XCTAssertTrue(scheduleRows(application).firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement(removedItemIdentifier).exists)
  }

  func testUnreferencedItemDeletionReviewsEmptyImpactAndKeepsTheOtherItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let removedItemIdentifier = createItem(
      "Museum", notes: "Museum booking", application: application)
    let retainedItemIdentifier = createItem("Park", notes: "Park booking", application: application)
    openItem(removedItemIdentifier, application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No saved references"].waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Unreferenced Item deletion reviews empty impact")
    application.plannerElement("saved.item.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    openItem(removedItemIdentifier, application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No saved references"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.item.delete.confirm").waitForNonExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openCatalog("Items", creationIdentifier: "saved.item.new", application: application)
    XCTAssertFalse(application.plannerElement(removedItemIdentifier).exists)
    XCTAssertTrue(application.plannerElement(retainedItemIdentifier).exists)
    openItem(retainedItemIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Park booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
  }

  func testDeletingTheOriginalItemFromAListAppearanceClearsTheRemovedSelectionAndKeepsTheList() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let itemIdentifier = createItem("Museum", notes: "Museum booking", application: application)
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    application.plannerElement("saved.list.new").activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Wishlist")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    addListItem("Museum", application: application)
    let appearance = application.savedPlannerItemRows("Museum").firstMatch
    let appearanceIdentifier = appearance.identifier
    appearance.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("saved.item.delete").exists)
    application.plannerElement("View Item").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 saved reference"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.item.delete.confirm").waitForNonExistence(timeout: 10))
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    let list = application.savedPlannerListRow("Wishlist")
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    let listIdentifier = list.identifier
    list.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement(appearanceIdentifier).exists)
    XCTAssertFalse(application.plannerElement("saved.appearance.actions").exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    recordScreenshot(application, name: "Item deletion clears the removed List appearance")
    application.terminate()
    application.launchSavedPlannerJourney()
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    XCTAssertTrue(application.plannerElement(listIdentifier).waitForExistence(timeout: 10))
    application.plannerElement(listIdentifier).activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement(appearanceIdentifier).exists)
    XCTAssertFalse(application.plannerElement("saved.appearance.actions").exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    openCatalog("Items", creationIdentifier: "saved.item.new", application: application)
    XCTAssertFalse(application.plannerElement(itemIdentifier).exists)
  }

  private func createItem(_ title: String, notes: String, application: XCUIApplication) -> String {
    openCatalog("Items", creationIdentifier: "saved.item.new", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let titleField = application.textFields["saved.item.title"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    titleField.activateForPlannerJourney()
    titleField.typeText(title)
    let notesField = application.textFields["saved.item.notes"]
    notesField.activateForPlannerJourney()
    notesField.typeText(notes)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    openCatalog("Items", creationIdentifier: "saved.item.new", application: application)
    let row = application.savedPlannerItemRows(title).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    return row.identifier
  }

  private func openItem(_ identifier: String, application: XCUIApplication) {
    openCatalog("Items", creationIdentifier: "saved.item.new", application: application)
    let row = application.plannerElement(identifier)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
  }

  private func openCatalog(
    _ section: String, creationIdentifier: String, application: XCUIApplication
  ) {
    #if os(macOS)
      let destination = application.plannerElement("saved.section.\(section.lowercased())")
    #else
      let destination = application.buttons[section].firstMatch
    #endif
    XCTAssertTrue(destination.waitForExistence(timeout: 10))
    destination.activateForPlannerJourney()
    let creation = application.plannerElement(creationIdentifier)
    if !creation.waitForExistence(timeout: 2) {
      let sidebar = application.plannerElement("Show Sidebar")
      let back = application.navigationBars.buttons[section].firstMatch
      if sidebar.exists {
        sidebar.activateForPlannerJourney()
      } else if back.exists {
        back.activateForPlannerJourney()
      } else {
        let genericBack = application.plannerElement("BackButton")
        XCTAssertTrue(genericBack.exists)
        genericBack.activateForPlannerJourney()
      }
    }
    XCTAssertTrue(creation.waitForExistence(timeout: 10))
  }

  private func openItinerary(_ application: XCUIApplication) {
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Weekend route")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.entry.new").waitForExistence(timeout: 10))
  }

  private func addListItem(_ title: String, application: XCUIApplication) {
    let add = application.plannerElement("saved.list.add")
    if add.exists {
      add.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
      application.plannerElement("Add existing Item").activateForPlannerJourney()
    }
    let candidate = application.staticTexts[title].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertTrue(application.savedPlannerItemRows(title).firstMatch.waitForExistence(timeout: 10))
  }

  private func addItineraryEntry(_ title: String, application: XCUIApplication) {
    application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
    let choice = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.entry.choice.", title)
    ).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
    application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.entry.new").waitForExistence(timeout: 10))
  }

  private func itineraryRows(_ application: XCUIApplication) -> XCUIElementQuery {
    application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
  }

  private func scheduleRows(_ application: XCUIApplication, sourceKind: String = "item")
    -> XCUIElementQuery
  {
    application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.\(sourceKind).schedule."))
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
