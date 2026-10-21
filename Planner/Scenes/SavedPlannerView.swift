import PlannerCore
import SwiftUI

#if os(iOS)
  import UIKit
#endif

private enum SavedPlannerSection: Hashable {
  case lists, items, inbox, itineraries, calendar
}

private enum SavedPlannerSidebarSelection: Hashable {
  case lists, items, inbox, itineraries, calendar
  case list(UUID)
}

private enum SavedDeletionReplacementContext: Equatable {
  case items(SavedItemCatalogScope)
  case lists
  case listItems(UUID)
}

private struct SavedDeletionReplacement {
  let namespace: String
  let context: SavedDeletionReplacementContext
  let selectionGeneration: UUID
}

private struct SavedListWindowInputs: Equatable {
  let listIdentifier: UUID?
  let namespace: String?
  let revision: UUID
  let filters: SavedItemFilters
  let searchText: String
  let sort: SavedItemSort
  let isActive: Bool
  let isReviewingDeletion: Bool
}

struct SavedPlannerView: View {
  @Environment(\.undoManager) private var undoManager
  @State private var associationUndo = SavedAssociationUndoHistory()
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  private var secondaryToolbarPlacement: ToolbarItemPlacement {
    #if os(macOS)
      return .automatic
    #else
      if horizontalSizeClass == .regular { return .bottomBar }
      return .automatic
    #endif
  }

  @Bindable var store: SavedPlannerStore
  let planOpening: SavedPlanOpeningCoordinator
  let windowIdentifier: UUID
  @State private var claimedOpeningIdentifier: UUID?
  @State private var isResolvingOpening = false
  @State private var openingNavigationTask: Task<Void, Never>?
  @State private var selectedSection: SavedPlannerSection = .lists
  @State private var calendarSelection: SavedCalendarSelection?
  @State private var calendarInspectorPresented = false
  @State private var selectedItineraryIdentifier: UUID?
  @State private var selectedItineraryRow: SavedItineraryRowSelection?
  @State private var itineraryCatalogArchive = SavedItemFilters.Archive.active
  @State private var itineraryPresentations: [UUID: SavedItineraryPresentation] = [:]
  @State private var itineraryColumnVisibility: NavigationSplitViewVisibility = .all
  @State private var selectedListId: UUID?
  @State private var retainedListSource: PlannerListSourceRead?
  @State private var listWindow: SavedItemWindow?
  @State private var listWindowNamespace: String?
  @State private var visibleMembershipIdentifiers: Set<UUID> = []
  @State private var listScrollAnchor: UUID?
  @State private var pendingListScrollAnchor: UUID?
  @State private var listFilters = SavedItemFilters()
  @State private var listSearchText = ""
  @State private var isOpeningList = false
  @State private var showNewList = false
  @State private var listEditDraft: SavedListEditDraft?
  @State private var showLabels = false
  @State private var showSettings = false
  @State private var showRecovery = false
  @State private var listCatalogWindow: SavedItemWindow?
  @State private var listCatalogArchive = SavedItemFilters.Archive.active
  @State private var isOpeningListCatalog = false
  @State private var newItemDraft: SavedNewItemDraft?
  @State private var isSavingNewItem = false
  @State private var showDraftNavigationReview = false
  @State private var pendingDraftNavigation: (() -> Void)?
  @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
  @State private var captureEntryPoint: SavedCaptureEntryPoint?
  @State private var showAddItem = false
  @State private var bulkCompletionDraft: SavedBulkCompletionDraft?
  @State private var isPreparingBulkCompletion = false
  @State private var selectionGeneration = UUID()
  @State private var deletionReplacement: SavedDeletionReplacement?
  @State private var selectedItemId: UUID?
  @State private var selectedItem: PlannerItemSourceRead?
  @State private var isOpeningItem = false
  @State private var itemFilters = SavedItemFilters(archive: .active)
  @State private var itemSearchText = ""
  @State private var inboxFilters = SavedItemFilters(completion: .todo, archive: .active)
  @State private var inboxSearchText = ""
  @State private var sortPreferences = SavedItemSortPreferences()
  @State private var catalogSortPreferences = SavedCatalogSortPreferences()
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

  private var listLifecycleContent: some View {
    Group {
      if store.isReady {
        nativeLayout
      } else if let reason = store.openingFailure {
        ContentUnavailableView {
          Label("Planner unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(reason)
        } actions: {
          Button("Try again") { Task { await store.open() } }
          Button("Recovery copies", systemImage: "clock.arrow.circlepath") {
            showRecovery = true
          }
          .accessibilityIdentifier("saved.settings.recovery")
        }
      } else {
        ProgressView("Opening Planner")
      }
    }
    .task { await store.open() }
    .task(id: store.isReady) { await loadListCatalog() }
    .task(id: listCatalogArchive) { await loadListCatalog() }
    .task(id: listCatalogSort.wrappedValue) { await loadListCatalog() }
    .task(id: store.devicePreferenceNamespace) { await loadListCatalog() }
    .task(id: listWindowInputs) { await loadSelectedList() }
    .task(id: visibleMembershipIdentifiers) {
      guard let window = listWindow, window.state == .ready else { return }
      #if os(iOS)
        guard pendingListScrollAnchor == nil else { return }
      #endif
      let indices = Set(
        listRows.filter { visibleMembershipIdentifiers.contains($0.id) }.map(\.index))
      guard !indices.isEmpty else { return }
      await window.requestRows(at: indices)
    }
    .onChange(of: listWindow?.state) { _, state in
      if state == .loading { pendingListScrollAnchor = listScrollAnchor }
    }
    .onDisappear {
      listWindow?.cancel()
      visibleMembershipIdentifiers = []
    }
    #if os(iOS)
      .onChange(of: listSort.wrappedValue) {
        if listSort.wrappedValue.mode != .manual { listEditMode = .inactive }
      }
      .onChange(of: selectedListId) { listEditMode = .inactive }
    #endif
  }

  var body: some View {
    ZStack { listLifecycleContent }
      .disabled(isResolvingOpening)
      .overlay { if isResolvingOpening { ProgressView("Opening plan") } }
      .task(id: planOpening.readyRequestIdentifier(for: windowIdentifier)) {
        await receivePlanOpening()
      }
      .onChange(of: isSavingNewItem) {
        if !isSavingNewItem { Task { await receivePlanOpening() } }
      }
      .onChange(of: claimedOpeningIdentifier) {
        if claimedOpeningIdentifier == nil { Task { await receivePlanOpening() } }
      }
      .onChange(of: pendingDraftNavigation == nil) {
        if pendingDraftNavigation == nil { Task { await receivePlanOpening() } }
      }
      .onChange(of: hasPresentedWorkflow) {
        if !hasPresentedWorkflow { Task { await receivePlanOpening() } }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if usesSidebarNavigation && associationUndo.presentsControl {
          SavedAssociationUndoControl(history: associationUndo, store: store)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
      }
      .onDisappear {
        openingNavigationTask?.cancel()
        associationUndo.clear()
      }
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
      .onChange(of: store.devicePreferenceNamespace) {
        associationUndo.clear()
        itineraryPresentations = [:]
        calendarSelection = nil
        recordSelectionChange()
      }
      .onReceive(store.sourceDeletions) { notice in
        receiveSourceDeletion(notice)
      }
      .task(id: selectedAppearanceIdentity) { await loadSelectedAppearance() }
      .task(id: store.changeRevision) {
        if itemDeletionDraft == nil { await loadSelectedItem() }
        await loadListCatalog()
        if itemDeletionDraft == nil || itemDeletionDraft?.source.id != selectedAppearance?.source.id
        {
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
        SavedMoveItemForm(store: store, draft: draft) { result, destinationName in
          associationUndo.record(result, name: "Move Item", store: store, manager: undoManager)
          clearRemovedMembershipSelection(
            draft.membershipIdentifier, listIdentifier: draft.sourceListIdentifier,
            explanation: "The Item is now in \(destinationName).", detailTitle: "Item moved")
        }
      }
      .sheet(item: $listAdditionDraft) { draft in
        SavedAddToListForm(store: store, draft: draft)
      }
      .sheet(item: $itemEditDraft) { draft in
        SavedEditItemForm(store: store, item: draft.item) { result in
          associationUndo.recordOwnedRemovals(result, store: store, manager: undoManager)
        }
      }
      .sheet(item: $itemDeletionDraft, onDismiss: refreshAfterDeletionReview) { draft in
        SavedSourceDeletionForm(store: store, draft: draft)
      }
      .sheet(item: $listDeletionDraft, onDismiss: refreshAfterDeletionReview) { draft in
        SavedSourceDeletionForm(store: store, draft: draft)
      }
      .sheet(item: $itineraryDeletionDraft, onDismiss: refreshAfterDeletionReview) { draft in
        SavedSourceDeletionForm(store: store, draft: draft)
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
              && newItemDraft == nil
              && captureEntryPoint == nil
              && (selectedSection != .itineraries || showNewList || newItemDraft != nil)
          },
          set: { if !$0 { store.alertMessage = nil } })
      ) {
        Button("OK") { store.alertMessage = nil }
      } message: {
        Text(store.alertMessage ?? "")
      }
      .confirmationDialog("Save changes to this Item?", isPresented: $showDraftNavigationReview) {
        Button("Save") { Task { await saveNewItem(continuingNavigation: true) } }
        Button("Discard", role: .destructive) { finishDraftNavigation() }
        #if os(macOS)
          Button("Keep editing", role: .cancel) { keepEditingDraft() }
        #else
          Button("Keep editing") { keepEditingDraft() }
        #endif
      } message: {
        Text("Save this Item, discard the draft, or keep editing before leaving.")
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

  private var usesSidebarNavigation: Bool {
    #if os(macOS)
      true
    #else
      horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    #endif
  }

  @ViewBuilder
  private var nativeLayout: some View {
    if usesSidebarNavigation {
      if selectedSection == .calendar {
        NavigationSplitView(columnVisibility: $columnVisibility) {
          plannerSidebar
        } detail: {
          calendarContent
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: $calendarInspectorPresented) { calendarInspector }
      } else {
        plannerColumns
      }
    } else {
      #if os(iOS)
        TabView(selection: sectionSelection) {
          Tab("Lists", systemImage: "list.bullet", value: .lists) { plannerColumns }
          Tab("Items", systemImage: "square.stack", value: .items) { catalogColumns(scope: .items) }
          Tab("Inbox", systemImage: "tray", value: .inbox) { catalogColumns(scope: .inbox) }
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
        .tabViewBottomAccessory(isEnabled: associationUndo.presentsControl) {
          SavedAssociationUndoControl(history: associationUndo, store: store)
            .padding(.horizontal)
        }
      #endif
    }
  }

  private func catalogColumns(scope: SavedItemCatalogScope) -> some View {
    NavigationSplitView(preferredCompactColumn: compactColumnSelection) {
      itemCatalog(scope: scope)
    } detail: {
      if let newItemDraft { newItemEditor(newItemDraft) } else { itemDetail }
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
    calendarContent
      .inspector(isPresented: $calendarInspectorPresented) { calendarInspector }
  }

  private var calendarContent: some View {
    NavigationStack {
      SavedCalendarView(store: store, selection: calendarInspectorSelection)
        .safeAreaInset(edge: .top) { recoveryNotice }
        .toolbar {
          if !calendarInspectorPresented {
            ToolbarItem(placement: .primaryAction) { calendarDetailsToggle }
          }
        }
    }
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
        if usesSidebarNavigation {
          if selectedSection == .items { return .items }
          if selectedSection == .inbox { return .inbox }
          if selectedSection == .itineraries { return .itineraries }
          if selectedSection == .calendar { return .calendar }
        }
        if let selectedListId { return .list(selectedListId) }
        return usesSidebarNavigation ? .lists : nil
      },
      set: { selection in
        guard selection != nil else { return }
        requestDraftNavigation {
          recordSelectionChange()
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
          #if os(iOS)
            if usesSidebarNavigation {
              if selection == .lists {
                columnVisibility = .all
              } else {
                columnVisibility = .doubleColumn
              }
            }
          #endif
        }
      })
  }

  private var itineraryCatalog: some View {
    SavedItineraryCatalog(
      store: store, archive: $itineraryCatalogArchive,
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
    let presentation = Binding(
      get: { itineraryPresentations[identifier] ?? SavedItineraryPresentation() },
      set: { itineraryPresentations[identifier] = $0 })
    return SavedItineraryDetail(
      store: store, identifier: identifier, selection: $selectedItineraryRow,
      searchText: presentation.searchText, filters: presentation.filters,
      collapsedEntries: presentation.collapsedEntries,
      isPreparingDeletion: isPreparingItineraryDeletion,
      isReviewingDeletion: itineraryDeletionDraft?.source.id == identifier,
      prepareDeletion: { itinerary in Task { await prepareItineraryDeletion(itinerary) } },
      recordRemoval: { result in
        associationUndo.record(
          result, name: "Remove from itinerary", store: store, manager: undoManager)
      },
      recordOwnedRemovals: { result in
        associationUndo.recordOwnedRemovals(result, store: store, manager: undoManager)
      }
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
    usesSidebarNavigation && (selectedSection == .items || selectedSection == .inbox)
  }

  private var usesItineraryColumns: Bool {
    usesSidebarNavigation && selectedSection == .itineraries
  }

  private func loadListCatalog() async {
    guard !Task.isCancelled else { return }
    guard store.isReady else {
      listCatalogWindow?.cancel()
      listCatalogWindow = nil
      isOpeningListCatalog = false
      return
    }
    isOpeningListCatalog = true
    let archive = listCatalogArchive
    let revision = store.changeRevision
    let namespace = store.devicePreferenceNamespace
    let sort = listCatalogSort.wrappedValue
    listCatalogWindow?.cancel()
    guard let namespace, let window = store.makeItemWindow() else {
      listCatalogWindow = nil
      isOpeningListCatalog = false
      return
    }
    listCatalogWindow = window
    await window.reload(
      catalogQuery: .init(sourceKind: .list, archive: archive.queryValue, sort: sort.queryValue),
      identity: .init(namespace: namespace, savedRevision: revision))
    guard !Task.isCancelled, listCatalogArchive == archive, store.changeRevision == revision,
      store.devicePreferenceNamespace == namespace, listCatalogSort.wrappedValue == sort,
      listCatalogWindow === window
    else { return }
    isOpeningListCatalog = false
    guard window.state == .ready, let replacement = deletionReplacement,
      replacement.namespace == namespace, replacement.context == .lists,
      replacement.selectionGeneration == selectionGeneration,
      selectedSection == .lists, selectedListId == nil
    else { return }
    deletionReplacement = nil
    guard usesAutomaticDeletionSelection else {
      preferredCompactColumn = .sidebar
      return
    }
    guard case .source(let firstList)? = window.rowIdentities.first else { return }
    deletionReplacement = .init(
      namespace: replacement.namespace, context: .listItems(firstList.id),
      selectionGeneration: replacement.selectionGeneration)
    selectedListId = firstList.id
  }

  private func itemCatalog(scope: SavedItemCatalogScope) -> some View {
    SavedItemCatalog(
      store: store, scope: scope, isActive: selectedSection == (scope == .inbox ? .inbox : .items),
      selection: itemSelection,
      filters: scope == .inbox ? $inboxFilters : $itemFilters,
      searchText: scope == .inbox ? $inboxSearchText : $itemSearchText,
      sort: itemSort(scope: scope),
      canCreate: store.canCreate, create: { beginNewItem(listIdentifier: nil) },
      capture: { captureEntryPoint = .global }, didLoad: replaceDeletedCatalogSelection
    )
    .safeAreaInset(edge: .top) { recoveryNotice }
  }

  private func replaceDeletedCatalogSelection(
    scope: SavedItemCatalogScope, identity: SavedItemWindowIdentity, firstIdentifier: UUID?
  ) {
    guard let replacement = deletionReplacement,
      replacement.namespace == identity.namespace, replacement.context == .items(scope),
      identity.namespace == store.devicePreferenceNamespace,
      identity.savedRevision == store.changeRevision,
      replacement.selectionGeneration == selectionGeneration,
      selectedSection == .items || selectedSection == .inbox,
      catalogScope == scope, selectedItemId == nil
    else { return }
    deletionReplacement = nil
    if usesAutomaticDeletionSelection {
      selectedItemId = firstIdentifier
    } else {
      preferredCompactColumn = .sidebar
    }
  }

  private var catalogScope: SavedItemCatalogScope {
    selectedSection == .inbox ? .inbox : .items
  }

  private var listCatalogSort: Binding<SavedCatalogSort> {
    let key = store.devicePreferenceNamespace.map { "planner.catalog-sort.\($0).lists" }
    return Binding(
      get: { catalogSortPreferences.selection(for: key) },
      set: { catalogSortPreferences.select($0, for: key) })
  }

  private func itemSort(scope: SavedItemCatalogScope) -> Binding<SavedItemSort> {
    let key = store.devicePreferenceNamespace.map { "planner.sort.\($0).\(scope.rawValue)" }
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
      && listWindow?.state == .ready
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
        Button("Try again") { Task { await loadSelectedItem() } }
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

  private func receiveSourceDeletion(_ notice: SavedSourceDeletionNotice) {
    guard notice.namespace == store.devicePreferenceNamespace else { return }
    let name: String
    switch notice.source.kind {
    case .item:
      if let selectedItem, selectedItem.source == notice.source {
        name = selectedItem.content.title
      } else if let selectedAppearance, selectedAppearance.source == notice.source {
        name = selectedAppearance.content.title
      } else {
        name = "Item"
      }
    case .list: name = selectedList?.content.name ?? "List"
    case .itinerary: name = itineraryDeletionDraft?.name ?? "Itinerary"
    default: return
    }
    let draft = SavedSourceDeletionDraft(
      source: notice.source, name: name, review: notice.review)
    switch notice.source.kind {
    case .item: clearDeletedItemSelection(draft, review: notice.review)
    case .list: clearDeletedListSelection(draft, review: notice.review)
    case .itinerary: clearDeletedItinerarySelection(draft)
    default: return
    }
    refreshAfterDeletionReview()
  }

  private func clearDeletedItemSelection(_ draft: SavedSourceDeletionDraft, review: PlannerReview) {
    if calendarSelection?.source == draft.source { calendarSelection = nil }
    if selectedItemId == draft.source.id {
      selectedItemId = nil
      selectedItem = nil
      isOpeningItem = false
      itemDeletionMessage = "\(draft.name) and its references were removed."
      if newItemDraft == nil, selectedSection == .items || selectedSection == .inbox {
        if usesAutomaticDeletionSelection, let namespace = store.devicePreferenceNamespace {
          deletionReplacement = .init(
            namespace: namespace, context: .items(catalogScope),
            selectionGeneration: selectionGeneration)
        } else {
          preferredCompactColumn = .sidebar
        }
      }
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
      let removedAppearance = selectedAppearanceIdentity
      selectedAppearanceIdentity = nil
      selectedAppearance = nil
      isOpeningAppearance = false
      appearanceChangeTitle = "Item deleted"
      appearanceChangeMessage = "\(draft.name) and its references were removed."
      if newItemDraft == nil, selectedSection == .lists,
        case .listMembership(let listIdentifier, _) = removedAppearance,
        selectedListId == listIdentifier
      {
        if usesAutomaticDeletionSelection, let namespace = store.devicePreferenceNamespace {
          deletionReplacement = .init(
            namespace: namespace, context: .listItems(listIdentifier),
            selectionGeneration: selectionGeneration)
        } else {
          preferredCompactColumn = .content
        }
      }
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
      await loadListCatalog()
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
    itineraryPresentations.removeValue(forKey: draft.source.id)
    if calendarSelection?.source == draft.source { calendarSelection = nil }
    guard selectedItineraryIdentifier == draft.source.id else { return }
    selectedItineraryIdentifier = nil
    selectedItineraryRow = nil
    itineraryDeletionMessage = "\(draft.name) was deleted. Its Items and Lists remain available."
  }

  private func clearDeletedListSelection(_ draft: SavedSourceDeletionDraft, review: PlannerReview) {
    if selectedListId == draft.source.id {
      selectedListId = nil
      retainedListSource = nil
      listWindow?.cancel()
      visibleMembershipIdentifiers = []
      listScrollAnchor = nil
      pendingListScrollAnchor = nil
      isOpeningList = false
      selectedAppearanceIdentity = nil
      selectedAppearance = nil
      isOpeningAppearance = false
      listDeletionMessage = "\(draft.name) was deleted. Its Items remain available."
      if newItemDraft == nil, selectedSection == .lists {
        if usesAutomaticDeletionSelection, let namespace = store.devicePreferenceNamespace {
          deletionReplacement = .init(
            namespace: namespace, context: .lists, selectionGeneration: selectionGeneration)
        } else {
          preferredCompactColumn = .sidebar
        }
      }
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

  private var listWindowInputs: SavedListWindowInputs {
    .init(
      listIdentifier: selectedListId, namespace: store.devicePreferenceNamespace,
      revision: store.changeRevision, filters: listFilters, searchText: listSearchText,
      sort: listSort.wrappedValue, isActive: store.isReady && selectedSection == .lists,
      isReviewingDeletion: selectedListId != nil && listDeletionDraft?.source.id == selectedListId)
  }

  /// Keep valid detail context during loading; ready metadata comes from the validated window.
  private var selectedList: PlannerListSourceRead? {
    guard let identifier = selectedListId,
      listWindowNamespace == store.devicePreferenceNamespace
    else { return nil }
    if let window = listWindow, window.state == .ready,
      let source = window.listSource, source.source.id == identifier
    {
      return source
    }
    guard retainedListSource?.source.id == identifier else { return nil }
    return retainedListSource
  }

  private var listRows: [SavedMembershipWindowRow] {
    guard let identifier = selectedListId, let window = listWindow, window.state == .ready,
      listWindowNamespace == store.devicePreferenceNamespace
    else { return [] }
    return window.rowIdentities.enumerated().compactMap { index, identity in
      guard case .appearance(let source, .listMembership(let owner, let membership)) = identity,
        source.kind == .item, owner == identifier
      else { return nil }
      return .init(id: membership, index: index, identity: identity)
    }
  }

  private func loadSelectedList() async {
    guard !Task.isCancelled else { return }
    let inputs = listWindowInputs
    guard inputs.isActive, let identifier = inputs.listIdentifier, let namespace = inputs.namespace
    else {
      listWindow?.cancel()
      visibleMembershipIdentifiers = []
      isOpeningList = false
      if inputs.listIdentifier == nil || listWindowNamespace != inputs.namespace {
        retainedListSource = nil
        listScrollAnchor = nil
        pendingListScrollAnchor = nil
      }
      return
    }
    if inputs.isReviewingDeletion {
      isOpeningList = false
      return
    }
    isOpeningList = true
    if listWindowNamespace != namespace || listWindow == nil {
      listWindow?.cancel()
      listWindow = store.makeItemWindow()
      listWindowNamespace = namespace
      retainedListSource = nil
    }
    if retainedListSource?.source.id != identifier {
      retainedListSource = nil
      listScrollAnchor = nil
      pendingListScrollAnchor = nil
    } else {
      pendingListScrollAnchor = listScrollAnchor
    }
    visibleMembershipIdentifiers = []
    guard let window = listWindow else {
      isOpeningList = false
      return
    }
    await window.reload(
      query: .init(
        scope: .list(identifier), text: inputs.searchText,
        completion: inputs.filters.completion.queryValue,
        archive: inputs.filters.archive.queryValue,
        categories: inputs.filters.categoryQuery, tags: inputs.filters.tagQuery,
        lists: inputs.filters.listQuery, duration: inputs.filters.durationQuery,
        hasAddress: inputs.filters.hasAddress,
        hasLinks: inputs.filters.hasLinks, scheduled: inputs.filters.scheduled,
        sort: inputs.sort.queryValue),
      identity: .init(namespace: namespace, savedRevision: inputs.revision))
    guard !Task.isCancelled, listWindowInputs == inputs, listWindow === window else { return }
    isOpeningList = false
    guard window.state == .ready, let source = window.listSource else { return }
    retainedListSource = source
    guard let replacement = deletionReplacement,
      replacement.namespace == namespace, replacement.context == .listItems(identifier),
      replacement.selectionGeneration == selectionGeneration,
      selectedSection == .lists, selectedAppearanceIdentity == nil
    else { return }
    deletionReplacement = nil
    guard usesAutomaticDeletionSelection else {
      preferredCompactColumn = .content
      return
    }
    guard case .appearance(_, let appearance) = window.rowIdentities.first else { return }
    selectedAppearanceIdentity = appearance
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
          if newItemDraft == nil, listWindow?.state == .ready { selectedAppearanceIdentity = nil }
          return
        }
        requestDraftNavigation {
          recordSelectionChange()
          appearanceChangeMessage = nil
          selectedAppearanceIdentity = .listMembership(listId: listId, membershipId: identifier)
          preferredCompactColumn = .detail
        }
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

  private func appearanceContent(
    _ selectedAppearance: PlannerAppearanceRead, list selectedList: PlannerListSourceRead
  ) -> SavedAppearanceDetail {
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
  }

  @ViewBuilder
  private var appearanceDetail: some View {
    if let selectedAppearance, let selectedList {
      appearanceContent(selectedAppearance, list: selectedList)
    } else if isOpeningAppearance {
      ProgressView("Opening Item")
    } else if selectedAppearanceIdentity != nil {
      ContentUnavailableView {
        Label("List entry unavailable", systemImage: "exclamationmark.triangle")
      } actions: {
        Button("Try again") { Task { await loadSelectedAppearance() } }
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
      let namespace = store.devicePreferenceNamespace
      guard
        let result = await store.removeMembership(
          membershipIdentifier, listIdentifier: listIdentifier),
        case .applied = result.outcome, store.devicePreferenceNamespace == namespace
      else { return }
      associationUndo.record(result, name: "Remove from list", store: store, manager: undoManager)
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
    preferredCompactColumn = .content
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
      if usesSidebarNavigation {
        Section {
          NavigationLink(value: SavedPlannerSidebarSelection.lists) {
            Label("Lists", systemImage: "list.bullet")
              .foregroundStyle(SavedRowForeground())
          }
          .accessibilityIdentifier("saved.section.lists")
          NavigationLink(value: SavedPlannerSidebarSelection.items) {
            Label("Items", systemImage: "square.stack")
              .foregroundStyle(SavedRowForeground())
          }
          .accessibilityIdentifier("saved.section.items")
          NavigationLink(value: SavedPlannerSidebarSelection.inbox) {
            Label("Inbox", systemImage: "tray")
              .foregroundStyle(SavedRowForeground())
          }
          .accessibilityIdentifier("saved.section.inbox")
          NavigationLink(value: SavedPlannerSidebarSelection.itineraries) {
            Label(
              "Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath"
            )
            .foregroundStyle(SavedRowForeground())
          }
          .accessibilityIdentifier("saved.section.itineraries")
          NavigationLink(value: SavedPlannerSidebarSelection.calendar) {
            Label("Calendar", systemImage: "calendar")
              .foregroundStyle(SavedRowForeground())
          }
          .accessibilityIdentifier("saved.section.calendar")
        }
      }
      Section("Lists") {
        if usesSidebarNavigation, listCatalogWindow?.state == .ready,
          listCatalogWindow?.matchingCount == 0
        {
          Text(listCatalogArchive == .active ? "No Lists yet" : "No matching Lists")
            .foregroundStyle(.secondary)
        }
        if let listCatalogWindow {
          SavedContainerWindowRows(
            window: listCatalogWindow, sourceKind: .list,
            selectionTag: { SavedPlannerSidebarSelection.list($0.id) }
          ) { row in
            if case .source(let source) = row.identity, let estimates = row.containerEstimates {
              let list = SavedPlannerList(
                source: source, name: row.title, archived: row.archived == true,
                manualEstimate: row.manualEstimate, estimates: estimates)
              NavigationLink(value: SavedPlannerSidebarSelection.list(list.id)) {
                VStack(alignment: .leading, spacing: 4) {
                  HStack {
                    Label(list.name, systemImage: "list.bullet.rectangle")
                      .foregroundStyle(SavedRowForeground())
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
                Button(list.archived ? "Unarchive list" : "Archive list", systemImage: "archivebox")
                {
                  Task { _ = await store.setListArchived(list.id, archived: !list.archived) }
                }
                .disabled(!store.canCreate)
              }
            }
          }
        }
      }
    }
    .listStyle(.sidebar)
    .accessibilityIdentifier("saved.lists.catalog")
    .overlay {
      #if os(iOS)
        if !usesSidebarNavigation, listCatalogWindow?.state == .ready,
          listCatalogWindow?.matchingCount == 0
        {
          ContentUnavailableView(
            listCatalogArchive == .active ? "No Lists yet" : "No matching Lists",
            systemImage: "list.bullet.rectangle",
            description: Text("Change the archive filter or create a List to start planning."))
        }
      #endif
      if isOpeningListCatalog || listCatalogWindow?.state == .loading {
        ProgressView("Updating Lists")
      } else if listCatalogWindow == nil || listCatalogWindow?.state != .ready {
        ContentUnavailableView {
          Label("Lists unavailable", systemImage: "exclamationmark.triangle")
        } actions: {
          Button("Try again") { Task { await loadListCatalog() } }
        }
      }
    }
    .safeAreaInset(edge: .top) {
      if selectedSection == .lists { recoveryNotice }
    }
    .navigationTitle("Planner")
    .toolbarTitleDisplayMode(.inline)
    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    .toolbar {
      ToolbarItem(placement: secondaryToolbarPlacement) {
        Button("Manage labels", systemImage: "square.grid.2x2") { showLabels = true }
          .labelStyle(.iconOnly)
          .help("Manage labels")
          .disabled(!store.isReady)
          .accessibilityIdentifier("saved.categories.manage")
      }
      #if os(iOS)
        ToolbarItem(placement: secondaryToolbarPlacement) {
          Button("Settings", systemImage: "gearshape") { showSettings = true }
            .labelStyle(.iconOnly)
            .help("Settings")
            .disabled(!store.isReady)
            .accessibilityIdentifier("saved.settings.open")
        }
      #endif
      ToolbarItem {
        SavedCatalogSortMenu(sort: listCatalogSort, accessibilityIdentifier: "saved.lists.sort")
      }
      ToolbarItem {
        SavedCatalogArchiveFilterMenu(
          archive: $listCatalogArchive, pluralTitle: "Lists",
          accessibilityIdentifier: "saved.lists.archive")
      }
      ToolbarItem(placement: .primaryAction) {
        Button("New list", systemImage: "plus") {
          requestDraftNavigation { showNewList = true }
        }
        .labelStyle(.iconOnly)
        .help("New list")
        .disabled(!store.canCreate)
        .accessibilityIdentifier("saved.list.new")
      }
    }
  }

  @ViewBuilder
  private func listContents(_ list: PlannerListSourceRead) -> some View {
    if let window = listWindow {
      switch window.state {
      case .ready:
        let rows = listRows
        if rows.isEmpty {
          ScrollView {
            VStack(spacing: 0) {
              #if os(iOS)
                SavedListProgress(
                  listName: list.content.name, progress: list.progress, estimates: list.estimates,
                  manualEstimate: list.content.manualEstimate, matchingCount: 0,
                  isArchived: list.state.archived == true
                ).padding()
              #endif
              ContentUnavailableView(
                list.progress.totalCount == 0 ? "No items" : "No matching items",
                systemImage: "checklist", description: appearanceChangeMessage.map { Text($0) })
            }
          }
        } else {
          #if os(macOS)
            SavedMacMembershipTable(
              store: store, list: list, window: window, rows: rows,
              selection: membershipSelection, canReorderMemberships: canReorderMemberships,
              visibilityChanged: setMembershipVisibility, retryMembership: retryMembership,
              addToList: proposeListAddition,
              moveMembership: { item in
                proposeMembershipMove(item.id, itemTitle: item.row.title, list: list)
              },
              removeMembership: { membership in
                removeMembership(membership, listIdentifier: list.source.id)
              })
          #else
            ScrollViewReader { proxy in
              List(selection: membershipSelection) {
                Section {
                  ForEach(rows) { row in
                    membershipRow(row, list: list, window: window)
                      .id(row.id)
                      .onScrollVisibilityChange { visible in
                        setMembershipVisibility(row.id, visible)
                      }
                  }
                  .onMove { offsets, destination in
                    moveMembership(from: offsets, to: destination, in: rows, listId: list.source.id)
                  }
                } header: {
                  SavedListProgress(
                    listName: list.content.name, progress: list.progress, estimates: list.estimates,
                    manualEstimate: list.content.manualEstimate, matchingCount: rows.count,
                    isArchived: list.state.archived == true
                  ).textCase(nil)
                }
              }
              .listStyle(.plain)
              .accessibilityIdentifier("saved.list.contents")
              .environment(\.editMode, $listEditMode)
              .task(id: pendingListScrollAnchor) {
                guard let anchor = pendingListScrollAnchor,
                  let row = rows.first(where: { $0.id == anchor })
                else {
                  pendingListScrollAnchor = nil
                  return
                }
                /** Resolve the anchor page before restoring variable-height native rows. */
                await window.requestRows(at: [row.index])
                guard !Task.isCancelled, pendingListScrollAnchor == anchor,
                  listWindow === window, window.state == .ready,
                  listRows.contains(where: { $0.id == anchor })
                else { return }
                proxy.scrollTo(anchor, anchor: .center)
                pendingListScrollAnchor = nil
              }
            }
          #endif
        }
      case .failed(let reason):
        ContentUnavailableView {
          Label("Items unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(reason)
        } actions: {
          Button("Try again") { Task { await loadSelectedList() } }
        }
      case .idle, .loading:
        ProgressView("Opening List")
      }
    } else {
      ProgressView("Opening List")
    }
  }

  private func retryMembership(_ row: SavedMembershipWindowRow) {
    guard let window = listWindow, window.state == .ready,
      let current = listRows.first(where: { $0.id == row.id })
    else { return }
    var indices = Set(
      listRows.filter { visibleMembershipIdentifiers.contains($0.id) }.map(\.index))
    indices.insert(current.index)
    Task { await window.requestRows(at: indices) }
  }

  private func setMembershipVisibility(_ identifier: UUID, _ visible: Bool) {
    if visible {
      visibleMembershipIdentifiers.insert(identifier)
    } else {
      visibleMembershipIdentifiers.remove(identifier)
    }
    #if os(iOS)
      guard pendingListScrollAnchor == nil else { return }
    #endif
    guard let first = listRows.first(where: { visibleMembershipIdentifiers.contains($0.id) })
    else { return }
    listScrollAnchor = first.id
  }

  #if os(iOS)
    @ViewBuilder
    private func membershipRow(
      _ row: SavedMembershipWindowRow, list: PlannerListSourceRead, window: SavedItemWindow
    ) -> some View {
      switch window.presentation(at: row.index) {
      case .loaded(let presentation) where presentation.row.identity == row.identity:
        let item = SavedPlannerItem(
          id: row.id, row: presentation.row, rowPresentation: presentation.rowPresentation)
        SavedMembershipRow(item: item, canChange: store.canCreate) {
          guard case .appearance(_, let appearance) = item.row.identity else { return }
          listScrollAnchor = item.id
          pendingListScrollAnchor = item.id
          Task {
            _ = await store.setAppearanceCompletion(
              appearance, done: item.row.effectiveDone != true)
          }
        }
        .contextMenu {
          Button("Move to beginning") {
            Task {
              _ = await store.reorderMembership(item.id, listId: list.source.id, placement: .first)
            }
          }
          .disabled(!canReorderMemberships || listRows.first?.id == item.id)
          Button("Move to end") {
            Task {
              _ = await store.reorderMembership(item.id, listId: list.source.id, placement: .last)
            }
          }
          .disabled(!canReorderMemberships || listRows.last?.id == item.id)
          Divider()
          Button("Add to list") { proposeListAddition(item) }.disabled(!store.canCreate)
          Button("Move to list") {
            proposeMembershipMove(item.id, itemTitle: item.row.title, list: list)
          }.disabled(!store.canCreate)
          Button("Remove from list", role: .destructive) {
            removeMembership(item.id, listIdentifier: list.source.id)
          }.disabled(!store.canCreate)
        }
        .moveDisabled(!canReorderMemberships)
      case .loading, .loaded:
        ProgressView("Loading Item").selectionDisabled().moveDisabled(true)
      case .failed(let reason):
        VStack(alignment: .leading) {
          Text(reason).foregroundStyle(.secondary)
          Button("Try again") { retryMembership(row) }
        }
        .selectionDisabled().moveDisabled(true)
      }
    }
  #endif

  private var plannerColumns: some View {
    NavigationSplitView(
      columnVisibility: $columnVisibility, preferredCompactColumn: compactColumnSelection
    ) {
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
                .accessibilityIdentifier("saved.itineraries.back")
              }
            }
        } else {
          itineraryCatalog
        }
      } else if isItemSection {
        itemCatalog(scope: catalogScope)
      } else if let selectedList {
        listContents(selectedList)
          .navigationTitle(selectedList.content.name)
          .toolbarTitleDisplayMode(.inline)
          #if os(macOS)
            .safeAreaInset(edge: .top, spacing: 0) {
              listPaneHeader(selectedList)
            }
            .toolbar {
              ToolbarItemGroup(placement: .primaryAction) {
                SavedItemFilterControl(
                  filters: $listFilters, accessibilityIdentifier: "saved.list.filters",
                  showsSummary: newItemDraft == nil)
                if newItemDraft == nil {
                  listSortMenu
                  listActionsMenu(selectedList)
                  listAddMenu(selectedList)
                  if let selectedAppearance {
                    appearanceContent(selectedAppearance, list: selectedList).actionsMenu
                  }
                } else {
                  Menu {
                    listSortMenu
                    listActionsMenu(selectedList)
                    listAddMenu(selectedList)
                  } label: {
                    Label("List options", systemImage: "ellipsis")
                  }
                  .labelStyle(.iconOnly)
                  .help("List options")
                  .accessibilityIdentifier("saved.list.options")
                }
              }
            }
          #endif
          .searchable(text: $listSearchText, prompt: "Search this List")
          .searchPresentationToolbarBehavior(.avoidHidingContent)
          .overlay(alignment: .topTrailing) {
            if isOpeningList || listWindow?.state == .loading {
              ProgressView("Updating List").controlSize(.small).padding()
            }
            if isPreparingBulkCompletion {
              ProgressView("Preparing review").controlSize(.small).padding()
            }
            if isPreparingListDeletion {
              ProgressView("Reviewing deletion").controlSize(.small).padding()
            }
          }
          #if os(iOS)
            .toolbar {
              ToolbarItem {
                SavedItemFilterControl(
                  filters: $listFilters, accessibilityIdentifier: "saved.list.filters")
              }
              if horizontalSizeClass == .compact {
                ToolbarOverflowMenu {
                  listSortMenu
                  listEditButton
                  listActionsMenu(selectedList)
                }
              } else {
                ToolbarItem { listSortMenu }
                ToolbarItem { listEditButton }
                ToolbarItem(placement: .primaryAction) { listActionsMenu(selectedList) }
              }
              ToolbarItem {
                listAddMenu(selectedList)
              }
            }
          #endif
      } else if isOpeningList {
        ProgressView("Opening List")
      } else if selectedListId != nil {
        ContentUnavailableView {
          Label("List unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          if listWindowNamespace == store.devicePreferenceNamespace,
            case .failed(let reason) = listWindow?.state
          {
            Text(reason)
          } else {
            Text("Planner could not open the selected List.")
          }
        } actions: {
          Button("Try again") { Task { await loadSelectedList() } }
        }
      } else if let listDeletionMessage {
        ContentUnavailableView(
          "List deleted", systemImage: "trash", description: Text(listDeletionMessage))
      } else if listCatalogWindow?.state == .ready, listCatalogWindow?.matchingCount == 0 {
        ContentUnavailableView(
          listCatalogArchive == .active ? "No Lists yet" : "No matching Lists",
          systemImage: "list.bullet.rectangle",
          description: Text("Change the archive filter or create a List to start planning.")
        )
        .accessibilityIdentifier("saved.lists.empty")
      } else {
        ContentUnavailableView("Choose a List", systemImage: "list.bullet.rectangle")
      }
    } detail: {
      if let newItemDraft {
        newItemEditor(newItemDraft)
      } else if usesItineraryColumns {
        itineraryAppearanceDetail
      } else if isItemSection {
        itemDetail
      } else {
        appearanceDetail
      }
    }
    .navigationSplitViewStyle(.balanced)
    .onChange(of: selectedListId) { _, identifier in
      appearanceChangeMessage = nil
      if identifier != nil { listDeletionMessage = nil }
      #if os(iOS)
        if identifier != nil { columnVisibility = .doubleColumn }
      #endif
      if case .listMembership(let listIdentifier, _) = selectedAppearanceIdentity,
        listIdentifier == identifier
      {
        return
      }
      selectedAppearanceIdentity = nil
      selectedAppearance = nil
    }
  }

  private var listSortMenu: some View {
    SavedItemSortMenu(
      sort: listSort, allowsManual: true, accessibilityIdentifier: "saved.list.sort")
  }

  private func listAddMenu(_ list: PlannerListSourceRead) -> some View {
    Menu {
      Button("New item", systemImage: "square.and.pencil") {
        beginNewItem(listIdentifier: list.source.id)
      }
      .accessibilityIdentifier("saved.list.createItem")
      Button("Add existing item", systemImage: "plus") {
        requestDraftNavigation { showAddItem = true }
      }
      .accessibilityIdentifier("saved.list.add")
      Button("From link or text", systemImage: "text.badge.plus") {
        requestDraftNavigation { captureEntryPoint = .list(list.source.id) }
      }
      .accessibilityIdentifier("saved.list.capture")
    } label: {
      Label("Add", systemImage: "plus")
    }
    .labelStyle(.iconOnly)
    .help("Add an item to this list")
    .disabled(!store.canCreate || list.state.archived == true || isSavingNewItem)
    .accessibilityIdentifier("saved.list.addMenu")
  }

  #if os(macOS)
    private func listPaneHeader(_ list: PlannerListSourceRead) -> some View {
      VStack(spacing: 0) {
        SavedListProgress(
          listName: list.content.name, progress: list.progress, estimates: list.estimates,
          manualEstimate: list.content.manualEstimate, matchingCount: listRows.count,
          isArchived: list.state.archived == true, showsTitle: false
        )
        .padding()
        Divider()
      }
      .background(.background)
    }
  #endif

  #if os(iOS)
    private var listEditButton: some View {
      EditButton()
        .environment(\.editMode, $listEditMode)
        .disabled(!canReorderMemberships || listRows.count < 2)
        .accessibilityIdentifier("saved.list.edit")
    }
  #endif

  private func listActionsMenu(_ list: PlannerListSourceRead) -> some View {
    Menu {
      Button("Edit list", systemImage: "square.and.pencil") {
        listEditDraft = .init(list: list)
      }
      .accessibilityIdentifier("saved.list.estimate.edit")
      Divider()
      Group {
        Button("Mark all done") { prepareListBulkCompletion(list, done: true) }
        Button("Mark all undone") { prepareListBulkCompletion(list, done: false) }
      }
      .disabled(list.progress.totalCount == 0)
      Divider()
      Button("Delete list", role: .destructive) {
        Task { await prepareListDeletion(list) }
      }
      .accessibilityIdentifier("saved.list.delete")
    } label: {
      Label("List actions", systemImage: "ellipsis")
    }
    .labelStyle(.iconOnly)
    .disabled(!store.canCreate || isPreparingBulkCompletion || isPreparingListDeletion)
    .help("List actions")
    .accessibilityIdentifier("saved.list.actions")
  }

  private var usesAutomaticDeletionSelection: Bool {
    #if os(macOS)
      true
    #else
      horizontalSizeClass == .regular
    #endif
  }

  private func recordSelectionChange() {
    selectionGeneration = UUID()
    deletionReplacement = nil
  }

  private var sectionSelection: Binding<SavedPlannerSection> {
    Binding(
      get: { selectedSection },
      set: { section in
        guard section != selectedSection else { return }
        requestDraftNavigation {
          recordSelectionChange()
          selectedSection = section
        }
      })
  }

  private var itemSelection: Binding<UUID?> {
    Binding(
      get: { selectedItemId },
      set: { identifier in
        guard identifier != selectedItemId else { return }
        if identifier == nil && newItemDraft != nil { return }
        requestDraftNavigation {
          recordSelectionChange()
          selectedItemId = identifier
        }
      })
  }

  private var compactColumnSelection: Binding<NavigationSplitViewColumn> {
    Binding(
      get: { preferredCompactColumn },
      set: { column in
        if newItemDraft != nil && column != .detail {
          requestDraftNavigation { preferredCompactColumn = column }
        } else {
          preferredCompactColumn = column
        }
      })
  }

  private func beginNewItem(listIdentifier: UUID?) {
    requestDraftNavigation {
      guard let namespace = store.devicePreferenceNamespace else { return }
      recordSelectionChange()
      store.alertMessage = nil
      if let listIdentifier {
        guard let selectedList, selectedList.source.id == listIdentifier else { return }
        newItemDraft = .init(destination: selectedList, namespace: namespace)
      } else {
        newItemDraft = .init(destination: nil, namespace: namespace)
      }
      preferredCompactColumn = .detail
    }
  }

  private func newItemEditor(_ draft: SavedNewItemDraft) -> some View {
    SavedNewItemForm(
      store: store, draft: draft, isSaving: isSavingNewItem,
      cancel: { requestDraftNavigation {} },
      save: { Task { await saveNewItem(continuingNavigation: false) } })
  }

  private func requestDraftNavigation(_ navigation: @escaping () -> Void) {
    guard !isSavingNewItem else { return }
    guard pendingDraftNavigation == nil else {
      showDraftNavigationReview = true
      return
    }
    guard let newItemDraft, newItemDraft.hasChanges else {
      if self.newItemDraft != nil {
        self.newItemDraft = nil
        preferredCompactColumn = selectedSection == .lists ? .content : .sidebar
      }
      navigation()
      return
    }
    pendingDraftNavigation = navigation
    showDraftNavigationReview = true
  }

  private var hasPresentedWorkflow: Bool {
    showLabels || showRecovery || showSettings || showNewList || showAddItem
      || listEditDraft != nil || captureEntryPoint != nil || membershipMoveDraft != nil
      || listAdditionDraft != nil || itemEditDraft != nil || itemDeletionDraft != nil
      || listDeletionDraft != nil || itineraryDeletionDraft != nil || bulkCompletionDraft != nil
  }

  private func receivePlanOpening() async {
    guard claimedOpeningIdentifier == nil, !isSavingNewItem,
      pendingDraftNavigation == nil, !hasPresentedWorkflow
    else { return }
    do {
      guard
        let request = try await planOpening.claim(windowIdentifier: windowIdentifier, store: store)
      else { return }
      claimedOpeningIdentifier = request.identifier
      requestDraftNavigation {
        openingNavigationTask = Task { await navigateToRequestedPlan(request.identifier) }
      }
    } catch {
      if !Task.isCancelled { store.alertMessage = error.localizedDescription }
    }
  }

  private func navigateToRequestedPlan(_ identifier: UUID) async {
    isResolvingOpening = true
    defer {
      isResolvingOpening = false
      claimedOpeningIdentifier = nil
      openingNavigationTask = nil
    }
    do {
      let source = try await planOpening.resolveNavigation(
        requestIdentifier: identifier, windowIdentifier: windowIdentifier, store: store)
      try Task.checkCancellation()
      recordSelectionChange()
      if source.kind == .list {
        if selectedListId != source.id {
          selectedAppearanceIdentity = nil
          selectedAppearance = nil
        }
        selectedListId = source.id
        selectedSection = .lists
        columnVisibility = .all
        preferredCompactColumn = .content
      } else {
        if selectedItineraryIdentifier != source.id { selectedItineraryRow = nil }
        selectedItineraryIdentifier = source.id
        selectedSection = .itineraries
        itineraryColumnVisibility = .doubleColumn
      }
    } catch {
      if !Task.isCancelled { store.alertMessage = error.localizedDescription }
    }
  }

  private func keepEditingDraft() {
    if let identifier = claimedOpeningIdentifier {
      planOpening.cancel(requestIdentifier: identifier, windowIdentifier: windowIdentifier)
      claimedOpeningIdentifier = nil
    }
    pendingDraftNavigation = nil
  }

  private func finishDraftNavigation() {
    let navigation = pendingDraftNavigation
    pendingDraftNavigation = nil
    newItemDraft = nil
    preferredCompactColumn = selectedSection == .lists ? .content : .sidebar
    navigation?()
  }

  private func saveNewItem(continuingNavigation: Bool) async {
    guard let draft = newItemDraft, !isSavingNewItem else { return }
    guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      store.alertMessage = "An Item title must contain text."
      return
    }
    isSavingNewItem = true
    defer { isSavingNewItem = false }
    guard let result = await store.createItem(draft),
      let source = result.generated.first(where: { $0.kind == .item })
    else { return }
    newItemDraft = nil
    guard store.devicePreferenceNamespace == draft.namespace else {
      keepEditingDraft()
      return
    }
    if claimedOpeningIdentifier != nil && store.recoveryBlocked {
      keepEditingDraft()
      return
    }
    if continuingNavigation || claimedOpeningIdentifier != nil {
      finishDraftNavigation()
      return
    }
    pendingDraftNavigation = nil
    if let listIdentifier = draft.listIdentifier {
      selectedListId = listIdentifier
      for reference in result.generatedReferences {
        if case .membership(let identifier, let list, let item) = reference,
          list.id == listIdentifier, item == source
        {
          selectedAppearanceIdentity = .listMembership(
            listId: listIdentifier, membershipId: identifier)
          break
        }
      }
      await loadSelectedList()
      await loadSelectedAppearance()
    } else {
      selectedItemId = source.id
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
      from offsets: IndexSet, to destination: Int, in items: [SavedMembershipWindowRow],
      listId: UUID
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
  @State private var notes: String
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
    _notes = State(initialValue: list?.content.notes ?? "")
    _manualEstimate = State(initialValue: list?.content.manualEstimate)
  }

  private var canSave: Bool {
    guard store.canCreate, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    guard let list else { return true }
    return name != list.content.name || notes != (list.content.notes ?? "")
      || manualEstimate != list.content.manualEstimate
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Name", text: $name)
          .accessibilityIdentifier("saved.list.name")
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.list.notes")
        SavedActivityEstimateEditor(
          estimate: $manualEstimate,
          accessibilityIdentifierPrefix: "saved.list.estimate", purpose: .overall)
      }
      .disabled(store.isSaving)
      .formStyle(.grouped)
      .navigationTitle(list == nil ? "New list" : "Edit list")
      .toolbarTitleDisplayMode(.inline)
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
                  list, name: name, notes: notes, manualEstimate: manualEstimate,
                  operationId: operationId)
                source = saved ? list.source : nil
              } else {
                source = await store.createList(
                  name: name, notes: notes, manualEstimate: manualEstimate,
                  operationId: operationId)
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
