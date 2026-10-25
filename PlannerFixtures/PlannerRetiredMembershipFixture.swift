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

  static func makeStore(
    directory: URL, missingProvenance: Bool = false, includesItinerary: Bool = false,
    restoredSource: PlannerEntityKind? = nil
  ) async throws
    -> SavedPlannerStore
  {
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
      switch planner.decodeImport(
        try portableData(
          includesItinerary: includesItinerary, restoredSource: restoredSource))
      {
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
    try deliverRetiredCopy(
      configuration: configuration, missingProvenance: missingProvenance,
      restoredSource: restoredSource)
    return SavedPlannerStore(configuration: configuration)
  }

  /// Every launch redelivers the old native row before the production view opens its dataset.
  private static func deliverRetiredCopy(
    configuration: PlannerStorageConfiguration, missingProvenance: Bool,
    restoredSource: PlannerEntityKind?
  ) throws {
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
    if missingProvenance {
      guard
        let provenance = try context.fetch(FetchDescriptor<PlannerSchemaV19.MembershipProvenance>())
          .first(where: {
            $0.membershipId == retiredIdentifier && $0.membershipLifetimeId == retiredLifetime
          })
      else { throw CancellationError() }
      context.delete(provenance)
    }
    var deliveredItem = item
    if restoredSource == .item {
      let losing = try PlannerSchemaV18.Item(input: .init(title: "Losing hotel"))
      losing.id = itemIdentifier
      losing.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!
      losing.globalDone = true
      losing.archived = true
      context.insert(losing)
      deliveredItem = losing
      for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
      where entry.sourceKind == "item" && entry.sourceId == itemIdentifier {
        entry.sourceLifetimeId = losing.lifetimeId
        entry.item = losing
      }
    } else if restoredSource == .list {
      let losing = try PlannerSchemaV18.List(content: .init(name: "Losing plan"))
      losing.id = listIdentifier
      losing.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!
      losing.archived = true
      context.insert(losing)
      for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
      where entry.sourceKind == "list" && entry.sourceId == listIdentifier {
        entry.sourceLifetimeId = losing.lifetimeId
        entry.list = losing
      }
    }
    context.insert(
      PlannerSchemaV18.Membership(
        snapshot: .init(
          id: retiredIdentifier, lifetimeId: retiredLifetime,
          list: .init(kind: "list", id: listIdentifier, lifetimeId: listLifetime),
          item: .init(
            kind: "item", id: itemIdentifier, lifetimeId: deliveredItem.lifetimeId ?? itemLifetime),
          rank: 1024, localDone: true), list: list, item: deliveredItem))
    try context.save()
  }

  private static func portableData(
    includesItinerary: Bool, restoredSource: PlannerEntityKind?
  ) throws -> Data {
    var itemBinding: [String: Any] = [
      "kind": "item", "id": itemIdentifier.uuidString,
      "lifetimeId": "00000000-0000-4000-8000-000000000811",
    ]
    var listBinding: [String: Any] = [
      "kind": "list", "id": listIdentifier.uuidString,
      "lifetimeId": "00000000-0000-4000-8000-000000000821",
    ]
    let predecessor = restoredSource == .item ? itemBinding : listBinding
    if restoredSource == .item {
      itemBinding["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    } else if restoredSource == .list {
      listBinding["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    }
    let canonical: [String: Any] = [
      "kind": "listMembership", "membershipId": originalIdentifier.uuidString,
      "membershipLifetimeId": originalLifetime.uuidString,
    ]
    var aliases: [[String: Any]] = [
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
        var attestedItem = itemBinding
        if restoredSource == .item && identifier == retiredIdentifier {
          attestedItem["lifetimeId"] = "00000000-0000-4000-8000-000000000815"
        }
        return [
          "membershipId": identifier.uuidString, "membershipLifetimeId": lifetime.uuidString,
          "item": attestedItem, "list": listBinding, "observedRemovalIds": [],
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
    var sources = [item, list]
    var entries: [[String: Any]] = []
    if includesItinerary {
      let itineraryBinding: [String: Any] = [
        "kind": "itinerary", "id": "00000000-0000-4000-8000-000000000301",
        "lifetimeId": "00000000-0000-4000-8000-000000000831",
      ]
      sources.append(
        itineraryBinding.merging([
          "createdAt": 10.25, "updatedAt": 20.125, "globalDone": NSNull(), "archived": false,
          "content": [
            "title": "Retired stop route", "notes": NSNull(), "color": NSNull(),
            "iconName": NSNull(), "location": NSNull(), "manualEstimate": NSNull(),
          ], "contentOrigins": ["title": "independent"],
        ]) { _, incoming in incoming })
      for (index, entryIdentifier, entryLifetime) in [
        (0, "00000000-0000-4000-8000-000000000451", "00000000-0000-4000-8000-000000000851"),
        (1, "00000000-0000-4000-8000-000000000452", "00000000-0000-4000-8000-000000000852"),
      ] {
        entries.append([
          "id": entryIdentifier, "lifetimeId": entryLifetime, "itinerary": itineraryBinding,
          "source": listBinding, "rank": String((index + 1) * 1024), "localDone": NSNull(),
        ])
        let canonicalExpanded: [String: Any] = [
          "kind": "expandedListItem", "listEntryId": entryIdentifier,
          "listEntryLifetimeId": entryLifetime, "membershipId": originalIdentifier.uuidString,
          "membershipLifetimeId": originalLifetime.uuidString,
        ]
        for (offset, membershipIdentifier, membershipLifetime) in [
          (1, originalIdentifier, originalLifetime), (2, retiredIdentifier, retiredLifetime),
        ] {
          let context = canonicalExpanded.merging([
            "membershipId": membershipIdentifier.uuidString,
            "membershipLifetimeId": membershipLifetime.uuidString,
          ]) { _, incoming in incoming }
          aliases.append([
            "aliasId": "00000000-0000-4000-8000-000000000\(860 + index * 10 + offset)",
            "context": context, "canonicalContext": canonicalExpanded,
            "initialDone": index == 1 && offset == 2, "currentChangeId": NSNull(),
          ])
        }
      }
      entries.append([
        "id": "00000000-0000-4000-8000-000000000453",
        "lifetimeId": "00000000-0000-4000-8000-000000000853",
        "itinerary": itineraryBinding, "source": itemBinding, "rank": "3072", "localDone": false,
      ])
    }
    var graph: [String: Any] = [
      "format": "planner-data", "formatVersion": 3, "sources": sources,
      "memberships": [], "itineraryEntries": entries, "expandedCompletions": [],
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
    ]
    if restoredSource != nil {
      graph["formatVersion"] = 5
      graph["restorationFamilies"] = [
        [
          "familyId": "00000000-0000-4000-8000-000000000890", "predecessor": predecessor,
          "candidates": [
            [
              "lifetimeId": "00000000-0000-4000-8000-000000000814",
              "operationId": "00000000-0000-4000-8000-000000000994",
            ],
            [
              "lifetimeId": "00000000-0000-4000-8000-000000000815",
              "operationId": "00000000-0000-4000-8000-000000000995",
            ],
          ],
        ]
      ]
      var markers = graph["deletionMarkers"] as? [[String: Any]] ?? []
      markers.append([
        "deletionId": "00000000-0000-4000-8000-000000000892",
        "operationId": "00000000-0000-4000-8000-000000000992",
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ])
      graph["deletionMarkers"] = markers
    }
    return try JSONSerialization.data(withJSONObject: graph)
  }
}
