import Foundation
import PlannerCore

@MainActor
enum PlannerPreparedMaintenanceRecoveryFixture {
  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      namespaces.count == 1, let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let identifier = "00000000-0000-4000-8000-000000000941"
    let preparationFile = namespaceDirectory.appendingPathComponent(
      "maintenance-\(identifier).json")
    if FileManager.default.fileExists(atPath: preparationFile.path) {
      return SavedPlannerStore(configuration: configuration)
    }
    guard
      case .applied(let itemCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(title: "Prepared museum", notes: "Prepared recovery note")))
      ).outcome,
      let item = itemCreation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Prepared plan")))
      ).outcome,
      let list = listCreation.generated.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .exported(let data) = await planner.exportData(session: session),
      let backup = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let identity = try JSONSerialization.jsonObject(
        with: Data(contentsOf: namespaceDirectory.appendingPathComponent("identity.json")))
        as? [String: Any]
    else { throw CancellationError() }
    var preparation: [String: Any] = [
      "format": "planner-maintenance-preparation", "formatVersion": 1,
      "maintenanceId": identifier, "kind": "membershipConsolidation", "ruleVersion": 1,
      "proposedBackup": backup, "evidence": "preparedUnverified",
    ]
    for key in ["namespaceId", "datasetId", "epochId", "ownershipBinding"] {
      guard let value = identity[key] as? String else { throw CancellationError() }
      preparation[key] = value
    }
    try JSONSerialization.data(withJSONObject: preparation).write(
      to: preparationFile, options: .atomic)
    return SavedPlannerStore(configuration: configuration)
  }
}
