import XCTest

@MainActor
final class SavedRecoveryJourneyTests: XCTestCase {
  func testInspectingSavedRecoveryCopyPreservesCurrentTagAfterRelaunch() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    openSettings(application)
    let tagIdentifier = createRecoveryTag(application)
    let recovery = application.plannerElement("saved.settings.recovery")
    XCTAssertTrue(recovery.waitForExistence(timeout: 10))
    recovery.activateForPlannerJourney()
    let snapshot = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.recovery.snapshot.")
    ).firstMatch
    XCTAssertTrue(snapshot.waitForExistence(timeout: 15))
    snapshot.activateForPlannerJourney()
    let evidence = application.staticTexts["saved.recovery.evidence"]
    XCTAssertTrue(evidence.waitForExistence(timeout: 15))
    XCTAssertTrue(evidence.label.contains("Saved snapshot"))
    let sourceIdentifier = String(tagIdentifier.dropFirst("saved.tag.".count))
    let retainedSource = application.staticTexts["saved.recovery.source.tag.\(sourceIdentifier)"]
    XCTAssertTrue(retainedSource.waitForExistence(timeout: 10))
    XCTAssertTrue(retainedSource.label.contains("Recovery travel tag"))
    recordRecovery(name: "Native recovery inspection retains the saved Tag and evidence")
    application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
    application.plannerElement("saved.recovery.done").activateForPlannerJourney()
    application.terminate()
    application.launchSavedPlannerJourney()
    openSettings(application)
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
    XCTAssertEqual(application.plannerElement(tagIdentifier).label, "Recovery travel tag")
    recordRecovery(name: "Recovery inspection leaves the current Tag intact after relaunch")
  }

  #if os(iOS)
    func testExportingSavedRecoveryCopyRetainsTagAfterFileDeliveryAndRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      openSettings(application)
      let tagIdentifier = createRecoveryTag(application)
      application.plannerElement("saved.settings.recovery").activateForPlannerJourney()
      let snapshot = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.recovery.snapshot.")
      ).firstMatch
      XCTAssertTrue(snapshot.waitForExistence(timeout: 15))
      snapshot.activateForPlannerJourney()
      let export = application.plannerElement("saved.recovery.export")
      XCTAssertTrue(export.waitForExistence(timeout: 10))
      export.activateForPlannerJourney()
      let save = application.buttons.matching(NSPredicate(format: "label == %@", "Save"))
        .firstMatch
      XCTAssertTrue(save.waitForExistence(timeout: 10))
      let localLocation = application.cells.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "DOC.sidebar.item.On My ")
      ).firstMatch
      if localLocation.exists && localLocation.isHittable {
        localLocation.activateForPlannerJourney()
      }
      recordRecovery(name: "System picker saves the selected recovery copy")
      save.activateForPlannerJourney()
      let replace = application.buttons.matching(NSPredicate(format: "label == %@", "Replace"))
        .firstMatch
      if replace.waitForExistence(timeout: 2) { replace.activateForPlannerJourney() }
      let exported = application.staticTexts["saved.recovery.exported"]
      XCTAssertTrue(exported.waitForExistence(timeout: 10))
      XCTAssertTrue(exported.label.hasPrefix("Recovery copy exported, Planner Saved Recovery "))
      XCTAssertTrue(exported.label.hasSuffix(".json"))
      let filename = String(exported.label.dropFirst("Recovery copy exported, ".count))
      let expectation = XCTAttachment(
        string: "Filename: \(filename)\nTag: \(tagIdentifier)\nTitle: Recovery travel tag")
      expectation.name = "Public recovery export expectation"
      expectation.lifetime = .keepAlways
      add(expectation)
      recordRecovery(name: "Native recovery copy confirms successful file delivery")
      application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      application.plannerElement("saved.recovery.done").activateForPlannerJourney()
      application.terminate()
      application.launchSavedPlannerJourney()
      openSettings(application)
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      XCTAssertTrue(application.plannerElement(tagIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.plannerElement(tagIdentifier).label, "Recovery travel tag")
    }
  #endif

  private func createRecoveryTag(_ application: XCUIApplication) -> String {
    application.plannerElement("saved.settings.labels").activateForPlannerJourney()
    application.plannerElement("saved.labels.new").activateForPlannerJourney()
    application.plannerElement("New tag").activateForPlannerJourney()
    let name = application.textFields["saved.tag.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.activateForPlannerJourney()
    name.typeText("Recovery travel tag")
    application.plannerElement("saved.tag.save").activateForPlannerJourney()
    let tag = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.tag.", "Recovery travel tag")
    ).firstMatch
    XCTAssertTrue(tag.waitForExistence(timeout: 10))
    let identifier = tag.identifier
    application.plannerElement("saved.categories.done").activateForPlannerJourney()
    return identifier
  }

  private func openSettings(_ application: XCUIApplication) {
    #if os(macOS)
      application.typeKey(",", modifierFlags: .command)
    #else
      application.openSavedPlannerSettings()
    #endif
    XCTAssertTrue(application.plannerElement("saved.settings.labels").waitForExistence(timeout: 10))
  }

  private func recordRecovery(name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
