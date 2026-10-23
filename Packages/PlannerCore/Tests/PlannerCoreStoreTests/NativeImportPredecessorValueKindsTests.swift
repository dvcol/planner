import Foundation
import PlannerCore
import Testing

struct NativeImportPredecessorValueKindsTests {
  @Test(arguments: [1, 2])
  func predecessorValuesPreserveEveryLiveSourceKindAndItsCompleteLineage(restorationCount: Int)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func apply(_ backup: PlannerDecodedBackup, restoring: Bool = false) async throws {
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session,
          command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: restoring)),
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: review.command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    var seed = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let fixtureSources = try #require(seed["sources"] as? [[String: Any]])
    for key in seed.keys where key != "format" && key != "formatVersion" { seed[key] = [] }
    seed["sources"] = try ["item", "list", "itinerary", "category", "tag"].map { kind in
      try #require(fixtureSources.first { $0["kind"] as? String == kind })
    }
    guard
      case .decoded(let initial) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: seed))
    else { throw CancellationError() }
    try await apply(initial)
    guard case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData)
    else { throw CancellationError() }
    for _ in 0..<restorationCount {
      for source in original.backup.sources {
        guard
          case .reviewed(let deletion) = await planner.prepareReview(
            session: session,
            command: .deleteSource(source: .init(kind: source.kind, id: source.id))),
          case .applied(_, .complete) = await planner.execute(
            .init(
              operationId: UUID(), session: session, command: deletion.command,
              reviewToken: deletion.reviewToken)
          ).outcome
        else { throw CancellationError() }
        try await apply(original, restoring: true)
      }
    }
    guard case .exported(let restoredData) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    var changed = try #require(JSONSerialization.jsonObject(with: restoredData) as? [String: Any])
    let restoredSources = try #require(changed["sources"] as? [[String: Any]])
    changed["sources"] = try restoredSources.map { originalSource in
      var source = originalSource
      let kind = try #require(source["kind"] as? String)
      var content = try #require(source["content"] as? [String: Any])
      let nameField = content["title"] == nil ? "name" : "title"
      content[nameField] = "Current \(kind)"
      let fields: [String: Any] = [
        "notes": "Current notes", "subtitle": "Current subtitle", "iconName": "star",
        "estimate": ["minutes": "75", "displayUnit": "minute"],
        "manualEstimate": ["minutes": "75", "displayUnit": "minute"],
        "color": ["red": 0.125, "green": 0.5, "blue": 0.75, "alpha": 1.0],
        "location": [
          "displayName": "Current place", "formattedAddress": "Tokyo",
          "coordinate": ["latitude": 35.0, "longitude": 139.0],
        ],
      ]
      for (field, value) in fields where content[field] != nil { content[field] = value }
      var origins = try #require(source["contentOrigins"] as? [String: String])
      for field in ["title", "name", "subtitle", "notes", "location"] where content[field] != nil {
        origins[field] = "independent"
      }
      source["content"] = content
      source["contentOrigins"] = origins
      source["createdAt"] = 60.0
      source["updatedAt"] = 70.0
      if kind == "item" { source["globalDone"] = true }
      if ["item", "list", "itinerary"].contains(kind) { source["archived"] = true }
      return source
    }
    guard
      case .decoded(let changedBackup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: changed))
    else { throw CancellationError() }
    try await apply(changedBackup)
    guard case .exported(let before) = await planner.exportData(session: session),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: original, mode: .overwrite))
    else { throw CancellationError() }
    let details = try #require(review.impact.importDetails)
    #expect(details.replacements.count == 5)
    #expect(
      details.restorations.isEmpty && details.imports.isEmpty && details.referenceChanges.isEmpty)
    #expect(
      Set(details.replacements.map(\.owner.kind.rawValue)) == [
        "item", "list", "itinerary", "category", "tag",
      ])
    #expect(details.replacements.allSatisfy { $0.before?.identity == $0.after?.identity })
    guard case .exported(let afterReview) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterReview == before)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded = planner.decodeImport(after),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Overwrite each source's old values while preserving live lineage: \(response)")
      return
    }
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let originalObject = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let originalSources = try #require(originalObject["sources"] as? [[String: Any]])
    expected["sources"] = try originalSources.map { originalSource in
      var source = originalSource
      let live = try #require(
        restoredSources.first { $0["id"] as? String == source["id"] as? String })
      #expect(source["lifetimeId"] as? String != live["lifetimeId"] as? String)
      source["lifetimeId"] = live["lifetimeId"]
      return source
    }
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    let recoveryObject = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveryObject).isEqual(to: expected))
    #expect(
      result.importSummary?.replacements.count == 5
        && result.importSummary?.restorations.isEmpty == true)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeated) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: original, mode: .overwrite)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.impact.importDetails?.replacements.isEmpty == true)
  }
}
