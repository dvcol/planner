import Foundation
import PlannerCore
import Testing

struct MapRowWindowTests {
  @Test func mapPagesRetainEveryMatchingIdentityAndSavedLocationInput() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let fixture = try makeMapWindowFixture()
    let bootstrap = await planner.bootstrap()
    guard case .ready(let session) = bootstrap else {
      Issue.record("Open the Map fixture: \(bootstrap)")
      return
    }
    let imported = planner.decodeImport(fixture.data)
    guard case .decoded(let backup) = imported else {
      Issue.record("Decode the Map fixture: \(imported)")
      return
    }
    let reviewed = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup))
    guard case .reviewed(let review) = reviewed else {
      Issue.record("Review the Map fixture: \(reviewed)")
      return
    }
    let saved = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = saved.outcome else {
      Issue.record("Save the Map fixture: \(saved)")
      return
    }
    guard case .exported(let before) = await planner.exportData(session: session),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    #expect(snapshot.rows == fixture.identities)
    #expect(snapshot.matchingCount == 130)
    var rows: [PlannerMapRowRead] = []
    for offset: Int64 in [0, 64, 128, 130] {
      let result = await planner.read(
        session: session,
        request: .mapRows(generation: snapshot.generation, offset: offset, limit: 64))
      guard case .mapRows(let page) = result else {
        Issue.record("Read the complete saved Map inputs at offset \(offset): \(result)")
        return
      }
      #expect(page.generation == snapshot.generation && page.offset == offset)
      #expect(page.matchingCount == 130)
      #expect(page.collection == nil && page.listBranches.isEmpty)
      #expect(
        page.rows.map(\.identity)
          == Array(fixture.identities[Int(offset)..<min(Int(offset) + 64, 130)]))
      rows.append(contentsOf: page.rows)
    }
    #expect(rows.map(\.identity) == fixture.identities)
    for (index, row) in rows.enumerated() {
      let position = index + 1
      #expect(row.title == String(format: "Map Item %03d", position))
      #expect(row.sourceLifetimeId == fixture.lifetimes[index])
      #expect(row.placement == nil)
      guard [1, 64, 65, 130].contains(position) else {
        #expect(row.ownedLocation == nil && row.mapsLinks.isEmpty)
        continue
      }
      #expect(
        row.ownedLocation
          == .init(
            displayName: "Saved place \(position)", formattedAddress: "Address \(position)",
            coordinate: .init(latitude: 35, longitude: 139)))
      #expect(row.mapsLinks.map(\.linkId) == fixture.mapsLinkIdentifiers[position])
      #expect(
        row.mapsLinks.map(\.originalUrl) == [
          "https://maps.apple.com/?q=Place%20\(position)",
          "https://www.google.com/maps/search/?api=1&query=Place%20\(position)",
        ])
      #expect(row.mapsLinks.map(\.label) == ["Apple \(position)", "Google \(position)"])
      #expect(row.mapsLinks.map(\.kind) == [.appleMaps, .googleMaps])
      #expect(row.mapsLinks.first?.providerReference?.kind == .applePlaceId)
      #expect(row.mapsLinks.first?.providerReference?.value == "Place\(position)")
      #expect(row.mapsLinks.last?.providerReference == nil)
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let category = try #require(
      try await save(.createCategory(content: .init(name: "Selected"))).generated.first)
    let selectedPositions = [65, 130]
    for position in selectedPositions {
      guard case .source(let source) = fixture.identities[position - 1],
        case .source(.item(let current)) = await planner.read(
          session: session, request: .source(source))
      else { throw CancellationError() }
      _ = try await save(
        .editItem(
          sourceId: source.id, changes: .init(categoryIds: .set([category.id])),
          expectedFieldHashes: current.fieldHashes))
    }
    let list = try #require(
      try await save(.createList(content: .init(name: "Already listed"))).generated.first)
    guard case .source(let firstItem) = fixture.identities[0] else { throw CancellationError() }
    _ = try await save(.addMembership(itemId: firstItem.id, listId: list.id, placement: .last))
    guard case .exported(let filteredBefore) = await planner.exportData(session: session),
      case .snapshot(let filtered) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .inbox, text: "Map Item", completion: .all, archive: .all,
              categories: .init(ids: [category.id], match: .any), hasAddress: true, hasLinks: true))
        ))
    else { throw CancellationError() }
    #expect(filtered.rows == selectedPositions.map { fixture.identities[$0 - 1] })
    #expect(filtered.matchingCount == 2)
    for (offset, position) in selectedPositions.enumerated() {
      guard
        case .mapRows(let page) = await planner.read(
          session: session,
          request: .mapRows(generation: filtered.generation, offset: Int64(offset), limit: 1))
      else { throw CancellationError() }
      #expect(page.matchingCount == 2 && page.collection == nil && page.listBranches.isEmpty)
      #expect(page.rows.map(\.identity) == [fixture.identities[position - 1]])
      #expect(page.rows.first?.mapsLinks.map(\.linkId) == fixture.mapsLinkIdentifiers[position])
    }
    guard case .exported(let filteredAfter) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(filteredBefore == filteredAfter)
  }

  private func makeMapWindowFixture() throws -> (
    data: Data, identities: [PlannerRowIdentity], lifetimes: [UUID],
    mapsLinkIdentifiers: [Int: [UUID]]
  ) {
    var sources: [[String: Any]] = []
    var links: [[String: Any]] = []
    var identities: [PlannerRowIdentity] = []
    var lifetimes: [UUID] = []
    var mapsLinkIdentifiers: [Int: [UUID]] = [:]
    for position in 1...130 {
      let identifier = UUID()
      let lifetime = UUID()
      identities.append(.source(.init(kind: .item, id: identifier)))
      lifetimes.append(lifetime)
      let located = [1, 64, 65, 130].contains(position)
      let location: Any
      if located {
        location = [
          "displayName": "Saved place \(position)", "formattedAddress": "Address \(position)",
          "coordinate": ["latitude": 35, "longitude": 139],
        ]
      } else {
        location = NSNull()
      }
      var contentOrigins = ["title": "independent", "notes": "independent"]
      if located { contentOrigins["location"] = "independent" }
      sources.append([
        "kind": "item", "id": identifier.uuidString, "lifetimeId": lifetime.uuidString,
        "createdAt": 813_000_000, "updatedAt": 813_000_000,
        "content": [
          "title": String(format: "Map Item %03d", position), "subtitle": NSNull(),
          "notes": "Notes are excluded from Map rows", "location": location,
          "estimate": NSNull(),
        ],
        "globalDone": false, "archived": false, "contentOrigins": contentOrigins,
      ])
      guard located else { continue }
      let appleIdentifier = UUID()
      let googleIdentifier = UUID()
      mapsLinkIdentifiers[position] = [appleIdentifier, googleIdentifier]
      let examples: [(UUID, String, String, String, Any)] = [
        (
          appleIdentifier, "https://maps.apple.com/?q=Place%20\(position)", "Apple \(position)",
          "appleMaps",
          ["kind": "applePlaceId", "value": "Place\(position)"]
        ),
        (UUID(), "https://example.com/guide/\(position)", "Guide", "website", NSNull()),
        (
          googleIdentifier, "https://www.google.com/maps/search/?api=1&query=Place%20\(position)",
          "Google \(position)", "googleMaps", NSNull()
        ),
      ]
      for (rank, example) in examples.enumerated() {
        links.append([
          "id": example.0.uuidString, "lifetimeId": UUID().uuidString,
          "owner": [
            "kind": "item", "id": identifier.uuidString, "lifetimeId": lifetime.uuidString,
          ],
          "rank": String(rank * 1024), "originalUrl": example.1, "label": example.2,
          "kind": example.3, "providerReference": example.4,
        ])
      }
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": [], "itineraryEntries": [], "schedules": [], "labelAssociations": [],
      "ownedLinks": links, "completionChanges": [], "expandedCompletions": [],
      "contextAliases": [], "restorationFamilies": [], "deletionMarkers": [],
    ])
    return (data, identities, lifetimes, mapsLinkIdentifiers)
  }
}
