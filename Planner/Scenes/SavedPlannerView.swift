import PlannerCore
import SwiftUI

private enum SavedPlannerSection: Hashable {
  case lists, items, inbox, itineraries, calendar
}

private enum SavedPlannerSidebarSelection: Hashable {
  case lists, items, inbox, itineraries, calendar
  case list(UUID)
}

struct SavedPlannerView: View {
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  private var categoryToolbarPlacement: ToolbarItemPlacement {
    #if os(macOS)
      return .automatic
    #else
      if horizontalSizeClass == .regular { return .bottomBar }
      return .automatic
    #endif
  }

  @Bindable var store: SavedPlannerStore
  @State private var selectedSection: SavedPlannerSection = .lists
  @State private var calendarSelection: SavedCalendarSelection?
  @State private var calendarInspectorPresented = false
  @State private var selectedItineraryIdentifier: UUID?
  @State private var selectedItineraryRow: SavedItineraryRowSelection?
  @State private var itineraryColumnVisibility: NavigationSplitViewVisibility = .all
  @State private var selectedListId: UUID?
  @State private var selectedList: PlannerListSourceRead?
  @State private var listItems: [SavedPlannerItem]?
  @State private var listFilters = SavedItemFilters()
  @State private var listSearchText = ""
  @State private var isOpeningList = false
  @State private var showNewList = false
  @State private var listEditDraft: SavedListEditDraft?
  @State private var showLabels = false
  @State private var showSettings = false
  @State private var showRecovery = false
  @State private var listCatalog: [SavedPlannerList]?
  @State private var listCatalogArchive = SavedItemFilters.Archive.active
  @State private var isOpeningListCatalog = false
  @State private var showNewItem = false
  @State private var captureEntryPoint: SavedCaptureEntryPoint?
  @State private var showAddItem = false
  @State private var bulkCompletionDraft: SavedBulkCompletionDraft?
  @State private var isPreparingBulkCompletion = false
  @State private var selectedItemId: UUID?
  @State private var selectedItem: PlannerItemSourceRead?
  @State private var isOpeningItem = false
  @State private var catalogItems: [SavedPlannerItem]?
  @State private var itemFilters = SavedItemFilters(archive: .active)
  @State private var itemSearchText = ""
  @State private var inboxFilters = SavedItemFilters(completion: .todo, archive: .active)
  @State private var inboxSearchText = ""
  @State private var isOpeningCatalog = false
  @State private var sortPreferences = SavedItemSortPreferences()
  @State private var selectedAppearanceIdentity: PlannerAppearance?
  @State private var selectedAppearance: PlannerAppearanceRead?
  @State private var appearanceChangeMessage: String?
  @State private var appearanceChangeTitle = "Item removed from List"
  @State private var membershipMoveDraft: SavedMembershipMoveDraft?
  @State private var listAdditionDraft: SavedListAdditionDraft?
  @State private var itemEditDraft: SavedItemEditDraft?
  @State private var itemDeletionDraft: SavedSourceDeletionDraft?
  @State private var isPreparingItemDeletion = false
  @State private var itemDeletionMessage: String?
  @State private var listDeletionDraft: SavedSourceDeletionDraft?
  @State private var isPreparingListDeletion = false
  @State private var listDeletionMessage: String?
  @State private var itineraryDeletionDraft: SavedSourceDeletionDraft?
  @State private var isPreparingItineraryDeletion = false
  @State private var itineraryDeletionMessage: String?
  @State private var isOpeningAppearance = false
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  #if os(iOS)
    @State private var listEditMode: EditMode = .inactive
  #endif

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
          Button("Recovery Copies", systemImage: "clock.arrow.circlepath") {
            showRecovery = true
          }
          .accessibilityIdentifier("saved.settings.recovery")
        }
      } else {
        ProgressView("Opening Planner")
      }
    }
    .task { await store.open() }
    .task(id: store.isReady) { await loadCatalogItems() }
    .task(id: store.isReady) { await loadListCatalog() }
    .task(id: listCatalogArchive) { await loadListCatalog() }
    .task(id: catalogScope) { await loadCatalogItems() }
    .task(id: catalogFilters.wrappedValue) { await loadCatalogItems() }
    .task(id: catalogSearchText.wrappedValue) { await loadCatalogItems() }
    .task(id: itemSort.wrappedValue) { await loadCatalogItems() }
    .task(id: store.devicePreferenceNamespace) {
      await loadListCatalog()
      await loadCatalogItems()
      await loadSelectedList()
    }
    .task(id: selectedListId) { await loadSelectedList() }
    .task(id: listFilters) { await loadSelectedList() }
    .task(id: listSearchText) { await loadSelectedList() }
    .task(id: listSort.wrappedValue) { await loadSelectedList() }
    #if os(iOS)
      .onChange(of: listSort.wrappedValue) {
        if listSort.wrappedValue.mode != .manual { listEditMode = .inactive }
      }
      .onChange(of: selectedListId) { listEditMode = .inactive }
    #endif
    .task(id: selectedItemId) { await loadSelectedItem() }
    .onChange(of: selectedItemId) {
      if selectedItemId != nil { itemDeletionMessage = nil }
    }
    .onChange(of: selectedItineraryIdentifier) {
      selectedItineraryRow = nil
      if selectedItineraryIdentifier != nil { itineraryDeletionMessage = nil }
    }
    .onChange(of: calendarSelection) {
      guard let selection = calendarSelection else {
        calendarInspectorPresented = false
        return
      }
      calendarInspectorPresented = true
      if selection.source.kind == .item {
        if selectedItemId != selection.source.id {
          selectedItem = nil
          isOpeningItem = true
          selectedItemId = selection.source.id
        }
      } else if selection.source.kind == .itinerary {
        selectedItineraryIdentifier = selection.source.id
      }
    }
    .onChange(of: store.devicePreferenceNamespace) { calendarSelection = nil }
    .task(id: selectedAppearanceIdentity) { await loadSelectedAppearance() }
    .task(id: store.changeRevision) {
      await loadListCatalog()
      await loadSelectedList()
      await loadCatalogItems()
      if itemDeletionDraft == nil { await loadSelectedItem() }
      if itemDeletionDraft == nil || itemDeletionDraft?.source.id != selectedAppearance?.source.id {
        await loadSelectedAppearance()
      }
    }
    .sheet(isPresented: $showLabels) {
      SavedLabelsView(store: store)
    }
    .sheet(isPresented: $showRecovery) { SavedRecoveryCopiesView(store: store) }
    #if os(iOS)
      .sheet(isPresented: $showSettings) { SavedPlannerSettingsView(store: store) }
    #endif
    .sheet(isPresented: $showNewList) {
      SavedListForm(store: store) { source in
        selectedSection = .lists
        selectedListId = source.id
      }
    }
    .sheet(item: $listEditDraft) { draft in
      SavedListForm(store: store, list: draft.list) { _ in }
    }
    .sheet(isPresented: $showNewItem) {
      SavedNewItemForm(store: store) { source in selectedItemId = source.id }
    }
    .sheet(item: $captureEntryPoint) { entryPoint in
      SavedCaptureForm(store: store, entryPoint: entryPoint) { source in
        if case .global = entryPoint { selectedItemId = source.id }
      }
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
    .sheet(item: $itemEditDraft) { draft in
      SavedEditItemForm(store: store, item: draft.item)
    }
    .sheet(item: $itemDeletionDraft, onDismiss: refreshAfterDeletionReview) { draft in
      SavedSourceDeletionForm(store: store, draft: draft) { review in
        clearDeletedItemSelection(draft, review: review)
      }
    }
    .sheet(item: $listDeletionDraft, onDismiss: refreshAfterDeletionReview) { draft in
      SavedSourceDeletionForm(store: store, draft: draft) { review in
        clearDeletedListSelection(draft, review: review)
      }
    }
    .sheet(item: $itineraryDeletionDraft, onDismiss: refreshAfterDeletionReview) { draft in
      SavedSourceDeletionForm(store: store, draft: draft) { _ in
        clearDeletedItinerarySelection(draft)
      }
    }
    .sheet(item: $bulkCompletionDraft) { draft in
      SavedBulkCompletionForm(store: store, draft: draft)
    }
    .alert(
      "Planner",
      isPresented: Binding(
        get: {
          store.alertMessage != nil && itemEditDraft == nil && itemDeletionDraft == nil
            && listDeletionDraft == nil && itineraryDeletionDraft == nil
            && bulkCompletionDraft == nil
            && !showLabels
            && !showSettings
            && captureEntryPoint == nil
            && (selectedSection != .itineraries || showNewList || showNewItem)
        },
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
  private var recoveryNotice: some View {
    if store.isReady && store.recoveryBlocked {
      HStack {
        Label(store.recoveryStatusTitle, systemImage: "exclamationmark.triangle")
          .font(.callout)
        Spacer()
        #if os(macOS)
          SettingsLink { Text("Recovery") }
            .accessibilityIdentifier("saved.recovery.status.open")
        #else
          Button("Recovery") { showSettings = true }
            .accessibilityIdentifier("saved.recovery.status.open")
        #endif
      }
      .padding(.horizontal).padding(.vertical, 8)
      .background(.bar)
    }
  }

  @ViewBuilder
  private var nativeLayout: some View {
    #if os(macOS)
      if selectedSection == .calendar {
        NavigationSplitView(columnVisibility: $columnVisibility) {
          plannerSidebar
        } detail: {
          wideCalendar
        }
        .navigationSplitViewStyle(.balanced)
      } else {
        plannerColumns
      }
    #else
      TabView(selection: $selectedSection) {
        Tab("Lists", systemImage: "list.bullet", value: .lists) { plannerColumns }
        Tab("Items", systemImage: "square.stack", value: .items) { catalogColumns }
        Tab("Inbox", systemImage: "tray", value: .inbox) { catalogColumns }
        Tab("Calendar", systemImage: "calendar", value: .calendar) {
          calendarColumns
        }
        Tab(
          "Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
          value: .itineraries
        ) {
          NavigationSplitView(columnVisibility: $itineraryColumnVisibility) {
            itineraryCatalog
          } content: {
            itineraryDetail
          } detail: {
            itineraryAppearanceDetail
          }
        }
      }
    #endif
  }

  private var catalogColumns: some View {
    NavigationSplitView {
      itemCatalog
    } detail: {
      itemDetail
    }
  }

  #if os(iOS)
    @ViewBuilder
    private var calendarColumns: some View {
      if horizontalSizeClass == .regular {
        wideCalendar
      } else {
        NavigationStack {
          SavedCalendarView(store: store, selection: $calendarSelection)
            .safeAreaInset(edge: .top) { recoveryNotice }
            .navigationDestination(item: $calendarSelection) { _ in calendarDetail }
        }
      }
    }
  #endif

  private var calendarInspectorSelection: Binding<SavedCalendarSelection?> {
    Binding(
      get: { calendarSelection },
      set: { selection in
        calendarSelection = selection
        calendarInspectorPresented = selection != nil
      })
  }

  private var wideCalendar: some View {
    NavigationStack {
      SavedCalendarView(store: store, selection: calendarInspectorSelection)
        .safeAreaInset(edge: .top) { recoveryNotice }
        .toolbar {
          if !calendarInspectorPresented {
            ToolbarItem(placement: .primaryAction) { calendarDetailsToggle }
          }
        }
    }
    .inspector(isPresented: $calendarInspectorPresented) { calendarInspector }
  }

  private var calendarDetailsToggle: some View {
    Button {
      calendarInspectorPresented.toggle()
    } label: {
      Label(
        calendarInspectorPresented ? "Hide Details" : "Show Details",
        systemImage: "sidebar.right")
    }
    .disabled(calendarSelection == nil)
    .help(calendarInspectorPresented ? "Hide Details" : "Show Details")
    .accessibilityIdentifier("saved.calendar.details.toggle")
  }

  private var calendarInspector: some View {
    calendarDetailStack
      .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
  }

  private var calendarDetailStack: some View {
    NavigationStack {
      calendarDetail
        .toolbar {
          if calendarInspectorPresented {
            ToolbarItem(placement: .primaryAction) { calendarDetailsToggle }
          }
        }
    }
    .id(calendarSelection)
  }

  @ViewBuilder
  private var calendarDetail: some View {
    if let selection = calendarSelection {
      if selection.source.kind == .item {
        if selectedItemId == selection.source.id,
          selectedItem == nil || selectedItem?.source == selection.source
        {
          itemDetail
        } else {
          ProgressView("Opening Item")
        }
      } else if selection.source.kind == .itinerary {
        itineraryDetail(identifier: selection.source.id)
          .navigationDestination(item: $selectedItineraryRow) { row in
            SavedItineraryItemDetail(
              appearance: row.appearance(itineraryId: selection.source.id),
              isReviewingDeletion: itineraryDeletionDraft?.source.id == selection.source.id
            )
            .id(row)
          }
      }
    } else {
      ContentUnavailableView("Choose a schedule", systemImage: "calendar")
    }
  }

  private var sidebarSelection: Binding<SavedPlannerSidebarSelection?> {
    Binding(
      get: {
        #if os(macOS)
          if selectedSection == .items { return .items }
          if selectedSection == .inbox { return .inbox }
          if selectedSection == .itineraries { return .itineraries }
          if selectedSection == .calendar { return .calendar }
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
        case .inbox: selectedSection = .inbox
        case .itineraries: selectedSection = .itineraries
        case .calendar: selectedSection = .calendar
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

  private var itineraryCatalog: some View {
    SavedItineraryCatalog(
      store: store,
      selection: Binding(
        get: { selectedItineraryIdentifier },
        set: { identifier in
          selectedItineraryIdentifier = identifier
          #if os(iOS)
            if identifier != nil { itineraryColumnVisibility = .doubleColumn }
          #endif
        })
    )
    .safeAreaInset(edge: .top) { recoveryNotice }
  }

  @ViewBuilder
  private var itineraryDetail: some View {
    if let selectedItineraryIdentifier {
      itineraryDetail(identifier: selectedItineraryIdentifier)
    } else if let itineraryDeletionMessage {
      ContentUnavailableView(
        "Itinerary deleted", systemImage: "trash", description: Text(itineraryDeletionMessage))
    } else {
      ContentUnavailableView(
        "Choose an Itinerary", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
    }
  }

  private func itineraryDetail(identifier: UUID) -> some View {
    SavedItineraryDetail(
      store: store, identifier: identifier, selection: $selectedItineraryRow,
      isPreparingDeletion: isPreparingItineraryDeletion,
      isReviewingDeletion: itineraryDeletionDraft?.source.id == identifier,
      prepareDeletion: { itinerary in Task { await prepareItineraryDeletion(itinerary) } }
    )
    .id(identifier)
  }

  @ViewBuilder
  private var itineraryAppearanceDetail: some View {
    if let selectedItineraryIdentifier, let selectedItineraryRow {
      SavedItineraryItemDetail(
        appearance: selectedItineraryRow.appearance(itineraryId: selectedItineraryIdentifier),
        isReviewingDeletion: itineraryDeletionDraft?.source.id == selectedItineraryIdentifier
      )
      .id(selectedItineraryRow)
    } else {
      ContentUnavailableView("Choose an Item", systemImage: "square.stack")
    }
  }

  private var isItemSection: Bool {
    #if os(macOS)
      selectedSection == .items || selectedSection == .inbox
    #else
      false
    #endif
  }

  private var usesItineraryColumns: Bool {
    #if os(macOS)
      selectedSection == .itineraries
    #else
      false
    #endif
  }

  private func loadListCatalog() async {
    guard store.isReady else { return }
    isOpeningListCatalog = true
    let archive = listCatalogArchive
    let revision = store.changeRevision
    let namespace = store.devicePreferenceNamespace
    let loaded = await store.readLists(archive: archive.queryValue)
    guard !Task.isCancelled, listCatalogArchive == archive, store.changeRevision == revision,
      store.devicePreferenceNamespace == namespace
    else { return }
    listCatalog = loaded
    isOpeningListCatalog = false
  }

  @ViewBuilder
  private var itemCatalog: some View {
    if let catalogItems {
      SavedItemCatalog(
        scope: catalogScope, items: catalogItems, selection: $selectedItemId,
        filters: catalogFilters, searchText: catalogSearchText, sort: itemSort,
        canCreate: store.canCreate, create: { showNewItem = true },
        capture: { captureEntryPoint = .global }
      )
      .overlay(alignment: .topTrailing) {
        if isOpeningCatalog { ProgressView("Updating Items").controlSize(.small).padding() }
      }
      .safeAreaInset(edge: .top) { recoveryNotice }
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
    let scope = catalogScope
    let filters = catalogFilters.wrappedValue
    let searchText = catalogSearchText.wrappedValue
    let revision = store.changeRevision
    let namespace = store.devicePreferenceNamespace
    let sort = itemSort.wrappedValue
    let loaded = await store.readItems(
      scope: scope.queryValue, text: searchText, completion: filters.completion.queryValue,
      archive: filters.archive.queryValue, categories: filters.categoryQuery,
      tags: filters.tagQuery, lists: filters.listQuery,
      hasAddress: filters.hasAddress, hasLinks: filters.hasLinks, scheduled: filters.scheduled,
      sort: sort.queryValue)
    guard !Task.isCancelled, catalogScope == scope, catalogFilters.wrappedValue == filters,
      catalogSearchText.wrappedValue == searchText,
      store.changeRevision == revision, store.devicePreferenceNamespace == namespace,
      itemSort.wrappedValue == sort
    else {
      return
    }
    catalogItems = loaded
    isOpeningCatalog = false
  }

  private var catalogScope: SavedItemCatalogScope {
    selectedSection == .inbox ? .inbox : .items
  }

  private var catalogFilters: Binding<SavedItemFilters> {
    catalogScope == .inbox ? $inboxFilters : $itemFilters
  }

  private var catalogSearchText: Binding<String> {
    catalogScope == .inbox ? $inboxSearchText : $itemSearchText
  }

  private var itemSort: Binding<SavedItemSort> {
    let key = store.devicePreferenceNamespace.map { "planner.sort.\($0).\(catalogScope.rawValue)" }
    return Binding(
      get: { sortPreferences.selection(for: key, default: SavedItemSort()) },
      set: { sortPreferences.select($0, for: key) })
  }

  private var listSort: Binding<SavedItemSort> {
    let key: String?
    if let namespace = store.devicePreferenceNamespace, let identifier = selectedListId {
      key = "planner.sort.\(namespace).list.\(identifier.uuidString)"
    } else {
      key = nil
    }
    return Binding(
      get: { sortPreferences.selection(for: key, default: SavedItemSort(mode: .manual)) },
      set: { sortPreferences.select($0, for: key) })
  }

  private var canReorderMemberships: Bool {
    store.canCreate && selectedListId != nil && listSort.wrappedValue.mode == .manual
  }

  @ViewBuilder
  private var itemDetail: some View {
    if let selectedItem {
      SavedItemDetail(
        item: selectedItem, canChange: store.canCreate && !isPreparingItemDeletion,
        isSaving: store.isSaving,
        addToList: {
          listAdditionDraft = SavedListAdditionDraft(
            itemIdentifier: selectedItem.source.id, itemTitle: selectedItem.content.title)
        },
        editItem: { itemEditDraft = SavedItemEditDraft(item: selectedItem) },
        deleteItem: { Task { await prepareItemDeletion(selectedItem) } },
        setCompletion: { done in
          Task { _ = await store.setItemCompletion(selectedItem.source.id, done: done) }
        },
        setArchive: { archived in
          Task { _ = await store.setItemArchived(selectedItem.source.id, archived: archived) }
        }
      )
      .overlay {
        if isPreparingItemDeletion { ProgressView("Reviewing deletion") }
      }
    } else if isOpeningItem {
      ProgressView("Opening Item")
    } else if selectedItemId != nil {
      ContentUnavailableView {
        Label("Item unavailable", systemImage: "exclamationmark.triangle")
      } actions: {
        Button("Try Again") { Task { await loadSelectedItem() } }
      }
    } else if let itemDeletionMessage {
      ContentUnavailableView(
        "Item deleted", systemImage: "trash", description: Text(itemDeletionMessage))
    } else {
      ContentUnavailableView("Choose an Item", systemImage: "square.stack")
    }
  }

  private func prepareItemDeletion(_ item: PlannerItemSourceRead) async {
    guard !isPreparingItemDeletion else { return }
    isPreparingItemDeletion = true
    defer { isPreparingItemDeletion = false }
    if let review = await store.prepareSourceDeletion(item.source) {
      itemDeletionDraft = .init(source: item.source, name: item.content.title, review: review)
    }
  }

  private func clearDeletedItemSelection(_ draft: SavedSourceDeletionDraft, review: PlannerReview) {
    if calendarSelection?.source == draft.source { calendarSelection = nil }
    if selectedItemId == draft.source.id {
      selectedItemId = nil
      selectedItem = nil
      isOpeningItem = false
      itemDeletionMessage = "\(draft.name) and its references were removed."
    }
    let removedMembershipIdentifiers = Set(
      review.impact.referenceRemovals.compactMap { reference -> UUID? in
        if case .membership(let identifier, _, _) = reference { return identifier }
        return nil
      })
    var membershipSelectionRemoved = false
    if case .listMembership(_, let identifier) = selectedAppearanceIdentity {
      membershipSelectionRemoved = removedMembershipIdentifiers.contains(identifier)
    }
    if membershipSelectionRemoved || selectedAppearance?.source == draft.source {
      selectedAppearanceIdentity = nil
      selectedAppearance = nil
      isOpeningAppearance = false
      appearanceChangeTitle = "Item deleted"
      appearanceChangeMessage = itemDeletionMessage
    }
    guard let selectedItineraryRow else { return }
    let selectedWasRemoved = review.impact.referenceRemovals.contains { reference in
      switch (selectedItineraryRow, reference) {
      case (.direct(let entryId), .itineraryEntry(let removedId, _, _)):
        return entryId == removedId
      case (.expanded(_, let membershipId), .membership(let removedId, _, _)):
        return membershipId == removedId
      default: return false
      }
    }
    if selectedWasRemoved { self.selectedItineraryRow = nil }
  }

  private func refreshAfterDeletionReview() {
    Task {
      await loadSelectedList()
      await loadSelectedItem()
      await loadSelectedAppearance()
    }
  }

  private func prepareListDeletion(_ list: PlannerListSourceRead) async {
    guard !isPreparingListDeletion else { return }
    isPreparingListDeletion = true
    defer { isPreparingListDeletion = false }
    if let review = await store.prepareSourceDeletion(list.source) {
      listDeletionDraft = .init(source: list.source, name: list.content.name, review: review)
    }
  }

  private func prepareItineraryDeletion(_ itinerary: PlannerItinerarySourceRead) async {
    guard !isPreparingItineraryDeletion else { return }
    isPreparingItineraryDeletion = true
    defer { isPreparingItineraryDeletion = false }
    if let review = await store.prepareSourceDeletion(itinerary.source) {
      itineraryDeletionDraft = .init(
        source: itinerary.source, name: itinerary.content.title, review: review)
    }
  }

  private func clearDeletedItinerarySelection(_ draft: SavedSourceDeletionDraft) {
    if calendarSelection?.source == draft.source { calendarSelection = nil }
    guard selectedItineraryIdentifier == draft.source.id else { return }
    selectedItineraryIdentifier = nil
    selectedItineraryRow = nil
    itineraryDeletionMessage = "\(draft.name) was deleted. Its Items and Lists remain available."
  }

  private func clearDeletedListSelection(_ draft: SavedSourceDeletionDraft, review: PlannerReview) {
    if selectedListId == draft.source.id {
      selectedListId = nil
      selectedList = nil
      listItems = nil
      isOpeningList = false
      selectedAppearanceIdentity = nil
      selectedAppearance = nil
      isOpeningAppearance = false
      listDeletionMessage = "\(draft.name) was deleted. Its Items remain available."
    }
    guard let selectedItineraryRow else { return }
    let selectedWasRemoved = review.impact.referenceRemovals.contains { reference in
      switch (selectedItineraryRow, reference) {
      case (.direct(let entryIdentifier), .itineraryEntry(let removedIdentifier, _, _)):
        return entryIdentifier == removedIdentifier
      case (.expanded(let entryIdentifier, _), .itineraryEntry(let removedIdentifier, _, _)):
        return entryIdentifier == removedIdentifier
      case (.expanded(_, let membershipIdentifier), .membership(let removedIdentifier, _, _)):
        return membershipIdentifier == removedIdentifier
      default: return false
      }
    }
    if selectedWasRemoved { self.selectedItineraryRow = nil }
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
    if listDeletionDraft?.source.id == identifier { return }
    isOpeningList = true
    let revision = store.changeRevision
    let filters = listFilters
    let searchText = listSearchText
    let namespace = store.devicePreferenceNamespace
    let sort = listSort.wrappedValue
    if selectedList?.source.id != identifier {
      selectedList = nil
      listItems = nil
    }
    let loaded = await store.readList(identifier)
    let loadedItems: [SavedPlannerItem]?
    if loaded != nil {
      loadedItems = await store.readListItems(
        identifier, text: searchText, completion: filters.completion.queryValue,
        archive: filters.archive.queryValue, categories: filters.categoryQuery,
        tags: filters.tagQuery, lists: filters.listQuery,
        hasAddress: filters.hasAddress, hasLinks: filters.hasLinks, scheduled: filters.scheduled,
        sort: sort.queryValue)
    } else {
      loadedItems = nil
    }
    guard !Task.isCancelled, selectedListId == identifier, store.changeRevision == revision,
      listFilters == filters, listSearchText == searchText,
      store.devicePreferenceNamespace == namespace, listSort.wrappedValue == sort
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
    if case .listMembership(let listIdentifier, _) = identity,
      listDeletionDraft?.source.id == listIdentifier
    {
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
      if let listDeletionMessage {
        ContentUnavailableView(
          "List deleted", systemImage: "trash", description: Text(listDeletionMessage))
      } else if appearanceChangeMessage != nil {
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

  private var plannerSidebar: some View {
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
          NavigationLink(value: SavedPlannerSidebarSelection.inbox) {
            Label("Inbox", systemImage: "tray")
          }
          .accessibilityIdentifier("saved.section.inbox")
          NavigationLink(value: SavedPlannerSidebarSelection.itineraries) {
            Label(
              "Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
          }
          .accessibilityIdentifier("saved.section.itineraries")
          NavigationLink(value: SavedPlannerSidebarSelection.calendar) {
            Label("Calendar", systemImage: "calendar")
          }
          .accessibilityIdentifier("saved.section.calendar")
        }
      #endif
      Section("Lists") {
        ForEach(listCatalog ?? []) { list in
          NavigationLink(value: SavedPlannerSidebarSelection.list(list.id)) {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Label(list.name, systemImage: "list.bullet.rectangle")
                if list.archived {
                  Image(systemName: "archivebox").foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }
              }
              SavedContainerEstimatePreview(
                estimates: list.estimates, manualEstimate: list.manualEstimate)
            }
          }
          .accessibilityLabel(list.name)
          .accessibilityValue(
            (list.archived ? "Archived. " : "Active. ")
              + list.estimates.nativeEstimatePreviewAccessibilityDescription(
                manualEstimate: list.manualEstimate)
          )
          .accessibilityIdentifier("saved.list.\(list.id.uuidString)")
          .contextMenu {
            Button(list.archived ? "Unarchive List" : "Archive List", systemImage: "archivebox") {
              Task { _ = await store.setListArchived(list.id, archived: !list.archived) }
            }
            .disabled(!store.canCreate)
          }
        }
      }
    }
    .listStyle(.sidebar)
    .overlay {
      #if os(iOS)
        if listCatalog?.isEmpty == true {
          ContentUnavailableView(
            listCatalogArchive == .active ? "No Lists yet" : "No matching Lists",
            systemImage: "list.bullet.rectangle",
            description: Text("Change the archive filter or create a List to start planning."))
        }
      #endif
      if isOpeningListCatalog {
        ProgressView("Updating Lists")
      } else if listCatalog == nil {
        ContentUnavailableView {
          Label("Lists unavailable", systemImage: "exclamationmark.triangle")
        } actions: {
          Button("Try Again") { Task { await loadListCatalog() } }
        }
      }
    }
    .safeAreaInset(edge: .top) {
      if selectedSection == .lists { recoveryNotice }
    }
    .navigationTitle("Planner")
    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    .toolbar {
      ToolbarItem(placement: categoryToolbarPlacement) {
        Button("Manage Labels", systemImage: "square.grid.2x2") { showLabels = true }
          .disabled(!store.isReady)
          .accessibilityIdentifier("saved.categories.manage")
      }
      #if os(iOS)
        ToolbarItem(placement: categoryToolbarPlacement) {
          Button("Settings", systemImage: "gearshape") { showSettings = true }
            .disabled(!store.isReady)
            .accessibilityIdentifier("saved.settings.open")
        }
      #endif
      ToolbarItem {
        SavedCatalogArchiveFilterMenu(
          archive: $listCatalogArchive, pluralTitle: "Lists",
          accessibilityIdentifier: "saved.lists.archive")
      }
      ToolbarItem {
        Button("New List", systemImage: "plus") { showNewList = true }
          .disabled(!store.canCreate)
          .accessibilityIdentifier("saved.list.new")
      }
    }
  }

  private var plannerColumns: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      plannerSidebar
    } content: {
      if usesItineraryColumns {
        if selectedItineraryIdentifier != nil {
          itineraryDetail
            .toolbar {
              ToolbarItem(placement: .navigation) {
                Button("Itineraries", systemImage: "chevron.backward") {
                  selectedItineraryIdentifier = nil
                }
              }
            }
        } else {
          itineraryCatalog
        }
      } else if isItemSection {
        itemCatalog
      } else if let selectedList {
        Group {
          if let listItems {
            if listItems.isEmpty {
              VStack(spacing: 0) {
                SavedListProgress(
                  progress: selectedList.progress, estimates: selectedList.estimates,
                  manualEstimate: selectedList.content.manualEstimate, matchingCount: 0,
                  isArchived: selectedList.state.archived == true
                ).padding()
                ContentUnavailableView(
                  selectedList.progress.totalCount == 0 ? "No items" : "No matching items",
                  systemImage: "checklist",
                  description: appearanceChangeMessage.map { Text($0) })
              }
            } else {
              #if os(macOS)
                SavedMacMembershipTable(
                  store: store, list: selectedList, items: listItems,
                  selection: membershipSelection, canReorderMemberships: canReorderMemberships,
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
                        .disabled(!canReorderMemberships || listItems.first?.id == item.id)
                        Button("Move to End") {
                          Task {
                            _ = await store.reorderMembership(
                              item.id, listId: selectedList.source.id, placement: .last)
                          }
                        }
                        .disabled(!canReorderMemberships || listItems.last?.id == item.id)
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
                      .moveDisabled(!canReorderMemberships)
                    }
                    .onMove { offsets, destination in
                      moveMembership(
                        from: offsets, to: destination, in: listItems,
                        listId: selectedList.source.id)
                    }
                  } header: {
                    SavedListProgress(
                      progress: selectedList.progress, estimates: selectedList.estimates,
                      manualEstimate: selectedList.content.manualEstimate,
                      matchingCount: listItems.count,
                      isArchived: selectedList.state.archived == true
                    ).textCase(nil)
                  }
                }
                .environment(\.editMode, $listEditMode)
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
        .searchable(text: $listSearchText, prompt: "Search this List")
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .overlay(alignment: .topTrailing) {
          if isOpeningList { ProgressView("Updating List").controlSize(.small).padding() }
          if isPreparingBulkCompletion {
            ProgressView("Preparing review").controlSize(.small).padding()
          }
          if isPreparingListDeletion {
            ProgressView("Reviewing deletion").controlSize(.small).padding()
          }
        }
        .toolbar {
          ToolbarItem {
            SavedItemFilterControl(
              filters: $listFilters, accessibilityIdentifier: "saved.list.filters")
          }
          ToolbarItem {
            SavedItemSortMenu(
              sort: listSort, allowsManual: true, accessibilityIdentifier: "saved.list.sort")
          }
          #if os(iOS)
            ToolbarItem {
              EditButton()
                .environment(\.editMode, $listEditMode)
                .disabled(!canReorderMemberships || (listItems?.count ?? 0) < 2)
                .accessibilityIdentifier("saved.list.edit")
            }
          #endif
          ToolbarItem {
            Button("Add existing Item", systemImage: "plus") { showAddItem = true }
              .disabled(!store.canCreate)
              .accessibilityIdentifier("saved.list.add")
          }
          ToolbarItem(placement: .primaryAction) {
            Menu {
              Button("Capture Text or Link", systemImage: "text.badge.plus") {
                captureEntryPoint = .list(selectedList.source.id)
              }
              .disabled(selectedList.state.archived == true)
              .accessibilityIdentifier("saved.list.capture")
              Divider()
              Button("Edit estimate", systemImage: "clock") {
                listEditDraft = .init(list: selectedList)
              }
              .accessibilityIdentifier("saved.list.estimate.edit")
              Divider()
              Group {
                Button("Mark all Done") { prepareListBulkCompletion(selectedList, done: true) }
                Button("Mark all Undone") { prepareListBulkCompletion(selectedList, done: false) }
              }
              .disabled(selectedList.progress.totalCount == 0)
              Divider()
              Button("Delete List", role: .destructive) {
                Task { await prepareListDeletion(selectedList) }
              }
              .accessibilityIdentifier("saved.list.delete")
            } label: {
              Label("List actions", systemImage: "ellipsis")
            }
            .disabled(
              !store.canCreate || isPreparingBulkCompletion || isPreparingListDeletion
            )
            .help("List actions")
            .accessibilityIdentifier("saved.list.actions")
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
      } else if let listDeletionMessage {
        ContentUnavailableView(
          "List deleted", systemImage: "trash", description: Text(listDeletionMessage))
      } else if listCatalog?.isEmpty == true {
        ContentUnavailableView(
          listCatalogArchive == .active ? "No Lists yet" : "No matching Lists",
          systemImage: "list.bullet.rectangle",
          description: Text("Change the archive filter or create a List to start planning."))
      } else {
        ContentUnavailableView("Choose a List", systemImage: "list.bullet.rectangle")
      }
    } detail: {
      if usesItineraryColumns {
        itineraryAppearanceDetail
      } else if isItemSection {
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
      if identifier != nil { listDeletionMessage = nil }
      #if os(iOS)
        if identifier != nil { columnVisibility = .doubleColumn }
      #endif
    }
  }

  private func prepareListBulkCompletion(_ list: PlannerListSourceRead, done: Bool) {
    guard !isPreparingBulkCompletion else { return }
    isPreparingBulkCompletion = true
    Task {
      defer { isPreparingBulkCompletion = false }
      guard
        let review = await store.prepareBulkCompletion(
          scope: .list(listId: list.source.id), done: done),
        selectedListId == list.source.id
      else { return }
      bulkCompletionDraft = .init(containerName: list.content.name, review: review)
    }
  }

  #if os(iOS)
    private func moveMembership(
      from offsets: IndexSet, to destination: Int, in items: [SavedPlannerItem], listId: UUID
    ) {
      guard canReorderMemberships else { return }
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

private struct SavedListEditDraft: Identifiable {
  let list: PlannerListSourceRead
  var id: UUID { list.source.id }
}

private struct SavedListForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let list: PlannerListSourceRead?
  let didCreate: (PlannerEntityReference) -> Void
  @State private var name: String
  @State private var manualEstimate: PlannerEstimate?
  @State private var operationId = UUID()

  init(
    store: SavedPlannerStore, list: PlannerListSourceRead? = nil,
    didCreate: @escaping (PlannerEntityReference) -> Void
  ) {
    self.store = store
    self.list = list
    self.didCreate = didCreate
    _name = State(initialValue: list?.content.name ?? "")
    _manualEstimate = State(initialValue: list?.content.manualEstimate)
  }

  private var canSave: Bool {
    guard store.canCreate, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    guard let list else { return true }
    return name != list.content.name || manualEstimate != list.content.manualEstimate
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Name", text: $name)
          .accessibilityIdentifier("saved.list.name")
        SavedActivityEstimateEditor(
          estimate: $manualEstimate,
          accessibilityIdentifierPrefix: "saved.list.estimate", isContainerEstimate: true)
      }
      .disabled(store.isSaving)
      .formStyle(.grouped)
      .navigationTitle(list == nil ? "New List" : "Edit List")
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
              let source: PlannerEntityReference?
              if let list {
                let saved = await store.editList(
                  list, name: name, manualEstimate: manualEstimate, operationId: operationId)
                source = saved ? list.source : nil
              } else {
                source = await store.createList(
                  name: name, manualEstimate: manualEstimate, operationId: operationId)
              }
              guard let source, store.alertMessage == nil else { return }
              didCreate(source)
              dismiss()
            }
          }
          .disabled(!canSave)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.list.save")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Saving List") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    .alert(
      "Planner",
      isPresented: Binding(
        get: { store.alertMessage != nil }, set: { if !$0 { store.alertMessage = nil } })
    ) {
      Button("OK") { store.alertMessage = nil }
    } message: {
      Text(store.alertMessage ?? "")
    }
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 280)
    #endif
  }
}
