import PlannerCore
import SwiftUI

struct SavedCaptureForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let didSave: (PlannerEntityReference) -> Void
  @State private var input = ""
  @State private var draft: PlannerCaptureDraftRead?
  @State private var title = ""
  @State private var notes = ""
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
    if !draft.reuseCandidates.isEmpty {
      Section {
        Picker("Save as", selection: $reuseIdentifier) {
          Text("Create new Item").tag(nil as UUID?)
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
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.capture.notes")
      }
    }
    if !draft.links.isEmpty {
      Section("Links") {
        ForEach(draft.links, id: \.linkId) { link in
          Text(link.originalUrl).textSelection(.enabled)
        }
      }
    }
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
              self.draft = updated
            }
          }
        }
      }
    }
  }

  private var canSave: Bool {
    guard let draft, !draft.inputIssues.contains(where: \.blocksSave) else { return false }
    return reuseIdentifier != nil || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    notes = prepared.content.notes ?? ""
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
    if reuseIdentifier == nil,
      title != draft.content.title || notes != (draft.content.notes ?? "")
    {
      let notesChange: PlannerFieldChange<String>
      if notes == (draft.content.notes ?? "") {
        notesChange = .unchanged
      } else if notes.isEmpty {
        notesChange = .clear
      } else {
        notesChange = .set(notes)
      }
      guard
        let updated = await store.updateCapture(
          draft,
          edit: .init(
            changes: .init(
              title: title == draft.content.title ? .unchanged : .set(title),
              notes: notesChange)))
      else { return }
      draft = updated
      self.draft = updated
    }
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
