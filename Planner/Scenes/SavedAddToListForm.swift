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

  private var selectedDestination: SavedPlannerList? {
    store.lists.first { $0.id == selectedListIdentifier }
  }

  var body: some View {
    NavigationStack {
      List(selection: $selectedListIdentifier) {
        Section {
          Text(draft.itemTitle).font(.headline)
        }
        Section {
          ForEach(store.lists) { destination in
            Label(destination.name, systemImage: "list.bullet.rectangle")
              .tag(destination.id)
              .accessibilityIdentifier("saved.membership.destination.\(destination.id.uuidString)")
          }
        } header: {
          Text("Destination List")
        } footer: {
          Text(
            "The Item stays in its other Lists. Existing entries keep their completion and position."
          )
        }
      }
      .overlay {
        if store.lists.isEmpty {
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
            guard let destination = selectedDestination else { return }
            Task {
              if await store.addMembership(
                itemId: draft.itemIdentifier, listId: destination.id,
                operationId: operationIdentifier)
              {
                dismiss()
              }
            }
          }
          .disabled(!store.canCreate || selectedDestination == nil)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.item.list.add")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Adding Item") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
  }
}
