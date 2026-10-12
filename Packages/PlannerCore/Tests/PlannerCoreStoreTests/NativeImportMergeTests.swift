import Foundation
import PlannerCore
import Testing

struct NativeImportMergeTests {
  @Test(arguments: [false, true], [false, true])
  func skipPreservesWholeOwnersAndImportsNewReferencesToCurrentSources(
    omitConflictedOwners: Bool, interleaveSourceIdentifiers: Bool
  )
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
    let itemIdentifierSuffix = interleaveSourceIdentifiers ? "0F0" : "101"
    let listIdentifierSuffix = interleaveSourceIdentifiers ? "010" : "201"
    let currentItemIdentifier = "00000000-0000-4000-8000-000000000\(itemIdentifierSuffix)"
    let currentListIdentifier = "00000000-0000-4000-8000-000000000\(listIdentifierSuffix)"
    let originalData = Data(
      String(decoding: try nativeImportFixtureData(), as: UTF8.self)
        .replacingOccurrences(
          of: "00000000-0000-4000-8000-000000000101", with: currentItemIdentifier
        )
        .replacingOccurrences(
          of: "00000000-0000-4000-8000-000000000201", with: currentListIdentifier
        ).utf8)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let original) = planner.decodeImport(originalData),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: original))
    else { throw CancellationError() }
    let seedResponse = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: seedReview.command,
        reviewToken: seedReview.reviewToken))
    guard case .applied(_, .complete) = seedResponse.outcome else {
      Issue.record("Restore valid independent fixture: \(seedResponse)")
      return
    }
    guard
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var incoming = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let newItemIdentifier = "00000000-0000-4000-8000-000000000103"
    let newListIdentifier = "00000000-0000-4000-8000-000000000203"
    let newItem: [String: Any] = [
      "kind": "item", "id": newItemIdentifier,
      "lifetimeId": "00000000-0000-4000-8000-000000000813",
      "createdAt": 30.0, "updatedAt": 40.0,
      "content": [
        "title": "Travel Adapter", "subtitle": NSNull(), "notes": NSNull(),
        "location": NSNull(), "estimate": NSNull(),
      ], "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
    ]
    let newList: [String: Any] = [
      "kind": "list", "id": newListIdentifier,
      "lifetimeId": "00000000-0000-4000-8000-000000000823",
      "createdAt": 30.0, "updatedAt": 40.0,
      "content": [
        "name": "New trip", "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
        "manualEstimate": NSNull(),
      ], "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
    ]
    let newMemberships: [[String: Any]] = [
      (
        "00000000-0000-4000-8000-000000000404",
        currentItemIdentifier, "00000000-0000-4000-8000-000000000811", "1024"
      ),
      (
        "00000000-0000-4000-8000-000000000405",
        newItemIdentifier, "00000000-0000-4000-8000-000000000813", "2048"
      ),
    ].map { identifier, itemIdentifier, itemLifetime, rank in
      [
        "id": identifier, "lifetimeId": identifier,
        "list": [
          "kind": "list", "id": newListIdentifier,
          "lifetimeId": "00000000-0000-4000-8000-000000000823",
        ],
        "item": ["kind": "item", "id": itemIdentifier, "lifetimeId": itemLifetime],
        "rank": rank, "localDone": false,
      ]
    }
    var sources = try #require(incoming["sources"] as? [[String: Any]])
    var expected = incoming
    expected["sources"] = sources + [newItem, newList]
    let currentMemberships = try #require(incoming["memberships"] as? [[String: Any]])
    expected["memberships"] = currentMemberships + newMemberships
    let museumIndex = try #require(
      sources.firstIndex { $0["id"] as? String == currentItemIdentifier })
    var museumContent = try #require(sources[museumIndex]["content"] as? [String: Any])
    museumContent["title"] = "Backup museum"
    sources[museumIndex]["content"] = museumContent
    sources[museumIndex]["globalDone"] = true
    sources.removeAll { $0["kind"] as? String == "tag" }
    if omitConflictedOwners {
      sources.removeAll {
        [currentItemIdentifier, currentListIdentifier].contains(
          $0["id"] as? String ?? "")
      }
    }
    incoming["sources"] = sources + [newItem, newList]
    var memberships = currentMemberships
    let membershipIndex = try #require(
      memberships.firstIndex { $0["id"] as? String == "00000000-0000-4000-8000-000000000401" })
    memberships[membershipIndex]["rank"] = "4096"
    memberships[membershipIndex]["localDone"] = false
    incoming["memberships"] = memberships + newMemberships
    var changes = try #require(incoming["completionChanges"] as? [[String: Any]])
    changes[0]["done"] = false
    incoming["completionChanges"] = changes
    let decoding = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decoding else {
      if case .invalid(let failure) = decoding { Issue.record("Decode merge fixture: \(failure)") }
      return
    }
    let reviewing = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: .skip))
    guard case .reviewed(let review) = reviewing else {
      Issue.record("Review merge fixture: \(reviewing)")
      return
    }
    let response = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome else {
      Issue.record("Apply independent new owners while retaining skipped whole owners: \(response)")
      return
    }
    #expect(
      Set(result.generated.map(\.id))
        == Set([UUID(uuidString: newItemIdentifier)!, UUID(uuidString: newListIdentifier)!]))
    for _ in 0..<2 {
      guard case .exported(let exported) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
      #expect(importMergeGraphMatches(actual, expected))
      guard
        case .reviewed(let repeatedReview) = await planner.prepareReview(
          session: session, command: .applyImport(backup: backup, mode: .skip)),
        case .applied(let repeated, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: repeatedReview.command,
            reviewToken: repeatedReview.reviewToken)
        ).outcome
      else { throw CancellationError() }
      #expect(repeated.generated.isEmpty)
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let reopenedGraph = try #require(
      JSONSerialization.jsonObject(with: reopenedData) as? [String: Any])
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(importMergeGraphMatches(reopenedGraph, expected))
    #expect(importMergeGraphMatches(recoveredGraph, expected))
  }
}

private func importMergeGraphMatches(_ actual: [String: Any], _ expected: [String: Any]) -> Bool {
  var normalizedActual = actual
  var normalizedExpected = expected
  for group in ["sources", "memberships"] {
    normalizedActual[group] = (actual[group] as? [[String: Any]])?.sorted {
      ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "")
    }
    normalizedExpected[group] = (expected[group] as? [[String: Any]])?.sorted {
      ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "")
    }
  }
  return NSDictionary(dictionary: normalizedActual).isEqual(to: normalizedExpected)
}
