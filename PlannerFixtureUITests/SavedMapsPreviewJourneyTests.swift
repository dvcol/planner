import XCTest

@MainActor
final class SavedMapsPreviewJourneyTests: XCTestCase {
  func testEditingAPendingMapsURLPreservesBookmarkIdentityAndRejectsItsOldPreview() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "saved-maps-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Delayed map").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    row.activateForPlannerJourney()
    let loading = application.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Loading map preview")
    ).firstMatch
    XCTAssertTrue(loading.waitForExistence(timeout: 5))
    let bookmarks = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
    let edited = bookmarks.matching(NSPredicate(format: "label == %@", "Delayed place"))
      .firstMatch
    reveal(edited, application: application)
    let bookmarkIdentifier = edited.identifier
    let linkIdentifier = bookmarkIdentifier.replacingOccurrences(of: "saved.item.link.", with: "")
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
    let urlField = application.textFields["saved.item.edit.link.url." + linkIdentifier]
    reveal(urlField, application: application)
    XCTAssertEqual(
      urlField.value as? String, "https://maps.apple.com/place?name=Delayed&coordinate=35,139")
    urlField.activateForPlannerJourney()
    #if os(macOS)
      urlField.typeKey("a", modifierFlags: .command)
    #else
      let keyboard = application.keyboards.firstMatch
      XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
      if urlField.frame.maxY > keyboard.frame.minY - 100 {
        let editor = application.collectionViews.containing(
          .textField, identifier: urlField.identifier
        ).firstMatch
        let bottom = min(editor.frame.maxY, keyboard.frame.minY) - 30
        let top = max(editor.frame.minY + 30, bottom - 250)
        let origin = editor.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(
          .init(dx: editor.frame.width - 8, dy: bottom - editor.frame.minY))
        let end = origin.withOffset(
          .init(dx: editor.frame.width - 8, dy: top - editor.frame.minY))
        start.press(forDuration: 0.05, thenDragTo: end)
      }
      XCTAssertLessThan(urlField.frame.maxY, keyboard.frame.minY - 80)
      urlField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
      capture(application, name: "Native URL selection stays above the keyboard")
    #endif
    urlField.typeText("https://maps.apple.com/place?name=Current&coordinate=36,140")
    XCTAssertEqual(
      urlField.value as? String, "https://maps.apple.com/place?name=Current&coordinate=36,140")
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let map = application.descendants(matching: .any)
      .matching(identifier: "saved.item.maps.preview.map").firstMatch
    reveal(map, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Current"].exists)
    XCTAssertFalse(application.staticTexts["Outdated"].exists)
    capture(application, name: "Editing a saved Maps URL rejects the old link response")
    reveal(edited, application: application)
    XCTAssertEqual(bookmarks.count, 2)
    XCTAssertEqual(edited.identifier, bookmarkIdentifier)
    XCTAssertEqual(
      edited.value as? String, "https://maps.apple.com/place?name=Current&coordinate=36,140")
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    row.activateForPlannerJourney()
    reveal(map, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Reopened"].exists)
    XCTAssertFalse(application.staticTexts["Outdated"].exists)
    reveal(edited, application: application)
    XCTAssertEqual(bookmarks.count, 2)
    XCTAssertEqual(edited.identifier, bookmarkIdentifier)
    XCTAssertEqual(
      edited.value as? String, "https://maps.apple.com/place?name=Current&coordinate=36,140")
  }

  func testExplicitMapsRetrySurvivesNavigationAndRestartsAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "saved-maps-retry", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Retry map").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    row.activateForPlannerJourney()
    let retry = application.plannerElement("saved.item.maps.preview.retry")
    reveal(retry, application: application)
    XCTAssertTrue(retry.waitForExistence(timeout: 5))
    let fallback = application.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Open saved Maps link")
    ).firstMatch
    XCTAssertTrue(fallback.exists)
    retry.activateForPlannerJourney()
    let recovered = application.staticTexts["Recovered"]
    XCTAssertTrue(recovered.waitForExistence(timeout: 10))
    XCTAssertEqual(application.state, .runningForeground)
    XCTAssertFalse(retry.exists)
    let bookmark = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    reveal(bookmark, application: application)
    let bookmarkIdentifier = bookmark.identifier
    XCTAssertEqual(
      bookmark.value as? String, "https://maps.apple.com/place?name=Retry&coordinate=35,139")
    XCTAssertEqual(application.state, .runningForeground)
    application.openPlannerSection("Lists")
    XCTAssertTrue(recovered.waitForNonExistence(timeout: 5))
    application.openPlannerSection("Items")
    if row.exists && row.isHittable { row.activateForPlannerJourney() }
    reveal(recovered, application: application)
    XCTAssertTrue(recovered.waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Unrequested lookup"].exists)
    XCTAssertFalse(retry.exists)
    capture(application, name: "Explicit Maps Retry survives leaving and returning to Items")
    reveal(bookmark, application: application)
    XCTAssertEqual(bookmark.identifier, bookmarkIdentifier)
    XCTAssertEqual(
      bookmark.value as? String, "https://maps.apple.com/place?name=Retry&coordinate=35,139")
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    row.activateForPlannerJourney()
    reveal(retry, application: application)
    XCTAssertTrue(retry.waitForExistence(timeout: 10))
    XCTAssertFalse(recovered.exists)
    reveal(bookmark, application: application)
    XCTAssertEqual(bookmark.identifier, bookmarkIdentifier)
    XCTAssertEqual(
      bookmark.value as? String, "https://maps.apple.com/place?name=Retry&coordinate=35,139")
  }

  func testRemovingThePendingMapsLinkKeepsTheSurvivingBookmarkAndPreview() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "saved-maps-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Delayed map").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    let sourceIdentifier = row.identifier
    row.activateForPlannerJourney()
    let loading = application.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Loading map preview")
    ).firstMatch
    XCTAssertTrue(loading.waitForExistence(timeout: 5))
    let bookmarks = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
    let delayed = bookmarks.matching(NSPredicate(format: "label == %@", "Delayed place"))
      .firstMatch
    let current = bookmarks.matching(NSPredicate(format: "label == %@", "Current place"))
      .firstMatch
    reveal(current, application: application)
    let currentIdentifier = current.identifier
    let delayedIdentifier = delayed.identifier.replacingOccurrences(
      of: "saved.item.link.", with: "")
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit item").activateForPlannerJourney()
    let actions = application.plannerElement("saved.item.edit.link.actions." + delayedIdentifier)
    reveal(actions, application: application)
    actions.activateForPlannerJourney()
    application.plannerElement("Remove link").activateForPlannerJourney()
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let map = application.descendants(matching: .any)
      .matching(identifier: "saved.item.maps.preview.map").firstMatch
    reveal(map, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Current"].exists)
    XCTAssertFalse(application.staticTexts["Outdated"].exists)
    XCTAssertFalse(application.plannerElement("saved.item.maps.preview.source").exists)
    capture(application, name: "Removing the pending Maps link retains the current map")
    reveal(current, application: application)
    XCTAssertEqual(bookmarks.count, 1)
    XCTAssertEqual(current.identifier, currentIdentifier)
    XCTAssertEqual(
      current.value as? String, "https://maps.apple.com/place?name=Current&coordinate=36,140")
    application.terminate()
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    XCTAssertEqual(row.identifier, sourceIdentifier)
    row.activateForPlannerJourney()
    reveal(map, application: application)
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Reopened"].exists)
    XCTAssertFalse(application.staticTexts["Outdated"].exists)
    reveal(current, application: application)
    XCTAssertEqual(bookmarks.count, 1)
    XCTAssertEqual(current.identifier, currentIdentifier)
    XCTAssertEqual(
      current.value as? String, "https://maps.apple.com/place?name=Current&coordinate=36,140")
  }

  func testSwitchingSavedMapsLinksRejectsTheReleasedObsoletePreview() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "saved-maps-delay", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let row = application.savedPlannerItemRows("Delayed map").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20))
    row.activateForPlannerJourney()
    let picker = application.plannerElement("saved.item.maps.preview.source")
    reveal(picker, application: application)
    let loading = application.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Loading map preview")
    ).firstMatch
    XCTAssertTrue(loading.waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["Current"].exists)
    picker.activateForPlannerJourney()
    application.plannerElement("Current place").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Current"].waitForExistence(timeout: 10))
    XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["Outdated"].exists)
    XCTAssertTrue(
      application.descendants(matching: .any)
        .matching(identifier: "saved.item.maps.preview.map").firstMatch.exists)
    XCTAssertTrue(
      application.descendants(matching: .any)
        .matching(NSPredicate(format: "label == %@", "Owned map notes")).firstMatch.exists)
    XCTAssertTrue(
      application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
        .waitForPlannerBooleanState(false))
    capture(application, name: "Selected saved Maps link survives the released obsolete preview")
    let bookmarks = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
    let current = bookmarks.matching(NSPredicate(format: "label == %@", "Current place"))
      .firstMatch
    reveal(current, application: application)
    XCTAssertEqual(bookmarks.count, 2)
    XCTAssertEqual(
      current.value as? String, "https://maps.apple.com/place?name=Current&coordinate=36,140")
    let delayed = bookmarks.matching(NSPredicate(format: "label == %@", "Delayed place"))
      .firstMatch
    XCTAssertEqual(
      delayed.value as? String, "https://maps.apple.com/place?name=Delayed&coordinate=35,139")
  }

  private func reveal(_ element: XCUIElement, application: XCUIApplication) {
    for _ in 0..<6 {
      if element.exists && element.isHittable { return }
      #if os(macOS)
        let forms = application.scrollViews
      #else
        let forms = application.collectionViews
      #endif
      let editor = forms.containing(.any, identifier: "saved.item.edit.title").firstMatch
      let details = forms.containing(.any, identifier: "saved.item.completion").firstMatch
      let form = editor.exists ? editor : details
      XCTAssertTrue(form.waitForExistence(timeout: 5))
      let start = form.coordinate(withNormalizedOffset: .init(dx: 0.97, dy: 0.8))
      let end = form.coordinate(withNormalizedOffset: .init(dx: 0.97, dy: 0.25))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
    XCTAssertTrue(element.waitForExistence(timeout: 5))
  }

  private func capture(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
