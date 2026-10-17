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
  private(set) var sourceIdentifiers: [UUID] = []
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
    sourceIdentifiers = []
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
    sourceIdentifiers = []
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
      var identifiers: [UUID] = []
      for identity in snapshot.rows {
        guard case .source(let source) = identity, source.kind == .item else {
          state = .failed("Planner could not resolve its Items.")
          return
        }
        identifiers.append(source.id)
      }
      guard Int64(identifiers.count) == snapshot.matchingCount,
        Set(identifiers).count == identifiers.count
      else {
        state = .failed("Planner could not resolve its complete Items.")
        return
      }
      if identifiers.isEmpty {
        generation = snapshot.generation
        state = .ready
        return
      }
      let read = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64))
      guard !Task.isCancelled, reloadIdentifier == requestIdentifier else { return }
      switch read {
      case .rows(let window):
        guard window.generation == snapshot.generation, window.offset == 0,
          window.matchingCount == snapshot.matchingCount,
          window.rows.count == min(64, identifiers.count)
        else {
          state = .failed("Planner could not read its complete Item page.")
          return
        }
        var items: [SavedPlannerItem] = []
        for (index, row) in window.rows.enumerated() {
          guard row.identity == .source(.init(kind: .item, id: identifiers[index])) else {
            state = .failed("Planner could not resolve its Item page.")
            return
          }
          items.append(
            .init(id: identifiers[index], row: row, rowPresentation: window.rowPresentation))
        }
        sourceIdentifiers = identifiers
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

  func presentation(at index: Int) -> SavedItemWindowPresentation {
    if let failure = pageFailures[index / 64] { return .failed(failure) }
    guard sourceIdentifiers.indices.contains(index), let page = pages[index / 64],
      page.indices.contains(index % 64)
    else { return .loading }
    return .loaded(page[index % 64])
  }

  func requestRows(at visibleIndices: Set<Int>) async {
    guard !Task.isCancelled, state == .ready, let generation else { return }
    let visibilityIdentifier = UUID()
    visibilityRequestIdentifier = visibilityIdentifier
    let visibleSourceIdentifiers = Set(
      visibleIndices.filter { sourceIdentifiers.indices.contains($0) }.map { sourceIdentifiers[$0] }
    )
    let visiblePages = Set(
      visibleIndices.filter { sourceIdentifiers.indices.contains($0) }.map { $0 / 64 })
    retainedPages = visiblePages
    if let first = visiblePages.min(), first > 0 { retainedPages.insert(first - 1) }
    if let last = visiblePages.max(), (last + 1) * 64 < sourceIdentifiers.count {
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
          window.rows.count == min(64, sourceIdentifiers.count - offset)
        else {
          pageFailures[page] = "Planner could not read its complete Item page."
          continue
        }
        var items: [SavedPlannerItem] = []
        for (rowIndex, row) in window.rows.enumerated() {
          let identifier = sourceIdentifiers[offset + rowIndex]
          guard row.identity == .source(.init(kind: .item, id: identifier)) else { break }
          items.append(.init(id: identifier, row: row, rowPresentation: window.rowPresentation))
        }
        guard items.count == window.rows.count else {
          pageFailures[page] = "Planner could not resolve its Item page."
          continue
        }
        pageFailures[page] = nil
        pages[page] = items
      case .failed(let reason):
        guard reason.code == "staleSnapshot", let query, let lifecycleIdentity else {
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
            sourceIdentifiers.indices.filter {
              visibleSourceIdentifiers.contains(sourceIdentifiers[$0])
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
