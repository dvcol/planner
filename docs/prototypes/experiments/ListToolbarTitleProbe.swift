import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class ListToolbarTitleProbe: XCTestCase {
    func testListTitleRemainsReadableAndItsAddMenuStillOpensBesideNativeActions() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "catalog-overflow", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Lists")
      let list = application.savedPlannerListRow("Overflow budget")
      XCTAssertTrue(list.waitForExistence(timeout: 15))
      list.activateForPlannerJourney()
      let filters = application.plannerElement("saved.list.filters")
      XCTAssertTrue(filters.waitForExistence(timeout: 10))
      let title = application.navigationBars.staticTexts["Overflow budget"].firstMatch
      let titleExists = title.waitForExistence(timeout: 5)
      let minimumWidth = ("Overflow budget" as NSString).size(
        withAttributes: [.font: UIFont.preferredFont(forTextStyle: .headline)]).width
      let screenshot = XCTAttachment(screenshot: application.screenshot())
      screenshot.name = "List title beside native filter sort Edit Add and actions"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      XCTAssertTrue(titleExists)
      let frames = XCTAttachment(
        string:
          "Title: \(title.frame)\nMinimum headline width: \(minimumWidth)\n\(application.navigationBars.debugDescription)"
      )
      frames.name = "List native title and toolbar frames"
      frames.lifetime = .keepAlways
      add(frames)
      XCTAssertGreaterThanOrEqual(title.frame.width, minimumWidth)
      for button in application.navigationBars.buttons.allElementsBoundByIndex
      where button.isHittable {
        XCTAssertFalse(
          title.frame.intersects(button.frame), "The List title overlaps \(button.label).")
      }
      application.openSavedPlannerListAddMenu()
      let existing = application.plannerElement("saved.list.add")
      XCTAssertTrue(existing.waitForExistence(timeout: 5))
      existing.activateForPlannerJourney()
      let cancel = application.plannerElement("saved.membership.cancel")
      XCTAssertTrue(cancel.waitForExistence(timeout: 5))
      cancel.activateForPlannerJourney()
      XCTAssertTrue(filters.waitForExistence(timeout: 5))
    }

  }
#endif
