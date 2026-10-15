import XCTest

#if os(iOS)
  @MainActor
  final class LargeCollectionJourneyTests: XCTestCase {
    func testSearchAndSortChangesRevisitStableSourcesInLargeNativeCatalog() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 120))
      application.openPlannerSection("Items")
      XCTAssertTrue(
        application.savedPlannerItemRows("Scale Item 00001").firstMatch
          .waitForExistence(timeout: 30))
      let search = application.searchFields["Search Items"]
      if !search.exists {
        application.collectionViews.containing(
          NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
        ).firstMatch.swipeDown()
      }
      XCTAssertTrue(search.waitForExistence(timeout: 10))
      replaceSearch("Scale Item", in: search)
      replaceSearch("Scale Item 04999", in: search)
      let earlier = requireSoleItem("Scale Item 04999", application: application)
      let earlierIdentifier = earlier.identifier
      earlier.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Scale notes 4999"].waitForExistence(timeout: 10))
      let completion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      capture("The replacement search opens the correct near-end source")
      returnToCatalog(search: search, application: application)
      replaceSearch("No scale match", in: search)
      replaceSearch("Scale Item 05000", in: search)
      let last = requireSoleItem("Scale Item 05000", application: application)
      let lastIdentifier = last.identifier
      XCTAssertFalse(earlier.exists)
      last.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Far-end collection marker"].waitForExistence(timeout: 10))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let showsSimultaneousDetail = search.isHittable
      returnToCatalog(search: search, application: application)
      let filters = application.plannerElement("saved.items.filters")
      application.chooseSavedPlannerStateFilter("Done", control: filters)
      XCTAssertTrue(last.waitForNonExistence(timeout: 30))
      if showsSimultaneousDetail {
        XCTAssertTrue(application.staticTexts["Far-end collection marker"].exists)
        XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      }
      capture("The Done filter hides a valid selected Todo source")
      application.chooseSavedPlannerStateFilter("Todo", control: filters)
      XCTAssertEqual(
        requireSoleItem("Scale Item 05000", application: application).identifier, lastIdentifier)
      replaceSearch("Scale Item 0499", in: search)
      let sort = application.plannerElement("saved.items.sort")
      chooseSort("Created", menu: sort, application: application)
      chooseSort("Descending", menu: sort, application: application)
      requireVisibleOrder(
        ["Scale Item 04998", "Scale Item 04997", "Scale Item 04999"],
        application: application)
      XCTAssertEqual(sort.label, "Sort: Created · Descending")
      capture("Created descending orders the filtered near-end sources in the large dataset")
      chooseSort("Title", menu: sort, application: application)
      chooseSort("Ascending", menu: sort, application: application)
      requireVisibleOrder(
        ["Scale Item 04997", "Scale Item 04998", "Scale Item 04999"], towardEnd: true,
        application: application)
      XCTAssertEqual(sort.label, "Sort: Title · Ascending")
      capture("Title ascending restores the filtered source order after changing native sort")
      replaceSearch("Scale Item 05000", in: search)
      XCTAssertEqual(
        requireSoleItem("Scale Item 05000", application: application).identifier, lastIdentifier)
      last.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Far-end collection marker"].waitForExistence(timeout: 10))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let identities = XCTAttachment(
        string:
          "Near-end source: \(earlierIdentifier)\nFar-end source: \(lastIdentifier)\nSimultaneous detail layout: \(showsSimultaneousDetail)"
      )
      identities.name = "Large-catalog query-change observed identities"
      identities.lifetime = .keepAlways
      add(identities)
      capture("The far-end search restores its original source and unchanged Todo state")
    }

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
      let displayedCompletion = completion.waitForPlannerBooleanState(true)
      if !displayedCompletion { capture("Large-collection completion did not settle") }
      XCTAssertTrue(displayedCompletion)
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
      XCTAssertTrue(application.staticTexts["1 of 25 items done"].waitForExistence(timeout: 30))
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
      let filters = application.plannerElement("saved.items.filters")
      XCTAssertTrue(filters.waitForExistence(timeout: 30))
      application.chooseSavedPlannerStateFilter(
        "All completion states", control: filters)
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

    private func replaceSearch(_ text: String, in search: XCUIElement) {
      XCTAssertTrue(search.waitForExistence(timeout: 10))
      search.activateForPlannerJourney()
      let clear = search.buttons["Clear text"]
      if clear.exists { clear.activateForPlannerJourney() }
      if !text.isEmpty {
        search.activateForPlannerJourney()
        search.typeText(text)
        XCTAssertTrue(search.waitForPlannerValue(text))
      }
    }

    private func requireSoleItem(_ title: String, application: XCUIApplication) -> XCUIElement {
      let row = application.savedPlannerItemRows(title).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 30))
      let rows = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
          "saved.item.", "Scale Item "))
      XCTAssertEqual(rows.count, 1)
      XCTAssertEqual(rows.firstMatch.identifier, row.identifier)
      return row
    }

    private func returnToCatalog(search: XCUIElement, application: XCUIApplication) {
      if !search.isHittable {
        application.plannerElement("BackButton").activateForPlannerJourney()
      }
      XCTAssertTrue(search.waitForPlannerHittability())
    }

    private func chooseSort(
      _ title: String, menu: XCUIElement, application: XCUIApplication
    ) {
      let option = application.plannerElement(title)
      if !option.exists {
        let isAvailable = menu.waitForExistence(timeout: 30)
        if !isAvailable { capture("Native Sort control unavailable after a query change") }
        XCTAssertTrue(isAvailable, application.debugDescription)
        XCTAssertTrue(menu.waitForPlannerHittability())
        menu.activateForPlannerJourney()
      }
      XCTAssertTrue(option.waitForExistence(timeout: 5))
      option.activateForPlannerJourney()
      if option.exists {
        application.searchFields["Search Items"].activateForPlannerJourney()
      }
    }

    private func requireVisibleOrder(
      _ titles: [String], towardEnd: Bool = false,
      application: XCUIApplication
    ) {
      let rows = titles.map { application.savedPlannerItemRows($0).firstMatch }
      let contents = application.collectionViews.containing(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
      ).firstMatch
      XCTAssertTrue(contents.waitForExistence(timeout: 30))
      let ordered = NSPredicate { _, _ in
        rows.allSatisfy { $0.exists && $0.isHittable }
          && zip(rows, rows.dropFirst()).allSatisfy { adjacentRows in
            adjacentRows.0.frame.midY < adjacentRows.1.frame.midY
          }
      }
      for _ in 0..<6 {
        if ordered.evaluate(with: contents) { break }
        if towardEnd {
          contents.swipeUp()
        } else {
          contents.swipeDown()
        }
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: ordered, object: contents)], timeout: 30),
        .completed)
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
      let foundLastItem = rows.firstMatch.waitForExistence(timeout: 30)
      if !foundLastItem { capture("Large-collection far-end search did not settle") }
      XCTAssertTrue(foundLastItem)
      XCTAssertEqual(rows.count, 1)
      let displayedItemRows = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
          "saved.item.", "Scale Item "))
      XCTAssertEqual(displayedItemRows.count, 1)
      XCTAssertEqual(displayedItemRows.firstMatch.identifier, rows.firstMatch.identifier)
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
