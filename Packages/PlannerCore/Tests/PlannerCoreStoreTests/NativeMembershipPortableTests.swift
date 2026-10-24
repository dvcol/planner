import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeMembershipPortableTests {
  enum InvalidProvenance: String, CaseIterable {
    case missingGroup, unknownField, duplicateBinding, duplicateRemoval, missingMarker,
      missingBinding
    case unknownObservation, duplicateObservation, wrongLiveLifetime, unknownHistoricalItem
    case unawareAddition, selfObservedRemoval, causalCycle, orphanBinding

    var path: String {
      switch self {
      case .missingGroup: "/membershipRemovals"
      case .unknownField: "/membershipProvenance/0/rank"
      case .duplicateBinding: "/membershipProvenance/2/membershipId"
      case .duplicateRemoval: "/membershipRemovals/1/deletionId"
      case .missingMarker, .missingBinding: "/membershipRemovals/0/deletionId"
      case .unknownObservation: "/membershipProvenance/1/observedRemovalIds/0"
      case .duplicateObservation: "/membershipProvenance/1/observedRemovalIds/1"
      case .wrongLiveLifetime: "/membershipProvenance/1/item/lifetimeId"
      case .unknownHistoricalItem: "/membershipProvenance/0/item/id"
      case .unawareAddition: "/memberships/0/id"
      case .selfObservedRemoval, .causalCycle: "/membershipProvenance/0/observedRemovalIds"
      case .orphanBinding: "/membershipProvenance/2/membershipId"
      }
    }
  }

  @Test func informedReaddDecodesItsRetainedRemovalHistoryWithoutOpeningStorage() throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .shareExtension, storageMode: .localOnly))
    let result = planner.decodeImport(try informedMembershipPortableFixtureData())
    guard case .decoded(let decoded) = result else {
      Issue.record("Decode the independent informed re-add and retained strict removal: \(result)")
      return
    }
    #expect(decoded.backup.formatVersion == 3)
    #expect(decoded.backup.membershipProvenance.count == 2)
    #expect(
      decoded.backup.membershipRemovals.map(\.deletionId.uuidString) == [
        "00000000-0000-4000-8000-000000000891"
      ])
    let informed = try #require(
      decoded.backup.membershipProvenance.first {
        $0.membershipId.uuidString == "00000000-0000-4000-8000-000000000405"
      })
    #expect(
      informed.observedRemovalIds.map(\.uuidString) == [
        "00000000-0000-4000-8000-000000000891"
      ])
    #expect(informed.list.id.uuidString == "00000000-0000-4000-8000-000000000201")
    #expect(informed.item.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000811")
    let membership = try #require(decoded.backup.memberships.first)
    #expect(decoded.backup.sources.count == 2 && decoded.backup.memberships.count == 1)
    #expect(membership.id.uuidString == "00000000-0000-4000-8000-000000000405")
    #expect(membership.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000845")
    #expect(!membership.localDone && membership.rank == 1024)
    #expect(decoded.backup.items.first?.globalDone == false)
    #expect(decoded.backup.deletionMarkers.count == 1)
    #expect(decoded.externalBindings.isEmpty && decoded.originPaths.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func removalObservationsCannotBorrowAnotherItemListPairsAuthority() throws {
    var graph = try #require(
      JSONSerialization.jsonObject(with: informedMembershipPortableFixtureData()) as? [String: Any])
    var sources = try #require(graph["sources"] as? [[String: Any]])
    var otherItem = sources[0]
    otherItem["id"] = "00000000-0000-4000-8000-000000000102"
    otherItem["lifetimeId"] = "00000000-0000-4000-8000-000000000812"
    sources.append(otherItem)
    graph["sources"] = sources
    var provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    provenance[0]["item"] = [
      "kind": "item", "id": "00000000-0000-4000-8000-000000000102",
      "lifetimeId": "00000000-0000-4000-8000-000000000812",
    ]
    graph["membershipProvenance"] = provenance
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .shareExtension, storageMode: .localOnly))
    let result = planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
    guard case .invalid(let failure) = result else {
      Issue.record("A removal for another Item cannot authorize this membership: \(result)")
      return
    }
    #expect(failure.code == "invalidInput")
    #expect(failure.propertyPath == "/membershipProvenance/1/observedRemovalIds/0")
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test(arguments: InvalidProvenance.allCases)
  func malformedMembershipHistoryRejectsTheWholeDecodeAtItsActualProperty(
    testCase: InvalidProvenance
  ) throws {
    var graph = try #require(
      JSONSerialization.jsonObject(with: informedMembershipPortableFixtureData()) as? [String: Any])
    var provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    var removals = try #require(graph["membershipRemovals"] as? [[String: Any]])
    var markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    switch testCase {
    case .missingGroup: break
    case .unknownField: provenance[0]["rank"] = "1024"
    case .duplicateBinding: provenance.append(provenance[0])
    case .duplicateRemoval: removals.append(removals[0])
    case .missingMarker: markers = []
    case .missingBinding: provenance.removeFirst()
    case .unknownObservation:
      provenance[1]["observedRemovalIds"] = ["00000000-0000-4000-8000-000000000899"]
    case .duplicateObservation:
      provenance[1]["observedRemovalIds"] = [
        "00000000-0000-4000-8000-000000000891", "00000000-0000-4000-8000-000000000891",
      ]
    case .wrongLiveLifetime:
      var item = try #require(provenance[1]["item"] as? [String: Any])
      item["lifetimeId"] = "00000000-0000-4000-8000-000000000819"
      provenance[1]["item"] = item
    case .unknownHistoricalItem:
      provenance[0]["item"] = [
        "kind": "item", "id": "00000000-0000-4000-8000-000000000199",
        "lifetimeId": "00000000-0000-4000-8000-000000000819",
      ]
    case .unawareAddition: provenance[1]["observedRemovalIds"] = []
    case .selfObservedRemoval:
      provenance[0]["observedRemovalIds"] = ["00000000-0000-4000-8000-000000000891"]
    case .causalCycle:
      provenance[0]["observedRemovalIds"] = ["00000000-0000-4000-8000-000000000892"]
      provenance[1]["observedRemovalIds"] = [
        "00000000-0000-4000-8000-000000000891", "00000000-0000-4000-8000-000000000892",
      ]
      var otherBinding = provenance[0]
      otherBinding["membershipId"] = "00000000-0000-4000-8000-000000000402"
      otherBinding["membershipLifetimeId"] = "00000000-0000-4000-8000-000000000842"
      otherBinding["observedRemovalIds"] = ["00000000-0000-4000-8000-000000000891"]
      provenance.append(otherBinding)
      var otherMarker = markers[0]
      otherMarker["deletionId"] = "00000000-0000-4000-8000-000000000892"
      otherMarker["operationId"] = "00000000-0000-4000-8000-000000000992"
      otherMarker["target"] = [
        "kind": "membership", "id": "00000000-0000-4000-8000-000000000402",
        "lifetimeId": "00000000-0000-4000-8000-000000000842",
      ]
      markers.append(otherMarker)
      removals.append(["deletionId": "00000000-0000-4000-8000-000000000892"])
    case .orphanBinding:
      var unproven = provenance[0]
      unproven["membershipId"] = "00000000-0000-4000-8000-000000000499"
      unproven["membershipLifetimeId"] = "00000000-0000-4000-8000-000000000849"
      provenance.append(unproven)
    }
    graph["membershipProvenance"] = provenance
    graph["membershipRemovals"] = removals
    graph["deletionMarkers"] = markers
    if testCase == .missingGroup { graph.removeValue(forKey: "membershipRemovals") }
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .shareExtension, storageMode: .localOnly))
    let result = planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
    guard case .invalid(let failure) = result else {
      Issue.record("Malformed membership history must reject atomically: \(testCase), \(result)")
      return
    }
    #expect(failure.code == "invalidInput")
    #expect(failure.propertyPath == testCase.path)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func informedReaddSurvivesNativeImportRecoveryReplayAndReopen() async throws {
    let data = try informedMembershipPortableFixtureData()
    let expected = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(data),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite))
    else { throw CancellationError() }
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .applyImport(backup: decoded, mode: .overwrite), reviewToken: review.reviewToken)
    let response = await planner.execute(operation)
    guard case .applied(let saved, .complete(let checkpoint)) = response.outcome,
      case .exported(let exported) = await planner.exportData(session: session)
    else {
      Issue.record("The complete v3 graph must save with its original provenance: \(response)")
      return
    }
    let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: actual))
    let importedRemovalOperation = try #require(
      UUID(uuidString: "00000000-0000-4000-8000-000000000991"))
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: importedRemovalOperation)
    else {
      Issue.record("Imported removal history must not fabricate an applied user operation.")
      return
    }
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .applied(let replayed, .complete(let replayCheckpoint)) =
        await planner.execute(operation).outcome
    else { throw CancellationError() }
    let recoveryGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: recoveryGraph))
    #expect(saved == replayed && checkpoint == replayCheckpoint)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == exported)
  }

  @Test(arguments: ["notes", "globalCompletion", "recoveryRetry"])
  func laterOrdinaryWritesPreserveMembershipAuthorityAndOriginalImportReplay(_ scenario: String)
    async throws
  {
    let data = try informedMembershipPortableFixtureData()
    var expected = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(data),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded)),
      let item = decoded.backup.items.first
    else { throw CancellationError() }
    let original = PlannerOperation(
      operationId: UUID(), session: session, command: review.command,
      reviewToken: review.reviewToken)
    guard
      case .applied(let imported, .complete(let originalCheckpoint)) =
        await planner.execute(original).outcome,
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id))),
      let notesHash = before.fieldHashes[.notes]
    else { throw CancellationError() }
    let command: PlannerCommand
    if scenario == "globalCompletion" {
      command = .setCompletion(scope: .globalItem(itemId: item.id), done: true)
    } else {
      command = .editItem(
        sourceId: item.id, changes: .init(notes: .set("Updated Hotel notes")),
        expectedFieldHashes: [.notes: notesHash])
    }
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    var observer: (any NSObjectProtocol)?
    if scenario == "recoveryRetry" {
      observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
    }
    defer {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(operationId: operationIdentifier, session: session, command: command))
    guard case .applied(let edited, let recovery) = response.outcome else {
      Issue.record("The ordinary write must preserve imported authority: \(response)")
      return
    }
    let checkpoint: Int64
    if scenario == "recoveryRetry" {
      guard case .incomplete = recovery else { throw CancellationError() }
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      try obstruction.restore()
      guard
        case .applied(let retried, .complete(let generation)) = await planner.retryRecovery(
          session: session, operationId: operationIdentifier
        ).outcome
      else { throw CancellationError() }
      #expect(retried == edited)
      checkpoint = generation
    } else {
      guard case .complete(let generation) = recovery else { throw CancellationError() }
      checkpoint = generation
    }
    guard
      case .source(.item(let saved)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id))),
      case .exported(let exported) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .applied(let replayed, .complete(let replayCheckpoint)) =
        await planner.execute(original).outcome
    else { throw CancellationError() }
    var sources = try #require(expected["sources"] as? [[String: Any]])
    sources[0]["updatedAt"] = saved.updatedAt.timeIntervalSinceReferenceDate
    if scenario == "globalCompletion" {
      sources[0]["globalDone"] = true
    } else {
      var content = try #require(sources[0]["content"] as? [String: Any])
      content["notes"] = "Updated Hotel notes"
      sources[0]["content"] = content
    }
    expected["sources"] = sources
    let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
    let recoveryGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: actual))
    #expect(NSDictionary(dictionary: expected).isEqual(to: recoveryGraph))
    #expect(imported == replayed && replayCheckpoint == originalCheckpoint)
    #expect(checkpoint > originalCheckpoint)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == exported)
  }
}

private func informedMembershipPortableFixtureData() throws -> Data {
  #if SWIFT_PACKAGE
    let bundle = Bundle.module
  #else
    let bundle = Bundle(for: NativeMembershipPortableFixtureBundle.self)
  #endif
  let fixture = try #require(
    bundle.url(
      forResource: "informed-readd-v3", withExtension: "json",
      subdirectory: "Fixtures/MembershipConsolidation"))
  return try Data(contentsOf: fixture)
}

private final class NativeMembershipPortableFixtureBundle: NSObject {}
