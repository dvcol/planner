import Foundation
import PlannerCore

@MainActor
enum PlannerListWindowFixture {
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
    let data = try portableData()
    let backup: PlannerDecodedBackup
    switch planner.decodeImport(data) {
    case .decoded(let decoded): backup = decoded
    case .invalid(let failure): throw failure
    }
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
    var sources: [[String: Any]] = []
    var memberships: [[String: Any]] = []
    let lists = ["Window Route", "Shared Item List"].map { name in
      (name: name, identifier: UUID().uuidString, lifetimeIdentifier: UUID().uuidString)
    }
    for list in lists {
      sources.append([
        "kind": "list", "id": list.identifier, "lifetimeId": list.lifetimeIdentifier,
        "createdAt": 813_000_000, "updatedAt": 813_000_000,
        "content": [
          "name": list.name, "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
          "manualEstimate": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
      ])
    }
    for index in 1...193 {
      let identifier = UUID().uuidString
      let lifetimeIdentifier = UUID().uuidString
      sources.append([
        "kind": "item", "id": identifier, "lifetimeId": lifetimeIdentifier,
        "createdAt": 813_000_000 + index, "updatedAt": 813_000_000 + index,
        "content": [
          "title": String(format: "Window Item %03d", index), "subtitle": NSNull(),
          "notes": "Window notes \(index)", "location": NSNull(),
          "estimate": ["minutes": "5", "displayUnit": "minute"],
        ],
        "globalDone": false, "archived": false,
        "contentOrigins": ["title": "independent", "notes": "independent"],
      ])
      let owners = index == 193 ? lists : Array(lists.prefix(1))
      for list in owners {
        memberships.append([
          "id": UUID().uuidString, "lifetimeId": UUID().uuidString,
          "list": ["kind": "list", "id": list.identifier, "lifetimeId": list.lifetimeIdentifier],
          "item": ["kind": "item", "id": identifier, "lifetimeId": lifetimeIdentifier],
          "rank": String(index * 1024), "localDone": false,
        ])
      }
    }
    return try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": memberships, "itineraryEntries": [], "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
  }
}
