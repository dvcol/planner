import XCTest

@MainActor
final class SavedBrowserSourceReturnJourneyTests: XCTestCase {
  func testDeletedItineraryKeepsItsGuideOpenAndPreservesItsSourcePlans() async throws {
    try await qualifyUnavailableItineraryGuide(opensItemAppearance: false)
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
