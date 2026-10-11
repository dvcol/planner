import Foundation
import PlannerCore
import Testing

struct ItineraryCatalogTests {
  @Test func itineraryCatalogKeepsDuplicateIdentitiesNativeMatchingAndLiveWindowPreviews()
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
      case .snapshot(let empty) = await planner.query(
        .init(session: session, request: .catalog(.init(sourceKind: .itinerary))))
    else {
      Issue.record("Itinerary discovery must distinguish a valid empty catalog from unavailable.")
      return
    }
    #expect(empty.rows.isEmpty && empty.matchingCount == 0 && empty.rowPresentation == nil)
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let location = PlannerOwnedLocation(
      displayName: "Tokyo", formattedAddress: "Tokyo, Japan",
      coordinate: .init(latitude: 35, longitude: 139))
    let mapsUrl = "https://maps.apple.com/?q=Tokyo"
    let websiteUrl = "https://example.com/cafe"
    let contents: [PlannerItineraryContentInput] = [
      .init(title: "Zoo", notes: "Hidden notes"),
      .init(
        title: "CAFÉ GUIDE", notes: "Long private notes", location: location,
        links: [.init(originalUrl: mapsUrl), .init(originalUrl: websiteUrl, label: "Guide")]),
      .init(title: "cafe guide", links: [.init(originalUrl: mapsUrl)]),
      .init(title: "Cafe cafe"),
    ]
    var sources: [PlannerEntityReference] = []
    for content in contents {
      sources.append(
        try #require(try await save(.createItinerary(content: content)).generated.first))
    }
    _ = try await save(.createItem(content: .init(title: "CAFÉ GUIDE")))
    _ = try await save(.setArchive(source: sources[0], archived: true))
    func catalog(_ archive: PlannerItemQuery.Archive, text: String = "") async throws
      -> PlannerQuerySnapshot
    {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .catalog(.init(sourceKind: .itinerary, text: text, archive: archive))))
      else { throw CancellationError() }
      return snapshot
    }
    let tied = [sources[1], sources[2]].sorted { $0.id.uuidString < $1.id.uuidString }
    let active = try await catalog(.active)
    let archived = try await catalog(.archived)
    let all = try await catalog(.all)
    let searched = try await catalog(.all, text: "  GUIDE\nCaFe  ")
    #expect(active.rows == ([sources[3]] + tied).map(PlannerRowIdentity.source))
    #expect(archived.rows == [.source(sources[0])])
    #expect(all.rows == ([sources[3]] + tied + [sources[0]]).map(PlannerRowIdentity.source))
    #expect(searched.rows == tied.map(PlannerRowIdentity.source))
    #expect(all.matchingCount == 4 && searched.matchingCount == 2)
    #expect(all.progress.isEmpty && all.unresolvedReferences.isEmpty && all.rowPresentation == nil)
    guard
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: all.generation, offset: 0, limit: 4)),
      case .rows(let second) = await planner.read(
        session: session, request: .rows(generation: searched.generation, offset: 1, limit: 1)),
      case .rows(let beyond) = await planner.read(
        session: session, request: .rows(generation: all.generation, offset: 4, limit: 1))
    else { throw CancellationError() }
    #expect(window.rows.map(\.identity) == all.rows)
    #expect(window.matchingCount == 4 && window.rowPresentation == nil)
    #expect(second.rows.map(\.identity) == [.source(tied[1])])
    #expect(beyond.rows.isEmpty && beyond.matchingCount == 4)
    let rich = try #require(window.rows.first { $0.identity == .source(sources[1]) })
    let mapsOnly = try #require(window.rows.first { $0.identity == .source(sources[2]) })
    let plain = try #require(window.rows.first { $0.identity == .source(sources[3]) })
    #expect(rich.title == "CAFÉ GUIDE" && rich.ownedLocation == location && rich.hasLocation)
    #expect(rich.hasLinks && rich.previewLink?.originalUrl == websiteUrl)
    #expect(rich.previewLink?.label == "Guide" && rich.previewLink?.kind == .website)
    #expect(mapsOnly.hasLinks && mapsOnly.previewLink == nil && !mapsOnly.hasLocation)
    #expect(!plain.hasLinks && plain.previewLink == nil && plain.ownedLocation == nil)
    for row in window.rows {
      #expect(row.globalDone == nil && row.localDone == nil && row.effectiveDone == nil)
      #expect(row.estimate == nil && row.subtitle == nil && row.scheduleSummary == .none)
      #expect(row.archived == (row.identity == .source(sources[0])))
    }
    guard
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(sources[1]))
    else { throw CancellationError() }
    #expect(rich.previewLink?.linkId == original.content.links[1].linkId)
    #expect(original.sourceLifetimeId == rich.sourceLifetimeId)
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        .init(
          operationId: UUID(), session: otherSession,
          command: .editItinerary(
            sourceId: sources[1].id, changes: .init(title: .set("Alpine")),
            expectedFieldHashes: [.title: try #require(original.fieldHashes[.title])]))
      ).outcome,
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: all.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    let refreshed = try await catalog(.all)
    #expect(refreshed.generation != all.generation)
    #expect(
      refreshed.rows
        == [sources[1], sources[3], sources[2], sources[0]].map(PlannerRowIdentity.source))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let retained) = await reopened.query(
        .init(session: reopenedSession, request: .catalog(.init(sourceKind: .itinerary)))),
      case .rows(let retainedWindow) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: retained.generation, offset: 0, limit: 1))
    else { throw CancellationError() }
    #expect(retained.rows == [sources[1], sources[3], sources[2]].map(PlannerRowIdentity.source))
    #expect(retainedWindow.rows.first?.title == "Alpine")
    #expect(retainedWindow.rows.first?.previewLink?.originalUrl == websiteUrl)
  }
}
