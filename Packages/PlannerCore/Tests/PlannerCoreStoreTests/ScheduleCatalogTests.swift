import Foundation
import PlannerCore
import Testing

struct ScheduleCatalogTests {
  @Test func scheduleCatalogKeepsEachAssignmentIdentityAndLiveOwnerTitlesAcrossWindowsAndReopen()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let empty) = await planner.query(
        .init(session: session, request: .catalog(.init(sourceKind: .schedule, archive: .all))))
    else {
      Issue.record("Schedule discovery must distinguish an empty catalog from unavailable.")
      return
    }
    #expect(empty.rows.isEmpty && empty.matchingCount == 0 && empty.rowPresentation == nil)
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep booking"))).generated
        .first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Hotel", notes: "Keep route")))
        .generated.first)
    let forms: [PlannerScheduleForm] = [
      .timed(
        start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
        planningTimeZone: "Asia/Tokyo"),
      .allDay(start: .init(year: 2020, month: 1, day: 1), end: nil),
      .allDay(
        start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11)),
    ]
    let owners = [item, item, itinerary]
    var schedules: [PlannerEntityReference] = []
    for (owner, form) in zip(owners, forms) {
      schedules.append(
        try #require(try await save(.createSchedule(source: owner, form: form)).generated.first))
    }
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await save(.setArchive(source: item, archived: true))
    _ = try await save(.setArchive(source: itinerary, archived: true))
    func catalog() async throws -> PlannerQuerySnapshot {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(session: session, request: .catalog(.init(sourceKind: .schedule, archive: .all))))
      else { throw CancellationError() }
      return snapshot
    }
    let snapshot = try await catalog()
    let expected = schedules.sorted { $0.id.uuidString < $1.id.uuidString }
    #expect(snapshot.rows == expected.map(PlannerRowIdentity.source))
    #expect(snapshot.matchingCount == 3 && snapshot.progress.isEmpty)
    #expect(snapshot.unresolvedReferences.isEmpty && snapshot.rowPresentation == nil)
    for (offset, references) in [(Int64(0), Array(expected.prefix(2))), (Int64(2), [expected[2]])] {
      guard
        case .rows(let window) = await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: offset, limit: 2))
      else { throw CancellationError() }
      #expect(window.rows.map(\.identity) == references.map(PlannerRowIdentity.source))
      #expect(window.rows.allSatisfy { $0.title == "Hotel" })
      #expect(
        window.rows.allSatisfy {
          $0.globalDone == nil && $0.localDone == nil && $0.effectiveDone == nil
            && $0.archived == nil
            && $0.scheduleSummary == .none
        })
    }
    for (index, schedule) in schedules.enumerated() {
      guard
        case .source(.schedule(let read)) = await planner.read(
          session: session, request: .source(schedule))
      else { throw CancellationError() }
      #expect(read.source == schedule)
      #expect(read.content.source == owners[index])
      #expect(read.content.form == forms[index])
    }
    _ = try await save(.removeSchedule(scheduleId: schedules[0].id))
    guard
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 2))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    let remaining = Array(schedules.dropFirst()).sorted { $0.id.uuidString < $1.id.uuidString }
    #expect(try await catalog().rows == remaining.map(PlannerRowIdentity.source))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let retained) = await reopened.query(
        .init(
          session: reopenedSession, request: .catalog(.init(sourceKind: .schedule, archive: .all)))),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.itinerary(let retainedItinerary)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(retained.rows == remaining.map(PlannerRowIdentity.source))
    #expect(retainedItem.content.notes == "Keep booking" && retainedItem.state.globalDone == true)
    #expect(retainedItem.state.archived == true && retainedItinerary.state.archived == true)
    #expect(retainedItinerary.content.notes == "Keep route")
  }

  @Test
  func scheduleCatalogRejectsRestrictionsAndRefreshesLiveOwnerTitlesWithoutChangingAssignments()
    async throws
  {
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
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let form = PlannerScheduleForm.allDay(start: .init(year: 2026, month: 10, day: 9), end: nil)
    var schedules: [PlannerEntityReference] = []
    for owner in [item, itinerary] {
      schedules.append(
        try #require(try await save(.createSchedule(source: owner, form: form)).generated.first))
    }
    guard
      case .snapshot(let issued) = await planner.query(
        .init(session: session, request: .catalog(.init(sourceKind: .schedule, archive: .all)))),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let originalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    for (query, path) in [
      (PlannerCatalogQuery(sourceKind: .schedule), "/query/archive"),
      (.init(sourceKind: .schedule, archive: .archived), "/query/archive"),
      (.init(sourceKind: .schedule, text: "Hotel", archive: .all), "/query/text"),
      (.init(sourceKind: .schedule, text: " ", archive: .all), "/query/text"),
    ] {
      guard
        case .failed(let failure) = await planner.query(
          .init(session: session, request: .catalog(query)))
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput" && failure.propertyPath == path)
    }
    guard
      case .rows(let unchanged) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 2)),
      case .listedNamespaces(let retainedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let retainedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let originalItinerary)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(unchanged.rows.map(\.identity) == issued.rows)
    #expect(retainedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(retainedRecovery.portableData == originalRecovery.portableData)
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        .init(
          operationId: UUID(), session: otherSession,
          command: .editItem(
            sourceId: item.id, changes: .init(title: .set("Renamed Hotel")),
            expectedFieldHashes: [.title: try #require(originalItem.fieldHashes[.title])]))
      ).outcome,
      case .applied(_, .complete) = await otherWriter.execute(
        .init(
          operationId: UUID(), session: otherSession,
          command: .editItinerary(
            sourceId: itinerary.id, changes: .init(title: .set("Renamed Weekend")),
            expectedFieldHashes: [.title: try #require(originalItinerary.fieldHashes[.title])]))
      ).outcome,
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .snapshot(let refreshed) = await planner.query(
        .init(
          session: session, request: .catalog(.init(sourceKind: .schedule, archive: .all)))),
      case .rows(let updated) = await planner.read(
        session: session, request: .rows(generation: refreshed.generation, offset: 0, limit: 2))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot" && refreshed.rows == issued.rows)
    #expect(updated.rows.first { $0.identity == .source(schedules[0]) }?.title == "Renamed Hotel")
    #expect(updated.rows.first { $0.identity == .source(schedules[1]) }?.title == "Renamed Weekend")
    for (index, schedule) in schedules.enumerated() {
      guard
        case .source(.schedule(let retained)) = await planner.read(
          session: session, request: .source(schedule))
      else { throw CancellationError() }
      #expect(retained.content.form == form && retained.content.source == [item, itinerary][index])
    }
  }
}
