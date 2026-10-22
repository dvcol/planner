import CoreGraphics
import ImageIO
import Network
import XCTest

@MainActor
final class SavedBrowserJourneyTests: XCTestCase {
  func testRecoveringAFailedReloadPreservesThePreviousPageInHistory() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    savedLink.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    server.setGardenAvailable(false)
    application.buttons["saved.browser.reload"].activateForPlannerJourney()
    let unavailable = application.staticTexts["Page unavailable"].firstMatch
    XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
    server.setGardenAvailable(true)
    application.buttons["Retry"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 15))
    XCTAssertTrue(unavailable.waitForNonExistence(timeout: 5))
    application.buttons["saved.browser.back"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    try await recordWindow(application, name: "Recovered reload preserves native Back history")
  }

  func testToolbarReloadRecoversUnavailableSavedAndLinkedWebsites() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    server.setGuideAvailable(false)
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    let savedLinkIdentifier = savedLink.identifier
    savedLink.activateForPlannerJourney()
    let unavailable = application.staticTexts["Page unavailable"].firstMatch
    XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
    server.setGuideAvailable(true)
    application.buttons["saved.browser.reload"].activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 15))
    XCTAssertTrue(unavailable.waitForNonExistence(timeout: 5))
    server.setGardenAvailable(false)
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
    server.setGardenAvailable(true)
    application.buttons["saved.browser.reload"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 15))
    XCTAssertTrue(unavailable.waitForNonExistence(timeout: 5))
    try await recordWindow(application, name: "Toolbar reload recovers saved and linked guides")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testFailedLinkedWebsiteRetriesThatPageAndKeepsItsOriginalBookmark() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    server.setGardenAvailable(false)
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    let savedLinkIdentifier = savedLink.identifier
    savedLink.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    page.links["Garden guide"].activateForPlannerJourney()
    let unavailable = application.staticTexts["Page unavailable"].firstMatch
    XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
    XCTAssertTrue(server.requestLines.contains("GET /garden HTTP/1.1"))
    server.setGardenAvailable(true)
    application.buttons["Retry"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 15))
    XCTAssertTrue(unavailable.waitForNonExistence(timeout: 5))
    try await recordWindow(application, name: "Linked guide recovers without changing its bookmark")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testFailedWebsiteCanRetryRepeatedlyWithoutChangingItsSavedBookmark() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    server.setGuideAvailable(false)
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    let savedLinkIdentifier = savedLink.identifier
    savedLink.activateForPlannerJourney()
    let unavailable = application.staticTexts["Page unavailable"].firstMatch
    XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
    let requestsBeforeRetry = server.requestLines.filter { $0 == "GET /guide HTTP/1.1" }.count
    XCTAssertGreaterThan(requestsBeforeRetry, 0)
    application.buttons["Retry"].firstMatch.activateForPlannerJourney()
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while ContinuousClock.now < deadline,
      server.requestLines.filter({ $0 == "GET /guide HTTP/1.1" }).count <= requestsBeforeRetry
    {
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertGreaterThan(
      server.requestLines.filter { $0 == "GET /guide HTTP/1.1" }.count, requestsBeforeRetry)
    XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
    server.setGuideAvailable(true)
    application.buttons["Retry"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 15))
    try await recordWindow(application, name: "Saved guide recovers after repeated failure")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testSavedWebsiteOpensInsidePlannerAndReturnsToTheSameItem() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    for _ in 0..<6 where !savedLink.isHittable { application.swipeUp() }
    let originalLinkIdentity = savedLink.identifier
    XCTAssertEqual(savedLink.value as? String, destination.absoluteString)
    savedLink.activateForPlannerJourney()
    let returnToItem = application.buttons["saved.browser.return"]
    guard returnToItem.waitForExistence(timeout: 10) else {
      let hierarchy = XCTAttachment(string: application.debugDescription)
      hierarchy.name = "Unavailable browser own-app hierarchy, state \(application.state.rawValue)"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      if application.windows.firstMatch.exists {
        let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
        capture.name = "Unavailable browser own-app window"
        capture.lifetime = .keepAlways
        add(capture)
      }
      XCTFail("Opening the saved guide must present Planner's native browser return control.")
      return
    }
    XCTAssertEqual(application.state, .runningForeground)
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.waitForExistence(timeout: 10))
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    XCTAssertTrue(server.requestLines.contains("GET /guide HTTP/1.1"))
    try await recordWindow(application, name: "Saved guide opens in native Planner webpage")
    returnToItem.activateForPlannerJourney()
    let restoredLink = application.descendants(matching: .any)
      .matching(identifier: originalLinkIdentity).firstMatch
    XCTAssertTrue(restoredLink.waitForExistence(timeout: 10))
    XCTAssertEqual(restoredLink.value as? String, destination.absoluteString)
    let linkIdentifier = originalLinkIdentity.replacingOccurrences(of: "saved.item.link.", with: "")
    let richCard = application.descendants(matching: .any)
      .matching(identifier: "saved.item.preview.card.\(linkIdentifier)").firstMatch
    XCTAssertTrue(richCard.waitForExistence(timeout: 10))
    for _ in 0..<6 where !richCard.isHittable { application.swipeUp() }
    richCard.activateForPlannerJourney()
    XCTAssertTrue(returnToItem.waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    returnToItem.activateForPlannerJourney()
    XCTAssertTrue(restoredLink.waitForExistence(timeout: 10))
    XCTAssertEqual(restoredLink.value as? String, destination.absoluteString)
    let catalogBack = application.navigationBars.buttons["Items"].firstMatch
    if catalogBack.exists { catalogBack.activateForPlannerJourney() }
    XCTAssertTrue(
      application.savedPlannerItemRows("Museum reading").firstMatch.waitForExistence(timeout: 5))
    XCTAssertEqual(application.savedPlannerItemRows("Museum reading").count, 1)
  }

  func testNativeWebpageHistoryAndReloadKeepTheSavedBookmarkUnchanged() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    let savedLinkIdentifier = savedLink.identifier
    savedLink.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    let back = application.buttons["saved.browser.back"]
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    XCTAssertTrue(back.isEnabled)
    back.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    let forward = application.buttons["saved.browser.forward"]
    XCTAssertTrue(forward.isEnabled)
    forward.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    let previousRequests = server.requestLines.filter { $0 == "GET /garden HTTP/1.1" }.count
    application.buttons["saved.browser.reload"].activateForPlannerJourney()
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while ContinuousClock.now < deadline,
      server.requestLines.filter({ $0 == "GET /garden HTTP/1.1" }).count <= previousRequests
    {
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertGreaterThan(
      server.requestLines.filter { $0 == "GET /garden HTTP/1.1" }.count, previousRequests)
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    try await recordWindow(
      application, name: "Native webpage history and reload preserve the original bookmark")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testCalendarSourceOpensItsGuideAndReturnsToTheSameScheduleDetails() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    let links = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
    XCTAssertTrue(links.firstMatch.waitForExistence(timeout: 10))
    let savedLinkIdentifier = links.firstMatch.identifier
    let actions = application.plannerElement("saved.item.actions")
    XCTAssertTrue(actions.waitForExistence(timeout: 10))
    actions.activateForPlannerJourney()
    application.plannerElement("Schedule item").activateForPlannerJourney()
    application.plannerElement("saved.schedule.save").activateForPlannerJourney()
    let schedule = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
    ).firstMatch
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    let scheduleIdentifier = schedule.identifier
      .replacingOccurrences(of: "saved.item.schedule.", with: "")
    application.openPlannerSection("Calendar")
    let booking = application.descendants(matching: .any)
      .matching(identifier: "saved.calendar.schedule.\(scheduleIdentifier)").firstMatch
    XCTAssertTrue(booking.waitForExistence(timeout: 10))
    booking.activateForPlannerJourney()
    let savedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    for _ in 0..<6 where !savedLink.isHittable { application.swipeUp() }
    savedLink.activateForPlannerJourney()
    let returnToPlanner = application.buttons["saved.browser.return"]
    XCTAssertTrue(returnToPlanner.waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    try await recordWindow(
      application, name: "Calendar source guide uses the existing navigation stack")
    returnToPlanner.activateForPlannerJourney()
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(savedLink.value as? String, destination.absoluteString)
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
  }

  func testItineraryGuideReturnsToItsOwnPlanInsteadOfAnItemPlaceholder() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Itineraries")
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum route")
    let addLink = application.plannerElement("saved.itinerary.link.add")
    for _ in 0..<6 where !addLink.isHittable { application.swipeUp() }
    XCTAssertTrue(addLink.isHittable)
    addLink.activateForPlannerJourney()
    let linkInput = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.link.url.")
    ).firstMatch
    XCTAssertTrue(linkInput.waitForExistence(timeout: 5))
    linkInput.activateForPlannerJourney()
    linkInput.typeText(destination.absoluteString)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let savedLink = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
    ).firstMatch
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    let savedLinkIdentifier = savedLink.identifier
    for _ in 0..<6 where !savedLink.isHittable { application.swipeUp() }
    savedLink.activateForPlannerJourney()
    let returnToPlan = application.buttons["saved.browser.return"]
    XCTAssertTrue(returnToPlan.waitForExistence(timeout: 10))
    XCTAssertEqual(returnToPlan.label, "Return to itinerary")
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    try await recordWindow(application, name: "Itinerary guide keeps its plan return context")
    returnToPlan.activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
    XCTAssertTrue(application.staticTexts["Museum route"].firstMatch.exists)
  }

  func testListGuideReturnsToTheSameLocallyCompletedAppearance() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    createLinkedItem(in: application, destination: destination)
    XCTAssertTrue(application.plannerElement("saved.item.actions").waitForExistence(timeout: 10))
    application.beginPlannerListCreation()
    let name = application.textFields["saved.list.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.activateForPlannerJourney()
    name.typeText("Reading list")
    application.plannerElement("saved.list.save").activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["No items"].waitForExistence(timeout: 10))
    application.openSavedPlannerListAddMenu()
    application.plannerElement("saved.list.add").activateForPlannerJourney()
    let candidate = application.staticTexts["Museum reading"].firstMatch
    XCTAssertTrue(candidate.waitForExistence(timeout: 10))
    candidate.activateForPlannerJourney()
    application.plannerElement("saved.membership.add").activateForPlannerJourney()
    let markDone = application.buttons["Mark Museum reading done in this List"].firstMatch
    XCTAssertTrue(markDone.waitForExistence(timeout: 10))
    markDone.activateForPlannerJourney()
    let markUndone = application.buttons["Mark Museum reading undone in this List"].firstMatch
    XCTAssertTrue(markUndone.waitForExistence(timeout: 10))
    application.savedPlannerItemRows("Museum reading").firstMatch.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Reading list"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.exists)
    let links = application.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link."))
    XCTAssertTrue(links.firstMatch.waitForExistence(timeout: 10))
    let linkIdentifier = links.firstMatch.identifier
    links.firstMatch.activateForPlannerJourney()
    let returnToItem = application.buttons["saved.browser.return"]
    XCTAssertTrue(returnToItem.waitForExistence(timeout: 10))
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    returnToItem.activateForPlannerJourney()
    XCTAssertTrue(application.staticTexts["In Reading list"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Completed"].firstMatch.exists)
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: linkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
    try await recordWindow(
      application, name: "Browser return preserves the completed List appearance")
    application.openPlannerSection("Items")
    let completion = application.descendants(matching: .any)
      .matching(identifier: "saved.item.completion").firstMatch
    if !completion.waitForExistence(timeout: 2) {
      let source = application.savedPlannerItemRows("Museum reading").firstMatch
      XCTAssertTrue(source.waitForExistence(timeout: 10))
      source.activateForPlannerJourney()
    }
    XCTAssertTrue(completion.waitForPlannerBooleanState(false))
  }

  private func recordWindow(_ application: XCUIApplication, name: String) async throws {
    let window = application.windows.firstMatch
    let windowFrame = window.frame
    var screenshot = window.screenshot()
    var didPaint = true
    #if os(iOS)
      if application.buttons["saved.browser.return"].exists {
        let browserBar = application.navigationBars.containing(
          .button, identifier: "saved.browser.return"
        ).firstMatch
        let barFrame = browserBar.frame
        let contentFrame = CGRect(
          x: barFrame.minX, y: barFrame.maxY + 8, width: barFrame.width,
          height: min(200, windowFrame.maxY - barFrame.maxY - 8))
        didPaint = false
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
          screenshot = window.screenshot()
          if readingAreaHasPainted(screenshot, frame: contentFrame, windowFrame: windowFrame) {
            didPaint = true
            break
          }
          try await Task.sleep(for: .milliseconds(100))
        }
      }
    #endif
    let capture = XCTAttachment(screenshot: screenshot)
    capture.name = name
    capture.lifetime = .keepAlways
    add(capture)
    XCTAssertTrue(didPaint, "The native reading pane must visibly paint the fixture content.")
  }

  /// Sample the native content pane because WebKit can expose DOM text before its first frame.
  private func readingAreaHasPainted(
    _ screenshot: XCUIScreenshot, frame: CGRect, windowFrame: CGRect
  ) -> Bool {
    let readingFrame = frame.intersection(windowFrame)
    guard !windowFrame.isEmpty, !readingFrame.isEmpty,
      let source = CGImageSourceCreateWithData(screenshot.pngRepresentation as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return false }
    let scale = CGFloat(image.width) / windowFrame.width
    let crop = CGRect(
      x: (readingFrame.minX - windowFrame.minX) * scale,
      y: (readingFrame.minY - windowFrame.minY) * scale,
      width: readingFrame.width * scale, height: readingFrame.height * scale)
    guard let readingImage = image.cropping(to: crop) else { return false }
    var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
          bytesPerRow: 32 * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue)
      else { return false }
      context.draw(readingImage, in: CGRect(x: 0, y: 0, width: 32, height: 32))
      return true
    }
    guard drawn else { return false }
    let brightness = stride(from: 0, to: pixels.count, by: 4).map { offset in
      (Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / 3
    }
    let background = brightness.sorted()[brightness.count / 2]
    return brightness.filter { abs($0 - background) > 40 }.count > 16
  }

  private func createLinkedItem(in application: XCUIApplication, destination: URL) {
    application.openSavedPlannerNewItemEditor()
    let title = application.textFields["saved.item.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum reading")
    let addLink = application.plannerElement("saved.item.link.add")
    for _ in 0..<6 where !addLink.isHittable { application.swipeUp() }
    XCTAssertTrue(addLink.isHittable)
    addLink.activateForPlannerJourney()
    let linkInput = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.url.")
    ).firstMatch
    XCTAssertTrue(linkInput.waitForExistence(timeout: 5))
    linkInput.activateForPlannerJourney()
    linkInput.typeText(destination.absoluteString)
    application.plannerElement("saved.item.save").activateForPlannerJourney()
  }
}

private final class BrowserJourneyServer: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "Planner.BrowserJourneyServer")
  private let lock = NSLock()
  private var port: NWEndpoint.Port?
  private var failure: NWError?
  private var observedRequestLines: [String] = []
  private var isGuideAvailable = true
  private var isGardenAvailable = true
  private var connections: [NWConnection] = []

  init() throws {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    listener = try NWListener(using: parameters)
  }

  var requestLines: [String] { lock.withLock { observedRequestLines } }

  func setGuideAvailable(_ available: Bool) { lock.withLock { isGuideAvailable = available } }
  func setGardenAvailable(_ available: Bool) { lock.withLock { isGardenAvailable = available } }

  func start() async throws -> URL {
    listener.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      lock.withLock {
        if case .ready = state { port = listener.port }
        if case .failed(let error) = state { failure = error }
      }
    }
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else { return }
      connections.append(connection)
      connection.start(queue: queue)
      receive(connection, bytes: Data())
    }
    listener.start(queue: queue)
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while ContinuousClock.now < deadline {
      let observation = lock.withLock { (port, failure) }
      if let failure = observation.1 { throw failure }
      if let port = observation.0,
        let destination = URL(string: "http://localhost:\(port.rawValue)/guide")
      {
        return destination
      }
      try await Task.sleep(for: .milliseconds(10))
    }
    throw URLError(.timedOut)
  }

  func stop() {
    queue.async { [self] in
      listener.cancel()
      for connection in connections { connection.cancel() }
      connections.removeAll()
    }
  }

  private func receive(_ connection: NWConnection, bytes: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
      [weak self] incoming, _, complete, error in
      guard let self else { return }
      let received = bytes + (incoming ?? Data())
      guard error == nil, received.count <= 8192 else {
        connection.cancel()
        return
      }
      guard let header = String(data: received, encoding: .utf8), header.contains("\r\n\r\n") else {
        if complete { connection.cancel() } else { receive(connection, bytes: received) }
        return
      }
      let requestLine = header.components(separatedBy: "\r\n").first ?? ""
      lock.withLock { observedRequestLines.append(requestLine) }
      if requestLine == "GET /guide HTTP/1.1", !lock.withLock({ isGuideAvailable }) {
        connection.cancel()
        return
      }
      if requestLine == "GET /garden HTTP/1.1", !lock.withLock({ isGardenAvailable }) {
        connection.cancel()
        return
      }
      let body: String
      if requestLine.contains(" /garden ") {
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Garden guide</title></head>
          <body><h1>Garden guide fixture</h1><p>Enter through the east gate.</p></body></html>
          """
      } else {
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Museum guide</title></head>
          <body><h1>Museum guide fixture</h1><p>Meet at the garden entrance.</p>
          <a href="/garden">Garden guide</a></body></html>
          """
      }
      let content = requestLine.hasPrefix("HEAD ") ? "" : body
      let response =
        "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(content)"
      connection.send(
        content: Data(response.utf8),
        completion: .contentProcessed { _ in connection.cancel() })
    }
  }
}
