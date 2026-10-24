import Foundation
import SwiftData
import Testing

@testable import PlannerCore

struct NativeMembershipCommandEvidenceTests {
  @MainActor @Test func legacyMoveReceiptReplaysBeforeCurrentTargetResolutionAndKeepsItsDigest()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let literal = try #require(
      JSONSerialization.jsonObject(
        with: fixtureData("legacy-move-fingerprint-v1")) as? [String: Any])
    let digest = try #require(literal["payloadDigest"] as? String)
    var identity = try #require(literal["identity"] as? [String: Any])
    identity["schemaVersion"] = 19
    try initializeEmptyStore(configuration)
    try FileManager.default.createDirectory(
      at: configuration.controlURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: identity).write(
      to: configuration.controlURL,
      options: .atomic)
    var graph = try #require(
      JSONSerialization.jsonObject(
        with: fixtureData("informed-readd-v3")) as? [String: Any])
    var sources = try #require(graph["sources"] as? [[String: Any]])
    var destinationList = sources[1]
    destinationList["id"] = "00000000-0000-4000-8000-000000000202"
    destinationList["lifetimeId"] = "00000000-0000-4000-8000-000000000822"
    sources.append(destinationList)
    graph["sources"] = sources
    var members = try #require(graph["memberships"] as? [[String: Any]])
    members[0]["id"] = "00000000-0000-4000-8000-000000000406"
    members[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000846"
    members[0]["list"] = [
      "kind": "list", "id": destinationList["id"],
      "lifetimeId": destinationList["lifetimeId"],
    ]
    graph["memberships"] = members
    let operationIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000993")!
    var markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000893",
      "operationId": operationIdentifier.uuidString,
      "target": [
        "kind": "membership", "id": "00000000-0000-4000-8000-000000000405",
        "lifetimeId": "00000000-0000-4000-8000-000000000845",
      ],
      "closedFamilyId": NSNull(),
    ])
    graph["deletionMarkers"] = markers
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: incoming, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: review.command, reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let item = PlannerEntityReference(
      kind: .item,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)
    let origin = PlannerEntityReference(
      kind: .list,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!)
    let destination = PlannerEntityReference(
      kind: .list,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000202")!)
    let originalReference = PlannerReferenceRead.membership(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000405")!, list: origin, item: item)
    let destinationReference = PlannerReferenceRead.membership(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000406")!, list: destination, item: item)
    let expected = PlannerAppliedResult(
      generatedIdentities: [.reference(destinationReference)],
      affectedIdentities: [
        .reference(originalReference), .reference(destinationReference),
        .source(origin), .source(destination),
      ])
    let command = PlannerCommand.moveMembership(
      listId: origin.id,
      membershipId: UUID(uuidString: "00000000-0000-4000-8000-000000000405")!,
      destinationListId: destination.id, placement: .last)
    try insertLegacyMoveReceipt(
      configuration: configuration,
      operation: .init(operationId: operationIdentifier, session: session, command: command),
      digest: digest, result: expected)
    guard case .exported(let beforeReplay) = await planner.exportData(session: session),
      case .applied(let replayed, .incomplete) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .applied(let repaired, .complete(let checkpoint)) = await planner.retryRecovery(
        session: session, operationId: operationIdentifier
      ).outcome,
      case .applied(let repeated, .complete(let repeatedCheckpoint)) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .exported(let afterReplay) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(afterReplay)
    else {
      Issue.record("A valid legacy Move receipt must replay without its removed original target.")
      return
    }
    #expect(replayed == expected && repaired == expected && repeated == expected)
    #expect(checkpoint == repeatedCheckpoint)
    #expect(afterReplay == beforeReplay)
    #expect(saved.backup.membershipRemovals.count == 1)
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      "00000000-0000-4000-8000-000000000920")
    let acknowledged = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf:
            namespaceDirectory.appendingPathComponent("checkpoint-\(checkpoint).json")))
        as? [String: Any])
    let receipts = try #require(acknowledged["receipts"] as? [[String: Any]])
    let oldReceipt = try #require(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString })
    #expect(oldReceipt["payloadDigest"] as? String == digest)
  }

  /// Construct historical native evidence; public replay and recovery supply all observations.
  @MainActor private func insertLegacyMoveReceipt(
    configuration: PlannerStorageConfiguration,
    operation: PlannerOperation, digest: String, result: PlannerAppliedResult
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let bindings = [
      PlannerBoundIdentity(
        kind: "membership", id: UUID(uuidString: "00000000-0000-4000-8000-000000000405")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000845")!),
      PlannerBoundIdentity(
        kind: "list", id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000821")!),
      PlannerBoundIdentity(
        kind: "item", id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000811")!),
      PlannerBoundIdentity(
        kind: "list", id: UUID(uuidString: "00000000-0000-4000-8000-000000000202")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000822")!),
    ]
    context.insert(
      try PlannerSchemaV1.Receipt(
        operation: operation, digest: digest, result: result,
        bindings: bindings))
    try context.save()
  }

  @Test func ordinaryReAddRetainsItsOriginalObservationBasisForReplay() async throws {
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
          command: .createItem(content: .init(title: "Museum")))
      ).outcome,
      let item = itemCreation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listCreation.generated.first,
      case .applied(let initialAddition, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let originalIdentifier, _, _) = initialAddition.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: originalIdentifier))
      ).outcome,
      case .exported(let removedData) = await planner.exportData(session: session),
      case .decoded(let removedBackup) = planner.decodeImport(removedData)
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let command = PlannerCommand.addMembership(itemId: item.id, listId: list.id, placement: .last)
    guard
      case .applied(let added, .complete(let generation)) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .membership(let addedIdentifier, _, _) = added.generatedReferences.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let checkpoint = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(generation).json")))
        as? [String: Any])
    let receipts = try #require(checkpoint["receipts"] as? [[String: Any]])
    let receiptValue = receipts.first {
      $0["operationId"] as? String == operationIdentifier.uuidString
    }
    let receipt = try #require(receiptValue)
    #expect((receipt["payloadDigest"] as? String)?.hasPrefix("sha256-payload-v3:") == true)
    let proposals = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("proposal-") }
    let candidates = try proposals.compactMap { file -> [String: Any]? in
      let value = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
      return value?["originalOperationId"] as? String == operationIdentifier.uuidString
        ? value : nil
    }
    let preparedValue = candidates.first
    let preparation = try #require(preparedValue)
    #expect(preparation["formatVersion"] as? Int == 2)
    #expect((preparation["resolvedBindings"] as? [[String: Any]])?.count == 2)
    let evidence = preparation["resolvedMembershipEvidence"] as? [[String: Any]]
    #expect(evidence?.count == 1)
    #expect(evidence?.first?["membershipId"] as? String == addedIdentifier.uuidString)
    #expect(
      evidence?.first?["observedRemovalIds"] as? [String]
        == removedBackup.backup.membershipRemovals.map { $0.deletionId.uuidString }.sorted())
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: addedIdentifier))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome,
      case .exported(let currentData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayedGeneration)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .exported(let afterReplay) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(replayed == added && replayedGeneration == generation)
    #expect(afterReplay == currentData)
  }

  @MainActor @Test func strictRemoveUsesTheFrozenVersionThreeFingerprintAndPreparedBindings()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let literals = try #require(
      JSONSerialization.jsonObject(with: fixtureData("operation-fingerprint-literals"))
        as? [String: Any])
    var identity = try #require(literals["identity"] as? [String: Any])
    identity["schemaVersion"] = 19
    try initializeEmptyStore(configuration)
    try FileManager.default.createDirectory(
      at: configuration.controlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: identity).write(
      to: configuration.controlURL, options: .atomic)
    var graph = try #require(
      JSONSerialization.jsonObject(with: fixtureData("informed-readd-v3")) as? [String: Any])
    var memberships = try #require(graph["memberships"] as? [[String: Any]])
    var provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    #expect(memberships.count == 1 && provenance.count == 2)
    memberships[0]["id"] = "00000000-0000-4000-8000-000000000405"
    memberships[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000845"
    provenance[1]["membershipId"] = memberships[0]["id"]
    provenance[1]["membershipLifetimeId"] = memberships[0]["lifetimeId"]
    graph["memberships"] = memberships
    graph["membershipProvenance"] = provenance
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let listIdentifier = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000201"))
    let membershipIdentifier = try #require(
      UUID(uuidString: "00000000-0000-4000-8000-000000000405"))
    let operationIdentifier = UUID()
    let command = PlannerCommand.removeMembership(
      listId: listIdentifier, membershipId: membershipIdentifier)
    let outcome = await planner.execute(
      .init(operationId: operationIdentifier, session: session, command: command))
    guard case .applied(let removed, .complete(let generation)) = outcome.outcome else {
      Issue.record("The literal's informed membership must be removable: \(outcome)")
      return
    }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      "00000000-0000-4000-8000-000000000920")
    let checkpoint = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(generation).json")))
        as? [String: Any])
    let receipts = try #require(checkpoint["receipts"] as? [[String: Any]])
    let receipt = try #require(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString })
    let cases = try #require(literals["cases"] as? [[String: Any]])
    let literal = try #require(cases.first { $0["name"] as? String == "observed-remove-v3" })
    #expect(receipt["payloadDigest"] as? String == literal["payloadDigest"] as? String)
    let proposals = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("proposal-") }
    let candidates = try proposals.compactMap { file -> [String: Any]? in
      let value = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
      return value?["originalOperationId"] as? String == operationIdentifier.uuidString
        ? value : nil
    }
    let preparedValue = candidates.first
    let preparation = try #require(preparedValue)
    #expect(preparation["formatVersion"] as? Int == 2)
    #expect((preparation["resolvedBindings"] as? [[String: Any]])?.count == 3)
    #expect((preparation["resolvedMembershipEvidence"] as? [[String: Any]])?.count == 1)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayedGeneration)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(replayed == removed && replayedGeneration == generation)
  }

  @MainActor private func initializeEmptyStore(_ configuration: PlannerStorageConfiguration) throws
  {
    try FileManager.default.createDirectory(
      at: configuration.storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    try context.save()
  }

  private func fixtureData(_ name: String) throws -> Data {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeMembershipCommandEvidenceFixtureBundle.self)
    #endif
    return try Data(
      contentsOf: #require(
        bundle.url(
          forResource: name, withExtension: "json", subdirectory: "Fixtures/MembershipConsolidation"
        )))
  }
}

private final class NativeMembershipCommandEvidenceFixtureBundle: NSObject {}
