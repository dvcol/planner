import PlannerCore
import SwiftUI

struct SavedItemEditDraft: Identifiable {
  let item: PlannerItemSourceRead
  var id: UUID { item.source.id }
}

struct SavedItemLinkDraft: Identifiable {
  let id: UUID
  let savedLinkIdentifier: UUID?
  let originalLabel: String?
  var originalURL: String
  var label: String

  init(link: PlannerOwnedLinkRead) {
    id = link.linkId
    savedLinkIdentifier = link.linkId
    originalLabel = link.label
    originalURL = link.originalUrl
    label = link.label ?? ""
  }

  init() {
    id = UUID()
    savedLinkIdentifier = nil
    originalLabel = nil
    originalURL = ""
    label = ""
  }

  var input: PlannerLinkInput {
    let savedLabel: String?
    if label == (originalLabel ?? "") {
      savedLabel = originalLabel
    } else {
      savedLabel = label.isEmpty ? nil : label
    }
    return PlannerLinkInput(
      linkId: savedLinkIdentifier, originalUrl: originalURL, label: savedLabel)
  }
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
  @State private var links: [SavedItemLinkDraft]
  @FocusState private var focusedLinkIdentifier: UUID?
  @State private var operationIdentifier = UUID()

  init(store: SavedPlannerStore, item: PlannerItemSourceRead) {
    self.store = store
    self.item = item
    _title = State(initialValue: item.content.title)
    _subtitle = State(initialValue: item.content.subtitle ?? "")
    _notes = State(initialValue: item.content.notes ?? "")
    _locationName = State(initialValue: item.content.location?.displayName ?? "")
    _locationAddress = State(initialValue: item.content.location?.formattedAddress ?? "")
    _links = State(initialValue: item.content.links.map(SavedItemLinkDraft.init))
  }

  private var hasChanges: Bool {
    title != item.content.title || subtitle != (item.content.subtitle ?? "")
      || notes != (item.content.notes ?? "")
      || links.map(\.input) != item.content.links.map(\.editInput)
      || location != item.content.location
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
        Section("Links") {
          ForEach($links) { $link in
            VStack(alignment: .leading) {
              HStack {
                TextField("URL", text: $link.originalURL)
                  .autocorrectionDisabled()
                  .focused($focusedLinkIdentifier, equals: link.id)
                  .accessibilityIdentifier("saved.item.edit.link.url.\(link.id.uuidString)")
                  #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                  #endif
                Menu {
                  Button("Move Up", systemImage: "arrow.up") {
                    moveLink(link.id, offset: -1)
                  }
                  .disabled(links.first?.id == link.id)
                  Button("Move Down", systemImage: "arrow.down") {
                    moveLink(link.id, offset: 1)
                  }
                  .disabled(links.last?.id == link.id)
                  Divider()
                  Button("Remove Link", systemImage: "minus.circle", role: .destructive) {
                    if focusedLinkIdentifier == link.id { focusedLinkIdentifier = nil }
                    links.removeAll { $0.id == link.id }
                  }
                } label: {
                  Label("Link actions", systemImage: "ellipsis.circle")
                }
                .labelStyle(.iconOnly)
                .help("Link actions")
                .accessibilityIdentifier("saved.item.edit.link.actions.\(link.id.uuidString)")
              }
              TextField("Label", text: $link.label)
                .accessibilityIdentifier("saved.item.edit.link.label.\(link.id.uuidString)")
            }
          }
          Button("Add Link", systemImage: "plus") {
            let draft = SavedItemLinkDraft()
            links.append(draft)
            focusedLinkIdentifier = draft.id
          }
          .accessibilityIdentifier("saved.item.edit.link.add")
        }
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
            Task { [title, subtitle, notes, links, location] in
              if await store.editItem(
                item, title: title, subtitle: subtitle, notes: notes, links: links.map(\.input),
                location: location,
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

  private func moveLink(_ identifier: UUID, offset: Int) {
    guard let index = links.firstIndex(where: { $0.id == identifier }),
      links.indices.contains(index + offset)
    else { return }
    links.swapAt(index, index + offset)
  }
}
