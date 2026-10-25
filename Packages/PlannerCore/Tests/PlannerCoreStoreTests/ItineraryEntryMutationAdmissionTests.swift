import Foundation
import PlannerCore
import Testing

struct ItineraryEntryMutationAdmissionTests {
  @Test func invalidOwnersEntriesAndAnchorsLeaveTheGraphAndRecoveryUnchanged() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let other = try #require(
      try await save(.createItinerary(content: .init(title: "Other"))).generated.first)
    guard
      case .itineraryEntry(let entryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let foreignId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: other.id, source: item, placement: .last)
      ).generatedReferences.first,
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let missing: [PlannerCommand] = [
      .removeItineraryEntry(itineraryId: other.id, entryId: entryId),
      .removeItineraryEntry(itineraryId: itinerary.id, entryId: item.id),
      .removeItineraryEntry(itineraryId: itinerary.id, entryId: UUID()),
      .reorderItineraryEntry(itineraryId: other.id, entryId: entryId, placement: .first),
      .reorderItineraryEntry(itineraryId: itinerary.id, entryId: item.id, placement: .first),
      .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryId, placement: .before(associationId: foreignId)),
      .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryId, placement: .after(associationId: item.id)),
    ]
    let invalid: [PlannerCommand] = [
      .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryId, placement: .before(associationId: entryId)),
      .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryId, placement: .after(associationId: entryId)),
    ]
    for (commands, expectedCode) in [(missing, "missingReference"), (invalid, "invalidInput")] {
      for command in commands {
        let operationId = UUID()
        guard
          case .rejected(let failure) = await planner.execute(
            .init(operationId: operationId, session: session, command: command)
          ).outcome,
          case .noReliableEvidence = await planner.operationStatus(
            session: session, operationId: operationId)
        else { throw CancellationError() }
        #expect(failure.code == expectedCode)
      }
    }
    guard
      case .source(.itinerary(let after)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .selected(let retained) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .listedNamespaces(let currentNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else { throw CancellationError() }
    #expect(after.references == before.references)
    #expect(after.updatedAt == before.updatedAt)
    #expect(after.fieldHashes == before.fieldHashes)
    #expect(after.progress.totalCount == 1 && after.progress.doneCount == 0)
    #expect(retained.portableData == original.portableData)
    #expect(currentNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
  }

  @Test(arguments: ["remove", "reorder"])
  func inaccessibleRecoveryRejectsEntryMutationBeforeCommitAndPayloadReuseCannotChangeItsScope(
    mode: String
  )
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let retainedDirectory = directory.appendingPathComponent("retained-recovery")
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
      storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    var entryIds: [UUID] = []
    for _ in 0..<2 {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entryIds.append(identifier)
    }
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    let command: PlannerCommand
    if mode == "remove" {
      command = .removeItineraryEntry(itineraryId: itinerary.id, entryId: entryIds[1])
    } else {
      command = .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryIds[1], placement: .first)
    }
    let operationId = UUID()
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
    try Data("Obstruct recovery writes.".utf8).write(to: recoveryDirectory)
    let attempted = await planner.execute(
      .init(operationId: operationId, session: session, command: command))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
    guard case .rejected(let failure) = attempted.outcome,
      case .source(.itinerary(let unchanged)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationId),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(operationId: operationId, session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(failure.code == "persistenceFailure")
    #expect(unchanged.references == before.references)
    #expect(unchanged.updatedAt == before.updatedAt)
    #expect(checkpoint == 5)
    let changedCommand: PlannerCommand
    if mode == "remove" {
      changedCommand = .removeItineraryEntry(itineraryId: itinerary.id, entryId: entryIds[0])
    } else {
      changedCommand = .reorderItineraryEntry(
        itineraryId: itinerary.id, entryId: entryIds[1], placement: .last)
    }
    guard
      case .rejected(let mismatch) = await planner.execute(
        .init(operationId: operationId, session: session, command: changedCommand)
      ).outcome
    else { throw CancellationError() }
    #expect(mismatch.code == "operationPayloadMismatch")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    if mode == "remove" {
      #expect(retained.references == [before.references[0]])
      #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
    } else {
      #expect(retained.references == [before.references[1], before.references[0]])
      #expect(recovery.decodedBackup.backup.deletionMarkers.isEmpty)
    }
  }
}
