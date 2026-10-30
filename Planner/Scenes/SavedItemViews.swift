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
    let representation: SavedCollectionRepresentation
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
  let mapCollection: SavedMapCollection?
  let selectMapRow: (PlannerMapRowRead) -> Void
  @Binding var representation: SavedCollectionRepresentation
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
  #if os(iOS)
    @State private var contentWidth: CGFloat = 0
  #endif

  private var request: Request {
    .init(
      scope: scope, representation: representation, filters: filters, searchText: searchText,
      sort: sort,
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
    Group {
      if representation == .map {
        if let mapCollection {
          SavedMapCollectionView(collection: mapCollection, select: selectMapRow)
        } else {
          ProgressView("Opening Map")
        }
      } else {
        listContent
      }
    }
    .navigationSplitViewColumnWidth(
      min: representation == .map ? 320 : 220,
      ideal: representation == .map ? 560 : 320, max: representation == .map ? nil : 800
    )
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
    #if os(iOS)
      .modifier(
        SavedCollectionSearch(
          text: $searchText, placement: representation == .map ? .toolbar : .automatic,
          prompt: scope.searchPrompt, usesMap: representation == .map))
    #else
      .searchable(text: $searchText, prompt: Text(scope.searchPrompt))
    #endif
    .searchPresentationToolbarBehavior(.avoidHidingContent)
    #if os(iOS)
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.size.width
      } action: { width in
        contentWidth = width
      }
    #endif
    .toolbar {
      ToolbarItem {
        SavedItemFilterControl(
          filters: $filters, accessibilityIdentifier: "\(scope.identifierPrefix).filters")
      }
      #if os(iOS)
        if contentWidth < 440 {
          ToolbarOverflowMenu {
            representationMenu
            sortMenu
          }
        } else {
          ToolbarItem { representationMenu }
          ToolbarItem { sortMenu }
        }
      #else
        ToolbarItem { representationMenu }
        ToolbarItem { sortMenu }
      #endif
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

  private var representationMenu: some View {
    SavedCollectionRepresentationMenu(
      representation: $representation,
      accessibilityIdentifier: "\(scope.identifierPrefix).representation")
  }

  private var sortMenu: some View {
    SavedItemSortMenu(sort: $sort, accessibilityIdentifier: "\(scope.identifierPrefix).sort")
  }

  private var listContent: some View {
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
      HStack {
        Button {
          Task { _ = await store.setItemCompletion(item.id, done: item.row.globalDone != true) }
        } label: {
          Label(
            completionLabel,
            systemImage: item.row.globalDone == true ? "checkmark.circle.fill" : "circle"
          )
          .font(.title2)
          #if os(iOS)
            .frame(minWidth: 44, minHeight: 44)
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
      #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
          Button(
            item.row.archived == true ? "Unarchive" : "Archive", systemImage: "archivebox"
          ) {
            Task {
              _ = await store.setItemArchived(item.id, archived: item.row.archived != true)
            }
          }
          .tint(.accentColor)
          .disabled(!store.canCreate)
        }
      #endif
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
    guard request.isActive, request.representation == .list, let namespace = request.namespace
    else {
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
      query: request.filters.itemQuery(
        scope: request.scope.queryValue, text: request.searchText, sort: request.sort),
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

  private var listMembershipSummary: String {
    let membershipCount = item.references.filter { reference in
      guard case .membership(_, _, let source) = reference else { return false }
      return source == item.source
    }.count
    switch membershipCount {
    case 0: return "Not in a list"
    case 1: return "In 1 list"
    default: return "In \(membershipCount) lists"
    }
  }

  var body: some View {
    Form {
      Section {
        #if os(macOS)
          Text(item.content.title).font(.title2).fontWeight(.semibold)
        #endif
        if let subtitle = item.content.subtitle, !subtitle.isEmpty {
          Text(subtitle).foregroundStyle(.secondary)
        }
        if item.state.archived == true {
          Label("Archived", systemImage: "archivebox").foregroundStyle(.secondary)
        }
        Label(listMembershipSummary, systemImage: "list.bullet.rectangle")
          .accessibilityIdentifier("saved.item.lists.summary")
        SavedItemPlansDisclosure(item: item)
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

private struct SavedItemPlansDisclosure: View {
  @Environment(SavedPlannerStore.self) private var store
  let item: PlannerItemSourceRead
  @State private var isExpanded = false
  @State private var loadedRequest: Request?
  @State private var plans: [NamedPlan] = []
  @State private var loadingFailed = false

  private struct Request: Equatable {
    let namespace: String?
    let source: PlannerEntityReference
    let lifetimeIdentifier: UUID
    let revision: UUID
    let references: [PlannerReferenceRead]
    let isExpanded: Bool
  }

  private struct NamedPlan: Identifiable {
    let source: PlannerEntityReference
    let title: String
    var id: PlannerEntityReference { source }
  }

  private var request: Request {
    .init(
      namespace: store.devicePreferenceNamespace, source: item.source,
      lifetimeIdentifier: item.sourceLifetimeId, revision: store.changeRevision,
      references: item.references, isExpanded: isExpanded)
  }

  private var containingLists: Set<PlannerEntityReference> {
    Set(
      item.references.compactMap { reference in
        guard case .membership(_, let list, let source) = reference, source == item.source else {
          return nil
        }
        return list
      })
  }

  private func containingItineraries(
    source: PlannerEntityReference, references: [PlannerReferenceRead]
  ) -> Set<PlannerEntityReference> {
    Set(
      references.compactMap { reference in
        guard case .itineraryEntry(_, let itinerary, let owner) = reference, owner == source else {
          return nil
        }
        return itinerary
      })
  }

  var body: some View {
    Group {
      if !containingLists.isEmpty
        || !containingItineraries(source: item.source, references: item.references).isEmpty
      {
        DisclosureGroup(isExpanded: $isExpanded) {
          if loadedRequest != request {
            ProgressView("Loading plans")
          } else if loadingFailed {
            Text("Planner could not load the containing plans.").foregroundStyle(.secondary)
            Button("Try again") { Task { await loadPlans() } }
          } else {
            ForEach(plans) { plan in
              Label {
                Text(plan.title)
                  .fixedSize(horizontal: false, vertical: true)
              } icon: {
                if plan.source.kind == .list {
                  Image(systemName: "list.bullet.rectangle")
                } else {
                  Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                }
              }
              .accessibilityElement(children: .combine)
              .accessibilityLabel(plan.title)
              .accessibilityValue(plan.source.kind == .list ? "List" : "Itinerary")
              .accessibilityIdentifier(
                "saved.item.plan.\(plan.source.kind.rawValue).\(plan.source.id.uuidString)")
            }
          }
        } label: {
          Text("Plans").accessibilityIdentifier("saved.item.plans")
        }
      }
    }
    .task(id: request) { await loadPlans() }
  }

  private func loadPlans() async {
    let expectedRequest = request
    guard expectedRequest.isExpanded, expectedRequest.namespace != nil else { return }
    loadedRequest = nil
    var loadedPlans: [NamedPlan] = []
    var itineraries = containingItineraries(source: item.source, references: item.references)
    for reference in containingLists {
      let list = await store.readList(reference.id)
      guard !Task.isCancelled, expectedRequest == request else { return }
      guard let list else {
        loadingFailed = true
        loadedRequest = expectedRequest
        return
      }
      loadedPlans.append(.init(source: list.source, title: list.content.name))
      itineraries.formUnion(containingItineraries(source: list.source, references: list.references))
    }
    for reference in itineraries {
      let itinerary = await store.readItinerary(reference.id)
      guard !Task.isCancelled, expectedRequest == request else { return }
      guard let itinerary else {
        loadingFailed = true
        loadedRequest = expectedRequest
        return
      }
      loadedPlans.append(.init(source: itinerary.source, title: itinerary.content.title))
    }
    guard !Task.isCancelled, expectedRequest == request else { return }
    plans = loadedPlans.sorted { first, second in
      if first.source.kind != second.source.kind { return first.source.kind == .list }
      let comparison = first.title.localizedStandardCompare(second.title)
      if comparison != .orderedSame { return comparison == .orderedAscending }
      return first.source.id.uuidString < second.source.id.uuidString
    }
    loadingFailed = false
    loadedRequest = expectedRequest
  }
}
