import CryptoKit
import Foundation
import PlannerCore
import SwiftData
import Testing

struct RecoveryProposalSelectionTests {
  @Test(arguments: ["emptyRestorationCandidates", "duplicateObservedChanges"])
  func malformedPortableLineageIsRejectedBeforeRecoverySelection(_ scenario: String) async throws {
    let fixture = try await PreparedNotesProposalFixture.create()
    let proposalURL = fixture.configuration.recoveryDirectoryURL
      .appendingPathComponent(fixture.namespace.namespaceId.uuidString)
      .appendingPathComponent("proposal-\(fixture.proposal.proposalId.uuidString).json")
    var proposal = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: proposalURL)) as? [String: Any])
    var backup = try canonicalPortableFixtureExpectations(nativeImportFixtureData())
    let expectedPath: String
    switch scenario {
    case "emptyRestorationCandidates":
      let markers = try #require(backup["deletionMarkers"] as? [[String: Any]])
      let target = try #require(markers.first?["target"] as? [String: Any])
      let predecessor = try #require(target["source"] as? [String: Any])
      backup["restorationFamilies"] = [
        ["familyId": UUID().uuidString, "predecessor": predecessor, "candidates": []]
      ]
      expectedPath = "/restorationFamilies/0/candidates"
    case "duplicateObservedChanges":
      var aliases = try #require(backup["contextAliases"] as? [[String: Any]])
      var changes = try #require(backup["completionChanges"] as? [[String: Any]])
      let predecessorIdentifier = try #require(changes.first?["id"] as? String)
      var change = try #require(changes.first)
      let changeIdentifier = UUID().uuidString
      change["id"] = changeIdentifier
      change["observedChangeIds"] = [predecessorIdentifier, predecessorIdentifier]
      changes.append(change)
      aliases[0]["currentChangeId"] = changeIdentifier
      backup["contextAliases"] = aliases
      backup["completionChanges"] = changes
      expectedPath = "/completionChanges/1/observedChangeIds"
    default: throw CancellationError()
    }
    let portableData = try JSONSerialization.data(withJSONObject: backup)
    guard case .invalid(let importFailure) = fixture.planner.decodeImport(portableData) else {
      Issue.record("Public import must reject \(scenario).")
      return
    }
    #expect(importFailure.propertyPath == expectedPath)
    proposal["proposedBackup"] = backup
    try JSONSerialization.data(withJSONObject: proposal).write(to: proposalURL, options: .atomic)
    let response = await fixture.planner.inspectRecovery(
      request: .proposal(
        namespaceId: fixture.namespace.namespaceId, proposalId: fixture.proposal.proposalId))
    guard case .failed(let recoveryFailure) = response else {
      Issue.record("Recovery must reject \(scenario) before returning a selection.")
      return
    }
    #expect(recoveryFailure.code == "recoveryIntegrityFailure")
    #expect(recoveryFailure.propertyPath == expectedPath)
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source)),
      case .appliedRecoveryIncomplete(let result, _) = await fixture.planner.operationStatus(
        session: fixture.session, operationId: fixture.proposal.originalOperationId)
    else { throw CancellationError() }
    #expect(current.source == fixture.current.source)
    #expect(current.sourceLifetimeId == fixture.current.sourceLifetimeId)
    #expect(current.content.notes == fixture.current.content.notes)
    #expect(current.fieldHashes == fixture.current.fieldHashes)
    #expect(current.updatedAt == fixture.current.updatedAt)
    #expect(result.affected.contains(fixture.source))
  }

  @Test(arguments: [false, true])
  func completePortableLineageSurvivesPreparedFileInspectionWithoutApplyingData(
    includeRestorationFamily: Bool
  ) async throws {
    let fixture = try await PreparedNotesProposalFixture.create()
    let proposalURL = fixture.configuration.recoveryDirectoryURL
      .appendingPathComponent(fixture.namespace.namespaceId.uuidString)
      .appendingPathComponent("proposal-\(fixture.proposal.proposalId.uuidString).json")
    var proposal = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: proposalURL)) as? [String: Any])
    var expected = try canonicalPortableFixtureExpectations(nativeImportFixtureData())
    if includeRestorationFamily {
      let markers = try #require(expected["deletionMarkers"] as? [[String: Any]])
      let target = try #require(markers.first?["target"] as? [String: Any])
      let predecessor = try #require(target["source"] as? [String: Any])
      expected["restorationFamilies"] = [
        [
          "familyId": "00000000-0000-4000-8000-000000000890", "predecessor": predecessor,
          "candidates": [
            [
              "lifetimeId": "00000000-0000-4000-8000-000000000820",
              "operationId": "00000000-0000-4000-8000-000000000994",
            ]
          ],
        ]
      ]
    }
    guard
      case .decoded = fixture.planner.decodeImport(
        try JSONSerialization.data(withJSONObject: expected))
    else { throw CancellationError() }
    proposal["proposedBackup"] = expected
    try JSONSerialization.data(withJSONObject: proposal).write(to: proposalURL, options: .atomic)
    let response = await fixture.planner.inspectRecovery(
      request: .proposal(
        namespaceId: fixture.namespace.namespaceId, proposalId: fixture.proposal.proposalId))
    guard case .selected(let selection) = response else {
      Issue.record("Inspect every valid lineage record from the prepared file: \(response)")
      return
    }
    #expect(selection.evidence == .preparedUnverified)
    #expect(selection.decodedBackup.backup.contextAliases.count == 1)
    #expect(selection.decodedBackup.backup.completionChanges.count == 1)
    #expect(
      selection.decodedBackup.backup.restorationFamilies.count == (includeRestorationFamily ? 1 : 0)
    )
    let actual = try #require(
      JSONSerialization.jsonObject(with: selection.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source)),
      case .appliedRecoveryIncomplete(let result, _) = await fixture.planner.operationStatus(
        session: fixture.session, operationId: fixture.proposal.originalOperationId)
    else { throw CancellationError() }
    #expect(current.content.notes == "Monday booking")
    #expect(current.source.id == fixture.source.id)
    #expect(result.affected.contains(fixture.source))
  }

  @Test
  func selectingPreparedNotesProposalAfterReopenPreservesUnverifiedEvidenceAndAcknowledgedData()
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
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source))
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
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session,
        command: .editItem(
          sourceId: source.id, changes: .init(notes: .set("Monday booking")),
          expectedFieldHashes: [.notes: try #require(original.fieldHashes[.notes])])))
    #expect(obstruction.didObstruct)
    #expect(obstruction.failure == nil)
    guard case .applied(let applied, .incomplete(let failure)) = response.outcome else {
      throw CancellationError()
    }
    #expect(failure.code == "recoveryIncomplete")
    try obstruction.restore()

    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let proposal = namespace.preparedProposals.first,
      case .source(.item(let beforeInspection)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else { throw CancellationError() }
    #expect(namespaces.count == 1)
    #expect(namespace.preparedProposals.count == 1)
    #expect(proposal.originalOperationId == operationIdentifier)
    #expect(proposal.evidence == "preparedUnverified")
    #expect(proposal.requiresFreshReview)
    let selectionResponse = await reopened.inspectRecovery(
      request: .proposal(namespaceId: namespace.namespaceId, proposalId: proposal.proposalId))
    guard case .selected(let selection) = selectionResponse else {
      Issue.record("The retained proposal must be independently selectable: \(selectionResponse)")
      return
    }
    #expect(selection.namespaceId == namespace.namespaceId)
    #expect(selection.datasetId == namespace.datasetId)
    #expect(!selection.ownershipBinding.isEmpty)
    #expect(selection.evidence == .preparedUnverified)
    #expect(selection.checkpointGeneration == nil)
    #expect(selection.proposalId == proposal.proposalId)
    #expect(selection.originalOperationId == operationIdentifier)
    #expect(selection.decodedBackup.backup.items.count == 1)
    let recovered = try #require(selection.decodedBackup.backup.items.first)
    #expect(recovered.id == source.id)
    #expect(recovered.lifetimeId == beforeInspection.sourceLifetimeId)
    #expect(recovered.content.title == "Hotel")
    #expect(recovered.content.notes == "Monday booking")
    #expect(!recovered.globalDone && !recovered.archived)
    let portable = try #require(
      JSONSerialization.jsonObject(with: selection.portableData) as? [String: Any])
    #expect(portable["format"] as? String == "planner-data")
    #expect(portable["receipts"] == nil && portable["preparedProposals"] == nil)
    #expect(portable["datasetId"] == nil && portable["ownershipBinding"] == nil)
    guard
      case .selected(let acknowledged) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .source(.item(let afterInspection)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .appliedRecoveryIncomplete(let statusResult, _) = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(acknowledged.evidence == .acknowledgedSnapshot)
    #expect(acknowledged.ownershipBinding == selection.ownershipBinding)
    #expect(acknowledged.decodedBackup.backup.items.first?.content.notes == "Original notes")
    #expect(afterInspection.source == beforeInspection.source)
    #expect(afterInspection.sourceLifetimeId == beforeInspection.sourceLifetimeId)
    #expect(afterInspection.content.title == "Hotel")
    #expect(afterInspection.content.notes == "Monday booking")
    #expect(afterInspection.updatedAt == beforeInspection.updatedAt)
    #expect(afterInspection.fieldHashes == beforeInspection.fieldHashes)
    #expect(statusResult == applied)
  }

  @Test(arguments: [
    "missingProposal", "missingNamespace", "wrongOwner", "wrongDataset", "wrongEvidence",
    "malformed", "duplicateIdentity", "unresolvedReference", "acknowledged",
  ])
  func invalidOrAcknowledgedProposalSelectionRetainsCurrentContentAndRecovery(_ scenario: String)
    async throws
  {
    let fixture = try await PreparedNotesProposalFixture.create()
    let namespaceDirectory = fixture.configuration.recoveryDirectoryURL
      .appendingPathComponent(fixture.namespace.namespaceId.uuidString)
    let proposalURL =
      namespaceDirectory
      .appendingPathComponent("proposal-\(fixture.proposal.proposalId.uuidString).json")
    let originalBytes = try Data(contentsOf: proposalURL)
    var proposal = try #require(
      JSONSerialization.jsonObject(with: originalBytes) as? [String: Any])
    var requestedNamespace = fixture.namespace.namespaceId
    var requestedProposal = fixture.proposal.proposalId
    var expectedCode = "recoveryIntegrityFailure"
    switch scenario {
    case "missingProposal":
      requestedProposal = UUID()
      expectedCode = "missingReference"
    case "missingNamespace":
      requestedNamespace = UUID()
      expectedCode = "missingReference"
    case "wrongOwner": proposal["ownershipBinding"] = "different-owner"
    case "wrongDataset": proposal["datasetId"] = UUID().uuidString
    case "wrongEvidence": proposal["evidence"] = "acknowledgedSnapshot"
    case "malformed":
      try Data("{ incomplete proposal".utf8).write(to: proposalURL, options: .atomic)
      expectedCode = "readUnavailable"
    case "duplicateIdentity":
      try originalBytes.write(
        to: namespaceDirectory.appendingPathComponent("proposal-duplicate.json"), options: .atomic)
    case "unresolvedReference":
      var backup = try #require(proposal["proposedBackup"] as? [String: Any])
      let missingIdentifier = UUID().uuidString
      let linkIdentifier = UUID().uuidString
      backup["ownedLinks"] = [
        [
          "id": linkIdentifier, "lifetimeId": linkIdentifier,
          "owner": ["kind": "item", "id": missingIdentifier, "lifetimeId": missingIdentifier],
          "rank": "0", "originalUrl": "https://example.com", "label": NSNull(),
          "kind": "website", "providerReference": NSNull(),
        ]
      ]
      proposal["proposedBackup"] = backup
    case "acknowledged":
      let originalCheckpointURL = namespaceDirectory.appendingPathComponent("checkpoint-1.json")
      var envelope = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: originalCheckpointURL))
          as? [String: Any])
      let bytes = try JSONSerialization.data(
        withJSONObject: try #require(proposal["proposedBackup"] as? [String: Any]))
      envelope["checkpointGeneration"] = "2"
      envelope["portablePayloadBase64"] = bytes.base64EncodedString()
      envelope["dataDigest"] =
        "sha256:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
      var receipts = try #require(envelope["receipts"] as? [[String: Any]])
      receipts.append([
        "operationId": fixture.proposal.originalOperationId.uuidString,
        "payloadDigest": try #require(proposal["payloadDigest"] as? String),
        "datasetId": fixture.namespace.datasetId.uuidString,
        "ownershipBinding": fixture.acknowledged.ownershipBinding,
        "result": [
          "generated": [],
          "affected": [["kind": "item", "id": fixture.source.id.uuidString]],
          "progress": [], "importSummary": NSNull(),
        ],
        "commitState": "applied", "checkpointGeneration": "2",
      ])
      envelope["receipts"] = receipts
      try JSONSerialization.data(withJSONObject: envelope).write(
        to: namespaceDirectory.appendingPathComponent("checkpoint-2.json"), options: .atomic)
      expectedCode = "missingReference"
    default: throw CancellationError()
    }
    if ["wrongOwner", "wrongDataset", "wrongEvidence", "unresolvedReference"].contains(scenario) {
      try JSONSerialization.data(withJSONObject: proposal).write(to: proposalURL, options: .atomic)
    }
    guard
      case .failed(let failure) = await fixture.planner.inspectRecovery(
        request: .proposal(namespaceId: requestedNamespace, proposalId: requestedProposal))
    else {
      Issue.record("Reject \(scenario) without returning a misleading proposal selection.")
      return
    }
    #expect(failure.code == expectedCode)
    #expect(!failure.message.isEmpty)
    guard
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source)),
      case .selected(let acknowledged) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: fixture.namespace.namespaceId, checkpointGeneration: 1))
    else { throw CancellationError() }
    #expect(current.source == fixture.source)
    #expect(current.content.title == "Hotel" && current.content.notes == "Monday booking")
    #expect(current.fieldHashes == fixture.current.fieldHashes)
    #expect(current.updatedAt == fixture.current.updatedAt)
    #expect(acknowledged.portableData == fixture.acknowledged.portableData)
    if scenario == "acknowledged" {
      guard
        case .listed(let namespace) = await fixture.planner.inspectRecovery(
          request: .namespace(namespaceId: fixture.namespace.namespaceId))
      else { throw CancellationError() }
      #expect(namespace.preparedProposals.isEmpty)
      #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 2)
    }
  }

  @Test func inspectingRetainedProposalFromSeparateEmptyDatasetNeverImportsOrAcknowledgesIt()
    async throws
  {
    let fixture = try await PreparedNotesProposalFixture.create()
    let separateConfiguration = PlannerStorageConfiguration(
      storeURL: fixture.directory.appendingPathComponent("separate-store/Planner.sqlite"),
      controlURL: fixture.directory.appendingPathComponent("separate-control/writer"),
      recoveryDirectoryURL: fixture.configuration.recoveryDirectoryURL,
      processRole: .mainApplication, storageMode: .localOnly)
    let separate = Planner(configuration: separateConfiguration)
    guard case .ready(let separateSession) = await separate.bootstrap(),
      case .selected(let selection) = await separate.inspectRecovery(
        request: .proposal(
          namespaceId: fixture.namespace.namespaceId, proposalId: fixture.proposal.proposalId)),
      case .snapshot(let empty) = await separate.query(
        .init(session: separateSession, request: .items(.init()))),
      case .noReliableEvidence = await separate.operationStatus(
        session: separateSession, operationId: fixture.proposal.originalOperationId)
    else { throw CancellationError() }
    #expect(selection.datasetId == fixture.namespace.datasetId)
    #expect(selection.evidence == .preparedUnverified && selection.checkpointGeneration == nil)
    #expect(selection.decodedBackup.backup.items.first?.id == fixture.source.id)
    #expect(selection.decodedBackup.backup.items.first?.content.notes == "Monday booking")
    #expect(empty.matchingCount == 0 && empty.rows.isEmpty)
    let reopened = Planner(configuration: separateConfiguration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let stillEmpty) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init()))),
      case .listed(let oldNamespace) = await reopened.inspectRecovery(
        request: .namespace(namespaceId: fixture.namespace.namespaceId))
    else { throw CancellationError() }
    #expect(stillEmpty.matchingCount == 0 && stillEmpty.rows.isEmpty)
    #expect(oldNamespace.preparedProposals.count == 1)
    #expect(oldNamespace.acknowledgedSnapshot?.checkpointGeneration == 1)
  }

  @Test func preparedProposalRemainsSelectableWhenTheCommittedStoreIsMissing() async throws {
    let fixture = try await PreparedNotesProposalFixture.create()
    let missingStoreDirectory = try makePlannerStoreFixtureDirectory()
    try FileManager.default.createDirectory(
      at: missingStoreDirectory, withIntermediateDirectories: true)
    let missingStoreConfiguration = PlannerStorageConfiguration(
      storeURL: missingStoreDirectory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: missingStoreDirectory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: missingStoreDirectory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    try FileManager.default.copyItem(
      at: fixture.configuration.controlURL.deletingLastPathComponent(),
      to: missingStoreConfiguration.controlURL.deletingLastPathComponent())
    try FileManager.default.copyItem(
      at: fixture.configuration.recoveryDirectoryURL,
      to: missingStoreConfiguration.recoveryDirectoryURL)
    let reopened = Planner(configuration: missingStoreConfiguration)
    guard case .unavailable = await reopened.bootstrap(),
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .proposal(
          namespaceId: fixture.namespace.namespaceId, proposalId: fixture.proposal.proposalId)),
      case .selected(let acknowledged) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: fixture.namespace.namespaceId, checkpointGeneration: 1))
    else { throw CancellationError() }
    #expect(selection.evidence == .preparedUnverified && selection.checkpointGeneration == nil)
    #expect(selection.originalOperationId == fixture.proposal.originalOperationId)
    #expect(selection.decodedBackup.backup.items.first?.id == fixture.source.id)
    #expect(selection.decodedBackup.backup.items.first?.content.notes == "Monday booking")
    #expect(acknowledged.portableData == fixture.acknowledged.portableData)
    #expect(acknowledged.decodedBackup.backup.items.first?.content.notes == "Original notes")
    #expect(!FileManager.default.fileExists(atPath: missingStoreConfiguration.storeURL.path))
    #expect(FileManager.default.fileExists(atPath: fixture.configuration.storeURL.path))
  }
}

private struct PreparedNotesProposalFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let source: PlannerEntityReference
  let current: PlannerItemSourceRead
  let namespace: PlannerRecoveryView
  let proposal: PlannerProposalSummary
  let acknowledged: PlannerRecoverySelection

  static func create() async throws -> Self {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    guard
      case .applied(_, .incomplete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: source.id, changes: .init(notes: .set("Monday booking")),
            expectedFieldHashes: [.notes: try #require(original.fieldHashes[.notes])]))
      ).outcome
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    guard
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first, let proposal = namespace.preparedProposals.first,
      case .selected(let acknowledged) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 1))
    else { throw CancellationError() }
    return Self(
      directory: directory, configuration: configuration, planner: planner, session: session,
      source: source, current: current, namespace: namespace, proposal: proposal,
      acknowledged: acknowledged)
  }
}
