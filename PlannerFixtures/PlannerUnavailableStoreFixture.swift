import Foundation
import PlannerCore

@MainActor
enum PlannerUnavailableStoreFixture {
  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    let storeDirectory = directory.appendingPathComponent("store", isDirectory: true)
    let retainedStoreDirectory = directory.appendingPathComponent(
      "retained-unavailable-store", isDirectory: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: storeDirectory.appendingPathComponent("Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    if !FileManager.default.fileExists(atPath: retainedStoreDirectory.path) {
      try await seed(configuration: configuration)
      try FileManager.default.moveItem(at: storeDirectory, to: retainedStoreDirectory)
    }
    return SavedPlannerStore(configuration: configuration)
  }

  private static func seed(configuration: PlannerStorageConfiguration) async throws {
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let tagResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createTag(content: .init(name: "Retained travel")))
      ).outcome,
      let tag = tagResult.generated.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: "Unavailable museum", notes: "Saved before the store became unavailable",
              tagIds: [tag.id])))
      ).outcome
    else { throw CancellationError() }
  }
}
