import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeImportApplyTests {
  @Test func failedRecoveryPreparationLeavesGraphAndReceiptUnapplied() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let backup) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceURL = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: namespaceURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .rejected(let failure) = response.outcome else {
      Issue.record(
        "Recovery preparation failure must reject the import before acknowledgement: \(response)")
      return
    }
    #expect(!failure.message.isEmpty)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(after == before)
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else { throw CancellationError() }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == before)
  }

  @Test(arguments: ["notes", "localCompletion"])
  func ordinaryEditAfterImportPreservesCompleteNativeAndRecoveryGraph(_ scenario: String)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let backup) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      let importedItem = backup.backup.items.first,
      case .source(.item(let beforeEdit)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: importedItem.id))),
      let notesHash = beforeEdit.fieldHashes[.notes]
    else { throw CancellationError() }
    let command: PlannerCommand
    if scenario == "localCompletion" {
      let membership = try #require(backup.backup.memberships.first)
      command = .setCompletion(
        scope: .appearance(
          .listMembership(listId: membership.list.id, membershipId: membership.id)), done: false)
    } else {
      command = .editItem(
        sourceId: importedItem.id, changes: .init(notes: .set("Imported note revision")),
        expectedFieldHashes: [.notes: notesHash])
    }
    let response = await planner.execute(
      .init(operationId: UUID(), session: session, command: command))
    guard case .applied(_, .complete(let checkpoint)) = response.outcome else {
      Issue.record("The ordinary \(scenario) edit must commit with complete recovery: \(response)")
      return
    }
    guard
      case .exported(let exported) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(selection.decodedBackup.backup.contextAliases.count == 1)
    #expect(
      selection.decodedBackup.backup.completionChanges.count
        == (scenario == "localCompletion" ? 2 : 1))
    if scenario == "localCompletion" {
      #expect(selection.decodedBackup.backup.memberships.first?.localDone == false)
      #expect(selection.decodedBackup.backup.items.first?.globalDone == importedItem.globalDone)
    }
    let native = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
    let recovered = try #require(
      JSONSerialization.jsonObject(with: selection.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recovered).isEqual(to: native))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == exported)
  }

  @Test(arguments: [false, true])
  func reviewedCompleteBackupRestoresItsGraphAndSurvivesReopen(retryRecovery: Bool) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let fixture = try nativeImportFixtureData()
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let backup) = planner.decodeImport(fixture),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup))
    else { throw CancellationError() }
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    var observer: (any NSObjectProtocol)?
    if retryRecovery {
      observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
    }
    defer {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let result = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let importedResult, let recovery) = result.outcome else {
      Issue.record("Restore the complete reviewed graph with independent recovery: \(result)")
      return
    }
    let checkpoint: Int64
    if retryRecovery {
      guard case .incomplete = recovery else { throw CancellationError() }
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      try obstruction.restore()
      guard
        case .applied(let retriedResult, .complete(let generation)) = await planner.retryRecovery(
          session: session, operationId: operationIdentifier
        ).outcome
      else { throw CancellationError() }
      #expect(retriedResult == importedResult)
      checkpoint = generation
    } else {
      guard case .complete(let generation) = recovery else { throw CancellationError() }
      checkpoint = generation
    }
    #expect(checkpoint > 0)
    guard case .exported(let exported) = await planner.exportData(session: session) else {
      Issue.record("The restored complete graph must remain exportable.")
      return
    }
    let expected = try canonicalPortableFixtureExpectations(fixture)
    let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let recovered = try #require(
      JSONSerialization.jsonObject(with: selection.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recovered).isEqual(to: expected))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .appliedRecoveryComplete(let reopenedResult, let reopenedCheckpoint) =
        await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(reopenedData == exported)
    #expect(reopenedResult == importedResult)
    #expect(reopenedCheckpoint == checkpoint)
    guard
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .exported(let afterReplay) = await reopened.exportData(session: reopenedSession),
      case .rejected(let mismatch) = await reopened.execute(
        .init(
          operationId: operationIdentifier, session: reopenedSession,
          command: .applyImport(backup: backup, mode: .overwrite))
      ).outcome
    else { throw CancellationError() }
    #expect(replayed == importedResult)
    #expect(replayedCheckpoint == checkpoint)
    #expect(afterReplay == exported)
    #expect(mismatch.code == "operationPayloadMismatch")
  }
}
