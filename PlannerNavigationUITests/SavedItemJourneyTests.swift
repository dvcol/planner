import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class SavedItemJourneyTests: XCTestCase {
  #if os(iOS)
    #if targetEnvironment(simulator)
      /// Runs normal application storage on a fresh simulator with no Apple Account.
      func testNormalFirstLaunchWithoutICloudKeepsLocalPlansAfterRelaunch() throws {
        continueAfterFailure = false
        let application = XCUIApplication()
        application.launchSavedPlannerJourney()
        XCTAssertTrue(
          application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 30))
        recordScreenshot(application, name: "Normal first launch reaches its ready empty catalog")
        application.openSavedPlannerSettings()
        let syncStatus = application.staticTexts.matching(identifier: "saved.settings.sync.status")
          .firstMatch
        XCTAssertTrue(syncStatus.waitForExistence(timeout: 10))
        XCTAssertEqual(syncStatus.label, "iCloud unavailable")
        XCTAssertTrue(
          application.staticTexts[
            "Your plans are saved on this device. When private iCloud is available, reopen Planner to review and copy them."
          ].exists)
        XCTAssertFalse(application.plannerElement("saved.settings.sync.copyLocal").exists)
        let retry = application.plannerElement("saved.settings.sync.retry")
        XCTAssertTrue(retry.isEnabled)
        retry.activateForPlannerJourney()
        let retryFinished = XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "enabled == true"), object: retry)
        XCTAssertEqual(XCTWaiter.wait(for: [retryFinished], timeout: 10), .completed)
        XCTAssertEqual(syncStatus.label, "iCloud unavailable")
        try application.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
        recordScreenshot(
          application, name: "Normal first launch explains unavailable private iCloud")
        application.plannerElement("saved.settings.done").activateForPlannerJourney()
        application.openPlannerSection("Items")
        XCTAssertFalse(application.savedPlannerItemRows("Offline museum").firstMatch.exists)
        application.openSavedPlannerNewItemEditor()
        let title = application.textFields["saved.item.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.activateForPlannerJourney()
        title.typeText("Offline museum")
        let notes = application.textFields["saved.item.notes"]
        notes.activateForPlannerJourney()
        notes.typeText("Check opening hours")
        application.plannerElement("saved.item.save").activateForPlannerJourney()
        XCTAssertTrue(application.staticTexts["Check opening hours"].waitForExistence(timeout: 10))
        let back = application.navigationBars.buttons["Items"].firstMatch
        if back.exists { back.activateForPlannerJourney() }
        let row = application.savedPlannerItemRows("Offline museum").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let sourceIdentity = row.identifier
        application.terminate()
        application.launchSavedPlannerJourney()
        XCTAssertTrue(
          application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 30))
        application.openPlannerSection("Items")
        let reopened = application.savedPlannerItemRows("Offline museum").firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        XCTAssertEqual(reopened.identifier, sourceIdentity)
        reopened.activateForPlannerJourney()
        XCTAssertTrue(application.staticTexts["Check opening hours"].waitForExistence(timeout: 10))
        recordScreenshot(
          application, name: "Device-only Item retains its identity and notes after relaunch")
      }

    #endif

    func testInboxSearchRetainsTheCompleteQueryAndRestoresTheSameItemWhenCleared() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Inbox")
      let usesSheet = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
      let search: XCUIElement
      if usesSheet {
        search =
          application.descendants(matching: .any)
          .matching(identifier: "saved.map.search.text").firstMatch
        XCTAssertFalse(application.searchFields.firstMatch.exists)
      } else {
        search = application.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
      }
      recordScreenshot(application, name: "Native Inbox search before editing")
      if usesSheet { try application.performAccessibilityAudit(for: .textClipped) }
      func setQuery(_ query: String) throws {
        if usesSheet { application.openSavedPlannerCollectionSearch() }
        if !search.exists { application.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let clear: XCUIElement
        if usesSheet {
          clear = application.buttons["saved.map.search.clear"]
        } else {
          clear = search.buttons["Clear text"]
        }
        if clear.exists { clear.activateForPlannerJourney() }
        if usesSheet { try application.performAccessibilityAudit(for: .textClipped) }
        if !query.isEmpty {
          search.activateForPlannerJourney()
          search.typeText(query)
          XCTAssertTrue(search.waitForPlannerValue(query))
        }
        recordScreenshot(application, name: "Native Inbox query: \(query)")
        if usesSheet {
          try application.performAccessibilityAudit(for: .textClipped)
          let done = application.buttons["saved.map.search.done"]
          done.activateForPlannerJourney()
          XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        }
      }
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Tokyo museum visit near the garden")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      let back = application.navigationBars.buttons["Inbox"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      let item = application.savedPlannerItemRows("Tokyo museum visit near the garden").firstMatch
      XCTAssertTrue(item.waitForExistence(timeout: 10))
      let sourceIdentifier = item.identifier
      try setQuery("Tokyo museum visit near the garden")
      XCTAssertTrue(item.waitForExistence(timeout: 10))
      recordScreenshot(application, name: "Native Inbox search retains the complete query")
      try setQuery("No such visit")
      XCTAssertTrue(item.waitForNonExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["No matching items"].waitForExistence(timeout: 10))
      try setQuery("")
      XCTAssertTrue(item.waitForExistence(timeout: 10))
      XCTAssertEqual(item.identifier, sourceIdentifier)
      recordScreenshot(application, name: "Clearing native Inbox search restores the same Item")
      // Text-size audits can replace the active search presentation.
      try application.performAccessibilityAudit(for: .textClipped)
      XCTAssertTrue(item.waitForExistence(timeout: 10))
      XCTAssertEqual(item.identifier, sourceIdentifier)
    }

    func testCompactListCatalogToolbarKeepsItsTitleAndActionsAvailable() throws {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      func revealCatalogSidebar() {
        let sidebar = application.buttons["Show Sidebar"].firstMatch
        if sidebar.exists && sidebar.isHittable { sidebar.activateForPlannerJourney() }
      }
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Lists")
      revealCatalogSidebar()
      XCTAssertTrue(
        application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 10))
      let toolbar = application.navigationBars["Planner"]
      let title = toolbar.staticTexts["Planner"]
      recordScreenshot(application, name: "Adaptive Lists catalog toolbar")
      XCTAssertTrue(toolbar.waitForExistence(timeout: 5))
      if UIDevice.current.userInterfaceIdiom == .phone {
        XCTAssertTrue(title.waitForExistence(timeout: 5))
      } else {
        XCTAssertTrue(application.plannerElement("saved.section.lists").waitForPlannerHittability())
        let referenceHeight = application.plannerElement("saved.section.lists").frame.height
        var measurements: [[String: Any]] = []
        var destinations: [(element: XCUIElement, name: String)] = []
        for (identifier, name) in [
          ("lists", "Lists"), ("items", "Items"), ("inbox", "Inbox"),
          ("itineraries", "Itineraries"), ("calendar", "Calendar"),
        ] {
          let destination = application.plannerElement("saved.section.\(identifier)")
          XCTAssertTrue(destination.waitForPlannerHittability(), name)
          destinations.append((destination, name))
          measurements.append([
            "name": name, "width": destination.frame.width,
            "height": destination.frame.height, "referenceHeight": referenceHeight,
          ])
        }
        let attachment = XCTAttachment(
          data: try JSONSerialization.data(withJSONObject: measurements, options: .sortedKeys),
          uniformTypeIdentifier: "public.json")
        attachment.name = "Sidebar destination text geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
        for destination in destinations {
          XCTAssertEqual(destination.element.label, destination.name)
          XCTAssertEqual(
            destination.element.frame.height, referenceHeight, accuracy: 1, destination.name)
        }
      }
      if title.exists { XCTAssertTrue(toolbar.frame.contains(title.frame)) }
      if UIDevice.current.userInterfaceIdiom == .phone {
        try application.performAccessibilityAudit(for: .textClipped)
      }
      let archive = application.plannerElement("saved.lists.archive")
      let create = application.plannerElement("saved.list.new")
      let overflow = toolbar.buttons["OverflowBarButtonItem"].firstMatch
      for control in [archive, create] {
        XCTAssertTrue(control.waitForPlannerHittability())
        XCTAssertTrue(toolbar.frame.contains(control.frame))
        if title.exists { XCTAssertFalse(title.frame.intersects(control.frame)) }
      }
      if UIDevice.current.userInterfaceIdiom == .phone || toolbar.frame.width < 440 {
        XCTAssertTrue(overflow.waitForPlannerHittability())
        if title.exists { XCTAssertFalse(title.frame.intersects(overflow.frame)) }
      }
      if overflow.exists { overflow.activateForPlannerJourney() }
      application.openSavedPlannerSettings()
      XCTAssertTrue(
        application.plannerElement("saved.settings.labels").waitForExistence(timeout: 10))
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
      if overflow.exists { overflow.activateForPlannerJourney() }
      application.openSavedPlannerLabels()
      let closeLabels = application.plannerElement("saved.categories.done")
      XCTAssertTrue(closeLabels.waitForExistence(timeout: 10))
      closeLabels.activateForPlannerJourney()
      if overflow.exists { overflow.activateForPlannerJourney() }
      var sort: XCUIElement {
        application.savedPlannerCatalogSortControl(identifierPrefix: "saved.lists")
      }
      XCTAssertTrue(sort.waitForPlannerHittability())
      sort.activateForPlannerJourney()
      let descending = application.buttons["Descending"].firstMatch
      let nativeMenu = application.collectionViews.containing(.button, identifier: "Title")
        .firstMatch
      recordScreenshot(application, name: "Native Lists sort menu at large text")
      for _ in 0..<8 where !descending.isHittable {
        guard nativeMenu.exists else {
          XCTFail("The native Sort menu is unavailable. \(application.debugDescription)")
          return
        }
        nativeMenu.swipeUp()
      }
      XCTAssertTrue(descending.waitForPlannerHittability())
      recordScreenshot(
        application, name: "Native Lists sort choices remain reachable at large text")
      descending.activateForPlannerJourney()
      application.windows.firstMatch.coordinate(
        withNormalizedOffset: CGVector(dx: 0.99, dy: 0.6)
      ).tap()
      revealCatalogSidebar()
      archive.activateForPlannerJourney()
      application.plannerElement("All Lists").activateForPlannerJourney()
      XCTAssertEqual(archive.label, "All Lists")
      create.activateForPlannerJourney()
      let name = application.textFields["saved.list.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      name.activateForPlannerJourney()
      name.typeText("Toolbar list")
      application.plannerElement("saved.list.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      application.openPlannerSection("Lists")
      revealCatalogSidebar()
      let back = application.navigationBars.buttons["BackButton"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      let row = application.savedPlannerListRow("Toolbar list")
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      let sourceIdentifier = row.identifier
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Lists")
      revealCatalogSidebar()
      if back.exists { back.activateForPlannerJourney() }
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, sourceIdentifier)
      XCTAssertEqual(archive.label, "Active Lists")
      if overflow.exists { overflow.activateForPlannerJourney() }
      XCTAssertTrue(sort.waitForPlannerHittability())
      XCTAssertTrue(sort.label.contains("Descending"))
      recordScreenshot(
        application, name: "Lists catalog retains its source and options after relaunch")
    }

    func testItemTitleRemainsReadableDuringCreationAndEditingAtAccessibilitySizes() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openItems(application)
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Tokyo museum morning")
      title.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
      XCTAssertTrue(title.waitForPlannerValue("Tokyo museum morning"))
      let notes = application.textFields["saved.item.notes"]
      notes.activateForPlannerJourney()
      notes.typeText("Keep this visit")
      XCTAssertTrue(title.waitForPlannerValue("Tokyo museum morning"))
      XCTAssertGreaterThan(
        title.frame.height, application.textFields["saved.item.subtitle"].frame.height)
      recordScreenshot(application, name: "Accessible Item title during creation")
      if UIDevice.current.userInterfaceIdiom == .phone {
        try application.performAccessibilityAudit(for: .textClipped)
      }
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Keep this visit"].waitForExistence(timeout: 10))
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      let row = application.savedPlannerItemRows("Tokyo museum morning").firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      let sourceIdentifier = row.identifier
      row.activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Edit item").activateForPlannerJourney()
      let editedTitle = application.textFields["saved.item.edit.title"]
      XCTAssertTrue(editedTitle.waitForExistence(timeout: 10))
      XCTAssertTrue(editedTitle.waitForPlannerValue("Tokyo museum morning"))
      editedTitle.activateForPlannerJourney()
      editedTitle.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
      XCTAssertTrue(editedTitle.waitForPlannerValue("Tokyo museum morning"))
      XCTAssertTrue(
        application.textFields["saved.item.edit.notes"].waitForPlannerValue("Keep this visit"))
      XCTAssertGreaterThan(
        editedTitle.frame.height, application.textFields["saved.item.edit.subtitle"].frame.height)
      recordScreenshot(application, name: "Accessible saved Item title during editing")
      if UIDevice.current.userInterfaceIdiom == .phone {
        try application.performAccessibilityAudit(for: .textClipped)
      }
      application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      openItems(application)
      let reopened = application.savedPlannerItemRows("Tokyo museum morning").firstMatch
      XCTAssertTrue(reopened.waitForExistence(timeout: 10))
      XCTAssertEqual(reopened.identifier, sourceIdentifier)
      reopened.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Keep this visit"].waitForExistence(timeout: 10))
      XCTAssertTrue(
        application.descendants(matching: .any).matching(identifier: "saved.item.completion")
          .firstMatch.waitForPlannerBooleanState(false))
    }

    func testCatalogSwipeArchiveAndUnarchivePreserveTheItemAndCompletionAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openDesignSection("Items", in: application)
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Swipe archive")
      let notes = application.textFields["saved.item.notes"]
      notes.activateForPlannerJourney()
      notes.typeText("Keep this note while archived")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep this note while archived"].waitForExistence(timeout: 10))
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      let row = application.savedPlannerItemRows("Swipe archive").firstMatch
      XCTAssertTrue(row.waitForPlannerHittability())
      let sourceIdentifier = row.identifier
      application.buttons["Mark Swipe archive done everywhere"].firstMatch
        .activateForPlannerJourney()
      let completion = application.buttons["Mark Swipe archive undone everywhere"].firstMatch
      XCTAssertTrue(completion.waitForExistence(timeout: 5))
      row.swipeLeft()
      let archive = application.buttons["Archive"].firstMatch
      XCTAssertTrue(archive.waitForExistence(timeout: 5))
      XCTAssertTrue(archive.isHittable)
      recordScreenshot(application, name: "Native Item row offers Archive after a swipe")
      archive.activateForPlannerJourney()
      XCTAssertTrue(row.waitForNonExistence(timeout: 10))
      let filters = application.plannerElement("saved.items.filters")
      application.chooseSavedPlannerStateFilter("Archived", control: filters)
      XCTAssertTrue(row.waitForPlannerHittability())
      XCTAssertEqual(row.identifier, sourceIdentifier)
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      row.swipeLeft()
      let unarchive = application.buttons["Unarchive"].firstMatch
      XCTAssertTrue(unarchive.waitForExistence(timeout: 5))
      XCTAssertTrue(unarchive.isHittable)
      recordScreenshot(application, name: "Native archived Item row offers Unarchive after a swipe")
      unarchive.activateForPlannerJourney()
      XCTAssertTrue(row.waitForNonExistence(timeout: 10))
      application.chooseSavedPlannerStateFilter("Active", control: filters)
      XCTAssertTrue(row.waitForPlannerHittability())
      XCTAssertEqual(row.identifier, sourceIdentifier)
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      application.terminate()
      application.launchSavedPlannerJourney()
      openDesignSection("Items", in: application)
      XCTAssertTrue(row.waitForPlannerHittability())
      XCTAssertEqual(row.identifier, sourceIdentifier)
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      row.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Keep this note while archived"].waitForExistence(timeout: 10))
      XCTAssertTrue(
        application.descendants(matching: .any).matching(identifier: "saved.item.completion")
          .firstMatch.waitForPlannerBooleanState(true))
      XCTAssertFalse(application.staticTexts["Archived"].exists)
      recordScreenshot(application, name: "Swipe archive keeps Item identity notes and completion")
    }
  #endif

  func testCatalogCompletionWorksWithoutOpeningDetailsAndSurvivesRelaunch() throws {
    continueAfterFailure = false
    let itemTitle = "Tokyo museum morning, lunch in the gardens and a visit to the bookshop"
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openDesignSection("Items", in: application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText(itemTitle)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.descendants(matching: .any).matching(identifier: "saved.item.completion")
        .firstMatch.waitForExistence(timeout: 10))
    #if os(iOS)
      let back = application.navigationBars.buttons["Items"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
    #endif
    let complete = application.buttons["Mark \(itemTitle) done everywhere"].firstMatch
    XCTAssertTrue(complete.waitForExistence(timeout: 10))
    let completionIdentifier = complete.identifier
    recordScreenshot(application, name: "Multiline Item row before completion")
    complete.activateForPlannerJourney()
    let reopen = application.buttons["Mark \(itemTitle) undone everywhere"].firstMatch
    XCTAssertTrue(reopen.waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Native row completion in the Item catalog")
    application.terminate()
    application.launchSavedPlannerJourney()
    openDesignSection("Items", in: application)
    XCTAssertTrue(reopen.waitForExistence(timeout: 10))
    XCTAssertEqual(reopen.identifier, completionIdentifier)
    reopen.activateForPlannerJourney()
    XCTAssertTrue(complete.waitForExistence(timeout: 10))
    application.savedPlannerItemRows(itemTitle).firstMatch.activateForPlannerJourney()
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    recordScreenshot(application, name: "Native row completion preserves the same saved Item")
  }

  func testAdaptiveNavigationKeepsSavedItemAvailableAcrossDestinations() throws {
    try qualifyAdaptiveNavigation()
  }

  func testDarkAdaptiveNavigationKeepsSavedItemAvailableAcrossDestinations() throws {
    try qualifyAdaptiveNavigation(appearance: "Dark")
  }

  private func qualifyAdaptiveNavigation(appearance: String? = nil) throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    #if os(macOS)
      if let appearance { application.launchArguments += ["-AppleInterfaceStyle", appearance] }
    #endif
    #if os(iOS)
      let originalAppearance = XCUIDevice.shared.appearance
      if appearance == "Dark" {
        XCUIDevice.shared.appearance = .dark
        XCTAssertEqual(XCUIDevice.shared.appearance, .dark)
      } else {
        XCUIDevice.shared.appearance = .light
        XCTAssertEqual(XCUIDevice.shared.appearance, .light)
      }
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock {
        await MainActor.run {
          XCUIDevice.shared.orientation = .portrait
          XCUIDevice.shared.appearance = originalAppearance
        }
      }
    #endif
    application.launchSavedPlannerJourney()
    XCTAssertTrue(application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 10))
    let showSidebar = application.windows.firstMatch.buttons["Show Sidebar"].firstMatch
    if showSidebar.exists { showSidebar.activateForPlannerJourney() }
    recordScreenshot(application, name: "Native design initial navigation")
    recordHierarchy(application, name: "Native design initial navigation hierarchy")
    #if os(iOS)
      try auditNativeScene(application, name: "Initial navigation")
    #endif
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCTAssertTrue(
          application.plannerElement("saved.section.items").waitForExistence(timeout: 10))
      }
    #endif
    openDesignSection("Items", in: application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.item.save").isEnabled)
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .phone {
        XCTAssertFalse(application.tabBars.firstMatch.isHittable)
      }
    #endif
    recordScreenshot(application, name: "Native design empty Item draft")
    title.activateForPlannerJourney()
    title.typeText("Museum morning")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet by the garden entrance")
    XCTAssertTrue(application.plannerElement("saved.item.save").isEnabled)
    #if os(iOS)
      revealForContrastReview(
        application.staticTexts["No estimate"].firstMatch,
        in: application.collectionViews.containing(.any, identifier: "saved.item.notes"),
        application: application)
    #endif
    recordScreenshot(application, name: "Native design New Item editor")
    #if os(iOS)
      try auditNativeScene(application, name: "New Item editor")
    #endif
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet by the garden entrance"].waitForExistence(timeout: 10))
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .phone {
        XCTAssertTrue(application.tabBars.firstMatch.isHittable)
      }
    #endif
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    #if os(iOS)
      revealEstimateForAppearanceReview(application)
    #endif
    recordScreenshot(application, name: "Native design selected Item details")
    #if os(iOS)
      try auditNativeScene(
        application, name: "Selected Item details",
        auditTypes: [.contrast, .hitRegion, .sufficientElementDescription])
      for _ in 0..<6 where !completion.isHittable { application.swipeDown() }
      XCTAssertTrue(completion.isHittable)
    #endif
    for section in ["Lists", "Inbox", "Itineraries", "Calendar"] {
      openDesignSection(section, in: application)
      switch section {
      case "Lists":
        #if os(iOS)
          if UIDevice.current.userInterfaceIdiom == .phone {
            let tab = application.buttons.matching(identifier: "list.bullet").firstMatch
            XCTAssertTrue(tab.exists)
            XCTAssertTrue(tab.isSelected)
          } else {
            XCTAssertTrue(
              application.descendants(matching: .any).matching(identifier: "saved.lists.empty")
                .firstMatch.waitForExistence(timeout: 5))
          }
        #else
          XCTAssertTrue(
            application.descendants(matching: .any).matching(identifier: "saved.lists.empty")
              .firstMatch.waitForExistence(timeout: 5))
        #endif
      case "Inbox":
        #if os(iOS)
          if UIDevice.current.userInterfaceIdiom == .phone {
            let back = application.navigationBars.buttons["Inbox"].firstMatch
            if back.exists { back.activateForPlannerJourney() }
          }
        #endif
        XCTAssertTrue(
          application.descendants(matching: .any).matching(identifier: "saved.inbox.catalog")
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(
          application.savedPlannerItemRows("Museum morning").firstMatch.waitForExistence(
            timeout: 10))
      case "Itineraries":
        XCTAssertTrue(application.staticTexts["No Itineraries yet"].waitForExistence(timeout: 5))
      case "Calendar":
        XCTAssertTrue(
          application.descendants(matching: .any).matching(identifier: "saved.calendar.canvas")
            .firstMatch.waitForExistence(timeout: 5))
        #if os(iOS)
          if UIDevice.current.userInterfaceIdiom == .pad,
            let hideSidebar = application.buttons.matching(identifier: "Hide Sidebar")
              .allElementsBoundByIndex.first(where: \.isHittable)
          {
            hideSidebar.activateForPlannerJourney()
          }
          revealForContrastReview(
            application.staticTexts[
              "Choose another date or schedule an Item or Itinerary."
            ].firstMatch,
            in: application.scrollViews.containing(
              .staticText, identifier: "No scheduled entries"
            ), application: application)
          try auditNativeScene(
            application, name: "Fully visible empty Calendar agenda", auditTypes: .contrast)
        #endif
      default: XCTFail("Unexpected design-review destination")
      }
      recordScreenshot(application, name: "Native design \(section) destination")
      #if os(iOS)
        try auditNativeScene(application, name: "\(section) destination")
      #endif
    }
    openDesignSection("Items", in: application)
    let row = application.savedPlannerItemRows("Museum morning").firstMatch
    #if os(iOS)
      if !row.waitForExistence(timeout: 3) {
        application.navigationBars.buttons["Items"].firstMatch.activateForPlannerJourney()
      }
    #endif
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    let originalItemIdentifier = row.identifier
    row.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet by the garden entrance"].waitForExistence(timeout: 10))
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    recordScreenshot(application, name: "Native design retained Item selection")
    #if os(iOS)
      XCUIDevice.shared.orientation = .landscapeLeft
      let landscape = NSPredicate { _, _ in
        let frame = application.windows.firstMatch.frame
        return frame.width > frame.height
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: landscape, object: application)], timeout: 5),
        .completed)
      if UIDevice.current.userInterfaceIdiom == .pad {
        let sidebar = application.windows.firstMatch.buttons["Show Sidebar"].firstMatch
        if sidebar.exists { sidebar.activateForPlannerJourney() }
        recordScreenshot(application, name: "Native design landscape navigation")
        if let hideSidebar = application.buttons.matching(identifier: "Hide Sidebar")
          .allElementsBoundByIndex.first(where: \.isHittable)
        {
          hideSidebar.activateForPlannerJourney()
        }
      } else {
        XCTAssertTrue(application.buttons["Items"].firstMatch.exists)
        XCTAssertFalse(application.plannerElement("saved.section.items").exists)
      }
      XCTAssertTrue(
        application.staticTexts["Meet by the garden entrance"].waitForExistence(timeout: 5))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      activateCompletion(completion)
      XCTAssertTrue(completion.waitForPlannerBooleanState(true))
      activateCompletion(completion)
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      revealForContrastReview(
        application.staticTexts[
          "Completing this Item shows it as done in every List and Itinerary."
        ].firstMatch,
        in: application.collectionViews.containing(
          .any, identifier: "saved.item.completion"
        ), application: application)
      recordScreenshot(application, name: "Native design landscape retains selected Item")
      try auditNativeScene(application, name: "Landscape navigation and Item details")
      XCUIDevice.shared.orientation = .portrait
    #endif
    application.terminate()
    application.launchSavedPlannerJourney()
    openDesignSection("Items", in: application)
    let reopened = application.savedPlannerItemRows("Museum morning").firstMatch
    #if os(iOS)
      if !reopened.waitForExistence(timeout: 3) {
        let back = application.navigationBars.buttons["Items"].firstMatch
        if back.exists { back.activateForPlannerJourney() }
      }
    #endif
    XCTAssertTrue(reopened.waitForExistence(timeout: 10))
    XCTAssertEqual(reopened.identifier, originalItemIdentifier)
    reopened.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet by the garden entrance"].waitForExistence(timeout: 10))
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    #if os(iOS)
      revealEstimateForAppearanceReview(application)
    #endif
    recordScreenshot(application, name: "Native design saved Item after relaunch")
    #if os(iOS)
      try auditNativeScene(
        application, name: "Reopened Item details",
        auditTypes: [.contrast, .hitRegion, .sufficientElementDescription])
    #endif
  }

  #if os(iOS)
    private func revealForContrastReview(
      _ element: XCUIElement, in scrollContentQuery: XCUIElementQuery,
      application: XCUIApplication
    ) {
      let initialContent = scrollContentQuery.firstMatch
      XCTAssertTrue(initialContent.waitForExistence(timeout: 5))
      let containers = application.descendants(matching: initialContent.elementType)
      guard
        let scrollContent = containers.allElementsBoundByIndex.first(where: {
          $0.frame == initialContent.frame && $0.identifier == initialContent.identifier
        })
      else {
        XCTFail("The native scroll content is unavailable.")
        return
      }
      let navigationBar = application.navigationBars.firstMatch
      let tabBar = application.tabBars.firstMatch
      for _ in 0..<8 {
        let windowFrame = application.windows.firstMatch.frame
        let scrollFrame = scrollContent.frame
        var visibleTop = max(windowFrame.minY, scrollFrame.minY)
        var visibleBottom = min(windowFrame.maxY, scrollFrame.maxY)
        if navigationBar.exists { visibleTop = max(visibleTop, navigationBar.frame.maxY) }
        if tabBar.exists { visibleBottom = min(visibleBottom, tabBar.frame.minY) }
        let keyboard = application.keyboards.firstMatch
        if keyboard.exists { visibleBottom = min(visibleBottom, keyboard.frame.minY) }
        guard visibleBottom > visibleTop else {
          XCTFail("The native scroll content is fully covered.")
          return
        }
        let visibleFrame = CGRect(
          x: scrollFrame.minX, y: visibleTop, width: scrollFrame.width,
          height: visibleBottom - visibleTop)
        var scrollTowardTop = false
        if element.exists {
          if visibleFrame.contains(element.frame), element.isHittable { return }
          scrollTowardTop = element.frame.minY < visibleTop
        }
        let scrollOrigin = scrollContent.coordinate(withNormalizedOffset: .zero)
        let upperPoint = scrollOrigin.withOffset(
          CGVector(
            dx: scrollFrame.width * 0.5,
            dy: visibleTop - scrollFrame.minY + visibleFrame.height * 0.35))
        let lowerPoint = scrollOrigin.withOffset(
          CGVector(
            dx: scrollFrame.width * 0.5,
            dy: visibleTop - scrollFrame.minY + visibleFrame.height * 0.65))
        let start = scrollTowardTop ? upperPoint : lowerPoint
        let end = scrollTowardTop ? lowerPoint : upperPoint
        start.press(
          forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
      }
      XCTFail("The contrast target could not be revealed above the native bars: \(element)")
    }

    private func revealEstimateForAppearanceReview(_ application: XCUIApplication) {
      let estimate = application.descendants(matching: .any)
        .matching(identifier: "saved.item.estimate").firstMatch
      for _ in 0..<6 where !estimate.isHittable { application.swipeUp() }
      XCTAssertTrue(estimate.isHittable)
    }

    private func auditNativeScene(
      _ application: XCUIApplication, name: String,
      auditTypes: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription]
    ) throws {
      try XCTContext.runActivity(named: "Native accessibility audit: \(name)") { _ in
        try application.performAccessibilityAudit(for: auditTypes) { issue in
          let attachment = XCTAttachment(string: issue.detailedDescription)
          attachment.name = "Native accessibility issue: \(name)"
          attachment.lifetime = .keepAlways
          self.add(attachment)
          return false
        }
      }
    }
  #endif

  func testItineraryCatalogRetainsArchiveFilterAfterOpeningAndReturning() throws {
    #if os(iOS)
      guard UIDevice.current.userInterfaceIdiom == .pad else {
        throw XCTSkip("This journey qualifies the shared sidebar's catalog/detail transition.")
      }
    #endif
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openDesignSection("Itineraries", in: application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let back = application.plannerElement("saved.itineraries.back")
    XCTAssertTrue(back.waitForExistence(timeout: 10))
    back.activateForPlannerJourney()
    let archive = application.plannerElement("saved.itineraries.archive")
    XCTAssertTrue(archive.waitForExistence(timeout: 5))
    archive.activateForPlannerJourney()
    application.plannerElement("All Itineraries").activateForPlannerJourney()
    XCTAssertEqual(archive.label, "All Itineraries")
    let route = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Museum route")
    ).firstMatch
    XCTAssertTrue(route.waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Native design Itinerary catalog before selection")
    route.activateForPlannerJourney()
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    back.activateForPlannerJourney()
    XCTAssertTrue(archive.waitForExistence(timeout: 5))
    recordScreenshot(application, name: "Native design Itinerary catalog after returning")
    XCTAssertEqual(archive.label, "All Itineraries")
    XCTAssertTrue(route.exists)
  }

  func testItinerarySearchSurvivesSwitchingDestinations() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openDesignSection("Itineraries", in: application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Afternoon route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let done = application.buttons["saved.map.search.done"]
    func revealSearch() -> XCUIElement {
      #if os(iOS)
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
          application.openSavedPlannerCollectionSearch()
          return application.descendants(matching: .any)
            .matching(identifier: "saved.map.search.text").firstMatch
        }
      #endif
      let search = application.searchFields.firstMatch
      #if os(iOS)
        if !search.exists { application.swipeDown() }
      #endif
      return search
    }
    let search = revealSearch()
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.activateForPlannerJourney()
    search.typeText("garden")
    XCTAssertTrue(search.waitForPlannerValue("garden"))
    recordScreenshot(application, name: "Native design Itinerary search before leaving")
    if done.exists {
      done.activateForPlannerJourney()
      XCTAssertTrue(done.waitForNonExistence(timeout: 5))
    }
    openDesignSection("Items", in: application)
    openDesignSection("Itineraries", in: application)
    _ = revealSearch()
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    recordScreenshot(application, name: "Native design Itinerary search after returning")
    XCTAssertTrue(search.waitForPlannerValue("garden"))
    if done.exists { done.activateForPlannerJourney() }
  }

  private func openDesignSection(_ name: String, in application: XCUIApplication) {
    application.openPlannerSection(name)
  }

  #if !os(macOS)
    func testNonexistentStartStaysEnteredDisablesSaveAndCancelCreatesNoSchedule() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openItems(application)
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Missing clock time")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      selectPlanningTimeZone("America/New_York", search: "New York", application: application)
      try enterScheduleClock(
        application, identifier: "saved.schedule.start", date: "8 Mar 2026", hour: 2, minute: 30)
      XCTAssertTrue(
        application.staticTexts[
          "Start does not exist in this time zone. Choose another time."
        ].exists)
      XCTAssertFalse(application.plannerElement("saved.schedule.save").isEnabled)
      recordHierarchy(application, name: "Civil schedule missing Start remains entered")
      recordScreenshot(application, name: "Civil schedule missing Start remains entered")
      application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
      let schedules = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
      XCTAssertEqual(schedules.count, 0)
      application.terminate()
      application.launchSavedPlannerJourney()
      openItems(application)
      let row = application.savedPlannerItemRows("Missing clock time").firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      row.activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 5))
      XCTAssertEqual(schedules.count, 0)
      recordScreenshot(
        application, name: "Civil schedule missing Start Cancel retains unscheduled Item")
    }

    func testRepeatedStartRequiresChoiceAndRetainsEachOccurrenceAfterRelaunch() throws {
      try verifyRepeatedStart(
        itemTitle: "Repeated clock time", date: "1 Nov 2026", minute: 30,
        planningTimeZone: "America/New_York", timeZoneSearch: "New York",
        expectedOccurrences: [
          ("UTC-04:00", "2026-11-01T05:30:00Z"),
          ("UTC-05:00", "2026-11-01T06:30:00Z"),
        ])
    }

    func testLordHoweStartRetainsBothHalfHourOccurrencesAfterRelaunch() throws {
      try verifyRepeatedStart(
        itemTitle: "Half-hour repeat", date: "5 Apr 2026", minute: 45,
        planningTimeZone: "Australia/Lord_Howe", timeZoneSearch: "Lord Howe",
        expectedOccurrences: [
          ("UTC+11:00", "2026-04-04T14:45:00Z"),
          ("UTC+10:30", "2026-04-04T15:15:00Z"),
        ])
    }

    private func verifyRepeatedStart(
      itemTitle: String, date: String, minute: Int, planningTimeZone: String,
      timeZoneSearch: String, expectedOccurrences: [(offset: String, instant: String)]
    ) throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openItems(application)
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText(itemTitle)
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      selectPlanningTimeZone(planningTimeZone, search: timeZoneSearch, application: application)
      try enterScheduleClock(
        application, identifier: "saved.schedule.start", date: date, hour: 1, minute: minute)
      XCTAssertFalse(application.plannerElement("saved.schedule.save").isEnabled)
      let occurrence = application.plannerElement("saved.schedule.start.occurrence")
      XCTAssertTrue(occurrence.waitForExistence(timeout: 5))
      recordScreenshot(application, name: "Civil schedule repeated Start requires a choice")
      let formatter = ISO8601DateFormatter()
      var scheduleIdentifier: String?
      for (offset, expected) in expectedOccurrences {
        selectScheduleOccurrence(application, identifier: "saved.schedule.start", offset: offset)
        XCTAssertTrue(application.plannerElement("saved.schedule.save").isEnabled)
        recordScreenshot(application, name: "Civil schedule explicit Start \(offset)")
        application.plannerElement("saved.schedule.save").activateForPlannerJourney()
        let schedules = application.descendants(matching: .any).matching(
          NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
        let schedule = schedules.firstMatch
        XCTAssertTrue(schedule.waitForExistence(timeout: 10))
        XCTAssertEqual(schedules.count, 1)
        if let scheduleIdentifier { XCTAssertEqual(schedule.identifier, scheduleIdentifier) }
        scheduleIdentifier = schedule.identifier
        let description = try XCTUnwrap(schedule.value as? String)
        XCTAssertTrue(description.hasSuffix(" · \(timeZoneSearch)"))
        XCTAssertEqual(
          try displayedClockChangeInstant(description, timeZoneIdentifier: planningTimeZone),
          formatter.date(from: expected))
        application.terminate()
        application.launchSavedPlannerJourney()
        openItems(application)
        let row = application.savedPlannerItemRows(itemTitle).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.activateForPlannerJourney()
        XCTAssertTrue(schedule.waitForPlannerValue(description))
        XCTAssertEqual(schedule.identifier, scheduleIdentifier)
        XCTAssertEqual(schedules.count, 1)
        recordScreenshot(application, name: "Civil schedule Start \(offset) after relaunch")
        if offset == expectedOccurrences.first?.offset {
          openScheduleMenu(schedule)
          application.plannerElement("Edit schedule").activateForPlannerJourney()
          XCTAssertTrue(application.plannerElement("saved.schedule.save").isEnabled)
        }
      }
    }

    func testRepeatedEndComparesInstantsAndMissingEndEditLeavesSavedScheduleUnchanged() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openItems(application)
      application.openSavedPlannerNewItemEditor()
      let title = application.textFields["saved.item.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      title.typeText("Clock change span")
      application.plannerElement("saved.item.save").activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      selectPlanningTimeZone("America/New_York", search: "New York", application: application)
      try enterScheduleClock(
        application, identifier: "saved.schedule.start", date: "1 Nov 2026", hour: 1, minute: 45)
      selectScheduleOccurrence(application, identifier: "saved.schedule.start", offset: "UTC-04:00")
      let includesEnd = application.descendants(matching: .any).matching(
        identifier: "saved.schedule.hasEnd"
      ).firstMatch
      XCTAssertTrue(includesEnd.waitForPlannerBooleanState(false))
      activateCompletion(includesEnd)
      try enterScheduleClock(
        application, identifier: "saved.schedule.end", date: "1 Nov 2026", hour: 1, minute: 15)
      XCTAssertFalse(application.plannerElement("saved.schedule.save").isEnabled)
      selectScheduleOccurrence(application, identifier: "saved.schedule.end", offset: "UTC-04:00")
      XCTAssertFalse(application.plannerElement("saved.schedule.save").isEnabled)
      XCTAssertTrue(application.staticTexts["End must be later than Start."].exists)
      recordScreenshot(application, name: "Civil schedule earlier End occurrence is invalid")
      selectScheduleOccurrence(application, identifier: "saved.schedule.end", offset: "UTC-05:00")
      XCTAssertTrue(application.plannerElement("saved.schedule.save").isEnabled)
      recordScreenshot(application, name: "Civil schedule later End occurrence is valid")
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      let schedules = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
      let schedule = schedules.firstMatch
      XCTAssertTrue(schedule.waitForExistence(timeout: 10))
      XCTAssertEqual(schedules.count, 1)
      let identity = schedule.identifier
      let description = try XCTUnwrap(schedule.value as? String)
      XCTAssertTrue(description.hasSuffix(" · New York"))
      let components = description.components(separatedBy: " · ")
      XCTAssertEqual(components.count, 2)
      let endpoints = components[0].components(separatedBy: " – ")
      XCTAssertEqual(endpoints.count, 2)
      let formatter = ISO8601DateFormatter()
      XCTAssertEqual(
        try displayedClockChangeInstant(endpoints[0] + " · " + components[1]),
        formatter.date(from: "2026-11-01T05:45:00Z"))
      XCTAssertEqual(
        try displayedClockChangeInstant(endpoints[1] + " · " + components[1]),
        formatter.date(from: "2026-11-01T06:15:00Z"))
      openScheduleMenu(schedule)
      application.plannerElement("Edit schedule").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement("saved.schedule.save").isEnabled)
      try enterScheduleClock(
        application, identifier: "saved.schedule.start", date: "8 Mar 2026", hour: 1, minute: 30)
      XCTAssertTrue(application.plannerElement("saved.schedule.save").isEnabled)
      try enterScheduleClock(
        application, identifier: "saved.schedule.end", date: "8 Mar 2026", hour: 2, minute: 30)
      XCTAssertTrue(
        application.staticTexts[
          "End does not exist in this time zone. Choose another time."
        ].exists)
      XCTAssertFalse(application.plannerElement("saved.schedule.save").isEnabled)
      recordScreenshot(application, name: "Civil schedule missing End edit cannot Save")
      application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
      XCTAssertTrue(schedule.waitForPlannerValue(description))
      XCTAssertEqual(schedule.identifier, identity)
      application.terminate()
      application.launchSavedPlannerJourney()
      openItems(application)
      let row = application.savedPlannerItemRows("Clock change span").firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      row.activateForPlannerJourney()
      XCTAssertTrue(schedule.waitForPlannerValue(description))
      XCTAssertEqual(schedule.identifier, identity)
      XCTAssertEqual(schedules.count, 1)
      recordScreenshot(
        application, name: "Civil schedule valid span survives invalid draft and relaunch")
    }

    private func selectScheduleOccurrence(
      _ application: XCUIApplication, identifier: String, offset: String
    ) {
      let occurrence = application.plannerElement(identifier + ".occurrence")
      XCTAssertTrue(occurrence.waitForExistence(timeout: 5))
      occurrence.activateForPlannerJourney()
      let option = application.buttons.matching(
        NSPredicate(format: "label ENDSWITH %@", offset)
      ).firstMatch
      XCTAssertTrue(option.waitForExistence(timeout: 5))
      option.activateForPlannerJourney()
    }

    private func displayedClockChangeInstant(
      _ description: String, timeZoneIdentifier: String = "America/New_York"
    ) throws -> Date {
      let components = description.components(separatedBy: " · ")
      XCTAssertEqual(components.count, 2)
      var formatStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
        .timeZone(.specificName(.short))
      formatStyle.timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
      return try formatStyle.parseStrategy.parse(components[0])
    }

    private func enterScheduleClock(
      _ application: XCUIApplication, identifier: String, date: String, hour: Int, minute: Int
    ) throws {
      let picker = application.descendants(matching: .any).matching(identifier: identifier)
        .firstMatch
      XCTAssertTrue(picker.waitForExistence(timeout: 5))
      let dateButton = picker.buttons.firstMatch
      let dateFormatter = DateFormatter()
      dateFormatter.locale = Locale(identifier: "en_GB")
      dateFormatter.timeZone = .gmt
      dateFormatter.dateFormat = "d MMM yyyy"
      let targetDate = try XCTUnwrap(dateFormatter.date(from: date))
      recordHierarchy(application, name: "Civil schedule date control before opening")
      dateButton.activateForPlannerJourney()
      let monthHeader = application.buttons["DatePicker.Show"].firstMatch
      XCTAssertTrue(monthHeader.waitForExistence(timeout: 5))
      let displayedMonth = try XCTUnwrap(monthHeader.value as? String)
      dateFormatter.dateFormat = "MMMM yyyy"
      let currentDate = try XCTUnwrap(dateFormatter.date(from: displayedMonth))
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let currentMonth = try XCTUnwrap(calendar.dateInterval(of: .month, for: currentDate)?.start)
      let targetMonth = try XCTUnwrap(calendar.dateInterval(of: .month, for: targetDate)?.start)
      let monthDistance = try XCTUnwrap(
        calendar.dateComponents(
          [.month], from: currentMonth, to: targetMonth
        ).month)
      let monthControl = monthDistance < 0 ? "DatePicker.PreviousMonth" : "DatePicker.NextMonth"
      for _ in 0..<abs(monthDistance) {
        application.buttons[monthControl].firstMatch.activateForPlannerJourney()
      }
      let day = calendar.component(.day, from: targetDate)
      let dayButton = application.buttons.containing(.staticText, identifier: String(day))
        .firstMatch
      XCTAssertTrue(dayButton.waitForExistence(timeout: 5))
      dayButton.activateForPlannerJourney()
      dismissScheduleClockPopover(application)
      XCTAssertTrue(picker.buttons[date].firstMatch.exists)
      let timeButton = picker.buttons.matching(
        NSPredicate(format: "label MATCHES %@", "[0-9]{1,2}:[0-9]{2}.*")
      ).firstMatch
      XCTAssertTrue(timeButton.waitForExistence(timeout: 5))
      timeButton.activateForPlannerJourney()
      let hourWheel = application.pickerWheels.element(boundBy: 0)
      let minuteWheel = application.pickerWheels.element(boundBy: 1)
      XCTAssertTrue(hourWheel.waitForExistence(timeout: 5))
      XCTAssertTrue(minuteWheel.waitForExistence(timeout: 5))
      minuteWheel.adjust(toPickerWheelValue: String(format: "%02d", minute))
      hourWheel.adjust(toPickerWheelValue: String(format: "%02d", hour))
      dismissScheduleClockPopover(application)
      XCTAssertTrue(picker.buttons[date].firstMatch.exists)
      XCTAssertTrue(picker.buttons[String(format: "%02d:%02d", hour, minute)].firstMatch.exists)
    }

    private func dismissScheduleClockPopover(_ application: XCUIApplication) {
      let region = application.buttons["PopoverDismissRegion"].firstMatch
      XCTAssertTrue(region.waitForExistence(timeout: 5))
      application.plannerElement("saved.schedule.cancel").coordinate(
        withNormalizedOffset: CGVector(dx: 1.4, dy: 0.5)
      ).tap()
      XCTAssertTrue(region.waitForNonExistence(timeout: 5))
    }
  #endif

  func testPlanningTimeZoneSelectionStagesCancelAndPreservesInstantAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Travel appointment")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the travel notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    let timeZoneControl = application.plannerElement("saved.schedule.zone")
    XCTAssertTrue(timeZoneControl.waitForExistence(timeout: 5))
    selectPlanningTimeZone("Europe/Paris", search: "Paris", application: application)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "Start only")
    let identity = schedule.identifier
    let originalDescription = try XCTUnwrap(schedule.value as? String)
    recordScreenshot(application, name: "Readable saved schedule summary")
    XCTAssertTrue(originalDescription.hasSuffix(" · Paris"))
    let originalInstant = try displayedStartInstant(
      originalDescription, timeZoneIdentifier: "Europe/Paris")
    openScheduleMenu(schedule)
    application.plannerElement("Edit schedule").activateForPlannerJourney()
    selectPlanningTimeZone("America/New_York", search: "New York", application: application)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForPlannerValue(originalDescription))
    XCTAssertEqual(scheduleRows.count, 1)
    openScheduleMenu(schedule)
    application.plannerElement("Edit schedule").activateForPlannerJourney()
    selectPlanningTimeZone("Asia/Tokyo", search: "Tokyo", application: application)
    recordScreenshot(application, name: "Native timezone selection stages the existing instant")
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value ENDSWITH %@", " · Tokyo"), object: schedule)
        ], timeout: 10), .completed)
    let changedDescription = try XCTUnwrap(schedule.value as? String)
    XCTAssertNotEqual(changedDescription, originalDescription)
    XCTAssertEqual(
      try displayedStartInstant(changedDescription, timeZoneIdentifier: "Asia/Tokyo"),
      originalInstant)
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertTrue(application.staticTexts["Keep the travel notes"].exists)
    recordScreenshot(application, name: "Native timezone edit preserves the scheduled instant")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let row = application.savedPlannerItemRows("Travel appointment").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertTrue(schedule.waitForPlannerValue(changedDescription))
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(
      try displayedStartInstant(
        try XCTUnwrap(schedule.value as? String), timeZoneIdentifier: "Asia/Tokyo"), originalInstant
    )
    XCTAssertTrue(application.staticTexts["Keep the travel notes"].exists)
    recordScreenshot(application, name: "Native planning timezone survives relaunch")
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
    recordScreenshot(application, name: "Native time zone search choices for \(identifier)")
    option.activateForPlannerJourney()
    XCTAssertTrue(timeZoneControl.waitForExistence(timeout: 5))
    recordScreenshot(application, name: "Readable schedule time zone \(search)")
    XCTAssertEqual(timeZoneControl.label, "Time zone, \(search)")
  }

  private func displayedStartInstant(
    _ description: String, timeZoneIdentifier: String
  ) throws -> Date {
    let components = description.components(separatedBy: " · ")
    XCTAssertEqual(components.count, 2)
    let timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
    var formatStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
    formatStyle.timeZone = timeZone
    return try formatStyle.parseStrategy.parse(components[0])
  }

  func testEditingAllDayScheduleReloadsCivilDatesAndKeepsIdentityAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Updated gallery days")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    let allDay = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.allDay").firstMatch
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    activateCompletion(allDay)
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    activateCompletion(includeEnd)
    selectScheduleDay(application, pickerIdentifier: "saved.schedule.start", day: 9)
    selectScheduleDay(application, pickerIdentifier: "saved.schedule.end", day: 11)
    let startButton = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.start").firstMatch.buttons.firstMatch
    let endButton = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.end").firstMatch.buttons.firstMatch
    let originalStartLabel = startButton.label
    let originalEndLabel = endButton.label
    XCTAssertFalse(originalStartLabel.isEmpty)
    XCTAssertFalse(originalEndLabel.isEmpty)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "All day")
    let identity = schedule.identifier
    let originalDescription = schedule.value as? String
    XCTAssertTrue(originalDescription?.contains("9") == true)
    XCTAssertTrue(originalDescription?.contains("11") == true)
    openScheduleMenu(schedule)
    let editAction = application.plannerElement("Edit schedule")
    XCTAssertTrue(editAction.waitForExistence(timeout: 5))
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    XCTAssertEqual(startButton.label, originalStartLabel)
    XCTAssertEqual(endButton.label, originalEndLabel)
    recordScreenshot(application, name: "Native all-day edit reloads the saved civil range")
    selectScheduleDay(application, pickerIdentifier: "saved.schedule.end", day: 12)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(schedule.value as? String, originalDescription)
    XCTAssertEqual(scheduleRows.count, 1)
    openScheduleMenu(schedule)
    editAction.activateForPlannerJourney()
    XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    XCTAssertEqual(startButton.label, originalStartLabel)
    XCTAssertEqual(endButton.label, originalEndLabel)
    selectScheduleDay(application, pickerIdentifier: "saved.schedule.end", day: 12)
    XCTAssertTrue(application.staticTexts["Includes both selected dates."].exists)
    XCTAssertTrue(application.plannerElement("saved.schedule.save").isEnabled)
    recordScreenshot(application, name: "Native all-day edit changes only the range end")
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "12"), object: schedule)
        ], timeout: 10), .completed)
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(schedule.label, "All day")
    XCTAssertEqual(scheduleRows.count, 1)
    let editedDescription = schedule.value as? String
    XCTAssertTrue(editedDescription?.contains("9") == true)
    XCTAssertNotEqual(editedDescription, originalDescription)
    recordScreenshot(application, name: "Native saved all-day edit preserves schedule identity")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let row = application.savedPlannerItemRows("Updated gallery days").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    let restored = application.descendants(matching: .any).matching(identifier: identity).firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertEqual(restored.label, "All day")
    XCTAssertEqual(restored.value as? String, editedDescription)
    XCTAssertEqual(scheduleRows.count, 1)
    recordScreenshot(application, name: "Native all-day edit preserves civil dates after relaunch")
  }

  func testEditingScheduleCanCancelOrClearEndWithoutReplacingIdentityAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Gallery appointment")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the gallery notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the gallery notes"].waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    activateCompletion(includeEnd)
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "Timed")
    let identity = schedule.identifier
    let originalDescription = schedule.value as? String
    XCTAssertFalse(originalDescription?.isEmpty ?? true)
    openScheduleMenu(schedule)
    let editAction = application.plannerElement("Edit schedule")
    XCTAssertTrue(editAction.waitForExistence(timeout: 5))
    editAction.activateForPlannerJourney()
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    activateCompletion(includeEnd)
    XCTAssertTrue(application.staticTexts["This schedule has no end time."].exists)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForExistence(timeout: 5))
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(schedule.label, "Timed")
    XCTAssertEqual(schedule.value as? String, originalDescription)
    openScheduleMenu(schedule)
    editAction.activateForPlannerJourney()
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    activateCompletion(includeEnd)
    recordScreenshot(application, name: "Native Schedule edit clears only its draft end")
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Start only"), object: schedule)
        ], timeout: 10), .completed)
    XCTAssertEqual(schedule.identifier, identity)
    XCTAssertEqual(scheduleRows.count, 1)
    let editedDescription = schedule.value as? String
    XCTAssertFalse(editedDescription?.isEmpty ?? true)
    XCTAssertNotEqual(editedDescription, originalDescription)
    XCTAssertTrue(application.staticTexts["Keep the gallery notes"].exists)
    XCTAssertFalse(application.alerts["Planner"].exists)
    recordScreenshot(application, name: "Native Schedule edit preserves its identity")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let row = application.savedPlannerItemRows("Gallery appointment").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    let restored = application.descendants(matching: .any).matching(identifier: identity).firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertEqual(restored.label, "Start only")
    XCTAssertEqual(restored.value as? String, editedDescription)
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertTrue(application.staticTexts["Keep the gallery notes"].exists)
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    recordScreenshot(application, name: "Native Schedule edit survives relaunch")
  }

  func testEditedAllDayRangeRejectsEarlierEndAndKeepsInclusiveDatesAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Three-day gallery")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    let allDay = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.allDay").firstMatch
    XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
    activateCompletion(allDay)
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    activateCompletion(includeEnd)
    selectScheduleDay(application, pickerIdentifier: "saved.schedule.start", day: 9)
    selectScheduleDay(application, pickerIdentifier: "saved.schedule.end", day: 8)
    XCTAssertTrue(
      application.staticTexts["End date cannot precede Start."].waitForExistence(timeout: 5))
    XCTAssertFalse(application.plannerElement("saved.schedule.save").isEnabled)
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    XCTAssertEqual(scheduleRows.count, 0)
    recordScreenshot(application, name: "Native all-day range rejects an earlier end")
    selectScheduleDay(application, pickerIdentifier: "saved.schedule.end", day: 11)
    XCTAssertTrue(
      application.staticTexts["Includes both selected dates."].waitForExistence(timeout: 5))
    XCTAssertTrue(application.plannerElement("saved.schedule.save").isEnabled)
    recordScreenshot(application, name: "Native all-day range includes the selected dates")
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "All day")
    let identity = schedule.identifier
    let description = schedule.value as? String
    XCTAssertTrue(description?.contains("9") == true)
    XCTAssertTrue(description?.contains("11") == true)
    recordScreenshot(application, name: "Native saved inclusive all-day range")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let row = application.savedPlannerItemRows("Three-day gallery").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.activateForPlannerJourney()
    let restored = application.descendants(matching: .any).matching(identifier: identity).firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertEqual(restored.value as? String, description)
    XCTAssertEqual(scheduleRows.count, 1)
    recordScreenshot(application, name: "Native inclusive all-day range after relaunch")
  }

  private func selectScheduleDay(
    _ application: XCUIApplication, pickerIdentifier: String, day: Int
  ) {
    let picker = application.descendants(matching: .any)
      .matching(identifier: pickerIdentifier).firstMatch
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    let dateButton = picker.buttons.firstMatch
    if !dateButton.waitForExistence(timeout: 5) {
      recordHierarchy(application, name: "Native date picker opening query")
      XCTFail("The native schedule date button must be available.")
      return
    }
    dateButton.activateForPlannerJourney()
    let selectedDay = application.buttons.containing(.staticText, identifier: String(day))
      .firstMatch
    if !selectedDay.waitForExistence(timeout: 5) {
      recordHierarchy(application, name: "Native calendar day selection query")
      XCTFail("The requested native calendar day must be available.")
      return
    }
    selectedDay.activateForPlannerJourney()
    let dismissRegion = application.buttons.matching(identifier: "PopoverDismissRegion").firstMatch
    XCTAssertTrue(dismissRegion.waitForExistence(timeout: 5))
    let insideScheduleToolbar = application.plannerElement("saved.schedule.cancel").coordinate(
      withNormalizedOffset: CGVector(dx: 1.4, dy: 0.5))
    #if os(macOS)
      insideScheduleToolbar.click()
    #else
      insideScheduleToolbar.tap()
    #endif
    XCTAssertTrue(dismissRegion.waitForNonExistence(timeout: 5))
    XCTAssertTrue(application.plannerElement("saved.schedule.cancel").exists)
  }

  private func recordHierarchy(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(string: application.debugDescription)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testAllDayItemSchedulesKeepCivilDateAndRowPreviewAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("All-day gallery")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule."))
    for cancelsDraft in [true, false] {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      let allDay = application.descendants(matching: .any)
        .matching(identifier: "saved.schedule.allDay").firstMatch
      XCTAssertTrue(allDay.waitForPlannerBooleanState(false))
      activateCompletion(allDay)
      XCTAssertTrue(allDay.waitForPlannerBooleanState(true))
      let includeEnd = application.descendants(matching: .any)
        .matching(identifier: "saved.schedule.hasEnd").firstMatch
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
      activateCompletion(includeEnd)
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
      XCTAssertTrue(application.staticTexts["Includes both selected dates."].exists)
      if cancelsDraft {
        application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
        XCTAssertEqual(scheduleRows.count, 0)
      } else {
        recordScreenshot(application, name: "Native all-day Item schedule draft")
        application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      }
    }
    let schedule = scheduleRows.firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(schedule.label, "All day")
    let identity = schedule.identifier
    let description = schedule.value as? String
    XCTAssertFalse(description?.isEmpty ?? true)
    XCTAssertFalse(description?.contains(":") ?? true)
    recordScreenshot(application, name: "Native saved all-day Item schedule")
    returnToItemCatalog(application)
    let row = application.savedPlannerItemRows("All-day gallery").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertTrue((row.value as? String ?? "").contains("All day"))
    let rowIdentity = row.identifier
    let rowMetadata = row.value as? String
    application.terminate()
    application.launchSavedPlannerJourney()
    returnToItemCatalog(application)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(row.identifier, rowIdentity)
    XCTAssertEqual(row.value as? String, rowMetadata)
    row.activateForPlannerJourney()
    let restored = application.descendants(matching: .any).matching(identifier: identity).firstMatch
    XCTAssertTrue(restored.waitForExistence(timeout: 10))
    XCTAssertEqual(restored.label, "All day")
    XCTAssertEqual(restored.value as? String, description)
    XCTAssertEqual(scheduleRows.count, 1)
    recordScreenshot(application, name: "Native all-day Item schedule after relaunch")
  }

  func testItemRowsPreviewSavedAppointmentsAndAdditionalCountAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum appointments")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    returnToItemCatalog(application)
    let row = application.savedPlannerItemRows("Museum appointments").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    let identity = row.identifier
    XCTAssertFalse((row.value as? String ?? "").contains("Scheduled:"))
    for includesEnd in [false, true] {
      row.activateForPlannerJourney()
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      let includeEnd = application.descendants(matching: .any)
        .matching(identifier: "saved.schedule.hasEnd").firstMatch
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
      if includesEnd { activateCompletion(includeEnd) }
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      let savedSchedule = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.",
          includesEnd ? "Timed" : "Start only")
      ).firstMatch
      XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
      returnToItemCatalog(application)
      let expectedMetadata = includesEnd ? "1 additional schedule" : "Scheduled:"
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "value CONTAINS %@", expectedMetadata), object: row)
          ], timeout: 10), .completed)
      XCTAssertEqual(row.identifier, identity)
      if !includesEnd {
        XCTAssertFalse((row.value as? String ?? "").contains("additional schedule"))
        recordScreenshot(application, name: "Native Item row shows a start-only appointment")
      }
    }
    let savedMetadata = row.value as? String
    XCTAssertNotNil(savedMetadata)
    XCTAssertTrue(savedMetadata?.contains("Scheduled:") == true)
    recordScreenshot(application, name: "Native Item row shows additional appointments")
    application.terminate()
    application.launchSavedPlannerJourney()
    returnToItemCatalog(application)
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertEqual(row.identifier, identity)
    XCTAssertEqual(row.value as? String, savedMetadata)
    recordScreenshot(application, name: "Native Item appointment row after relaunch")
  }

  private func returnToItemCatalog(_ application: XCUIApplication) {
    openItems(application)
    let back = application.navigationBars.buttons["Items"].firstMatch
    if back.exists { back.activateForPlannerJourney() }
    XCTAssertTrue(application.plannerElement("saved.item.addMenu").waitForExistence(timeout: 10))
  }

  func testConfirmedScheduleRemovalKeepsOtherAppointmentsAndSourceItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Garden appointments")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the meeting notes")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the meeting notes"].waitForExistence(timeout: 10))
    let startOnlySchedules = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Start only"))
    let timedSchedules = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Timed"))
    for includesEnd in [false, true] {
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("Schedule item").activateForPlannerJourney()
      let includeEnd = application.descendants(matching: .any)
        .matching(identifier: "saved.schedule.hasEnd").firstMatch
      XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
      if includesEnd { activateCompletion(includeEnd) }
      application.plannerElement("saved.schedule.save").activateForPlannerJourney()
      let savedSchedule = includesEnd ? timedSchedules.firstMatch : startOnlySchedules.firstMatch
      XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    }
    let retainedIdentifier = startOnlySchedules.firstMatch.identifier
    openScheduleMenu(timedSchedules.firstMatch)
    let removeAction = application.plannerElement("Remove schedule")
    XCTAssertTrue(removeAction.waitForExistence(timeout: 5))
    removeAction.activateForPlannerJourney()
    let confirm = application.buttons.matching(identifier: "saved.schedule.remove.confirm")
      .firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    XCTAssertTrue(
      application.staticTexts[
        "1 schedule will be removed. The Item and its other schedules stay available."
      ].exists)
    recordScreenshot(application, name: "Native schedule removal confirmation")
    application.staticTexts["Garden appointments"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    XCTAssertEqual(timedSchedules.count, 1)
    XCTAssertEqual(startOnlySchedules.count, 1)
    openScheduleMenu(timedSchedules.firstMatch)
    removeAction.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.activateForPlannerJourney()
    XCTAssertTrue(timedSchedules.firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertEqual(startOnlySchedules.count, 1)
    XCTAssertEqual(startOnlySchedules.firstMatch.identifier, retainedIdentifier)
    XCTAssertTrue(application.staticTexts["Keep the meeting notes"].exists)
    XCTAssertFalse(application.alerts["Planner"].waitForExistence(timeout: 2))
    recordScreenshot(application, name: "Native schedule removal preserves another appointment")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retainedItem = application.savedPlannerItemRows("Garden appointments").firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(startOnlySchedules.firstMatch.waitForExistence(timeout: 10))
    XCTAssertEqual(startOnlySchedules.firstMatch.identifier, retainedIdentifier)
    XCTAssertEqual(timedSchedules.count, 0)
    openScheduleMenu(startOnlySchedules.firstMatch)
    removeAction.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.activateForPlannerJourney()
    XCTAssertTrue(startOnlySchedules.firstMatch.waitForNonExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Keep the meeting notes"].waitForExistence(timeout: 10))
    XCTAssertEqual(startOnlySchedules.count, 0)
    XCTAssertEqual(timedSchedules.count, 0)
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    XCTAssertFalse(application.alerts["Planner"].waitForExistence(timeout: 2))
    recordScreenshot(application, name: "Native Item remains after removing its last schedule")
  }

  private func openScheduleMenu(_ schedule: XCUIElement) {
    #if os(macOS)
      schedule.rightClick()
    #else
      schedule.press(forDuration: 1.2)
    #endif
  }

  func testOptionalScheduleEndCanBeClearedCanceledAndSavedAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Timed visit")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    let includeEnd = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.hasEnd").firstMatch
    XCTAssertTrue(includeEnd.waitForExistence(timeout: 5))
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    let endPicker = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.end").firstMatch
    XCTAssertFalse(endPicker.exists)
    activateCompletion(includeEnd)
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(true))
    XCTAssertTrue(endPicker.waitForExistence(timeout: 5))
    XCTAssertFalse(application.staticTexts["This schedule has no end time."].exists)
    activateCompletion(includeEnd)
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    XCTAssertFalse(endPicker.exists)
    XCTAssertTrue(application.staticTexts["This schedule has no end time."].exists)
    activateCompletion(includeEnd)
    XCTAssertTrue(endPicker.waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    let timedSchedules = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Timed"))
    XCTAssertEqual(timedSchedules.count, 0)
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    XCTAssertTrue(includeEnd.waitForPlannerBooleanState(false))
    activateCompletion(includeEnd)
    XCTAssertTrue(endPicker.waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let savedSchedule = timedSchedules.firstMatch
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(timedSchedules.count, 1)
    let identifier = savedSchedule.identifier
    let description = savedSchedule.value as? String
    XCTAssertNotNil(description)
    recordScreenshot(application, name: "Native saved Item schedule with optional end")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retainedItem = application.savedPlannerItemRows("Timed visit").firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(timedSchedules.count, 1)
    XCTAssertEqual(savedSchedule.identifier, identifier)
    XCTAssertEqual(savedSchedule.value as? String, description)
    let itemCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    recordScreenshot(application, name: "Native Item schedule with optional end after relaunch")
  }

  func testCancelingScheduleDraftAndSavingStartOnlyAssignmentPreserveItemAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Garden visit")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet by the entrance")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Meet by the entrance"].waitForExistence(timeout: 10))
    let itemCompletion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    let scheduleAction = application.plannerElement("Schedule item")
    XCTAssertTrue(scheduleAction.waitForExistence(timeout: 5))
    scheduleAction.activateForPlannerJourney()
    let startPicker = application.descendants(matching: .any)
      .matching(identifier: "saved.schedule.start").firstMatch
    XCTAssertTrue(startPicker.waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["This schedule has no end time."].exists)
    application.plannerElement("saved.schedule.cancel").activateForPlannerJourney()
    XCTAssertFalse(startPicker.waitForExistence(timeout: 2))
    let scheduleRows = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.schedule.", "Start only"))
    XCTAssertEqual(scheduleRows.count, 0)
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    scheduleAction.activateForPlannerJourney()
    XCTAssertTrue(startPicker.waitForExistence(timeout: 5))
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let savedSchedule = scheduleRows.firstMatch
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    let savedIdentifier = savedSchedule.identifier
    let savedDescription = savedSchedule.value as? String
    XCTAssertNotNil(savedDescription)
    XCTAssertFalse(startPicker.exists)
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet by the entrance"].exists)
    recordScreenshot(application, name: "Native saved start-only Item schedule")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retainedItem = application.savedPlannerItemRows("Garden visit").firstMatch
    XCTAssertTrue(retainedItem.waitForExistence(timeout: 10))
    retainedItem.activateForPlannerJourney()
    XCTAssertTrue(savedSchedule.waitForExistence(timeout: 10))
    XCTAssertEqual(scheduleRows.count, 1)
    XCTAssertEqual(savedSchedule.identifier, savedIdentifier)
    XCTAssertEqual(savedSchedule.value as? String, savedDescription)
    XCTAssertTrue(itemCompletion.waitForPlannerBooleanState(false))
    XCTAssertTrue(application.staticTexts["Meet by the entrance"].exists)
    recordScreenshot(application, name: "Native start-only Item schedule after relaunch")
  }

  func testItemsCreationMenuAfterFreshLaunchCanOpenAndCancelDraft() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertTrue(title.isHittable)
    let cancel = application.windows.firstMatch.buttons.matching(
      NSPredicate(
        format: "identifier == %@ OR identifier == %@", "saved.item.cancel", "saved.item.back")
    ).firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    cancel.activateForPlannerJourney()
    XCTAssertTrue(title.waitForNonExistence(timeout: 5))
  }

  func testItemDraftCancellationAndGlobalCompletionSurviveNativeRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openItems(application)
    let newItem = application.plannerElement("saved.item.addMenu")
    XCTAssertTrue(newItem.waitForExistence(timeout: 10))
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Canceled visit")
    let cancel = application.windows.firstMatch.buttons.matching(
      NSPredicate(
        format: "identifier == %@ OR identifier == %@", "saved.item.cancel", "saved.item.back")
    ).firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    cancel.activateForPlannerJourney()
    let discard = application.windows.firstMatch.buttons["Discard"].firstMatch
    XCTAssertTrue(discard.waitForExistence(timeout: 5))
    discard.activateForPlannerJourney()
    let addAfterDiscard = application.plannerElement("saved.item.addMenu")
    XCTAssertTrue(addAfterDiscard.waitForExistence(timeout: 10))
    XCTAssertTrue(addAfterDiscard.waitForPlannerHittability())
    XCTAssertFalse(application.staticTexts["Canceled visit"].exists)

    application.openSavedPlannerNewItemEditor()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Nezu Museum")
    let notes = application.textFields["saved.item.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Meet at the garden entrance")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 10))
    XCTAssertFalse(title.exists)
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    XCTAssertEqual(completion.plannerBooleanState, false)
    activateCompletion(completion)
    XCTAssertTrue(completion.waitForPlannerBooleanState(true), application.debugDescription)
    XCTAssertFalse(application.staticTexts["Global: Todo"].exists)
    XCTAssertFalse(application.plannerElement("Open source Item").exists)
    recordScreenshot(application, name: "Saved Item with global completion")

    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let retained = application.savedPlannerItemRows("Nezu Museum").firstMatch
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    retained.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Meet at the garden entrance"].waitForExistence(timeout: 5))
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    activateCompletion(completion)
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    XCTAssertFalse(application.staticTexts["Canceled visit"].exists)
    recordScreenshot(application, name: "Saved Item reopened globally after relaunch")
  }

  private func openItems(_ application: XCUIApplication) {
    application.openPlannerSection("Items")
  }

  private func activateCompletion(_ element: XCUIElement) {
    #if os(macOS)
      element.click()
    #else
      let visibleSwitch = element.switches.firstMatch
      XCTAssertTrue(visibleSwitch.exists)
      visibleSwitch.tap()
    #endif
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    #if os(macOS)
      let screenshot = application.windows.firstMatch.screenshot()
    #else
      let screenshot = XCUIScreen.main.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
