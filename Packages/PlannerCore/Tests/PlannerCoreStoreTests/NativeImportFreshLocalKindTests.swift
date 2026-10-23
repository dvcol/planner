import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeImportFreshLocalKindTests {
  @Test(arguments: [101, 201, 301, 501, 601])
  func restoredSourceValuesPreserveOmittedReferencesAndTruthfulRecovery(sourceSuffix: Int)
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
      case .decoded(let seed) = planner.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let initialReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: initialReview.command,
          reviewToken: initialReview.reviewToken)
      ).outcome,
      case .exported(let originalData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let original = try #require(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let originalSources = try #require(original["sources"] as? [[String: Any]])
    let identifier = candidateKindIdentifier(sourceSuffix)
    let originalSource = try #require(originalSources.first { $0["id"] as? String == identifier })
    let kindName = try #require(originalSource["kind"] as? String)
    let kind = try #require(PlannerEntityKind(rawValue: kindName))
    let sourceIdentifier = try #require(UUID(uuidString: identifier))
    let originalLifetime = try #require(originalSource["lifetimeId"] as? String)
    let source = PlannerEntityReference(kind: kind, id: sourceIdentifier)
    guard
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let current = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var incoming = current
    var incomingSource = originalSource
    incomingSource["lifetimeId"] = candidateKindIdentifier(881)
    incomingSource["updatedAt"] = 30.75
    var content = try #require(incomingSource["content"] as? [String: Any])
    content[kind == .item || kind == .itinerary ? "title" : "name"] = "Recovered \(kindName)"
    incomingSource["content"] = content
    if kind == .item { incomingSource["globalDone"] = true }
    if [.item, .list, .itinerary].contains(kind) { incomingSource["archived"] = true }
    incoming["sources"] = [incomingSource]
    for collection in [
      "memberships", "itineraryEntries", "expandedCompletions", "schedules",
      "labelAssociations", "ownedLinks", "contextAliases", "completionChanges",
    ] {
      incoming[collection] = [] as [Any]
    }
    let predecessor: [String: Any] = [
      "kind": kindName, "id": identifier, "lifetimeId": originalLifetime,
    ]
    incoming["restorationFamilies"] = [
      [
        "familyId": candidateKindIdentifier(893), "predecessor": predecessor,
        "candidates": [
          [
            "lifetimeId": candidateKindIdentifier(881), "operationId": candidateKindIdentifier(996),
          ]
        ],
      ]
    ]
    let incomingOutcome = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = incomingOutcome else {
      Issue.record("The represented \(kindName) restoration must decode: \(incomingOutcome)")
      return
    }
    let reviewOutcome = await planner.prepareReview(
      session: session,
      command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    guard case .reviewed(let review) = reviewOutcome else {
      Issue.record(
        "Review the deleted \(kindName) without adopting its candidate: \(reviewOutcome)")
      return
    }
    #expect(review.impact.importDetails?.restorations.map(\.owner.id) == [sourceIdentifier])
    #expect(review.impact.importDetails?.replacements.isEmpty == true)
    guard case .exported(let afterReview) = await planner.exportData(session: session),
      case .listedNamespaces(let preparationNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      let preparationNamespace = preparationNamespaces.first
    else { throw CancellationError() }
    #expect(afterReview == before)
    let namespaceURL = configuration.recoveryDirectoryURL.appendingPathComponent(
      preparationNamespace.namespaceId.uuidString)
    let operationIdentifier = try #require(UUID(uuidString: candidateKindIdentifier(998)))
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: namespaceURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    }
    guard
      case .rejected = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else { throw CancellationError() }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    guard case .exported(let afterFailure) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterFailure == before)
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .incomplete) = response.outcome else {
      Issue.record("Report the applied \(kindName) despite its recovery failure: \(response)")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    guard
      case .appliedRecoveryIncomplete(let pending, _) = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .applied(let repaired, .complete(let checkpoint)) = await planner.retryRecovery(
        session: session, operationId: operationIdentifier
      ).outcome,
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(pending == result && repaired == result)
    let saved = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let savedSources = try #require(saved["sources"] as? [[String: Any]])
    let savedSource = try #require(savedSources.first { $0["id"] as? String == identifier })
    let savedLifetime = try #require(savedSource["lifetimeId"] as? String)
    #expect(savedLifetime != originalLifetime && savedLifetime != candidateKindIdentifier(881))
    #expect(result.importSummary?.restorations.first?.owner.lifetimeId.uuidString == savedLifetime)
    let familyIdentifiers = [
      101: "BF4CA8D3-7AFB-8BF5-A2C3-7F67C76178EC",
      201: "DE6D0B08-E4DF-8F2A-9DBD-91424DB6CEFB",
      301: "C85169EF-4FEE-86AD-AC31-84374FA3B761",
      501: "C8FDEC60-E75B-8F90-A0C7-9721C11610F1",
      601: "76FA2045-D177-8FFB-8A25-84D27471F3A1",
    ]
    var expected = current
    var expectedSource = incomingSource
    expectedSource["lifetimeId"] = savedLifetime
    expected["sources"] = try #require(current["sources"] as? [[String: Any]]) + [expectedSource]
    expected["restorationFamilies"] = [
      [
        "familyId": try #require(familyIdentifiers[sourceSuffix]), "predecessor": predecessor,
        "candidates": [
          ["lifetimeId": savedLifetime, "operationId": operationIdentifier.uuidString]
        ],
      ]
    ]
    let expectedData = try JSONSerialization.data(withJSONObject: expected)
    #expect(try competingValueGraph(after) == competingValueGraph(expectedData))
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(try competingValueGraph(recovered.portableData) == competingValueGraph(expectedData))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeated) = await reopened.prepareReview(
        session: reopenedSession,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
  }
}
