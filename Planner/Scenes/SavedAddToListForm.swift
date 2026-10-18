import PlannerCore
import SwiftUI

struct SavedListAdditionDraft: Identifiable {
  let itemIdentifier: UUID
  let itemTitle: String
  var id: UUID { itemIdentifier }
}

struct SavedAddToListForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let draft: SavedListAdditionDraft
  @State private var selectedListIdentifier: UUID?
  @State private var operationIdentifier = UUID()
  @State private var window: SavedItemWindow?
  @State private var loadedIdentity: SavedItemWindowIdentity?
  @State private var loadingFailure: String?

  private var loadIdentity: SavedItemWindowIdentity? {
    guard let namespace = store.devicePreferenceNamespace else { return nil }
    return .init(namespace: namespace, savedRevision: store.changeRevision)
  }

  private var selectedDestinationIdentifier: UUID? {
    guard loadedIdentity == loadIdentity, loadIdentity != nil, window?.state == .ready,
      let selectedListIdentifier,
      window?.rowIdentities.contains(.source(.init(kind: .list, id: selectedListIdentifier)))
        == true
    else { return nil }
    return selectedListIdentifier
  }

  var body: some View {
    NavigationStack {
      List(selection: $selectedListIdentifier) {
        Section {
          Text(draft.itemTitle).font(.headline)
        }
        Section {
          if let window {
            SavedContainerWindowRows(window: window, sourceKind: .list, selectionTag: { $0.id }) {
              row in
              if case .source(let source) = row.identity {
                Label(row.title, systemImage: "list.bullet.rectangle")
                  .accessibilityIdentifier("saved.membership.destination.\(source.id.uuidString)")
              }
            }
          }
        } header: {
          Text("Destination List")
        } footer: {
          Text(
            "The Item stays in its other Lists. Existing entries keep their completion and position."
          )
        }
      }
      .accessibilityIdentifier("saved.membership.destinations")
      .overlay {
        if let loadingFailure {
          ContentUnavailableView {
            Label("Lists unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(loadingFailure)
          } actions: {
            Button("Try Again") { Task { await loadLists() } }
          }
        } else if case .failed(let reason) = window?.state {
          ContentUnavailableView {
            Label("Lists unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(reason)
          } actions: {
            Button("Try Again") { Task { await loadLists() } }
          }
        } else if window?.state != .ready || loadedIdentity != loadIdentity {
          ProgressView("Loading Lists")
        } else if window?.matchingCount == 0 {
          ContentUnavailableView(
            "No Lists yet", systemImage: "list.bullet.rectangle",
            description: Text("Create a List before adding this Item."))
        }
      }
      .navigationTitle("Add to List")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.item.list.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            guard let destinationIdentifier = selectedDestinationIdentifier,
              let identity = loadedIdentity
            else { return }
            Task {
              guard loadIdentity == identity, selectedDestinationIdentifier == destinationIdentifier
              else { return }
              if await store.addMembership(
                itemId: draft.itemIdentifier, listId: destinationIdentifier,
                operationId: operationIdentifier)
              {
                dismiss()
              }
            }
          }
          .disabled(!store.canCreate || selectedDestinationIdentifier == nil)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.item.list.add")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Adding Item") }
      }
    }
    .task(id: loadIdentity) { await loadLists() }
    .onDisappear { window?.cancel() }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
  }

  private func loadLists() async {
    guard !Task.isCancelled else { return }
    let identity = loadIdentity
    window?.cancel()
    loadedIdentity = nil
    loadingFailure = nil
    guard let identity, let window = store.makeItemWindow() else {
      self.window = nil
      loadingFailure = "Planner is not ready to load its Lists."
      return
    }
    self.window = window
    await window.reload(
      catalogQuery: .init(sourceKind: .list, archive: .active), identity: identity)
    guard !Task.isCancelled, loadIdentity == identity, self.window === window else { return }
    loadedIdentity = identity
  }

}
