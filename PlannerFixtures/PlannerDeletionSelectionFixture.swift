import Foundation
import PlannerCore

@MainActor
enum PlannerDeletionSelectionFixture {
  static func seed(_ planner: PlannerCore.Planner, session: PlannerDatasetSession) async throws {
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    for archived in [false, true] {
      let prefix = archived ? "Hidden" : "Visible"
      guard
        let item = try await save(
          .createItem(content: .init(title: prefix + " Item", notes: prefix + " saved notes"))
        )
        .generated.first,
        let list = try await save(.createList(content: .init(name: prefix + " List")))
          .generated.first
      else { throw CancellationError() }
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
      if archived {
        _ = try await save(.setArchive(source: item, archived: true))
        _ = try await save(.setArchive(source: list, archived: true))
      }
    }
  }
}
