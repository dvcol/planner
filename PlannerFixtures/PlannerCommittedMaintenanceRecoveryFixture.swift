import Foundation
import SwiftData

@testable import PlannerCore

@MainActor
enum PlannerCommittedMaintenanceRecoveryFixture {
  static func makeStore(directory: URL, readOnly: Bool, lateInputOnReopen: Bool = false)
    async throws
    -> SavedPlannerStore
  {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    if FileManager.default.fileExists(atPath: configuration.controlURL.path) {
      if lateInputOnReopen {
        try await deliverLaterMembership(configuration: configuration, directory: directory)
      }
      return SavedPlannerStore(configuration: configuration)
    }
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    if snapshot.matchingCount > 0 { return SavedPlannerStore(configuration: configuration) }
    guard
      case .applied(let itemCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: "Maintenance museum",
              notes: "Keep the original maintenance note")))
      )
      .outcome,
      let item = itemCreation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Maintenance plan")))
      )
      .outcome,
      let list = listCreation.generated.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      )
      .outcome
    else { throw CancellationError() }
    try insertIndependentMembership(configuration: configuration, item: item, list: list)
    let obstruction = FixtureRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let waitingIdentifier = UUID()
    guard
      case .rejected = await planner.execute(
        .init(
          operationId: waitingIdentifier, session: session,
          command: .createTag(content: .init(name: "Must remain unapplied")))
      )
      .outcome, obstruction.didObstruct
    else { throw CancellationError() }
    try obstruction.restore()
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: waitingIdentifier),
      case .status(let status) = await planner.read(session: session, request: .status),
      case .known(_, let operations, let maintenance, true) = status.recovery,
      operations.isEmpty, maintenance.count == 1
    else { throw CancellationError() }
    if readOnly {
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(
          request: .namespaces), let namespace = namespaces.first, namespaces.count == 1
      else { throw CancellationError() }
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o555],
        ofItemAtPath: configuration.recoveryDirectoryURL
          .appendingPathComponent(namespace.namespaceId.uuidString).path)
    }
    return SavedPlannerStore(configuration: configuration)
  }

  private static func deliverLaterMembership(
    configuration: PlannerStorageConfiguration, directory: URL
  ) async throws {
    let marker = directory.appendingPathComponent("late-membership-delivered")
    guard !FileManager.default.fileExists(atPath: marker.path) else { return }
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let data) = await planner.exportData(session: session),
      case .decoded(let decoded) = planner.decodeImport(data),
      let item = decoded.backup.items.first, decoded.backup.items.count == 1,
      let list = decoded.backup.lists.first, decoded.backup.lists.count == 1
    else { throw CancellationError() }
    try insertIndependentMembership(
      configuration: configuration,
      item: .init(kind: .item, id: item.id), list: .init(kind: .list, id: list.id))
    try Data("Delivered one independent native membership.".utf8).write(
      to: marker, options: .atomic)
  }

  private static func insertIndependentMembership(
    configuration: PlannerStorageConfiguration, item: PlannerEntityReference,
    list: PlannerEntityReference
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    guard
      let itemRecord = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first(
        where: { $0.id == item.id }), let itemLifetime = itemRecord.lifetimeId,
      let listRecord = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first(
        where: { $0.id == list.id }), let listLifetime = listRecord.lifetimeId
    else { throw CancellationError() }
    context.insert(
      PlannerSchemaV18.Membership(
        snapshot: .init(
          id: UUID(), lifetimeId: UUID(),
          list: .init(kind: "list", id: list.id, lifetimeId: listLifetime),
          item: .init(kind: "item", id: item.id, lifetimeId: itemLifetime),
          rank: 2048, localDone: false), list: listRecord, item: itemRecord))
    try context.save()
  }
}
