import XCTest

@MainActor
final class SavedCaptureFieldsJourneyTests: XCTestCase {
  func testEditingOnlyReuseLinkRequiresExplicitReselectionWithoutCreatingAnItem() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    openCapture(application)
    replace(
      application.textFields["saved.capture.title"], with: "Keep original",
      application: application)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    openCapture(application)
    let choice = application.plannerElement("saved.capture.choice")
    XCTAssertTrue(choice.waitForExistence(timeout: 10))
    XCTAssertTrue(
      choice.label.contains("Use existing: Keep original")
        || (choice.value as? String)?.contains("Use existing: Keep original") == true)
    let link = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.url.")
    ).firstMatch
    replace(link, with: "https://example.com/changed", application: application)
    let add = application.plannerElement("saved.capture.add")
    add.activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: add)
        ],
        timeout: 5), .completed)
    XCTAssertTrue(
      choice.label.contains("Selected Item no longer matches")
        || (choice.value as? String)?.contains("Selected Item no longer matches") == true)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    let original = application.savedPlannerItemRows("Keep original").firstMatch
    XCTAssertTrue(original.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Keep original").count, 1)
    XCTAssertEqual(application.savedPlannerItemRows("Saved link").count, 0)
    original.activateForPlannerJourney()
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 5))
    XCTAssertEqual(savedLink.value as? String, "https://example.com/owned?keep=%41")
  }

  func testCaptureSharedLabelsRemainStagedUntilAddAndPersistAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    createLabel("Category", name: "Culture", application: application)
    createLabel("Tag", name: "Rain", application: application)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItems(application)
    openCapture(application)
    selectLabel("Categories", name: "Culture", application: application)
    selectLabel("Tags", name: "Rain", application: application)
    scrollableCapture(application).swipeDown()
    replace(
      application.textFields["saved.capture.title"], with: "Cancelled labeled capture",
      application: application)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    openCapture(application)
    selectLabel("Categories", name: "Culture", application: application)
    selectLabel("Tags", name: "Rain", application: application)
    scrollableCapture(application).swipeDown()
    replace(
      application.textFields["saved.capture.title"], with: "Labeled capture",
      application: application)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Culture"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.exists)
    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Native capture saves selected shared Categories and Tags"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    application.terminate()
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.plannerElement("saved.section.inbox").activateForPlannerJourney()
    #else
      application.buttons["Inbox"].firstMatch.activateForPlannerJourney()
    #endif
    let row = application.savedPlannerItemRows("Labeled capture").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Labeled capture").count, 1)
    XCTAssertEqual(application.savedPlannerItemRows("Cancelled labeled capture").count, 0)
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Culture"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.exists)
  }

  func testRemovingOnlyLinkDoesNotPromoteAutomaticTitleIntoOwnedText() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    openCapture(application)
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForPlannerValue("Saved link"))
    let actions = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.actions.")
    ).firstMatch
    reveal(actions, application: application)
    actions.activateForPlannerJourney()
    application.plannerElement("Remove Link").activateForPlannerJourney()
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    for _ in 0..<4 where !title.exists || !title.isHittable {
      scrollableCapture(application).swipeDown()
    }
    let emptyTitle = NSPredicate(format: "value == %@ OR value == %@", "", "Title")
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: emptyTitle, object: title)], timeout: 5),
      .completed)
    XCTAssertFalse(application.plannerElement("saved.capture.add").isEnabled)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
  }

  func testOwnedCaptureFieldsAndLinkLabelPersistAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    openCapture(application)
    let subtitle = application.textFields["saved.capture.subtitle"]
    XCTAssertTrue(subtitle.waitForExistence(timeout: 10))
    enter("Afternoon visit", into: subtitle, application: application)
    let title = application.textFields["saved.capture.title"]
    replace(title, with: "Owned capture", application: application)
    let estimate = application.descendants(matching: .any)
      .matching(identifier: "saved.capture.estimate.enabled").firstMatch
    reveal(estimate, application: application)
    XCTAssertTrue(estimate.waitForPlannerBooleanState(false))
    #if os(macOS)
      estimate.activateForPlannerJourney()
    #else
      estimate.switches.firstMatch.activateForPlannerJourney()
    #endif
    XCTAssertTrue(estimate.waitForPlannerBooleanState(true))
    let name = application.textFields["saved.capture.location.name"]
    enter("My meeting point", into: name, application: application)
    let address = application.textFields["saved.capture.location.address"]
    enter("Independently entered address", into: address, application: application)
    let linkLabel = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.label.")
    ).firstMatch
    enter("My guide", into: linkLabel, application: application)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Afternoon visit"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["My meeting point"].exists)
    XCTAssertTrue(application.staticTexts["Independently entered address"].exists)
    let summary = application.descendants(matching: .any)
      .matching(identifier: "saved.item.estimate").firstMatch
    XCTAssertTrue(summary.waitForPlannerValue("60 minutes"))
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    XCTAssertEqual(link.label, "My guide")
    XCTAssertEqual(link.value as? String, "https://example.com/owned?keep=%41")
    let savedLinkIdentifier = link.identifier
    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Native capture owns subtitle estimate location and bookmark label"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    application.terminate()
    application.launchSavedPlannerJourney()
    #if os(macOS)
      application.plannerElement("saved.section.inbox").activateForPlannerJourney()
    #else
      application.buttons["Inbox"].firstMatch.activateForPlannerJourney()
    #endif
    let row = application.savedPlannerItemRows("Owned capture").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Afternoon visit"].waitForExistence(timeout: 5))
    XCTAssertTrue(summary.waitForPlannerValue("60 minutes"))
    let restoredLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(restoredLink.waitForExistence(timeout: 5))
    XCTAssertEqual(restoredLink.label, "My guide")
    XCTAssertEqual(restoredLink.value as? String, "https://example.com/owned?keep=%41")
    XCTAssertTrue(application.staticTexts["My meeting point"].exists)
    XCTAssertTrue(application.staticTexts["Independently entered address"].exists)
  }

  private func openItems(_ application: XCUIApplication) {
    #if os(macOS)
      application.plannerElement("saved.section.items").activateForPlannerJourney()
    #else
      application.buttons["Items"].firstMatch.activateForPlannerJourney()
    #endif
  }

  private func createLabel(_ kind: String, name: String, application: XCUIApplication) {
    application.plannerElement("saved.labels.new").activateForPlannerJourney()
    application.plannerElement("New \(kind)").activateForPlannerJourney()
    let field = application.textFields["saved.\(kind.lowercased()).name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(name)
    application.plannerElement("saved.\(kind.lowercased()).save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
  }

  private func openLabels(_ application: XCUIApplication) {
    let labels = application.plannerElement("saved.categories.manage")
    if !labels.waitForExistence(timeout: 3) || !labels.isHittable {
      #if os(macOS)
        application.plannerElement("saved.section.lists").activateForPlannerJourney()
      #else
        application.buttons["Lists"].firstMatch.activateForPlannerJourney()
      #endif
      if !labels.waitForExistence(timeout: 2) || !labels.isHittable {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists {
          sidebar.activateForPlannerJourney()
        } else {
          application.plannerElement("BackButton").activateForPlannerJourney()
        }
      }
    }
    XCTAssertTrue(labels.waitForExistence(timeout: 10))
    labels.activateForPlannerJourney()
  }

  private func selectLabel(_ kind: String, name: String, application: XCUIApplication) {
    let picker = application.plannerElement("saved.capture.\(kind.lowercased())")
    reveal(picker, application: application)
    picker.activateForPlannerJourney()
    let toggle = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.label.", name)
    ).firstMatch
    XCTAssertTrue(toggle.waitForExistence(timeout: 5))
    XCTAssertTrue(toggle.waitForPlannerBooleanState(false))
    #if os(macOS)
      toggle.activateForPlannerJourney()
    #else
      toggle.switches.firstMatch.activateForPlannerJourney()
    #endif
    XCTAssertTrue(toggle.waitForPlannerBooleanState(true))
    application.plannerElement("saved.item.labels.done").activateForPlannerJourney()
  }

  private func openCapture(_ application: XCUIApplication) {
    let capture = application.plannerElement("saved.capture.new")
    XCTAssertTrue(capture.waitForExistence(timeout: 10))
    capture.activateForPlannerJourney()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    input.typeText("https://example.com/owned?keep=%41")
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
  }

  private func reveal(_ element: XCUIElement, application: XCUIApplication) {
    if isVisible(element, application: application) { return }
    for _ in 0..<8 {
      scrollableCapture(application).swipeUp()
      if isVisible(element, application: application) { return }
    }
    XCTAssertTrue(isVisible(element, application: application), element.debugDescription)
  }

  private func scrollableCapture(_ application: XCUIApplication) -> XCUIElement {
    #if os(macOS)
      let scrollable = application.scrollViews.allElementsBoundByIndex.last
    #else
      let scrollable = application.collectionViews.allElementsBoundByIndex.last
    #endif
    guard let scrollable else {
      XCTFail("The native capture Form is unavailable.", file: #filePath, line: #line)
      return application
    }
    return scrollable
  }

  private func isVisible(_ element: XCUIElement, application: XCUIApplication) -> Bool {
    guard element.exists && element.isHittable else { return false }
    #if os(macOS)
      return true
    #else
      let keyboard = application.keyboards.firstMatch
      let bottom = keyboard.exists ? keyboard.frame.minY : application.windows.firstMatch.frame.maxY
      return element.frame.maxY < bottom - 10
    #endif
  }

  private func enter(_ text: String, into element: XCUIElement, application: XCUIApplication) {
    reveal(element, application: application)
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    element.activateForPlannerJourney()
    element.typeText(text)
  }

  private func replace(_ element: XCUIElement, with text: String, application: XCUIApplication) {
    reveal(element, application: application)
    element.activateForPlannerJourney()
    let value = element.value as? String ?? ""
    element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count) + text)
  }
}
