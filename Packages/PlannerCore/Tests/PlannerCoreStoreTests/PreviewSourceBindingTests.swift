import Foundation
import PlannerCore
import Testing

struct PreviewSourceBindingTests {
  @Test func sourceRowsAndAppearancesShareTheirLifetimeAcrossChangesAndReopen() async throws {
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
          command: .createItem(
            content: .init(
              title: "Hotel", notes: "Keep these notes",
              location: .init(displayName: nil, formattedAddress: "Tokyo", coordinate: nil),
              links: [.init(originalUrl: "https://example.com/menu", label: "Menu")])))
      )
      .outcome,
      let item = created.generated.first,
      case .applied(let createdList, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      )
      .outcome,
      let list = createdList.generated.first,
      case .applied(let added, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      )
      .outcome,
      case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .appearance(let appearance) = await planner.read(
        session: session,
        request: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier))),
      case .snapshot(let catalog) = await planner.query(
        .init(session: session, request: .items(.init()))),
      case .rows(let sourceWindow) = await planner.read(
        session: session, request: .rows(generation: catalog.generation, offset: 0, limit: 1)),
      let sourceRow = sourceWindow.rows.first,
      case .snapshot(let membershipQuery) = await planner.query(
        .init(session: session, request: .items(.init(scope: .list(list.id))))),
      case .rows(let appearanceWindow) = await planner.read(
        session: session,
        request: .rows(generation: membershipQuery.generation, offset: 0, limit: 1)),
      let appearanceRow = appearanceWindow.rows.first
    else {
      Issue.record("One saved Item must be readable in its source and live List contexts.")
      return
    }
    #expect(sourceRow.sourceLifetimeId == original.sourceLifetimeId)
    #expect(appearanceRow.sourceLifetimeId == original.sourceLifetimeId)
    #expect(appearance.sourceLifetimeId == original.sourceLifetimeId)
    #expect(sourceRow.previewLink == original.content.links.first)
    #expect(appearanceRow.ownedLocation == original.content.location)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(
              .listMembership(listId: list.id, membershipId: membershipIdentifier)),
            done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id, changes: .init(notes: .set("Revised notes")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome
    else {
      Issue.record("Ordinary contextual completion and notes edits must save.")
      return
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .appearance(let currentAppearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier))),
      case .snapshot(let currentQuery) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(.init(scope: .list(list.id), completion: .all)))),
      case .rows(let currentWindow) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: currentQuery.generation, offset: 0, limit: 1)),
      let currentRow = currentWindow.rows.first
    else {
      Issue.record("The same source and completed appearance must survive reopening.")
      return
    }
    #expect(current.sourceLifetimeId == original.sourceLifetimeId)
    #expect(currentAppearance.sourceLifetimeId == original.sourceLifetimeId)
    #expect(currentRow.sourceLifetimeId == original.sourceLifetimeId)
    #expect(currentRow.effectiveDone == true)
    #expect(current.state.globalDone == false)
    #expect(current.content.notes == "Revised notes")
    #expect(current.content.links == original.content.links)
    #expect(reopenedSession.datasetId == session.datasetId)
    #expect(reopenedSession.ownershipBinding == session.ownershipBinding)
  }
}
