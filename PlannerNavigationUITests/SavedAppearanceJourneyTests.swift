import CoreGraphics
import ImageIO
import XCTest

@MainActor
final class SavedAppearanceJourneyTests: XCTestCase {
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
    XCTAssertTrue(guideActions.waitForExistence(timeout: 5))
    revealEditorElement(guideActions, application: application)
    guideActions.activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("Move Up").isEnabled)
    application.plannerElement("Move Down").activateForPlannerJourney()
    revealEditorElement(guideActions, application: application)
    guideActions.activateForPlannerJourney()
    XCTAssertFalse(application.plannerElement("Move Down").isEnabled)
    application.plannerElement("Move Up").activateForPlannerJourney()
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
    XCTAssertTrue(archivedTokyo.waitForPlannerValue("Archived"))
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
    filters.activateForPlannerJourney()
    application.plannerElement("Active").activateForPlannerJourney()
    XCTAssertTrue(museum.waitForNonExistence(timeout: 10))
    XCTAssertFalse(hotel.exists)
    XCTAssertTrue(application.staticTexts["Showing 0 of 2 items"].exists)
    assertProgress(0.5, application: application)
    if keepsSimultaneousDetail {
      XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
      XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    }
    recordScreenshot(application, name: "Active search hides the row and retains valid detail")
    filters.activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
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
    filters.activateForPlannerJourney()
    application.plannerElement("Archived").activateForPlannerJourney()
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

    filters.activateForPlannerJourney()
    application.plannerElement("Active").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    XCTAssertFalse(item.exists)
    XCTAssertTrue(application.staticTexts["1 of 1 item done"].exists)
    XCTAssertTrue(application.staticTexts["Showing 0 of 1 item"].exists)
    assertProgress(1, application: application)
    if keepsSimultaneousDetail {
      XCTAssertTrue(application.staticTexts["In Tokyo Food"].exists)
      XCTAssertTrue(application.staticTexts["Meet at the garden entrance"].exists)
    }
    filters.activateForPlannerJourney()
    application.plannerElement("Todo").activateForPlannerJourney()
    XCTAssertEqual(filters.plannerControlTitle, "Todo · Active")
    filters.activateForPlannerJourney()
    application.plannerElement("Archived").activateForPlannerJourney()
    XCTAssertEqual(filters.plannerControlTitle, "Todo · Archived")
    XCTAssertFalse(item.exists)
    assertProgress(1, application: application)
    recordScreenshot(
      application, name: "Saved cumulative filters with full progress and no matches")

    filters.activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    XCTAssertEqual(item.identifier, membershipIdentifier)
    XCTAssertEqual(filters.plannerControlTitle, "Archived")
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    filters.activateForPlannerJourney()
    application.plannerElement("Done").activateForPlannerJourney()
    XCTAssertEqual(filters.plannerControlTitle, "Done · Archived")
    completion.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
    assertProgress(0, application: application)
    XCTAssertTrue(application.staticTexts["0 of 1 item done"].exists)
    filters.activateForPlannerJourney()
    application.plannerElement("All completion states").activateForPlannerJourney()
    filters.activateForPlannerJourney()
    application.plannerElement("All archive states").activateForPlannerJourney()
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
    menu.activateForPlannerJourney()
    let option = application.plannerElement(title)
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.activateForPlannerJourney()
  }

  private func waitForRenderedPreviewImage(_ card: XCUIElement, application: XCUIApplication) {
    let rendered = NSPredicate { _, _ in
      guard card.exists else { return false }
      let cardFrame = card.frame
      let windowFrame = application.windows.firstMatch.frame
      guard !cardFrame.isEmpty, !windowFrame.isEmpty else { return false }
      let snapshot = application.screenshot().pngRepresentation
      guard let source = CGImageSourceCreateWithData(snapshot as CFData, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
      else { return false }
      let scale = CGFloat(image.width) / windowFrame.width
      let imageFrame = CGRect(
        x: cardFrame.minX * scale, y: cardFrame.minY * scale,
        width: cardFrame.width * scale, height: cardFrame.height * scale / 2)
      guard let top = image.cropping(to: imageFrame) else { return false }
      var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
      let drewImage = pixels.withUnsafeMutableBytes { buffer in
        guard
          let context = CGContext(
            data: buffer.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
            bytesPerRow: 32 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return false }
        context.draw(top, in: CGRect(x: 0, y: 0, width: 32, height: 32))
        return true
      }
      guard drewImage else { return false }
      let coloredPixels = stride(from: 0, to: pixels.count, by: 4).filter { offset in
        let channels = [Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2])]
        return (channels.max() ?? 0) - (channels.min() ?? 0) > 40
      }.count
      return coloredPixels > 256
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
    application: XCUIApplication
  ) -> String {
    let add = application.plannerElement("saved.item.edit.link.add")
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    revealEditorElement(add, application: application)
    add.activateForPlannerJourney()
    let newURL = application.textFields.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND NOT (identifier IN %@)",
        "saved.item.edit.link.url.", existingURLIdentifiers)
    ).firstMatch
    XCTAssertTrue(newURL.waitForExistence(timeout: 5))
    revealEditorElement(newURL, application: application)
    newURL.activateForPlannerJourney()
    newURL.typeText(originalURL)
    let labelField = application.textFields[
      newURL.identifier.replacingOccurrences(
        of: "saved.item.edit.link.url.", with: "saved.item.edit.link.label.")]
    revealEditorElement(labelField, application: application)
    labelField.activateForPlannerJourney()
    labelField.typeText(label)
    return newURL.identifier
  }

  private func revealEditorElement(_ element: XCUIElement, application: XCUIApplication) {
    if element.isHittable { return }
    for _ in 0..<3 {
      application.swipeUp()
      if element.isHittable { return }
    }
    XCTAssertTrue(element.waitForPlannerHittability())
  }

  private func savedBookmarkRows(_ application: XCUIApplication) -> XCUIElementQuery {
    application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
  }

  private func removeBookmark(_ identity: String, application: XCUIApplication) {
    let actions = application.plannerElement("saved.item.edit.link.actions.\(identity)")
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    revealEditorElement(actions, application: application)
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

  private func createItem(_ application: XCUIApplication, title: String = "Nezu Museum") {
    openSection("Items", application: application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let titleField = application.textFields["saved.item.title"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 5))
    titleField.activateForPlannerJourney()
    titleField.typeText(title)
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet at the garden entrance")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
  }

  private func createList(_ title: String, application: XCUIApplication) {
    openSection("Lists", application: application)
    let create = application.plannerElement("saved.list.new")
    revealSidebarIfNeeded(application, element: create)
    create.activateForPlannerJourney()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText(title)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
  }

  private func addItem(_ application: XCUIApplication, title: String = "Nezu Museum") {
    application.plannerElement("saved.list.add").activateForPlannerJourney()
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
      let section = application.plannerElement("saved.section.\(title.lowercased())")
    #else
      let section = application.buttons[title].firstMatch
    #endif
    XCTAssertTrue(section.waitForExistence(timeout: 10))
    section.activateForPlannerJourney()
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
