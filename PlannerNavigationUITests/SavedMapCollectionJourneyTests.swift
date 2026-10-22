import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class SavedMapCollectionJourneyTests: XCTestCase {
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

  private func returnToCatalog(_ application: XCUIApplication) {
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .phone {
        let back = application.navigationBars.buttons["Items"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.activateForPlannerJourney()
      }
    #endif
  }
}
