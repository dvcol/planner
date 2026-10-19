import XCTest

#if os(iOS)
  import ImageIO
  import UIKit

  @MainActor
  final class LargeCollectionScrollJourneyTests: XCTestCase {
    func testVisibleRowsStayPaintedWhenSelectionScrollsOffscreen() throws {
      continueAfterFailure = false
      guard UIDevice.current.userInterfaceIdiom == .pad else {
        throw XCTSkip("This diagnostic requires the simultaneous iPad catalog/detail layout.")
      }
      XCUIDevice.shared.orientation = .portrait
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openCatalog(application)
      let first = application.savedPlannerItemRows("Scale Item 00001").firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 30))
      let catalog = application.collectionViews["saved.items.catalog"].firstMatch
      first.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Scale notes 1"].waitForExistence(timeout: 10))
      revealCatalog(application, contents: catalog)
      let control = try visiblePaintSample(in: catalog)
      let controlPaint = try rowPaint(
        in: control.frame, application: application, screenshot: XCUIScreen.main.screenshot())
      let controlObservation = XCTAttachment(
        string: "Source: \(control.label)\nFrame: \(control.frame)\nPaint: \(controlPaint)")
      controlObservation.name = "Native row paint positive control"
      controlObservation.lifetime = .keepAlways
      add(controlObservation)
      guard controlPaint.dark > controlPaint.total / 2 else {
        throw XCTSkip("Run this native paint diagnostic with dark appearance.")
      }
      XCTAssertGreaterThan(controlPaint.bright, 20)
      let last = application.savedPlannerItemRows("Scale Item 05000").firstMatch
      for attempt in 0..<4 {
        if last.exists && last.isHittable && catalog.frame.contains(last.frame) { break }
        let pointerTarget = try visiblePaintSample(in: catalog)
        pointerTarget.scroll(byDeltaX: 0, deltaY: 500_000)
        let snapshot = try catalog.snapshot()
        let rows = visibleItemSnapshots(snapshot, within: snapshot.frame)
          .filter { $0.elementType == .button }.sorted { $0.frame.midY < $1.frame.midY }
        print("Row paint pointer-scroll attempt \(attempt): \(rows.last?.label ?? "no source")")
      }
      XCTAssertTrue(last.exists && last.isHittable)
      for _ in 0..<12 {
        catalog.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.42))
          .press(
            forDuration: 0.05,
            thenDragTo: catalog.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.72)))
      }
      XCTAssertFalse(last.isHittable)
      for attempt in 0..<40 {
        if last.exists && last.isHittable && catalog.frame.contains(last.frame) { break }
        catalog.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.72))
          .press(
            forDuration: 0.05,
            thenDragTo: catalog.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.42)))
        if attempt.isMultiple(of: 10) { print("Row paint touch-return attempt \(attempt)") }
      }
      let checkpoint = capture("Row paint fast-scroll controller checkpoint")
      let hierarchy = XCTAttachment(string: catalog.debugDescription)
      hierarchy.name = "Row paint native catalog after fast scrolling"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      XCTAssertTrue(last.exists && last.isHittable, catalog.debugDescription)
      XCTAssertTrue(application.staticTexts["Scale notes 1"].isHittable)
      let sample = try visiblePaintSample(in: catalog)
      let sampleTitle = sample.label
      let sampleIdentifier = sample.identifier
      let sampleFrame = sample.frame
      capture("Row paint with the original source selected offscreen")
      let initial = try rowPaint(
        in: sampleFrame, application: application, screenshot: checkpoint)
      var settled = initial
      let painted = NSPredicate { _, _ in
        guard
          let current = try? self.rowPaint(
            in: sampleFrame, application: application, screenshot: XCUIScreen.main.screenshot())
        else {
          return false
        }
        settled = current
        return current.bright > 20
      }
      let outcome = XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: painted, object: sample)], timeout: 5)
      let observation = XCTAttachment(
        string:
          "Source: \(sampleTitle)\nIdentity: \(sampleIdentifier)\nFrame: \(sampleFrame)\nInitial: \(initial)\nSettled: \(settled)\nPaint wait: \(outcome.rawValue)"
      )
      observation.name = "Unselected native row paint observation"
      observation.lifetime = .keepAlways
      add(observation)
      capture("Row paint after waiting without changing selection")
      XCTAssertGreaterThan(initial.dark, initial.total / 2, "Run this diagnostic in dark mode.")
      XCTAssertEqual(outcome, .completed, "The visible source title must paint without a tap.")
      XCTAssertEqual(sample.identifier, sampleIdentifier)
      XCTAssertEqual(sample.label, sampleTitle)
      XCTAssertTrue(application.staticTexts["Scale notes 1"].isHittable)
    }

    private func visiblePaintSample(in catalog: XCUIElement) throws -> XCUIElement {
      let viewport = catalog.frame
      let visibleSources = catalog.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "saved.item.", "Scale Item ")
      ).allElementsBoundByIndex.filter {
        $0.isHittable && viewport.contains($0.frame)
      }.sorted { $0.frame.midY < $1.frame.midY }
      guard visibleSources.count > 3 else {
        XCTFail("The native catalog must expose enough source rows for an unselected sample.")
        throw CancellationError()
      }
      return visibleSources[visibleSources.count / 2]
    }

    private func rowPaint(
      in frame: CGRect, application: XCUIApplication, screenshot: XCUIScreenshot
    ) throws -> (
      bright: Int, dark: Int, total: Int
    ) {
      guard let source = CGImageSourceCreateWithData(screenshot.pngRepresentation as CFData, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
      else { throw CocoaError(.fileReadCorruptFile) }
      let windowFrame = application.windows.firstMatch.frame
      let scale = CGFloat(image.width) / windowFrame.width
      let region = CGRect(
        x: (frame.minX - windowFrame.minX) * scale,
        y: (frame.minY - windowFrame.minY) * scale,
        width: frame.width * scale, height: frame.height * scale
      ).integral
      guard let cropped = image.cropping(to: region), cropped.width > 0, cropped.height > 0 else {
        throw CocoaError(.fileReadCorruptFile)
      }
      var pixels = [UInt8](repeating: 0, count: cropped.width * cropped.height * 4)
      let drawn = pixels.withUnsafeMutableBytes { buffer in
        guard
          let context = CGContext(
            data: buffer.baseAddress, width: cropped.width, height: cropped.height,
            bitsPerComponent: 8, bytesPerRow: cropped.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return false }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        return true
      }
      guard drawn else { throw CocoaError(.fileReadCorruptFile) }
      var bright = 0
      var dark = 0
      for offset in stride(from: 0, to: pixels.count, by: 4) {
        if pixels[offset] > 230 && pixels[offset + 1] > 230 && pixels[offset + 2] > 230 {
          bright += 1
        }
        if pixels[offset] < 38 && pixels[offset + 1] < 38 && pixels[offset + 2] < 38 { dark += 1 }
      }
      return (bright, dark, cropped.width * cropped.height)
    }

    func testEveryItemCanBeObservedThroughTheUnfilteredNativeCatalog() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openCatalog(application)
      let first = application.savedPlannerItemRows("Scale Item 00001").firstMatch
      XCTAssertTrue(first.waitForExistence(timeout: 30))
      let catalog = application.collectionViews.containing(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "saved.item.", "Scale Item ")
      ).firstMatch
      XCTAssertTrue(catalog.waitForExistence(timeout: 15))
      let expectedTitles = Set((1...5000).map { String(format: "Scale Item %05d", $0) })
      var observedIdentifiersByTitle: [String: String] = [:]
      first.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["Scale notes 1"].waitForExistence(timeout: 10))
      let completion = application.descendants(matching: .any).matching(
        identifier: "saved.item.completion"
      ).firstMatch
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      revealCatalog(application, contents: catalog)
      XCTAssertTrue(first.waitForExistence(timeout: 10))
      XCTAssertTrue(first.isHittable)
      capture("Every Item traversal begins with the unfiltered first source")
      let last = application.savedPlannerItemRows("Scale Item 05000").firstMatch
      for attempt in 0...5000 {
        var snapshot = try catalog.snapshot()
        var rows = visibleItemSnapshots(snapshot, within: snapshot.frame)
        if rows.contains(where: { $0.elementType == .progressIndicator }) {
          let loaded = NSPredicate { _, _ in
            guard let current = try? catalog.snapshot() else { return false }
            return !self.visibleItemSnapshots(current, within: current.frame).contains {
              $0.elementType == .progressIndicator
            }
          }
          XCTAssertEqual(
            XCTWaiter.wait(
              for: [XCTNSPredicateExpectation(predicate: loaded, object: catalog)], timeout: 10),
            .completed)
          snapshot = try catalog.snapshot()
          rows = visibleItemSnapshots(snapshot, within: snapshot.frame)
        }
        let sourceRows = rows.filter { $0.elementType == .button }.sorted {
          $0.frame.midY < $1.frame.midY
        }
        let titles = sourceRows.map(\.label)
        XCTAssertEqual(titles, titles.sorted())
        for row in sourceRows {
          XCTAssertTrue(expectedTitles.contains(row.label))
          if let retainedIdentifier = observedIdentifiersByTitle[row.label] {
            XCTAssertEqual(row.identifier, retainedIdentifier)
            continue
          }
          let element = catalog.buttons.matching(identifier: row.identifier).firstMatch
          guard element.isHittable else { continue }
          observedIdentifiersByTitle[row.label] = row.identifier
        }
        if attempt.isMultiple(of: 10) {
          print(
            "Every Item traversal attempt \(attempt): \(observedIdentifiersByTitle.count) identities; last visible \(titles.last ?? "none")"
          )
        }
        if last.exists && last.isHittable && snapshot.frame.contains(last.frame) { break }
        catalog.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.72))
          .press(
            forDuration: 0.05,
            thenDragTo: catalog.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.42)))
      }
      let observed = XCTAttachment(
        string: observedIdentifiersByTitle.sorted { $0.key < $1.key }.map { entry in
          "\(entry.key): \(entry.value)"
        }.joined(separator: "\n"))
      observed.name = "Native Item traversal observed title and identity pairs"
      observed.lifetime = .keepAlways
      add(observed)
      XCTAssertEqual(Set(observedIdentifiersByTitle.keys), expectedTitles)
      XCTAssertEqual(Set(observedIdentifiersByTitle.values).count, 5000)
      XCTAssertTrue(last.isHittable)
      let lastIdentifier = try XCTUnwrap(observedIdentifiersByTitle["Scale Item 05000"])
      XCTAssertEqual(last.identifier, lastIdentifier)
      capture("Every Item traversal observes all five thousand source identities")
      last.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Far-end collection marker"].waitForExistence(timeout: 10))
      XCTAssertTrue(completion.waitForPlannerBooleanState(false))
      capture("Every Item traversal opens the original far-end source")
    }

    private func visibleItemSnapshots(
      _ snapshot: any XCUIElementSnapshot, within viewport: CGRect
    ) -> [any XCUIElementSnapshot] {
      var rows: [any XCUIElementSnapshot] = []
      if viewport.contains(snapshot.frame) && !snapshot.frame.isEmpty {
        let isSource =
          snapshot.elementType == .button
          && snapshot.identifier.hasPrefix("saved.item.") && snapshot.label.hasPrefix("Scale Item ")
        let isLoading =
          snapshot.elementType == .progressIndicator && snapshot.label == "Loading Item"
        if isSource || isLoading { rows.append(snapshot) }
      }
      for child in snapshot.children {
        rows.append(contentsOf: visibleItemSnapshots(child, within: viewport))
      }
      return rows
    }

    func testUnfilteredCatalogScrollsToBothEndsAndReopensTheSameSource() {
      continueAfterFailure = false
      print("XCTest Fast touch velocity: \(XCUIGestureVelocity.fast.rawValue)")
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "large-collection", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      openCatalog(application)
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
      openCatalog(application)
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

    private func openCatalog(_ application: XCUIApplication) {
      let navigationReady = NSPredicate { _, _ in
        application.buttons["Items"].firstMatch.exists
          || application.buttons["Show Sidebar"].firstMatch.exists
      }
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [XCTNSPredicateExpectation(predicate: navigationReady, object: application)],
          timeout: 120), .completed)
      application.openPlannerSection("Items")
    }

    private func hasVisibleSources(in contents: XCUIElement) -> Bool {
      guard contents.exists else { return false }
      let viewport = contents.frame
      let sources = contents.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "saved.item.", "Scale Item ")
      ).allElementsBoundByIndex
      return sources.contains { source in
        source.isHittable && viewport.contains(source.frame)
      }
    }

    private func revealCatalog(_ application: XCUIApplication, contents: XCUIElement) {
      if hasVisibleSources(in: contents) { return }
      let back = application.buttons["BackButton"].firstMatch
      if back.exists && back.isHittable {
        back.activateForPlannerJourney()
      } else {
        let sidebar = application.buttons["Show Sidebar"].firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        sidebar.activateForPlannerJourney()
      }
      XCTAssertTrue(contents.waitForExistence(timeout: 10))
      XCTAssertTrue(hasVisibleSources(in: contents), application.debugDescription)
    }

    @discardableResult
    private func capture(_ name: String) -> XCUIScreenshot {
      let screenshot = XCUIScreen.main.screenshot()
      let attachment = XCTAttachment(screenshot: screenshot)
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
      return screenshot
    }
  }
#endif
