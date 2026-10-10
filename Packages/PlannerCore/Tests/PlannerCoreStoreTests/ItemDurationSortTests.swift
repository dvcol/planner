import Foundation
import PlannerCore
import Testing

struct ItemDurationSortTests {
  @Test func listDurationSortRetainsManualOrderLocalCompletionAndFullProgressAcrossFilters()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = configuration(at: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = creation.generated.first
    else {
      Issue.record("The real List must initialize before duration sorting.")
      return
    }
    var sources: [PlannerEntityReference] = []
    var membershipIdentifiers: [UUID] = []
    for content in [
      PlannerItemContentInput(title: "Unknown Zulu"),
      PlannerItemContentInput(
        title: "Zulu lunch", estimate: PlannerEstimate(minutes: 180, displayUnit: .hour)),
      PlannerItemContentInput(
        title: "Short walk", estimate: PlannerEstimate(minutes: 119, displayUnit: .day)),
      PlannerItemContentInput(title: "Unknown Alpha"),
      PlannerItemContentInput(
        title: "Alpha lunch", estimate: PlannerEstimate(minutes: 180, displayUnit: .minute)),
    ] {
      let source = try await createItem(content, planner: planner, session: session)
      guard
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Each shared source must have one saved Manual position.")
        return
      }
      sources.append(source)
      membershipIdentifiers.append(membershipIdentifier)
    }
    let completedAppearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifiers[1])
    for command: PlannerCommand in [
      .setCompletion(scope: .appearance(completedAppearance), done: true),
      .setCompletion(scope: .globalItem(itemId: sources[2].id), done: true),
      .setArchive(source: sources[2], archived: true),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Independent completion and archive must save before sorting.")
        return
      }
    }
    guard
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Saved references and order must be publicly readable.")
      return
    }
    let allRows = sources.enumerated().map { index, source in
      PlannerRowIdentity.appearance(
        source: source,
        appearance: .listMembership(listId: list.id, membershipId: membershipIdentifiers[index]))
    }
    let cases: [(direction: PlannerItemQuery.Sort.Direction, indices: [Int])] = [
      (.ascending, [2, 4, 1, 3, 0]),
      (.descending, [4, 1, 2, 3, 0]),
    ]
    for example in cases {
      guard
        case .snapshot(let sorted) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              .init(
                scope: .list(list.id), completion: .all, archive: .all,
                sort: .init(mode: .duration, direction: example.direction)))))
      else {
        Issue.record("The declared List duration sort must return exact appearance identities.")
        return
      }
      #expect(sorted.rows == example.indices.map { allRows[$0] })
      #expect(sorted.matchingCount == 5)
      #expect(sorted.progress.first?.doneCount == 2)
      #expect(sorted.progress.first?.totalCount == 5)
    }
    let filteredCases: [(duration: PlannerItemQuery.Duration?, text: String, indices: [Int])] = [
      (.init(minimumMinutes: 180, maximumMinutes: 180), "", [4]),
      (.init(minimumMinutes: 180, maximumMinutes: 180, includeUnknown: true), "", [4, 3, 0]),
      (.init(minimumMinutes: 180, maximumMinutes: 180, includeUnknown: true), "lunch", [4]),
      (nil, "lunch", [4]),
      (nil, "", [4, 3, 0]),
    ]
    for example in filteredCases {
      guard
        case .snapshot(let sorted) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              .init(
                scope: .list(list.id), text: example.text, duration: example.duration,
                sort: .init(mode: .duration, direction: .descending)))))
      else {
        Issue.record("Duration sorting must compose with the accepted query filters.")
        return
      }
      #expect(sorted.rows == example.indices.map { allRows[$0] })
      #expect(sorted.matchingCount == Int64(example.indices.count))
      #expect(sorted.progress.first?.doneCount == 2)
      #expect(sorted.progress.first?.totalCount == 5)
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let manual) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual))))),
      case .source(.list(let current)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let completed) = await reopened.read(
        session: reopenedSession, request: .appearance(completedAppearance)),
      case .source(.item(let source)) = await reopened.read(
        session: reopenedSession, request: .source(sources[1]))
    else {
      Issue.record("Reopening and switching to Manual must recover saved order and local state.")
      return
    }
    #expect(manual.rows == allRows)
    #expect(manual.matchingCount == 5)
    #expect(manual.progress.first?.doneCount == 2)
    #expect(manual.progress.first?.totalCount == 5)
    #expect(current.references == original.references)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(completed.localDone)
    #expect(completed.effectiveDone)
    #expect(completed.globalDone == false)
    #expect(source.state.globalDone == false)
    #expect(source.content.estimate == PlannerEstimate(minutes: 180, displayUnit: .hour))
  }

  @Test func durationSortKeepsUnknownLastAndTitleTiesAscendingInBothDirectionsAfterReopen()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = configuration(at: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize before duration sorting.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for content in [
      PlannerItemContentInput(
        title: "Zulu lunch", estimate: PlannerEstimate(minutes: 180, displayUnit: .hour)),
      PlannerItemContentInput(
        title: "Alpha lunch", estimate: PlannerEstimate(minutes: 180, displayUnit: .minute)),
      PlannerItemContentInput(
        title: "Short walk", estimate: PlannerEstimate(minutes: 119, displayUnit: .day)),
      PlannerItemContentInput(title: "Unknown Zulu"),
      PlannerItemContentInput(title: "Unknown Alpha"),
      PlannerItemContentInput(
        title: "Upper neighbor",
        estimate: PlannerEstimate(minutes: 9_007_199_254_740_993, displayUnit: .year)),
      PlannerItemContentInput(
        title: "Lower neighbor",
        estimate: PlannerEstimate(minutes: 9_007_199_254_740_992, displayUnit: .year)),
    ] {
      sources.append(try await createItem(content, planner: planner, session: session))
    }
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(sources[5]))
    else {
      Issue.record("Saved exact estimate values must be publicly readable.")
      return
    }
    let cases: [(direction: PlannerItemQuery.Sort.Direction, indices: [Int])] = [
      (.ascending, [2, 1, 0, 6, 5, 4, 3]),
      (.descending, [5, 6, 1, 0, 2, 4, 3]),
    ]
    for scope in [PlannerItemQuery.Scope.global, .inbox] {
      for example in cases {
        guard
          case .snapshot(let sorted) = await planner.query(
            PlannerQuery(
              session: session,
              request: .items(
                .init(scope: scope, sort: .init(mode: .duration, direction: example.direction)))))
        else {
          Issue.record("A declared duration sort must issue the complete sorted snapshot.")
          return
        }
        #expect(sorted.matchingCount == 7)
        #expect(sorted.rows == example.indices.map { .source(sources[$0]) })
        guard
          case .rows(let window) = await planner.read(
            session: session, request: .rows(generation: sorted.generation, offset: 3, limit: 2))
        else {
          Issue.record("Sorted identities must retain their issued row-window positions.")
          return
        }
        #expect(window.rows.map(\.identity) == example.indices[3...4].map { .source(sources[$0]) })
      }
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      Issue.record("Duration sorting must remain available after reopening.")
      return
    }
    for example in cases {
      guard
        case .snapshot(let sorted) = await reopened.query(
          PlannerQuery(
            session: reopenedSession,
            request: .items(.init(sort: .init(mode: .duration, direction: example.direction)))))
      else {
        Issue.record("Reopening must preserve the exact saved minutes and both sort directions.")
        return
      }
      #expect(sorted.matchingCount == 7)
      #expect(sorted.rows == example.indices.map { .source(sources[$0]) })
    }
    guard
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(sources[5]))
    else {
      Issue.record("Sorting must preserve the saved estimate and source state.")
      return
    }
    #expect(current.content.estimate == original.content.estimate)
    #expect(current.content.estimate?.minutes == 9_007_199_254_740_993)
    #expect(current.content.estimate?.displayUnit == .year)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(current.references == original.references)
  }

  private func configuration(at directory: URL) -> PlannerStorageConfiguration {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  private func createItem(
    _ content: PlannerItemContentInput, planner: Planner, session: PlannerDatasetSession
  ) async throws -> PlannerEntityReference {
    guard
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createItem(content: content))
      ).outcome
    else {
      Issue.record("The fixture estimate must save with complete recovery evidence.")
      throw FixtureFailure()
    }
    return try #require(creation.generated.first)
  }

  private struct FixtureFailure: Error {}
}
