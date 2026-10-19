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
  let didSave: (PlannerOperationResult) -> Void
  @State private var namespace: String?
  @State private var title: String
  @State private var subtitle: String
  @State private var notes: String
  @State private var estimate: PlannerEstimate?
  @State private var locationDraft: SavedOwnedLocationDraft
  @State private var links: [SavedOwnedLinkDraft]
  @State private var categoryIdentifiers: Set<UUID>
  @State private var tagIdentifiers: Set<UUID>
  @State private var operationIdentifier = UUID()

  init(
    store: SavedPlannerStore, item: PlannerItemSourceRead,
    didSave: @escaping (PlannerOperationResult) -> Void
  ) {
    self.store = store
    self.item = item
    self.didSave = didSave
    _namespace = State(initialValue: store.devicePreferenceNamespace)
    _title = State(initialValue: item.content.title)
    _subtitle = State(initialValue: item.content.subtitle ?? "")
    _notes = State(initialValue: item.content.notes ?? "")
    _estimate = State(initialValue: item.content.estimate)
    _locationDraft = State(initialValue: SavedOwnedLocationDraft(item.content.location))
    _links = State(initialValue: item.content.links.map(SavedOwnedLinkDraft.init))
    _categoryIdentifiers = State(initialValue: item.content.categoryIds)
    _tagIdentifiers = State(initialValue: item.content.tagIds)
  }

  private var hasChanges: Bool {
    title != item.content.title || subtitle != (item.content.subtitle ?? "")
      || notes != (item.content.notes ?? "")
      || estimate != item.content.estimate
      || links.map(\.input) != item.content.links.map(\.editInput)
      || location != item.content.location
      || categoryIdentifiers != item.content.categoryIds || tagIdentifiers != item.content.tagIds
  }

  private var location: PlannerOwnedLocation? { locationDraft.value }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Title", text: $title)
            .accessibilityIdentifier("saved.item.edit.title")
          TextField("Subtitle", text: $subtitle)
            .accessibilityIdentifier("saved.item.edit.subtitle")
          TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(3...8)
            .accessibilityIdentifier("saved.item.edit.notes")
        } footer: {
          Text("Changes appear wherever this Item is used.")
        }
        SavedActivityEstimateEditor(
          estimate: $estimate, accessibilityIdentifierPrefix: "saved.item.edit.estimate")
        Section("Labels") {
          NavigationLink {
            SavedItemLabelPicker(store: store, kind: .category, selection: $categoryIdentifiers)
          } label: {
            LabeledContent("Categories", value: selectionSummary(categoryIdentifiers))
          }
          .accessibilityIdentifier("saved.item.edit.categories")
          NavigationLink {
            SavedItemLabelPicker(store: store, kind: .tag, selection: $tagIdentifiers)
          } label: {
            LabeledContent("Tags", value: selectionSummary(tagIdentifiers))
          }
          .accessibilityIdentifier("saved.item.edit.tags")
        }
        SavedOwnedLocationEditor(
          draft: $locationDraft, title: title,
          accessibilityIdentifierPrefix: "saved.item.edit.location")
        SavedOwnedLinksEditor(
          links: $links, accessibilityIdentifierPrefix: "saved.item.edit.link")
      }
      .disabled(store.isSaving)
      .formStyle(.grouped)
      .accessibilityIdentifier("saved.item.edit.form")
      .navigationTitle("Edit item")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.item.edit.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              [
                title, subtitle, notes, estimate, links, location, categoryIdentifiers,
                tagIdentifiers
              ] in
              guard let namespace, namespace == store.devicePreferenceNamespace else { return }
              let result = await store.editItem(
                item, title: title, subtitle: subtitle, notes: notes, estimate: estimate,
                links: links.map(\.input),
                location: location, categoryIdentifiers: categoryIdentifiers,
                tagIdentifiers: tagIdentifiers,
                operationIdentifier: operationIdentifier)
              guard let result, case .applied = result.outcome,
                namespace == store.devicePreferenceNamespace
              else { return }
              didSave(result)
              dismiss()
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

  private func selectionSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "None" : "\(identifiers.count) selected"
  }
}
