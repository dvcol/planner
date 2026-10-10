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
  @State private var listFilters = SavedItemFilters()
  @State private var isOpeningList = false
  @State private var showNewList = false
  @State private var showNewItem = false
  @State private var showAddItem = false
  @State private var selectedItemId: UUID?
  @State private var selectedItem: PlannerItemSourceRead?
  @State private var isOpeningItem = false
  @State private var catalogItems: [SavedPlannerItem]?
  @State private var itemFilters = SavedItemFilters(archive: .active)
  @State private var isOpeningCatalog = false
  @State private var selectedAppearanceIdentity: PlannerAppearance?
  @State private var selectedAppearance: PlannerAppearanceRead?
  @State private var appearanceChangeMessage: String?
  @State private var appearanceChangeTitle = "Item removed from List"
  @State private var membershipMoveDraft: SavedMembershipMoveDraft?
  @State private var listAdditionDraft: SavedListAdditionDraft?
  @State private var isOpeningAppearance = false
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
    .task(id: store.isReady) { await loadCatalogItems() }
    .task(id: itemFilters) { await loadCatalogItems() }
    .task(id: selectedListId) { await loadSelectedList() }
    .task(id: listFilters) { await loadSelectedList() }
    .task(id: selectedItemId) { await loadSelectedItem() }
    .task(id: selectedAppearanceIdentity) { await loadSelectedAppearance() }
    .task(id: store.changeRevision) {
      await loadSelectedList()
      await loadCatalogItems()
      await loadSelectedItem()
      await loadSelectedAppearance()
    }
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
        SavedAddItemForm(store: store, list: selectedList) {}
      }
    }
    .sheet(item: $membershipMoveDraft) { draft in
      SavedMoveItemForm(store: store, draft: draft) { destination in
        clearRemovedMembershipSelection(
          draft.membershipIdentifier, listIdentifier: draft.sourceListIdentifier,
          explanation: "The Item is now in \(destination.name).", detailTitle: "Item moved")
      }
    }
    .sheet(item: $listAdditionDraft) { draft in
      SavedAddToListForm(store: store, draft: draft)
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
          #if os(iOS)
            columnVisibility = .doubleColumn
          #endif
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

  @ViewBuilder
  private var itemCatalog: some View {
    if let catalogItems {
      SavedItemCatalog(
        items: catalogItems, selection: $selectedItemId, filters: $itemFilters,
        canCreate: store.canCreate
      ) { showNewItem = true }
      .overlay(alignment: .topTrailing) {
        if isOpeningCatalog { ProgressView("Updating Items").controlSize(.small).padding() }
      }
    } else if isOpeningCatalog {
      ProgressView("Opening Items")
    } else {
      ContentUnavailableView {
        Label("Items unavailable", systemImage: "exclamationmark.triangle")
      } actions: {
        Button("Try Again") { Task { await loadCatalogItems() } }
      }
    }
  }

  private func loadCatalogItems() async {
    guard store.isReady else { return }
    isOpeningCatalog = true
    let filters = itemFilters
    let revision = store.changeRevision
    let loaded = await store.readItems(
      completion: filters.completion.queryValue, archive: filters.archive.queryValue)
    guard !Task.isCancelled, itemFilters == filters, store.changeRevision == revision else {
      return
    }
    catalogItems = loaded
    isOpeningCatalog = false
  }

  @ViewBuilder
  private var itemDetail: some View {
    if let selectedItem {
      SavedItemDetail(
        item: selectedItem, canChange: store.canCreate, isSaving: store.isSaving,
        addToList: {
          listAdditionDraft = SavedListAdditionDraft(
            itemIdentifier: selectedItem.source.id, itemTitle: selectedItem.content.title)
        },
        setCompletion: { done in
          Task { _ = await store.setItemCompletion(selectedItem.source.id, done: done) }
        },
        setArchive: { archived in
          Task { _ = await store.setItemArchived(selectedItem.source.id, archived: archived) }
        })
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
    let revision = store.changeRevision
    if selectedItem?.source.id != identifier { selectedItem = nil }
    let loaded = await store.readItem(identifier)
    guard !Task.isCancelled, selectedItemId == identifier, store.changeRevision == revision else {
      return
    }
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
    let revision = store.changeRevision
    let filters = listFilters
    if selectedList?.source.id != identifier {
      selectedList = nil
      listItems = nil
    }
    let loaded = await store.readList(identifier)
    let loadedItems: [SavedPlannerItem]?
    if loaded != nil {
      loadedItems = await store.readListItems(
        identifier, completion: filters.completion.queryValue, archive: filters.archive.queryValue)
    } else {
      loadedItems = nil
    }
    guard !Task.isCancelled, selectedListId == identifier, store.changeRevision == revision,
      listFilters == filters
    else {
      return
    }
    selectedList = loaded
    listItems = loadedItems
    isOpeningList = false
  }

  private var membershipSelection: Binding<UUID?> {
    Binding(
      get: {
        guard case .listMembership(let listId, let membershipId) = selectedAppearanceIdentity,
          listId == selectedListId
        else { return nil }
        return membershipId
      },
      set: { identifier in
        guard let listId = selectedListId, let identifier else {
          selectedAppearanceIdentity = nil
          return
        }
        appearanceChangeMessage = nil
        selectedAppearanceIdentity = .listMembership(listId: listId, membershipId: identifier)
      })
  }

  private func loadSelectedAppearance() async {
    guard let identity = selectedAppearanceIdentity else {
      selectedAppearance = nil
      isOpeningAppearance = false
      return
    }
    isOpeningAppearance = true
    let revision = store.changeRevision
    if selectedAppearance?.appearance != identity { selectedAppearance = nil }
    let loaded = await store.readAppearance(identity)
    guard !Task.isCancelled, selectedAppearanceIdentity == identity,
      store.changeRevision == revision
    else { return }
    selectedAppearance = loaded
    isOpeningAppearance = false
  }

  @ViewBuilder
  private var appearanceDetail: some View {
    if let selectedAppearance, let selectedList {
      SavedAppearanceDetail(
        item: selectedAppearance, listName: selectedList.content.name, canChange: store.canCreate,
        addToList: {
          listAdditionDraft = SavedListAdditionDraft(
            itemIdentifier: selectedAppearance.source.id,
            itemTitle: selectedAppearance.content.title)
        },
        viewItem: {
          selectedItemId = selectedAppearance.source.id
          selectedSection = .items
        },
        moveToList: {
          guard
            case .listMembership(let listIdentifier, let membershipIdentifier) =
              selectedAppearance.appearance,
            listIdentifier == selectedList.source.id
          else { return }
          proposeMembershipMove(
            membershipIdentifier, itemTitle: selectedAppearance.content.title, list: selectedList)
        },
        removeFromList: {
          guard
            case .listMembership(let listIdentifier, let membershipIdentifier) =
              selectedAppearance.appearance
          else { return }
          removeMembership(membershipIdentifier, listIdentifier: listIdentifier)
        })
    } else if isOpeningAppearance {
      ProgressView("Opening Item")
    } else if selectedAppearanceIdentity != nil {
      ContentUnavailableView {
        Label("List entry unavailable", systemImage: "exclamationmark.triangle")
      } actions: {
        Button("Try Again") { Task { await loadSelectedAppearance() } }
      }
    } else {
      if appearanceChangeMessage != nil {
        ContentUnavailableView(
          appearanceChangeTitle, systemImage: "list.bullet.rectangle",
          description: Text("Choose another Item to see its details."))
      } else {
        ContentUnavailableView("Choose an Item", systemImage: "square.stack")
      }
    }
  }

  private func proposeListAddition(_ item: SavedPlannerItem) {
    guard case .appearance(let source, _) = item.row.identity, source.kind == .item else {
      return
    }
    listAdditionDraft = SavedListAdditionDraft(
      itemIdentifier: source.id, itemTitle: item.row.title)
  }

  private func removeMembership(_ membershipIdentifier: UUID, listIdentifier: UUID) {
    Task {
      guard await store.removeMembership(membershipIdentifier, listIdentifier: listIdentifier)
      else { return }
      clearRemovedMembershipSelection(
        membershipIdentifier, listIdentifier: listIdentifier,
        explanation: "The Item remains available in Items.", detailTitle: "Item removed from List")
    }
  }

  private func clearRemovedMembershipSelection(
    _ membershipIdentifier: UUID, listIdentifier: UUID, explanation: String, detailTitle: String
  ) {
    let removedAppearance = PlannerAppearance.listMembership(
      listId: listIdentifier, membershipId: membershipIdentifier)
    guard selectedAppearanceIdentity == removedAppearance else { return }
    selectedAppearanceIdentity = nil
    selectedAppearance = nil
    isOpeningAppearance = false
    appearanceChangeMessage = explanation
    appearanceChangeTitle = detailTitle
  }

  private func proposeMembershipMove(
    _ membershipIdentifier: UUID, itemTitle: String, list: PlannerListSourceRead
  ) {
    guard store.canCreate else { return }
    membershipMoveDraft = SavedMembershipMoveDraft(
      sourceListIdentifier: list.source.id, membershipIdentifier: membershipIdentifier,
      sourceListName: list.content.name, itemTitle: itemTitle)
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
              VStack(spacing: 0) {
                SavedListProgress(progress: selectedList.progress, matchingCount: 0).padding()
                ContentUnavailableView(
                  selectedList.progress.totalCount == 0 ? "No items" : "No matching items",
                  systemImage: "checklist",
                  description: appearanceChangeMessage.map { Text($0) })
              }
            } else {
              #if os(macOS)
                SavedMacMembershipTable(
                  store: store, list: selectedList, items: listItems,
                  selection: membershipSelection,
                  addToList: proposeListAddition,
                  moveMembership: { item in
                    proposeMembershipMove(item.id, itemTitle: item.row.title, list: selectedList)
                  },
                  removeMembership: { membershipIdentifier in
                    removeMembership(membershipIdentifier, listIdentifier: selectedList.source.id)
                  })
              #else
                List(selection: membershipSelection) {
                  Section {
                    ForEach(listItems) { item in
                      SavedMembershipRow(item: item, canChange: store.canCreate) {
                        guard case .appearance(_, let appearance) = item.row.identity else {
                          return
                        }
                        Task {
                          _ = await store.setAppearanceCompletion(
                            appearance, done: item.row.effectiveDone != true)
                        }
                      }
                      .contextMenu {
                        Button("Move to Beginning") {
                          Task {
                            _ = await store.reorderMembership(
                              item.id, listId: selectedList.source.id, placement: .first)
                          }
                        }
                        .disabled(!store.canCreate || listItems.first?.id == item.id)
                        Button("Move to End") {
                          Task {
                            _ = await store.reorderMembership(
                              item.id, listId: selectedList.source.id, placement: .last)
                          }
                        }
                        .disabled(!store.canCreate || listItems.last?.id == item.id)
                        Divider()
                        Button("Add to List") { proposeListAddition(item) }
                          .disabled(!store.canCreate)
                        Button("Move to List") {
                          proposeMembershipMove(
                            item.id, itemTitle: item.row.title, list: selectedList)
                        }
                        .disabled(!store.canCreate)
                        Button("Remove from List", role: .destructive) {
                          removeMembership(item.id, listIdentifier: selectedList.source.id)
                        }
                        .disabled(!store.canCreate)
                      }
                      .moveDisabled(!store.canCreate)
                    }
                    .onMove { offsets, destination in
                      moveMembership(
                        from: offsets, to: destination, in: listItems,
                        listId: selectedList.source.id)
                    }
                  } header: {
                    SavedListProgress(
                      progress: selectedList.progress, matchingCount: listItems.count
                    ).textCase(nil)
                  }
                }
              #endif
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
        .overlay(alignment: .topTrailing) {
          if isOpeningList { ProgressView("Updating List").controlSize(.small).padding() }
        }
        .toolbar {
          ToolbarItem {
            SavedItemFilterMenu(
              filters: $listFilters, accessibilityIdentifier: "saved.list.filters")
          }
          #if os(iOS)
            ToolbarItem {
              EditButton()
                .disabled(!store.canCreate || (listItems?.count ?? 0) < 2)
                .accessibilityIdentifier("saved.list.edit")
            }
          #endif
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
        appearanceDetail
      }
    }
    .navigationSplitViewStyle(.balanced)
    .onChange(of: selectedListId) { _, identifier in
      selectedAppearanceIdentity = nil
      selectedAppearance = nil
      appearanceChangeMessage = nil
      #if os(iOS)
        if identifier != nil { columnVisibility = .doubleColumn }
      #endif
    }
  }

  #if os(iOS)
    private func moveMembership(
      from offsets: IndexSet, to destination: Int, in items: [SavedPlannerItem], listId: UUID
    ) {
      guard store.canCreate else { return }
      guard offsets.count == 1, let source = offsets.first, items.indices.contains(source),
        (0...items.count).contains(destination)
      else {
        store.alertMessage = "Move one Item at a time."
        return
      }
      guard destination != source, destination != source + 1 else { return }
      let placement: PlannerPlacement
      if destination < source {
        placement = .before(associationId: items[destination].id)
      } else {
        placement = .after(associationId: items[destination - 1].id)
      }
      Task {
        _ = await store.reorderMembership(items[source].id, listId: listId, placement: placement)
      }
    }
  #endif
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
