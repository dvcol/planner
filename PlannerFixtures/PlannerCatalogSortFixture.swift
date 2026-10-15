import Foundation
import PlannerCore

@MainActor
enum PlannerCatalogSortFixture {
  static func seed(_ planner: PlannerCore.Planner, session: PlannerDatasetSession) async throws {
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let names = ["Zulu plan", "Alpha plan", "Missing plan", "Manual plan"]
    var items: [PlannerEntityReference] = []
    let minutes: [Int64?] = [180, 60, nil, nil]
    for (index, name) in names.enumerated() {
      let result = try await save(
        .createItem(
          content: .init(
            title: name + " activity",
            estimate: minutes[index].map { .init(minutes: $0, displayUnit: .minute) })))
      guard let source = result.generated.first else { throw CancellationError() }
      items.append(source)
    }
    for kind in [PlannerEntityKind.list, .itinerary] {
      var sources: [PlannerEntityReference] = []
      for (index, name) in names.enumerated() {
        let manual: PlannerEstimate? = index == 3 ? .init(minutes: 240, displayUnit: .hour) : nil
        let command: PlannerCommand
        if kind == .list {
          command = .createList(content: .init(name: name, manualEstimate: manual))
        } else {
          command = .createItinerary(content: .init(title: name, manualEstimate: manual))
        }
        let result = try await save(command)
        guard let source = result.generated.first else { throw CancellationError() }
        sources.append(source)
        if kind == .list {
          _ = try await save(
            .addMembership(itemId: items[index].id, listId: source.id, placement: .last))
        } else {
          _ = try await save(
            .addItineraryEntry(itineraryId: source.id, source: items[index], placement: .last))
        }
      }
      switch await planner.read(session: session, request: .source(sources[2])) {
      case .source(.list(let source)):
        _ = try await save(
          .editList(
            sourceId: source.source.id, changes: .init(notes: .set("Recently edited plan")),
            expectedFieldHashes: source.fieldHashes))
      case .source(.itinerary(let source)):
        _ = try await save(
          .editItinerary(
            sourceId: source.source.id, changes: .init(notes: .set("Recently edited plan")),
            expectedFieldHashes: source.fieldHashes))
      default: throw CancellationError()
      }
    }
  }
}
