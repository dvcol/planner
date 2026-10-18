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

enum SavedItemWindowPresentation {
  case loading
  case loaded(SavedPlannerItem)
  case failed(String)
}

@MainActor @Observable
final class SavedItemWindow {
  private struct PendingPage {
    let identifier: UUID
    let task: Task<PlannerReadResult, Never>
  }

  private let planner: PlannerCore.Planner
  private let session: PlannerDatasetSession
  private(set) var rowIdentities: [PlannerRowIdentity] = []
  private(set) var listSource: PlannerListSourceRead?
  private(set) var matchingCount: Int64 = 0
  private(set) var state = SavedItemWindowState.idle
  private var reloadIdentifier = UUID()
  private var visibilityRequestIdentifier = UUID()
  private var query: PlannerItemQuery?
  private var lifecycleIdentity: SavedItemWindowIdentity?
  private var generation: UUID?
  private var pages: [Int: [SavedPlannerItem]] = [:]
  private var pageFailures: [Int: String] = [:]
  private var retainedPages: Set<Int> = []
  @ObservationIgnored private var pendingPages: [Int: PendingPage] = [:]
  @ObservationIgnored private var refreshTask: Task<Void, Never>?

  init(planner: PlannerCore.Planner, session: PlannerDatasetSession) {
    self.planner = planner
    self.session = session
  }

  func reload(query: PlannerItemQuery, identity: SavedItemWindowIdentity) async {
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
    matchingCount = 0
    state = .idle
  }

  private func reload(
    query: PlannerItemQuery, identity: SavedItemWindowIdentity, requestIdentifier: UUID
  ) async {
    guard !Task.isCancelled else { return }
    self.query = query
    lifecycleIdentity = identity
    reloadIdentifier = requestIdentifier
    for pending in pendingPages.values { pending.task.cancel() }
    pendingPages = [:]
    generation = nil
    state = .loading
    rowIdentities = []
    listSource = nil
    matchingCount = 0
    pages = [:]
    pageFailures = [:]
    retainedPages = []
    while !Task.isCancelled {
      let result = await planner.query(.init(session: session, request: .items(query)))
      guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
      guard case .snapshot(let snapshot) = result else {
        if case .failed(let reason) = result { state = .failed(reason.message) }
        return
      }
      var identifiers: Set<UUID> = []
      for rowIdentity in snapshot.rows {
        guard let identifier = nativeIdentifier(for: rowIdentity, scope: query.scope),
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
      if case .list(let identifier) = query.scope {
        headerRead = await planner.read(
          session: session, request: .source(.init(kind: .list, id: identifier)))
        guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
      }
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
        var items: [SavedPlannerItem] = []
        for (index, row) in window.rows.enumerated() {
          guard row.identity == snapshot.rows[index],
            let identifier = nativeIdentifier(for: row.identity, scope: query.scope)
          else {
            state = .failed("Planner could not resolve its Item page.")
            return
          }
          items.append(
            .init(id: identifier, row: row, rowPresentation: window.rowPresentation))
        }
        if case .list(let identifier) = query.scope {
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

  private func nativeIdentifier(for identity: PlannerRowIdentity, scope: PlannerItemQuery.Scope)
    -> UUID?
  {
    switch (scope, identity) {
    case (.global, .source(let source)), (.inbox, .source(let source)):
      return source.kind == .item ? source.id : nil
    case (
      .list(let expectedList), .appearance(let source, .listMembership(let list, let membership))
    ):
      guard source.kind == .item, list == expectedList else { return nil }
      return membership
    default: return nil
    }
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
        var items: [SavedPlannerItem] = []
        for (rowIndex, row) in window.rows.enumerated() {
          guard row.identity == rowIdentities[offset + rowIndex],
            let identifier = nativeIdentifier(for: row.identity, scope: query.scope)
          else { break }
          items.append(.init(id: identifier, row: row, rowPresentation: window.rowPresentation))
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
