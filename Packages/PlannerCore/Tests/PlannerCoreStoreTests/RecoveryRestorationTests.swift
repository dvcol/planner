import Foundation
import PlannerCore
import SwiftData
import Testing

struct RecoveryRestorationTests {
  @Test(arguments: [PlannerImportMode.skip, .overwrite])
  func deletedIdentityStaysDeletedUnlessRecoveryOverwriteExplicitlyRestoresIt(
    _ mode: PlannerImportMode
  )
    async throws
  {
    let directory = fixtureDirectory()
    let selection = try await singleItemSelection(directory: directory)
    let item = try #require(selection.decodedBackup.backup.items.first)
    let target = Planner(configuration: configuration(directory: directory, name: "target"))
    guard case .ready(let session) = await target.bootstrap(),
      case .reviewed(let initialReview) = await target.prepareReview(
        session: session, command: .restoreRecovery(selection: selection)),
      case .applied(_, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: session, command: initialReview.command,
          reviewToken: initialReview.reviewToken)
      ).outcome,
      case .reviewed(let deleteReview) = await target.prepareReview(
        session: session, command: .deleteSource(source: .init(kind: .item, id: item.id))),
      case .applied(_, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: session, command: deleteReview.command,
          reviewToken: deleteReview.reviewToken)
      ).outcome,
      case .exported(let deletedData) = await target.exportData(session: session),
      case .reviewed(let restoreReview) = await target.prepareReview(
        session: session, command: .restoreRecovery(selection: selection, mode: mode)),
      case .exported(let afterReview) = await target.exportData(session: session)
    else { throw CancellationError() }
    #expect(afterReview == deletedData)
    #expect(restoreReview.impact.importDetails?.restorations.count == (mode == .overwrite ? 1 : 0))
    #expect(restoreReview.impact.importDetails?.skippedConflicts.count == (mode == .skip ? 1 : 0))
    guard
      case .applied(_, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: session, command: restoreReview.command,
          reviewToken: restoreReview.reviewToken)
      ).outcome,
      case .exported(let restoredData) = await target.exportData(session: session),
      case .decoded(let restored) = target.decodeImport(restoredData)
    else { throw CancellationError() }
    if mode == .skip {
      #expect(restoredData == deletedData)
      #expect(restored.backup.items.isEmpty)
    } else {
      let restoredItem = try #require(restored.backup.items.first)
      #expect(restoredItem.id == item.id)
      #expect(restoredItem.lifetimeId != item.lifetimeId)
      #expect(restoredItem.content.notes == "Original notes")
      #expect(restored.backup.restorationFamilies.count == 1)
    }
  }

  @Test func unverifiedProposalRequiresFreshOperationAndDoesNotAcknowledgeSource() async throws {
    let directory = fixtureDirectory()
    let sourceConfiguration = configuration(directory: directory, name: "source")
    let selection = try await singleItemSelection(directory: directory)
    let source = Planner(configuration: sourceConfiguration)
    let item = try #require(selection.decodedBackup.backup.items.first)
    guard case .ready(let sourceSession) = await source.bootstrap(),
      case .source(.item(let original)) = await source.read(
        session: sourceSession, request: .source(.init(kind: .item, id: item.id)))
    else { throw CancellationError() }
    let obstruction = NativeSaveRecoveryObstruction(configuration: sourceConfiguration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let uncertainOperationIdentifier = UUID()
    guard
      case .applied(_, .incomplete) = await source.execute(
        .init(
          operationId: uncertainOperationIdentifier, session: sourceSession,
          command: .editItem(
            sourceId: item.id, changes: .init(notes: .set("Monday booking")),
            expectedFieldHashes: [.notes: try #require(original.fieldHashes[.notes])]))
      ).outcome
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    guard
      case .listed(let namespace) = await source.inspectRecovery(
        request: .namespace(namespaceId: selection.namespaceId)),
      let proposal = namespace.preparedProposals.first,
      case .selected(let proposedSelection) = await source.inspectRecovery(
        request: .proposal(namespaceId: namespace.namespaceId, proposalId: proposal.proposalId))
    else { throw CancellationError() }
    #expect(proposedSelection.evidence == .preparedUnverified)
    #expect(proposedSelection.originalOperationId == uncertainOperationIdentifier)
    let target = Planner(configuration: configuration(directory: directory, name: "target"))
    guard case .ready(let session) = await target.bootstrap(),
      case .exported(let emptyData) = await target.exportData(session: session),
      case .reviewed(let review) = await target.prepareReview(
        session: session, command: .restoreRecovery(selection: proposedSelection)),
      case .rejected(let reuseFailure) = await target.execute(
        .init(
          operationId: uncertainOperationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let afterRejection) = await target.exportData(session: session)
    else { throw CancellationError() }
    #expect(reuseFailure.code == "invalidInput" && reuseFailure.propertyPath == "/operationId")
    #expect(afterRejection == emptyData)
    guard
      case .applied(_, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .source(.item(let restored)) = await target.read(
        session: session, request: .source(.init(kind: .item, id: item.id))),
      case .noReliableEvidence = await target.operationStatus(
        session: session, operationId: uncertainOperationIdentifier),
      case .appliedRecoveryIncomplete = await source.operationStatus(
        session: sourceSession, operationId: uncertainOperationIdentifier),
      case .listed(let unchangedNamespace) = await source.inspectRecovery(
        request: .namespace(namespaceId: selection.namespaceId))
    else { throw CancellationError() }
    #expect(restored.source.id == item.id && restored.content.notes == "Monday booking")
    #expect(unchangedNamespace.acknowledgedSnapshot?.checkpointGeneration == 1)
    #expect(unchangedNamespace.preparedProposals.map(\.proposalId) == [proposal.proposalId])
  }

  @Test(arguments: ["mode", "selection", "target", "current", "fileCommand"])
  func changedRecoveryReviewCannotApplyToDifferentData(_ scenario: String) async throws {
    let directory = fixtureDirectory()
    let selection = try await singleItemSelection(directory: directory)
    var target = Planner(configuration: configuration(directory: directory, name: "target"))
    guard case .ready(let originalSession) = await target.bootstrap() else {
      throw CancellationError()
    }
    var session = originalSession
    var command = PlannerCommand.restoreRecovery(selection: selection)
    guard
      case .reviewed(let review) = await target.prepareReview(session: session, command: command)
    else { throw CancellationError() }
    switch scenario {
    case "mode": command = .restoreRecovery(selection: selection, mode: .overwrite)
    case "selection":
      command = .restoreRecovery(
        selection: try await selectionWithAdditionalTag(directory: directory, selection: selection))
    case "target":
      target = Planner(configuration: configuration(directory: directory, name: "other-target"))
      guard case .ready(let otherSession) = await target.bootstrap() else {
        throw CancellationError()
      }
      session = otherSession
    case "current":
      guard
        case .applied(_, .complete) = await target.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createTag(content: .init(name: "New current label")))
        ).outcome
      else { throw CancellationError() }
    case "fileCommand": command = .applyImport(backup: selection.decodedBackup)
    default: throw CancellationError()
    }
    guard case .exported(let before) = await target.exportData(session: session) else {
      throw CancellationError()
    }
    let operationIdentifier = UUID()
    let response = await target.execute(
      .init(
        operationId: operationIdentifier, session: session, command: command,
        reviewToken: review.reviewToken))
    guard case .rejected(let failure) = response.outcome,
      case .exported(let after) = await target.exportData(session: session),
      case .noReliableEvidence = await target.operationStatus(
        session: session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(failure.code == "staleReview")
    #expect(after == before)
  }

  @Test(arguments: ["mode", "selection", "fileCommand", "reselected"])
  func recoveryReceiptBindsRetainedEvidenceAndAllowsEquivalentReselection(_ scenario: String)
    async throws
  {
    let directory = fixtureDirectory()
    let selection = try await singleItemSelection(directory: directory)
    let target = Planner(configuration: configuration(directory: directory, name: "target"))
    guard case .ready(let session) = await target.bootstrap(),
      case .reviewed(let review) = await target.prepareReview(
        session: session, command: .restoreRecovery(selection: selection))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    guard
      case .applied(let original, .complete(let checkpoint)) = await target.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let before) = await target.exportData(session: session)
    else { throw CancellationError() }
    let command: PlannerCommand
    switch scenario {
    case "mode": command = .restoreRecovery(selection: selection, mode: .overwrite)
    case "selection":
      command = .restoreRecovery(
        selection: try await selectionWithAdditionalTag(directory: directory, selection: selection))
    case "fileCommand": command = .applyImport(backup: selection.decodedBackup)
    case "reselected":
      guard
        case .selected(let reselected) = await target.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: selection.namespaceId,
            checkpointGeneration: try #require(selection.checkpointGeneration)))
      else { throw CancellationError() }
      #expect(reselected.selectionId != selection.selectionId)
      command = .restoreRecovery(selection: reselected)
    default: throw CancellationError()
    }
    let response = await target.execute(
      .init(operationId: operationIdentifier, session: session, command: command))
    if scenario == "reselected" {
      guard case .applied(let replayed, .complete(let replayedCheckpoint)) = response.outcome else {
        Issue.record("Equivalent retained evidence must replay without applying again: \(response)")
        return
      }
      #expect(replayed == original)
      #expect(replayedCheckpoint == checkpoint)
    } else {
      guard case .rejected(let failure) = response.outcome else { throw CancellationError() }
      #expect(failure.code == "operationPayloadMismatch")
    }
    guard case .exported(let after) = await target.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(after == before)
  }

  @Test(arguments: [PlannerImportMode.skip, .overwrite])
  func recoveryMergePreservesIndependentDataAndUsesReviewedConflictMode(_ mode: PlannerImportMode)
    async throws
  {
    let directory = fixtureDirectory()
    let selection = try await singleItemSelection(directory: directory)
    let target = Planner(configuration: configuration(directory: directory, name: "target"))
    guard case .ready(let targetSession) = await target.bootstrap(),
      case .reviewed(let initialReview) = await target.prepareReview(
        session: targetSession, command: .restoreRecovery(selection: selection)),
      case .applied(_, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: targetSession, command: initialReview.command,
          reviewToken: initialReview.reviewToken)
      ).outcome,
      let item = selection.decodedBackup.backup.items.first,
      case .source(.item(let original)) = await target.read(
        session: targetSession, request: .source(.init(kind: .item, id: item.id))),
      case .applied(_, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: targetSession,
          command: .editItem(
            sourceId: item.id, changes: .init(notes: .set("Current notes")),
            expectedFieldHashes: [.notes: try #require(original.fieldHashes[.notes])]))
      ).outcome,
      case .applied(let independentTag, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: targetSession,
          command: .createTag(content: .init(name: "Current label")))
      ).outcome,
      let currentTag = independentTag.generated.first
    else { throw CancellationError() }
    let updatedSelection = try await selectionWithAdditionalTag(
      directory: directory, selection: selection)
    guard
      case .reviewed(let review) = await target.prepareReview(
        session: targetSession, command: .restoreRecovery(selection: updatedSelection, mode: mode)
      )
    else { throw CancellationError() }
    #expect(review.impact.importDetails?.imports.count == 1)
    #expect(review.impact.importDetails?.skippedConflicts.count == (mode == .skip ? 1 : 0))
    #expect(review.impact.importDetails?.replacements.count == (mode == .overwrite ? 1 : 0))
    guard
      case .applied(_, .complete) = await target.execute(
        .init(
          operationId: UUID(), session: targetSession, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .source(.item(let merged)) = await target.read(
        session: targetSession, request: .source(.init(kind: .item, id: item.id))),
      case .source(.tag(let retainedCurrentTag)) = await target.read(
        session: targetSession, request: .source(currentTag)),
      case .exported(let data) = await target.exportData(session: targetSession),
      case .decoded(let restored) = target.decodeImport(data)
    else { throw CancellationError() }
    #expect(merged.source.id == item.id)
    #expect(merged.content.notes == (mode == .skip ? "Current notes" : "Original notes"))
    #expect(retainedCurrentTag.content.name == "Current label")
    #expect(restored.backup.sources.count == 3)
    #expect(
      restored.backup.sources.contains {
        guard case .tag(let tag) = $0 else { return false }
        return tag.content.name == "Retained label"
      })
  }

  @Test func reviewedSnapshotRestoresCompleteGraphIntoSeparateEmptyDatasetAndReplaysAfterReopen()
    async throws
  {
    let directory = fixtureDirectory()
    let source = Planner(configuration: configuration(directory: directory, name: "source"))
    guard case .ready(let sourceSession) = await source.bootstrap(),
      case .decoded(let backup) = source.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let importReview) = await source.prepareReview(
        session: sourceSession, command: .applyImport(backup: backup)),
      case .applied(_, .complete(let sourceCheckpoint)) = await source.execute(
        .init(
          operationId: UUID(), session: sourceSession, command: importReview.command,
          reviewToken: importReview.reviewToken)
      ).outcome,
      case .exported(let sourceData) = await source.exportData(session: sourceSession),
      case .listedNamespaces(let namespaces) = await source.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await source.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: sourceCheckpoint))
    else { throw CancellationError() }

    let targetConfiguration = configuration(directory: directory, name: "target")
    let target = Planner(configuration: targetConfiguration)
    guard case .ready(let targetSession) = await target.bootstrap(),
      case .exported(let emptyData) = await target.exportData(session: targetSession)
    else { throw CancellationError() }
    #expect(targetSession.datasetId != selection.datasetId)
    let command = PlannerCommand.restoreRecovery(selection: selection)
    let reviewResponse = await target.prepareReview(session: targetSession, command: command)
    guard case .reviewed(let review) = reviewResponse else {
      Issue.record(
        "The approved recovery command must provide its exact import review: \(reviewResponse)")
      return
    }
    #expect(review.impact.kind == .importData)
    #expect(review.impact.importDetails?.imports.isEmpty == false)
    guard case .exported(let afterReview) = await target.exportData(session: targetSession) else {
      throw CancellationError()
    }
    #expect(afterReview == emptyData)
    let operationIdentifier = UUID()
    guard
      case .rejected(let missingReview) = await target.execute(
        .init(operationId: operationIdentifier, session: targetSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(missingReview.code == "staleReview")
    let response = await target.execute(
      .init(
        operationId: operationIdentifier, session: targetSession, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let targetCheckpoint)) = response.outcome else {
      Issue.record("Reviewed restoration must commit the complete selected graph: \(response)")
      return
    }
    #expect(result.importSummary?.imports.isEmpty == false)
    guard case .exported(let restoredData) = await target.exportData(session: targetSession),
      case .exported(let unchangedSourceData) = await source.exportData(session: sourceSession)
    else { throw CancellationError() }
    #expect(restoredData == sourceData)
    #expect(unchangedSourceData == sourceData)
    let reopened = Planner(configuration: targetConfiguration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(reopenedData == sourceData)
    #expect(replayed.importSummary == result.importSummary)
    #expect(replayedCheckpoint == targetCheckpoint)
  }

  private func configuration(directory: URL, name: String) -> PlannerStorageConfiguration {
    let datasetDirectory = directory.appendingPathComponent(name, isDirectory: true)
    return .init(
      storeURL: datasetDirectory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: datasetDirectory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  private func fixtureDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "PlannerRecoveryRestoration", isDirectory: true
    )
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  }

  private func singleItemSelection(directory: URL) async throws -> PlannerRecoverySelection {
    let source = Planner(configuration: configuration(directory: directory, name: "source"))
    guard case .ready(let session) = await source.bootstrap(),
      case .applied(_, .complete(let checkpoint)) = await source.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      case .listedNamespaces(let namespaces) = await source.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await source.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return selection
  }

  private func selectionWithAdditionalTag(directory: URL, selection: PlannerRecoverySelection)
    async throws -> PlannerRecoverySelection
  {
    let source = Planner(configuration: configuration(directory: directory, name: "source"))
    guard case .ready(let session) = await source.bootstrap(),
      case .applied(_, .complete(let checkpoint)) = await source.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createTag(content: .init(name: "Retained label")))
      ).outcome,
      case .selected(let updated) = await source.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: selection.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return updated
  }
}
