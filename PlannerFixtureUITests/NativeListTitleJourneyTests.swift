import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class NativeListTitleJourneyTests: XCTestCase {
    func testLongListUsesOneNativeTitleWithAlignedSummaryAcrossEmptyListAndMap() {
      continueAfterFailure = false
      if UIDevice.current.userInterfaceIdiom == .pad {
        XCUIDevice.shared.orientation = .landscapeLeft
      } else {
        XCUIDevice.shared.orientation = .portrait
      }
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "retired-membership", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      application.beginPlannerListCreation()
      let name = "Tokyo weekend museum visits, gardens, bookshops and rainy-day alternatives"
      let nameField = application.textFields["saved.list.name"]
      XCTAssertTrue(nameField.waitForExistence(timeout: 10))
      nameField.activateForPlannerJourney()
      nameField.typeText(name)
      application.plannerElement("saved.list.save").activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
      capture("Empty long List has one native title above its summary")
      assertSingleTitle(name, application: application)
      let estimate = application.staticTexts["Estimate"].firstMatch
      let remaining = application.staticTexts["Remaining"].firstMatch
      XCTAssertTrue(estimate.exists && remaining.exists)
      let summaryLeadingEdge = estimate.frame.minX
      XCTAssertEqual(remaining.frame.minX, summaryLeadingEdge, accuracy: 1)

      application.openSavedPlannerListAddMenu()
      application.plannerElement("saved.list.add").activateForPlannerJourney()
      let candidate = application.staticTexts["Retired stop hotel"].firstMatch
      XCTAssertTrue(candidate.waitForExistence(timeout: 10))
      candidate.activateForPlannerJourney()
      let confirm = application.plannerElement("saved.membership.add")
      XCTAssertTrue(confirm.isEnabled)
      confirm.activateForPlannerJourney()
      XCTAssertTrue(confirm.waitForNonExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))
      XCTAssertTrue(application.savedPlannerItemRows("Retired stop hotel").firstMatch.exists)
      assertSingleTitle(name, application: application)
      XCTAssertEqual(estimate.frame.minX, summaryLeadingEdge, accuracy: 1)
      XCTAssertEqual(remaining.frame.minX, summaryLeadingEdge, accuracy: 1)
      capture("Populated long List retains the same title and summary alignment")

      application.openSavedPlannerListViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("Map")
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))
      assertSingleTitle(name, application: application)
      XCTAssertEqual(estimate.frame.minX, summaryLeadingEdge, accuracy: 1)
      XCTAssertEqual(remaining.frame.minX, summaryLeadingEdge, accuracy: 1)
      capture("Map uses the same native List title and aligned progress summary")
      application.openSavedPlannerListViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("List")
      XCTAssertTrue(
        application.savedPlannerItemRows("Retired stop hotel").firstMatch.waitForExistence(
          timeout: 10))
      assertSingleTitle(name, application: application)
      application.terminate()
    }

    private func assertSingleTitle(_ name: String, application: XCUIApplication) {
      let nativeTitle = application.navigationBars.staticTexts[name].firstMatch
      XCTAssertTrue(nativeTitle.waitForExistence(timeout: 10))
      XCTAssertEqual(nativeTitle.label, name)
      let visibleTitles = application.staticTexts.matching(
        NSPredicate(format: "label == %@", name)
      ).allElementsBoundByIndex.filter(\.isHittable)
      XCTAssertEqual(visibleTitles.count, 1, "The visible List title should have one owner.")
      XCTAssertTrue(application.plannerElement("saved.list.filters").isHittable)
      XCTAssertTrue(application.savedPlannerListAddControl().isHittable)
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
