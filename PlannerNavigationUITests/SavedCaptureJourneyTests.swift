import XCTest

@MainActor
final class SavedCaptureJourneyTests: XCTestCase {
  func testAppleMapsPreviewYieldsToAnOwnedAddressWithoutChangingTheBookmark() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    let originalURL = "https://maps.apple.com/place?name=Museum&coordinate=35,139#retained"
    openCapture(application, input: originalURL)
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    replace(title, with: "Apple Maps bookmark")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let map = application.descendants(matching: .any)
      .matching(identifier: "saved.item.maps.preview.map").firstMatch
    revealSavedMap(map, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.staticTexts["Place details come from this Maps link and haven't been verified."]
        .exists)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    let address = application.textFields["saved.item.edit.location.address"]
    revealSavedMap(address, application: application)
    XCTAssertTrue(address.waitForExistence(timeout: 5))
    XCTAssertEqual(address.value as? String, address.placeholderValue)
    replace(address, with: "1 Apple Park Way, Cupertino, CA")
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let savedAddress = application.staticTexts["1 Apple Park Way, Cupertino, CA"]
    revealSavedMap(savedAddress, application: application)
    XCTAssertTrue(savedAddress.waitForExistence(timeout: 10))
    XCTAssertFalse(map.exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Owned address takes precedence over the saved Apple Maps bookmark"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let row = application.savedPlannerItemRows("Apple Maps bookmark").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    revealSavedMap(savedAddress, application: application)
    XCTAssertTrue(savedAddress.waitForExistence(timeout: 10))
    XCTAssertFalse(map.exists)
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    revealSavedMap(link, application: application)
    XCTAssertEqual(link.value as? String, originalURL)
  }

  func testGoogleTextSearchRetainsAUsefulFallbackWithoutInventingAMapPin() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    let originalURL = "https://www.google.com/maps/search/?api=1&query=museums+near+Tokyo"
    openCapture(application, input: originalURL)
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    replace(title, with: "Museum search")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let fallback = application.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", "Open saved Maps link")).firstMatch
    revealSavedMap(fallback, application: application)
    XCTAssertTrue(fallback.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["museums near Tokyo"].exists)
    XCTAssertFalse(
      application.descendants(matching: .any)
        .matching(identifier: "saved.item.maps.preview.map").firstMatch.exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Google text search stays a search with a useful saved-link fallback"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testGoogleMapsCaptureShowsATemporarySavedMapAndRetainsItsBookmarkAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    let originalURL =
      "https://www.google.com/maps/search/?api=1&query=35.6804%2C139.7690#original-fragment"
    openCapture(application, input: originalURL)
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    replace(title, with: "Tokyo search location")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let map = application.descendants(matching: .any)
      .matching(identifier: "saved.item.maps.preview.map").firstMatch
    revealSavedMap(map, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Search location"].firstMatch.exists)
    XCTAssertTrue(
      application.staticTexts["Place details haven't been verified for this search link."]
        .exists)
    #if os(macOS)
      let snapshot = application.windows.firstMatch.screenshot()
    #else
      let snapshot = application.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: snapshot)
    attachment.name = "Saved Google Maps search location uses the native map"
    attachment.lifetime = .keepAlways
    add(attachment)
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    revealSavedMap(link, application: application)
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    XCTAssertEqual(link.value as? String, originalURL)
    let linkIdentifier = link.identifier
    #if os(macOS)
      let sourceRows = application.buttons.matching(
        NSPredicate(format: "identifier MATCHES %@", "saved[.]item[.][0-9A-Fa-f-]{36}"))
      XCTAssertEqual(sourceRows.count, 1)
      let sourceIdentifier = sourceRows.firstMatch.identifier
    #endif

    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    #if os(macOS)
      let row = application.buttons.matching(identifier: sourceIdentifier).firstMatch
    #else
      let row = application.savedPlannerItemRows("Tokyo search location").firstMatch
    #endif
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(row.label, "Tokyo search location")
    row.activateForPlannerJourney()
    revealSavedMap(map, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    let restoredLink = application.descendants(matching: .any)
      .matching(identifier: linkIdentifier).firstMatch
    revealSavedMap(restoredLink, application: application)
    XCTAssertEqual(restoredLink.value as? String, originalURL)
  }

  func testUntouchedSavedLinkDraftCanBeAddedWithoutAnEmptyEdit() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    openCapture(application, input: "https://example.com/untouched?keep=original")
    XCTAssertTrue(application.textFields["saved.capture.title"].waitForExistence(timeout: 10))
    XCTAssertEqual(application.textFields["saved.capture.title"].value as? String, "Saved link")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    XCTAssertEqual(link.value as? String, "https://example.com/untouched?keep=original")
  }

  func testExactLinkReusePreservesDoneArchivedContentAndRememberedListWithoutDuplicates() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let newList = application.plannerElement("saved.list.new")
    if !newList.waitForExistence(timeout: 3) {
      application.plannerElement("Show Sidebar").activateForPlannerJourney()
    }
    XCTAssertTrue(newList.waitForExistence(timeout: 5))
    newList.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Capture destination")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openItems(application)
    openCapture(application, input: "https://example.com/reuse?keep=exact")
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    replace(title, with: "Keep original")
    let notes = application.textFields["saved.capture.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Owned original notes")
    let destination = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.list.")
    ).firstMatch
    for _ in 0..<4 where !destination.exists || !destination.isHittable { application.swipeUp() }
    XCTAssertTrue(destination.waitForPlannerBooleanState(false))
    #if os(macOS)
      destination.activateForPlannerJourney()
    #else
      destination.switches.firstMatch.activateForPlannerJourney()
    #endif
    XCTAssertTrue(destination.waitForPlannerBooleanState(true))
    let reviewAttachment = XCTAttachment(screenshot: application.screenshot())
    reviewAttachment.name = "Native capture review selects a live List destination"
    reviewAttachment.lifetime = .keepAlways
    add(reviewAttachment)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Owned original notes"].waitForExistence(timeout: 10))
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    #if os(macOS)
      completion.activateForPlannerJourney()
    #else
      completion.switches.firstMatch.activateForPlannerJourney()
    #endif
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].firstMatch.waitForExistence(timeout: 10))
    let originalLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    let originalLinkIdentifier = originalLink.identifier

    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    openCapture(application, input: "https://example.com/reuse?keep=exact")
    let choice = application.plannerElement("saved.capture.choice")
    XCTAssertTrue(choice.waitForExistence(timeout: 10))
    XCTAssertTrue(
      choice.label.contains("Use existing: Keep original")
        || (choice.value as? String)?.contains("Use existing: Keep original") == true,
      choice.debugDescription)
    XCTAssertFalse(title.exists)
    XCTAssertTrue(destination.waitForPlannerBooleanState(true))
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Owned original notes"].waitForExistence(timeout: 10))
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    XCTAssertTrue(application.staticTexts["Archived"].firstMatch.exists)
    XCTAssertTrue(
      application.descendants(matching: .any)
        .matching(identifier: originalLinkIdentifier).firstMatch.exists)
    XCTAssertEqual(
      application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
      ).count, 1)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    application.plannerElement("saved.items.filters").activateForPlannerJourney()
    application.plannerElement("Clear Filters").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    let originalRow = application.savedPlannerItemRows("Keep original").firstMatch
    XCTAssertTrue(originalRow.waitForExistence(timeout: 10))
    let itemRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier MATCHES %@", "saved\\.item\\.[0-9A-Fa-f-]{36}"))
    XCTAssertEqual(itemRows.count, 1)
    originalRow.activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any)
        .matching(identifier: originalLinkIdentifier).firstMatch.waitForExistence(timeout: 5))
  }

  func testReviewedCaptureEstimateShortcutsCancelWithoutSavingAndPersistOneInboxItem() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    openCapture(application, input: "https://example.com/visit?source=original")
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.value as? String, "Saved link")
    replace(title, with: "Cancelled capture")
    #if os(iOS)
      title.typeText("\n")
    #endif
    chooseCaptureEstimateShortcut("Half-day (12 hours)", application: application)
    assertCaptureEstimateQuantity("12", unit: "Hours", application: application)
    #if os(iOS)
      let reviewScreenshot = XCUIScreen.main.screenshot()
    #else
      let reviewScreenshot = application.windows.firstMatch.screenshot()
    #endif
    let reviewAttachment = XCTAttachment(screenshot: reviewScreenshot)
    reviewAttachment.name = "Native capture review keeps the staged estimate before Cancel"
    reviewAttachment.lifetime = .keepAlways
    add(reviewAttachment)
    application.plannerElement("saved.capture.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))

    openCapture(application, input: "https://example.com/visit?source=original")
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    replace(title, with: "Museum capture")
    #if os(iOS)
      title.typeText("\n")
    #endif
    chooseCaptureEstimateShortcut("Full-day (24 hours)", application: application)
    assertCaptureEstimateQuantity("1", unit: "Days", application: application)
    chooseCaptureEstimateShortcut("Weekend (48 hours)", application: application)
    assertCaptureEstimateQuantity("2", unit: "Days", application: application)
    let notes = application.textFields["saved.capture.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Bring the museum pass")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Bring the museum pass"].waitForExistence(timeout: 10))
    let estimate = application.descendants(matching: .any).matching(
      identifier: "saved.item.estimate"
    ).firstMatch
    assertWeekendEstimate(estimate)
    let link = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    XCTAssertEqual(link.value as? String, "https://example.com/visit?source=original")
    let retainedLinkIdentifier = link.identifier
    #if os(macOS)
      let snapshot = application.windows.firstMatch.screenshot()
    #else
      let snapshot = application.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: snapshot)
    attachment.name = "Reviewed native capture saves Weekend estimate notes and original link"
    attachment.lifetime = .keepAlways
    add(attachment)

    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Inbox")
    let row = application.savedPlannerItemRows("Museum capture").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Museum capture").count, 1)
    XCTAssertEqual(application.savedPlannerItemRows("Cancelled capture").count, 0)
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Bring the museum pass"].waitForExistence(timeout: 5))
    let restoredLink = application.descendants(matching: .any)
      .matching(identifier: retainedLinkIdentifier).firstMatch
    XCTAssertTrue(restoredLink.waitForExistence(timeout: 5))
    XCTAssertEqual(restoredLink.value as? String, "https://example.com/visit?source=original")
    assertWeekendEstimate(estimate)
    XCTAssertEqual(
      application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
      ).count, 0)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    let quantity = application.descendants(matching: .any).matching(
      identifier: "saved.item.edit.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(quantity.waitForPlannerValue("2"))
    #if os(macOS)
      XCTAssertTrue(
        application.popUpButtons["saved.item.edit.estimate.unit"].waitForPlannerValue("Days"))
    #else
      XCTAssertTrue(
        application.plannerElement("saved.item.edit.estimate.unit").label.contains("Days"))
    #endif
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    assertWeekendEstimate(estimate)
  }

  private func assertWeekendEstimate(_ estimate: XCUIElement) {
    let expected = NSPredicate(format: "value MATCHES %@", "2[\\s,]?880 minutes")
    XCTAssertTrue(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: expected, object: estimate)], timeout: 5)
        == .completed,
      "Estimate label: \(estimate.label), value: \(String(describing: estimate.value))")
  }

  private func chooseCaptureEstimateShortcut(_ title: String, application: XCUIApplication) {
    let shortcuts = application.plannerElement("saved.capture.estimate.shortcuts")
    XCTAssertTrue(shortcuts.waitForPlannerHittability())
    shortcuts.activateForPlannerJourney()
    let choice = application.plannerElement(title)
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
  }

  private func assertCaptureEstimateQuantity(
    _ quantity: String, unit: String, application: XCUIApplication
  ) {
    let control = application.descendants(matching: .any).matching(
      identifier: "saved.capture.estimate.quantity"
    ).firstMatch
    XCTAssertTrue(control.waitForPlannerValue(quantity))
    #if os(macOS)
      let unitPicker = application.popUpButtons["saved.capture.estimate.unit"]
      XCTAssertTrue(
        unitPicker.waitForPlannerValue(unit),
        "Expected \(unit); label: \(unitPicker.label), value: \(String(describing: unitPicker.value))"
      )
    #else
      XCTAssertTrue(application.plannerElement("saved.capture.estimate.unit").label.contains(unit))
    #endif
  }

  private func openItems(_ application: XCUIApplication) {
    application.openPlannerSection("Items")
  }

  private func openCapture(_ application: XCUIApplication, input: String) {
    application.openSavedPlannerCatalogAddMenu()
    let capture = application.plannerElement("saved.capture.new")
    XCTAssertTrue(capture.waitForExistence(timeout: 10))
    capture.activateForPlannerJourney()
    let field = application.textFields["saved.capture.input"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(input)
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
  }

  private func replace(_ field: XCUIElement, with value: String) {
    field.activateForPlannerJourney()
    #if os(macOS)
      field.typeKey("a", modifierFlags: .command)
      field.typeText(value)
    #else
      let existing = field.value as? String ?? ""
      field.typeText(
        String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + value)
    #endif
    XCTAssertEqual(field.value as? String, value)
  }

  private func revealSavedMap(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<6 where !element.exists || !element.isHittable {
      #if os(macOS)
        let form =
          application.scrollViews.allElementsBoundByIndex.last
          ?? application.scrollViews.firstMatch
        form.swipeUp()
      #else
        let editorForm = application.collectionViews.containing(
          .any, identifier: "saved.item.edit.title"
        ).firstMatch
        let detailsForm = application.collectionViews.containing(
          .any, identifier: "saved.item.completion"
        ).firstMatch
        let form = editorForm.exists ? editorForm : detailsForm
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        let start = form.coordinate(withNormalizedOffset: .init(dx: 0.97, dy: 0.8))
        let end = form.coordinate(withNormalizedOffset: .init(dx: 0.97, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: end)
      #endif
    }
  }
}
