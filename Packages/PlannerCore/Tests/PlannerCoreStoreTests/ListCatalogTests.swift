import Foundation
import PlannerCore
import Testing

struct ListCatalogTests {
  @Test func catalogRejectsItemKindAndKeepsUnimplementedKindsDistinctFromEmptyLists() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let empty) = await planner.query(
        PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list))))
    else {
      Issue.record("A valid empty List catalog must remain distinct from unsupported discovery.")
      return
    }
    #expect(empty.rows.isEmpty)
    #expect(empty.matchingCount == 0)
    #expect(empty.rowPresentation == nil)
    for kind in [PlannerEntityKind.item, .itinerary, .tag, .schedule] {
      guard
        case .failed(let failure) = await planner.query(
          PlannerQuery(session: session, request: .catalog(.init(sourceKind: kind))))
      else {
        Issue.record("Unsupported catalog kinds must not report a successful empty dataset.")
        continue
      }
      #expect(failure.code == (kind == .item ? "invalidInput" : "unavailable"))
      #expect(failure.propertyPath == "/query/sourceKind")
    }
    guard
      case .rows(let retainedWindow) = await planner.read(
        session: session, request: .rows(generation: empty.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record(
        "Rejected read requests must preserve the issued empty window and recovery state.")
      return
    }
    #expect(retainedWindow.rows.isEmpty)
    #expect(namespaces.first?.acknowledgedSnapshot == nil)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func titleOrderingIgnoresCaseAndAccentsAcrossGlobalInboxAndListAppearances() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome, let list = created.generated.first
    else {
      Issue.record("The title-ordering fixture must initialize through the public writer.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for title in ["Zoo", "CAFÉ GUIDE", "cafe guide", "Cafe cafe"] {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: title)))
        ).outcome, let source = created.generated.first
      else {
        Issue.record("Each original Item title must save without normalization.")
        return
      }
      sources.append(source)
    }
    let equivalentSources = [sources[1], sources[2]].sorted { $0.id.uuidString < $1.id.uuidString }
    let ascending = ([sources[3]] + equivalentSources + [sources[0]]).map(PlannerRowIdentity.source)
    let descending = ([sources[0]] + equivalentSources + [sources[3]]).map(
      PlannerRowIdentity.source)
    for scope in [PlannerItemQuery.Scope.global, .inbox] {
      for direction in [PlannerItemQuery.Sort.Direction.ascending, .descending] {
        guard
          case .snapshot(let snapshot) = await planner.query(
            PlannerQuery(
              session: session,
              request: .items(.init(scope: scope, sort: .init(direction: direction)))))
        else {
          Issue.record("Global and Inbox title queries must expose all original source identities.")
          return
        }
        #expect(snapshot.rows == (direction == .ascending ? ascending : descending))
      }
    }
    var appearances: [UUID: PlannerRowIdentity] = [:]
    for source in sources {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = created.generatedReferences.first
      else {
        Issue.record("The same live Items must retain exact List appearances.")
        return
      }
      appearances[source.id] = .appearance(
        source: source, appearance: .listMembership(listId: list.id, membershipId: membershipId))
    }
    for direction in [PlannerItemQuery.Sort.Direction.ascending, .descending] {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(.init(scope: .list(list.id), sort: .init(direction: direction)))))
      else {
        Issue.record("Contextual title ordering must use the same insensitive comparison policy.")
        return
      }
      let expectedSources: [PlannerEntityReference]
      if direction == .ascending {
        expectedSources = [sources[3]] + equivalentSources + [sources[0]]
      } else {
        expectedSources = [sources[0]] + equivalentSources + [sources[3]]
      }
      #expect(snapshot.rows == expectedSources.compactMap { appearances[$0.id] })
    }
    guard
      case .snapshot(let manual) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(.init(scope: .list(list.id), sort: .init(mode: .manual))))),
      case .rows(let rows) = await planner.read(
        session: session, request: .rows(generation: manual.generation, offset: 0, limit: 4))
    else {
      Issue.record("Title sorting must leave Manual order and displayed original text intact.")
      return
    }
    #expect(rows.rows.map(\.title) == ["Zoo", "CAFÉ GUIDE", "cafe guide", "Cafe cafe"])
  }

  @Test func listCatalogRetainsDuplicateNamesAndExactIdentityThroughSearchArchiveRenameAndReopen()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize before catalog discovery.")
      return
    }
    var lists: [PlannerEntityReference] = []
    for name in ["Zoo", "CAFÉ GUIDE", "cafe guide", "Cafe cafe", "Archived guide"] {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createList(
              content: .init(
                name: name,
                notes: String(repeating: "Long original notes. ", count: 1000))))
        ).outcome,
        let source = created.generated.first
      else {
        Issue.record("Catalog Lists must save with independent source identities.")
        return
      }
      lists.append(source)
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: lists[4], archived: true))
      ).outcome,
      case .snapshot(let active) = await planner.query(
        PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list))))
    else {
      Issue.record("Active List catalog discovery must return stable source identities.")
      return
    }
    #expect(active.matchingCount == 4)
    #expect(active.rowPresentation == nil)
    #expect(active.progress.isEmpty)
    #expect(active.unresolvedReferences.isEmpty)
    #expect(active.rows.first == .source(lists[3]))
    #expect(active.rows.last == .source(lists[0]))
    #expect(
      Set(
        active.rows[1...2].compactMap { identity -> UUID? in
          if case .source(let source) = identity { return source.id }
          return nil
        }) == Set([lists[1].id, lists[2].id]))
    if case .source(let first) = active.rows[1], case .source(let second) = active.rows[2] {
      #expect(first.id.uuidString < second.id.uuidString)
    } else {
      Issue.record("Equivalent names must retain separate, consistently ordered source identities.")
    }
    guard
      case .snapshot(let searched) = await planner.query(
        PlannerQuery(
          session: session,
          request: .catalog(.init(sourceKind: .list, text: "  CaFÉ  GuIdE\n")))),
      case .snapshot(let archived) = await planner.query(
        PlannerQuery(
          session: session, request: .catalog(.init(sourceKind: .list, archive: .archived)))),
      case .snapshot(let all) = await planner.query(
        PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list, archive: .all)))),
      case .snapshot(let missingText) = await planner.query(
        PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list, text: "missing")))
      ),
      case .rows(let firstWindow) = await planner.read(
        session: session,
        request: .rows(generation: searched.generation, offset: 0, limit: 1)),
      case .rows(let secondWindow) = await planner.read(
        session: session,
        request: .rows(generation: searched.generation, offset: 1, limit: 1)),
      case .rows(let beyond) = await planner.read(
        session: session,
        request: .rows(generation: searched.generation, offset: 2, limit: Int64.max)),
      case .rows(let archivedWindow) = await planner.read(
        session: session,
        request: .rows(generation: archived.generation, offset: 0, limit: 1)),
      let firstRow = firstWindow.rows.first, let secondRow = secondWindow.rows.first,
      let archivedRow = archivedWindow.rows.first
    else {
      Issue.record("Catalog search/archive queries and lazy List windows must remain coherent.")
      return
    }
    #expect(searched.rows == Array(active.rows[1...2]))
    #expect(searched.matchingCount == 2)
    #expect(archived.rows == [.source(lists[4])])
    #expect(all.rows == [.source(lists[4])] + active.rows)
    #expect(missingText.rows.isEmpty)
    #expect(missingText.matchingCount == 0)
    #expect(firstWindow.rowPresentation == nil)
    #expect(secondWindow.rowPresentation == nil)
    #expect(firstRow.identity == searched.rows[0])
    #expect(secondRow.identity == searched.rows[1])
    #expect(Set([firstRow.title, secondRow.title]) == ["CAFÉ GUIDE", "cafe guide"])
    #expect(firstRow.globalDone == nil)
    #expect(firstRow.localDone == nil)
    #expect(firstRow.effectiveDone == nil)
    #expect(firstRow.archived == false)
    #expect(firstRow.subtitle == nil)
    #expect(firstRow.estimate == nil)
    #expect(!firstRow.hasLocation && !firstRow.hasLinks)
    #expect(firstRow.ownedLocation == nil)
    #expect(firstRow.previewLink == nil)
    #expect(firstRow.scheduleSummary == .none)
    #expect(beyond.rows.isEmpty)
    #expect(beyond.rowPresentation == nil)
    #expect(archivedRow.title == "Archived guide")
    #expect(archivedRow.archived == true)
    guard
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(lists[0])),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: lists[0].id, changes: .init(name: .set("A first")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .failed(let stale) = await planner.read(
        session: session,
        request: .rows(generation: active.generation, offset: 0, limit: 1)),
      case .snapshot(let refreshed) = await planner.query(
        PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list)))),
      case .rows(let renamedWindow) = await planner.read(
        session: session,
        request: .rows(generation: refreshed.generation, offset: 0, limit: 1))
    else {
      Issue.record("Rename must preserve identity, invalidate old rows and expose current names.")
      return
    }
    #expect(checkpoint == 7)
    #expect(stale.code == "staleSnapshot")
    #expect(refreshed.generation != active.generation)
    #expect(refreshed.rows == [.source(lists[0])] + Array(active.rows.prefix(3)))
    #expect(renamedWindow.rows.first?.identity == .source(lists[0]))
    #expect(renamedWindow.rows.first?.title == "A first")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let restored) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .catalog(.init(sourceKind: .list)))),
      case .source(.list(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(lists[0])),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Catalog discovery must preserve renamed sources and saved data across reopen.")
      return
    }
    #expect(restored.rows == refreshed.rows)
    #expect(restored.rowPresentation == nil)
    #expect(retained.content.name == "A first")
    #expect(retained.content.notes == original.content.notes)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 7)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }
}
