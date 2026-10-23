import XCTest

@MainActor
final class ChangeObservationJourneyTests: XCTestCase {
  func testFilteredItineraryMapKeepsItsExactRepeatedBranchAfterAnIndependentContentEdit() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-itinerary", "--fixture-repeated-itinerary-list",
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Itineraries")
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "City trip")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
    XCTAssertTrue(itinerary.waitForPlannerHittability())
    itinerary.staticTexts["City trip"].firstMatch.activateForPlannerJourney()
    let contents = application.descendants(matching: .any)
      .matching(identifier: "saved.itinerary.contents").firstMatch
    let appearances = application.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.", "Hotel"))
    XCTAssertTrue(appearances.firstMatch.waitForExistence(timeout: 10))
    var identifiers: [String] = []
    for _ in 0..<8 {
      for row in appearances.allElementsBoundByIndex where !identifiers.contains(row.identifier) {
        identifiers.append(row.identifier)
      }
      if identifiers.count == 3 { break }
      contents.swipeUp()
    }
    XCTAssertEqual(identifiers.count, 3)
    let selectedIdentifier = try XCTUnwrap(
      identifiers.first { $0.split(separator: ".").count == 5 })
    let selected = application.buttons[selectedIdentifier]
    for _ in 0..<8 where !selected.isHittable { contents.swipeDown() }
    let completion = application.buttons[
      selectedIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")]
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    let search = application.searchFields["Search this Itinerary"]
    if !search.exists { contents.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.activateForPlannerJourney()
    search.typeText("Original notes\n")
    XCTAssertTrue(search.waitForPlannerValue("Original notes"))
    application.openSavedPlannerItineraryViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let pin = application.buttons["saved.map.pin.35.662,139.717"]
    XCTAssertTrue(pin.waitForExistence(timeout: 15))
    XCTAssertEqual(pin.label, "3 items")
    pin.activateForPlannerJourney()
    let branch = application.buttons["Hotel · Weekend · Stop 2 · Item 1"].firstMatch
    XCTAssertTrue(branch.waitForExistence(timeout: 5))
    branch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.waitForExistence(timeout: 10))
    performFixtureAction(
      "fixture.writer.update", expecting: "Saved another-writer change", in: application)
    XCTAssertTrue(application.staticTexts["Other writer notes"].waitForExistence(timeout: 15))
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.exists)
    XCTAssertFalse(application.plannerElement("saved.item.completion").exists)
    let details = XCTAttachment(screenshot: application.screenshot())
    details.name = "Filtered itinerary Map retains its exact completed repeated branch"
    details.lifetime = .keepAlways
    add(details)
    if application.windows.firstMatch.frame.width < 600 {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 15))
    XCTAssertTrue(pin.waitForNonExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["0 of 0 items located"].exists)
    let empty = XCTAttachment(screenshot: application.screenshot())
    empty.name = "Filtered itinerary Map removes all old pins without changing branch state"
    empty.lifetime = .keepAlways
    add(empty)
    application.openSavedPlannerItineraryViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("List")
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.activateForPlannerJourney()
    search.buttons["Clear text"].activateForPlannerJourney()
    search.activateForPlannerJourney()
    search.typeText("Hotel updated\n")
    let current = application.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.",
        "Hotel updated"))
    XCTAssertTrue(current.firstMatch.waitForExistence(timeout: 10))
    var restoredIdentifiers: Set<String> = []
    for _ in 0..<8 {
      for row in current.allElementsBoundByIndex {
        restoredIdentifiers.insert(row.identifier)
        let control = application.buttons[
          row.identifier.replacingOccurrences(
            of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")]
        XCTAssertEqual(
          control.value as? String, row.identifier == selectedIdentifier ? "Completed" : "To do")
      }
      if restoredIdentifiers.count == 3 { break }
      contents.swipeUp()
    }
    XCTAssertEqual(restoredIdentifiers, Set(identifiers))
    for _ in 0..<8 where !selected.isHittable { contents.swipeDown() }
    XCTAssertTrue(selected.isHittable)
    selected.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Other writer notes"].exists)
  }

  func testFilteredCatalogMapsKeepTheirSelectedSourceAfterAnIndependentContentEdit() {
    continueAfterFailure = false
    for section in ["Items", "Inbox"] {
      let application = XCUIApplication()
      application.launchArguments = [
        "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      if section == "Inbox" {
        performFixtureAction(
          "fixture.writer.removeMembership", expecting: "Removed Hotel from Weekend",
          in: application)
      }
      application.openPlannerSection(section)
      let source = application.savedPlannerItemRows("Hotel").firstMatch
      XCTAssertTrue(source.waitForExistence(timeout: 20))
      let sourceIdentifier = source.identifier
      let search = application.searchFields["Search \(section)"]
      if !search.exists { application.swipeDown() }
      XCTAssertTrue(search.waitForExistence(timeout: 10))
      search.activateForPlannerJourney()
      search.typeText("Original notes\n")
      XCTAssertTrue(search.waitForPlannerValue("Original notes"))
      XCTAssertTrue(source.waitForExistence(timeout: 10))
      application.openSavedPlannerCatalogViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("Map")
      let pin = application.buttons["saved.map.pin.35.662,139.717"]
      XCTAssertTrue(pin.waitForExistence(timeout: 15))
      pin.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
      let completion = application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      performFixtureAction(
        "fixture.writer.update", expecting: "Saved another-writer change", in: application)
      XCTAssertTrue(application.staticTexts["Other writer notes"].waitForExistence(timeout: 15))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      XCTAssertTrue(application.plannerElement("saved.item.actions").exists)
      XCTAssertFalse(application.alerts.firstMatch.exists)
      let details = XCTAttachment(screenshot: application.screenshot())
      details.name =
        "Filtered catalog Map retains its selected \(section) source after a writer edit"
      details.lifetime = .keepAlways
      add(details)
      if application.windows.firstMatch.frame.width < 600 {
        application.plannerElement("BackButton").activateForPlannerJourney()
      }
      XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 15))
      XCTAssertTrue(pin.waitForNonExistence(timeout: 5))
      XCTAssertTrue(application.staticTexts["0 of 0 items located"].exists)
      let empty = XCTAttachment(screenshot: application.screenshot())
      empty.name =
        "Filtered catalog Map removes the old \(section) pin and keeps source details valid"
      empty.lifetime = .keepAlways
      add(empty)
      application.openSavedPlannerCatalogViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("List")
      XCTAssertTrue(search.waitForExistence(timeout: 10))
      search.activateForPlannerJourney()
      search.buttons["Clear text"].activateForPlannerJourney()
      search.activateForPlannerJourney()
      search.typeText("Hotel updated\n")
      let updated = application.savedPlannerItemRows("Hotel updated").firstMatch
      XCTAssertTrue(updated.waitForExistence(timeout: 10))
      XCTAssertEqual(updated.identifier, sourceIdentifier)
      updated.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      XCTAssertTrue(application.staticTexts["Other writer notes"].exists)
      application.terminate()
    }
  }

  func testFilteredMapKeepsItsSelectedListAppearanceAfterAnIndependentContentEdit() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    list.activateForPlannerJourney()
    let appearance = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    let completion = application.buttons[
      appearanceIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    let search = application.searchFields["Search this List"]
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.activateForPlannerJourney()
    search.typeText("Original notes\n")
    XCTAssertTrue(search.waitForPlannerValue("Original notes"))
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    application.openSavedPlannerListViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let pin = application.buttons["saved.map.pin.35.662,139.717"]
    XCTAssertTrue(pin.waitForExistence(timeout: 15))
    pin.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Weekend"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.exists)
    application.activatePlannerFixtureWriterAction("fixture.writer.update")
    let status = application.staticTexts["fixture.writer.status"]
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Saved another-writer change"),
            object: status)
        ], timeout: 15), .completed)
    XCTAssertTrue(application.staticTexts["Other writer notes"].waitForExistence(timeout: 15))
    XCTAssertTrue(application.staticTexts["In Weekend"].exists)
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.exists)
    XCTAssertTrue(application.plannerElement("saved.appearance.actions").exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let details = XCTAttachment(screenshot: application.screenshot())
    details.name = "Filtered Map retains the exact completed List appearance after a writer edit"
    details.lifetime = .keepAlways
    add(details)
    if application.windows.firstMatch.frame.width < 600 {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 15))
    XCTAssertTrue(pin.waitForNonExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["0 of 0 items located"].exists)
    let empty = XCTAttachment(screenshot: application.screenshot())
    empty.name = "Filtered Map removes the old pin without deleting its selected appearance"
    empty.lifetime = .keepAlways
    add(empty)
    application.openSavedPlannerListViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("List")
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.activateForPlannerJourney()
    search.buttons["Clear text"].activateForPlannerJourney()
    search.activateForPlannerJourney()
    search.typeText("Hotel updated\n")
    let current = application.savedPlannerItemRows("Hotel updated").firstMatch
    XCTAssertTrue(current.waitForExistence(timeout: 10))
    XCTAssertEqual(current.identifier, appearanceIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel updated").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    source.activateForPlannerJourney()
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Other writer notes"].exists)
  }

  func testAnIndependentWriterMovesTheOpenCollectionMapPinWithoutChangingItsSource() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 20))
    let sourceIdentifier = source.identifier
    application.openSavedPlannerCatalogViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let original = application.buttons["saved.map.pin.35.662,139.717"]
    XCTAssertTrue(original.waitForExistence(timeout: 10))
    performFixtureAction(
      "fixture.writer.moveHotel", expecting: "Saved another-writer location", in: application)
    XCTAssertTrue(
      application.buttons["saved.map.pin.35.655,139.717"].waitForExistence(timeout: 15))
    XCTAssertTrue(original.waitForNonExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Independent writer refreshes the open collection Map"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.openSavedPlannerCatalogViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("List")
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertEqual(source.identifier, sourceIdentifier)
  }

  func testAChangedBindingOffersValidatedReconnectionWithoutReplacingTheDraft() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let origin = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(origin.waitForExistence(timeout: 20))
    origin.activateForPlannerJourney()
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.createItem").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    let notes = application.textFields["saved.item.notes"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    title.activateForPlannerJourney()
    title.typeText("Connection draft")
    notes.activateForPlannerJourney()
    notes.typeText("Retain connection notes")
    let save = application.plannerElement("saved.item.save")
    XCTAssertTrue(save.isEnabled)
    application.activatePlannerFixtureWriterAction("fixture.writer.changeBinding")
    let legacyAlert = application.alerts.firstMatch
    if legacyAlert.waitForExistence(timeout: 2) {
      legacyAlert.buttons["OK"].activateForPlannerJourney()
    }
    let reconnect = application.plannerElement("saved.changes.retry")
    XCTAssertTrue(reconnect.waitForExistence(timeout: 15))
    XCTAssertFalse(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Connection draft")
    XCTAssertEqual(notes.value as? String, "Retain connection notes")
    performFixtureAction(
      "fixture.writer.restoreBinding", expecting: "Dataset binding restored", in: application)
    reconnect.activateForPlannerJourney()
    XCTAssertTrue(reconnect.waitForNonExistence(timeout: 15))
    XCTAssertTrue(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Connection draft")
    XCTAssertEqual(notes.value as? String, "Retain connection notes")
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Validated reconnection preserves the edited draft"
    attachment.lifetime = .keepAlways
    add(attachment)
    save.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Retain connection notes"].waitForExistence(timeout: 15))
  }

  func testRecoveryOnlyDamageAndRepairPreserveAnEditedDraftAndItsListDestination() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let origin = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(origin.waitForExistence(timeout: 20))
    let originIdentifier = origin.identifier
    origin.activateForPlannerJourney()
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.createItem").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    let notes = application.textFields["saved.item.notes"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    title.activateForPlannerJourney()
    title.typeText("Unsaved visit")
    XCTAssertTrue(notes.waitForExistence(timeout: 10))
    notes.activateForPlannerJourney()
    notes.typeText("Keep this draft")
    let save = application.plannerElement("saved.item.save")
    XCTAssertTrue(save.isEnabled)
    performFixtureAction(
      "fixture.writer.update", expecting: "Saved another-writer change", in: application)
    XCTAssertEqual(title.value as? String, "Unsaved visit")
    XCTAssertEqual(notes.value as? String, "Keep this draft")
    XCTAssertFalse(application.alerts.firstMatch.exists)
    performFixtureAction(
      "fixture.writer.damageRecovery", expecting: "Recovery checkpoint damaged", in: application)
    let recovery = application.plannerElement("saved.recovery.status.open")
    XCTAssertTrue(recovery.waitForExistence(timeout: 15))
    XCTAssertFalse(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Unsaved visit")
    XCTAssertEqual(notes.value as? String, "Keep this draft")
    let damaged = XCTAttachment(screenshot: application.screenshot())
    damaged.name = "Independent recovery damage preserves the edited draft"
    damaged.lifetime = .keepAlways
    add(damaged)
    performFixtureAction(
      "fixture.writer.repairRecovery", expecting: "Recovery checkpoint repaired", in: application)
    XCTAssertTrue(recovery.waitForNonExistence(timeout: 15))
    XCTAssertTrue(save.isEnabled)
    XCTAssertEqual(title.value as? String, "Unsaved visit")
    XCTAssertEqual(notes.value as? String, "Keep this draft")
    let destination = application.descendants(matching: .any)
      .matching(identifier: "saved.item.destination").firstMatch
    XCTAssertTrue(
      destination.label.contains("Weekend") || (destination.value as? String) == "Weekend"
        || destination.staticTexts["Weekend"].exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Independent recovery repair preserves the edited draft"
    attachment.lifetime = .keepAlways
    add(attachment)
    save.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep this draft"].waitForExistence(timeout: 15))
    application.openPlannerSection("Lists")
    let savedOrigin = application.plannerElement(originIdentifier)
    if savedOrigin.exists && savedOrigin.isHittable { savedOrigin.activateForPlannerJourney() }
    let saved = application.buttons.matching(NSPredicate(format: "label == %@", "Unsaved visit"))
      .firstMatch
    if !saved.isHittable { application.plannerElement("BackButton").activateForPlannerJourney() }
    XCTAssertTrue(saved.waitForExistence(timeout: 10))
  }

  private func performFixtureAction(
    _ identifier: String, expecting status: String, in application: XCUIApplication
  ) {
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement(identifier).activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", status),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
  }

  func testAnIndependentWriterRefreshesTheSelectedItemWithoutNavigation() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let original = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(original.waitForExistence(timeout: 20))
    let sourceIdentifier = original.identifier
    original.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    application.activatePlannerFixtureWriterAction("fixture.writer.update")
    let status = application.staticTexts["fixture.writer.status"]
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Saved another-writer change"),
            object: status)
        ], timeout: 10), .completed)
    XCTAssertTrue(application.staticTexts["Other writer notes"].waitForExistence(timeout: 15))
    XCTAssertFalse(application.staticTexts["Original notes"].exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Independent writer refreshes the selected Item"
    attachment.lifetime = .keepAlways
    add(attachment)
    let updated = application.savedPlannerItemRows("Hotel updated").firstMatch
    if !updated.isHittable {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }
    XCTAssertTrue(updated.waitForExistence(timeout: 10))
    XCTAssertEqual(updated.identifier, sourceIdentifier)
  }
}
