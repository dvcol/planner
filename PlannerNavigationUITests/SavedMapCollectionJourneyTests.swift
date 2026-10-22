import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class SavedMapCollectionJourneyTests: XCTestCase {
  func testMapLocationsRetainProviderAttributionAndSearchUncertainty() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let originalURL = "https://www.google.com/maps/search/?api=1&query=35,139"
    createItem("Map museum", link: originalURL, in: application)
    let originalLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", originalURL)
    ).firstMatch
    revealDetailLink(originalLink, in: application)
    XCTAssertTrue(originalLink.waitForExistence(timeout: 10))
    let originalIdentifier = originalLink.identifier
    returnToCatalog(application)
    application.plannerElement("saved.items.representation").activateForPlannerJourney()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    XCTAssertTrue(application.buttons["saved.map.pin.35.0,139.0"].waitForExistence(timeout: 10))
    let locatedCount = application.staticTexts["1 of 1 items located"].firstMatch
    let locations = application.plannerElement("saved.map.locations")
    XCTAssertTrue(locatedCount.waitForExistence(timeout: 5))
    XCTAssertTrue(locatedCount.isHittable)
    XCTAssertTrue(locations.isHittable)
    let footerCapture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    footerCapture.name = "Collection Map footer remains readable at accessibility text sizes"
    footerCapture.lifetime = .keepAlways
    add(footerCapture)
    #if os(iOS)
      if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
        let map = application.descendants(matching: .any)
          .matching(identifier: "saved.map.collection").firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        if map.frame.width <= 600 {
          XCTAssertGreaterThanOrEqual(
            locations.frame.minY, locatedCount.frame.maxY,
            "A narrow accessibility footer must give the count and Locations their own rows.")
        }
      }
    #endif
    locations.activateForPlannerJourney()
    let provider = application.staticTexts.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.map.location.provider.")
    ).firstMatch
    XCTAssertTrue(provider.waitForExistence(timeout: 5))
    XCTAssertEqual(provider.label, "Google Maps")
    XCTAssertTrue(provider.isHittable)
    let uncertainty = application.staticTexts.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.map.location.uncertainty.")
    ).firstMatch
    XCTAssertTrue(uncertainty.waitForExistence(timeout: 5))
    XCTAssertEqual(uncertainty.label, "Place details haven't been verified for this search link.")
    XCTAssertTrue(uncertainty.isHittable)
    #if os(iOS)
      if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
        XCTAssertGreaterThan(
          uncertainty.frame.height, provider.frame.height * 1.5,
          "The complete location warning must wrap visibly at accessibility text sizes.")
        XCTAssertLessThanOrEqual(
          uncertainty.frame.maxY, application.windows.firstMatch.frame.maxY,
          "The complete warning must fit in the initial accessibility Locations sheet.")
      }
    #endif
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Collection Map Locations retain provider and search uncertainty"
    capture.lifetime = .keepAlways
    add(capture)
    application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.map.location.source.")
    ).firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let retainedLink = application.descendants(matching: .any).matching(
      identifier: originalIdentifier
    )
    .firstMatch
    revealDetailLink(retainedLink, in: application)
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, originalURL)
  }

  func testUnresolvedMapSearchCanRetryWithoutInventingAPinOrChangingItsBookmark() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let originalURL = "https://www.google.com/maps/search/?api=1&query=Museum"
    createItem("Map search", link: originalURL, in: application)
    let originalLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", originalURL)
    ).firstMatch
    revealDetailLink(originalLink, in: application)
    XCTAssertTrue(originalLink.waitForExistence(timeout: 10))
    let originalIdentifier = originalLink.identifier
    returnToCatalog(application)
    application.plannerElement("saved.items.representation").activateForPlannerJourney()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    XCTAssertTrue(application.staticTexts["0 of 1 items located"].waitForExistence(timeout: 10))
    application.plannerElement("saved.map.locations").activateForPlannerJourney()
    let location = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.map.location.source.")
    ).firstMatch
    XCTAssertTrue(location.waitForExistence(timeout: 5))
    let unavailable = NSPredicate(format: "value == %@", "Location unavailable")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: unavailable, object: location)], timeout: 10),
      .completed)
    let options = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.map.location.options.")
    ).firstMatch
    XCTAssertTrue(options.waitForExistence(timeout: 5))
    options.activateForPlannerJourney()
    let retry = application.plannerElement("Retry location")
    XCTAssertTrue(retry.waitForExistence(timeout: 5))
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Unresolved collection Map search retains Retry and saved link"
    capture.lifetime = .keepAlways
    add(capture)
    retry.activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: unavailable, object: location)], timeout: 10),
      .completed)
    location.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let retainedLink = application.descendants(matching: .any).matching(
      identifier: originalIdentifier
    )
    .firstMatch
    revealDetailLink(retainedLink, in: application)
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, originalURL)
  }

  func testNativeMapLinkChoiceMovesThePinWithoutChangingSavedBookmarks() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let originalURL = "https://www.google.com/maps/search/?api=1&query=35,139"
    let alternateURL = "https://www.google.com/maps/search/?api=1&query=36,140"
    createItem("Map museum", link: originalURL, in: application)
    let originalLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", originalURL)
    ).firstMatch
    revealDetailLink(originalLink, in: application)
    XCTAssertTrue(originalLink.waitForExistence(timeout: 10))
    let originalIdentifier = originalLink.identifier
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.item.edit.title"].waitForExistence(timeout: 5))
    let addLink = application.plannerElement("saved.item.edit.link.add")
    for _ in 0..<8 where !addLink.isHittable { application.swipeUp() }
    XCTAssertTrue(addLink.isHittable)
    addLink.activateForPlannerJourney()
    guard
      let alternateInput = application.textFields.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.edit.link.url.")
      ).allElementsBoundByIndex.last
    else {
      XCTFail("The new saved bookmark input is unavailable")
      return
    }
    alternateInput.activateForPlannerJourney()
    alternateInput.typeText(alternateURL)
    let draftIdentifier = alternateInput.identifier.replacingOccurrences(
      of: "saved.item.edit.link.url.", with: "")
    let label = application.textFields["saved.item.edit.link.label.\(draftIdentifier)"]
    XCTAssertTrue(label.waitForExistence(timeout: 5))
    label.activateForPlannerJourney()
    label.typeText("Alternate pin")
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let alternateLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", alternateURL)
    ).firstMatch
    revealDetailLink(alternateLink, in: application)
    XCTAssertTrue(alternateLink.waitForExistence(timeout: 10))
    let alternateIdentifier = alternateLink.identifier
    XCTAssertNotEqual(originalIdentifier, alternateIdentifier)
    returnToCatalog(application)
    application.plannerElement("saved.items.representation").activateForPlannerJourney()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let originalPin = application.buttons["saved.map.pin.35.0,139.0"]
    let alternatePin = application.buttons["saved.map.pin.36.0,140.0"]
    XCTAssertTrue(originalPin.waitForExistence(timeout: 10))
    XCTAssertFalse(alternatePin.exists)
    application.plannerElement("saved.map.locations").activateForPlannerJourney()
    let options = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.map.location.options.")
    ).firstMatch
    XCTAssertTrue(options.waitForExistence(timeout: 5))
    options.activateForPlannerJourney()
    let mapLinkChoice = application.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", "Map link")
    ).firstMatch
    XCTAssertTrue(mapLinkChoice.waitForExistence(timeout: 5))
    mapLinkChoice.activateForPlannerJourney()
    let alternateChoice = application.buttons["Alternate pin"].firstMatch
    XCTAssertTrue(alternateChoice.waitForExistence(timeout: 5))
    alternateChoice.activateForPlannerJourney()
    let close = application.buttons["Close"].firstMatch
    XCTAssertTrue(close.waitForPlannerHittability())
    close.activateForPlannerJourney()
    XCTAssertTrue(alternatePin.waitForExistence(timeout: 10))
    XCTAssertTrue(originalPin.waitForNonExistence(timeout: 5))
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Native collection Maps link picker keeps original bookmarks"
    capture.lifetime = .keepAlways
    add(capture)
    alternatePin.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    for (identifier, expectedURL) in [
      (originalIdentifier, originalURL), (alternateIdentifier, alternateURL),
    ] {
      let retainedLink = application.descendants(matching: .any).matching(identifier: identifier)
        .firstMatch
      revealDetailLink(retainedLink, in: application)
      XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedLink.value as? String, expectedURL)
    }
  }

  func testItineraryMapDistinguishesRepeatedStopsAndPreservesTheirLocalCompletion() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let originalURL = "https://www.google.com/maps/search/?api=1&query=35,139"
    createItem("Map museum", link: originalURL, in: application)
    createWeekendRoute(referencing: ["Map museum", "Map museum"], in: application)
    completeOnlyFirstRouteAppearance(in: application)
    verifyRepeatedMapStops(
      in: application, firstChoiceLabel: "Map museum · Stop 1",
      secondChoiceLabel: "Map museum · Stop 2", originalURL: originalURL,
      captureName: "Counted itinerary pin distinguishes independent repeated stops")
  }

  func testItineraryMapKeepsRepeatedListBranchesIndependentFromTheStandaloneList() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let originalURL = "https://www.google.com/maps/search/?api=1&query=35,139"
    createItem("Map museum", link: originalURL, in: application)
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Food stops")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.add").activateForPlannerJourney()
    let candidate = application.staticTexts["Map museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 10))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    let standaloneCompletion = application.buttons["Mark Map museum done in this List"].firstMatch
    XCTAssertTrue(standaloneCompletion.waitForExistence(timeout: 10))
    standaloneCompletion.activateForPlannerJourney()
    XCTAssertTrue(
      application.buttons["Mark Map museum undone in this List"].firstMatch
        .waitForExistence(timeout: 10))
    createWeekendRoute(referencing: ["Food stops", "Food stops"], in: application)
    completeOnlyFirstRouteAppearance(in: application)
    verifyRepeatedMapStops(
      in: application, firstChoiceLabel: "Map museum · Food stops · Stop 1 · Item 1",
      secondChoiceLabel: "Map museum · Food stops · Stop 2 · Item 1", originalURL: originalURL,
      captureName: "Counted itinerary List pin distinguishes independent child appearances")
  }

  func testListMapOpensTheLocallyCompletedMembershipWithoutCompletingTheSource() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let originalURL = "https://www.google.com/maps/search/?api=1&query=35,139"
    createItem("Map museum", link: originalURL, in: application)
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Garden visits")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.add").activateForPlannerJourney()
    let candidate = application.staticTexts["Map museum"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 10))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    let markDone = application.buttons["Mark Map museum done in this List"].firstMatch
    XCTAssertTrue(markDone.waitForExistence(timeout: 10))
    markDone.activateForPlannerJourney()
    XCTAssertTrue(
      application.buttons["Mark Map museum undone in this List"].firstMatch
        .waitForExistence(timeout: 10))
    application.openSavedPlannerListViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let pin = application.buttons["saved.map.pin.35.0,139.0"]
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    pin.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Garden visits"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.exists)
    XCTAssertTrue(application.plannerElement("saved.appearance.actions").exists)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "List Map opens its exact completed membership"
    capture.lifetime = .keepAlways
    add(capture)
    let link = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", originalURL)
    ).firstMatch
    revealDetailLink(link, in: application)
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    let bookmarkIdentifier = link.identifier
    application.openPlannerSection("Items")
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    if !completion.waitForExistence(timeout: 2) {
      let source = application.savedPlannerItemRows("Map museum").firstMatch
      XCTAssertTrue(source.waitForExistence(timeout: 10))
      source.activateForPlannerJourney()
    }
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: bookmarkIdentifier).firstMatch
    revealDetailLink(retainedLink, in: application)
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, originalURL)
  }

  func testCoincidentMarkerChoicesKeepDistinctSavedItemIdentities() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let museumURL = "https://www.google.com/maps/search/?api=1&query=35,139#museum"
    let cafeURL = "https://www.google.com/maps/search/?api=1&query=35,139#cafe"
    createItem("Map museum", link: museumURL, in: application)
    returnToCatalog(application)
    createItem("Map cafe", link: cafeURL, in: application)
    returnToCatalog(application)
    application.plannerElement("saved.items.representation").activateForPlannerJourney()
    application.plannerElement("saved.collection.showMap").activateForPlannerJourney()
    let pin = application.buttons.matching(identifier: "saved.map.pin.35.0,139.0")
      .matching(NSPredicate(format: "label == %@", "2 items")).firstMatch
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    XCTAssertTrue(pin.waitForPlannerHittability())
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Counted native Map marker keeps exact Item choices"
    capture.lifetime = .keepAlways
    add(capture)
    pin.activateForPlannerJourney()
    let museum = application.buttons["Map museum"].firstMatch
    let cafe = application.buttons["Map cafe"].firstMatch
    XCTAssertTrue(museum.waitForExistence(timeout: 5))
    XCTAssertTrue(cafe.exists)
    museum.activateForPlannerJourney()
    let museumLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", museumURL)
    ).firstMatch
    XCTAssertTrue(museumLink.waitForExistence(timeout: 10))
    let museumLinkIdentifier = museumLink.identifier
    returnToCatalog(application)
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    pin.activateForPlannerJourney()
    XCTAssertTrue(cafe.waitForExistence(timeout: 5))
    cafe.activateForPlannerJourney()
    let cafeLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", cafeURL)
    ).firstMatch
    XCTAssertTrue(cafeLink.waitForExistence(timeout: 10))
    XCTAssertNotEqual(cafeLink.identifier, museumLinkIdentifier)
    XCTAssertTrue(museumLink.waitForNonExistence(timeout: 5))
  }

  func testItemsMapOpensTheExactPinAndAnUnlocatedItemThroughNativeNavigation() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let originalURL = "https://www.google.com/maps/search/?api=1&query=35,139"
    createItem("Map museum", link: originalURL, in: application)
    returnToCatalog(application)
    createItem("Unlocated note", link: nil, in: application)
    returnToCatalog(application)
    let representation = application.plannerElement("saved.items.representation")
    XCTAssertTrue(representation.waitForExistence(timeout: 5))
    representation.activateForPlannerJourney()
    application.plannerElement("saved.collection.showMap").activateForPlannerJourney()
    let map = application.descendants(matching: .any).matching(identifier: "saved.map.collection")
      .firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    let pin = application.buttons["saved.map.pin.35.0,139.0"]
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    XCTAssertTrue(pin.waitForPlannerHittability())
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Native Items Map retains its pin and Locations control"
    capture.lifetime = .keepAlways
    add(capture)
    pin.activateForPlannerJourney()
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(savedLink.value as? String, originalURL)
    XCTAssertTrue(application.plannerElement("saved.item.actions").exists)
    returnToCatalog(application)
    application.plannerElement("saved.map.locations").activateForPlannerJourney()
    let unlocated = application.buttons["Unlocated note"].firstMatch
    XCTAssertTrue(unlocated.waitForExistence(timeout: 5))
    unlocated.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    XCTAssertTrue(savedLink.waitForNonExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Unlocated note"].firstMatch.exists)
  }

  private func createWeekendRoute(referencing sources: [String], in application: XCUIApplication) {
    application.openPlannerSection("Itineraries")
    let newItinerary = application.plannerElement("saved.itinerary.new")
    XCTAssertTrue(newItinerary.waitForExistence(timeout: 10))
    newItinerary.activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    let addEntry = application.plannerElement("saved.itinerary.entry.new")
    for source in sources {
      XCTAssertTrue(addEntry.waitForExistence(timeout: 10))
      addEntry.activateForPlannerJourney()
      let choice = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.entry.choice.",
          source)
      ).firstMatch
      XCTAssertTrue(choice.waitForExistence(timeout: 5))
      choice.activateForPlannerJourney()
      application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    }
  }

  private func completeOnlyFirstRouteAppearance(in application: XCUIApplication) {
    let rows = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
    XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 10))
    XCTAssertEqual(rows.count, 2)
    let firstIdentifier = rows.element(boundBy: 0).identifier
    let secondIdentifier = rows.element(boundBy: 1).identifier
    XCTAssertNotEqual(firstIdentifier, secondIdentifier)
    let firstCheck = application.plannerElement(
      firstIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
    let secondCheck = application.plannerElement(
      secondIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
    XCTAssertEqual(firstCheck.value as? String, "To do")
    XCTAssertEqual(secondCheck.value as? String, "To do")
    XCTAssertTrue(application.staticTexts["0 of 2 items done"].exists)
    firstCheck.activateForPlannerJourney()
    XCTAssertTrue(firstCheck.waitForPlannerValue("Completed"))
    XCTAssertEqual(secondCheck.value as? String, "To do")
    XCTAssertTrue(application.staticTexts["1 of 2 items done"].exists)
  }

  private func verifyRepeatedMapStops(
    in application: XCUIApplication, firstChoiceLabel: String, secondChoiceLabel: String,
    originalURL: String, captureName: String
  ) {
    application.openSavedPlannerItineraryViewMenu()
    application.chooseSavedPlannerCollectionRepresentation("Map")
    let pin = application.buttons["saved.map.pin.35.0,139.0"]
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    XCTAssertEqual(pin.label, "2 items")
    pin.activateForPlannerJourney()
    let firstStop = application.buttons[firstChoiceLabel].firstMatch
    let secondStop = application.buttons[secondChoiceLabel].firstMatch
    XCTAssertTrue(firstStop.waitForExistence(timeout: 5))
    XCTAssertTrue(secondStop.exists)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = captureName
    capture.lifetime = .keepAlways
    add(capture)
    firstStop.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.waitForExistence(timeout: 10))
    let link = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.", originalURL)
    ).firstMatch
    revealDetailLink(link, in: application)
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    let bookmarkIdentifier = link.identifier
    returnToCatalog(application, title: "Weekend route")
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    pin.activateForPlannerJourney()
    XCTAssertTrue(secondStop.waitForExistence(timeout: 5))
    secondStop.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["To do"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.item.completion").exists)
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: bookmarkIdentifier).firstMatch
    revealDetailLink(retainedLink, in: application)
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, originalURL)
  }

  private func revealDetailLink(_ link: XCUIElement, in application: XCUIApplication) {
    #if os(iOS)
      guard let form = application.collectionViews.allElementsBoundByIndex.last(where: \.isHittable)
      else {
        XCTFail("The selected Item detail form is unavailable")
        return
      }
      let usesAccessibilityText =
        UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
      let maximumScrolls = usesAccessibilityText ? 12 : 4
      let horizontalPosition = usesAccessibilityText ? 24 / form.frame.width : 0.98
      for _ in 0..<maximumScrolls where !link.exists {
        let start = form.coordinate(
          withNormalizedOffset: CGVector(dx: horizontalPosition, dy: 0.75))
        let end = form.coordinate(
          withNormalizedOffset: CGVector(dx: horizontalPosition, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: end)
      }
    #endif
  }

  private func createItem(_ name: String, link: String?, in application: XCUIApplication) {
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText(name)
    if let link {
      let addLink = application.plannerElement("saved.item.link.add")
      for _ in 0..<6 where !addLink.isHittable { application.swipeUp() }
      XCTAssertTrue(addLink.isHittable)
      addLink.activateForPlannerJourney()
      let input = application.textFields.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.url.")
      ).firstMatch
      XCTAssertTrue(input.waitForExistence(timeout: 5))
      input.activateForPlannerJourney()
      input.typeText(link)
    }
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
  }

  private func returnToCatalog(_ application: XCUIApplication, title: String = "Items") {
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .phone {
        let back = application.navigationBars.buttons[title].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.activateForPlannerJourney()
      }
    #endif
  }
}
