import Foundation
import PlannerCore
import Testing

struct MembershipRowTests {
  @Test func emptyAndFilteredOutListsKeepDistinctCompleteScopeProgressAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdList, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let list = createdList.generated.first,
      case .snapshot(let empty) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .list(list.id))))),
      case .rows(let emptyWindow) = await planner.read(
        session: session, request: .rows(generation: empty.generation, offset: 0, limit: Int64.max))
    else {
      Issue.record("An empty saved List must have a coherent empty query and window.")
      return
    }
    #expect(empty.rows.isEmpty)
    #expect(empty.matchingCount == 0)
    #expect(empty.progress.first?.state == .empty)
    #expect(empty.progress.first?.doneCount == 0)
    #expect(empty.progress.first?.totalCount == 0)
    #expect(emptyWindow.rows.isEmpty)
    #expect(emptyWindow.rowPresentation == empty.rowPresentation)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: list, archived: true))
      ).outcome,
      case .applied(let createdItem, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(let added, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipId, _, _)? = added.generatedReferences.first,
      case .snapshot(let activeChild) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(scope: .list(list.id)))))
    else {
      Issue.record("Container Archive must retain effective memberships and scoped child access.")
      return
    }
    let identity = PlannerRowIdentity.appearance(
      source: item, appearance: .listMembership(listId: list.id, membershipId: membershipId))
    #expect(activeChild.rows == [identity])
    #expect(activeChild.progress.first?.state == .partial)
    #expect(activeChild.progress.first?.doneCount == 0)
    #expect(activeChild.progress.first?.totalCount == 1)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: item, archived: true))
      ).outcome
    else {
      Issue.record("Global Done and Item Archive must save independently.")
      return
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let filteredOut) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .items(.init(scope: .list(list.id))))),
      case .snapshot(let all) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(.init(scope: .list(list.id), completion: .all, archive: .all)))),
      case .source(.list(let source)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: activeChild.generation, offset: 0, limit: 1))
    else {
      Issue.record(
        "Filtered-out completed Lists must retain complete progress across native reopen.")
      return
    }
    #expect(filteredOut.rows.isEmpty)
    #expect(filteredOut.matchingCount == 0)
    #expect(filteredOut.progress.first?.state == .complete)
    #expect(filteredOut.progress.first?.doneCount == 1)
    #expect(filteredOut.progress.first?.totalCount == 1)
    #expect(all.rows == [identity])
    #expect(source.state.archived == true)
    #expect(source.progress.state == .complete)
    #expect(stale.code == "staleSnapshot")
  }

  @Test func listQueryRetainsManualAppearanceOrderAndCompleteScopeProgressWhileRowsStayCompact()
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
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(content: PlannerListContentInput(name: "Tokyo")))
      ).outcome,
      let list = created.generated.first
    else {
      Issue.record("The contextual List must save first.")
      return
    }
    var items: [PlannerEntityReference] = []
    var identities: [PlannerRowIdentity] = []
    for title in ["Z Hotel", "Museum", "Archived stop"] {
      guard
        case .applied(let itemCreated, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(
              content: PlannerItemContentInput(
                title: title, notes: String(repeating: "Long original notes. ", count: 1000),
                location: .init(
                  displayName: title, formattedAddress: "Tokyo",
                  coordinate: .init(latitude: 35, longitude: 139)),
                estimate: .init(minutes: 120, displayUnit: .hour),
                links: [
                  PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
                  PlannerLinkInput(originalUrl: "https://example.com/hotel", label: "Website"),
                ])))
        ).outcome,
        let item = itemCreated.generated.first,
        case .applied(let added, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipId, _, _)? = added.generatedReferences.first
      else {
        Issue.record("Contextual Items must retain source and association identities.")
        return
      }
      items.append(item)
      identities.append(
        .appearance(
          source: item, appearance: .listMembership(listId: list.id, membershipId: membershipId)))
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: items[2].id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: items[2], archived: true))
      ).outcome,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: items[0],
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400),
              end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo"
            )))
      ).outcome,
      let schedule = scheduled.generated.first
    else {
      Issue.record("Archived/global Done and timed preview fixtures must save.")
      return
    }
    let presentation = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_202_200),
      displayTimeZone: "Asia/Tokyo")
    guard
      case .snapshot(let todo) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              scope: .list(list.id), sort: .init(mode: .manual), rowPresentation: presentation))))
    else {
      Issue.record(
        "List scope must expose exact appearance identities and complete-scope progress.")
      return
    }
    guard
      case .snapshot(let alphabetical) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery(scope: .list(list.id))))),
      case .snapshot(let descending) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(scope: .list(list.id), sort: .init(direction: .descending)))))
    else {
      Issue.record("List query defaults and requested title sort must remain display choices.")
      return
    }
    for request in [
      PlannerItemQuery(scope: .list(list.id), sort: .init(mode: .manual, direction: .descending)),
      PlannerItemQuery(scope: .global, sort: .init(mode: .manual)),
      PlannerItemQuery(scope: .inbox, sort: .init(mode: .manual)),
    ] {
      guard
        case .failed(let rejected) = await planner.query(
          PlannerQuery(session: session, request: .items(request)))
      else {
        Issue.record("Manual sort must reject descending and non-List scopes.")
        continue
      }
      #expect(rejected.code == "invalidInput")
      #expect(rejected.propertyPath == "/query/sort")
    }
    #expect(alphabetical.rows == [identities[1], identities[0]])
    #expect(descending.rows == [identities[0], identities[1]])
    #expect(todo.rows == Array(identities.prefix(2)))
    #expect(todo.matchingCount == 2)
    #expect(todo.rowPresentation == presentation)
    #expect(todo.unresolvedReferences.isEmpty)
    #expect(todo.progress.count == 1)
    #expect(todo.progress.first?.container == list)
    #expect(todo.progress.first?.state == .partial)
    #expect(todo.progress.first?.doneCount == 1)
    #expect(todo.progress.first?.totalCount == 3)
    guard
      case .rows(let firstWindow) = await planner.read(
        session: session,
        request: .rows(generation: todo.generation, offset: 0, limit: 1)),
      let first = firstWindow.rows.first,
      case .rows(let beyond) = await planner.read(
        session: session,
        request: .rows(generation: todo.generation, offset: 2, limit: 1)),
      case .snapshot(let done) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              scope: .list(list.id), completion: .done, archive: .all, sort: .init(mode: .manual),
              rowPresentation: presentation
            )))),
      case .rows(let doneWindow) = await planner.read(
        session: session,
        request: .rows(generation: done.generation, offset: 0, limit: 1)),
      let doneRow = doneWindow.rows.first
    else {
      Issue.record("Lazy windows must retain their exact context and selected owned previews.")
      return
    }
    #expect(firstWindow.matchingCount == 2)
    #expect(firstWindow.rowPresentation == presentation)
    #expect(first.identity == identities[0])
    #expect(first.title == "Z Hotel")
    #expect(first.localDone == false)
    #expect(first.globalDone == false)
    #expect(first.effectiveDone == false)
    #expect(first.hasLocation)
    #expect(first.hasLinks)
    #expect(first.ownedLocation?.formattedAddress == "Tokyo")
    #expect(first.estimate?.minutes == 120)
    #expect(first.previewLink?.originalUrl == "https://example.com/hotel")
    #expect(
      first.scheduleSummary
        == .directItem(
          schedule: schedule, owner: items[0],
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400),
            end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo"),
          additionalCount: 0))
    #expect(beyond.rows.isEmpty)
    #expect(beyond.rowPresentation == presentation)
    #expect(done.rows == [identities[2]])
    #expect(done.progress.first?.doneCount == 1)
    #expect(done.progress.first?.totalCount == 3)
    #expect(doneRow.identity == identities[2])
    #expect(doneRow.localDone == false)
    #expect(doneRow.globalDone == true)
    #expect(doneRow.effectiveDone == true)
    #expect(doneRow.archived == true)
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(items[0])),
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: items[0].id, changes: PlannerItemChanges(notes: .set("Booking updated")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: todo.generation, offset: 0, limit: 1)),
      case .snapshot(let refreshed) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              scope: .list(list.id), sort: .init(mode: .manual), rowPresentation: presentation)))),
      case .failed(let missingList) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(PlannerItemQuery(scope: .list(UUID()), rowPresentation: presentation))))
    else {
      Issue.record(
        "Store changes must invalidate old windows while retaining exact surviving appearances.")
      return
    }
    #expect(stale.code == "staleSnapshot")
    #expect(refreshed.generation != todo.generation)
    #expect(refreshed.rows == todo.rows)
    #expect(refreshed.progress.first?.doneCount == 1)
    #expect(refreshed.progress.first?.totalCount == 3)
    #expect(missingList.code == "missingReference")
  }
}
