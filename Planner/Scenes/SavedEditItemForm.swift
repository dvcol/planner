import PlannerCore
import SwiftUI

struct SavedItemEditDraft: Identifiable {
  let item: PlannerItemSourceRead
  var id: UUID { item.source.id }
}

struct SavedEditItemForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let item: PlannerItemSourceRead
  @State private var title: String
  @State private var notes: String
  @State private var operationIdentifier = UUID()

  init(store: SavedPlannerStore, item: PlannerItemSourceRead) {
    self.store = store
    self.item = item
    _title = State(initialValue: item.content.title)
    _notes = State(initialValue: item.content.notes ?? "")
  }

  private var hasChanges: Bool {
    title != item.content.title || notes != (item.content.notes ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Title", text: $title)
            .accessibilityIdentifier("saved.item.edit.title")
          TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(3...8)
            .accessibilityIdentifier("saved.item.edit.notes")
        } footer: {
          Text("Changes appear wherever this Item is used.")
        }
      }
      .disabled(store.isSaving)
      .formStyle(.grouped)
      .navigationTitle("Edit Item")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.item.edit.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { [title, notes] in
              if await store.editItem(
                item, title: title, notes: notes, operationIdentifier: operationIdentifier)
              {
                dismiss()
              }
            }
          }
          .disabled(
            !store.canCreate || !hasChanges
              || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.item.edit.save")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Saving Item") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    .alert(
      "Planner",
      isPresented: Binding(
        get: { store.alertMessage != nil },
        set: { if !$0 { store.alertMessage = nil } })
    ) {
      Button("OK") { store.alertMessage = nil }
    } message: {
      Text(store.alertMessage ?? "")
    }
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
  }
}
