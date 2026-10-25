import Foundation
import PlannerCore
import Testing

struct NativeMembershipAliasTests {
  @Test(arguments: [
    "remove", "move", "reorder", "addBeforeAlias", "reorderBeforeAlias", "moveBeforeAlias",
    "selfAnchor",
  ])
  func eligibleAliasesOrganizeTheCanonicalMembershipAndPlacementAnchor(action: String) async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let graph = try retiredMembershipAliasFixtureGraph("retired-expanded-membership-alias-v3")
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph)),
      case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("The independent fixture action must save: \(response)")
        throw CancellationError()
      }
      return result
    }
    let origin = PlannerEntityReference(
      kind: .list, id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!)
    let hotel = PlannerEntityReference(
      kind: .item, id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)
    let canonicalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let retiredIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!
    let otherList = try #require(
      try await save(.createList(content: .init(name: "Other"))).generated.first)
    let otherItem = try #require(
      try await save(.createItem(content: .init(title: "Other activity", notes: "Keep"))).generated
        .first)
    var otherMembership: UUID?
    if action != "addBeforeAlias" {
      let owner = action == "moveBeforeAlias" ? otherList : origin
      let added = try await save(
        .addMembership(itemId: otherItem.id, listId: owner.id, placement: .last))
      guard case .membership(let identifier, _, _)? = added.generatedReferences.first else {
        throw CancellationError()
      }
      otherMembership = identifier
    }
    guard
      case .source(.item(let beforeHotel)) = await planner.read(
        session: session, request: .source(hotel)),
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let foreignAppearance = PlannerAppearance.listMembership(
      listId: otherList.id, membershipId: retiredIdentifier)
    guard
      case .failed(let foreignRead) = await planner.read(
        session: session, request: .appearance(foreignAppearance))
    else { throw CancellationError() }
    #expect(foreignRead.code == "missingReference")
    for invalid in [
      PlannerCommand.setCompletion(scope: .appearance(foreignAppearance), done: true),
      .removeMembership(listId: otherList.id, membershipId: retiredIdentifier),
    ] {
      let invalidIdentifier = UUID()
      guard
        case .rejected(let failure) = await planner.execute(
          .init(operationId: invalidIdentifier, session: session, command: invalid)
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: invalidIdentifier)
      else { throw CancellationError() }
      #expect(failure.code == "missingReference")
    }
    guard case .exported(let afterInvalid) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterInvalid == before)
    let command: PlannerCommand
    switch action {
    case "remove":
      command = .removeMembership(listId: origin.id, membershipId: retiredIdentifier)
    case "move":
      command = .moveMembership(
        listId: origin.id, membershipId: retiredIdentifier,
        destinationListId: otherList.id, placement: .last)
    case "reorder":
      command = .reorderMembership(
        listId: origin.id, membershipId: retiredIdentifier, placement: .last)
    case "addBeforeAlias":
      command = .addMembership(
        itemId: otherItem.id, listId: origin.id,
        placement: .before(associationId: retiredIdentifier))
    case "reorderBeforeAlias":
      command = .reorderMembership(
        listId: origin.id, membershipId: try #require(otherMembership),
        placement: .before(associationId: retiredIdentifier))
    case "moveBeforeAlias":
      command = .moveMembership(
        listId: otherList.id, membershipId: try #require(otherMembership),
        destinationListId: origin.id,
        placement: .before(associationId: retiredIdentifier))
    case "selfAnchor":
      command = .reorderMembership(
        listId: origin.id, membershipId: retiredIdentifier,
        placement: .before(associationId: canonicalIdentifier))
    default: throw CancellationError()
    }
    let operation = PlannerOperation(operationId: UUID(), session: session, command: command)
    let response = await planner.execute(operation)
    if action == "selfAnchor" {
      guard case .rejected(let failure) = response.outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operation.operationId),
        case .exported(let unchanged) = await planner.exportData(session: session)
      else { throw CancellationError() }
      #expect(failure.code == "invalidInput")
      #expect(failure.propertyPath == "/command/placement/associationId")
      #expect(unchanged == before)
      return
    }
    guard case .applied(let applied, .complete(let checkpoint)) = response.outcome else {
      Issue.record("A proven alias must organize its canonical relationship: \(response)")
      return
    }
    let expectedOrigin: [UUID]
    let expectedOther: [UUID]
    switch action {
    case "remove":
      expectedOrigin = [otherItem.id]
      expectedOther = []
    case "move":
      expectedOrigin = [otherItem.id]
      expectedOther = [hotel.id]
    default:
      expectedOrigin = [otherItem.id, hotel.id]
      expectedOther = []
    }
    for (list, expected) in [(origin, expectedOrigin), (otherList, expectedOther)] {
      guard
        case .snapshot(let query) = await planner.query(
          .init(
            session: session,
            request: .items(
              .init(
                scope: .list(list.id), completion: .all, archive: .all,
                sort: .init(mode: .manual)))))
      else { throw CancellationError() }
      let sources = query.rows.compactMap { row -> UUID? in
        guard case .appearance(let source, _) = row else { return nil }
        return source.id
      }
      #expect(query.matchingCount == Int64(expected.count))
      #expect(sources == expected)
    }
    guard
      case .source(.item(let afterHotel)) = await planner.read(
        session: session, request: .source(hotel)),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(afterHotel.updatedAt == beforeHotel.updatedAt)
    #expect(afterHotel.fieldHashes == beforeHotel.fieldHashes)
    #expect(afterHotel.state.globalDone == false)
    if ["remove", "move", "reorder"].contains(action) {
      #expect(
        applied.affectedReferences.contains(
          .membership(id: canonicalIdentifier, list: origin, item: hotel)))
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let retained) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operation.operationId, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(retained == after)
    #expect(replayed == applied && replayCheckpoint == checkpoint)
    if action == "remove" || action == "move" {
      let undo = try #require(response.associationUndoSnapshot)
      _ = try await save(.restoreAssociation(snapshot: undo))
      guard
        case .appearance(let restored) = await planner.read(
          session: session,
          request: .appearance(
            .listMembership(listId: origin.id, membershipId: canonicalIdentifier)))
      else { throw CancellationError() }
      #expect(restored.localDone && restored.effectiveDone && !restored.globalDone)
    }
  }

  @Test(arguments: ["list", "firstBranch", "secondBranch"])
  func eligibleRetiredMembershipReadsAndCompletesOnlyItsSelectedAppearance(scope: String)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let graph = try retiredMembershipAliasFixtureGraph("retired-expanded-membership-alias-v3")
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph)),
      case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    let canonicalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let retiredIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!
    let firstEntry = UUID(uuidString: "00000000-0000-4000-8000-000000000451")!
    let secondEntry = UUID(uuidString: "00000000-0000-4000-8000-000000000452")!
    let directEntry = UUID(uuidString: "00000000-0000-4000-8000-000000000453")!
    let item = PlannerEntityReference(
      kind: .item, id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)
    let selected: PlannerAppearance
    let initialDone: Bool
    switch scope {
    case "list":
      selected = .listMembership(listId: listIdentifier, membershipId: retiredIdentifier)
      initialDone = true
    case "firstBranch":
      selected = .expandedListItem(
        itineraryId: itineraryIdentifier, listEntryId: firstEntry, membershipId: retiredIdentifier)
      initialDone = false
    case "secondBranch":
      selected = .expandedListItem(
        itineraryId: itineraryIdentifier, listEntryId: secondEntry, membershipId: retiredIdentifier)
      initialDone = true
    default: throw CancellationError()
    }
    let originalRead = await planner.read(session: session, request: .appearance(selected))
    guard case .appearance(let original) = originalRead,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("A proven eligible alias must resolve its exact appearance: \(originalRead)")
      return
    }
    #expect(original.appearance == selected)
    #expect(original.source == item && !original.globalDone)
    #expect(original.localDone == initialDone && original.effectiveDone == initialDone)
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(selected), done: !initialDone))
    let completion = await planner.execute(operation)
    guard case .applied(let applied, .complete(let checkpoint)) = completion.outcome else {
      Issue.record(
        "A retired alias must complete only its eligible canonical context: \(completion)")
      return
    }
    let appearances: [(PlannerAppearance, Bool)] = [
      (
        .listMembership(listId: listIdentifier, membershipId: canonicalIdentifier),
        scope != "list"
      ),
      (
        .expandedListItem(
          itineraryId: itineraryIdentifier, listEntryId: firstEntry,
          membershipId: canonicalIdentifier), scope == "firstBranch"
      ),
      (
        .expandedListItem(
          itineraryId: itineraryIdentifier, listEntryId: secondEntry,
          membershipId: canonicalIdentifier), scope != "secondBranch"
      ),
      (.directItineraryItem(itineraryId: itineraryIdentifier, entryId: directEntry), false),
    ]
    for (appearance, expectedDone) in appearances {
      guard
        case .appearance(let current) = await planner.read(
          session: session, request: .appearance(appearance))
      else { throw CancellationError() }
      #expect(current.source == item && !current.globalDone)
      #expect(current.localDone == expectedDone && current.effectiveDone == expectedDone)
    }
    guard
      case .source(.item(let unchangedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .exported(let saved) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(unchangedItem.updatedAt == originalItem.updatedAt)
    #expect(unchangedItem.fieldHashes == originalItem.fieldHashes)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let retained) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(
          operationId: operation.operationId, session: reopenedSession, command: operation.command)
      ).outcome,
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .removeMembership(listId: listIdentifier, membershipId: canonicalIdentifier))
      ).outcome,
      case .applied(let readded, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .addMembership(itemId: item.id, listId: listIdentifier, placement: .last))
      ).outcome,
      case .membership(let freshIdentifier, _, _)? = readded.generatedReferences.first
    else { throw CancellationError() }
    #expect(retained == saved)
    #expect(replayed == applied && replayCheckpoint == checkpoint)
    let obsoleteRead = await reopened.read(
      session: reopenedSession, request: .appearance(selected))
    guard case .failed(let unavailable) = obsoleteRead else {
      Issue.record("An old alias cannot target an ordinary re-add: \(obsoleteRead)")
      return
    }
    #expect(unavailable.code == "missingReference")
    let rejectedIdentifier = UUID()
    guard
      case .rejected(let rejected) = await reopened.execute(
        .init(operationId: rejectedIdentifier, session: reopenedSession, command: operation.command)
      ).outcome,
      case .noReliableEvidence = await reopened.operationStatus(
        session: reopenedSession, operationId: rejectedIdentifier),
      case .applied(let lateReplay, .complete(let lateCheckpoint)) = await reopened.execute(
        .init(
          operationId: operation.operationId, session: reopenedSession, command: operation.command)
      ).outcome,
      case .appearance(let fresh) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: listIdentifier, membershipId: freshIdentifier))
      )
    else { throw CancellationError() }
    #expect(rejected.code == "missingReference")
    #expect(lateReplay == applied && lateCheckpoint == checkpoint)
    #expect(fresh.source == item && !fresh.globalDone && !fresh.localDone && !fresh.effectiveDone)
  }

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
    let currentExpected = try canonicalPortableFixtureExpectations(
      JSONSerialization.data(withJSONObject: expected))
    #expect(NSDictionary(dictionary: currentExpected).isEqual(to: actual))
    #expect(NSDictionary(dictionary: currentExpected).isEqual(to: recovery))
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
