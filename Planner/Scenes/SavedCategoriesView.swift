import PlannerCore
import SwiftUI

struct SavedCategoriesView: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @State private var categories: [SavedPlannerCategory]?
  @State private var isLoading = false
  @State private var loadingFailure: String?
  @State private var showNewCategory = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(categories ?? []) { category in
          NavigationLink(category.name, value: category.id)
            .accessibilityIdentifier("saved.category.\(category.id.uuidString)")
        }
      }
      .overlay {
        if isLoading {
          ProgressView("Loading Categories")
        } else if let loadingFailure {
          ContentUnavailableView {
            Label("Categories unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(loadingFailure)
          } actions: {
            Button("Try Again") { Task { await loadCategories() } }
          }
        } else if categories?.isEmpty == true {
          ContentUnavailableView(
            "No Categories yet", systemImage: "square.grid.2x2",
            description: Text("Create a Category to get started."))
        }
      }
      .navigationTitle("Categories")
      .navigationDestination(for: UUID.self) { identifier in
        SavedCategoryEditDestination(store: store, categoryIdentifier: identifier)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.categories.done")
        }
        ToolbarItem(placement: .primaryAction) {
          Button("New Category", systemImage: "plus") { showNewCategory = true }
            .disabled(!store.canCreate)
            .accessibilityIdentifier("saved.category.new")
        }
      }
      .task(id: store.changeRevision) { await loadCategories() }
    }
    .sheet(isPresented: $showNewCategory) {
      NavigationStack { SavedCategoryForm(store: store) }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 440, minHeight: 360)
    #endif
  }

  private func loadCategories() async {
    isLoading = true
    loadingFailure = nil
    defer { isLoading = false }
    if let loaded = await store.readCategories() {
      categories = loaded
    } else {
      loadingFailure = store.alertMessage ?? "Planner could not read its Categories."
      store.alertMessage = nil
    }
  }
}

private struct SavedCategoryEditDestination: View {
  let store: SavedPlannerStore
  let categoryIdentifier: UUID
  @State private var category: PlannerCategorySourceRead?
  @State private var loadingFailure: String?

  var body: some View {
    Group {
      if let category {
        SavedCategoryForm(store: store, category: category)
      } else if let loadingFailure {
        ContentUnavailableView {
          Label("Category unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try Again") { Task { await loadCategory() } }
        }
      } else {
        ProgressView("Opening Category")
      }
    }
    .task { await loadCategory() }
  }

  private func loadCategory() async {
    loadingFailure = nil
    if let loaded = await store.readCategory(categoryIdentifier) {
      category = loaded
    } else {
      loadingFailure = store.alertMessage ?? "Planner could not open this Category."
      store.alertMessage = nil
    }
  }
}

private struct SavedCategoryForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let category: PlannerCategorySourceRead?
  @State private var name: String
  @State private var operationIdentifier = UUID()

  init(store: SavedPlannerStore, category: PlannerCategorySourceRead? = nil) {
    self.store = store
    self.category = category
    _name = State(initialValue: category?.content.name ?? "")
  }

  var body: some View {
    Form {
      TextField("Name", text: $name)
        .accessibilityIdentifier("saved.category.name")
    }
    .disabled(store.isSaving)
    .formStyle(.grouped)
    .navigationTitle(category == nil ? "New Category" : "Edit Category")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
          .disabled(store.isSaving)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("saved.category.cancel")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { Task { await save() } }
          .disabled(
            !store.canCreate || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || name == category?.content.name
          )
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.category.save")
      }
    }
    .overlay {
      if store.isSaving { ProgressView("Saving Category") }
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
    if let category {
      saved = await store.renameCategory(
        category, name: name, operationIdentifier: operationIdentifier)
    } else {
      saved =
        await store.createCategory(name: name, operationIdentifier: operationIdentifier) != nil
    }
    if saved && store.alertMessage == nil { dismiss() }
  }
}
