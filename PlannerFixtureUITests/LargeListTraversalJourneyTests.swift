import XCTest

#if os(iOS)
  @MainActor
  final class LargeListTraversalJourneyTests: XCTestCase {
    func testEveryListCanBeTraversedInBothDirectionsWithoutChangingItsIdentity() {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Lists"].firstMatch.waitForExistence(timeout: 120))
      application.openPlannerSection("Lists")
      let first = application.savedPlannerListRow("Scale List 001")
      let last = application.savedPlannerListRow("Scale List 200")
      XCTAssertTrue(first.waitForExistence(timeout: 30))
      let catalog = application.collectionViews.containing(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
          "saved.list.", "Scale List ")
      ).firstMatch
      XCTAssertTrue(catalog.waitForExistence(timeout: 15))
      capture("The two-hundred-List catalog begins at Scale List 001")
      var forwardIdentities: [String: String] = [:]
      traverse(catalog, to: last, towardEnd: true, identities: &forwardIdentities)
      let expectedTitles = Set((1...200).map { String(format: "Scale List %03d", $0) })
      XCTAssertEqual(Set(forwardIdentities.keys), expectedTitles)
      XCTAssertEqual(Set(forwardIdentities.values).count, 200)
      capture("Every List identity has been observed while reaching Scale List 200")
      last.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["0 of 25 items done"].waitForExistence(timeout: 30))
      XCTAssertTrue(
        application.savedPlannerItemRows("Scale Item 00200").firstMatch
          .waitForExistence(timeout: 15))
      capture("Scale List 200 opens its expected live children")
      if !catalog.exists || !catalog.isHittable {
        let back = application.buttons["BackButton"].firstMatch
        let sidebar = application.buttons["Show Sidebar"].firstMatch
        if back.exists && back.isHittable {
          back.activateForPlannerJourney()
        } else {
          XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
          sidebar.activateForPlannerJourney()
        }
      }
      XCTAssertTrue(catalog.waitForExistence(timeout: 10))
      XCTAssertTrue(last.isHittable)
      var backwardIdentities: [String: String] = [:]
      traverse(catalog, to: first, towardEnd: false, identities: &backwardIdentities)
      XCTAssertEqual(backwardIdentities, forwardIdentities)
      capture("Returning through every List retains all two hundred source identities")
      first.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["0 of 25 items done"].waitForExistence(timeout: 30))
      XCTAssertTrue(
        application.savedPlannerItemRows("Scale Item 00001").firstMatch
          .waitForExistence(timeout: 15))
      let observed = XCTAttachment(
        string: forwardIdentities.sorted { $0.key < $1.key }.map { entry in
          "\(entry.key): \(entry.value)"
        }.joined(separator: "\n"))
      observed.name = "Two hundred List identities observed in both traversal directions"
      observed.lifetime = .keepAlways
      add(observed)
      capture("Scale List 001 reopens its expected live children after traversal")
    }

    private func traverse(
      _ catalog: XCUIElement, to target: XCUIElement, towardEnd: Bool,
      identities: inout [String: String]
    ) {
      var previousTail: String?
      for attempt in 0...200 {
        let catalogFrame = catalog.frame
        let visibleRows = catalog.buttons.matching(
          NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
            "saved.list.", "Scale List ")
        ).allElementsBoundByIndex.compactMap {
          row -> (title: String, identity: String, verticalPosition: CGFloat)? in
          guard row.isHittable else { return nil }
          let rowFrame = row.frame
          guard catalogFrame.contains(rowFrame) else { return nil }
          return (row.label, row.identifier, rowFrame.midY)
        }.sorted { $0.verticalPosition < $1.verticalPosition }
        let titles = visibleRows.map(\.title)
        XCTAssertEqual(titles, titles.sorted())
        for row in visibleRows {
          let title = row.title
          let identity = row.identity
          if let previous = identities[title] { XCTAssertEqual(identity, previous) }
          identities[title] = identity
        }
        if target.exists && target.isHittable && catalogFrame.contains(target.frame) { return }
        if attempt.isMultiple(of: 5), let tail = titles.last {
          if let previousTail {
            XCTAssertNotEqual(tail, previousTail, "Native List traversal did not advance.")
          }
          previousTail = tail
          print(
            "List traversal attempt \(attempt), toward end \(towardEnd): \(identities.count) identities"
          )
        }
        let startFraction = towardEnd ? 0.72 : 0.42
        let endFraction = towardEnd ? 0.42 : 0.72
        catalog.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startFraction))
          .press(
            forDuration: 0.05,
            thenDragTo: catalog.coordinate(
              withNormalizedOffset: CGVector(dx: 0.5, dy: endFraction)))
      }
      XCTFail("Native List traversal did not reach \(target.label).")
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
