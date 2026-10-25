import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class RetiredMembershipJourneyTests: XCTestCase {
    func testFreshMembershipRetainsLocalCompletionAfterAnOldCopyReturnsOnRelaunch() {
      verifyFreshMembershipAfterRelaunch(fixture: "retired-membership")
    }

    func testFreshMembershipRetainsLocalCompletionWithoutTheOldCopysSeparateProvenance() {
      verifyFreshMembershipAfterRelaunch(fixture: "retired-membership-without-provenance")
    }

    func testRepeatedItineraryStopsKeepIndependentCompletionAfterAnOldMembershipReturns() {
      verifyRepeatedStopsAfterRelaunch(fixture: "retired-itinerary-membership")
    }

    func testRepeatedItineraryStopsKeepIndependentCompletionWithoutOldMembershipProvenance() {
      verifyRepeatedStopsAfterRelaunch(fixture: "retired-itinerary-membership-without-provenance")
    }

    private func verifyRepeatedStopsAfterRelaunch(fixture: String) {
      continueAfterFailure = false
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      let datasetIdentifier = UUID().uuidString
      application.launchArguments = ["--fixture", fixture, "--fixture-dataset", datasetIdentifier]
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
      capture("Repeated route starts with its retired List membership absent")

      application.openSavedPlannerListAddMenu()
      application.plannerElement("saved.list.add").activateForPlannerJourney()
      let choice = application.staticTexts["Retired stop hotel"].firstMatch
      XCTAssertTrue(choice.waitForExistence(timeout: 10))
      choice.activateForPlannerJourney()
      let confirmAddition = application.plannerElement("saved.membership.add")
      XCTAssertTrue(confirmAddition.isEnabled)
      confirmAddition.activateForPlannerJourney()
      XCTAssertTrue(confirmAddition.waitForNonExistence(timeout: 10))
      let membership = application.savedPlannerItemRows("Retired stop hotel").firstMatch
      XCTAssertTrue(membership.waitForExistence(timeout: 10))
      let membershipIdentifier = membership.identifier
      let membershipIdentity = membershipIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "")
      XCTAssertNotNil(UUID(uuidString: membershipIdentity))
      XCTAssertFalse(membershipIdentity.hasSuffix("000000000401"))
      XCTAssertFalse(membershipIdentity.hasSuffix("000000000402"))
      let standaloneCompletion = application.buttons[
        "saved.appearance.completion.\(membershipIdentity)"]
      XCTAssertTrue(standaloneCompletion.waitForPlannerValue("To do"))
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))

      application.openPlannerSection("Itineraries")
      let itineraryIdentifier = "saved.itinerary.row.00000000-0000-4000-8000-000000000301"
      let itinerary = application.buttons[itineraryIdentifier]
      XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
      itinerary.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["0 of 3 items done"].waitForExistence(timeout: 10))
      let firstStop = "00000000-0000-4000-8000-000000000451.\(membershipIdentity)"
      let secondStop = "00000000-0000-4000-8000-000000000452.\(membershipIdentity)"
      let directStop = "00000000-0000-4000-8000-000000000453"
      verifyItineraryStates(
        [firstStop: "To do", secondStop: "To do", directStop: "To do"], in: application)
      let secondCompletion = application.buttons["saved.itinerary.completion.\(secondStop)"]
      let contents = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.contents").firstMatch
      for _ in 0..<6 where !secondCompletion.isHittable { contents.swipeDown() }
      XCTAssertTrue(secondCompletion.isHittable)
      secondCompletion.activateForPlannerJourney()
      XCTAssertTrue(secondCompletion.waitForPlannerValue("Completed"))
      verifyItineraryStates(
        [firstStop: "To do", secondStop: "Completed", directStop: "To do"], in: application)
      capture("Only the second fresh List stop is completed in the repeated route")
      application.terminate()

      application.launchSavedPlannerJourney()
      application.openPlannerSection("Itineraries")
      XCTAssertTrue(itinerary.waitForExistence(timeout: 15))
      itinerary.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["1 of 3 items done"].waitForExistence(timeout: 10))
      verifyItineraryStates(
        [firstStop: "To do", secondStop: "Completed", directStop: "To do"], in: application)
      capture("Relaunch and retired-copy delivery preserve the exact completed second stop")

      application.openPlannerSection("Lists")
      XCTAssertTrue(application.plannerElement(listIdentifier).waitForExistence(timeout: 10))
      application.plannerElement(listIdentifier).activateForPlannerJourney()
      XCTAssertTrue(membership.waitForExistence(timeout: 10))
      XCTAssertEqual(membership.identifier, membershipIdentifier)
      XCTAssertEqual(application.savedPlannerItemRows("Retired stop hotel").count, 1)
      XCTAssertTrue(standaloneCompletion.waitForPlannerValue("To do"))
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))
      capture("The standalone List keeps the same fresh membership locally Todo")

      application.openPlannerSection("Items")
      XCTAssertTrue(application.plannerElement(sourceIdentifier).waitForExistence(timeout: 10))
      application.plannerElement(sourceIdentifier).activateForPlannerJourney()
      let globalCompletion = application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
      XCTAssertTrue(globalCompletion.waitForExistence(timeout: 10))
      XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
      XCTAssertTrue(
        application.staticTexts["Keep the original hotel note"].waitForExistence(timeout: 10))
      capture("Repeated-route completion preserves the original shared Item and global Todo")
      let identities = XCTAttachment(
        string:
          "Dataset: \(datasetIdentifier)\nSource: \(sourceIdentifier)\nList: \(listIdentifier)\nMembership: \(membershipIdentifier)\nItinerary: \(itineraryIdentifier)\nFirst stop: \(firstStop)\nSecond stop: \(secondStop)\nDirect stop: \(directStop)"
      )
      identities.name = "Repeated retired membership observed identities"
      identities.lifetime = .keepAlways
      add(identities)
      application.terminate()
    }

    private func verifyItineraryStates(
      _ expected: [String: String], in application: XCUIApplication
    ) {
      let contents = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.contents").firstMatch
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
      let appearances = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
      var observed: Set<String> = []
      for _ in 0..<8 {
        for appearance in appearances.allElementsBoundByIndex {
          let identity = appearance.identifier.replacingOccurrences(
            of: "saved.itinerary.appearance.", with: "")
          XCTAssertNotNil(expected[identity], "Unexpected itinerary appearance: \(identity)")
          let completion = application.buttons["saved.itinerary.completion.\(identity)"]
          XCTAssertTrue(
            completion.waitForPlannerValue(expected[identity] ?? "Unexpected appearance"))
          observed.insert(identity)
        }
        if observed == Set(expected.keys) { break }
        contents.swipeUp()
      }
      XCTAssertEqual(observed, Set(expected.keys))
    }

    private func verifyFreshMembershipAfterRelaunch(fixture: String) {
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
        "--fixture", fixture, "--fixture-dataset", datasetIdentifier,
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
