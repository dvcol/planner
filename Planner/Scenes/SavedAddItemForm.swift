import PlannerCore
import SwiftUI

struct SavedAddItemForm: View {
  private struct LoadIdentity: Equatable {
    let namespace: String?
    let revision: UUID
    let retryIdentifier: UUID
  }

  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let list: PlannerListSourceRead
  let didAdd: () -> Void
  @State private var selectedItemId: UUID?
  @State private var operationId = UUID()
  @State private var window: SavedItemWindow?
  @State private var visibleIdentifiers: Set<UUID> = []
  @State private var loadFailure: String?
  @State private var retryIdentifier = UUID()
  @State private var loadedIdentity: LoadIdentity?

  private var loadIdentity: LoadIdentity {
    .init(
      namespace: store.devicePreferenceNamespace, revision: store.changeRevision,
      retryIdentifier: retryIdentifier)
  }

  private var canAddSelection: Bool {
    guard loadedIdentity == loadIdentity, window?.state == .ready, let selectedItemId else {
      return false
    }
    return sourceRows.contains { $0.identifier == selectedItemId }
  }

  private var sourceRows: [(index: Int, identifier: UUID)] {
    guard let window else { return [] }
    return window.rowIdentities.enumerated().compactMap { index, identity in
      guard case .source(let source) = identity, source.kind == .item else { return nil }
      return (index, source.id)
    }
  }

  var body: some View {
    NavigationStack {
      List(selection: $selectedItemId) {
        if let window {
          ForEach(sourceRows, id: \.identifier) { index, identifier in
            choice(window.presentation(at: index), index: index, identifier: identifier)
              .onScrollVisibilityChange { visible in
                if visible {
                  visibleIdentifiers.insert(identifier)
                } else {
                  visibleIdentifiers.remove(identifier)
                }
              }
          }
        }
      }
      .accessibilityIdentifier("saved.membership.choices")
      .disabled(store.isSaving)
      .overlay { pickerStatus }
      .navigationTitle("Add to \(list.content.name)")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.membership.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            guard canAddSelection, let selectedItemId else { return }
            Task {
              if await store.addMembership(
                itemId: selectedItemId, listId: list.source.id, operationId: operationId)
              {
                didAdd()
                dismiss()
              }
            }
          }
          .disabled(!store.canCreate || !canAddSelection)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.membership.add")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Adding Item") }
      }
    }
    .task(id: loadIdentity) { await loadItems(identity: loadIdentity) }
    .task(id: visibleIdentifiers) {
      guard let window, !visibleIdentifiers.isEmpty else { return }
      let indices = Set(
        sourceRows.filter { visibleIdentifiers.contains($0.identifier) }.map(\.index))
      await window.requestRows(at: indices)
    }
    .onDisappear {
      window?.cancel()
      visibleIdentifiers = []
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
  }

  @ViewBuilder
  private func choice(_ presentation: SavedItemWindowPresentation, index: Int, identifier: UUID)
    -> some View
  {
    switch presentation {
    case .loaded(let presentation)
    where presentation.row.identity == .source(.init(kind: .item, id: identifier)):
      let item = SavedPlannerItem(
        id: identifier, row: presentation.row, rowPresentation: presentation.rowPresentation)
      Label(item.row.title, systemImage: "square.stack")
        .tag(item.id)
        .accessibilityIdentifier("saved.membership.choice.item.\(item.id.uuidString)")
    case .loading, .loaded:
      ProgressView("Loading Item").selectionDisabled()
    case .failed(let reason):
      VStack(alignment: .leading) {
        Text(reason).foregroundStyle(.secondary)
        Button("Try Again") { Task { await window?.requestRows(at: [index]) } }
      }
      .selectionDisabled()
    }
  }

  @ViewBuilder
  private var pickerStatus: some View {
    if let loadFailure {
      failureContent(loadFailure)
    } else {
      switch window?.state ?? .idle {
      case .idle, .loading: ProgressView("Loading Items")
      case .failed(let reason): failureContent(reason)
      case .ready:
        if window?.matchingCount == 0 {
          ContentUnavailableView(
            "No active Items", systemImage: "square.stack",
            description: Text("Create an Item or unarchive one in Items, then add it to this List.")
          )
        }
      }
    }
  }

  private func failureContent(_ reason: String) -> some View {
    ContentUnavailableView {
      Label("Items unavailable", systemImage: "exclamationmark.triangle")
    } description: {
      Text(reason)
    } actions: {
      Button("Try Again") { retryIdentifier = UUID() }
        .accessibilityIdentifier("saved.membership.retry")
    }
  }

  private func loadItems(identity: LoadIdentity) async {
    guard !Task.isCancelled else { return }
    window?.cancel()
    visibleIdentifiers = []
    loadFailure = nil
    loadedIdentity = nil
    guard let namespace = identity.namespace, let window = store.makeItemWindow() else {
      self.window = nil
      loadFailure = "Planner is not ready to load its Items."
      return
    }
    self.window = window
    await window.reload(
      query: .init(completion: .all, archive: .active),
      identity: .init(namespace: namespace, savedRevision: identity.revision))
    guard !Task.isCancelled, loadIdentity == identity, window.state == .ready else { return }
    loadedIdentity = identity
    if let selectedItemId, !sourceRows.contains(where: { $0.identifier == selectedItemId }) {
      self.selectedItemId = nil
    }
  }
}
