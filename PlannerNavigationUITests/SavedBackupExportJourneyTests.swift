import XCTest

@MainActor
final class SavedBackupExportJourneyTests: XCTestCase {
  #if os(iOS)
    func testSavingBackupExportsSavedLabelAndPreservesItAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      application.plannerElement("saved.labels.new").activateForPlannerJourney()
      application.plannerElement("New tag").activateForPlannerJourney()
      let name = application.textFields["saved.tag.name"]
      XCTAssertTrue(name.waitForExistence(timeout: 5))
      name.activateForPlannerJourney()
      name.typeText("Exported travel tag")
      application.plannerElement("saved.tag.save").activateForPlannerJourney()
      let tag = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Exported travel tag")
      ).firstMatch
      XCTAssertTrue(tag.waitForExistence(timeout: 10))
      let identity = tag.identifier
      application.plannerElement("saved.categories.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.export").activateForPlannerJourney()
      let save = application.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch
      XCTAssertTrue(save.waitForExistence(timeout: 10))
      recordScreenshot(application, name: "System picker saves a Planner JSON backup")
      save.activateForPlannerJourney()
      let replace = application.buttons.matching(NSPredicate(format: "label == %@", "Replace"))
        .firstMatch
      if replace.waitForExistence(timeout: 3) { replace.activateForPlannerJourney() }
      XCTAssertTrue(application.staticTexts["Backup exported"].waitForExistence(timeout: 10))
      let summary = application.staticTexts["saved.settings.exported"]
      XCTAssertTrue(summary.waitForExistence(timeout: 5))
      XCTAssertTrue(summary.label.hasPrefix("Backup exported, Planner Backup"))
      XCTAssertTrue(summary.label.hasSuffix(".json"))
      let filename = String(summary.label.dropFirst("Backup exported, ".count))
      XCTAssertFalse(application.alerts["Backup export failed"].exists)
      recordHierarchy(application, name: "Native Settings after file delivery")
      let expected = XCTAttachment(
        string: "Filename: \(filename)\nTag: \(identity)\nTitle: Exported travel tag")
      expected.name = "Public exported file expectation"
      expected.lifetime = .keepAlways
      add(expected)
      recordScreenshot(application, name: "Settings confirms successful native file delivery")
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(identity).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(identity).label, "Exported travel tag")
    }
  #endif

  func testCancellingBackupExportPreservesSavedLabelsAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    application.plannerElement("saved.labels.new").activateForPlannerJourney()
    application.plannerElement("New tag").activateForPlannerJourney()
    let name = application.textFields["saved.tag.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Keep after export cancellation")
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    let tag = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.",
        "Keep after export cancellation")
    ).firstMatch
    XCTAssertTrue(tag.waitForExistence(timeout: 10))
    let identity = tag.identifier
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    let export = application.plannerElement("saved.settings.export")
    XCTAssertTrue(export.waitForExistence(timeout: 10))
    export.activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement("Save").waitForExistence(timeout: 10))
    #if os(iOS)
      let browse = application.buttons["Browse"]
      if browse.exists { browse.activateForPlannerJourney() }
    #endif
    recordHierarchy(application, name: "Native backup export picker")
    #if os(macOS)
      let cancel = application.plannerElement("Cancel")
      XCTAssertTrue(cancel.waitForExistence(timeout: 10))
      cancel.activateForPlannerJourney()
    #else
      let cancel = application.buttons.matching(NSPredicate(format: "label == %@", "Cancel"))
        .firstMatch
      if cancel.exists {
        cancel.activateForPlannerJourney()
      } else {
        // iPhone's close control is absent from XCTest queries; dismiss its native sheet by dragging the header.
        let header = application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.095))
        let lowerEdge = application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        header.press(forDuration: 0.05, thenDragTo: lowerEdge)
      }
    #endif
    XCTAssertTrue(export.waitForPlannerHittability())
    XCTAssertTrue(export.isEnabled)
    XCTAssertFalse(application.alerts["Backup export failed"].exists)
    XCTAssertFalse(application.staticTexts["Backup exported"].exists)
    recordScreenshot(application, name: "Canceled export returns to native Settings")
    application.terminate()
    application.launchSavedPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(identity).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(identity).label, "Keep after export cancellation")
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

  private func recordHierarchy(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(string: application.debugDescription)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func recordScreenshot(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
