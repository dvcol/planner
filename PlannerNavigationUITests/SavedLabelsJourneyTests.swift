import XCTest

@MainActor
final class SavedLabelsJourneyTests: XCTestCase {
  func testCategoryDeletionReviewsItemAndItineraryUsesAndPreservesOwnersAfterCancelAndRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    createLabel("Category", name: "Culture", application: application)
    let category = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.category.", "Culture")
    ).firstMatch
    let categoryIdentifier = category.identifier
    createLabel("Tag", name: "Rain", application: application)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    createLabeledItem("Museum", categories: ["Culture"], tags: ["Rain"], application: application)
    openItems(application)
    let item = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 10))
    let itemIdentifier = item.identifier
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    selectLabels(
      "Categories", names: ["Culture"], identifierPrefix: "saved.itinerary",
      application: application)
    selectLabels(
      "Tags", names: ["Rain"], identifierPrefix: "saved.itinerary", application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    addItineraryEntry("Museum", application: application)
    let appearance = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance.")
    ).firstMatch
    XCTAssertTrue(appearance.waitForExistence(timeout: 10))
    let appearanceIdentifier = appearance.identifier
    let completionIdentifier = appearanceIdentifier.replacingOccurrences(
      of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    application.plannerElement(completionIdentifier).activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 of 1 item done"].waitForExistence(timeout: 10))
    openLabels(application)
    application.plannerElement(categoryIdentifier).activateForPlannerJourney()
    let deletion = application.plannerElement("saved.category.delete")
    XCTAssertTrue(deletion.waitForExistence(timeout: 5))
    deletion.activateForPlannerJourney()
    let impact = application.staticTexts["1 Item · 1 Itinerary"]
    XCTAssertTrue(impact.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Culture"].firstMatch.exists)
    recordLabelsScreenshot(application, name: "Category Delete reviews Item and Itinerary uses")
    application.plannerElement("saved.category.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(deletion.waitForExistence(timeout: 5))
    XCTAssertTrue(application.textFields["saved.category.name"].waitForPlannerValue("Culture"))
    application.plannerElement("saved.category.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(categoryIdentifier).waitForExistence(timeout: 5))
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItineraries(application)
    let restoredAfterCancellation = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Weekend route")
    ).firstMatch
    XCTAssertTrue(restoredAfterCancellation.waitForExistence(timeout: 10))
    restoredAfterCancellation.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement(appearanceIdentifier).waitForPlannerValue(
        "Categories: Culture, Tags: Rain"))
    XCTAssertTrue(application.staticTexts["1 of 1 item done"].exists)
    openLabels(application)
    application.plannerElement(categoryIdentifier).activateForPlannerJourney()
    deletion.activateForPlannerJourney()
    XCTAssertTrue(impact.waitForExistence(timeout: 10))
    application.plannerElement("saved.category.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(categoryIdentifier).waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.textFields["saved.category.name"].waitForNonExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.exists)
    recordLabelsScreenshot(application, name: "Confirmed Category deletion retains the other label")
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItems(application)
    XCTAssertTrue(application.plannerElement(itemIdentifier).waitForExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement(itemIdentifier).waitForPlannerValue("Tags: Rain"))
    application.plannerElement(itemIdentifier).activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Culture"].exists)
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.exists)
    let globalCompletion = application.descendants(matching: .any).matching(
      identifier: "saved.item.completion"
    ).firstMatch
    XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Weekend route")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement(appearanceIdentifier).waitForPlannerValue("Tags: Rain"))
    XCTAssertTrue(application.plannerElement(completionIdentifier).waitForPlannerValue("Completed"))
    XCTAssertTrue(application.staticTexts["1 of 1 item done"].exists)
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.exists)
    XCTAssertFalse(application.staticTexts["Culture"].exists)
    recordLabelsScreenshot(
      application, name: "Category deletion preserves completed route after relaunch")
    openLabels(application)
    XCTAssertFalse(application.plannerElement(categoryIdentifier).exists)
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.exists)
  }

  func testItineraryOnlyTagDeletionRequiresConfirmationAndRetainsTheOtherSameNameIdentity() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    createLabel("Tag", name: "Rain", application: application)
    let tagRows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Rain"))
    let deletedTagIdentifier = tagRows.firstMatch.identifier
    createLabel("Tag", name: "Rain", application: application)
    XCTAssertTrue(application.textFields["saved.tag.name"].waitForNonExistence(timeout: 5))
    XCTAssertEqual(tagRows.count, 2)
    let survivingTagIdentifier = tagRows.matching(
      NSPredicate(format: "identifier != %@", deletedTagIdentifier)
    ).firstMatch.identifier
    XCTAssertNotEqual(deletedTagIdentifier, survivingTagIdentifier)
    createLabel("Category", name: "Culture", application: application)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Rain route")
    let notes = application.textFields["saved.itinerary.notes"]
    notes.activateForPlannerJourney()
    notes.typeText("Keep the rainy route notes")
    selectLabels(
      "Categories", names: ["Culture"], identifierPrefix: "saved.itinerary",
      application: application)
    application.plannerElement("saved.itinerary.tags").activateForPlannerJourney()
    let selectedTagIdentifier = deletedTagIdentifier.replacingOccurrences(
      of: "saved.tag.", with: "saved.item.label.tag.")
    let selectedTag = application.descendants(matching: .any).matching(
      identifier: selectedTagIdentifier
    ).firstMatch
    XCTAssertTrue(selectedTag.waitForExistence(timeout: 5))
    XCTAssertTrue(selectedTag.waitForPlannerBooleanState(false))
    #if os(macOS)
      selectedTag.click()
    #else
      selectedTag.switches.firstMatch.tap()
    #endif
    XCTAssertTrue(selectedTag.waitForPlannerBooleanState(true))
    application.plannerElement("saved.item.labels.done").activateForPlannerJourney()
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.exists)
    openItineraries(application)
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Rain route")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    let itineraryIdentifier = itinerary.identifier
    itinerary.activateForPlannerJourney()
    openLabels(application)
    application.plannerElement(deletedTagIdentifier).activateForPlannerJourney()
    application.plannerElement("saved.tag.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 Itinerary"].waitForExistence(timeout: 10))
    recordLabelsScreenshot(application, name: "Tag Delete reviews an Itinerary-only association")
    application.plannerElement("saved.tag.delete.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.tag.name"].waitForPlannerValue("Rain"))
    application.plannerElement("saved.tag.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(deletedTagIdentifier).waitForExistence(timeout: 5))
    XCTAssertTrue(application.plannerElement(survivingTagIdentifier).exists)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItineraries(application)
    application.plannerElement(itineraryIdentifier).activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Keep the rainy route notes"].exists)
    openLabels(application)
    application.plannerElement(deletedTagIdentifier).activateForPlannerJourney()
    application.plannerElement("saved.tag.delete").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["1 Itinerary"].waitForExistence(timeout: 10))
    application.plannerElement("saved.tag.delete.confirm").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(deletedTagIdentifier).waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.plannerElement(survivingTagIdentifier).exists)
    XCTAssertEqual(application.plannerElement(survivingTagIdentifier).label, "Rain")
    recordLabelsScreenshot(application, name: "Tag deletion retains the distinct same-name Tag")
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertTrue(application.plannerElement(itineraryIdentifier).waitForExistence(timeout: 10))
    application.plannerElement(itineraryIdentifier).activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Keep the rainy route notes"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Culture"].firstMatch.exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    XCTAssertFalse(application.staticTexts["Rain"].exists)
    recordLabelsScreenshot(
      application, name: "Tag deletion preserves Itinerary notes and other labels")
    openLabels(application)
    XCTAssertFalse(application.plannerElement(deletedTagIdentifier).exists)
    XCTAssertTrue(application.plannerElement(survivingTagIdentifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(survivingTagIdentifier).label, "Rain")
  }

  func testRepeatedItineraryAppearancesKeepLiveLabelsAndIndependentCompletionAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    createLabel("Category", name: "Culture", application: application)
    for name in ["Indoor", "Rain", "Walking"] {
      createLabel("Tag", name: name, application: application)
    }
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    createLabeledItem(
      "Museum", categories: ["Culture"], tags: ["Indoor", "Rain", "Walking"],
      application: application)
    createListWithItems("Food stops", itemTitles: ["Museum"], application: application)
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for entry in ["Museum", "Museum", "Food stops"] {
      addItineraryEntry(entry, application: application)
    }
    let rows = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
    XCTAssertEqual(rows.count, 3)
    let appearanceIdentifiers = rows.allElementsBoundByIndex.map(\.identifier)
    XCTAssertEqual(Set(appearanceIdentifiers).count, 3)
    for row in rows.allElementsBoundByIndex {
      XCTAssertTrue(row.waitForPlannerValue("Categories: Culture, Tags: Indoor, Rain, Walking"))
    }
    XCTAssertTrue(application.staticTexts["Culture · Indoor · Rain · +1"].exists)
    let completionIdentifiers = appearanceIdentifiers.map {
      $0.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")
    }
    application.plannerElement(completionIdentifiers[0]).activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement(completionIdentifiers[0]).waitForPlannerValue("Completed"))
    for identifier in completionIdentifiers.dropFirst() {
      XCTAssertTrue(application.plannerElement(identifier).waitForPlannerValue("To do"))
    }
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].waitForExistence(timeout: 10))
    recordLabelsScreenshot(
      application, name: "Live compact labels in three independent Itinerary appearances")
    application.plannerElement(appearanceIdentifiers[0]).activateForPlannerJourney()
    for name in ["Culture", "Indoor", "Rain", "Walking"] {
      XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    recordLabelsScreenshot(
      application, name: "Complete labels in a completed direct Itinerary appearance")
    openLabels(application)
    application.staticTexts["Culture"].firstMatch.activateForPlannerJourney()
    let categoryName = application.textFields["saved.category.name"]
    XCTAssertTrue(categoryName.waitForExistence(timeout: 5))
    replaceText(categoryName, with: "Art", application: application)
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Art"].firstMatch.waitForExistence(timeout: 10))
    application.staticTexts["Rain"].firstMatch.activateForPlannerJourney()
    let tagName = application.textFields["saved.tag.name"]
    XCTAssertTrue(tagName.waitForExistence(timeout: 5))
    replaceText(tagName, with: "Wet weather", application: application)
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Wet weather"].firstMatch.waitForExistence(timeout: 10))
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    let itinerary = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.",
        "Weekend route")
    ).firstMatch
    XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
    itinerary.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement(appearanceIdentifiers[0]).waitForExistence(timeout: 10))
    XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), appearanceIdentifiers)
    for row in rows.allElementsBoundByIndex {
      XCTAssertTrue(row.waitForPlannerValue("Categories: Art, Tags: Indoor, Walking, Wet weather"))
    }
    XCTAssertTrue(application.staticTexts["Art · Indoor · Walking · +1"].exists)
    XCTAssertTrue(
      application.plannerElement(completionIdentifiers[0]).waitForPlannerValue("Completed"))
    for identifier in completionIdentifiers.dropFirst() {
      XCTAssertTrue(application.plannerElement(identifier).waitForPlannerValue("To do"))
    }
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    application.plannerElement(appearanceIdentifiers[2]).activateForPlannerJourney()
    for name in ["Art", "Indoor", "Walking", "Wet weather"] {
      XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    XCTAssertFalse(application.staticTexts["Culture"].exists)
    XCTAssertFalse(application.staticTexts["Rain"].exists)
    recordLabelsScreenshot(
      application, name: "Renamed labels in an expanded List appearance after relaunch")
    openItems(application)
    let source = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    XCTAssertTrue(source.waitForPlannerValue("Categories: Art, Tags: Indoor, Walking, Wet weather"))
    source.activateForPlannerJourney()
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
  }

  private func addItineraryEntry(_ title: String, application: XCUIApplication) {
    let addition = application.plannerElement("saved.itinerary.entry.new")
    XCTAssertTrue(addition.waitForExistence(timeout: 10))
    addition.activateForPlannerJourney()
    let choice = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.entry.choice.", title)
    ).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 5))
    choice.activateForPlannerJourney()
    application.plannerElement("saved.itinerary.entry.add").activateForPlannerJourney()
    XCTAssertTrue(addition.waitForExistence(timeout: 10))
  }

  func testSettingsManageLabelsSharesSavedIdentityWithTheToolbarAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSettings(application)
    recordLabelsScreenshot(application, name: "Native Settings entry for Manage Labels")
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Manage Labels"].firstMatch.waitForExistence(timeout: 5))
    newTag(application)
    let name = application.textFields["saved.tag.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled Tag")
    application.plannerElement("saved.tag.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled Tag"].exists)
    createLabel("Tag", name: "Rain", application: application)
    let tag = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Rain")
    ).firstMatch
    XCTAssertTrue(tag.waitForExistence(timeout: 10))
    let sourceIdentifier = tag.identifier
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("saved.settings.labels").waitForExistence(timeout: 5))
    closeSettings(application)
    openLabels(application)
    XCTAssertEqual(tag.identifier, sourceIdentifier)
    tag.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Wet weather", application: application)
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(sourceIdentifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(sourceIdentifier).label, "Wet weather")
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(sourceIdentifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(sourceIdentifier).label, "Wet weather")
    recordLabelsScreenshot(application, name: "Settings and toolbar use the same saved Tag")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(sourceIdentifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(sourceIdentifier).label, "Wet weather")
    XCTAssertFalse(application.staticTexts["Canceled Tag"].exists)
    recordLabelsScreenshot(application, name: "Manage Labels through Settings after relaunch")
  }

  private func openSettings(_ application: XCUIApplication) {
    #if os(macOS)
      application.typeKey(",", modifierFlags: .command)
    #else
      let settings = application.plannerElement("saved.settings.open")
      if !settings.waitForExistence(timeout: 2) {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists { sidebar.activateForPlannerJourney() }
      }
      XCTAssertTrue(settings.waitForExistence(timeout: 10))
      settings.activateForPlannerJourney()
    #endif
    XCTAssertTrue(application.plannerElement("saved.settings.labels").waitForExistence(timeout: 10))
  }

  private func closeSettings(_ application: XCUIApplication) {
    #if os(macOS)
      application.typeKey("w", modifierFlags: .command)
    #else
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
    #endif
  }

  func testItineraryLabelSelectionStagesChangesAndPreservesLiveNamesAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    createLabel("Category", name: "Culture", application: application)
    createLabel("Tag", name: "Rain", application: application)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItineraries(application)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Canceled route")
    selectLabels(
      "Categories", names: ["Culture"], identifierPrefix: "saved.itinerary",
      application: application)
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled route"].exists)
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Weekend route")
    selectLabels(
      "Categories", names: ["Culture"], identifierPrefix: "saved.itinerary",
      application: application)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Culture"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["No items"].exists)
    openItineraries(application)
    let row = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.",
        "Weekend route")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    let sourceIdentifier = row.identifier
    row.activateForPlannerJourney()
    openItineraryEditor(application)
    let save = application.plannerElement("saved.itinerary.save")
    XCTAssertFalse(save.isEnabled)
    selectLabels(
      "Tags", names: ["Rain"], identifierPrefix: "saved.itinerary", application: application)
    XCTAssertTrue(save.isEnabled)
    application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Culture"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Rain"].exists)
    openItineraryEditor(application)
    selectLabels(
      "Tags", names: ["Rain"], identifierPrefix: "saved.itinerary", application: application)
    recordLabelsScreenshot(application, name: "Staged Itinerary Category and Tag selections")
    save.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Rain"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Culture"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordLabelsScreenshot(application, name: "Complete Itinerary labels after guarded save")
    openLabels(application)
    application.staticTexts["Culture"].firstMatch.activateForPlannerJourney()
    let categoryName = application.textFields["saved.category.name"]
    XCTAssertTrue(categoryName.waitForExistence(timeout: 5))
    replaceText(categoryName, with: "Art", application: application)
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Art"].firstMatch.waitForExistence(timeout: 10))
    application.staticTexts["Rain"].firstMatch.activateForPlannerJourney()
    let tagName = application.textFields["saved.tag.name"]
    XCTAssertTrue(tagName.waitForExistence(timeout: 5))
    replaceText(tagName, with: "Wet weather", application: application)
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Wet weather"].firstMatch.waitForExistence(timeout: 10))
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItineraries(application)
    XCTAssertEqual(row.identifier, sourceIdentifier)
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Art"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Wet weather"].exists)
    XCTAssertFalse(application.staticTexts["Culture"].exists)
    XCTAssertFalse(application.staticTexts["Rain"].exists)
    application.terminate()
    application.launchSavedPlannerJourney()
    openItineraries(application)
    XCTAssertEqual(row.identifier, sourceIdentifier)
    row.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Art"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Wet weather"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
    recordLabelsScreenshot(application, name: "Live Itinerary labels after rename and relaunch")
    openItineraryEditor(application)
    selectLabels(
      "Tags", names: ["Wet weather"], identifierPrefix: "saved.itinerary", selected: false,
      application: application)
    save.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Wet weather"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Art"].exists)
    XCTAssertTrue(application.staticTexts["No items"].exists)
  }

  private func openItineraries(_ application: XCUIApplication) {
    #if os(macOS)
      let section = application.plannerElement("saved.section.itineraries")
    #else
      let section = application.buttons["Itineraries"].firstMatch
    #endif
    XCTAssertTrue(section.waitForExistence(timeout: 10))
    section.activateForPlannerJourney()
    let creation = application.plannerElement("saved.itinerary.new")
    if !creation.waitForExistence(timeout: 2) {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists {
        sidebar.activateForPlannerJourney()
      } else {
        let back = application.plannerElement("BackButton")
        XCTAssertTrue(back.exists)
        back.activateForPlannerJourney()
      }
    }
    XCTAssertTrue(creation.waitForExistence(timeout: 10))
  }

  private func openItineraryEditor(_ application: XCUIApplication) {
    let editor = application.plannerElement("saved.itinerary.edit")
    XCTAssertTrue(editor.waitForExistence(timeout: 10))
    editor.activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.itinerary.title"].waitForExistence(timeout: 5))
  }

  func testManageLabelsStagesTagCreationAndRenameAndRetainsIdentityAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    XCTAssertTrue(application.staticTexts["Manage Labels"].firstMatch.waitForExistence(timeout: 5))
    newTag(application)
    let name = application.textFields["saved.tag.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Canceled Tag")
    application.plannerElement("saved.tag.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Canceled Tag"].exists)
    newTag(application)
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Rain")
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    let rain = application.staticTexts["Rain"].firstMatch
    XCTAssertTrue(rain.waitForExistence(timeout: 10))
    let tag = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.tag.")
    ).matching(NSPredicate(format: "label == %@", "Rain")).firstMatch
    let identifier = tag.identifier
    XCTAssertFalse(identifier.isEmpty)
    rain.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Canceled rename", application: application)
    application.plannerElement("saved.tag.cancel").activateForPlannerJourney()
    XCTAssertTrue(rain.waitForExistence(timeout: 5))
    rain.activateForPlannerJourney()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    replaceText(name, with: "Wet weather", application: application)
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(identifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(identifier).label, "Wet weather")
    XCTAssertFalse(rain.exists)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openLabels(application)
    XCTAssertTrue(application.plannerElement(identifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(identifier).label, "Wet weather")
    XCTAssertFalse(application.staticTexts["Canceled Tag"].exists)
    XCTAssertFalse(application.staticTexts["Canceled rename"].exists)
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = "Manage Labels with saved Tag after relaunch"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testItemLabelSelectionStagesCancelAndShowsCompactLiveNamesAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    createLabel("Category", name: "Culture", application: application)
    for name in ["Indoor", "Rain", "Walking"] {
      createLabel("Tag", name: name, application: application)
    }
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItems(application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum")
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    openItemEditor(application)
    selectLabels("Categories", names: ["Culture"], application: application)
    application.plannerElement("saved.item.edit.cancel").activateForPlannerJourney()
    XCTAssertFalse(application.staticTexts["Culture"].exists)
    openItemEditor(application)
    selectLabels("Categories", names: ["Culture"], application: application)
    selectLabels("Tags", names: ["Indoor", "Rain", "Walking"], application: application)
    application.plannerElement("saved.item.edit.save").activateForPlannerJourney()
    for name in ["Culture", "Indoor", "Rain", "Walking"] {
      XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    openItems(application)
    let row = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertTrue(row.waitForPlannerValue("Categories: Culture, Tags: Indoor, Rain, Walking"))
    XCTAssertTrue(application.staticTexts["Culture · Indoor · Rain · +1"].exists)
    recordLabelsScreenshot(application, name: "Compact Item label preview with overflow")
    application.terminate()
    application.launchSavedPlannerJourney()
    openItems(application)
    let reopened = application.savedPlannerItemRows("Museum").firstMatch
    XCTAssertTrue(reopened.waitForExistence(timeout: 10))
    XCTAssertTrue(reopened.waitForPlannerValue("Categories: Culture, Tags: Indoor, Rain, Walking"))
    let sourceIdentifier = reopened.identifier
    reopened.activateForPlannerJourney()
    for name in ["Culture", "Indoor", "Rain", "Walking"] {
      XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    recordLabelsScreenshot(application, name: "Complete Item labels after relaunch")
    openLabels(application)
    application.staticTexts["Culture"].firstMatch.activateForPlannerJourney()
    let categoryName = application.textFields["saved.category.name"]
    XCTAssertTrue(categoryName.waitForExistence(timeout: 5))
    replaceText(categoryName, with: "Art", application: application)
    application.plannerElement("saved.category.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Art"].firstMatch.waitForExistence(timeout: 10))
    application.staticTexts["Rain"].firstMatch.activateForPlannerJourney()
    let tagName = application.textFields["saved.tag.name"]
    XCTAssertTrue(tagName.waitForExistence(timeout: 5))
    replaceText(tagName, with: "Wet weather", application: application)
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Wet weather"].firstMatch.waitForExistence(timeout: 10))
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItems(application)
    XCTAssertEqual(reopened.identifier, sourceIdentifier)
    XCTAssertTrue(
      reopened.waitForPlannerValue("Categories: Art, Tags: Indoor, Walking, Wet weather"))
    XCTAssertTrue(application.staticTexts["Art · Indoor · Walking · +1"].exists)
    XCTAssertFalse(application.staticTexts["Culture · Indoor · Rain · +1"].exists)
    recordLabelsScreenshot(application, name: "Shared rename refreshes compact Item labels")
    reopened.activateForPlannerJourney()
    for name in ["Art", "Indoor", "Walking", "Wet weather"] {
      XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    XCTAssertFalse(application.staticTexts["Culture"].exists)
    XCTAssertFalse(application.staticTexts["Rain"].exists)
    recordLabelsScreenshot(application, name: "Shared rename refreshes complete Item labels")
  }

  func testCumulativeLabelFiltersNarrowListRowsAndClearWithoutChangingFullProgress() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openLabels(application)
    createLabel("Category", name: "Culture", application: application)
    createLabel("Tag", name: "Rain", application: application)
    createLabel("Tag", name: "Indoor", application: application)
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    openItems(application)
    application.plannerElement("saved.items.filters").activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.filters.categories").waitForExistence(timeout: 5))
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    createLabeledItem(
      "Dry museum", categories: ["Culture"], tags: ["Indoor"], application: application)
    createLabeledItem(
      "Rain museum", categories: ["Culture"], tags: ["Rain", "Indoor"], application: application)
    createLabeledItem("Cafe", categories: [], tags: ["Rain"], application: application)
    openItems(application)
    let catalogFilters = application.plannerElement("saved.items.filters")
    catalogFilters.activateForPlannerJourney()
    selectLabels(
      "Categories", names: ["Culture"], identifierPrefix: "saved.filters", application: application)
    selectLabels(
      "Tags", names: ["Rain"], identifierPrefix: "saved.filters", application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Cafe").firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Dry museum").firstMatch.exists)
    XCTAssertTrue(application.savedPlannerItemRows("Rain museum").firstMatch.exists)
    XCTAssertEqual(catalogFilters.label, "Active · 1 Category · 1 Tag")
    recordLabelsScreenshot(application, name: "Cumulative label filters narrow the Item catalog")
    catalogFilters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(application.savedPlannerItemRows("Cafe").firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerItemRows("Dry museum").firstMatch.exists)
    XCTAssertEqual(catalogFilters.label, "All")
    createListWithItems(
      "Weekend", itemTitles: ["Dry museum", "Rain museum", "Cafe"], application: application)
    let rain = application.savedPlannerItemRows("Rain museum").firstMatch
    let completion = application.plannerElement(
      rain.identifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion."))
    completion.activateForPlannerJourney()
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertTrue(rain.waitForPlannerValue("Categories: Culture, Tags: Indoor, Rain"))
    rain.activateForPlannerJourney()
    for name in ["Culture", "Indoor", "Rain"] {
      XCTAssertTrue(application.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    recordLabelsScreenshot(
      application, name: "Complete shared labels in a completed List appearance")
    #if os(iOS)
      let back = application.plannerElement("BackButton")
      if back.exists { back.activateForPlannerJourney() }
    #endif
    let filters = application.plannerElement("saved.list.filters")
    XCTAssertEqual(filters.label, "All")
    filters.activateForPlannerJourney()
    selectLabels(
      "Categories", names: ["Culture"], identifierPrefix: "saved.filters", application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Dry museum").firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(rain.exists)
    XCTAssertFalse(application.savedPlannerItemRows("Cafe").firstMatch.exists)
    XCTAssertEqual(filters.label, "1 Category")
    XCTAssertTrue(application.staticTexts["Showing 2 of 3 items"].exists)
    filters.activateForPlannerJourney()
    selectLabels(
      "Tags", names: ["Rain"], identifierPrefix: "saved.filters", application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(rain.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Dry museum").firstMatch.exists)
    XCTAssertFalse(application.savedPlannerItemRows("Cafe").firstMatch.exists)
    XCTAssertEqual(filters.label, "1 Category · 1 Tag")
    XCTAssertTrue(application.staticTexts["Showing 1 of 3 items"].exists)
    let progress = application.progressIndicators["saved.list.progress"]
    XCTAssertEqual(progress.plannerProgressFraction ?? -1, 0.333, accuracy: 0.02)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    recordLabelsScreenshot(application, name: "Cumulative label filters retain full List progress")
    filters.activateForPlannerJourney()
    application.plannerElement("Clear Categories").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(application.savedPlannerItemRows("Cafe").firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Dry museum").firstMatch.exists)
    XCTAssertTrue(rain.exists)
    XCTAssertEqual(filters.label, "1 Tag")
    filters.activateForPlannerJourney()
    selectLabels(
      "Tags", names: ["Indoor"], identifierPrefix: "saved.filters", application: application)
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Dry museum").firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerItemRows("Cafe").firstMatch.exists)
    XCTAssertTrue(rain.exists)
    XCTAssertEqual(filters.label, "2 Tags")
    filters.activateForPlannerJourney()
    let matchPicker = application.plannerElement("saved.filters.tag.match")
    application.revealSavedPlannerFilter("saved.filters.tag.match")
    matchPicker.activateForPlannerJourney()
    application.plannerElement("All selected").activateForPlannerJourney()
    recordLabelsScreenshot(application, name: "Native adaptive Filters with All selected Tags")
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertTrue(
      application.savedPlannerItemRows("Cafe").firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertFalse(application.savedPlannerItemRows("Dry museum").firstMatch.exists)
    XCTAssertTrue(rain.exists)
    XCTAssertEqual(filters.label, "All 2 Tags")
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertEqual(progress.plannerProgressFraction ?? -1, 0.333, accuracy: 0.02)
    filters.activateForPlannerJourney()
    application.plannerElement("saved.filters.clear").activateForPlannerJourney()
    application.plannerElement("saved.filters.done").activateForPlannerJourney()
    XCTAssertEqual(filters.label, "All")
    XCTAssertTrue(application.savedPlannerItemRows("Cafe").firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(application.savedPlannerItemRows("Dry museum").firstMatch.exists)
    XCTAssertTrue(rain.exists)
    XCTAssertTrue(completion.waitForPlannerValue("Completed"))
    XCTAssertEqual(progress.plannerProgressFraction ?? -1, 0.333, accuracy: 0.02)
    XCTAssertFalse(application.staticTexts["Showing 1 of 3 items"].exists)
    recordLabelsScreenshot(
      application, name: "Clear restores all List rows and preserves completion")
  }

  private func createLabeledItem(
    _ name: String, categories: [String], tags: [String], application: XCUIApplication
  ) {
    openItems(application)
    application.plannerElement("saved.item.new").activateForPlannerJourney()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText(name)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
    openItemEditor(application)
    if !categories.isEmpty {
      selectLabels("Categories", names: categories, application: application)
    }
    if !tags.isEmpty { selectLabels("Tags", names: tags, application: application) }
    let save = application.plannerElement("saved.item.edit.save")
    save.activateForPlannerJourney()
    XCTAssertTrue(save.waitForNonExistence(timeout: 10))
  }

  private func createListWithItems(
    _ name: String, itemTitles: [String], application: XCUIApplication
  ) {
    #if os(macOS)
      let lists = application.plannerElement("saved.section.lists")
    #else
      let lists = application.buttons["Lists"].firstMatch
    #endif
    lists.activateForPlannerJourney()
    let create = application.plannerElement("saved.list.new")
    if !create.waitForExistence(timeout: 3) {
      let sidebar = application.plannerElement("Show Sidebar")
      if sidebar.exists { sidebar.activateForPlannerJourney() }
    }
    XCTAssertTrue(create.waitForExistence(timeout: 10))
    create.activateForPlannerJourney()
    let title = application.textFields["saved.list.name"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText(name)
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    for itemTitle in itemTitles {
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
      let candidate = application.staticTexts[itemTitle].firstMatch
      XCTAssertTrue(candidate.waitForExistence(timeout: 5))
      candidate.activateForPlannerJourney()
      application.plannerElement("saved.membership.add").activateForPlannerJourney()
      XCTAssertTrue(
        application.savedPlannerItemRows(itemTitle).firstMatch.waitForExistence(timeout: 10))
    }
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

  private func openItems(_ application: XCUIApplication) {
    #if os(macOS)
      let items = application.plannerElement("saved.section.items")
    #else
      let items = application.buttons["Items"].firstMatch
    #endif
    XCTAssertTrue(items.waitForExistence(timeout: 10))
    items.activateForPlannerJourney()
    let back = application.navigationBars.buttons["Items"].firstMatch
    if back.exists { back.activateForPlannerJourney() }
    XCTAssertTrue(application.plannerElement("saved.item.new").waitForExistence(timeout: 10))
  }

  private func openItemEditor(_ application: XCUIApplication) {
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Edit Item").activateForPlannerJourney()
    XCTAssertTrue(application.textFields["saved.item.edit.title"].waitForExistence(timeout: 5))
  }

  private func selectLabels(
    _ kind: String, names: [String], identifierPrefix: String = "saved.item.edit",
    selected: Bool = true,
    application: XCUIApplication
  ) {
    let picker = application.plannerElement("\(identifierPrefix).\(kind.lowercased())")
    if identifierPrefix == "saved.filters" {
      application.revealSavedPlannerFilter("\(identifierPrefix).\(kind.lowercased())")
    }
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.activateForPlannerJourney()
    for name in names {
      let toggle = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.label.", name)
      ).firstMatch
      XCTAssertTrue(toggle.waitForExistence(timeout: 5))
      XCTAssertEqual(toggle.plannerBooleanState, !selected)
      #if os(macOS)
        toggle.click()
      #else
        let control = toggle.switches.firstMatch
        XCTAssertTrue(control.exists)
        control.tap()
      #endif
      XCTAssertTrue(toggle.waitForPlannerBooleanState(selected))
    }
    application.plannerElement("saved.item.labels.done").activateForPlannerJourney()
  }

  private func recordLabelsScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func openLabels(_ application: XCUIApplication) {
    let labels = application.plannerElement("saved.categories.manage")
    if !labels.waitForExistence(timeout: 3) || !labels.isHittable {
      #if os(macOS)
        let lists = application.plannerElement("saved.section.lists")
      #else
        let lists = application.buttons["Lists"].firstMatch
      #endif
      XCTAssertTrue(lists.waitForExistence(timeout: 5))
      lists.activateForPlannerJourney()
      if !labels.waitForExistence(timeout: 2) || !labels.isHittable {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists {
          sidebar.activateForPlannerJourney()
        } else {
          let back = application.plannerElement("BackButton")
          XCTAssertTrue(back.exists, application.debugDescription)
          back.activateForPlannerJourney()
        }
      }
    }
    XCTAssertTrue(labels.waitForExistence(timeout: 10))
    labels.activateForPlannerJourney()
  }

  private func newTag(_ application: XCUIApplication) {
    application.plannerElement("saved.labels.new").activateForPlannerJourney()
    let tag = application.plannerElement("New Tag")
    XCTAssertTrue(tag.waitForExistence(timeout: 5))
    tag.activateForPlannerJourney()
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
}
