import XCTest

@MainActor
final class SavedListDeletionJourneyTests: XCTestCase {
  func
    testListDeletionReviewsRepeatedUsesAndRetainsItemsAndTheRemainingRouteAfterCancelAndRelaunch()
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let museumIdentifier = createItem("Museum", notes: "Museum booking", application: application)
    let parkIdentifier = createItem("Park", notes: "Park booking", application: application)
    let removedListIdentifier = createList("Wishlist", application: application)
    for title in ["Museum", "Park"] { addListItem(title, application: application) }
    let removedMembershipIdentifiers = ["Museum", "Park"].map {
      application.savedPlannerItemRows($0).firstMatch.identifier
    }
    let retainedListIdentifier = createList("Rain plan", application: application)
    addListItem("Museum", application: application)
    let retainedMembershipIdentifier = application.savedPlannerItemRows("Museum").firstMatch
      .identifier
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the route booking")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for entryTitle in ["Museum", "Wishlist", "Wishlist", "Rain plan"] {
      addItineraryEntry(entryTitle, application: application)
    }
    let rows = itineraryRows(application)
    XCTAssertEqual(rows.count, 6)
    let originalAppearanceIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    let retainedAppearanceIdentifiers = [
      originalAppearanceIdentifiers[0], originalAppearanceIdentifiers[5],
    ]
    for identifier in originalAppearanceIdentifiers.prefix(2) {
      application.plannerElement(
        identifier.replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
      ).activateForPlannerJourney()
    }
    XCTAssertTrue(application.staticTexts["2 of 6 items done"].waitForExistence(timeout: 10))
    application.savedPlannerItineraryActionsControl().activateForPlannerJourney()
    application.plannerElement("Schedule itinerary").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.schedule.save").waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let itinerarySchedule = scheduleRows(application, sourceKind: "itinerary").firstMatch
    XCTAssertTrue(itinerarySchedule.waitForExistence(timeout: 10))
    let itineraryScheduleIdentifier = itinerarySchedule.identifier
    let itineraryScheduleDescription = itinerarySchedule.value as? String
    XCTAssertFalse(itineraryScheduleDescription?.isEmpty ?? true)
    openItem(museumIdentifier, application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.schedule.save").waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let itemSchedule = scheduleRows(application).firstMatch
    XCTAssertTrue(itemSchedule.waitForExistence(timeout: 10))
    let itemScheduleIdentifier = itemSchedule.identifier
    let itemScheduleDescription = itemSchedule.value as? String
    XCTAssertFalse(itemScheduleDescription?.isEmpty ?? true)
    openList(removedListIdentifier, application: application)
    XCTAssertTrue(
      application.staticTexts["0 of 2 items done"].firstMatch.waitForExistence(timeout: 10))
    openListActions(application)
    let deletion = application.plannerElement("saved.list.delete")
    XCTAssertTrue(deletion.waitForExistence(timeout: 5))
    deletion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["5 saved references"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Wishlist"].firstMatch.exists)
    recordScreenshot(
      application, name: "List Delete reviews repeated references and retains source Items")
    application.plannerElement("saved.list.delete.cancel").activateForPlannerJourney()
    for identifier in removedMembershipIdentifiers {
      XCTAssertTrue(application.plannerElement(identifier).waitForExistence(timeout: 10))
    }
    XCTAssertTrue(application.staticTexts["0 of 2 items done"].firstMatch.exists)
    openItinerary(application)
    XCTAssertEqual(
      readItineraryAppearanceIdentifiers(application, expectedCount: 6),
      originalAppearanceIdentifiers)
    XCTAssertTrue(application.staticTexts["2 of 6 items done"].exists)
    XCTAssertEqual(
      application.descendants(matching: .any).matching(identifier: itineraryScheduleIdentifier)
        .firstMatch.value as? String,
      itineraryScheduleDescription)
    openList(removedListIdentifier, application: application)
    openListActions(application)
    deletion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["5 saved references"].waitForExistence(timeout: 10))
    application.plannerElement("saved.list.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.list.delete.confirm").waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.alerts["Planner"].exists)
    XCTAssertFalse(application.plannerElement("saved.appearance.actions").exists)
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    XCTAssertTrue(
      application.plannerElement(removedListIdentifier).waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement(retainedListIdentifier).exists)
    recordScreenshot(application, name: "Confirmed List deletion clears the container selection")
    openItinerary(application)
    XCTAssertEqual(
      readItineraryAppearanceIdentifiers(application, expectedCount: 2),
      retainedAppearanceIdentifiers)
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Keep the route booking"].exists)
    XCTAssertEqual(
      application.descendants(matching: .any).matching(identifier: itineraryScheduleIdentifier)
        .firstMatch.value as? String,
      itineraryScheduleDescription)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(application)
    XCTAssertEqual(
      readItineraryAppearanceIdentifiers(application, expectedCount: 2),
      retainedAppearanceIdentifiers)
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].waitForExistence(timeout: 10))
    XCTAssertEqual(
      application.descendants(matching: .any).matching(identifier: itineraryScheduleIdentifier)
        .firstMatch.value as? String,
      itineraryScheduleDescription)
    recordScreenshot(
      application, name: "List deletion retains ordered route appearances after relaunch")
    openList(retainedListIdentifier, application: application)
    XCTAssertTrue(
      application.plannerElement(retainedMembershipIdentifier).waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].firstMatch.exists)
    openItem(museumIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
    XCTAssertEqual(
      application.descendants(matching: .any).matching(identifier: itemScheduleIdentifier)
        .firstMatch.value as? String,
      itemScheduleDescription)
    openItem(parkIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Park booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    XCTAssertFalse(application.plannerElement(removedListIdentifier).exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
  }

  func testEmptyListDeletionAndSelectedMembershipCleanupPreserveTheOriginalItem() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let itemIdentifier = createItem("Museum", notes: "Museum booking", application: application)
    let populatedListIdentifier = createList("Rain plan", application: application)
    addListItem("Museum", application: application)
    let membershipIdentifier = application.savedPlannerItemRows("Museum").firstMatch.identifier
    let emptyListIdentifier = createList("Empty plan", application: application)
    openListActions(application)
    XCTAssertFalse(application.plannerElement("Mark all done").isEnabled)
    XCTAssertFalse(application.plannerElement("Mark all undone").isEnabled)
    application.plannerElement("saved.list.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No saved references"].waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Empty List Delete reviews zero references")
    application.plannerElement("saved.list.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openList(emptyListIdentifier, application: application)
    openListActions(application)
    application.plannerElement("saved.list.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No saved references"].waitForExistence(timeout: 10))
    application.plannerElement("saved.list.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.list.delete.confirm").waitForNonExistence(timeout: 10))
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    XCTAssertFalse(application.plannerElement(emptyListIdentifier).exists)
    XCTAssertTrue(application.plannerElement(populatedListIdentifier).exists)
    openList(populatedListIdentifier, application: application)
    let membership = application.plannerElement(membershipIdentifier)
    XCTAssertTrue(membership.waitForExistence(timeout: 10))
    membership.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement("saved.appearance.actions").exists)
    #if os(iOS)
      if !application.plannerElement("saved.list.actions").exists {
        let back = application.navigationBars.buttons["Rain plan"].firstMatch
        if back.exists {
          back.activateForPlannerJourney()
        } else {
          let genericBack = application.plannerElement("BackButton")
          if genericBack.exists { genericBack.activateForPlannerJourney() }
        }
      }
    #endif
    openListActions(application)
    application.plannerElement("saved.list.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 saved reference"].waitForExistence(timeout: 10))
    application.plannerElement("saved.list.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.list.delete.confirm").waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement("saved.appearance.actions").exists)
    XCTAssertFalse(application.plannerElement(membershipIdentifier).exists)
    XCTAssertFalse(application.staticTexts["Museum booking"].exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    recordScreenshot(application, name: "Selected List deletion clears its child detail")
    application.terminate()
    application.launchSavedPlannerJourney()
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    XCTAssertFalse(application.plannerElement(emptyListIdentifier).exists)
    XCTAssertFalse(application.plannerElement(populatedListIdentifier).exists)
    XCTAssertTrue(application.staticTexts["No Lists yet"].waitForExistence(timeout: 10))
    openItem(itemIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
    XCTAssertFalse(application.alerts["Planner"].exists)
  }

  private func createList(_ name: String, application: XCUIApplication) -> String {
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    application.plannerElement("saved.list.new").activateForPlannerJourney()
    let nameField = application.textFields["saved.list.name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    nameField.activateForPlannerJourney()
    nameField.typeText(name)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    let list = application.savedPlannerListRow(name)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    let identifier = list.identifier
    list.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    return identifier
  }

  private func openList(_ identifier: String, application: XCUIApplication) {
    openCatalog("Lists", creationIdentifier: "saved.list.new", application: application)
    let list = application.plannerElement(identifier)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    list.activateForPlannerJourney()
    let toolbar = application.buttons.matching(
      NSPredicate(format: "identifier IN %@", ["saved.list.actions", "OverflowBarButtonItem"]))
    XCTAssertTrue(toolbar.firstMatch.waitForExistence(timeout: 10))
  }

  private func openListActions(_ application: XCUIApplication) {
    let actions = application.buttons.matching(
      NSPredicate(format: "identifier == %@ OR label == %@", "saved.list.actions", "List actions")
    )
    .firstMatch
    if !actions.exists {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
    }
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
  }

  private func createItem(_ title: String, notes: String, application: XCUIApplication) -> String {
    openCatalog("Items", creationIdentifier: "saved.item.addMenu", application: application)
    application.openSavedPlannerNewItemEditor()
    let titleField = application.textFields["saved.item.title"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    titleField.activateForPlannerJourney()
    titleField.typeText(title)
    let notesField = application.textFields["saved.item.notes"]
    notesField.activateForPlannerJourney()
    notesField.typeText(notes)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    openCatalog("Items", creationIdentifier: "saved.item.addMenu", application: application)
    let row = application.savedPlannerItemRows(title).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    return row.identifier
  }

  private func openItem(_ identifier: String, application: XCUIApplication) {
    openCatalog("Items", creationIdentifier: "saved.item.addMenu", application: application)
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
    application.openSavedPlannerListAddMenu()
    let add = application.plannerElement("saved.list.add")
    if add.exists {
      add.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
      application.plannerElement("Add existing item").activateForPlannerJourney()
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

  private func readItineraryAppearanceIdentifiers(
    _ application: XCUIApplication, expectedCount: Int
  ) -> [String] {
    #if os(macOS)
      let contents = application.tables.firstMatch
    #else
      let contents = application.collectionViews.firstMatch
    #endif
    var identifiers = [String]()
    var scrollCount = 0
    for _ in 0..<4 {
      for row in itineraryRows(application).allElementsBoundByIndex {
        let identifier = row.identifier
        if !identifiers.contains(identifier) { identifiers.append(identifier) }
      }
      if identifiers.count == expectedCount { break }
      XCTAssertTrue(contents.exists)
      contents.swipeUp()
      scrollCount += 1
    }
    for _ in 0..<scrollCount { contents.swipeDown() }
    return identifiers
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
