import Foundation
import PlannerCore
import Testing

struct NativeImportClosedHistoryTests {
  @Test(arguments: ["listMembership", "directItineraryItem", "expandedListItem"])
  func removedContextsRetainReviewableRestorableHistory(kind: String) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    func configuration(_ name: String) -> PlannerStorageConfiguration {
      let root = directory.appendingPathComponent(name)
      return .init(
        storeURL: root.appendingPathComponent("store/Planner.sqlite"),
        controlURL: root.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: root.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
    }
    var fixture = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let context: [String: Any]
    let aliasIdentifier: String
    let removal: PlannerCommand
    if kind == "directItineraryItem" {
      aliasIdentifier = "00000000-0000-4000-8000-000000000451"
      context = [
        "kind": kind, "entryId": aliasIdentifier, "entryLifetimeId": aliasIdentifier,
      ]
      removal = .removeItineraryEntry(
        itineraryId: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
        entryId: UUID(uuidString: aliasIdentifier)!)
    } else {
      aliasIdentifier = "00000000-0000-4000-8000-000000000401"
      if kind == "listMembership" {
        context = [
          "kind": kind, "membershipId": aliasIdentifier, "membershipLifetimeId": aliasIdentifier,
        ]
      } else {
        context = [
          "kind": kind, "membershipId": aliasIdentifier, "membershipLifetimeId": aliasIdentifier,
          "listEntryId": "00000000-0000-4000-8000-000000000452",
          "listEntryLifetimeId": "00000000-0000-4000-8000-000000000452",
        ]
      }
      removal = .removeMembership(
        listId: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
        membershipId: UUID(uuidString: aliasIdentifier)!)
    }
    fixture["contextAliases"] = [
      [
        "aliasId": aliasIdentifier, "context": context, "canonicalContext": context,
        "initialDone": false, "currentChangeId": "00000000-0000-4000-8000-000000000881",
      ]
    ]
    fixture["completionChanges"] = [
      [
        "id": "00000000-0000-4000-8000-000000000881", "aliasId": aliasIdentifier,
        "context": context, "done": kind == "listMembership", "observedChangeIds": [String](),
      ]
    ]
    let planner = Planner(configuration: configuration("original"))
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: fixture)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: removal)
      ).outcome,
      case .exported(let closedData) = await planner.exportData(session: session),
      case .decoded(let closedBackup) = planner.decodeImport(closedData)
    else { throw CancellationError() }
    #expect(closedBackup.backup.contextAliases.count == 1)
    #expect(closedBackup.backup.completionChanges.count == 1)
    let reviewResult = await planner.prepareReview(
      session: session, command: .applyImport(backup: closedBackup, mode: .skip))
    guard case .reviewed(let review) = reviewResult else {
      Issue.record("Review valid closed completion history: \(reviewResult)")
      return
    }
    guard
      case .applied(let repeated, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(repeated.generated.isEmpty && repeatedData == closedData)
    var conflicting = try #require(JSONSerialization.jsonObject(with: closedData) as? [String: Any])
    var aliases = try #require(conflicting["contextAliases"] as? [[String: Any]])
    var changes = try #require(conflicting["completionChanges"] as? [[String: Any]])
    aliases[0]["initialDone"] = true
    changes[0]["done"] = kind != "listMembership"
    conflicting["contextAliases"] = aliases
    conflicting["completionChanges"] = changes
    guard
      case .decoded(let conflictingBackup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: conflicting))
    else { throw CancellationError() }
    for mode in [PlannerImportMode.skip, .overwrite] {
      guard
        case .reviewed(let conflictReview) = await planner.prepareReview(
          session: session, command: .applyImport(backup: conflictingBackup, mode: mode)),
        let closureDetails = conflictReview.impact.importDetails?.incomingDeletions.first(where: {
          $0.propertyPaths.contains("/contextAliases/0")
        })
      else { throw CancellationError() }
      #expect(
        closureDetails.owner == nil && closureDetails.before == nil && closureDetails.after == nil)
      #expect(closureDetails.propertyPaths.contains("/completionChanges/0"))
      let response = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: conflictReview.command,
          reviewToken: conflictReview.reviewToken))
      guard case .applied(_, .complete) = response.outcome,
        case .exported(let resultData) = await planner.exportData(session: session)
      else {
        Issue.record("Apply the reviewed \(mode) rule to closed history: \(response)")
        return
      }
      if mode == .skip {
        #expect(resultData == closedData)
      } else {
        let resultGraph = try #require(
          JSONSerialization.jsonObject(with: resultData) as? [String: Any])
        #expect(NSDictionary(dictionary: resultGraph).isEqual(to: conflicting))
      }
    }
    let restored = Planner(configuration: configuration("restored"))
    guard case .ready(let restoredSession) = await restored.bootstrap() else {
      throw CancellationError()
    }
    let restoreReviewResult = await restored.prepareReview(
      session: restoredSession, command: .applyImport(backup: closedBackup))
    guard case .reviewed(let restoreReview) = restoreReviewResult else {
      Issue.record("Review closed history for a faithful empty restore: \(restoreReviewResult)")
      return
    }
    let response = await restored.execute(
      .init(
        operationId: UUID(), session: restoredSession, command: restoreReview.command,
        reviewToken: restoreReview.reviewToken))
    guard case .applied(_, .complete(let checkpoint)) = response.outcome,
      case .exported(let restoredData) = await restored.exportData(session: restoredSession),
      case .listedNamespaces(let namespaces) = await restored.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await restored.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Restore closed history with its declared closure: \(response)")
      return
    }
    #expect(restoredData == closedData)
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    let expectedGraph = try #require(
      JSONSerialization.jsonObject(with: closedData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredGraph).isEqual(to: expectedGraph))
    let reopened = Planner(configuration: configuration("restored"))
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == closedData)
  }
}
