import Foundation
import Observation
import PlannerCore

struct SavedItemWindowIdentity: Equatable {
  let namespace: String
  let savedRevision: UUID
}

enum SavedItemWindowState: Equatable {
  case idle, loading, ready
  case failed(String)
}

struct SavedItemWindowRow {
  let row: PlannerRowRead
  let rowPresentation: PlannerRowPresentationContext?
}

struct SavedItineraryWindowEntry: Identifiable {
  let id: UUID
  let source: PlannerEntityReference
  let rowIdentities: [PlannerRowIdentity]
  let matchingRowIndices: [Int]
  let list: PlannerListSourceRead?
  let listSummary: PlannerItineraryListEntrySummary?
  let matchesHeader: Bool
}

struct SavedItineraryWindowMetadata {
  let itinerary: PlannerItinerarySourceRead
  let entries: [SavedItineraryWindowEntry]

  var visibleEntries: [SavedItineraryWindowEntry] {
    entries.filter { $0.matchesHeader || !$0.matchingRowIndices.isEmpty }
  }
}

enum SavedItemWindowPresentation {
  case loading
  case loaded(SavedItemWindowRow)
  case failed(String)
}

@MainActor @Observable
final class SavedItemWindow {
  private enum RowKey: Hashable {
    case source(UUID)
    case membership(listId: UUID, membershipId: UUID)
    case direct(itineraryId: UUID, entryId: UUID)
    case expanded(itineraryId: UUID, listEntryId: UUID, membershipId: UUID)
  }

  private struct PendingPage {
    let identifier: UUID
    let task: Task<PlannerReadResult, Never>
  }

  private let planner: PlannerCore.Planner
  private let session: PlannerDatasetSession
  private(set) var rowIdentities: [PlannerRowIdentity] = []
  private(set) var listSource: PlannerListSourceRead?
  private(set) var itineraryMetadata: SavedItineraryWindowMetadata?
  private(set) var matchingCount: Int64 = 0
  private(set) var state = SavedItemWindowState.idle
  private var reloadIdentifier = UUID()
  private var visibilityRequestIdentifier = UUID()
  private var query: PlannerQueryRequest?
  private var lifecycleIdentity: SavedItemWindowIdentity?
  private var generation: UUID?
  private var pages: [Int: [SavedItemWindowRow]] = [:]
  private var pageFailures: [Int: String] = [:]
  private var retainedPages: Set<Int> = []
  @ObservationIgnored private var pendingPages: [Int: PendingPage] = [:]
  @ObservationIgnored private var refreshTask: Task<Void, Never>?

  init(planner: PlannerCore.Planner, session: PlannerDatasetSession) {
    self.planner = planner
    self.session = session
  }

  func reload(query: PlannerItemQuery, identity: SavedItemWindowIdentity) async {
    await replaceQuery(.items(query), identity: identity)
  }

  func reload(catalogQuery: PlannerCatalogQuery, identity: SavedItemWindowIdentity) async {
    await replaceQuery(.catalog(catalogQuery), identity: identity)
  }

  private func replaceQuery(_ query: PlannerQueryRequest, identity: SavedItemWindowIdentity) async {
    guard !Task.isCancelled else { return }
    refreshTask?.cancel()
    refreshTask = nil
    visibilityRequestIdentifier = UUID()
    await reload(query: query, identity: identity, requestIdentifier: UUID())
  }

  func cancel() {
    reloadIdentifier = UUID()
    visibilityRequestIdentifier = UUID()
    refreshTask?.cancel()
    refreshTask = nil
    for pending in pendingPages.values { pending.task.cancel() }
    pendingPages = [:]
    generation = nil
    query = nil
    lifecycleIdentity = nil
    pages = [:]
    pageFailures = [:]
    retainedPages = []
    rowIdentities = []
    listSource = nil
    itineraryMetadata = nil
    matchingCount = 0
    state = .idle
  }

  private func reload(
    query: PlannerQueryRequest, identity: SavedItemWindowIdentity, requestIdentifier: UUID
  ) async {
    guard !Task.isCancelled else { return }
    let itemQuery: PlannerItemQuery?
    if case .items(let items) = query {
      itemQuery = items
    } else {
      itemQuery = nil
    }
    let preservesItineraryRows: Bool
    if case .itinerary(let identifier)? = itemQuery?.scope {
      preservesItineraryRows =
        itineraryMetadata?.itinerary.source.id == identifier
        && lifecycleIdentity?.namespace == identity.namespace
    } else {
      preservesItineraryRows = false
    }
    self.query = query
    lifecycleIdentity = identity
    reloadIdentifier = requestIdentifier
    for pending in pendingPages.values { pending.task.cancel() }
    pendingPages = [:]
    generation = nil
    state = .loading
    listSource = nil
    if !preservesItineraryRows {
      rowIdentities = []
      itineraryMetadata = nil
      matchingCount = 0
    }
    pages = [:]
    pageFailures = [:]
    retainedPages = []
    if case .catalog(let catalog) = query,
      catalog.sourceKind != .list && catalog.sourceKind != .itinerary
    {
      state = .failed("Planner can load only List and Itinerary catalogs here.")
      return
    }
    while !Task.isCancelled {
      let result = await planner.query(.init(session: session, request: query))
      guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
      guard case .snapshot(let snapshot) = result else {
        if case .failed(let reason) = result { state = .failed(reason.message) }
        return
      }
      var identifiers: Set<RowKey> = []
      for rowIdentity in snapshot.rows {
        guard let identifier = rowKey(for: rowIdentity, query: query),
          identifiers.insert(identifier).inserted
        else {
          state = .failed("Planner could not resolve its Items.")
          return
        }
      }
      guard Int64(identifiers.count) == snapshot.matchingCount else {
        state = .failed("Planner could not resolve its complete Items.")
        return
      }
      var headerRead: PlannerReadResult?
      if case .list(let identifier)? = itemQuery?.scope {
        headerRead = await planner.read(
          session: session, request: .source(.init(kind: .list, id: identifier)))
        guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
      }
      var metadataResult: Result<SavedItineraryWindowMetadata, MetadataReadError>?
      if let itemQuery, case .itinerary(let identifier) = itemQuery.scope {
        do {
          metadataResult = .success(
            try await readItineraryMetadata(
              identifier: identifier, query: itemQuery, matchingSnapshot: snapshot,
              requestIdentifier: requestIdentifier))
        } catch let reason as MetadataReadError {
          metadataResult = .failure(reason)
        } catch {
          metadataResult = .failure(.unavailable("Planner could not open this Itinerary."))
        }
        guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
      }
      // Validate the matching generation last, including failures from earlier source reads.
      let read = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64))
      guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
      switch read {
      case .rows(let window):
        guard window.generation == snapshot.generation, window.offset == 0,
          window.matchingCount == snapshot.matchingCount,
          window.rows.count == min(64, snapshot.rows.count)
        else {
          state = .failed("Planner could not read its complete Item page.")
          return
        }
        if case .failure(let reason) = metadataResult {
          switch reason {
          case .stale: continue
          case .superseded: return
          case .unavailable(let message):
            state = .failed(message)
            return
          }
        }
        var items: [SavedItemWindowRow] = []
        for (index, row) in window.rows.enumerated() {
          guard row.identity == snapshot.rows[index],
            isValidRow(row, query: query)
          else {
            state = .failed("Planner could not resolve its Item page.")
            return
          }
          items.append(
            .init(row: row, rowPresentation: window.rowPresentation))
        }
        if case .list(let identifier)? = itemQuery?.scope {
          guard case .source(.list(let list)) = headerRead,
            list.source == .init(kind: .list, id: identifier)
          else {
            if case .failed(let reason) = headerRead {
              state = .failed(reason.message)
            } else {
              state = .failed("Planner could not read this List.")
            }
            return
          }
          listSource = list
        }
        if case .success(let metadata) = metadataResult { itineraryMetadata = metadata }
        rowIdentities = snapshot.rows
        matchingCount = snapshot.matchingCount
        generation = snapshot.generation
        pages[0] = items
        state = .ready
        return
      case .failed(let reason):
        if reason.code == "staleSnapshot" { continue }
        state = .failed(reason.message)
        return
      default:
        state = .failed("Planner could not read its Items.")
        return
      }
    }
  }

  private func rowKey(for identity: PlannerRowIdentity, query: PlannerQueryRequest) -> RowKey? {
    switch query {
    case .items(let items): return rowKey(for: identity, scope: items.scope)
    case .catalog(let catalog):
      guard case .source(let source) = identity, source.kind == catalog.sourceKind,
        source.kind == .list || source.kind == .itinerary
      else { return nil }
      return .source(source.id)
    case .calendar: return nil
    }
  }

  private func isValidRow(_ row: PlannerRowRead, query: PlannerQueryRequest) -> Bool {
    guard rowKey(for: row.identity, query: query) != nil else { return false }
    if case .catalog = query {
      return row.containerEstimates != nil && row.archived != nil
    }
    return true
  }

  private func rowKey(for identity: PlannerRowIdentity, scope: PlannerItemQuery.Scope) -> RowKey? {
    switch (scope, identity) {
    case (.global, .source(let source)), (.inbox, .source(let source)):
      guard source.kind == .item else { return nil }
      return .source(source.id)
    case (.list(let owner), .appearance(let source, .listMembership(let list, let membership))):
      guard source.kind == .item, list == owner else { return nil }
      return .membership(listId: list, membershipId: membership)
    case (
      .itinerary(let owner), .appearance(let source, .directItineraryItem(let itinerary, let entry))
    ):
      guard source.kind == .item, itinerary == owner else { return nil }
      return .direct(itineraryId: itinerary, entryId: entry)
    case (
      .itinerary(let owner),
      .appearance(let source, .expandedListItem(let itinerary, let entry, let membership))
    ):
      guard source.kind == .item, itinerary == owner else { return nil }
      return .expanded(itineraryId: itinerary, listEntryId: entry, membershipId: membership)
    default: return nil
    }
  }

  private enum MetadataReadError: Error {
    case stale, superseded
    case unavailable(String)
  }

  private func checkMetadataRequest(_ identifier: UUID) throws {
    guard !Task.isCancelled, reloadIdentifier == identifier else {
      throw MetadataReadError.superseded
    }
  }

  private func metadataReadError(_ result: PlannerReadResult, message: String) -> MetadataReadError
  {
    guard case .failed(let reason) = result else { return .unavailable(message) }
    if reason.code == "staleSnapshot" { return .stale }
    return .unavailable(reason.message)
  }

  private func validateMetadataSnapshot(_ snapshot: PlannerQuerySnapshot, requestIdentifier: UUID)
    async throws
  {
    let result = await planner.read(
      session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    try checkMetadataRequest(requestIdentifier)
    guard case .rows(let page) = result else {
      throw metadataReadError(result, message: "Planner could not verify this Itinerary.")
    }
    guard page.generation == snapshot.generation, page.offset == 0,
      page.matchingCount == snapshot.matchingCount,
      page.rows.count == min(1, snapshot.rows.count),
      page.rows.first?.identity == snapshot.rows.first
    else {
      throw MetadataReadError.unavailable(
        "Planner could not verify its complete Itinerary metadata.")
    }
  }

  private func readItineraryMetadata(
    identifier: UUID, query: PlannerItemQuery, matchingSnapshot: PlannerQuerySnapshot,
    requestIdentifier: UUID
  ) async throws -> SavedItineraryWindowMetadata {
    let fullQuery = await planner.query(
      .init(
        session: session,
        request: .items(
          .init(
            scope: .itinerary(identifier), completion: .all, archive: .all,
            sort: .init(mode: .manual), rowPresentation: matchingSnapshot.rowPresentation))))
    try checkMetadataRequest(requestIdentifier)
    guard case .snapshot(let fullSnapshot) = fullQuery else {
      if case .failed(let reason) = fullQuery {
        throw MetadataReadError.unavailable(reason.message)
      }
      throw MetadataReadError.unavailable("Planner could not read this Itinerary's entries.")
    }
    let itineraryRead = await planner.read(
      session: session, request: .source(.init(kind: .itinerary, id: identifier)))
    try checkMetadataRequest(requestIdentifier)
    guard case .source(.itinerary(let itinerary)) = itineraryRead,
      itinerary.source == .init(kind: .itinerary, id: identifier)
    else {
      throw metadataReadError(itineraryRead, message: "Planner could not read this Itinerary.")
    }
    var lists: [UUID: PlannerListSourceRead] = [:]
    for reference in itinerary.references {
      guard case .itineraryEntry(_, _, let source) = reference, source.kind == .list,
        lists[source.id] == nil
      else { continue }
      let listRead = await planner.read(session: session, request: .source(source))
      try checkMetadataRequest(requestIdentifier)
      guard case .source(.list(let list)) = listRead, list.source == source else {
        throw metadataReadError(listRead, message: "Planner could not read an Itinerary List.")
      }
      lists[source.id] = list
    }
    let hasItemRestrictions =
      query.categories?.ids.isEmpty == false || query.tags?.ids.isEmpty == false
      || query.lists?.ids.isEmpty == false || query.duration != nil
      || query.hasAddress || query.hasLinks || query.scheduled != .all
    var matchingLists: Set<UUID> = []
    var listSnapshot: PlannerQuerySnapshot?
    if !lists.isEmpty && !hasItemRestrictions {
      let result = await planner.query(
        .init(
          session: session,
          request: .catalog(.init(sourceKind: .list, text: query.text, archive: query.archive))))
      try checkMetadataRequest(requestIdentifier)
      guard case .snapshot(let snapshot) = result else {
        if case .failed(let reason) = result { throw MetadataReadError.unavailable(reason.message) }
        throw MetadataReadError.unavailable("Planner could not filter its Itinerary Lists.")
      }
      for identity in snapshot.rows {
        guard case .source(let source) = identity, source.kind == .list,
          matchingLists.insert(source.id).inserted
        else { throw MetadataReadError.unavailable("Planner could not resolve its List headers.") }
      }
      guard Int64(matchingLists.count) == snapshot.matchingCount else {
        throw MetadataReadError.unavailable("Planner could not resolve its complete List headers.")
      }
      listSnapshot = snapshot
    }
    try await validateMetadataSnapshot(fullSnapshot, requestIdentifier: requestIdentifier)
    if let listSnapshot {
      try await validateMetadataSnapshot(listSnapshot, requestIdentifier: requestIdentifier)
    }
    return try assembleItineraryMetadata(
      itinerary: itinerary, lists: lists, fullSnapshot: fullSnapshot,
      matchingSnapshot: matchingSnapshot, matchingLists: matchingLists, query: query)
  }

  private func assembleItineraryMetadata(
    itinerary: PlannerItinerarySourceRead, lists: [UUID: PlannerListSourceRead],
    fullSnapshot: PlannerQuerySnapshot, matchingSnapshot: PlannerQuerySnapshot,
    matchingLists: Set<UUID>, query: PlannerItemQuery
  ) throws -> SavedItineraryWindowMetadata {
    let invalidMetadata = MetadataReadError.unavailable(
      "Planner could not resolve this Itinerary's complete entries.")
    var matchingPositions: [RowKey: Int] = [:]
    for (index, identity) in matchingSnapshot.rows.enumerated() {
      guard let key = rowKey(for: identity, scope: query.scope), matchingPositions[key] == nil
      else { throw invalidMetadata }
      matchingPositions[key] = index
    }
    var summaries: [UUID: PlannerItineraryListEntrySummary] = [:]
    for summary in itinerary.listEntrySummaries {
      guard summaries[summary.entryId] == nil else { throw invalidMetadata }
      summaries[summary.entryId] = summary
    }
    var entries: [SavedItineraryWindowEntry] = []
    var entryIdentifiers: Set<UUID> = []
    var listEntryIdentifiers: Set<UUID> = []
    var completeIdentities: [PlannerRowIdentity] = []
    var consumedMatches: Set<RowKey> = []
    for reference in itinerary.references {
      guard case .itineraryEntry(let entryIdentifier, let owner, let source) = reference else {
        continue
      }
      guard owner == itinerary.source, entryIdentifiers.insert(entryIdentifier).inserted else {
        throw invalidMetadata
      }
      let identities: [PlannerRowIdentity]
      let list: PlannerListSourceRead?
      let summary: PlannerItineraryListEntrySummary?
      let matchesHeader: Bool
      switch source.kind {
      case .item:
        list = nil
        summary = nil
        matchesHeader = false
        identities = [
          .appearance(
            source: source,
            appearance: .directItineraryItem(
              itineraryId: itinerary.source.id, entryId: entryIdentifier))
        ]
      case .list:
        guard let savedList = lists[source.id], let savedSummary = summaries[entryIdentifier],
          savedSummary.source == source
        else { throw invalidMetadata }
        list = savedList
        summary = savedSummary
        listEntryIdentifiers.insert(entryIdentifier)
        var membershipIdentities: [PlannerRowIdentity] = []
        var membershipIdentifiers: Set<UUID> = []
        for reference in savedList.references {
          guard case .membership(let membership, let listOwner, let item) = reference else {
            continue
          }
          guard listOwner == source, item.kind == .item,
            membershipIdentifiers.insert(membership).inserted
          else { throw invalidMetadata }
          membershipIdentities.append(
            .appearance(
              source: item,
              appearance: .expandedListItem(
                itineraryId: itinerary.source.id, listEntryId: entryIdentifier,
                membershipId: membership)))
        }
        identities = membershipIdentities
        guard savedSummary.progress.totalCount == Int64(identities.count) else {
          throw invalidMetadata
        }
        let matchesCompletion =
          switch query.completion {
          case .all: true
          case .todo: savedSummary.progress.state != .complete
          case .done: savedSummary.progress.state == .complete
          }
        matchesHeader = matchingLists.contains(source.id) && matchesCompletion
      default: throw invalidMetadata
      }
      var indices: [Int] = []
      for identity in identities {
        guard let key = rowKey(for: identity, scope: query.scope) else { throw invalidMetadata }
        if let index = matchingPositions[key] {
          guard matchingSnapshot.rows[index] == identity, consumedMatches.insert(key).inserted
          else {
            throw invalidMetadata
          }
          indices.append(index)
        }
      }
      completeIdentities.append(contentsOf: identities)
      entries.append(
        .init(
          id: entryIdentifier, source: source, rowIdentities: identities,
          matchingRowIndices: indices, list: list, listSummary: summary,
          matchesHeader: matchesHeader))
    }
    guard completeIdentities == fullSnapshot.rows,
      Int64(completeIdentities.count) == fullSnapshot.matchingCount,
      itinerary.progress.totalCount == Int64(completeIdentities.count),
      consumedMatches.count == matchingSnapshot.rows.count,
      Set(summaries.keys) == listEntryIdentifiers
    else { throw invalidMetadata }
    return .init(itinerary: itinerary, entries: entries)
  }

  func presentation(at index: Int) -> SavedItemWindowPresentation {
    if let failure = pageFailures[index / 64] { return .failed(failure) }
    guard rowIdentities.indices.contains(index), let page = pages[index / 64],
      page.indices.contains(index % 64)
    else { return .loading }
    return .loaded(page[index % 64])
  }

  func requestRows(at visibleIndices: Set<Int>) async {
    guard !Task.isCancelled, state == .ready, let generation, let query else { return }
    let visibilityIdentifier = UUID()
    visibilityRequestIdentifier = visibilityIdentifier
    let visibleRowIdentities = visibleIndices.filter { rowIdentities.indices.contains($0) }
      .map { rowIdentities[$0] }
    let visiblePages = Set(
      visibleIndices.filter { rowIdentities.indices.contains($0) }.map { $0 / 64 })
    retainedPages = visiblePages
    if let first = visiblePages.min(), first > 0 { retainedPages.insert(first - 1) }
    if let last = visiblePages.max(), (last + 1) * 64 < rowIdentities.count {
      retainedPages.insert(last + 1)
    }
    pages = pages.filter { retainedPages.contains($0.key) }
    pageFailures = pageFailures.filter { retainedPages.contains($0.key) }
    for (page, pending) in pendingPages where !retainedPages.contains(page) {
      pending.task.cancel()
      pendingPages[page] = nil
    }
    let requestIdentifier = reloadIdentifier
    let requestedPages =
      visiblePages.sorted() + retainedPages.subtracting(visiblePages).sorted()
    for page in requestedPages where pages[page] == nil {
      guard !Task.isCancelled, reloadIdentifier == requestIdentifier,
        visibilityRequestIdentifier == visibilityIdentifier
      else { return }
      guard retainedPages.contains(page) else { continue }
      if pendingPages[page] == nil {
        let task = Task {
          await planner.read(
            session: session,
            request: .rows(generation: generation, offset: Int64(page * 64), limit: 64))
        }
        pendingPages[page] = PendingPage(identifier: UUID(), task: task)
      }
      guard let pending = pendingPages[page] else { return }
      let read = await pending.task.value
      guard !Task.isCancelled, reloadIdentifier == requestIdentifier,
        visibilityRequestIdentifier == visibilityIdentifier,
        pendingPages[page]?.identifier == pending.identifier, retainedPages.contains(page)
      else { return }
      pendingPages[page] = nil
      switch read {
      case .rows(let window):
        let offset = page * 64
        guard window.generation == generation, window.offset == Int64(offset),
          window.matchingCount == matchingCount,
          window.rows.count == min(64, rowIdentities.count - offset)
        else {
          pageFailures[page] = "Planner could not read its complete Item page."
          continue
        }
        var items: [SavedItemWindowRow] = []
        for (rowIndex, row) in window.rows.enumerated() {
          guard row.identity == rowIdentities[offset + rowIndex],
            isValidRow(row, query: query)
          else { break }
          items.append(.init(row: row, rowPresentation: window.rowPresentation))
        }
        guard items.count == window.rows.count else {
          pageFailures[page] = "Planner could not resolve its Item page."
          continue
        }
        pageFailures[page] = nil
        pages[page] = items
      case .failed(let reason):
        guard reason.code == "staleSnapshot", let lifecycleIdentity else {
          pageFailures[page] = reason.message
          continue
        }
        // Visibility changes during refresh must not cancel the replacement query.
        let refresh = Task {
          guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
          let refreshedRequestIdentifier = UUID()
          await reload(
            query: query, identity: lifecycleIdentity, requestIdentifier: refreshedRequestIdentifier
          )
          guard !Task.isCancelled, reloadIdentifier == refreshedRequestIdentifier,
            visibilityRequestIdentifier == visibilityIdentifier
          else { return }
          let refreshedIndices = Set(
            rowIdentities.indices.filter {
              visibleRowIdentities.contains(rowIdentities[$0])
            }
          )
          await requestRows(at: refreshedIndices)
        }
        refreshTask = refresh
        await refresh.value
        return
      default: pageFailures[page] = "Planner could not read its Item page."
      }
    }
  }
}
