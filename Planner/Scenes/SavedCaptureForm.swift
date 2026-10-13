import PlannerCore
import SwiftUI

struct SavedCaptureForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let didSave: (PlannerEntityReference) -> Void
  @State private var input = ""
  @State private var draft: PlannerCaptureDraftRead?
  @State private var title = ""
  @State private var subtitle = ""
  @State private var notes = ""
  @State private var estimate: PlannerEstimate?
  @State private var categoryIdentifiers: Set<UUID> = []
  @State private var tagIdentifiers: Set<UUID> = []
  @State private var locationName = ""
  @State private var locationAddress = ""
  @State private var links: [SavedOwnedLinkDraft] = []
  @State private var reuseIdentifier: UUID?
  @State private var destinations: [SavedPlannerList] = []
  @State private var selectedListIdentifiers: Set<UUID> = []
  @State private var isWorking = false
  @State private var applied = false
  @State private var operationIdentifier = UUID()
  @State private var reviewChanged = false

  var body: some View {
    NavigationStack {
      Form {
        if let draft {
          reviewSections(draft)
        } else {
          Section {
            TextField("Text or link", text: $input, axis: .vertical)
              .lineLimit(4...10)
              .accessibilityIdentifier("saved.capture.input")
          } footer: {
            Text("Paste your text or links, then review before adding one Item.")
          }
        }
        if reviewChanged {
          Section {
            Label(
              "The destination changed. Review before adding again.", systemImage: "arrow.clockwise"
            )
          }
        }
        if let message = store.alertMessage {
          Section {
            Label(message, systemImage: "exclamationmark.triangle")
          }
        }
      }
      .formStyle(.grouped)
      .disabled(isWorking || store.isSaving || applied)
      .navigationTitle(draft == nil ? "Capture Text or Link" : "Review Capture")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(applied ? "Done" : "Cancel") {
            Task {
              isWorking = true
              if let draft, !applied { await store.discardCapture(draft) }
              dismiss()
            }
          }
          .disabled(isWorking || store.isSaving)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("saved.capture.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          if draft == nil {
            Button("Review") { Task { await prepare() } }
              .disabled(
                !store.canCreate || isWorking
                  || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              )
              .accessibilityIdentifier("saved.capture.review")
          } else {
            Button("Add") { Task { await save() } }
              .disabled(!store.canCreate || isWorking || applied || !canSave)
              .accessibilityIdentifier("saved.capture.add")
          }
        }
      }
      .overlay {
        if isWorking || store.isSaving {
          ProgressView(store.isSaving ? "Saving Item" : "Preparing capture")
        }
      }
    }
    .interactiveDismissDisabled(isWorking || store.isSaving)
    .onDisappear {
      if let draft, !applied { Task { await store.discardCapture(draft) } }
    }
    #if os(macOS)
      .frame(minWidth: 440, minHeight: 420)
    #endif
  }

  @ViewBuilder
  private func reviewSections(_ draft: PlannerCaptureDraftRead) -> some View {
    if !draft.reuseCandidates.isEmpty || reuseIdentifier != nil {
      Section {
        Picker("Save as", selection: $reuseIdentifier) {
          Text("Create new Item").tag(nil as UUID?)
          if let reuseIdentifier,
            !draft.reuseCandidates.contains(where: { $0.itemId == reuseIdentifier })
          {
            Text("Selected Item no longer matches").tag(Optional(reuseIdentifier)).disabled(true)
          }
          ForEach(draft.reuseCandidates, id: \.itemId) { candidate in
            Text("Use existing: \(candidate.title)").tag(Optional(candidate.itemId))
          }
        }
        .accessibilityIdentifier("saved.capture.choice")
      } footer: {
        Text(
          "Use existing adds missing links and Lists. Its content and completion stay as they are.")
      }
    }
    if reuseIdentifier == nil {
      Section("Item") {
        TextField("Title", text: $title).accessibilityIdentifier("saved.capture.title")
        TextField("Subtitle", text: $subtitle).accessibilityIdentifier("saved.capture.subtitle")
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.capture.notes")
      }
      SavedActivityEstimateEditor(
        estimate: $estimate, accessibilityIdentifierPrefix: "saved.capture.estimate")
      Section("Labels") {
        NavigationLink {
          SavedItemLabelPicker(store: store, kind: .category, selection: $categoryIdentifiers)
        } label: {
          LabeledContent("Categories", value: selectionSummary(categoryIdentifiers))
        }
        .accessibilityIdentifier("saved.capture.categories")
        NavigationLink {
          SavedItemLabelPicker(store: store, kind: .tag, selection: $tagIdentifiers)
        } label: {
          LabeledContent("Tags", value: selectionSummary(tagIdentifiers))
        }
        .accessibilityIdentifier("saved.capture.tags")
      }
      Section("Location") {
        TextField("Place name", text: $locationName).accessibilityIdentifier(
          "saved.capture.location.name")
        TextField("Address", text: $locationAddress).accessibilityIdentifier(
          "saved.capture.location.address")
      }
    }
    SavedOwnedLinksEditor(links: $links, accessibilityIdentifierPrefix: "saved.capture.link")
    if !destinations.isEmpty {
      Section {
        ForEach(destinations) { destination in
          Toggle(
            destination.name,
            isOn: Binding(
              get: { selectedListIdentifiers.contains(destination.id) },
              set: { selected in
                if selected {
                  selectedListIdentifiers.insert(destination.id)
                } else {
                  selectedListIdentifiers.remove(destination.id)
                }
              })
          )
          .accessibilityIdentifier("saved.capture.list.\(destination.id.uuidString)")
        }
      } header: {
        Text("Add to Lists")
      } footer: {
        Text("With no Lists selected, a new Item goes to Inbox. Existing memberships are kept.")
      }
    } else {
      Section { Text("New Items will be added to Inbox.").foregroundStyle(.secondary) }
    }
    ForEach(draft.inputIssues, id: \.inputIndex) { issue in
      Section {
        Label(issue.message, systemImage: "exclamationmark.triangle")
        Button("Remove Input") {
          Task {
            isWorking = true
            defer { isWorking = false }
            if let updated = await store.updateCapture(
              draft, edit: .init(removeInputIndexes: [issue.inputIndex]))
            {
              if title == draft.content.title { title = updated.content.title }
              self.draft = updated
            }
          }
        }
      }
    }
  }

  private var canSave: Bool {
    guard let draft, !draft.inputIssues.contains(where: \.blocksSave) else { return false }
    if let reuseIdentifier {
      return draft.reuseCandidates.contains { $0.itemId == reuseIdentifier }
    }
    return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func selectionSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "None" : "\(identifiers.count) selected"
  }

  private var location: PlannerOwnedLocation? {
    let coordinate = draft?.content.location?.coordinate
    let name = optionalText(locationName, original: draft?.content.location?.displayName)
    let address = optionalText(locationAddress, original: draft?.content.location?.formattedAddress)
    if name == nil && address == nil && coordinate == nil { return nil }
    return .init(displayName: name, formattedAddress: address, coordinate: coordinate)
  }

  private func optionalText(_ text: String, original: String?) -> String? {
    if text == (original ?? "") { return original }
    return text.isEmpty ? nil : text
  }

  private func optionalChange<Value: Equatable>(_ value: Value?, original: Value?)
    -> PlannerFieldChange<Value>
  {
    if value == original { return .unchanged }
    if let value { return .set(value) }
    return .clear
  }

  private var destinationPreferenceKey: String? {
    store.devicePreferenceNamespace.map { "Planner.capture.global.destinations.\($0)" }
  }

  private func prepare() async {
    guard !isWorking else { return }
    isWorking = true
    defer { isWorking = false }
    guard let prepared = await store.prepareCapture(text: input) else { return }
    draft = prepared
    title = prepared.content.title
    subtitle = prepared.content.subtitle ?? ""
    notes = prepared.content.notes ?? ""
    estimate = prepared.content.estimate
    categoryIdentifiers = prepared.content.categoryIds
    tagIdentifiers = prepared.content.tagIds
    locationName = prepared.content.location?.displayName ?? ""
    locationAddress = prepared.content.location?.formattedAddress ?? ""
    links = prepared.links.map(SavedOwnedLinkDraft.init)
    if prepared.reuseCandidates.count == 1 { reuseIdentifier = prepared.reuseCandidates[0].itemId }
    guard let loaded = await store.readLists(archive: .active) else { return }
    destinations = loaded
    if let key = destinationPreferenceKey,
      let values = UserDefaults.standard.stringArray(forKey: key)
    {
      let remembered = Set(values.compactMap(UUID.init(uuidString:)))
      if remembered.isSubset(of: Set(loaded.map(\.id))) { selectedListIdentifiers = remembered }
    }
  }

  private func save() async {
    guard var draft, !isWorking, !applied else { return }
    isWorking = true
    store.alertMessage = nil
    defer { isWorking = false }
    let previousLinks = draft.links.map {
      PlannerLinkInput(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
    }
    let editedLinks = links.map(\.input)
    let hasContentChanges =
      reuseIdentifier == nil
      && (title != draft.content.title || subtitle != (draft.content.subtitle ?? "")
        || notes != (draft.content.notes ?? "") || estimate != draft.content.estimate
        || location != draft.content.location || categoryIdentifiers != draft.content.categoryIds
        || tagIdentifiers != draft.content.tagIds)
    if hasContentChanges || editedLinks != previousLinks {
      let changes: PlannerItemChanges
      if reuseIdentifier == nil {
        changes = .init(
          title: title == draft.content.title ? .unchanged : .set(title),
          subtitle: optionalChange(
            optionalText(subtitle, original: draft.content.subtitle),
            original: draft.content.subtitle),
          notes: optionalChange(
            optionalText(notes, original: draft.content.notes), original: draft.content.notes),
          location: optionalChange(location, original: draft.content.location),
          estimate: optionalChange(estimate, original: draft.content.estimate),
          links: editedLinks == previousLinks ? .unchanged : .set(editedLinks),
          categoryIds: optionalChange(categoryIdentifiers, original: draft.content.categoryIds),
          tagIds: optionalChange(tagIdentifiers, original: draft.content.tagIds))
      } else {
        changes = .init(links: .set(editedLinks))
      }
      guard
        let updated = await store.updateCapture(
          draft,
          edit: .init(changes: changes))
      else { return }
      if title == draft.content.title { title = updated.content.title }
      draft = updated
      self.draft = updated
      links = updated.links.map(SavedOwnedLinkDraft.init)
    }
    guard canSave else { return }
    let choice: PlannerCaptureChoice = reuseIdentifier.map { .reuse(itemId: $0) } ?? .createNew
    guard
      let prepared = await store.reviewCapture(
        draft, choice: choice, listIdentifiers: selectedListIdentifiers)
    else { return }
    switch await store.applyReviewedChange(prepared, operationIdentifier: operationIdentifier) {
    case .applied(let result):
      applied = true
      if let key = destinationPreferenceKey {
        UserDefaults.standard.set(selectedListIdentifiers.map(\.uuidString), forKey: key)
      }
      let source =
        reuseIdentifier.map { PlannerEntityReference(kind: .item, id: $0) }
        ?? result.generated.first { $0.kind == .item }
      if let source { didSave(source) }
      if store.alertMessage == nil { dismiss() }
    case .reviewChanged:
      reviewChanged = true
    case .failed: break
    }
  }
}
