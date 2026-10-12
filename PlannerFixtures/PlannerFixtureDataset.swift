import Foundation
import PlannerCore

@MainActor
enum PlannerFixtureDataset {
  static func makeOverflowStore() async throws -> SavedPlannerStore {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerFixtures", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    guard
      let list = try await save(
        .createList(
          content: .init(
            name: "Overflow budget", manualEstimate: .init(minutes: 240, displayUnit: .hour)))
      ).generated.first
    else { throw CancellationError() }
    for (title, minutes) in [("Long activity", Int64.max), ("Short activity", Int64(1))] {
      guard
        let item = try await save(
          .createItem(
            content: .init(
              title: title, estimate: .init(minutes: minutes, displayUnit: .year)))
        ).generated.first
      else { throw CancellationError() }
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    return SavedPlannerStore(configuration: configuration)
  }
}
