import Foundation
import PlannerCore
import Testing

struct NativeImportMergeTests {
  @Test(arguments: ["referenceLifetime", "aliasIdentity", "changeIdentity"])
  func changedOwnedIdentitiesRejectWithoutPartialSourceReplacement(scenario: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var incoming = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var sources = try #require(incoming["sources"] as? [[String: Any]])
    var content = try #require(sources[0]["content"] as? [String: Any])
    content["title"] = "Must not partially overwrite"
    sources[0]["content"] = content
    incoming["sources"] = sources
    if scenario == "referenceLifetime" {
      var associations = try #require(incoming["labelAssociations"] as? [[String: Any]])
      associations[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000915"
      incoming["labelAssociations"] = associations
    } else {
      var aliases = try #require(incoming["contextAliases"] as? [[String: Any]])
      var changes = try #require(incoming["completionChanges"] as? [[String: Any]])
      if scenario == "aliasIdentity" {
        aliases[0]["aliasId"] = "00000000-0000-4000-8000-000000000915"
        changes[0]["aliasId"] = "00000000-0000-4000-8000-000000000915"
      } else {
        changes[0]["id"] = "00000000-0000-4000-8000-000000000991"
        aliases[0]["currentChangeId"] = "00000000-0000-4000-8000-000000000991"
      }
      incoming["contextAliases"] = aliases
      incoming["completionChanges"] = changes
    }
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decoded else {
      Issue.record("Decode identity-change gate: \(decoded)")
      return
    }
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .rejected(let failure) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else {
      Issue.record("Unsupported identity changes must leave no partial import: \(response)")
      return
    }
    #expect(failure.code == "unavailable")
    #expect(after == before)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == before)
  }

  @Test(arguments: [
    "memberships", "itineraryEntries", "expandedCompletions", "ownedLinks",
    "schedules", "contextAliases", "completionChanges",
  ])
  func retainedOwnedDataOverwritesPreserveBindingsAndHistory(group: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var incoming = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var sources = try #require(incoming["sources"] as? [[String: Any]])
    var content = try #require(sources[0]["content"] as? [String: Any])
    content["title"] = "Whole owner replacement"
    sources[0]["content"] = content
    incoming["sources"] = sources
    var records = try #require(incoming[group] as? [[String: Any]])
    switch group {
    case "memberships", "itineraryEntries": records[0]["rank"] = "4096"
    case "expandedCompletions": records[0]["localDone"] = true
    case "ownedLinks": records[0]["label"] = "Incoming label"
    case "schedules":
      var form = try #require(records[0]["form"] as? [String: Any])
      form["end"] = 813207600.0
      records[0]["form"] = form
    case "contextAliases": records[0]["initialDone"] = true
    default:
      records[0]["done"] = false
      var memberships = try #require(incoming["memberships"] as? [[String: Any]])
      memberships[0]["localDone"] = false
      incoming["memberships"] = memberships
    }
    incoming[group] = records
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decoded else {
      Issue.record("Decode changed owned data in \(group): \(decoded)")
      return
    }
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome else {
      Issue.record("Overwrite retained owned records and source fields together: \(response)")
      return
    }
    #expect(result.generated.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(importMergeGraphMatches(actual, incoming))
    #expect(importMergeGraphMatches(recovery, incoming))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .overwrite)),
      case .applied(let repeated, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
          reviewToken: repeatedReview.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.generated.isEmpty && repeatedData == after)
  }

  @Test func overwriteSourceFieldsPreservesReferencesAndHistoryAcrossSetAndClear() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let baselineData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let baseline = try #require(JSONSerialization.jsonObject(with: baselineData) as? [String: Any])
    for clearOptionalFields in [false, true] {
      var incoming = baseline
      let sources = try #require(baseline["sources"] as? [[String: Any]])
      incoming["sources"] = try sources.map { original in
        var source = original
        let kind = try #require(source["kind"] as? String)
        var content = try #require(source["content"] as? [String: Any])
        let nameField = content["title"] == nil ? "name" : "title"
        content[nameField] = "Incoming \(kind) \(clearOptionalFields ? "cleared" : "set")"
        let optionalContent: [String: Any] = [
          "notes": "Incoming notes", "subtitle": "Incoming subtitle", "iconName": "star",
          "estimate": ["minutes": "75", "displayUnit": "minute"],
          "manualEstimate": ["minutes": "75", "displayUnit": "minute"],
          "color": ["red": 0.125, "green": 0.5, "blue": 0.75, "alpha": 1.0],
          "location": [
            "displayName": "Incoming place", "formattedAddress": "Tokyo",
            "coordinate": ["latitude": 35.0, "longitude": 139.0],
          ],
        ]
        for (field, value) in optionalContent where content[field] != nil {
          content[field] = clearOptionalFields ? NSNull() : value
        }
        var origins = try #require(source["contentOrigins"] as? [String: String])
        for field in ["title", "name", "subtitle", "notes", "location"] where content[field] != nil
        {
          if content[field] is NSNull {
            origins.removeValue(forKey: field)
            continue
          }
          origins[field] = "independent"
        }
        source["content"] = content
        source["contentOrigins"] = origins
        source["createdAt"] = 60.0
        source["updatedAt"] = clearOptionalFields ? 80.0 : 70.0
        if kind == "item" { source["globalDone"] = !clearOptionalFields }
        if ["item", "list", "itinerary"].contains(kind) {
          source["archived"] = !clearOptionalFields
        }
        return source
      }
      let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
      guard case .decoded(let backup) = decoded else {
        Issue.record("Decode source-field replacement: \(decoded)")
        return
      }
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .applyImport(backup: backup, mode: .overwrite))
      else { throw CancellationError() }
      let operationIdentifier = UUID()
      let response = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken))
      guard case .applied(let result, .complete(let checkpoint)) = response.outcome else {
        Issue.record("Overwrite source fields without replacing references/history: \(response)")
        return
      }
      #expect(result.generated.isEmpty)
      let expectedAffected = try sources.map { source in
        PlannerEntityReference(
          kind: try #require(
            (source["kind"] as? String).flatMap(PlannerEntityKind.init(rawValue:))),
          id: try #require((source["id"] as? String).flatMap(UUID.init(uuidString:))))
      }
      #expect(Set(result.affected) == Set(expectedAffected))
      guard case .exported(let exported) = await planner.exportData(session: session),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovered) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
      let recovery = try #require(
        JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
      #expect(importMergeGraphMatches(actual, incoming))
      #expect(importMergeGraphMatches(recovery, incoming))
      let reopened = Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
        case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
          .init(
            operationId: operationIdentifier, session: reopenedSession, command: review.command)
        ).outcome,
        case .reviewed(let repeatReview) = await reopened.prepareReview(
          session: reopenedSession, command: .applyImport(backup: backup, mode: .overwrite)),
        case .applied(let repeated, .complete) = await reopened.execute(
          .init(
            operationId: UUID(), session: reopenedSession, command: repeatReview.command,
            reviewToken: repeatReview.reviewToken)
        ).outcome,
        case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
      else { throw CancellationError() }
      #expect(reopenedData == exported)
      #expect(replayed == result && replayCheckpoint == checkpoint)
      #expect(repeated.generated.isEmpty && repeatedData == exported)
    }
  }

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
