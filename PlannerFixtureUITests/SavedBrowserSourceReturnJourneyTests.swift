import XCTest

@MainActor
final class SavedBrowserSourceReturnJourneyTests: XCTestCase {
  func testRestoredListAppearanceReturnsToItsOriginalLocalStateAndLiveContent() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
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
    appearance.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].waitForExistence(timeout: 10))
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<6 where !link.isHittable { application.swipeUp() }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    let bookmarkIdentifier = link.identifier
    XCTAssertEqual(link.value as? String, destination.absoluteString)
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    for (action, status) in [
      ("removeMembership", "Removed Hotel from Weekend"),
      ("update", "Saved another-writer change"),
      ("restoreMembership", "Restored original Hotel membership"),
    ] {
      application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
      application.plannerElement("fixture.writer.\(action)").activateForPlannerJourney()
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "label == %@", status),
              object: application.staticTexts["fixture.writer.status"])
          ], timeout: 15), .completed, application.debugDescription)
      XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
      XCTAssertFalse(application.alerts.firstMatch.exists)
    }
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Restored List membership preserves the open guide and exact public context"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.alerts.firstMatch.exists)
    XCTAssertTrue(
      application.plannerElement("saved.appearance.actions").waitForExistence(timeout: 10))
    XCTAssertTrue(application.collectionViews.firstMatch.waitForExistence(timeout: 10))
    let detailForm = try XCTUnwrap(
      application.collectionViews.allElementsBoundByIndex.last)
    for _ in 0..<6 where !application.staticTexts["Completed"].isHittable {
      let horizontalPosition = 24 / detailForm.frame.width
      detailForm.coordinate(withNormalizedOffset: CGVector(dx: horizontalPosition, dy: 0.25))
        .press(
          forDuration: 0.05,
          thenDragTo: detailForm.coordinate(
            withNormalizedOffset: CGVector(dx: horizontalPosition, dy: 0.75)))
    }
    XCTAssertTrue(application.staticTexts["Other writer notes"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["In Weekend"].exists)
    XCTAssertTrue(application.staticTexts["Completed"].exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Restored List reader Return shows local completion and current shared content"
    returned.lifetime = .keepAlways
    add(returned)
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: bookmarkIdentifier).firstMatch
    for _ in 0..<6 where !retainedLink.isHittable { application.swipeUp() }
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
    let restored = application.savedPlannerItemRows("Hotel updated").firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertEqual(restored.identifier, appearanceIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel updated").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertNotEqual(source.identifier, appearanceIdentifier)
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Other writer notes"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
  }

  func testRestoredSourceKeepsItsGuideButDoesNotReuseTheOldReaderContext() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 20))
    let sourceIdentifier = source.identifier
    source.activateForPlannerJourney()
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<6 where !link.isHittable { application.swipeUp() }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    let bookmarkIdentifier = link.identifier
    XCTAssertEqual(link.value as? String, destination.absoluteString)
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.restoreHotel").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Restored Hotel with a new lifetime"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 15), .completed, application.debugDescription)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Fresh restored Item lifetime keeps the original guide readable"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts["The original item is no longer available. Returned to Items."].exists
    )
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    let catalog = application.descendants(matching: .any)
      .matching(identifier: "saved.items.catalog").firstMatch
    XCTAssertTrue(catalog.waitForExistence(timeout: 10))
    let restored = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertTrue(restored.waitForPlannerHittability())
    XCTAssertEqual(restored.identifier, sourceIdentifier)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Old reader returns to the collection containing the restored public Item"
    returned.lifetime = .keepAlways
    add(returned)
    restored.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: bookmarkIdentifier).firstMatch
    for _ in 0..<6 where !retainedLink.isHittable { application.swipeUp() }
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testDeletedCalendarSourceKeepsItsGuideAndReturnsToCalendar() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    let listIdentifier = list.identifier
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    let sourceIdentifier = source.identifier
    source.activateForPlannerJourney()
    let originalLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<6 where !originalLink.isHittable { application.swipeUp() }
    XCTAssertTrue(originalLink.waitForExistence(timeout: 10))
    let bookmarkIdentifier = originalLink.identifier
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    for _ in 0..<6 where !schedule.isHittable { application.swipeUp() }
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = schedule.identifier.replacingOccurrences(
      of: "saved.item.schedule.", with: "")
    application.openPlannerSection("Calendar")
    let booking = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.schedule.\(scheduleIdentifier)").firstMatch
    XCTAssertTrue(booking.waitForExistence(timeout: 10))
    booking.activateForPlannerJourney()
    let calendarLink = application.descendants(matching: .any)
      .matching(identifier: bookmarkIdentifier).firstMatch
    for _ in 0..<6 where !calendarLink.isHittable { application.swipeUp() }
    XCTAssertTrue(calendarLink.waitForExistence(timeout: 10))
    XCTAssertEqual(calendarLink.value as? String, destination.absoluteString)
    calendarLink.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    let returnToItem = application.buttons["saved.browser.return"]
    XCTAssertEqual(returnToItem.label, "Return to item")
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.deleteHotel").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Deleted Hotel from another writer"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed, application.debugDescription)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Deleted Calendar source keeps its original guide open"
    reading.lifetime = .keepAlways
    add(reading)
    returnToItem.activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts[
        "The original item is no longer available. Returned to Calendar."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    let mode = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.mode").firstMatch
    XCTAssertTrue(mode.waitForExistence(timeout: 10))
    XCTAssertTrue(mode.isHittable)
    XCTAssertTrue(booking.waitForNonExistence(timeout: 10))
    let detailsToggle = application.buttons["saved.calendar.details.toggle"]
    if detailsToggle.exists { XCTAssertFalse(detailsToggle.isEnabled) }
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Deleted Calendar browser source returns to the surviving Calendar"
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Items")
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertFalse(
      application.descendants(matching: .any).matching(identifier: sourceIdentifier).firstMatch
        .exists)
    application.openPlannerSection("Lists")
    let retainedList = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedList.identifier, listIdentifier)
    retainedList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Hotel").count, 0)
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "Deleted Calendar source preserves its original empty List"
    retained.lifetime = .keepAlways
    add(retained)
  }

  func testDeletedItineraryKeepsItsGuideOpenAndPreservesItsSourcePlans() async throws {
    try await qualifyUnavailableItineraryGuide(opensItemAppearance: false)
  }

  func testDeletedCalendarItineraryKeepsItsGuideAndSharedSources() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString, "--fixture-itinerary",
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    let listIdentifier = list.identifier
    list.activateForPlannerJourney()
    let membership = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(membership.waitForExistence(timeout: 10))
    let membershipIdentifier = membership.identifier
    application.openPlannerSection("Items")
    let item = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    let itemIdentifier = item.identifier
    item.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let itemLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", "Museum guide")
    ).firstMatch
    for _ in 0..<6 where !itemLink.isHittable { application.swipeUp() }
    XCTAssertTrue(itemLink.waitForExistence(timeout: 10))
    let itemBookmarkIdentifier = itemLink.identifier
    application.openPlannerSection("Itineraries")
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "City trip")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
    let itineraryIdentifier = itinerary.identifier
    itinerary.activateForPlannerJourney()
    let itineraryLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", "Itinerary guide")
    ).firstMatch
    for _ in 0..<6 where !itineraryLink.isHittable { application.swipeUp() }
    XCTAssertTrue(itineraryLink.waitForExistence(timeout: 10))
    let itineraryBookmarkIdentifier = itineraryLink.identifier
    let actions = application.savedPlannerItineraryActionsControl()
    if actions.exists {
      actions.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5))
      overflow.activateForPlannerJourney()
      let itineraryActions = application.plannerElement("Itinerary actions")
      if itineraryActions.exists { itineraryActions.activateForPlannerJourney() }
    }
    application.plannerElement("Schedule itinerary").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule.")
    ).firstMatch
    for _ in 0..<6 where !schedule.isHittable { application.swipeUp() }
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = schedule.identifier.replacingOccurrences(
      of: "saved.itinerary.schedule.", with: "")
    application.openPlannerSection("Calendar")
    let booking = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.schedule.\(scheduleIdentifier)").firstMatch
    XCTAssertTrue(booking.waitForExistence(timeout: 10))
    booking.activateForPlannerJourney()
    let savedGuide = application.descendants(matching: .any)
      .matching(identifier: itineraryBookmarkIdentifier).firstMatch
    for _ in 0..<6 where !savedGuide.isHittable { application.swipeUp() }
    XCTAssertTrue(savedGuide.waitForExistence(timeout: 10))
    XCTAssertEqual(savedGuide.value as? String, destination.absoluteString)
    savedGuide.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    let returnToItinerary = application.buttons["saved.browser.return"]
    XCTAssertEqual(returnToItinerary.label, "Return to itinerary")
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.deleteCityTrip").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Deleted City trip from another writer"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed, application.debugDescription)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Deleted Calendar Itinerary keeps its owned guide open"
    reading.lifetime = .keepAlways
    add(reading)
    returnToItinerary.activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts[
        "The original itinerary is no longer available. Returned to Calendar."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    let mode = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.mode").firstMatch
    XCTAssertTrue(mode.waitForExistence(timeout: 10))
    XCTAssertTrue(mode.isHittable)
    XCTAssertTrue(booking.waitForNonExistence(timeout: 10))
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Deleted Calendar Itinerary returns to Calendar without its booking"
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Itineraries")
    XCTAssertTrue(
      application.staticTexts["No Itineraries yet"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(
      application.descendants(matching: .any)
        .matching(identifier: itineraryIdentifier).firstMatch.exists)
    let catalog = XCTAttachment(screenshot: application.screenshot())
    catalog.name = "Deleted Calendar Itinerary clears its shared catalog selection"
    catalog.lifetime = .keepAlways
    add(catalog)
    application.openPlannerSection("Items")
    for _ in 0..<6 where !application.staticTexts["Original notes"].exists {
      application.swipeDown()
    }
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    let retainedItemLink = application.descendants(matching: .any)
      .matching(identifier: itemBookmarkIdentifier).firstMatch
    for _ in 0..<6 where !retainedItemLink.isHittable { application.swipeUp() }
    XCTAssertTrue(retainedItemLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedItemLink.value as? String, destination.absoluteString)
    let retainedItem = application.savedPlannerItemRows("Hotel").firstMatch
    if !retainedItem.exists {
      let back = application.navigationBars.buttons["BackButton"].firstMatch
      XCTAssertTrue(back.waitForExistence(timeout: 5))
      back.activateForPlannerJourney()
    }
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedItem.identifier, itemIdentifier)
    application.openPlannerSection("Lists")
    let retainedList = application.savedPlannerListRow("Weekend")
    if !retainedList.exists {
      let back = application.navigationBars.buttons["BackButton"].firstMatch
      XCTAssertTrue(back.waitForExistence(timeout: 5))
      back.activateForPlannerJourney()
    }
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedList.identifier, listIdentifier)
    retainedList.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(membershipIdentifier).waitForExistence(timeout: 10))
    let membershipCompletion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertEqual(membershipCompletion.value as? String, "To do")
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "Deleted Calendar Itinerary preserves its Item and original List membership"
    retained.lifetime = .keepAlways
    add(retained)
  }

  func testDeletedItineraryAppearanceKeepsItsGuideOpenAndReturnsToItineraries() async throws {
    try await qualifyUnavailableItineraryGuide(opensItemAppearance: true)
  }

  func testRemovedItineraryAppearanceKeepsItsGuideAndReturnsToTheSurvivingPlan() async throws {
    try await qualifyUnavailableItineraryGuide(opensItemAppearance: true, removesEntryOnly: true)
  }

  func testRemovedRepeatedListBranchKeepsItsGuideAndOtherCompletion() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString, "--fixture-itinerary",
      "--fixture-repeated-itinerary-list",
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    let listIdentifier = list.identifier
    list.activateForPlannerJourney()
    application.chooseSavedPlannerStateFilter(
      "All completion states", control: application.plannerElement("saved.list.filters"))
    let membership = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(membership.waitForExistence(timeout: 10))
    let membershipIdentifier = membership.identifier
    let membershipCompletion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    membershipCompletion.activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Completed"),
            object: membershipCompletion)
        ], timeout: 10), .completed)
    application.openPlannerSection("Itineraries")
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "City trip")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
    itinerary.activateForPlannerJourney()
    application.chooseSavedPlannerStateFilter(
      "All completion states", control: application.plannerElement("saved.itinerary.filters"))
    let contents = application.descendants(matching: .any)
      .matching(identifier: "saved.itinerary.contents").firstMatch
    XCTAssertTrue(contents.waitForExistence(timeout: 10))
    let appearances = application.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.", "Hotel"))
    var expandedIdentifiers: [String] = []
    for _ in 0..<12 {
      for appearance in appearances.allElementsBoundByIndex
      where appearance.identifier.split(separator: ".").count == 5 && appearance.isHittable {
        if !expandedIdentifiers.contains(appearance.identifier) {
          expandedIdentifiers.append(appearance.identifier)
        }
      }
      if expandedIdentifiers.count == 2 { break }
      contents.swipeUp()
    }
    XCTAssertEqual(expandedIdentifiers.count, 2)
    let removedIdentifier = try XCTUnwrap(expandedIdentifiers.first)
    let survivingIdentifier = try XCTUnwrap(expandedIdentifiers.last)
    XCTAssertNotEqual(removedIdentifier, survivingIdentifier)
    let survivingCompletion = application.buttons[
      survivingIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")]
    survivingCompletion.activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Completed"),
            object: survivingCompletion)
        ], timeout: 10), .completed)
    let removedAppearance = application.buttons[removedIdentifier]
    for _ in 0..<8 where !removedAppearance.isHittable { contents.swipeDown() }
    XCTAssertTrue(removedAppearance.isHittable)
    let removedCompletion = application.buttons[
      removedIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")]
    XCTAssertEqual(removedCompletion.value as? String, "To do")
    removedAppearance.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let link = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", "Museum guide")
    ).firstMatch
    for _ in 0..<6 where !link.isHittable { application.swipeUp() }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    let bookmarkIdentifier = link.identifier
    XCTAssertEqual(link.value as? String, destination.absoluteString)
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    let returnToItem = application.buttons["saved.browser.return"]
    XCTAssertEqual(returnToItem.label, "Return to item")
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.removeWeekendBranch").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(
              format: "label == %@", "Removed first Weekend branch from City trip"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Removed repeated List branch keeps its exact guide open"
    reading.lifetime = .keepAlways
    add(reading)
    returnToItem.activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts[
        "The original itinerary entry is no longer available. Returned to the Itinerary."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.buttons[removedIdentifier].exists)
    for _ in 0..<8 where !application.buttons[survivingIdentifier].isHittable { contents.swipeUp() }
    XCTAssertTrue(application.buttons[survivingIdentifier].waitForExistence(timeout: 10))
    XCTAssertEqual(survivingCompletion.value as? String, "Completed")
    XCTAssertFalse(application.staticTexts["Original notes"].exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Repeated List return preserves the other appearance completion"
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    let retainedBookmark = application.descendants(matching: .any)
      .matching(identifier: bookmarkIdentifier).firstMatch
    for _ in 0..<6 where !retainedBookmark.isHittable { application.swipeUp() }
    XCTAssertTrue(retainedBookmark.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedBookmark.value as? String, destination.absoluteString)
    application.openPlannerSection("Lists")
    let retainedList = application.savedPlannerListRow("Weekend")
    if !retainedList.exists {
      let back = application.navigationBars.buttons["BackButton"].firstMatch
      XCTAssertTrue(back.waitForExistence(timeout: 5))
      back.activateForPlannerJourney()
    }
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedList.identifier, listIdentifier)
    retainedList.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(membershipIdentifier).waitForExistence(timeout: 10))
    XCTAssertEqual(membershipCompletion.value as? String, "Completed")
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "Repeated List removal preserves standalone completion and original membership"
    retained.lifetime = .keepAlways
    add(retained)
  }

  private func qualifyUnavailableItineraryGuide(
    opensItemAppearance: Bool, removesEntryOnly: Bool = false
  ) async throws {
    continueAfterFailure = false
    var capturePrefix = opensItemAppearance ? "Deleted Itinerary appearance" : "Deleted Itinerary"
    if removesEntryOnly { capturePrefix = "Removed Itinerary appearance" }
    var openedAppearanceIdentifier: String?
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString, "--fixture-itinerary",
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    let listIdentifier = list.identifier
    list.activateForPlannerJourney()
    let membership = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(membership.waitForExistence(timeout: 10))
    let membershipIdentifier = membership.identifier
    application.openPlannerSection("Itineraries")
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "City trip")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
    let itineraryIdentifier = itinerary.identifier
    itinerary.activateForPlannerJourney()
    if opensItemAppearance {
      let appearance = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.", "Hotel"
        )
      ).firstMatch
      for _ in 0..<6 {
        if appearance.exists && appearance.isHittable { break }
        application.swipeUp()
      }
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      openedAppearanceIdentifier = appearance.identifier
      appearance.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    }
    let linkTitle = opensItemAppearance ? "Museum guide" : "Itinerary guide"
    let link = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", linkTitle)
    ).firstMatch
    for _ in 0..<6 {
      if link.exists && link.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    XCTAssertEqual(link.value as? String, destination.absoluteString)
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    let returnToPlanner = application.buttons["saved.browser.return"]
    XCTAssertEqual(
      returnToPlanner.label, opensItemAppearance ? "Return to item" : "Return to itinerary")
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    let writerAction =
      removesEntryOnly ? "fixture.writer.removeCityTripEntry" : "fixture.writer.deleteCityTrip"
    application.plannerElement(writerAction).activateForPlannerJourney()
    let writerStatus =
      removesEntryOnly ? "Removed Hotel from City trip" : "Deleted City trip from another writer"
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", writerStatus),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "\(capturePrefix) leaves its guide open"
    reading.lifetime = .keepAlways
    add(reading)
    returnToPlanner.activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    let subject = opensItemAppearance ? "itinerary entry" : "itinerary"
    let returnDestination = removesEntryOnly ? "the Itinerary" : "Itineraries"
    XCTAssertTrue(
      explanation.staticTexts[
        "The original \(subject) is no longer available. Returned to \(returnDestination)."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    if removesEntryOnly {
      XCTAssertTrue(application.staticTexts["City trip"].firstMatch.waitForExistence(timeout: 10))
      let removedIdentifier = try XCTUnwrap(openedAppearanceIdentifier)
      XCTAssertFalse(application.buttons[removedIdentifier].exists)
      let remainingAppearance = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.", "Hotel"
        )
      ).firstMatch
      for _ in 0..<6 {
        if remainingAppearance.exists && remainingAppearance.isHittable { break }
        application.swipeUp()
      }
      XCTAssertTrue(remainingAppearance.waitForExistence(timeout: 10))
      XCTAssertNotEqual(remainingAppearance.identifier, removedIdentifier)
      let remainingCompletion = application.buttons[
        remainingAppearance.identifier.replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")]
      XCTAssertEqual(remainingCompletion.value as? String, "To do")
      XCTAssertFalse(application.staticTexts["Original notes"].exists)
    } else {
      XCTAssertTrue(
        application.staticTexts["No Itineraries yet"].firstMatch.waitForExistence(timeout: 10))
      XCTAssertFalse(
        application.descendants(matching: .any)
          .matching(identifier: itineraryIdentifier).firstMatch.exists)
    }
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "\(capturePrefix) returns to its catalog"
    if removesEntryOnly { returned.name = "Removed Itinerary appearance returns to its plan" }
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    application.openPlannerSection("Lists")
    let retainedList = application.savedPlannerListRow("Weekend")
    if !retainedList.exists {
      let back = application.navigationBars.buttons["BackButton"].firstMatch
      XCTAssertTrue(back.waitForExistence(timeout: 5))
      back.activateForPlannerJourney()
    }
    XCTAssertTrue(retainedList.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedList.identifier, listIdentifier)
    retainedList.activateForPlannerJourney()
    let retainedMembership = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(retainedMembership.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedMembership.identifier, membershipIdentifier)
    let membershipCompletion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertEqual(membershipCompletion.value as? String, "To do")
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "\(capturePrefix) preserves its original List membership"
    retained.lifetime = .keepAlways
    add(retained)
  }

  func testDeletedContainingListKeepsItsGuideOpenAndReturnsToLists() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    list.activateForPlannerJourney()
    let appearance = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    appearance.activateForPlannerJourney()
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<3 {
      if link.exists && link.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.deleteWeekend").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Deleted Weekend from another writer"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Deleted containing List leaves its guide open"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts[
        "The original List entry is no longer available. Returned to Lists."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerListRow("Weekend").exists)
    XCTAssertFalse(application.buttons[appearanceIdentifier].exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Deleted containing List returns to Lists"
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "Deleted containing List preserves its shared Todo Item"
    retained.lifetime = .keepAlways
    add(retained)
  }

  func testRemovedListAppearanceReturnsToItsListAndPreservesTheSharedItem() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Lists")
    let list = application.savedPlannerListRow("Weekend")
    XCTAssertTrue(list.waitForExistence(timeout: 20))
    list.activateForPlannerJourney()
    let appearance = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    appearance.activateForPlannerJourney()
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<3 {
      if link.exists && link.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.removeMembership").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Removed Hotel from Weekend"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Removed List appearance leaves the original guide open"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts[
        "The original List entry is no longer available. Returned to the List."
      ].exists)
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Weekend"].exists)
    XCTAssertFalse(application.buttons[appearanceIdentifier].exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Removed browser appearance returns to its original List"
    returned.lifetime = .keepAlways
    add(returned)
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertNotEqual(source.identifier, appearanceIdentifier)
    source.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    let retained = XCTAttachment(screenshot: application.screenshot())
    retained.name = "Removed browser appearance preserves its shared Todo Item"
    retained.lifetime = .keepAlways
    add(retained)
  }

  func testDeletedSourceKeepsItsGuideOpenAndReturnsToItsSurvivingCollection() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = [
      "--change-stream-fixture", "--fixture-dataset", UUID().uuidString,
      "--fixture-website-url", destination.absoluteString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let source = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 20))
    source.activateForPlannerJourney()
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    for _ in 0..<3 {
      if link.exists && link.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    link.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.plannerElement("fixture.writer.menu").activateForPlannerJourney()
    application.plannerElement("fixture.writer.deleteHotel").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Deleted Hotel from another writer"),
            object: application.staticTexts["fixture.writer.status"])
        ], timeout: 10), .completed)
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.alerts.firstMatch.exists)
    let reading = XCTAttachment(screenshot: application.screenshot())
    reading.name = "Deleted source leaves the original guide open"
    reading.lifetime = .keepAlways
    add(reading)
    application.plannerElement("saved.browser.return").activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(
      explanation.staticTexts["The original item is no longer available. Returned to Items."].exists
    )
    explanation.buttons["OK"].activateForPlannerJourney()
    XCTAssertTrue(page.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.items.catalog")
        .firstMatch.exists)
    let returned = XCTAttachment(screenshot: application.screenshot())
    returned.name = "Deleted browser source returns to the surviving Items collection"
    returned.lifetime = .keepAlways
    add(returned)
  }
}
