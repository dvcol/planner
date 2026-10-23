import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class CatalogTitleLayoutJourneyTests: XCTestCase {
    func testAccessibleItineraryMapKeepsItsPinAndFooterDuringRotation() throws {
      try XCTSkipUnless(
        UIDevice.current.userInterfaceIdiom == .pad, "This journey compares iPad panes.")
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
      }
      let application = XCUIApplication()
      application.launchArguments = [
        "--change-stream-fixture", "--fixture-itinerary", "--fixture-map-search-coordinate",
        "--fixture-dataset", UUID().uuidString,
      ]
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Itineraries")
      let itinerary = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "City trip")
      ).firstMatch
      XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
      var previousFrame = CGRect.null
      let settledCatalog = NSPredicate { _, _ in
        let frame = itinerary.frame
        let settled = frame == previousFrame && itinerary.isHittable
        previousFrame = frame
        return settled
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: settledCatalog, object: application)],
          timeout: 10), .completed)
      itinerary.staticTexts["City trip"].firstMatch.activateForPlannerJourney()
      XCTAssertTrue(
        application.plannerElement("saved.itinerary.filters").waitForExistence(timeout: 10))
      application.openSavedPlannerItineraryViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("Map")
      let pin = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.map.pin.")
      ).firstMatch
      XCTAssertTrue(pin.waitForExistence(timeout: 10))
      if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
        let summary = application.scrollViews["saved.map.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let warning = summary.staticTexts["2 estimates missing"].firstMatch
        for _ in 0..<8 {
          if warning.exists && warning.isHittable { break }
          summary.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(warning.isHittable)
        XCTAssertTrue(pin.isHittable)
      }
      pin.activateForPlannerJourney()
      let firstStop = application.buttons["Hotel · Stop 1"].firstMatch
      XCTAssertTrue(firstStop.waitForExistence(timeout: 5))
      firstStop.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
      for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
        XCUIDevice.shared.orientation = orientation
        let settled = NSPredicate { _, _ in
          let frame = application.windows.firstMatch.frame
          let matchesOrientation: Bool
          if orientation == .portrait {
            matchesOrientation = frame.height > frame.width
          } else {
            matchesOrientation = frame.width > frame.height
          }
          return matchesOrientation && pin.exists && pin.isHittable
        }
        let result = XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: settled, object: application)], timeout: 10)
        let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
        capture.name = "Itinerary native accessible Map rotation \(orientation.rawValue)"
        capture.lifetime = .keepAlways
        add(capture)
        let hierarchy = XCTAttachment(string: application.debugDescription)
        hierarchy.name = "Itinerary native accessible Map viewport hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertEqual(result, .completed)
        let map = application.descendants(matching: .any)
          .matching(identifier: "saved.map.collection").firstMatch
        let summary = application.scrollViews["saved.map.summary"]
        let visibleTop = summary.exists ? max(map.frame.minY, summary.frame.maxY) : map.frame.minY
        XCTAssertGreaterThanOrEqual(pin.frame.minY, visibleTop - 1)
        XCTAssertLessThanOrEqual(pin.frame.maxY, map.frame.maxY + 1)
        XCTAssertGreaterThanOrEqual(pin.frame.minX, map.frame.minX - 1)
        XCTAssertLessThanOrEqual(pin.frame.maxX, map.frame.maxX + 1)
        let locations = application.plannerElement("saved.map.locations")
        XCTAssertTrue(locations.isHittable)
        XCTAssertEqual(locations.label, "Locations")
        XCTAssertTrue(application.staticTexts["2 of 2 items located"].firstMatch.isHittable)
        XCTAssertTrue(application.staticTexts["Original notes"].exists)
      }
    }

    func testItineraryTitleAndPrimaryActionsRemainVisibleInTheCollectionPane() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--change-stream-fixture", "--fixture-itinerary", "--fixture-dataset", UUID().uuidString,
      ]
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Itineraries")
      let itinerary = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "City trip")
      ).firstMatch
      XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
      itinerary.activateForPlannerJourney()
      let filters = application.plannerElement("saved.itinerary.filters")
      XCTAssertTrue(filters.waitForExistence(timeout: 10))
      let title = application.navigationBars.staticTexts["City trip"].firstMatch
      let titleExists = title.waitForExistence(timeout: 5)
      let capture = XCTAttachment(screenshot: application.screenshot())
      capture.name = "Itinerary title beside native Filters Add and More"
      capture.lifetime = .keepAlways
      add(capture)
      let frames = XCTAttachment(string: application.navigationBars.debugDescription)
      frames.name = "Itinerary native title and toolbar frames"
      frames.lifetime = .keepAlways
      add(frames)
      XCTAssertTrue(titleExists, "The selected Itinerary title must remain visible.")
      let minimumWidth = ("City trip" as NSString).size(
        withAttributes: [.font: UIFont.preferredFont(forTextStyle: .headline)]).width
      if application.windows.firstMatch.frame.width < 600 {
        XCTAssertGreaterThanOrEqual(title.frame.width, minimumWidth)
      } else {
        XCTAssertTrue(
          application.collectionViews["saved.itinerary.contents"].staticTexts["City trip"].exists)
      }
      XCTAssertTrue(filters.isHittable)
      let addEntry = application.plannerElement("saved.itinerary.entry.new")
      XCTAssertTrue(addEntry.isHittable, "Add must remain directly visible beside Filters.")
      for button in application.navigationBars.buttons.allElementsBoundByIndex
      where button.isHittable {
        XCTAssertFalse(
          title.frame.intersects(button.frame), "The Itinerary title overlaps \(button.label).")
      }
      addEntry.activateForPlannerJourney()
      let cancel = application.plannerElement("saved.itinerary.entry.cancel")
      XCTAssertTrue(cancel.waitForExistence(timeout: 5))
      cancel.activateForPlannerJourney()
      XCTAssertTrue(filters.waitForExistence(timeout: 5))
      XCTAssertTrue(title.exists)
      application.openSavedPlannerItineraryViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("Map")
      let mapTitle = application.staticTexts["saved.itinerary.title"].firstMatch
      XCTAssertTrue(mapTitle.waitForExistence(timeout: 10))
      XCTAssertEqual(mapTitle.label, "City trip")
      XCTAssertTrue(mapTitle.isHittable)
      let mapCapture = XCTAttachment(screenshot: application.screenshot())
      mapCapture.name = "Itinerary title retained above its native collection Map"
      mapCapture.lifetime = .keepAlways
      add(mapCapture)
    }

    func testItineraryMoreKeepsReorderEditingAndSchedulingReachable() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--change-stream-fixture", "--fixture-itinerary", "--fixture-dataset", UUID().uuidString,
      ]
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Itineraries")
      let itinerary = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "City trip")
      ).firstMatch
      XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
      let itineraryIdentifier = itinerary.identifier
      itinerary.activateForPlannerJourney()
      let rows = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
      XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 10))
      XCTAssertEqual(rows.count, 2)
      let identities = rows.allElementsBoundByIndex.map(\.identifier)
      let reorder = application.savedPlannerItineraryReorderControl()
      XCTAssertTrue(reorder.isEnabled)
      reorder.activateForPlannerJourney()
      application.savedPlannerItineraryReorderControl().activateForPlannerJourney()
      XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), identities)
      application.savedPlannerItineraryEditControl().activateForPlannerJourney()
      let titleField = application.textFields["saved.itinerary.title"]
      XCTAssertTrue(titleField.waitForExistence(timeout: 5))
      XCTAssertEqual(titleField.value as? String, "City trip")
      application.plannerElement("saved.itinerary.cancel").activateForPlannerJourney()
      application.savedPlannerItineraryActionsControl().activateForPlannerJourney()
      application.plannerElement("Schedule itinerary").activateForPlannerJourney()
      let cancelSchedule = application.plannerElement("saved.schedule.cancel")
      XCTAssertTrue(cancelSchedule.waitForExistence(timeout: 5))
      cancelSchedule.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["0 of 2 items done"].waitForExistence(timeout: 5))
      XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), identities)
      application.openSavedPlannerItineraryViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("Map")
      XCTAssertTrue(application.staticTexts["saved.itinerary.title"].waitForExistence(timeout: 10))
      let mapReorder = application.savedPlannerItineraryReorderControl()
      XCTAssertFalse(mapReorder.isEnabled)
      application.dismissSavedPlannerItineraryOverflow()
      let mapCapture = XCTAttachment(screenshot: application.screenshot())
      mapCapture.name = "Itinerary toolbar preserves Map after canceled Edit and Schedule"
      mapCapture.lifetime = .keepAlways
      add(mapCapture)
      application.openSavedPlannerItineraryViewMenu()
      application.chooseSavedPlannerCollectionRepresentation("List")
      XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 10))
      XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), identities)
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Itineraries")
      XCTAssertTrue(itinerary.waitForExistence(timeout: 20))
      XCTAssertEqual(itinerary.identifier, itineraryIdentifier)
      itinerary.activateForPlannerJourney()
      XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 10))
      XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), identities)
      XCTAssertTrue(application.staticTexts["0 of 2 items done"].exists)
      let capture = XCTAttachment(screenshot: application.screenshot())
      capture.name = "Itinerary toolbar and exact route survive relaunch"
      capture.lifetime = .keepAlways
      add(capture)
    }

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
