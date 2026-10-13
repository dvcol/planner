import Foundation
import PlannerCore
import Testing

struct NativeImportProviderTests {
  @Test(arguments: ["item", "itinerary"])
  func applePlaceReferencesSurviveNativeImportRecoveryAndReopen(ownerKind: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeImportProviderTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let sourceConfiguration = providerTestConfiguration(directory.appendingPathComponent("source"))
    let source = Planner(configuration: sourceConfiguration)
    var seedGraph = try providerTestGraph(nativeImportFixtureData())
    var seedSources = try #require(seedGraph["sources"] as? [[String: Any]])
    for index in seedSources.indices {
      let origins = try #require(seedSources[index]["contentOrigins"] as? [String: String])
      seedSources[index]["contentOrigins"] = origins.mapValues { _ in "appFallback" }
    }
    seedGraph["sources"] = seedSources
    let seedData = try JSONSerialization.data(withJSONObject: seedGraph)
    let seedOperationIdentifier = UUID()
    guard case .ready(let sourceSession) = await source.bootstrap(),
      case .decoded(let seed) = source.decodeImport(seedData),
      case .reviewed(let seedReview) = await source.prepareReview(
        session: sourceSession, command: .applyImport(backup: seed)),
      case .applied(_, .complete(let seedCheckpoint)) = await source.execute(
        .init(
          operationId: seedOperationIdentifier, session: sourceSession, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let original) = await source.exportData(session: sourceSession)
    else { throw CancellationError() }
    #expect(seedCheckpoint > 0)
    var payload = try providerTestGraph(original)
    var links = try #require(payload["ownedLinks"] as? [[String: Any]])
    let sources = try #require(payload["sources"] as? [[String: Any]])
    let owner = try #require(sources.first { $0["kind"] as? String == ownerKind })
    let ownerIdentifier = try #require(
      (owner["id"] as? String).flatMap(UUID.init(uuidString:)))
    let ownerEntityKind = try #require(PlannerEntityKind(rawValue: ownerKind))
    var link = links[0]
    if ownerKind == "itinerary" {
      link["id"] = "00000000-0000-4000-8000-000000000753"
      link["lifetimeId"] = "00000000-0000-4000-8000-000000000753"
      link["owner"] = [
        "id": try #require(owner["id"] as? String), "kind": ownerKind,
        "lifetimeId": try #require(owner["lifetimeId"] as? String),
      ]
    }
    link["originalUrl"] = "https://maps.apple.com/?q=Nezu%20Museum"
    link["kind"] = "appleMaps"
    link["providerReference"] = ["kind": "applePlaceId", "value": "fixture-nezu-place"]
    if ownerKind == "item" {
      links[0] = link
    } else {
      links.append(link)
    }
    payload["ownedLinks"] = links
    let linkIdentifier = try #require((link["id"] as? String).flatMap(UUID.init(uuidString:)))
    let configuration = providerTestConfiguration(directory.appendingPathComponent("destination"))
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: payload)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: incoming))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let applied, .complete(let checkpoint)) = response.outcome,
      case .exported(let saved) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "Native provider import must save its full graph: \(response); seed: \(directory.path)")
      return
    }
    #expect(NSDictionary(dictionary: try providerTestGraph(saved)).isEqual(to: payload))
    #expect(
      NSDictionary(dictionary: try providerTestGraph(recovered.portableData)).isEqual(to: payload))
    let reference = PlannerEntityReference(kind: ownerEntityKind, id: ownerIdentifier)
    let reads = try await providerTestLinks(planner, session: session, owner: reference)
    let actual = try #require(reads.first { $0.linkId == linkIdentifier })
    #expect(actual.providerReference?.kind == .applePlaceId)
    #expect(actual.providerReference?.value == "fixture-nezu-place")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .exported(let afterReplay) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == saved && afterReplay == saved)
    #expect(replayed == applied && replayCheckpoint == checkpoint)
    try await providerTestRetainedImports(
      planner, session: session, payload: payload, linkIdentifier: linkIdentifier)
    try await providerTestCompletion(
      planner, session: session, owner: reference, linkIdentifier: linkIdentifier)
    try await providerTestOrdinaryEdits(
      planner, session: session, configuration: configuration, owner: reference,
      linkIdentifier: linkIdentifier)
  }
}

private func providerTestConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
  .init(
    storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
    controlURL: directory.appendingPathComponent("control/writer"),
    recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
    processRole: .mainApplication, storageMode: .localOnly)
}

private func providerTestGraph(_ data: Data) throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func providerTestLinks(
  _ planner: Planner, session: PlannerDatasetSession, owner: PlannerEntityReference
) async throws -> [PlannerOwnedLinkRead] {
  switch await planner.read(session: session, request: .source(owner)) {
  case .source(.item(let item)): return item.content.links
  case .source(.itinerary(let itinerary)): return itinerary.content.links
  default: throw CancellationError()
  }
}

private func providerTestRetainedImports(
  _ planner: Planner, session: PlannerDatasetSession, payload: [String: Any], linkIdentifier: UUID
) async throws {
  let scenarios: [(mode: PlannerImportMode, value: String?)] = [
    (.skip, "fixture-other-place"), (.overwrite, "fixture-other-place"),
    (.overwrite, nil), (.overwrite, "fixture-nezu-place"),
  ]
  var expected = payload
  for scenario in scenarios {
    var incoming = payload
    var links = try #require(incoming["ownedLinks"] as? [[String: Any]])
    let index = try #require(links.firstIndex { $0["id"] as? String == linkIdentifier.uuidString })
    if let value = scenario.value {
      links[index]["providerReference"] = ["kind": "applePlaceId", "value": value]
    } else {
      links[index]["providerReference"] = NSNull()
    }
    incoming["ownedLinks"] = links
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: scenario.mode)),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    if scenario.mode == .overwrite { expected = incoming }
    let saved = try await providerTestCheckpoint(planner, session: session, generation: checkpoint)
    #expect(NSDictionary(dictionary: try providerTestGraph(saved)).isEqual(to: expected))
  }
}

private func providerTestOrdinaryEdits(
  _ planner: Planner, session: PlannerDatasetSession, configuration: PlannerStorageConfiguration,
  owner: PlannerEntityReference, linkIdentifier: UUID
) async throws {
  for replaceURL in [false, true] {
    let command = try await providerTestLinkEdit(
      planner, session: session, owner: owner, linkIdentifier: linkIdentifier,
      replaceURL: replaceURL)
    guard
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    let saved = try await providerTestCheckpoint(planner, session: session, generation: checkpoint)
    let reads = try await providerTestLinks(planner, session: session, owner: owner)
    let retained = try #require(reads.first { $0.linkId == linkIdentifier })
    #expect(retained.label == "Reviewed bookmark")
    let expectedReference = replaceURL ? nil : "fixture-nezu-place"
    #expect(retained.providerReference?.value == expectedReference)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == saved)
  }
}

private func providerTestCompletion(
  _ planner: Planner, session: PlannerDatasetSession, owner: PlannerEntityReference,
  linkIdentifier: UUID
) async throws {
  let operation: PlannerOperation
  if owner.kind == .item {
    operation = .init(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .globalItem(itemId: owner.id), done: true))
  } else {
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .setBulkCompletion(scope: .itinerary(itineraryId: owner.id), done: true))
    else { throw CancellationError() }
    operation = .init(
      operationId: UUID(), session: session, command: review.command,
      reviewToken: review.reviewToken)
  }
  guard case .applied(_, .complete(let checkpoint)) = await planner.execute(operation).outcome
  else {
    throw CancellationError()
  }
  _ = try await providerTestCheckpoint(planner, session: session, generation: checkpoint)
  let links = try await providerTestLinks(planner, session: session, owner: owner)
  #expect(
    links.first { $0.linkId == linkIdentifier }?.providerReference?.value == "fixture-nezu-place")
}

private func providerTestLinkEdit(
  _ planner: Planner, session: PlannerDatasetSession, owner: PlannerEntityReference,
  linkIdentifier: UUID, replaceURL: Bool
) async throws -> PlannerCommand {
  switch await planner.read(session: session, request: .source(owner)) {
  case .source(.item(let item)):
    return .editItem(
      sourceId: owner.id,
      changes: .init(
        links: .set(
          providerTestLinkInputs(item.content.links, target: linkIdentifier, replaceURL: replaceURL)
        )),
      expectedFieldHashes: [.links: try #require(item.fieldHashes[.links])])
  case .source(.itinerary(let itinerary)):
    return .editItinerary(
      sourceId: owner.id,
      changes: .init(
        links: .set(
          providerTestLinkInputs(
            itinerary.content.links, target: linkIdentifier, replaceURL: replaceURL))),
      expectedFieldHashes: [.links: try #require(itinerary.fieldHashes[.links])])
  default: throw CancellationError()
  }
}

private func providerTestLinkInputs(
  _ links: [PlannerOwnedLinkRead], target: UUID, replaceURL: Bool
) -> [PlannerLinkInput] {
  links.reversed().map { link in
    if link.linkId != target {
      return .init(linkId: link.linkId, originalUrl: link.originalUrl, label: link.label)
    }
    let url = replaceURL ? "https://maps.apple.com/?q=Tokyo%20Station" : link.originalUrl
    return .init(linkId: link.linkId, originalUrl: url, label: "Reviewed bookmark")
  }
}

private func providerTestCheckpoint(
  _ planner: Planner, session: PlannerDatasetSession, generation: Int64
) async throws -> Data {
  guard case .exported(let exported) = await planner.exportData(session: session),
    case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
    let namespace = namespaces.first,
    case .selected(let recovered) = await planner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: namespace.namespaceId, checkpointGeneration: generation))
  else { throw CancellationError() }
  #expect(
    NSDictionary(dictionary: try providerTestGraph(exported)).isEqual(
      to: try providerTestGraph(recovered.portableData)))
  return exported
}
