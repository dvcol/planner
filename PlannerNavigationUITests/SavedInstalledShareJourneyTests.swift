#if os(iOS)
  import XCTest

  @MainActor
  final class SavedInstalledShareJourneyTests: XCTestCase {
    func testSafariShareCancelAndSaveUseTheInstalledSharedStore() async throws {
      try XCTSkipUnless(
        ProcessInfo.processInfo.environment["PLANNER_EMPTY_SHARED_STORE_TEST"] == "1",
        "Requires an explicitly prepared empty shared Planner store.")
      continueAfterFailure = false
      let server = try BrowserJourneyServer()
      let originalURL = try await server.start()
      defer { server.stop() }
      let application = XCUIApplication()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      let itemRows = application.buttons.matching(
        NSPredicate(format: "identifier MATCHES %@", "saved\\.item\\.[0-9A-Fa-f-]{36}"))
      recordShareScreenshot(application, name: "Fresh shared Planner store before Safari capture")
      XCTAssertEqual(itemRows.count, 0)

      let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
      safari.open(originalURL)
      XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10))
      XCTAssertTrue(safari.staticTexts["Museum guide fixture"].waitForExistence(timeout: 10))
      recordShareScreenshot(safari, name: "Safari opens the controlled guide")
      openPlannerShare(in: safari)
      let title = safari.textFields["saved.capture.title"]
      XCTAssertTrue(title.waitForExistence(timeout: 15))
      recordShareScreenshot(safari, name: "Installed extension reviews the Safari provider")
      safari.plannerElement("saved.capture.cancel").activateForPlannerJourney()
      XCTAssertTrue(title.waitForNonExistence(timeout: 10))
      application.activate()
      application.openPlannerSection("Items")
      XCTAssertEqual(itemRows.count, 0)

      safari.activate()
      openPlannerShare(in: safari)
      XCTAssertTrue(title.waitForExistence(timeout: 15))
      title.activateForPlannerJourney()
      if let initialTitle = title.value as? String {
        title.typeText(
          String(repeating: XCUIKeyboardKey.delete.rawValue, count: initialTitle.count))
      }
      title.typeText("Installed Share visit")
      XCTAssertTrue(title.waitForPlannerValue("Installed Share visit"))
      let addItem = safari.plannerElement("saved.capture.add")
      if !addItem.isEnabled {
        for _ in 0..<4 { safari.swipeUp() }
        recordShareScreenshot(safari, name: "Installed Share input and destination diagnostics")
        let diagnostics = XCTAttachment(string: safari.debugDescription)
        diagnostics.name = "Installed Share review before Add"
        diagnostics.lifetime = .keepAlways
        add(diagnostics)
      }
      XCTAssertTrue(addItem.isEnabled)
      addItem.activateForPlannerJourney()
      XCTAssertTrue(title.waitForNonExistence(timeout: 15))

      let backgroundState = application.state
      XCTAssertTrue(
        backgroundState == .runningBackground || backgroundState == .runningBackgroundSuspended)
      application.activate()
      let row = application.savedPlannerItemRows("Installed Share visit").firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(application.savedPlannerItemRows("Installed Share visit").count, 1)
      let itemIdentifier = row.identifier
      row.activateForPlannerJourney()
      let link = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND value == %@",
          "saved.item.link.", originalURL.absoluteString)
      ).firstMatch
      XCTAssertTrue(link.waitForExistence(timeout: 10))
      let linkIdentifier = link.identifier
      recordShareScreenshot(application, name: "Main app reads the installed Share save")
      application.terminate()
      application.launchSavedPlannerJourney()
      application.openPlannerSection("Items")
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertEqual(row.identifier, itemIdentifier)
      row.activateForPlannerJourney()
      XCTAssertTrue(
        application.descendants(matching: .any).matching(identifier: linkIdentifier).firstMatch
          .waitForExistence(timeout: 10))
      application.plannerElement("saved.item.actions").activateForPlannerJourney()
      application.plannerElement("saved.item.delete").activateForPlannerJourney()
      let confirmDeletion = application.plannerElement("saved.item.delete.confirm")
      XCTAssertTrue(confirmDeletion.waitForExistence(timeout: 10))
      confirmDeletion.activateForPlannerJourney()
      XCTAssertTrue(confirmDeletion.waitForNonExistence(timeout: 10))
      application.openPlannerSection("Items")
      XCTAssertTrue(row.waitForNonExistence(timeout: 10))
      XCTAssertEqual(itemRows.count, 0)
    }

    private func openPlannerShare(in safari: XCUIApplication) {
      let planner = safari.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", "Planner")
      ).firstMatch
      if !planner.exists {
        let share = safari.buttons["Share"].firstMatch
        if !share.exists {
          let pageMenu = safari.buttons["MoreMenuButton"]
          XCTAssertTrue(pageMenu.waitForExistence(timeout: 5))
          pageMenu.activateForPlannerJourney()
        }
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.activateForPlannerJourney()
      }
      if !planner.waitForExistence(timeout: 3) {
        let more = safari.cells["More"].firstMatch
        let applications = safari.cells.matching(identifier: "shareCell")
        for _ in 0..<16 {
          if planner.isHittable || more.isHittable { break }
          guard
            let visibleApplication = applications.allElementsBoundByIndex.first(where: {
              $0.isHittable
            })
          else {
            XCTFail("The native Share app row is unavailable.")
            return
          }
          visibleApplication.swipeLeft()
        }
        if !planner.isHittable {
          XCTAssertTrue(more.waitForExistence(timeout: 5))
          more.activateForPlannerJourney()
        }
      }
      XCTAssertTrue(planner.waitForExistence(timeout: 10))
      recordShareScreenshot(safari, name: "System Share sheet discovers Planner")
      planner.activateForPlannerJourney()
    }

    private func recordShareScreenshot(_ application: XCUIApplication, name: String) {
      let attachment = XCTAttachment(screenshot: application.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
