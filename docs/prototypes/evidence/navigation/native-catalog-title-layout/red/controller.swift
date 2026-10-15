import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class CatalogTitleLayoutJourneyTests: XCTestCase {
    func testItemCatalogTitlesRemainReadableBesideNativeToolbarActions() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "catalog-overflow", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      for section in ["Items", "Inbox"] {
        application.openPlannerSection(section)
        let filters = application.plannerElement("saved.\(section.lowercased()).filters")
        XCTAssertTrue(filters.waitForExistence(timeout: 15))
        let title = application.navigationBars.staticTexts[section].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: application.screenshot())
        capture.name = "\(section) title beside native catalog actions"
        capture.lifetime = .keepAlways
        add(capture)
        let minimumWidth = ceil(
          (section as NSString).size(
            withAttributes: [.font: UIFont.preferredFont(forTextStyle: .headline)]).width)
        let frames = XCTAttachment(
          string:
            "Title: \(title.frame)\nMinimum untruncated headline width: \(minimumWidth)\n\(application.navigationBars.debugDescription)"
        )
        frames.name = "\(section) native navigation frames"
        frames.lifetime = .keepAlways
        add(frames)
        XCTAssertGreaterThanOrEqual(title.frame.width, minimumWidth)
        for button in application.navigationBars.buttons.allElementsBoundByIndex
        where button.isHittable {
          XCTAssertFalse(
            title.frame.intersects(button.frame),
            "The \(section) title overlaps \(button.label).")
        }
      }
    }
  }
#endif
