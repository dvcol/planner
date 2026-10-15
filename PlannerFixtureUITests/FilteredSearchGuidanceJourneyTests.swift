import XCTest

#if os(iOS)
  @MainActor
  final class FilteredSearchGuidanceJourneyTests: XCTestCase {
    func testItemsAndInboxExplainFilteredSearchWithoutChangingTheSource() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "address-retry", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      var sourceIdentifier: String?
      for section in ["Items", "Inbox"] {
        application.openPlannerSection(section)
        let row = application.savedPlannerItemRows("Retry place").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        if let sourceIdentifier {
          XCTAssertEqual(row.identifier, sourceIdentifier)
        } else {
          sourceIdentifier = row.identifier
        }
        let search = application.searchFields["Search \(section)"]
        if !search.exists {
          application.collectionViews.containing(
            NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.")
          ).firstMatch.swipeDown()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        replaceSearch("Retry place", in: search)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let filters = application.plannerElement("saved.\(section.lowercased()).filters")
        application.chooseSavedPlannerStateFilter("Done", control: filters)
        XCTAssertTrue(row.waitForNonExistence(timeout: 10))
        let guidance = application.staticTexts["Change the filters or try a different search."]
        let hasGuidance = guidance.waitForExistence(timeout: 5)
        capture("\(section) explains why an exact search has no filtered results")
        XCTAssertTrue(hasGuidance, application.debugDescription)
        application.chooseSavedPlannerStateFilter("Todo", control: filters)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.identifier, sourceIdentifier)
        XCTAssertTrue(guidance.waitForNonExistence(timeout: 5))
        application.chooseSavedPlannerStateFilter("All completion states", control: filters)
        application.chooseSavedPlannerStateFilter("All archive states", control: filters)
        XCTAssertEqual(filters.label, "All")
        replaceSearch("No matching place", in: search)
        XCTAssertTrue(row.waitForNonExistence(timeout: 10))
        XCTAssertTrue(
          application.staticTexts["Check the spelling or try a new search."]
            .waitForExistence(timeout: 5))
        XCTAssertFalse(guidance.exists)
        capture("\(section) keeps native search guidance when filters are unrestricted")
        replaceSearch("Retry place", in: search)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.identifier, sourceIdentifier)
        if application.keyboards.firstMatch.exists {
          search.typeText("\n")
          XCTAssertTrue(application.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        }
      }
      application.savedPlannerItemRows("Retry place").firstMatch.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Original notes"].waitForExistence(timeout: 10))
      let completion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let identity = XCTAttachment(
        string: "Unchanged Item in Items and Inbox: \(sourceIdentifier ?? "missing")")
      identity.name = "Filtered search observed source"
      identity.lifetime = .keepAlways
      add(identity)
    }

    private func replaceSearch(_ text: String, in search: XCUIElement) {
      search.activateForPlannerJourney()
      let clear = search.buttons["Clear text"]
      if clear.exists { clear.activateForPlannerJourney() }
      search.activateForPlannerJourney()
      search.typeText(text)
      XCTAssertTrue(search.waitForPlannerValue(text))
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
