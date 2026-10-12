import Foundation
import PlannerCore
import SwiftData
import Testing

struct RecoveryCheckpointRetryAdmissionTests {
  @Test func continuedFileFailureRetainsAppliedEvidenceAndMutationBlockUntilRetrySucceeds()
    async throws
  {
    let fixture = try await CheckpointRetryFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let pending = try await fixture.applyWithRecoveryFailure(
      .setCompletion(scope: .globalItem(itemId: fixture.source.id), done: true))
    let before = try await fixture.currentItem()
    let recovery = fixture.configuration.recoveryDirectoryURL
    let retained = fixture.directory.appendingPathComponent("retained-during-retry")
    try FileManager.default.moveItem(at: recovery, to: retained)
    try Data("Recovery remains obstructed during retry.".utf8).write(to: recovery)
    let response = await fixture.planner.retryRecovery(
      session: fixture.session, operationId: pending.operationId)
    try FileManager.default.removeItem(at: recovery)
    try FileManager.default.moveItem(at: retained, to: recovery)
    guard case .applied(let retainedResult, .incomplete(let failure)) = response.outcome,
      case .appliedRecoveryIncomplete(let statusResult, _) = await fixture.planner.operationStatus(
        session: fixture.session, operationId: pending.operationId),
      case .rejected(let blocked) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItem(content: .init(title: "Must remain blocked")))
      )
      .outcome
    else { throw CancellationError() }
    #expect(response.operationId == pending.operationId)
    #expect(retainedResult == pending.result && statusResult == pending.result)
    #expect(failure.code == "recoveryIncomplete" && !failure.message.isEmpty)
    #expect(blocked.code == "mutationBlocked")
    let afterFailure = try await fixture.currentItem()
    #expect(afterFailure.content.notes == "Original notes" && afterFailure.state.globalDone == true)
    #expect(
      afterFailure.updatedAt == before.updatedAt && afterFailure.fieldHashes == before.fieldHashes)
    #expect(
      try await fixture.acknowledgement().portableData == fixture.originalRecovery.portableData)
    guard
      case .applied(let recovered, .complete(let checkpoint)) = await fixture.planner.retryRecovery(
        session: fixture.session, operationId: pending.operationId
      ).outcome
    else { throw CancellationError() }
    #expect(recovered == pending.result && checkpoint == 2)
    let afterSuccess = try await fixture.currentItem()
    #expect(afterSuccess.updatedAt == before.updatedAt && afterSuccess.state.globalDone == true)
  }

  @Test(arguments: ["unknown", "preparedOnly", "foreignSession", "separateDataset"])
  func unknownUnverifiedOrUnauthorizedRetryCannotAcknowledgeOrChangeData(_ scenario: String)
    async throws
  {
    let fixture = try await CheckpointRetryFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let pending = try await fixture.applyWithRecoveryFailure(
      .setCompletion(scope: .globalItem(itemId: fixture.source.id), done: true))
    let before = try await fixture.currentItem()
    var requestedPlanner = fixture.planner
    var requestedSession = fixture.session
    var operationIdentifier = UUID()
    var expectedCode = "recoveryNotApplied"
    switch scenario {
    case "unknown": break
    case "preparedOnly":
      let proposalIdentifier = UUID()
      var backup = try #require(
        JSONSerialization.jsonObject(with: fixture.originalRecovery.portableData) as? [String: Any])
      var sources = try #require(backup["sources"] as? [[String: Any]])
      sources[0]["globalDone"] = true
      backup["sources"] = sources
      let proposal: [String: Any] = [
        "proposalId": proposalIdentifier.uuidString,
        "originalOperationId": operationIdentifier.uuidString,
        "datasetId": fixture.originalRecovery.datasetId.uuidString,
        "ownershipBinding": fixture.originalRecovery.ownershipBinding,
        "proposedBackup": backup,
        "payloadDigest": "sha256-payload-v1:" + String(repeating: "0", count: 64),
        "evidence": "preparedUnverified",
      ]
      let proposalURL = fixture.configuration.recoveryDirectoryURL
        .appendingPathComponent(fixture.originalRecovery.namespaceId.uuidString)
        .appendingPathComponent("proposal-\(proposalIdentifier.uuidString).json")
      try JSONSerialization.data(withJSONObject: proposal).write(to: proposalURL, options: .atomic)
      guard
        case .preparedUnverified(let summary) = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { throw CancellationError() }
      #expect(summary.proposalId == proposalIdentifier && summary.requiresFreshReview)
    case "foreignSession":
      let otherFacade = Planner(configuration: fixture.configuration)
      guard case .ready(let foreignSession) = await otherFacade.bootstrap() else {
        throw CancellationError()
      }
      requestedSession = foreignSession
      operationIdentifier = pending.operationId
      expectedCode = "staleDatasetSession"
    case "separateDataset":
      let otherConfiguration = PlannerStorageConfiguration(
        storeURL: fixture.directory.appendingPathComponent("other-store/Planner.sqlite"),
        controlURL: fixture.directory.appendingPathComponent("other-control/writer"),
        recoveryDirectoryURL: fixture.directory.appendingPathComponent("other-recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      requestedPlanner = Planner(configuration: otherConfiguration)
      guard case .ready(let otherSession) = await requestedPlanner.bootstrap() else {
        throw CancellationError()
      }
      requestedSession = otherSession
      operationIdentifier = pending.operationId
    default: throw CancellationError()
    }
    let response = await requestedPlanner.retryRecovery(
      session: requestedSession, operationId: operationIdentifier)
    guard case .rejected(let failure) = response.outcome,
      case .appliedRecoveryIncomplete(let statusResult, _) = await fixture.planner.operationStatus(
        session: fixture.session, operationId: pending.operationId)
    else { throw CancellationError() }
    #expect(response.operationId == operationIdentifier)
    #expect(failure.code == expectedCode && !failure.message.isEmpty)
    #expect(statusResult == pending.result)
    let current = try await fixture.currentItem()
    #expect(current.source == before.source && current.sourceLifetimeId == before.sourceLifetimeId)
    #expect(current.updatedAt == before.updatedAt && current.fieldHashes == before.fieldHashes)
    #expect(current.content.notes == "Original notes" && current.state.globalDone == true)
    #expect(
      try await fixture.acknowledgement().portableData == fixture.originalRecovery.portableData)
    if scenario == "preparedOnly" {
      guard
        case .preparedUnverified = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { throw CancellationError() }
    }
    if scenario == "separateDataset" {
      guard
        case .snapshot(let empty) = await requestedPlanner.query(
          .init(session: requestedSession, request: .items(.init())))
      else { throw CancellationError() }
      #expect(empty.matchingCount == 0 && empty.rows.isEmpty)
    }
  }

  @Test func concurrentFacadeRetriesPublishOneCheckpointAndPreserveOriginalAppliedResult()
    async throws
  {
    let fixture = try await CheckpointRetryFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let pending = try await fixture.applyWithRecoveryFailure(
      .setCompletion(scope: .globalItem(itemId: fixture.source.id), done: true))
    let secondPlanner = Planner(configuration: fixture.configuration)
    guard case .ready(let secondSession) = await secondPlanner.bootstrap() else {
      throw CancellationError()
    }
    async let first = fixture.planner.retryRecovery(
      session: fixture.session, operationId: pending.operationId)
    async let second = secondPlanner.retryRecovery(
      session: secondSession, operationId: pending.operationId)
    let responses = await [first, second]
    for response in responses {
      guard case .applied(let result, .complete(let checkpoint)) = response.outcome else {
        throw CancellationError()
      }
      #expect(response.operationId == pending.operationId)
      #expect(result == pending.result && checkpoint == 2)
    }
    let recovered = try await fixture.acknowledgement()
    #expect(recovered.checkpointGeneration == 2)
    #expect(recovered.decodedBackup.backup.items.count == 1)
    #expect(recovered.decodedBackup.backup.items.first?.globalDone == true)
  }

  @Test func bulkCheckpointRetryPreservesEverySupportedGraphGroupAndPriorDeletionMarker()
    async throws
  {
    let fixture = try await CheckpointRetryFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let category = try #require(
      try await fixture.save(.createCategory(content: .init(name: "Food"))).generated.first)
    let tag = try #require(
      try await fixture.save(.createTag(content: .init(name: "Rain"))).generated.first)
    let original = try await fixture.currentItem()
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.source.id,
        changes: .init(
          location: .set(.init(displayName: "Hotel", formattedAddress: "Tokyo", coordinate: nil)),
          estimate: .set(.init(minutes: 120, displayUnit: .hour)),
          links: .set([.init(originalUrl: "https://example.com/hotel", label: "Website")]),
          categoryIds: .set([category.id])),
        expectedFieldHashes: [
          .location: try #require(original.fieldHashes[.location]),
          .estimate: try #require(original.fieldHashes[.estimate]),
          .links: try #require(original.fieldHashes[.links]),
          .categoryIds: try #require(original.fieldHashes[.categoryIds]),
        ]))
    let park = try #require(
      try await fixture.save(.createItem(content: .init(title: "Park", tagIds: [tag.id])))
        .generated.first)
    _ = try await fixture.save(.setArchive(source: park, archived: true))
    let list = try #require(
      try await fixture.save(.createList(content: .init(name: "Wishlist"))).generated.first)
    let hotelMembership = try #require(
      try await fixture.save(
        .addMembership(itemId: fixture.source.id, listId: list.id, placement: .last)
      )
      .generatedReferences.first)
    _ = try await fixture.save(.addMembership(itemId: park.id, listId: list.id, placement: .last))
    let itinerary = try #require(
      try await fixture.save(
        .createItinerary(
          content: .init(
            title: "Weekend", notes: "Plan notes",
            links: [.init(originalUrl: "https://example.com/plan")],
            categoryIds: [category.id], tagIds: [tag.id]))
      )
      .generated.first)
    var entries: [UUID] = []
    for source in [fixture.source, list, fixture.source] {
      let reference = try #require(
        try await fixture.save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        )
        .generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      entries.append(identifier)
    }
    guard case .membership(let membershipIdentifier, _, _) = hotelMembership else {
      throw CancellationError()
    }
    _ = try await fixture.save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: entries[1],
            membershipId: membershipIdentifier)), done: true))
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400.25)
    let hotelSchedule = try #require(
      try await fixture.save(
        .createSchedule(
          source: fixture.source,
          form: .timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo"))
      )
      .generated.first)
    let itineraryForm = PlannerScheduleForm.allDay(
      start: .init(year: 2026, month: 10, day: 9), end: .init(year: 2026, month: 10, day: 11))
    let itinerarySchedule = try #require(
      try await fixture.save(.createSchedule(source: itinerary, form: itineraryForm)).generated
        .first)
    let removedSchedule = try #require(
      try await fixture.save(
        .createSchedule(
          source: fixture.source,
          form: .timed(start: start, end: nil, planningTimeZone: "Europe/Paris"))
      )
      .generated.first)
    _ = try await fixture.save(.removeSchedule(scheduleId: removedSchedule.id))
    let command = PlannerCommand.setBulkCompletion(scope: .list(listId: list.id), done: true)
    guard
      case .reviewed(let review) = await fixture.planner.prepareReview(
        session: fixture.session, command: command)
    else { throw CancellationError() }
    let pending = try await fixture.applyWithRecoveryFailure(
      command, reviewToken: review.reviewToken)
    guard
      case .listedNamespaces(let namespaces) = await fixture.planner.inspectRecovery(
        request: .namespaces),
      let namespace = namespaces.first,
      let proposal = namespace.preparedProposals.first,
      case .selected(let proposed) = await fixture.planner.inspectRecovery(
        request: .proposal(namespaceId: namespace.namespaceId, proposalId: proposal.proposalId)),
      case .exported(let pendingExport) = await fixture.planner.exportData(session: fixture.session),
      case .applied(let result, .complete(let checkpoint)) = await fixture.planner.retryRecovery(
        session: fixture.session, operationId: pending.operationId
      ).outcome
    else { throw CancellationError() }
    #expect(result == pending.result)
    #expect(
      try normalizedPortableSnapshot(pendingExport)
        .isEqual(normalizedPortableSnapshot(proposed.portableData)))
    let exportedObject = try #require(
      JSONSerialization.jsonObject(with: pendingExport) as? [String: Any])
    #expect((exportedObject["ownedLinks"] as? [[String: Any]])?.count == 2)
    let recovered = try await fixture.acknowledgement()
    guard
      case .exported(let repairedExport) = await fixture.planner.exportData(
        session: fixture.session)
    else { throw CancellationError() }
    #expect(
      try normalizedPortableSnapshot(repairedExport)
        .isEqual(normalizedPortableSnapshot(recovered.portableData)))
    #expect(recovered.checkpointGeneration == checkpoint)
    #expect(
      try normalizedPortableSnapshot(recovered.portableData)
        .isEqual(normalizedPortableSnapshot(proposed.portableData)))
    let backup = recovered.decodedBackup.backup
    #expect(backup.sources.count == 6 && backup.items.count == 2)
    #expect(backup.memberships.count == 2 && backup.memberships.allSatisfy(\.localDone))
    #expect(backup.itineraryEntries.sorted { $0.rank < $1.rank }.map(\.id) == entries)
    #expect(
      backup.expandedCompletions.count == 1 && backup.expandedCompletions.first?.localDone == true)
    #expect(backup.labelAssociations.count == 4)
    #expect(backup.deletionMarkers.count == 1)
    #expect(backup.schedules.count == 2)
    #expect(
      backup.schedules.first { $0.id == hotelSchedule.id }?.form
        == .timed(
          start: start, end: nil, planningTimeZone: "Asia/Tokyo"))
    #expect(backup.schedules.first { $0.id == itinerarySchedule.id }?.form == itineraryForm)
    #expect(backup.items.first { $0.id == park.id }?.archived == true)
    #expect(backup.items.first { $0.id == fixture.source.id }?.content.estimate?.minutes == 120)
    for (scope, done, total) in [
      (PlannerItemQuery.Scope.list(list.id), Int64(2), Int64(2)),
      (.itinerary(itinerary.id), Int64(1), Int64(4)),
    ] {
      guard
        case .snapshot(let snapshot) = await fixture.planner.query(
          .init(
            session: fixture.session,
            request: .items(.init(scope: scope, completion: .all, archive: .all))))
      else { throw CancellationError() }
      #expect(
        snapshot.progress.first?.doneCount == done && snapshot.progress.first?.totalCount == total)
    }
  }
}

private struct CheckpointRetryFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let source: PlannerEntityReference
  let originalRecovery: PlannerRecoverySelection

  static func create() async throws -> Self {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
      )
      .outcome,
      let source = creation.generated.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return Self(
      directory: directory, configuration: configuration, planner: planner, session: session,
      source: source, originalRecovery: recovery)
  }

  func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return result
  }

  func applyWithRecoveryFailure(_ command: PlannerCommand, reviewToken: PlannerReviewToken? = nil)
    async throws -> (operationId: UUID, result: PlannerAppliedResult)
  {
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    guard
      case .applied(let result, .incomplete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: command,
          reviewToken: reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    return (operationIdentifier, result)
  }

  func currentItem() async throws -> PlannerItemSourceRead {
    guard
      case .source(.item(let item)) = await planner.read(session: session, request: .source(source))
    else { throw CancellationError() }
    return item
  }

  func acknowledgement() async throws -> PlannerRecoverySelection {
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return recovery
  }
}

/// Root record arrays have no display order; ranks and identities carry the saved order.
private func normalizedPortableSnapshot(_ data: Data) throws -> NSDictionary {
  var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  for (key, value) in object {
    guard let records = value as? [[String: Any]] else { continue }
    let encoded = try records.map { record in
      (
        bytes: try JSONSerialization.data(withJSONObject: record, options: .sortedKeys),
        record: record
      )
    }
    object[key] = encoded.sorted { first, second in
      first.bytes.lexicographicallyPrecedes(second.bytes)
    }
    .map(\.record)
  }
  return NSDictionary(dictionary: object)
}
