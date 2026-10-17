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

    func testCatalogCrossesPageBoundariesAndKeepsSelectionAcrossRotation() throws {
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 120))
      application.openPlannerSection("Items")
      let first = application.savedPlannerItemRows("Scale Item 00001").firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 30))
      let firstIdentifier = first.identifier
      let completion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      let contents = application.collectionViews.containing(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "saved.item.", "Scale Item ")
      ).firstMatch
      first.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Scale notes 1"].waitForExistence(timeout: 10))
      revealCatalog(application, contents: contents)
      let retainsSimultaneousDetail = application.staticTexts["Scale notes 1"].isHittable
      let observedLayout = XCTAttachment(
        string:
          "First source: \(firstIdentifier)\nSimultaneous detail layout: \(retainsSimultaneousDetail)"
      )
      observedLayout.name = "Native Item window observed source and layout"
      observedLayout.lifetime = .keepAlways
      add(observedLayout)
      for title in ["Scale Item 00065", "Scale Item 00129"] {
        let intermediate = application.savedPlannerItemRows(title).firstMatch
        scroll(contents, to: intermediate, towardEnd: true, maximumVelocity: 300)
        XCTAssertTrue(intermediate.waitForExistence(timeout: 30))
        XCTAssertTrue(intermediate.isHittable)
        if retainsSimultaneousDetail {
          XCTAssertTrue(application.staticTexts["Scale notes 1"].isHittable)
          XCTAssertTrue(completion.exists)
        }
        capture("Native catalog crosses the page boundary at \(title)")
      }
      rotate(.landscapeLeft, application: application)
      if retainsSimultaneousDetail {
        XCTAssertTrue(application.staticTexts["Scale notes 1"].waitForPlannerHittability())
        XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      }
      let visibleRows = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "saved.item.", "Scale Item ")
      ).allElementsBoundByIndex.filter(\.isHittable)
      XCTAssertFalse(visibleRows.isEmpty)
      let landscapeRow = visibleRows[visibleRows.count / 2]
      let landscapeNumber = try XCTUnwrap(Int(landscapeRow.label.dropFirst("Scale Item ".count)))
      let landscapeNotes = "Scale notes \(landscapeNumber)"
      landscapeRow.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts[landscapeNotes].waitForPlannerHittability())
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      capture("Windowed native catalog selects its visible source in landscape")
      rotate(.portrait, application: application)
      XCTAssertTrue(application.staticTexts[landscapeNotes].waitForPlannerHittability())
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      revealCatalog(application, contents: contents)
      scroll(contents, to: first, towardEnd: false)
      XCTAssertTrue(first.waitForExistence(timeout: 30))
      XCTAssertTrue(first.isHittable)
      XCTAssertEqual(first.identifier, firstIdentifier)
      first.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Scale notes 1"].waitForExistence(timeout: 10))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      capture("Released first page reopens its original source after rotation")
    }

    private func rotate(_ orientation: UIDeviceOrientation, application: XCUIApplication) {
      XCUIDevice.shared.orientation = orientation
      let window = application.windows.firstMatch
      let expectedLayout = NSPredicate { _, _ in
        let frame = window.frame
        return (frame.width > frame.height) == orientation.isLandscape
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: expectedLayout, object: window)], timeout: 10),
        .completed)
    }

    private func scroll(
      _ contents: XCUIElement, to target: XCUIElement, towardEnd: Bool,
      maximumVelocity: Double = 2_500
    ) {
      var previousTailTitle: String?
      for attempt in 1...1_000 {
        let targetExists = target.exists
        if targetExists && target.isHittable { return }
        var moveTowardEnd = towardEnd
        var velocity = maximumVelocity
        if targetExists {
          let targetFrame = target.frame
          if !targetFrame.isEmpty {
            moveTowardEnd = targetFrame.midY > contents.frame.midY
            velocity = 300
          }
        }
        if velocity <= 300 {
          let origin = contents.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
          let destinationY = moveTowardEnd ? 0.2 : 0.8
          let destination = contents.coordinate(
            withNormalizedOffset: .init(dx: 0.5, dy: destinationY))
          origin.press(
            forDuration: 0.05, thenDragTo: destination, withVelocity: .init(rawValue: velocity),
            thenHoldForDuration: 0.2)
        } else if moveTowardEnd {
          contents.swipeUp(velocity: .init(rawValue: velocity))
        } else {
          contents.swipeDown(velocity: .init(rawValue: velocity))
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
