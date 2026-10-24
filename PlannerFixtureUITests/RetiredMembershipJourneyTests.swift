import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class RetiredMembershipJourneyTests: XCTestCase {
    func testFreshMembershipRetainsLocalCompletionAfterAnOldCopyReturnsOnRelaunch() {
      continueAfterFailure = false
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      let datasetIdentifier = UUID().uuidString
      application.launchArguments = [
        "--fixture", "retired-membership", "--fixture-dataset", datasetIdentifier,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let source = application.savedPlannerItemRows("Retired stop hotel").firstMatch
      XCTAssertTrue(source.waitForExistence(timeout: 15))
      let sourceIdentifier = source.identifier
      application.openPlannerSection("Lists")
      let list = application.savedPlannerListRow("Retired stop plan")
      XCTAssertTrue(list.waitForExistence(timeout: 10))
      let listIdentifier = list.identifier
      list.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      XCTAssertEqual(application.savedPlannerItemRows("Retired stop hotel").count, 0)
      capture("A retired native membership leaves its List empty")

      application.openSavedPlannerListAddMenu()
      application.plannerElement("saved.list.add").activateForPlannerJourney()
      let choice = application.staticTexts["Retired stop hotel"].firstMatch
      XCTAssertTrue(choice.waitForExistence(timeout: 10))
      choice.activateForPlannerJourney()
      let confirmAddition = application.plannerElement("saved.membership.add")
      XCTAssertTrue(confirmAddition.isEnabled)
      confirmAddition.activateForPlannerJourney()
      XCTAssertTrue(confirmAddition.waitForNonExistence(timeout: 10))
      let appearance = application.savedPlannerItemRows("Retired stop hotel").firstMatch
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      let appearanceIdentifier = appearance.identifier
      XCTAssertTrue(appearanceIdentifier.hasPrefix("saved.appearance."))
      XCTAssertFalse(appearanceIdentifier.contains("00000000-0000-4000-8000-000000000401"))
      XCTAssertFalse(appearanceIdentifier.contains("00000000-0000-4000-8000-000000000402"))
      XCTAssertEqual(application.savedPlannerItemRows("Retired stop hotel").count, 1)
      let completion = application.buttons[
        appearanceIdentifier.replacingOccurrences(
          of: "saved.appearance.", with: "saved.appearance.completion.")]
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))
      capture("An ordinary native re-add starts a fresh Todo appearance")
      completion.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      XCTAssertTrue(application.staticTexts["1 of 1 item done"].waitForExistence(timeout: 10))
      application.terminate()

      application.launchSavedPlannerJourney()
      application.openPlannerSection("Lists")
      XCTAssertTrue(application.plannerElement(listIdentifier).waitForExistence(timeout: 15))
      application.plannerElement(listIdentifier).activateForPlannerJourney()
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      XCTAssertEqual(appearance.identifier, appearanceIdentifier)
      XCTAssertEqual(application.savedPlannerItemRows("Retired stop hotel").count, 1)
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      XCTAssertTrue(application.staticTexts["1 of 1 item done"].waitForExistence(timeout: 10))
      capture("A later retired copy preserves the fresh membership's local completion")

      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(sourceIdentifier).waitForExistence(timeout: 10))
      XCTAssertEqual(application.savedPlannerItemRows("Retired stop hotel").count, 1)
      application.plannerElement(sourceIdentifier).activateForPlannerJourney()
      let globalCompletion = application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
      XCTAssertTrue(globalCompletion.waitForExistence(timeout: 10))
      XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
      XCTAssertTrue(
        application.staticTexts["Keep the original hotel note"].waitForExistence(timeout: 10))
      capture("The same shared Item keeps its note and global Todo state")
      let identities = XCTAttachment(
        string:
          "Dataset: \(datasetIdentifier)\nSource: \(sourceIdentifier)\nList: \(listIdentifier)\nAppearance: \(appearanceIdentifier)"
      )
      identities.name = "Retired native membership observed identities"
      identities.lifetime = .keepAlways
      add(identities)
      application.terminate()
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
