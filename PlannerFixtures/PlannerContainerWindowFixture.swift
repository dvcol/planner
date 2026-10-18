import Foundation
import PlannerCore

@MainActor
enum PlannerContainerWindowFixture {
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
    guard case .decoded(let backup) = planner.decodeImport(try portableData()),
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
    let itemIdentifier = UUID().uuidString
    let itemLifetimeIdentifier = UUID().uuidString
    let itemReference: [String: Any] = [
      "kind": "item", "id": itemIdentifier, "lifetimeId": itemLifetimeIdentifier,
    ]
    var sources: [[String: Any]] = [
      [
        "kind": "item", "id": itemIdentifier, "lifetimeId": itemLifetimeIdentifier,
        "createdAt": 813_000_000, "updatedAt": 813_000_000,
        "content": [
          "title": "Window source", "subtitle": NSNull(), "notes": "Window source notes",
          "location": NSNull(), "estimate": ["minutes": "5", "displayUnit": "minute"],
        ],
        "globalDone": false, "archived": false,
        "contentOrigins": ["title": "independent", "notes": "independent"],
      ]
    ]
    var entries: [[String: Any]] = []
    for kind in ["list", "itinerary"] {
      for index in 1...193 {
        let identifier = UUID().uuidString
        let lifetimeIdentifier = UUID().uuidString
        let titleField = kind == "list" ? "name" : "title"
        let title = String(format: "Window %@ %03d", kind == "list" ? "List" : "Itinerary", index)
        var content: [String: Any] = [
          titleField: title, "notes": "Container \(kind) notes \(index)",
          "color": NSNull(), "iconName": NSNull(),
          "manualEstimate": ["minutes": String(index * 5), "displayUnit": "minute"],
        ]
        if kind == "itinerary" { content["location"] = NSNull() }
        sources.append([
          "kind": kind, "id": identifier, "lifetimeId": lifetimeIdentifier,
          "createdAt": 813_000_000 + index, "updatedAt": 813_000_000 + index,
          "content": content, "globalDone": NSNull(), "archived": false,
          "contentOrigins": [titleField: "independent", "notes": "independent"],
        ])
        if kind == "itinerary" {
          entries.append([
            "id": UUID().uuidString, "lifetimeId": UUID().uuidString,
            "itinerary": ["kind": kind, "id": identifier, "lifetimeId": lifetimeIdentifier],
            "source": itemReference, "rank": "1024", "localDone": false,
          ])
        }
      }
    }
    return try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": [], "itineraryEntries": entries, "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
  }
}
