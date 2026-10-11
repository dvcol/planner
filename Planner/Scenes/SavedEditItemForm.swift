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
  @State private var subtitle: String
  @State private var notes: String
  @State private var locationName: String
  @State private var locationAddress: String
  @State private var links: [SavedOwnedLinkDraft]
  @State private var categoryIdentifiers: Set<UUID>
  @State private var tagIdentifiers: Set<UUID>
  @State private var operationIdentifier = UUID()

  init(store: SavedPlannerStore, item: PlannerItemSourceRead) {
    self.store = store
    self.item = item
    _title = State(initialValue: item.content.title)
    _subtitle = State(initialValue: item.content.subtitle ?? "")
    _notes = State(initialValue: item.content.notes ?? "")
    _locationName = State(initialValue: item.content.location?.displayName ?? "")
    _locationAddress = State(initialValue: item.content.location?.formattedAddress ?? "")
    _links = State(initialValue: item.content.links.map(SavedOwnedLinkDraft.init))
    _categoryIdentifiers = State(initialValue: item.content.categoryIds)
    _tagIdentifiers = State(initialValue: item.content.tagIds)
  }

  private var hasChanges: Bool {
    title != item.content.title || subtitle != (item.content.subtitle ?? "")
      || notes != (item.content.notes ?? "")
      || links.map(\.input) != item.content.links.map(\.editInput)
      || location != item.content.location
      || categoryIdentifiers != item.content.categoryIds || tagIdentifiers != item.content.tagIds
  }

  private var location: PlannerOwnedLocation? {
    if item.content.location?.coordinate != nil { return item.content.location }
    if locationName.isEmpty && locationAddress.isEmpty { return nil }
    return PlannerOwnedLocation(
      displayName: locationName.isEmpty ? nil : locationName,
      formattedAddress: locationAddress.isEmpty ? nil : locationAddress, coordinate: nil)
  }

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
        if item.content.location?.coordinate == nil {
          Section("Location") {
            TextField("Place name", text: $locationName)
              .accessibilityIdentifier("saved.item.edit.location.name")
            TextField("Address", text: $locationAddress)
              .accessibilityIdentifier("saved.item.edit.location.address")
          }
        } else {
          ItemLocationSection(title: title, location: item.content.location)
        }
        SavedOwnedLinksEditor(
          links: $links, accessibilityIdentifierPrefix: "saved.item.edit.link")
      }
      .disabled(store.isSaving)
      .formStyle(.grouped)
      .navigationTitle("Edit Item")
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
            Task { [title, subtitle, notes, links, location, categoryIdentifiers, tagIdentifiers] in
              if await store.editItem(
                item, title: title, subtitle: subtitle, notes: notes, links: links.map(\.input),
                location: location, categoryIdentifiers: categoryIdentifiers,
                tagIdentifiers: tagIdentifiers,
                operationIdentifier: operationIdentifier)
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

  private func selectionSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "None" : "\(identifiers.count) selected"
  }
}
