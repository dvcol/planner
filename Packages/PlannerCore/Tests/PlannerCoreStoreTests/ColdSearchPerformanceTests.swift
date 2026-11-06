import Foundation
import SwiftData
import Testing

@testable import PlannerCore

struct ColdSearchPerformanceTests {
  @Test @MainActor
  func textSearchLoadsSharedLabelsOnAColdReader() async throws {
    let count = 500
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    for command in [
      PlannerCommand.createCategory(content: .init(name: "Shared Category")),
      .createTag(content: .init(name: "Shared Tag")),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: ModelConfiguration(
        schema: schema, url: configuration.storeURL, cloudKitDatabase: .none))
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let category = try #require(context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first)
    let tag = try #require(context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first)
    for index in 0..<count {
      let item = try PlannerSchemaV18.Item(
        input: .init(
          title: "Search fixture \(index)", notes: "Retained searchable notes",
          links: [.init(originalUrl: "https://example.com/\(index)")]))
      item.labelAssociations = [
        .init(item: item, category: category), .init(item: item, tag: tag),
      ]
      context.insert(item)
    }
    try context.save()

    let query = PlannerQuery(
      session: session,
      request: .items(.init(text: "fixture", completion: .all, archive: .all)))
    let clock = ContinuousClock()
    let coldStart = clock.now
    guard case .snapshot(let cold) = await planner.query(query) else {
      throw CancellationError()
    }
    let coldDuration = coldStart.duration(to: clock.now)
    guard case .snapshot(let warm) = await planner.query(query) else {
      throw CancellationError()
    }
    // The shared-label regression took over a minute for this fixture. Keep a generous
    // budget above the subsecond baseline so this detects repeated graph validation.
    #expect(coldDuration < .seconds(10))
    #expect(cold.matchingCount == Int64(count))
    #expect(warm.matchingCount == Int64(count))
    #expect(cold.rows == warm.rows)
    await planner.close()
  }
}
