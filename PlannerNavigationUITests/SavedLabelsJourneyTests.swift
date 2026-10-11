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

  private func selectLabels(_ kind: String, names: [String], application: XCUIApplication) {
    let picker = application.plannerElement("saved.item.edit.\(kind.lowercased())")
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
