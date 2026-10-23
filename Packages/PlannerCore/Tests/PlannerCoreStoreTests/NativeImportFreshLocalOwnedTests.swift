import Foundation
import PlannerCore
import Testing

struct NativeImportFreshLocalOwnedTests {
  @Test(arguments: ["ownedLink", "schedule", "labelAssociation"], [false, true])
  func freshOwnerRestoresExactOwnedReferencesButRejectsForeignCandidates(
    referenceKind: String, hasForeignReferenceCandidate: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let initial) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: initial.command,
          reviewToken: initial.reviewToken)
      ).outcome,
      case .exported(let originalData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let original = try #require(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let originalSources = try #require(original["sources"] as? [[String: Any]])
    let originalItem = try #require(
      originalSources.first { $0["id"] as? String == candidateKindIdentifier(101) })
    let source = PlannerEntityReference(
      kind: .item, id: try #require(UUID(uuidString: candidateKindIdentifier(101))))
    guard
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let current = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let collection: String
    let bindingField: String
    let referenceSuffix: Int
    let expectedReferenceFamily: String
    switch referenceKind {
    case "ownedLink":
      collection = "ownedLinks"
      bindingField = "owner"
      referenceSuffix = 751
      expectedReferenceFamily = "6DC8997D-6E3B-8DE5-AB8F-CACF3A2241D7"
    case "schedule":
      collection = "schedules"
      bindingField = "source"
      referenceSuffix = 701
      expectedReferenceFamily = "B10D238F-8316-8791-875A-9905DC25FAE6"
    default:
      collection = "labelAssociations"
      bindingField = "owner"
      referenceSuffix = 551
      expectedReferenceFamily = "57420176-5935-8C08-913F-9E45A400ACD5"
    }
    let referenceIdentifier = candidateKindIdentifier(referenceSuffix)
    let originalReference = try #require(
      (original[collection] as? [[String: Any]])?.first {
        $0["id"] as? String == referenceIdentifier
      })
    let originalReferenceLifetime = try #require(originalReference["lifetimeId"] as? String)
    let sourcePredecessor: [String: Any] = [
      "kind": "item", "id": source.id.uuidString, "lifetimeId": candidateKindIdentifier(811),
    ]
    let referencePredecessor: [String: Any] = [
      "kind": referenceKind, "id": referenceIdentifier, "lifetimeId": originalReferenceLifetime,
    ]
    var incoming = original
    for key in incoming.keys where key != "format" && key != "formatVersion" { incoming[key] = [] }
    var incomingItem = originalItem
    incomingItem["lifetimeId"] = candidateKindIdentifier(881)
    var independentTag = try #require(originalSources.first { $0["kind"] as? String == "tag" })
    independentTag["id"] = candidateKindIdentifier(602)
    independentTag["lifetimeId"] = candidateKindIdentifier(862)
    incoming["sources"] = [incomingItem, independentTag]
    var incomingReference = originalReference
    var owner = try #require(incomingReference[bindingField] as? [String: Any])
    owner["lifetimeId"] = candidateKindIdentifier(881)
    incomingReference[bindingField] = owner
    let markers = try #require(current["deletionMarkers"] as? [[String: Any]])
    var incomingMarkers = markers.filter {
      guard let target = $0["target"] as? [String: Any],
        let boundSource = target["source"] as? [String: Any]
      else { return false }
      return boundSource["kind"] as? String == "item"
        && boundSource["id"] as? String == source.id.uuidString
    }
    var incomingFamilies: [[String: Any]] = [
      [
        "familyId": candidateKindIdentifier(893), "predecessor": sourcePredecessor,
        "candidates": [
          [
            "lifetimeId": candidateKindIdentifier(881), "operationId": candidateKindIdentifier(996),
          ]
        ],
      ]
    ]
    if hasForeignReferenceCandidate {
      incomingReference["lifetimeId"] = candidateKindIdentifier(883)
      let marker = try #require(
        markers.first {
          guard let target = $0["target"] as? [String: Any] else { return false }
          if let boundSource = target["source"] as? [String: Any] {
            return boundSource["kind"] as? String == referenceKind
              && boundSource["id"] as? String == referenceIdentifier
          }
          return target["kind"] as? String == referenceKind
            && target["id"] as? String == referenceIdentifier
        })
      incomingMarkers.append(marker)
      incomingFamilies.append([
        "familyId": candidateKindIdentifier(894), "predecessor": referencePredecessor,
        "candidates": [
          [
            "lifetimeId": candidateKindIdentifier(883), "operationId": candidateKindIdentifier(997),
          ]
        ],
      ])
    }
    incoming[collection] = [incomingReference]
    incoming["deletionMarkers"] = incomingMarkers
    incoming["restorationFamilies"] = incomingFamilies
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decoded else {
      Issue.record("The independently valid restored \(referenceKind) must decode: \(decoded)")
      return
    }
    let reviewOutcome = await planner.prepareReview(
      session: session,
      command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    if hasForeignReferenceCandidate, case .failed(let failure) = reviewOutcome {
      #expect(failure.code == "unavailable")
      guard case .exported(let unchanged) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      #expect(unchanged == before)
      return
    }
    guard case .reviewed(let review) = reviewOutcome else {
      Issue.record("Review the exact represented \(referenceKind): \(reviewOutcome)")
      return
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    if hasForeignReferenceCandidate {
      guard case .rejected(let failure) = response.outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier),
        case .exported(let unchanged) = await planner.exportData(session: session)
      else {
        Issue.record("Reject the foreign reference family without restoring its owner: \(response)")
        return
      }
      #expect(failure.code == "unavailable" && unchanged == before)
      return
    }
    #expect(review.impact.importDetails?.restorations.map(\.owner.id) == [source.id])
    #expect(
      review.impact.importDetails?.referenceChanges.filter { $0.change == .restore }.count == 1)
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record("Restore the exact \(referenceKind) under a fresh Item lifetime: \(response)")
      return
    }
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let savedItem = try #require(
      (actual["sources"] as? [[String: Any]])?.first {
        $0["id"] as? String == source.id.uuidString
      })
    let savedSourceLifetime = try #require(savedItem["lifetimeId"] as? String)
    let savedReference = try #require(
      (actual[collection] as? [[String: Any]])?.first {
        $0["id"] as? String == referenceIdentifier
      })
    let savedReferenceLifetime = try #require(savedReference["lifetimeId"] as? String)
    #expect(savedSourceLifetime != candidateKindIdentifier(811))
    #expect(savedSourceLifetime != candidateKindIdentifier(881))
    #expect(savedReferenceLifetime != originalReferenceLifetime)
    #expect(savedReferenceLifetime != candidateKindIdentifier(883))
    #expect(
      result.importSummary?.restorations.first?.owner.lifetimeId.uuidString == savedSourceLifetime)
    var expected = current
    var expectedItem = originalItem
    expectedItem["lifetimeId"] = savedSourceLifetime
    expected["sources"] =
      try #require(current["sources"] as? [[String: Any]])
      + [expectedItem, independentTag]
    var expectedReference = originalReference
    expectedReference["lifetimeId"] = savedReferenceLifetime
    var expectedOwner = try #require(originalReference[bindingField] as? [String: Any])
    expectedOwner["lifetimeId"] = savedSourceLifetime
    expectedReference[bindingField] = expectedOwner
    expected[collection] =
      try #require(current[collection] as? [[String: Any]]) + [expectedReference]
    expected["restorationFamilies"] =
      try #require(current["restorationFamilies"] as? [[String: Any]])
      + [
        [
          "familyId": "BF4CA8D3-7AFB-8BF5-A2C3-7F67C76178EC", "predecessor": sourcePredecessor,
          "candidates": [
            [
              "lifetimeId": savedSourceLifetime, "operationId": operationIdentifier.uuidString,
            ]
          ],
        ],
        [
          "familyId": expectedReferenceFamily, "predecessor": referencePredecessor,
          "candidates": [
            [
              "lifetimeId": savedReferenceLifetime, "operationId": operationIdentifier.uuidString,
            ]
          ],
        ],
      ]
    let expectedData = try JSONSerialization.data(withJSONObject: expected)
    #expect(try competingValueGraph(after) == competingValueGraph(expectedData))
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(try competingValueGraph(recovered.portableData) == competingValueGraph(expectedData))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome
    else { throw CancellationError() }
    let repeatedOutcome = await reopened.prepareReview(
      session: reopenedSession,
      command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    guard case .reviewed(let repeatedReview) = repeatedOutcome else {
      Issue.record("Review the same restored \(referenceKind) again: \(repeatedOutcome)")
      return
    }
    let repeatedResponse = await reopened.execute(
      .init(
        operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
        reviewToken: repeatedReview.reviewToken))
    guard case .applied(_, .complete) = repeatedResponse.outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else {
      Issue.record("Retain exact saved \(referenceKind) lifetimes on reimport: \(repeatedResponse)")
      return
    }
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeatedData == after)
    var changedIncoming = incoming
    var changedReference = incomingReference
    switch referenceKind {
    case "ownedLink": changedReference["label"] = "Changed older bookmark"
    case "schedule":
      var form = try #require(changedReference["form"] as? [String: Any])
      form["start"] = 813_200_460.0
      changedReference["form"] = form
    default:
      changedReference["label"] = [
        "kind": "tag", "id": candidateKindIdentifier(601),
        "lifetimeId": candidateKindIdentifier(861),
      ]
    }
    changedIncoming[collection] = [changedReference]
    let changedDecoded = reopened.decodeImport(
      try JSONSerialization.data(withJSONObject: changedIncoming))
    guard case .decoded(let changedBackup) = changedDecoded else {
      Issue.record("The changed older reference must remain valid input: \(changedDecoded)")
      return
    }
    let changedReviewOutcome = await reopened.prepareReview(
      session: reopenedSession,
      command: .applyImport(backup: changedBackup, mode: .overwrite, restoreDeletedData: true))
    switch changedReviewOutcome {
    case .failed(let failure): #expect(failure.code == "unavailable")
    case .reviewed(let changedReview):
      let changedOperation = UUID()
      let changedResponse = await reopened.execute(
        .init(
          operationId: changedOperation, session: reopenedSession, command: changedReview.command,
          reviewToken: changedReview.reviewToken))
      guard case .rejected(let failure) = changedResponse.outcome,
        case .noReliableEvidence = await reopened.operationStatus(
          session: reopenedSession, operationId: changedOperation)
      else {
        Issue.record(
          "Changed restored references retain their reconciliation gate: \(changedResponse)")
        return
      }
      #expect(failure.code == "unavailable")
    }
    guard case .exported(let unchanged) = await reopened.exportData(session: reopenedSession) else {
      throw CancellationError()
    }
    #expect(unchanged == after)
  }
}
