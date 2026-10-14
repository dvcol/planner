import Foundation
import PlannerCore

@MainActor
enum PlannerFixtureDataset {
  private enum Scenario: String {
    case catalogOverflow = "catalog-overflow"
    case calendarRepeatedTimes = "calendar-repeated-times"
    case calendarLatePoint = "calendar-late-point"
    case pinnedAddress = "pinned-address"
    case pinnedEmptyName = "pinned-empty-name"
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
