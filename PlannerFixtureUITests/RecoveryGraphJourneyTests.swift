import XCTest

#if os(iOS)
  @MainActor
  final class RecoveryGraphJourneyTests: XCTestCase {
    func testReviewedRecoveryRestoresAnEmptyPlannerWithRepeatedReferencesAndSavedState() throws {
      continueAfterFailure = false
      let application = XCUIApplication()
      application.launchArguments = [
        "--fixture", "graph-recovery", "--fixture-dataset", UUID().uuidString,
      ]
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      XCTAssertFalse(application.savedPlannerItemRows("Recovery museum").firstMatch.exists)
      try openRetainedGraph(application)
      let museumIdentifier = try sourceIdentifier("Recovery museum", kind: "item", in: application)
      let lunchIdentifier = try sourceIdentifier("Recovery lunch", kind: "item", in: application)
      let categoryIdentifier = try sourceIdentifier(
        "Recovery culture", kind: "category", in: application)
      let tagIdentifier = try sourceIdentifier("Recovery rainy day", kind: "tag", in: application)
      let listIdentifier = try sourceIdentifier("Recovery food list", kind: "list", in: application)
      let itineraryIdentifier = try sourceIdentifier(
        "Recovery weekend", kind: "itinerary", in: application)
      for count in [
        "List memberships, 2", "Itinerary entries, 3", "Schedules, 2", "Label associations, 4",
        "Bookmarks, 1",
      ] {
        let referenceCount = application.staticTexts[count]
        reveal(referenceCount, in: application)
        XCTAssertTrue(referenceCount.exists, application.debugDescription)
      }
      capture(
        "Retained recovery graph includes memberships, entries, labels, bookmarks and Schedules")
      let restore = application.plannerElement("saved.recovery.restore.review")
      reveal(restore, in: application, upward: false)
      restore.activateForPlannerJourney()
      let additions = application.staticTexts["saved.import.summary.additions"]
      XCTAssertTrue(additions.waitForExistence(timeout: 10), application.debugDescription)
      XCTAssertEqual(additions.label, "Additions, 6")
      capture(
        "Recovery review includes six sources and their saved Schedules for the empty Planner")
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      closeRecovery(application)
      application.openPlannerSection("Items")
      XCTAssertFalse(application.plannerElement("saved.item.\(museumIdentifier)").exists)
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      XCTAssertFalse(application.savedPlannerItemRows("Recovery museum").firstMatch.exists)
      try openRetainedGraph(application)
      XCTAssertEqual(
        try sourceIdentifier("Recovery museum", kind: "item", in: application), museumIdentifier)
      reveal(restore, in: application, upward: false)
      restore.activateForPlannerJourney()
      XCTAssertTrue(additions.waitForExistence(timeout: 10), application.debugDescription)
      XCTAssertEqual(additions.label, "Additions, 6")
      application.plannerElement("saved.import.confirm").activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["saved.recovery.restore.applied"].waitForExistence(timeout: 15))
      application.plannerElement("saved.import.close").activateForPlannerJourney()
      closeRecovery(application)
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Items")
      let museum = application.plannerElement("saved.item.\(museumIdentifier)")
      XCTAssertTrue(museum.waitForExistence(timeout: 15))
      XCTAssertEqual(application.savedPlannerItemRows("Recovery museum").count, 1)
      XCTAssertTrue((museum.value as? String)?.contains("Recovery culture") == true)
      XCTAssertTrue((museum.value as? String)?.contains("Recovery rainy day") == true)
      museum.activateForPlannerJourney()
      XCTAssertTrue(
        application.staticTexts["Museum notes from retained data"].waitForExistence(timeout: 10))
      let globalCompletion = application.descendants(matching: .any)
        .matching(identifier: "saved.item.completion").firstMatch
      XCTAssertTrue(globalCompletion.waitForPlannerBooleanState(false))
      let schedule = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.item.schedule.")
      ).firstMatch
      reveal(schedule, in: application)
      XCTAssertTrue(schedule.exists)
      XCTAssertEqual(schedule.label, "Start only")
      XCTAssertTrue((schedule.value as? String)?.contains("Asia/Tokyo") == true)
      let link = application.descendants(matching: .any).matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label == %@", "saved.item.link.", "Museum map")
      ).firstMatch
      reveal(link, in: application)
      XCTAssertTrue(link.exists)
      XCTAssertTrue(link.waitForPlannerValue("https://maps.apple.com/?q=Tokyo"))
      application.openPlannerSection("Lists")
      let list = application.plannerElement("saved.list.\(listIdentifier)")
      revealNavigation(to: list, in: application)
      list.activateForPlannerJourney()
      let listFilters = application.plannerElement("saved.list.filters")
      application.chooseSavedPlannerStateFilter("All completion states", control: listFilters)
      application.chooseSavedPlannerStateFilter("All archive states", control: listFilters)
      XCTAssertTrue(application.staticTexts["2 of 2 items finished"].waitForExistence(timeout: 10))
      let membershipRows = application.buttons.matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label IN %@", "saved.appearance.",
          ["Recovery museum", "Recovery lunch"]))
      XCTAssertEqual(
        membershipRows.allElementsBoundByIndex.map(\.label), ["Recovery museum", "Recovery lunch"])
      let membershipIdentifiers = membershipRows.allElementsBoundByIndex.map(\.identifier)
      let membershipCompletion = application.plannerElement(
        membershipIdentifiers[0].replacingOccurrences(
          of: "saved.appearance.", with: "saved.appearance.completion."))
      XCTAssertTrue(membershipCompletion.waitForPlannerValue("Completed"))
      application.openPlannerSection("Itineraries")
      let itinerary = application.plannerElement("saved.itinerary.row.\(itineraryIdentifier)")
      revealNavigation(to: itinerary, in: application)
      itinerary.activateForPlannerJourney()
      let itineraryFilters = application.plannerElement("saved.itinerary.filters")
      application.chooseSavedPlannerStateFilter("All completion states", control: itineraryFilters)
      application.chooseSavedPlannerStateFilter("All archive states", control: itineraryFilters)
      XCTAssertTrue(application.staticTexts["2 of 4 items finished"].waitForExistence(timeout: 10))
      let itinerarySchedule = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.schedule.")
      ).firstMatch
      XCTAssertTrue(itinerarySchedule.exists)
      XCTAssertEqual(itinerarySchedule.label, "All day")
      let itineraryScheduleIdentifier = itinerarySchedule.identifier
      let itineraryScheduleDescription = try XCTUnwrap(itinerarySchedule.value as? String)
      XCTAssertFalse(itineraryScheduleDescription.isEmpty)
      let appearances = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.itinerary.appearance."))
      let lastMuseumAppearance = appearances.matching(
        NSPredicate(format: "label == %@", "Recovery museum")
      ).element(boundBy: 2)
      reveal(lastMuseumAppearance, in: application)
      XCTAssertEqual(
        appearances.allElementsBoundByIndex.map(\.label),
        ["Recovery museum", "Recovery museum", "Recovery lunch", "Recovery museum"])
      let appearanceIdentifiers = appearances.allElementsBoundByIndex.map(\.identifier)
      assertCompletion(
        ["Completed", "To do", "To do", "To do"], identifiers: appearanceIdentifiers,
        in: application)
      capture(
        "Restored route retains repeated Items, independent local completion and archived children")
      application.terminate()
      application.launchSavedPlannerJourney()
      XCTAssertTrue(application.buttons["Items"].firstMatch.waitForExistence(timeout: 20))
      application.openPlannerSection("Itineraries")
      revealNavigation(to: itinerary, in: application)
      itinerary.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["2 of 4 items finished"].waitForExistence(timeout: 10))
      reveal(lastMuseumAppearance, in: application)
      XCTAssertEqual(appearances.allElementsBoundByIndex.map(\.identifier), appearanceIdentifiers)
      assertCompletion(
        ["Completed", "To do", "To do", "To do"], identifiers: appearanceIdentifiers,
        in: application)
      reveal(itinerarySchedule, in: application, upward: false)
      XCTAssertEqual(itinerarySchedule.identifier, itineraryScheduleIdentifier)
      XCTAssertEqual(itinerarySchedule.value as? String, itineraryScheduleDescription)
      application.openPlannerSection("Lists")
      revealNavigation(to: list, in: application)
      list.activateForPlannerJourney()
      XCTAssertTrue(application.staticTexts["2 of 2 items finished"].waitForExistence(timeout: 10))
      XCTAssertEqual(
        membershipRows.allElementsBoundByIndex.map(\.identifier), membershipIdentifiers)
      XCTAssertTrue(membershipCompletion.waitForPlannerValue("Completed"))
      capture("Restored List identity, order and local completion remain after another relaunch")
      application.openPlannerSection("Items")
      application.chooseSavedPlannerStateFilter(
        "All archive states", control: application.plannerElement("saved.items.filters"))
      let lunch = application.plannerElement("saved.item.\(lunchIdentifier)")
      XCTAssertTrue(lunch.waitForExistence(timeout: 10))
      XCTAssertEqual(lunch.label, "Recovery lunch")
      application.openPlannerSection("Lists")
      application.openSavedPlannerSettings()
      application.plannerElement("saved.settings.labels").activateForPlannerJourney()
      let category = application.plannerElement("saved.category.\(categoryIdentifier)")
      let tag = application.plannerElement("saved.tag.\(tagIdentifier)")
      XCTAssertTrue(category.waitForExistence(timeout: 10))
      XCTAssertTrue(tag.exists)
      XCTAssertEqual(category.label, "Recovery culture")
      XCTAssertEqual(tag.label, "Recovery rainy day")
      capture("Restored shared labels retain their original source identities")

    }

    private func sourceIdentifier(_ name: String, kind: String, in application: XCUIApplication)
      throws -> String
    {
      let prefix = "saved.recovery.source.\(kind)."
      let source = application.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", prefix, name)
      ).firstMatch
      reveal(source, in: application)
      XCTAssertTrue(source.exists)
      return String(source.identifier.dropFirst(prefix.count))
    }

    private func openRetainedGraph(_ application: XCUIApplication) throws {
      application.openPlannerSection("Lists")
      application.openSavedPlannerSettings()
      application.plannerElement("saved.settings.recovery").activateForPlannerJourney()
      let snapshots = application.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "saved.recovery.snapshot."))
      XCTAssertTrue(snapshots.firstMatch.waitForExistence(timeout: 15))
      let count = snapshots.count
      for index in 0..<count {
        snapshots.element(boundBy: index).activateForPlannerJourney()
        XCTAssertTrue(
          application.staticTexts["saved.recovery.evidence"].waitForExistence(timeout: 10))
        let museum = application.descendants(matching: .any).matching(
          NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "saved.recovery.source.item.",
            "Recovery museum")
        ).firstMatch
        if museum.exists { return }
        application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      }
      XCTFail("The retained complete plan must be available.")
      throw CancellationError()
    }

    private func assertCompletion(
      _ expected: [String], identifiers: [String], in application: XCUIApplication
    ) {
      for (identifier, value) in zip(identifiers, expected) {
        let completion = application.plannerElement(
          identifier.replacingOccurrences(
            of: "saved.itinerary.appearance.", with: "saved.itinerary.completion."))
        XCTAssertTrue(completion.waitForPlannerValue(value))
      }
    }

    private func revealNavigation(to element: XCUIElement, in application: XCUIApplication) {
      if !element.waitForExistence(timeout: 2) {
        let sidebar = application.plannerElement("Show Sidebar")
        if sidebar.exists {
          sidebar.activateForPlannerJourney()
        } else {
          let back = application.navigationBars.buttons["BackButton"].firstMatch
          if back.exists { back.activateForPlannerJourney() }
        }
      }
      XCTAssertTrue(element.waitForExistence(timeout: 10))
    }

    private func reveal(
      _ element: XCUIElement, in application: XCUIApplication, upward: Bool = true
    ) {
      guard let form = application.collectionViews.allElementsBoundByIndex.last else {
        XCTFail("The recovery Form must be present.")
        return
      }
      for _ in 0..<8 {
        let visibleTop =
          (application.navigationBars.allElementsBoundByIndex.last?.frame.maxY ?? form.frame.minY)
          + 4
        let tabBarTop = application.tabBars.allElementsBoundByIndex.first(where: \.isHittable)?
          .frame.minY
        let visibleBottom = min(form.frame.maxY, tabBarTop ?? form.frame.maxY) - 4
        if element.exists && element.isHittable,
          element.frame.minY >= visibleTop, element.frame.maxY <= visibleBottom
        {
          return
        }
        let scrollDownward = element.exists ? element.frame.minY < visibleTop : !upward
        let start = form.coordinate(
          withNormalizedOffset: CGVector(dx: 0.98, dy: scrollDownward ? 0.35 : 0.75))
        let end = form.coordinate(
          withNormalizedOffset: CGVector(dx: 0.98, dy: scrollDownward ? 0.65 : 0.4))
        start.press(forDuration: 0.05, thenDragTo: end)
      }
      capture("Recovery control visibility failure")
      XCTFail(
        "The recovery control must be fully visible below native navigation. "
          + application.debugDescription)
    }

    private func closeRecovery(_ application: XCUIApplication) {
      application.plannerElement("saved.recovery.selection.done").activateForPlannerJourney()
      application.plannerElement("saved.recovery.done").activateForPlannerJourney()
      application.plannerElement("saved.settings.done").activateForPlannerJourney()
    }

    private func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
#endif
