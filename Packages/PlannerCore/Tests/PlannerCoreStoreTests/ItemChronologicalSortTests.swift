import Foundation
import PlannerCore
import Testing

struct ItemChronologicalSortTests {
  @Test func listChronologicalSortPreservesItemTimestampsManualOrderAndFullFilteredProgress()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = configuration(at: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize before List chronological sorting.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for content in [
      PlannerItemContentInput(
        title: "Zulu café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 180, displayUnit: .hour)),
      PlannerItemContentInput(
        title: "Alpha café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 180, displayUnit: .minute)),
      PlannerItemContentInput(
        title: "Middle Hotel", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 120, displayUnit: .hour)),
    ] {
      sources.append(try await createItem(content, planner: planner, session: session))
    }
    let first = try await item(sources[0], planner: planner, session: session)
    let second = try await item(sources[1], planner: planner, session: session)
    let third = try await item(sources[2], planner: planner, session: session)
    try #require(first.createdAt < second.createdAt)
    try #require(second.createdAt < third.createdAt)
    try await editNotes("Garden review", source: first, planner: planner, session: session)
    let edited = try await item(sources[0], planner: planner, session: session)
    try #require(edited.updatedAt > third.updatedAt)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: sources[1], archived: true))
      ).outcome,
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = creation.generated.first
    else {
      Issue.record("The source archive and List must save with complete recovery evidence.")
      return
    }
    let archived = try await item(sources[1], planner: planner, session: session)
    try #require(archived.updatedAt > edited.updatedAt)
    let originals = [edited, archived, third]
    let manualIndices = [1, 0, 2]
    var membershipIdentifiers: [Int: UUID] = [:]
    for index in manualIndices {
      guard
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: sources[index].id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Each source must have its exact saved Manual appearance.")
        return
      }
      membershipIdentifiers[index] = membershipIdentifier
    }
    var appearanceRows: [PlannerRowIdentity] = []
    for index in 0..<3 {
      appearanceRows.append(
        .appearance(
          source: sources[index],
          appearance: .listMembership(
            listId: list.id, membershipId: try #require(membershipIdentifiers[index]))))
    }
    let completedAppearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: try #require(membershipIdentifiers[0]))
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(completedAppearance), done: true))
      ).outcome,
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Independent local completion and saved List order must be readable.")
      return
    }
    let cases:
      [(
        mode: PlannerItemQuery.Sort.Mode, direction: PlannerItemQuery.Sort.Direction, indices: [Int]
      )] = [
        (.created, .ascending, [0, 1, 2]),
        (.created, .descending, [2, 1, 0]),
        (.lastUpdated, .ascending, [2, 0, 1]),
        (.lastUpdated, .descending, [1, 0, 2]),
      ]
    for example in cases {
      guard
        case .snapshot(let sorted) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              .init(
                scope: .list(list.id), completion: .all, archive: .all,
                sort: .init(mode: example.mode, direction: example.direction)))))
      else {
        Issue.record(
          "The declared List chronological sort must issue its complete appearance scope.")
        return
      }
      #expect(sorted.rows == example.indices.map { appearanceRows[$0] })
      #expect(sorted.matchingCount == 3)
      #expect(sorted.progress.first?.doneCount == 1)
      #expect(sorted.progress.first?.totalCount == 3)
    }
    for example in [cases[0], cases[3]] {
      guard
        case .snapshot(let filtered) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              .init(
                scope: .list(list.id), text: "cafe garden", completion: .all, archive: .all,
                duration: .init(minimumMinutes: 180, maximumMinutes: 180),
                sort: .init(mode: example.mode, direction: example.direction)))))
      else {
        Issue.record("Chronological sorting must compose with text, duration and retained states.")
        return
      }
      #expect(filtered.rows == example.indices.filter { $0 != 2 }.map { appearanceRows[$0] })
      #expect(filtered.matchingCount == 2)
      #expect(filtered.progress.first?.doneCount == 1)
      #expect(filtered.progress.first?.totalCount == 3)
    }
    guard
      case .snapshot(let ordinary) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(.init(scope: .list(list.id), sort: .init(mode: .lastUpdated)))))
    else {
      Issue.record("Ordinary cumulative filters must retain full progress under a date sort.")
      return
    }
    #expect(ordinary.rows == [appearanceRows[2]])
    #expect(ordinary.matchingCount == 1)
    #expect(ordinary.progress.first?.doneCount == 1)
    #expect(ordinary.progress.first?.totalCount == 3)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let manual) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual))))),
      case .source(.list(let currentList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .appearance(let completed) = await reopened.read(
        session: reopenedSession, request: .appearance(completedAppearance))
    else {
      Issue.record(
        "Reopening and returning to Manual must preserve saved associations and local state.")
      return
    }
    #expect(manual.rows == manualIndices.map { appearanceRows[$0] })
    #expect(currentList.references == originalList.references)
    #expect(currentList.updatedAt == originalList.updatedAt)
    #expect(currentList.fieldHashes == originalList.fieldHashes)
    #expect(completed.localDone)
    #expect(completed.effectiveDone)
    #expect(completed.globalDone == false)
    for index in 0..<3 {
      let current = try await item(sources[index], planner: reopened, session: reopenedSession)
      #expect(current.createdAt == originals[index].createdAt)
      #expect(current.updatedAt == originals[index].updatedAt)
      #expect(current.fieldHashes == originals[index].fieldHashes)
      #expect(current.state.globalDone == false)
    }
  }

  @Test func chronologicalSortDistinguishesCreationFromContentUpdatesAfterReopen()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = configuration(at: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize before chronological sorting.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for title in ["Zulu", "Alpha", "Middle"] {
      sources.append(try await createItem(.init(title: title), planner: planner, session: session))
    }
    let first = try await item(sources[0], planner: planner, session: session)
    let second = try await item(sources[1], planner: planner, session: session)
    let third = try await item(sources[2], planner: planner, session: session)
    try #require(first.createdAt < second.createdAt)
    try #require(second.createdAt < third.createdAt)
    try await editNotes("First later edit", source: first, planner: planner, session: session)
    let firstEdited = try await item(sources[0], planner: planner, session: session)
    try #require(firstEdited.updatedAt > third.updatedAt)
    try await editNotes("Second later edit", source: second, planner: planner, session: session)
    let secondEdited = try await item(sources[1], planner: planner, session: session)
    try #require(secondEdited.updatedAt > firstEdited.updatedAt)
    #expect(firstEdited.createdAt == first.createdAt)
    #expect(secondEdited.createdAt == second.createdAt)
    let cases:
      [(
        mode: PlannerItemQuery.Sort.Mode, direction: PlannerItemQuery.Sort.Direction, indices: [Int]
      )] = [
        (.created, .ascending, [0, 1, 2]),
        (.created, .descending, [2, 1, 0]),
        (.lastUpdated, .ascending, [2, 0, 1]),
        (.lastUpdated, .descending, [1, 0, 2]),
      ]
    for scope in [PlannerItemQuery.Scope.global, .inbox] {
      for example in cases {
        guard
          case .snapshot(let sorted) = await planner.query(
            PlannerQuery(
              session: session,
              request: .items(
                .init(
                  scope: scope, sort: .init(mode: example.mode, direction: example.direction)))))
        else {
          Issue.record("The declared chronological sort must return a complete snapshot.")
          return
        }
        #expect(sorted.matchingCount == 3)
        #expect(sorted.rows == example.indices.map { .source(sources[$0]) })
        guard
          case .rows(let window) = await planner.read(
            session: session, request: .rows(generation: sorted.generation, offset: 1, limit: 1))
        else {
          Issue.record("Chronological ordering must retain its issued row-window positions.")
          return
        }
        #expect(window.matchingCount == 3)
        #expect(window.rows.map(\.identity) == [.source(sources[example.indices[1]])])
      }
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      Issue.record("Saved timestamps must remain sortable after reopening.")
      return
    }
    for example in cases {
      guard
        case .snapshot(let sorted) = await reopened.query(
          PlannerQuery(
            session: reopenedSession,
            request: .items(.init(sort: .init(mode: example.mode, direction: example.direction)))))
      else {
        Issue.record("Reopening must retain creation and Last updated ordering.")
        return
      }
      #expect(sorted.rows == example.indices.map { .source(sources[$0]) })
    }
    let originals = [firstEdited, secondEdited, third]
    for index in 0..<3 {
      let current = try await item(sources[index], planner: reopened, session: reopenedSession)
      #expect(current.createdAt == originals[index].createdAt)
      #expect(current.updatedAt == originals[index].updatedAt)
      #expect(current.content.title == originals[index].content.title)
      #expect(current.content.notes == originals[index].content.notes)
      #expect(current.fieldHashes == originals[index].fieldHashes)
      #expect(current.references == originals[index].references)
      #expect(current.state.globalDone == false)
      #expect(current.state.archived == false)
    }
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
      Issue.record("The fixture Item must save with complete recovery evidence.")
      throw FixtureFailure()
    }
    return try #require(creation.generated.first)
  }

  private func item(
    _ source: PlannerEntityReference, planner: Planner, session: PlannerDatasetSession
  ) async throws -> PlannerItemSourceRead {
    guard
      case .source(.item(let value)) = await planner.read(
        session: session, request: .source(source))
    else {
      Issue.record("The fixture Item must be readable through the public source seam.")
      throw FixtureFailure()
    }
    return value
  }

  private func editNotes(
    _ notes: String, source: PlannerItemSourceRead, planner: Planner, session: PlannerDatasetSession
  ) async throws {
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: source.source.id, changes: .init(notes: .set(notes)),
            expectedFieldHashes: [.notes: try #require(source.fieldHashes[.notes])]))
      ).outcome
    else {
      Issue.record("The guarded content edit must save with complete recovery evidence.")
      throw FixtureFailure()
    }
  }

  private struct FixtureFailure: Error {}
}
