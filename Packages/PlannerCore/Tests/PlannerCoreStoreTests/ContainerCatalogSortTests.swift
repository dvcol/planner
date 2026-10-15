import Foundation
import PlannerCore
import Testing

struct ContainerCatalogSortTests {
  @Test func externalEditsRefreshCatalogOrderWithoutRewritingParentDatesOrReferences() async throws
  {
    let configuration = makeConfiguration()
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    func catalog(_ kind: PlannerEntityKind, _ mode: PlannerCatalogQuery.Sort.Mode) async throws
      -> PlannerQuerySnapshot
    {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .catalog(.init(sourceKind: kind, archive: .all, sort: .init(mode: mode)))))
      else { throw CancellationError() }
      return snapshot
    }
    func metadata(_ source: PlannerEntityReference) async throws -> (
      created: Date, updated: Date, references: [PlannerReferenceRead]
    ) {
      switch await planner.read(session: session, request: .source(source)) {
      case .source(.list(let value)): return (value.createdAt, value.updatedAt, value.references)
      case .source(.itinerary(let value)):
        return (value.createdAt, value.updatedAt, value.references)
      default: throw CancellationError()
      }
    }
    var items: [PlannerEntityReference] = []
    for (title, minutes) in [("Shared", Int64(30)), ("Fixed", 60)] {
      items.append(
        try #require(
          try await save(
            .createItem(
              content: .init(title: title, estimate: .init(minutes: minutes, displayUnit: .minute)))
          )
          .generated.first))
    }
    var lists: [PlannerEntityReference] = []
    for (index, name) in ["Zulu", "Alpha"].enumerated() {
      let list = try #require(
        try await save(.createList(content: .init(name: name))).generated.first)
      let addition = try await save(
        .addMembership(itemId: items[index].id, listId: list.id, placement: .last))
      if index == 0 {
        guard case .membership(let identifier, _, _)? = addition.generatedReferences.first else {
          throw CancellationError()
        }
        _ = try await save(
          .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: identifier)),
            done: true))
      }
      lists.append(list)
    }
    var itineraries: [PlannerEntityReference] = []
    for (index, title) in ["Zulu", "Alpha"].enumerated() {
      let itinerary = try #require(
        try await save(.createItinerary(content: .init(title: title))).generated.first)
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: lists[index], placement: .last))
      itineraries.append(itinerary)
    }
    let pairs: [(kind: PlannerEntityKind, sources: [PlannerEntityReference])] = [
      (.list, lists), (.itinerary, itineraries),
    ]
    var originalMetadata:
      [UUID: (created: Date, updated: Date, references: [PlannerReferenceRead])] = [:]
    var generations: [UUID] = []
    for pair in pairs {
      for source in pair.sources { originalMetadata[source.id] = try await metadata(source) }
      let first = try #require(originalMetadata[pair.sources[0].id])
      let second = try #require(originalMetadata[pair.sources[1].id])
      try #require(first.created < second.created && first.updated < second.updated)
      for mode in [PlannerCatalogQuery.Sort.Mode.fullEstimate, .lastUpdated] {
        let snapshot = try await catalog(pair.kind, mode)
        #expect(snapshot.rows == pair.sources.map(PlannerRowIdentity.source))
        generations.append(snapshot.generation)
      }
    }
    guard case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let originalBackup) = planner.decodeImport(originalData)
    else { throw CancellationError() }
    let writer = Planner(configuration: configuration)
    guard case .ready(let writerSession) = await writer.bootstrap(),
      case .source(.item(let item)) = await writer.read(
        session: writerSession, request: .source(items[0])),
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .editItem(
            sourceId: items[0].id,
            changes: .init(estimate: .set(.init(minutes: 120, displayUnit: .minute))),
            expectedFieldHashes: item.fieldHashes))
      ).outcome
    else { throw CancellationError() }
    for generation in generations {
      for offset in [Int64(1), 0] {
        guard
          case .failed(let failure) = await planner.read(
            session: session, request: .rows(generation: generation, offset: offset, limit: 1))
        else { throw CancellationError() }
        #expect(failure.code == "staleSnapshot")
      }
    }
    guard case .exported(let childEditData) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    for pair in pairs {
      let full = try await catalog(pair.kind, .fullEstimate)
      let updated = try await catalog(pair.kind, .lastUpdated)
      #expect(full.rows == pair.sources.reversed().map(PlannerRowIdentity.source))
      #expect(updated.rows == pair.sources.map(PlannerRowIdentity.source))
      guard
        case .rows(let window) = await planner.read(
          session: session, request: .rows(generation: full.generation, offset: 0, limit: 2))
      else { throw CancellationError() }
      #expect(
        window.rows.map { $0.containerEstimates?.fullEstimate } == [
          .exact(minutes: 60), .exact(minutes: 120),
        ])
      for source in pair.sources {
        let current = try await metadata(source)
        let original = try #require(originalMetadata[source.id])
        #expect(current.created == original.created && current.updated == original.updated)
        #expect(current.references == original.references)
      }
    }
    guard case .exported(let afterChildReads) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterChildReads == childEditData)
    for pair in pairs {
      let title = try await catalog(pair.kind, .title)
      let updated = try await catalog(pair.kind, .lastUpdated)
      #expect(title.rows == pair.sources.reversed().map(PlannerRowIdentity.source))
      let source = pair.sources[0]
      let rename: PlannerCommand
      switch await writer.read(session: writerSession, request: .source(source)) {
      case .source(.list(let value)):
        rename = .editList(
          sourceId: source.id, changes: .init(name: .set("Aardvark")),
          expectedFieldHashes: value.fieldHashes)
      case .source(.itinerary(let value)):
        rename = .editItinerary(
          sourceId: source.id, changes: .init(title: .set("Aardvark")),
          expectedFieldHashes: value.fieldHashes)
      default: throw CancellationError()
      }
      guard
        case .applied(_, .complete) = await writer.execute(
          .init(operationId: UUID(), session: writerSession, command: rename)
        ).outcome
      else { throw CancellationError() }
      for generation in [title.generation, updated.generation] {
        guard
          case .failed(let failure) = await planner.read(
            session: session, request: .rows(generation: generation, offset: 0, limit: 1))
        else { throw CancellationError() }
        #expect(failure.code == "staleSnapshot")
      }
      let renamedTitle = try await catalog(pair.kind, .title)
      let renamedUpdated = try await catalog(pair.kind, .lastUpdated)
      let created = try await catalog(pair.kind, .created)
      let full = try await catalog(pair.kind, .fullEstimate)
      #expect(renamedTitle.rows == pair.sources.map(PlannerRowIdentity.source))
      #expect(renamedUpdated.rows == pair.sources.reversed().map(PlannerRowIdentity.source))
      #expect(created.rows == pair.sources.map(PlannerRowIdentity.source))
      #expect(full.rows == pair.sources.reversed().map(PlannerRowIdentity.source))
      for source in pair.sources {
        let current = try await metadata(source)
        let original = try #require(originalMetadata[source.id])
        #expect(current.created == original.created && current.references == original.references)
      }
    }
    guard case .exported(let finalData) = await planner.exportData(session: session),
      case .decoded(let finalBackup) = planner.decodeImport(finalData)
    else { throw CancellationError() }
    #expect(finalBackup.backup.memberships == originalBackup.backup.memberships)
    for pair in pairs {
      _ = try await catalog(pair.kind, .fullEstimate)
      _ = try await catalog(pair.kind, .lastUpdated)
    }
    guard case .exported(let afterFinalReads) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterFinalReads == finalData)
  }

  @Test func fullEstimateCatalogsKeepCertaintyGroupsManualBudgetsAndExactIntegerOrder() async throws
  {
    let planner = Planner(configuration: makeConfiguration())
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    let itemInputs: [(String, Int64?)] = [
      ("Museum", 180), ("Short", 120), ("Medium", 240), ("Long", 300),
      ("Missing A", nil), ("Missing B", nil), ("Maximum", Int64.max), ("One", 1),
      ("Huge lower", 9_007_199_254_740_992), ("Huge upper", 9_007_199_254_740_993),
    ]
    var items: [PlannerEntityReference] = []
    for (title, minutes) in itemInputs {
      items.append(
        try #require(
          try await save(
            .createItem(
              content: .init(
                title: title, estimate: minutes.map { .init(minutes: $0, displayUnit: .minute) }))
          )
          .generated.first))
    }
    _ = try await save(.setCompletion(scope: .globalItem(itemId: items[0].id), done: true))
    _ = try await save(.setArchive(source: items[3], archived: true))
    _ = try await save(
      .createSchedule(
        source: items[0],
        form: .timed(
          start: Date(timeIntervalSinceReferenceDate: 813_000_000), end: nil,
          planningTimeZone: "Asia/Tokyo")))
    let plans:
      [(title: String, manualMinutes: Int64?, children: [Int], total: PlannerDurationTotal)] = [
        ("Empty", nil, [], .exact(minutes: 0)),
        ("Museum", nil, [0], .exact(minutes: 180)),
        ("Manual", 240, [4, 1], .exact(minutes: 240)),
        ("Long", nil, [3], .exact(minutes: 300)),
        ("Partial short", nil, [1, 4], .lowerBound(minutes: 120, missingEstimateCount: 1)),
        ("Partial long", nil, [2, 4], .lowerBound(minutes: 240, missingEstimateCount: 1)),
        ("Overflow", nil, [6, 7], .unavailable),
        ("CAFÉ", nil, [2], .exact(minutes: 240)),
        ("cafe", nil, [2], .exact(minutes: 240)),
        ("partial café", nil, [1, 4], .lowerBound(minutes: 120, missingEstimateCount: 1)),
        ("PARTIAL CAFE", nil, [1, 4, 5], .lowerBound(minutes: 120, missingEstimateCount: 2)),
        ("Alpha overflow", nil, [6, 7], .unavailable),
        ("Huge lower", nil, [8], .exact(minutes: 9_007_199_254_740_992)),
        ("Huge upper", nil, [9], .exact(minutes: 9_007_199_254_740_993)),
        ("Manual overflow", 60, [6, 7], .exact(minutes: 60)),
      ]
    var manualList: PlannerEntityReference?
    var overflowList: PlannerEntityReference?
    for kind in [PlannerEntityKind.list, .itinerary] {
      var containers: [PlannerEntityReference] = []
      for (index, plan) in plans.enumerated() {
        let manual = plan.manualMinutes.map { PlannerEstimate(minutes: $0, displayUnit: .minute) }
        let command: PlannerCommand
        if kind == .list {
          command = .createList(content: .init(name: plan.title, manualEstimate: manual))
        } else {
          command = .createItinerary(content: .init(title: plan.title, manualEstimate: manual))
        }
        let source = try #require(try await save(command).generated.first)
        containers.append(source)
        var children = plan.children.map { items[$0] }
        if kind == .itinerary, [7, 8].contains(index) {
          children = [try #require(manualList)]
        }
        if kind == .itinerary, [6, 11].contains(index) {
          children = [try #require(overflowList)]
        }
        for child in children {
          if kind == .list {
            _ = try await save(
              .addMembership(itemId: child.id, listId: source.id, placement: .last))
          } else {
            _ = try await save(
              .addItineraryEntry(itineraryId: source.id, source: child, placement: .last))
          }
        }
        if kind == .list, index == 2 { manualList = source }
        if kind == .list, index == 6 { overflowList = source }
      }
      _ = try await save(.setArchive(source: containers[5], archived: true))
      if kind == .itinerary {
        _ = try await save(
          .createSchedule(
            source: containers[1],
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_000_000), end: nil,
              planningTimeZone: "Asia/Tokyo")))
      }
      guard case .exported(let before) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      let cafeTies = [containers[7], containers[8]].sorted { $0.id.uuidString < $1.id.uuidString }
      let partialTies = [containers[9], containers[10]].sorted {
        $0.id.uuidString < $1.id.uuidString
      }
      let ascending =
        [containers[0], containers[14], containers[1]] + cafeTies
        + [containers[2], containers[3], containers[12], containers[13]] + partialTies
        + [containers[4], containers[5], containers[11], containers[6]]
      let descending =
        [containers[13], containers[12], containers[3]] + cafeTies
        + [containers[2], containers[1], containers[14], containers[0], containers[5]] + partialTies
        + [containers[4], containers[11], containers[6]]
      for (direction, expected) in [
        (PlannerCatalogQuery.Sort.Direction.ascending, ascending), (.descending, descending),
      ] {
        let sort = PlannerCatalogQuery.Sort(mode: .fullEstimate, direction: direction)
        guard
          case .snapshot(let snapshot) = await planner.query(
            .init(
              session: session,
              request: .catalog(.init(sourceKind: kind, archive: .all, sort: sort))))
        else { throw CancellationError() }
        #expect(snapshot.rows == expected.map(PlannerRowIdentity.source))
        #expect(snapshot.matchingCount == 15)
        for offset in Array(stride(from: 0, to: 15, by: 2)) + [0, 15] {
          guard
            case .rows(let window) = await planner.read(
              session: session,
              request: .rows(generation: snapshot.generation, offset: Int64(offset), limit: 2))
          else { throw CancellationError() }
          #expect(
            window.rows.map(\.identity)
              == expected.dropFirst(offset).prefix(2).map(PlannerRowIdentity.source))
          for row in window.rows {
            let index = try #require(containers.firstIndex { row.identity == .source($0) })
            #expect(row.containerEstimates?.fullEstimate == plans[index].total)
          }
        }
        guard
          case .snapshot(let active) = await planner.query(
            .init(session: session, request: .catalog(.init(sourceKind: kind, sort: sort)))),
          case .snapshot(let searched) = await planner.query(
            .init(
              session: session,
              request: .catalog(.init(sourceKind: kind, text: "CA FE", archive: .all, sort: sort))))
        else { throw CancellationError() }
        #expect(
          active.rows == expected.filter { $0 != containers[5] }.map(PlannerRowIdentity.source))
        let matching = expected.filter {
          [containers[7], containers[8], containers[9], containers[10]].contains($0)
        }
        #expect(searched.rows == matching.map(PlannerRowIdentity.source))
      }
      guard case .exported(let after) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      #expect(after == before)
    }
  }

  @Test func chronologicalCatalogsUseSavedDatesWithFixedTitleAndIdentityTies() async throws {
    let planner = Planner(configuration: makeConfiguration())
    var records: [[String: Any]] = []
    var fixtures: [(kind: PlannerEntityKind, sources: [PlannerEntityReference])] = []
    let titles = ["Zulu", "Alpha", "CAFÉ", "cafe", "Beta"]
    let createdOffsets = [10, 30, 20, 20, 20]
    let updatedOffsets = [50, 70, 60, 60, 80]
    for (kindIndex, kind) in [PlannerEntityKind.list, .itinerary].enumerated() {
      var sources: [PlannerEntityReference] = []
      for (index, title) in titles.enumerated() {
        let identifier = try #require(
          UUID(
            uuidString: String(format: "00000000-0000-4000-8000-%012d", kindIndex * 100 + index + 1)
          ))
        let titleField = kind == .list ? "name" : "title"
        var content: [String: Any] = [
          titleField: title, "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
          "manualEstimate": NSNull(),
        ]
        if kind == .itinerary { content["location"] = NSNull() }
        records.append([
          "kind": kind.rawValue, "id": identifier.uuidString, "lifetimeId": UUID().uuidString,
          "createdAt": 813_000_000 + createdOffsets[index],
          "updatedAt": 813_000_000 + updatedOffsets[index],
          "content": content, "globalDone": NSNull(), "archived": index == 4,
          "contentOrigins": [titleField: "independent"],
        ])
        sources.append(.init(kind: kind, id: identifier))
      }
      fixtures.append((kind, sources))
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": records,
      "memberships": [], "itineraryEntries": [], "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(data),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let scenarios:
      [(
        mode: PlannerCatalogQuery.Sort.Mode, direction: PlannerCatalogQuery.Sort.Direction,
        indices: [Int]
      )] = [
        (.created, .ascending, [0, 4, 2, 3, 1]),
        (.created, .descending, [1, 4, 2, 3, 0]),
        (.lastUpdated, .ascending, [0, 2, 3, 1, 4]),
        (.lastUpdated, .descending, [4, 1, 2, 3, 0]),
      ]
    for fixture in fixtures {
      for (index, source) in fixture.sources.enumerated() {
        let dates: (created: Date, updated: Date)
        switch await planner.read(session: session, request: .source(source)) {
        case .source(.list(let value)): dates = (value.createdAt, value.updatedAt)
        case .source(.itinerary(let value)): dates = (value.createdAt, value.updatedAt)
        default: throw CancellationError()
        }
        #expect(
          dates.created
            == Date(timeIntervalSinceReferenceDate: Double(813_000_000 + createdOffsets[index])))
        #expect(
          dates.updated
            == Date(timeIntervalSinceReferenceDate: Double(813_000_000 + updatedOffsets[index])))
      }
      for scenario in scenarios {
        let expected = scenario.indices.map { PlannerRowIdentity.source(fixture.sources[$0]) }
        let sort = PlannerCatalogQuery.Sort(mode: scenario.mode, direction: scenario.direction)
        guard
          case .snapshot(let snapshot) = await planner.query(
            .init(
              session: session,
              request: .catalog(.init(sourceKind: fixture.kind, archive: .all, sort: sort))))
        else { throw CancellationError() }
        #expect(snapshot.rows == expected && snapshot.matchingCount == 5)
        for offset in [0, 2, 4, 0, 5] {
          guard
            case .rows(let window) = await planner.read(
              session: session,
              request: .rows(generation: snapshot.generation, offset: Int64(offset), limit: 2))
          else { throw CancellationError() }
          #expect(window.rows.map(\.identity) == Array(expected.dropFirst(offset).prefix(2)))
        }
        guard
          case .snapshot(let active) = await planner.query(
            .init(
              session: session,
              request: .catalog(.init(sourceKind: fixture.kind, sort: sort)))),
          case .snapshot(let searched) = await planner.query(
            .init(
              session: session,
              request: .catalog(
                .init(sourceKind: fixture.kind, text: "FE ca", archive: .all, sort: sort))))
        else { throw CancellationError() }
        #expect(active.rows == expected.filter { $0 != .source(fixture.sources[4]) })
        #expect(
          searched.rows == [fixture.sources[2], fixture.sources[3]].map(PlannerRowIdentity.source))
      }
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(after == before)
  }

  @Test func nonContainerSortsRejectWithoutInvalidatingCatalogsOrChangingData() async throws {
    let planner = Planner(configuration: makeConfiguration())
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    for kind in [PlannerEntityKind.category, .tag, .schedule] {
      guard
        case .snapshot(let original) = await planner.query(
          .init(session: session, request: .catalog(.init(sourceKind: kind, archive: .all))))
      else { throw CancellationError() }
      #expect(original.rows.isEmpty && original.matchingCount == 0)
      for mode in [PlannerCatalogQuery.Sort.Mode.title, .created, .lastUpdated, .fullEstimate] {
        for direction in [PlannerCatalogQuery.Sort.Direction.ascending, .descending] {
          guard
            case .failed(let failure) = await planner.query(
              .init(
                session: session,
                request: .catalog(
                  .init(
                    sourceKind: kind, archive: .all, sort: .init(mode: mode, direction: direction)))
              ))
          else {
            Issue.record("Only List and Itinerary catalogs accept explicit sorting.")
            continue
          }
          #expect(failure.code == "invalidInput")
          #expect(failure.propertyPath == "/query/sort")
        }
      }
      guard
        case .rows(let retained) = await planner.read(
          session: session, request: .rows(generation: original.generation, offset: 0, limit: 1))
      else { throw CancellationError() }
      #expect(retained.rows.isEmpty && retained.matchingCount == 0)
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(after == before)
  }

  @Test func explicitTitleDirectionsKeepCatalogDefaultsTiesFiltersAndOrderedPages() async throws {
    let planner = Planner(configuration: makeConfiguration())
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let applied, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return applied
    }
    for kind in [PlannerEntityKind.list, .itinerary] {
      var sources: [PlannerEntityReference] = []
      for title in ["Zoo", "CAFÉ", "cafe", "Alpine", "Bee"] {
        let command: PlannerCommand
        if kind == .list {
          command = .createList(content: .init(name: title))
        } else {
          command = .createItinerary(content: .init(title: title))
        }
        sources.append(try #require(try await save(command).generated.first))
      }
      _ = try await save(.setArchive(source: sources[4], archived: true))
      guard case .exported(let before) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      let tied = [sources[1], sources[2]].sorted { $0.id.uuidString < $1.id.uuidString }
      let ascending = [sources[3], sources[4]] + tied + [sources[0]]
      let descending = [sources[0]] + tied + [sources[4], sources[3]]
      let examples: [(PlannerCatalogQuery.Sort?, [PlannerEntityReference])] = [
        (nil, ascending),
        (.init(mode: .title, direction: .ascending), ascending),
        (.init(mode: .title, direction: .descending), descending),
      ]
      var originalSnapshot: PlannerQuerySnapshot?
      for (sort, expected) in examples {
        guard
          case .snapshot(let snapshot) = await planner.query(
            .init(
              session: session,
              request: .catalog(.init(sourceKind: kind, archive: .all, sort: sort))))
        else { throw CancellationError() }
        if case .none = sort { originalSnapshot = snapshot }
        #expect(snapshot.rows == expected.map(PlannerRowIdentity.source))
        #expect(snapshot.matchingCount == 5)
        for offset in [0, 2, 4, 0, 5] {
          guard
            case .rows(let window) = await planner.read(
              session: session,
              request: .rows(generation: snapshot.generation, offset: Int64(offset), limit: 2))
          else { throw CancellationError() }
          #expect(
            window.rows.map(\.identity)
              == expected.dropFirst(offset).prefix(2).map(PlannerRowIdentity.source))
          #expect(window.matchingCount == 5)
        }
      }
      for (archive, text, expected) in [
        (PlannerItemQuery.Archive.active, "", [sources[0]] + tied + [sources[3]]),
        (.archived, "", [sources[4]]),
        (.all, "  FE\nCA  ", tied),
      ] {
        guard
          case .snapshot(let snapshot) = await planner.query(
            .init(
              session: session,
              request: .catalog(
                .init(
                  sourceKind: kind, text: text, archive: archive,
                  sort: .init(mode: .title, direction: .descending)))))
        else { throw CancellationError() }
        #expect(snapshot.rows == expected.map(PlannerRowIdentity.source))
      }
      guard let originalSnapshot,
        case .rows(let originalWindow) = await planner.read(
          session: session,
          request: .rows(generation: originalSnapshot.generation, offset: 0, limit: 2)),
        case .exported(let after) = await planner.exportData(session: session)
      else {
        throw CancellationError()
      }
      #expect(
        originalWindow.rows.map(\.identity) == ascending.prefix(2).map(PlannerRowIdentity.source))
      #expect(after == before)
    }
  }

  /// The runner removes these stores only after cached SwiftData containers exit with the process.
  private func makeConfiguration() -> PlannerStorageConfiguration {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerContainerCatalogSortTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    print("Container catalog sort fixture: \(directory.path)")
    return .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

}
