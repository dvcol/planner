import PlannerCore
import SwiftUI

struct SavedItemCatalog: View {
  let items: [SavedPlannerItem]
  @Binding var selection: UUID?
  let canCreate: Bool
  let create: () -> Void

  var body: some View {
    List(selection: $selection) {
      ForEach(items) { item in
        NavigationLink(value: item.id) {
          HStack(alignment: .top) {
            Image(systemName: item.row.globalDone == true ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
              Text(item.row.title)
              if let subtitle = item.row.subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
              }
            }
          }
        }
        .accessibilityIdentifier("saved.item.\(item.id.uuidString)")
      }
    }
    .overlay {
      if items.isEmpty {
        ContentUnavailableView(
          "No Items yet", systemImage: "square.stack",
          description: Text("Create an Item to start planning."))
      }
    }
    .navigationTitle("Items")
    .toolbar {
      ToolbarItem {
        Button("New Item", systemImage: "plus", action: create)
          .disabled(!canCreate)
          .accessibilityIdentifier("saved.item.new")
      }
    }
  }
}

struct SavedItemDetail: View {
  let item: PlannerItemSourceRead
  let canChange: Bool
  let isSaving: Bool
  let setCompletion: @MainActor @Sendable (Bool) -> Void

  var body: some View {
    Form {
      Section {
        Text(item.content.title).font(.title2).fontWeight(.semibold)
        if let subtitle = item.content.subtitle, !subtitle.isEmpty {
          Text(subtitle).foregroundStyle(.secondary)
        }
        Toggle(
          "Completed",
          isOn: Binding(get: { item.state.globalDone == true }, set: setCompletion)
        )
        .disabled(!canChange)
        .accessibilityIdentifier("saved.item.completion")
      } footer: {
        Text("Completing this Item shows it as done in every List and Itinerary.")
      }
      if let notes = item.content.notes, !notes.isEmpty {
        Section("Notes") { Text(notes).textSelection(.enabled) }
      }
    }
    .formStyle(.grouped)
    .navigationTitle(item.content.title)
    .overlay {
      if isSaving { ProgressView("Saving change") }
    }
  }
}

struct SavedNewItemForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let didCreate: (PlannerEntityReference) -> Void
  @State private var title = ""
  @State private var notes = ""
  @State private var operationId = UUID()

  var body: some View {
    NavigationStack {
      Form {
        TextField("Title", text: $title)
          .accessibilityIdentifier("saved.item.title")
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.item.notes")
      }
      .formStyle(.grouped)
      .navigationTitle("New Item")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.item.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              if let source = await store.createItem(
                title: title, notes: notes, operationId: operationId)
              {
                didCreate(source)
                dismiss()
              }
            }
          }
          .disabled(
            !store.canCreate || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.item.save")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Saving Item") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 280)
    #endif
  }
}
