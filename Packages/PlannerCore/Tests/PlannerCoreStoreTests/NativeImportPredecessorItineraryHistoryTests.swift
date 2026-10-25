import Foundation
import PlannerCore
import Testing

struct NativeImportPredecessorItineraryHistoryTests {
  @Test(
    arguments: ["none", "direct", "expanded"],
    [(false, false), (false, true), (true, false), (true, true)])
  func restoredItineraryKeepsExactDirectAndExpandedHistoryOrRejectsTheWholeCollision(
    collision: String, restorationCase: (Bool, Bool)
  ) async throws {
    let (restoreListParent, restoresIncomingValuesIntoDeletedSource) = restorationCase
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var seedObject = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let directContext: [String: Any] = [
      "kind": "directItineraryItem", "entryId": itineraryHistoryIdentifier(451),
      "entryLifetimeId": itineraryHistoryIdentifier(451),
    ]
    let expandedContext: [String: Any] = [
      "kind": "expandedListItem", "listEntryId": itineraryHistoryIdentifier(452),
      "listEntryLifetimeId": itineraryHistoryIdentifier(452),
      "membershipId": itineraryHistoryIdentifier(401),
      "membershipLifetimeId": itineraryHistoryIdentifier(401),
    ]
    var seedAliases = try #require(seedObject["contextAliases"] as? [[String: Any]])
    var seedChanges = try #require(seedObject["completionChanges"] as? [[String: Any]])
    for (identifier, changeIdentifier, context) in [
      (451, 882, directContext), (452, 883, expandedContext),
    ] {
      seedAliases.append([
        "aliasId": itineraryHistoryIdentifier(identifier), "context": context,
        "canonicalContext": context, "initialDone": false,
        "currentChangeId": itineraryHistoryIdentifier(changeIdentifier),
      ])
      seedChanges.append([
        "id": itineraryHistoryIdentifier(changeIdentifier),
        "aliasId": itineraryHistoryIdentifier(identifier), "context": context,
        "done": false, "observedChangeIds": [],
      ])
    }
    seedObject["contextAliases"] = seedAliases
    seedObject["completionChanges"] = seedChanges
    guard
      case .decoded(let seed) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: seedObject)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      case .itinerary(let originalItinerary)? = original.backup.sources.first(where: {
        $0.kind == .itinerary
      })
    else { throw CancellationError() }
    let itinerary = PlannerEntityReference(kind: .itinerary, id: originalItinerary.id)
    let originalObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let originalSources = try #require(originalObject["sources"] as? [[String: Any]])
    let itineraryRecord = try #require(
      originalSources.first { $0["kind"] as? String == "itinerary" })
    let listRecord = try #require(
      originalSources.first { $0["id"] as? String == itineraryHistoryIdentifier(201) })
    var sourceOnly = originalObject
    for key in sourceOnly.keys where key != "format" && key != "formatVersion" {
      sourceOnly[key] = []
    }
    sourceOnly["sources"] = [itineraryRecord]
    if restoreListParent {
      let list = PlannerEntityReference(
        kind: .list, id: try #require(UUID(uuidString: itineraryHistoryIdentifier(201))))
      var listOnly = sourceOnly
      listOnly["sources"] = [listRecord]
      guard
        case .reviewed(let deletion) = await planner.prepareReview(
          session: session, command: .deleteSource(source: list)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: deletion.command,
            reviewToken: deletion.reviewToken)
        ).outcome,
        case .decoded(let listBackup) = planner.decodeImport(
          try JSONSerialization.data(withJSONObject: listOnly)),
        case .reviewed(let restoration) = await planner.prepareReview(
          session: session,
          command: .applyImport(backup: listBackup, mode: .overwrite, restoreDeletedData: true)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: restoration.command,
            reviewToken: restoration.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    guard
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: itinerary)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome
    else { throw CancellationError() }
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
    let currentItinerary = current.backup.sources.compactMap {
      portableSource -> PlannerPortableItinerary? in
      guard case .itinerary(let portableItinerary) = portableSource else { return nil }
      return portableItinerary
    }.first { $0.id == itinerary.id }
    #expect((currentItinerary == nil) == restoresIncomingValuesIntoDeletedSource)
    let currentList = try #require(
      current.backup.lists.first { $0.id.uuidString == itineraryHistoryIdentifier(201) })
    var incoming = sourceOnly
    var tag = try #require(originalSources.first { $0["kind"] as? String == "tag" })
    tag["id"] = itineraryHistoryIdentifier(602)
    tag["lifetimeId"] = itineraryHistoryIdentifier(862)
    incoming["sources"] = [itineraryRecord, tag]
    if restoreListParent { incoming["sources"] = [itineraryRecord, listRecord, tag] }
    let originalEntries = try #require(originalObject["itineraryEntries"] as? [[String: Any]])
    var directEntry = try #require(
      originalEntries.first { $0["id"] as? String == itineraryHistoryIdentifier(451) })
    directEntry["localDone"] = true
    let listEntry = try #require(
      originalEntries.first { $0["id"] as? String == itineraryHistoryIdentifier(452) })
    incoming["itineraryEntries"] = [directEntry, listEntry]
    let membership = try #require((originalObject["memberships"] as? [[String: Any]])?.first)
    incoming["memberships"] = [membership]
    var expanded = try #require((originalObject["expandedCompletions"] as? [[String: Any]])?.first)
    expanded["localDone"] = true
    incoming["expandedCompletions"] = [expanded]
    var aliases: [[String: Any]] = []
    var changes: [[String: Any]] = []
    for (
      kind, freshAliasIdentifier, freshChangeIdentifier, retainedAliasIdentifier,
      retainedChangeIdentifier, context
    ) in [
      ("direct", 691, 891, 451, 882, directContext),
      ("expanded", 692, 892, 452, 883, expandedContext),
    ] {
      var aliasIdentifier = freshAliasIdentifier
      var changeIdentifier = freshChangeIdentifier
      if collision == kind {
        aliasIdentifier = retainedAliasIdentifier
        changeIdentifier = retainedChangeIdentifier
      }
      aliases.append([
        "aliasId": itineraryHistoryIdentifier(aliasIdentifier), "context": context,
        "canonicalContext": context, "initialDone": false,
        "currentChangeId": itineraryHistoryIdentifier(changeIdentifier),
      ])
      changes.append([
        "id": itineraryHistoryIdentifier(changeIdentifier),
        "aliasId": itineraryHistoryIdentifier(aliasIdentifier), "context": context,
        "done": true, "observedChangeIds": [], "observedExpandedCompletionDeletionIds": [],
      ])
    }
    if restoresIncomingValuesIntoDeletedSource {
      var representedItinerary = itineraryRecord
      representedItinerary["lifetimeId"] = itineraryHistoryIdentifier(881)
      incoming["sources"] = [representedItinerary, tag]
      if restoreListParent { incoming["sources"] = [representedItinerary, listRecord, tag] }
      incoming["itineraryEntries"] = try [directEntry, listEntry].map { originalEntry in
        var entry = originalEntry
        var owner = try #require(entry["itinerary"] as? [String: Any])
        owner["lifetimeId"] = itineraryHistoryIdentifier(881)
        entry["itinerary"] = owner
        return entry
      }
      let currentObject = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
      let markers = try #require(currentObject["deletionMarkers"] as? [[String: Any]])
      incoming["deletionMarkers"] = markers.filter {
        guard let target = $0["target"] as? [String: Any],
          let source = target["source"] as? [String: Any]
        else { return false }
        return source["kind"] as? String == "itinerary"
          && source["id"] as? String == itinerary.id.uuidString
      }
      incoming["restorationFamilies"] = [
        [
          "familyId": itineraryHistoryIdentifier(893),
          "predecessor": [
            "kind": "itinerary", "id": itinerary.id.uuidString,
            "lifetimeId": originalItinerary.lifetimeId.uuidString,
          ],
          "candidates": [
            [
              "lifetimeId": itineraryHistoryIdentifier(881),
              "operationId": itineraryHistoryIdentifier(996),
            ]
          ],
        ]
      ]
    }
    incoming["contextAliases"] = aliases
    incoming["completionChanges"] = changes
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
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
    if let currentItinerary {
      #expect(review.impact.importDetails?.restorations.isEmpty == true)
      #expect(
        review.impact.importDetails?.replacements.first?.owner.lifetimeId
          == currentItinerary.lifetimeId)
    } else {
      #expect(review.impact.importDetails?.restorations.map(\.owner.id) == [itinerary.id])
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    if collision != "none" {
      guard case .rejected(let failure) = response.outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier),
        case .exported(let afterRejected) = await planner.exportData(session: session)
      else {
        Issue.record(
          "Either contextual history collision must reject every replacement/addition: \(response)")
        return
      }
      #expect(failure.code == "unavailable")
      #expect(afterRejected == before)
      return
    }
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let restored) = planner.decodeImport(after),
      let savedItinerary = restored.backup.sources.compactMap({
        portableSource -> PlannerPortableItinerary? in
        guard case .itinerary(let portableItinerary) = portableSource else { return nil }
        return portableItinerary
      }).first(where: { $0.id == itinerary.id }),
      let restoredDirect = restored.backup.itineraryEntries.first(where: {
        $0.id.uuidString == itineraryHistoryIdentifier(451)
      }),
      let restoredList = restored.backup.itineraryEntries.first(where: {
        $0.id.uuidString == itineraryHistoryIdentifier(452)
      }),
      let restoredMembership = restored.backup.memberships.first(where: {
        $0.id.uuidString == itineraryHistoryIdentifier(401)
      }),
      case .source(.itinerary(let itineraryRead)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "Restore exact direct and expanded history under the live Itinerary: \(response)")
      return
    }
    #expect(restoredDirect.lifetimeId.uuidString != itineraryHistoryIdentifier(451))
    #expect(restoredList.lifetimeId.uuidString != itineraryHistoryIdentifier(452))
    #expect(
      restoredMembership.localDone && restoredMembership.listLifetimeId == currentList.lifetimeId)
    if restoreListParent {
      #expect(restoredMembership.lifetimeId.uuidString != itineraryHistoryIdentifier(401))
      #expect(itineraryRead.progress.doneCount == 2 && itineraryRead.progress.totalCount == 2)
      #expect(itineraryRead.progress.archivedCount == 0)
    } else {
      #expect(restoredMembership.lifetimeId.uuidString == itineraryHistoryIdentifier(401))
      #expect(itineraryRead.progress.doneCount == 2 && itineraryRead.progress.totalCount == 3)
      #expect(itineraryRead.progress.archivedCount == 1)
    }
    #expect(itineraryRead.progress.state == .complete)
    var freshDirectContext = directContext
    freshDirectContext["entryLifetimeId"] = restoredDirect.lifetimeId.uuidString
    var freshExpandedContext = expandedContext
    freshExpandedContext["listEntryLifetimeId"] = restoredList.lifetimeId.uuidString
    freshExpandedContext["membershipLifetimeId"] = restoredMembership.lifetimeId.uuidString
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var expectedSources = try #require(expected["sources"] as? [[String: Any]])
    var expectedItinerary = itineraryRecord
    expectedItinerary["lifetimeId"] = savedItinerary.lifetimeId.uuidString
    if let itineraryIndex = expectedSources.firstIndex(where: {
      $0["id"] as? String == itinerary.id.uuidString
    }) {
      expectedSources[itineraryIndex] = expectedItinerary
    } else {
      expectedSources.append(expectedItinerary)
      #expect(savedItinerary.lifetimeId != originalItinerary.lifetimeId)
      #expect(savedItinerary.lifetimeId.uuidString != itineraryHistoryIdentifier(881))
    }
    if restoreListParent {
      var expectedList = listRecord
      expectedList["lifetimeId"] = currentList.lifetimeId.uuidString
      let listIndex = try #require(
        expectedSources.firstIndex { $0["id"] as? String == currentList.id.uuidString })
      expectedSources[listIndex] = expectedList
      var expectedMembership = membership
      expectedMembership["lifetimeId"] = restoredMembership.lifetimeId.uuidString
      var owner = try #require(expectedMembership["list"] as? [String: Any])
      owner["lifetimeId"] = currentList.lifetimeId.uuidString
      expectedMembership["list"] = owner
      var expectedMemberships = try #require(expected["memberships"] as? [[String: Any]])
      expectedMemberships.append(expectedMembership)
      expectedMemberships.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
      expected["memberships"] = expectedMemberships
    }
    expectedSources.append(tag)
    expectedSources.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["sources"] = expectedSources
    var expectedEntries = try #require(expected["itineraryEntries"] as? [[String: Any]])
    for (record, restoredEntry) in [(directEntry, restoredDirect), (listEntry, restoredList)] {
      var entry = record
      entry["lifetimeId"] = restoredEntry.lifetimeId.uuidString
      var owner = try #require(entry["itinerary"] as? [String: Any])
      owner["lifetimeId"] = savedItinerary.lifetimeId.uuidString
      entry["itinerary"] = owner
      if restoredEntry.source.kind == .list {
        var dependency = try #require(entry["source"] as? [String: Any])
        dependency["lifetimeId"] = currentList.lifetimeId.uuidString
        entry["source"] = dependency
      }
      expectedEntries.append(entry)
    }
    expectedEntries.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["itineraryEntries"] = expectedEntries
    var expandedRecordContext = try #require(expanded["context"] as? [String: Any])
    expandedRecordContext["listEntryLifetimeId"] = restoredList.lifetimeId.uuidString
    expandedRecordContext["membershipLifetimeId"] = restoredMembership.lifetimeId.uuidString
    expanded["context"] = expandedRecordContext
    expected["expandedCompletions"] = [expanded]
    var expectedAliases = try #require(expected["contextAliases"] as? [[String: Any]])
    var expectedChanges = try #require(expected["completionChanges"] as? [[String: Any]])
    for (index, context) in [freshDirectContext, freshExpandedContext].enumerated() {
      aliases[index]["context"] = context
      aliases[index]["canonicalContext"] = context
      changes[index]["context"] = context
      expectedAliases.append(aliases[index])
      expectedChanges.append(changes[index])
    }
    expectedAliases.sort { ($0["aliasId"] as? String ?? "") < ($1["aliasId"] as? String ?? "") }
    expectedChanges.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["contextAliases"] = expectedAliases
    expected["completionChanges"] = expectedChanges
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let actualFamilies = try #require(actual["restorationFamilies"] as? [[String: Any]])
    var expectedFamilies = try #require(expected["restorationFamilies"] as? [[String: Any]])
    for entry in [restoredDirect, restoredList] {
      let family = try #require(
        restored.backup.restorationFamilies.first {
          $0.predecessor.kind == .itineraryEntry && $0.predecessor.id == entry.id
        })
      #expect(family.predecessor.lifetimeId == entry.id && family.candidates.count == 1)
      #expect(
        family.candidates.first?.lifetimeId == entry.lifetimeId
          && family.candidates.first?.operationId == operationIdentifier)
      expectedFamilies.append(
        try #require(
          actualFamilies.first { $0["familyId"] as? String == family.familyId.uuidString }))
    }
    if restoreListParent {
      let family = try #require(
        restored.backup.restorationFamilies.first {
          $0.predecessor.kind == .membership && $0.predecessor.id == restoredMembership.id
        })
      #expect(
        family.predecessor.lifetimeId == restoredMembership.id && family.candidates.count == 1)
      #expect(
        family.candidates.first?.lifetimeId == restoredMembership.lifetimeId
          && family.candidates.first?.operationId == operationIdentifier)
      expectedFamilies.append(
        try #require(
          actualFamilies.first { $0["familyId"] as? String == family.familyId.uuidString }))
    }
    if restoresIncomingValuesIntoDeletedSource {
      expectedFamilies.append([
        "familyId": "C85169EF-4FEE-86AD-AC31-84374FA3B761",
        "predecessor": [
          "kind": "itinerary", "id": itinerary.id.uuidString,
          "lifetimeId": originalItinerary.lifetimeId.uuidString,
        ],
        "candidates": [
          [
            "lifetimeId": savedItinerary.lifetimeId.uuidString,
            "operationId": operationIdentifier.uuidString,
          ]
        ],
      ])
    }
    expectedFamilies.sort { ($0["familyId"] as? String ?? "") < ($1["familyId"] as? String ?? "") }
    expected["restorationFamilies"] = expectedFamilies
    if !NSDictionary(dictionary: actual).isEqual(to: expected) {
      try JSONSerialization.data(withJSONObject: actual, options: [.sortedKeys]).write(
        to: directory.appendingPathComponent("itinerary-history-actual.json"))
      try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys]).write(
        to: directory.appendingPathComponent("itinerary-history-expected.json"))
    }
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
        session: reopenedSession,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(
      reopenedData == after && repeatedData == after && replayed == result
        && replayCheckpoint == checkpoint)
    for appearance in [
      PlannerAppearance.directItineraryItem(itineraryId: itinerary.id, entryId: restoredDirect.id),
      .expandedListItem(
        itineraryId: itinerary.id, listEntryId: restoredList.id, membershipId: restoredMembership.id
      ),
    ] {
      guard
        case .applied(_, .complete) = await reopened.execute(
          .init(
            operationId: UUID(), session: reopenedSession,
            command: .setCompletion(scope: .appearance(appearance), done: false))
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let afterCompletion) = await reopened.exportData(session: reopenedSession),
      case .decoded(let completed) = reopened.decodeImport(afterCompletion),
      case .source(.item(let itemRead)) = await reopened.read(
        session: reopenedSession, request: .source(restoredMembership.item))
    else { throw CancellationError() }
    #expect(
      completed.backup.memberships.first(where: { $0.id == restoredMembership.id })?.localDone
        == true)
    #expect(itemRead.state.globalDone == false)
    for (aliasIdentifier, previousChangeIdentifier) in [(691, 891), (692, 892)] {
      let currentAlias = try #require(
        completed.backup.contextAliases.first {
          $0.aliasId.uuidString == itineraryHistoryIdentifier(aliasIdentifier)
        })
      let change = try #require(
        completed.backup.completionChanges.first { $0.id == currentAlias.currentChangeId })
      #expect(
        !change.done
          && change.observedChangeIds.map(\.uuidString) == [
            itineraryHistoryIdentifier(previousChangeIdentifier)
          ])
    }
  }
}

private func itineraryHistoryIdentifier(_ suffix: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", suffix)
}
