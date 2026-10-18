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
  @State private var items: [SavedPlannerItem]?
  @State private var loadFailure: String?
  @State private var retryIdentifier = UUID()
  @State private var loadedIdentity: LoadIdentity?

  private var loadIdentity: LoadIdentity {
    .init(
      namespace: store.devicePreferenceNamespace, revision: store.changeRevision,
      retryIdentifier: retryIdentifier)
  }

  private var canAddSelection: Bool {
    guard loadedIdentity == loadIdentity, let selectedItemId else { return false }
    return items?.contains { $0.id == selectedItemId } == true
  }

  var body: some View {
    NavigationStack {
      List(selection: $selectedItemId) {
        ForEach(items ?? []) { item in
          Label(item.row.title, systemImage: "square.stack")
            .tag(item.id)
            .accessibilityIdentifier("saved.membership.choice.item.\(item.id.uuidString)")
        }
      }
      .accessibilityIdentifier("saved.membership.choices")
      .overlay {
        if let loadFailure {
          ContentUnavailableView {
            Label("Items unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(loadFailure)
          } actions: {
            Button("Try Again") { retryIdentifier = UUID() }
              .accessibilityIdentifier("saved.membership.retry")
          }
        } else if items == nil {
          ProgressView("Loading Items")
        } else if items?.isEmpty == true {
          ContentUnavailableView(
            "No active Items", systemImage: "square.stack",
            description: Text("Create an Item or unarchive one in Items, then add it to this List.")
          )
        }
      }
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
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
  }

  private func loadItems(identity: LoadIdentity) async {
    items = nil
    loadFailure = nil
    loadedIdentity = nil
    let candidates = await store.readItems(completion: .all, archive: .active)
    guard !Task.isCancelled, loadIdentity == identity else { return }
    guard let candidates else {
      loadFailure = store.alertMessage ?? "Planner could not load its Items."
      store.alertMessage = nil
      return
    }
    items = candidates
    loadedIdentity = identity
    if let selectedItemId, !candidates.contains(where: { $0.id == selectedItemId }) {
      self.selectedItemId = nil
    }
  }
}
