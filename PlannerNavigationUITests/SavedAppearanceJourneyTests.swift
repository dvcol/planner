import CoreGraphics
import XCTest

@MainActor
final class SavedAppearanceJourneyTests: XCTestCase {
  func testListMembershipFiltersUseAnyAllAndKeepContextualCompletionAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Shared")
    openCatalogSection("Items", application: application)
    let catalogFilters = application.plannerElement("saved.items.filters")
    catalogFilters.activateForPlannerJourney()
    application.revealSavedPlannerFilter("saved.filters.lists")
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    application.savedPlannerItemRows("Shared").firstMatch.activateForPlannerJourney()
    editPresenceContent(address: nil, addLink: true, application: application)
    for title in ["North only", "South only", "Unlisted"] {
      createItem(application, title: title)
    }
    createList("North", application: application)
    addItem(application, title: "Shared")
    addItem(application, title: "North only")
    createList("South", application: application)
    addItem(application, title: "Shared")
    addItem(application, title: "South only")
    openCatalogSection("Items", application: application)
    let shared = application.savedPlannerItemRows("Shared").firstMatch
    let northOnly = application.savedPlannerItemRows("North only").firstMatch
    let southOnly = application.savedPlannerItemRows("South only").firstMatch
    let unlisted = application.savedPlannerItemRows("Unlisted").firstMatch
    XCTAssertTrue(shared.waitForExistence(timeout: 10))
    let sourceIdentifier = shared.identifier
    catalogFilters.activateForPlannerJourney()
    selectFilterLists(["North"], application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(unlisted.waitForNonExistence(timeout: 10))
    XCTAssertFalse(southOnly.exists)
    XCTAssertTrue(shared.exists)
    XCTAssertTrue(northOnly.exists)
    XCTAssertEqual(catalogFilters.label, "Active · 1 List")
    catalogFilters.activateForPlannerJourney()
    selectFilterLists(["South"], application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(southOnly.waitForExistence(timeout: 10))
    XCTAssertTrue(northOnly.exists)
    XCTAssertTrue(shared.exists)
    XCTAssertFalse(unlisted.exists)
    XCTAssertEqual(catalogFilters.label, "Active · 2 Lists")
    catalogFilters.activateForPlannerJourney()
    let match = application.plannerElement("saved.filters.list.match")
    application.revealSavedPlannerFilter("saved.filters.list.match")
    match.activateForPlannerJourney()
    application.plannerElement("All selected").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(northOnly.waitForNonExistence(timeout: 10))
    XCTAssertFalse(southOnly.exists)
    XCTAssertFalse(unlisted.exists)
    XCTAssertEqual(shared.identifier, sourceIdentifier)
    XCTAssertEqual(catalogFilters.label, "Active · All 2 Lists")
    recordScreenshot(application, name: "All selected Lists retain one shared source Item")
    catalogFilters.activateForPlannerJourney()
    setPresenceFilter("saved.filters.hasLinks", to: true, application: application)
    let clearLists = application.plannerElement("Clear Lists")
    application.revealSavedPlannerFilter("Clear Lists")
    clearLists.activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertEqual(catalogFilters.label, "Active · Links")
    XCTAssertTrue(shared.exists)
    XCTAssertFalse(northOnly.exists)
    XCTAssertFalse(southOnly.exists)
    XCTAssertFalse(unlisted.exists)
    catalogFilters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(northOnly.waitForExistence(timeout: 10))
    XCTAssertTrue(southOnly.exists)
    XCTAssertTrue(unlisted.exists)
    XCTAssertEqual(catalogFilters.label, "All")

    openList("North", itemTitle: "Shared", application: application)
    let appearance = application.savedPlannerItemRows("Shared").firstMatch
    let appearanceIdentifier = appearance.identifier
    let completion = application.plannerElement(
      appearanceIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    let listFilters = application.plannerElement("saved.list.filters")
    listFilters.activateForPlannerJourney()
    selectFilterLists(["South"], application: application)
    recordScreenshot(application, name: "Native List membership filter in the adaptive Form")
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(northOnly.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Showing 1 of 2 items"].exists)
    XCTAssertEqual(appearance.identifier, appearanceIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    recordScreenshot(
      application, name: "List membership filtering preserves full contextual progress")
    listFilters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(northOnly.waitForExistence(timeout: 10))
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("North", itemTitle: "Shared", application: application)
    XCTAssertEqual(appearance.identifier, appearanceIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    openList("South", itemTitle: "Shared", application: application)
    let otherAppearance = application.savedPlannerItemRows("Shared").firstMatch
    XCTAssertNotEqual(otherAppearance.identifier, appearanceIdentifier)
    let otherCompletion = application.plannerElement(
      otherAppearance.identifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    XCTAssertTrue(otherCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    recordScreenshot(
      application, name: "Other List keeps its independent completion after relaunch")
  }

  private func selectFilterLists(_ names: [String], application: XCUIApplication) {
    let picker = application.plannerElement("saved.filters.lists")
    application.revealSavedPlannerFilter("saved.filters.lists")
    picker.activateForPlannerJourney()
    for name in names {
      let toggle = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.filters.list.", name)
      ).firstMatch
      XCTAssertTrue(toggle.waitForExistence(timeout: 5))
      XCTAssertEqual(toggle.plannerBooleanState, false)
      #if os(macOS)
        toggle.click()
      #else
        let control = toggle.switches.firstMatch
        XCTAssertTrue(control.exists)
        control.tap()
      #endif
      XCTAssertTrue(toggle.waitForPlannerBooleanState(true))
    }
    application.plannerElement("saved.filters.lists.done").activateForPlannerJourney()
  }

  func testAddressAndLinkFiltersNarrowCumulativelyWithoutChangingSavedContentOrListProgress() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Plain")
    openCatalogSection("Items", application: application)
    let catalogFilters = application.plannerElement("saved.items.filters")
    catalogFilters.activateForPlannerJourney()
    revealPresenceFilter("saved.filters.hasAddress", application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()

    createItem(application, title: "Guide")
    editPresenceContent(address: nil, addLink: true, application: application)
    createItem(application, title: "Located")
    editPresenceContent(
      address: "1 Apple Park Way, Cupertino, CA", addLink: false, application: application)
    createItem(application, title: "Located guide")
    editPresenceContent(
      address: "1 Apple Park Way, Cupertino, CA", addLink: true, application: application)
    openCatalogSection("Items", application: application)
    let plain = application.savedPlannerItemRows("Plain").firstMatch
    let guide = application.savedPlannerItemRows("Guide").firstMatch
    let located = application.savedPlannerItemRows("Located").firstMatch
    let locatedGuide = application.savedPlannerItemRows("Located guide").firstMatch
    XCTAssertTrue(locatedGuide.waitForExistence(timeout: 10))
    let sourceIdentifier = locatedGuide.identifier
    catalogFilters.activateForPlannerJourney()
    setPresenceFilter("saved.filters.hasLinks", to: true, application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(plain.waitForNonExistence(timeout: 10))
    XCTAssertFalse(located.exists)
    XCTAssertTrue(guide.exists)
    XCTAssertTrue(locatedGuide.exists)
    XCTAssertEqual(catalogFilters.label, "Active · Links")
    catalogFilters.activateForPlannerJourney()
    setPresenceFilter("saved.filters.hasAddress", to: true, application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 10))
    XCTAssertFalse(plain.exists)
    XCTAssertFalse(located.exists)
    XCTAssertTrue(locatedGuide.exists)
    XCTAssertEqual(locatedGuide.identifier, sourceIdentifier)
    XCTAssertEqual(catalogFilters.label, "Active · Address · Links")
    recordScreenshot(
      application, name: "Cumulative address and link filters narrow the Item catalog")
    catalogFilters.activateForPlannerJourney()
    setPresenceFilter("saved.filters.hasLinks", to: false, application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(located.waitForExistence(timeout: 10))
    XCTAssertTrue(locatedGuide.exists)
    XCTAssertFalse(guide.exists)
    XCTAssertFalse(plain.exists)
    XCTAssertEqual(catalogFilters.label, "Active · Address")
    catalogFilters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(plain.waitForExistence(timeout: 10))
    XCTAssertTrue(guide.exists)
    XCTAssertTrue(located.exists)
    XCTAssertTrue(locatedGuide.exists)
    XCTAssertEqual(catalogFilters.label, "All")

    createList("Weekend", application: application)
    for title in ["Plain", "Guide", "Located", "Located guide"] {
      addItem(application, title: title)
    }
    let appearance = application.savedPlannerItemRows("Located guide").firstMatch
    let appearanceIdentifier = appearance.identifier
    let completion = application.plannerElement(
      appearanceIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    let listFilters = application.plannerElement("saved.list.filters")
    listFilters.activateForPlannerJourney()
    setPresenceFilter("saved.filters.hasAddress", to: true, application: application)
    setPresenceFilter("saved.filters.hasLinks", to: true, application: application)
    recordScreenshot(application, name: "Native content filter controls in the adaptive Form")
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Plain").firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Guide").firstMatch.exists)
    XCTAssertFalse(application.savedPlannerItemRows("Located").firstMatch.exists)
    XCTAssertEqual(appearance.identifier, appearanceIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertTrue(application.staticTexts["Showing 1 of 4 items"].exists)
    assertProgress(0.25, application: application)
    recordScreenshot(application, name: "Content filters retain the full List progress")
    listFilters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Plain").firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerItemRows("Guide").firstMatch.exists)
    XCTAssertTrue(application.savedPlannerItemRows("Located").firstMatch.exists)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.25, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Weekend", itemTitle: "Located guide", application: application)
    XCTAssertEqual(appearance.identifier, appearanceIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.25, application: application)
    viewGlobalItem(application, itemTitle: "Located guide")
    XCTAssertTrue(
      application.staticTexts["1 Apple Park Way, Cupertino, CA"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      savedBookmarkRows(application).matching(NSPredicate(format: "label == %@", "Guide"))
        .firstMatch.exists)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    recordScreenshot(
      application, name: "Content and independent completion survive filtered relaunch")
  }

  private func revealPresenceFilter(_ identifier: String, application: XCUIApplication) {
    application.revealSavedPlannerFilter(identifier)
  }

  private func setPresenceFilter(
    _ identifier: String, to expected: Bool, application: XCUIApplication
  ) {
    revealPresenceFilter(identifier, application: application)
    let control = application.descendants(matching: .any).matching(identifier: identifier)
      .firstMatch
    XCTAssertEqual(control.plannerBooleanState, !expected)
    #if os(macOS)
      control.click()
    #else
      let nativeSwitch = control.switches.firstMatch
      XCTAssertTrue(nativeSwitch.exists)
      nativeSwitch.tap()
    #endif
    XCTAssertTrue(control.waitForPlannerBooleanState(expected))
  }

  private func editPresenceContent(
    address: String?, addLink: Bool, application: XCUIApplication
  ) {
    openItemEditor(application)
    if let address {
      let field = application.textFields["saved.item.edit.location.address"]
      revealEditorElement(field, application: application)
      replaceText(field, with: address, application: application)
    }
    if addLink {
      _ = addBookmark(
        "https://maps.apple.com/?q=Cupertino", label: "Guide", application: application)
    }
    let save = application.plannerElement("saved.item.edit.save")
    save.activateForPlannerJourney()
    XCTAssertTrue(save.waitForNonExistence(timeout: 10))
  }

  func testNativeBulkReviewIncludesHiddenArchivedItemsAndRetainsGlobalCompletion() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createItem(application, title: "Hotel")
    createList("Tokyo Food", application: application)
    addItem(application)
    addItem(application, title: "Hotel")
    let museum = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let museumIdentifier = museum.identifier
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    let hotelIdentifier = hotel.identifier
    viewGlobalItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    openList("Tokyo Food", itemTitle: "Hotel", application: application)
    let filters = application.plannerElement("saved.list.filters")
    application.chooseSavedPlannerStateFilter("Active", control: filters)
    XCTAssertTrue(museum.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Showing 1 of 2 items"].exists)
    XCTAssertTrue(application.staticTexts["1 of 2 items finished"].exists)
    XCTAssertTrue(application.staticTexts["0 done · 1 archived"].exists)
    assertProgress(0.5, application: application)

    recordScreenshot(application, name: "Native List toolbar before bulk review")
    openBulkReview(done: true, application: application)
    XCTAssertTrue(application.staticTexts["2 items in Tokyo Food"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.staticTexts["Includes archived items and items hidden by filters."].exists)
    recordScreenshot(application, name: "Native bulk review includes hidden archived Items")
    application.plannerElement("saved.list.bulk.cancel").activateForPlannerJourney()
    assertProgress(0.5, application: application)
    openBulkReview(done: true, application: application)
    application.plannerElement("saved.list.bulk.confirm").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["2 of 2 items done"].waitForExistence(timeout: 10))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Bulk Done retains full progress while one Item is hidden")

    viewGlobalItem(application, itemTitle: "Hotel")
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openList("Tokyo Food", itemTitle: "Hotel", application: application)
    openBulkReview(done: false, application: application)
    XCTAssertTrue(application.staticTexts["2 items in Tokyo Food"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.staticTexts["Items completed globally will still appear done."].exists)
    application.plannerElement("saved.list.bulk.confirm").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["2 of 2 items finished"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["1 done · 1 archived"].exists)
    assertProgress(1, application: application)
    viewGlobalItem(application, itemTitle: "Hotel")
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openList("Tokyo Food", itemTitle: "Hotel", application: application)
    assertProgress(0.5, application: application)
    application.chooseSavedPlannerStateFilter("All archive states", control: filters)
    XCTAssertTrue(museum.waitForExistence(timeout: 10))
    XCTAssertEqual(museum.identifier, museumIdentifier)
    XCTAssertEqual(hotel.identifier, hotelIdentifier)
    viewGlobalItem(application)
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    assertProgress(0.5, application: application)
    XCTAssertTrue(application.staticTexts["1 of 2 items finished"].exists)
    XCTAssertTrue(application.staticTexts["0 done · 1 archived"].exists)
    XCTAssertEqual(museum.identifier, museumIdentifier)
    XCTAssertEqual(hotel.identifier, hotelIdentifier)
    recordScreenshot(application, name: "Bulk state and source identities survive native relaunch")
  }

  private func openBulkReview(done: Bool, application: XCUIApplication) {
    let actions = application.plannerElement("saved.list.actions")
    if actions.exists {
      actions.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"]
      XCTAssertTrue(overflow.waitForExistence(timeout: 5), application.debugDescription)
      overflow.activateForPlannerJourney()
      let nestedActions = application.plannerElement("List actions")
      XCTAssertTrue(nestedActions.waitForExistence(timeout: 5), application.debugDescription)
      nestedActions.activateForPlannerJourney()
    }
    let command = application.plannerElement(done ? "Mark all Done" : "Mark all Undone")
    XCTAssertTrue(command.waitForExistence(timeout: 5), application.debugDescription)
    command.activateForPlannerJourney()
  }

  func testOwnedAddressCreatesANativePreviewAndRemainsLiveInACompletedList() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    openItemEditor(application)
    let name = application.textFields["saved.item.edit.location.name"]
    let address = application.textFields["saved.item.edit.location.address"]
    XCTAssertTrue(address.waitForExistence(timeout: 5))
    revealEditorElement(name, application: application)
    replaceText(name, with: "Apple Park stop", application: application)
    revealEditorElement(address, application: application)
    replaceText(address, with: "1 Apple Park Way, Cupertino, CA", application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Apple Park stop"].exists)

    openItemEditor(application)
    revealEditorElement(name, application: application)
    replaceText(name, with: "Apple Park stop", application: application)
    revealEditorElement(address, application: application)
    replaceText(address, with: "1 Apple Park Way, Cupertino, CA", application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Apple Park stop"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["1 Apple Park Way, Cupertino, CA"].exists)
    let preview = application.descendants(matching: .any)
      .matching(identifier: "saved.item.location.preview.map").firstMatch
    XCTAssertTrue(preview.waitForExistence(timeout: 45))
    recordScreenshot(application, name: "Saved owned address renders a native MapKit pin")

    createList("Tokyo", application: application)
    addItem(application)
    let membership = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = membership.identifier
    XCTAssertTrue(
      membership.waitForPlannerValue("Apple Park stop, 1 Apple Park Way, Cupertino, CA"))
    recordScreenshot(application, name: "List row includes a compact saved location preview")
    let completion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    membership.activateForPlannerJourney()
    XCTAssertTrue(preview.waitForExistence(timeout: 45))
    XCTAssertTrue(application.staticTexts["Apple Park stop"].exists)
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(
      application, name: "Completed List appearance retains the owned address preview")
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo", application: application)
    XCTAssertEqual(membership.identifier, membershipIdentifier)
    assertProgress(1, application: application)
    membership.activateForPlannerJourney()
    XCTAssertTrue(preview.waitForExistence(timeout: 45))
    XCTAssertTrue(application.staticTexts["Apple Park stop"].exists)
    XCTAssertTrue(application.staticTexts["1 Apple Park Way, Cupertino, CA"].exists)
    recordScreenshot(application, name: "Owned address and local completion survive reopening")
  }

  func testNativePreviewFailureKeepsTheOwnedLinkAndAllowsRetry() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    openItemEditor(application)
    _ = addBookmark(
      "http://127.0.0.1:1/unavailable", label: "Unavailable website", application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let link = savedBookmarkRows(application).matching(
      NSPredicate(format: "label == %@", "Unavailable website")
    ).firstMatch
    XCTAssertTrue(link.waitForPlannerValue("http://127.0.0.1:1/unavailable"))
    let failure = application.staticTexts["Preview unavailable"]
    XCTAssertTrue(failure.waitForExistence(timeout: 35))
    let retry = application.plannerElement("Retry")
    XCTAssertTrue(retry.isEnabled)
    retry.activateForPlannerJourney()
    XCTAssertTrue(failure.waitForExistence(timeout: 35))
    XCTAssertTrue(link.waitForPlannerValue("http://127.0.0.1:1/unavailable"))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    recordScreenshot(
      application, name: "A provider failure preserves the owned link and native retry")
  }

  func testNativeWebsitePreviewsKeepOwnedLinksAndRemainLiveInAList() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    openItemEditor(application)
    let imageDraft = addBookmark(
      "http://127.0.0.1:44555/image", label: "Museum guide", application: application)
    _ = addBookmark(
      "http://127.0.0.1:44555/plain", label: "Plain website",
      existingURLIdentifiers: [imageDraft], application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let imageLink = savedBookmarkRows(application).matching(
      NSPredicate(format: "label == %@", "Museum guide")
    ).firstMatch
    XCTAssertTrue(imageLink.waitForPlannerValue("http://127.0.0.1:44555/image"))
    let imageIdentity = imageLink.identifier.replacingOccurrences(of: "saved.item.link.", with: "")
    let card = application.descendants(matching: .any)
      .matching(identifier: "saved.item.preview.card.\(imageIdentity)").firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 30))
    XCTAssertTrue(card.waitForPlannerValue("Image available"))
    waitForRenderedPreviewImage(card, application: application)
    recordScreenshot(application, name: "Native rich website card keeps owned bookmark labels")

    createList("Tokyo", application: application)
    addItem(application)
    let membership = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = membership.identifier
    let thumbnail = application.images["saved.item.preview.thumbnail.\(imageIdentity)"]
    XCTAssertTrue(thumbnail.waitForExistence(timeout: 15))
    let localCompletion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    localCompletion.activateForPlannerJourney()
    XCTAssertTrue(localCompletion.waitForPlannerValue("Completed"))
    membership.activateForPlannerJourney()
    XCTAssertTrue(card.waitForExistence(timeout: 10))
    XCTAssertTrue(card.waitForPlannerValue("Image available"))
    waitForRenderedPreviewImage(card, application: application)
    recordScreenshot(application, name: "Live List appearance reuses the native website preview")
    let actions = application.plannerElement("saved.appearance.actions")
    actions.activateForPlannerJourney()
    application.plannerElement("View Item").activateForPlannerJourney()
    openItemEditor(application)
    removeBookmark(imageIdentity, application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertFalse(imageLink.exists)
    XCTAssertFalse(card.exists)
    let plain = savedBookmarkRows(application).matching(
      NSPredicate(format: "label == %@", "Plain website")
    )
    .firstMatch
    XCTAssertTrue(plain.waitForPlannerValue("http://127.0.0.1:44555/plain"))
    let plainIdentity = plain.identifier.replacingOccurrences(of: "saved.item.link.", with: "")
    let plainCard = application.descendants(matching: .any)
      .matching(identifier: "saved.item.preview.card.\(plainIdentity)").firstMatch
    XCTAssertTrue(plainCard.waitForExistence(timeout: 30))
    XCTAssertTrue(plainCard.waitForPlannerValue("No image"))
    recordScreenshot(application, name: "Plain website remains useful without an image")
    openList("Tokyo", application: application)
    XCTAssertEqual(membership.identifier, membershipIdentifier)
    XCTAssertTrue(membership.waitForPlannerValue("Plain website"))
    XCTAssertFalse(thumbnail.exists)
    assertProgress(1, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo", application: application)
    XCTAssertEqual(membership.identifier, membershipIdentifier)
    membership.activateForPlannerJourney()
    XCTAssertTrue(plainCard.waitForExistence(timeout: 30))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(application, name: "Reopening reloads temporary previews from the saved link")
  }

  func testNativeBookmarkValidationEditOrderAndRemovalPreserveItemStateAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openItemEditor(application)
    replaceText(
      application.textFields["saved.item.edit.title"], with: "Rejected title",
      application: application)
    _ = addBookmark(
      "file:///private/tmp/bookmark", label: "Invalid bookmark", application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let alert = application.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    XCTAssertTrue(alert.staticTexts["A bookmark must be an absolute HTTP or HTTPS URL."].exists)
    recordScreenshot(application, name: "Invalid bookmark rejects the staged Item edit")
    alert.buttons["OK"].activateForPlannerJourney()
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Nezu Museum"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["Rejected title"].exists)
    XCTAssertEqual(savedBookmarkRows(application).count, 0)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))

    openItemEditor(application)
    let guideDraftIdentifier = addBookmark(
      "https://example.com/original", label: "Guide", application: application)
    _ = addBookmark(
      "https://maps.apple.com/?q=Nezu", label: "Map",
      existingURLIdentifiers: [guideDraftIdentifier],
      application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let initialGuide = savedBookmarkRows(application).matching(
      NSPredicate(format: "label == %@", "Guide")
    )
    .firstMatch
    let map = savedBookmarkRows(application).matching(NSPredicate(format: "label == %@", "Map"))
      .firstMatch
    XCTAssertTrue(initialGuide.waitForExistence(timeout: 10))
    XCTAssertTrue(map.exists)
    let guideIdentifier = initialGuide.identifier
    let guide = savedBookmarkRows(application).matching(identifier: guideIdentifier).firstMatch
    let mapIdentifier = map.identifier
    let guideIdentity = guideIdentifier.replacingOccurrences(of: "saved.item.link.", with: "")
    let mapIdentity = mapIdentifier.replacingOccurrences(of: "saved.item.link.", with: "")

    openItemEditor(application)
    let guideActions = application.plannerElement("saved.item.edit.link.actions.\(guideIdentity)")
    revealEditorElement(guideActions, application: application)
    XCTAssertTrue(guideActions.waitForExistence(timeout: 5))
    guideActions.activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("Move Up").isEnabled)
    application.plannerElement("Move Down").activateForPlannerJourney()
    revealEditorElement(guideActions, application: application)
    guideActions.activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("Move Down").isEnabled)
    application.plannerElement("Move Up").activateForPlannerJourney()
    revealEditorElement(guideActions, application: application)
    guideActions.activateForPlannerJourney()
    application.plannerElement("Move Down").activateForPlannerJourney()
    let guideURL = application.textFields["saved.item.edit.link.url.\(guideIdentity)"]
    revealEditorElement(guideURL, application: application)
    replaceText(
      guideURL, with: "https://example.com/Revised?Offer=Tea+Cake", application: application)
    let guideLabel = application.textFields["saved.item.edit.link.label.\(guideIdentity)"]
    revealEditorElement(guideLabel, application: application)
    replaceText(guideLabel, with: "Revised guide", application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(guide.waitForPlannerValue("https://example.com/Revised?Offer=Tea+Cake"))
    XCTAssertEqual(guide.label, "Revised guide")
    XCTAssertEqual(
      savedBookmarkRows(application).allElementsBoundByIndex.map(\.identifier),
      [mapIdentifier, guideIdentifier])
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(
      application, name: "Editing and ordering bookmarks preserves their saved identities")

    openItemEditor(application)
    removeBookmark(guideIdentity, application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    openItemEditor(application)
    removeBookmark(guideIdentity, application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 10))
    XCTAssertTrue(map.exists)
    XCTAssertEqual(savedBookmarkRows(application).count, 1)
    openCatalogSection("Items", application: application)
    let mapsOnlyRow = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(mapsOnlyRow.waitForPlannerValue("Maps"))
    recordScreenshot(application, name: "Maps-only Item keeps a compact row hint")
    mapsOnlyRow.activateForPlannerJourney()
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    openItemEditor(application)
    removeBookmark(mapIdentity, application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.item.edit.save").waitForNonExistence(timeout: 10))
    XCTAssertEqual(savedBookmarkRows(application).count, 0)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))

    application.terminate()
    application.launchSavedPlannerJourney()
    openCatalogSection("Items", application: application)
    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    XCTAssertEqual(savedBookmarkRows(application).count, 0)
    XCTAssertFalse(application.staticTexts["Links"].exists)
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(
      application, name: "Removing every bookmark survives reopening without changing Item state")
  }

  func testNativeBookmarksCancelSaveAndRemainLiveAcrossListsAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo", application: application)
    addItem(application)
    let membership = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = membership.identifier
    let localCompletion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    localCompletion.activateForPlannerJourney()
    XCTAssertTrue(localCompletion.waitForPlannerValue("Completed"))
    createList("Wishlist", application: application)
    addItem(application)
    openList("Tokyo", application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openItemEditor(application)
    _ = addBookmark(
      "https://example.com/canceled", label: "Canceled bookmark", application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled bookmark"].exists)
    XCTAssertEqual(savedBookmarkRows(application).count, 0)

    openItemEditor(application)
    let guideURL = "https://example.com/Museum?Offer=Tea+Cake"
    let mapsURL = "https://maps.apple.com/?q=Nezu%20Museum"
    let guideDraftIdentifier = addBookmark(
      guideURL, label: "Museum guide", application: application)
    _ = addBookmark(
      mapsURL, label: "Map bookmark", existingURLIdentifiers: [guideDraftIdentifier],
      application: application)
    recordScreenshot(application, name: "Native bookmark editor reviews two owned links")
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    let guide = savedBookmarkRows(application).matching(
      NSPredicate(format: "label == %@", "Museum guide")
    ).firstMatch
    let maps = savedBookmarkRows(application).matching(
      NSPredicate(format: "label == %@", "Map bookmark")
    ).firstMatch
    XCTAssertTrue(guide.waitForExistence(timeout: 10))
    XCTAssertTrue(guide.waitForPlannerValue(guideURL))
    XCTAssertTrue(maps.waitForPlannerValue(mapsURL))
    let guideIdentifier = guide.identifier
    let mapsIdentifier = maps.identifier
    XCTAssertEqual(savedBookmarkRows(application).count, 2)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(application, name: "Item details show useful owned bookmarks without previews")

    openList("Tokyo", application: application)
    XCTAssertEqual(membership.identifier, membershipIdentifier)
    XCTAssertTrue(membership.waitForPlannerValue("Museum guide"))
    XCTAssertTrue(localCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    membership.activateForPlannerJourney()
    XCTAssertTrue(
      savedBookmarkRows(application).matching(identifier: guideIdentifier).firstMatch
        .waitForExistence(timeout: 10))
    XCTAssertTrue(
      savedBookmarkRows(application).matching(identifier: mapsIdentifier).firstMatch.exists)
    openList("Wishlist", application: application)
    let otherMembership = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(otherMembership.waitForPlannerValue("Museum guide"))
    let otherCompletion = application.buttons[
      otherMembership.identifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(otherCompletion.waitForPlannerValue("To do"))
    otherMembership.activateForPlannerJourney()
    XCTAssertTrue(
      savedBookmarkRows(application).matching(identifier: guideIdentifier).firstMatch
        .waitForExistence(timeout: 10))
    XCTAssertTrue(
      savedBookmarkRows(application).matching(identifier: mapsIdentifier).firstMatch.exists)

    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo", application: application)
    XCTAssertEqual(membership.identifier, membershipIdentifier)
    XCTAssertTrue(membership.waitForPlannerValue("Museum guide"))
    XCTAssertTrue(localCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    membership.activateForPlannerJourney()
    XCTAssertTrue(
      savedBookmarkRows(application).matching(identifier: guideIdentifier).firstMatch
        .waitForPlannerValue(guideURL))
    XCTAssertTrue(
      savedBookmarkRows(application).matching(identifier: mapsIdentifier).firstMatch
        .waitForPlannerValue(mapsURL))
    XCTAssertEqual(savedBookmarkRows(application).count, 2)
    recordScreenshot(
      application, name: "Reopened List retains bookmark identities and local completion")
  }

  func
    testNativeListArchiveFiltersPreserveSourceItemsMembershipOrderAndLocalCompletionAfterRelaunch()
    throws
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Zulu")
    createItem(application, title: "Alpha")
    createList("Tokyo", application: application)
    addItem(application, title: "Zulu")
    addItem(application, title: "Alpha")
    createList("Wishlist", application: application)
    addItem(application, title: "Zulu")
    let tokyo = application.savedPlannerListRow("Tokyo")
    revealSidebarIfNeeded(application, element: tokyo)
    let tokyoIdentifier = tokyo.identifier
    openList("Tokyo", itemTitle: "Zulu", application: application)
    let zulu = application.savedPlannerItemRows("Zulu").firstMatch
    let alpha = application.savedPlannerItemRows("Alpha").firstMatch
    let zuluIdentifier = zulu.identifier
    let alphaIdentifier = alpha.identifier
    let completion = application.buttons[
      zuluIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    assertItemOrder(["Zulu", "Alpha"], application: application)
    let filters = application.plannerElement("saved.lists.archive")
    revealSidebarIfNeeded(application, element: filters)
    openListContextMenu(tokyo)
    application.plannerElement("Archive List").activateForPlannerJourney()
    XCTAssertEqual(filters.label, "Active Lists")
    XCTAssertTrue(application.plannerElement(tokyoIdentifier).waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerListRow("Wishlist").exists)
    chooseFilter("Archived Lists", menu: filters, application: application)
    let archivedTokyo = application.savedPlannerListRow("Tokyo")
    XCTAssertTrue(archivedTokyo.waitForExistence(timeout: 10))
    XCTAssertEqual(archivedTokyo.identifier, tokyoIdentifier)
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value BEGINSWITH %@", "Archived."),
            object: archivedTokyo)
        ],
        timeout: 5), .completed)
    XCTAssertFalse(application.savedPlannerListRow("Wishlist").exists)
    openList("Tokyo", itemTitle: "Zulu", application: application)
    XCTAssertTrue(application.staticTexts["Archived List"].waitForExistence(timeout: 10))
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertEqual(alpha.identifier, alphaIdentifier)
    assertProgress(0.5, application: application)
    assertItemOrder(["Zulu", "Alpha"], application: application)
    recordScreenshot(application, name: "Archived List retains saved order and contextual progress")
    revealSidebarIfNeeded(application, element: filters)
    chooseFilter("All Lists", menu: filters, application: application)
    XCTAssertTrue(archivedTokyo.waitForExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerListRow("Wishlist").waitForExistence(timeout: 10))
    recordScreenshot(application, name: "All Lists filter includes archived and active containers")

    openList("Wishlist", itemTitle: "Zulu", application: application)
    let otherCompletion = application.buttons[
      application.savedPlannerItemRows("Zulu").firstMatch.identifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(otherCompletion.waitForPlannerValue("To do"))
    viewGlobalItem(application, itemTitle: "Zulu")
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertFalse(application.staticTexts["Archived"].exists)
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)

    application.terminate()
    application.launchSavedPlannerJourney()
    revealSidebarIfNeeded(application, element: filters)
    XCTAssertEqual(filters.label, "Active Lists")
    XCTAssertFalse(application.plannerElement(tokyoIdentifier).exists)
    XCTAssertTrue(application.savedPlannerListRow("Wishlist").exists)
    chooseFilter("Archived Lists", menu: filters, application: application)
    XCTAssertTrue(application.plannerElement(tokyoIdentifier).waitForExistence(timeout: 10))
    openList("Tokyo", itemTitle: "Zulu", application: application)
    XCTAssertEqual(application.savedPlannerItemRows("Zulu").firstMatch.identifier, zuluIdentifier)
    XCTAssertEqual(application.savedPlannerItemRows("Alpha").firstMatch.identifier, alphaIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    assertItemOrder(["Zulu", "Alpha"], application: application)
    revealSidebarIfNeeded(application, element: filters)
    openListContextMenu(application.plannerElement(tokyoIdentifier))
    application.plannerElement("Unarchive List").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(tokyoIdentifier).waitForNonExistence(timeout: 10))
    chooseFilter("Active Lists", menu: filters, application: application)
    XCTAssertTrue(application.plannerElement(tokyoIdentifier).waitForExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerListRow("Wishlist").exists)
    openList("Tokyo", itemTitle: "Zulu", application: application)
    XCTAssertTrue(application.staticTexts["Archived List"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    assertItemOrder(["Zulu", "Alpha"], application: application)
    recordScreenshot(
      application, name: "Unarchived List preserves contextual completion after relaunch")
  }

  func testNativeCatalogTabsRemainAvailableAfterClearingInboxSearch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openCatalogSection("Inbox", application: application)
    let search = application.searchFields["Search Inbox"]
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    replaceText(search, with: "garden", application: application)
    replaceText(search, with: "", application: application)
    #if os(iOS)
      let dismissSearch = application.buttons.matching(
        NSPredicate(format: "label IN %@", ["Close", "Hide keyboard"])
      ).firstMatch
      XCTAssertTrue(dismissSearch.waitForExistence(timeout: 5))
      XCTAssertTrue(dismissSearch.waitForPlannerHittability())
      let retainsSearchFocus = dismissSearch.label == "Hide keyboard"
      dismissSearch.activateForPlannerJourney()
      if retainsSearchFocus {
        let catalog = application.collectionViews["Sidebar"].firstMatch
        XCTAssertTrue(catalog.waitForExistence(timeout: 5))
        XCTAssertTrue(catalog.waitForPlannerHittability())
        catalog.activateForPlannerJourney()
      }
    #endif
    recordScreenshot(application, name: "Cleared Inbox search before native tab switch")
    openCatalogSection("Items", application: application)
    let itemSort = application.plannerElement("saved.items.sort")
    XCTAssertTrue(itemSort.waitForExistence(timeout: 5))
    XCTAssertTrue(itemSort.waitForPlannerHittability())
    #if os(iOS)
      XCTAssertTrue(application.buttons["Items"].firstMatch.isSelected)
    #endif
    XCTAssertTrue(application.searchFields["Search Items"].exists)
    recordScreenshot(application, name: "Items catalog after cleared Inbox search")
  }

  func testNativeInboxRetainsUnlistedItemsAndIndependentFiltersSortAndSourceStateAfterRelaunch()
    throws
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Zulu")
    createItem(application, title: "Alpha")
    createItem(application, title: "Middle")
    createList("Tokyo", application: application)
    addItem(application, title: "Zulu")
    let membership = application.savedPlannerItemRows("Zulu").firstMatch
    let localCompletion = application.buttons[
      membership.identifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    localCompletion.activateForPlannerJourney()
    XCTAssertTrue(localCompletion.waitForPlannerValue("Completed"))
    openCatalogSection("Inbox", application: application)
    let sort = application.plannerElement("saved.inbox.sort")
    let filters = application.plannerElement("saved.inbox.filters")
    XCTAssertTrue(sort.waitForExistence(timeout: 5))
    assertSortChoice("Title · Ascending", menu: sort)
    XCTAssertEqual(filters.label, "Todo · Active")
    assertItemOrder(["Alpha", "Middle"], application: application)
    XCTAssertTrue(
      application.savedPlannerItemRows("Zulu").firstMatch.waitForNonExistence(timeout: 5))
    chooseSort("Descending", menu: sort, application: application)
    assertItemOrder(["Middle", "Alpha"], application: application)
    recordScreenshot(application, name: "Native Inbox excludes listed Items")
    let alpha = application.savedPlannerItemRows("Alpha").firstMatch
    let alphaIdentifier = alpha.identifier
    alpha.activateForPlannerJourney()
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
    XCTAssertTrue(
      application.savedPlannerItemRows("Alpha").firstMatch.waitForNonExistence(timeout: 5))
    chooseFilter("All completion states", menu: filters, application: application)
    assertItemOrder(["Middle", "Alpha"], application: application)
    application.savedPlannerItemRows("Alpha").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    #if os(iOS)
      if back.exists { back.activateForPlannerJourney() }
    #endif
    XCTAssertTrue(application.plannerElement(alphaIdentifier).waitForNonExistence(timeout: 5))
    chooseFilter("All archive states", menu: filters, application: application)
    let archivedAlpha = application.plannerElement(alphaIdentifier)
    XCTAssertTrue(archivedAlpha.waitForExistence(timeout: 10))
    XCTAssertLessThan(
      application.savedPlannerItemRows("Middle").firstMatch.frame.midY, archivedAlpha.frame.midY)
    XCTAssertEqual(filters.label, "All")
    XCTAssertFalse(application.savedPlannerItemRows("Zulu").firstMatch.exists)
    recordScreenshot(
      application, name: "Inbox includes archived completed Items through cumulative filters")
    let search = application.searchFields["Search Inbox"]
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    replaceText(search, with: "alpha garden", application: application)
    XCTAssertTrue(archivedAlpha.waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.savedPlannerItemRows("Middle").firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertFalse(application.savedPlannerItemRows("Zulu").firstMatch.exists)
    replaceText(search, with: "", application: application)
    XCTAssertTrue(
      application.savedPlannerItemRows("Middle").firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(archivedAlpha.exists)
    XCTAssertEqual(filters.label, "All")
    #if os(iOS)
      let dismissSearch = application.buttons.matching(
        NSPredicate(format: "label IN %@", ["Close", "Hide keyboard"])
      ).firstMatch
      XCTAssertTrue(dismissSearch.waitForExistence(timeout: 5))
      XCTAssertTrue(dismissSearch.waitForPlannerHittability())
      let retainsSearchFocus = dismissSearch.label == "Hide keyboard"
      dismissSearch.activateForPlannerJourney()
      if retainsSearchFocus {
        let catalog = application.collectionViews["Sidebar"].firstMatch
        XCTAssertTrue(catalog.waitForExistence(timeout: 5))
        XCTAssertTrue(catalog.waitForPlannerHittability())
        catalog.activateForPlannerJourney()
      }
    #endif
    openCatalogSection("Items", application: application)
    let itemSort = application.plannerElement("saved.items.sort")
    assertSortChoice("Title · Ascending", menu: itemSort)
    XCTAssertEqual(application.plannerElement("saved.items.filters").label, "Active")
    chooseSort("Created", menu: itemSort, application: application)
    chooseSort("Descending", menu: itemSort, application: application)
    openCatalogSection("Inbox", application: application)
    assertSortChoice("Title · Descending", menu: sort)
    XCTAssertEqual(filters.label, "All")
    XCTAssertTrue(archivedAlpha.waitForExistence(timeout: 10))
    XCTAssertLessThan(
      application.savedPlannerItemRows("Middle").firstMatch.frame.midY, archivedAlpha.frame.midY)
    openList("Tokyo", itemTitle: "Zulu", application: application)
    XCTAssertTrue(localCompletion.waitForPlannerValue("Completed"))
    #if os(macOS)
      membership.rightClick()
    #else
      membership.press(forDuration: 1)
    #endif
    application.plannerElement("Remove from List").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openCatalogSection("Inbox", application: application)
    assertItemOrder(["Zulu", "Middle"], application: application)
    XCTAssertTrue(archivedAlpha.waitForExistence(timeout: 10))
    XCTAssertLessThan(
      application.savedPlannerItemRows("Middle").firstMatch.frame.midY, archivedAlpha.frame.midY)
    application.savedPlannerItemRows("Zulu").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    application.terminate()
    application.launchSavedPlannerJourney()
    openCatalogSection("Inbox", application: application)
    assertSortChoice("Title · Descending", menu: sort)
    XCTAssertEqual(filters.label, "Todo · Active")
    assertItemOrder(["Zulu", "Middle"], application: application)
    XCTAssertFalse(application.plannerElement(alphaIdentifier).exists)
    recordScreenshot(application, name: "Relaunched Inbox retains sort and last-membership removal")
    openCatalogSection("Items", application: application)
    assertSortChoice("Created · Descending", menu: itemSort)
    assertItemOrder(["Middle", "Zulu"], application: application)
  }

  func testNativeItemSortUsesCanonicalModesAndRemembersDatasetScopedDeviceChoiceAfterRelaunch()
    throws
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    let datasetIdentifier = UUID().uuidString
    application.launchArguments = ["--local-prototype-dataset", datasetIdentifier]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Zulu")
    createItem(application, title: "Alpha")
    createItem(application, title: "Middle")
    openSection("Items", application: application)
    if !application.savedPlannerItemRows("Alpha").firstMatch.isHittable {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }
    let sort = application.plannerElement("saved.items.sort")
    XCTAssertTrue(sort.waitForExistence(timeout: 5))
    assertSortChoice("Title · Ascending", menu: sort)
    assertItemOrder(["Alpha", "Middle", "Zulu"], application: application)
    chooseSort("Descending", menu: sort, application: application)
    assertItemOrder(["Zulu", "Middle", "Alpha"], application: application)
    chooseSort("Created", menu: sort, application: application)
    assertItemOrder(["Middle", "Alpha", "Zulu"], application: application)
    chooseSort("Ascending", menu: sort, application: application)
    assertItemOrder(["Zulu", "Alpha", "Middle"], application: application)
    chooseSort("Duration", menu: sort, application: application)
    assertItemOrder(["Alpha", "Middle", "Zulu"], application: application)
    chooseSort("Descending", menu: sort, application: application)
    assertItemOrder(["Alpha", "Middle", "Zulu"], application: application)
    chooseSort("Last updated", menu: sort, application: application)
    assertItemOrder(["Middle", "Alpha", "Zulu"], application: application)
    assertSortChoice("Last updated · Descending", menu: sort)
    recordScreenshot(application, name: "Native Item chronological sort with device choice")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    assertSortChoice("Last updated · Descending", menu: sort)
    assertItemOrder(["Middle", "Alpha", "Zulu"], application: application)
    application.terminate()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    assertSortChoice("Title · Ascending", menu: sort)
    XCTAssertTrue(
      application.savedPlannerItemRows("Zulu").firstMatch.waitForNonExistence(timeout: 5))
    application.terminate()
    application.launchArguments = ["--local-prototype-dataset", datasetIdentifier]
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    assertSortChoice("Last updated · Descending", menu: sort)
    assertItemOrder(["Middle", "Alpha", "Zulu"], application: application)
    recordScreenshot(application, name: "Returning dataset retains native Item sort")
  }

  func testNativeListSortRemembersEachListAndPreservesManualOrderAppearanceCompletionAndProgress()
    throws
  {
    continueAfterFailure = false
    #if os(iOS)
      /// Native iOS progress accessibility exposes whole percentages.
      let completedFraction = 0.33
    #else
      let completedFraction = 1.0 / 3.0
    #endif
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Zulu")
    createItem(application, title: "Alpha")
    createItem(application, title: "Middle")
    createList("Tokyo", application: application)
    addItem(application, title: "Zulu")
    addItem(application, title: "Alpha")
    addItem(application, title: "Middle")
    let sort = application.plannerElement("saved.list.sort")
    XCTAssertTrue(sort.waitForExistence(timeout: 5))
    assertSortChoice("Manual", menu: sort)
    assertItemOrder(["Zulu", "Alpha", "Middle"], application: application)
    let titles = ["Zulu", "Alpha", "Middle"]
    let originalIdentities = titles.map {
      application.savedPlannerItemRows($0).firstMatch.identifier
    }
    let completion = application.buttons[
      originalIdentities[0].replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(completedFraction, application: application)
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    #if os(iOS)
      let edit = application.plannerElement("saved.list.edit")
      XCTAssertEqual(edit.plannerControlTitle, "Edit")
      edit.activateForPlannerJourney()
    #endif
    chooseSort("Title", menu: sort, application: application)
    assertSortChoice("Title · Ascending", menu: sort)
    assertItemOrder(["Alpha", "Middle", "Zulu"], application: application)
    #if os(iOS)
      XCTAssertFalse(edit.isEnabled)
      XCTAssertEqual(edit.plannerControlTitle, "Edit")
    #endif
    chooseSort("Descending", menu: sort, application: application)
    assertItemOrder(["Zulu", "Middle", "Alpha"], application: application)
    chooseSort("Created", menu: sort, application: application)
    chooseSort("Ascending", menu: sort, application: application)
    assertItemOrder(["Zulu", "Alpha", "Middle"], application: application)
    chooseSort("Manual", menu: sort, application: application)
    assertSortChoice("Manual", menu: sort)
    assertItemOrder(["Zulu", "Alpha", "Middle"], application: application)
    #if os(iOS)
      XCTAssertTrue(edit.isEnabled)
      XCTAssertEqual(edit.plannerControlTitle, "Edit")
    #endif
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(completedFraction, application: application)
    XCTAssertEqual(
      titles.map { application.savedPlannerItemRows($0).firstMatch.identifier }, originalIdentities)
    recordScreenshot(application, name: "Manual order restored with retained List completion")
    createList("Weekend", application: application)
    addItem(application, title: "Alpha")
    addItem(application, title: "Zulu")
    addItem(application, title: "Middle")
    assertSortChoice("Manual", menu: sort)
    chooseSort("Title", menu: sort, application: application)
    chooseSort("Descending", menu: sort, application: application)
    assertItemOrder(["Zulu", "Middle", "Alpha"], application: application)
    openList("Tokyo", itemTitle: "Zulu", application: application)
    assertSortChoice("Manual", menu: sort)
    chooseSort("Title", menu: sort, application: application)
    assertSortChoice("Title · Ascending", menu: sort)
    assertItemOrder(["Alpha", "Middle", "Zulu"], application: application)
    openList("Weekend", itemTitle: "Zulu", application: application)
    assertSortChoice("Title · Descending", menu: sort)
    assertProgress(0, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo", itemTitle: "Zulu", application: application)
    assertSortChoice("Title · Ascending", menu: sort)
    assertItemOrder(["Alpha", "Middle", "Zulu"], application: application)
    assertProgress(completedFraction, application: application)
    XCTAssertEqual(
      titles.map { application.savedPlannerItemRows($0).firstMatch.identifier }, originalIdentities)
    chooseSort("Manual", menu: sort, application: application)
    assertItemOrder(["Zulu", "Alpha", "Middle"], application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    recordScreenshot(application, name: "Relaunched List keeps its own sort and source order")
    openList("Weekend", itemTitle: "Zulu", application: application)
    assertSortChoice("Title · Descending", menu: sort)
    assertItemOrder(["Zulu", "Middle", "Alpha"], application: application)
    assertProgress(0, application: application)
    openList("Tokyo", itemTitle: "Zulu", application: application)
    viewGlobalItem(application, itemTitle: "Zulu")
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForPlannerBooleanState(false))
  }

  func testNativeListSearchKeepsArchivedCompletionProgressAndValidDetailAcrossCumulativeFilters()
    throws
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createItem(application, title: "Hotel")
    createList("Tokyo Food", application: application)
    addItem(application)
    addItem(application, title: "Hotel")
    let museum = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = museum.identifier
    let completion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    viewGlobalItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    openList("Tokyo Food", application: application)
    assertProgress(0.5, application: application)
    let search = application.searchFields["Search this List"]
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5), application.debugDescription)
    museum.activateForPlannerJourney()
    let keepsSimultaneousDetail = search.isHittable
    if !keepsSimultaneousDetail {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }
    replaceText(search, with: "nezu garden", application: application)
    XCTAssertTrue(museum.waitForExistence(timeout: 10))
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(hotel.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Showing 1 of 2 items"].exists)
    assertProgress(0.5, application: application)
    recordScreenshot(application, name: "List search shows one match and full archived progress")
    let filters = application.plannerElement("saved.list.filters")
    application.chooseSavedPlannerStateFilter("Active", control: filters)
    XCTAssertTrue(museum.waitForNonExistence(timeout: 10))
    XCTAssertFalse(hotel.exists)
    XCTAssertTrue(application.staticTexts["Showing 0 of 2 items"].exists)
    assertProgress(0.5, application: application)
    if keepsSimultaneousDetail {
      XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
      XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    }
    recordScreenshot(application, name: "Active search hides the row and retains valid detail")
    application.chooseSavedPlannerStateFilter("All archive states", control: filters)
    XCTAssertTrue(museum.waitForExistence(timeout: 10))
    XCTAssertFalse(hotel.exists)
    replaceText(search, with: "", application: application)
    XCTAssertTrue(museum.waitForExistence(timeout: 10))
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    XCTAssertEqual(museum.identifier, membershipIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    recordScreenshot(application, name: "All archive states and cleared search restore both rows")
  }

  func testNativeItemSearchMatchesEveryWordAcrossSharedContentAndClearsWithoutEditingItems()
    throws
  {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Café Lunch")
    createItem(application, title: "Hotel")
    openSection("Items", application: application)
    let cafe = application.savedPlannerItemRows("Café Lunch").firstMatch
    if !cafe.isHittable {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }
    let search = application.searchFields.firstMatch
    if !search.exists { application.swipeDown() }
    XCTAssertTrue(search.waitForExistence(timeout: 5), application.debugDescription)
    replaceText(search, with: "cafe garden", application: application)
    XCTAssertTrue(cafe.waitForExistence(timeout: 10))
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(hotel.waitForNonExistence(timeout: 10))
    recordScreenshot(application, name: "Native search matches title and notes across one Item")
    replaceText(search, with: "cafe hotel", application: application)
    XCTAssertTrue(cafe.waitForNonExistence(timeout: 10))
    XCTAssertFalse(hotel.exists)
    replaceText(search, with: "", application: application)
    XCTAssertTrue(cafe.waitForExistence(timeout: 10))
    XCTAssertTrue(hotel.waitForExistence(timeout: 10))
    cafe.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    recordScreenshot(application, name: "Clearing native search keeps Item content and Todo")
  }

  func testSubtitlePreviewUpdatesTheListRowAndCanBeClearedWithoutChangingCompletion() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let row = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = row.identifier
    let completion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    viewGlobalItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let editItem = application.plannerElement("Edit Item")
    editItem.activateForPlannerJourney()
    let subtitle = application.textFields["saved.item.edit.subtitle"]
    XCTAssertTrue(subtitle.waitForExistence(timeout: 5))
    replaceText(subtitle, with: "Museum and garden", application: application)
    let save = application.plannerElement("saved.item.edit.save")
    XCTAssertTrue(save.isEnabled)
    recordScreenshot(application, name: "Native editor reviews the shared row subtitle")
    save.activateForPlannerJourney()
    XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    XCTAssertTrue(
      application.staticTexts["Museum and garden"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    openList("Tokyo Food", application: application)
    XCTAssertEqual(row.identifier, membershipIdentifier)
    XCTAssertTrue(row.waitForPlannerValue("Museum and garden"))
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Shared subtitle appears in the completed List row")
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertEqual(row.identifier, membershipIdentifier)
    XCTAssertTrue(row.waitForPlannerValue("Museum and garden"))
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    editItem.activateForPlannerJourney()
    XCTAssertTrue(subtitle.waitForExistence(timeout: 5))
    XCTAssertTrue(subtitle.waitForPlannerValue("Museum and garden"))
    replaceText(subtitle, with: "", application: application)
    XCTAssertTrue(save.isEnabled)
    save.activateForPlannerJourney()
    XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openList("Tokyo Food", application: application)
    XCTAssertEqual(row.identifier, membershipIdentifier)
    XCTAssertTrue(row.waitForPlannerValue(""))
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    XCTAssertFalse(application.staticTexts["Museum and garden"].exists)
    recordScreenshot(
      application, name: "Clearing the subtitle keeps the compact completed List row")
  }

  func testEditingOneFieldAtATimePreservesOtherContentAndGlobalCompletionAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let originalRow = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = originalRow.identifier
    let completion = application.buttons[
      membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let editItem = application.plannerElement("Edit Item")
    XCTAssertTrue(editItem.waitForExistence(timeout: 5))
    editItem.activateForPlannerJourney()
    let titleField = application.textFields["saved.item.edit.title"]
    let notesField = application.textFields["saved.item.edit.notes"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    XCTAssertTrue(notesField.waitForPlannerValue("Meet at the garden entrance"))
    replaceText(titleField, with: "Nezu Garden", application: application)
    let save = application.plannerElement("saved.item.edit.save")
    save.activateForPlannerJourney()
    XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Nezu Garden"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    editItem.activateForPlannerJourney()
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    XCTAssertTrue(titleField.waitForPlannerValue("Nezu Garden"))
    replaceText(notesField, with: "", application: application)
    XCTAssertTrue(save.isEnabled)
    save.activateForPlannerJourney()
    XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Notes"].exists)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    recordScreenshot(
      application, name: "Clearing only notes retains the edited title and global Done")
    openList("Tokyo Food", itemTitle: "Nezu Garden", application: application)
    let updatedRow = application.savedPlannerItemRows("Nezu Garden").firstMatch
    XCTAssertEqual(updatedRow.identifier, membershipIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertFalse(completion.isEnabled)
    assertProgress(1, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", itemTitle: "Nezu Garden", application: application)
    XCTAssertEqual(updatedRow.identifier, membershipIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertFalse(completion.isEnabled)
    assertProgress(1, application: application)
    recordScreenshot(
      application, name: "Relaunch retains global Done after independent content edits")
    viewGlobalItem(application, itemTitle: "Nezu Garden")
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    XCTAssertFalse(application.staticTexts["Notes"].exists)
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openList("Tokyo Food", itemTitle: "Nezu Garden", application: application)
    XCTAssertEqual(updatedRow.identifier, membershipIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    XCTAssertTrue(completion.isEnabled)
    assertProgress(0, application: application)
  }

  func testEditingAnItemUpdatesItsLiveListReferencesAndKeepsTheirCompletionAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let originalRow = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let sourceIdentifier = originalRow.identifier
    let sourceCompletion = application.buttons[
      sourceIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    sourceCompletion.activateForPlannerJourney()
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    createList("Wishlist", application: application)
    addItem(application)
    let destinationIdentifier = originalRow.identifier
    let destinationCompletion = application.buttons[
      destinationIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let editItem = application.plannerElement("Edit Item")
    XCTAssertTrue(editItem.waitForExistence(timeout: 5))
    editItem.activateForPlannerJourney()
    let titleField = application.textFields["saved.item.edit.title"]
    let notesField = application.textFields["saved.item.edit.notes"]
    let save = application.plannerElement("saved.item.edit.save")
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    XCTAssertTrue(titleField.waitForPlannerValue("Nezu Museum"))
    XCTAssertTrue(notesField.waitForPlannerValue("Meet at the garden entrance"))
    XCTAssertFalse(save.isEnabled)
    replaceText(titleField, with: "Cancelled title", application: application)
    replaceText(notesField, with: "Cancelled notes", application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Cancelled notes"].exists)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    editItem.activateForPlannerJourney()
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    XCTAssertTrue(titleField.waitForPlannerValue("Nezu Museum"))
    XCTAssertTrue(notesField.waitForPlannerValue("Meet at the garden entrance"))
    replaceText(titleField, with: "", application: application)
    XCTAssertFalse(save.isEnabled)
    replaceText(titleField, with: "Nezu Museum Garden", application: application)
    replaceText(notesField, with: "Meet at the north gate", application: application)
    XCTAssertTrue(save.isEnabled)
    recordScreenshot(application, name: "Native Item editor reviews shared title and notes")
    save.activateForPlannerJourney()
    XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the north gate"].waitForExistence(timeout: 10))
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    let updatedRow = application.savedPlannerItemRows("Nezu Museum Garden").firstMatch
    openList("Tokyo Food", itemTitle: "Nezu Museum Garden", application: application)
    XCTAssertEqual(updatedRow.identifier, sourceIdentifier)
    XCTAssertFalse(originalRow.exists)
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    updatedRow.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Meet at the north gate"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
    recordScreenshot(application, name: "Saved Item edit updates the locally Done List reference")
    openList("Wishlist", itemTitle: "Nezu Museum Garden", application: application)
    XCTAssertEqual(updatedRow.identifier, destinationIdentifier)
    XCTAssertFalse(originalRow.exists)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", itemTitle: "Nezu Museum Garden", application: application)
    XCTAssertEqual(updatedRow.identifier, sourceIdentifier)
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    openList("Wishlist", itemTitle: "Nezu Museum Garden", application: application)
    XCTAssertEqual(updatedRow.identifier, destinationIdentifier)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    updatedRow.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Meet at the north gate"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["In Wishlist"].exists)
    recordScreenshot(
      application, name: "Relaunch preserves edited content and independent local Todo")
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
    viewGlobalItem(application, itemTitle: "Nezu Museum Garden")
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the north gate"].exists)
  }

  func testAddingFromListDetailAndRowMenuKeepsTheOriginalContextAndExistingDestination() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createItem(application, title: "Hotel")
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let sourceIdentifier = item.identifier
    let sourceCompletion = application.buttons[
      sourceIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    sourceCompletion.activateForPlannerJourney()
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    createList("Wishlist", application: application)
    openList("Tokyo Food", application: application)
    item.activateForPlannerJourney()
    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    let addToList = application.plannerElement("Add to List")
    XCTAssertTrue(addToList.waitForExistence(timeout: 5))
    addToList.activateForPlannerJourney()
    let destination = moveDestination("Wishlist", application: application)
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    let add = application.plannerElement("saved.item.list.add")
    add.activateForPlannerJourney()
    XCTAssertTrue(add.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].exists)
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(application, name: "Adding elsewhere retains the selected List detail")
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
    XCTAssertEqual(item.identifier, sourceIdentifier)
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    openList("Wishlist", application: application)
    let destinationIdentifier = item.identifier
    XCTAssertNotEqual(destinationIdentifier, sourceIdentifier)
    let destinationCompletion = application.buttons[
      destinationIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    destinationCompletion.activateForPlannerJourney()
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("Completed"))
    addItem(application, title: "Hotel")
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(hotel.waitForExistence(timeout: 5))
    XCTAssertLessThan(item.frame.midY, hotel.frame.midY)
    openList("Tokyo Food", application: application)
    #if os(macOS)
      item.rightClick()
    #else
      item.press(forDuration: 1)
    #endif
    XCTAssertTrue(addToList.waitForExistence(timeout: 5))
    addToList.activateForPlannerJourney()
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    add.activateForPlannerJourney()
    XCTAssertTrue(add.waitForNonExistence(timeout: 10))
    XCTAssertEqual(item.identifier, sourceIdentifier)
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, destinationIdentifier)
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(hotel.waitForExistence(timeout: 5))
    XCTAssertLessThan(item.frame.midY, hotel.frame.midY)
    assertProgress(0.5, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertEqual(item.identifier, sourceIdentifier)
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, destinationIdentifier)
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(hotel.waitForExistence(timeout: 5))
    XCTAssertLessThan(item.frame.midY, hotel.frame.midY)
    assertProgress(0.5, application: application)
    recordScreenshot(
      application, name: "Row-menu addition preserves existing destination after relaunch")
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
  }

  func testAddingFromGlobalItemDetailWithoutListsExplainsTheEmptyStateAndCancels() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let addToList = application.plannerElement("Add to List")
    XCTAssertTrue(addToList.waitForExistence(timeout: 5))
    addToList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Lists yet"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Create a List before adding this Item."].exists)
    let add = application.plannerElement("saved.item.list.add")
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    XCTAssertFalse(add.isEnabled)
    recordScreenshot(application, name: "Add to List explains that no destination exists")
    application.plannerElement("saved.item.list.cancel").activateForPlannerJourney()
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    openSection("Lists", application: application)
    XCTAssertTrue(application.staticTexts["No Lists yet"].waitForExistence(timeout: 10))
  }

  func testAddingFromGlobalItemDetailRetainsItsSourceAndRevealsNewLocalTodoAfterReopening() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let sourceIdentifier = item.identifier
    let sourceCompletion = application.buttons[
      sourceIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    sourceCompletion.activateForPlannerJourney()
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    createList("Wishlist", application: application)
    openList("Tokyo Food", application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let addToList = application.plannerElement("Add to List")
    XCTAssertTrue(addToList.waitForExistence(timeout: 5))
    addToList.activateForPlannerJourney()
    let add = application.plannerElement("saved.item.list.add")
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    XCTAssertFalse(add.isEnabled)
    let destination = moveDestination("Wishlist", application: application)
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    application.plannerElement("saved.item.list.cancel").activateForPlannerJourney()
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openSection("Lists", application: application)
    let wishlist = application.savedPlannerListRow("Wishlist")
    revealSidebarIfNeeded(application, element: wishlist)
    wishlist.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openList("Tokyo Food", application: application)
    XCTAssertEqual(item.identifier, sourceIdentifier)
    viewGlobalItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    addToList.activateForPlannerJourney()
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    recordScreenshot(application, name: "Global Item reviews adding a live reference to Wishlist")
    add.activateForPlannerJourney()
    XCTAssertTrue(add.waitForNonExistence(timeout: 10))
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    openList("Wishlist", application: application)
    let destinationIdentifier = item.identifier
    XCTAssertNotEqual(destinationIdentifier, sourceIdentifier)
    let destinationCompletion = application.buttons[
      destinationIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("Completed"))
    XCTAssertFalse(destinationCompletion.isEnabled)
    assertProgress(1, application: application)
    recordScreenshot(application, name: "New List reference inherits global Done display")
    viewGlobalItem(application)
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openList("Wishlist", application: application)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    XCTAssertTrue(destinationCompletion.isEnabled)
    assertProgress(0, application: application)
    viewGlobalItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    addToList.activateForPlannerJourney()
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    add.activateForPlannerJourney()
    XCTAssertTrue(add.waitForNonExistence(timeout: 10))
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, destinationIdentifier)
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertEqual(item.identifier, sourceIdentifier)
    XCTAssertTrue(sourceCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, destinationIdentifier)
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    recordScreenshot(application, name: "Relaunch preserves new local Todo after global reopening")
    viewGlobalItem(application)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
  }

  func testRowMenuMoveKeepsAnExistingDestinationIdentityCompletionAndOrderAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createItem(application, title: "Hotel")
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let removedIdentifier = item.identifier
    createList("Wishlist", application: application)
    addItem(application)
    addItem(application, title: "Hotel")
    let retainedIdentifier = item.identifier
    let retainedCompletion = application.buttons[
      retainedIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    retainedCompletion.activateForPlannerJourney()
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    assertProgress(0.5, application: application)
    let hotel = application.savedPlannerItemRows("Hotel").firstMatch
    XCTAssertTrue(hotel.waitForExistence(timeout: 5))
    XCTAssertLessThan(item.frame.midY, hotel.frame.midY)
    openList("Tokyo Food", application: application)
    XCTAssertEqual(item.identifier, removedIdentifier)
    #if os(macOS)
      item.rightClick()
    #else
      item.press(forDuration: 1)
    #endif
    let moveToList = application.plannerElement("Move to List")
    XCTAssertTrue(moveToList.waitForExistence(timeout: 5))
    moveToList.activateForPlannerJourney()
    let destination = moveDestination("Wishlist", application: application)
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    recordScreenshot(application, name: "Row-menu move reviews an already populated destination")
    application.plannerElement("saved.membership.move").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, retainedIdentifier)
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(hotel.waitForExistence(timeout: 5))
    XCTAssertLessThan(item.frame.midY, hotel.frame.midY)
    assertProgress(0.5, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let emptiedList = application.savedPlannerListRow("Tokyo Food")
    revealSidebarIfNeeded(application, element: emptiedList)
    emptiedList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, retainedIdentifier)
    XCTAssertEqual(application.savedPlannerItemRows("Nezu Museum").count, 1)
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    XCTAssertTrue(hotel.waitForExistence(timeout: 5))
    XCTAssertLessThan(item.frame.midY, hotel.frame.midY)
    assertProgress(0.5, application: application)
    recordScreenshot(application, name: "Existing destination keeps identity completion and order")
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
  }

  func testMovingASelectedListItemCancelsWithoutChangeThenCreatesANewTodoDestination() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let originalIdentifier = item.identifier
    let originalCompletion = application.buttons[
      originalIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    originalCompletion.activateForPlannerJourney()
    XCTAssertTrue(originalCompletion.waitForPlannerValue("Completed"))
    createList("Wishlist", application: application)
    openList("Tokyo Food", application: application)
    item.activateForPlannerJourney()
    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    let moveToList = application.plannerElement("Move to List")
    XCTAssertTrue(moveToList.waitForExistence(timeout: 5))
    moveToList.activateForPlannerJourney()
    let move = application.plannerElement("saved.membership.move")
    XCTAssertTrue(move.waitForExistence(timeout: 5))
    XCTAssertFalse(move.isEnabled)
    XCTAssertFalse(moveDestination("Tokyo Food", application: application).exists)
    let destination = moveDestination("Wishlist", application: application)
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    recordScreenshot(application, name: "Native move destination review before cancellation")
    application.plannerElement("saved.membership.move.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].exists)
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertEqual(item.identifier, originalIdentifier)
    XCTAssertTrue(originalCompletion.waitForPlannerValue("Completed"))
    item.activateForPlannerJourney()
    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    moveToList.activateForPlannerJourney()
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    destination.activateForPlannerJourney()
    move.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    XCTAssertFalse(application.progressIndicators["saved.list.progress"].exists)
    recordScreenshot(application, name: "Source List after confirmed native move")
    openList("Wishlist", application: application)
    let destinationIdentifier = item.identifier
    XCTAssertNotEqual(destinationIdentifier, originalIdentifier)
    let destinationCompletion = application.buttons[
      destinationIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    viewGlobalItem(application)
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let emptiedList = application.savedPlannerListRow("Tokyo Food")
    revealSidebarIfNeeded(application, element: emptiedList)
    emptiedList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, destinationIdentifier)
    XCTAssertTrue(destinationCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    item.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Wishlist"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(
      application, name: "Moved Item retains its new Todo destination after relaunch")
  }

  func testRemovingAnUnselectedListItemFromItsRowMenuKeepsTheSharedItem() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(item.waitForPlannerHittability())
    #if os(macOS)
      item.rightClick()
    #else
      item.press(forDuration: 1)
    #endif
    let remove = application.plannerElement("Remove from List")
    XCTAssertTrue(remove.waitForExistence(timeout: 5))
    remove.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    XCTAssertFalse(application.progressIndicators["saved.list.progress"].exists)
    recordScreenshot(application, name: "Native row menu removes an unselected List membership")
    openSection("Items", application: application)
    revealSidebarIfNeeded(application, element: application.plannerElement("saved.item.new"))
    let retainedItem = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
    ).matching(
      NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Nezu Museum", "Nezu Museum")
    ).firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
  }

  func testRemovingASelectedListItemKeepsItsSourceAndOtherListStateWhileReAddStartsTodo() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let removedIdentifier = item.identifier
    let removedCompletion = application.buttons[
      removedIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    removedCompletion.activateForPlannerJourney()
    XCTAssertTrue(removedCompletion.waitForPlannerValue("Completed"))
    createList("Wishlist", application: application)
    addItem(application)
    let retainedIdentifier = item.identifier
    let retainedCompletion = application.buttons[
      retainedIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    retainedCompletion.activateForPlannerJourney()
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    openList("Tokyo Food", application: application)
    item.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 5))
    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    let remove = application.plannerElement("Remove from List")
    XCTAssertTrue(remove.waitForExistence(timeout: 5))
    remove.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["The Item remains available in Items."].exists)
    XCTAssertFalse(item.exists)
    XCTAssertFalse(application.progressIndicators["saved.list.progress"].exists)
    recordScreenshot(
      application, name: "Selected List item removed while shared source is retained")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Lists", application: application)
    let emptyList = application.savedPlannerListRow("Tokyo Food")
    revealSidebarIfNeeded(application, element: emptyList)
    emptyList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, retainedIdentifier)
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    viewGlobalItem(application)
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openSection("Lists", application: application)
    revealSidebarIfNeeded(application, element: emptyList)
    emptyList.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    addItem(application)
    XCTAssertNotEqual(item.identifier, removedIdentifier)
    let replacementCompletion = application.buttons[
      item.identifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")]
    XCTAssertTrue(replacementCompletion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    recordScreenshot(
      application, name: "Ordinary List re-add starts Todo with the same shared Item")
    openList("Wishlist", application: application)
    XCTAssertEqual(item.identifier, retainedIdentifier)
    XCTAssertTrue(retainedCompletion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
  }

  func testArchivedItemWithoutAListCanBeFoundAndUnarchivedInTheItemsCatalog() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    let filters = application.plannerElement("saved.items.filters")
    revealSidebarIfNeeded(application, element: application.plannerElement("saved.item.new"))
    XCTAssertTrue(filters.waitForExistence(timeout: 5))
    XCTAssertEqual(filters.plannerControlTitle, "Active")
    application.chooseSavedPlannerStateFilter("Archived", control: filters)
    #if os(macOS)
      let archivedItem = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
      ).matching(
        NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Nezu Museum", "Nezu Museum")
      ).firstMatch
    #else
      let archivedItem = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
      ).matching(NSPredicate(format: "label CONTAINS %@", "Nezu Museum")).firstMatch
    #endif
    XCTAssertTrue(archivedItem.waitForExistence(timeout: 10))
    archivedItem.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Archived"].exists)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Unarchive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    recordScreenshot(application, name: "Unlisted archived Item restored through the Items catalog")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSection("Items", application: application)
    revealSidebarIfNeeded(application, element: application.plannerElement("saved.item.new"))
    XCTAssertEqual(filters.plannerControlTitle, "Active")
    XCTAssertTrue(archivedItem.waitForExistence(timeout: 10))
    archivedItem.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
  }

  func testSavedListFiltersIncludeArchivedItemsAndKeepFullProgressWithNoMatches() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let completion = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.completion.")
    ).firstMatch
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    viewGlobalItem(application)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    openList("Tokyo Food", application: application)
    let item = application.savedPlannerItemRows("Nezu Museum").firstMatch
    let membershipIdentifier = item.identifier
    let filters = application.plannerElement("saved.list.filters")
    XCTAssertTrue(filters.waitForExistence(timeout: 5))
    XCTAssertEqual(filters.plannerControlTitle, "All")
    assertProgress(1, application: application)
    item.activateForPlannerJourney()
    let keepsSimultaneousDetail = filters.isHittable
    if !keepsSimultaneousDetail {
      application.plannerElement("BackButton").activateForPlannerJourney()
    }

    application.chooseSavedPlannerStateFilter("Active", control: filters)
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    XCTAssertTrue(application.staticTexts["1 of 1 item done"].exists)
    XCTAssertTrue(application.staticTexts["Showing 0 of 1 item"].exists)
    assertProgress(1, application: application)
    if keepsSimultaneousDetail {
      XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
      XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    }
    application.chooseSavedPlannerStateFilter("Todo", control: filters)
    XCTAssertEqual(filters.plannerControlTitle, "Todo · Active")
    application.chooseSavedPlannerStateFilter("Archived", control: filters)
    XCTAssertEqual(filters.plannerControlTitle, "Todo · Archived")
    XCTAssertFalse(item.exists)
    assertProgress(1, application: application)
    recordScreenshot(
      application, name: "Saved cumulative filters with full progress and no matches")

    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertEqual(item.identifier, membershipIdentifier)
    XCTAssertEqual(filters.plannerControlTitle, "Archived")
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    application.chooseSavedPlannerStateFilter("Done", control: filters)
    XCTAssertEqual(filters.plannerControlTitle, "Done · Archived")
    completion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    assertProgress(0, application: application)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].exists)
    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    application.chooseSavedPlannerStateFilter("All archive states", control: filters)
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertEqual(item.identifier, membershipIdentifier)
    XCTAssertEqual(filters.plannerControlTitle, "All")
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    recordScreenshot(application, name: "Saved archived Item visible with All filters")
  }

  func testItemArchivePreservesItsSavedListReferenceAndLocalCompletion() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let completion = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.completion.")
    ).firstMatch
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)

    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Saved archived Item retains List progress")
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    viewGlobalItem(application)
    XCTAssertTrue(application.staticTexts["Archived"].waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Unarchive Item").activateForPlannerJourney()
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(
      application.staticTexts["Archived"].waitForNonExistence(timeout: 10))
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
  }

  func testListCompletionStaysLocalWhileGlobalCompletionOverridesAndReopeningRestoresIt() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)
    let completion = application.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.completion.")
    ).firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Completed"].exists)
    recordScreenshot(application, name: "Saved List with contextual completion and details")

    createList("Wishlist", application: application)
    addItem(application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    viewGlobalItem(application)
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(true))
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertFalse(completion.isEnabled)
    XCTAssertTrue(completion.label.contains("Completed globally"))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Saved List with globally completed Item")

    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertFalse(completion.isEnabled)
    XCTAssertTrue(completion.label.contains("Completed globally"))
    assertProgress(1, application: application)
    recordScreenshot(application, name: "Global completion overrides both saved List appearances")

    viewGlobalItem(application)
    activateGlobalCompletion(globalCompletion)
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    XCTAssertTrue(completion.isEnabled)
    assertProgress(0, application: application)
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertTrue(completion.isEnabled)
    assertProgress(1, application: application)

    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    assertProgress(1, application: application)
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
    openList("Wishlist", application: application)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    assertProgress(0, application: application)
  }

  func testListSelectionShowsContextualDetailsAndExplicitGlobalItemNavigation() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application)
    createList("Tokyo Food", application: application)
    addItem(application)

    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10),
      application.debugDescription)
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.staticTexts["Local: Todo"].exists)
    XCTAssertFalse(application.staticTexts["Prototype identity inspection"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Saved List appearance details")

    application.plannerElement("saved.appearance.actions").activateForPlannerJourney()
    application.plannerElement("View Item").activateForPlannerJourney()
    let globalCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(globalCompletion.waitForExistence(timeout: 10))
    XCTAssertEqual(globalCompletion.plannerBooleanState, false)
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    XCTAssertFalse(application.staticTexts["In Tokyo Food"].exists)

    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Tokyo Food", application: application)
    application.savedPlannerItemRows("Nezu Museum").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Tokyo Food"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
  }

  private func moveDestination(_ title: String, application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.membership.destination.")
    ).matching(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
  }

  private func chooseSort(
    _ title: String, menu: XCUIElement, application: XCUIApplication
  ) {
    var control = menu
    #if os(macOS)
      if !control.exists || !control.isHittable {
        let overflow = application.windows.firstMatch.popUpButtons["more toolbar items"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        overflow.activateForPlannerJourney()
        control =
          overflow.menuItems.matching(
            NSPredicate(format: "title MATCHES %@", "^Sort:.*")
          ).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 5))
      }
    #endif
    control.activateForPlannerJourney()
    let option = application.plannerElement(title)
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.activateForPlannerJourney()
    #if os(macOS)
      application.typeKey(.escape, modifierFlags: [])
      application.typeKey(.escape, modifierFlags: [])
    #endif
  }

  private func waitForRenderedPreviewImage(_ card: XCUIElement, application: XCUIApplication) {
    let rendered = NSPredicate { _, _ in
      application.hasPaintedPlannerPreview(card)
    }
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: rendered, object: card)], timeout: 20),
      .completed, "The detailed color fixture must be painted inside the native link card.")
  }

  private func openItemEditor(_ application: XCUIApplication) {
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.item.edit.title"].waitForExistence(timeout: 5))
  }

  private func addBookmark(
    _ originalURL: String, label: String, existingURLIdentifiers: [String] = [],
    application: XCUIApplication, accessibilityIdentifierPrefix: String = "saved.item.edit.link"
  ) -> String {
    let add = application.plannerElement("\(accessibilityIdentifierPrefix).add")
    revealEditorElement(add, application: application)
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    add.activateForPlannerJourney()
    let newURL = application.textFields.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND NOT (identifier IN %@)",
        "\(accessibilityIdentifierPrefix).url.", existingURLIdentifiers)
    ).firstMatch
    revealEditorElement(newURL, application: application)
    XCTAssertTrue(newURL.waitForExistence(timeout: 5))
    newURL.activateForPlannerJourney()
    newURL.typeText(originalURL)
    let labelField = application.textFields[
      newURL.identifier.replacingOccurrences(
        of: "\(accessibilityIdentifierPrefix).url.",
        with: "\(accessibilityIdentifierPrefix).label.")]
    revealEditorElement(labelField, application: application)
    labelField.activateForPlannerJourney()
    labelField.typeText(label)
    return newURL.identifier
  }

  private func revealEditorElement(_ element: XCUIElement, application: XCUIApplication) {
    if element.isHittable { return }
    for _ in 0..<3 {
      #if os(macOS)
        scrollItemDetail(application)
      #else
        application.swipeUp()
      #endif
      if element.isHittable { return }
    }
    XCTAssertTrue(element.waitForPlannerHittability())
  }

  private func savedBookmarkRows(_ application: XCUIApplication) -> XCUIElementQuery {
    application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
  }

  private func revealSavedBookmark(_ label: String, application: XCUIApplication) -> XCUIElement {
    let bookmark = savedBookmarkRows(application).matching(
      NSPredicate(format: "label == %@", label)
    ).firstMatch
    for _ in 0..<6 {
      if bookmark.exists && bookmark.isHittable { return bookmark }
      #if os(iOS)
        let window = application.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: .init(dx: 0.96, dy: 0.74))
        let end = window.coordinate(withNormalizedOffset: .init(dx: 0.96, dy: 0.50))
        start.press(forDuration: 0.01, thenDragTo: end)
      #else
        scrollItemDetail(application)
      #endif
    }
    XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
    return bookmark
  }

  #if os(macOS)
    private func scrollItemDetail(_ application: XCUIApplication) {
      let scrollViews = application.windows.firstMatch.scrollViews
      guard scrollViews.count > 0 else {
        XCTFail("The Item detail scroll view is unavailable")
        return
      }
      scrollViews.element(boundBy: scrollViews.count - 1).scroll(byDeltaX: 0, deltaY: -400)
    }
  #endif

  private func removeBookmark(_ identity: String, application: XCUIApplication) {
    let actions = application.plannerElement("saved.item.edit.link.actions.\(identity)")
    revealEditorElement(actions, application: application)
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
    application.plannerElement("Remove Link").activateForPlannerJourney()
  }

  private func openListContextMenu(_ list: XCUIElement) {
    XCTAssertTrue(list.waitForPlannerHittability())
    #if os(macOS)
      list.rightClick()
    #else
      list.press(forDuration: 1)
    #endif
  }

  private func chooseFilter(
    _ title: String, menu: XCUIElement, application: XCUIApplication
  ) {
    if title == "All completion states" || title == "All archive states" {
      application.chooseSavedPlannerStateFilter(title, control: menu)
      return
    }
    menu.activateForPlannerJourney()
    let option = application.plannerElement(title)
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    XCTAssertTrue(option.waitForPlannerHittability())
    option.activateForPlannerJourney()
  }

  private func assertSortChoice(_ choice: String, menu: XCUIElement) {
    let selected = NSPredicate(format: "label == %@", "Sort: \(choice)")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: selected, object: menu)], timeout: 5), .completed
    )
  }

  private func assertItemOrder(_ titles: [String], application: XCUIApplication) {
    for (firstTitle, secondTitle) in zip(titles, titles.dropFirst()) {
      let first = application.savedPlannerItemRows(firstTitle).firstMatch
      let second = application.savedPlannerItemRows(secondTitle).firstMatch
      let ordered = NSPredicate { _, _ in
        first.exists && second.exists && first.frame.midY < second.frame.midY
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: ordered, object: application)], timeout: 10),
        .completed, "Expected \(firstTitle) before \(secondTitle)")
    }
  }

  func testNewItemFromListCancelsWithoutChangesAndSavesRichContentInItsOriginalList() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createList("Origin", application: application)
    openNewItemInList(application)
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertEqual(application.sheets.count, 0)
    title.activateForPlannerJourney()
    title.typeText("Discarded draft")
    closeNewItemEditor(application)
    application.windows.firstMatch.buttons["Discard"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(title.waitForNonExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    openCatalogSection("Items", application: application)
    XCTAssertEqual(application.savedPlannerItemRows("Discarded draft").count, 0)
    openSection("Lists", application: application)
    let origin = application.savedPlannerListRow("Origin")
    revealSidebarIfNeeded(application, element: origin)
    origin.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    openNewItemInList(application)
    for (identifier, text) in [
      ("saved.item.title", "Garden visit"),
      ("saved.item.subtitle", "Bring the sketchbook"),
      ("saved.item.notes", "Meet at the south entrance"),
      ("saved.item.location.name", "Hama-rikyu Gardens"),
      ("saved.item.location.address", "1-1 Hamarikyuteien, Chuo City, Tokyo"),
    ] {
      let field = application.textFields[identifier]
      revealEditorElement(field, application: application)
      field.activateForPlannerJourney()
      field.typeText(text)
    }
    let firstBookmark = addBookmark(
      "https://example.com/gardens", label: "Tickets", application: application,
      accessibilityIdentifierPrefix: "saved.item.link")
    _ = addBookmark(
      "https://example.com/gardens", label: "Garden guide",
      existingURLIdentifiers: [firstBookmark], application: application,
      accessibilityIdentifierPrefix: "saved.item.link")
    recordScreenshot(application, name: "Rich New Item draft in the List detail column")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    #if os(iOS)
      if application.windows.firstMatch.frame.width < 600 {
        XCTAssertTrue(
          application.staticTexts["Meet at the south entrance"].waitForExistence(timeout: 10))
        application.navigationBars.buttons["BackButton"].firstMatch.activateForPlannerJourney()
      }
    #endif
    let appearance = application.savedPlannerItemRows("Garden visit").firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    let completion = application.plannerElement(
      appearanceIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    appearance.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the south entrance"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Bring the sketchbook"].exists)
    let savedLinks = savedBookmarkRows(application)
    let tickets = revealSavedBookmark("Tickets", application: application)
    XCTAssertTrue(tickets.waitForPlannerValue("https://example.com/gardens"))
    let guide = revealSavedBookmark("Garden guide", application: application)
    XCTAssertTrue(guide.waitForPlannerValue("https://example.com/gardens"))
    let savedLinkIdentifiers = savedLinks.allElementsBoundByIndex.map(\.identifier)
    XCTAssertEqual(Set(savedLinkIdentifiers).count, 2)
    recordScreenshot(application, name: "Created rich Item keeps its Origin List appearance")
    createList("Other", application: application)
    XCTAssertEqual(application.savedPlannerItemRows("Garden visit").count, 0)
    openCatalogSection("Items", application: application)
    let source = application.savedPlannerItemRows("Garden visit")
    XCTAssertEqual(source.count, 1)
    let sourceIdentifier = source.firstMatch.identifier
    source.firstMatch.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the south entrance"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openList("Origin", itemTitle: "Garden visit", application: application)
    XCTAssertEqual(appearance.identifier, appearanceIdentifier)
    XCTAssertTrue(completion.waitForPlannerValue("To do"))
    appearance.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Bring the sketchbook"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Meet at the south entrance"].exists)
    _ = revealSavedBookmark("Tickets", application: application)
    _ = revealSavedBookmark("Garden guide", application: application)
    XCTAssertEqual(
      savedBookmarkRows(application).allElementsBoundByIndex.map(\.identifier),
      savedLinkIdentifiers)
    openCatalogSection("Items", application: application)
    XCTAssertEqual(source.count, 1)
    XCTAssertEqual(source.firstMatch.identifier, sourceIdentifier)
    source.firstMatch.activateForPlannerJourney()
    openItemEditor(application)
    let address = application.textFields["saved.item.edit.location.address"]
    revealEditorElement(address, application: application)
    XCTAssertEqual(address.value as? String, "1-1 Hamarikyuteien, Chuo City, Tokyo")
    XCTAssertEqual(
      application.textFields["saved.item.edit.location.name"].value as? String,
      "Hama-rikyu Gardens")
  }

  func testNewItemNavigationRequiresExplicitChoiceAndKeepsInvalidDraftsOpen() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createList("Origin", application: application)
    openNewItemInList(application)
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    closeNewItemEditor(application)
    XCTAssertTrue(title.waitForNonExistence(timeout: 5))
    XCTAssertFalse(application.buttons["Keep Editing"].exists)
    openNewItemInList(application)
    title.activateForPlannerJourney()
    title.typeText("Preserved draft")
    attemptDraftNavigation(application)
    let dialog = application.windows.firstMatch.sheets.firstMatch
    XCTAssertTrue(dialog.waitForExistence(timeout: 5))
    for choice in ["Save", "Discard", "Keep Editing"] {
      XCTAssertTrue(dialog.buttons[choice].exists)
    }
    #if os(macOS)
      XCTAssertEqual(dialog.buttons.count, 3)
    #endif
    recordScreenshot(application, name: "Draft navigation choices after guarded Back")
    let hierarchy = XCTAttachment(string: application.windows.firstMatch.debugDescription)
    hierarchy.name = "Draft navigation own-window hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    chooseDraftNavigationAction("Keep Editing", application: application)
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertEqual(title.value as? String, "Preserved draft")
    replaceText(title, with: "", application: application)
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep this note while fixing the title")
    attemptDraftNavigation(application)
    chooseDraftNavigationAction("Save", application: application)
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.staticTexts["An Item title must contain text."].waitForExistence(timeout: 5))
    application.windows.firstMatch.buttons["OK"].firstMatch.activateForPlannerJourney()
    XCTAssertEqual(notes.value as? String, "Keep this note while fixing the title")
    title.activateForPlannerJourney()
    title.typeText("Saved while leaving")
    attemptDraftNavigation(application)
    chooseDraftNavigationAction("Save", application: application)
    XCTAssertTrue(title.waitForNonExistence(timeout: 10))
    openCatalogSection("Items", application: application)
    let source = application.savedPlannerItemRows("Saved while leaving")
    XCTAssertTrue(source.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(source.count, 1)
    let sourceIdentifier = source.firstMatch.identifier
    XCTAssertTrue(sourceIdentifier.hasPrefix("saved.item."))
    recordScreenshot(application, name: "Explicit navigation Save creates the Item before leaving")
    openList("Origin", itemTitle: "Saved while leaving", application: application)
    let appearance = application.savedPlannerItemRows("Saved while leaving").firstMatch
    XCTAssertNotEqual(appearance.identifier, sourceIdentifier)
  }

  private func attemptDraftNavigation(_ application: XCUIApplication) {
    #if os(iOS)
      if application.windows.firstMatch.frame.width < 600 {
        application.navigationBars["New Item"].buttons.matching(
          NSPredicate(
            format: "identifier == %@ OR identifier == %@", "BackButton", "saved.item.back")
        ).firstMatch.activateForPlannerJourney()
      } else {
        application.buttons.matching(identifier: "square.stack").allElementsBoundByIndex
          .first(where: \.isHittable)?.activateForPlannerJourney()
      }
    #else
      openSection("Items", application: application)
    #endif
  }

  private func chooseDraftNavigationAction(_ title: String, application: XCUIApplication) {
    let action = application.windows.firstMatch.sheets.buttons[title].firstMatch
    XCTAssertTrue(action.waitForExistence(timeout: 5))
    XCTAssertTrue(action.isEnabled)
    action.activateForPlannerJourney()
  }

  private func closeNewItemEditor(_ application: XCUIApplication) {
    let control = application.windows.firstMatch.buttons.matching(
      NSPredicate(
        format: "identifier == %@ OR identifier == %@", "saved.item.cancel", "saved.item.back")
    ).firstMatch
    XCTAssertTrue(control.waitForExistence(timeout: 5))
    control.activateForPlannerJourney()
  }

  func testDeletingSelectedItemChoosesTheFirstVisibleSurvivorInTheCurrentSort() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    for (title, notes) in [
      ("Zzz archived", "Only archived details"), ("Bravo", "Only Bravo details"),
      ("Zulu", "Only Zulu details"), ("Delta", "Only Delta details"),
    ] {
      createItem(application, title: title, notes: notes)
    }
    openCatalogSection("Items", application: application)
    application.savedPlannerItemRows("Zzz archived").firstMatch.activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Archive Item").activateForPlannerJourney()
    openCatalogSection("Items", application: application)
    chooseSort(
      "Descending", menu: application.plannerElement("saved.items.sort"), application: application)
    XCTAssertFalse(application.savedPlannerItemRows("Zzz archived").firstMatch.exists)
    let removed = application.savedPlannerItemRows("Delta").firstMatch
    let surviving = application.savedPlannerItemRows("Zulu").firstMatch
    let survivingIdentifier = surviving.identifier
    removed.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Only Delta details"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    application.plannerElement("saved.item.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Only Delta details"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    application.plannerElement("saved.item.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.item.delete.confirm").waitForNonExistence(timeout: 10))
    #if os(iOS)
      if application.windows.firstMatch.frame.width < 600 {
        XCTAssertTrue(surviving.waitForExistence(timeout: 10))
        XCTAssertFalse(application.staticTexts["Only Zulu details"].exists)
        XCTAssertFalse(application.plannerElement("saved.item.completion").exists)
      } else {
        XCTAssertTrue(application.staticTexts["Only Zulu details"].waitForExistence(timeout: 10))
      }
    #else
      XCTAssertTrue(application.staticTexts["Only Zulu details"].waitForExistence(timeout: 10))
    #endif
    recordScreenshot(
      application, name: "Confirmed Item deletion selects the first visible survivor")
    openCatalogSection("Items", application: application)
    XCTAssertFalse(removed.exists)
    XCTAssertEqual(surviving.identifier, survivingIdentifier)
    XCTAssertTrue(application.savedPlannerItemRows("Bravo").firstMatch.exists)
  }

  func testDeletingSelectedListChoosesTheFirstVisibleListAndItsFirstItemOnRegularLayouts() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    createItem(application, title: "Willow", notes: "Willow stays unselected")
    createItem(application, title: "Birch", notes: "The first sorted Item keeps its context")
    createList("Alpha", application: application)
    createList("Zulu", application: application)
    addItem(application, title: "Willow")
    addItem(application, title: "Birch")
    chooseSort(
      "Title", menu: application.plannerElement("saved.list.sort"), application: application)
    for title in ["Extra", "Middle"] { createList(title, application: application) }
    openCatalogSection("Lists", application: application)
    chooseSort(
      "Descending", menu: application.plannerElement("saved.lists.sort"), application: application)
    application.savedPlannerListRow("Middle").activateForPlannerJourney()
    #if os(macOS)
      XCTAssertEqual(application.windows.firstMatch.title, "Middle")
      deleteSourceInAnotherWindow("Extra", application: application)
      XCTAssertEqual(application.windows.firstMatch.title, "Middle")
      XCTAssertTrue(application.staticTexts["No items"].exists)
    #endif
    application.openSavedPlannerListActionsMenu()
    application.plannerElement("saved.list.delete").activateForPlannerJourney()
    application.plannerElement("saved.list.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    #if os(macOS)
      let originalWindowIdentifier = application.windows.firstMatch.identifier
      let originalWindow = application.windows.matching(
        NSPredicate(format: "identifier == %@", originalWindowIdentifier)
      ).firstMatch
      let deletingWindow = deleteSourceInAnotherWindow(
        "Middle", application: application, closeAfterDeleting: false)
      let hierarchy = XCTAttachment(string: originalWindow.debugDescription)
      hierarchy.name = "Original Planner window after another window deletes its selection"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      XCTAssertTrue(originalWindow.staticTexts["In Zulu"].waitForExistence(timeout: 10))
      XCTAssertTrue(originalWindow.staticTexts["The first sorted Item keeps its context"].exists)
      XCTAssertFalse(originalWindow.staticTexts["Willow stays unselected"].exists)
      deletingWindow.buttons["_XCUI:CloseWindow"].click()
      XCTAssertTrue(deletingWindow.waitForNonExistence(timeout: 10))
    #else
      application.openSavedPlannerListActionsMenu()
      application.plannerElement("saved.list.delete").activateForPlannerJourney()
      application.plannerElement("saved.list.delete.confirm").activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.list.delete.confirm").waitForNonExistence(timeout: 10))
    #endif
    #if os(iOS)
      if application.windows.firstMatch.frame.width < 600 {
        XCTAssertTrue(application.savedPlannerListRow("Alpha").waitForExistence(timeout: 10))
        XCTAssertTrue(application.savedPlannerListRow("Zulu").exists)
        XCTAssertFalse(application.staticTexts["The first sorted Item keeps its context"].exists)
      } else {
        XCTAssertTrue(application.staticTexts["In Zulu"].waitForExistence(timeout: 10))
        XCTAssertTrue(application.staticTexts["The first sorted Item keeps its context"].exists)
        XCTAssertFalse(application.staticTexts["Willow stays unselected"].exists)
      }
    #else
      XCTAssertTrue(application.staticTexts["In Zulu"].waitForExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["The first sorted Item keeps its context"].exists)
      XCTAssertFalse(application.staticTexts["Willow stays unselected"].exists)
    #endif
    recordScreenshot(
      application, name: "Confirmed List deletion selects the first surviving context")
  }

  #if os(macOS)
    func testRenamingTheOriginatingListRequiresReviewBeforeSavingTheRetainedItemDraft() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      createList("Origin", application: application)
      let listIdentifier = application.savedPlannerListRow("Origin").identifier
      openNewItemInList(application)
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Retained visit")
      let notes = application.textFields["saved.item.notes"]
      notes.activateForPlannerJourney()
      notes.typeText("Keep these notes through destination review")
      let existingWindowIdentifiers = Set(
        application.windows.allElementsBoundByIndex.map(\.identifier))
      application.menuBars.menuBarItems["File"].click()
      application.menuItems["New Window"].click()
      guard
        let newWindow = application.windows.allElementsBoundByIndex.first(where: {
          !existingWindowIdentifiers.contains($0.identifier)
        })
      else {
        XCTFail("New Window did not create another Planner window")
        return
      }
      let editingWindow = application.windows.matching(
        NSPredicate(format: "identifier == %@", newWindow.identifier)
      ).firstMatch
      let origin = editingWindow.buttons.matching(identifier: listIdentifier).firstMatch
      XCTAssertTrue(origin.waitForExistence(timeout: 10))
      origin.click()
      XCTAssertTrue(editingWindow.staticTexts["No items"].waitForExistence(timeout: 10))
      let actions = editingWindow.descendants(matching: .any)
        .matching(identifier: "saved.list.actions").firstMatch
      XCTAssertTrue(actions.waitForExistence(timeout: 5))
      actions.click()
      application.menuItems["saved.list.estimate.edit"].click()
      let name = editingWindow.sheets.textFields["saved.list.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      replaceText(name, with: "Renamed origin", application: application)
      editingWindow.sheets.buttons["saved.list.save"].click()
      XCTAssertTrue(name.waitForNonExistence(timeout: 10))
      XCTAssertEqual(application.savedPlannerListRow("Renamed origin").identifier, listIdentifier)
      editingWindow.buttons["_XCUI:CloseWindow"].click()
      XCTAssertTrue(editingWindow.waitForNonExistence(timeout: 10))
      XCTAssertEqual(title.value as? String, "Retained visit")
      XCTAssertEqual(notes.value as? String, "Keep these notes through destination review")
      application.plannerElement("saved.item.save").click()
      let review = application.windows.firstMatch.sheets.firstMatch
      XCTAssertTrue(review.buttons["Use This List"].waitForExistence(timeout: 10))
      XCTAssertTrue(
        review.staticTexts[
          "The original List changed. Save to Renamed origin instead? Your draft is preserved."
        ].exists)
      recordScreenshot(application, name: "Renamed List requires explicit Item destination review")
      review.buttons["Keep Editing"].click()
      XCTAssertEqual(title.value as? String, "Retained visit")
      XCTAssertEqual(notes.value as? String, "Keep these notes through destination review")
      XCTAssertTrue(application.staticTexts["No items"].exists)
      application.plannerElement("saved.item.save").click()
      XCTAssertTrue(review.buttons["Use This List"].waitForExistence(timeout: 10))
      review.buttons["Use This List"].click()
      XCTAssertTrue(review.waitForNonExistence(timeout: 5))
      XCTAssertTrue(title.exists)
      XCTAssertTrue(application.staticTexts["No items"].exists)
      application.plannerElement("saved.item.save").click()
      XCTAssertTrue(title.waitForNonExistence(timeout: 10))
      let appearance = application.savedPlannerItemRows("Retained visit").firstMatch
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      let appearanceIdentifier = appearance.identifier
      XCTAssertTrue(appearanceIdentifier.hasPrefix("saved.appearance."))
      let completion = application.plannerElement(
        appearanceIdentifier.replacingOccurrences(
          of: "saved.appearance.", with: "saved.appearance.completion."))
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      appearance.click()
      XCTAssertTrue(application.staticTexts["In Renamed origin"].waitForExistence(timeout: 10))
      XCTAssertTrue(
        application.staticTexts["Keep these notes through destination review"].exists)
      recordScreenshot(
        application, name: "Reviewed destination creates one retained List appearance")
      application.terminate()
      application.launchSavedPlannerJourney()
      openList("Renamed origin", itemTitle: "Retained visit", application: application)
      XCTAssertEqual(application.savedPlannerListRow("Renamed origin").identifier, listIdentifier)
      XCTAssertEqual(appearance.identifier, appearanceIdentifier)
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      openCatalogSection("Items", application: application)
      XCTAssertEqual(application.savedPlannerItemRows("Retained visit").count, 1)
    }

    func testDeletingASelectedAppearanceInAnotherWindowSelectsItsFirstVisibleSibling() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      createItem(application, title: "Alpha outside", notes: "The global catalog stays separate")
      createItem(application, title: "Deleted", notes: "Remove this source")
      createItem(application, title: "Birch", notes: "The surviving contextual Item")
      createList("Context", application: application)
      addItem(application, title: "Deleted")
      addItem(application, title: "Birch")
      let surviving = application.savedPlannerItemRows("Birch").firstMatch
      let survivingIdentifier = surviving.identifier
      application.savedPlannerItemRows("Deleted").firstMatch.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["In Context"].waitForExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["Remove this source"].exists)
      let originalWindowIdentifier = application.windows.firstMatch.identifier
      let originalWindow = application.windows.matching(
        NSPredicate(format: "identifier == %@", originalWindowIdentifier)
      ).firstMatch
      let deletingWindow = deleteSourceInAnotherWindow(
        "Deleted", application: application, sourceKind: "item", closeAfterDeleting: false)
      XCTAssertTrue(originalWindow.staticTexts["In Context"].waitForExistence(timeout: 10))
      XCTAssertTrue(originalWindow.staticTexts["The surviving contextual Item"].exists)
      XCTAssertFalse(originalWindow.staticTexts["The global catalog stays separate"].exists)
      XCTAssertEqual(surviving.identifier, survivingIdentifier)
      deletingWindow.buttons["_XCUI:CloseWindow"].click()
      XCTAssertTrue(deletingWindow.waitForNonExistence(timeout: 10))
      recordScreenshot(
        application, name: "Item deletion selects the surviving List appearance in its own context")
    }
  #endif

  #if os(macOS)
    @discardableResult
    private func deleteSourceInAnotherWindow(
      _ title: String, application: XCUIApplication, sourceKind: String = "list",
      closeAfterDeleting: Bool = true
    ) -> XCUIElement {
      let existingWindowIdentifiers = Set(
        application.windows.allElementsBoundByIndex.map(\.identifier))
      application.menuBars.menuBarItems["File"].click()
      application.menuItems["New Window"].click()
      guard
        let newWindow = application.windows.allElementsBoundByIndex.first(where: {
          !existingWindowIdentifiers.contains($0.identifier)
        })
      else {
        XCTFail("New Window did not create another Planner window")
        return application.windows.firstMatch
      }
      let window = application.windows.matching(
        NSPredicate(format: "identifier == %@", newWindow.identifier)
      ).firstMatch
      if sourceKind == "item" {
        window.descendants(matching: .any)["saved.section.items"].click()
      }
      let row = window.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.\(sourceKind).", title)
      ).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      row.click()
      let actions = window.descendants(matching: .any)["saved.\(sourceKind).actions"]
      XCTAssertTrue(actions.waitForExistence(timeout: 10))
      actions.click()
      application.menuItems["Delete \(sourceKind.capitalized)"].click()
      let confirm = window.sheets.descendants(matching: .any)["saved.\(sourceKind).delete.confirm"]
      XCTAssertTrue(confirm.waitForExistence(timeout: 5))
      confirm.click()
      XCTAssertTrue(confirm.waitForNonExistence(timeout: 10))
      if closeAfterDeleting {
        window.buttons["_XCUI:CloseWindow"].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 10))
      }
      return window
    }
  #endif

  private func openNewItemInList(_ application: XCUIApplication) {
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.createItem").activateForPlannerJourney()
  }

  private func createItem(
    _ application: XCUIApplication, title: String = "Nezu Museum",
    notes: String = "Meet at the garden entrance"
  ) {
    openSection("Items", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let titleField = application.textFields["saved.item.title"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    titleField.activateForPlannerJourney()
    titleField.typeText(title)
    let notesField = application.textFields["saved.item.notes"]
    notesField.activateForPlannerJourney()
    notesField.typeText(notes)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts[notes].waitForExistence(timeout: 10))
  }

  private func createList(_ title: String, application: XCUIApplication) {
    openSection("Lists", application: application)
    let create = application.plannerElement("saved.list.new")
    #if os(macOS)
      if create.exists && create.isHittable {
        create.activateForPlannerJourney()
      } else {
        let overflow = application.windows.firstMatch.popUpButtons["more toolbar items"]
        XCTAssertTrue(
          overflow.waitForExistence(timeout: 5), application.windows.firstMatch.debugDescription)
        overflow.activateForPlannerJourney()
        let nativeCreate = overflow.menuItems["New List"]
        XCTAssertTrue(
          nativeCreate.waitForExistence(timeout: 5),
          application.windows.firstMatch.debugDescription)
        nativeCreate.activateForPlannerJourney()
      }
    #else
      if application.windows.firstMatch.frame.width > 600, !create.exists,
        let overflow = application.navigationBars["Planner"].buttons.matching(
          identifier: "OverflowBarButtonItem"
        ).allElementsBoundByIndex.first(where: \.isHittable)
      {
        overflow.activateForPlannerJourney()
        let nativeCreate = application.plannerElement("New List")
        XCTAssertTrue(
          nativeCreate.waitForExistence(timeout: 5),
          application.windows.firstMatch.debugDescription)
        nativeCreate.activateForPlannerJourney()
      } else {
        revealSidebarIfNeeded(application, element: create)
        create.activateForPlannerJourney()
      }
    #endif
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText(title)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
  }

  private func addItem(_ application: XCUIApplication, title: String = "Nezu Museum") {
    application.openSavedPlannerListAddMenu()
    let add = application.plannerElement("saved.list.add")
    if add.exists {
      add.activateForPlannerJourney()
    } else {
      let overflow = application.buttons["OverflowBarButtonItem"].firstMatch
      XCTAssertTrue(overflow.waitForExistence(timeout: 5), application.debugDescription)
      overflow.activateForPlannerJourney()
      let overflowAdd = application.plannerElement("Add existing Item")
      XCTAssertTrue(overflowAdd.waitForExistence(timeout: 5), application.debugDescription)
      overflowAdd.activateForPlannerJourney()
    }
    let candidate = application.staticTexts[title].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 5))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("saved.membership.add").waitForExistence(timeout: 2))
    XCTAssertTrue(
      application.savedPlannerItemRows(title).firstMatch.waitForExistence(timeout: 10))
  }

  private func openList(
    _ title: String, itemTitle: String = "Nezu Museum", application: XCUIApplication
  ) {
    openSection("Lists", application: application)
    let list = application.savedPlannerListRow(title)
    revealSidebarIfNeeded(application, element: list)
    XCTAssertTrue(list.waitForExistence(timeout: 10))
    list.activateForPlannerJourney()
    let item = application.savedPlannerItemRows(itemTitle).firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertTrue(item.waitForPlannerHittability())
  }

  private func openSection(_ title: String, application: XCUIApplication) {
    #if os(macOS)
      application.activate()
      XCTAssertTrue(application.wait(for: .runningForeground, timeout: 10))
      let section = application.plannerElement("saved.section.\(title.lowercased())")
      XCTAssertTrue(section.waitForExistence(timeout: 10))
      section.activateForPlannerJourney()
    #else
      application.openPlannerSection(title)
    #endif
  }

  private func openCatalogSection(_ title: String, application: XCUIApplication) {
    openSection(title, application: application)
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
  }

  private func revealSidebarIfNeeded(_ application: XCUIApplication, element: XCUIElement) {
    if element.waitForExistence(timeout: 3) { return }
    for _ in 0..<2 {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists {
        sidebar.activateForPlannerJourney()
      } else {
        let back = application.plannerElement("BackButton")
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.activateForPlannerJourney()
      }
      if element.waitForExistence(timeout: 3) { return }
    }
    XCTFail("Planner's native List navigation did not become available.")
  }

  private func viewGlobalItem(
    _ application: XCUIApplication, itemTitle: String = "Nezu Museum"
  ) {
    let item = application.savedPlannerItemRows(itemTitle).firstMatch
    XCTAssertTrue(item.waitForPlannerHittability())
    item.activateForPlannerJourney()
    let actions = application.plannerElement("saved.appearance.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    actions.activateForPlannerJourney()
    let viewItem = application.plannerElement("View Item")
    XCTAssertTrue(viewItem.waitForExistence(timeout: 5))
    viewItem.activateForPlannerJourney()
  }

  private func replaceText(
    _ field: XCUIElement, with value: String, application: XCUIApplication
  ) {
    field.activateForPlannerJourney()
    #if os(macOS)
      field.typeKey("a", modifierFlags: .command)
    #else
      let existingValue = field.value as? String ?? ""
      if !existingValue.isEmpty, existingValue != field.placeholderValue {
        field.press(forDuration: 1)
        let selectAll = application.descendants(matching: .any).matching(
          NSPredicate(format: "label == %@ OR identifier == %@", "Select All", "Select All")
        ).firstMatch
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
        selectAll.activateForPlannerJourney()
      }
    #endif
    if value.isEmpty {
      field.typeText(XCUIKeyboardKey.delete.rawValue)
    } else {
      field.typeText(value)
      XCTAssertTrue(field.waitForPlannerValue(value))
    }
  }

  private func activateGlobalCompletion(_ element: XCUIElement) {
    #if os(macOS)
      element.click()
    #else
      let visibleSwitch = element.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
  }

  private func assertProgress(_ expected: Double, application: XCUIApplication) {
    let progress = application.progressIndicators["saved.list.progress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    XCTAssertEqual(progress.plannerProgressFraction, expected)
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
