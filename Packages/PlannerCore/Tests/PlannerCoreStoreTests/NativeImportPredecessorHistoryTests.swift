import Foundation
import PlannerCore
import Testing

struct NativeImportPredecessorHistoryTests {
  @Test(arguments: [false, true], [false, true])
  func restoredMembershipHistoryTransformsExactLifetimesOrRejectsRetainedIdentityCollisions(
    collidesWithRetainedHistory: Bool, restoresIncomingValuesIntoDeletedSource: Bool
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
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      let oldMembership = original.backup.memberships.first,
      let oldList = original.backup.lists.first(where: { $0.id == oldMembership.list.id })
    else { throw CancellationError() }
    let list = PlannerEntityReference(kind: .list, id: oldList.id)
    guard
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: list)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let originalObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let originalSources = try #require(originalObject["sources"] as? [[String: Any]])
    let originalList = try #require(
      originalSources.first { $0["id"] as? String == list.id.uuidString })
    var sourceOnly = originalObject
    for key in sourceOnly.keys where key != "format" && key != "formatVersion" {
      sourceOnly[key] = []
    }
    sourceOnly["sources"] = [originalList]
    if !restoresIncomingValuesIntoDeletedSource {
      guard
        case .decoded(let sourceOnlyBackup) = planner.decodeImport(
          try JSONSerialization.data(withJSONObject: sourceOnly)),
        case .reviewed(let restoration) = await planner.prepareReview(
          session: session,
          command: .applyImport(
            backup: sourceOnlyBackup, mode: .overwrite, restoreDeletedData: true)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: restoration.command,
            reviewToken: restoration.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before)
    else { throw CancellationError() }
    let currentList = current.backup.lists.first(where: { $0.id == list.id })
    #expect((currentList == nil) == restoresIncomingValuesIntoDeletedSource)
    var incoming = sourceOnly
    var independentTag = try #require(originalSources.first { $0["kind"] as? String == "tag" })
    independentTag["id"] = predecessorHistoryIdentifier(602)
    independentTag["lifetimeId"] = predecessorHistoryIdentifier(862)
    var tagContent = try #require(independentTag["content"] as? [String: Any])
    tagContent["name"] = "Independent new label"
    independentTag["content"] = tagContent
    incoming["sources"] = [originalList, independentTag]
    let originalMembership = try #require(
      (originalObject["memberships"] as? [[String: Any]])?.first)
    incoming["memberships"] = [originalMembership]
    if restoresIncomingValuesIntoDeletedSource {
      let currentObject = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
      let markers = try #require(currentObject["deletionMarkers"] as? [[String: Any]])
      incoming["deletionMarkers"] = markers.filter {
        guard let target = $0["target"] as? [String: Any],
          let source = target["source"] as? [String: Any]
        else { return false }
        return source["kind"] as? String == "list" && source["id"] as? String == list.id.uuidString
      }
      var incomingList = originalList
      incomingList["lifetimeId"] = predecessorHistoryIdentifier(881)
      incoming["sources"] = [incomingList, independentTag]
      var incomingMembership = originalMembership
      var owner = try #require(incomingMembership["list"] as? [String: Any])
      owner["lifetimeId"] = predecessorHistoryIdentifier(881)
      incomingMembership["list"] = owner
      incoming["memberships"] = [incomingMembership]
      let predecessor: [String: Any] = [
        "kind": "list", "id": list.id.uuidString, "lifetimeId": oldList.lifetimeId.uuidString,
      ]
      incoming["restorationFamilies"] = [
        [
          "familyId": predecessorHistoryIdentifier(893), "predecessor": predecessor,
          "candidates": [
            [
              "lifetimeId": predecessorHistoryIdentifier(881),
              "operationId": predecessorHistoryIdentifier(996),
            ]
          ],
        ]
      ]
    }
    var alias = try #require((originalObject["contextAliases"] as? [[String: Any]])?.first)
    var change = try #require((originalObject["completionChanges"] as? [[String: Any]])?.first)
    var earlierChanges: [[String: Any]] = []
    if !collidesWithRetainedHistory {
      alias["aliasId"] = predecessorHistoryIdentifier(691)
      alias["currentChangeId"] = predecessorHistoryIdentifier(891)
      change["id"] = predecessorHistoryIdentifier(891)
      change["aliasId"] = predecessorHistoryIdentifier(691)
      var earlierChange = change
      earlierChange["id"] = predecessorHistoryIdentifier(890)
      earlierChange["done"] = false
      earlierChanges = [earlierChange]
      change["observedChangeIds"] = [predecessorHistoryIdentifier(890)]
    }
    incoming["contextAliases"] = [alias]
    incoming["completionChanges"] = earlierChanges + [change]
    let decodedOutcome = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decodedOutcome else {
      Issue.record("The represented List and membership history must decode: \(decodedOutcome)")
      return
    }
    guard
      case .reviewed(let ordinary) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite)),
      case .rejected = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: ordinary.command,
          reviewToken: ordinary.reviewToken)
      ).outcome,
      case .exported(let afterDenied) = await planner.exportData(session: session),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    #expect(afterDenied == before)
    if let currentList {
      #expect(review.impact.importDetails?.restorations.isEmpty == true)
      #expect(
        review.impact.importDetails?.replacements.first?.owner.lifetimeId == currentList.lifetimeId)
    } else {
      #expect(review.impact.importDetails?.restorations.map(\.owner.id) == [list.id])
      #expect(review.impact.importDetails?.replacements.isEmpty == true)
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    if collidesWithRetainedHistory {
      guard case .rejected(let failure) = response.outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier),
        case .exported(let afterRejected) = await planner.exportData(session: session)
      else {
        Issue.record(
          "A retained history identity cannot be rebound to a fresh membership: \(response)")
        return
      }
      #expect(failure.code == "unavailable")
      #expect(afterRejected == before)
      let reopened = Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
      else { throw CancellationError() }
      #expect(reopenedData == before)
      return
    }
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let restored) = planner.decodeImport(after),
      let savedList = restored.backup.lists.first(where: { $0.id == list.id }),
      let membership = restored.backup.memberships.first(where: { $0.id == oldMembership.id }),
      let restoredAlias = restored.backup.contextAliases.first(where: {
        $0.aliasId.uuidString == predecessorHistoryIdentifier(691)
      }),
      let restoredChange = restored.backup.completionChanges.first(where: {
        $0.id.uuidString == predecessorHistoryIdentifier(891)
      }),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Restore exact contextual history under the saved List: \(response)")
      return
    }
    let context = PlannerPortableCompletionContext.listMembership(
      membershipId: membership.id, membershipLifetimeId: membership.lifetimeId)
    #expect(
      membership.lifetimeId != oldMembership.lifetimeId
        && membership.listLifetimeId == savedList.lifetimeId)
    #expect(
      membership.localDone && listRead.progress.doneCount == 1 && listRead.progress.totalCount == 1)
    #expect(restoredAlias.context == context && restoredAlias.canonicalContext == context)
    #expect(
      restoredChange.context == context && restoredChange.done
        && restoredChange.observedChangeIds.map(\.uuidString) == [predecessorHistoryIdentifier(890)]
    )
    let earlierChange = try #require(
      restored.backup.completionChanges.first {
        $0.id.uuidString == predecessorHistoryIdentifier(890)
      })
    #expect(
      earlierChange.context == context && !earlierChange.done
        && earlierChange.observedChangeIds.isEmpty)
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var expectedSources = try #require(expected["sources"] as? [[String: Any]])
    var expectedList = originalList
    expectedList["lifetimeId"] = savedList.lifetimeId.uuidString
    if let listIndex = expectedSources.firstIndex(where: {
      $0["id"] as? String == list.id.uuidString
    }) {
      expectedSources[listIndex] = expectedList
    } else {
      expectedSources.append(expectedList)
      #expect(savedList.lifetimeId != oldList.lifetimeId)
      #expect(savedList.lifetimeId.uuidString != predecessorHistoryIdentifier(881))
    }
    expectedSources.append(independentTag)
    expectedSources.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["sources"] = expectedSources
    var expectedMembership = originalMembership
    expectedMembership["lifetimeId"] = membership.lifetimeId.uuidString
    var expectedListBinding = try #require(expectedMembership["list"] as? [String: Any])
    expectedListBinding["lifetimeId"] = savedList.lifetimeId.uuidString
    expectedMembership["list"] = expectedListBinding
    var expectedMemberships = try #require(expected["memberships"] as? [[String: Any]])
    expectedMemberships.append(expectedMembership)
    expectedMemberships.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["memberships"] = expectedMemberships
    let expectedContext: [String: Any] = [
      "kind": "listMembership", "membershipId": membership.id.uuidString,
      "membershipLifetimeId": membership.lifetimeId.uuidString,
    ]
    alias["context"] = expectedContext
    alias["canonicalContext"] = expectedContext
    change["context"] = expectedContext
    var expectedAliases = try #require(expected["contextAliases"] as? [[String: Any]])
    expectedAliases.append(alias)
    expectedAliases.sort { ($0["aliasId"] as? String ?? "") < ($1["aliasId"] as? String ?? "") }
    expected["contextAliases"] = expectedAliases
    var expectedChanges = try #require(expected["completionChanges"] as? [[String: Any]])
    for var earlierChange in earlierChanges {
      earlierChange["context"] = expectedContext
      expectedChanges.append(earlierChange)
    }
    expectedChanges.append(change)
    expectedChanges.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["completionChanges"] = expectedChanges
    let family = try #require(
      restored.backup.restorationFamilies.first {
        $0.predecessor.kind == .membership && $0.predecessor.id == oldMembership.id
      })
    #expect(
      family.predecessor.lifetimeId == oldMembership.lifetimeId && family.candidates.count == 1)
    #expect(
      family.candidates.first?.lifetimeId == membership.lifetimeId
        && family.candidates.first?.operationId == operationIdentifier)
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let actualFamilies = try #require(actual["restorationFamilies"] as? [[String: Any]])
    let newFamily = try #require(
      actualFamilies.first { $0["familyId"] as? String == family.familyId.uuidString })
    var expectedFamilies = try #require(expected["restorationFamilies"] as? [[String: Any]])
    expectedFamilies.append(newFamily)
    if restoresIncomingValuesIntoDeletedSource {
      expectedFamilies.append([
        "familyId": "DE6D0B08-E4DF-8F2A-9DBD-91424DB6CEFB",
        "predecessor": [
          "kind": "list", "id": list.id.uuidString, "lifetimeId": oldList.lifetimeId.uuidString,
        ],
        "candidates": [
          [
            "lifetimeId": savedList.lifetimeId.uuidString,
            "operationId": operationIdentifier.uuidString,
          ]
        ],
      ])
    }
    expectedFamilies.sort { ($0["familyId"] as? String ?? "") < ($1["familyId"] as? String ?? "") }
    expected["restorationFamilies"] = expectedFamilies
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    let recoveredObject = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredObject).isEqual(to: expected))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeated) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: restored, mode: .overwrite)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    guard
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: membership.id)),
            done: false))
      ).outcome,
      case .exported(let afterCompletion) = await reopened.exportData(session: reopenedSession),
      case .decoded(let completed) = reopened.decodeImport(afterCompletion),
      let currentAlias = completed.backup.contextAliases.first(where: {
        $0.aliasId == restoredAlias.aliasId
      }),
      let currentChange = completed.backup.completionChanges.first(where: {
        $0.id == currentAlias.currentChangeId
      }),
      case .source(.item(let itemRead)) = await reopened.read(
        session: reopenedSession, request: .source(oldMembership.item))
    else { throw CancellationError() }
    #expect(
      completed.backup.memberships.first(where: { $0.id == membership.id })?.localDone == false)
    #expect(currentChange.context == context && !currentChange.done)
    #expect(currentChange.observedChangeIds == [restoredChange.id])
    #expect(itemRead.state.globalDone == false)
  }
}

private func predecessorHistoryIdentifier(_ suffix: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", suffix)
}
