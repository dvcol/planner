import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  final class ListWindowJourneyTests: XCTestCase {
    func testItineraryPickerKeepsAnOffscreenItemSelectionAndItsEntryAfterRelaunch() {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "list-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openItinerary(application)
      XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 15))
      application.plannerElement("saved.itinerary.entry.new").activateForPlannerJourney()
      let choices = application.collectionViews["saved.itinerary.entry.choices"]
      XCTAssertTrue(choices.waitForExistence(timeout: 10))
      let navigationBar = application.navigationBars["Add to Itinerary"]
      XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
      let topBoundary = navigationBar.frame.maxY
      let itemChoiceIdentifierPrefix = "saved.itinerary.entry.choice.item."
      for title in ["Window Item 065", "Window Item 129"] {
        scrollPicker(
          choices, to: title, topBoundary: topBoundary,
          choiceIdentifierPrefix: itemChoiceIdentifierPrefix)
      }
      let selected = choices.staticTexts["Window Item 129"].firstMatch
      capture("Itinerary Item picker source is fully visible before selection")
      selected.activateForPlannerJourney()
      let add = application.plannerElement("saved.itinerary.entry.add")
      let enabled = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"), object: add)
      XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
      scrollPicker(
        choices, to: "Window Item 001", topBoundary: topBoundary,
        choiceIdentifierPrefix: itemChoiceIdentifierPrefix)
      XCTAssertTrue(add.isEnabled)
      capture("Itinerary Item picker retains an offscreen selected source")
      add.activateForPlannerJourney()
      XCTAssertTrue(choices.waitForNonExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))
      let appearance = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.appearance.",
          "Window Item 129")
      ).firstMatch
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      let identifier = appearance.identifier
      let completion = application.buttons[
        identifier.replacingOccurrences(
          of: "saved.itinerary.appearance.", with: "saved.itinerary.completion.")]
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      appearance.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Window notes 129"].waitForExistence(timeout: 10))
      capture("Itinerary Item picker adds its exact source into the original plan")
      application.terminate()
      application.launchSavedPlannerJourney()
      openItinerary(application)
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 10))
      XCTAssertEqual(appearance.identifier, identifier)
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      capture("Itinerary Item picker preserves its entry after relaunch")
    }

    func testAddingAnOffscreenPickerSelectionKeepsItsSourceAndOriginalListAfterRelaunch() {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "list-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openList(application, title: "Shared Item List")
      XCTAssertTrue(application.staticTexts["0 of 1 item done"].waitForExistence(timeout: 15))
      application.openSavedPlannerListAddMenu()
      application.plannerElement("saved.list.add").activateForPlannerJourney()
      let choices = application.collectionViews["saved.membership.choices"]
      XCTAssertTrue(choices.waitForExistence(timeout: 10))
      let navigationBar = application.navigationBars["Add to Shared Item List"]
      XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
      let topBoundary = navigationBar.frame.maxY
      let first = choices.staticTexts["Window Item 001"].firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 15))
      for title in ["Window Item 065", "Window Item 129"] {
        let choice = choices.staticTexts[title].firstMatch
        scrollPicker(choices, to: title, topBoundary: topBoundary)
        XCTAssertTrue(choice.waitForExistence(timeout: 10))
      }
      let selected = choices.staticTexts["Window Item 129"].firstMatch
      capture("Item picker source is fully visible before selection")
      selected.activateForPlannerJourney()
      let add = application.plannerElement("saved.membership.add")
      let enabled = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"), object: add)
      XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
      scrollPicker(choices, to: "Window Item 193", topBoundary: topBoundary)
      scrollPicker(choices, to: "Window Item 001", topBoundary: topBoundary)
      XCTAssertTrue(add.isEnabled)
      capture("Item picker retains a selected source after revisiting its first page")
      add.activateForPlannerJourney()
      XCTAssertTrue(choices.waitForNonExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["0 of 2 items done"].waitForExistence(timeout: 10))
      let appearance = application.savedPlannerItemRows("Window Item 129").firstMatch
      XCTAssertTrue(appearance.waitForExistence(timeout: 10))
      let identifier = appearance.identifier
      let completion = application.buttons[
        identifier.replacingOccurrences(
          of: "saved.appearance.", with: "saved.appearance.completion.")]
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      appearance.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Window notes 129"].waitForExistence(timeout: 10))
      XCTAssertTrue(application.staticTexts["In Shared Item List"].exists)
      capture("Item picker adds its selected source to the original List")
      application.terminate()
      application.launchSavedPlannerJourney()
      openList(application, title: "Shared Item List")
      XCTAssertTrue(application.staticTexts["0 of 2 items done"].waitForExistence(timeout: 10))
      XCTAssertEqual(appearance.identifier, identifier)
      XCTAssertTrue(completion.waitForPlannerValue("To do"))
      capture("Item picker preserves its added appearance after relaunch")
    }

    func testCompletingAVisibleItemKeepsItsListSelectedDuringRefresh() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "list-windows", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openList(application)
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
      openList(application)
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
      openList(application)
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
      openList(application)
      XCTAssertTrue(application.staticTexts["1 of 193 items done"].waitForExistence(timeout: 10))
      scroll(contents, to: last, towardEnd: true)
      XCTAssertEqual(last.identifier, lastIdentifier)
      XCTAssertTrue(completion.waitForPlannerValue("Completed"))
      capture("Windowed List preserves membership identity and completion after relaunch")
    }

    private func openList(_ application: XCUIApplication, title: String = "Window Route") {
      let route = application.savedPlannerListRow(title)
      if !route.waitForExistence(timeout: 3) || !route.isHittable {
        let sidebar = application.buttons["Show Sidebar"].firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        sidebar.activateForPlannerJourney()
      }
      XCTAssertTrue(route.waitForExistence(timeout: 30))
      route.activateForPlannerJourney()
    }

    private func openItinerary(_ application: XCUIApplication) {
      if UIDevice.current.userInterfaceIdiom == .pad {
        let section = application.plannerElement("saved.section.itineraries")
        if !section.waitForExistence(timeout: 2) {
          let sidebar = application.buttons["Show Sidebar"].firstMatch
          XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
          sidebar.activateForPlannerJourney()
        }
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        section.activateForPlannerJourney()
      } else {
        application.openPlannerSection("Itineraries")
      }
      let itinerary = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.itinerary.row.", "Picker Route"
        )
      ).firstMatch
      XCTAssertTrue(itinerary.waitForExistence(timeout: 15))
      itinerary.activateForPlannerJourney()
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

    /// Use visible fixture ordinals to recover when a native fling overshoots an unmaterialized row.
    private func scrollPicker(
      _ choices: XCUIElement, to title: String, topBoundary: CGFloat,
      choiceIdentifierPrefix: String = "saved.membership.choice.item."
    ) {
      guard let targetOrdinal = Int(title.suffix(3)) else {
        XCTFail("The fixture choice must have an Item ordinal.")
        return
      }
      let target = choices.staticTexts[title].firstMatch
      for _ in 0..<150 {
        let viewport = choices.frame
        let visibleTop = max(topBoundary, viewport.minY)
        if target.exists {
          let frame = target.frame
          if target.isHittable, frame.minY >= visibleTop, frame.maxY <= viewport.maxY {
            return
          }
          if !frame.isEmpty {
            let movesDown = frame.midY > (visibleTop + viewport.maxY) / 2
            let origin = choices.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            let destination = choices.coordinate(
              withNormalizedOffset: .init(dx: 0.5, dy: movesDown ? 0.2 : 0.8))
            origin.press(
              forDuration: 0.05, thenDragTo: destination, withVelocity: .init(rawValue: 300),
              thenHoldForDuration: 0.2)
            continue
          }
        }
        let visibleOrdinals = choices.staticTexts.matching(
          NSPredicate(format: "identifier BEGINSWITH %@", choiceIdentifierPrefix)
        ).allElementsBoundByIndex.compactMap { element -> Int? in
          let frame = element.frame
          guard frame.minY >= visibleTop, frame.maxY <= viewport.maxY else { return nil }
          return Int(element.label.suffix(3))
        }
        guard let firstOrdinal = visibleOrdinals.min() else {
          _ = target.waitForExistence(timeout: 1)
          continue
        }
        if firstOrdinal > targetOrdinal {
          choices.swipeDown(velocity: .init(rawValue: 600))
        } else {
          choices.swipeUp(velocity: .init(rawValue: 600))
        }
      }
      XCTFail("Native Item picker did not expose \(title) below its navigation bar.")
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
