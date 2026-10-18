import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class ListWindowJourneyTests: XCTestCase {
    func testCompletingAVisibleItemKeepsItsListSelectedDuringRefresh() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "list-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openRoute(application)
      let first = application.savedPlannerItemRows("Window Item 001").firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 15))
      let identifier = first.identifier
      let completion = application.buttons[
        identifier.replacingOccurrences(
          of: "saved.appearance.", with: "saved.appearance.completion.")]
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      completion.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      XCTAssertEqual(first.identifier, identifier)
      XCTAssertTrue(application.staticTexts["1 of 193 items done"].waitForExistence(timeout: 10))
      capture("Windowed List keeps its selected container after first-row completion")
    }

    func testCompletingALaterPageItemKeepsItsControlVisibleAfterRefresh() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "list-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openRoute(application)
      let contents = application.collectionViews["saved.list.contents"]
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
      let item = application.savedPlannerItemRows("Window Item 193").firstMatch
      scroll(contents, to: item, towardEnd: true)
      let identifier = item.identifier
      let completion = application.buttons[
        identifier.replacingOccurrences(
          of: "saved.appearance.", with: "saved.appearance.completion.")]
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      completion.activateForPlannerJourney()
      let completed = completion.waitForPlannerValue("Completed")
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Released-page completion result hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      capture("Released-page completion result viewport")
      XCTAssertTrue(completed)
      XCTAssertTrue(completion.waitForPlannerHittability())
      XCTAssertEqual(item.identifier, identifier)
      capture("Windowed List keeps its selected container after a released-page completion")
    }

    func testListCrossesPagesRevisitsMembershipsAndKeepsLocalCompletionAfterRelaunch() {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "list-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openRoute(application)
      XCTAssertTrue(application.staticTexts["0 of 193 items done"].waitForExistence(timeout: 30))
      let first = application.savedPlannerItemRows("Window Item 001").firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 15))
      let firstIdentifier = first.identifier
      let contents = application.collectionViews["saved.list.contents"]
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
      for title in ["Window Item 065", "Window Item 129", "Window Item 193"] {
        let row = application.savedPlannerItemRows(title).firstMatch
        scroll(contents, to: row, towardEnd: true)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.isHittable)
        capture("Windowed List reaches \(title)")
      }
      let last = application.savedPlannerItemRows("Window Item 193").firstMatch
      let lastIdentifier = last.identifier
      let completionIdentifier = lastIdentifier.replacingOccurrences(
        of: "saved.appearance.", with: "saved.appearance.completion.")
      let completion = application.buttons[completionIdentifier]
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      completion.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      last.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Window notes 193"].waitForExistence(timeout: 10))
      revealContents(application, contents: contents)
      scroll(contents, to: first, towardEnd: false)
      XCTAssertEqual(first.identifier, firstIdentifier)
      XCTAssertTrue(application.staticTexts["1 of 193 items done"].waitForExistence(timeout: 10))
      capture("Windowed List revisits its first membership with full progress")
      scroll(contents, to: last, towardEnd: true)
      XCTAssertEqual(last.identifier, lastIdentifier)
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      capture("Windowed List rereads the same completed final membership")
      application.terminate()
      application.launchSavedPlannerJourney()
      openRoute(application)
      XCTAssertTrue(application.staticTexts["1 of 193 items done"].waitForExistence(timeout: 10))
      scroll(contents, to: last, towardEnd: true)
      XCTAssertEqual(last.identifier, lastIdentifier)
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      capture("Windowed List preserves membership identity and completion after relaunch")
    }

    private func openRoute(_ application: XCUIApplication) {
      let route = application.savedPlannerListRow("Window Route")
      if !route.waitForExistence(timeout: 3) || !route.isHittable {
        let sidebar = application.buttons["Show Sidebar"].firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        sidebar.activateForPlannerJourney()
      }
      XCTAssertTrue(route.waitForExistence(timeout: 30))
      route.activateForPlannerJourney()
    }

    private func revealContents(_ application: XCUIApplication, contents: XCUIElement) {
      if contents.exists {
        let rows = contents.buttons.matching(
          NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
            "saved.appearance.", "Window Item "))
        if rows.allElementsBoundByIndex.contains(where: \.isHittable) { return }
      }
      let back = application.buttons["BackButton"].firstMatch
      XCTAssertTrue(back.waitForExistence(timeout: 5))
      back.activateForPlannerJourney()
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
    }

    private func scroll(_ contents: XCUIElement, to target: XCUIElement, towardEnd: Bool) {
      for _ in 0..<150 {
        if target.exists && target.isHittable { return }
        if target.exists && !target.frame.isEmpty {
          let movesDown = target.frame.midY > contents.frame.midY
          let origin = contents.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
          let destination = contents.coordinate(
            withNormalizedOffset: .init(dx: 0.5, dy: movesDown ? 0.2 : 0.8))
          origin.press(
            forDuration: 0.05, thenDragTo: destination, withVelocity: .init(rawValue: 300),
            thenHoldForDuration: 0.2)
        } else if towardEnd {
          contents.swipeUp(velocity: .init(rawValue: 1_500))
        } else {
          contents.swipeDown(velocity: .init(rawValue: 1_500))
        }
      }
      XCTFail("Native List did not expose the requested membership.")
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
