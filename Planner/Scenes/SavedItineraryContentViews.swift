import PlannerCore
import PlannerPreviews
import SwiftUI

enum SavedItineraryRowSelection: Hashable {
  case direct(entryId: UUID)
  case expanded(listEntryId: UUID, membershipId: UUID)

  init?(_ appearance: PlannerAppearance, itineraryId: UUID) {
    switch appearance {
    case .directItineraryItem(let owner, let entryId) where owner == itineraryId:
      self = .direct(entryId: entryId)
    case .expandedListItem(let owner, let listEntryId, let membershipId) where owner == itineraryId:
      self = .expanded(listEntryId: listEntryId, membershipId: membershipId)
    default: return nil
    }
  }

  var identifier: String {
    switch self {
    case .direct(let entryId): return entryId.uuidString
    case .expanded(let listEntryId, let membershipId):
      return "\(listEntryId.uuidString).\(membershipId.uuidString)"
    }
  }

  func appearance(itineraryId: UUID) -> PlannerAppearance {
    switch self {
    case .direct(let entryId):
      return .directItineraryItem(itineraryId: itineraryId, entryId: entryId)
    case .expanded(let listEntryId, let membershipId):
      return .expandedListItem(
        itineraryId: itineraryId, listEntryId: listEntryId, membershipId: membershipId)
    }
  }
}

struct SavedItineraryItem: Identifiable {
  let id: SavedItineraryRowSelection
  let row: PlannerRowRead
  let rowPresentation: PlannerRowPresentationContext?
}

struct SavedItineraryItemRow: View {
  let item: SavedItineraryItem
  let canChange: Bool
  let toggleCompletion: () -> Void

  var body: some View {
    HStack(alignment: .top) {
      Button(action: toggleCompletion) {
        Label(
          completionLabel,
          systemImage: item.row.effectiveDone == true ? "checkmark.circle.fill" : "circle"
        )
        #if os(iOS)
          .frame(minWidth: 44, minHeight: 44, alignment: .top)
          .contentShape(.rect)
        #endif
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      #if os(iOS)
        .foregroundStyle(SavedRowForeground.completion(isDone: item.row.effectiveDone == true))
      #endif
      .disabled(!canChange || item.row.globalDone == true)
      .accessibilityValue(item.row.effectiveDone == true ? "Completed" : "To do")
      .accessibilityIdentifier("saved.itinerary.completion.\(item.id.identifier)")
      .help(completionLabel)
      NavigationLink(value: item.id) {
        SavedItemRowContent(row: item.row, rowPresentation: item.rowPresentation)
      }
      .accessibilityLabel(item.row.title)
      .accessibilityValue(item.row.metadataDescription(presentation: item.rowPresentation))
      .accessibilityIdentifier("saved.itinerary.appearance.\(item.id.identifier)")
      if item.row.archived == true {
        Image(systemName: "archivebox")
          .foregroundStyle(SavedRowForeground.secondary)
          .accessibilityLabel("Archived")
      }
    }
  }

  private var completionLabel: String {
    if item.row.globalDone == true { return "Completed globally: \(item.row.title)" }
    if item.row.effectiveDone == true { return "Mark \(item.row.title) undone in this Itinerary" }
    return "Mark \(item.row.title) done in this Itinerary"
  }
}

struct SavedItineraryItemDetail: View {
  @Environment(SavedPlannerStore.self) private var store
  let appearance: PlannerAppearance
  let isReviewingDeletion: Bool
  @State private var item: PlannerAppearanceRead?
  @State private var failure: String?

  var body: some View {
    Group {
      if let item {
        Form {
          Section {
            Text(item.content.title).font(.title2).fontWeight(.semibold)
            Label(
              item.effectiveDone ? "Completed" : "To do",
              systemImage: item.effectiveDone ? "checkmark.circle.fill" : "circle")
            if item.archived { Label("Archived", systemImage: "archivebox") }
            if let subtitle = item.content.subtitle, !subtitle.isEmpty {
              Text(subtitle).foregroundStyle(.secondary)
            }
          }
          if let notes = item.content.notes, !notes.isEmpty {
            Section("Notes") { Text(notes).textSelection(.enabled) }
          }
          SavedItemEstimateSection(estimate: item.content.estimate)
          ItemLabelsSection(labels: item.labels)
          ItemLocationSection(
            title: item.content.title, location: item.content.location,
            previewSource: previewSource(item), links: item.content.links)
          ItemLinksSection(
            links: item.content.links, source: item.source,
            sourceLifetimeId: item.sourceLifetimeId, appearance: item.appearance)
        }
        .formStyle(.grouped)
        .navigationTitle(item.content.title)
        .toolbarTitleDisplayMode(.inline)
      } else if let failure {
        ContentUnavailableView {
          Label("Item unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(failure)
        } actions: {
          Button("Try again") { Task { await loadItem() } }
        }
      } else {
        ProgressView("Opening Item")
      }
    }
    .task(id: store.changeRevision) { await loadItem() }
    .onChange(of: isReviewingDeletion) {
      if !isReviewingDeletion { Task { await loadItem() } }
    }
  }

  private func loadItem() async {
    guard !isReviewingDeletion else { return }
    let revision = store.changeRevision
    let loaded = await store.readAppearance(appearance)
    guard !Task.isCancelled, !isReviewingDeletion, store.changeRevision == revision else { return }
    item = loaded
    failure = loaded == nil ? store.alertMessage ?? "This Item is no longer in the Itinerary." : nil
    if loaded == nil { store.alertMessage = nil }
  }

  private func previewSource(_ item: PlannerAppearanceRead) -> PlannerPreviewSource? {
    guard let namespace = store.devicePreferenceNamespace else { return nil }
    return .init(
      namespace: namespace, sourceId: item.source.id, sourceLifetimeId: item.sourceLifetimeId)
  }
}

struct SavedAddItineraryEntryForm: View {
  private struct LoadIdentity: Equatable {
    let namespace: String?
    let revision: UUID
    let itineraryIdentifier: UUID
    let retryIdentifier: UUID
  }

  private struct VisibleReadIdentity: Equatable {
    let loadIdentity: LoadIdentity
    let sourcesAreReady: Bool
    let visibleIdentifiers: Set<UUID>
  }

  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let itineraryId: UUID
  @State private var window: SavedItemWindow?
  @State private var visibleIdentifiers: Set<UUID> = []
  @State private var hasDisplayedItems = false
  @State private var listWindow: SavedItemWindow?
  @State private var selection: String?
  @State private var failure: String?
  @State private var retryIdentifier = UUID()
  @State private var loadedIdentity: LoadIdentity?
  @State private var operationIdentifier = UUID()

  private var loadIdentity: LoadIdentity {
    .init(
      namespace: store.devicePreferenceNamespace, revision: store.changeRevision,
      itineraryIdentifier: itineraryId, retryIdentifier: retryIdentifier)
  }

  private var sourcesAreReady: Bool {
    loadedIdentity == loadIdentity && window?.state == .ready && listWindow?.state == .ready
      && failure == nil
  }

  private var visibleReadIdentity: VisibleReadIdentity {
    .init(
      loadIdentity: loadIdentity, sourcesAreReady: sourcesAreReady,
      visibleIdentifiers: visibleIdentifiers)
  }

  private var sourceRows: [(index: Int, identifier: UUID, selectionTag: String)] {
    guard let window else { return [] }
    return window.rowIdentities.enumerated().compactMap { index, identity in
      guard case .source(let source) = identity, source.kind == .item else { return nil }
      return (index, source.id, "item.\(source.id.uuidString)")
    }
  }

  private var selectedSource: PlannerEntityReference? {
    guard sourcesAreReady else { return nil }
    if let item = sourceRows.first(where: { selection == "item.\($0.identifier.uuidString)" }) {
      return .init(kind: .item, id: item.identifier)
    }
    return listWindow?.rowIdentities.compactMap { identity -> PlannerEntityReference? in
      guard case .source(let source) = identity, source.kind == .list,
        selection == "list.\(source.id.uuidString)"
      else { return nil }
      return source
    }.first
  }

  var body: some View {
    NavigationStack {
      List(selection: $selection) {
        Section("Items") {
          if let window {
            ForEach(sourceRows, id: \.selectionTag) { index, identifier, selectionTag in
              let presentation = window.presentation(at: index)
              let hasLoadedPresentation =
                switch presentation {
                case .loaded(let presentation)
                where presentation.row.identity == .source(.init(kind: .item, id: identifier)): true
                case .loading, .failed, .loaded: false
                }
              itemChoice(presentation, index: index, identifier: identifier)
                .tag(selectionTag)
                .selectionDisabled(!hasLoadedPresentation)
                .onScrollVisibilityChange { visible in
                  if visible {
                    hasDisplayedItems = true
                    visibleIdentifiers.insert(identifier)
                  } else {
                    visibleIdentifiers.remove(identifier)
                  }
                }
            }
          }
        }
        Section("Lists") {
          if let listWindow {
            SavedContainerWindowRows(
              window: listWindow, sourceKind: .list, selectionTag: { "list.\($0.id.uuidString)" }
            ) { row in
              if case .source(let source) = row.identity {
                Label(row.title, systemImage: "list.bullet.rectangle")
                  .accessibilityLabel(row.title)
                  .accessibilityIdentifier(
                    "saved.itinerary.entry.choice.list.\(source.id.uuidString)")
              }
            }
          }
        }
      }
      .accessibilityIdentifier("saved.itinerary.entry.choices")
      .disabled(store.isSaving)
      .overlay { pickerStatus }
      .navigationTitle("Add to Itinerary")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.itinerary.entry.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            guard let selectedSource else { return }
            let identity = loadIdentity
            Task {
              guard !Task.isCancelled, loadIdentity == identity,
                self.selectedSource == selectedSource
              else { return }
              let saved = await store.addItineraryEntry(
                itineraryId: itineraryId, source: selectedSource,
                operationIdentifier: operationIdentifier)
              if saved && store.alertMessage == nil { dismiss() }
            }
          }
          .disabled(!store.canCreate || selectedSource == nil)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.itinerary.entry.add")
        }
      }
    }
    .task(id: loadIdentity) { await loadSources(identity: loadIdentity) }
    .task(id: visibleReadIdentity) {
      guard sourcesAreReady, let window, hasDisplayedItems || !visibleIdentifiers.isEmpty else {
        return
      }
      let indices = Set(
        sourceRows.filter { visibleIdentifiers.contains($0.identifier) }.map(\.index))
      await window.requestRows(at: indices)
    }
    .onDisappear {
      window?.cancel()
      listWindow?.cancel()
      visibleIdentifiers = []
      hasDisplayedItems = false
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
      .frame(minWidth: 440, minHeight: 400)
    #endif
  }

  @ViewBuilder
  private func itemChoice(_ presentation: SavedItemWindowPresentation, index: Int, identifier: UUID)
    -> some View
  {
    switch presentation {
    case .loaded(let presentation)
    where presentation.row.identity == .source(.init(kind: .item, id: identifier)):
      let item = SavedPlannerItem(
        id: identifier, row: presentation.row, rowPresentation: presentation.rowPresentation)
      Label(item.row.title, systemImage: "square.stack")
        .accessibilityLabel(item.row.title)
        .accessibilityIdentifier("saved.itinerary.entry.choice.item.\(item.id.uuidString)")
    case .loading, .loaded:
      ProgressView("Loading Item")
    case .failed(let reason):
      VStack(alignment: .leading) {
        Text(reason).foregroundStyle(.secondary)
        Button("Try again") { Task { await window?.requestRows(at: [index]) } }
      }
    }
  }

  @ViewBuilder
  private var pickerStatus: some View {
    if let failure {
      failureContent(failure)
    } else if case .failed(let reason) = listWindow?.state {
      failureContent(reason)
    } else {
      switch window?.state ?? .idle {
      case .idle, .loading: ProgressView("Loading Items and Lists")
      case .failed(let reason): failureContent(reason)
      case .ready:
        if !sourcesAreReady {
          ProgressView("Loading Items and Lists")
        } else if window?.matchingCount == 0 && listWindow?.matchingCount == 0 {
          ContentUnavailableView("No Items or Lists yet", systemImage: "square.stack")
        } else if store.isSaving {
          ProgressView("Adding entry")
        }
      }
    }
  }

  private func failureContent(_ reason: String) -> some View {
    ContentUnavailableView {
      Label("Entries unavailable", systemImage: "exclamationmark.triangle")
    } description: {
      Text(reason)
    } actions: {
      Button("Try again") { retryIdentifier = UUID() }
        .accessibilityIdentifier("saved.itinerary.entry.retry")
    }
  }

  private func loadSources(identity: LoadIdentity) async {
    guard !Task.isCancelled else { return }
    window?.cancel()
    listWindow?.cancel()
    listWindow = nil
    visibleIdentifiers = []
    hasDisplayedItems = false
    failure = nil
    loadedIdentity = nil
    guard let namespace = identity.namespace, let window = store.makeItemWindow() else {
      self.window = nil
      failure = "Planner is not ready to load its entries."
      return
    }
    self.window = window
    await window.reload(
      query: .init(completion: .all, archive: .active),
      identity: .init(namespace: namespace, savedRevision: identity.revision))
    guard !Task.isCancelled, loadIdentity == identity, self.window === window,
      window.state == .ready
    else { return }
    guard let listWindow = store.makeItemWindow() else {
      failure = "Planner is not ready to load its Lists."
      return
    }
    self.listWindow = listWindow
    await listWindow.reload(
      catalogQuery: .init(sourceKind: .list, archive: .active),
      identity: .init(namespace: namespace, savedRevision: identity.revision))
    guard !Task.isCancelled, loadIdentity == identity, self.window === window,
      self.listWindow === listWindow, window.state == .ready, listWindow.state == .ready
    else { return }
    loadedIdentity = identity
    if selection != nil, selectedSource == nil {
      selection = nil
    }
  }

}
