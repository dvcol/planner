import XCTest

@MainActor
final class SavedItineraryDeletionJourneyTests: XCTestCase {
  func testCreatingASecondItineraryOpensItsOwnEmptyContents() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let originalIdentifier = createItinerary("Original plan", application: application)
    let newIdentifier = createItinerary("New plan", application: application)
    XCTAssertNotEqual(originalIdentifier, newIdentifier)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    XCTAssertTrue(application.plannerElement("saved.itinerary.actions").exists)
    recordScreenshot(application, name: "New itinerary opens independently of the prior selection")
  }

  func
    testItineraryDeletionReviewsRepeatedEntriesAndRetainsIndependentListsAndPlansAfterCancelAndRelaunch()
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let museumIdentifier = createItem("Museum", notes: "Museum booking", application: application)
    let parkIdentifier = createItem("Park", notes: "Park booking", application: application)
    let listIdentifier = createList("Wishlist", application: application)
    for title in ["Museum", "Park"] { addListItem(title, application: application) }
    let membershipIdentifiers = ["Museum", "Park"].map {
      application.savedPlannerItemRows($0).firstMatch.identifier
    }
    application.plannerElement(
      membershipIdentifiers[0].replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")
    )
    .activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].waitForExistence(timeout: 10))
    let removedItineraryIdentifier = createItinerary("Weekend route", application: application)
    for title in ["Museum", "Wishlist", "Wishlist"] {
      addItineraryEntry(title, application: application)
    }
    let removedAppearanceIdentifiers = readItineraryAppearanceIdentifiers(
      application, expectedCount: 5)
    XCTAssertEqual(removedAppearanceIdentifiers.count, 5)
    for identifier in removedAppearanceIdentifiers.prefix(2) {
      application.plannerElement(
        identifier.replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
      )
      .activateForPlannerJourney()
    }
    XCTAssertTrue(application.staticTexts["2 of 5 items done"].waitForExistence(timeout: 10))
    let removedSchedule = createItinerarySchedule(application)
    let retainedItineraryIdentifier = createItinerary("Rain route", application: application)
    for title in ["Museum", "Wishlist"] { addItineraryEntry(title, application: application) }
    let retainedAppearanceIdentifiers = readItineraryAppearanceIdentifiers(
      application, expectedCount: 3)
    XCTAssertEqual(retainedAppearanceIdentifiers.count, 3)
    application.plannerElement(
      retainedAppearanceIdentifiers[1].replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    )
    .activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].waitForExistence(timeout: 10))
    let retainedSchedule = createItinerarySchedule(application)
    openItem(museumIdentifier, application: application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule Item").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.schedule.save").waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let itemSchedule = scheduleRows(application).firstMatch
    XCTAssertTrue(itemSchedule.waitForExistence(timeout: 10))
    let itemScheduleIdentifier = itemSchedule.identifier
    let itemScheduleDescription = itemSchedule.value as? String
    XCTAssertFalse(itemScheduleDescription?.isEmpty ?? true)
    openItinerary(removedItineraryIdentifier, application: application)
    openItineraryActions(application)
    let deletion = application.plannerElement("saved.itinerary.delete")
    XCTAssertTrue(deletion.waitForExistence(timeout: 5))
    deletion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["5 saved references"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Weekend route"].firstMatch.exists)
    recordScreenshot(
      application, name: "Itinerary Delete reviews repeated route and owned appointment")
    application.plannerElement("saved.itinerary.delete.cancel").activateForPlannerJourney()
    XCTAssertEqual(
      readItineraryAppearanceIdentifiers(application, expectedCount: 5),
      removedAppearanceIdentifiers)
    XCTAssertTrue(application.staticTexts["2 of 5 items done"].exists)
    XCTAssertEqual(
      application.descendants(matching: .any)[removedSchedule.identifier].value as? String,
      removedSchedule.description)
    openItineraryActions(application)
    deletion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["5 saved references"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.delete.confirm").waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.alerts["Planner"].exists)
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    XCTAssertFalse(application.plannerElement(removedItineraryIdentifier).exists)
    XCTAssertTrue(application.plannerElement(retainedItineraryIdentifier).exists)
    XCTAssertFalse(application.descendants(matching: .any)[removedSchedule.identifier].exists)
    recordScreenshot(application, name: "Confirmed Itinerary deletion clears plan selection")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItinerary(retainedItineraryIdentifier, application: application)
    XCTAssertEqual(
      readItineraryAppearanceIdentifiers(application, expectedCount: 3),
      retainedAppearanceIdentifiers)
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].waitForExistence(timeout: 10))
    XCTAssertEqual(
      application.descendants(matching: .any)[retainedSchedule.identifier].value as? String,
      retainedSchedule.description)
    recordScreenshot(
      application, name: "Other route retains order completion and appointment after relaunch")
    openList(listIdentifier, application: application)
    for identifier in membershipIdentifiers {
      XCTAssertTrue(application.plannerElement(identifier).waitForExistence(timeout: 10))
    }
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].firstMatch.exists)
    openItem(museumIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
    XCTAssertEqual(
      application.descendants(matching: .any)[itemScheduleIdentifier].value as? String,
      itemScheduleDescription)
    openItem(parkIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Park booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    XCTAssertFalse(application.plannerElement(removedItineraryIdentifier).exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
  }

  func testEmptyItineraryDeletionAndSelectedAppearanceDeletionRetainTheSourceItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let itemIdentifier = createItem("Museum", notes: "Museum booking", application: application)
    let emptyIdentifier = createItinerary("Empty plan", application: application)
    openItineraryActions(application)
    let bulk = application.plannerElement("Mark all Done")
    XCTAssertTrue(bulk.exists)
    XCTAssertFalse(bulk.isEnabled)
    application.plannerElement("saved.itinerary.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No saved references"].waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Empty Itinerary Delete has no saved references")
    application.plannerElement("saved.itinerary.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openItineraryActions(application)
    application.plannerElement("saved.itinerary.delete").activateForPlannerJourney()
    application.plannerElement("saved.itinerary.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.delete.confirm").waitForNonExistence(timeout: 10))
    let populatedIdentifier = createItinerary("Selected plan", application: application)
    addItineraryEntry("Museum", application: application)
    let appearance = itineraryRows(application).firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    appearance.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    #if os(iOS)
      if !application.plannerElement("saved.itinerary.actions").exists {
        let back = application.navigationBars.buttons["Selected plan"].firstMatch
        if back.exists {
          back.activateForPlannerJourney()
        } else {
          let genericBack = application.plannerElement("BackButton")
          if genericBack.exists { genericBack.activateForPlannerJourney() }
        }
      }
    #endif
    openItineraryActions(application)
    application.plannerElement("saved.itinerary.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 saved reference"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.delete.confirm").waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement(appearanceIdentifier).exists)
    XCTAssertFalse(application.staticTexts["Museum booking"].exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    recordScreenshot(application, name: "Itinerary Delete clears selected appearance detail")
    application.terminate()
    application.launchSavedPlannerJourney()
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    XCTAssertFalse(application.plannerElement(emptyIdentifier).exists)
    XCTAssertFalse(application.plannerElement(populatedIdentifier).exists)
    openItem(itemIdentifier, application: application)
    XCTAssertTrue(application.staticTexts["Museum booking"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
  }

  private func createItinerary(_ title: String, application: XCUIApplication) -> String {
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let titleField = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    titleField.activateForPlannerJourney()
    titleField.typeText(title)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    let row = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", title)
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    let identifier = row.identifier
    openItinerary(identifier, application: application)
    return identifier
  }

  private func openItinerary(_ identifier: String, application: XCUIApplication) {
    openCatalog("Itineraries", creationIdentifier: "saved.itinerary.new", application: application)
    let itinerary = application.plannerElement(identifier)
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.entry.new").waitForExistence(timeout: 10))
  }

  private func openItineraryActions(_ application: XCUIApplication) {
    let actions = application.buttons.matching(
      NSPredicate(
        format: "identifier == %@ OR label == %@", "saved.itinerary.actions", "Itinerary actions")
    ).firstMatch
    if !actions.exists {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
    }
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
  }

  private func createItinerarySchedule(_ application: XCUIApplication) -> (
    identifier: String, description: String?
  ) {
    openItineraryActions(application)
    application.plannerElement("Schedule Itinerary").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.schedule.save").waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = scheduleRows(application, sourceKind: "itinerary").firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let description = schedule.value as? String
    XCTAssertFalse(description?.isEmpty ?? true)
    return (schedule.identifier, description)
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

  private func addListItem(_ title: String, application: XCUIApplication) {
    application.openSavedPlannerListAddMenu()
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
