import Foundation
import PlannerCore
import SwiftData

@MainActor
enum PlannerRecoveryFixture {
  enum Access { case writable, readOnly, unavailable }

  static func makeStore(directory: URL, access: Access) async throws -> SavedPlannerStore {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    if !window.rows.isEmpty { return SavedPlannerStore(configuration: configuration) }
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Existing hotel")))
      ).outcome
    else { throw CancellationError() }
    let obstruction = FixtureRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    guard
      case .applied(_, .incomplete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(title: "Recovery museum", notes: "Original recovery notes")))
      ).outcome,
      obstruction.didObstruct
    else { throw CancellationError() }
    try obstruction.restore()
    if access != .writable {
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        namespaces.count == 1, let namespace = namespaces.first
      else { throw CancellationError() }
      let namespaceDirectory = configuration.recoveryDirectoryURL
        .appendingPathComponent(namespace.namespaceId.uuidString)
      if access == .readOnly {
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o555], ofItemAtPath: namespaceDirectory.path)
      } else {
        try Data("Unreadable checkpoint evidence.".utf8).write(
          to: namespaceDirectory.appendingPathComponent("checkpoint-invalid.json"))
      }
    }
    return SavedPlannerStore(configuration: configuration)
  }
}

private final class FixtureRecoverySaveObstruction: @unchecked Sendable {
  private let lock = NSLock()
  private let storeURL: URL
  private let recoveryURL: URL
  private let retainedURL: URL
  private var obstructed = false

  init(configuration: PlannerStorageConfiguration) {
    storeURL = configuration.storeURL.standardizedFileURL
    recoveryURL = configuration.recoveryDirectoryURL
    retainedURL = recoveryURL.deletingLastPathComponent()
      .appendingPathComponent("retained-after-native-save")
  }

  var didObstruct: Bool { lock.withLock { obstructed } }

  func observe(_ notification: Notification) {
    guard let context = notification.object as? ModelContext,
      context.container.configurations.contains(where: { $0.url.standardizedFileURL == storeURL })
    else { return }
    lock.withLock {
      guard !obstructed else { return }
      do {
        try FileManager.default.moveItem(at: recoveryURL, to: retainedURL)
        try Data("Obstruct recovery after native save.".utf8).write(to: recoveryURL)
        obstructed = true
      } catch { return }
    }
  }

  func restore() throws {
    guard FileManager.default.fileExists(atPath: retainedURL.path) else { return }
    if FileManager.default.fileExists(atPath: recoveryURL.path) {
      try FileManager.default.removeItem(at: recoveryURL)
    }
    try FileManager.default.moveItem(at: retainedURL, to: recoveryURL)
  }
}
