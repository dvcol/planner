import Foundation
import PlannerCore

@MainActor
enum PlannerItineraryWindowFixture {
  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let initial) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    if initial.matchingCount > 0 { return SavedPlannerStore(configuration: configuration) }
    let decoded = planner.decodeImport(try portableData())
    guard case .decoded(let backup) = decoded else { throw CancellationError() }
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup))
    else { throw CancellationError() }
    let result = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
    return SavedPlannerStore(configuration: configuration)
  }

  private static func portableData() throws -> Data {
    let list = Identity(kind: "list")
    let route = Identity(kind: "itinerary")
    let reorderRoute = Identity(kind: "itinerary")
    var sources: [[String: Any]] = [
      list.record(
        content: [
          "name": "Route activities", "notes": NSNull(), "color": NSNull(),
          "iconName": NSNull(), "manualEstimate": NSNull(),
        ], originField: "name"),
      route.record(content: itineraryContent("Windowed route"), originField: "title"),
      reorderRoute.record(content: itineraryContent("Reorder route"), originField: "title"),
    ]
    var memberships: [[String: Any]] = []
    var items: [Identity] = []
    for index in 1...65 {
      let item = Identity(kind: "item")
      items.append(item)
      var record = item.record(
        content: [
          "title": String(format: "Window Activity %03d", index), "subtitle": NSNull(),
          "notes": "Window itinerary notes \(index)", "location": NSNull(),
          "estimate": ["minutes": "5", "displayUnit": "minute"],
        ], originField: "title")
      record["contentOrigins"] = ["title": "independent", "notes": "independent"]
      sources.append(record)
      memberships.append([
        "id": UUID().uuidString, "lifetimeId": UUID().uuidString,
        "list": list.reference, "item": item.reference, "rank": String(index * 1024),
        "localDone": false,
      ])
    }
    guard let first = items.first else { throw CancellationError() }
    var entries: [[String: Any]] = []
    for (index, source) in [first, list, list, first].enumerated() {
      entries.append(entry(owner: route, source: source, rank: index, done: false))
    }
    for (index, source) in items.prefix(3).enumerated() {
      entries.append(entry(owner: reorderRoute, source: source, rank: index, done: index == 0))
    }
    return try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": memberships, "itineraryEntries": entries, "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
  }

  private static func itineraryContent(_ title: String) -> [String: Any] {
    [
      "title": title, "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
      "location": NSNull(), "manualEstimate": NSNull(),
    ]
  }

  private static func entry(owner: Identity, source: Identity, rank: Int, done: Bool) -> [String:
    Any]
  {
    [
      "id": UUID().uuidString, "lifetimeId": UUID().uuidString,
      "itinerary": owner.reference, "source": source.reference, "rank": String((rank + 1) * 1024),
      "localDone": source.kind == "item" ? done as Any : NSNull(),
    ]
  }

  private struct Identity {
    let kind: String
    let identifier = UUID().uuidString
    let lifetimeIdentifier = UUID().uuidString

    var reference: [String: Any] {
      ["kind": kind, "id": identifier, "lifetimeId": lifetimeIdentifier]
    }

    func record(content: [String: Any], originField: String) -> [String: Any] {
      [
        "kind": kind, "id": identifier, "lifetimeId": lifetimeIdentifier,
        "createdAt": 813_000_000, "updatedAt": 813_000_000, "content": content,
        "globalDone": kind == "item" ? false as Any : NSNull(), "archived": false,
        "contentOrigins": [originField: "independent"],
      ]
    }
  }
}
