import Foundation
import PlannerCore
import Testing

struct NativeImportOwnedRemovalTests {
  @Test func explicitTodoClosurePreservesHistoryWithoutAStoredCompletionFlag() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    var seedGraph = try removalSeedGraph(group: "expandedCompletion")
    var expanded = try #require(seedGraph["expandedCompletions"] as? [[String: Any]])
    let removed = expanded.removeFirst()
    seedGraph["expandedCompletions"] = expanded
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: seedGraph)),
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
    var markers = try #require(incoming["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000994",
      "operationId": "00000000-0000-4000-8000-000000000995",
      "target": ["kind": "expandedCompletion", "context": try #require(removed["context"])],
      "closedFamilyId": NSNull(),
    ])
    incoming["deletionMarkers"] = markers
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite))
    else { throw CancellationError() }
    let response = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record("Apply a reviewed Todo closure with retained history and no flag: \(response)")
      return
    }
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: incoming))
  }

  @Test(
    arguments: [
      "membership", "directEntry", "listEntry", "expandedCompletion", "labelAssociation",
      "ownedLink", "schedule",
    ], [(false, false), (false, true), (true, false), (true, true)])
  func overwriteClosesRemovedReferencesAndRetainsTheirHistory(
    group: String, options: (explicitClosure: Bool, omitUnchangedOwners: Bool)
  ) async throws {
    let explicitClosure = options.explicitClosure
    let omitUnchangedOwners = options.omitUnchangedOwners
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let seedGraph = try removalSeedGraph(group: group)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: seedGraph)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let original = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let (expected, target) = try removalGraph(group: group, from: original)
    var incoming = expected
    if explicitClosure {
      var markers = try #require(incoming["deletionMarkers"] as? [[String: Any]])
      markers.append([
        "deletionId": "00000000-0000-4000-8000-000000000994",
        "operationId": "00000000-0000-4000-8000-000000000995", "target": target,
        "closedFamilyId": NSNull(),
      ])
      incoming["deletionMarkers"] = markers
    } else if ["membership", "directEntry", "listEntry", "expandedCompletion"].contains(group) {
      incoming["contextAliases"] = [[String: Any]]()
      incoming["completionChanges"] = [[String: Any]]()
    }
    if omitUnchangedOwners {
      let suffix = ["labelAssociation", "ownedLink", "schedule"].contains(group) ? "101" : "301"
      let ownerSuffix = group == "membership" ? "201" : suffix
      incoming["sources"] = try #require(incoming["sources"] as? [[String: Any]]).filter {
        ($0["id"] as? String)?.hasSuffix(ownerSuffix) == true
      }
    }
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decoded else {
      Issue.record("Decode removed \(group) with explicit closure \(explicitClosure): \(decoded)")
      return
    }
    for mode in [PlannerImportMode.skip, .overwrite] {
      let prepared = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: mode))
      guard case .reviewed(let review) = prepared else {
        Issue.record("Review removed \(group): \(prepared)")
        return
      }
      if mode == .overwrite {
        let removalCount = group == "membership" ? 2 : (group == "listEntry" ? 3 : 1)
        #expect(review.impact.referenceRemovals.count == removalCount)
        #expect(review.impact.sourceDeletes.count == (group == "schedule" ? 1 : 0))
      }
      let operationIdentifier = UUID()
      let response = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken))
      guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
        case .exported(let after) = await planner.exportData(session: session),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovered) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else {
        Issue.record("Apply \(mode) removing \(group): \(response)")
        return
      }
      var actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
      let recovery = try #require(
        JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
      #expect(NSDictionary(dictionary: recovery).isEqual(to: actual))
      #expect(result.generated.isEmpty)
      let appliedSummary = try #require(result.importSummary)
      #expect(appliedSummary.incomingDeletions == review.impact.importDetails?.incomingDeletions)
      if mode == .skip {
        #expect(after == before)
      } else {
        let markers = try #require(actual["deletionMarkers"] as? [[String: Any]])
        let originalMarkers = try #require(original["deletionMarkers"] as? [[String: Any]])
        let closure = try #require(
          markers.first {
            guard let actualTarget = $0["target"] as? [String: Any] else { return false }
            return NSDictionary(dictionary: actualTarget).isEqual(to: target)
          })
        #expect(markers.count == originalMarkers.count + 1)
        #expect(Set(closure.keys) == ["deletionId", "operationId", "target", "closedFamilyId"])
        let expectedOperationIdentifier: String
        if explicitClosure {
          expectedOperationIdentifier = "00000000-0000-4000-8000-000000000995"
        } else {
          expectedOperationIdentifier = operationIdentifier.uuidString
        }
        #expect(closure["operationId"] as? String == expectedOperationIdentifier)
        actual["deletionMarkers"] = originalMarkers
        #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
      }
      let reopened = Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
        case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
          .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
        ).outcome,
        case .reviewed(let repeatedReview) = await reopened.prepareReview(
          session: reopenedSession, command: .applyImport(backup: backup, mode: mode)),
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
      if mode == .overwrite {
        guard case .decoded(let obsolete) = reopened.decodeImport(before) else {
          throw CancellationError()
        }
        let obsoletePrepared = await reopened.prepareReview(
          session: reopenedSession, command: .applyImport(backup: obsolete, mode: .overwrite))
        let obsoleteOperationIdentifier = UUID()
        if case .reviewed(let obsoleteReview) = obsoletePrepared {
          let obsoleteResponse = await reopened.execute(
            .init(
              operationId: obsoleteOperationIdentifier, session: reopenedSession,
              command: obsoleteReview.command, reviewToken: obsoleteReview.reviewToken))
          guard case .rejected = obsoleteResponse.outcome else {
            Issue.record(
              "An obsolete backup must not resurrect a closed \(group): \(obsoleteResponse)")
            return
          }
        } else if case .failed(let failure) = obsoletePrepared {
          #expect(["invalidInput", "missingReference", "unavailable"].contains(failure.code))
        }
        guard
          case .noReliableEvidence = await reopened.operationStatus(
            session: reopenedSession, operationId: obsoleteOperationIdentifier),
          case .exported(let retainedData) = await reopened.exportData(session: reopenedSession)
        else {
          Issue.record("Rejected obsolete import must leave no write or operation receipt.")
          return
        }
        #expect(retainedData == after)
        let restoreDirectory = directory.appendingPathComponent("restored")
        let restored = Planner(
          configuration: .init(
            storeURL: restoreDirectory.appendingPathComponent("store/Planner.sqlite"),
            controlURL: restoreDirectory.appendingPathComponent("control/writer"),
            recoveryDirectoryURL: restoreDirectory.appendingPathComponent("recovery"),
            processRole: .mainApplication, storageMode: .localOnly))
        guard case .ready(let restoredSession) = await restored.bootstrap(),
          case .decoded(let closedBackup) = restored.decodeImport(after),
          case .reviewed(let restoreReview) = await restored.prepareReview(
            session: restoredSession, command: .applyImport(backup: closedBackup)),
          case .applied(_, .complete) = await restored.execute(
            .init(
              operationId: UUID(), session: restoredSession, command: restoreReview.command,
              reviewToken: restoreReview.reviewToken)
          ).outcome,
          case .exported(let restoredData) = await restored.exportData(session: restoredSession)
        else { throw CancellationError() }
        #expect(restoredData == after)
      }
    }
  }

  @Test(arguments: ["ownedLink", "expandedCompletion"])
  func laterOrdinarySaveRetainsImportedClosureInIndependentRecovery(group: String) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: removalSeedGraph(group: group))),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let original = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var incoming = try removalGraph(group: group, from: original).0
    if group == "expandedCompletion" {
      incoming["contextAliases"] = [[String: Any]]()
      incoming["completionChanges"] = [[String: Any]]()
    }
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let closedData) = await planner.exportData(session: session),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createTag(content: .init(name: "Later ordinary save")))
      ).outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let closed = try #require(JSONSerialization.jsonObject(with: closedData) as? [String: Any])
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    for group in ["deletionMarkers", "contextAliases", "completionChanges"] {
      #expect(
        NSArray(array: try #require(actual[group] as? [Any])).isEqual(
          to: try #require(closed[group] as? [Any])))
    }
    #expect(NSDictionary(dictionary: recovery).isEqual(to: actual))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after)
  }
}

private func removalSeedGraph(group: String) throws -> [String: Any] {
  var graph = try #require(
    JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
  let context: [String: Any]
  switch group {
  case "directEntry":
    context = [
      "kind": "directItineraryItem", "entryId": "00000000-0000-4000-8000-000000000451",
      "entryLifetimeId": "00000000-0000-4000-8000-000000000451",
    ]
  case "listEntry", "expandedCompletion":
    context = [
      "kind": "expandedListItem", "listEntryId": "00000000-0000-4000-8000-000000000452",
      "listEntryLifetimeId": "00000000-0000-4000-8000-000000000452",
      "membershipId": "00000000-0000-4000-8000-000000000401",
      "membershipLifetimeId": "00000000-0000-4000-8000-000000000401",
    ]
  default: return graph
  }
  var aliases = try #require(graph["contextAliases"] as? [[String: Any]])
  var changes = try #require(graph["completionChanges"] as? [[String: Any]])
  aliases[0]["context"] = context
  aliases[0]["canonicalContext"] = context
  changes[0]["context"] = context
  changes[0]["done"] = false
  graph["contextAliases"] = aliases
  graph["completionChanges"] = changes
  return graph
}

private func removalGraph(group: String, from original: [String: Any]) throws
  -> ([String: Any], [String: Any])
{
  var graph = original
  let recordGroup: String
  let targetKind: String
  switch group {
  case "membership":
    recordGroup = "memberships"
    targetKind = "membership"
  case "directEntry", "listEntry":
    recordGroup = "itineraryEntries"
    targetKind = "itineraryEntry"
  case "expandedCompletion":
    recordGroup = "expandedCompletions"
    targetKind = "expandedCompletion"
  case "labelAssociation":
    recordGroup = "labelAssociations"
    targetKind = "labelAssociation"
  case "ownedLink":
    recordGroup = "ownedLinks"
    targetKind = "ownedLink"
  default:
    recordGroup = "schedules"
    targetKind = "source"
  }
  var records = try #require(graph[recordGroup] as? [[String: Any]])
  let removed = records.remove(at: group == "listEntry" ? 1 : 0)
  graph[recordGroup] = records
  let target: [String: Any]
  if group == "expandedCompletion" {
    target = ["kind": targetKind, "context": try #require(removed["context"])]
  } else if group == "schedule" {
    target = [
      "kind": targetKind,
      "source": [
        "kind": "schedule", "id": try #require(removed["id"]),
        "lifetimeId": try #require(removed["lifetimeId"]),
      ],
    ]
  } else {
    target = [
      "kind": targetKind, "id": try #require(removed["id"]),
      "lifetimeId": try #require(removed["lifetimeId"]),
    ]
  }
  if group == "membership" || group == "listEntry" {
    let identifier = try #require(removed["id"] as? String)
    let contextKey = group == "membership" ? "membershipId" : "listEntryId"
    graph["expandedCompletions"] = try #require(
      graph["expandedCompletions"] as? [[String: Any]]
    ).filter { ($0["context"] as? [String: Any])?[contextKey] as? String != identifier }
  }
  return (graph, target)
}
