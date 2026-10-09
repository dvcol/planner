import PlannerCore
import SwiftUI

private enum SavedPlannerSection: Hashable {
  case lists, items
}

private enum SavedPlannerSidebarSelection: Hashable {
  case lists, items
  case list(UUID)
}

struct SavedPlannerView: View {
  @Bindable var store: SavedPlannerStore
  @State private var selectedSection: SavedPlannerSection = .lists
  @State private var selectedListId: UUID?
  @State private var selectedList: PlannerListSourceRead?
  @State private var listItems: [SavedPlannerItem]?
  @State private var isOpeningList = false
  @State private var showNewList = false
  @State private var showNewItem = false
  @State private var showAddItem = false
  @State private var selectedItemId: UUID?
  @State private var selectedItem: PlannerItemSourceRead?
  @State private var isOpeningItem = false
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  var body: some View {
    Group {
      if store.isReady {
        nativeLayout
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
    .task(id: selectedItemId) { await loadSelectedItem() }
    .sheet(isPresented: $showNewList) {
      SavedNewListForm(store: store) { source in
        selectedSection = .lists
        selectedListId = source.id
      }
    }
    .sheet(isPresented: $showNewItem) {
      SavedNewItemForm(store: store) { source in selectedItemId = source.id }
    }
    .sheet(isPresented: $showAddItem) {
      if let selectedList {
        SavedAddItemForm(store: store, list: selectedList) {
          Task { await loadSelectedList() }
        }
      }
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

  @ViewBuilder
  private var nativeLayout: some View {
    #if os(macOS)
      plannerColumns
    #else
      TabView(selection: $selectedSection) {
        Tab("Lists", systemImage: "list.bullet", value: .lists) { plannerColumns }
        Tab("Items", systemImage: "square.stack", value: .items) {
          NavigationSplitView {
            itemCatalog
          } detail: {
            itemDetail
          }
        }
      }
    #endif
  }

  private var sidebarSelection: Binding<SavedPlannerSidebarSelection?> {
    Binding(
      get: {
        #if os(macOS)
          if selectedSection == .items { return .items }
        #endif
        if let selectedListId { return .list(selectedListId) }
        #if os(macOS)
          return .lists
        #else
          return nil
        #endif
      },
      set: { selection in
        switch selection {
        case .items: selectedSection = .items
        case .list(let identifier):
          selectedSection = .lists
          selectedListId = identifier
        case .lists:
          selectedSection = .lists
          selectedListId = nil
        case nil: break
        }
      })
  }

  private var isItemSection: Bool {
    #if os(macOS)
      selectedSection == .items
    #else
      false
    #endif
  }

  private var itemCatalog: some View {
    SavedItemCatalog(
      items: store.items, selection: $selectedItemId, canCreate: store.canCreate
    ) { showNewItem = true }
  }

  @ViewBuilder
  private var itemDetail: some View {
    if let selectedItem {
      SavedItemDetail(item: selectedItem, canChange: store.canCreate, isSaving: store.isSaving) {
        done in
        Task {
          if await store.setItemCompletion(selectedItem.source.id, done: done) {
            await loadSelectedItem()
          }
        }
      }
    } else if isOpeningItem {
      ProgressView("Opening Item")
    } else if selectedItemId != nil {
      ContentUnavailableView {
        Label("Item unavailable", systemImage: "exclamationmark.triangle")
      } actions: {
        Button("Try Again") { Task { await loadSelectedItem() } }
      }
    } else {
      ContentUnavailableView("Choose an Item", systemImage: "square.stack")
    }
  }

  private func loadSelectedItem() async {
    guard let identifier = selectedItemId else {
      selectedItem = nil
      isOpeningItem = false
      return
    }
    isOpeningItem = true
    selectedItem = nil
    let loaded = await store.readItem(identifier)
    guard !Task.isCancelled, selectedItemId == identifier else { return }
    selectedItem = loaded
    isOpeningItem = false
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
      List(selection: sidebarSelection) {
        #if os(macOS)
          Section("Planner") {
            NavigationLink(value: SavedPlannerSidebarSelection.lists) {
              Label("Lists", systemImage: "list.bullet")
            }
            .accessibilityIdentifier("saved.section.lists")
            NavigationLink(value: SavedPlannerSidebarSelection.items) {
              Label("Items", systemImage: "square.stack")
            }
            .accessibilityIdentifier("saved.section.items")
          }
        #endif
        Section("Lists") {
          ForEach(store.lists) { list in
            NavigationLink(value: SavedPlannerSidebarSelection.list(list.id)) {
              Label(list.name, systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier("saved.list.\(list.id.uuidString)")
          }
        }
      }
      .listStyle(.sidebar)
      .overlay {
        #if os(iOS)
          if store.lists.isEmpty {
            ContentUnavailableView(
              "No Lists yet", systemImage: "list.bullet.rectangle",
              description: Text("Create a List to start planning."))
          }
        #endif
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
      if isItemSection {
        itemCatalog
      } else if let selectedList {
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
        .toolbar {
          ToolbarItem {
            Button("Add existing Item", systemImage: "plus") { showAddItem = true }
              .disabled(!store.canCreate)
              .accessibilityIdentifier("saved.list.add")
          }
        }
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
      if isItemSection {
        itemDetail
      } else {
        ContentUnavailableView("Choose an Item", systemImage: "square.stack")
      }
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
