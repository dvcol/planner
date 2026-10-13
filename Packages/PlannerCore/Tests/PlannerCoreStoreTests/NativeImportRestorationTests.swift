import Foundation
import PlannerCore
import Testing

struct NativeImportRestorationTests {
  @Test func foreignOwnedCandidateCannotBypassRestorationReconciliation() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeImportRestorationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
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
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeImportRestorationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
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
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeImportRestorationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
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
    guard
      case .rejected = await admission.execute(
        .init(
          operationId: candidateOperationIdentifier, session: admissionSession,
          command: candidateReview.command, reviewToken: candidateReview.reviewToken)
      ).outcome,
      case .noReliableEvidence = await admission.operationStatus(
        session: admissionSession, operationId: candidateOperationIdentifier),
      case .exported(let rejectedCandidateData) = await admission.exportData(
        session: admissionSession)
    else {
      Issue.record("Incoming candidate reconciliation must stay gated without any partial import.")
      return
    }
    #expect(rejectedCandidateData == deletedData)
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
      case .reviewed(let conflictingReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: conflictingBackup, mode: .overwrite))
    else { throw CancellationError() }
    let conflictingOperationIdentifier = UUID()
    guard
      case .rejected = await planner.execute(
        .init(
          operationId: conflictingOperationIdentifier, session: session,
          command: conflictingReview.command, reviewToken: conflictingReview.reviewToken)
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: conflictingOperationIdentifier),
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
