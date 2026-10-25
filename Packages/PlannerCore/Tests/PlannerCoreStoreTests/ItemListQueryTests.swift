import Foundation
import PlannerCore
import Testing

struct ItemListQueryTests {
  @Test func listIdentityGroupsNarrowLiveMembershipsAndPreserveContextualProgress() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real graph before membership-group queries.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else {
        Issue.record("Save each source through the public durable writer.")
        throw CancellationError()
      }
      return source
    }
    let food = try await create(.createCategory(content: .init(name: "Food")))
    let rain = try await create(.createTag(content: .init(name: "Rain")))
    let firstList = try await create(.createList(content: .init(name: "Stops")))
    let secondList = try await create(.createList(content: .init(name: "Stops")))
    let inputs = [
      PlannerItemContentInput(
        title: "Hotel", estimate: .init(minutes: 120, displayUnit: .hour), categoryIds: [food.id],
        tagIds: [rain.id]),
      PlannerItemContentInput(
        title: "Museum", estimate: .init(minutes: 120, displayUnit: .hour), tagIds: [rain.id]),
      PlannerItemContentInput(title: "Park", categoryIds: [food.id]),
      PlannerItemContentInput(title: "Inbox", categoryIds: [food.id], tagIds: [rain.id]),
    ]
    var sources: [PlannerEntityReference] = []
    for input in inputs { sources.append(try await create(.createItem(content: input))) }
    var firstListAppearances: [PlannerAppearance] = []
    for (list, indices) in [(firstList, [0, 1]), (secondList, [0, 2])] {
      for index in indices {
        guard
          case .applied(let result, .complete) = await planner.execute(
            PlannerOperation(
              operationId: UUID(), session: session,
              command: .addMembership(itemId: sources[index].id, listId: list.id, placement: .last))
          ).outcome,
          case .membership(let identifier, _, _)? = result.generatedReferences.first
        else {
          Issue.record("Retain the overlapping sources as independent live memberships.")
          return
        }
        if list.id == firstList.id {
          firstListAppearances.append(.listMembership(listId: list.id, membershipId: identifier))
        }
      }
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(firstListAppearances[0]), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: firstList, archived: true))
      ).outcome
    else {
      Issue.record(
        "Archive the container without changing its source membership or local completion.")
      return
    }
    let firstGroup = PlannerItemQuery.IdentityGroup(ids: [firstList.id])
    let secondGroup = PlannerItemQuery.IdentityGroup(ids: [secondList.id])
    let anyGroup = PlannerItemQuery.IdentityGroup(ids: [firstList.id, secondList.id])
    let allGroup = PlannerItemQuery.IdentityGroup(ids: [firstList.id, secondList.id], match: .all)
    let examples: [(PlannerItemQuery, [Int])] = [
      (.init(lists: firstGroup), [0, 1]),
      (.init(lists: secondGroup), [0, 2]),
      (.init(lists: anyGroup), [0, 1, 2]),
      (.init(lists: allGroup), [0]),
      (.init(lists: .init(ids: [])), [0, 3, 1, 2]),
      (.init(lists: .init(ids: [], match: .all)), [0, 3, 1, 2]),
      (.init(scope: .inbox, lists: anyGroup), []),
      (.init(scope: .inbox, lists: .init(ids: [])), [3]),
      (
        .init(
          text: "HOTEL", categories: .init(ids: [food.id]), tags: .init(ids: [rain.id]),
          lists: anyGroup,
          duration: .init(minimumMinutes: 120, maximumMinutes: 120)), [0]
      ),
    ]
    for (query, expectedIndices) in examples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: session, request: .items(query)))
      else {
        Issue.record("Any/All membership groups must return a complete identity snapshot.")
        return
      }
      #expect(snapshot.rows == expectedIndices.map { .source(sources[$0]) })
      #expect(snapshot.matchingCount == Int64(expectedIndices.count))
      #expect(snapshot.progress.isEmpty)
    }
    let listExamples: [(PlannerItemQuery, [Int])] = [
      (
        .init(
          scope: .list(firstList.id), completion: .all, lists: secondGroup,
          sort: .init(mode: .manual)), [0]
      ),
      (.init(scope: .list(firstList.id), lists: secondGroup, sort: .init(mode: .manual)), []),
      (.init(scope: .list(firstList.id), lists: firstGroup, sort: .init(mode: .manual)), [1]),
      (
        .init(
          scope: .list(firstList.id), completion: .done, lists: allGroup, sort: .init(mode: .manual)
        ), [0]
      ),
    ]
    for (query, expectedIndices) in listExamples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: session, request: .items(query)))
      else {
        Issue.record("A contextual membership filter must preserve its source List progress.")
        return
      }
      #expect(
        snapshot.rows
          == expectedIndices.map {
            .appearance(source: sources[$0], appearance: firstListAppearances[$0])
          })
      #expect(snapshot.matchingCount == Int64(expectedIndices.count))
      #expect(snapshot.progress.first?.doneCount == 1)
      #expect(snapshot.progress.first?.totalCount == 2)
      #expect(snapshot.progress.first?.state == .partial)
    }
    guard
      case .source(.list(let savedList)) = await planner.read(
        session: session, request: .source(firstList)),
      case .source(.item(let hotel)) = await planner.read(
        session: session, request: .source(sources[0])),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Filtering cannot change saved source/container state or recovery.")
      return
    }
    #expect(savedList.state.archived == true)
    #expect(
      savedList.references.compactMap { reference in
        if case .membership(_, _, let item) = reference { return item }
        return nil
      } == [sources[0], sources[1]])
    #expect(hotel.state.globalDone == false)
    #expect(
      hotel.references.filter { reference in
        if case .membership = reference { return true }
        return false
      }.count == 2)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 14)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }
}
