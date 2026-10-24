import CryptoKit
import Foundation
import SwiftData
import Testing

@testable import PlannerCore

#if os(macOS)
  import Darwin
#endif

struct NativeMembershipConsolidationTests {
  @Test func aSoleUnawareOfflineMembershipStaysRemovedWithoutDiscardingItsItem() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum", notes: "Keep this Item")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let listResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listResult.generated.first,
      case .applied(let addition, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipIdentifier, _, _) = addition.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: membershipIdentifier))
      ).outcome
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [
        ("00000000-0000-4000-8000-000000000403", "00000000-0000-4000-8000-000000000843", 1024, true)
      ])
    let contentsResult = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .all, archive: .all))))
    guard case .snapshot(let contents) = contentsResult,
      case .snapshot(let inbox) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .inbox, completion: .all, archive: .all)))),
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .exported(let beforeRepeat) = await planner.exportData(session: session),
      case .listedNamespaces(let originalNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("A strict Remove must suppress even a sole unseen Add: \(contentsResult)")
      return
    }
    #expect(contents.matchingCount == 0)
    #expect(inbox.matchingCount == 1)
    #expect(retained.content.notes == "Keep this Item" && retained.state.globalDone == false)
    guard
      case .snapshot(let repeated) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(list.id), completion: .all, archive: .all)))),
      case .exported(let afterRepeat) = await planner.exportData(session: session),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else { throw CancellationError() }
    #expect(repeated.matchingCount == 0 && afterRepeat == beforeRepeat)
    #expect(
      afterNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration
        == originalNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration)
  }

  @Test func ordinaryReaddDoesNotInheritAClosedCanonicalGroupsCompletion() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let listResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listResult.generated.first
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
    guard
      case .snapshot(let completed) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(list.id), completion: .done, archive: .all)))),
      case .appearance(_, .listMembership(_, let canonicalIdentifier))? = completed.rows.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: canonicalIdentifier))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [
        (
          "00000000-0000-4000-8000-000000000403", "00000000-0000-4000-8000-000000000843", 3072,
          false
        )
      ])
    let todoResult = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .todo, archive: .all))))
    let doneResult = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .done, archive: .all))))
    let exportResult = await planner.exportData(session: session)
    guard case .snapshot(let todo) = todoResult, case .snapshot(let done) = doneResult,
      case .exported(let data) = exportResult
    else {
      Issue.record(
        "Late membership reads must retain the informed re-add: \(todoResult), \(doneResult), \(exportResult)"
      )
      return
    }
    #expect(todo.matchingCount == 1)
    #expect(done.matchingCount == 0)
    let graph = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let members = try #require(graph["memberships"] as? [[String: Any]])
    #expect(members.count == 1 && members.first?["localDone"] as? Bool == false)
    let aliases = try #require(graph["contextAliases"] as? [[String: Any]])
    let originalIdentifiers = [
      "00000000-0000-4000-8000-000000000401", "00000000-0000-4000-8000-000000000402",
    ]
    let oldHistory = aliases.filter { value in
      guard let context = value["context"] as? [String: Any],
        let identifier = context["membershipId"] as? String
      else { return false }
      return originalIdentifiers.contains(identifier)
    }
    #expect(oldHistory.count == 2)
    #expect(
      oldHistory.allSatisfy {
        ($0["canonicalContext"] as? [String: Any])?["membershipId"] as? String
          == "00000000-0000-4000-8000-000000000401"
      })
    #expect((graph["completionChanges"] as? [Any])?.isEmpty == true)
  }

  @Test func committedMaintenanceBlocksNewCommandsUntilItsOwnRecoveryRetryCompletes() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdItem, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(let createdList, .complete(let initialCheckpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = createdList.generated.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let originalFiles = try maintenanceNamespaceFiles(namespaceDirectory)
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) {
      notification in obstruction.observe(notification)
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
    }
    let waitingOperationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: waitingOperationIdentifier, session: session,
        command: .createTag(content: .init(name: "Must wait"))))
    guard case .rejected = response.outcome else {
      Issue.record(
        "The waiting command must remain unapplied after maintenance recovery fails: \(response)")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    guard
      case .snapshot(let readable) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(list.id), completion: .done, archive: .all)))),
      case .exported(let committedData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(readable.matchingCount == 1)
    try obstruction.restore()
    let preparationFiles = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasPrefix("maintenance-") }
    #expect(preparationFiles.count == 1)
    let preparationFile = try #require(preparationFiles.first)
    let preparation = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: preparationFile)) as? [String: Any])
    let maintenanceIdentifier = try #require(
      (preparation["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: waitingOperationIdentifier),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: maintenanceIdentifier),
      case .listed(let pendingView) = await planner.inspectRecovery(
        request: .namespace(namespaceId: namespace.namespaceId))
    else { throw CancellationError() }
    #expect(pendingView.acknowledgedSnapshot?.checkpointGeneration == initialCheckpoint)
    let status = await planner.read(session: session, request: .status)
    guard case .status(let pendingStatus) = status,
      case .known(
        let pendingCheckpoint, let incompleteOperations, let incompleteMaintenance,
        let mutationBlocked) =
        pendingStatus.recovery
    else {
      Issue.record(
        "Verified committed maintenance must have a known, blocked recovery status: \(status)")
      return
    }
    #expect(
      pendingCheckpoint == initialCheckpoint && incompleteOperations.isEmpty && mutationBlocked)
    #expect(incompleteMaintenance == [maintenanceIdentifier])
    let blocked = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .createTag(content: .init(name: "Still waiting"))))
    guard case .rejected(let blockedReason) = blocked.outcome else {
      Issue.record("Pending maintenance must block a new ordinary command: \(blocked)")
      return
    }
    #expect(blockedReason.code == "mutationBlocked")
    let beforeRetry = try maintenanceNamespaceFiles(namespaceDirectory)
    for (name, bytes) in originalFiles { #expect(beforeRetry[name] == bytes) }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: namespaceDirectory.path)
    let continued = await planner.retryMaintenanceRecovery(
      session: session, maintenanceId: maintenanceIdentifier)
    guard case .incomplete(let reason) = continued else {
      Issue.record(
        "A verified native commit must remain incomplete when publication still fails: \(continued)"
      )
      return
    }
    #expect(!reason.message.isEmpty)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeRetry)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
    guard
      case .complete(let checkpoint) = await planner.retryMaintenanceRecovery(
        session: session, maintenanceId: maintenanceIdentifier),
      case .exported(let recoveredData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(checkpoint == initialCheckpoint + 1)
    #expect(recoveredData == committedData)
    let acknowledgedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
    guard
      case .complete(let repeatedCheckpoint) = await planner.retryMaintenanceRecovery(
        session: session, maintenanceId: maintenanceIdentifier)
    else { throw CancellationError() }
    #expect(repeatedCheckpoint == checkpoint)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == acknowledgedFiles)
    let saved = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .createTag(content: .init(name: "After recovery"))))
    guard case .applied(_, .complete(let nextCheckpoint)) = saved.outcome,
      case .exported(let finalData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(nextCheckpoint == checkpoint + 1)
    let finalGraph = try #require(JSONSerialization.jsonObject(with: finalData) as? [String: Any])
    let finalSources = try #require(finalGraph["sources"] as? [[String: Any]])
    let tags = finalSources.filter { $0["kind"] as? String == "tag" }
    #expect(tags.count == 1)
    #expect((tags.first?["content"] as? [String: Any])?["name"] as? String == "After recovery")
  }

  @Test func independentNativeMembershipsReadAsOneDoneContextWithoutCompletingTheirItem()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let itemOperationIdentifier = UUID()
    let listOperationIdentifier = UUID()
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdItem, .complete(let itemCheckpoint)) = await planner.execute(
        .init(
          operationId: itemOperationIdentifier, session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(let createdList, .complete(let listCheckpoint)) = await planner.execute(
        .init(
          operationId: listOperationIdentifier, session: session,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let list = createdList.generated.first,
      case .exported(let originalData) = await planner.exportData(session: session)
    else { throw CancellationError() }

    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)

    guard
      case .listedNamespaces(let beforeNamespaces) = await planner.inspectRecovery(
        request: .namespaces), let beforeNamespace = beforeNamespaces.first
    else { throw CancellationError() }
    let beforeDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      beforeNamespace.namespaceId.uuidString)
    let beforeStatusFiles = try maintenanceNamespaceFiles(beforeDirectory)
    let requiredStatus = await planner.read(session: session, request: .status)
    if case .status(let status) = requiredStatus, case .unavailable(let reason) = status.recovery {
      #expect(reason.code == "maintenanceRequired")
    } else {
      Issue.record(
        "Uncommitted consolidation must be reported without normalizing: \(requiredStatus)")
    }
    #expect(try maintenanceNamespaceFiles(beforeDirectory) == beforeStatusFiles)

    let reopened = Planner(configuration: configuration)
    let bootstrap = await reopened.bootstrap()
    guard case .ready(let reopenedSession) = bootstrap else {
      Issue.record("Native relationship delivery must retain a readable dataset: \(bootstrap)")
      return
    }
    let result = await reopened.query(
      .init(
        session: reopenedSession,
        request: .items(.init(scope: .list(list.id), completion: .done, archive: .all))))
    guard case .snapshot(let snapshot) = result else {
      Issue.record("Independent Todo/Done memberships must resolve to one Done context: \(result)")
      return
    }
    #expect(snapshot.matchingCount == 1)
    #expect(
      snapshot.rows == [
        .appearance(
          source: item,
          appearance: .listMembership(
            listId: list.id,
            membershipId: UUID(uuidString: "00000000-0000-4000-8000-000000000401")!))
      ])
    guard
      case .source(.item(let read)) = await reopened.read(
        session: reopenedSession, request: .source(item))
    else { throw CancellationError() }
    #expect(read.state.globalDone == false)
    guard case .exported(let data) = await reopened.exportData(session: reopenedSession),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(checkpoint == listCheckpoint + 1)
    let actual = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var expected = try #require(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let sources = try #require(expected["sources"] as? [[String: Any]])
    let originalItem = try #require(sources.first { $0["id"] as? String == item.id.uuidString })
    let originalList = try #require(sources.first { $0["id"] as? String == list.id.uuidString })
    let itemBinding: [String: Any] = [
      "kind": "item", "id": item.id.uuidString,
      "lifetimeId": try #require(originalItem["lifetimeId"]),
    ]
    let listBinding: [String: Any] = [
      "kind": "list", "id": list.id.uuidString,
      "lifetimeId": try #require(originalList["lifetimeId"]),
    ]
    let canonical: [String: Any] = [
      "kind": "listMembership", "membershipId": "00000000-0000-4000-8000-000000000401",
      "membershipLifetimeId": "00000000-0000-4000-8000-000000000841",
    ]
    expected["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000401",
        "lifetimeId": "00000000-0000-4000-8000-000000000841",
        "list": listBinding, "item": itemBinding, "rank": "1024", "localDone": true,
      ]
    ]
    let seeds = try initialCompletionSeedFixtures()
    expected["contextAliases"] = try seeds.map { seed -> [String: Any] in
      [
        "aliasId": try #require(seed["aliasId"]), "context": try #require(seed["context"]),
        "canonicalContext": canonical, "initialDone": try #require(seed["initialDone"]),
        "currentChangeId": NSNull(),
      ]
    }.sorted { ($0["aliasId"] as? String ?? "") < ($1["aliasId"] as? String ?? "") }
    expected["membershipProvenance"] = [
      [
        "membershipId": "00000000-0000-4000-8000-000000000401",
        "membershipLifetimeId": "00000000-0000-4000-8000-000000000841",
        "list": listBinding, "item": itemBinding, "observedRemovalIds": [],
      ],
      [
        "membershipId": "00000000-0000-4000-8000-000000000402",
        "membershipLifetimeId": "00000000-0000-4000-8000-000000000842",
        "list": listBinding, "item": itemBinding, "observedRemovalIds": [],
      ],
    ]
    #expect(NSDictionary(dictionary: expected).isEqual(to: actual))
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: recoveredGraph))
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let envelope = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(checkpoint).json")))
        as? [String: Any])
    #expect(envelope["formatVersion"] as? Int == 2)
    let maintenanceReceipts = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(maintenanceReceipts.count == 1)
    let maintenance = try #require(maintenanceReceipts.first)
    let maintenanceIdentifier = try #require(
      (maintenance["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
    #expect(
      maintenanceIdentifier != itemOperationIdentifier
        && maintenanceIdentifier != listOperationIdentifier)
    #expect(maintenance["checkpointGeneration"] as? String == String(checkpoint))
    let commandReceipts = try #require(envelope["receipts"] as? [[String: Any]])
    #expect(
      Set(commandReceipts.compactMap { $0["operationId"] as? String }) == [
        itemOperationIdentifier.uuidString, listOperationIdentifier.uuidString,
      ])
    let preparationData = try Data(
      contentsOf: namespaceDirectory.appendingPathComponent(
        "maintenance-\(maintenanceIdentifier.uuidString).json"))
    let preparation = try #require(
      JSONSerialization.jsonObject(with: preparationData) as? [String: Any])
    #expect(
      Set(preparation.keys) == [
        "format", "formatVersion", "maintenanceId", "namespaceId", "datasetId", "epochId",
        "ownershipBinding", "kind", "ruleVersion", "proposedBackup", "evidence",
      ])
    #expect(preparation["format"] as? String == "planner-maintenance-preparation")
    #expect(preparation["evidence"] as? String == "preparedUnverified")
    let preparedGraph = try #require(preparation["proposedBackup"] as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: preparedGraph))
    let digest =
      "sha256:" + SHA256.hash(data: preparationData).map { String(format: "%02x", $0) }.joined()
    #expect(maintenance["preparationDigest"] as? String == digest)
    let beforeNoOp = try maintenanceNamespaceFiles(namespaceDirectory)
    guard
      case .noReliableEvidence = await reopened.operationStatus(
        session: reopenedSession, operationId: maintenanceIdentifier),
      case .complete(let maintenanceCheckpoint) = await reopened.retryMaintenanceRecovery(
        session: reopenedSession, maintenanceId: maintenanceIdentifier),
      case .applied(let replayedItem, .complete(let replayedItemCheckpoint)) =
        await reopened.execute(
          .init(
            operationId: itemOperationIdentifier, session: reopenedSession,
            command: .createItem(content: .init(title: "Hotel")))
        ).outcome,
      case .applied(let replayedList, .complete(let replayedListCheckpoint)) =
        await reopened.execute(
          .init(
            operationId: listOperationIdentifier, session: reopenedSession,
            command: .createList(content: .init(name: "Tokyo")))
        ).outcome
    else { throw CancellationError() }
    #expect(maintenanceCheckpoint == checkpoint)
    #expect(replayedItem == createdItem && replayedItemCheckpoint == itemCheckpoint)
    #expect(replayedList == createdList && replayedListCheckpoint == listCheckpoint)
    let another = Planner(configuration: configuration)
    guard case .ready(let anotherSession) = await another.bootstrap(),
      case .exported(let reopenedData) = await another.exportData(session: anotherSession)
    else { throw CancellationError() }
    #expect(reopenedData == data)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeNoOp)
  }

  /// Model access constructs the actual persisted input; all behavioral observations use Planner.
  @MainActor private func insertIndependentMemberships(
    storeURL: URL, itemIdentifier: UUID, listIdentifier: UUID,
    contributions: [(identifier: String, lifetime: String, rank: Int64, done: Bool)] = [
      ("00000000-0000-4000-8000-000000000401", "00000000-0000-4000-8000-000000000841", 1024, false),
      ("00000000-0000-4000-8000-000000000402", "00000000-0000-4000-8000-000000000842", 2048, true),
    ]
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let item = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first { $0.id == itemIdentifier })
    let list = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first { $0.id == listIdentifier })
    let itemLifetime = try #require(item.lifetimeId)
    let listLifetime = try #require(list.lifetimeId)
    for (identifier, lifetime, rank, done) in contributions {
      context.insert(
        PlannerSchemaV18.Membership(
          snapshot: .init(
            id: try #require(UUID(uuidString: identifier)),
            lifetimeId: try #require(UUID(uuidString: lifetime)),
            list: .init(kind: "list", id: listIdentifier, lifetimeId: listLifetime),
            item: .init(kind: "item", id: itemIdentifier, lifetimeId: itemLifetime),
            rank: Int64(rank), localDone: done), list: list, item: item))
    }
    try context.save()
  }
}

private func maintenanceNamespaceFiles(_ directory: URL) throws -> [String: Data] {
  try Dictionary(
    uniqueKeysWithValues: FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).map {
      ($0.lastPathComponent, try Data(contentsOf: $0))
    })
}

private func initialCompletionSeedFixtures() throws -> [[String: Any]] {
  #if SWIFT_PACKAGE
    let bundle = Bundle.module
  #else
    let bundle = Bundle(for: InitialCompletionSeedFixtureBundle.self)
  #endif
  let file = try #require(
    bundle.url(
      forResource: "initial-completion-seeds-v1", withExtension: "json",
      subdirectory: "Fixtures/MembershipConsolidation"))
  let root = try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
  return try #require(root["cases"] as? [[String: Any]])
}

private final class InitialCompletionSeedFixtureBundle: NSObject {}

#if os(macOS)
  extension NativeMembershipConsolidationTests {
    @Test func failedMaintenanceSaveKeepsItsPreparationUnverifiedAndRetriesFresh() async throws {
      guard ProcessInfo.processInfo.environment["PLANNER_MAINTENANCE_SAVE_FAULT_CHILD"] == "1"
      else {
        try runIsolatedMaintenanceSaveFailure()
        return
      }
      let directory = try makePlannerStoreFixtureDirectory()
      let configuration = PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      let planner = Planner(configuration: configuration)
      guard case .ready(let session) = await planner.bootstrap(),
        case .applied(let itemCreation, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: "Hotel", notes: "Keep these notes")))
        ).outcome,
        let item = itemCreation.generated.first,
        case .applied(let listCreation, .complete(let originalCheckpoint)) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: "Tokyo")))
        ).outcome,
        let list = listCreation.generated.first,
        case .exported(let originalData) = await planner.exportData(session: session),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first
      else { throw CancellationError() }
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespace.namespaceId.uuidString)
      let originalFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      try await insertIndependentMemberships(
        storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
      let obstruction = NativeSaveFileSizeObstruction(
        configuration: configuration, maximumFileSize: 0)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.willSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let waitingIdentifier = UUID()
      let command = PlannerCommand.createTag(content: .init(name: "Waiting for maintenance"))
      let failed = await planner.execute(
        .init(operationId: waitingIdentifier, session: session, command: command))
      try obstruction.restore()
      NotificationCenter.default.removeObserver(observer)
      #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
      guard case .rejected(let failure) = failed.outcome else {
        Issue.record("A failed maintenance save must not apply the waiting command: \(failed)")
        return
      }
      #expect(failure.code == "maintenanceRequired")
      let failedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      for (name, bytes) in originalFiles { #expect(failedFiles[name] == bytes) }
      let preparations = failedFiles.filter { $0.key.hasPrefix("maintenance-") }
      #expect(preparations.count == 1)
      let failedPreparationBytes = try #require(preparations.values.first)
      let failedPreparation = try #require(
        JSONSerialization.jsonObject(with: failedPreparationBytes) as? [String: Any])
      let failedIdentifier = try #require(
        (failedPreparation["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
      #expect(failedPreparation["evidence"] as? String == "preparedUnverified")
      guard case .status(let status) = await planner.read(session: session, request: .status),
        case .unavailable(let statusFailure) = status.recovery,
        case .rejected(let retryFailure) = await planner.retryMaintenanceRecovery(
          session: session, maintenanceId: failedIdentifier),
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: waitingIdentifier),
        case .listed(let beforeRetry) = await planner.inspectRecovery(
          request: .namespace(namespaceId: namespace.namespaceId))
      else {
        Issue.record(
          "Preparation alone must authorize neither a command nor maintenance acknowledgement.")
        return
      }
      #expect(statusFailure.code == "maintenanceRequired")
      #expect(retryFailure.code == "maintenanceNotApplied")
      #expect(beforeRetry.acknowledgedSnapshot?.checkpointGeneration == originalCheckpoint)
      #expect(try maintenanceNamespaceFiles(namespaceDirectory) == failedFiles)
      let proposed = try #require(failedPreparation["proposedBackup"] as? [String: Any])
      #expect((proposed["contextAliases"] as? [Any])?.count == 2)
      try await insertIndependentMemberships(
        storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
        contributions: [
          (
            "00000000-0000-4000-8000-000000000403", "00000000-0000-4000-8000-000000000843", 3072,
            false
          )
        ])
      let reopened = Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .exported(let healedData) = await reopened.exportData(session: reopenedSession),
        case .listed(let healedView) = await reopened.inspectRecovery(
          request: .namespace(namespaceId: namespace.namespaceId)),
        let healedCheckpoint = healedView.acknowledgedSnapshot?.checkpointGeneration
      else { throw CancellationError() }
      #expect(healedCheckpoint == originalCheckpoint + 1)
      let healedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      #expect(
        healedFiles["maintenance-\(failedIdentifier.uuidString).json"] == failedPreparationBytes)
      #expect(healedFiles.keys.filter { $0.hasPrefix("maintenance-") }.count == 2)
      let envelope = try #require(
        JSONSerialization.jsonObject(
          with: Data(
            contentsOf: namespaceDirectory.appendingPathComponent(
              "checkpoint-\(healedCheckpoint).json"))) as? [String: Any])
      let maintenance = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
      #expect(maintenance.count == 1)
      let healedMaintenance = try #require(maintenance.first)
      let healedIdentifierText = try #require(healedMaintenance["maintenanceId"] as? String)
      let healedIdentifier = try #require(UUID(uuidString: healedIdentifierText))
      #expect(healedIdentifier != failedIdentifier && healedIdentifier != waitingIdentifier)
      let healed = try #require(JSONSerialization.jsonObject(with: healedData) as? [String: Any])
      let original = try #require(
        JSONSerialization.jsonObject(with: originalData) as? [String: Any])
      #expect(
        NSArray(array: try #require(healed["sources"] as? [Any])).isEqual(
          to: try #require(original["sources"] as? [Any])))
      let memberships = try #require(healed["memberships"] as? [[String: Any]])
      #expect(memberships.count == 1)
      #expect(memberships.first?["id"] as? String == "00000000-0000-4000-8000-000000000401")
      #expect(memberships.first?["localDone"] as? Bool == true)
      let healedAliases = try #require(healed["contextAliases"] as? [[String: Any]])
      #expect(healedAliases.count == 3)
      #expect(
        Set(
          healedAliases.compactMap {
            ($0["context"] as? [String: Any])?["membershipId"] as? String
          }) == [
            "00000000-0000-4000-8000-000000000401",
            "00000000-0000-4000-8000-000000000402",
            "00000000-0000-4000-8000-000000000403",
          ])
      #expect((healed["membershipProvenance"] as? [Any])?.count == 3)
      #expect((healed["completionChanges"] as? [Any])?.isEmpty == true)
      #expect((healed["deletionMarkers"] as? [Any])?.isEmpty == true)
      guard
        case .rejected(let staleRetry) = await reopened.retryMaintenanceRecovery(
          session: reopenedSession, maintenanceId: failedIdentifier),
        case .noReliableEvidence = await reopened.operationStatus(
          session: reopenedSession, operationId: waitingIdentifier)
      else { throw CancellationError() }
      #expect(staleRetry.code == "maintenanceNotApplied")
      #expect(try maintenanceNamespaceFiles(namespaceDirectory) == healedFiles)
      let resumed = await reopened.execute(
        .init(operationId: waitingIdentifier, session: reopenedSession, command: command))
      guard case .applied(_, .complete(let commandCheckpoint)) = resumed.outcome,
        case .snapshot(let tags) = await reopened.query(
          .init(session: reopenedSession, request: .catalog(.init(sourceKind: .tag, archive: .all)))
        )
      else {
        Issue.record(
          "After fresh maintenance, the original waiting command must execute once: \(resumed)")
        return
      }
      #expect(commandCheckpoint == healedCheckpoint + 1)
      #expect(tags.matchingCount == 1)
    }

    private func runIsolatedMaintenanceSaveFailure() throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "PlannerMaintenanceSaveFault-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let outputURL = directory.appendingPathComponent("child.log")
      try Data().write(to: outputURL)
      let output = try FileHandle(forWritingTo: outputURL)
      defer { try? output.close() }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      var runnerArguments: [String] = []
      if let index = CommandLine.arguments.firstIndex(of: "--test-bundle-path"),
        CommandLine.arguments.indices.contains(index + 1)
      {
        runnerArguments = ["--test-bundle-path", CommandLine.arguments[index + 1]]
      }
      process.arguments =
        runnerArguments + [
          "--testing-library", "swift-testing", "--filter",
          "NativeMembershipConsolidationTests/failedMaintenanceSaveKeepsItsPreparationUnverifiedAndRetriesFresh",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_MAINTENANCE_SAVE_FAULT_CHILD"] = "1"
      process.environment = environment
      process.standardOutput = output
      process.standardError = output
      let completion = DispatchSemaphore(value: 0)
      process.terminationHandler = { _ in completion.signal() }
      try process.run()
      let finished = completion.wait(timeout: .now() + 45) == .success
      if !finished {
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
      }
      try output.close()
      let transcript = try String(contentsOf: outputURL, encoding: .utf8)
      print("MAINTENANCE_SAVE_FAULT_CHILD_LOG \(outputURL.path)")
      #expect(finished, "The isolated maintenance save fault must finish within its deadline.")
      #expect(process.terminationReason == .exit)
      #expect(process.terminationStatus == 0, Comment(rawValue: String(transcript.suffix(12_000))))
      #expect(transcript.contains("Test run with 1 test"))
    }
  }
#endif
