import Foundation
import PlannerCore
import Testing

struct ImportLineageEncodingTests {
  @Test func explicitCompletionHistoryEncodesTheIndependentPortableFixture() throws {
    let planner = nativeImportPlanner(
      directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let fixture = try nativeImportFixtureData()
    guard case .decoded(let decoded) = planner.decodeImport(fixture) else {
      throw CancellationError()
    }
    let original = try #require(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
    for (name, encoded) in [
      ("contextAliases", try JSONEncoder().encode(decoded.backup.contextAliases)),
      ("completionChanges", try JSONEncoder().encode(decoded.backup.completionChanges)),
    ] {
      let actual = try JSONSerialization.jsonObject(with: encoded)
      let expected = try #require(original[name] as? [Any])
      #expect(NSArray(array: expected).isEqual(to: try #require(actual as? [Any])))
    }
  }

  @Test(arguments: ["listMembership", "directItineraryItem", "expandedListItem"])
  func initialContributionRetainsItsContextAndExplicitNullChange(kind: String) throws {
    let planner = nativeImportPlanner(
      directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    var original = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let context: [String: Any]
    let aliasIdentifier: String
    let initialDone: Bool
    switch kind {
    case "listMembership":
      let record = try #require((original["memberships"] as? [[String: Any]])?.first)
      aliasIdentifier = try #require(record["id"] as? String)
      initialDone = try #require(record["localDone"] as? Bool)
      context = [
        "kind": kind, "membershipId": aliasIdentifier,
        "membershipLifetimeId": try #require(record["lifetimeId"]),
      ]
    case "directItineraryItem":
      let record = try #require((original["itineraryEntries"] as? [[String: Any]])?.first)
      aliasIdentifier = try #require(record["id"] as? String)
      initialDone = try #require(record["localDone"] as? Bool)
      context = [
        "kind": kind, "entryId": aliasIdentifier,
        "entryLifetimeId": try #require(record["lifetimeId"]),
      ]
    default:
      let record = try #require((original["expandedCompletions"] as? [[String: Any]])?.first)
      var expanded = try #require(record["context"] as? [String: Any])
      expanded["kind"] = kind
      context = expanded
      aliasIdentifier = "00000000-0000-4000-8000-000000000900"
      initialDone = try #require(record["localDone"] as? Bool)
    }
    let expected: [String: Any] = [
      "aliasId": aliasIdentifier, "context": context, "canonicalContext": context,
      "initialDone": initialDone, "currentChangeId": NSNull(),
    ]
    original["contextAliases"] = [expected]
    original["completionChanges"] = [Any]()
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: original))
    else { throw CancellationError() }
    let data = try JSONEncoder().encode(decoded.backup.contextAliases)
    let encoded = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    #expect(encoded.count == 1)
    #expect(NSDictionary(dictionary: try #require(encoded.first)).isEqual(to: expected))
    let reopened = try JSONDecoder().decode([PlannerPortableContextAlias].self, from: data)
    #expect(reopened.first?.context == decoded.backup.contextAliases.first?.context)
    #expect(
      reopened.first?.canonicalContext == decoded.backup.contextAliases.first?.canonicalContext)
    #expect(reopened.first?.currentChangeId == nil)
    #expect(reopened.first?.initialDone == initialDone)
  }
}
