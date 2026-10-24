import Foundation
import PlannerCore
import Testing

struct NativeMembershipAliasTests {
  enum InvalidAlias: CaseIterable {
    case missingProvenance, wrongOriginalLifetime, anotherItem, anotherGeneration, retiredCanonical
    case anotherEntry, wrongEntryLifetime

    var path: String {
      switch self {
      case .missingProvenance: "/contextAliases/1/context/membershipId"
      case .wrongOriginalLifetime: "/membershipProvenance/1/membershipId"
      case .anotherItem, .anotherGeneration: "/contextAliases/1/canonicalContext"
      case .retiredCanonical: "/contextAliases/0/canonicalContext/membershipId"
      case .anotherEntry: "/contextAliases/3/canonicalContext"
      case .wrongEntryLifetime: "/contextAliases/3/context/listEntryId"
      }
    }
  }

  @Test(arguments: InvalidAlias.allCases)
  func retiredAliasesCannotBorrowAnotherPairGenerationOrCanonicalLifetime(scenario: InvalidAlias)
    throws
  {
    let fixtureName: String
    switch scenario {
    case .anotherEntry, .wrongEntryLifetime: fixtureName = "retired-expanded-membership-alias-v3"
    default: fixtureName = "retired-membership-alias-v3"
    }
    var graph = try retiredMembershipAliasFixtureGraph(fixtureName)
    var provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    var aliases = try #require(graph["contextAliases"] as? [[String: Any]])
    switch scenario {
    case .missingProvenance: provenance.removeLast()
    case .wrongOriginalLifetime:
      var context = try #require(aliases[1]["context"] as? [String: Any])
      context["membershipLifetimeId"] = "00000000-0000-4000-8000-000000000843"
      aliases[1]["context"] = context
    case .anotherItem:
      var sources = try #require(graph["sources"] as? [[String: Any]])
      var otherItem = sources[0]
      otherItem["id"] = "00000000-0000-4000-8000-000000000102"
      otherItem["lifetimeId"] = "00000000-0000-4000-8000-000000000812"
      sources.insert(otherItem, at: 1)
      graph["sources"] = sources
      provenance[1]["item"] = [
        "kind": "item", "id": "00000000-0000-4000-8000-000000000102",
        "lifetimeId": "00000000-0000-4000-8000-000000000812",
      ]
    case .anotherGeneration:
      var removed = provenance[1]
      removed["membershipId"] = "00000000-0000-4000-8000-000000000403"
      removed["membershipLifetimeId"] = "00000000-0000-4000-8000-000000000843"
      provenance.append(removed)
      provenance[0]["observedRemovalIds"] = ["00000000-0000-4000-8000-000000000891"]
      graph["deletionMarkers"] = [
        [
          "deletionId": "00000000-0000-4000-8000-000000000891",
          "operationId": "00000000-0000-4000-8000-000000000991",
          "target": [
            "kind": "membership", "id": "00000000-0000-4000-8000-000000000403",
            "lifetimeId": "00000000-0000-4000-8000-000000000843",
          ], "closedFamilyId": NSNull(),
        ]
      ]
      graph["membershipRemovals"] = [["deletionId": "00000000-0000-4000-8000-000000000891"]]
    case .retiredCanonical:
      for index in aliases.indices { aliases[index]["canonicalContext"] = aliases[1]["context"] }
    case .anotherEntry: aliases[3]["canonicalContext"] = aliases[4]["canonicalContext"]
    case .wrongEntryLifetime:
      var context = try #require(aliases[3]["context"] as? [String: Any])
      context["listEntryLifetimeId"] = "00000000-0000-4000-8000-000000000859"
      aliases[3]["context"] = context
    }
    graph["membershipProvenance"] = provenance
    graph["contextAliases"] = aliases
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .shareExtension, storageMode: .localOnly))
    let result = planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
    guard case .invalid(let failure) = result else {
      Issue.record("Retained provenance cannot authorize this alias: \(result)")
      return
    }
    #expect(failure.code == "invalidInput")
    #expect(failure.propertyPath == scenario.path)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test(
    arguments: [false, true],
    ["retired-membership-alias-v3", "retired-expanded-membership-alias-v3"])
  func retiredMembershipHistorySurvivesImportRecoveryReplayAndReopen(
    explicitReopen: Bool, fixtureName: String
  ) async throws {
    var expected = try retiredMembershipAliasFixtureGraph(fixtureName)
    if explicitReopen {
      var members = try #require(expected["memberships"] as? [[String: Any]])
      members[0]["localDone"] = false
      expected["memberships"] = members
      var aliases = try #require(expected["contextAliases"] as? [[String: Any]])
      aliases[0]["currentChangeId"] = "00000000-0000-4000-8000-000000000901"
      expected["contextAliases"] = aliases
      expected["completionChanges"] = [
        [
          "id": "00000000-0000-4000-8000-000000000901",
          "aliasId": "00000000-0000-4000-8000-000000000851",
          "context": try #require(aliases[0]["context"] as? [String: Any]),
          "done": false, "observedChangeIds": [],
        ]
      ]
    }
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let decodedResult = planner.decodeImport(try JSONSerialization.data(withJSONObject: expected))
    guard case .decoded(let decoded) = decodedResult else {
      Issue.record("Retained exact provenance must resolve the retired alias: \(decodedResult)")
      return
    }
    guard case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite))
    else { throw CancellationError() }
    let operation = PlannerOperation(
      operationId: UUID(), session: session, command: review.command,
      reviewToken: review.reviewToken)
    let response = await planner.execute(operation)
    guard case .applied(let saved, .complete(let checkpoint)) = response.outcome,
      case .exported(let exported) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("The canonical graph and retired history must save together: \(response)")
      return
    }
    let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: actual))
    #expect(NSDictionary(dictionary: expected).isEqual(to: recovery))
    let reopened = Planner(configuration: configuration)
    let listIdentifier = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000201"))
    let itemIdentifier = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000101"))
    let membershipIdentifier = try #require(
      UUID(uuidString: "00000000-0000-4000-8000-000000000401"))
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .snapshot(let query) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(.init(scope: .list(listIdentifier), completion: .all, archive: .all)))),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operation.operationId, session: reopenedSession, command: review.command)
      ).outcome
    else { throw CancellationError() }
    #expect(reopenedData == exported)
    #expect(saved == replayed && checkpoint == replayCheckpoint)
    #expect(
      query.rows == [
        .appearance(
          source: .init(kind: .item, id: itemIdentifier),
          appearance: .listMembership(listId: listIdentifier, membershipId: membershipIdentifier))
      ])
    #expect(query.progress.first?.totalCount == 1)
    #expect(query.progress.first?.doneCount == (explicitReopen ? 0 : 1))
  }
}

private func retiredMembershipAliasFixtureGraph(
  _ fixtureName: String = "retired-membership-alias-v3"
)
  throws -> [String: Any]
{
  #if SWIFT_PACKAGE
    let bundle = Bundle.module
  #else
    let bundle = Bundle(for: NativeMembershipAliasFixtureBundle.self)
  #endif
  let fixture = try #require(
    bundle.url(
      forResource: fixtureName, withExtension: "json",
      subdirectory: "Fixtures/MembershipConsolidation"))
  return try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
}

private final class NativeMembershipAliasFixtureBundle: NSObject {}
