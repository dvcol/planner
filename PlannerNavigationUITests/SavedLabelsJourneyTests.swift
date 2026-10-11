import XCTest

@MainActor
final class SavedLabelsJourneyTests: XCTestCase {
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
    if !labels.waitForExistence(timeout: 3) {
      #if os(macOS)
        let lists = application.plannerElement("saved.section.lists")
      #else
        let lists = application.buttons["Lists"].firstMatch
      #endif
      XCTAssertTrue(lists.waitForExistence(timeout: 5))
      lists.activateForPlannerJourney()
      if !labels.waitForExistence(timeout: 2) {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists { sidebar.activateForPlannerJourney() }
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
