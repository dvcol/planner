import Foundation
import PlannerCore
import SwiftData
import Testing

struct ItemInListCreationRecoveryTests {
  @Test func committedCreationRetainsItsWholeGraphAndRepairsRecoveryWithoutReapplying() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "PlannerQ93Store-" + UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listCreation.generated.first
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
    let command = PlannerCommand.createItem(
      content: .init(
        title: "Museum", notes: "Retain locally committed content",
        links: [
          .init(originalUrl: "https://example.com/museum", label: "Tickets"),
          .init(originalUrl: "https://example.com/museum", label: "Exhibitions"),
        ]), listId: list.id)
    let response = await planner.execute(
      .init(operationId: operationIdentifier, session: session, command: command))
    guard case .applied(let applied, .incomplete) = response.outcome,
      let item = applied.generated.first,
      case .membership(let membershipIdentifier, _, _)? = applied.generatedReferences.first
    else {
      Issue.record(
        "A post-save recovery failure must retain the complete applied creation: \(response.outcome)"
      )
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .appearance(let appearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier))),
      case .rejected(let blocked) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .createItem(content: .init(title: "Must stay blocked"), listId: list.id))
      ).outcome
    else { throw CancellationError() }
    #expect(retained.content.notes == "Retain locally committed content")
    #expect(retained.content.links.map(\.label) == ["Tickets", "Exhibitions"])
    #expect(!appearance.localDone && !appearance.globalDone)
    #expect(blocked.code == "mutationBlocked")
    let repair = await reopened.retryRecovery(
      session: reopenedSession, operationId: operationIdentifier)
    guard case .applied(let repaired, .complete(let checkpoint)) = repair.outcome,
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .source(.list(let populated)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all)))),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "Checkpoint-only repair must acknowledge the original complete graph: \(repair.outcome)")
      return
    }
    #expect(repaired == applied && replayed == applied)
    #expect(checkpoint == 2 && replayedCheckpoint == checkpoint)
    #expect(items.matchingCount == 1 && populated.references.count == 1)
    #expect(populated.progress.totalCount == 1 && populated.progress.doneCount == 0)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(recovery.decodedBackup.backup.items.count == 1)
    #expect(recovery.decodedBackup.backup.memberships.count == 1)
    let portable = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    #expect((portable["ownedLinks"] as? [[String: Any]])?.count == 2)
  }
}
