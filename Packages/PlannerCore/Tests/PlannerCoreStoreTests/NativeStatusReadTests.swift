import Foundation
import PlannerCore
import Testing

struct NativeStatusReadTests {
  @Test func emptyAndAcknowledgedStatusReadUsesObservedRecoveryWithoutInventingCloudActivity()
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
    let emptyResponse = await planner.read(session: session, request: .status)
    guard case .status(let empty) = emptyResponse,
      case .known(
        let emptyCheckpoint, let emptyIncomplete, let emptyMaintenance, let emptyBlocked) = empty
        .recovery,
      case .unknown = empty.account
    else {
      Issue.record(
        "The native status request must expose observed local evidence: \(emptyResponse)")
      return
    }
    #expect(
      emptyCheckpoint == nil && emptyIncomplete.isEmpty && emptyMaintenance.isEmpty && !emptyBlocked
    )
    #expect(empty.cloud.state == .unknown)
    #expect(empty.cloud.storeIdentity == nil && empty.cloud.eventId == nil)
    #expect(empty.cloud.observedAt == nil && empty.cloud.reason == nil)
    let operationIdentifier = UUID()
    guard
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      )
      .outcome,
      let source = creation.generated.first,
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(source)),
      case .snapshot(let query) = await planner.query(
        .init(session: session, request: .items(.init()))),
      case .status(let saved) = await planner.read(session: session, request: .status),
      case .known(let savedCheckpoint, let incomplete, let maintenance, let blocked) = saved
        .recovery,
      case .unknown = saved.account
    else { throw CancellationError() }
    #expect(checkpoint == 1 && savedCheckpoint == checkpoint)
    #expect(incomplete.isEmpty && maintenance.isEmpty && !blocked)
    #expect(saved.cloud.state == .unknown)
    #expect(saved.cloud.storeIdentity == nil && saved.cloud.eventId == nil)
    #expect(saved.cloud.observedAt == nil && saved.cloud.reason == nil)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .status(let retainedStatus) = await reopened.read(
        session: reopenedSession, request: .status),
      case .known(
        let retainedCheckpoint, let retainedIncomplete, let retainedMaintenance, let retainedBlocked
      ) =
        retainedStatus.recovery,
      case .source(.item(let after)) = await planner.read(
        session: session, request: .source(source)),
      case .rows(let rows) = await planner.read(
        session: session, request: .rows(generation: query.generation, offset: 0, limit: 1)),
      case .appliedRecoveryComplete(let statusResult, let statusCheckpoint) =
        await reopened.operationStatus(session: reopenedSession, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(
      retainedCheckpoint == checkpoint && retainedIncomplete.isEmpty && retainedMaintenance.isEmpty
        && !retainedBlocked)
    #expect(after.updatedAt == before.updatedAt && after.fieldHashes == before.fieldHashes)
    #expect(after.content.title == "Hotel" && after.content.notes == "Original notes")
    #expect(rows.rows.count == 1)
    #expect(statusResult == creation && statusCheckpoint == checkpoint)
  }
}
