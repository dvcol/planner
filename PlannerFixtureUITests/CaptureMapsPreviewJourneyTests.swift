import XCTest

@MainActor
final class CaptureMapsPreviewJourneyTests: XCTestCase {
  func testRevertingAChangedLinkDuringLookupRetainsAnExplicitPreviewRetry() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCaptureEditor()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    input.typeText("My visit\nhttps://maps.apple.com/place?name=Museum&coordinate=35,139")
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.capture.title"].waitForExistence(timeout: 10))
    let loading = application.descendants(matching: .any).matching(
      identifier: "saved.capture.preview.loading"
    ).firstMatch
    for _ in 0..<4 {
      if loading.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(loading.exists)
    let label = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.label.")
    ).firstMatch
    XCTAssertTrue(label.isHittable)
    label.activateForPlannerJourney()
    label.typeText("X")
    label.typeText(XCUIKeyboardKey.delete.rawValue)
    let retry = application.plannerElement("saved.capture.preview.retry")
    XCTAssertTrue(retry.waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["saved.capture.preview.title"].exists)
    XCTAssertTrue(application.plannerElement("saved.capture.add").isEnabled)
    retry.activateForPlannerJourney()
    let previewTitle = application.staticTexts["saved.capture.preview.title"]
    XCTAssertTrue(previewTitle.waitForExistence(timeout: 10))
    XCTAssertEqual(previewTitle.label, "Museum")
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["My visit"].waitForExistence(timeout: 10))
    assertOwnedLocationIsEmpty(application, expectedTitle: "My visit")
  }

  func testEditedMapsLinksChooseTheFirstAvailableSourceAndRepairRemovedSelection() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCaptureEditor()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    input.typeText("My route\nhttps://example.com/visit")
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.capture.title"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["saved.capture.preview.title"].exists)
    let firstField = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.url.")
    ).firstMatch
    reveal(firstField, application: application)
    replace(
      firstField, with: "https://maps.apple.com/place?name=Museum&coordinate=35,139",
      application: application)
    let refresh = application.plannerElement("saved.capture.preview.refresh")
    reveal(refresh, application: application)
    refresh.activateForPlannerJourney()
    let previewTitle = application.staticTexts["saved.capture.preview.title"]
    XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
    XCTAssertEqual(previewTitle.label, "Museum")
    let addLink = application.plannerElement("saved.capture.link.add")
    reveal(addLink, application: application)
    addLink.activateForPlannerJourney()
    let secondField = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.url.")
    ).element(boundBy: 1)
    reveal(secondField, application: application)
    secondField.activateForPlannerJourney()
    let second = "https://maps.apple.com/place?name=Cafe&coordinate=36,140"
    secondField.typeText(second)
    reveal(refresh, application: application)
    refresh.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.capture.preview.source").waitForExistence(timeout: 5))
    XCTAssertEqual(previewTitle.label, "Museum")
    let firstActions = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.actions.")
    ).firstMatch
    reveal(firstActions, application: application)
    firstActions.activateForPlannerJourney()
    application.buttons["Remove Link"].activateForPlannerJourney()
    reveal(refresh, application: application)
    refresh.activateForPlannerJourney()
    let repairedPreview = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Cafe"), object: previewTitle)
    XCTAssertEqual(XCTWaiter.wait(for: [repairedPreview], timeout: 5), .completed)
    XCTAssertFalse(application.plannerElement("saved.capture.preview.source").exists)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["My route"].waitForExistence(timeout: 10))
    let savedLinks = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    )
    revealSavedDetail(savedLinks.firstMatch, application: application)
    XCTAssertTrue(savedLinks.firstMatch.waitForExistence(timeout: 5))
    XCTAssertEqual(savedLinks.count, 1)
    XCTAssertEqual(savedLinks.firstMatch.value as? String, second)
    XCTAssertFalse(application.staticTexts["Museum"].exists)
    assertOwnedLocationIsEmpty(application, expectedTitle: "My route")
  }

  func testRemovingTheOnlyMapsLinkThenRefreshingDoesNotSaveAnAutomaticTitle() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCaptureEditor()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    input.typeText("https://maps.apple.com/place?name=Museum&coordinate=35,139")
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.value as? String, "Saved link")
    let actions = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.actions.")
    ).firstMatch
    for _ in 0..<6 {
      if actions.isHittable { break }
      application.swipeUp()
    }
    XCTAssertTrue(actions.exists)
    actions.activateForPlannerJourney()
    application.buttons["Remove Link"].activateForPlannerJourney()
    let refresh = application.plannerElement("saved.capture.preview.refresh")
    XCTAssertTrue(refresh.waitForExistence(timeout: 5))
    refresh.activateForPlannerJourney()
    let add = application.plannerElement("saved.capture.add")
    let cannotSaveFallback = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "enabled == false"), object: add)
    XCTAssertEqual(XCTWaiter.wait(for: [cannotSaveFallback], timeout: 5), .completed)
    XCTAssertFalse(application.staticTexts["saved.capture.preview.title"].exists)
    for _ in 0..<6 {
      if title.isHittable { break }
      application.swipeDown()
    }
    let emptyTitle = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@ OR value == %@", "", "Title"), object: title)
    XCTAssertEqual(XCTWaiter.wait(for: [emptyTitle], timeout: 5), .completed)
    title.activateForPlannerJourney()
    title.typeText("A deliberate visit")
    add.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["A deliberate visit"].waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Saved link").count, 0)
    XCTAssertFalse(application.staticTexts["Museum"].exists)
  }

  func testCancelDuringLookupLeavesNoSavedItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCaptureEditor()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    input.typeText("Discarded visit\nhttps://maps.apple.com/place?name=Museum&coordinate=35,139")
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.capture.title"].waitForExistence(timeout: 10))
    let loading = application.descendants(matching: .any).matching(
      identifier: "saved.capture.preview.loading"
    ).firstMatch
    for _ in 0..<4 {
      if loading.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(loading.exists, application.debugDescription)
    let cancel = application.plannerElement("saved.capture.cancel")
    XCTAssertTrue(cancel.isEnabled)
    cancel.activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Existing").firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Discarded visit").count, 0)
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(
      application.savedPlannerItemRows("Existing").firstMatch.waitForExistence(timeout: 20))
    XCTAssertEqual(application.savedPlannerItemRows("Discarded visit").count, 0)
    XCTAssertFalse(application.staticTexts["saved.capture.preview.title"].exists)
  }

  func testAddRemainsAvailableDuringLookupAndPersistsOnePartialItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCaptureEditor()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    let original = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
    input.typeText("Partial visit\n" + original)
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.capture.title"].waitForExistence(timeout: 10))
    let loading = application.descendants(matching: .any).matching(
      identifier: "saved.capture.preview.loading"
    ).firstMatch
    for _ in 0..<4 {
      if loading.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(loading.exists, application.debugDescription)
    XCTAssertFalse(application.staticTexts["saved.capture.preview.title"].exists)
    let add = application.plannerElement("saved.capture.add")
    XCTAssertTrue(add.isEnabled)
    add.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[original].waitForExistence(timeout: 10))
    assertOwnedLocationIsEmpty(application, expectedTitle: "Partial visit")
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let rows = application.savedPlannerItemRows("Partial visit")
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20))
    XCTAssertEqual(rows.count, 1)
    rows.firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[original].waitForExistence(timeout: 10))
    assertOwnedLocationIsEmpty(application, expectedTitle: "Partial visit")
  }

  func testUnavailablePreviewOffersExplicitRetryWithoutBlockingOrReplacingOwnedFields() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps-retry", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCaptureEditor()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    let original = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
    input.typeText("My saved visit\n" + original)
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.value as? String, "My saved visit")
    let unavailable = application.staticTexts["saved.capture.preview.unavailable"]
    for _ in 0..<6 {
      if unavailable.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["saved.capture.preview.title"].exists)
    XCTAssertTrue(application.plannerElement("saved.capture.add").isEnabled)
    application.plannerElement("saved.capture.preview.retry").activateForPlannerJourney()
    let previewTitle = application.staticTexts["saved.capture.preview.title"]
    XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
    XCTAssertEqual(previewTitle.label, "Museum")
    XCTAssertTrue(unavailable.waitForNonExistence(timeout: 5))
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["My saved visit"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts[original].exists)
    assertOwnedLocationIsEmpty(application, expectedTitle: "My saved visit")
  }

  func testEditingTheOriginalLinkHidesItsPreviewUntilExplicitRefresh() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCaptureEditor()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    let original = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
    let replacement = "https://maps.apple.com/place?name=Cafe&coordinate=36,140"
    input.typeText("Evening visit\n" + original)
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.capture.title"].waitForExistence(timeout: 10))
    let previewTitle = application.staticTexts["saved.capture.preview.title"]
    for _ in 0..<6 {
      if previewTitle.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
    XCTAssertEqual(previewTitle.label, "Museum")
    let originalField = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.capture.link.url.")
    )
    .firstMatch
    for _ in 0..<6 {
      if originalField.isHittable { break }
      application.swipeDown()
    }
    XCTAssertTrue(originalField.exists)
    originalField.activateForPlannerJourney()
    replace(originalField, with: replacement, application: application)
    application.swipeUp()
    XCTAssertFalse(previewTitle.exists)
    let refresh = application.plannerElement("saved.capture.preview.refresh")
    for _ in 0..<6 {
      if refresh.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(refresh.waitForExistence(timeout: 5))
    refresh.activateForPlannerJourney()
    let refreshedPreview = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Cafe"), object: previewTitle)
    XCTAssertEqual(XCTWaiter.wait(for: [refreshedPreview], timeout: 5), .completed)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Evening visit"].waitForExistence(timeout: 10))
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    revealSavedDetail(savedLink, application: application)
    XCTAssertTrue(savedLink.waitForExistence(timeout: 5))
    XCTAssertEqual(savedLink.value as? String, replacement)
    XCTAssertFalse(application.staticTexts["Museum"].exists)
    assertOwnedLocationIsEmpty(application, expectedTitle: "Evening visit")
    XCTAssertTrue(application.staticTexts[original].exists)
  }

  func testSelectingAnotherMapsLinkChangesOnlyTheTemporaryPreview() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCatalogAddMenu()
    let capture = application.plannerElement("saved.capture.new")
    XCTAssertTrue(capture.waitForExistence(timeout: 10))
    capture.activateForPlannerJourney()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    let first = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
    let second = "https://maps.apple.com/place?name=Cafe&coordinate=36,140"
    input.typeText("My route\n" + first + "\n" + second)
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.value as? String, "My route")
    let sourcePicker = application.plannerElement("saved.capture.preview.source")
    for _ in 0..<6 {
      if sourcePicker.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(sourcePicker.waitForExistence(timeout: 5))
    XCTAssertEqual(application.staticTexts["saved.capture.preview.title"].label, "Museum")
    sourcePicker.activateForPlannerJourney()
    application.buttons[second].activateForPlannerJourney()
    let changedPreview = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Cafe"),
      object: application.staticTexts["saved.capture.preview.title"])
    XCTAssertEqual(XCTWaiter.wait(for: [changedPreview], timeout: 5), .completed)
    XCTAssertTrue(application.plannerElement("saved.capture.add").isEnabled)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Selecting a Maps link changes its temporary native preview"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[first + "\n" + second].waitForExistence(timeout: 10))
    assertOwnedLocationIsEmpty(application, expectedTitle: "My route")
    let savedSourcePicker = application.plannerElement("saved.item.maps.preview.source")
    revealSavedDetail(savedSourcePicker, application: application)
    XCTAssertTrue(application.staticTexts["Museum"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Cafe"].exists)
    savedSourcePicker.activateForPlannerJourney()
    application.buttons[second].activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Cafe"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Museum"].exists)
  }

  func testControlledMapsPreviewKeepsOwnedFieldsAndSavesOnlyTheOriginalBookmark() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "capture-maps", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerCatalogAddMenu()
    let capture = application.plannerElement("saved.capture.new")
    XCTAssertTrue(capture.waitForExistence(timeout: 10))
    capture.activateForPlannerJourney()
    let input = application.textFields["saved.capture.input"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.activateForPlannerJourney()
    let original = "https://maps.apple.com/place?name=Museum&address=Tokyo&coordinate=35,139"
    input.typeText("My visit\n" + original)
    application.plannerElement("saved.capture.review").activateForPlannerJourney()
    let title = application.textFields["saved.capture.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.value as? String, "My visit")
    let previewTitle = application.staticTexts["saved.capture.preview.title"]
    for _ in 0..<6 {
      if previewTitle.exists { break }
      application.swipeUp()
    }
    XCTAssertTrue(previewTitle.waitForExistence(timeout: 5), application.debugDescription)
    XCTAssertEqual(previewTitle.label, "Museum")
    XCTAssertTrue(
      application.descendants(matching: .any).matching(
        identifier: "saved.capture.preview.map"
      ).firstMatch.exists)
    XCTAssertTrue(application.plannerElement("saved.capture.add").isEnabled)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Temporary Maps preview in native capture review"
    attachment.lifetime = .keepAlways
    add(attachment)
    application.plannerElement("saved.capture.add").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[original].waitForExistence(timeout: 10))
    assertOwnedLocationIsEmpty(application, expectedTitle: "My visit")
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("My visit").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[original].waitForExistence(timeout: 10))
    assertOwnedLocationIsEmpty(application, expectedTitle: "My visit")
  }

  private func assertOwnedLocationIsEmpty(
    _ application: XCUIApplication, expectedTitle: String
  ) {
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    let title = application.textFields["saved.item.edit.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertEqual(title.value as? String, expectedTitle)
    let name = application.textFields["saved.item.edit.location.name"]
    let address = application.textFields["saved.item.edit.location.address"]
    reveal(name, application: application)
    XCTAssertEqual(name.value as? String, name.placeholderValue)
    reveal(address, application: application)
    XCTAssertEqual(address.value as? String, address.placeholderValue)
    XCTAssertFalse(
      application.descendants(matching: .any)
        .matching(identifier: "saved.item.edit.location.pin").firstMatch.exists)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(title.waitForNonExistence(timeout: 5))
  }

  private func revealSavedDetail(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<6 {
      if element.exists && element.isHittable { return }
      #if os(macOS)
        let form = application.scrollViews.containing(
          .any, identifier: "saved.item.completion"
        ).firstMatch
      #else
        let form = application.collectionViews.containing(
          .any, identifier: "saved.item.completion"
        ).firstMatch
      #endif
      XCTAssertTrue(form.waitForExistence(timeout: 5))
      let start = form.coordinate(withNormalizedOffset: .init(dx: 0.97, dy: 0.8))
      let end = form.coordinate(withNormalizedOffset: .init(dx: 0.97, dy: 0.25))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
    XCTAssertTrue(element.waitForExistence(timeout: 5))
  }

  private func reveal(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<6 {
      if element.isHittable { return }
      application.swipeUp()
    }
    XCTAssertTrue(element.isHittable, application.debugDescription)
  }

  private func replace(_ field: XCUIElement, with value: String, application: XCUIApplication) {
    field.activateForPlannerJourney()
    #if os(macOS)
      field.typeKey("a", modifierFlags: .command)
    #else
      field.press(forDuration: 1)
      let selectAll = application.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@ OR identifier == %@", "Select All", "Select All")
      ).firstMatch
      if selectAll.waitForExistence(timeout: 2) {
        selectAll.activateForPlannerJourney()
      } else {
        field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
      }
    #endif
    field.typeText(value)
    XCTAssertTrue(field.waitForPlannerValue(value))
  }
}
