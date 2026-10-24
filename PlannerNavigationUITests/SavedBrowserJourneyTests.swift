import CoreGraphics
import ImageIO
import XCTest

#if os(iOS)
  import UIKit
#endif

@MainActor
final class SavedBrowserJourneyTests: XCTestCase {
  #if os(iOS)
    func testFailedLinkedGuideOpensItsExactTargetInTheSystemBrowser() async throws {
      continueAfterFailure = false
      let server = try BrowserJourneyServer()
      server.setGardenAvailable(false)
      let destination = try await server.start()
      defer { server.stop() }
      let failedDestination = destination.deletingLastPathComponent().appendingPathComponent(
        "garden")
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      createLinkedItem(in: application, destination: destination)
      let bookmark = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
      ).firstMatch
      XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
      let bookmarkIdentifier = bookmark.identifier
      bookmark.activateForPlannerJourney()
      let page = application.webViews.firstMatch
      XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
      page.links["Garden guide"].activateForPlannerJourney()
      let unavailable = application.staticTexts["Page unavailable"].firstMatch
      XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
      let external = application.buttons["Open in default browser"].firstMatch
      XCTAssertTrue(external.waitForExistence(timeout: 5))
      XCTAssertEqual(external.value as? String, failedDestination.absoluteString)
      let requestLine = "GET /garden HTTP/1.1"
      let plannerUserAgents = server.userAgents(for: requestLine)
      XCTAssertFalse(plannerUserAgents.isEmpty)
      let browser = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
      XCTAssertNotEqual(browser.state, .runningForeground)
      XCTAssertEqual(application.state, .runningForeground)
      let offered = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
      offered.name = "Failed linked guide offers its exact external target"
      offered.lifetime = .keepAlways
      add(offered)
      server.setGardenAvailable(true)
      external.activateForPlannerJourney()
      let browserBecameForeground = browser.wait(for: .runningForeground, timeout: 10)
      let deadline = ContinuousClock.now.advanced(by: .seconds(10))
      while ContinuousClock.now < deadline,
        !server.userAgents(for: requestLine).dropFirst(plannerUserAgents.count).contains(where: {
          $0.contains(" Safari/") && !plannerUserAgents.contains($0)
        })
      {
        try await Task.sleep(for: .milliseconds(20))
      }
      let externalUserAgents = Array(
        server.userAgents(for: requestLine).dropFirst(plannerUserAgents.count))
      let observation: [String: Any] = [
        "originalBookmark": destination.absoluteString,
        "requestedExternalTarget": failedDestination.absoluteString,
        "requestLine": requestLine,
        "plannerUserAgents": plannerUserAgents,
        "externalUserAgents": externalUserAgents,
        "browserBecameForeground": browserBecameForeground,
        "browserState": browser.state.rawValue,
        "plannerState": application.state.rawValue,
      ]
      let requests = XCTAttachment(
        data: try JSONSerialization.data(withJSONObject: observation, options: .prettyPrinted),
        uniformTypeIdentifier: "public.json")
      requests.name = "Actual system browser request provenance"
      requests.lifetime = .keepAlways
      add(requests)
      let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      opened.name = "System browser after explicit Planner external action"
      opened.lifetime = .keepAlways
      add(opened)
      XCTAssertTrue(browserBecameForeground)
      XCTAssertTrue(
        externalUserAgents.contains {
          $0.contains(" Safari/") && !plannerUserAgents.contains($0)
        })
      application.activate()
      XCTAssertTrue(application.wait(for: .runningForeground, timeout: 10))
      XCTAssertTrue(unavailable.waitForExistence(timeout: 10))
      XCTAssertEqual(external.value as? String, failedDestination.absoluteString)
      application.buttons["saved.browser.return"].activateForPlannerJourney()
      let retainedBookmark = application.descendants(matching: .any)
        .matching(identifier: bookmarkIdentifier).firstMatch
      XCTAssertTrue(retainedBookmark.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedBookmark.value as? String, destination.absoluteString)
      try await recordWindow(
        application, name: "System browser handoff preserves the original saved bookmark")
    }

    func testConfirmedMapsLinkOpensMapsAndKeepsTheOriginalGuide() async throws {
      continueAfterFailure = false
      let server = try BrowserJourneyServer()
      let guideURL = try await server.start()
      defer { server.stop() }
      let destination = guideURL.deletingLastPathComponent().appendingPathComponent(
        "external-app-policy")
      let application = XCUIApplication()
      application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      createLinkedItem(in: application, destination: destination)
      let bookmark = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.link.")
      ).firstMatch
      XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
      let bookmarkIdentifier = bookmark.identifier
      bookmark.activateForPlannerJourney()
      let page = application.webViews.firstMatch
      XCTAssertTrue(page.staticTexts["External app policy fixture"].waitForExistence(timeout: 10))
      page.links["Maps link"].activateForPlannerJourney()
      let confirmation = application.navigationBars["Open another app"].firstMatch
      XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
      XCTAssertEqual(
        application.staticTexts["saved.browser.external.destination"].label, "maps://?ll=35,139")
      let maps = XCUIApplication(bundleIdentifier: "com.apple.Maps")
      XCTAssertNotEqual(maps.state, .runningForeground)
      XCTAssertEqual(application.state, .runningForeground)
      let offered = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
      offered.name = "Maps destination awaits explicit Planner Open"
      offered.lifetime = .keepAlways
      add(offered)
      application.buttons["saved.browser.external.open"].activateForPlannerJourney()
      let mapsBecameForeground = maps.wait(for: .runningForeground, timeout: 10)
      let observation: [String: Any] = [
        "originalBookmark": destination.absoluteString,
        "confirmedExternalTarget": "maps://?ll=35,139",
        "mapsBecameForeground": mapsBecameForeground,
        "mapsState": maps.state.rawValue,
        "plannerState": application.state.rawValue,
      ]
      let launch = XCTAttachment(
        data: try JSONSerialization.data(withJSONObject: observation, options: .prettyPrinted),
        uniformTypeIdentifier: "public.json")
      launch.name = "Actual Maps foreground observation"
      launch.lifetime = .keepAlways
      add(launch)
      let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      opened.name = "Apple Maps after explicit Planner Open"
      opened.lifetime = .keepAlways
      add(opened)
      XCTAssertTrue(mapsBecameForeground)
      application.activate()
      XCTAssertTrue(application.wait(for: .runningForeground, timeout: 10))
      XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
      XCTAssertTrue(page.staticTexts["External app policy fixture"].waitForExistence(timeout: 10))
      XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
      try await recordWindow(
        application, name: "Guide remains readable after returning from Apple Maps")
      application.buttons["saved.browser.return"].activateForPlannerJourney()
      let retainedBookmark = application.descendants(matching: .any)
        .matching(identifier: bookmarkIdentifier).firstMatch
      XCTAssertTrue(retainedBookmark.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedBookmark.value as? String, destination.absoluteString)
    }

    func testDismissingInitialAppConfirmationReturnsToTheExactSavedItem() async throws {
      continueAfterFailure = false
      let server = try BrowserJourneyServer()
      let guideURL = try await server.start()
      defer { server.stop() }
      let destination = guideURL.deletingLastPathComponent().appendingPathComponent(
        "initial-app-redirect")
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
      let explanation = application.navigationBars["Open another app"].firstMatch
      XCTAssertTrue(explanation.waitForExistence(timeout: 10))
      XCTAssertEqual(application.state, .runningForeground)
      XCTAssertEqual(
        application.staticTexts["saved.browser.external.destination"].label, "maps://?ll=36,140")
      XCTAssertTrue(application.buttons["saved.browser.external.open"].isHittable)
      let offered = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
      offered.name = "Initial app redirect awaits native confirmation before any page"
      offered.lifetime = .keepAlways
      add(offered)
      dismissExternalAppSheetInteractively(in: application, header: explanation)
      XCTAssertTrue(explanation.waitForNonExistence(timeout: 10))
      let retainedLink = application.descendants(matching: .any)
        .matching(identifier: savedLinkIdentifier).firstMatch
      XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
      XCTAssertFalse(application.buttons["saved.browser.return"].exists)
      XCTAssertEqual(application.state, .runningForeground)
      let returned = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
      returned.name = "Dismissed initial app confirmation returns to its saved Item"
      returned.lifetime = .keepAlways
      add(returned)
    }

    func testDismissingLoadedAppConfirmationKeepsTheGuideAndBookmark() async throws {
      continueAfterFailure = false
      let server = try BrowserJourneyServer()
      let guideURL = try await server.start()
      defer { server.stop() }
      let destination = guideURL.deletingLastPathComponent().appendingPathComponent(
        "external-app-policy")
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
      XCTAssertTrue(page.staticTexts["External app policy fixture"].waitForExistence(timeout: 10))
      page.links["Mail link"].activateForPlannerJourney()
      let explanation = application.navigationBars["Open another app"].firstMatch
      XCTAssertTrue(explanation.waitForExistence(timeout: 10))
      XCTAssertEqual(
        application.staticTexts["saved.browser.external.destination"].label,
        "mailto:planner-fixture@example.invalid?subject=Planning")
      XCTAssertTrue(application.buttons["saved.browser.external.open"].isHittable)
      dismissExternalAppSheetInteractively(in: application, header: explanation)
      XCTAssertTrue(explanation.waitForNonExistence(timeout: 10))
      XCTAssertTrue(page.staticTexts["External app policy fixture"].waitForExistence(timeout: 10))
      XCTAssertEqual(application.state, .runningForeground)
      XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
      try await recordWindow(application, name: "Interactive app-sheet dismissal keeps the guide")
      page.links["Garden guide"].activateForPlannerJourney()
      XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
      application.buttons["saved.browser.back"].activateForPlannerJourney()
      XCTAssertTrue(page.staticTexts["External app policy fixture"].waitForExistence(timeout: 10))
      application.buttons["saved.browser.return"].activateForPlannerJourney()
      let retainedLink = application.descendants(matching: .any)
        .matching(identifier: savedLinkIdentifier).firstMatch
      XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
      XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
    }

    private func dismissExternalAppSheetInteractively(
      in application: XCUIApplication, header: XCUIElement
    ) {
      let start = header.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.05))
      let lowerEdge = application.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.95))
      start.press(forDuration: 0.05, thenDragTo: lowerEdge)
    }
  #endif

  func testSupportedExternalAppLinksWaitForConfirmationAndKeepTheOriginalGuide() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let guideURL = try await server.start()
    defer { server.stop() }
    let destination = guideURL.deletingLastPathComponent().appendingPathComponent(
      "external-app-policy")
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
    XCTAssertTrue(page.staticTexts["External app policy fixture"].waitForExistence(timeout: 10))
    let choices = [
      ("Mail link", "mailto:planner-fixture@example.invalid?subject=Planning"),
      ("Phone link", "tel:+810000000000"),
      ("Maps link", "maps://?ll=35,139"),
    ]
    for (title, target) in choices {
      page.links[title].activateForPlannerJourney()
      #if os(iOS)
        if title == "Phone link", UIDevice.current.userInterfaceIdiom == .pad {
          XCTAssertEqual(application.state, .runningForeground)
          XCTAssertFalse(application.navigationBars["Open another app"].exists)
          let capture = XCTAttachment(screenshot: application.screenshot())
          capture.name = "Native WebKit Phone actions await an explicit choice"
          capture.lifetime = .keepAlways
          add(capture)
          application.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.85)).tap()
          XCTAssertEqual(application.state, .runningForeground)
          XCTAssertTrue(page.staticTexts["External app policy fixture"].exists)
          XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
          continue
        }
      #endif
      let explanation = application.navigationBars["Open another app"].firstMatch
      XCTAssertTrue(explanation.waitForExistence(timeout: 10))
      let opening = application.buttons["saved.browser.external.open"]
      XCTAssertTrue(opening.isHittable)
      let displayedTarget = application.staticTexts["saved.browser.external.destination"]
      XCTAssertTrue(displayedTarget.isHittable)
      XCTAssertEqual(displayedTarget.label, target)
      XCTAssertFalse(application.buttons["Open in default browser"].exists)
      if title == "Mail link" {
        let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
        capture.name = "Supported external-app link awaits an exact native Open action"
        capture.lifetime = .keepAlways
        add(capture)
      }
      application.buttons["saved.browser.external.cancel"].activateForPlannerJourney()
      XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
      XCTAssertTrue(page.staticTexts["External app policy fixture"].exists)
      XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
    }
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testGeneratedAndRedirectedAppLinksWaitForConfirmationWithoutChangingTheBookmark()
    async throws
  {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let guideURL = try await server.start()
    defer { server.stop() }
    let destination = guideURL.deletingLastPathComponent().appendingPathComponent(
      "external-app-policy")
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
    XCTAssertTrue(page.staticTexts["External app policy fixture"].waitForExistence(timeout: 10))
    page.buttons["Generated Mail link"].activateForPlannerJourney()
    let explanation = application.navigationBars["Open another app"].firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    let mailTarget = "mailto:planner-fixture@example.invalid?subject=Planning"
    XCTAssertEqual(application.staticTexts["saved.browser.external.destination"].label, mailTarget)
    XCTAssertTrue(application.buttons["saved.browser.external.open"].isHittable)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Generated external-app link awaits an exact native Open action"
    capture.lifetime = .keepAlways
    add(capture)
    application.buttons["saved.browser.external.cancel"].activateForPlannerJourney()
    XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    XCTAssertTrue(page.staticTexts["External app policy fixture"].exists)
    page.links["Automatic Maps redirect"].activateForPlannerJourney()
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertEqual(
      application.staticTexts["saved.browser.external.destination"].label, "maps://?ll=36,140")
    XCTAssertTrue(application.buttons["saved.browser.external.open"].isHittable)
    application.buttons["saved.browser.external.cancel"].activateForPlannerJourney()
    XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    XCTAssertTrue(page.staticTexts["Automatic redirect fixture"].exists)
    XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testWebsiteFileLinkKeepsTheGuideAndItsOriginalBookmark() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let guideURL = try await server.start()
    defer { server.stop() }
    let destination = guideURL.deletingLastPathComponent().appendingPathComponent("link-policy")
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
    XCTAssertTrue(page.staticTexts["Link policy fixture"].waitForExistence(timeout: 10))
    page.links["Unavailable file link"].activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    let reportedNavigation = explanation.waitForExistence(timeout: 2)
    if reportedNavigation {
      XCTAssertTrue(explanation.staticTexts["Link unavailable"].exists)
      XCTAssertTrue(
        explanation.staticTexts.matching(
          NSPredicate(format: "label CONTAINS %@", "file:///planner-fixture-unavailable.txt")
        ).firstMatch.exists)
      XCTAssertFalse(explanation.buttons["Open in default browser"].exists)
      explanation.buttons["Keep reading"].activateForPlannerJourney()
      XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    }
    XCTAssertTrue(page.staticTexts["File link activated"].waitForExistence(timeout: 5))
    XCTAssertTrue(page.staticTexts["Link policy fixture"].exists)
    XCTAssertEqual(application.state, .runningForeground)
    XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
    let observation = XCTAttachment(
      data: try JSONSerialization.data(
        withJSONObject: [
          "target": "file:///planner-fixture-unavailable.txt",
          "plannerNoticePresented": reportedNavigation,
          "guideStillReadable": page.staticTexts["Link policy fixture"].exists,
        ], options: .prettyPrinted),
      uniformTypeIdentifier: "public.json")
    observation.name = "Native file link activation outcome"
    observation.lifetime = .keepAlways
    add(observation)
    try await recordWindow(application, name: "Native file link keeps the saved guide readable")
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    XCTAssertTrue(server.requestLines.contains("GET /garden HTTP/1.1"))
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testWebsiteExecutableDataLinkKeepsTheGuideAndItsOriginalBookmark() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let guideURL = try await server.start()
    defer { server.stop() }
    let destination = guideURL.deletingLastPathComponent().appendingPathComponent(
      "executable-link-policy")
    let executableTarget =
      "data:text/html,%3Ch1%3EInline%20executable%20fixture%3C%2Fh1%3E%3Cscript%3Edocument.title%3D%27Executed%20inline%20fixture%27%3C%2Fscript%3E"
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
    XCTAssertTrue(page.staticTexts["Executable link policy fixture"].waitForExistence(timeout: 10))
    page.links["Unavailable executable data link"].activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    let reportedNavigation = explanation.waitForExistence(timeout: 2)
    if reportedNavigation {
      XCTAssertTrue(explanation.staticTexts["Link unavailable"].exists)
      XCTAssertTrue(
        explanation.staticTexts.matching(
          NSPredicate(format: "label CONTAINS %@", executableTarget)
        ).firstMatch.exists)
      XCTAssertFalse(explanation.buttons["Open in default browser"].exists)
      explanation.buttons["Keep reading"].activateForPlannerJourney()
      XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    }
    XCTAssertTrue(
      page.staticTexts["Executable data link activated"].waitForExistence(timeout: 5))
    XCTAssertTrue(page.staticTexts["Executable link policy fixture"].exists)
    XCTAssertFalse(page.staticTexts["Inline executable fixture"].exists)
    XCTAssertEqual(application.state, .runningForeground)
    XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
    let observation = XCTAttachment(
      data: try JSONSerialization.data(
        withJSONObject: [
          "target": executableTarget,
          "plannerNoticePresented": reportedNavigation,
          "guideStillReadable": page.staticTexts["Executable link policy fixture"].exists,
          "inlineDocumentVisible": page.staticTexts["Inline executable fixture"].exists,
        ], options: .prettyPrinted),
      uniformTypeIdentifier: "public.json")
    observation.name = "Native executable data link activation outcome"
    observation.lifetime = .keepAlways
    add(observation)
    try await recordWindow(
      application, name: "Native executable data link keeps the saved guide readable")
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    XCTAssertTrue(server.requestLines.contains("GET /garden HTTP/1.1"))
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testUnsupportedWebsiteLinkKeepsTheGuideAndItsOriginalBookmark() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let guideURL = try await server.start()
    defer { server.stop() }
    let destination = guideURL.deletingLastPathComponent().appendingPathComponent("link-policy")
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
    XCTAssertTrue(page.staticTexts["Link policy fixture"].waitForExistence(timeout: 10))
    page.links["Unavailable app link"].activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(explanation.staticTexts["Link unavailable"].exists)
    let target = explanation.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "planner-fixture-unsupported://guide")
    ).firstMatch
    XCTAssertTrue(target.isHittable)
    XCTAssertFalse(explanation.buttons["Open in default browser"].exists)
    XCTAssertTrue(explanation.buttons["Keep reading"].isHittable)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Unsupported website link retains its guide without an external action"
    capture.lifetime = .keepAlways
    add(capture)
    explanation.buttons["Keep reading"].activateForPlannerJourney()
    XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    XCTAssertTrue(page.staticTexts["Link policy fixture"].exists)
    XCTAssertFalse(application.staticTexts["Page unavailable"].exists)
    page.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testUnavailableLinkedPageKeepsItsExactBrowserTargetAndReadableError() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    server.setGardenAvailable(false)
    let destination = try await server.start()
    defer { server.stop() }
    let gardenURL = destination.deletingLastPathComponent().appendingPathComponent("garden")
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
    XCTAssertTrue(
      application.staticTexts["Page unavailable"].firstMatch.waitForExistence(timeout: 15))
    let externalOpening = application.buttons["Open in default browser"].firstMatch
    XCTAssertTrue(externalOpening.waitForExistence(timeout: 5))
    XCTAssertEqual(externalOpening.value as? String, gardenURL.absoluteString)
    XCTAssertTrue(application.staticTexts[gardenURL.absoluteString].firstMatch.isHittable)
    let connectionError = application.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[cd] %@", "connect")
    ).firstMatch
    XCTAssertTrue(connectionError.isHittable)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Failed linked webpage keeps its exact external target and readable error"
    capture.lifetime = .keepAlways
    add(capture)
    server.setGardenAvailable(true)
    application.buttons["Retry"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 15))
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testInitialUnsupportedBookmarkCanReturnToItsExactSavedItem() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let guideURL = try await server.start()
    defer { server.stop() }
    let destination = guideURL.deletingLastPathComponent().appendingPathComponent(
      "unsupported-content")
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
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 10))
    XCTAssertTrue(explanation.staticTexts["Open content in your browser"].exists)
    let target = explanation.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", destination.absoluteString)
    ).firstMatch
    XCTAssertTrue(target.isHittable)
    XCTAssertTrue(explanation.buttons["Open in default browser"].isHittable)
    XCTAssertTrue(explanation.buttons["Return to item"].isHittable)
    XCTAssertFalse(explanation.buttons["Keep reading"].exists)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Initial unsupported bookmark offers exact target and returns to Item"
    capture.lifetime = .keepAlways
    add(capture)
    explanation.buttons["Return to item"].activateForPlannerJourney()
    XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
    XCTAssertFalse(application.buttons["saved.browser.return"].exists)
  }

  func testUnsupportedLinkedContentOffersItsExactBrowserTargetAndKeepsTheSavedGuide() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let unsupportedURL = destination.deletingLastPathComponent().appendingPathComponent(
      "unsupported-content")
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
    let guide = application.webViews.firstMatch.staticTexts["Museum guide fixture"]
    XCTAssertTrue(guide.waitForExistence(timeout: 10))
    application.webViews.firstMatch.links["Unsupported content"].activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 5))
    XCTAssertTrue(explanation.staticTexts["Open content in your browser"].exists)
    let target = explanation.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", unsupportedURL.absoluteString)
    ).firstMatch
    XCTAssertTrue(target.exists)
    XCTAssertTrue(target.isHittable)
    XCTAssertTrue(explanation.buttons["Open in default browser"].isHittable)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name =
      "Native unsupported linked content offers exact external target and keeps saved guide"
    capture.lifetime = .keepAlways
    add(capture)
    explanation.buttons["Keep reading"].activateForPlannerJourney()
    XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    XCTAssertTrue(guide.waitForExistence(timeout: 10))
    XCTAssertTrue(guide.isHittable)
    XCTAssertFalse(application.staticTexts["Page unavailable"].firstMatch.exists)
    server.setGardenAvailable(false)
    application.webViews.firstMatch.links["Garden guide"].activateForPlannerJourney()
    XCTAssertTrue(
      application.staticTexts["Page unavailable"].firstMatch.waitForExistence(timeout: 10))
    server.setGardenAvailable(true)
    application.buttons["Retry"].firstMatch.activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Garden guide fixture"]
        .waitForExistence(timeout: 10))
    application.buttons["saved.browser.back"].activateForPlannerJourney()
    XCTAssertTrue(guide.waitForExistence(timeout: 10))
    XCTAssertFalse(application.staticTexts["Page unavailable"].firstMatch.exists)
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testRequestedDownloadOffersItsExactBrowserTargetAndKeepsTheSavedGuide() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    defer { server.stop() }
    let downloadURL = destination.deletingLastPathComponent().appendingPathComponent(
      "download-guide")
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
    let guide = application.webViews.firstMatch.staticTexts["Museum guide fixture"]
    XCTAssertTrue(guide.waitForExistence(timeout: 10))
    application.webViews.firstMatch.links["Download guide"].activateForPlannerJourney()
    let explanation = application.alerts.firstMatch
    XCTAssertTrue(explanation.waitForExistence(timeout: 5))
    XCTAssertTrue(explanation.staticTexts["Open download in your browser"].exists)
    let target = explanation.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", downloadURL.absoluteString)
    ).firstMatch
    XCTAssertTrue(target.exists)
    XCTAssertTrue(target.isHittable)
    XCTAssertTrue(explanation.buttons["Open in default browser"].isHittable)
    let capture = XCTAttachment(screenshot: application.windows.firstMatch.screenshot())
    capture.name = "Native requested download offers exact external target and keeps saved guide"
    capture.lifetime = .keepAlways
    add(capture)
    explanation.buttons["Keep reading"].activateForPlannerJourney()
    XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
    XCTAssertTrue(guide.waitForExistence(timeout: 10))
    XCTAssertTrue(guide.isHittable)
    XCTAssertFalse(application.staticTexts["Page unavailable"].firstMatch.exists)
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testPersistentWebsiteCookieSurvivesClosingTheReaderAndRelaunchingPlanner() async throws {
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    server.setVisitorCookieName(
      "planner_visit_" + UUID().uuidString.replacingOccurrences(of: "-", with: ""))
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
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    checkRememberedVisit(
      in: application, server: server, expectedHeading: "Visit not remembered",
      expectedCookie: "absent")
    application.buttons["saved.browser.back"].activateForPlannerJourney()
    let remember = application.webViews.firstMatch.links["Remember visit"]
    XCTAssertTrue(remember.waitForExistence(timeout: 5))
    remember.activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Visit remembered"].waitForExistence(timeout: 10))
    checkRememberedVisit(
      in: application, server: server, expectedHeading: "Returning visitor",
      expectedCookie: "remembered")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    savedLink.activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    checkRememberedVisit(
      in: application, server: server, expectedHeading: "Returning visitor",
      expectedCookie: "remembered")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    application.terminate()
    XCTAssertEqual(application.state, .notRunning)
    application.launchSavedPlannerJourney()
    application.openPlannerSection("Items")
    let retainedLink = application.descendants(matching: .any)
      .matching(identifier: savedLinkIdentifier).firstMatch
    if !retainedLink.waitForExistence(timeout: 2) {
      let item = application.savedPlannerItemRows("Museum reading").firstMatch
      XCTAssertTrue(item.waitForExistence(timeout: 10))
      item.activateForPlannerJourney()
    }
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
    retainedLink.activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    checkRememberedVisit(
      in: application, server: server, expectedHeading: "Returning visitor",
      expectedCookie: "remembered")
    try await recordWindow(
      application, name: "Persistent website cookie survives closing reader and app relaunch")
    application.webViews.firstMatch.links["Forget visit"].activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Visit forgotten"].waitForExistence(timeout: 10))
    checkRememberedVisit(
      in: application, server: server, expectedHeading: "Visit not remembered",
      expectedCookie: "absent")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    XCTAssertTrue(retainedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(retainedLink.value as? String, destination.absoluteString)
  }

  func testPendingReaderSurvivesRotationAndKeepsNativeHistory() async throws {
    #if os(iOS)
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
      }
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
      page.links["Delayed guide"].activateForPlannerJourney()
      let requestDeadline = ContinuousClock.now.advanced(by: .seconds(5))
      while server.delayedRequestCount == 0, ContinuousClock.now < requestDeadline {
        try await Task.sleep(for: .milliseconds(10))
      }
      XCTAssertEqual(server.delayedRequestCount, 1)
      let loading = application.progressIndicators["Loading webpage"].firstMatch
      XCTAssertTrue(loading.waitForExistence(timeout: 5))
      XCUIDevice.shared.orientation = .landscapeLeft
      let landscape = NSPredicate { _, _ in
        let frame = application.windows.firstMatch.frame
        return frame.width > frame.height
      }
      await fulfillment(
        of: [XCTNSPredicateExpectation(predicate: landscape, object: application)], timeout: 5)
      XCTAssertTrue(loading.waitForExistence(timeout: 5))
      XCTAssertTrue(application.buttons["saved.browser.return"].isHittable)
      XCUIDevice.shared.orientation = .portrait
      let portrait = NSPredicate { _, _ in
        let frame = application.windows.firstMatch.frame
        return frame.height > frame.width
      }
      await fulfillment(
        of: [XCTNSPredicateExpectation(predicate: portrait, object: application)], timeout: 5)
      XCTAssertTrue(loading.waitForExistence(timeout: 5))
      server.releaseDelayedResponses()
      XCTAssertTrue(page.staticTexts["Delayed guide fixture"].waitForExistence(timeout: 10))
      XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
      XCTAssertEqual(server.delayedResponseOutcomes.count, 1)
      try await recordWindow(
        application, name: "Pending reader renders delayed guide after rotation")
      application.buttons["saved.browser.back"].activateForPlannerJourney()
      XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
      application.buttons["saved.browser.return"].activateForPlannerJourney()
      XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
      XCTAssertEqual(savedLink.identifier, savedLinkIdentifier)
      XCTAssertEqual(savedLink.value as? String, destination.absoluteString)
      XCTAssertTrue(application.staticTexts["Museum reading"].firstMatch.exists)
    #else
      throw XCTSkip("Device rotation is qualified through the phone/tablet native journey.")
    #endif
  }

  func testFailedReaderSurvivesRotationAndRetriesTheSameSavedWebsite() async throws {
    #if os(iOS)
      continueAfterFailure = false
      XCUIDevice.shared.orientation = .portrait
      addTeardownBlock {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
      }
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
      XCUIDevice.shared.orientation = .landscapeLeft
      let landscape = NSPredicate { _, _ in
        let frame = application.windows.firstMatch.frame
        return frame.width > frame.height
      }
      await fulfillment(
        of: [XCTNSPredicateExpectation(predicate: landscape, object: application)], timeout: 5)
      XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
      XCTAssertTrue(unavailable.isHittable)
      XCTAssertTrue(application.buttons["Retry"].firstMatch.isHittable)
      XCTAssertTrue(application.buttons["saved.browser.return"].isHittable)
      XCUIDevice.shared.orientation = .portrait
      let portrait = NSPredicate { _, _ in
        let frame = application.windows.firstMatch.frame
        return frame.height > frame.width
      }
      await fulfillment(
        of: [XCTNSPredicateExpectation(predicate: portrait, object: application)], timeout: 5)
      XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
      server.setGuideAvailable(true)
      application.buttons["Retry"].firstMatch.activateForPlannerJourney()
      let page = application.webViews.firstMatch
      XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 15))
      XCTAssertTrue(unavailable.waitForNonExistence(timeout: 5))
      try await recordWindow(application, name: "Rotated failed reader recovers the original guide")
      application.buttons["saved.browser.return"].activateForPlannerJourney()
      XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
      XCTAssertEqual(savedLink.identifier, savedLinkIdentifier)
      XCTAssertEqual(savedLink.value as? String, destination.absoluteString)
      XCTAssertTrue(application.staticTexts["Museum reading"].firstMatch.exists)
    #else
      throw XCTSkip("Device rotation is qualified through the phone/tablet native journey.")
    #endif
  }

  func testReportedNewWindowLinkReusesReaderAndNativeHistory() async throws {
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
    page.links["Garden in another window"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    XCTAssertTrue(server.requestLines.contains("GET /garden HTTP/1.1"))
    try await recordWindow(application, name: "Reported new-window link reuses native reader")
    application.buttons["saved.browser.back"].activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    XCTAssertEqual(savedLink.identifier, savedLinkIdentifier)
    XCTAssertEqual(savedLink.value as? String, destination.absoluteString)
    XCTAssertTrue(application.staticTexts["Museum reading"].firstMatch.exists)
  }

  func testDelayedPreviousGuideCannotReplaceTheNewItineraryReader() async throws {
    #if os(iOS)
      guard UIDevice.current.userInterfaceIdiom == .pad else {
        throw XCTSkip("This journey requires simultaneous Itinerary and reader panes.")
      }
    #endif
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    let garden = destination.deletingLastPathComponent().appendingPathComponent("garden")
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let (firstLink, secondLink) = createLinkedItinerary(
      in: application, first: destination, second: garden)
    XCTAssertTrue(firstLink.waitForExistence(timeout: 10))
    XCTAssertTrue(secondLink.waitForExistence(timeout: 10))
    let firstIdentifier = firstLink.identifier
    let secondIdentifier = secondLink.identifier
    firstLink.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    page.links["Delayed guide"].activateForPlannerJourney()
    let requestDeadline = ContinuousClock.now.advanced(by: .seconds(5))
    while server.delayedRequestCount == 0, ContinuousClock.now < requestDeadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertEqual(server.delayedRequestCount, 1)
    XCTAssertTrue(secondLink.isHittable)
    secondLink.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    server.releaseDelayedResponses()
    let responseDeadline = ContinuousClock.now.advanced(by: .seconds(5))
    while server.delayedResponseOutcomes.isEmpty, ContinuousClock.now < responseDeadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertEqual(server.delayedResponseOutcomes.count, 1)
    let outcome = XCTAttachment(string: server.delayedResponseOutcomes.joined(separator: "\n"))
    outcome.name = "Old guide socket response outcome"
    outcome.lifetime = .keepAlways
    add(outcome)
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].exists)
    XCTAssertFalse(page.staticTexts["Museum guide fixture"].exists)
    XCTAssertFalse(application.staticTexts["Page unavailable"].firstMatch.exists)
    XCTAssertFalse(application.buttons["saved.browser.back"].isEnabled)
    try await recordWindow(application, name: "Delayed previous guide cannot replace Garden")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    XCTAssertTrue(firstLink.waitForExistence(timeout: 10))
    XCTAssertEqual(firstLink.identifier, firstIdentifier)
    XCTAssertEqual(secondLink.identifier, secondIdentifier)
    XCTAssertEqual(firstLink.value as? String, destination.absoluteString)
    XCTAssertEqual(secondLink.value as? String, garden.absoluteString)
  }

  func testOpeningAnotherSavedItineraryLinkReplacesTheVisibleReader() async throws {
    #if os(iOS)
      guard UIDevice.current.userInterfaceIdiom == .pad else {
        throw XCTSkip("This journey requires simultaneous Itinerary and reader panes.")
      }
    #endif
    continueAfterFailure = false
    let server = try BrowserJourneyServer()
    let destination = try await server.start()
    let garden = destination.deletingLastPathComponent().appendingPathComponent("garden")
    defer { server.stop() }
    let application = XCUIApplication()
    application.launchArguments = ["--local-prototype-dataset", UUID().uuidString]
    application.launchSavedPlannerJourney()
    let (firstLink, secondLink) = createLinkedItinerary(
      in: application, first: destination, second: garden)
    XCTAssertTrue(firstLink.waitForExistence(timeout: 10))
    XCTAssertTrue(secondLink.waitForExistence(timeout: 10))
    let firstIdentifier = firstLink.identifier
    let secondIdentifier = secondLink.identifier
    firstLink.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    XCTAssertTrue(secondLink.isHittable)
    secondLink.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Garden guide fixture"].waitForExistence(timeout: 10))
    XCTAssertTrue(server.requestLines.contains("GET /garden HTTP/1.1"))
    XCTAssertFalse(application.buttons["saved.browser.back"].isEnabled)
    try await recordWindow(application, name: "Another saved link replaces the visible reader")
    application.buttons["saved.browser.return"].activateForPlannerJourney()
    XCTAssertTrue(firstLink.waitForExistence(timeout: 10))
    XCTAssertEqual(firstLink.identifier, firstIdentifier)
    XCTAssertEqual(secondLink.identifier, secondIdentifier)
    XCTAssertEqual(firstLink.value as? String, destination.absoluteString)
    XCTAssertEqual(secondLink.value as? String, garden.absoluteString)
  }

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

  func testDestinationNavigationClosesReaderAndPreservesTheBooking() async throws {
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
    let bookmarkIdentifier = links.firstMatch.identifier
    application.plannerElement("saved.item.actions").activateForPlannerJourney()
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
    let bookmark = application.descendants(matching: .any)
      .matching(identifier: bookmarkIdentifier).firstMatch
    XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
    for _ in 0..<6 where !bookmark.isHittable { application.swipeUp() }
    bookmark.activateForPlannerJourney()
    let page = application.webViews.firstMatch
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    try await recordWindow(
      application, name: "Calendar reader before explicit destination navigation")
    application.openPlannerSection("Items")
    XCTAssertEqual(application.state, .runningForeground)
    try await recordWindow(application, name: "Items selected from an open Calendar reader")
    XCTAssertTrue(page.waitForNonExistence(timeout: 10), application.debugDescription)
    XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
    XCTAssertEqual(bookmark.value as? String, destination.absoluteString)
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    application.openPlannerSection("Calendar")
    XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    for _ in 0..<6 where !bookmark.isHittable { application.swipeUp() }
    bookmark.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.openPlannerSection("Lists")
    XCTAssertEqual(application.state, .runningForeground)
    XCTAssertTrue(page.waitForNonExistence(timeout: 10), application.debugDescription)
    XCTAssertTrue(application.staticTexts["No Lists yet"].firstMatch.waitForExistence(timeout: 10))
    try await recordWindow(application, name: "Lists selected without inheriting the open reader")
    application.openPlannerSection("Items")
    XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
    for _ in 0..<6 where !bookmark.isHittable { application.swipeUp() }
    bookmark.activateForPlannerJourney()
    XCTAssertTrue(page.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
    application.openPlannerSection("Calendar")
    XCTAssertEqual(application.state, .runningForeground)
    XCTAssertTrue(page.waitForNonExistence(timeout: 10), application.debugDescription)
    XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
    XCTAssertEqual(bookmark.value as? String, destination.absoluteString)
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    try await recordWindow(
      application, name: "Calendar retains its exact booking after reader navigation")
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
    application.openPlannerSection("Items")
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    for _ in 0..<6 where !savedLink.isHittable { application.swipeUp() }
    savedLink.activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts["Museum guide fixture"]
        .waitForExistence(timeout: 10))
    XCTAssertEqual(returnToPlanner.label, "Return to item")
    returnToPlanner.activateForPlannerJourney()
    XCTAssertTrue(savedLink.waitForExistence(timeout: 10))
    application.openPlannerSection("Calendar")
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

  private func checkRememberedVisit(
    in application: XCUIApplication, server: BrowserJourneyServer,
    expectedHeading: String, expectedCookie: String
  ) {
    let check = application.webViews.firstMatch.links["Check visit"]
    XCTAssertTrue(check.waitForExistence(timeout: 5))
    check.activateForPlannerJourney()
    XCTAssertTrue(
      application.webViews.firstMatch.staticTexts[expectedHeading].waitForExistence(timeout: 10))
    XCTAssertEqual(server.visitorCookieValues.last, expectedCookie)
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

  private func createLinkedItinerary(
    in application: XCUIApplication, first: URL, second: URL
  ) -> (XCUIElement, XCUIElement) {
    application.openPlannerSection("Itineraries")
    application.plannerElement("saved.itinerary.new").activateForPlannerJourney()
    let title = application.textFields["saved.itinerary.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.activateForPlannerJourney()
    title.typeText("Museum and garden")
    let addLink = application.plannerElement("saved.itinerary.link.add")
    for _ in 0..<6 where !addLink.isHittable { application.swipeUp() }
    XCTAssertTrue(addLink.isHittable)
    addLink.activateForPlannerJourney()
    let firstInput = application.textFields.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.link.url.")
    ).firstMatch
    XCTAssertTrue(firstInput.waitForExistence(timeout: 5))
    let firstInputIdentifier = firstInput.identifier
    firstInput.activateForPlannerJourney()
    firstInput.typeText(first.absoluteString)
    for _ in 0..<6 where !addLink.isHittable { application.swipeUp() }
    XCTAssertTrue(addLink.isHittable)
    addLink.activateForPlannerJourney()
    let secondInput = application.textFields.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND identifier != %@",
        "saved.itinerary.link.url.", firstInputIdentifier)
    ).firstMatch
    XCTAssertTrue(secondInput.waitForExistence(timeout: 5))
    secondInput.activateForPlannerJourney()
    secondInput.typeText(second.absoluteString)
    application.plannerElement("saved.itinerary.save").activateForPlannerJourney()
    let firstLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@",
        "saved.item.link.", first.absoluteString)
    ).firstMatch
    let secondLink = application.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND value == %@", "saved.item.link.",
        second.absoluteString)
    ).firstMatch
    return (firstLink, secondLink)
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
