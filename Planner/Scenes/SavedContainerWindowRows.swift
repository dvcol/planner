import PlannerCore
import SwiftUI

struct SavedContainerWindowRows<RowContent: View>: View {
  private struct VisibleReadIdentity: Equatable {
    let window: ObjectIdentifier
    let state: SavedItemWindowState
    let identifiers: Set<UUID>
  }

  let window: SavedItemWindow
  let sourceKind: PlannerEntityKind
  var excludedIdentifiers: Set<UUID> = []
  @ViewBuilder let content: (PlannerRowRead) -> RowContent
  @State private var visibleIdentifiers: Set<UUID> = []
  @State private var hasDisplayedRows = false

  private var sourceRows: [(index: Int, source: PlannerEntityReference)] {
    window.rowIdentities.enumerated().compactMap { index, identity in
      guard case .source(let source) = identity, source.kind == sourceKind,
        !excludedIdentifiers.contains(source.id)
      else { return nil }
      return (index, source)
    }
  }

  var body: some View {
    ForEach(sourceRows, id: \.source.id) { index, source in
      row(at: index, source: source)
        .onScrollVisibilityChange { visible in
          if visible {
            hasDisplayedRows = true
            visibleIdentifiers.insert(source.id)
          } else {
            visibleIdentifiers.remove(source.id)
          }
        }
    }
    .task(
      id: VisibleReadIdentity(
        window: ObjectIdentifier(window), state: window.state, identifiers: visibleIdentifiers)
    ) {
      guard hasDisplayedRows || !visibleIdentifiers.isEmpty else { return }
      let indices = Set(
        sourceRows.filter { visibleIdentifiers.contains($0.source.id) }.map(\.index))
      await window.requestRows(at: indices)
    }
    .onChange(of: ObjectIdentifier(window)) {
      hasDisplayedRows = false
    }
  }

  @ViewBuilder
  private func row(at index: Int, source: PlannerEntityReference) -> some View {
    switch window.presentation(at: index) {
    case .loaded(let presentation) where presentation.row.identity == .source(source):
      content(presentation.row)
    case .loading, .loaded:
      ProgressView(sourceKind == .list ? "Loading List" : "Loading Itinerary")
        .selectionDisabled()
    case .failed(let reason):
      VStack(alignment: .leading) {
        Text(reason).foregroundStyle(.secondary)
        Button("Try Again") { Task { await window.requestRows(at: [index]) } }
      }
      .selectionDisabled()
    }
  }
}
