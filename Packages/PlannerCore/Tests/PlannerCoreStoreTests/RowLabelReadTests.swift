import Foundation
import PlannerCore
import Testing

struct RowLabelReadTests {
  @Test func itemRowsResolveSharedLabelMetadataWithoutCollapsingDuplicateNames() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: configuration(directory))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else { throw CancellationError() }
      return source
    }
    let category = try await save(
      .createCategory(
        content: .init(
          name: "Food", color: .init(red: 0, green: 0.5, blue: 1, alpha: 1),
          iconName: "fork.knife")))
    let firstTag = try await save(.createTag(content: .init(name: "Food")))
    let secondTag = try await save(.createTag(content: .init(name: "Food", iconName: "tag")))
    let hotel = try await save(
      .createItem(
        content: .init(
          title: "Hotel", notes: "Full notes stay in source reads",
          categoryIds: [category.id], tagIds: [firstTag.id, secondTag.id])))
    let museum = try await save(.createItem(content: .init(title: "Museum")))
    guard
      case .source(.item(let sourceRead)) = await planner.read(
        session: session, request: .source(hotel)),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: .max))
    else { throw CancellationError() }
    let hotelRow = try #require(window.rows.first { $0.identity == .source(hotel) })
    let museumRow = try #require(window.rows.first { $0.identity == .source(museum) })
    #expect(hotelRow.labels == sourceRead.labels)
    #expect(hotelRow.labels.count == 3)
    #expect(hotelRow.labels.map(\.name) == ["Food", "Food", "Food"])
    let categoryLabel = try #require(hotelRow.labels.first { $0.reference == category })
    #expect(categoryLabel.color == .init(red: 0, green: 0.5, blue: 1, alpha: 1))
    #expect(categoryLabel.iconName == "fork.knife")
    #expect(hotelRow.labels.first { $0.reference == firstTag }?.iconName == nil)
    #expect(hotelRow.labels.first { $0.reference == secondTag }?.iconName == "tag")
    #expect(museumRow.labels.isEmpty)
  }

  @Test func contextualRowsKeepSourceLabelsLiveAcrossAnotherWriterAndReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = configuration(directory)
    let planner = Planner(configuration: storage)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Food"))).generated.first)
    let tag = try #require(
      try await save(.createTag(content: .init(name: "Rain"))).generated.first)
    let routeCategory = try #require(
      try await save(.createCategory(content: .init(name: "Travel"))).generated.first)
    let hotel = try #require(
      try await save(
        .createItem(content: .init(title: "Hotel", categoryIds: [category.id], tagIds: [tag.id]))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food List"))).generated.first)
    _ = try await save(.addMembership(itemId: hotel.id, listId: list.id, placement: .last))
    let itinerary = try #require(
      try await save(
        .createItinerary(content: .init(title: "Weekend", categoryIds: [routeCategory.id]))
      ).generated.first)
    for source in [hotel, list, hotel] {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
    }
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(hotel)),
      case .source(.category(let categoryRead)) = await planner.read(
        session: session, request: .source(category)),
      case .source(.tag(let tagRead)) = await planner.read(session: session, request: .source(tag))
    else { throw CancellationError() }
    let requests: [PlannerQueryRequest] = [
      .items(.init(completion: .all, archive: .all)),
      .items(.init(scope: .list(list.id), completion: .all, archive: .all)),
      .items(
        .init(
          scope: .itinerary(itinerary.id), completion: .all, archive: .all,
          sort: .init(mode: .manual))),
    ]
    var generations = [UUID]()
    for (index, request) in requests.enumerated() {
      let window = try await readWindow(planner, session: session, request: request)
      generations.append(window.generation)
      #expect(window.rows.count == (index == 2 ? 3 : 1))
      #expect(window.rows.allSatisfy { $0.labels == original.labels })
    }
    let routeRows = try await readWindow(
      planner, session: session, request: .catalog(.init(sourceKind: .itinerary)))
    let routeRow = try #require(routeRows.rows.first)
    #expect(routeRow.labels.count == 1)
    #expect(routeRow.labels.first?.reference == routeCategory)
    #expect(routeRow.labels.first?.name == "Travel")
    for kind: PlannerEntityKind in [.list, .category, .tag] {
      let window = try await readWindow(
        planner, session: session, request: .catalog(.init(sourceKind: kind, archive: .all)))
      #expect(!window.rows.isEmpty)
      #expect(window.rows.allSatisfy { $0.labels.isEmpty })
    }
    let otherWriter = Planner(configuration: storage)
    guard case .ready(let otherSession) = await otherWriter.bootstrap() else {
      throw CancellationError()
    }
    for command: PlannerCommand in [
      .editCategory(
        sourceId: category.id, changes: .init(name: .set("Dining")),
        expectedFieldHashes: categoryRead.fieldHashes),
      .editTag(
        sourceId: tag.id, changes: .init(name: .set("Wet weather")),
        expectedFieldHashes: tagRead.fieldHashes),
    ] {
      guard
        case .applied(_, .complete) = await otherWriter.execute(
          .init(operationId: UUID(), session: otherSession, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    for generation in generations + [routeRows.generation] {
      guard
        case .failed(let failure) = await planner.read(
          session: session, request: .rows(generation: generation, offset: 0, limit: .max))
      else { throw CancellationError() }
      #expect(failure.code == "staleSnapshot")
    }
    guard
      case .source(.item(let afterRename)) = await planner.read(
        session: session, request: .source(hotel)),
      case .listedNamespaces(let recoveryBeforeReads) = await planner.inspectRecovery(
        request: .namespaces)
    else { throw CancellationError() }
    #expect(afterRename.fieldHashes == original.fieldHashes)
    #expect(afterRename.updatedAt == original.updatedAt)
    let reopened = Planner(configuration: storage)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      throw CancellationError()
    }
    for request in requests {
      let window = try await readWindow(reopened, session: reopenedSession, request: request)
      #expect(window.rows.allSatisfy { $0.labels == afterRename.labels })
      for row in window.rows {
        #expect(row.labels.first { $0.reference == category }?.name == "Dining")
        #expect(row.labels.first { $0.reference == tag }?.name == "Wet weather")
        #expect(!row.labels.contains { $0.reference == routeCategory })
      }
    }
    guard
      case .listedNamespaces(let recoveryAfterReads) = await reopened.inspectRecovery(
        request: .namespaces)
    else { throw CancellationError() }
    #expect(
      recoveryBeforeReads.first?.acknowledgedSnapshot?.checkpointGeneration
        == recoveryAfterReads.first?.acknowledgedSnapshot?.checkpointGeneration)
    #expect(recoveryAfterReads.first?.preparedProposals.isEmpty == true)
  }

  private func readWindow(
    _ planner: Planner, session: PlannerDatasetSession, request: PlannerQueryRequest
  ) async throws -> PlannerRowWindow {
    guard
      case .snapshot(let snapshot) = await planner.query(.init(session: session, request: request)),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: .max))
    else { throw CancellationError() }
    return window
  }

  private func configuration(_ directory: URL) -> PlannerStorageConfiguration {
    .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }
}
