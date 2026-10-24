import Foundation
import PlannerCore
import Testing

struct NativeImportFreshLocalValuesTests {
  @Test(arguments: [false, true], [false, true])
  func restoredValuesCreateALocalLifetimeAndRebindOnlyRepresentedReferences(
    usesPredecessorDerivedFamilyIdentity: Bool, hasClosedLineage: Bool
  ) async throws {
    let currentFixture = hasClosedLineage ? "current-deep" : "current"
    let expectedFixture = hasClosedLineage ? "expected-deep" : "expected"
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let current) = planner.decodeImport(
        try freshLocalValuesFixture(currentFixture)),
      case .reviewed(let initialReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: current)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: initialReview.command,
          reviewToken: initialReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(
      try competingValueGraph(before)
        == freshLocalValuesExpectedGraph(freshLocalValuesFixture(currentFixture)))
    var incomingData = try freshLocalValuesFixture("incoming")
    if usesPredecessorDerivedFamilyIdentity {
      let incomingText = try #require(String(data: incomingData, encoding: .utf8))
      incomingData = Data(
        incomingText.replacingOccurrences(
          of: "00000000-0000-4000-8000-000000000893",
          with: "BF4CA8D3-7AFB-8BF5-A2C3-7F67C76178EC"
        ).utf8)
    }
    let incomingOutcome = planner.decodeImport(incomingData)
    guard case .decoded(let incoming) = incomingOutcome else {
      Issue.record("The literal incoming backup must decode: \(incomingOutcome)")
      return
    }
    let unauthorizedOutcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: incoming, mode: .overwrite))
    guard case .reviewed(let unauthorizedReview) = unauthorizedOutcome else {
      Issue.record("The literal restoration must preview before authority: \(unauthorizedOutcome)")
      return
    }
    let unauthorizedOperation = UUID()
    guard
      case .rejected = await planner.execute(
        .init(
          operationId: unauthorizedOperation, session: session, command: unauthorizedReview.command,
          reviewToken: unauthorizedReview.reviewToken)
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: unauthorizedOperation),
      case .exported(let afterUnauthorized) = await planner.exportData(session: session),
      case .rejected(let changedAuthority) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .applyImport(backup: incoming, mode: .overwrite, restoreDeletedData: true),
          reviewToken: unauthorizedReview.reviewToken)
      ).outcome,
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: incoming, mode: .overwrite, restoreDeletedData: true)),
      case .exported(let afterReview) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(afterUnauthorized == before && afterReview == before)
    #expect(changedAuthority.code == "staleReview")
    let details = try #require(review.impact.importDetails)
    let museumIdentifier = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000101"))
    #expect(details.restorations.map(\.owner.id) == [museumIdentifier])
    #expect(details.restorations.first?.before == nil)
    #expect(
      Set(details.imports.map(\.owner.id)) == [
        UUID(uuidString: "00000000-0000-4000-8000-000000000277")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000602")!,
      ])
    #expect(details.replacements.isEmpty && details.skippedDependents.isEmpty)
    let operationIdentifier = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000998"))
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(after),
      let museum = saved.backup.items.first
    else {
      Issue.record(
        "Fresh restoration must save the literal Museum and represented Tour: \(response)")
      return
    }
    #expect(museum.id == museumIdentifier)
    #expect(museum.lifetimeId != UUID(uuidString: "00000000-0000-4000-8000-000000000811"))
    #expect(museum.lifetimeId != UUID(uuidString: "00000000-0000-4000-8000-000000000813"))
    #expect(result.affected.contains(.init(kind: .item, id: museumIdentifier)))
    let savedSummary = try #require(result.importSummary)
    #expect(savedSummary.restorations.first?.owner.lifetimeId == museum.lifetimeId)
    #expect(savedSummary.restorations.first?.after?.identity.lifetimeId == museum.lifetimeId)
    let tourSummary = try #require(savedSummary.imports.first { $0.owner.kind == .list })
    #expect(tourSummary.dependencies.count == 1)
    #expect(tourSummary.dependencies.first?.id == museumIdentifier)
    #expect(tourSummary.dependencies.first?.lifetimeId == museum.lifetimeId)
    let expectedText = try #require(
      String(data: freshLocalValuesFixture(expectedFixture), encoding: .utf8))
    let expected = Data(
      expectedText.replacingOccurrences(
        of: "$restored-lifetime", with: museum.lifetimeId.uuidString
      ).utf8)
    #expect(try competingValueGraph(after) == freshLocalValuesExpectedGraph(expected))
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(
      try competingValueGraph(recovered.portableData) == freshLocalValuesExpectedGraph(expected))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome
    else { throw CancellationError() }
    let repeatedOutcome = await reopened.prepareReview(
      session: reopenedSession,
      command: .applyImport(backup: incoming, mode: .overwrite, restoreDeletedData: true))
    guard case .reviewed(let repeatedReview) = repeatedOutcome else {
      Issue.record(
        "Reimport must retain the fresh lifetime and complete current history: \(repeatedOutcome)")
      return
    }
    guard
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
          reviewToken: repeatedReview.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
  }
}

private func freshLocalValuesFixture(_ name: String) throws -> Data {
  #if SWIFT_PACKAGE
    let fixtureBundle = Bundle.module
  #else
    let fixtureBundle = Bundle(for: NativeImportFixtureBundle.self)
  #endif
  let fixture = try #require(
    fixtureBundle.url(
      forResource: "fresh-local-restoration-\(name)-v2", withExtension: "json",
      subdirectory: "Fixtures/PortableImport"))
  return try Data(contentsOf: fixture)
}

private func freshLocalValuesExpectedGraph(_ legacyFixtureData: Data) throws -> Data {
  let expected = try canonicalPortableFixtureExpectations(legacyFixtureData)
  return try competingValueGraph(JSONSerialization.data(withJSONObject: expected))
}
