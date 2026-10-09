import PlannerCore
import SwiftUI

struct SavedAddItemForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let list: PlannerListSourceRead
  let didAdd: () -> Void
  @State private var selectedItemId: UUID?
  @State private var operationId = UUID()

  var body: some View {
    NavigationStack {
      List(selection: $selectedItemId) {
        ForEach(store.items) { item in
          Label(item.row.title, systemImage: "square.stack")
            .tag(item.id)
        }
      }
      .overlay {
        if store.items.isEmpty {
          ContentUnavailableView(
            "No Items yet", systemImage: "square.stack",
            description: Text("Create an Item in Items, then add it to this List."))
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
            guard let selectedItemId else { return }
            Task {
              if await store.addMembership(
                itemId: selectedItemId, listId: list.source.id, operationId: operationId)
              {
                didAdd()
                dismiss()
              }
            }
          }
          .disabled(!store.canCreate || selectedItemId == nil)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.membership.add")
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
