import PlannerCore
import PlannerPreviews
import SwiftUI

private struct SavedItineraryCatalogReadInputs: Equatable {
  let revision: UUID
  let archive: SavedItemFilters.Archive
  let sort: SavedCatalogSort
  let namespace: String?
}

struct SavedItineraryCatalog: View {
  let store: SavedPlannerStore
  @Binding var archive: SavedItemFilters.Archive
  @Binding var selection: UUID?
  @State private var catalogWindow: SavedItemWindow?
  @State private var isLoading = false
  @State private var loadingFailure: String?
  @State private var showNewItinerary = false
  @State private var sortPreferences = SavedCatalogSortPreferences()

  var body: some View {
    List(selection: $selection) {
      if let catalogWindow {
        SavedContainerWindowRows(
          window: catalogWindow, sourceKind: .itinerary, selectionTag: { $0.id }
        ) { row in
          if case .source(let source) = row.identity, let estimates = row.containerEstimates {
            let itinerary = SavedPlannerItinerary(
              source: source, title: row.title, archived: row.archived == true,
              manualEstimate: row.manualEstimate, estimates: estimates)
            NavigationLink(value: itinerary.id) {
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Label(
                    itinerary.title,
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                  )
                  .foregroundStyle(SavedRowForeground())
                  if itinerary.archived {
                    Image(systemName: "archivebox").foregroundStyle(.secondary)
                      .accessibilityHidden(true)
                  }
                }
                SavedContainerEstimatePreview(
                  estimates: itinerary.estimates, manualEstimate: itinerary.manualEstimate)
              }
            }
            .accessibilityLabel(itinerary.title)
            .accessibilityValue(
              (itinerary.archived ? "Archived. " : "Active. ")
                + itinerary.estimates.nativeEstimatePreviewAccessibilityDescription(
                  manualEstimate: itinerary.manualEstimate)
            )
            .accessibilityIdentifier("saved.itinerary.row.\(itinerary.id.uuidString)")
          }
        }
      }
    }
    .accessibilityIdentifier("saved.itineraries.catalog")
    .overlay {
      if isLoading || catalogWindow?.state == .loading {
        ProgressView("Loading Itineraries")
      } else if let loadingFailure = catalogFailure {
        ContentUnavailableView {
          Label("Itineraries unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try again") { Task { await loadItineraries() } }
        }
      } else if catalogWindow?.state == .ready, catalogWindow?.matchingCount == 0 {
        ContentUnavailableView(
          archive == .active ? "No Itineraries yet" : "No matching Itineraries",
          systemImage: "point.topleft.down.to.point.bottomright.curvepath",
          description: Text("Change the archive filter or create an Itinerary to start planning."))
      }
    }
    .navigationTitle("Itineraries")
    .toolbarTitleDisplayMode(.inline)
    .navigationSplitViewColumnWidth(min: 240, ideal: 320, max: 480)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        SavedCatalogSortMenu(sort: sort, accessibilityIdentifier: "saved.itineraries.sort")
      }
      ToolbarItem(placement: .primaryAction) {
        SavedCatalogArchiveFilterMenu(
          archive: $archive, pluralTitle: "Itineraries",
          accessibilityIdentifier: "saved.itineraries.archive")
      }
      ToolbarItem(placement: .primaryAction) {
        Button("New itinerary", systemImage: "plus") { showNewItinerary = true }
          .labelStyle(.iconOnly)
          .help("New itinerary")
          .disabled(!store.canCreate)
          .accessibilityIdentifier("saved.itinerary.new")
      }
    }
    .task(
      id: SavedItineraryCatalogReadInputs(
        revision: store.changeRevision, archive: archive, sort: sort.wrappedValue,
        namespace: store.devicePreferenceNamespace)
    ) {
      await loadItineraries()
    }
    .sheet(isPresented: $showNewItinerary) {
      SavedItineraryForm(store: store) { source in selection = source.id }
    }
  }

  private var sort: Binding<SavedCatalogSort> {
    let key = store.devicePreferenceNamespace.map { "planner.catalog-sort.\($0).itineraries" }
    return Binding(
      get: { sortPreferences.selection(for: key) },
      set: { sortPreferences.select($0, for: key) })
  }

  private var catalogFailure: String? {
    if case .failed(let reason) = catalogWindow?.state { return reason }
    return loadingFailure
  }

  private func loadItineraries() async {
    guard !Task.isCancelled else { return }
    isLoading = true
    loadingFailure = nil
    let revision = store.changeRevision
    let selectedArchive = archive
    let selectedSort = sort.wrappedValue
    let namespace = store.devicePreferenceNamespace
    catalogWindow?.cancel()
    guard let namespace, let window = store.makeItemWindow() else {
      catalogWindow = nil
      loadingFailure = "Planner is not ready to load its Itineraries."
      isLoading = false
      return
    }
    catalogWindow = window
    await window.reload(
      catalogQuery: .init(
        sourceKind: .itinerary, archive: selectedArchive.queryValue, sort: selectedSort.queryValue),
      identity: .init(namespace: namespace, savedRevision: revision))
    guard !Task.isCancelled, store.changeRevision == revision, archive == selectedArchive,
      sort.wrappedValue == selectedSort, store.devicePreferenceNamespace == namespace,
      catalogWindow === window
    else {
      return
    }
    if case .failed(let reason) = window.state {
      loadingFailure = reason
    }
    isLoading = false
  }
}

private struct SavedItineraryEditDraft: Identifiable {
  let itinerary: PlannerItinerarySourceRead
  var id: UUID { itinerary.source.id }
}

private struct SavedItineraryReadInputs: Equatable {
  let identifier: UUID
  let revision: UUID
  let text: String
  let filters: SavedItemFilters
  let namespace: String?
}

private struct SavedItineraryWindowRow: Identifiable {
  let id: SavedItineraryRowSelection
  let index: Int
  let identity: PlannerRowIdentity
}

struct SavedItineraryPresentation {
  var representation = SavedCollectionRepresentation.list
  var searchText = ""
  var filters = SavedItemFilters()
  var collapsedEntries: Set<UUID> = []
}

struct SavedItineraryDetail: View {
  let store: SavedPlannerStore
  let identifier: UUID
  @Binding var selection: SavedItineraryRowSelection?
  let representation: Binding<SavedCollectionRepresentation>?
  let mapCollection: SavedMapCollection?
  let selectMapRow: (PlannerMapRowRead) -> Void
  @Binding var searchText: String
  @Binding var filters: SavedItemFilters
  @Binding var collapsedEntries: Set<UUID>
  let isPreparingDeletion: Bool
  let isReviewingDeletion: Bool
  let prepareDeletion: (PlannerItinerarySourceRead) -> Void
  let recordRemoval: (PlannerOperationResult) -> Void
  let recordOwnedRemovals: (PlannerOperationResult) -> Void
  @State private var window: SavedItemWindow?
  @State private var windowNamespace: String?
  @State private var windowItineraryIdentifier: UUID?
  @State private var windowCreationFailure: String?
  @State private var visibleRows: Set<SavedItineraryRowSelection> = []
  @State private var scrollAnchor: SavedItineraryRowSelection?
  @State private var pendingScrollAnchor: SavedItineraryRowSelection?
  @State private var editDraft: SavedItineraryEditDraft?
  @State private var showAddEntry = false
  @State private var showNewSchedule = false
  @State private var scheduleToEdit: PlannerScheduleSourceRead?
  @State private var bulkCompletionDraft: SavedBulkCompletionDraft?
  @State private var isPreparingBulkCompletion = false
  @State private var removedSelectionMessage: String?
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var contentWidth: CGFloat = 0
    @State private var entryEditMode: EditMode = .inactive
  #endif

  var body: some View {
    Group {
      if let contents {
        let itinerary = contents.itinerary
        Group {
          if usesMapRepresentation {
            itineraryMap(itinerary)
          } else {
            ScrollViewReader { proxy in
              List(selection: $selection) {
                Section {
                  itineraryTitle(itinerary)
                  if itinerary.state.archived == true {
                    Label("Archived Itinerary", systemImage: "archivebox").foregroundStyle(
                      .secondary)
                  }
                  if itinerary.progress.state == .empty {
                    Text("No items").foregroundStyle(.secondary)
                  } else if let done = itinerary.progress.doneCount,
                    let archived = itinerary.progress.archivedCount,
                    let total = itinerary.progress.totalCount, total > 0
                  {
                    SavedCompletionProgress(
                      doneCount: done, archivedCount: archived, totalCount: total,
                      accessibilityIdentifier: "saved.itinerary.progress")
                  } else {
                    Text("Progress unavailable").foregroundStyle(.secondary)
                  }
                  SavedContainerEstimates(
                    estimates: itinerary.estimates,
                    manualEstimate: itinerary.content.manualEstimate,
                    accessibilityIdentifierPrefix: "saved.itinerary.estimate")
                  let directCount = contents.entries.filter { $0.source.kind == .item }.count
                  let listCount = contents.entries.filter { $0.source.kind == .list }.count
                  Text(
                    "\(directCount) direct \(directCount == 1 ? "item" : "items") · \(listCount) \(listCount == 1 ? "list" : "lists")"
                  )
                  .font(.caption).foregroundStyle(Color.primary)
                  if let total = itinerary.progress.totalCount,
                    (window?.matchingCount ?? 0) != total
                  {
                    Text("Matching \(window?.matchingCount ?? 0) of \(total) items")
                      .font(.caption).foregroundStyle(Color.primary)
                  }
                }
                if let notes = itinerary.content.notes, !notes.isEmpty {
                  Section("Notes") { Text(notes).textSelection(.enabled) }
                }
                ItemLabelsSection(labels: itinerary.labels)
                ItemLocationSection(
                  title: itinerary.content.title, location: itinerary.content.location,
                  previewSource: previewSource(for: itinerary))
                ItemLinksSection(
                  links: itinerary.content.links, source: itinerary.source,
                  sourceLifetimeId: itinerary.sourceLifetimeId)
                SavedSchedulesSection(
                  source: itinerary.source, references: itinerary.references,
                  canChange: store.canCreate
                ) { scheduleToEdit = $0 }
                Section {
                  if contents.visibleEntries.isEmpty && !contents.entries.isEmpty {
                    Text("No matching entries").foregroundStyle(.secondary)
                  }
                  ForEach(contents.visibleEntries) { entry in
                    itineraryEntry(entry, in: contents)
                  }
                  .onMove { offsets, destination in
                    moveEntry(from: offsets, to: destination, in: contents.visibleEntries)
                  }
                } header: {
                  Text("Entries").foregroundStyle(Color.primary)
                }
              }
              .accessibilityIdentifier("saved.itinerary.contents")
              .task(id: pendingScrollAnchor) {
                guard let anchor = pendingScrollAnchor, let window,
                  let row = expandedRows.first(where: { $0.id == anchor })
                else {
                  pendingScrollAnchor = nil
                  return
                }
                await window.requestRows(at: [row.index])
                guard !Task.isCancelled, pendingScrollAnchor == anchor, self.window === window,
                  window.state == .ready, expandedRows.contains(where: { $0.id == anchor })
                else { return }
                proxy.scrollTo(anchor, anchor: .center)
                pendingScrollAnchor = nil
              }
            }
          }
        }
        #if os(iOS)
          .environment(\.editMode, $entryEditMode)
        #endif
        .navigationTitle(itinerary.content.title)
        #if os(iOS)
          .navigationBarTitleDisplayMode(showsCollectionTitle ? .inline : .large)
        #else
          .toolbarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: "Search this Itinerary")
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .navigationSplitViewColumnWidth(
          min: usesMapRepresentation ? 320 : 260,
          ideal: usesMapRepresentation ? 560 : 400, max: 800
        )
        #if os(iOS)
          .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
          } action: { width in
            contentWidth = width
          }
        #endif
        .overlay(alignment: .topTrailing) {
          if isPreparingBulkCompletion || isPreparingDeletion || isLoading {
            ProgressView(isLoading ? "Updating entries" : "Preparing review")
              .controlSize(.small).padding()
          }
        }
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            SavedItemFilterControl(
              filters: $filters, accessibilityIdentifier: "saved.itinerary.filters")
          }
          #if os(iOS)
            if horizontalSizeClass == .compact || contentWidth < 440 {
              ToolbarOverflowMenu {
                representationMenu
                reorderButton(entryCount: contents.entries.count)
                editButton(itinerary)
                actionsMenu(itinerary)
              }
            } else {
              ToolbarItem(placement: .secondaryAction) { representationMenu }
              ToolbarItem(placement: .primaryAction) {
                reorderButton(entryCount: contents.entries.count)
              }
              ToolbarItem(placement: .primaryAction) { editButton(itinerary) }
              ToolbarItem(placement: .primaryAction) { actionsMenu(itinerary) }
            }
          #else
            ToolbarItem(placement: .secondaryAction) { representationMenu }
            ToolbarItem(placement: .primaryAction) { editButton(itinerary) }
            ToolbarItem(placement: .primaryAction) { actionsMenu(itinerary) }
          #endif
          ToolbarItem(placement: .primaryAction) {
            Button("Add entry", systemImage: "plus") { showAddEntry = true }
              .labelStyle(.iconOnly)
              .help("Add an itinerary entry")
              .disabled(!store.canCreate || isLoading)
              .accessibilityIdentifier("saved.itinerary.entry.new")
          }
        }
      } else if let loadingFailure {
        ContentUnavailableView {
          Label("Itinerary unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try again") { Task { await loadItinerary() } }
        }
      } else {
        ProgressView("Opening Itinerary")
      }
    }
    .task(id: readInputs) { await loadItinerary() }
    .task(id: visibleRows) { await requestVisibleRows() }
    .task(id: collapsedEntries) { await requestVisibleRows() }
    .onDisappear {
      // Compact navigation needs the parent row identities while its Item detail is open.
      if selection == nil { window?.cancel() }
      visibleRows = []
    }
    .onChange(of: isReviewingDeletion) {
      if !isReviewingDeletion { Task { await loadItinerary() } }
    }
    .sheet(item: $editDraft) { draft in
      SavedItineraryForm(
        store: store, itinerary: draft.itinerary, didEdit: recordOwnedRemovals
      ) { _ in }
    }
    .sheet(isPresented: $showAddEntry) {
      SavedAddItineraryEntryForm(store: store, itineraryId: identifier)
    }
    .sheet(item: $bulkCompletionDraft) { draft in
      SavedBulkCompletionForm(store: store, draft: draft)
    }
    .sheet(
      isPresented: Binding(
        get: { showNewSchedule || scheduleToEdit != nil },
        set: {
          if !$0 {
            showNewSchedule = false
            scheduleToEdit = nil
          }
        })
    ) {
      if let itinerary = contents?.itinerary {
        SavedScheduleForm(
          store: store, source: itinerary.source, sourceTitle: itinerary.content.title,
          schedule: scheduleToEdit)
      }
    }
    .alert(
      "Planner",
      isPresented: Binding(
        get: {
          (store.alertMessage != nil || removedSelectionMessage != nil)
            && editDraft == nil && !showAddEntry
            && bulkCompletionDraft == nil && !showNewSchedule && scheduleToEdit == nil
            && !isReviewingDeletion
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

  @ViewBuilder
  private var representationMenu: some View {
    if let representation {
      SavedCollectionRepresentationMenu(
        representation: representation,
        accessibilityIdentifier: "saved.itinerary.representation")
    }
  }

  #if os(iOS)
    private func reorderButton(entryCount: Int) -> some View {
      EditButton()
        .environment(\.editMode, $entryEditMode)
        .accessibilityLabel("Reorder entries")
        .accessibilityIdentifier("saved.itinerary.reorder")
        .disabled(
          usesMapRepresentation || !store.canCreate || isLoading
            || isPreparingBulkCompletion || (entryCount < 2 && !entryEditMode.isEditing))
    }
  #endif

  private func editButton(_ itinerary: PlannerItinerarySourceRead) -> some View {
    Button("Edit itinerary", systemImage: "pencil") {
      editDraft = .init(itinerary: itinerary)
    }
    .labelStyle(.iconOnly)
    .help("Edit itinerary")
    .disabled(!store.canCreate || isLoading)
    .accessibilityIdentifier("saved.itinerary.edit")
  }

  private func actionsMenu(_ itinerary: PlannerItinerarySourceRead) -> some View {
    Menu {
      Button("Schedule itinerary") { showNewSchedule = true }
      Button(itinerary.state.archived == true ? "Unarchive itinerary" : "Archive itinerary") {
        Task {
          _ = await store.setItineraryArchived(
            identifier, archived: itinerary.state.archived != true)
        }
      }
      Divider()
      Group {
        Button("Mark all done") {
          prepareBulkCompletion(
            .itinerary(itineraryId: identifier), containerName: itinerary.content.title,
            done: true)
        }
        Button("Mark all undone") {
          prepareBulkCompletion(
            .itinerary(itineraryId: identifier), containerName: itinerary.content.title,
            done: false)
        }
      }
      .disabled(itinerary.progress.totalCount == 0)
      Divider()
      Button("Delete itinerary", role: .destructive) { prepareDeletion(itinerary) }
        .accessibilityIdentifier("saved.itinerary.delete")
    } label: {
      Label("Itinerary actions", systemImage: "ellipsis")
    }
    .labelStyle(.iconOnly)
    .disabled(
      !store.canCreate || isLoading || isPreparingBulkCompletion || isPreparingDeletion
    )
    .help("Itinerary actions")
    .accessibilityIdentifier("saved.itinerary.actions")
  }

  private var usesMapRepresentation: Bool { representation?.wrappedValue == .map }

  private var showsCollectionTitle: Bool {
    #if os(iOS)
      UIDevice.current.userInterfaceIdiom != .phone
    #else
      true
    #endif
  }

  @ViewBuilder
  private func itineraryTitle(_ itinerary: PlannerItinerarySourceRead) -> some View {
    if showsCollectionTitle {
      Text(itinerary.content.title).font(.title2).fontWeight(.semibold)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("saved.itinerary.title")
    }
  }

  private func itineraryMap(_ itinerary: PlannerItinerarySourceRead) -> some View {
    let summary = VStack(alignment: .leading, spacing: 8) {
      itineraryTitle(itinerary)
      if let done = itinerary.progress.doneCount, let archived = itinerary.progress.archivedCount,
        let total = itinerary.progress.totalCount, total > 0
      {
        SavedCompletionProgress(
          doneCount: done, archivedCount: archived, totalCount: total,
          accessibilityIdentifier: "saved.itinerary.progress")
      }
      SavedContainerEstimates(
        estimates: itinerary.estimates, manualEstimate: itinerary.content.manualEstimate,
        accessibilityIdentifierPrefix: "saved.itinerary.estimate")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.bar)
    return SavedMapCollectionLayout {
      summary
    } mapContent: {
      if let mapCollection {
        SavedMapCollectionView(collection: mapCollection, select: selectMapRow)
      } else {
        ProgressView("Opening Map").frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private var contents: SavedItineraryWindowMetadata? {
    guard let window, windowNamespace == store.devicePreferenceNamespace,
      let metadata = window.itineraryMetadata, metadata.itinerary.source.id == identifier
    else { return nil }
    if case .failed = window.state { return nil }
    return metadata
  }

  private var isLoading: Bool { window?.state == .loading }

  private var loadingFailure: String? {
    if let window, case .failed(let message) = window.state { return message }
    return windowCreationFailure
  }

  private func rows(in entry: SavedItineraryWindowEntry) -> [SavedItineraryWindowRow] {
    guard let window else { return [] }
    return entry.matchingRowIndices.compactMap { index in
      guard window.rowIdentities.indices.contains(index),
        case .appearance(_, let appearance) = window.rowIdentities[index],
        let selection = SavedItineraryRowSelection(appearance, itineraryId: identifier)
      else { return nil }
      return .init(id: selection, index: index, identity: window.rowIdentities[index])
    }
  }

  private var expandedRows: [SavedItineraryWindowRow] {
    (contents?.visibleEntries ?? []).flatMap { entry -> [SavedItineraryWindowRow] in
      if entry.source.kind == .list && collapsedEntries.contains(entry.id) { return [] }
      return rows(in: entry)
    }
  }

  @ViewBuilder
  private func itineraryEntry(
    _ entry: SavedItineraryWindowEntry, in contents: SavedItineraryWindowMetadata
  ) -> some View {
    let matchingRows = rows(in: entry)
    Group {
      if let list = entry.list {
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
          if matchingRows.isEmpty {
            Text(entry.rowIdentities.isEmpty ? "No items" : "No matching items")
              .foregroundStyle(.secondary)
          } else {
            ForEach(matchingRows) { row in
              windowedItineraryRow(row).moveDisabled(true)
            }
          }
        } label: {
          VStack(alignment: .leading, spacing: 6) {
            Label(list.content.name, systemImage: "list.bullet.rectangle")
              .font(.headline)
            if list.state.archived == true {
              Label("Archived List", systemImage: "archivebox")
                .font(.caption).foregroundStyle(.secondary)
            }
            if let summary = entry.listSummary {
              SavedContainerEstimates(
                estimates: summary.estimates, manualEstimate: summary.manualEstimate,
                accessibilityIdentifierPrefix:
                  "saved.itinerary.entry.estimate.\(entry.id.uuidString)")
              if let done = summary.progress.doneCount,
                let archived = summary.progress.archivedCount,
                let total = summary.progress.totalCount, total > 0
              {
                SavedCompletionProgress(
                  doneCount: done, archivedCount: archived, totalCount: total,
                  accessibilityIdentifier: "saved.itinerary.entry.progress.\(entry.id)"
                ).font(.caption).foregroundStyle(.secondary)
              }
            }
            if matchingRows.count != entry.rowIdentities.count {
              Text("Matching \(matchingRows.count) of \(entry.rowIdentities.count) items")
                .font(.caption).foregroundStyle(Color.primary)
            }
          }
          .padding(.vertical, 8)
          .contextMenu {
            entryActions(entry, in: contents.entries)
            Divider()
            Group {
              Button("Mark all done") {
                prepareBulkCompletion(
                  .itineraryListEntry(itineraryId: identifier, listEntryId: entry.id),
                  containerName: list.content.name, done: true)
              }
              Button("Mark all undone") {
                prepareBulkCompletion(
                  .itineraryListEntry(itineraryId: identifier, listEntryId: entry.id),
                  containerName: list.content.name, done: false)
              }
            }
            .disabled(
              !store.canCreate || isLoading || isPreparingBulkCompletion
                || entry.rowIdentities.isEmpty)
          }
        }
      } else if let row = matchingRows.first {
        windowedItineraryRow(row)
          .contextMenu { entryActions(entry, in: contents.entries) }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.itinerary.entry.\(entry.id.uuidString)")
    .moveDisabled(!canReorderEntries)
  }

  @ViewBuilder
  private func windowedItineraryRow(_ row: SavedItineraryWindowRow) -> some View {
    if let window {
      Group {
        switch window.presentation(at: row.index) {
        case .loaded(let presentation) where presentation.row.identity == row.identity:
          itineraryRow(
            .init(id: row.id, row: presentation.row, rowPresentation: presentation.rowPresentation))
        case .loading, .loaded:
          ProgressView("Loading Item").selectionDisabled().moveDisabled(true)
        case .failed(let message):
          VStack(alignment: .leading) {
            Text(message).foregroundStyle(.secondary)
            Button("Try again") { Task { await window.requestRows(at: [row.index]) } }
          }
          .selectionDisabled().moveDisabled(true)
        }
      }
      .id(row.id)
      .onScrollVisibilityChange { visible in
        if visible {
          visibleRows.insert(row.id)
        } else {
          visibleRows.remove(row.id)
        }
        guard window.state == .ready,
          let first = expandedRows.first(where: { visibleRows.contains($0.id) })
        else { return }
        scrollAnchor = first.id
      }
    }
  }

  private func requestVisibleRows() async {
    guard let window, window.state == .ready else { return }
    let indices = Set(expandedRows.filter { visibleRows.contains($0.id) }.map(\.index))
    await window.requestRows(at: indices)
  }

  private var alertDescription: String {
    let description = removedSelectionMessage ?? store.alertMessage ?? ""
    guard removedSelectionMessage != nil && store.recoveryBlocked else { return description }
    return description
      + "\n\nThe change was saved, but its recovery copy is incomplete. Further changes are paused."
  }

  private var readInputs: SavedItineraryReadInputs {
    .init(
      identifier: identifier, revision: store.changeRevision, text: searchText, filters: filters,
      namespace: store.devicePreferenceNamespace)
  }

  private func previewSource(for itinerary: PlannerItinerarySourceRead) -> PlannerPreviewSource? {
    guard let namespace = store.devicePreferenceNamespace else { return nil }
    return .init(
      namespace: namespace, sourceId: itinerary.source.id,
      sourceLifetimeId: itinerary.sourceLifetimeId)
  }

  private func itineraryRow(_ item: SavedItineraryItem) -> some View {
    SavedItineraryItemRow(item: item, canChange: store.canCreate && !isLoading) {
      scrollAnchor = item.id
      Task {
        _ = await store.setAppearanceCompletion(
          item.id.appearance(itineraryId: identifier), done: item.row.effectiveDone != true)
      }
    }
    .tag(item.id)
  }

  private func entryActions(
    _ entry: SavedItineraryWindowEntry, in entries: [SavedItineraryWindowEntry]
  ) -> some View {
    Group {
      Button("Move to beginning") {
        Task {
          _ = await store.reorderItineraryEntry(
            entry.id, itineraryIdentifier: identifier, placement: .first)
        }
      }
      .disabled(entries.first?.id == entry.id)
      Button("Move to end") {
        Task {
          _ = await store.reorderItineraryEntry(
            entry.id, itineraryIdentifier: identifier, placement: .last)
        }
      }
      .disabled(entries.last?.id == entry.id)
      Divider()
      Button("Remove from itinerary", role: .destructive) { removeEntry(entry) }
    }
    .disabled(!store.canCreate || isLoading || isPreparingBulkCompletion)
  }

  private func removeEntry(_ entry: SavedItineraryWindowEntry) {
    Task {
      let namespace = store.devicePreferenceNamespace
      guard
        let result = await store.removeItineraryEntry(entry.id, itineraryIdentifier: identifier),
        case .applied = result.outcome, store.devicePreferenceNamespace == namespace
      else { return }
      recordRemoval(result)
      guard let selection else { return }
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
    guard store.canCreate, !isLoading, !isPreparingBulkCompletion else { return false }
    #if os(iOS)
      return entryEditMode.isEditing
    #else
      return true
    #endif
  }

  private func moveEntry(
    from offsets: IndexSet, to destination: Int, in entries: [SavedItineraryWindowEntry]
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
    guard !Task.isCancelled, !isReviewingDeletion else { return }
    let inputs = readInputs
    windowCreationFailure = nil
    guard let namespace = inputs.namespace else {
      window?.cancel()
      return
    }
    if windowNamespace != namespace || windowItineraryIdentifier != inputs.identifier {
      visibleRows = []
      scrollAnchor = nil
      pendingScrollAnchor = nil
    }
    if window == nil || windowNamespace != namespace {
      window?.cancel()
      window = store.makeItemWindow()
      windowNamespace = namespace
    }
    windowItineraryIdentifier = inputs.identifier
    guard let window else {
      windowCreationFailure = "Planner could not open this Itinerary. Try again."
      return
    }
    let previousScrollAnchor = scrollAnchor
    await window.reload(
      query: .init(
        scope: .itinerary(inputs.identifier), text: inputs.text,
        completion: inputs.filters.completion.queryValue,
        archive: inputs.filters.archive.queryValue,
        categories: inputs.filters.categoryQuery, tags: inputs.filters.tagQuery,
        lists: inputs.filters.listQuery, duration: inputs.filters.durationQuery,
        hasAddress: inputs.filters.hasAddress,
        hasLinks: inputs.filters.hasLinks, scheduled: inputs.filters.scheduled,
        sort: .init(mode: .manual)),
      identity: .init(namespace: namespace, savedRevision: inputs.revision))
    guard !Task.isCancelled, readInputs == inputs, !isReviewingDeletion, self.window === window,
      window.state == .ready
    else { return }
    if !visibleRows.isEmpty { await requestVisibleRows() }
    if let previousScrollAnchor,
      expandedRows.contains(where: { $0.id == previousScrollAnchor })
    {
      pendingScrollAnchor = previousScrollAnchor
    }
  }

}

private struct SavedItineraryForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let itinerary: PlannerItinerarySourceRead?
  let didSave: (PlannerEntityReference) -> Void
  private let didEdit: ((PlannerOperationResult) -> Void)?
  @State private var namespace: String?
  @State private var title: String
  @State private var notes: String
  @State private var manualEstimate: PlannerEstimate?
  @State private var locationDraft: SavedOwnedLocationDraft
  @State private var links: [SavedOwnedLinkDraft]
  @State private var categoryIdentifiers: Set<UUID>
  @State private var tagIdentifiers: Set<UUID>
  @State private var operationIdentifier = UUID()

  init(
    store: SavedPlannerStore, itinerary: PlannerItinerarySourceRead? = nil,
    didEdit: ((PlannerOperationResult) -> Void)? = nil,
    didSave: @escaping (PlannerEntityReference) -> Void
  ) {
    self.store = store
    self.itinerary = itinerary
    self.didSave = didSave
    self.didEdit = didEdit
    _namespace = State(initialValue: store.devicePreferenceNamespace)
    _title = State(initialValue: itinerary?.content.title ?? "")
    _notes = State(initialValue: itinerary?.content.notes ?? "")
    _manualEstimate = State(initialValue: itinerary?.content.manualEstimate)
    _locationDraft = State(initialValue: SavedOwnedLocationDraft(itinerary?.content.location))
    _links = State(initialValue: itinerary?.content.links.map(SavedOwnedLinkDraft.init) ?? [])
    _categoryIdentifiers = State(initialValue: itinerary?.content.categoryIds ?? [])
    _tagIdentifiers = State(initialValue: itinerary?.content.tagIds ?? [])
  }

  private var canSave: Bool {
    guard store.canCreate, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    guard let itinerary else { return true }
    return title != itinerary.content.title || notes != (itinerary.content.notes ?? "")
      || links.map(\.input) != itinerary.content.links.map(\.editInput)
      || categoryIdentifiers != itinerary.content.categoryIds
      || tagIdentifiers != itinerary.content.tagIds
      || manualEstimate != itinerary.content.manualEstimate
      || locationDraft.value != itinerary.content.location
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Title", text: $title)
          .accessibilityIdentifier("saved.itinerary.title")
        TextField("Notes", text: $notes, axis: .vertical)
          .lineLimit(3...8)
          .accessibilityIdentifier("saved.itinerary.notes")
        SavedActivityEstimateEditor(
          estimate: $manualEstimate,
          accessibilityIdentifierPrefix: "saved.itinerary.estimate", purpose: .overall)
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
        SavedOwnedLocationEditor(
          draft: $locationDraft, title: title,
          accessibilityIdentifierPrefix: "saved.itinerary.location")
        SavedOwnedLinksEditor(links: $links, accessibilityIdentifierPrefix: "saved.itinerary.link")
      }
      .disabled(store.isSaving)
      .formStyle(.grouped)
      .navigationTitle(itinerary == nil ? "New itinerary" : "Edit itinerary")
      .toolbarTitleDisplayMode(.inline)
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
    guard let namespace, namespace == store.devicePreferenceNamespace else { return }
    let source: PlannerEntityReference?
    if let itinerary {
      let result = await store.editItinerary(
        itinerary, title: title, notes: notes, location: locationDraft.value,
        links: links.map(\.input),
        categoryIdentifiers: categoryIdentifiers,
        tagIdentifiers: tagIdentifiers, manualEstimate: manualEstimate,
        operationIdentifier: operationIdentifier)
      guard let result, case .applied = result.outcome,
        namespace == store.devicePreferenceNamespace
      else { return }
      didEdit?(result)
      source = itinerary.source
    } else {
      source = await store.createItinerary(
        title: title, notes: notes, location: locationDraft.value, links: links.map(\.input),
        categoryIdentifiers: categoryIdentifiers,
        tagIdentifiers: tagIdentifiers, manualEstimate: manualEstimate,
        operationIdentifier: operationIdentifier)
    }
    guard let source, namespace == store.devicePreferenceNamespace, store.alertMessage == nil else {
      return
    }
    didSave(source)
    dismiss()
  }

  private func selectionSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "None" : "\(identifiers.count) selected"
  }
}
