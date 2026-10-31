import XCTest

@MainActor
final class DeletionRecoveryJourneyTests: XCTestCase {
  func testAppliedDeletionKeepsATruthfulOneShotDialogAndRepairsRecoveryWithoutReapplying() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "deletion-recovery", "--fixture-dataset", UUID().uuidString,
    ]
    launch(application)
    application.openPlannerSection("Items")
    let removed = application.savedPlannerItemRows("Delete museum").firstMatch
    let retained = application.savedPlannerItemRows("Keep hotel").firstMatch
    XCTAssertTrue(removed.waitForExistence(timeout: 20))
    XCTAssertTrue(retained.exists)
    let removedIdentifier = removed.identifier
    let retainedIdentifier = retained.identifier
    removed.activateForPlannerJourney()
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
    application.plannerElement("saved.item.delete").activateForPlannerJourney()
    let confirm = application.plannerElement("saved.item.delete.confirm")
    let close = application.plannerElement("saved.item.delete.cancel")
    XCTAssertTrue(confirm.waitForExistence(timeout: 10))
    XCTAssertTrue(confirm.isEnabled)
    XCTAssertEqual(close.label, "Cancel")
    confirm.activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Close"), object: close)
        ], timeout: 15), .completed)
    XCTAssertTrue(confirm.exists)
    XCTAssertFalse(confirm.isEnabled)
    XCTAssertTrue(close.isEnabled)
    let message =
      "Your change is in local storage, but its recovery copy is incomplete. Further changes are paused."
    XCTAssertTrue(application.staticTexts[message].waitForExistence(timeout: 10))
    capture(
      application, name: "Applied deletion retains an honest recovery failure and Close action")
    close.activateForPlannerJourney()
    XCTAssertTrue(confirm.waitForNonExistence(timeout: 10))
    let alert = application.alerts["Plan 2Do"]
    if alert.waitForExistence(timeout: 3) {
      XCTAssertTrue(alert.staticTexts[message].exists)
      alert.buttons["OK"].activateForPlannerJourney()
    }
    application.openPlannerSection("Items")
    XCTAssertTrue(removed.waitForNonExistence(timeout: 10))
    XCTAssertTrue(retained.waitForExistence(timeout: 10))
    XCTAssertEqual(application.savedPlannerItemRows("Keep hotel").count, 1)
    XCTAssertEqual(retained.identifier, retainedIdentifier)
    let recovery = application.plannerElement("saved.recovery.status.open")
    XCTAssertTrue(recovery.waitForExistence(timeout: 10))
    XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
    application.terminate()
    launch(application)
    application.openPlannerSection("Items")
    XCTAssertTrue(retained.waitForExistence(timeout: 20))
    XCTAssertEqual(retained.identifier, retainedIdentifier)
    XCTAssertFalse(application.plannerElement(removedIdentifier).exists)
    XCTAssertFalse(removed.exists)
    XCTAssertEqual(application.savedPlannerItemRows("Keep hotel").count, 1)
    XCTAssertFalse(application.plannerElement("saved.item.addMenu").isEnabled)
    recovery.activateForPlannerJourney()
    let status = application.staticTexts["saved.recovery.status"]
    XCTAssertTrue(status.waitForExistence(timeout: 10))
    XCTAssertEqual(status.label, "Recovery copy incomplete")
    let retry = application.plannerElement("saved.recovery.retry")
    XCTAssertTrue(retry.isEnabled)
    capture(
      application, name: "Relaunch preserves applied deletion and offers checkpoint-only repair")
    retry.activateForPlannerJourney()
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Saved on this device"), object: status)
        ], timeout: 15), .completed)
    XCTAssertFalse(retry.exists)
    application.plannerElement("saved.settings.done").activateForPlannerJourney()
    XCTAssertFalse(recovery.exists)
    XCTAssertTrue(application.plannerElement("saved.item.addMenu").isEnabled)
    XCTAssertFalse(application.plannerElement(removedIdentifier).exists)
    XCTAssertEqual(retained.identifier, retainedIdentifier)
    retained.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Retained hotel notes"].waitForExistence(timeout: 10))
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
    #if os(iOS)
      let nativeSwitch = completion.switches.firstMatch
      XCTAssertTrue(nativeSwitch.waitForExistence(timeout: 5))
      XCTAssertTrue(nativeSwitch.isHittable)
      nativeSwitch.activateForPlannerJourney()
    #else
      completion.activateForPlannerJourney()
    #endif
    let completed = completion.waitForPlannerBooleanState(true)
    if !completed {
      capture(application, name: "Later completion failure in the actual Planner view")
    }
    XCTAssertTrue(completed, application.debugDescription)
    application.terminate()
    launch(application)
    application.openPlannerSection("Items")
    XCTAssertTrue(retained.waitForExistence(timeout: 20))
    XCTAssertEqual(retained.identifier, retainedIdentifier)
    XCTAssertFalse(application.plannerElement(removedIdentifier).exists)
    XCTAssertFalse(removed.exists)
    XCTAssertEqual(application.savedPlannerItemRows("Keep hotel").count, 1)
    XCTAssertFalse(recovery.exists)
    retained.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Retained hotel notes"].waitForExistence(timeout: 10))
    XCTAssertTrue(completion.waitForPlannerBooleanState(true))
    capture(application, name: "Checkpoint repair preserves deletion and a later independent edit")
  }

  private func launch(_ application: XCUIApplication) {
    application.launchSavedPlannerJourney()
    #if os(iOS)
      let tab = application.buttons.matching(identifier: "square.stack").firstMatch
      XCTAssertTrue(tab.waitForExistence(timeout: 20))
      XCTAssertTrue(tab.waitForPlannerHittability())
    #else
      XCTAssertTrue(application.plannerElement("saved.list.new").waitForExistence(timeout: 20))
    #endif
  }

  private func capture(_ application: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: application.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
