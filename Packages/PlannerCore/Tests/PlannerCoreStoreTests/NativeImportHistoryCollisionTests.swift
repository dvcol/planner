import Foundation
import PlannerCore
import Testing

struct NativeImportHistoryCollisionTests {
  @Test(arguments: ["alias", "change"])
  func skipChecksClosedHistoryBindingsBeforePreservingMatchingValues(collision: String) async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
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
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(
            listId: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
            membershipId: UUID(uuidString: "00000000-0000-4000-8000-000000000401")!))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var incoming = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let context: [String: Any] = [
      "kind": "listMembership", "membershipId": "00000000-0000-4000-8000-000000000494",
      "membershipLifetimeId": "00000000-0000-4000-8000-000000000494",
    ]
    var aliases = try #require(incoming["contextAliases"] as? [[String: Any]])
    var changes = try #require(incoming["completionChanges"] as? [[String: Any]])
    if collision == "change" {
      aliases[0]["aliasId"] = "00000000-0000-4000-8000-000000000994"
      aliases[0]["currentChangeId"] = NSNull()
      changes[0]["aliasId"] = "00000000-0000-4000-8000-000000000994"
    }
    aliases[0]["context"] = context
    aliases[0]["canonicalContext"] = context
    changes[0]["context"] = context
    incoming["contextAliases"] = aliases
    incoming["completionChanges"] = changes
    var markers = try #require(incoming["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000995",
      "operationId": "00000000-0000-4000-8000-000000000996", "closedFamilyId": NSNull(),
      "target": [
        "kind": "membership", "id": "00000000-0000-4000-8000-000000000494",
        "lifetimeId": "00000000-0000-4000-8000-000000000494",
      ],
    ])
    incoming["deletionMarkers"] = markers
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .skip))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .rejected(let failure) = response.outcome else {
      Issue.record(
        "Reject closed \(collision) binding collision before importing its closure: \(response)")
      return
    }
    #expect(failure.code == "unavailable")
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
}
