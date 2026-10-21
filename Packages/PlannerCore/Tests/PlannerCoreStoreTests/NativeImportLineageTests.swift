import Foundation
import PlannerCore
import Testing

struct NativeImportLineageTests {
  @Test(arguments: [
    "valid", "obsoleteReference", "wrongCandidate", "missingClosure", "missingFamily", "cycle",
    "closedCandidate",
  ])
  func restorationHistoryPreservesAuthorizedCandidateBindingsAndRejectsObsoleteLifetimes(
    _ scenario: String
  ) throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    object = try #require(rebindingImportedMuseum(object) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    sources[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    let predecessor: [String: Any] = [
      "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
      "lifetimeId": "00000000-0000-4000-8000-000000000811",
    ]
    let family: [String: Any] = [
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
    var markers = try #require(object["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000892",
      "operationId": "00000000-0000-4000-8000-000000000992",
      "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
    ])
    var families = [family]
    let expectedPath: String?
    switch scenario {
    case "obsoleteReference":
      var memberships = try #require(object["memberships"] as? [[String: Any]])
      var item = try #require(memberships[0]["item"] as? [String: Any])
      item["lifetimeId"] = "00000000-0000-4000-8000-000000000811"
      memberships[0]["item"] = item
      object["memberships"] = memberships
      expectedPath = "/memberships/0/item/lifetimeId"
    case "wrongCandidate":
      sources[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000815"
      expectedPath = "/restorationFamilies/0/candidates"
    case "missingClosure":
      markers.removeLast()
      expectedPath = "/restorationFamilies/0/predecessor"
    case "missingFamily":
      families = []
      expectedPath = "/sources/0/lifetimeId"
    case "cycle":
      let nextPredecessor: [String: Any] = [
        "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
        "lifetimeId": "00000000-0000-4000-8000-000000000814",
      ]
      families.append([
        "familyId": "00000000-0000-4000-8000-000000000893", "predecessor": nextPredecessor,
        "candidates": [
          [
            "lifetimeId": "00000000-0000-4000-8000-000000000811",
            "operationId": "00000000-0000-4000-8000-000000000996",
          ]
        ],
      ])
      markers.append([
        "deletionId": "00000000-0000-4000-8000-000000000894",
        "operationId": "00000000-0000-4000-8000-000000000997",
        "target": ["kind": "source", "source": nextPredecessor], "closedFamilyId": NSNull(),
      ])
      expectedPath = "/restorationFamilies/0/predecessor"
    case "closedCandidate":
      let candidate: [String: Any] = [
        "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
        "lifetimeId": "00000000-0000-4000-8000-000000000814",
      ]
      markers.append([
        "deletionId": "00000000-0000-4000-8000-000000000894",
        "operationId": "00000000-0000-4000-8000-000000000997",
        "target": ["kind": "source", "source": candidate],
        "closedFamilyId": "00000000-0000-4000-8000-000000000890",
      ])
      expectedPath = "/sources/0/lifetimeId"
    default: expectedPath = nil
    }
    object["sources"] = sources
    object["deletionMarkers"] = markers
    object["restorationFamilies"] = families
    let directory = try makePlannerStoreFixtureDirectory()
    var bytes = try JSONSerialization.data(withJSONObject: object)
    if scenario == "missingFamily" {
      let text = try #require(String(data: bytes, encoding: .utf8))
      bytes = Data(
        text.replacingOccurrences(
          of: "00000000-0000-4000-8000-000000000815",
          with: "00000000-0000-4000-8000-000000000814"
        ).utf8)
    }
    let result = nativeImportPlanner(directory: directory).decodeImport(bytes)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    if let expectedPath {
      guard case .invalid(let failure) = result else {
        Issue.record("Reject invalid \(scenario) restoration history.")
        return
      }
      #expect(failure.code == "invalidInput" && failure.propertyPath == expectedPath)
      return
    }
    guard case .decoded(let decoded) = result else {
      Issue.record("Preserve the complete declared restoration family: \(result)")
      return
    }
    #expect(
      decoded.backup.restorationFamilies.count == 1
        && decoded.backup.restorationFamilies[0].candidates.count == 2)
    #expect(
      decoded.backup.items.first?.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
    #expect(
      decoded.backup.memberships.first?.itemLifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000815")
    #expect(decoded.backup.ownedLinks.count == 2 && decoded.backup.deletionMarkers.count == 2)
    #expect(decoded.externalBindings.isEmpty)
  }

  @Test func aClosedMembershipCannotRedirectItsHistoryToAnotherItem() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    var memberships = try #require(object["memberships"] as? [[String: Any]])
    memberships.removeFirst()
    object["memberships"] = memberships
    var expanded = try #require(object["expandedCompletions"] as? [[String: Any]])
    expanded.removeFirst()
    object["expandedCompletions"] = expanded
    var aliases = try #require(object["contextAliases"] as? [[String: Any]])
    aliases[0]["canonicalContext"] = [
      "kind": "listMembership", "membershipId": "00000000-0000-4000-8000-000000000402",
      "membershipLifetimeId": "00000000-0000-4000-8000-000000000402",
    ]
    object["contextAliases"] = aliases
    var changes = try #require(object["completionChanges"] as? [[String: Any]])
    changes[0]["done"] = false
    object["completionChanges"] = changes
    var markers = try #require(object["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000895",
      "operationId": "00000000-0000-4000-8000-000000000998",
      "target": [
        "kind": "membership", "id": "00000000-0000-4000-8000-000000000401",
        "lifetimeId": "00000000-0000-4000-8000-000000000401",
      ], "closedFamilyId": NSNull(),
    ])
    object["deletionMarkers"] = markers
    let directory = try makePlannerStoreFixtureDirectory()
    let result = nativeImportPlanner(directory: directory).decodeImport(
      try JSONSerialization.data(withJSONObject: object))
    guard case .invalid(let failure) = result else {
      Issue.record("Closure alone cannot establish another membership's logical identity.")
      return
    }
    #expect(failure.propertyPath == "/contextAliases/0/canonicalContext")
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func explicitReopenSuppressesALateDoneSeedWithoutChangingSharedItemState() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    var memberships = try #require(object["memberships"] as? [[String: Any]])
    memberships[0]["localDone"] = false
    object["memberships"] = memberships
    var changes = try #require(object["completionChanges"] as? [[String: Any]])
    changes[0]["done"] = false
    object["completionChanges"] = changes
    var aliases = try #require(object["contextAliases"] as? [[String: Any]])
    var lateAlias = aliases[0]
    lateAlias["aliasId"] = "00000000-0000-4000-8000-000000000406"
    lateAlias["initialDone"] = true
    lateAlias["currentChangeId"] = NSNull()
    aliases.append(lateAlias)
    object["contextAliases"] = aliases
    let directory = try makePlannerStoreFixtureDirectory()
    guard
      case .decoded(let decoded) = nativeImportPlanner(directory: directory).decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else {
      Issue.record("The explicit Reopen wins over initial Done contributions.")
      return
    }
    #expect(
      decoded.backup.contextAliases.count == 2 && decoded.backup.contextAliases[1].initialDone)
    #expect(
      decoded.backup.memberships.first?.localDone == false
        && decoded.backup.completionChanges.first?.done == false)
    #expect(decoded.backup.items.allSatisfy { !$0.globalDone })
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func nativeRepeatedPropertyResolutionIsRetainedByTheImmutableDecodedBackup() throws {
    let original = try #require(String(data: nativeImportFixtureData(), encoding: .utf8))
    let duplicated = original.replacingOccurrences(
      of: "\"title\": \"Nezu Museum\"",
      with: "\"title\": \"Nezu Museum\", \"title\": \"Backup museum\"")
    #expect(duplicated != original)
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = nativeImportPlanner(directory: directory)
    var bytes = Data(duplicated.utf8)
    guard case .decoded(let first) = planner.decodeImport(bytes) else {
      Issue.record("Use Foundation's repeated-property policy once.")
      return
    }
    let chosen = try #require(first.backup.items.first?.content.title)
    #expect(["Nezu Museum", "Backup museum"].contains(chosen))
    bytes = Data(
      duplicated.replacingOccurrences(of: "Nezu Museum", with: "Later museum").replacingOccurrences(
        of: "Backup museum", with: "Later museum"
      ).utf8)
    guard case .decoded(let second) = planner.decodeImport(bytes) else { throw CancellationError() }
    #expect(second.backup.items.first?.content.title == "Later museum")
    #expect(first.backup.items.first?.content.title == chosen)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }
}

private func rebindingImportedMuseum(_ value: Any) -> Any {
  if let array = value as? [Any] { return array.map(rebindingImportedMuseum) }
  guard var object = value as? [String: Any] else { return value }
  if object["kind"] as? String == "item",
    object["id"] as? String == "00000000-0000-4000-8000-000000000101",
    object["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000811"
  {
    object["lifetimeId"] = "00000000-0000-4000-8000-000000000815"
  }
  return object.mapValues(rebindingImportedMuseum)
}
