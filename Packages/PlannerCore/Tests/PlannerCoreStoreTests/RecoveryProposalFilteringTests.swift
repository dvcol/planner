import Foundation
import PlannerCore
import Testing

struct RecoveryProposalFilteringTests {
  @Test func completedInvalidProposalGraphDoesNotBlockAnUnrelatedEdit() async throws {
    let fixture = try await ProposalFilteringFixture.create()
    var proposal = fixture.proposal
    proposal["proposedBackup"] = try fixture.duplicateSourceBackup()
    try fixture.write(proposal)

    guard
      case .applied(let result, .complete(let checkpoint)) = try await fixture.editNotes().outcome,
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source)),
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(let observedCheckpoint, let incomplete, let maintenance, let blocked) =
        status.recovery,
      case .listed(let recovery) = await fixture.planner.inspectRecovery(
        request: .namespace(namespaceId: fixture.namespaceId))
    else {
      Issue.record("An acknowledged proposal's obsolete graph must not block the current writer.")
      return
    }
    #expect(result.affected.contains(fixture.source))
    #expect(checkpoint == 2 && observedCheckpoint == 2)
    #expect(incomplete.isEmpty && maintenance.isEmpty && !blocked)
    #expect(current.source == fixture.source && current.content.notes == "Updated notes")
    #expect(recovery.preparedProposals.isEmpty)
  }

  @Test func unresolvedInvalidProposalGraphStillRejectsInspectionAndEdits() async throws {
    let fixture = try await ProposalFilteringFixture.create()
    var proposal = fixture.proposal
    proposal["originalOperationId"] = UUID().uuidString
    try fixture.write(proposal)
    guard
      case .listed(let warm) = await fixture.planner.inspectRecovery(
        request: .namespace(namespaceId: fixture.namespaceId))
    else {
      Issue.record("Valid unresolved evidence must be readable before its graph is damaged.")
      return
    }
    #expect(warm.preparedProposals.count == 1)
    proposal["proposedBackup"] = try fixture.duplicateSourceBackup()
    try fixture.write(proposal)

    guard case .rejected(let failure) = try await fixture.editNotes().outcome,
      case .failed(let inspectionFailure) = await fixture.planner.inspectRecovery(
        request: .proposal(namespaceId: fixture.namespaceId, proposalId: fixture.proposalId)),
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record("An unresolved proposal must retain complete snapshot validation.")
      return
    }
    #expect(failure.code == "recoveryIntegrityFailure")
    #expect(inspectionFailure.code == "recoveryIntegrityFailure")
    #expect(current.content.notes == fixture.original.content.notes)
    #expect(current.updatedAt == fixture.original.updatedAt)
    #expect(current.fieldHashes == fixture.original.fieldHashes)
  }

  enum InvalidHeader: CaseIterable {
    case owner, dataset, evidence, filenameIdentity, duplicateFilename
  }

  @Test(arguments: InvalidHeader.allCases)
  func completedProposalCannotBypassOwnerEvidenceOrFileIdentityChecks(_ fault: InvalidHeader)
    async throws
  {
    let fixture = try await ProposalFilteringFixture.create()
    var proposal = fixture.proposal
    switch fault {
    case .owner: proposal["ownershipBinding"] = "different-owner"
    case .dataset: proposal["datasetId"] = UUID().uuidString
    case .evidence: proposal["evidence"] = "acknowledgedSnapshot"
    case .filenameIdentity: proposal["proposalId"] = UUID().uuidString
    case .duplicateFilename:
      try JSONSerialization.data(withJSONObject: proposal).write(
        to: fixture.proposalURL.deletingLastPathComponent()
          .appendingPathComponent("proposal-duplicate.json"), options: .atomic)
    }
    try fixture.write(proposal)

    guard case .rejected(let failure) = try await fixture.editNotes().outcome,
      case .failed(let inspectionFailure) = await fixture.planner.inspectRecovery(
        request: .namespace(namespaceId: fixture.namespaceId)),
      case .source(.item(let current)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record("Completed operation identity must not authorize malformed proposal headers.")
      return
    }
    #expect(failure.code == "recoveryIntegrityFailure")
    #expect(inspectionFailure.code == "recoveryIntegrityFailure")
    #expect(current.content.notes == fixture.original.content.notes)
    #expect(current.updatedAt == fixture.original.updatedAt)
    #expect(current.fieldHashes == fixture.original.fieldHashes)
  }
}

private struct ProposalFilteringFixture {
  let planner: Planner
  let session: PlannerDatasetSession
  let source: PlannerEntityReference
  let original: PlannerItemSourceRead
  let namespaceId: UUID
  let proposalId: UUID
  let proposalURL: URL
  let proposal: [String: Any]

  /// Saves one Item and retains its actual acknowledged proposal file for controlled faults.
  static func create() async throws -> Self {
    let directory = try makePlannerStoreFixtureDirectory()
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: recoveryDirectory,
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Retained Item", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    #expect(checkpoint == 1)
    let proposalFiles = try FileManager.default.contentsOfDirectory(
      at: recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString),
      includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("proposal-") && $0.pathExtension == "json" }
    #expect(proposalFiles.count == 1)
    let proposalURL = try #require(proposalFiles.first)
    let proposal = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: proposalURL)) as? [String: Any])
    let proposalId = try #require(
      (proposal["proposalId"] as? String).flatMap(UUID.init(uuidString:)))
    return Self(
      planner: planner, session: session, source: source, original: original,
      namespaceId: namespace.namespaceId, proposalId: proposalId, proposalURL: proposalURL,
      proposal: proposal)
  }

  /// Exercises the same public edit path that consults retained prepared proposals.
  func editNotes() async throws -> PlannerOperationResult {
    await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: source.id, changes: .init(notes: .set("Updated notes")),
          expectedFieldHashes: [.notes: try #require(original.fieldHashes[.notes])]))
    )
  }

  /// Keeps the prepared document decodable while violating whole-graph identity uniqueness.
  func duplicateSourceBackup() throws -> [String: Any] {
    var backup = try #require(proposal["proposedBackup"] as? [String: Any])
    let sources = try #require(backup["sources"] as? [[String: Any]])
    backup["sources"] = sources + [try #require(sources.first)]
    return backup
  }

  /// Alters only this fixture's proposal through the existing filesystem boundary.
  func write(_ proposal: [String: Any]) throws {
    try JSONSerialization.data(withJSONObject: proposal).write(to: proposalURL, options: .atomic)
  }
}
