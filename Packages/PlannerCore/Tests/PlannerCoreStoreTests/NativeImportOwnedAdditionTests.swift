import Foundation
import PlannerCore
import Testing

struct NativeImportOwnedAdditionTests {
  @Test(
    arguments: [
      "membership", "directEntry", "listEntry", "expandedCompletion", "itemCategory",
      "itineraryTag", "itemLink", "itineraryLink", "itemSchedule", "itinerarySchedule",
      "contextAlias", "completionChange",
    ], [false, true])
  func overwriteAddsOwnedRecordsWhileSkipKeepsCurrentOwner(
    group: String, omitUnchangedOwners: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    var seedGraph = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    if group == "expandedCompletion" {
      var expanded = try #require(seedGraph["expandedCompletions"] as? [[String: Any]])
      expanded.removeLast()
      seedGraph["expandedCompletions"] = expanded
    }
    if group == "itineraryTag" {
      var labels = try #require(seedGraph["labelAssociations"] as? [[String: Any]])
      labels.removeLast()
      seedGraph["labelAssociations"] = labels
    }
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
    let incoming = try graphAddingOwnedRecord(group: group, to: original)
    var payload = incoming
    if omitUnchangedOwners {
      let sources = try #require(payload["sources"] as? [[String: Any]])
      payload["sources"] = sources.filter {
        ($0["id"] as? String)?.hasSuffix(ownedAdditionOwnerSuffix(group)) == true
      }
    }
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: payload))
    guard case .decoded(let backup) = decoded else {
      Issue.record("Decode independently added \(group): \(decoded)")
      return
    }
    for mode in [PlannerImportMode.skip, .overwrite] {
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .applyImport(backup: backup, mode: mode))
      else { throw CancellationError() }
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
        Issue.record("Apply \(mode) with added \(group): \(response)")
        return
      }
      let expected = mode == .skip ? original : incoming
      let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
      let recovery = try #require(
        JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
      #expect(result.generated.isEmpty)
      #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
      #expect(NSDictionary(dictionary: recovery).isEqual(to: expected))
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
    }
  }
}

private func ownedAdditionOwnerSuffix(_ group: String) -> String {
  switch group {
  case "membership": "202"
  case "itemCategory": "102"
  case "itemLink", "itemSchedule": "101"
  case "contextAlias", "completionChange": "201"
  default: "301"
  }
}

private func graphAddingOwnedRecord(group: String, to original: [String: Any]) throws -> [String:
  Any]
{
  var graph = original
  let identifier = "00000000-0000-4000-8000-000000000994"
  let sources = try #require(graph["sources"] as? [[String: Any]])
  func binding(_ suffix: String) throws -> [String: Any] {
    let source = try #require(sources.first { ($0["id"] as? String)?.hasSuffix(suffix) == true })
    return [
      "kind": try #require(source["kind"]), "id": try #require(source["id"]),
      "lifetimeId": try #require(source["lifetimeId"]),
    ]
  }
  let recordGroup: String
  let record: [String: Any]
  switch group {
  case "membership":
    recordGroup = "memberships"
    record = [
      "id": identifier, "lifetimeId": identifier, "list": try binding("202"),
      "item": try binding("102"), "rank": "2048", "localDone": true,
    ]
  case "directEntry", "listEntry":
    recordGroup = "itineraryEntries"
    record = [
      "id": identifier, "lifetimeId": identifier, "itinerary": try binding("301"),
      "source": try binding(group == "directEntry" ? "101" : "201"), "rank": "3072",
      "localDone": group == "directEntry" ? true : NSNull(),
    ]
  case "expandedCompletion":
    recordGroup = "expandedCompletions"
    record = [
      "context": [
        "listEntryId": "00000000-0000-4000-8000-000000000452",
        "listEntryLifetimeId": "00000000-0000-4000-8000-000000000452",
        "membershipId": "00000000-0000-4000-8000-000000000402",
        "membershipLifetimeId": "00000000-0000-4000-8000-000000000402",
      ], "localDone": true,
    ]
  case "itemCategory", "itineraryTag":
    recordGroup = "labelAssociations"
    record = [
      "id": identifier, "lifetimeId": identifier,
      "owner": try binding(group == "itemCategory" ? "102" : "301"),
      "label": try binding(group == "itemCategory" ? "501" : "601"),
    ]
  case "itemLink", "itineraryLink":
    recordGroup = "ownedLinks"
    record = [
      "id": identifier, "lifetimeId": identifier,
      "owner": try binding(group == "itemLink" ? "101" : "301"), "rank": "3072",
      "originalUrl": "https://example.com/added", "label": "Added", "kind": "website",
      "providerReference": NSNull(),
    ]
  case "itemSchedule", "itinerarySchedule":
    recordGroup = "schedules"
    record = [
      "id": identifier, "lifetimeId": identifier,
      "source": try binding(group == "itemSchedule" ? "101" : "301"),
      "form": [
        "kind": "timed", "start": 813200400.0, "end": NSNull(),
        "planningTimeZone": "Asia/Tokyo",
      ],
    ]
  case "contextAlias":
    recordGroup = "contextAliases"
    let aliases = try #require(graph[recordGroup] as? [[String: Any]])
    let context = try #require(aliases[0]["context"])
    record = [
      "aliasId": identifier, "context": context, "canonicalContext": context,
      "initialDone": false, "currentChangeId": NSNull(),
    ]
  default:
    recordGroup = "completionChanges"
    var aliases = try #require(graph["contextAliases"] as? [[String: Any]])
    let context = try #require(aliases[0]["context"])
    aliases[0]["currentChangeId"] = identifier
    graph["contextAliases"] = aliases
    var memberships = try #require(graph["memberships"] as? [[String: Any]])
    memberships[0]["localDone"] = false
    graph["memberships"] = memberships
    record = [
      "id": identifier, "aliasId": try #require(aliases[0]["aliasId"]), "context": context,
      "done": false, "observedChangeIds": ["00000000-0000-4000-8000-000000000881"],
    ]
  }
  var records = try #require(graph[recordGroup] as? [[String: Any]])
  records.append(record)
  graph[recordGroup] = records
  return graph
}
