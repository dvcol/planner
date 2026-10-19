import XCTest

@MainActor
final class SavedItineraryJourneyTests: XCTestCase {
  func testItineraryLinksStageCancelPreserveIdentityAndOrderAcrossEditAndRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Route bookmarks")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the route notes")
    let addLink = application.plannerElement("saved.itinerary.link.add")
    XCTAssertTrue(addLink.waitForExistence(timeout: 5))
    addItineraryLink(
      "https://maps.apple.com/?q=Tokyo", label: "Tokyo Map", application: application)
    addItineraryLink(
      "https://maps.apple.com/?q=Kyoto", label: "Kyoto Map", application: application)
    recordScreenshot(application, name: "Native Itinerary stages two owned links")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let links = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
    let tokyo = links.matching(NSPredicate(format: "label == %@", "Tokyo Map")).firstMatch
    let kyoto = links.matching(NSPredicate(format: "label == %@", "Kyoto Map")).firstMatch
    XCTAssertTrue(tokyo.waitForExistence(timeout: 10))
    XCTAssertTrue(kyoto.waitForExistence(timeout: 10))
    XCTAssertEqual(links.count, 2)
    let tokyoIdentity = tokyo.identifier
    let kyotoIdentity = kyoto.identifier
    XCTAssertEqual(links.allElementsBoundByIndex.map(\.identifier), [tokyoIdentity, kyotoIdentity])
    XCTAssertTrue(tokyo.waitForPlannerValue("https://maps.apple.com/?q=Tokyo"))
    XCTAssertTrue(kyoto.waitForPlannerValue("https://maps.apple.com/?q=Kyoto"))
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    addItineraryLink(
      "https://maps.apple.com/?q=Osaka", label: "Canceled Map", application: application)
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(tokyo.waitForExistence(timeout: 5))
    XCTAssertEqual(links.count, 2)
    XCTAssertFalse(application.staticTexts["Canceled Map"].exists)
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    let tokyoIdentifier = tokyoIdentity.replacingOccurrences(of: "saved.item.link.", with: "")
    let tokyoURL = application.textFields["saved.itinerary.link.url.\(tokyoIdentifier)"]
    XCTAssertTrue(tokyoURL.waitForExistence(timeout: 5))
    replaceText(tokyoURL, with: "https://maps.apple.com/?q=Kobe", application: application)
    replaceText(
      application.textFields["saved.itinerary.link.label.\(tokyoIdentifier)"], with: "Kobe Map",
      application: application)
    application.plannerElement("saved.itinerary.link.actions.\(tokyoIdentifier)")
      .activateForPlannerJourney()
    application.plannerElement("Move down").activateForPlannerJourney()
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let retainedTokyo = links.matching(identifier: tokyoIdentity).firstMatch
    XCTAssertTrue(retainedTokyo.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedTokyo.label, "Kobe Map")
    XCTAssertTrue(retainedTokyo.waitForPlannerValue("https://maps.apple.com/?q=Kobe"))
    XCTAssertEqual(links.allElementsBoundByIndex.map(\.identifier), [kyotoIdentity, tokyoIdentity])
    recordScreenshot(
      application, name: "Itinerary detail retains owned link identities after reorder and edit")
    let kyotoIdentifier = kyotoIdentity.replacingOccurrences(of: "saved.item.link.", with: "")
    for confirmsRemoval in [false, true] {
      application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
      application.plannerElement("saved.itinerary.link.actions.\(kyotoIdentifier)")
        .activateForPlannerJourney()
      application.plannerElement("Remove link").activateForPlannerJourney()
      let action = confirmsRemoval ? "saved.itinerary.save" : "saved.itinerary.cancel"
      application.plannerElement(action).activateForPlannerJourney()
      XCTAssertTrue(retainedTokyo.waitForExistence(timeout: 10))
      XCTAssertEqual(links.count, confirmsRemoval ? 1 : 2)
      XCTAssertEqual(links.matching(identifier: kyotoIdentity).firstMatch.exists, !confirmsRemoval)
    }
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    openCatalog(application)
    let itinerary = itineraryRow(application, title: "Route bookmarks")
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    let itineraryIdentity = itinerary.identifier
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    XCTAssertEqual(itinerary.identifier, itineraryIdentity)
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(retainedTokyo.waitForExistence(timeout: 10))
    XCTAssertEqual(links.count, 1)
    XCTAssertEqual(retainedTokyo.label, "Kobe Map")
    XCTAssertTrue(retainedTokyo.waitForPlannerValue("https://maps.apple.com/?q=Kobe"))
    XCTAssertFalse(links.matching(identifier: kyotoIdentity).firstMatch.exists)
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(
      application, name: "Itinerary owned links survive relaunch without canceled edits")
  }

  private func addItineraryLink(_ originalURL: String, label: String, application: XCUIApplication)
  {
    let fields = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.link.url."))
    let existing = Set(fields.allElementsBoundByIndex.map(\.identifier))
    application.plannerElement("saved.itinerary.link.add").activateForPlannerJourney()
    let field = fields.matching(NSPredicate(format: "NOT identifier IN %@", Array(existing)))
      .firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.activateForPlannerJourney()
    field.typeText(originalURL)
    let labelIdentifier = field.identifier.replacingOccurrences(
      of: "saved.itinerary.link.url.", with: "saved.itinerary.link.label.")
    let labelField = application.textFields[labelIdentifier]
    labelField.activateForPlannerJourney()
    labelField.typeText(label)
  }

  func testInvalidItineraryLinksKeepTheDraftAndSavedOwnerUntilCorrectedOrCanceled() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Route validation")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Original route notes")
    addItineraryLink("file:///private/tmp/route", label: "Route Map", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let alert = application.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    XCTAssertTrue(alert.staticTexts["A bookmark must be an absolute HTTP or HTTPS URL."].exists)
    recordScreenshot(application, name: "Invalid Itinerary creation retains the staged draft")
    alert.buttons["OK"].activateForPlannerJourney()
    let urlFields = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.link.url."))
    replaceText(
      urlFields.firstMatch, with: "https://maps.apple.com/?q=Tokyo", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let links = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
    let link = links.firstMatch
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    let identity = link.identifier
    XCTAssertEqual(links.count, 1)
    XCTAssertTrue(link.waitForPlannerValue("https://maps.apple.com/?q=Tokyo"))
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    replaceText(notes, with: "Unapplied route notes", application: application)
    replaceText(
      urlFields.firstMatch, with: "file:///private/tmp/edited-route", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    XCTAssertTrue(alert.staticTexts["A bookmark must be an absolute HTTP or HTTPS URL."].exists)
    recordScreenshot(application, name: "Invalid link rejects the complete Itinerary edit")
    alert.buttons["OK"].activateForPlannerJourney()
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    XCTAssertEqual(link.identifier, identity)
    XCTAssertEqual(links.count, 1)
    XCTAssertTrue(link.waitForPlannerValue("https://maps.apple.com/?q=Tokyo"))
    XCTAssertTrue(application.staticTexts["Original route notes"].exists)
    XCTAssertFalse(application.staticTexts["Unapplied route notes"].exists)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    let itinerary = itineraryRow(application, title: "Route validation")
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(link.waitForExistence(timeout: 10))
    XCTAssertEqual(link.identifier, identity)
    XCTAssertEqual(links.count, 1)
    XCTAssertTrue(link.waitForPlannerValue("https://maps.apple.com/?q=Tokyo"))
    XCTAssertTrue(application.staticTexts["Original route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(
      application, name: "Rejected Itinerary edits leave the saved owner unchanged after relaunch")
  }

  func testItineraryPlanningTimeZoneSelectionPreservesInstantAndOwnerAfterCancelAndRelaunch() throws
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Tokyo afternoon")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the route notes")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the route notes"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
    application.plannerElement("Schedule itinerary").activateForPlannerJourney()
    selectPlanningTimeZone("Europe/Paris", search: "Paris", application: application)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule."))
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "Start only")
    let identity = schedule.identifier
    let originalDescription = try XCTUnwrap(schedule.value as? String)
    XCTAssertTrue(originalDescription.hasSuffix(" · Europe/Paris"))
    let originalInstant = try displayedStartInstant(originalDescription)
    openScheduleMenu(schedule)
    application.plannerElement("Edit schedule").activateForPlannerJourney()
    selectPlanningTimeZone("America/New_York", search: "New York", application: application)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForPlannerValue(originalDescription))
    XCTAssertEqual(scheduleRows.count, 1)
    openScheduleMenu(schedule)
    application.plannerElement("Edit schedule").activateForPlannerJourney()
    selectPlanningTimeZone("Asia/Tokyo", search: "Tokyo", application: application)
    recordScreenshot(application, name: "Itinerary planning zone stages the original appointment")
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value ENDSWITH %@", " · Asia/Tokyo"), object: schedule)
        ], timeout: 10), .completed)
    let changedDescription = try XCTUnwrap(schedule.value as? String)
    XCTAssertNotEqual(changedDescription, originalDescription)
    XCTAssertEqual(try displayedStartInstant(changedDescription), originalInstant)
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Itinerary timezone edit retains its owner and instant")
    openCatalog(application)
    let itinerary = itineraryRow(application, title: "Tokyo afternoon")
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    let itineraryIdentity = itinerary.identifier
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    XCTAssertEqual(itinerary.identifier, itineraryIdentity)
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertTrue(schedule.waitForPlannerValue(changedDescription))
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(
      try displayedStartInstant(try XCTUnwrap(schedule.value as? String)), originalInstant)
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Itinerary planning timezone survives relaunch")
  }

  private func selectPlanningTimeZone(
    _ identifier: String, search: String, application: XCUIApplication
  ) {
    let timeZoneControl = application.plannerElement("saved.schedule.zone")
    XCTAssertTrue(timeZoneControl.waitForExistence(timeout: 5))
    timeZoneControl.activateForPlannerJourney()
    let searchField = application.searchFields.firstMatch
    XCTAssertTrue(searchField.waitForExistence(timeout: 5))
    searchField.activateForPlannerJourney()
    searchField.typeText(search)
    let option = application.plannerElement("saved.schedule.zone.option.\(identifier)")
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.activateForPlannerJourney()
    XCTAssertTrue(timeZoneControl.waitForExistence(timeout: 5))
  }

  private func displayedStartInstant(_ description: String) throws -> Date {
    let components = description.components(separatedBy: " · ")
    XCTAssertEqual(components.count, 2)
    let timeZone = try XCTUnwrap(TimeZone(identifier: components[1]))
    var formatStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
    formatStyle.timeZone = timeZone
    return try formatStyle.parseStrategy.parse(components[0])
  }

  func testEmptyItineraryCanCancelAndSaveItsOwnStartOnlyScheduleAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Tokyo afternoon")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the route notes")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the route notes"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    let actions = application.plannerElement("saved.itinerary.actions")
    XCTAssertTrue(actions.isEnabled)
    actions.activateForPlannerJourney()
    let scheduleAction = application.plannerElement("Schedule itinerary")
    XCTAssertTrue(scheduleAction.waitForExistence(timeout: 5))
    scheduleAction.activateForPlannerJourney()
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["This schedule has no end time."].exists)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule."))
    XCTAssertEqual(scheduleRows.count, 0)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    actions.activateForPlannerJourney()
    scheduleAction.activateForPlannerJourney()
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "Start only")
    let scheduleIdentity = schedule.identifier
    let description = schedule.value as? String
    XCTAssertFalse(description?.isEmpty ?? true)
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Native empty Itinerary saves its own appointment")
    openCatalog(application)
    let itinerary = itineraryRow(application, title: "Tokyo afternoon")
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    let itineraryIdentity = itinerary.identifier
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    XCTAssertEqual(itinerary.identifier, itineraryIdentity)
    itinerary.activateForPlannerJourney()
    let restored = application.descendants(matching: .any)
      .matching(identifier: scheduleIdentity).firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertEqual(restored.label, "Start only")
    XCTAssertEqual(restored.value as? String, description)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertTrue(application.staticTexts["Keep the route notes"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Native Itinerary appointment survives relaunch")
  }

  func testItineraryScheduleConversionAndConfirmedRemovalRetainOwnerAndOtherAssignment() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend appointments")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the route"].waitForExistence(timeout: 10))
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule."))
    let timedRows = scheduleRows.matching(NSPredicate(format: "label == %@", "Timed"))
    let startOnlyRows = scheduleRows.matching(NSPredicate(format: "label == %@", "Start only"))
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    let allDay = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.allDay").firstMatch
    for includesEnd in [false, true] {
      application.plannerElement("saved.itinerary.actions").activateForPlannerJourney()
      application.plannerElement("Schedule itinerary").activateForPlannerJourney()
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
      if includesEnd { activateScheduleToggle(includeEnd) }
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      let row = includesEnd ? timedRows.firstMatch : startOnlyRows.firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
    }
    XCTAssertEqual(scheduleRows.count, 2)
    let retainedIdentity = startOnlyRows.firstMatch.identifier
    let retainedDescription = startOnlyRows.firstMatch.value as? String
    let convertedIdentity = timedRows.firstMatch.identifier
    let originalDescription = timedRows.firstMatch.value as? String
    let converted = application.descendants(matching: .any)
      .matching(identifier: convertedIdentity).firstMatch
    openScheduleMenu(converted)
    let editAction = application.plannerElement("Edit schedule")
    XCTAssertTrue(editAction.waitForExistence(timeout: 5))
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    activateScheduleToggle(allDay)
    XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertTrue(converted.waitForExistence(timeout: 5))
    XCTAssertEqual(converted.label, "Timed")
    XCTAssertEqual(converted.value as? String, originalDescription)
    openScheduleMenu(converted)
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    activateScheduleToggle(allDay)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let allDayRows = scheduleRows.matching(NSPredicate(format: "label == %@", "All day"))
    XCTAssertTrue(allDayRows.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(allDayRows.firstMatch.identifier, convertedIdentity)
    XCTAssertEqual(scheduleRows.count, 2)
    let convertedDescription = converted.value as? String
    XCTAssertFalse(convertedDescription?.isEmpty ?? true)
    XCTAssertNotEqual(convertedDescription, originalDescription)
    openScheduleMenu(converted)
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    recordScreenshot(application, name: "Native Itinerary edit reloads its converted all-day form")
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    let itinerary = itineraryRow(application, title: "Weekend appointments")
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(converted.waitForExistence(timeout: 10))
    XCTAssertEqual(converted.label, "All day")
    XCTAssertEqual(converted.value as? String, convertedDescription)
    XCTAssertEqual(startOnlyRows.firstMatch.identifier, retainedIdentity)
    XCTAssertEqual(startOnlyRows.firstMatch.value as? String, retainedDescription)
    openScheduleMenu(converted)
    let removeAction = application.plannerElement("Remove schedule")
    XCTAssertTrue(removeAction.waitForExistence(timeout: 5))
    removeAction.activateForPlannerJourney()
    let confirm = application.buttons["saved.schedule.remove.confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.staticTexts[
        "1 schedule will be removed. The Itinerary and its other schedules stay available."
      ].exists)
    recordScreenshot(application, name: "Native Itinerary schedule removal explains its scope")
    application.staticTexts["Weekend appointments"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    XCTAssertEqual(scheduleRows.count, 2)
    XCTAssertEqual(converted.value as? String, convertedDescription)
    openScheduleMenu(converted)
    removeAction.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.activateForPlannerJourney()
    XCTAssertTrue(converted.waitForNonExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(startOnlyRows.firstMatch.identifier, retainedIdentity)
    XCTAssertTrue(application.staticTexts["Keep the route"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordScreenshot(application, name: "Native Itinerary removal retains its other appointment")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(startOnlyRows.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(startOnlyRows.firstMatch.identifier, retainedIdentity)
    XCTAssertEqual(startOnlyRows.firstMatch.value as? String, retainedDescription)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertFalse(converted.exists)
    XCTAssertTrue(application.staticTexts["Keep the route"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    recordScreenshot(application, name: "Native Itinerary schedule removal survives relaunch")
  }

  private func openScheduleMenu(_ schedule: XCUIElement) {
    #if os(macOS)
      schedule.rightClick()
    #else
      schedule.press(forDuration: 1.2)
    #endif
  }

  private func activateScheduleToggle(_ element: XCUIElement) {
    #if os(macOS)
      element.click()
    #else
      let visibleSwitch = element.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
  }

  func testItineraryDraftsCancelAndGuardedTitleNotesPersistAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(application.staticTexts["No Itineraries yet"].waitForExistence(timeout: 5))
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    let notes = application.textFields["saved.itinerary.notes"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.itinerary.save").isEnabled)
    title.activateForPlannerJourney()
    title.typeText("Canceled plan")
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Itineraries yet"].waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["Canceled plan"].exists)

    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Tokyo Weekend")
    notes.activateForPlannerJourney()
    notes.typeText("Explore at our own pace")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Explore at our own pace"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    openCatalog(application)
    let originalRow = itineraryRow(application, title: "Tokyo Weekend")
    XCTAssertTrue(originalRow.waitForExistence(timeout: 10))
    let originalIdentifier = originalRow.identifier
    originalRow.activateForPlannerJourney()
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.itinerary.save").isEnabled)
    replaceText(title, with: "Canceled rename", application: application)
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Explore at our own pace"].waitForExistence(timeout: 5))
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    replaceText(title, with: "Tokyo Break", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Explore at our own pace"].waitForExistence(timeout: 10))
    application.plannerElement("saved.itinerary.edit").activateForPlannerJourney()
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    XCTAssertTrue(title.waitForPlannerValue("Tokyo Break"))
    replaceText(notes, with: "Museum and dinner", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum and dinner"].waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Saved native Itinerary details")

    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    let retainedRow = itineraryRow(application, title: "Tokyo Break")
    XCTAssertTrue(retainedRow.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedRow.identifier, originalIdentifier)
    XCTAssertFalse(itineraryRow(application, title: "Tokyo Weekend").exists)
    XCTAssertFalse(itineraryRow(application, title: "Canceled rename").exists)
    XCTAssertFalse(itineraryRow(application, title: "Canceled plan").exists)
    recordScreenshot(application, name: "Native Itinerary catalog after relaunch")
    retainedRow.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Museum and dinner"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)
  }

  private func openItineraries(_ application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("saved.section.itineraries")
    #else
      let section = application.buttons["Itineraries"].firstMatch
    #endif
    XCTAssertTrue(section.waitForExistence(timeout: 10), application.debugDescription)
    section.activateForPlannerJourney()
    openCatalog(application)
  }

  private func openCatalog(_ application: XCUIApplication) {
    let newItinerary = application.plannerElement("saved.itinerary.new")
    if !newItinerary.waitForExistence(timeout: 2) {
      let back = application.buttons["Itineraries"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
    }
    if !newItinerary.exists {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(newItinerary.waitForExistence(timeout: 10), application.debugDescription)
  }

  private func itineraryRow(_ application: XCUIApplication, title: String) -> XCUIElement {
    application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", title)
    ).firstMatch
  }

  private func replaceText(
    _ field: XCUIElement, with value: String, application: XCUIApplication
  ) {
    field.activateForPlannerJourney()
    #if os(macOS)
      field.typeKey("a", modifierFlags: .command)
    #else
      field.press(forDuration: 1)
      let selectAll = application.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@ OR identifier == %@", "Select All", "Select All")
      ).firstMatch
      XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
      selectAll.activateForPlannerJourney()
    #endif
    field.typeText(value)
    XCTAssertTrue(field.waitForPlannerValue(value))
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = application.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
