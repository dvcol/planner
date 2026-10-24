import Foundation
import SwiftData
import Testing

@testable import Planner
@testable import PlannerCore

@MainActor
struct RetiredMembershipRoutingTests {
  @Test func aRetiredNativeCopyCannotReviveOrRetargetAnHTTPMembership() async throws {
    let (_, seedConfiguration, _) = try makePlannerIntentStorage()
    let seedPlanner = PlannerCore.Planner(configuration: seedConfiguration)
    guard case .ready(let seedSession) = await seedPlanner.bootstrap() else {
      throw CancellationError()
    }
    let item = try await create(
      .createItem(content: .init(title: "Hotel", notes: "Keep the shared notes")),
      planner: seedPlanner, session: seedSession)
    let list = try await create(
      .createList(content: .init(name: "Tokyo")), planner: seedPlanner, session: seedSession)
    guard case .exported(let initialData) = await seedPlanner.exportData(session: seedSession),
      case .decoded(let initialBackup) = seedPlanner.decodeImport(initialData)
    else { throw CancellationError() }
    let (_, configuration, _) = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let itemLifetime = try #require(initialBackup.backup.items.first?.lifetimeId)
    let listLifetime = try #require(initialBackup.backup.lists.first?.lifetimeId)
    let originalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let retiredIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!
    let originalLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000841")!
    let retiredLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000842")!
    var graph = try #require(
      JSONSerialization.jsonObject(with: initialData) as? [String: Any])
    let canonical: [String: Any] = [
      "kind": "listMembership", "membershipId": originalIdentifier.uuidString,
      "membershipLifetimeId": originalLifetime.uuidString,
    ]
    graph["contextAliases"] = [
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
    graph["membershipProvenance"] = [
      (originalIdentifier, originalLifetime), (retiredIdentifier, retiredLifetime),
    ].map { identifier, lifetime -> [String: Any] in
      [
        "membershipId": identifier.uuidString, "membershipLifetimeId": lifetime.uuidString,
        "item": ["kind": "item", "id": item.id.uuidString, "lifetimeId": itemLifetime.uuidString],
        "list": ["kind": "list", "id": list.id.uuidString, "lifetimeId": listLifetime.uuidString],
        "observedRemovalIds": [],
      ]
    }
    graph["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000891",
        "operationId": "00000000-0000-4000-8000-000000000991",
        "target": [
          "kind": "membership", "id": originalIdentifier.uuidString,
          "lifetimeId": originalLifetime.uuidString,
        ], "closedFamilyId": NSNull(),
      ]
    ]
    let decoding = planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
    guard case .decoded(let incoming) = decoding else {
      Issue.record("Retired-alias fixture must decode: \(decoding)")
      return
    }
    let reviewing = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: .overwrite))
    guard case .reviewed(let review) = reviewing else {
      Issue.record("Retired-alias fixture must be reviewable: \(reviewing)")
      return
    }
    let imported = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = imported.outcome else {
      Issue.record("Retired-alias fixture must be durably imported: \(imported)")
      return
    }
    guard case .exported(let beforeDelivery) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      try insertRetiredCopy(
        configuration: configuration, item: item, list: list,
        identifier: retiredIdentifier, lifetime: retiredLifetime)
      let empty = try await call(
        "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": [
            "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
            "completion": "all", "archive": "all",
          ],
        ], endpoint: endpoint, httpSession: httpSession)
      #expect(empty["matchingCount"] as? String == "0")
      #expect((empty["rows"] as? [Any])?.isEmpty == true)
      let emptyMap = try await call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "mapRows", "generation": try #require(empty["generation"] as? String),
            "offset": "0", "limit": "64",
          ],
        ], endpoint: endpoint, httpSession: httpSession)
      #expect(emptyMap["matchingCount"] as? String == "0")
      #expect((emptyMap["rows"] as? [Any])?.isEmpty == true)
      guard case .exported(let afterDelivery) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      #expect(afterDelivery == beforeDelivery)
      let addition: [String: Any] = [
        "formatVersion": 1, "operationId": UUID().uuidString,
        "command": [
          "type": "addMembership", "itemId": item.id.uuidString, "listId": list.id.uuidString,
          "placement": ["kind": "last"],
        ],
      ]
      let added = try await call(
        "planner_execute", arguments: addition, endpoint: endpoint, httpSession: httpSession)
      try #require(added["state"] as? String == "applied")
      let generated = try #require(
        (added["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      try #require(generated.count == 1)
      let replacement = try #require(generated.first?["id"] as? String)
      #expect(
        replacement != originalIdentifier.uuidString && replacement != retiredIdentifier.uuidString)
      guard case .exported(let afterAddition) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      for identifier in [originalIdentifier, retiredIdentifier] {
        let appearance: [String: Any] = [
          "kind": "listMembership", "listId": list.id.uuidString,
          "membershipId": identifier.uuidString,
        ]
        let missing = try await call(
          "planner_read",
          arguments: [
            "formatVersion": 1, "request": ["kind": "appearance", "appearance": appearance],
          ],
          endpoint: endpoint, httpSession: httpSession, isError: true)
        #expect((missing["reason"] as? [String: Any])?["code"] as? String == "missingReference")
        for command: [String: Any] in [
          [
            "type": "setCompletion", "scope": ["kind": "appearance", "appearance": appearance],
            "done": true,
          ],
          [
            "type": "removeMembership", "listId": list.id.uuidString,
            "membershipId": identifier.uuidString,
          ],
        ] {
          let operationIdentifier = UUID()
          let rejected = try await call(
            "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": operationIdentifier.uuidString, "command": command,
            ],
            endpoint: endpoint, httpSession: httpSession, isError: true)
          #expect(rejected["state"] as? String == "rejected")
          #expect((rejected["reason"] as? [String: Any])?["code"] as? String == "missingReference")
          guard
            case .noReliableEvidence = await planner.operationStatus(
              session: session, operationId: operationIdentifier)
          else { throw CancellationError() }
        }
      }
      try insertRetiredCopy(
        configuration: configuration, item: item, list: list,
        identifier: retiredIdentifier, lifetime: retiredLifetime)
      let retained = try await call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "appearance",
            "appearance": [
              "kind": "listMembership", "listId": list.id.uuidString, "membershipId": replacement,
            ],
          ],
        ], endpoint: endpoint, httpSession: httpSession)
      let value = try #require(retained["value"] as? [String: Any])
      #expect(value["localDone"] as? Bool == false)
      #expect(value["globalDone"] as? Bool == false)
      #expect(value["effectiveDone"] as? Bool == false)
      #expect((value["source"] as? [String: Any])?["id"] as? String == item.id.uuidString)
      let replay = try await call(
        "planner_execute", arguments: addition, endpoint: endpoint, httpSession: httpSession)
      #expect(NSDictionary(dictionary: replay).isEqual(to: added))
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .exported(let finalData) = await reopened.exportData(session: reopenedSession)
      else { throw CancellationError() }
      #expect(finalData == afterAddition)
    } catch {
      await listener.stop()
      throw error
    }
    await listener.stop()
  }

  private func create(
    _ command: PlannerCommand, planner: PlannerCore.Planner, session: PlannerDatasetSession
  ) async throws -> PlannerEntityReference {
    guard
      case .applied(let applied, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return try #require(applied.generated.first)
  }

  /// The second native writer supplies input; every behavioral assertion uses Core or actual HTTP.
  private func insertRetiredCopy(
    configuration: PlannerStorageConfiguration, item: PlannerEntityReference,
    list: PlannerEntityReference, identifier: UUID, lifetime: UUID
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let savedItem = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first { $0.id == item.id })
    let savedList = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first { $0.id == list.id })
    context.insert(
      PlannerSchemaV18.Membership(
        snapshot: .init(
          id: identifier, lifetimeId: lifetime,
          list: .init(kind: "list", id: list.id, lifetimeId: try #require(savedList.lifetimeId)),
          item: .init(kind: "item", id: item.id, lifetimeId: try #require(savedItem.lifetimeId)),
          rank: 1024, localDone: true), list: savedList, item: savedItem))
    try context.save()
  }

  private func call(
    _ name: String, arguments: [String: Any], endpoint: URL, httpSession: URLSession,
    isError: Bool = false
  ) async throws -> [String: Any] {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": "tools/call",
      "params": ["name": name, "arguments": arguments],
    ])
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 5
    let (data, response) = try await httpSession.data(for: request)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(envelope["error"] == nil)
    let result = try #require(envelope["result"] as? [String: Any])
    let structured = try #require(result["structuredContent"] as? [String: Any])
    try #require(result["isError"] as? Bool == isError, "Unexpected \(name) result: \(structured)")
    let text = try #require((result["content"] as? [[String: Any]])?.first?["text"] as? String)
    if name == "planner_read", isError {
      #expect(text == (structured["reason"] as? [String: Any])?["message"] as? String)
      return structured
    }
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: structured))
    return structured
  }
}
