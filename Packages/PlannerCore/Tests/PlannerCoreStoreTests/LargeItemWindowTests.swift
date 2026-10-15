import Foundation
import PlannerCore
import Testing

struct LargeItemWindowTests {
  @Test func sortedWindowsTraverseEveryImportedItemAndRetainEarlierGenerations() async throws {
    /// The runner removes this store after SwiftData's test process exits.
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerLargeItemWindowTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    print("Large Item window fixture: \(directory.path)")
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
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let savedBackup) = planner.decodeImport(before)
    else {
      Issue.record("Import the complete 5,000-Item and 200-List dataset before reading windows.")
      return
    }
    #expect(savedBackup.backup.items.count == 5000)
    #expect(savedBackup.backup.lists.count == 200)
    let savedMemberships = savedBackup.backup.memberships
    #expect(savedMemberships.count == 5000)
    #expect(Set(savedMemberships.map(\.id)).count == 5000)
    #expect(Set(savedMemberships.map(\.item.id)) == Set(fixture.items.map(\.id)))
    let membershipsByList = Dictionary(grouping: savedMemberships, by: \.list.id)
    #expect(Set(membershipsByList.keys) == Set(fixture.lists.map(\.id)))
    #expect(membershipsByList.values.allSatisfy { $0.count == 25 })
    #expect(savedMemberships.allSatisfy { !$0.localDone })
    let presentation = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_198_600),
      displayTimeZone: "Asia/Tokyo")
    let forwardRows = fixture.items.map(PlannerRowIdentity.source)
    let reversedRows = Array(forwardRows.reversed())
    let scenarios:
      [(name: String, sort: PlannerItemQuery.Sort, expectedRows: [PlannerRowIdentity])] = [
        ("Title ascending", .init(mode: .title), forwardRows),
        ("Title descending", .init(mode: .title, direction: .descending), reversedRows),
        ("Created ascending", .init(mode: .created), forwardRows),
        ("Created descending", .init(mode: .created, direction: .descending), reversedRows),
        ("Last updated ascending", .init(mode: .lastUpdated), reversedRows),
        ("Last updated descending", .init(mode: .lastUpdated, direction: .descending), forwardRows),
        ("Duration ascending", .init(mode: .duration), forwardRows),
        ("Duration descending", .init(mode: .duration, direction: .descending), reversedRows),
      ]
    guard
      case .snapshot(let lists) = await planner.query(
        .init(session: session, request: .catalog(.init(sourceKind: .list, archive: .all))))
    else {
      Issue.record("The complete List catalog must be queryable after import.")
      return
    }
    #expect(lists.matchingCount == 200)
    #expect(lists.rows == fixture.lists.map(PlannerRowIdentity.source))
    var oldestGeneration: UUID?
    for scenario in scenarios {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .items(
              .init(
                completion: .all, archive: .all, sort: scenario.sort,
                rowPresentation: presentation))))
      else {
        Issue.record("Query the complete Item catalog using \(scenario.name).")
        return
      }
      if oldestGeneration == nil { oldestGeneration = snapshot.generation }
      #expect(snapshot.matchingCount == 5000)
      #expect(snapshot.rows == scenario.expectedRows, "\(scenario.name)")
      var traversed: [PlannerRowIdentity] = []
      var offset: Int64 = 0
      var pageCount = 0
      while offset < 5000 {
        guard
          case .rows(let window) = await planner.read(
            session: session,
            request: .rows(generation: snapshot.generation, offset: offset, limit: 64))
        else {
          Issue.record("\(scenario.name) page at \(offset) must remain readable.")
          return
        }
        let expectedEnd = min(Int(offset) + 64, 5000)
        #expect(window.generation == snapshot.generation)
        #expect(window.offset == offset && window.matchingCount == 5000)
        #expect(window.rowPresentation == presentation)
        #expect(
          window.rows.map(\.identity) == Array(scenario.expectedRows[Int(offset)..<expectedEnd]),
          "\(scenario.name)")
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
      #expect(traversed == scenario.expectedRows, "\(scenario.name)")
      guard
        case .rows(let revisited) = await planner.read(
          session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64)),
        case .rows(let exhausted) = await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: 5000, limit: 64))
      else {
        Issue.record("Revisit and exhaust the retained \(scenario.name) generation.")
        return
      }
      #expect(revisited.rows.map(\.identity) == Array(scenario.expectedRows.prefix(64)))
      #expect(exhausted.rows.isEmpty && exhausted.matchingCount == 5000)
    }
    guard let oldestGeneration,
      case .rows(let oldestPage) = await planner.read(
        session: session,
        request: .rows(generation: oldestGeneration, offset: 0, limit: 64)),
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
      Issue.record("The oldest retained page and the sole far-end search must remain readable.")
      return
    }
    #expect(oldestPage.rows.map(\.identity) == Array(forwardRows.prefix(64)))
    #expect(filtered.matchingCount == 1)
    #expect(match.rows.map(\.identity) == Array(forwardRows.suffix(1)))
    #expect(match.rows.first?.title == "Paging Item 05000")
    #expect(after == before)
  }

  @Test func secondWriterInvalidatesLargeItemWindowsWithoutLosingSavedReferences() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerLargeItemWindowTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    print("Large Item window fixture: \(directory.path)")
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let fixture = try makeLargeWindowFixture()
    let lastItem = try #require(fixture.items.last)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(fixture.data),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let originalBackup) = planner.decodeImport(originalData),
      case .snapshot(let original) = await planner.query(
        .init(session: session, request: .items(.init()))),
      case .rows(let firstPage) = await planner.read(
        session: session, request: .rows(generation: original.generation, offset: 0, limit: 64))
    else {
      Issue.record("Import and read the first page of the original 5,000 Todo Items.")
      return
    }
    #expect(original.matchingCount == 5000)
    #expect(original.rows == fixture.items.map(PlannerRowIdentity.source))
    #expect(firstPage.rows.map(\.identity) == Array(original.rows.prefix(64)))
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        .init(
          operationId: UUID(), session: otherSession,
          command: .setCompletion(scope: .globalItem(itemId: lastItem.id), done: true))
      ).outcome
    else {
      Issue.record("The second writer must durably complete Item 05000 between page reads.")
      return
    }
    for offset: Int64 in [64, 0, 4992] {
      guard
        case .failed(let failure) = await planner.read(
          session: session,
          request: .rows(generation: original.generation, offset: offset, limit: 64))
      else {
        Issue.record("An obsolete generation must reject its page at \(offset).")
        return
      }
      #expect(failure.code == "staleSnapshot")
      #expect(
        failure.details
          == .staleSnapshot(requestedGeneration: original.generation, currentGeneration: nil))
    }
    let expectedRows = fixture.items.dropLast().map(PlannerRowIdentity.source)
    guard
      case .snapshot(let refreshed) = await planner.query(
        .init(session: session, request: .items(.init())))
    else {
      Issue.record("The original reader must refresh its Todo query after the other writer.")
      return
    }
    #expect(refreshed.generation != original.generation)
    #expect(refreshed.matchingCount == 4999)
    #expect(refreshed.rows == expectedRows)
    var traversed: [PlannerRowIdentity] = []
    var pageCount = 0
    for offset in stride(from: 0, to: 4999, by: 64) {
      guard
        case .rows(let page) = await planner.read(
          session: session,
          request: .rows(generation: refreshed.generation, offset: Int64(offset), limit: 64))
      else {
        Issue.record("Read the complete refreshed generation at \(offset).")
        return
      }
      #expect(page.generation == refreshed.generation)
      #expect(page.offset == Int64(offset) && page.matchingCount == 4999)
      #expect(page.rows.map(\.identity) == Array(expectedRows[offset..<min(offset + 64, 4999)]))
      #expect(page.rows.allSatisfy { $0.globalDone == false && $0.archived == false })
      traversed.append(contentsOf: page.rows.map(\.identity))
      pageCount += 1
    }
    #expect(pageCount == 79)
    #expect(traversed == expectedRows)
    guard
      case .source(.item(let completed)) = await planner.read(
        session: session, request: .source(lastItem)),
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let savedBackup) = planner.decodeImport(after)
    else {
      Issue.record("Read the retained completed source and complete graph after refresh.")
      return
    }
    #expect(completed.source == lastItem)
    #expect(completed.state.globalDone == true && completed.state.archived == false)
    #expect(Set(savedBackup.backup.items.map(\.id)) == Set(fixture.items.map(\.id)))
    #expect(Set(savedBackup.backup.lists.map(\.id)) == Set(fixture.lists.map(\.id)))
    let memberships = savedBackup.backup.memberships
    #expect(
      Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0) })
        == Dictionary(
          uniqueKeysWithValues: originalBackup.backup.memberships.map { ($0.id, $0) }))
    #expect(memberships.count == 5000 && Set(memberships.map(\.id)).count == 5000)
    #expect(Set(memberships.map(\.item.id)) == Set(fixture.items.map(\.id)))
    let membershipsByList = Dictionary(grouping: memberships, by: \.list.id)
    #expect(Set(membershipsByList.keys) == Set(fixture.lists.map(\.id)))
    #expect(membershipsByList.values.allSatisfy { $0.count == 25 })
    #expect(memberships.allSatisfy { !$0.localDone })
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
