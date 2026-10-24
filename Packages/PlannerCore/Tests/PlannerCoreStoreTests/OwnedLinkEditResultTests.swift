import Foundation
import PlannerCore
import SwiftData
import Testing

struct OwnedLinkEditResultTests {
  @Test(arguments: [PlannerEntityKind.item, .itinerary])
  func newBookmarkIdentitiesSurviveIncompleteRecoveryWithoutReapplying(ownerKind: PlannerEntityKind)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = storageConfiguration(directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let creation: PlannerCommand
    let initialLinks = [
      PlannerLinkInput(originalUrl: "https://example.com/retained", label: "Keep")
    ]
    if ownerKind == .item {
      creation = .createItem(
        content: .init(title: "Keep", notes: "Unrelated notes", links: initialLinks))
    } else {
      creation = .createItinerary(
        content: .init(title: "Keep", notes: "Unrelated notes", links: initialLinks))
    }
    guard
      case .applied(let created, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: creation)
      ).outcome,
      let owner = created.generated.first
    else { throw CancellationError() }
    #expect(created.generatedIdentities == [.source(owner)])
    #expect(created.affectedIdentities == [.source(owner)])
    let original = try await read(owner, planner: planner, session: session)
    let originalLinks = try links(original)
    let retained = try #require(originalLinks.first)
    let replacement = [
      PlannerLinkInput(originalUrl: "https://example.com/duplicate", label: "First"),
      PlannerLinkInput(
        linkId: retained.linkId, originalUrl: retained.originalUrl, label: retained.label),
      PlannerLinkInput(originalUrl: "https://example.com/duplicate", label: "Second"),
    ]
    let command: PlannerCommand
    switch original {
    case .item(let item):
      command = .editItem(
        sourceId: owner.id, changes: .init(links: .set(replacement)),
        expectedFieldHashes: item.fieldHashes)
    case .itinerary(let itinerary):
      command = .editItinerary(
        sourceId: owner.id, changes: .init(links: .set(replacement)),
        expectedFieldHashes: itinerary.fieldHashes)
    default: throw CancellationError()
    }
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) {
      notification in obstruction.observe(notification)
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let outcome = await planner.execute(
      .init(operationId: operationIdentifier, session: session, command: command)
    ).outcome
    guard case .applied(let applied, .incomplete) = outcome else {
      Issue.record(
        "The edit must be locally committed before its real recovery failure: \(outcome)")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    let committed = try await read(owner, planner: planner, session: session)
    let committedLinks = try links(committed)
    let expected: [PlannerAppliedIdentity] = [
      .reference(.ownedLink(id: committedLinks[0].linkId, owner: owner)),
      .reference(.ownedLink(id: committedLinks[2].linkId, owner: owner)),
    ]
    #expect(applied.generatedIdentities == expected)
    #expect(applied.affectedIdentities == [.source(owner)] + expected)
    #expect(applied.generated.isEmpty && applied.affected == [owner])
    #expect(committedLinks[1].linkId == retained.linkId)
    #expect(Set(committedLinks.map(\.linkId)).count == 3)
    try obstruction.restore()
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .appliedRecoveryIncomplete(let observed, _) = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier),
      case .applied(let repaired, .complete(let checkpoint)) = await reopened.retryRecovery(
        session: reopenedSession, operationId: operationIdentifier
      ).outcome,
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .appliedRecoveryComplete(let acknowledged, let acknowledgedCheckpoint) =
        await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
    else {
      Issue.record(
        "Recovery must acknowledge the exact committed result rather than repeat the edit.")
      return
    }
    #expect(
      observed == applied && repaired == applied && replayed == applied && acknowledged == applied)
    #expect(checkpoint == 2 && replayedCheckpoint == 2 && acknowledgedCheckpoint == 2)
    let current = try await read(owner, planner: reopened, session: reopenedSession)
    #expect(try links(current) == committedLinks)
    switch (committed, current) {
    case (.item(let before), .item(let after)):
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
      #expect(after.content.notes == "Unrelated notes")
    case (.itinerary(let before), .itinerary(let after)):
      #expect(after.fieldHashes == before.fieldHashes && after.updatedAt == before.updatedAt)
      #expect(after.content.notes == "Unrelated notes")
    default: Issue.record("Recovery must retain the owner kind.")
    }
  }

  @Test func genuinePreChangeEditReceiptsReplayAndRepairWithoutBackfillingBookmarkResults()
    async throws
  {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: OwnedLinkFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(
        forResource: "LegacyOwnedLinkResults", withExtension: nil, subdirectory: "Fixtures"))
    let directory = try makePlannerStoreFixtureDirectory()
    try FileManager.default.copyItem(at: fixture, to: directory)
    let records = try JSONDecoder().decode(
      [LegacyLinkEdit].self,
      from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    #expect(records.count == 2)
    let planner = Planner(configuration: storageConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    for record in records {
      let before = try await read(record.owner, planner: planner, session: session)
      #expect(try links(before).map(\.linkId) == record.linkIds)
      #expect(record.result.generatedIdentities.isEmpty)
      #expect(record.result.affectedIdentities == [.source(record.owner)])
      let status = await planner.operationStatus(session: session, operationId: record.operationId)
      if record.incomplete {
        guard case .appliedRecoveryIncomplete(let result, _) = status,
          case .applied(let repaired, .complete(let checkpoint)) = await planner.retryRecovery(
            session: session, operationId: record.operationId
          ).outcome
        else {
          Issue.record(
            "A genuine pre-change incomplete edit must be repairable without new result metadata.")
          return
        }
        #expect(result == record.result && repaired == record.result)
        #expect(checkpoint == record.checkpoint)
      } else {
        guard case .appliedRecoveryComplete(let result, let checkpoint) = status else {
          Issue.record("An acknowledged pre-change edit must retain its complete receipt.")
          return
        }
        #expect(result == record.result && checkpoint == record.checkpoint)
      }
      let replacement = [
        PlannerLinkInput(originalUrl: "https://example.com/duplicate", label: "First"),
        PlannerLinkInput(originalUrl: "https://example.com/duplicate", label: "Second"),
      ]
      let hash = PlannerFieldHash(value: record.linksHash)
      let command: PlannerCommand
      if record.owner.kind == .item {
        command = .editItem(
          sourceId: record.owner.id, changes: .init(links: .set(replacement)),
          expectedFieldHashes: [.links: hash])
      } else {
        command = .editItinerary(
          sourceId: record.owner.id, changes: .init(links: .set(replacement)),
          expectedFieldHashes: [.links: hash])
      }
      guard
        case .applied(let replayed, .complete(let checkpoint)) = await planner.execute(
          .init(operationId: record.operationId, session: session, command: command)
        ).outcome,
        case .appliedRecoveryComplete(let acknowledged, let acknowledgedCheckpoint) =
          await planner.operationStatus(
            session: session, operationId: record.operationId)
      else {
        Issue.record("Replay and operation status must preserve stored historical results exactly.")
        return
      }
      #expect(replayed == record.result && acknowledged == record.result)
      #expect(checkpoint == record.checkpoint && acknowledgedCheckpoint == record.checkpoint)
      let after = try await read(record.owner, planner: planner, session: session)
      #expect(try links(after) == links(before))
    }
    let reopened = Planner(configuration: storageConfiguration(directory))
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .status(let status) = await reopened.read(session: reopenedSession, request: .status),
      case .known(_, let incompleteOperations, _, let mutationBlocked) = status.recovery
    else { throw CancellationError() }
    #expect(incompleteOperations.isEmpty && !mutationBlocked)
  }

  private func storageConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
    .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  private func read(
    _ owner: PlannerEntityReference, planner: Planner, session: PlannerDatasetSession
  ) async throws -> PlannerSourceRead {
    guard case .source(let source) = await planner.read(session: session, request: .source(owner))
    else { throw CancellationError() }
    return source
  }

  private func links(_ source: PlannerSourceRead) throws -> [PlannerOwnedLinkRead] {
    switch source {
    case .item(let item): return item.content.links
    case .itinerary(let itinerary): return itinerary.content.links
    default: throw CancellationError()
    }
  }

  #if !SWIFT_PACKAGE
    private final class OwnedLinkFixtureBundle: NSObject {}
  #endif
}

private struct LegacyLinkEdit: Codable {
  let owner: PlannerEntityReference
  let operationId: UUID
  let linksHash: String
  let result: PlannerAppliedResult
  let checkpoint: Int64
  let incomplete: Bool
  let linkIds: [UUID]
}
