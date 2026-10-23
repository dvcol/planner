import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeImportPredecessorLabelTests {
  @Test(arguments: [101, 301], [false, true])
  func restoredOwnerLabelsRequireRepresentedAuthorizedDependencies(
    ownerSuffix: Int, obstructRecovery: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func decode(_ object: [String: Any]) throws -> PlannerDecodedBackup {
      guard
        case .decoded(let backup) = planner.decodeImport(
          try JSONSerialization.data(withJSONObject: object))
      else { throw CancellationError() }
      return backup
    }
    func apply(_ backup: PlannerDecodedBackup, restoring: Bool = false) async throws {
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session,
          command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: restoring)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: review.command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    let original = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    try await apply(try decode(original))
    guard case .exported(let originalData) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let originalObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let originalSources = try #require(originalObject["sources"] as? [[String: Any]])
    var empty = originalObject
    for key in empty.keys where key != "format" && key != "formatVersion" { empty[key] = [] }
    let selectedIdentifiers = [ownerSuffix, 501, 601].map(predecessorLabelIdentifier)
    let selectedSources = originalSources.filter {
      selectedIdentifiers.contains($0["id"] as? String ?? "")
    }
    for identifierSuffix in [501, 601, ownerSuffix] {
      let source = try #require(
        originalSources.first {
          $0["id"] as? String == predecessorLabelIdentifier(identifierSuffix)
        })
      let kindName = try #require(source["kind"] as? String)
      let kind = try #require(PlannerEntityKind(rawValue: kindName))
      let identifier = try #require(UUID(uuidString: predecessorLabelIdentifier(identifierSuffix)))
      guard
        case .reviewed(let deletion) = await planner.prepareReview(
          session: session, command: .deleteSource(source: .init(kind: kind, id: identifier))),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: deletion.command,
            reviewToken: deletion.reviewToken)
        ).outcome
      else { throw CancellationError() }
      var sourceOnly = empty
      sourceOnly["sources"] = [source]
      try await apply(try decode(sourceOnly), restoring: true)
    }
    guard case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before)
    else { throw CancellationError() }
    let ownerIdentifier = try #require(UUID(uuidString: predecessorLabelIdentifier(ownerSuffix)))
    let currentOwner = try #require(current.backup.sources.first { $0.id == ownerIdentifier })
    var independent = try #require(originalSources.first { $0["kind"] as? String == "tag" })
    independent["id"] = predecessorLabelIdentifier(602)
    independent["lifetimeId"] = predecessorLabelIdentifier(862)
    let originalAssociations = try #require(originalObject["labelAssociations"] as? [[String: Any]])
    let selectedAssociations = originalAssociations.filter {
      ($0["owner"] as? [String: Any])?["id"] as? String == ownerIdentifier.uuidString
    }
    var incoming = empty
    incoming["sources"] = selectedSources + [independent]
    incoming["labelAssociations"] = selectedAssociations
    var omittedDependencies = incoming
    omittedDependencies["sources"] =
      selectedSources.filter {
        $0["id"] as? String == ownerIdentifier.uuidString
      } + [independent]
    let omitted = try decode(omittedDependencies)
    guard
      case .failed(let missing) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: omitted, mode: .overwrite, restoreDeletedData: true)),
      case .exported(let afterMissing) = await planner.exportData(session: session)
    else {
      Issue.record("An omitted closed Category/Tag must not redirect by public identity.")
      return
    }
    #expect(missing.code == "missingReference")
    #expect(missing.propertyPath == "/labelAssociations/0/label/lifetimeId")
    #expect(afterMissing == before)
    let backup = try decode(incoming)
    guard
      case .reviewed(let denied) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite)),
      case .rejected = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: denied.command,
          reviewToken: denied.reviewToken)
      ).outcome,
      case .exported(let afterDenied) = await planner.exportData(session: session),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    #expect(afterDenied == before)
    #expect(review.impact.importDetails?.restorations.isEmpty == true)
    #expect(
      review.impact.importDetails?.referenceChanges.filter { $0.change == .restore }.count == 2)
    let operationIdentifier = UUID()
    guard
      case .listedNamespaces(let preparationNamespaces) = await planner.inspectRecovery(
        request: .namespaces), let preparationNamespace = preparationNamespaces.first
    else { throw CancellationError() }
    let namespaceURL = configuration.recoveryDirectoryURL.appendingPathComponent(
      preparationNamespace.namespaceId.uuidString)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: namespaceURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    }
    let failedPreparation = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .rejected = failedPreparation.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else {
      Issue.record("Failed recovery preparation must not apply any predecessor or label data.")
      return
    }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    guard case .exported(let afterPreparationFailure) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(afterPreparationFailure == before)
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    var observer: (any NSObjectProtocol)?
    if obstructRecovery {
      observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
    }
    defer {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      try? obstruction.restore()
    }
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, let recoveryOutcome) = response.outcome else {
      Issue.record(
        "The reviewed label graph must save with a truthful recovery outcome: \(response)")
      return
    }
    let checkpoint: Int64
    if obstructRecovery {
      guard case .incomplete = recoveryOutcome else {
        Issue.record(
          "Expected incomplete recovery after the save; actual: \(recoveryOutcome), obstructed: \(obstruction.didObstruct), failure: \(String(describing: obstruction.failure))"
        )
        return
      }
      let pendingStatus = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
      guard case .unavailable(let blockedRead) = pendingStatus else {
        Issue.record(
          "The obstructed recovery directory cannot supply a reliable status: \(pendingStatus)")
        return
      }
      #expect(blockedRead.code == "readUnavailable")
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      try obstruction.restore()
      guard
        case .appliedRecoveryIncomplete(let pending, _) = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else { throw CancellationError() }
      #expect(pending == result)
      guard
        case .applied(let repaired, .complete(let generation)) = await planner.retryRecovery(
          session: session, operationId: operationIdentifier
        ).outcome
      else { throw CancellationError() }
      #expect(repaired == result)
      checkpoint = generation
    } else {
      guard case .complete(let generation) = recoveryOutcome else { throw CancellationError() }
      checkpoint = generation
    }
    guard
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let restored) = planner.decodeImport(after),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId,
          checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "Restore labels under the exact live owner and represented live labels: \(response)")
      return
    }
    #expect(restored.backup.labelAssociations.count == 2)
    let currentLabels = current.backup.sources.filter { $0.kind == .category || $0.kind == .tag }
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var expectedSources = try #require(expected["sources"] as? [[String: Any]])
    for var source in selectedSources {
      let live = try #require(
        current.backup.sources.first { $0.id.uuidString == source["id"] as? String })
      source["lifetimeId"] = predecessorLabelLifetime(live).uuidString
      let index = try #require(
        expectedSources.firstIndex { $0["id"] as? String == live.id.uuidString })
      expectedSources[index] = source
    }
    expectedSources.append(independent)
    expectedSources.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["sources"] = expectedSources
    var expectedAssociations: [[String: Any]] = []
    var expectedFamilies = try #require(expected["restorationFamilies"] as? [[String: Any]])
    for var association in selectedAssociations {
      let identifierString = try #require(association["id"] as? String)
      let identifier = try #require(UUID(uuidString: identifierString))
      let restoredAssociation = try #require(
        restored.backup.labelAssociations.first { $0.id == identifier })
      let originalLifetime = try #require(association["lifetimeId"] as? String)
      #expect(restoredAssociation.lifetimeId.uuidString != originalLifetime)
      var ownerBinding = try #require(association["owner"] as? [String: Any])
      ownerBinding["lifetimeId"] = predecessorLabelLifetime(currentOwner).uuidString
      association["owner"] = ownerBinding
      var labelBinding = try #require(association["label"] as? [String: Any])
      let label = try #require(
        currentLabels.first { $0.id.uuidString == labelBinding["id"] as? String })
      labelBinding["lifetimeId"] = predecessorLabelLifetime(label).uuidString
      association["label"] = labelBinding
      association["lifetimeId"] = restoredAssociation.lifetimeId.uuidString
      expectedAssociations.append(association)
      let family = try #require(
        restored.backup.restorationFamilies.first {
          $0.predecessor.kind == .labelAssociation && $0.predecessor.id == identifier
        })
      #expect(family.predecessor.lifetimeId.uuidString == originalLifetime)
      #expect(family.candidates.count == 1)
      #expect(family.candidates.first?.lifetimeId == restoredAssociation.lifetimeId)
      #expect(family.candidates.first?.operationId == operationIdentifier)
      expectedFamilies.append([
        "familyId": family.familyId.uuidString,
        "predecessor": [
          "kind": "labelAssociation", "id": identifier.uuidString,
          "lifetimeId": originalLifetime,
        ],
        "candidates": [
          [
            "lifetimeId": restoredAssociation.lifetimeId.uuidString,
            "operationId": operationIdentifier.uuidString,
          ]
        ],
      ])
    }
    expectedAssociations.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expectedFamilies.sort { ($0["familyId"] as? String ?? "") < ($1["familyId"] as? String ?? "") }
    expected["labelAssociations"] = expectedAssociations
    expected["restorationFamilies"] = expectedFamilies
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    #expect(NSDictionary(dictionary: recovery).isEqual(to: expected))
    let sourceRead = await planner.read(
      session: session,
      request: .source(.init(kind: currentOwner.kind, id: currentOwner.id)))
    switch sourceRead {
    case .source(.item(let item)):
      #expect(Set(item.labels.map(\.reference.id)) == Set(currentLabels.map(\.id)))
    case .source(.itinerary(let itinerary)):
      #expect(Set(itinerary.labels.map(\.reference.id)) == Set(currentLabels.map(\.id)))
    default: Issue.record("Read the restored label choices from the canonical owner.")
    }
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
  }
}

private func predecessorLabelIdentifier(_ suffix: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", suffix)
}

private func predecessorLabelLifetime(_ source: PlannerPortableSource) -> UUID {
  switch source {
  case .item(let item): item.lifetimeId
  case .list(let list): list.lifetimeId
  case .itinerary(let itinerary): itinerary.lifetimeId
  case .category(let category): category.lifetimeId
  case .tag(let tag): tag.lifetimeId
  }
}
