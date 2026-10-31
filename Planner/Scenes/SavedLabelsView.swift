import CoreGraphics
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

  var source: PlannerEntityReference {
    switch self {
    case .category(let category): category.source
    case .tag(let tag): tag.source
    }
  }

  var name: String {
    switch self {
    case .category(let category): category.content.name
    case .tag(let tag): tag.content.name
    }
  }

  var iconName: String? {
    switch self {
    case .category(let category): category.content.iconName
    case .tag(let tag): tag.content.iconName
    }
  }

  var color: PlannerColor? {
    switch self {
    case .category(let category): category.content.color
    case .tag(let tag): tag.content.color
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
            Button("Try again") { Task { await loadLabels() } }
          }
        }
      }
      .navigationTitle("Manage labels")
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
              Button("New \(kind.title.lowercased())", systemImage: kind.systemImage) {
                newLabelKind = kind
              }
            }
          } label: {
            Label("New label", systemImage: "plus")
          }
          .labelStyle(.iconOnly)
          .disabled(!store.canCreate)
          .accessibilityIdentifier("saved.labels.new")
          .help("New category or tag")
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
          Button("Try again") { Task { await loadLabel() } }
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

private enum SavedLabelSymbol: String, CaseIterable, Identifiable {
  case dining = "fork.knife"
  case museum = "building.columns"
  case travel = "airplane"
  case home = "house"
  case shopping = "bag"
  case outdoors = "leaf"
  case favorite = "star"
  case flag = "flag"

  var id: String { rawValue }
  var title: String {
    switch self {
    case .dining: "Dining"
    case .museum: "Museum"
    case .travel: "Travel"
    case .home: "Home"
    case .shopping: "Shopping"
    case .outdoors: "Outdoors"
    case .favorite: "Favorite"
    case .flag: "Flag"
    }
  }
}

private struct SavedLabelForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let kind: SavedLabelKind
  let original: SavedLabelSource?
  @State private var name: String
  @State private var iconName: String?
  @State private var usesColor: Bool
  @State private var selectedColor: CGColor
  @State private var colorWasEdited = false
  @State private var operationIdentifier = UUID()
  @State private var deletionDraft: SavedSourceDeletionDraft?
  @State private var isReviewingDeletion = false
  @State private var deletionCompleted = false

  init(store: SavedPlannerStore, kind: SavedLabelKind, original: SavedLabelSource? = nil) {
    self.store = store
    self.kind = kind
    self.original = original
    _name = State(initialValue: original?.name ?? "")
    _iconName = State(initialValue: original?.iconName)
    _usesColor = State(initialValue: original?.color != nil)
    let color =
      original?.color ?? PlannerColor(red: 0, green: 0.47843137254901963, blue: 1, alpha: 1)
    _selectedColor = State(
      initialValue: CGColor(
        srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha))
  }

  var body: some View {
    Form {
      TextField("Name", text: $name)
        .accessibilityIdentifier("saved.\(kind.rawValue).name")
      Section("Appearance") {
        Toggle("Use color", isOn: $usesColor)
          .accessibilityIdentifier("saved.\(kind.rawValue).color.enabled")
        if usesColor {
          ColorPicker(
            "Color",
            selection: Binding(
              get: { selectedColor },
              set: {
                selectedColor = $0
                colorWasEdited = true
              }), supportsOpacity: true
          )
          .accessibilityIdentifier("saved.\(kind.rawValue).color")
        }
        Picker("Icon", selection: $iconName) {
          Label("Default", systemImage: kind.systemImage).tag(String?.none)
          ForEach(SavedLabelSymbol.allCases) { symbol in
            Label(symbol.title, systemImage: symbol.rawValue).tag(Optional(symbol.rawValue))
          }
          if let existing = original?.iconName, SavedLabelSymbol(rawValue: existing) == nil {
            Label("Current icon", systemImage: existing).tag(Optional(existing))
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("saved.\(kind.rawValue).icon")
        .accessibilityValue(iconDisplayName)
      }
      if let original {
        Section {
          Button("Delete \(kind.title.lowercased())", systemImage: "trash", role: .destructive) {
            Task { await reviewDeletion(original) }
          }
          .disabled(!store.canCreate)
          .accessibilityIdentifier("saved.\(kind.rawValue).delete")
        }
      }
    }
    .disabled(store.isSaving || isReviewingDeletion)
    .formStyle(.grouped)
    .navigationTitle(
      original == nil ? "New \(kind.title.lowercased())" : "Edit \(kind.title.lowercased())"
    )
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
          .disabled(store.isSaving || isReviewingDeletion)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("saved.\(kind.rawValue).cancel")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { Task { await save() } }
          .disabled(
            !store.canCreate || isReviewingDeletion
              || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || !hasChanges
          )
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.\(kind.rawValue).save")
      }
    }
    .overlay {
      if isReviewingDeletion {
        ProgressView("Reviewing deletion")
      } else if store.isSaving {
        ProgressView("Saving \(kind.title)")
      }
    }
    .interactiveDismissDisabled(store.isSaving || isReviewingDeletion)
    .sheet(item: $deletionDraft, onDismiss: finishDeletion) { draft in
      SavedSourceDeletionForm(store: store, draft: draft) { _ in deletionCompleted = true }
    }
    .alert(
      "Plan 2Do",
      isPresented: Binding(
        get: { store.alertMessage != nil && deletionDraft == nil },
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

  private var hasChanges: Bool {
    name != original?.name || iconName != original?.iconName
      || usesColor != (original?.color != nil) || (usesColor && colorWasEdited)
  }

  private func colorForSave() throws -> PlannerColor? {
    guard usesColor else { return nil }
    if let originalColor = original?.color, !colorWasEdited { return originalColor }
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let converted = selectedColor.converted(
        to: colorSpace, intent: .relativeColorimetric, options: nil),
      let components = converted.components, components.count == 4,
      components.allSatisfy({ $0.isFinite && (0...1).contains($0) })
    else {
      throw CocoaError(
        .coderInvalidValue,
        userInfo: [
          NSLocalizedDescriptionKey: "This color cannot be saved. Try a different color."
        ])
    }
    return PlannerColor(
      red: Double(components[0]), green: Double(components[1]),
      blue: Double(components[2]), alpha: Double(components[3]))
  }

  private var iconDisplayName: String {
    guard let iconName else { return "Default" }
    return SavedLabelSymbol(rawValue: iconName)?.title ?? "Current icon"
  }

  private func save() async {
    let color: PlannerColor?
    do { color = try colorForSave() } catch {
      store.alertMessage = error.localizedDescription
      return
    }
    let saved: Bool
    if let original {
      saved = await store.editLabel(
        original, name: name, color: color, iconName: iconName,
        operationIdentifier: operationIdentifier)
    } else {
      saved =
        await store.createLabel(
          kind, name: name, color: color, iconName: iconName,
          operationIdentifier: operationIdentifier) != nil
    }
    if saved && store.alertMessage == nil { dismiss() }
  }

  private func reviewDeletion(_ label: SavedLabelSource) async {
    guard !isReviewingDeletion else { return }
    isReviewingDeletion = true
    defer { isReviewingDeletion = false }
    if let review = await store.prepareSourceDeletion(label.source) {
      deletionDraft = .init(source: label.source, name: label.name, review: review)
    }
  }

  private func finishDeletion() {
    if deletionCompleted { dismiss() }
  }
}
