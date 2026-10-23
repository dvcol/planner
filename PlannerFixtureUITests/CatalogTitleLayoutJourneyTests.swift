import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class CatalogTitleLayoutJourneyTests: XCTestCase {
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
      screenshot.name = "List title beside compact native Filters Add and More"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      XCTAssertTrue(filters.isHittable)
      XCTAssertTrue(
        application.plannerElement("saved.list.addMenu").isHittable,
        "Add must remain directly visible beside Filters in a narrow List pane.")
      if application.windows.firstMatch.frame.width < 600 {
        XCTAssertTrue(titleExists)
        XCTAssertTrue(application.savedPlannerListAddControl().isHittable)
        XCTAssertFalse(application.plannerElement("saved.list.sort").isHittable)
        XCTAssertFalse(application.plannerElement("saved.list.edit").isHittable)
        XCTAssertFalse(application.plannerElement("saved.list.actions").isHittable)
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
      } else {
        let header = application.collectionViews["saved.list.contents"].staticTexts[
          "Overflow budget"]
        XCTAssertTrue(header.exists)
      }
      application.openSavedPlannerListAddMenu()
      let existing = application.plannerElement("saved.list.add")
      XCTAssertTrue(existing.waitForExistence(timeout: 5))
      existing.activateForPlannerJourney()
      let cancel = application.plannerElement("saved.membership.cancel")
      XCTAssertTrue(cancel.waitForExistence(timeout: 5))
      cancel.activateForPlannerJourney()
      XCTAssertTrue(filters.waitForExistence(timeout: 5))
      if application.windows.firstMatch.frame.width < 600 {
        application.terminate()
        application.launchSavedPlannerJourney()
        application.openPlannerSection("Lists")
        let reopenedList = application.savedPlannerListRow("Overflow budget")
        XCTAssertTrue(reopenedList.waitForExistence(timeout: 15))
        reopenedList.activateForPlannerJourney()
        XCTAssertTrue(
          application.savedPlannerItemRows("Long activity").firstMatch.waitForExistence(timeout: 10)
        )
        let reopenedTitle = application.navigationBars.staticTexts["Overflow budget"].firstMatch
        XCTAssertTrue(reopenedTitle.waitForExistence(timeout: 5))
        let reopenedCapture = XCTAttachment(screenshot: application.screenshot())
        reopenedCapture.name = "List title after reopening the saved dataset"
        reopenedCapture.lifetime = .keepAlways
        add(reopenedCapture)
        XCTAssertGreaterThanOrEqual(reopenedTitle.frame.width, minimumWidth)
      }
    }

    func testListMoreKeepsSortEditDoneAndContainerActionsReachable() {
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
      let longActivity = application.savedPlannerItemRows("Long activity").firstMatch
      let shortActivity = application.savedPlannerItemRows("Short activity").firstMatch
      XCTAssertTrue(longActivity.waitForExistence(timeout: 10))
      XCTAssertTrue(shortActivity.exists)
      let identities = [longActivity.identifier, shortActivity.identifier]
      let sort = application.savedPlannerListSortControl()
      XCTAssertEqual(sort.label, "Sort: Manual")
      sort.activateForPlannerJourney()
      let title = application.plannerElement("Title")
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.activateForPlannerJourney()
      let ascending = application.savedPlannerListSortControl()
      XCTAssertEqual(ascending.label, "Sort: Title · Ascending")
      ascending.activateForPlannerJourney()
      application.plannerElement("Descending").activateForPlannerJourney()
      let sorted = NSPredicate { _, _ in
        shortActivity.exists && longActivity.exists
          && shortActivity.frame.midY < longActivity.frame.midY
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: sorted, object: application)], timeout: 10),
        .completed)
      let nonManualEdit = application.savedPlannerListEditControl()
      XCTAssertFalse(nonManualEdit.isEnabled)
      application.dismissSavedPlannerListOverflow()
      application.savedPlannerListSortControl().activateForPlannerJourney()
      application.plannerElement("Manual").activateForPlannerJourney()
      let edit = application.savedPlannerListEditControl()
      XCTAssertTrue(edit.isEnabled)
      XCTAssertEqual(edit.label, "Edit")
      edit.activateForPlannerJourney()
      let done = application.savedPlannerListEditControl()
      XCTAssertEqual(done.label, "Done")
      done.activateForPlannerJourney()
      XCTAssertEqual([longActivity.identifier, shortActivity.identifier], identities)
      XCTAssertLessThan(longActivity.frame.midY, shortActivity.frame.midY)
      application.openSavedPlannerListActionsMenu()
      let estimate = application.plannerElement("saved.list.estimate.edit")
      XCTAssertTrue(estimate.waitForExistence(timeout: 5))
      estimate.activateForPlannerJourney()
      let cancel = application.plannerElement("saved.list.cancel")
      XCTAssertTrue(cancel.waitForExistence(timeout: 5))
      cancel.activateForPlannerJourney()
      XCTAssertTrue(longActivity.waitForExistence(timeout: 5))
      XCTAssertEqual([longActivity.identifier, shortActivity.identifier], identities)
      let screenshot = XCTAttachment(screenshot: application.screenshot())
      screenshot.name = "List native toolbar after Sort Edit Done and canceled estimate"
      screenshot.lifetime = .keepAlways
      add(screenshot)
    }

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
        let minimumWidth = (section as NSString).size(
          withAttributes: [.font: UIFont.preferredFont(forTextStyle: .headline)]).width
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

    func testCatalogViewSortFiltersAndAddRemainReachableThroughNativeOverflow() {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "catalog-overflow", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      for section in ["Items", "Inbox"] {
        application.openPlannerSection(section)
        let prefix = "saved.\(section.lowercased())"
        let filters = application.plannerElement("\(prefix).filters")
        XCTAssertTrue(filters.waitForExistence(timeout: 15))
        application.openSavedPlannerCatalogViewMenu(identifierPrefix: prefix)
        application.chooseSavedPlannerCollectionRepresentation("Map")
        application.openSavedPlannerCatalogViewMenu(identifierPrefix: prefix)
        application.chooseSavedPlannerCollectionRepresentation("List")
        application.savedPlannerCatalogSortControl(identifierPrefix: prefix)
          .activateForPlannerJourney()
        application.plannerElement("Descending").activateForPlannerJourney()
        let sort = application.savedPlannerCatalogSortControl(identifierPrefix: prefix)
        XCTAssertEqual(sort.label, "Sort: Title · Descending")
        application.dismissSavedPlannerCatalogOverflow()
        filters.activateForPlannerJourney()
        let done = application.plannerElement("saved.filters.done")
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.activateForPlannerJourney()
        application.openSavedPlannerNewItemEditor()
        let cancel = application.buttons.matching(
          NSPredicate(
            format: "identifier == %@ OR identifier == %@", "saved.item.cancel", "saved.item.back")
        ).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.activateForPlannerJourney()
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: application.screenshot())
        capture.name = "\(section) catalog toolbar after Map Sort Filters and canceled New Item"
        capture.lifetime = .keepAlways
        add(capture)
      }
    }
  }
#endif
