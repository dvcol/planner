import Foundation
import PlannerCore
import Testing

struct LargeItemWindowTests {
  @Test func titleWindowsTraverseEveryImportedItemAndRevisitTheOriginalPage() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let fixture = try makeLargeWindowFixture()
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(fixture.data),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else {
      Issue.record("Import the complete 5,000-Item and 200-List dataset before reading windows.")
      return
    }
    let presentation = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_198_600),
      displayTimeZone: "Asia/Tokyo")
    let expectedRows = fixture.items.map(PlannerRowIdentity.source)
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .items(.init(completion: .all, archive: .all, rowPresentation: presentation)))),
      case .snapshot(let lists) = await planner.query(
        .init(session: session, request: .catalog(.init(sourceKind: .list, archive: .all))))
    else {
      Issue.record("Both complete source catalogs must be queryable after import.")
      return
    }
    #expect(snapshot.matchingCount == 5000)
    #expect(snapshot.rows == expectedRows)
    #expect(lists.matchingCount == 200)
    #expect(lists.rows == fixture.lists.map(PlannerRowIdentity.source))
    var traversed: [PlannerRowIdentity] = []
    var offset: Int64 = 0
    var pageCount = 0
    while offset < 5000 {
      guard
        case .rows(let window) = await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: offset, limit: 64))
      else {
        Issue.record("Every page of the retained generation must remain readable: \(offset).")
        return
      }
      let expectedEnd = min(Int(offset) + 64, 5000)
      #expect(window.generation == snapshot.generation)
      #expect(window.offset == offset && window.matchingCount == 5000)
      #expect(window.rowPresentation == presentation)
      #expect(window.rows.map(\.identity) == Array(expectedRows[Int(offset)..<expectedEnd]))
      #expect(
        window.rows.allSatisfy {
          $0.globalDone == false && $0.localDone == nil && $0.archived == false
        })
      guard !window.rows.isEmpty else {
        Issue.record("A nonterminal page cannot silently omit the remaining sources.")
        return
      }
      traversed.append(contentsOf: window.rows.map(\.identity))
      offset += Int64(window.rows.count)
      pageCount += 1
    }
    #expect(pageCount == 79)
    #expect(traversed == expectedRows)
    guard
      case .rows(let revisited) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64)),
      case .rows(let exhausted) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 5000, limit: 64)),
      case .snapshot(let filtered) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              text: "Paging Item 05000", completion: .all, archive: .all,
              rowPresentation: presentation)))),
      case .rows(let match) = await planner.read(
        session: session, request: .rows(generation: filtered.generation, offset: 0, limit: 64)),
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record("Revisiting, exhausting and narrowing the complete catalog must remain valid.")
      return
    }
    #expect(revisited.rows.map(\.identity) == Array(expectedRows.prefix(64)))
    #expect(exhausted.rows.isEmpty && exhausted.matchingCount == 5000)
    #expect(filtered.matchingCount == 1)
    #expect(match.rows.map(\.identity) == Array(expectedRows.suffix(1)))
    #expect(match.rows.first?.title == "Paging Item 05000")
    #expect(after == before)
  }

  private func makeLargeWindowFixture() throws -> (
    data: Data, items: [PlannerEntityReference], lists: [PlannerEntityReference]
  ) {
    var sources: [[String: Any]] = []
    var memberships: [[String: Any]] = []
    let lists = (1...200).map { index in
      (index: index, identifier: UUID(), lifetimeIdentifier: UUID())
    }
    var items: [PlannerEntityReference] = []
    for list in lists {
      sources.append([
        "kind": "list", "id": list.identifier.uuidString,
        "lifetimeId": list.lifetimeIdentifier.uuidString,
        "createdAt": 813_000_000 + list.index, "updatedAt": 813_000_000 + list.index,
        "content": [
          "name": String(format: "Paging List %03d", list.index),
          "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
          "manualEstimate": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
      ])
    }
    for index in 1...5000 {
      let itemIdentifier = UUID()
      let itemLifetimeIdentifier = UUID()
      let list = lists[(index - 1) % lists.count]
      items.append(.init(kind: .item, id: itemIdentifier))
      sources.append([
        "kind": "item", "id": itemIdentifier.uuidString,
        "lifetimeId": itemLifetimeIdentifier.uuidString,
        "createdAt": 813_000_000 + index, "updatedAt": 813_100_000 - index,
        "content": [
          "title": String(format: "Paging Item %05d", index), "subtitle": NSNull(),
          "notes": NSNull(), "location": NSNull(),
          "estimate": ["minutes": String(index), "displayUnit": "minute"],
        ],
        "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
      ])
      memberships.append([
        "id": UUID().uuidString, "lifetimeId": UUID().uuidString,
        "list": [
          "kind": "list", "id": list.identifier.uuidString,
          "lifetimeId": list.lifetimeIdentifier.uuidString,
        ],
        "item": [
          "kind": "item", "id": itemIdentifier.uuidString,
          "lifetimeId": itemLifetimeIdentifier.uuidString,
        ],
        "rank": String(((index - 1) / lists.count + 1) * 1024), "localDone": false,
      ])
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": memberships, "itineraryEntries": [], "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
    return (data, items, lists.map { .init(kind: .list, id: $0.identifier) })
  }
}
