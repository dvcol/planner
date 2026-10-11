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
  @Binding var selection: SavedItineraryRowSelection?
  @State private var contents: SavedItineraryContents?
  @State private var loadingFailure: String?
  @State private var editDraft: SavedItineraryEditDraft?
  @State private var showAddEntry = false
  @State private var collapsedEntries: Set<UUID> = []
  @State private var bulkCompletionDraft: SavedBulkCompletionDraft?
  @State private var isPreparingBulkCompletion = false
  @State private var removedSelectionMessage: String?
  #if os(iOS)
    @State private var entryEditMode: EditMode = .inactive
  #endif

  var body: some View {
    Group {
      if let contents {
        let itinerary = contents.itinerary
        List(selection: $selection) {
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
            let directCount = contents.entries.filter { $0.source.kind == .item }.count
            let listCount = contents.entries.filter { $0.source.kind == .list }.count
            Text(
              "\(directCount) direct \(directCount == 1 ? "item" : "items") · \(listCount) \(listCount == 1 ? "list" : "lists")"
            )
            .font(.caption).foregroundStyle(.secondary)
          }
          if let notes = itinerary.content.notes, !notes.isEmpty {
            Section("Notes") { Text(notes).textSelection(.enabled) }
          }
          ItemLabelsSection(labels: itinerary.labels)
          Section("Entries") {
            ForEach(contents.entries) { entry in
              VStack(alignment: .leading) {
                if entry.source.kind == .list {
                  DisclosureGroup(
                    isExpanded: Binding(
                      get: { !collapsedEntries.contains(entry.id) },
                      set: { expanded in
                        if expanded {
                          collapsedEntries.remove(entry.id)
                        } else {
                          collapsedEntries.insert(entry.id)
                        }
                      })
                  ) {
                    if entry.items.isEmpty {
                      Text("No items").foregroundStyle(.secondary)
                    } else {
                      ForEach(entry.items) { item in itineraryRow(item) }
                    }
                  } label: {
                    VStack(alignment: .leading, spacing: 6) {
                      Label(entry.title, systemImage: "list.bullet.rectangle")
                        .font(.headline)
                      if !entry.items.isEmpty {
                        let done = entry.items.filter { $0.row.effectiveDone == true }.count
                        ProgressView(value: Double(done), total: Double(entry.items.count)) {
                          Text(
                            "\(done) of \(entry.items.count) \(entry.items.count == 1 ? "item" : "items") done"
                          )
                          .font(.caption).foregroundStyle(.secondary)
                        }
                      }
                    }
                    .padding(.vertical, 8)
                    .contextMenu {
                      entryActions(entry, in: contents.entries)
                      Divider()
                      Group {
                        Button("Mark all Done") {
                          prepareBulkCompletion(
                            .itineraryListEntry(itineraryId: identifier, listEntryId: entry.id),
                            containerName: entry.title, done: true)
                        }
                        Button("Mark all Undone") {
                          prepareBulkCompletion(
                            .itineraryListEntry(itineraryId: identifier, listEntryId: entry.id),
                            containerName: entry.title, done: false)
                        }
                      }
                      .disabled(
                        !store.canCreate || isPreparingBulkCompletion || entry.items.isEmpty)
                    }
                  }
                } else if let item = entry.items.first {
                  itineraryRow(item)
                    .contextMenu { entryActions(entry, in: contents.entries) }
                }
              }
              .accessibilityElement(children: .contain)
              .accessibilityIdentifier("saved.itinerary.entry.\(entry.id.uuidString)")
              .moveDisabled(!canReorderEntries)
            }
            .onMove { offsets, destination in
              moveEntry(from: offsets, to: destination, in: contents.entries)
            }
          }
        }
        #if os(iOS)
          .environment(\.editMode, $entryEditMode)
        #endif
        .navigationTitle(itinerary.content.title)
        .navigationSplitViewColumnWidth(min: 260, ideal: 400, max: 600)
        .overlay(alignment: .topTrailing) {
          if isPreparingBulkCompletion {
            ProgressView("Preparing review").controlSize(.small).padding()
          }
        }
        .toolbar {
          #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
              EditButton()
                .environment(\.editMode, $entryEditMode)
                .accessibilityLabel("Reorder entries")
                .accessibilityIdentifier("saved.itinerary.reorder")
                .disabled(
                  !store.canCreate || isPreparingBulkCompletion
                    || (contents.entries.count < 2 && !entryEditMode.isEditing))
            }
          #endif
          ToolbarItem(placement: .primaryAction) {
            Button("Add entry", systemImage: "plus") { showAddEntry = true }
              .disabled(!store.canCreate)
              .accessibilityIdentifier("saved.itinerary.entry.new")
          }
          ToolbarItem(placement: .primaryAction) {
            Button("Edit Itinerary", systemImage: "pencil") {
              editDraft = .init(itinerary: itinerary)
            }
            .disabled(!store.canCreate)
            .accessibilityIdentifier("saved.itinerary.edit")
          }
          ToolbarItem(placement: .primaryAction) {
            Menu {
              Button("Mark all Done") {
                prepareBulkCompletion(
                  .itinerary(itineraryId: identifier), containerName: itinerary.content.title,
                  done: true)
              }
              Button("Mark all Undone") {
                prepareBulkCompletion(
                  .itinerary(itineraryId: identifier), containerName: itinerary.content.title,
                  done: false)
              }
            } label: {
              Label("Itinerary actions", systemImage: "ellipsis")
            }
            .disabled(
              !store.canCreate || isPreparingBulkCompletion || itinerary.progress.totalCount == 0
            )
            .help("Itinerary actions")
            .accessibilityIdentifier("saved.itinerary.actions")
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
    .sheet(isPresented: $showAddEntry) {
      SavedAddItineraryEntryForm(store: store, itineraryId: identifier)
    }
    .sheet(item: $bulkCompletionDraft) { draft in
      SavedBulkCompletionForm(store: store, draft: draft)
    }
    .alert(
      "Planner",
      isPresented: Binding(
        get: {
          (store.alertMessage != nil || removedSelectionMessage != nil)
            && editDraft == nil && !showAddEntry
            && bulkCompletionDraft == nil
        },
        set: {
          if !$0 {
            store.alertMessage = nil
            removedSelectionMessage = nil
          }
        })
    ) {
      Button("OK") {
        store.alertMessage = nil
        removedSelectionMessage = nil
      }
    } message: {
      Text(alertDescription)
    }
  }

  private var alertDescription: String {
    let description = removedSelectionMessage ?? store.alertMessage ?? ""
    guard removedSelectionMessage != nil && store.recoveryBlocked else { return description }
    return description
      + "\n\nThe change was saved, but its recovery copy is incomplete. Further changes are paused."
  }

  private func itineraryRow(_ item: SavedItineraryItem) -> some View {
    SavedItineraryItemRow(item: item, canChange: store.canCreate) {
      Task {
        _ = await store.setAppearanceCompletion(
          item.id.appearance(itineraryId: identifier), done: item.row.effectiveDone != true)
      }
    }
    .tag(item.id)
  }

  private func entryActions(
    _ entry: SavedItineraryEntryRows, in entries: [SavedItineraryEntryRows]
  ) -> some View {
    Group {
      Button("Move to Beginning") {
        Task {
          _ = await store.reorderItineraryEntry(
            entry.id, itineraryIdentifier: identifier, placement: .first)
        }
      }
      .disabled(entries.first?.id == entry.id)
      Button("Move to End") {
        Task {
          _ = await store.reorderItineraryEntry(
            entry.id, itineraryIdentifier: identifier, placement: .last)
        }
      }
      .disabled(entries.last?.id == entry.id)
      Divider()
      Button("Remove from Itinerary", role: .destructive) { removeEntry(entry) }
    }
    .disabled(!store.canCreate || isPreparingBulkCompletion)
  }

  private func removeEntry(_ entry: SavedItineraryEntryRows) {
    Task {
      guard await store.removeItineraryEntry(entry.id, itineraryIdentifier: identifier),
        let selection
      else { return }
      let selectedEntryIdentifier: UUID
      switch selection {
      case .direct(let entryIdentifier): selectedEntryIdentifier = entryIdentifier
      case .expanded(let entryIdentifier, _): selectedEntryIdentifier = entryIdentifier
      }
      guard selectedEntryIdentifier == entry.id else { return }
      self.selection = nil
      if entry.source.kind == .list {
        removedSelectionMessage =
          "The selected entry was removed. The List and its Items remain available outside this Itinerary."
      } else {
        removedSelectionMessage =
          "The selected entry was removed. The Item remains available in Items."
      }
    }
  }

  private var canReorderEntries: Bool {
    guard store.canCreate, !isPreparingBulkCompletion else { return false }
    #if os(iOS)
      return entryEditMode.isEditing
    #else
      return true
    #endif
  }

  private func moveEntry(
    from offsets: IndexSet, to destination: Int, in entries: [SavedItineraryEntryRows]
  ) {
    guard canReorderEntries else { return }
    guard offsets.count == 1, let source = offsets.first, entries.indices.contains(source),
      (0...entries.count).contains(destination)
    else {
      store.alertMessage = "Move one entry at a time."
      return
    }
    guard destination != source, destination != source + 1 else { return }
    let placement: PlannerPlacement
    if destination < source {
      placement = .before(associationId: entries[destination].id)
    } else {
      placement = .after(associationId: entries[destination - 1].id)
    }
    Task {
      _ = await store.reorderItineraryEntry(
        entries[source].id, itineraryIdentifier: identifier, placement: placement)
    }
  }

  private func prepareBulkCompletion(
    _ scope: PlannerBulkScope, containerName: String, done: Bool
  ) {
    guard !isPreparingBulkCompletion else { return }
    isPreparingBulkCompletion = true
    Task {
      defer { isPreparingBulkCompletion = false }
      guard
        let review = await store.prepareBulkCompletion(scope: scope, done: done)
      else { return }
      bulkCompletionDraft = .init(containerName: containerName, review: review)
    }
  }

  private func loadItinerary() async {
    loadingFailure = nil
    let revision = store.changeRevision
    let loaded = await store.readItineraryContents(identifier)
    guard !Task.isCancelled, store.changeRevision == revision else { return }
    if let loaded {
      contents = loaded
    } else {
      contents = nil
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
  @State private var categoryIdentifiers: Set<UUID>
  @State private var tagIdentifiers: Set<UUID>
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
    _categoryIdentifiers = State(initialValue: itinerary?.content.categoryIds ?? [])
    _tagIdentifiers = State(initialValue: itinerary?.content.tagIds ?? [])
  }

  private var canSave: Bool {
    guard store.canCreate, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    guard let itinerary else { return true }
    return title != itinerary.content.title || notes != (itinerary.content.notes ?? "")
      || categoryIdentifiers != itinerary.content.categoryIds
      || tagIdentifiers != itinerary.content.tagIds
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Title", text: $title)
          .accessibilityIdentifier("saved.itinerary.title")
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.itinerary.notes")
        Section("Labels") {
          NavigationLink {
            SavedItemLabelPicker(store: store, kind: .category, selection: $categoryIdentifiers)
          } label: {
            LabeledContent("Categories", value: selectionSummary(categoryIdentifiers))
          }
          .accessibilityIdentifier("saved.itinerary.categories")
          NavigationLink {
            SavedItemLabelPicker(store: store, kind: .tag, selection: $tagIdentifiers)
          } label: {
            LabeledContent("Tags", value: selectionSummary(tagIdentifiers))
          }
          .accessibilityIdentifier("saved.itinerary.tags")
        }
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
        itinerary, title: title, notes: notes, categoryIdentifiers: categoryIdentifiers,
        tagIdentifiers: tagIdentifiers, operationIdentifier: operationIdentifier)
      source = saved ? itinerary.source : nil
    } else {
      source = await store.createItinerary(
        title: title, notes: notes, categoryIdentifiers: categoryIdentifiers,
        tagIdentifiers: tagIdentifiers, operationIdentifier: operationIdentifier)
    }
    guard let source, store.alertMessage == nil else { return }
    didSave(source)
    dismiss()
  }

  private func selectionSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "None" : "\(identifiers.count) selected"
  }
}
