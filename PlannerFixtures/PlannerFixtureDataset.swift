import Foundation
import PlannerCore

@MainActor
enum PlannerFixtureDataset {
  private enum Scenario: String {
    case catalogOverflow = "catalog-overflow"
    case calendarClockAlignment = "calendar-clock-alignment"
    case calendarRepeatedTimes = "calendar-repeated-times"
    case calendarRepeatedSpan = "calendar-repeated-span"
    case calendarRepeatedShortSpan = "calendar-repeated-short-span"
    case calendarLatePoint = "calendar-late-point"
    case retainedRecovery = "retained-recovery"
    case conflictingRecovery = "conflicting-recovery"
    case incompleteRecovery = "incomplete-recovery"
    case recoveryRetryFailure = "recovery-retry-failure"
    case unavailableRecovery = "unavailable-recovery"
    case unavailableStore = "unavailable-store"
    case graphRecovery = "graph-recovery"
    case pinnedAddress = "pinned-address"
    case pinnedEmptyName = "pinned-empty-name"
    case pinnedItinerary = "pinned-itinerary"
    case linkImage = "link-image"
    case linkOutcomes = "link-outcomes"
    case linkDelay = "link-delay"
    case addressCandidates = "address-candidates"
    case addressRetry = "address-retry"
    case addressDelay = "address-delay"
    case captureMaps = "capture-maps"
    case captureMapsRetry = "capture-maps-retry"
    case captureMapsDelay = "capture-maps-delay"

    var isMapsCapture: Bool {
      switch self {
      case .captureMaps, .captureMapsRetry, .captureMapsDelay: true
      default: false
      }
    }

    var recoveryAccess: PlannerRecoveryFixture.Access? {
      switch self {
      case .incompleteRecovery: .writable
      case .recoveryRetryFailure: .readOnly
      case .unavailableRecovery: .unavailable
      default: nil
      }
    }
  }

  static func makeStore() async throws -> SavedPlannerStore {
    let arguments = ProcessInfo.processInfo.arguments
    let scenarioName = try argument("--fixture", in: arguments) ?? Scenario.catalogOverflow.rawValue
    guard let scenario = Scenario(rawValue: scenarioName) else { throw CancellationError() }
    let identifier: UUID
    if let value = try argument("--fixture-dataset", in: arguments) {
      guard let parsed = UUID(uuidString: value) else { throw CancellationError() }
      identifier = parsed
    } else {
      identifier = UUID()
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerFixtures", isDirectory: true)
      .appendingPathComponent(scenario.rawValue, isDirectory: true)
      .appendingPathComponent(identifier.uuidString, isDirectory: true)
    if scenario == .unavailableStore {
      return try await PlannerUnavailableStoreFixture.makeStore(directory: directory)
    }
    if scenario == .graphRecovery {
      return try await PlannerRecoveryGraphFixture.makeStore(directory: directory)
    }
    if let recoveryAccess = scenario.recoveryAccess {
      return try await PlannerRecoveryFixture.makeStore(
        directory: directory, access: recoveryAccess)
    }
    if scenario == .retainedRecovery || scenario == .conflictingRecovery {
      return try await makeRetainedRecoveryStore(
        directory: directory, includesConflicts: scenario == .conflictingRecovery)
    }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner: PlannerCore.Planner
    if scenario.isMapsCapture {
      planner = PlannerCore.Planner(
        configuration: configuration,
        captureHTTPTransport: FixtureCaptureHTTPTransport(
          failingFirstRequest: scenario == .captureMapsRetry,
          responseDelay: scenario == .captureMapsDelay ? .seconds(6) : .zero))
    } else {
      planner = PlannerCore.Planner(configuration: configuration)
    }
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(archive: .all)))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    if !window.rows.isEmpty {
      if scenario.isMapsCapture { return SavedPlannerStore(planner: planner) }
      return SavedPlannerStore(configuration: configuration)
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    if scenario == .calendarClockAlignment {
      try await PlannerClockAlignmentFixture.seed(planner, session: session)
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .calendarRepeatedSpan || scenario == .calendarRepeatedShortSpan {
      let startTimestamp =
        scenario == .calendarRepeatedShortSpan ? "2026-11-01T05:55:00Z" : "2026-11-01T05:30:00Z"
      let endTimestamp =
        scenario == .calendarRepeatedShortSpan ? "2026-11-01T06:05:00Z" : "2026-11-01T06:30:00Z"
      guard
        let item = try await save(.createItem(content: .init(title: "Clock-change museum")))
          .generated.first,
        let start = ISO8601DateFormatter().date(from: startTimestamp),
        let end = ISO8601DateFormatter().date(from: endTimestamp)
      else { throw CancellationError() }
      _ = try await save(
        .createSchedule(
          source: item,
          form: .timed(start: start, end: end, planningTimeZone: "America/New_York")))
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .calendarRepeatedTimes || scenario == .calendarLatePoint {
      let title: String
      let timestamps: [String]
      if scenario == .calendarLatePoint {
        title = "Late museum"
        timestamps = ["2026-11-02T04:59:00Z"]
      } else {
        title = "Repeated-hour museum"
        timestamps = ["2026-11-01T05:30:00Z", "2026-11-01T06:30:00Z"]
      }
      guard
        let item = try await save(.createItem(content: .init(title: title)))
          .generated.first
      else { throw CancellationError() }
      let formatter = ISO8601DateFormatter()
      for timestamp in timestamps {
        guard let start = formatter.date(from: timestamp) else { throw CancellationError() }
        _ = try await save(
          .createSchedule(
            source: item,
            form: .timed(start: start, end: nil, planningTimeZone: "America/New_York")))
      }
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario.isMapsCapture {
      _ = try await save(.createItem(content: .init(title: "Existing")))
      return SavedPlannerStore(planner: planner)
    }
    if scenario == .linkDelay {
      _ = try await save(
        .createItem(
          content: .init(
            title: "Delayed website", notes: "Original notes",
            links: [.init(originalUrl: "https://fixtures.invalid/delayed", label: "Saved website")]
          )))
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .linkImage {
      _ = try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Original notes",
            links: [.init(originalUrl: "https://fixtures.invalid/image", label: "Museum guide")]
          )))
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .linkOutcomes {
      _ = try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Original notes",
            links: [
              .init(originalUrl: "https://fixtures.invalid/plain", label: "Plain website"),
              .init(originalUrl: "https://fixtures.invalid/retry", label: "Recoverable website"),
            ])))
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .addressDelay {
      _ = try await save(
        .createItem(
          content: .init(
            title: "Delayed place", notes: "Original notes",
            location: .init(
              displayName: "Saved location", formattedAddress: "Fixture delayed address",
              coordinate: nil))))
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .addressRetry {
      _ = try await save(
        .createItem(
          content: .init(
            title: "Retry place", notes: "Original notes",
            location: .init(
              displayName: "Saved location", formattedAddress: "Fixture retry address",
              coordinate: nil))))
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .addressCandidates {
      for (title, address) in [
        ("Unmatched place", "Fixture no matches"),
        ("Ambiguous place", "Fixture multiple matches"),
      ] {
        _ = try await save(
          .createItem(
            content: .init(
              title: title, notes: "Original notes",
              location: .init(
                displayName: "Saved location", formattedAddress: address, coordinate: nil))))
      }
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .pinnedItinerary {
      guard
        let item = try await save(.createItem(content: .init(title: "Route child"))).generated
          .first,
        let itinerary = try await save(
          .createItinerary(
            content: .init(
              title: "Museum route", notes: "Keep these route notes",
              location: .init(
                displayName: "Museum entrance", formattedAddress: "Original address",
                coordinate: .init(latitude: 35.662, longitude: 139.717))))
        )
        .generated.first
      else { throw CancellationError() }
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
      return SavedPlannerStore(configuration: configuration)
    }
    if scenario == .pinnedAddress || scenario == .pinnedEmptyName {
      let displayName = scenario == .pinnedEmptyName ? "" : "Museum entrance"
      _ = try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Original notes",
            location: .init(
              displayName: displayName, formattedAddress: "Original address",
              coordinate: .init(latitude: 35.662, longitude: 139.717)))))
      return SavedPlannerStore(configuration: configuration)
    }
    guard
      let list = try await save(
        .createList(
          content: .init(
            name: "Overflow budget", manualEstimate: .init(minutes: 240, displayUnit: .hour)))
      ).generated.first
    else { throw CancellationError() }
    for (title, minutes) in [("Long activity", Int64.max), ("Short activity", Int64(1))] {
      guard
        let item = try await save(
          .createItem(
            content: .init(
              title: title, estimate: .init(minutes: minutes, displayUnit: .year)))
        ).generated.first
      else { throw CancellationError() }
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    return SavedPlannerStore(configuration: configuration)
  }

  private static func makeRetainedRecoveryStore(directory: URL, includesConflicts: Bool)
    async throws
    -> SavedPlannerStore
  {
    func configuration(for name: String) -> PlannerStorageConfiguration {
      let datasetDirectory = directory.appendingPathComponent(name, isDirectory: true)
      return .init(
        storeURL: datasetDirectory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: datasetDirectory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
    }
    let currentConfiguration = configuration(for: "current")
    let currentPlanner = PlannerCore.Planner(configuration: currentConfiguration)
    guard case .ready(let currentSession) = await currentPlanner.bootstrap(),
      case .snapshot(let snapshot) = await currentPlanner.query(
        .init(session: currentSession, request: .items(.init(archive: .all)))),
      case .rows(let window) = await currentPlanner.read(
        session: currentSession,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    if !window.rows.isEmpty { return SavedPlannerStore(configuration: currentConfiguration) }

    let retainedPlanner = PlannerCore.Planner(configuration: configuration(for: "retained"))
    guard case .ready(let retainedSession) = await retainedPlanner.bootstrap() else {
      throw CancellationError()
    }
    let retainedCommands: [PlannerCommand] = [
      .createTag(content: .init(name: "Retained travel tag")),
      .createItem(
        content: .init(
          title: "Retained museum", notes: includesConflicts ? "Retained museum notes" : nil)),
    ]
    for command in retainedCommands {
      guard
        case .applied(_, .complete) = await retainedPlanner.execute(
          .init(operationId: UUID(), session: retainedSession, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    if includesConflicts {
      try await seedRecoveryConflicts(
        retainedPlanner: retainedPlanner, retainedSession: retainedSession,
        currentPlanner: currentPlanner, currentSession: currentSession)
    }
    let currentCommands: [PlannerCommand] = [
      .createTag(content: .init(name: "Current travel tag")),
      .createItem(content: .init(title: "Current hotel")),
    ]
    for command in currentCommands {
      guard
        case .applied(_, .complete) = await currentPlanner.execute(
          .init(operationId: UUID(), session: currentSession, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    return SavedPlannerStore(configuration: currentConfiguration)
  }

  private static func seedRecoveryConflicts(
    retainedPlanner: PlannerCore.Planner, retainedSession: PlannerDatasetSession,
    currentPlanner: PlannerCore.Planner, currentSession: PlannerDatasetSession
  ) async throws {
    guard case .exported(let data) = await retainedPlanner.exportData(session: retainedSession),
      case .decoded(let backup) = currentPlanner.decodeImport(data),
      case .reviewed(let review) = await currentPlanner.prepareReview(
        session: currentSession, command: .applyImport(backup: backup)),
      case .applied(_, .complete) = await currentPlanner.execute(
        .init(
          operationId: UUID(), session: currentSession, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      let item = backup.backup.items.first,
      let tagSource = backup.backup.sources.first(where: {
        if case .tag = $0 { return true }
        return false
      }),
      case .tag(let tag) = tagSource,
      case .source(.item(let currentItem)) = await currentPlanner.read(
        session: currentSession, request: .source(.init(kind: .item, id: item.id))),
      case .source(.tag(let currentTag)) = await currentPlanner.read(
        session: currentSession, request: .source(.init(kind: .tag, id: tag.id))),
      let notesHash = currentItem.fieldHashes[.notes],
      let nameHash = currentTag.fieldHashes[.name]
    else { throw CancellationError() }
    let commands: [PlannerCommand] = [
      .editItem(
        sourceId: item.id, changes: .init(notes: .set("Current museum notes")),
        expectedFieldHashes: [.notes: notesHash]),
      .editTag(
        sourceId: tag.id, changes: .init(name: .set("Edited retained tag")),
        expectedFieldHashes: [.name: nameHash]),
    ]
    for command in commands {
      guard
        case .applied(_, .complete) = await currentPlanner.execute(
          .init(operationId: UUID(), session: currentSession, command: command)
        ).outcome
      else { throw CancellationError() }
    }
  }

  private static func argument(_ name: String, in arguments: [String]) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else { return nil }
    guard arguments.indices.contains(index + 1) else { throw CancellationError() }
    return arguments[index + 1]
  }
}

private actor FixtureCaptureHTTPTransport: PlannerCaptureHTTPTransport {
  let failingFirstRequest: Bool
  let responseDelay: Duration
  private var requestedURLs: Set<URL> = []

  init(failingFirstRequest: Bool, responseDelay: Duration) {
    self.failingFirstRequest = failingFirstRequest
    self.responseDelay = responseDelay
  }

  func head(requestURL: URL, timeout: Duration) async throws -> HTTPURLResponse {
    let firstRequest = requestedURLs.insert(requestURL).inserted
    try await Task.sleep(for: responseDelay)
    guard
      let response = HTTPURLResponse(
        url: requestURL, statusCode: failingFirstRequest && firstRequest ? 503 : 200,
        httpVersion: "HTTP/1.1", headerFields: [:])
    else { throw URLError(.badServerResponse) }
    return response
  }
}
