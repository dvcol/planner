import Foundation
import SwiftData

@testable import PlannerCore

@MainActor
enum PlannerRetiredMembershipFixture {
  private static let itemIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000101")!
  private static let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
  private static let originalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
  private static let retiredIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!
  private static let originalLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000841")!
  private static let retiredLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000842")!

  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let existing) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    if existing.matchingCount == 0 {
      let backup: PlannerDecodedBackup
      switch planner.decodeImport(try portableData()) {
      case .decoded(let decoded): backup = decoded
      case .invalid(let failure): throw failure
      }
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .applyImport(backup: backup, mode: .overwrite)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: review.command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    try deliverRetiredCopy(configuration: configuration)
    return SavedPlannerStore(configuration: configuration)
  }

  /// Every launch redelivers the old native row before the production view opens its dataset.
  private static func deliverRetiredCopy(configuration: PlannerStorageConfiguration) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    guard
      let item = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first(
        where: { $0.id == itemIdentifier }), let itemLifetime = item.lifetimeId,
      let list = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first(
        where: { $0.id == listIdentifier }), let listLifetime = list.lifetimeId
    else { throw CancellationError() }
    context.insert(
      PlannerSchemaV18.Membership(
        snapshot: .init(
          id: retiredIdentifier, lifetimeId: retiredLifetime,
          list: .init(kind: "list", id: listIdentifier, lifetimeId: listLifetime),
          item: .init(kind: "item", id: itemIdentifier, lifetimeId: itemLifetime),
          rank: 1024, localDone: true), list: list, item: item))
    try context.save()
  }

  private static func portableData() throws -> Data {
    let itemBinding: [String: Any] = [
      "kind": "item", "id": itemIdentifier.uuidString,
      "lifetimeId": "00000000-0000-4000-8000-000000000811",
    ]
    let listBinding: [String: Any] = [
      "kind": "list", "id": listIdentifier.uuidString,
      "lifetimeId": "00000000-0000-4000-8000-000000000821",
    ]
    let canonical: [String: Any] = [
      "kind": "listMembership", "membershipId": originalIdentifier.uuidString,
      "membershipLifetimeId": originalLifetime.uuidString,
    ]
    let aliases: [[String: Any]] = [
      [
        "aliasId": "00000000-0000-4000-8000-000000000851", "context": canonical,
        "canonicalContext": canonical, "initialDone": false, "currentChangeId": NSNull(),
      ],
      [
        "aliasId": "00000000-0000-4000-8000-000000000852",
        "context": [
          "kind": "listMembership", "membershipId": retiredIdentifier.uuidString,
          "membershipLifetimeId": retiredLifetime.uuidString,
        ], "canonicalContext": canonical, "initialDone": true, "currentChangeId": NSNull(),
      ],
    ]
    let provenance = [(originalIdentifier, originalLifetime), (retiredIdentifier, retiredLifetime)]
      .map { identifier, lifetime -> [String: Any] in
        [
          "membershipId": identifier.uuidString, "membershipLifetimeId": lifetime.uuidString,
          "item": itemBinding, "list": listBinding, "observedRemovalIds": [],
        ]
      }
    let item = itemBinding.merging([
      "createdAt": 10.25, "updatedAt": 20.125, "globalDone": false, "archived": false,
      "content": [
        "title": "Retired stop hotel", "subtitle": NSNull(),
        "notes": "Keep the original hotel note",
        "location": NSNull(), "estimate": ["minutes": "30", "displayUnit": "minute"],
      ], "contentOrigins": ["title": "independent", "notes": "independent"],
    ]) { _, incoming in incoming }
    let list = listBinding.merging([
      "createdAt": 10.25, "updatedAt": 20.125, "globalDone": NSNull(), "archived": false,
      "content": [
        "name": "Retired stop plan", "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
        "manualEstimate": NSNull(),
      ], "contentOrigins": ["name": "independent"],
    ]) { _, incoming in incoming }
    return try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 3, "sources": [item, list],
      "memberships": [], "itineraryEntries": [], "expandedCompletions": [],
      "labelAssociations": [], "ownedLinks": [], "schedules": [], "completionChanges": [],
      "restorationFamilies": [], "membershipProvenance": provenance, "membershipRemovals": [],
      "contextAliases": aliases,
      "deletionMarkers": [
        [
          "deletionId": "00000000-0000-4000-8000-000000000891",
          "operationId": "00000000-0000-4000-8000-000000000991",
          "target": [
            "kind": "membership", "id": originalIdentifier.uuidString,
            "lifetimeId": originalLifetime.uuidString,
          ], "closedFamilyId": NSNull(),
        ]
      ],
    ])
  }
}
