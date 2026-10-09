import PlannerCore
import SwiftUI

struct SavedPlannerView: View {
  @Bindable var store: SavedPlannerStore
  @State private var selectedListId: UUID?
  @State private var selectedList: PlannerListSourceRead?
  @State private var listItems: [SavedPlannerItem]?
  @State private var isOpeningList = false
  @State private var showNewList = false
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  var body: some View {
    Group {
      if store.isReady {
        plannerColumns
      } else if let reason = store.openingFailure {
        ContentUnavailableView {
          Label("Planner unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(reason)
        } actions: {
          Button("Try Again") { Task { await store.open() } }
        }
      } else {
        ProgressView("Opening Planner")
      }
    }
    .task { await store.open() }
    .task(id: selectedListId) { await loadSelectedList() }
    .sheet(isPresented: $showNewList) {
      SavedNewListForm(store: store) { source in selectedListId = source.id }
    }
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
      .frame(minWidth: 820, minHeight: 540)
    #endif
  }

  private func loadSelectedList() async {
    guard let identifier = selectedListId else {
      selectedList = nil
      listItems = nil
      isOpeningList = false
      return
    }
    isOpeningList = true
    selectedList = nil
    listItems = nil
    let loaded = await store.readList(identifier)
    let loadedItems = loaded == nil ? nil : await store.readListItems(identifier)
    guard !Task.isCancelled, selectedListId == identifier else { return }
    selectedList = loaded
    listItems = loadedItems
    isOpeningList = false
  }

  private var plannerColumns: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      List(selection: $selectedListId) {
        Section("Lists") {
          ForEach(store.lists) { list in
            NavigationLink(value: list.id) {
              Label(list.name, systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier("saved.list.\(list.id.uuidString)")
          }
        }
      }
      .listStyle(.sidebar)
      .overlay {
        if store.lists.isEmpty {
          ContentUnavailableView(
            "No Lists yet", systemImage: "list.bullet.rectangle",
            description: Text("Create a List to start planning."))
        }
      }
      .navigationTitle("Planner")
      .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
      .toolbar {
        ToolbarItem {
          Button("New List", systemImage: "plus") { showNewList = true }
            .disabled(!store.canCreate)
            .accessibilityIdentifier("saved.list.new")
        }
      }
    } content: {
      if let selectedList {
        Group {
          if let listItems {
            if listItems.isEmpty {
              ContentUnavailableView("No items", systemImage: "checklist")
            } else {
              List(listItems) { item in
                Label(
                  item.row.title,
                  systemImage: item.row.effectiveDone == true ? "checkmark.circle.fill" : "circle")
              }
            }
          } else {
            ContentUnavailableView {
              Label("Items unavailable", systemImage: "exclamationmark.triangle")
            } actions: {
              Button("Try Again") { Task { await loadSelectedList() } }
            }
          }
        }
        .navigationTitle(selectedList.content.name)
      } else if isOpeningList {
        ProgressView("Opening List")
      } else if selectedListId != nil {
        ContentUnavailableView {
          Label("List unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text("Planner could not open the selected List.")
        } actions: {
          Button("Try Again") { Task { await loadSelectedList() } }
        }
      } else if store.lists.isEmpty {
        ContentUnavailableView(
          "No Lists yet", systemImage: "list.bullet.rectangle",
          description: Text("Create a List to start planning."))
      } else {
        ContentUnavailableView("Choose a List", systemImage: "list.bullet.rectangle")
      }
    } detail: {
      ContentUnavailableView("Choose an Item", systemImage: "square.stack")
    }
    .navigationSplitViewStyle(.balanced)
    #if os(iOS)
      .onChange(of: selectedListId) { _, identifier in
        if identifier != nil { columnVisibility = .doubleColumn }
      }
    #endif
  }
}

private struct SavedNewListForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let didCreate: (PlannerEntityReference) -> Void
  @State private var name = ""
  @State private var operationId = UUID()

  var body: some View {
    NavigationStack {
      Form {
        TextField("Name", text: $name)
          .accessibilityIdentifier("saved.list.name")
      }
      .formStyle(.grouped)
      .navigationTitle("New List")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.list.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              if let source = await store.createList(name: name, operationId: operationId) {
                didCreate(source)
                dismiss()
              }
            }
          }
          .disabled(
            !store.canCreate || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.list.save")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Saving List") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 360, minHeight: 180)
    #endif
  }
}
