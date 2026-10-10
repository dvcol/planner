import Foundation
import PlannerCore
import Testing

struct ItemDurationQueryTests {
  @Test func invalidDurationBoundsRejectTogetherAndExactIntegerQueriesKeepIssuedRowsReadable()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize for exact and invalid duration bounds.")
      return
    }
    let inputs = [
      PlannerItemContentInput(
        title: "Lower neighbor",
        estimate: PlannerEstimate(minutes: 9_007_199_254_740_992, displayUnit: .year)),
      PlannerItemContentInput(
        title: "Upper neighbor",
        estimate: PlannerEstimate(minutes: 9_007_199_254_740_993, displayUnit: .year)),
      PlannerItemContentInput(
        title: "Maximum", estimate: PlannerEstimate(minutes: Int64.max, displayUnit: .year)),
      PlannerItemContentInput(title: "Unknown"),
    ]
    var sources: [PlannerEntityReference] = []
    for input in inputs {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: .createItem(content: input))
        ).outcome,
        let source = creation.generated.first
      else {
        Issue.record("Exact integer fixture estimates must save without losing precision.")
        return
      }
      sources.append(source)
    }
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(sources[1])),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .items(.init())))
    else {
      Issue.record("The saved source and complete issued snapshot must be readable.")
      return
    }
    let invalidExamples: [(duration: PlannerItemQuery.Duration, propertyPath: String)] = [
      (.init(minimumMinutes: -1), "/query/duration/minimumMinutes"),
      (.init(maximumMinutes: -1), "/query/duration/maximumMinutes"),
      (.init(minimumMinutes: 1, maximumMinutes: 0), "/query/duration"),
      (.init(minimumMinutes: Int64.max, maximumMinutes: Int64.max - 1), "/query/duration"),
    ]
    for example in invalidExamples {
      let result = await planner.query(
        PlannerQuery(session: session, request: .items(.init(duration: example.duration))))
      guard case .failed(let failure) = result else {
        Issue.record("An invalid duration group must reject rather than issuing partial results.")
        continue
      }
      #expect(failure.code == "invalidInput")
      #expect(failure.propertyPath == example.propertyPath)
    }
    let validExamples: [(duration: PlannerItemQuery.Duration, expectedIndices: [Int])] = [
      (.init(maximumMinutes: 9_007_199_254_740_992), [0]),
      (.init(minimumMinutes: 9_007_199_254_740_993, maximumMinutes: 9_007_199_254_740_993), [1]),
      (.init(minimumMinutes: Int64.max, maximumMinutes: Int64.max), [2]),
      (.init(maximumMinutes: 0), []),
      (.init(maximumMinutes: 0, includeUnknown: true), [3]),
      (.init(minimumMinutes: 0), [0, 2, 1]),
      (.init(minimumMinutes: 0, includeUnknown: true), [0, 2, 3, 1]),
      (.init(), [0, 2, 3, 1]),
    ]
    for example in validExamples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: session, request: .items(.init(duration: example.duration))))
      else {
        Issue.record("A valid nonnegative integer duration group must issue its exact matches.")
        continue
      }
      #expect(snapshot.rows == example.expectedIndices.map { .source(sources[$0]) })
      #expect(snapshot.matchingCount == Int64(example.expectedIndices.count))
    }
    guard
      case .rows(let retained) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: Int64.max)
      ),
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(sources[1]))
    else {
      Issue.record("Rejected/read-only queries must preserve the prior generation and source.")
      return
    }
    #expect(retained.rows.map(\.identity) == issued.rows)
    #expect(current.content.estimate?.minutes == 9_007_199_254_740_993)
    #expect(current.content.estimate?.displayUnit == .year)
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.references == original.references)
  }

  @Test func maximumDurationIsInclusiveAndUnknownEstimatesAreAnExplicitChoice() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize for duration queries.")
      return
    }
    let inputs = [
      PlannerItemContentInput(
        title: "Short walk", estimate: PlannerEstimate(minutes: 119, displayUnit: .minute)),
      PlannerItemContentInput(
        title: "Boundary lunch", estimate: PlannerEstimate(minutes: 120, displayUnit: .hour)),
      PlannerItemContentInput(
        title: "Long visit", estimate: PlannerEstimate(minutes: 121, displayUnit: .minute)),
      PlannerItemContentInput(title: "Unknown stop"),
    ]
    var sources: [PlannerEntityReference] = []
    for input in inputs {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: .createItem(content: input))
        ).outcome,
        let source = creation.generated.first
      else {
        Issue.record("All duration-boundary fixture Items must save through the public facade.")
        return
      }
      sources.append(source)
    }
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(sources[1]))
    else {
      Issue.record("The boundary Item must be readable before querying.")
      return
    }
    for scope in [PlannerItemQuery.Scope.global, .inbox] {
      guard
        case .snapshot(let maximum) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(.init(scope: scope, duration: .init(maximumMinutes: 120))))),
        case .snapshot(let includingUnknown) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              .init(scope: scope, duration: .init(maximumMinutes: 120, includeUnknown: true))))),
        case .snapshot(let cleared) = await planner.query(
          PlannerQuery(session: session, request: .items(.init(scope: scope)))),
        case .snapshot(let emptyGroup) = await planner.query(
          PlannerQuery(session: session, request: .items(.init(scope: scope, duration: .init())))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: maximum.generation, offset: 0, limit: 1))
      else {
        Issue.record("A complete duration query and its issued row window must remain available.")
        return
      }
      #expect(maximum.rows == [.source(sources[1]), .source(sources[0])])
      #expect(maximum.matchingCount == 2)
      #expect(
        includingUnknown.rows == [.source(sources[1]), .source(sources[0]), .source(sources[3])])
      #expect(includingUnknown.matchingCount == 3)
      #expect(
        cleared.rows == [
          .source(sources[1]), .source(sources[2]), .source(sources[0]), .source(sources[3]),
        ])
      #expect(emptyGroup.rows == cleared.rows)
      #expect(window.rows.first?.identity == .source(sources[1]))
      #expect(window.rows.first?.title == "Boundary lunch")
    }
    guard
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(sources[1]))
    else {
      Issue.record("Searching by duration must retain the source Item.")
      return
    }
    #expect(current.content.estimate == PlannerEstimate(minutes: 120, displayUnit: .hour))
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.references == original.references)
  }

  @Test func listDurationRangeNarrowsCumulativelyWithoutChangingFullProgressOrManualOrder()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let listCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Café stops")))
      ).outcome,
      let list = listCreation.generated.first
    else {
      Issue.record("The real duration List must initialize.")
      return
    }
    let inputs = [
      PlannerItemContentInput(
        title: "Short café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 119, displayUnit: .minute)),
      PlannerItemContentInput(
        title: "Boundary café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 120, displayUnit: .hour)),
      PlannerItemContentInput(
        title: "Long café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 121, displayUnit: .minute)),
      PlannerItemContentInput(title: "Unknown café", notes: "Garden entrance"),
      PlannerItemContentInput(
        title: "Hotel", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 1, displayUnit: .minute)),
    ]
    var sources: [PlannerEntityReference] = []
    var appearances: [PlannerAppearance] = []
    for input in inputs {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: .createItem(content: input))
        ).outcome,
        let source = creation.generated.first,
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Each duration fixture Item must have one live List appearance.")
        return
      }
      sources.append(source)
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
          command: .setCompletion(scope: .globalItem(itemId: sources[2].id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: sources[2], archived: true))
      ).outcome,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Local/global completion and archive state must save before narrowing.")
      return
    }
    let manual = PlannerItemQuery.Sort(mode: .manual)
    let range = PlannerItemQuery.Duration(minimumMinutes: 120, maximumMinutes: 121)
    guard
      case .snapshot(let ordinary) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(scope: .list(list.id), text: "cafe garden", duration: range, sort: manual)))),
      case .snapshot(let allStates) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), text: "cafe garden", completion: .all, archive: .all,
              duration: range, sort: manual)))),
      case .snapshot(let includingUnknown) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), text: "cafe garden", completion: .all, archive: .all,
              duration: .init(minimumMinutes: 120, maximumMinutes: 121, includeUnknown: true),
              sort: manual)))),
      case .snapshot(let clearedDuration) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), text: "cafe garden", completion: .all, archive: .all,
              sort: manual)))),
      case .snapshot(let global) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(text: "cafe garden", duration: .init(minimumMinutes: 120, maximumMinutes: 120))))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: allStates.generation, offset: 1, limit: 1)),
      case .source(.list(let current)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Cumulative duration results, Manual windows and sources must remain readable.")
      return
    }
    #expect(ordinary.rows.isEmpty)
    #expect(ordinary.matchingCount == 0)
    #expect(ordinary.progress.first?.doneCount == 2)
    #expect(ordinary.progress.first?.totalCount == 5)
    let expected = [1, 2].map {
      PlannerRowIdentity.appearance(source: sources[$0], appearance: appearances[$0])
    }
    #expect(allStates.rows == expected)
    #expect(allStates.matchingCount == 2)
    #expect(allStates.progress.first?.doneCount == 2)
    #expect(allStates.progress.first?.totalCount == 5)
    #expect(
      includingUnknown.rows == expected + [
        .appearance(source: sources[3], appearance: appearances[3])
      ])
    #expect(includingUnknown.matchingCount == 3)
    #expect(
      clearedDuration.rows
        == [0, 1, 2, 3].map {
          .appearance(source: sources[$0], appearance: appearances[$0])
        })
    #expect(global.rows == [.source(sources[1])])
    #expect(global.matchingCount == 1)
    #expect(
      window.rows.first?.identity == .appearance(source: sources[2], appearance: appearances[2]))
    #expect(window.rows.first?.effectiveDone == true)
    #expect(current.references == original.references)
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(current.updatedAt == original.updatedAt)
  }
}
