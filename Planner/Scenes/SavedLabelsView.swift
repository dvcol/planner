import PlannerCore
import SwiftUI

enum SavedLabelKind: String, CaseIterable, Identifiable {
  case category, tag

  var id: String { rawValue }
  var title: String { self == .category ? "Category" : "Tag" }
  var pluralTitle: String { self == .category ? "Categories" : "Tags" }
  var sourceKind: PlannerEntityKind { self == .category ? .category : .tag }
  var systemImage: String { self == .category ? "square.grid.2x2" : "tag" }
}

enum SavedLabelSource {
  case category(PlannerCategorySourceRead)
  case tag(PlannerTagSourceRead)

  var name: String {
    switch self {
    case .category(let category): category.content.name
    case .tag(let tag): tag.content.name
    }
  }
}

struct SavedLabelSelection: Hashable {
  let kind: SavedLabelKind
  let id: UUID
}

struct SavedLabelsView: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @State private var categories = [SavedPlannerLabel]()
  @State private var tags = [SavedPlannerLabel]()
  @State private var isLoading = false
  @State private var loadingFailure: String?
  @State private var newLabelKind: SavedLabelKind?

  var body: some View {
    NavigationStack {
      List {
        labelSection(.category, labels: categories)
        labelSection(.tag, labels: tags)
      }
      .overlay {
        if isLoading {
          ProgressView("Loading Labels")
        } else if let loadingFailure {
          ContentUnavailableView {
            Label("Labels unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(loadingFailure)
          } actions: {
            Button("Try Again") { Task { await loadLabels() } }
          }
        }
      }
      .navigationTitle("Manage Labels")
      .navigationDestination(for: SavedLabelSelection.self) { selection in
        SavedLabelEditDestination(store: store, selection: selection)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.categories.done")
        }
        ToolbarItem(placement: .primaryAction) {
          Menu {
            ForEach(SavedLabelKind.allCases) { kind in
              Button("New \(kind.title)", systemImage: kind.systemImage) { newLabelKind = kind }
            }
          } label: {
            Label("New Label", systemImage: "plus")
          }
          .disabled(!store.canCreate)
          .accessibilityIdentifier("saved.labels.new")
          .help("Create a Category or Tag")
        }
      }
      .task(id: store.changeRevision) { await loadLabels() }
    }
    .sheet(item: $newLabelKind) { kind in
      NavigationStack { SavedLabelForm(store: store, kind: kind) }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 440, minHeight: 360)
    #endif
  }

  private func labelSection(_ kind: SavedLabelKind, labels: [SavedPlannerLabel]) -> some View {
    Section(kind.pluralTitle) {
      if labels.isEmpty {
        Text("No \(kind.pluralTitle) yet").foregroundStyle(.secondary)
      }
      ForEach(labels) { label in
        NavigationLink(label.name, value: SavedLabelSelection(kind: kind, id: label.id))
          .accessibilityIdentifier("saved.\(kind.rawValue).\(label.id.uuidString)")
      }
    }
  }

  private func loadLabels() async {
    let revision = store.changeRevision
    isLoading = true
    loadingFailure = nil
    defer { if revision == store.changeRevision { isLoading = false } }
    let loadedCategories = await store.readLabels(.category)
    let loadedTags = await store.readLabels(.tag)
    guard !Task.isCancelled, revision == store.changeRevision else { return }
    guard let loadedCategories, let loadedTags else {
      loadingFailure = store.alertMessage ?? "Planner could not read its Labels."
      store.alertMessage = nil
      return
    }
    categories = loadedCategories
    tags = loadedTags
  }
}

private struct SavedLabelEditDestination: View {
  let store: SavedPlannerStore
  let selection: SavedLabelSelection
  @State private var label: SavedLabelSource?
  @State private var loadingFailure: String?

  var body: some View {
    Group {
      if let label {
        SavedLabelForm(store: store, kind: selection.kind, original: label)
      } else if let loadingFailure {
        ContentUnavailableView {
          Label("\(selection.kind.title) unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try Again") { Task { await loadLabel() } }
        }
      } else {
        ProgressView("Opening \(selection.kind.title)")
      }
    }
    .task { await loadLabel() }
  }

  private func loadLabel() async {
    loadingFailure = nil
    if let loaded = await store.readLabel(selection) {
      label = loaded
    } else {
      loadingFailure = store.alertMessage ?? "Planner could not open this Label."
      store.alertMessage = nil
    }
  }
}

private struct SavedLabelForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let kind: SavedLabelKind
  let original: SavedLabelSource?
  @State private var name: String
  @State private var operationIdentifier = UUID()

  init(store: SavedPlannerStore, kind: SavedLabelKind, original: SavedLabelSource? = nil) {
    self.store = store
    self.kind = kind
    self.original = original
    _name = State(initialValue: original?.name ?? "")
  }

  var body: some View {
    Form {
      TextField("Name", text: $name)
        .accessibilityIdentifier("saved.\(kind.rawValue).name")
    }
    .disabled(store.isSaving)
    .formStyle(.grouped)
    .navigationTitle(original == nil ? "New \(kind.title)" : "Edit \(kind.title)")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
          .disabled(store.isSaving)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("saved.\(kind.rawValue).cancel")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { Task { await save() } }
          .disabled(
            !store.canCreate || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || name == original?.name
          )
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.\(kind.rawValue).save")
      }
    }
    .overlay {
      if store.isSaving { ProgressView("Saving \(kind.title)") }
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
    let saved: Bool
    if let original {
      saved = await store.renameLabel(
        original, name: name, operationIdentifier: operationIdentifier)
    } else {
      saved =
        await store.createLabel(kind, name: name, operationIdentifier: operationIdentifier) != nil
    }
    if saved && store.alertMessage == nil { dismiss() }
  }
}
