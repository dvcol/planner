import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeImportResultTests {
  @Test func incompleteRecoveryRetainsSummaryUntilCheckpointRepair() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let fixture) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: fixture))
    else { throw CancellationError() }
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    guard
      case .applied(let applied, .incomplete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    #expect(applied.importSummary?.imports.count == 7)
    try obstruction.restore()
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .appliedRecoveryIncomplete(let incomplete, _) = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier),
      case .exported(let before) = await reopened.exportData(session: reopenedSession),
      case .applied(let repaired, .complete) = await reopened.retryRecovery(
        session: reopenedSession, operationId: operationIdentifier
      ).outcome,
      case .appliedRecoveryComplete(let complete, _) = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier),
      case .exported(let after) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(incomplete == applied && repaired == applied && complete == applied)
    #expect(before == after)
  }

  @Test(arguments: ["skip", "overwrite"])
  func mixedSummaryPreservesCategoriesAndOriginalResultAfterLaterEdits(modeName: String)
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
      case .decoded(let fixture) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let seed) = await planner.prepareReview(
        session: session, command: .applyImport(backup: fixture)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seed.command,
          reviewToken: seed.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var payload = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var sources = try #require(payload["sources"] as? [[String: Any]])
    let itemIndex = try #require(sources.firstIndex { $0["kind"] as? String == "item" })
    var content = try #require(sources[itemIndex]["content"] as? [String: Any])
    content["title"] = "Incoming museum"
    sources[itemIndex]["content"] = content
    var newTag = try #require(sources.first { $0["kind"] as? String == "tag" })
    let tagIdentifier = UUID()
    newTag["id"] = tagIdentifier.uuidString
    newTag["lifetimeId"] = tagIdentifier.uuidString
    sources.append(newTag)
    payload["sources"] = sources
    let mode = try #require(PlannerImportMode(rawValue: modeName))
    guard
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: payload)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: incoming, mode: mode))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    guard
      case .applied(let applied, .complete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let summary = try #require(applied.importSummary)
    #expect(summary.imports.map(\.owner.id) == [tagIdentifier])
    #expect(summary.unchanged.count == 6)
    #expect(summary.skippedDependents.isEmpty && summary.restorations.isEmpty)
    let changed: PlannerImportEntry
    if mode == .skip {
      changed = try #require(summary.skippedConflicts.first)
      #expect(summary.skippedConflicts.count == 1 && summary.replacements.isEmpty)
      #expect(changed.reasonCode == "matchingRecordConflict")
      #expect(changed.after?.title == "Nezu Museum")
    } else {
      changed = try #require(summary.replacements.first)
      #expect(summary.replacements.count == 1 && summary.skippedConflicts.isEmpty)
      #expect(changed.reasonCode == nil)
      #expect(changed.after?.title == "Incoming museum")
    }
    #expect(changed.before?.title == "Nezu Museum")
    #expect(changed.before?.changedFieldNames == ["title"])
    #expect(summary.referenceChanges.allSatisfy { $0.change == .retain })
    guard
      case .source(.item(let saved)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: changed.owner.id))),
      case .applied(let edited, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: saved.source.id,
            changes: .init(title: .set("Later native title")),
            expectedFieldHashes: [.title: try #require(saved.fieldHashes[.title])]))
      ).outcome,
      case .exported(let editedData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(edited.importSummary == nil)
    let ordinaryResult = try #require(
      JSONSerialization.jsonObject(
        with: JSONEncoder().encode(edited)) as? [String: Any])
    #expect(ordinaryResult["importSummary"] == nil)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .exported(let afterReplay) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(replayed == applied && afterReplay == editedData)
  }

  @Test func restorationSummaryReportsSavedLifetimesAndReboundDependencies() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let fixture) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let seed) = await planner.prepareReview(
        session: session, command: .applyImport(backup: fixture)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seed.command,
          reviewToken: seed.reviewToken)
      ).outcome,
      case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData)
    else { throw CancellationError() }
    let item = try #require(original.backup.items.first)
    let itemReference = PlannerEntityReference(kind: .item, id: item.id)
    guard
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: itemReference)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true)),
      case .applied(let applied, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .source(.item(let saved)) = await planner.read(
        session: session, request: .source(itemReference))
    else { throw CancellationError() }
    let summary = try #require(applied.importSummary)
    let restored = try #require(summary.restorations.first { $0.owner.id == item.id })
    #expect(restored.owner.lifetimeId == saved.sourceLifetimeId)
    #expect(restored.owner.lifetimeId != item.lifetimeId)
    #expect(restored.after?.identity == restored.owner)
    let referringLists = summary.replacements.filter { $0.owner.kind == .list }
    #expect(!referringLists.isEmpty)
    #expect(
      referringLists.allSatisfy { entry in
        entry.dependencies.contains { $0.id == item.id && $0.lifetimeId == saved.sourceLifetimeId }
      })
    #expect(
      try JSONDecoder().decode(
        PlannerAppliedResult.self,
        from: JSONEncoder().encode(applied)) == applied)
  }

  @Test func appliedSummarySurvivesReopenStatusReplayAndRecoveryRetry() async throws {
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
        session: session, command: .applyImport(backup: backup))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    guard
      case .applied(let applied, .complete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let encoded = try JSONEncoder().encode(applied)
    let result = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let summary = try #require(result["importSummary"] as? [String: Any])
    #expect(applied.importSummary == review.impact.importDetails)
    #expect(
      Set(summary.keys) == [
        "imports", "unchanged", "skippedConflicts", "skippedDependents", "replacements",
        "restorations", "incomingDeletions", "referenceChanges",
      ])
    let imports = try #require(summary["imports"] as? [[String: Any]])
    #expect(imports.count == 7)
    let museum = try #require(
      imports.first { entry in
        (entry["owner"] as? [String: Any])?["id"] as? String
          == "00000000-0000-4000-8000-000000000101"
      })
    #expect(museum["reasonCode"] is NSNull && museum["before"] is NSNull)
    #expect((museum["after"] as? [String: Any])?["title"] as? String == "Nezu Museum")
    #expect((summary["incomingDeletions"] as? [[String: Any]])?.count == 1)
    #expect(try JSONDecoder().decode(PlannerAppliedResult.self, from: encoded) == applied)
    guard case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .appliedRecoveryComplete(let statusResult, _) = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier),
      case .applied(let replayed, .complete) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .applied(let retried, .complete) = await reopened.retryRecovery(
        session: reopenedSession, operationId: operationIdentifier
      ).outcome,
      case .exported(let after) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(statusResult == applied && replayed == applied && retried == applied)
    #expect(before == after)
  }
}
