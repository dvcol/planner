import Foundation
import SwiftData
import Testing

@testable import PlannerCore

struct NativeRestorationCandidateProbeTests {
  @Test func aKnownLosingNativeItemCandidateRetainsTheDeclaredWinner() async throws {
    var incoming = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let sources = try #require(incoming["sources"] as? [[String: Any]])
    var museum = try #require(sources.first)
    museum["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    incoming["sources"] = [museum]
    for field in [
      "memberships", "itineraryEntries", "expandedCompletions", "schedules", "labelAssociations",
      "ownedLinks", "contextAliases", "completionChanges",
    ] {
      incoming[field] = []
    }
    let predecessor: [String: Any] = [
      "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
      "lifetimeId": "00000000-0000-4000-8000-000000000811",
    ]
    incoming["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000892",
        "operationId": "00000000-0000-4000-8000-000000000992",
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ]
    ]
    incoming["restorationFamilies"] = [
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
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let baseline) = planner.decodeImport(before)
    else { throw CancellationError() }
    #expect(baseline.backup.restorationFamilies.first?.candidates.count == 2)
    #expect(
      baseline.backup.items.first?.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
    try await deliverLosingCandidate(storeURL: configuration.storeURL)
    let query = await planner.query(
      .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    let read = await planner.read(
      session: session,
      request: .source(
        .init(kind: .item, id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)))
    guard case .snapshot(let contents) = query, case .source(.item(let item)) = read,
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record(
        "A fully declared losing candidate must retain the A20 winner: \(query), \(read)")
      return
    }
    #expect(contents.matchingCount == 1)
    #expect(item.content.title == "Nezu Museum" && item.content.notes == "Original notes")
    #expect(item.state.globalDone == false)
    let originalGraph = try #require(JSONSerialization.jsonObject(with: before) as? NSDictionary)
    #expect(try JSONSerialization.jsonObject(with: after) as? NSDictionary == originalGraph)
  }

  @MainActor private func deliverLosingCandidate(storeURL: URL) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let winner = try #require(context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first)
    let losing = try PlannerSchemaV18.Item(
      input: .init(title: "Other museum", notes: "The losing candidate must not replace the winner")
    )
    losing.id = winner.id
    losing.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!
    losing.createdAt = winner.createdAt
    losing.updatedAt = winner.updatedAt
    losing.globalDone = true
    context.insert(losing)
    try context.save()
  }
}
