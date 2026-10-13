import Foundation
import PlannerCore
import Testing

struct NativeImportSourceDeletionTests {
  @Test(arguments: ["validMixed", "deletedDependency", "markerIdentityConflict"])
  func sourceDeletionAndNewOwnersApplyTogetherOrLeaveNoPartialImport(scenario: String) async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeImportSourceDeletionTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(try sourceDeletionSeedData()),
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
    let sources = try #require(original["sources"] as? [[String: Any]])
    let item = try #require(sources.first { $0["kind"] as? String == "item" })
    var tag = try #require(sources.first { $0["kind"] as? String == "tag" })
    tag["id"] = "00000000-0000-4000-8000-000000000779"
    tag["lifetimeId"] = "00000000-0000-4000-8000-000000000879"
    var incoming = original
    for name in [
      "sources", "memberships", "itineraryEntries", "expandedCompletions", "schedules",
      "labelAssociations", "ownedLinks", "contextAliases", "completionChanges",
    ] { incoming[name] = [[String: Any]]() }
    incoming["sources"] = [tag]
    var markers = try #require(original["deletionMarkers"] as? [[String: Any]])
    let deletionIdentifier: String
    if scenario == "markerIdentityConflict" {
      deletionIdentifier = "00000000-0000-4000-8000-000000000891"
    } else {
      deletionIdentifier = "00000000-0000-4000-8000-000000000994"
    }
    let marker: [String: Any] = [
      "deletionId": deletionIdentifier,
      "operationId": "00000000-0000-4000-8000-000000000995",
      "target": [
        "kind": "source",
        "source": [
          "kind": "item", "id": try #require(item["id"]),
          "lifetimeId": try #require(item["lifetimeId"]),
        ],
      ], "closedFamilyId": NSNull(),
    ]
    if scenario == "markerIdentityConflict" { markers = [marker] } else { markers.append(marker) }
    incoming["deletionMarkers"] = markers
    if scenario == "deletedDependency" {
      var list = try #require(sources.first { $0["kind"] as? String == "list" })
      list["id"] = "00000000-0000-4000-8000-000000000777"
      list["lifetimeId"] = "00000000-0000-4000-8000-000000000877"
      incoming["sources"] = [list, tag]
      incoming["memberships"] = [
        [
          "id": "00000000-0000-4000-8000-000000000778",
          "lifetimeId": "00000000-0000-4000-8000-000000000778", "rank": "1024", "localDone": false,
          "list": [
            "kind": "list", "id": try #require(list["id"]),
            "lifetimeId": try #require(list["lifetimeId"]),
          ],
          "item": [
            "kind": "item", "id": try #require(item["id"]),
            "lifetimeId": try #require(item["lifetimeId"]),
          ],
        ]
      ]
    }
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    let operationIdentifier = UUID()
    if case .decoded(let backup) = decoded {
      let prepared = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite))
      if case .reviewed(let review) = prepared {
        let response = await planner.execute(
          .init(
            operationId: operationIdentifier, session: session, command: review.command,
            reviewToken: review.reviewToken))
        if scenario == "validMixed" {
          guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
            case .exported(let after) = await planner.exportData(session: session),
            case .listedNamespaces(let namespaces) = await planner.inspectRecovery(
              request: .namespaces),
            let namespace = namespaces.first,
            case .selected(let recovered) = await planner.inspectRecovery(
              request: .acknowledgedSnapshot(
                namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
          else {
            Issue.record("Apply independent new Tag and reviewed deletion together: \(response)")
            return
          }
          let tagIdentifierString = try #require(tag["id"] as? String)
          let tagIdentifier = try #require(UUID(uuidString: tagIdentifierString))
          #expect(result.generated == [.init(kind: .tag, id: tagIdentifier)])
          var expected = try sourceDeletionExpectedGraph(kind: "item", from: original)
          var expectedSources = try #require(expected["sources"] as? [[String: Any]])
          expectedSources.append(tag)
          expected["sources"] = expectedSources
          var actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
          let recovery = try #require(
            JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
          #expect(NSDictionary(dictionary: recovery).isEqual(to: actual))
          actual["deletionMarkers"] = original["deletionMarkers"]
          #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
          let reopened = Planner(configuration: configuration)
          guard case .ready(let reopenedSession) = await reopened.bootstrap(),
            case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
            case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
              .init(
                operationId: operationIdentifier, session: reopenedSession, command: review.command)
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
          return
        }
        guard case .rejected = response.outcome else {
          Issue.record("Conflicting source closure must reject the whole import: \(response)")
          return
        }
      } else if case .failed(let failure) = prepared {
        #expect(scenario != "validMixed")
        #expect(["invalidInput", "missingReference", "unavailable"].contains(failure.code))
      }
    } else if case .invalid(let failure) = decoded {
      #expect(scenario != "validMixed")
      #expect(failure.code == "invalidInput")
    }
    guard case .exported(let after) = await planner.exportData(session: session),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(after == before)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == before)
  }

  @Test(arguments: ["item", "list", "itinerary", "category", "tag"], [false, true])
  func overwriteAppliesSourceClosureWhileSkipPreservesTheCompleteGraph(
    kind: String, declareSurvivingOwners: Bool
  ) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeImportSourceDeletionTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(try sourceDeletionSeedData()),
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
    let sources = try #require(original["sources"] as? [[String: Any]])
    let source = try #require(sources.first { $0["kind"] as? String == kind })
    let sourceIdentifier = try #require(source["id"] as? String)
    let deleted = PlannerEntityReference(
      kind: try #require(PlannerEntityKind(rawValue: kind)),
      id: try #require(UUID(uuidString: sourceIdentifier)))
    guard
      case .reviewed(let nativeDelete) = await planner.prepareReview(
        session: session, command: .deleteSource(source: deleted))
    else { throw CancellationError() }
    let expected = try sourceDeletionExpectedGraph(kind: kind, from: original)
    var incoming = expected
    if !declareSurvivingOwners {
      for name in [
        "sources", "memberships", "itineraryEntries", "expandedCompletions", "schedules",
        "labelAssociations", "ownedLinks", "contextAliases", "completionChanges",
      ] {
        incoming[name] = [[String: Any]]()
      }
    } else {
      let closedContexts: [String]
      switch kind {
      case "item": closedContexts = ["listMembership", "directItineraryItem", "expandedListItem"]
      case "list": closedContexts = ["listMembership", "expandedListItem"]
      case "itinerary": closedContexts = ["directItineraryItem", "expandedListItem"]
      default: closedContexts = []
      }
      let aliases = try #require(incoming["contextAliases"] as? [[String: Any]])
      let retained = aliases.filter {
        guard let context = $0["canonicalContext"] as? [String: Any],
          let kind = context["kind"] as? String
        else { return false }
        return !closedContexts.contains(kind)
      }
      let identifiers = Set(retained.compactMap { $0["aliasId"] as? String })
      incoming["contextAliases"] = retained
      incoming["completionChanges"] = try #require(
        incoming["completionChanges"] as? [[String: Any]]
      ).filter { ($0["aliasId"] as? String).map(identifiers.contains) == true }
    }
    let target: [String: Any] = [
      "kind": "source",
      "source": [
        "kind": kind, "id": sourceIdentifier, "lifetimeId": try #require(source["lifetimeId"]),
      ],
    ]
    var incomingMarkers = try #require(incoming["deletionMarkers"] as? [[String: Any]])
    incomingMarkers.append([
      "deletionId": "00000000-0000-4000-8000-000000000994",
      "operationId": "00000000-0000-4000-8000-000000000995",
      "target": target, "closedFamilyId": NSNull(),
    ])
    incoming["deletionMarkers"] = incomingMarkers
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decoded else {
      Issue.record("Decode source closure for \(kind): \(decoded)")
      return
    }
    for mode in [PlannerImportMode.skip, .overwrite] {
      let prepared = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: mode))
      guard case .reviewed(let review) = prepared else {
        Issue.record("Review source closure for \(kind): \(prepared)")
        return
      }
      if mode == .overwrite {
        #expect(Set(review.impact.sourceDeletes) == Set(nativeDelete.impact.sourceDeletes))
        #expect(Set(review.impact.referenceRemovals) == Set(nativeDelete.impact.referenceRemovals))
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
        Issue.record("Apply \(mode) source closure for \(kind): \(response)")
        return
      }
      var actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
      let recovery = try #require(
        JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
      #expect(result.generated.isEmpty)
      let appliedSummary = try #require(result.importSummary)
      #expect(appliedSummary.incomingDeletions == review.impact.importDetails?.incomingDeletions)
      #expect(NSDictionary(dictionary: recovery).isEqual(to: actual))
      if mode == .skip {
        #expect(after == before)
      } else {
        #expect(Set(result.affected).isSuperset(of: nativeDelete.impact.sourceDeletes))
        #expect(Set(result.affectedReferences) == Set(nativeDelete.impact.referenceRemovals))
        let markers = try #require(actual["deletionMarkers"] as? [[String: Any]])
        let supplied = try #require(
          markers.first {
            $0["deletionId"] as? String == "00000000-0000-4000-8000-000000000994"
          })
        #expect(
          NSDictionary(dictionary: try #require(supplied["target"] as? [String: Any])).isEqual(
            to: target))
        for marker in markers {
          #expect(Set(marker.keys) == ["deletionId", "operationId", "target", "closedFamilyId"])
        }
        actual["deletionMarkers"] = original["deletionMarkers"]
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
        let obsoleteOperationIdentifier = UUID()
        let obsoletePrepared = await reopened.prepareReview(
          session: reopenedSession, command: .applyImport(backup: obsolete, mode: .overwrite))
        if case .reviewed(let obsoleteReview) = obsoletePrepared {
          let obsoleteResponse = await reopened.execute(
            .init(
              operationId: obsoleteOperationIdentifier, session: reopenedSession,
              command: obsoleteReview.command, reviewToken: obsoleteReview.reviewToken))
          guard case .rejected = obsoleteResponse.outcome else {
            Issue.record("Obsolete import must not resurrect deleted \(kind): \(obsoleteResponse)")
            return
          }
        } else if case .failed(let failure) = obsoletePrepared {
          #expect(["invalidInput", "missingReference", "unavailable"].contains(failure.code))
        }
        guard
          case .noReliableEvidence = await reopened.operationStatus(
            session: reopenedSession, operationId: obsoleteOperationIdentifier),
          case .exported(let retainedData) = await reopened.exportData(session: reopenedSession)
        else { throw CancellationError() }
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
}

private func sourceDeletionSeedData() throws -> Data {
  var graph = try #require(
    JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
  var aliases = try #require(graph["contextAliases"] as? [[String: Any]])
  var changes = try #require(graph["completionChanges"] as? [[String: Any]])
  for (aliasSuffix, changeSuffix, context) in [
    (
      "882", "884",
      [
        "kind": "directItineraryItem", "entryId": "00000000-0000-4000-8000-000000000451",
        "entryLifetimeId": "00000000-0000-4000-8000-000000000451",
      ]
    ),
    (
      "883", "885",
      [
        "kind": "expandedListItem", "listEntryId": "00000000-0000-4000-8000-000000000452",
        "listEntryLifetimeId": "00000000-0000-4000-8000-000000000452",
        "membershipId": "00000000-0000-4000-8000-000000000401",
        "membershipLifetimeId": "00000000-0000-4000-8000-000000000401",
      ]
    ),
  ] {
    let aliasIdentifier = "00000000-0000-4000-8000-000000000" + aliasSuffix
    let changeIdentifier = "00000000-0000-4000-8000-000000000" + changeSuffix
    aliases.append([
      "aliasId": aliasIdentifier, "context": context, "canonicalContext": context,
      "initialDone": false, "currentChangeId": changeIdentifier,
    ])
    changes.append([
      "id": changeIdentifier, "aliasId": aliasIdentifier, "context": context,
      "done": false, "observedChangeIds": [String](),
    ])
  }
  graph["contextAliases"] = aliases
  graph["completionChanges"] = changes
  return try JSONSerialization.data(withJSONObject: graph)
}

private func sourceDeletionExpectedGraph(kind: String, from original: [String: Any]) throws
  -> [String: Any]
{
  var graph = original
  let removed: [String: Set<String>]
  switch kind {
  case "item":
    removed = [
      "sources": ["101"], "memberships": ["401", "403"], "itineraryEntries": ["451"],
      "labelAssociations": ["551", "651"], "ownedLinks": ["751", "752"], "schedules": ["701"],
    ]
  case "list":
    removed = ["sources": ["201"], "memberships": ["401", "402"], "itineraryEntries": ["452"]]
  case "itinerary":
    removed = [
      "sources": ["301"], "itineraryEntries": ["451", "452"],
      "labelAssociations": ["552", "652"], "schedules": ["702"],
    ]
  case "category": removed = ["sources": ["501"], "labelAssociations": ["551", "552"]]
  default: removed = ["sources": ["601"], "labelAssociations": ["651", "652"]]
  }
  for (group, suffixes) in removed {
    graph[group] = try #require(graph[group] as? [[String: Any]]).filter {
      guard let identifier = $0["id"] as? String else { return false }
      return !suffixes.contains { identifier.hasSuffix($0) }
    }
  }
  let removedMemberships = removed["memberships"] ?? []
  let removedEntries = removed["itineraryEntries"] ?? []
  graph["expandedCompletions"] = try #require(graph["expandedCompletions"] as? [[String: Any]])
    .filter {
      guard let context = $0["context"] as? [String: Any],
        let membership = context["membershipId"] as? String,
        let entry = context["listEntryId"] as? String
      else { return false }
      return !removedMemberships.contains { membership.hasSuffix($0) }
        && !removedEntries.contains { entry.hasSuffix($0) }
    }
  return graph
}
