import MapKit
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
  @State private var estimate: PlannerEstimate?
  @State private var locationName: String
  @State private var locationAddress: String
  @State private var keepsSavedPin: Bool
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
    _estimate = State(initialValue: item.content.estimate)
    _locationName = State(initialValue: item.content.location?.displayName ?? "")
    _locationAddress = State(initialValue: item.content.location?.formattedAddress ?? "")
    _keepsSavedPin = State(initialValue: item.content.location?.coordinate != nil)
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

  private var location: PlannerOwnedLocation? {
    let coordinate = keepsSavedPin ? item.content.location?.coordinate : nil
    let name = locationText(locationName, original: item.content.location?.displayName)
    let address = locationText(locationAddress, original: item.content.location?.formattedAddress)
    if coordinate == nil && name == nil && address == nil { return nil }
    return PlannerOwnedLocation(
      displayName: name, formattedAddress: address, coordinate: coordinate)
  }

  private func locationText(_ text: String, original: String?) -> String? {
    if text == (original ?? "") { return original }
    return text.isEmpty ? nil : text
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
        Section {
          TextField("Place name", text: $locationName)
            .accessibilityIdentifier("saved.item.edit.location.name")
          TextField("Address", text: $locationAddress)
            .accessibilityIdentifier("saved.item.edit.location.address")
          if item.content.location?.coordinate != nil {
            Picker("Saved pin", selection: $keepsSavedPin) {
              Text("Keep saved pin").tag(true)
              Text("Remove saved pin").tag(false)
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("saved.item.edit.location.pin")
          }
          if let coordinate = location?.coordinate {
            ItemLocationMap(
              title: title,
              coordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
              accessibilityIdentifier: "saved.item.edit.location.map")
          }
        } header: {
          Text("Location")
        } footer: {
          if item.content.location?.coordinate != nil {
            if keepsSavedPin {
              Text(
                "Place name and address changes keep this pin until you choose Remove saved pin.")
            } else {
              Text("Removing the pin keeps the place name and address. Save applies the change.")
            }
          }
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
            Task {
              [
                title, subtitle, notes, estimate, links, location, categoryIdentifiers,
                tagIdentifiers
              ] in
              if await store.editItem(
                item, title: title, subtitle: subtitle, notes: notes, estimate: estimate,
                links: links.map(\.input),
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
