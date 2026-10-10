import Foundation
import PlannerCore
import Testing

struct ItemTextQueryTests {
  struct SearchExample: Sendable {
    let text: String
    let expectedTitles: [String]
  }

  @Test(arguments: [
    SearchExample(text: "cafe", expectedTitles: ["Café tasting"]),
    SearchExample(text: "CAFÉ", expectedTitles: ["Café tasting"]),
    SearchExample(text: "Cafe\u{301}", expectedTitles: ["Café tasting"]),
    SearchExample(text: "Lunch", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "Afternoon", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "VEGETARIAN", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "Menu", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "Ginza", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "Meeting", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "/ramen", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "vegetarian\t\nmenu", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "https://example.com/ramen", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "example.COM /ramen", expectedTitles: ["Ramen lunch"]),
    SearchExample(text: "lunchmenu", expectedTitles: []),
    SearchExample(text: "rainy*", expectedTitles: []),
    SearchExample(text: "cfae", expectedTitles: []),
    SearchExample(text: "meal", expectedTitles: []),
    SearchExample(text: " \t\n ", expectedTitles: ["Café tasting", "Ramen lunch"]),
    SearchExample(text: "", expectedTitles: ["Café tasting", "Ramen lunch"]),
    SearchExample(text: "cafe menu", expectedTitles: []),
  ])
  func literalSearchUsesEverySavedFieldAndInsensitiveNativeMatching(example: SearchExample)
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
      Issue.record("The real dataset must initialize for the independent lexical examples.")
      return
    }
    let inputs = [
      PlannerItemContentInput(
        title: "Ramen lunch", subtitle: "Afternoon pause", notes: "Check vegetarian options",
        location: PlannerOwnedLocation(
          displayName: "Meeting point", formattedAddress: "Ginza fixture address", coordinate: nil),
        links: [PlannerLinkInput(originalUrl: "https://example.com/ramen", label: "Menu")]),
      PlannerItemContentInput(title: "Café tasting"),
    ]
    var sources: [String: PlannerEntityReference] = [:]
    for input in inputs {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: .createItem(content: input))
        ).outcome,
        let source = creation.generated.first
      else {
        Issue.record("Both independent lexical fixture Items must save.")
        return
      }
      sources[input.title] = source
    }
    let expectedRows = try example.expectedTitles.map {
      PlannerRowIdentity.source(try #require(sources[$0]))
    }
    for scope in [PlannerItemQuery.Scope.global, .inbox] {
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session, request: .items(.init(scope: scope, text: example.text))))
      else {
        Issue.record("The accepted text query must return a complete identity snapshot.")
        return
      }
      #expect(snapshot.rows == expectedRows)
      #expect(snapshot.matchingCount == Int64(example.expectedTitles.count))
      for offset in snapshot.rows.indices {
        guard
          case .rows(let window) = await planner.read(
            session: session,
            request: .rows(generation: snapshot.generation, offset: Int64(offset), limit: 1))
        else {
          Issue.record("A matching identity must remain readable in its generation.")
          return
        }
        #expect(window.rows.first?.identity == expectedRows[offset])
        #expect(window.rows.first?.title == example.expectedTitles[offset])
      }
    }
  }

  @Test func anotherWriterChangesSearchResultsAndInvalidatesTheIssuedWindow() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Friday booking")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(text: "Friday"))))
    else {
      Issue.record("The saved Friday Item and issued search generation must exist first.")
      return
    }
    #expect(issued.rows == [.source(source)])
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .editItem(
            sourceId: source.id, changes: .init(notes: .set("Monday booking")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .snapshot(let friday) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(text: "Friday")))),
      case .snapshot(let monday) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(text: "Monday")))),
      case .rows(let currentWindow) = await planner.read(
        session: session, request: .rows(generation: monday.generation, offset: 0, limit: 1)),
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(source))
    else {
      Issue.record(
        "The first reader must reject its old window and query the other writer's saved text.")
      return
    }
    #expect(stale.code == "staleSnapshot")
    #expect(friday.matchingCount == 0)
    #expect(friday.rows.isEmpty)
    #expect(monday.rows == [.source(source)])
    #expect(monday.generation != issued.generation)
    #expect(currentWindow.rows.first?.identity == .source(source))
    #expect(current.content.notes == "Monday booking")
    #expect(current.content.title == "Hotel")
    #expect(current.fieldHashes[.title] == original.fieldHashes[.title])
  }

  @Test func listSearchNarrowsEffectiveStateWithoutChangingProgressOrManualOrder() async throws {
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
          command: .createList(content: .init(name: "Tokyo Food")))
      ).outcome,
      let list = listCreation.generated.first
    else {
      Issue.record("The saved List must initialize.")
      return
    }
    var sources: [PlannerEntityReference] = []
    var appearances: [PlannerAppearance] = []
    for title in ["Café tasting", "Gardens", "Finished café", "Archived café"] {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: title)))
        ).outcome,
        let source = creation.generated.first,
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Each fixture Item must have one saved List appearance.")
        return
      }
      sources.append(source)
      appearances.append(.listMembership(listId: list.id, membershipId: membershipIdentifier))
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(appearances[0]), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: sources[2].id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: sources[3], archived: true))
      ).outcome,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("The independent local/global completion and archive states must save first.")
      return
    }
    let manual = PlannerItemQuery.Sort(mode: .manual)
    guard
      case .snapshot(let ordinary) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(.init(scope: .list(list.id), text: "cafe", sort: manual))))
    else {
      Issue.record("List text search must combine with effective Todo/Active filtering.")
      return
    }
    #expect(ordinary.matchingCount == 0)
    #expect(ordinary.rows.isEmpty)
    #expect(ordinary.progress.first?.doneCount == 2)
    #expect(ordinary.progress.first?.totalCount == 4)
    guard
      case .snapshot(let allStates) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), text: "cafe", completion: .all, archive: .all, sort: manual)))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: allStates.generation, offset: 1, limit: 1)),
      case .snapshot(let clearedText) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(scope: .list(list.id), completion: .all, archive: .all, sort: manual)))),
      case .snapshot(let globalTodo) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(text: "cafe")))),
      case .source(.list(let current)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Filtered rows, cleared search and unchanged saved order must stay available.")
      return
    }
    #expect(allStates.matchingCount == 3)
    #expect(
      allStates.rows == [
        .appearance(source: sources[0], appearance: appearances[0]),
        .appearance(source: sources[2], appearance: appearances[2]),
        .appearance(source: sources[3], appearance: appearances[3]),
      ])
    #expect(allStates.progress.first?.doneCount == 2)
    #expect(allStates.progress.first?.totalCount == 4)
    #expect(
      window.rows.first?.identity == .appearance(source: sources[2], appearance: appearances[2]))
    #expect(window.rows.first?.effectiveDone == true)
    #expect(
      clearedText.rows == [
        .appearance(source: sources[0], appearance: appearances[0]),
        .appearance(source: sources[1], appearance: appearances[1]),
        .appearance(source: sources[2], appearance: appearances[2]),
        .appearance(source: sources[3], appearance: appearances[3]),
      ])
    #expect(globalTodo.rows == [.source(sources[0])])
    #expect(current.references == original.references)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.fieldHashes == original.fieldHashes)
  }

  @Test func allSearchWordsMatchAcrossSavedFieldsWithoutChangingContentAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    let ramenResult = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(
            title: "Ramen lunch", subtitle: "Lunch break", notes: "Check vegetarian options",
            location: PlannerOwnedLocation(
              displayName: "Cafe meeting point", formattedAddress: "Ginza fixture address",
              coordinate: nil),
            links: [PlannerLinkInput(originalUrl: "https://example.com/ramen", label: "Menu")]))))
    let gardensResult = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(
            title: "Vegetarian gardens", notes: "Outdoor walk",
            links: [PlannerLinkInput(originalUrl: "https://example.com/gardens", label: "Guide")])))
    )
    guard case .applied(let ramenCreation, .complete) = ramenResult.outcome,
      case .applied(_, .complete) = gardensResult.outcome,
      let ramen = ramenCreation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(ramen))
    else {
      Issue.record("Both saved Items must exist before the cross-field search.")
      return
    }
    let query = PlannerItemQuery(text: "  VEGETARIAN\t\nmenu  ")
    guard
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(query))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("The search and issued row window must be available.")
      return
    }
    #expect(snapshot.matchingCount == 1)
    #expect(snapshot.rows == [.source(ramen)])
    #expect(window.matchingCount == 1)
    #expect(window.rows.first?.identity == .source(ramen))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let reopenedSnapshot) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .items(query))),
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(ramen))
    else {
      Issue.record("Saved cross-field search must survive public reopening.")
      return
    }
    #expect(reopenedSnapshot.matchingCount == 1)
    #expect(reopenedSnapshot.rows == [.source(ramen)])
    #expect(current.content.title == "Ramen lunch")
    #expect(current.content.notes == "Check vegetarian options")
    #expect(current.content.links.first?.label == "Menu")
    #expect(current.createdAt == original.createdAt)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(current.references == original.references)
    #expect(current.state.globalDone == false)
    #expect(current.state.archived == false)
  }
}
