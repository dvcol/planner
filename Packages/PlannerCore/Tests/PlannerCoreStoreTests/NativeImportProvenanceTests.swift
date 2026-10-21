import Foundation
import PlannerCore
import Testing

struct NativeImportProvenanceTests {
  @Test(arguments: ["item", "list", "itinerary", "category", "tag"])
  func importedFallbackOriginsSurviveNativeChangesAndRecovery(kind: String) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let sourceConfiguration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("source/store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("source/control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("source/recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let source = Planner(configuration: sourceConfiguration)
    guard case .ready(let sourceSession) = await source.bootstrap(),
      case .decoded(let fixture) = source.decodeImport(try nativeImportFixtureData()),
      case .reviewed(let seed) = await source.prepareReview(
        session: sourceSession, command: .applyImport(backup: fixture)),
      case .applied(_, .complete) = await source.execute(
        .init(
          operationId: UUID(), session: sourceSession, command: seed.command,
          reviewToken: seed.reviewToken)
      ).outcome,
      case .exported(let original) = await source.exportData(session: sourceSession)
    else { throw CancellationError() }
    var payload = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    var sources = try #require(payload["sources"] as? [[String: Any]])
    let index = try #require(sources.firstIndex { $0["kind"] as? String == kind })
    var origins = try #require(sources[index]["contentOrigins"] as? [String: String])
    origins = origins.mapValues { _ in "appFallback" }
    let originField = kind == "item" || kind == "itinerary" ? "title" : "name"
    let sourceIdentifier = try #require(
      (sources[index]["id"] as? String).flatMap(UUID.init(uuidString:)))
    let sourceKind = try #require(PlannerEntityKind(rawValue: kind))
    let reference = PlannerEntityReference(kind: sourceKind, id: sourceIdentifier)
    sources[index]["contentOrigins"] = origins
    payload["sources"] = sources
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("destination/store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("destination/control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("destination/recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: payload)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: incoming))
    else { throw CancellationError() }
    let response = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete(let checkpoint)) = response.outcome,
      case .exported(let saved) = await planner.exportData(session: session),
      case .decoded(let decoded) = planner.decodeImport(saved),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId,
          checkpointGeneration: checkpoint))
    else {
      Issue.record("Native import must retain the declared fallback origin: \(response)")
      return
    }
    #expect(try provenanceOrigins(decoded.backup, reference: reference) == origins)
    let savedGraph = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: savedGraph).isEqual(to: payload))
    #expect(NSDictionary(dictionary: recoveredGraph).isEqual(to: payload))
    let item = try #require(decoded.backup.items.first)
    guard
      case .applied(_, .complete(let completedCheckpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .exported(let completedData) = await planner.exportData(session: session),
      case .decoded(let completed) = planner.decodeImport(completedData),
      case .selected(let completedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId,
          checkpointGeneration: completedCheckpoint))
    else { throw CancellationError() }
    #expect(try provenanceOrigins(completed.backup, reference: reference) == origins)
    #expect(
      try provenanceOrigins(completedRecovery.decodedBackup.backup, reference: reference) == origins
    )
    if sourceKind == .list || sourceKind == .itinerary {
      if sourceKind == .itinerary {
        guard
          case .applied(_, .complete) = await planner.execute(
            .init(
              operationId: UUID(), session: session,
              command: .createSchedule(
                source: reference,
                form: .timed(
                  start: Date(timeIntervalSince1970: 1_791_376_800), end: nil,
                  planningTimeZone: "Asia/Tokyo")))
          ).outcome
        else { throw CancellationError() }
      }
      let scope: PlannerBulkScope
      if sourceKind == .list {
        scope = .list(listId: sourceIdentifier)
      } else {
        scope = .itinerary(itineraryId: sourceIdentifier)
      }
      guard
        case .reviewed(let bulk) = await planner.prepareReview(
          session: session, command: .setBulkCompletion(scope: scope, done: true)),
        case .applied(_, .complete(let bulkCheckpoint)) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: bulk.command,
            reviewToken: bulk.reviewToken)
        ).outcome,
        case .exported(let bulkData) = await planner.exportData(session: session),
        case .selected(let bulkRecovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId,
            checkpointGeneration: bulkCheckpoint))
      else { throw CancellationError() }
      #expect(
        try provenanceOrigins(bulkRecovery.decodedBackup.backup, reference: reference) == origins)
      let bulkGraph = try #require(JSONSerialization.jsonObject(with: bulkData) as? [String: Any])
      let bulkRecoveryGraph = try #require(
        JSONSerialization.jsonObject(
          with: bulkRecovery.portableData) as? [String: Any])
      #expect(NSDictionary(dictionary: bulkGraph).isEqual(to: bulkRecoveryGraph))
    }
    let edit = try await provenanceFieldEdit(planner, session: session, source: reference)
    guard
      case .applied(_, .complete(let editedCheckpoint)) = await planner.execute(
        .init(operationId: UUID(), session: session, command: edit)
      ).outcome,
      case .exported(let editedData) = await planner.exportData(session: session),
      case .decoded(let edited) = planner.decodeImport(editedData),
      case .selected(let editedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId,
          checkpointGeneration: editedCheckpoint))
    else { throw CancellationError() }
    var editedOrigins = origins
    editedOrigins[originField] = "independent"
    #expect(try provenanceOrigins(edited.backup, reference: reference) == editedOrigins)
    #expect(
      try provenanceOrigins(editedRecovery.decodedBackup.backup, reference: reference)
        == editedOrigins)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == editedData)
  }
}

private func provenanceOrigins(_ backup: PlannerPortableBackup, reference: PlannerEntityReference)
  throws -> [String: String]
{
  let source = try #require(
    backup.sources.first { $0.id == reference.id && $0.kind == reference.kind })
  switch source {
  case .item(let value): return value.contentOrigins
  case .list(let value): return value.contentOrigins
  case .itinerary(let value): return value.contentOrigins
  case .category(let value): return value.contentOrigins
  case .tag(let value): return value.contentOrigins
  }
}

private func provenanceFieldEdit(
  _ planner: Planner, session: PlannerDatasetSession,
  source: PlannerEntityReference
) async throws -> PlannerCommand {
  switch await planner.read(session: session, request: .source(source)) {
  case .source(.item(let value)):
    return .editItem(
      sourceId: source.id, changes: .init(title: .set(value.content.title)),
      expectedFieldHashes: [.title: try #require(value.fieldHashes[.title])])
  case .source(.list(let value)):
    return .editList(
      sourceId: source.id, changes: .init(name: .set(value.content.name)),
      expectedFieldHashes: [.name: try #require(value.fieldHashes[.name])])
  case .source(.itinerary(let value)):
    return .editItinerary(
      sourceId: source.id, changes: .init(title: .set(value.content.title)),
      expectedFieldHashes: [.title: try #require(value.fieldHashes[.title])])
  case .source(.category(let value)):
    return .editCategory(
      sourceId: source.id, changes: .init(name: .set(value.content.name)),
      expectedFieldHashes: [.name: try #require(value.fieldHashes[.name])])
  case .source(.tag(let value)):
    return .editTag(
      sourceId: source.id, changes: .init(name: .set(value.content.name)),
      expectedFieldHashes: [.name: try #require(value.fieldHashes[.name])])
  default: throw CancellationError()
  }
}
