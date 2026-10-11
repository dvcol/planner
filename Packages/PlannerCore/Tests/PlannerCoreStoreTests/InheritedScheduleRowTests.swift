import Foundation
import PlannerCore
import Testing

struct InheritedScheduleRowTests {
  @Test func inheritedPlanningTracksSurvivingPathsAndRetainsIndependentArchiveAndCompletion()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let result = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let applied, .complete) = result.outcome else {
        throw CancellationError()
      }
      return applied
    }
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Past trip"))).generated.first)
    _ = try await save(
      .createSchedule(
        source: itinerary, form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil)))
    var entries: [UUID] = []
    for _ in 0..<2 {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: hotel, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    _ = try await save(.setCompletion(scope: .globalItem(itemId: hotel.id), done: true))
    _ = try await save(.setArchive(source: hotel, archived: true))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    func query(_ scope: PlannerItemQuery.Scope = .global) async throws -> PlannerQuerySnapshot {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session, request: .items(.init(scope: scope, completion: .all, archive: .all)))
        )
      else { throw CancellationError() }
      return snapshot
    }
    func row(_ snapshot: PlannerQuerySnapshot) async throws -> PlannerRowRead {
      guard
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1)),
        let row = window.rows.first
      else { throw CancellationError() }
      return row
    }
    let original = try await query(.inbox)
    let inherited = try await row(original)
    #expect(inherited.scheduleSummary == .inScheduledPlan)
    #expect(inherited.globalDone == true && inherited.archived == true)
    _ = try await save(.removeItineraryEntry(itineraryId: itinerary.id, entryId: entries[0]))
    let surviving = try await row(query())
    #expect(surviving.scheduleSummary == .inScheduledPlan)
    guard
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: original.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    _ = try await save(.removeItineraryEntry(itineraryId: itinerary.id, entryId: entries[1]))
    let disconnected = try await row(query())
    #expect(disconnected.scheduleSummary == .none)
    let list = try #require(
      try await save(.createList(content: .init(name: "Retained list"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: hotel.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(.setArchive(source: list, archived: true))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let connected = try await row(query())
    #expect(connected.scheduleSummary == .inScheduledPlan)
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    let direct = try #require(
      try await save(.createSchedule(source: hotel, form: form)).generated.first)
    let appointed = try await row(query())
    #expect(
      appointed.scheduleSummary
        == .directItem(schedule: direct, owner: hotel, form: form, additionalCount: 0))
    _ = try await save(.removeSchedule(scheduleId: direct.id))
    let inheritedAgain = try await row(query())
    #expect(inheritedAgain.scheduleSummary == .inScheduledPlan)
    _ = try await save(.removeMembership(listId: list.id, membershipId: membershipId))
    let removed = try await row(query(.inbox))
    #expect(removed.scheduleSummary == .none)
    #expect(removed.globalDone == true && removed.archived == true)
  }

  @Test func itineraryAppearancesSelectOneActualPlanSpanInsteadOfTheItemsDirectAppointment()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let result = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let applied, .complete) = result.outcome else {
        Issue.record("The plan fixture must save: \(String(describing: result.outcome))")
        throw CancellationError()
      }
      return applied
    }
    let hotel = try #require(
      try await save(
        .createItem(
          content: .init(title: "Hotel", estimate: .init(minutes: 120, displayUnit: .hour)))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Trip"))).generated.first)
    _ = try await save(.addMembership(itemId: hotel.id, listId: list.id, placement: .last))
    for source in [hotel, list, hotel] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    let appointment = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400),
      end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo")
    let direct = try #require(
      try await save(.createSchedule(source: hotel, form: appointment)).generated.first)
    let firstSpan = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))
    let laterSpan = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 16), end: .init(year: 2026, month: 10, day: 18))
    let first = try #require(
      try await save(.createSchedule(source: itinerary, form: firstSpan)).generated.first)
    let later = try #require(
      try await save(.createSchedule(source: itinerary, form: laterSpan)).generated.first)
    for (instant, selected, form) in [
      (813_202_200.0, first, firstSpan), (813_720_600.0, later, laterSpan),
      (814_066_200.0, later, laterSpan),
    ] {
      let presentation = PlannerRowPresentationContext(
        referenceInstant: Date(timeIntervalSinceReferenceDate: instant),
        displayTimeZone: "Asia/Tokyo")
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .items(
              .init(
                scope: .itinerary(itinerary.id), completion: .all, archive: .all,
                sort: .init(mode: .manual), rowPresentation: presentation)))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 10))
      else { throw CancellationError() }
      #expect(window.rows.count == 3)
      #expect(snapshot.progress.first?.totalCount == 3)
      #expect(snapshot.progress.first?.doneCount == 0)
      #expect(window.rowPresentation == presentation)
      for row in window.rows {
        #expect(
          row.scheduleSummary
            == .itinerarySpan(schedule: selected, owner: itinerary, form: form, additionalCount: 1))
        #expect(row.estimate == .init(minutes: 120, displayUnit: .hour))
        #expect(row.localDone == false && row.globalDone == false)
      }
    }
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init()))),
      case .rows(let standalone) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(
      standalone.rows.first?.scheduleSummary
        == .directItem(schedule: direct, owner: hotel, form: appointment, additionalCount: 0))
  }

  @Test func listReachabilitySuppliesInheritedPlanningWithoutAnInventedAppointment() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let result = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let applied, .complete) = result.outcome else {
        Issue.record("The fixture action must save: \(String(describing: result.outcome))")
        throw CancellationError()
      }
      return applied
    }
    let hotel = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Hotel", notes: "Keep the booking",
            estimate: .init(minutes: 120, displayUnit: .hour)))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Trip"))).generated.first)
    _ = try await save(.addMembership(itemId: hotel.id, listId: list.id, placement: .last))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let presentation = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_924_000),
      displayTimeZone: "Asia/Tokyo")
    func rows(_ scope: PlannerItemQuery.Scope) async throws -> PlannerRowWindow {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .items(
              .init(scope: scope, completion: .all, archive: .all, rowPresentation: presentation)))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 10))
      else { throw CancellationError() }
      return window
    }
    let original = try await rows(.global)
    #expect(original.rows.count == 1)
    #expect(original.rows.first?.scheduleSummary == PlannerRowScheduleSummary.none)
    let schedule = try #require(
      try await save(
        .createSchedule(
          source: itinerary,
          form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil))
      ).generated.first)
    let global = try await rows(.global)
    let standalone = try await rows(.list(list.id))
    #expect(global.rows.count == 1 && standalone.rows.count == 1)
    #expect(global.rows.first?.scheduleSummary == .inScheduledPlan)
    #expect(standalone.rows.first?.scheduleSummary == .inScheduledPlan)
    #expect(global.rows.first?.estimate == .init(minutes: 120, displayUnit: .hour))
    #expect(global.rows.first?.globalDone == false)
    #expect(standalone.rows.first?.localDone == false)
    #expect(global.rowPresentation == presentation && standalone.rowPresentation == presentation)
    guard
      case .source(.item(let unchanged)) = await planner.read(
        session: session, request: .source(hotel))
    else { throw CancellationError() }
    #expect(unchanged.content.notes == "Keep the booking")
    #expect(unchanged.references.count == 1)
    _ = try await save(.removeSchedule(scheduleId: schedule.id))
    let unscheduled = try await rows(.global)
    #expect(unscheduled.rows.first?.scheduleSummary == PlannerRowScheduleSummary.none)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let snapshot) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init()))),
      case .rows(let retained) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(retained.rows.first?.identity == .source(hotel))
    #expect(retained.rows.first?.scheduleSummary == PlannerRowScheduleSummary.none)
    #expect(retained.rows.first?.estimate == .init(minutes: 120, displayUnit: .hour))
  }
}
