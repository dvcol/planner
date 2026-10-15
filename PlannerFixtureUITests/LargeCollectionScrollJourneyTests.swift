import XCTest

#if os(iOS)
  @MainActor
  final class LargeCollectionScrollJourneyTests: XCTestCase {
    func testUnfilteredCatalogScrollsToBothEndsAndReopensTheSameSource() {
      continueAfterFailure = false
      print("XCTest Fast touch velocity: \(XCUIGestureVelocity.fast.rawValue)")
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 120))
      application.openPlannerSection("Items")
      let first = application.savedPlannerItemRows("Scale Item 00001").firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 30))
      XCTAssertTrue(first.isHittable)
      let firstIdentifier = first.identifier
      let contents = application.collectionViews.containing(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "saved.item.", "Scale Item ")
      ).firstMatch
      XCTAssertTrue(contents.waitForExistence(timeout: 15))
      capture("The unfiltered native catalog begins at Item 00001")
      contents.swipeUp()
      XCTAssertFalse(first.isHittable)
      let last = application.savedPlannerItemRows("Scale Item 05000").firstMatch
      scroll(contents, to: last, towardEnd: true)
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Unfiltered native catalog after scrolling toward its end"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      XCTAssertTrue(last.waitForExistence(timeout: 30))
      XCTAssertTrue(last.isHittable)
      let lastIdentifier = last.identifier
      capture("The unfiltered native catalog reaches Item 05000 without search")
      last.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Far-end collection marker"].waitForExistence(timeout: 10))
      let completion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      revealCatalog(application, contents: contents)
      XCTAssertTrue(last.exists && last.isHittable)
      scroll(contents, to: first, towardEnd: false)
      XCTAssertTrue(first.waitForExistence(timeout: 30))
      XCTAssertTrue(first.isHittable)
      XCTAssertEqual(first.identifier, firstIdentifier)
      capture("Returning to the beginning retains the first source identity")
      scroll(contents, to: last, towardEnd: true)
      XCTAssertTrue(last.waitForExistence(timeout: 30))
      XCTAssertTrue(last.isHittable)
      XCTAssertEqual(last.identifier, lastIdentifier)
      last.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Far-end collection marker"].waitForExistence(timeout: 10))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      let identities = XCTAttachment(
        string: "First source: \(firstIdentifier)\nLast source: \(lastIdentifier)")
      identities.name = "Unfiltered catalog observed endpoint identities"
      identities.lifetime = .keepAlways
      add(identities)
      capture("The far-end source reopens with the same notes and Todo state")
    }

    private func scroll(
      _ contents: XCUIElement, to target: XCUIElement, towardEnd: Bool
    ) {
      var previousTailTitle: String?
      for attempt in 1...1_000 {
        if target.exists && target.isHittable { return }
        if towardEnd {
          contents.swipeUp(velocity: .init(rawValue: 2_500))
        } else {
          contents.swipeDown(velocity: .init(rawValue: 2_500))
        }
        if attempt == 1 || attempt.isMultiple(of: 10) {
          let rows = contents.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Scale Item "))
          if let tailRow = rows.allElementsBoundByIndex.reversed().first(where: \.isHittable) {
            let tailTitle = tailRow.label
            if let previousTailTitle {
              XCTAssertNotEqual(
                tailTitle, previousTailTitle, "Native touch scrolling did not advance.")
            }
            previousTailTitle = tailTitle
            print("Catalog scroll attempt \(attempt): \(tailTitle)")
          }
        }
      }
      XCTFail("The unfiltered catalog did not expose \(target.label) after native touch scrolling.")
    }

    private func revealCatalog(_ application: XCUIApplication, contents: XCUIElement) {
      if contents.exists && contents.isHittable { return }
      let back = application.buttons["BackButton"].firstMatch
      if back.exists { back.activateForPlannerJourney() }
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
      XCTAssertTrue(contents.isHittable)
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
