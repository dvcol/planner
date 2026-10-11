import PlannerCore
import SwiftUI

struct SavedItineraryCatalog: View {
  let store: SavedPlannerStore
  @Binding var selection: UUID?
  @State private var itineraries: [SavedPlannerItinerary]?
  @State private var isLoading = false
  @State private var loadingFailure: String?
  @State private var showNewItinerary = false

  var body: some View {
    List(selection: $selection) {
      ForEach(itineraries ?? []) { itinerary in
        NavigationLink(value: itinerary.id) {
          Label(itinerary.title, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .accessibilityLabel(itinerary.title)
        .accessibilityIdentifier("saved.itinerary.row.\(itinerary.id.uuidString)")
      }
    }
    .overlay {
      if isLoading {
        ProgressView("Loading Itineraries")
      } else if let loadingFailure {
        ContentUnavailableView {
          Label("Itineraries unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try Again") { Task { await loadItineraries() } }
        }
      } else if itineraries?.isEmpty == true {
        ContentUnavailableView(
          "No Itineraries yet", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
          description: Text("Create an Itinerary to start planning."))
      }
    }
    .navigationTitle("Itineraries")
    .navigationSplitViewColumnWidth(min: 240, ideal: 320, max: 480)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("New Itinerary", systemImage: "plus") { showNewItinerary = true }
          .disabled(!store.canCreate)
          .accessibilityIdentifier("saved.itinerary.new")
      }
    }
    .task(id: store.changeRevision) { await loadItineraries() }
    .sheet(isPresented: $showNewItinerary) {
      SavedItineraryForm(store: store) { source in selection = source.id }
    }
  }

  private func loadItineraries() async {
    isLoading = true
    loadingFailure = nil
    let revision = store.changeRevision
    let loaded = await store.readItineraries()
    guard !Task.isCancelled, store.changeRevision == revision else { return }
    if let loaded {
      itineraries = loaded
    } else {
      loadingFailure = store.alertMessage ?? "Planner could not read its Itineraries."
      store.alertMessage = nil
    }
    isLoading = false
  }
}

private struct SavedItineraryEditDraft: Identifiable {
  let itinerary: PlannerItinerarySourceRead
  var id: UUID { itinerary.source.id }
}

struct SavedItineraryDetail: View {
  let store: SavedPlannerStore
  let identifier: UUID
  @State private var itinerary: PlannerItinerarySourceRead?
  @State private var loadingFailure: String?
  @State private var editDraft: SavedItineraryEditDraft?

  var body: some View {
    Group {
      if let itinerary {
        Form {
          Section {
            if itinerary.progress.state == .empty {
              Text("No items").foregroundStyle(.secondary)
            } else if let done = itinerary.progress.doneCount,
              let total = itinerary.progress.totalCount, total > 0
            {
              ProgressView(value: Double(done), total: Double(total)) {
                Text("\(done) of \(total) \(total == 1 ? "item" : "items") done")
              }
            } else {
              Text("Progress unavailable").foregroundStyle(.secondary)
            }
          }
          if let notes = itinerary.content.notes, !notes.isEmpty {
            Section("Notes") { Text(notes).textSelection(.enabled) }
          }
        }
        .formStyle(.grouped)
        .navigationTitle(itinerary.content.title)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button("Edit Itinerary", systemImage: "pencil") {
              editDraft = .init(itinerary: itinerary)
            }
            .disabled(!store.canCreate)
            .accessibilityIdentifier("saved.itinerary.edit")
          }
        }
      } else if let loadingFailure {
        ContentUnavailableView {
          Label("Itinerary unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try Again") { Task { await loadItinerary() } }
        }
      } else {
        ProgressView("Opening Itinerary")
      }
    }
    .task(id: store.changeRevision) { await loadItinerary() }
    .sheet(item: $editDraft) { draft in
      SavedItineraryForm(store: store, itinerary: draft.itinerary) { _ in }
    }
  }

  private func loadItinerary() async {
    loadingFailure = nil
    let revision = store.changeRevision
    let loaded = await store.readItinerary(identifier)
    guard !Task.isCancelled, store.changeRevision == revision else { return }
    if let loaded {
      itinerary = loaded
    } else {
      itinerary = nil
      loadingFailure = store.alertMessage ?? "Planner could not open this Itinerary."
      store.alertMessage = nil
    }
  }
}

private struct SavedItineraryForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let itinerary: PlannerItinerarySourceRead?
  let didSave: (PlannerEntityReference) -> Void
  @State private var title: String
  @State private var notes: String
  @State private var operationIdentifier = UUID()

  init(
    store: SavedPlannerStore, itinerary: PlannerItinerarySourceRead? = nil,
    didSave: @escaping (PlannerEntityReference) -> Void
  ) {
    self.store = store
    self.itinerary = itinerary
    self.didSave = didSave
    _title = State(initialValue: itinerary?.content.title ?? "")
    _notes = State(initialValue: itinerary?.content.notes ?? "")
  }

  private var canSave: Bool {
    guard store.canCreate, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    guard let itinerary else { return true }
    return title != itinerary.content.title || notes != (itinerary.content.notes ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Title", text: $title)
          .accessibilityIdentifier("saved.itinerary.title")
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.itinerary.notes")
      }
      .disabled(store.isSaving)
      .formStyle(.grouped)
      .navigationTitle(itinerary == nil ? "New Itinerary" : "Edit Itinerary")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.itinerary.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(!canSave)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("saved.itinerary.save")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Saving Itinerary") }
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
      .frame(minWidth: 440, minHeight: 320)
    #endif
  }

  private func save() async {
    let source: PlannerEntityReference?
    if let itinerary {
      let saved = await store.editItinerary(
        itinerary, title: title, notes: notes, operationIdentifier: operationIdentifier)
      source = saved ? itinerary.source : nil
    } else {
      source = await store.createItinerary(
        title: title, notes: notes, operationIdentifier: operationIdentifier)
    }
    guard let source, store.alertMessage == nil else { return }
    didSave(source)
    dismiss()
  }
}
