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

struct SavedItineraryEntryRows: Identifiable {
  let id: UUID
  let source: PlannerEntityReference
  let title: String
  let items: [SavedItineraryItem]
  let matchesHeader: Bool
  let isArchived: Bool
  let listSummary: PlannerItineraryListEntrySummary?
}

struct SavedItineraryContents {
  let itinerary: PlannerItinerarySourceRead
  let entries: [SavedItineraryEntryRows]
  let matchingItemIdentifiers: Set<SavedItineraryRowSelection>

  var visibleEntries: [SavedItineraryEntryRows] {
    entries.filter { entry in
      entry.matchesHeader || entry.items.contains { matchingItemIdentifiers.contains($0.id) }
    }
  }
}

struct SavedItineraryItemRow: View {
  let item: SavedItineraryItem
  let canChange: Bool
  let toggleCompletion: () -> Void

  var body: some View {
    HStack {
      Button(action: toggleCompletion) {
        Label(
          completionLabel,
          systemImage: item.row.effectiveDone == true ? "checkmark.circle.fill" : "circle")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
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
        Image(systemName: "archivebox").accessibilityLabel("Archived")
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
            links: item.content.links, sourceId: item.source.id,
            sourceLifetimeId: item.sourceLifetimeId)
        }
        .formStyle(.grouped)
        .navigationTitle(item.content.title)
      } else if let failure {
        ContentUnavailableView {
          Label("Item unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(failure)
        } actions: {
          Button("Try Again") { Task { await loadItem() } }
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
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let itineraryId: UUID
  @State private var items: [SavedPlannerItem]?
  @State private var lists: [SavedPlannerList]?
  @State private var selection: String?
  @State private var failure: String?
  @State private var operationIdentifier = UUID()

  private var selectedSource: PlannerEntityReference? {
    if let item = items?.first(where: { selection == "item.\($0.id.uuidString)" }) {
      return .init(kind: .item, id: item.id)
    }
    return lists?.first { selection == "list.\($0.id.uuidString)" }?.source
  }

  var body: some View {
    NavigationStack {
      List(selection: $selection) {
        Section("Items") {
          ForEach(items ?? []) { item in
            Label(item.row.title, systemImage: "square.stack")
              .tag("item.\(item.id.uuidString)")
              .accessibilityLabel(item.row.title)
              .accessibilityIdentifier("saved.itinerary.entry.choice.item.\(item.id.uuidString)")
          }
        }
        Section("Lists") {
          ForEach(lists ?? []) { list in
            Label(list.name, systemImage: "list.bullet.rectangle")
              .tag("list.\(list.id.uuidString)")
              .accessibilityLabel(list.name)
              .accessibilityIdentifier("saved.itinerary.entry.choice.list.\(list.id.uuidString)")
          }
        }
      }
      .disabled(store.isSaving)
      .overlay {
        if let failure {
          ContentUnavailableView {
            Label("Entries unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(failure)
          } actions: {
            Button("Try Again") { Task { await loadSources() } }
          }
        } else if items == nil || lists == nil {
          ProgressView("Loading Items and Lists")
        } else if items?.isEmpty == true && lists?.isEmpty == true {
          ContentUnavailableView("No Items or Lists yet", systemImage: "square.stack")
        } else if store.isSaving {
          ProgressView("Adding entry")
        }
      }
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
            Task {
              let saved = await store.addItineraryEntry(
                itineraryId: itineraryId, source: selectedSource,
                operationIdentifier: operationIdentifier)
              if saved && store.alertMessage == nil { dismiss() }
            }
          }
          .disabled(!store.canCreate || selectedSource == nil || failure != nil)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.itinerary.entry.add")
        }
      }
    }
    .task { await loadSources() }
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

  private func loadSources() async {
    failure = nil
    let availableItems = await store.readItems(completion: .all, archive: .active)
    guard !Task.isCancelled else { return }
    let availableLists = await store.readLists(archive: .active)
    guard !Task.isCancelled else { return }
    items = availableItems
    lists = availableLists
    if items == nil || lists == nil {
      failure = store.alertMessage ?? "Planner could not load entries."
      store.alertMessage = nil
    }
  }
}
