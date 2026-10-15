import XCTest

#if os(iOS)
  @MainActor
  final class LargeCollectionJourneyTests: XCTestCase {
    func testFiveThousandItemsAndTwoHundredListsKeepFarEndSearchAndCompletionAfterRelaunch() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 120))
      application.openPlannerSection("Items")
      let firstItem = application.savedPlannerItemRows("Scale Item 00001").firstMatch
      XCTAssertTrue(firstItem.waitForExistence(timeout: 30))
      capture("The large native catalog opens at the first of five thousand Items")
      let lastItem = searchForLastItem(application)
      let itemIdentifier = lastItem.identifier
      lastItem.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Far-end collection marker"].waitForExistence(timeout: 10))
      let completion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      completion.switches.firstMatch.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerBooleanState(true))
      capture("The sole far-end match keeps its selected detail after global completion")
      application.openPlannerSection("Lists")
      openListCatalog(application)
      let lastList = application.savedPlannerListRow("Scale List 200")
      let listCatalog = application.collectionViews.containing(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.list.")
      ).firstMatch
      XCTAssertTrue(listCatalog.waitForExistence(timeout: 15))
      reveal(lastList, in: listCatalog)
      let listIdentifier = lastList.identifier
      lastList.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["1 of 25 items finished"].waitForExistence(timeout: 30))
      application.chooseSavedPlannerStateFilter(
        "All completion states", control: application.plannerElement("saved.list.filters"))
      let appearance = application.savedPlannerItemRows("Scale Item 05000").firstMatch
      let contents = application.collectionViews.containing(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.appearance.")
      ).firstMatch
      XCTAssertTrue(contents.waitForExistence(timeout: 15))
      reveal(appearance, in: contents)
      let appearanceIdentifier = appearance.identifier
      let appearanceCompletion = application.plannerElement(
        appearanceIdentifier.replacingOccurrences(
          of: "saved.appearance.", with: "saved.appearance.completion."))
      XCTAssertTrue(appearanceCompletion.waitForPlannerValue("Completed"))
      capture("The two-hundredth List retains its twenty-five live Item references")
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 120))
      application.openPlannerSection("Items")
      application.chooseSavedPlannerStateFilter(
        "All completion states", control: application.plannerElement("saved.items.filters"))
      let reopened = searchForLastItem(application)
      XCTAssertEqual(reopened.identifier, itemIdentifier)
      reopened.activateForPlannerJourney()
      XCTAssertTrue(completion.waitForPlannerBooleanState(true))
      XCTAssertTrue(application.staticTexts["Far-end collection marker"].exists)
      capture("The far-end source identity and completion survive large-dataset relaunch")
      let identities = XCTAttachment(
        string:
          "Item: \(itemIdentifier)\nList: \(listIdentifier)\nAppearance: \(appearanceIdentifier)\nItems: 5000\nLists: 200\nMemberships per List: 25"
      )
      identities.name = "Native large-collection observed identities"
      identities.lifetime = .keepAlways
      add(identities)
    }

    private func searchForLastItem(_ application: XCUIApplication) -> XCUIElement {
      let search = application.searchFields["Search Items"]
      if !search.exists {
        application.collectionViews.containing(
          NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
        ).firstMatch.swipeDown()
      }
      XCTAssertTrue(search.waitForExistence(timeout: 10))
      search.activateForPlannerJourney()
      let clear = search.buttons["Clear text"]
      if clear.exists { clear.activateForPlannerJourney() }
      search.typeText("Scale Item 05000")
      let rows = application.savedPlannerItemRows("Scale Item 05000")
      XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 30))
      XCTAssertEqual(rows.count, 1)
      return rows.firstMatch
    }

    private func openListCatalog(_ application: XCUIApplication) {
      let back = application.navigationBars.buttons["Lists"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      XCTAssertTrue(application.plannerElement("saved.list.new").waitForExistence(timeout: 15))
    }

    private func reveal(_ element: XCUIElement, in container: XCUIElement) {
      for _ in 0..<40 {
        if element.exists && element.isHittable && container.frame.contains(element.frame) {
          return
        }
        container.swipeUp()
      }
      XCTFail("The requested far-end row did not become visible.")
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
