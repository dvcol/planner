import Foundation
import PlannerCore
import Testing

struct NativeImportRestorationTests {
  @Test func skipKeepsRestoredCurrentDataWhileImportingAnIndependentSource() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum", notes: "Keep current notes")))
      ).outcome,
      let item = created.generated.first,
      case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: item)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .reviewed(let restoration) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: restoration.command,
          reviewToken: restoration.reviewToken)
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before),
      let currentItem = current.backup.items.first
    else { throw CancellationError() }
    var incoming = try #require(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let fixture = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let fixtureSources = try #require(fixture["sources"] as? [[String: Any]])
    let independentTag = try #require(fixtureSources.first { $0["kind"] as? String == "tag" })
    let tagIdentifier = try #require(independentTag["id"] as? String)
    let tagUUID = try #require(UUID(uuidString: tagIdentifier))
    var sources = try #require(incoming["sources"] as? [[String: Any]])
    sources.append(independentTag)
    incoming["sources"] = sources
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming))
    else { throw CancellationError() }
    let reviewOutcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: .skip))
    guard case .reviewed(let review) = reviewOutcome else {
      Issue.record("Skip must retain the live Item and admit independent data: \(reviewOutcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.map(\.owner.id) == [tagUUID])
    #expect(details.skippedConflicts.map(\.owner.id) == [item.id])
    #expect(details.skippedConflicts.first?.owner.lifetimeId == currentItem.lifetimeId)
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    #expect(details.skippedDependents.isEmpty)
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
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Mixed Skip must apply and independently recover together: \(response)")
      return
    }
    var actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recovery).isEqual(to: actual))
    let actualSources = try #require(actual["sources"] as? [[String: Any]])
    let importedTag = try #require(
      actualSources.first { $0["id"] as? String == tagIdentifier })
    #expect(NSDictionary(dictionary: importedTag).isEqual(to: independentTag))
    actual["sources"] = actualSources.filter { $0["id"] as? String != tagIdentifier }
    let expectedCurrent = try #require(
      JSONSerialization.jsonObject(with: before) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expectedCurrent))
    #expect(!result.generated.contains(item))
    #expect(result.importSummary?.imports.map(\.owner.id) == [tagUUID])
    #expect(
      result.importSummary?.skippedConflicts.first?.owner.lifetimeId == currentItem.lifetimeId)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .skip)),
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

  @Test func skipKeepsRestoredCurrentDataAndSkipsOwnersBoundToItsClosedPredecessor() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum", notes: "Keep current notes")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let otherCreated, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Current lunch")))
      ).outcome,
      let otherItem = otherCreated.generated.first,
      case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: item)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .reviewed(let restoration) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: restoration.command,
          reviewToken: restoration.reviewToken)
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before),
      let currentItem = current.backup.items.first(where: { $0.id == item.id })
    else { throw CancellationError() }
    var incoming = try #require(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let fixture = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let fixtureSources = try #require(fixture["sources"] as? [[String: Any]])
    let independentTag = try #require(fixtureSources.first { $0["kind"] as? String == "tag" })
    let tagIdentifier = try #require(independentTag["id"] as? String)
    let tagUUID = try #require(UUID(uuidString: tagIdentifier))
    var sources = try #require(incoming["sources"] as? [[String: Any]])
    let predecessor = try #require(sources.first { $0["id"] as? String == item.id.uuidString })
    let currentOther = try #require(
      sources.first { $0["id"] as? String == otherItem.id.uuidString })
    var listSource = try #require(fixtureSources.first { $0["kind"] as? String == "list" })
    var listContent = try #require(listSource["content"] as? [String: Any])
    listContent["name"] = "Old route branch"
    listContent["manualEstimate"] = NSNull()
    listSource["content"] = listContent
    var itinerarySource = try #require(
      fixtureSources.first { $0["kind"] as? String == "itinerary" })
    var itineraryContent = try #require(itinerarySource["content"] as? [String: Any])
    itineraryContent["title"] = "Dependent route"
    itineraryContent["manualEstimate"] = NSNull()
    itinerarySource["content"] = itineraryContent
    let listIdentifierText = try #require(listSource["id"] as? String)
    let itineraryIdentifierText = try #require(itinerarySource["id"] as? String)
    let listIdentifier = try #require(UUID(uuidString: listIdentifierText))
    let itineraryIdentifier = try #require(UUID(uuidString: itineraryIdentifierText))
    let listBinding: [String: Any] = [
      "kind": "list", "id": listIdentifier.uuidString,
      "lifetimeId": try #require(listSource["lifetimeId"] as? String),
    ]
    let itineraryBinding: [String: Any] = [
      "kind": "itinerary", "id": itineraryIdentifier.uuidString,
      "lifetimeId": try #require(itinerarySource["lifetimeId"] as? String),
    ]
    let predecessorBinding: [String: Any] = [
      "kind": "item", "id": item.id.uuidString,
      "lifetimeId": try #require(predecessor["lifetimeId"] as? String),
    ]
    let otherBinding: [String: Any] = [
      "kind": "item", "id": otherItem.id.uuidString,
      "lifetimeId": try #require(currentOther["lifetimeId"] as? String),
    ]
    sources += [listSource, itinerarySource, independentTag]
    incoming["sources"] = sources
    incoming["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000477",
        "lifetimeId": "00000000-0000-4000-8000-000000000477",
        "list": listBinding, "item": predecessorBinding, "rank": "1024", "localDone": false,
      ],
      [
        "id": "00000000-0000-4000-8000-000000000478",
        "lifetimeId": "00000000-0000-4000-8000-000000000478",
        "list": listBinding, "item": otherBinding, "rank": "2048", "localDone": true,
      ],
    ]
    incoming["itineraryEntries"] = [
      [
        "id": "00000000-0000-4000-8000-000000000457",
        "lifetimeId": "00000000-0000-4000-8000-000000000457",
        "itinerary": itineraryBinding, "source": listBinding, "rank": "1024",
        "localDone": NSNull(),
      ],
      [
        "id": "00000000-0000-4000-8000-000000000458",
        "lifetimeId": "00000000-0000-4000-8000-000000000458",
        "itinerary": itineraryBinding, "source": otherBinding, "rank": "2048", "localDone": false,
      ],
    ]
    let decodedResponse = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decodedResponse else {
      Issue.record("The complete predecessor fixture must decode: \(decodedResponse)")
      return
    }
    #expect(backup.externalBindings.isEmpty)
    let reviewOutcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: .skip))
    guard case .reviewed(let review) = reviewOutcome else {
      Issue.record("Skip must retain the live Item and admit independent data: \(reviewOutcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.map(\.owner.id) == [tagUUID])
    #expect(details.skippedConflicts.map(\.owner.id) == [item.id])
    #expect(details.skippedConflicts.first?.owner.lifetimeId == currentItem.lifetimeId)
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    #expect(
      Set(details.skippedDependents.map { $0.owner.id }) == [listIdentifier, itineraryIdentifier])
    #expect(details.skippedDependents.allSatisfy { $0.reasonCode == "deletedDependency" })
    #expect(details.skippedDependents.allSatisfy { $0.before == nil && $0.after == nil })
    #expect(details.unchanged.map { $0.owner.id } == [otherItem.id])
    #expect(details.referenceChanges.isEmpty)
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
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Mixed Skip must apply and independently recover together: \(response)")
      return
    }
    var actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recovery).isEqual(to: actual))
    let actualSources = try #require(actual["sources"] as? [[String: Any]])
    let importedTag = try #require(
      actualSources.first { $0["id"] as? String == tagIdentifier })
    #expect(NSDictionary(dictionary: importedTag).isEqual(to: independentTag))
    actual["sources"] = actualSources.filter { $0["id"] as? String != tagIdentifier }
    let expectedCurrent = try #require(
      JSONSerialization.jsonObject(with: before) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expectedCurrent))
    #expect(!result.generated.contains(item))
    #expect(
      Set(result.importSummary?.skippedDependents.map { $0.owner.id } ?? [])
        == [listIdentifier, itineraryIdentifier])
    #expect(result.importSummary?.imports.map(\.owner.id) == [tagUUID])
    #expect(
      result.importSummary?.skippedConflicts.first?.owner.lifetimeId == currentItem.lifetimeId)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .skip)),
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

  @Test func foreignOwnedCandidateCannotBypassRestorationReconciliation() async throws {
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
      case .exported(let originalData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var payload = try #require(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    var memberships = try #require(payload["memberships"] as? [[String: Any]])
    let membershipIdentifier = try #require(memberships[0]["id"] as? String)
    let predecessorLifetime = try #require(memberships[0]["lifetimeId"] as? String)
    let list = try #require(memberships[0]["list"] as? [String: Any])
    let listIdentifier = try #require(list["id"] as? String)
    let listUUID = try #require(UUID(uuidString: listIdentifier))
    let membershipUUID = try #require(UUID(uuidString: membershipIdentifier))
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: listUUID, membershipId: membershipUUID))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let closed = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    payload["deletionMarkers"] = closed["deletionMarkers"]
    let candidateLifetime = UUID().uuidString
    memberships[0]["lifetimeId"] = candidateLifetime
    payload["memberships"] = memberships
    var expanded = try #require(payload["expandedCompletions"] as? [[String: Any]])
    for index in expanded.indices {
      var context = try #require(expanded[index]["context"] as? [String: Any])
      if context["membershipId"] as? String == membershipIdentifier {
        context["membershipLifetimeId"] = candidateLifetime
        expanded[index]["context"] = context
      }
    }
    payload["expandedCompletions"] = expanded
    payload["restorationFamilies"] = [
      [
        "familyId": UUID().uuidString,
        "predecessor": [
          "kind": "membership", "id": membershipIdentifier,
          "lifetimeId": predecessorLifetime,
        ],
        "candidates": [["lifetimeId": candidateLifetime, "operationId": UUID().uuidString]],
      ]
    ]
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: payload)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: incoming, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .rejected = response.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record("Foreign owned candidate reconciliation must remain gated: \(response)")
      return
    }
    #expect(after == before)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == before)
  }

  @Test(arguments: ["item", "list", "itinerary", "category", "tag"], [false, true])
  func restoringSourceAndIncludedReferencesPreservesTheFullPlanningGraph(
    kind: String, deleteThroughImport: Bool
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
      let originalSource = original.backup.sources.first(where: { $0.kind.rawValue == kind })
    else { throw CancellationError() }
    let source = PlannerEntityReference(kind: originalSource.kind, id: originalSource.id)
    guard
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .exported(let deletedData) = await planner.exportData(session: session),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true))
    else {
      Issue.record("Preview restoration and included references for \(kind).")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.restorations.map(\.owner.id) == [source.id])
    #expect(review.impact.sourceDeletes.isEmpty)
    #expect(details.referenceChanges.contains { $0.change == .restore })
    guard case .exported(let reviewedData) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(reviewedData == deletedData)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let restoredData) = await planner.exportData(session: session),
      case .decoded(let restored) = planner.decodeImport(restoredData),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Apply complete \(kind) restoration: \(response)")
      return
    }
    guard
      case .reviewed(let olderReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: original, mode: .skip))
    else {
      Issue.record("Skip must review the older \(kind) without replacing its restored graph.")
      return
    }
    let restoredBackupObject = try #require(
      JSONSerialization.jsonObject(with: restoredData) as? [String: Any])
    let restoredSourceRecords = try #require(restoredBackupObject["sources"] as? [[String: Any]])
    let keptSourceRecord = try #require(
      restoredSourceRecords.first {
        $0["kind"] as? String == kind && $0["id"] as? String == source.id.uuidString
      })
    let keptLifetimeText = try #require(keptSourceRecord["lifetimeId"] as? String)
    let keptLifetime = try #require(UUID(uuidString: keptLifetimeText))
    let olderDetails = try #require(olderReview.impact.importDetails)
    let keptEntry = try #require(
      olderDetails.skippedConflicts.first {
        $0.owner.id == source.id && $0.owner.kind == source.kind
      })
    #expect(keptEntry.owner.lifetimeId == keptLifetime)
    #expect(olderDetails.imports.isEmpty && olderDetails.replacements.isEmpty)
    #expect(olderDetails.restorations.isEmpty && olderDetails.skippedDependents.isEmpty)
    #expect(olderDetails.referenceChanges.allSatisfy { $0.change == .retain })
    guard case .exported(let afterOlderReview) = await planner.exportData(session: session),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: olderReview.command,
          reviewToken: olderReview.reviewToken)
      ).outcome,
      case .exported(let afterOlderImport) = await planner.exportData(session: session)
    else {
      Issue.record("Skip must retain every restored \(kind) reference and history record.")
      return
    }
    #expect(afterOlderReview == restoredData && afterOlderImport == restoredData)
    #expect(result.generated.isEmpty && result.affected.contains(source))
    #expect(
      Set(result.affectedReferences).isSuperset(
        of: details.referenceChanges.filter {
          $0.change == .restore
        }.map(\.reference)))
    let beforeObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let afterObject = try #require(
      JSONSerialization.jsonObject(with: restoredData) as? [String: Any])
    let beforeContent = try #require(restorationContentGraph(beforeObject) as? [String: Any])
    let afterContent = try #require(restorationContentGraph(afterObject) as? [String: Any])
    #expect(NSDictionary(dictionary: afterContent).isEqual(to: beforeContent))
    let recoveryObject = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveryObject).isEqual(to: afterObject))
    #expect(!restored.backup.restorationFamilies.isEmpty)
    #expect(
      restored.backup.restorationFamilies.allSatisfy {
        $0.candidates.count == 1 && $0.candidates.first?.operationId == operationIdentifier
      })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: restored, mode: .overwrite)),
      case .applied(let repeated, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
          reviewToken: repeatedReview.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == restoredData)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.generated.isEmpty && repeatedData == restoredData)
    let copy = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("copy/store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("copy/control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("copy/recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let copySession) = await copy.bootstrap(),
      case .reviewed(let copyReview) = await copy.prepareReview(
        session: copySession, command: .applyImport(backup: restored)),
      case .applied(_, .complete) = await copy.execute(
        .init(
          operationId: UUID(), session: copySession, command: copyReview.command,
          reviewToken: copyReview.reviewToken)
      ).outcome,
      case .exported(let copyData) = await copy.exportData(session: copySession)
    else { throw CancellationError() }
    #expect(copyData == restoredData)
    let sourceFamily = try #require(
      restored.backup.restorationFamilies.first {
        $0.predecessor.kind.rawValue == kind && $0.predecessor.id == source.id
      })
    let secondDeletionCommand: PlannerCommand
    if deleteThroughImport {
      let payload = try restorationDeletionPayload(afterObject, deleting: source)
      guard
        case .decoded(let deletionBackup) = reopened.decodeImport(
          try JSONSerialization.data(withJSONObject: payload))
      else { throw CancellationError() }
      secondDeletionCommand = .applyImport(backup: deletionBackup, mode: .overwrite)
    } else {
      secondDeletionCommand = .deleteSource(source: source)
    }
    guard
      case .reviewed(let secondDeletion) = await reopened.prepareReview(
        session: reopenedSession, command: secondDeletionCommand),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: secondDeletion.command,
          reviewToken: secondDeletion.reviewToken)
      ).outcome,
      case .exported(let secondDeletedData) = await reopened.exportData(session: reopenedSession),
      case .decoded(let secondDeleted) = reopened.decodeImport(secondDeletedData)
    else { throw CancellationError() }
    #expect(
      secondDeleted.backup.deletionMarkers.contains {
        $0.closedFamilyId == sourceFamily.familyId
      })
    #expect(
      Set(restored.backup.restorationFamilies.map(\.familyId)).isSubset(
        of:
          Set(secondDeleted.backup.deletionMarkers.compactMap(\.closedFamilyId))))
    if deleteThroughImport {
      guard
        case .reviewed(let repeatDeletionReview) = await reopened.prepareReview(
          session: reopenedSession, command: secondDeletionCommand),
        case .applied(let repeatedDeletion, .complete) = await reopened.execute(
          .init(
            operationId: UUID(), session: reopenedSession, command: repeatDeletionReview.command,
            reviewToken: repeatDeletionReview.reviewToken)
        ).outcome,
        case .exported(let repeatedDeletionData) = await reopened.exportData(
          session: reopenedSession)
      else {
        Issue.record("Repeated family-closed deletion import must remain idempotent.")
        return
      }
      #expect(repeatedDeletion.generated.isEmpty && repeatedDeletionData == secondDeletedData)
    }
    let previousSources = try #require(afterObject["sources"] as? [[String: Any]])
    let previousSource = try #require(
      previousSources.first {
        $0["id"] as? String == source.id.uuidString
      })
    let previousLifetime = try #require(previousSource["lifetimeId"] as? String)
    guard
      case .reviewed(let nextRestoreReview) = await reopened.prepareReview(
        session: reopenedSession,
        command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: nextRestoreReview.command,
          reviewToken: nextRestoreReview.reviewToken)
      ).outcome,
      case .exported(let nextRestoredData) = await reopened.exportData(session: reopenedSession),
      case .decoded(let nextRestored) = reopened.decodeImport(nextRestoredData)
    else {
      Issue.record("Later explicit restoration must start a new family for \(kind).")
      return
    }
    #expect(
      nextRestored.backup.restorationFamilies.contains {
        $0.predecessor.id == source.id && $0.predecessor.lifetimeId.uuidString == previousLifetime
          && $0.familyId != sourceFamily.familyId
      })
  }

  @Test func reviewedRestoreKeepsPublicIdentityAndClosesThePreviousLifetime() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum", notes: "Saved notes")))
      ).outcome,
      let item = created.generated.first,
      case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData),
      let originalItem = original.backup.items.first,
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: item)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .exported(let deletedData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    guard
      case .reviewed(let ordinaryReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: original, mode: .overwrite))
    else { throw CancellationError() }
    let ordinaryOperationIdentifier = UUID()
    let ordinaryResponse = await planner.execute(
      .init(
        operationId: ordinaryOperationIdentifier, session: session,
        command: ordinaryReview.command, reviewToken: ordinaryReview.reviewToken))
    guard case .rejected = ordinaryResponse.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: ordinaryOperationIdentifier),
      case .rejected(let changedConfirmationFailure) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true),
          reviewToken: ordinaryReview.reviewToken)
      ).outcome,
      case .failed(let invalidModeFailure) = await planner.prepareReview(
        session: session, command: .applyImport(backup: original, restoreDeletedData: true))
    else { throw CancellationError() }
    #expect(changedConfirmationFailure.code == "staleReview")
    #expect(invalidModeFailure.code == "invalidInput")
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true))
    else {
      Issue.record("Explicit Overwrite must preview the deleted source restoration.")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.restorations.map(\.owner.id) == [item.id])
    guard case .exported(let afterReview) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterReview == deletedData)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let restoredData) = await planner.exportData(session: session),
      case .decoded(let restored) = planner.decodeImport(restoredData),
      let restoredItem = restored.backup.items.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Reviewed restoration must save and independently recover: \(response)")
      return
    }
    #expect(restoredItem.id == item.id && restoredItem.content.title == "Museum")
    #expect(restoredItem.content.notes == "Saved notes")
    #expect(restoredItem.lifetimeId != originalItem.lifetimeId)
    let olderBackupReview = await planner.prepareReview(
      session: session, command: .applyImport(backup: original, mode: .skip))
    guard case .reviewed(let olderReview) = olderBackupReview else {
      Issue.record("Skip must retain the current restored Item: \(olderBackupReview)")
      return
    }
    let olderDetails = try #require(olderReview.impact.importDetails)
    #expect(olderDetails.skippedConflicts.map(\.owner.id) == [item.id])
    #expect(olderDetails.skippedConflicts.first?.owner.lifetimeId == restoredItem.lifetimeId)
    #expect(olderDetails.skippedConflicts.first?.reasonCode == "matchingRecordConflict")
    #expect(olderDetails.imports.isEmpty && olderDetails.replacements.isEmpty)
    #expect(olderDetails.restorations.isEmpty && olderDetails.skippedDependents.isEmpty)
    guard case .exported(let afterOlderReview) = await planner.exportData(session: session),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: olderReview.command,
          reviewToken: olderReview.reviewToken)
      ).outcome,
      case .exported(let afterOlderImport) = await planner.exportData(session: session)
    else {
      Issue.record("Reviewed Skip must preserve the restored graph through execution.")
      return
    }
    #expect(afterOlderReview == restoredData)
    #expect(afterOlderImport == restoredData)
    guard
      case .rejected(let replayAuthorizationFailure) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .applyImport(backup: original, mode: .overwrite))
      ).outcome
    else { throw CancellationError() }
    #expect(replayAuthorizationFailure.code == "operationPayloadMismatch")
    let family = try #require(restored.backup.restorationFamilies.first)
    #expect(family.predecessor.id == item.id)
    #expect(family.predecessor.lifetimeId == originalItem.lifetimeId)
    #expect(family.candidates.count == 1)
    #expect(family.candidates.first?.lifetimeId == restoredItem.lifetimeId)
    #expect(family.candidates.first?.operationId == operationIdentifier)
    #expect(restored.backup.deletionMarkers.count == 1)
    #expect(result.affected.contains(item))
    let restoredObject = try #require(
      JSONSerialization.jsonObject(with: restoredData) as? [String: Any])
    let recoveredObject = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredObject).isEqual(to: restoredObject))
    let admission = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("admission/store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("admission/control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("admission/recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let admissionSession) = await admission.bootstrap(),
      case .decoded(let deleted) = admission.decodeImport(deletedData),
      case .reviewed(let deletedReview) = await admission.prepareReview(
        session: admissionSession, command: .applyImport(backup: deleted)),
      case .applied(_, .complete) = await admission.execute(
        .init(
          operationId: UUID(), session: admissionSession, command: deletedReview.command,
          reviewToken: deletedReview.reviewToken)
      ).outcome,
      case .reviewed(let skipReview) = await admission.prepareReview(
        session: admissionSession, command: .applyImport(backup: restored)),
      case .applied(_, .complete) = await admission.execute(
        .init(
          operationId: UUID(), session: admissionSession, command: skipReview.command,
          reviewToken: skipReview.reviewToken)
      ).outcome,
      case .exported(let skipData) = await admission.exportData(session: admissionSession),
      case .reviewed(let candidateReview) = await admission.prepareReview(
        session: admissionSession,
        command: .applyImport(backup: restored, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    #expect(skipData == deletedData)
    let candidateOperationIdentifier = UUID()
    let candidateResponse = await admission.execute(
      .init(
        operationId: candidateOperationIdentifier, session: admissionSession,
        command: candidateReview.command, reviewToken: candidateReview.reviewToken))
    guard
      case .applied(let candidateResult, .complete(let candidateCheckpoint)) = candidateResponse
        .outcome,
      case .exported(let candidateData) = await admission.exportData(session: admissionSession),
      case .decoded(let candidateBackup) = admission.decodeImport(candidateData),
      let candidateItem = candidateBackup.backup.items.first
    else {
      Issue.record(
        "Q152 must restore incoming values under a fresh local lifetime: \(candidateResponse)")
      return
    }
    #expect(candidateItem.id == item.id)
    #expect(candidateItem.content.title == "Museum" && candidateItem.content.notes == "Saved notes")
    #expect(candidateItem.lifetimeId != originalItem.lifetimeId)
    #expect(candidateItem.lifetimeId != restoredItem.lifetimeId)
    let candidateFamily = try #require(candidateBackup.backup.restorationFamilies.first)
    #expect(candidateFamily.familyId == family.familyId)
    #expect(candidateFamily.predecessor == family.predecessor)
    #expect(candidateFamily.candidates.count == 1)
    #expect(candidateFamily.candidates.first?.lifetimeId == candidateItem.lifetimeId)
    #expect(candidateFamily.candidates.first?.operationId == candidateOperationIdentifier)
    var expectedCandidateObject = restoredObject
    var expectedCandidateSources = try #require(
      expectedCandidateObject["sources"] as? [[String: Any]])
    #expect(expectedCandidateSources.count == 1)
    expectedCandidateSources[0]["lifetimeId"] = candidateItem.lifetimeId.uuidString
    expectedCandidateObject["sources"] = expectedCandidateSources
    var expectedCandidateFamilies = try #require(
      expectedCandidateObject["restorationFamilies"] as? [[String: Any]])
    #expect(expectedCandidateFamilies.count == 1)
    expectedCandidateFamilies[0]["candidates"] = [
      [
        "lifetimeId": candidateItem.lifetimeId.uuidString,
        "operationId": candidateOperationIdentifier.uuidString,
      ]
    ]
    expectedCandidateObject["restorationFamilies"] = expectedCandidateFamilies
    let candidateObject = try #require(
      JSONSerialization.jsonObject(with: candidateData) as? [String: Any])
    #expect(NSDictionary(dictionary: candidateObject).isEqual(to: expectedCandidateObject))
    guard
      case .listedNamespaces(let candidateNamespaces) = await admission.inspectRecovery(
        request: .namespaces),
      let candidateNamespace = candidateNamespaces.first,
      case .selected(let candidateRecovery) = await admission.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: candidateNamespace.namespaceId, checkpointGeneration: candidateCheckpoint)),
      case .applied(let candidateReplay, .complete(let candidateReplayCheckpoint)) =
        await admission.execute(
          .init(
            operationId: candidateOperationIdentifier, session: admissionSession,
            command: candidateReview.command)
        ).outcome,
      case .reviewed(let repeatedCandidateReview) = await admission.prepareReview(
        session: admissionSession,
        command: .applyImport(backup: restored, mode: .overwrite, restoreDeletedData: true)),
      case .applied(_, .complete) = await admission.execute(
        .init(
          operationId: UUID(), session: admissionSession, command: repeatedCandidateReview.command,
          reviewToken: repeatedCandidateReview.reviewToken)
      ).outcome,
      case .exported(let repeatedCandidateData) = await admission.exportData(
        session: admissionSession)
    else {
      Issue.record("Fresh local restoration must recover, replay and permit repeat import.")
      return
    }
    let candidateRecoveryObject = try #require(
      JSONSerialization.jsonObject(with: candidateRecovery.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: candidateRecoveryObject).isEqual(to: expectedCandidateObject))
    #expect(candidateReplay == candidateResult && candidateReplayCheckpoint == candidateCheckpoint)
    #expect(repeatedCandidateData == candidateData)
    var conflicting = restoredObject
    var conflictingFamilies = try #require(conflicting["restorationFamilies"] as? [[String: Any]])
    var candidates = try #require(conflictingFamilies[0]["candidates"] as? [[String: Any]])
    candidates[0]["operationId"] = UUID().uuidString
    conflictingFamilies[0]["candidates"] = candidates
    conflicting["restorationFamilies"] = conflictingFamilies
    var conflictingSources = try #require(conflicting["sources"] as? [[String: Any]])
    var conflictingContent = try #require(conflictingSources[0]["content"] as? [String: Any])
    conflictingContent["notes"] = "Incoming overwrite"
    conflictingSources[0]["content"] = conflictingContent
    var independentSource = conflictingSources[0]
    independentSource["id"] = UUID().uuidString
    independentSource["lifetimeId"] = UUID().uuidString
    conflictingSources.append(independentSource)
    conflicting["sources"] = conflictingSources
    guard
      case .decoded(let conflictingBackup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: conflicting)),
      case .failed(let conflictingFailure) = await planner.prepareReview(
        session: session, command: .applyImport(backup: conflictingBackup, mode: .overwrite))
    else {
      Issue.record("Conflicting known restoration provenance must fail before issuing a review.")
      return
    }
    #expect(conflictingFailure.code == "unavailable")
    guard
      case .exported(let unchangedData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(unchangedData == restoredData)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome
    else { throw CancellationError() }
    #expect(reopenedData == restoredData)
    #expect(replayed == result && replayCheckpoint == checkpoint)
  }
}

private func restorationContentGraph(_ value: Any) -> Any {
  if let array = value as? [Any] { return array.map(restorationContentGraph) }
  guard let object = value as? [String: Any] else { return value }
  return object.filter {
    $0.key != "lifetimeId" && !$0.key.hasSuffix("LifetimeId")
      && !["deletionMarkers", "restorationFamilies"].contains($0.key)
  }.mapValues(restorationContentGraph)
}

private func restorationDeletionPayload(
  _ original: [String: Any], deleting source: PlannerEntityReference
) throws -> [String: Any] {
  var payload = original
  let sources = try #require(original["sources"] as? [[String: Any]])
  let removed = try #require(
    sources.first {
      $0["kind"] as? String == source.kind.rawValue && $0["id"] as? String == source.id.uuidString
    })
  payload["sources"] = sources.filter {
    $0["kind"] as? String != source.kind.rawValue || $0["id"] as? String != source.id.uuidString
  }
  for (group, bindings) in [
    ("memberships", ["list", "item"]), ("itineraryEntries", ["itinerary", "source"]),
    ("labelAssociations", ["owner", "label"]), ("ownedLinks", ["owner"]), ("schedules", ["source"]),
  ] {
    payload[group] = try #require(original[group] as? [[String: Any]]).filter { record in
      !bindings.contains { field in
        guard let binding = record[field] as? [String: Any] else { return false }
        return binding["kind"] as? String == source.kind.rawValue
          && binding["id"] as? String == source.id.uuidString
      }
    }
  }
  let entries = try #require(payload["itineraryEntries"] as? [[String: Any]])
  let memberships = try #require(payload["memberships"] as? [[String: Any]])
  let entryIdentifiers = Set(entries.compactMap { $0["id"] as? String })
  let membershipIdentifiers = Set(memberships.compactMap { $0["id"] as? String })
  payload["expandedCompletions"] = try #require(original["expandedCompletions"] as? [[String: Any]])
    .filter {
      guard let context = $0["context"] as? [String: Any],
        let entryIdentifier = context["listEntryId"] as? String,
        let membershipIdentifier = context["membershipId"] as? String
      else { return false }
      return entryIdentifiers.contains(entryIdentifier)
        && membershipIdentifiers.contains(membershipIdentifier)
    }
  var markers = try #require(original["deletionMarkers"] as? [[String: Any]])
  markers.append([
    "deletionId": UUID().uuidString, "operationId": UUID().uuidString,
    "target": [
      "kind": "source",
      "source": [
        "kind": source.kind.rawValue, "id": source.id.uuidString,
        "lifetimeId": try #require(removed["lifetimeId"]),
      ],
    ], "closedFamilyId": NSNull(),
  ])
  payload["deletionMarkers"] = markers
  return payload
}
