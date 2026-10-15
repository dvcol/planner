import Foundation
import PlannerCore
import SwiftData

@MainActor
enum PlannerDeletionRecoveryFixture {
  private static var observer: NSObjectProtocol?

  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let obstruction = FixtureRecoverySaveObstruction(configuration: configuration)
    try obstruction.restore()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    if !window.rows.isEmpty { return SavedPlannerStore(configuration: configuration) }
    for (title, notes) in [
      ("Delete museum", "Museum deletion notes"), ("Keep hotel", "Retained hotel notes"),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: title, notes: notes)))
        )
        .outcome
      else { throw CancellationError() }
    }
    observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    return SavedPlannerStore(configuration: configuration)
  }
}
