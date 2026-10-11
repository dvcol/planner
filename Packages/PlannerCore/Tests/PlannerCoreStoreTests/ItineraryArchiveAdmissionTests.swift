import Foundation
import PlannerCore
import Testing

struct ItineraryArchiveAdmissionTests {
  @Test(arguments: [true, false])
  func archiveAdmissionAndRecoveryFailureLeaveTheItineraryUnchanged(archived: Bool) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let retainedDirectory = directory.appendingPathComponent("retained-recovery")
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
      storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItinerary(content: .init(title: "Route", notes: "Keep notes")))
      ).outcome
    else { throw CancellationError() }
    let itinerary = try #require(creation.generated.first)
    guard
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: itinerary, archived: !archived))
      ).outcome,
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let originalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let missingId = UUID()
    guard
      case .rejected(let missing) = await planner.execute(
        .init(
          operationId: missingId, session: session,
          command: .setArchive(source: .init(kind: .itinerary, id: UUID()), archived: archived))
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: missingId)
    else { throw CancellationError() }
    #expect(missing.code == "missingReference")
    let command = PlannerCommand.setArchive(source: itinerary, archived: archived)
    let operationId = UUID()
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
    try Data("Obstruct independent recovery writes.".utf8).write(to: recoveryDirectory)
    let attempted = await planner.execute(
      .init(operationId: operationId, session: session, command: command))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
    guard case .rejected(let failure) = attempted.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationId),
      case .source(.itinerary(let unchanged)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .selected(let retainedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .listedNamespaces(let retainedNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else { throw CancellationError() }
    #expect(failure.code == "persistenceFailure")
    #expect(unchanged.state.archived == !archived)
    #expect(unchanged.content == before.content)
    #expect(unchanged.updatedAt == before.updatedAt)
    #expect(unchanged.fieldHashes == before.fieldHashes)
    #expect(unchanged.references == before.references)
    #expect(retainedRecovery.portableData == originalRecovery.portableData)
    #expect(retainedNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    guard
      case .applied(let applied, .complete(let appliedCheckpoint)) = await planner.execute(
        .init(operationId: operationId, session: session, command: command)
      ).outcome,
      case .rejected(let mismatch) = await planner.execute(
        .init(
          operationId: operationId, session: session,
          command: .setArchive(source: itinerary, archived: !archived))
      ).outcome
    else { throw CancellationError() }
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(appliedCheckpoint == checkpoint + 1)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let current)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationId, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(current.state.archived == archived)
    #expect(current.content == before.content)
    #expect(current.references == before.references)
    #expect(current.fieldHashes == before.fieldHashes)
    #expect(replay == applied && replayCheckpoint == appliedCheckpoint)
  }
}
