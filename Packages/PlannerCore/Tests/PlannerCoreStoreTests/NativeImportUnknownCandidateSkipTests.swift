import Foundation
import PlannerCore
import Testing

struct NativeImportUnknownCandidateSkipTests {
  @Test(arguments: [813, 816], [false, true])
  func skipKeepsTheCurrentFamilyAndRejectsUnknownCandidateDependents(
    incomingLifetimeSuffix: Int, sharesFamilyIdentifier: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let fixture = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let sources = try #require(fixture["sources"] as? [[String: Any]])
    var museum = try #require(sources.first { $0["kind"] as? String == "item" })
    museum["lifetimeId"] = unknownCandidateIdentifier(814)
    var content = try #require(museum["content"] as? [String: Any])
    content["title"] = "Current museum"
    museum["content"] = content
    var current = fixture
    for key in current.keys where key != "format" && key != "formatVersion" { current[key] = [] }
    let predecessor = unknownCandidateBinding("item", 101, 811)
    var otherList = try #require(sources.first { $0["kind"] as? String == "list" })
    var otherListContent = try #require(otherList["content"] as? [String: Any])
    otherListContent["name"] = "Other"
    otherList["content"] = otherListContent
    current["sources"] = [museum, otherList]
    var currentMembership = try #require((fixture["memberships"] as? [[String: Any]])?.first)
    currentMembership["item"] = unknownCandidateBinding("item", 101, 814)
    current["memberships"] = [currentMembership]
    current["contextAliases"] = [
      try #require((fixture["contextAliases"] as? [[String: Any]])?.first)
    ]
    current["completionChanges"] = [
      try #require((fixture["completionChanges"] as? [[String: Any]])?.first)
    ]
    current["deletionMarkers"] = [
      [
        "deletionId": unknownCandidateIdentifier(892),
        "operationId": unknownCandidateIdentifier(992),
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ]
    ]
    current["restorationFamilies"] = [
      [
        "familyId": unknownCandidateIdentifier(890), "predecessor": predecessor,
        "candidates": [
          [
            "lifetimeId": unknownCandidateIdentifier(814),
            "operationId": unknownCandidateIdentifier(994),
          ]
        ],
      ]
    ]
    guard
      case .decoded(let seed) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: current)),
      case .reviewed(let initialReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: initialReview.command,
          reviewToken: initialReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var incoming = current
    var representedLifetimeSuffix = incomingLifetimeSuffix
    var familyIdentifierSuffix = 893
    var candidates = [
      [
        "lifetimeId": unknownCandidateIdentifier(incomingLifetimeSuffix),
        "operationId": unknownCandidateIdentifier(996),
      ]
    ]
    if sharesFamilyIdentifier {
      familyIdentifierSuffix = 890
      representedLifetimeSuffix = min(814, incomingLifetimeSuffix)
      candidates.append([
        "lifetimeId": unknownCandidateIdentifier(814),
        "operationId": unknownCandidateIdentifier(994),
      ])
    }
    museum["lifetimeId"] = unknownCandidateIdentifier(representedLifetimeSuffix)
    content["title"] = "Other museum"
    museum["content"] = content
    var list = try #require(sources.first { $0["kind"] as? String == "list" })
    list["id"] = unknownCandidateIdentifier(277)
    list["lifetimeId"] = unknownCandidateIdentifier(827)
    var listContent = try #require(list["content"] as? [String: Any])
    listContent["name"] = "Tour"
    list["content"] = listContent
    var tag = try #require(sources.first { $0["kind"] as? String == "tag" })
    var tagContent = try #require(tag["content"] as? [String: Any])
    tagContent["name"] = "Rainy day"
    tag["content"] = tagContent
    var itinerary = try #require(sources.first { $0["kind"] as? String == "itinerary" })
    var itineraryContent = try #require(itinerary["content"] as? [String: Any])
    itineraryContent["title"] = "Weekend tour"
    itinerary["content"] = itineraryContent
    incoming["sources"] = [museum, list, tag, itinerary]
    incoming["restorationFamilies"] = [
      [
        "familyId": unknownCandidateIdentifier(familyIdentifierSuffix), "predecessor": predecessor,
        "candidates": candidates,
      ]
    ]
    incoming["memberships"] = [
      [
        "id": unknownCandidateIdentifier(477), "lifetimeId": unknownCandidateIdentifier(477),
        "list": unknownCandidateBinding("list", 277, 827),
        "item": unknownCandidateBinding("item", 101, incomingLifetimeSuffix),
        "rank": "1024", "localDone": true,
      ]
    ]
    let membershipContext: [String: Any] = [
      "kind": "listMembership", "membershipId": unknownCandidateIdentifier(477),
      "membershipLifetimeId": unknownCandidateIdentifier(477),
    ]
    incoming["contextAliases"] = [
      [
        "aliasId": unknownCandidateIdentifier(477), "context": membershipContext,
        "canonicalContext": membershipContext, "initialDone": false,
        "currentChangeId": unknownCandidateIdentifier(889),
      ]
    ]
    incoming["completionChanges"] = [
      [
        "id": unknownCandidateIdentifier(889), "aliasId": unknownCandidateIdentifier(477),
        "context": membershipContext, "done": true, "observedChangeIds": [],
      ]
    ]
    let itineraryBinding = unknownCandidateBinding("itinerary", 301, 831)
    incoming["itineraryEntries"] = [
      [
        "id": unknownCandidateIdentifier(453), "lifetimeId": unknownCandidateIdentifier(453),
        "itinerary": itineraryBinding, "source": unknownCandidateBinding("list", 277, 827),
        "rank": "1024", "localDone": NSNull(),
      ]
    ]
    var guide = try #require((fixture["ownedLinks"] as? [[String: Any]])?.first)
    guide["owner"] = itineraryBinding
    incoming["ownedLinks"] = [guide]
    var schedule = try #require((fixture["schedules"] as? [[String: Any]])?.first)
    schedule["source"] = itineraryBinding
    incoming["schedules"] = [schedule]
    incoming["labelAssociations"] = [
      [
        "id": unknownCandidateIdentifier(559), "lifetimeId": unknownCandidateIdentifier(559),
        "owner": itineraryBinding, "label": unknownCandidateBinding("tag", 601, 861),
      ]
    ]
    let incomingData = try JSONSerialization.data(withJSONObject: incoming)
    guard case .decoded(let backup) = planner.decodeImport(incomingData) else {
      Issue.record("The independent incoming restoration graph must be valid.")
      return
    }
    var contradictory = incoming
    var contradictoryMuseum = museum
    contradictoryMuseum["lifetimeId"] = unknownCandidateIdentifier(min(814, incomingLifetimeSuffix))
    contradictory["sources"] = [contradictoryMuseum, list, tag, itinerary]
    var contradictoryCandidates = candidates.filter {
      $0["lifetimeId"] != unknownCandidateIdentifier(814)
    }
    contradictoryCandidates.append([
      "lifetimeId": unknownCandidateIdentifier(814),
      "operationId": unknownCandidateIdentifier(999),
    ])
    contradictory["restorationFamilies"] = [
      [
        "familyId": unknownCandidateIdentifier(familyIdentifierSuffix), "predecessor": predecessor,
        "candidates": contradictoryCandidates,
      ]
    ]
    guard
      case .decoded(let contradictoryBackup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: contradictory)),
      case .failed(let provenanceFailure) = await planner.prepareReview(
        session: session, command: .applyImport(backup: contradictoryBackup, mode: .skip)),
      case .exported(let afterProvenanceRejection) = await planner.exportData(session: session)
    else {
      Issue.record("Conflicting known candidate provenance must reject the whole review.")
      return
    }
    #expect(provenanceFailure.code == "unavailable")
    #expect(afterProvenanceRejection == before)
    let outcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: .skip))
    guard case .reviewed(let review) = outcome else {
      Issue.record("Skip must retain the current family and exclude unknown candidates: \(outcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.map(\.owner.id.uuidString) == [unknownCandidateIdentifier(601)])
    #expect(
      details.skippedConflicts.map(\.owner.lifetimeId.uuidString) == [
        unknownCandidateIdentifier(814)
      ])
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    let dependent = try #require(details.skippedDependents.first)
    #expect(details.skippedDependents.count == 2)
    #expect(dependent.owner.id.uuidString == unknownCandidateIdentifier(277))
    #expect(
      dependent.reasonCode == "deletedDependency" && dependent.before == nil
        && dependent.after == nil)
    #expect(
      dependent.dependencies.map(\.lifetimeId.uuidString) == [
        unknownCandidateIdentifier(incomingLifetimeSuffix)
      ])
    #expect(
      dependent.propertyPaths == [
        "/sources/1", "/memberships/0", "/contextAliases/0", "/completionChanges/0",
      ])
    let transitive = try #require(details.skippedDependents.last)
    #expect(transitive.owner.id.uuidString == unknownCandidateIdentifier(301))
    #expect(
      transitive.reasonCode == "deletedDependency" && transitive.before == nil
        && transitive.after == nil)
    #expect(
      Set(transitive.dependencies.map(\.id.uuidString)) == [
        unknownCandidateIdentifier(277), unknownCandidateIdentifier(601),
      ])
    #expect(
      transitive.propertyPaths == [
        "/sources/3", "/itineraryEntries/0", "/labelAssociations/0", "/ownedLinks/0",
        "/schedules/0",
      ])
    #expect(details.referenceChanges.allSatisfy { $0.change == .retain })
    guard case .exported(let afterReview) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterReview == before)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded = planner.decodeImport(after),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Apply only independent data while preserving the current family: \(response)")
      return
    }
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var expectedSources = try #require(expected["sources"] as? [[String: Any]])
    expectedSources.append(tag)
    expected["sources"] = expectedSources
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    let recoveredObject = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredObject).isEqual(to: expected))
    #expect(
      result.importSummary?.imports.map(\.owner.id.uuidString) == [unknownCandidateIdentifier(601)])
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeated) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .skip)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.impact.importDetails?.imports.isEmpty == true)
    let item = PlannerEntityReference(
      kind: .item, id: try #require(UUID(uuidString: unknownCandidateIdentifier(101))))
    guard
      case .reviewed(let lateReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .skip)),
      case .source(.item(let itemRead)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editItem(
            sourceId: item.id, changes: .init(notes: .set("A newer independent note")),
            expectedFieldHashes: [.notes: try #require(itemRead.fieldHashes[.notes])]))
      ).outcome,
      case .exported(let independentlyChanged) = await reopened.exportData(session: reopenedSession),
      case .rejected(let staleFailure) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: lateReview.command,
          reviewToken: lateReview.reviewToken)
      ).outcome,
      case .exported(let afterStaleReview) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(staleFailure.code == "staleReview")
    #expect(afterStaleReview == independentlyChanged)
  }
}

private func unknownCandidateIdentifier(_ suffix: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", suffix)
}

private func unknownCandidateBinding(_ kind: String, _ identifier: Int, _ lifetime: Int) -> [String:
  Any]
{
  [
    "kind": kind, "id": unknownCandidateIdentifier(identifier),
    "lifetimeId": unknownCandidateIdentifier(lifetime),
  ]
}
