import PlannerCore
import PlannerPreviews
import SwiftUI

enum SavedItemCatalogScope: String {
  case items, inbox

  var title: String { self == .inbox ? "Inbox" : "Items" }
  var searchPrompt: String { self == .inbox ? "Search Inbox" : "Search Items" }
  var identifierPrefix: String { "saved.\(rawValue)" }
  var queryValue: PlannerItemQuery.Scope { self == .inbox ? .inbox : .global }
}

struct SavedItemCatalog: View {
  private struct Request: Equatable {
    let scope: SavedItemCatalogScope
    let filters: SavedItemFilters
    let searchText: String
    let sort: SavedItemSort
    let namespace: String?
    let revision: UUID
    let isActive: Bool
    let retryIdentifier: UUID
  }

  let store: SavedPlannerStore
  let scope: SavedItemCatalogScope
  let isActive: Bool
  @Binding var selection: UUID?
  @Binding var filters: SavedItemFilters
  @Binding var searchText: String
  @Binding var sort: SavedItemSort
  let canCreate: Bool
  let create: () -> Void
  let capture: () -> Void
  let didLoad: (SavedItemCatalogScope, SavedItemWindowIdentity, UUID?) -> Void
  @State private var window: SavedItemWindow?
  @State private var windowNamespace: String?
  @State private var visibleIdentifiers: Set<UUID> = []
  @State private var retryIdentifier = UUID()

  private var request: Request {
    .init(
      scope: scope, filters: filters, searchText: searchText, sort: sort,
      namespace: store.devicePreferenceNamespace, revision: store.changeRevision,
      isActive: isActive, retryIdentifier: retryIdentifier)
  }

  private var sourceRows: [(index: Int, identifier: UUID)] {
    guard let window else { return [] }
    return window.rowIdentities.enumerated().compactMap { index, identity in
      guard case .source(let source) = identity, source.kind == .item else { return nil }
      return (index, source.id)
    }
  }

  var body: some View {
    List(selection: $selection) {
      if let window {
        ForEach(sourceRows, id: \.identifier) { index, identifier in
          row(window.presentation(at: index), index: index, identifier: identifier)
            .onScrollVisibilityChange { visible in
              if visible {
                visibleIdentifiers.insert(identifier)
              } else {
                visibleIdentifiers.remove(identifier)
              }
            }
        }
      }
    }
    .listStyle(.plain)
    .accessibilityIdentifier("\(scope.identifierPrefix).catalog")
    .overlay { catalogStatus }
    .task(id: request) { await reload() }
    .task(id: visibleIdentifiers) {
      guard let window, !visibleIdentifiers.isEmpty else { return }
      let indices = Set(
        sourceRows.filter { visibleIdentifiers.contains($0.identifier) }.map(\.index))
      await window.requestRows(at: indices)
    }
    .onDisappear {
      window?.cancel()
      visibleIdentifiers = []
    }
    .navigationTitle(scope.title)
    .toolbarTitleDisplayMode(.inline)
    .searchable(text: $searchText, prompt: Text(scope.searchPrompt))
    .searchPresentationToolbarBehavior(.avoidHidingContent)
    .toolbar {
      ToolbarItem {
        SavedItemFilterControl(
          filters: $filters, accessibilityIdentifier: "\(scope.identifierPrefix).filters")
      }
      ToolbarItem {
        SavedItemSortMenu(sort: $sort, accessibilityIdentifier: "\(scope.identifierPrefix).sort")
      }
      ToolbarItem {
        Menu {
          Button("New item", systemImage: "square.and.pencil", action: create)
            .accessibilityIdentifier("saved.item.new")
          Button("From link or text", systemImage: "text.badge.plus", action: capture)
            .accessibilityIdentifier("saved.capture.new")
        } label: {
          Label("Add", systemImage: "plus")
        }
        .labelStyle(.iconOnly)
        .help("Add an item")
        .disabled(!canCreate)
        .accessibilityIdentifier("saved.item.addMenu")
      }
    }
  }

  @ViewBuilder
  private func row(_ presentation: SavedItemWindowPresentation, index: Int, identifier: UUID)
    -> some View
  {
    switch presentation {
    case .loaded(let presentation)
    where presentation.row.identity == .source(.init(kind: .item, id: identifier)):
      let item = SavedPlannerItem(
        id: identifier, row: presentation.row, rowPresentation: presentation.rowPresentation)
      let completionVerb = item.row.globalDone == true ? "undone" : "done"
      let completionLabel = "Mark \(item.row.title) \(completionVerb) everywhere"
      HStack(alignment: .top) {
        Button {
          Task { _ = await store.setItemCompletion(item.id, done: item.row.globalDone != true) }
        } label: {
          Label(
            completionLabel,
            systemImage: item.row.globalDone == true ? "checkmark.circle.fill" : "circle"
          )
          #if os(iOS)
            .frame(minWidth: 44, minHeight: 44, alignment: .top)
            .contentShape(.rect)
          #endif
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(SavedRowForeground.completion(isDone: item.row.globalDone == true))
        .disabled(!store.canCreate)
        .accessibilityValue(item.row.globalDone == true ? "Completed" : "To do")
        .accessibilityIdentifier("saved.item.row.completion.\(item.id.uuidString)")
        .help(completionLabel)
        NavigationLink(value: item.id) {
          SavedItemRowContent(row: item.row, rowPresentation: item.rowPresentation)
          if item.row.archived == true {
            Image(systemName: "archivebox").accessibilityLabel("Archived")
          }
        }
        .accessibilityLabel(item.row.title)
        .accessibilityValue(item.row.metadataDescription(presentation: item.rowPresentation))
        .accessibilityIdentifier("saved.item.\(item.id.uuidString)")
      }
      .tag(item.id)
    case .loading, .loaded:
      ProgressView("Loading Item")
        .selectionDisabled()
    case .failed(let reason):
      VStack(alignment: .leading) {
        Text(reason).foregroundStyle(.secondary)
        Button("Try again") { Task { await window?.requestRows(at: [index]) } }
      }
      .selectionDisabled()
    }
  }

  @ViewBuilder
  private var catalogStatus: some View {
    switch window?.state ?? .idle {
    case .idle, .loading: ProgressView("Opening Items")
    case .failed(let reason):
      ContentUnavailableView {
        Label("Items unavailable", systemImage: "exclamationmark.triangle")
      } description: {
        Text(reason)
      } actions: {
        Button("Try again") { retryIdentifier = UUID() }
      }
    case .ready:
      if window?.matchingCount == 0 {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          if filters.summary == "All" {
            ContentUnavailableView.search(text: searchText)
          } else {
            ContentUnavailableView(
              "No matching items", systemImage: "magnifyingglass",
              description: Text("Change the filters or try a different search."))
          }
        } else {
          ContentUnavailableView(
            filters.summary == "All" ? "No Items yet" : "No matching items",
            systemImage: "square.stack",
            description: Text("Change the filters or create an Item to start planning."))
        }
      }
    }
  }

  private func reload() async {
    guard !Task.isCancelled else { return }
    let request = request
    guard request.isActive, let namespace = request.namespace else {
      window?.cancel()
      visibleIdentifiers = []
      return
    }
    if window == nil || windowNamespace != namespace {
      window?.cancel()
      window = store.makeItemWindow()
      windowNamespace = namespace
    }
    guard let window else { return }
    visibleIdentifiers = []
    let identity = SavedItemWindowIdentity(namespace: namespace, savedRevision: request.revision)
    await window.reload(
      query: .init(
        scope: request.scope.queryValue, text: request.searchText,
        completion: request.filters.completion.queryValue,
        archive: request.filters.archive.queryValue,
        categories: request.filters.categoryQuery, tags: request.filters.tagQuery,
        lists: request.filters.listQuery, duration: request.filters.durationQuery,
        hasAddress: request.filters.hasAddress,
        hasLinks: request.filters.hasLinks, scheduled: request.filters.scheduled,
        sort: request.sort.queryValue),
      identity: identity)
    guard !Task.isCancelled, self.request == request, window.state == .ready else { return }
    didLoad(request.scope, identity, sourceRows.first?.identifier)
  }

}

struct SavedItemDetail: View {
  @Environment(SavedPlannerStore.self) private var store
  let item: PlannerItemSourceRead
  let canChange: Bool
  let isSaving: Bool
  let addToList: () -> Void
  let editItem: () -> Void
  let deleteItem: () -> Void
  let setCompletion: @MainActor @Sendable (Bool) -> Void
  let setArchive: @MainActor @Sendable (Bool) -> Void
  @State private var showNewSchedule = false
  @State private var scheduleToEdit: PlannerScheduleSourceRead?

  var body: some View {
    Form {
      Section {
        Text(item.content.title).font(.title2).fontWeight(.semibold)
        if let subtitle = item.content.subtitle, !subtitle.isEmpty {
          Text(subtitle).foregroundStyle(.secondary)
        }
        if item.state.archived == true {
          Label("Archived", systemImage: "archivebox").foregroundStyle(.secondary)
        }
        Toggle(
          "Completed",
          isOn: Binding(get: { item.state.globalDone == true }, set: setCompletion)
        )
        .disabled(!canChange)
        .accessibilityIdentifier("saved.item.completion")
      } footer: {
        Text("Completing this Item shows it as done in every List and Itinerary.")
          .foregroundStyle(Color.primary)
      }
      if let notes = item.content.notes, !notes.isEmpty {
        Section {
          Text(notes).textSelection(.enabled)
        } header: {
          Text("Notes").foregroundStyle(Color.primary)
        }
      }
      SavedItemEstimateSection(estimate: item.content.estimate)
      SavedSchedulesSection(source: item.source, references: item.references, canChange: canChange)
      {
        scheduleToEdit = $0
      }
      ItemLabelsSection(labels: item.labels)
      ItemLocationSection(
        title: item.content.title, location: item.content.location, previewSource: previewSource,
        links: item.content.links)
      ItemLinksSection(
        links: item.content.links, source: item.source,
        sourceLifetimeId: item.sourceLifetimeId)
    }
    .formStyle(.grouped)
    .navigationTitle(item.content.title)
    .toolbarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button("Edit item", action: editItem)
            .disabled(!canChange)
          Button("Add to list", action: addToList)
            .disabled(!canChange)
          Button("Schedule item") { showNewSchedule = true }
            .disabled(!canChange)
          Button(item.state.archived == true ? "Unarchive item" : "Archive item") {
            setArchive(item.state.archived != true)
          }
          .disabled(!canChange)
          Divider()
          Button("Delete item", role: .destructive, action: deleteItem)
            .disabled(!canChange)
            .accessibilityIdentifier("saved.item.delete")
        } label: {
          Label("Item actions", systemImage: "ellipsis")
        }
        .labelStyle(.iconOnly)
        .help("Item actions")
        .accessibilityIdentifier("saved.item.actions")
      }
    }
    .overlay {
      if isSaving { ProgressView("Saving change") }
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
      SavedScheduleForm(
        store: store, source: item.source, sourceTitle: item.content.title, schedule: scheduleToEdit
      )
    }
  }

  private var previewSource: PlannerPreviewSource? {
    guard let namespace = store.devicePreferenceNamespace else { return nil }
    return .init(
      namespace: namespace, sourceId: item.source.id, sourceLifetimeId: item.sourceLifetimeId)
  }
}
