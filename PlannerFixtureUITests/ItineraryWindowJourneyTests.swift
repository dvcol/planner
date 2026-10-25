import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class ItineraryWindowJourneyTests: XCTestCase {
  #if os(iOS)
    func testEnlargedActivityNamesRemainDistinguishableInNarrowItineraries() throws {
      try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
      continueAfterFailure = false
      XCTAssertTrue(UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory)
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "itinerary-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCUIDevice.shared.orientation = .portrait
      waitForOrientation(application, landscape: false)
      openRoute("Windowed route", application: application)
      let hideSidebar = application.buttons["Hide Sidebar"].firstMatch
      if hideSidebar.exists && hideSidebar.isHittable {
        hideSidebar.activateForPlannerJourney()
      }
      let contents = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.contents").firstMatch
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
      XCTAssertLessThan(contents.frame.width, 440)
      let row = try revealExpandedActivity(
        "Window Activity 002", in: contents, application: application)
      XCTAssertFalse(application.staticTexts["saved.itinerary.title"].frame.intersects(row.frame))
      XCTAssertFalse(application.staticTexts["Entries"].frame.intersects(row.frame))
      capture(application, "Enlarged activity name and estimate in the narrow itinerary")
      let hierarchy = XCTAttachment(string: row.debugDescription)
      hierarchy.name = "Enlarged activity native text bounds"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      let title = row.staticTexts["Window Activity 002"]
      XCTAssertTrue(title.exists)
      let requiredTitleHeight = ("Window Activity 002" as NSString).boundingRect(
        with: CGSize(width: title.frame.width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: UIFont.preferredFont(forTextStyle: .body)], context: nil
      ).height
      XCTAssertGreaterThanOrEqual(title.frame.height + 2, requiredTitleHeight)
      let estimate = row.staticTexts["5 minutes"]
      XCTAssertTrue(estimate.exists)
      let requiredEstimateHeight = ("5 minutes" as NSString).boundingRect(
        with: CGSize(width: row.frame.width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: UIFont.preferredFont(forTextStyle: .caption1)], context: nil
      ).height
      XCTAssertGreaterThanOrEqual(estimate.frame.height + 2, requiredEstimateHeight)
      row.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Window itinerary notes 2"].waitForExistence(timeout: 10))
      capture(application, "Enlarged activity opens its exact unchanged notes")
      application.terminate()
    }

    func testLongItineraryTitleLeavesItsRouteUsableAtAccessibilitySizes() throws {
      try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
      continueAfterFailure = false
      XCTAssertTrue(UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory)
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "itinerary-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCUIDevice.shared.orientation = .portrait
      waitForOrientation(application, landscape: false)
      openRoute("Windowed route", application: application)
      application.savedPlannerItineraryEditControl().activateForPlannerJourney()
      let titleField = application.textFields["saved.itinerary.title"]
      XCTAssertTrue(titleField.waitForExistence(timeout: 10))
      let name =
        "Tokyo weekend museum visits and favourite restaurants, gardens, bookshops and rainy-day alternatives"
      titleField.activateForPlannerJourney()
      titleField.press(forDuration: 1)
      let selectAll = application.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@ OR identifier == %@", "Select All", "Select All")
      ).firstMatch
      XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
      selectAll.activateForPlannerJourney()
      titleField.typeText(name)
      XCTAssertTrue(titleField.waitForPlannerValue(name))
      application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
      XCTAssertTrue(titleField.waitForNonExistence(timeout: 10))
      let hideSidebar = application.buttons["Hide Sidebar"].firstMatch
      if hideSidebar.exists && hideSidebar.isHittable {
        hideSidebar.activateForPlannerJourney()
      }
      let contents = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.contents").firstMatch
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
      var appearanceIdentifier: String?
      for landscape in [false, true] {
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        waitForOrientation(application, landscape: landscape)
        capture(application, "Long itinerary title at accessibility size, landscape \(landscape)")
        assertVisibleItineraryContext(name, in: contents, application: application)
        if let appearanceIdentifier {
          let retainedRow = application.plannerElement(appearanceIdentifier)
          if retainedRow.exists {
            let viewport = visibleContentsFrame(contents, application: application)
            XCTAssertGreaterThanOrEqual(
              viewport.height + 2, retainedRow.frame.height,
              "Route viewport \(viewport), retained activity \(retainedRow.frame)")
          }
        }
        let row = try revealExpandedActivity(
          "Window Activity 001", in: contents, application: application,
          searchBackwards: landscape)
        if let appearanceIdentifier {
          XCTAssertEqual(row.identifier, appearanceIdentifier)
        } else {
          appearanceIdentifier = row.identifier
        }
        let heading = application.staticTexts["saved.itinerary.title"]
        let nameArea = application.scrollViews["saved.itinerary.heading"]
        XCTAssertTrue(nameArea.exists)
        let separated = NSPredicate { _, _ in !nameArea.frame.intersects(row.frame) }
        XCTAssertEqual(
          XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: separated, object: application)], timeout: 5),
          .completed,
          "Name area \(nameArea.frame), title \(heading.frame), activity \(row.frame), route \(contents.frame)"
        )
        if !landscape {
          let startingPosition = heading.frame.minY
          for _ in 0..<3 { nameArea.swipeUp() }
          XCTAssertLessThan(heading.frame.minY, startingPosition)
          XCTAssertTrue(row.isHittable)
          capture(application, "Long itinerary name remains readable in its native scroll area")
        }
        XCTAssertTrue(application.plannerElement("saved.itinerary.filters").isHittable)
        XCTAssertTrue(application.plannerElement("saved.itinerary.entry.new").isHittable)
      }
      application.terminate()
    }

    func testNarrowTabletKeepsItsItineraryContextWhileScrollingAndRotating() throws {
      try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
      continueAfterFailure = false
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "itinerary-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCUIDevice.shared.orientation = .portrait
      waitForOrientation(application, landscape: false)
      openRoute("Windowed route", application: application)
      let hideSidebar = application.buttons["Hide Sidebar"].firstMatch
      if hideSidebar.exists && hideSidebar.isHittable {
        hideSidebar.activateForPlannerJourney()
      }
      let catalog = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.contents").firstMatch
      XCTAssertTrue(catalog.waitForExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["0 of 132 items done"].waitForExistence(timeout: 10))
      XCTAssertLessThan(catalog.frame.width, 440)
      assertVisibleItineraryContext("Windowed route", in: catalog, application: application)
      let row = try revealExpandedActivity(
        "Window Activity 020", in: catalog, application: application)
      let identifier = row.identifier
      capture(application, "Narrow tablet itinerary context after scrolling into a List")
      let hierarchy = XCTAttachment(string: application.navigationBars.debugDescription)
      hierarchy.name = "Narrow tablet itinerary navigation after scrolling"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      assertVisibleItineraryContext("Windowed route", in: catalog, application: application)
      XCTAssertTrue(application.plannerElement("saved.itinerary.filters").isHittable)
      let addEntry = application.plannerElement("saved.itinerary.entry.new")
      XCTAssertTrue(addEntry.isHittable)
      addEntry.activateForPlannerJourney()
      let cancel = application.plannerElement("saved.itinerary.entry.cancel")
      XCTAssertTrue(cancel.waitForExistence(timeout: 10))
      cancel.activateForPlannerJourney()
      XCTAssertTrue(catalog.waitForExistence(timeout: 10))
      XCTAssertEqual(
        try revealExpandedActivity("Window Activity 020", in: catalog, application: application)
          .identifier, identifier)
      for landscape in [true, false] {
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        waitForOrientation(application, landscape: landscape)
        let originalAppearance = application.plannerElement(identifier)
        for _ in 0..<30 {
          if isFullyVisible(originalAppearance, in: catalog, application: application) { break }
          let verticalMovement: CGFloat
          if originalAppearance.exists && originalAppearance.frame.midY < catalog.frame.midY {
            verticalMovement = 0.2
          } else {
            verticalMovement = -0.2
          }
          let start = catalog.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
          let end = catalog.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5 + verticalMovement))
          start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(isFullyVisible(originalAppearance, in: catalog, application: application))
        XCTAssertEqual(originalAppearance.label, "Window Activity 020")
        capture(application, "Itinerary context after rotation, landscape \(landscape)")
        assertVisibleItineraryContext("Windowed route", in: catalog, application: application)
      }
      application.terminate()
    }

    private func assertVisibleItineraryContext(
      _ title: String, in catalog: XCUIElement, application: XCUIApplication
    ) {
      let headings = application.descendants(matching: .any)
        .matching(identifier: "saved.itinerary.title").allElementsBoundByIndex
      let nativeTitles = application.navigationBars.staticTexts.matching(identifier: title)
        .allElementsBoundByIndex
      let nameArea = application.scrollViews["saved.itinerary.heading"]
      let visibleFrames = (headings + nativeTitles).compactMap { heading -> CGRect? in
        guard heading.exists, heading.label == title else { return nil }
        let frame: CGRect
        if nameArea.exists {
          guard nameArea.isHittable else { return nil }
          frame = heading.frame.intersection(nameArea.frame)
        } else {
          guard heading.isHittable else { return nil }
          frame = heading.frame
        }
        guard !frame.isEmpty, frame.minX >= catalog.frame.minX,
          frame.maxX <= catalog.frame.maxX
        else { return nil }
        return frame
      }
      XCTAssertFalse(
        visibleFrames.isEmpty, "The current Itinerary must remain identifiable in its pane.")
      for frame in visibleFrames {
        for button in application.navigationBars.buttons.allElementsBoundByIndex
        where button.isHittable {
          XCTAssertFalse(frame.intersects(button.frame))
        }
      }
    }
  #endif

  func testCollapsingARepeatedListKeepsSelectedDetailsAndCompletionAcrossLayoutChanges() throws {
    continueAfterFailure = false
    #if os(iOS)
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
    #endif
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "itinerary-windows", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    openRoute("Windowed route", application: application)
    let catalog = application.descendants(matching: .any)
      .matching(identifier: "saved.itinerary.contents").firstMatch
    let firstRow = try revealExpandedActivity(
      "Window Activity 001", in: catalog, application: application)
    let firstIdentifier = firstRow.identifier
    let first = application.plannerElement(firstIdentifier)
    let firstCompletion = completion(firstIdentifier, application: application)
    firstCompletion.activateForPlannerJourney()
    let completed = NSPredicate(
      format: "label == %@", "Mark Window Activity 001 undone in this Itinerary")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: completed, object: firstCompletion)], timeout: 15
      ),
      .completed)
    first.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["Window itinerary notes 1"].waitForExistence(timeout: 10))
    #if os(iOS)
      if UIDevice.current.userInterfaceIdiom == .phone {
        let back = application.navigationBars.buttons["Windowed route"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.activateForPlannerJourney()
      }
    #endif
    try revealFirstActivity(in: catalog, application: application)
    let disclosure = firstActivitiesDisclosure(application)
    if !disclosure.waitForExistence(timeout: 5) {
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Collapsed itinerary native disclosure hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertTrue(disclosure.exists)
    disclosure.activateForPlannerJourney()
    let firstIsHidden = first.waitForNonExistence(timeout: 10)
    if !firstIsHidden {
      capture(application, "Collapsed itinerary appearance remains after disclosure")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Collapsed itinerary unexpected appearance hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertTrue(firstIsHidden)
    XCTAssertTrue(application.staticTexts["1 of 132 items done"].exists)
    assertSelectedCompletionIfWide(application)
    capture(application, "Collapsed itinerary branch preserves full progress and selected details")
    #if os(iOS)
      XCUIDevice.shared.orientation = .landscapeLeft
      waitForOrientation(application, landscape: true)
      XCTAssertFalse(first.exists)
      XCTAssertTrue(application.staticTexts["1 of 132 items done"].exists)
      assertSelectedCompletionIfWide(application)
      capture(application, "Collapsed itinerary branch keeps its state in landscape")
      XCUIDevice.shared.orientation = .portrait
      waitForOrientation(application, landscape: false)
    #else
      let window = application.windows.firstMatch
      let originalWidth = window.frame.width
      addTeardownBlock {
        await MainActor.run {
          guard window.exists else { return }
          Self.resizeWindow(window, width: originalWidth)
        }
      }
      Self.resizeWindow(window, width: 860)
      XCTAssertFalse(first.exists)
      assertSelectedCompletionIfWide(application)
      capture(
        application, "Collapsed itinerary branch keeps its selected detail in a narrow Mac window")
      Self.resizeWindow(window, width: 1200)
    #endif
    XCTAssertFalse(first.exists)
    XCTAssertTrue(application.staticTexts["1 of 132 items done"].exists)
    firstActivitiesDisclosure(application).activateForPlannerJourney()
    XCTAssertTrue(first.waitForExistence(timeout: 10))
    XCTAssertEqual(first.identifier, firstIdentifier)
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: completed, object: firstCompletion)], timeout: 15
      ),
      .completed)
    let second = try revealExpandedActivity(
      "Window Activity 001", excluding: firstIdentifier, in: catalog, application: application)
    XCTAssertNotEqual(second.identifier, firstIdentifier)
    XCTAssertEqual(
      completion(second.identifier, application: application).label,
      "Mark Window Activity 001 done in this Itinerary")
    capture(application, "Reopened itinerary branch retains independent repeated completion")
  }

  private func firstActivitiesDisclosure(_ application: XCUIApplication) -> XCUIElement {
    #if os(macOS)
      application.disclosureTriangles.matching(
        NSPredicate(format: "label CONTAINS %@", "Route activities")
      ).firstMatch
    #else
      application.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Route activities"))
        .firstMatch
    #endif
  }

  private func assertSelectedCompletionIfWide(_ application: XCUIApplication) {
    #if os(iOS)
      guard UIDevice.current.userInterfaceIdiom == .pad else { return }
    #endif
    XCTAssertTrue(application.staticTexts["Window itinerary notes 1"].exists)
    XCTAssertTrue(application.staticTexts["Completed"].exists)
  }

  private func revealExpandedActivity(
    _ title: String, excluding identifier: String? = nil, in catalog: XCUIElement,
    application: XCUIApplication, searchBackwards: Bool = false
  ) throws -> XCUIElement {
    XCTAssertTrue(catalog.waitForExistence(timeout: 15))
    for _ in 0..<30 {
      let matchingRows = activities(title, application: application).allElementsBoundByIndex.filter
      {
        $0.identifier != identifier && $0.identifier.split(separator: ".").count == 5
      }
      if let row = matchingRows.first(where: {
        isFullyVisible($0, in: catalog, application: application)
      }) {
        return row
      }
      if let row = matchingRows.first {
        let visibleFrame = visibleContentsFrame(catalog, application: application)
        let requiredMovement = visibleFrame.minY + 2 - row.frame.minY
        let maximumMovement = visibleFrame.height * 0.4
        let movement = min(maximumMovement, max(-maximumMovement, requiredMovement))
        let start = catalog.coordinate(withNormalizedOffset: .zero).withOffset(
          CGVector(
            dx: visibleFrame.midX - catalog.frame.minX,
            dy: visibleFrame.midY - catalog.frame.minY))
        let end = start.withOffset(CGVector(dx: 0, dy: movement))
        start.press(forDuration: 0.05, thenDragTo: end)
        continue
      }
      if searchBackwards {
        let visibleFrame = visibleContentsFrame(catalog, application: application)
        let start = catalog.coordinate(withNormalizedOffset: .zero).withOffset(
          CGVector(
            dx: visibleFrame.midX - catalog.frame.minX,
            dy: visibleFrame.midY - catalog.frame.minY))
        let end = start.withOffset(CGVector(dx: 0, dy: visibleFrame.height * 0.4))
        start.press(forDuration: 0.05, thenDragTo: end)
        continue
      }
      catalog.swipeUp()
    }
    XCTFail("The expanded itinerary appearance did not become fully visible.")
    throw CancellationError()
  }

  #if os(iOS)
    private func waitForOrientation(_ application: XCUIApplication, landscape: Bool) {
      let oriented = NSPredicate { _, _ in
        let frame = application.windows.firstMatch.frame
        return (frame.width > frame.height) == landscape
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: oriented, object: application)], timeout: 5),
        .completed)
    }
  #else
    private static func resizeWindow(_ window: XCUIElement, width: CGFloat) {
      let edge = window.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.8)).withOffset(
        .init(dx: -1, dy: 0))
      edge.click(
        forDuration: 0.1, thenDragTo: edge.withOffset(.init(dx: width - window.frame.width, dy: 0)))
      let resized = NSPredicate { _, _ in abs(window.frame.width - width) < 8 }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: resized, object: window)], timeout: 5),
        .completed)
    }
  #endif

  func testFilteredEntryDragPreservesHiddenCompletionAndFullOrderAfterRelaunch() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "itinerary-windows", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    openRoute("Reorder route", application: application)
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].waitForExistence(timeout: 10))
    let firstIdentifier = activities("Window Activity 001", application: application).firstMatch
      .identifier
    let secondIdentifier = activities("Window Activity 002", application: application).firstMatch
      .identifier
    let thirdIdentifier = activities("Window Activity 003", application: application).firstMatch
      .identifier
    XCTAssertFalse(firstIdentifier.isEmpty)
    XCTAssertFalse(secondIdentifier.isEmpty)
    XCTAssertFalse(thirdIdentifier.isEmpty)
    let first = application.plannerElement(firstIdentifier)
    let second = application.plannerElement(secondIdentifier)
    let third = application.plannerElement(thirdIdentifier)
    let filters = application.plannerElement("saved.itinerary.filters")
    application.chooseSavedPlannerStateFilter("Todo", control: filters)
    XCTAssertTrue(first.waitForNonExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Matching 2 of 3 items"].exists)
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    #if os(iOS)
      let edit = application.savedPlannerItineraryReorderControl()
      XCTAssertTrue(edit.waitForExistence(timeout: 5))
      edit.activateForPlannerJourney()
    #endif
    capture(application, "Filtered itinerary entries before native drag")
    dragEntry(third, before: second, application: application)
    let reordered = waitForOrder(third, before: second)
    if !reordered {
      capture(application, "Filtered itinerary entries after unsuccessful native drag")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Filtered itinerary native drag hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertTrue(reordered)
    #if os(iOS)
      application.savedPlannerItineraryReorderControl().activateForPlannerJourney()
    #endif
    XCTAssertFalse(first.exists)
    capture(application, "Filtered itinerary native drag keeps hidden completion and full progress")
    application.chooseSavedPlannerStateFilter("All completion states", control: filters)
    XCTAssertTrue(first.waitForExistence(timeout: 10))
    XCTAssertTrue(waitForOrder(first, before: third))
    XCTAssertTrue(waitForOrder(third, before: second))
    XCTAssertEqual(
      completion(firstIdentifier, application: application).label,
      "Mark Window Activity 001 undone in this Itinerary")
    application.terminate()
    application.launchSavedPlannerJourney()
    openRoute("Reorder route", application: application)
    XCTAssertTrue(first.waitForExistence(timeout: 10))
    XCTAssertTrue(waitForOrder(first, before: third))
    XCTAssertTrue(waitForOrder(third, before: second))
    XCTAssertEqual(first.identifier, firstIdentifier)
    XCTAssertEqual(second.identifier, secondIdentifier)
    XCTAssertEqual(third.identifier, thirdIdentifier)
    XCTAssertEqual(
      completion(firstIdentifier, application: application).label,
      "Mark Window Activity 001 undone in this Itinerary")
    XCTAssertTrue(application.staticTexts["1 of 3 items done"].exists)
    capture(
      application, "Filtered itinerary drag preserves exact entries and completion after relaunch")
  }

  private func waitForOrder(_ first: XCUIElement, before second: XCUIElement) -> Bool {
    let ordered = NSPredicate { _, _ in
      first.exists && second.exists && first.frame.minY < second.frame.minY
    }
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: ordered, object: first)], timeout: 10)
      == .completed
  }

  private func dragEntry(
    _ entry: XCUIElement, before target: XCUIElement, application: XCUIApplication
  ) {
    #if os(macOS)
      entry.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).click(
        forDuration: 1, thenDragTo: target.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0)),
        withVelocity: .slow, thenHoldForDuration: 1)
    #else
      let row = application.cells.containing(.button, identifier: entry.identifier).firstMatch
      let targetRow = application.cells.containing(.button, identifier: target.identifier)
        .firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      XCTAssertTrue(targetRow.waitForExistence(timeout: 5))
      let handle = row.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
        .firstMatch
      XCTAssertTrue(handle.waitForExistence(timeout: 5), application.debugDescription)
      handle.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(
        forDuration: 1,
        thenDragTo: targetRow.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.1)))
    #endif
  }

  func testRepeatedListPagesKeepIndependentChecksDetailsAndIdentitiesAfterRelaunch() throws {
    continueAfterFailure = false
    #if os(iOS)
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
    #endif
    let application = XCUIApplication()
    application.launchArguments = [
      "--fixture", "itinerary-windows", "--fixture-dataset", UUID().uuidString,
    ]
    application.launchSavedPlannerJourney()
    openRoute("Windowed route", application: application)
    XCTAssertTrue(application.staticTexts["0 of 132 items done"].waitForExistence(timeout: 15))
    XCTAssertTrue(application.staticTexts["2 direct items · 2 lists"].exists)
    capture(application, "Windowed itinerary starts with full progress and repeated List headers")
    let catalog = application.descendants(matching: .any)
      .matching(identifier: "saved.itinerary.contents").firstMatch
    let first = try revealActivity("Window Activity 065", in: catalog, application: application)
    let firstIdentifier = first.identifier
    let firstCompletion = completion(firstIdentifier, application: application)
    XCTAssertTrue(waitForCompletion(firstCompletion, done: false))
    capture(application, "Itinerary boundary appearance before local completion")
    firstCompletion.activateForPlannerJourney()
    let completed = waitForCompletion(firstCompletion, done: true)
    if !completed {
      capture(application, "Itinerary boundary completion refresh failure")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Itinerary boundary completion refresh hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertTrue(completed)
    XCTAssertTrue(firstCompletion.isHittable)
    capture(application, "First repeated List appearance stays visible after local completion")
    let second = try revealActivity(
      "Window Activity 065", excluding: firstIdentifier, in: catalog, application: application)
    let secondIdentifier = second.identifier
    XCTAssertNotEqual(firstIdentifier, secondIdentifier)
    XCTAssertTrue(
      waitForCompletion(completion(secondIdentifier, application: application), done: false))
    second.activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Window itinerary notes 65"].waitForExistence(timeout: 10))
    #if os(iOS)
      let needsBackNavigation = UIDevice.current.userInterfaceIdiom == .phone
    #else
      let needsBackNavigation = false
    #endif
    if needsBackNavigation {
      #if os(iOS)
        let back = application.navigationBars.buttons["Windowed route"].firstMatch
        if back.waitForExistence(timeout: 5) {
          back.activateForPlannerJourney()
        } else {
          application.plannerElement("BackButton").activateForPlannerJourney()
        }
      #endif
      try revealFirstActivity(in: catalog, application: application)
    } else {
      try revealFirstActivity(in: catalog, application: application)
      XCTAssertTrue(application.staticTexts["Window itinerary notes 65"].exists)
      capture(
        application, "Selected itinerary appearance keeps details while its page is offscreen")
    }
    XCTAssertTrue(application.staticTexts["1 of 132 items done"].waitForExistence(timeout: 10))
    application.terminate()
    application.launchSavedPlannerJourney()
    openRoute("Windowed route", application: application)
    XCTAssertTrue(application.staticTexts["1 of 132 items done"].waitForExistence(timeout: 15))
    let restoredFirst = try revealActivity(
      "Window Activity 065", in: catalog, application: application)
    XCTAssertEqual(restoredFirst.identifier, firstIdentifier)
    XCTAssertTrue(
      waitForCompletion(completion(firstIdentifier, application: application), done: true))
    let restoredSecond = try revealActivity(
      "Window Activity 065", excluding: firstIdentifier, in: catalog, application: application)
    XCTAssertEqual(restoredSecond.identifier, secondIdentifier)
    XCTAssertTrue(
      waitForCompletion(completion(secondIdentifier, application: application), done: false))
    capture(
      application, "Repeated itinerary pages retain exact independent appearances after relaunch")
  }

  private func openRoute(_ title: String, application: XCUIApplication) {
    let ready = NSPredicate { _, _ in
      application.plannerElement("saved.section.lists").exists
        || application.plannerElement("Show Sidebar").exists
        || application.buttons["Lists"].firstMatch.exists
    }
    let readiness = XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: ready, object: application)], timeout: 45)
    if readiness != .completed {
      capture(application, "Itinerary fixture navigation readiness failure")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Itinerary fixture readiness hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertEqual(readiness, .completed)
    application.openPlannerSection("Itineraries")
    let route = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", title)
    ).firstMatch
    XCTAssertTrue(route.waitForExistence(timeout: 15))
    route.activateForPlannerJourney()
    XCTAssertTrue(
      application.plannerElement("saved.itinerary.entry.new").waitForExistence(timeout: 15))
  }

  private func activities(_ title: String, application: XCUIApplication) -> XCUIElementQuery {
    application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.", title))
  }

  private func revealActivity(
    _ title: String, excluding identifier: String? = nil, in catalog: XCUIElement,
    application: XCUIApplication
  ) throws -> XCUIElement {
    XCTAssertTrue(catalog.waitForExistence(timeout: 10))
    for _ in 0..<30 {
      if let row = activities(title, application: application).allElementsBoundByIndex.first(
        where: {
          $0.identifier != identifier && isFullyVisible($0, in: catalog, application: application)
        })
      {
        return row
      }
      catalog.swipeUp()
    }
    XCTFail("The next matching itinerary appearance did not become fully visible.")
    throw CancellationError()
  }

  private func revealFirstActivity(in catalog: XCUIElement, application: XCUIApplication) throws {
    let contentsReturned = catalog.waitForExistence(timeout: 15)
    if !contentsReturned {
      capture(application, "Itinerary boundary contents did not return after Back")
    }
    XCTAssertTrue(contentsReturned)
    for _ in 0..<40 {
      if let row = activities("Window Activity 001", application: application)
        .allElementsBoundByIndex.first(where: {
          isFullyVisible($0, in: catalog, application: application)
        })
      {
        let progress = application.staticTexts["1 of 132 items done"]
        if progress.exists && catalog.frame.contains(progress.frame)
          && row.identifier.split(separator: ".").count == 4
        {
          return
        }
      }
      catalog.swipeDown()
    }
    capture(application, "Itinerary boundary first-row visibility failure")
    let hierarchy = XCTAttachment(string: application.debugDescription)
    hierarchy.name = "Itinerary boundary first-row visibility hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    XCTFail("The direct first appearance and full itinerary progress did not return.")
    throw CancellationError()
  }

  private func isFullyVisible(
    _ row: XCUIElement, in catalog: XCUIElement, application: XCUIApplication
  ) -> Bool {
    row.exists && row.isHittable
      && visibleContentsFrame(catalog, application: application).contains(row.frame)
  }

  private func visibleContentsFrame(
    _ catalog: XCUIElement, application: XCUIApplication
  ) -> CGRect {
    let frame = catalog.frame
    #if os(iOS)
      let bars = application.navigationBars.allElementsBoundByIndex.filter {
        $0.frame.intersects(frame)
      }
      var topBoundary = bars.map(\.frame.maxY).max() ?? frame.minY
      let nameArea = application.scrollViews["saved.itinerary.heading"]
      if nameArea.exists { topBoundary = max(topBoundary, nameArea.frame.maxY) }
      let sectionTitle = application.staticTexts["Entries"]
      if sectionTitle.exists { topBoundary = max(topBoundary, sectionTitle.frame.maxY) }
      var bottomBoundary = frame.maxY
      let tabBar = application.tabBars.firstMatch
      if tabBar.exists, tabBar.frame.intersects(frame) { bottomBoundary = tabBar.frame.minY }
      return CGRect(
        x: frame.minX, y: topBoundary, width: frame.width,
        height: max(0, bottomBoundary - topBoundary))
    #else
      return frame
    #endif
  }

  private func completion(_ rowIdentifier: String, application: XCUIApplication) -> XCUIElement {
    application.plannerElement(
      rowIdentifier.replacingOccurrences(
        of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
  }

  private func waitForCompletion(_ control: XCUIElement, done: Bool) -> Bool {
    let action = done ? "undone" : "done"
    let expected = "Mark Window Activity 065 \(action) in this Itinerary"
    return XCTWaiter.wait(
      for: [
        XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "label == %@", expected), object: control)
      ], timeout: 15) == .completed
  }

  private func capture(_ application: XCUIApplication, _ name: String) {
    #if os(iOS)
      let screenshot = XCUIScreen.main.screenshot()
    #else
      let screenshot = application.windows.firstMatch.screenshot()
    #endif
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
