import Foundation
import PlannerCore

@MainActor
enum PlannerRowReadabilityFixture {
  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    if snapshot.matchingCount > 0 { return SavedPlannerStore(configuration: configuration) }

    func save(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else { throw CancellationError() }
      return source
    }
    func apply(_ command: PlannerCommand) async throws {
      guard
        case .applied(_, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
    }

    let list = try await save(.createList(content: .init(name: "Festivals & events")))
    let category = try await save(.createCategory(content: .init(name: "Festivals & events")))
    let must = try await save(.createTag(content: .init(name: "Must")))
    let area = try await save(.createTag(content: .init(name: "Area · Asakusa")))
    let evening = try await save(.createTag(content: .init(name: "Evening")))
    let entries = [
      ("Asakusa Tori-no-Ichi", "7 & 19 November · lucky-rake market", "Otori Shrine", true),
      (
        "Chichibu Night Festival — main festival", "3 December · floats and fireworks",
        "Chichibu Shrine", true
      ),
      (
        "Design Festa vol.64", "14–15 November · independent makers",
        "Tokyo Big Sight West and South Halls", true
      ),
      (
        "Meiji Jingu — Culture Day yabusame", "3 November · horseback archery",
        "Meiji Jingu west approach lawn", false
      ),
    ]
    let start = Date(timeIntervalSince1970: 1_794_036_600)
    for (index, entry) in entries.enumerated() {
      let item = try await save(
        .createItem(
          content: .init(
            title: entry.0, subtitle: entry.1, notes: "Controlled row-layout fixture.",
            location: .init(
              displayName: entry.2, formattedAddress: "Tokyo, Japan", coordinate: nil),
            estimate: .init(minutes: 180, displayUnit: .minute),
            links: [
              .init(
                originalUrl: "https://fixtures.invalid/" + (entry.3 ? "image" : "none"),
                label: "Official dates & details")
            ],
            categoryIds: [category.id], tagIds: [must.id, area.id, evening.id])))
      try await apply(.addMembership(itemId: item.id, listId: list.id, placement: .last))
      _ = try await save(
        .createSchedule(
          source: item,
          form: .timed(
            start: start.addingTimeInterval(Double(index) * 86_400),
            end: start.addingTimeInterval(Double(index) * 86_400 + 10_800),
            planningTimeZone: "Asia/Tokyo")))
    }
    return SavedPlannerStore(configuration: configuration)
  }
}
