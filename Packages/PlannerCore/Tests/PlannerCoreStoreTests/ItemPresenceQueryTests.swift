import Foundation
import PlannerCore
import Testing

struct ItemPresenceQueryTests {
  @Test func addressAndLinkFiltersNarrowOwnedContentWithoutChangingFullListProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real store before owned-address and link queries.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else {
        Issue.record("Save each presence fixture through the public durable writer.")
        throw CancellationError()
      }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Travel")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let list = try await create(.createList(content: .init(name: "Stops")))
    let inputs = [
      PlannerItemContentInput(
        title: "A Address",
        location: .init(displayName: nil, formattedAddress: "Tokyo", coordinate: nil),
        estimate: .init(minutes: 120, displayUnit: .hour),
        links: [.init(originalUrl: "https://example.com/address")],
        categoryIds: [category.id], tagIds: [tag.id]),
      PlannerItemContentInput(
        title: "B Link", estimate: .init(minutes: 60, displayUnit: .hour),
        links: [.init(originalUrl: "https://example.com/link")], categoryIds: [category.id]),
      PlannerItemContentInput(
        title: "C Map", links: [.init(originalUrl: "https://maps.apple.com/?q=Tokyo")]),
      PlannerItemContentInput(
        title: "D Location",
        location: .init(
          displayName: "Meeting point", formattedAddress: nil,
          coordinate: .init(latitude: 35, longitude: 139))),
      PlannerItemContentInput(
        title: "E Blank",
        location: .init(displayName: nil, formattedAddress: " \t", coordinate: nil),
        links: [.init(originalUrl: "https://example.com/blank")]),
      PlannerItemContentInput(
        title: "F Inbox",
        location: .init(displayName: "Hotel", formattedAddress: "Paris", coordinate: nil)),
    ]
    var sources: [PlannerEntityReference] = []
    var appearances: [PlannerAppearance] = []
    for (index, input) in inputs.enumerated() {
      let source = try await create(.createItem(content: input))
      sources.append(source)
      if index == 5 { continue }
      guard
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Save exact appearances before contextual presence filtering.")
        return
      }
      appearances.append(.listMembership(listId: list.id, membershipId: membershipIdentifier))
    }
    for command: PlannerCommand in [
      .setCompletion(scope: .appearance(appearances[0]), done: true),
      .setArchive(source: sources[1], archived: true),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Save local Done and archive as independent states.")
        return
      }
    }
    let examples: [(PlannerItemQuery, [Int])] = [
      (.init(completion: .all, archive: .all), [0, 1, 2, 3, 4, 5]),
      (.init(completion: .all, archive: .all, hasAddress: true), [0, 5]),
      (.init(completion: .all, archive: .all, hasLinks: true), [0, 1, 2, 4]),
      (.init(completion: .all, archive: .all, hasAddress: true, hasLinks: true), [0]),
      (.init(scope: .inbox, hasAddress: true), [5]),
      (.init(scope: .inbox, hasLinks: true), []),
      (.init(scope: .inbox, hasAddress: false, hasLinks: false), [5]),
      (
        .init(
          text: "ADDRESS", categories: .init(ids: [category.id]), tags: .init(ids: [tag.id]),
          lists: .init(ids: [list.id]), duration: .init(minimumMinutes: 120, maximumMinutes: 120),
          hasAddress: true, hasLinks: true), [0]
      ),
    ]
    for (query, expectedIndices) in examples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: session, request: .items(query)))
      else {
        Issue.record("Presence filters must produce a coherent identity snapshot.")
        continue
      }
      #expect(snapshot.rows == expectedIndices.map { .source(sources[$0]) })
      #expect(snapshot.matchingCount == Int64(expectedIndices.count))
    }
    let listExamples: [(PlannerItemQuery, [Int])] = [
      (.init(scope: .list(list.id), hasAddress: true), []),
      (.init(scope: .list(list.id), hasLinks: true, sort: .init(mode: .manual)), [2, 4]),
      (
        .init(
          scope: .list(list.id), completion: .all, archive: .all, hasLinks: true,
          sort: .init(mode: .manual)), [0, 1, 2, 4]
      ),
      (
        .init(
          scope: .list(list.id), completion: .done, hasAddress: true, hasLinks: true,
          sort: .init(mode: .manual)), [0]
      ),
    ]
    for (query, expectedIndices) in listExamples {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: session, request: .items(query))),
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 2))
      else {
        Issue.record("Contextual presence filters retain exact appearances and moving windows.")
        continue
      }
      let expectedRows = expectedIndices.map {
        PlannerRowIdentity.appearance(source: sources[$0], appearance: appearances[$0])
      }
      #expect(snapshot.rows == expectedRows)
      #expect(window.rows.map(\.identity) == Array(expectedRows.prefix(2)))
      #expect(snapshot.progress.first?.doneCount == 1)
      #expect(snapshot.progress.first?.totalCount == 5)
    }
    guard
      case .source(.item(let mapItem)) = await planner.read(
        session: session, request: .source(sources[2])),
      case .source(.item(let addressItem)) = await planner.read(
        session: session, request: .source(sources[0])),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Querying preserves owned data and independent recovery.")
      return
    }
    #expect(mapItem.content.location == nil)
    #expect(mapItem.content.links.first?.kind == .appleMaps)
    #expect(addressItem.state.globalDone == false)
    #expect(addressItem.content.location?.formattedAddress == "Tokyo")
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 16)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }
}
