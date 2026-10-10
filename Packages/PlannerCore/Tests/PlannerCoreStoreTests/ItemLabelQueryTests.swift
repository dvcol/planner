import Foundation
import PlannerCore
import Testing

struct ItemLabelQueryTests {
  @Test func labelIdentityGroupsNarrowCumulativelyAndKeepFullListProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real store for label filtering.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else {
        Issue.record("The complete filtering fixture must save through public commands.")
        throw CancellationError()
      }
      return source
    }
    let food = try await create(.createCategory(content: .init(name: "Food")))
    let culture = try await create(.createCategory(content: .init(name: "Food")))
    let rain = try await create(.createTag(content: .init(name: "Rain")))
    let travel = try await create(.createTag(content: .init(name: "Travel")))
    let list = try await create(.createList(content: .init(name: "Stops")))
    let inputs = [
      PlannerItemContentInput(
        title: "Alpha cafe", estimate: .init(minutes: 60, displayUnit: .hour),
        categoryIds: [food.id], tagIds: [rain.id]),
      PlannerItemContentInput(
        title: "Beta cafe", estimate: .init(minutes: 120, displayUnit: .hour),
        categoryIds: [food.id, culture.id], tagIds: [rain.id, travel.id]),
      PlannerItemContentInput(
        title: "Gamma cafe", estimate: .init(minutes: 180, displayUnit: .hour),
        categoryIds: [culture.id], tagIds: [travel.id]),
      PlannerItemContentInput(title: "Hotel"),
      PlannerItemContentInput(
        title: "Delta cafe", estimate: .init(minutes: 90, displayUnit: .minute),
        categoryIds: [food.id], tagIds: [rain.id]),
    ]
    var sources: [PlannerEntityReference] = []
    var appearances: [PlannerAppearance] = []
    for (index, input) in inputs.enumerated() {
      let item = try await create(.createItem(content: input))
      sources.append(item)
      if index == 4 { continue }
      guard
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Retain each distinct source and its List appearance.")
        return
      }
      appearances.append(.listMembership(listId: list.id, membershipId: membershipIdentifier))
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(appearances[1]), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: sources[2], archived: true))
      ).outcome
    else {
      Issue.record("Set independent completion/archive before narrowing the List.")
      return
    }
    let foodGroup = PlannerItemQuery.IdentityGroup(ids: [food.id])
    let categoryAny = PlannerItemQuery.IdentityGroup(ids: [food.id, culture.id])
    let categoryAll = PlannerItemQuery.IdentityGroup(ids: [food.id, culture.id], match: .all)
    let rainGroup = PlannerItemQuery.IdentityGroup(ids: [rain.id])
    let tagAll = PlannerItemQuery.IdentityGroup(ids: [rain.id, travel.id], match: .all)
    let examples: [(PlannerItemQuery, [Int])] = [
      (.init(completion: .all, archive: .all, categories: foodGroup), [0, 1, 4]),
      (.init(completion: .all, archive: .all, categories: categoryAny), [0, 1, 4, 2]),
      (.init(completion: .all, archive: .all, categories: categoryAll), [1]),
      (.init(completion: .all, archive: .all, tags: rainGroup), [0, 1, 4]),
      (.init(completion: .all, archive: .all, tags: tagAll), [1]),
      (
        .init(
          completion: .all, archive: .all, categories: .init(ids: [culture.id]), tags: rainGroup),
        [1]
      ),
      (
        .init(
          scope: .inbox, completion: .all, archive: .all, categories: foodGroup, tags: rainGroup),
        [4]
      ),
      (
        .init(scope: .inbox, completion: .all, archive: .all, categories: .init(ids: [culture.id])),
        []
      ),
      (
        .init(
          text: "CAFE", completion: .all, archive: .all, categories: foodGroup, tags: rainGroup,
          duration: .init(minimumMinutes: 90, maximumMinutes: 150)), [1, 4]
      ),
      (
        .init(
          completion: .all, archive: .all, categories: .init(ids: []),
          tags: .init(ids: [], match: .all)), [0, 1, 4, 2, 3]
      ),
    ]
    for (query, expectedIndices) in examples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: session, request: .items(query)))
      else {
        Issue.record("Accepted label groups must produce a complete query snapshot.")
        return
      }
      #expect(snapshot.rows == expectedIndices.map { .source(sources[$0]) })
      #expect(snapshot.matchingCount == Int64(expectedIndices.count))
    }
    let listExamples: [(PlannerItemQuery, [Int])] = [
      (.init(scope: .list(list.id), categories: categoryAny, sort: .init(mode: .manual)), [0]),
      (
        .init(
          scope: .list(list.id), completion: .all, categories: categoryAny, tags: tagAll,
          sort: .init(mode: .manual)), [1]
      ),
      (
        .init(
          scope: .list(list.id), completion: .all, archive: .all, categories: categoryAny,
          sort: .init(mode: .manual)), [0, 1, 2]
      ),
      (
        .init(scope: .list(list.id), completion: .all, archive: .archived, categories: categoryAny),
        [2]
      ),
    ]
    for (query, expectedIndices) in listExamples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: session, request: .items(query)))
      else {
        Issue.record("Standalone List label groups must preserve exact appearance identity.")
        return
      }
      #expect(
        snapshot.rows
          == expectedIndices.map { .appearance(source: sources[$0], appearance: appearances[$0]) })
      #expect(snapshot.matchingCount == Int64(expectedIndices.count))
      #expect(snapshot.progress.first?.doneCount == 1)
      #expect(snapshot.progress.first?.totalCount == 4)
      #expect(snapshot.progress.first?.state == .partial)
      guard
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
      else {
        Issue.record("A filtered identity must hydrate through the moving row window.")
        return
      }
      #expect(window.rows.first?.title == inputs[expectedIndices[0]].title)
      #expect(window.rows.first?.identity == snapshot.rows.first)
    }
  }
}
