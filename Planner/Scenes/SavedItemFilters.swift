import PlannerCore
import SwiftUI

struct SavedItemFilters: Equatable {
  enum Completion: String {
    case todo, done, all

    var queryValue: PlannerItemQuery.Completion {
      switch self {
      case .todo: .todo
      case .done: .done
      case .all: .all
      }
    }
  }

  enum Archive: String {
    case active, archived, all

    var queryValue: PlannerItemQuery.Archive {
      switch self {
      case .active: .active
      case .archived: .archived
      case .all: .all
      }
    }
  }

  enum LabelMatch: String {
    case any, all

    var queryValue: PlannerItemQuery.IdentityGroup.Match {
      self == .any ? .any : .all
    }
  }

  var completion: Completion = .all
  var archive: Archive = .all
  var maximumDuration: PlannerEstimate?
  var includeUnknownEstimates = false
  var scheduled: PlannerItemQuery.Scheduling = .all
  var categoryIdentifiers: Set<UUID> = []
  var tagIdentifiers: Set<UUID> = []
  var listIdentifiers: Set<UUID> = []
  var categoryMatch: LabelMatch = .any
  var tagMatch: LabelMatch = .any
  var listMatch: PlannerItemQuery.IdentityGroup.Match = .any
  var hasAddress = false
  var hasLinks = false

  func itemQuery(scope: PlannerItemQuery.Scope, text: String, sort: SavedItemSort)
    -> PlannerItemQuery
  {
    .init(
      scope: scope, text: text, completion: completion.queryValue, archive: archive.queryValue,
      categories: categoryQuery, tags: tagQuery, lists: listQuery, duration: durationQuery,
      hasAddress: hasAddress, hasLinks: hasLinks, scheduled: scheduled, sort: sort.queryValue)
  }

  var hasItemOnlyRestrictions: Bool {
    !categoryIdentifiers.isEmpty || !tagIdentifiers.isEmpty || !listIdentifiers.isEmpty
      || maximumDuration != nil || hasAddress || hasLinks || scheduled != .all
  }

  var durationQuery: PlannerItemQuery.Duration? {
    guard let maximumDuration else { return nil }
    return .init(
      maximumMinutes: maximumDuration.minutes, includeUnknown: includeUnknownEstimates)
  }

  var categoryQuery: PlannerItemQuery.IdentityGroup? {
    guard !categoryIdentifiers.isEmpty else { return nil }
    return .init(ids: categoryIdentifiers, match: categoryMatch.queryValue)
  }

  var tagQuery: PlannerItemQuery.IdentityGroup? {
    guard !tagIdentifiers.isEmpty else { return nil }
    return .init(ids: tagIdentifiers, match: tagMatch.queryValue)
  }

  var listQuery: PlannerItemQuery.IdentityGroup? {
    guard !listIdentifiers.isEmpty else { return nil }
    return .init(ids: listIdentifiers, match: listMatch)
  }

  var summary: String {
    var restrictions = [completion.rawValue, archive.rawValue]
      .filter { $0 != "all" }.map { $0.capitalized }
    if scheduled != .all { restrictions.append(scheduled.rawValue.capitalized) }
    if let maximumDuration {
      restrictions.append("Up to \(maximumDuration.nativeEstimateDescription)")
      if includeUnknownEstimates { restrictions.append("Unknown estimates") }
    }
    if !categoryIdentifiers.isEmpty {
      if categoryIdentifiers.count == 1 {
        restrictions.append("1 Category")
      } else if categoryMatch == .all {
        restrictions.append("All \(categoryIdentifiers.count) Categories")
      } else {
        restrictions.append("\(categoryIdentifiers.count) Categories")
      }
    }
    if !tagIdentifiers.isEmpty {
      if tagIdentifiers.count == 1 {
        restrictions.append("1 Tag")
      } else if tagMatch == .all {
        restrictions.append("All \(tagIdentifiers.count) Tags")
      } else {
        restrictions.append("\(tagIdentifiers.count) Tags")
      }
    }
    if !listIdentifiers.isEmpty {
      if listIdentifiers.count == 1 {
        restrictions.append("1 List")
      } else if listMatch == .all {
        restrictions.append("All \(listIdentifiers.count) Lists")
      } else {
        restrictions.append("\(listIdentifiers.count) Lists")
      }
    }
    if hasAddress { restrictions.append("Address") }
    if hasLinks { restrictions.append("Links") }
    return restrictions.isEmpty ? "All" : restrictions.joined(separator: " · ")
  }
}

struct SavedItemFilterControl: View {
  @Environment(SavedPlannerStore.self) private var store
  @Binding var filters: SavedItemFilters
  let accessibilityIdentifier: String
  var showsSummary = true
  @State private var showFilters = false

  var body: some View {
    Button {
      showFilters = true
    } label: {
      Label {
        if showsSummary { Text(filters.summary) }
      } icon: {
        Image(systemName: "line.3.horizontal.decrease")
      }
      .labelStyle(.titleAndIcon)
      #if os(macOS)
        .lineLimit(1)
        .padding(.horizontal, 6)
      #else
        .fixedSize(horizontal: true, vertical: false)
      #endif
    }
    .accessibilityLabel(filters.summary)
    .accessibilityIdentifier(accessibilityIdentifier)
    .help("Filters: \(filters.summary)")
    .popover(isPresented: $showFilters) {
      SavedItemFilterForm(store: store, filters: $filters)
        #if os(iOS)
          .presentationCompactAdaptation(.sheet)
          .presentationDetents([.large])
        #endif
    }
  }
}

private struct SavedItemFilterForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @Binding var filters: SavedItemFilters

  var body: some View {
    NavigationStack {
      Form {
        Section("State") {
          Picker("Completion", selection: $filters.completion) {
            Text("Todo").tag(SavedItemFilters.Completion.todo)
            Text("Done").tag(SavedItemFilters.Completion.done)
            Text("All completion states").tag(SavedItemFilters.Completion.all)
          }
          .pickerStyle(.menu)
          .accessibilityIdentifier("saved.filters.completion")
          Picker("Archive", selection: $filters.archive) {
            Text("Active").tag(SavedItemFilters.Archive.active)
            Text("Archived").tag(SavedItemFilters.Archive.archived)
            Text("All archive states").tag(SavedItemFilters.Archive.all)
          }
          .pickerStyle(.menu)
          .accessibilityIdentifier("saved.filters.archive")
          Picker("Scheduling", selection: $filters.scheduled) {
            Text("Scheduled").tag(PlannerItemQuery.Scheduling.scheduled)
            Text("Unscheduled").tag(PlannerItemQuery.Scheduling.unscheduled)
            Text("All scheduling states").tag(PlannerItemQuery.Scheduling.all)
          }
          .pickerStyle(.menu)
          .accessibilityIdentifier("saved.filters.scheduled")
        }
        SavedActivityEstimateEditor(
          estimate: $filters.maximumDuration,
          accessibilityIdentifierPrefix: "saved.filters.duration", purpose: .maximumDuration)
        if filters.maximumDuration != nil {
          Section {
            Toggle("Include unknown estimates", isOn: $filters.includeUnknownEstimates)
              .accessibilityIdentifier("saved.filters.duration.includeUnknown")
          } footer: {
            Text(
              "The maximum includes its exact duration. Items without an estimate are excluded unless included here."
            )
          }
        }
        Section("Categories") {
          NavigationLink {
            SavedItemLabelPicker(
              store: store, kind: .category, selection: $filters.categoryIdentifiers)
          } label: {
            LabeledContent("Categories", value: selectionSummary(filters.categoryIdentifiers))
          }
          .accessibilityIdentifier("saved.filters.categories")
          if !filters.categoryIdentifiers.isEmpty {
            matchPicker(.category, selection: $filters.categoryMatch)
            Button("Clear categories") { filters.categoryIdentifiers = [] }
          }
        }
        Section("Tags") {
          NavigationLink {
            SavedItemLabelPicker(store: store, kind: .tag, selection: $filters.tagIdentifiers)
          } label: {
            LabeledContent("Tags", value: selectionSummary(filters.tagIdentifiers))
          }
          .accessibilityIdentifier("saved.filters.tags")
          if !filters.tagIdentifiers.isEmpty {
            matchPicker(.tag, selection: $filters.tagMatch)
            Button("Clear tags") { filters.tagIdentifiers = [] }
          }
        }
        Section("Lists") {
          NavigationLink {
            SavedFilterListPicker(store: store, selection: $filters.listIdentifiers)
          } label: {
            LabeledContent("In Lists", value: selectionSummary(filters.listIdentifiers))
          }
          .accessibilityIdentifier("saved.filters.lists")
          if !filters.listIdentifiers.isEmpty {
            Picker("Match", selection: $filters.listMatch) {
              Text("Any selected").tag(PlannerItemQuery.IdentityGroup.Match.any)
              Text("All selected").tag(PlannerItemQuery.IdentityGroup.Match.all)
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("saved.filters.list.match")
            Button("Clear lists") { filters.listIdentifiers = [] }
          }
        }
        Section("Content") {
          Toggle("Has an address", isOn: $filters.hasAddress)
            .accessibilityIdentifier("saved.filters.hasAddress")
          Toggle("Has links", isOn: $filters.hasLinks)
            .accessibilityIdentifier("saved.filters.hasLinks")
        }
      }
      .formStyle(.grouped)
      .accessibilityIdentifier("saved.filters.form")
      .navigationTitle("Filters")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Clear filters") { filters = .init() }
            .disabled(filters == SavedItemFilters())
            .accessibilityIdentifier("saved.filters.clear")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("saved.filters.done")
        }
      }
    }
    .frame(minWidth: 320, idealWidth: 360, minHeight: 420)
  }

  private func matchPicker(
    _ kind: SavedLabelKind, selection: Binding<SavedItemFilters.LabelMatch>
  ) -> some View {
    Picker("Match", selection: selection) {
      Text("Any selected").tag(SavedItemFilters.LabelMatch.any)
      Text("All selected").tag(SavedItemFilters.LabelMatch.all)
    }
    .pickerStyle(.menu)
    .accessibilityIdentifier("saved.filters.\(kind.rawValue).match")
  }

  private func selectionSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "Any" : "\(identifiers.count) selected"
  }
}

private struct SavedFilterListPicker: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @Binding var selection: Set<UUID>
  @State private var window: SavedItemWindow?
  @State private var loadedIdentity: SavedItemWindowIdentity?
  @State private var loadingFailure: String?

  var body: some View {
    List {
      if let window {
        SavedContainerWindowRows(window: window, sourceKind: .list, selectionTag: { $0.id }) {
          row in
          if case .source(let source) = row.identity {
            Toggle(
              isOn: Binding(
                get: { selection.contains(source.id) },
                set: { selected in
                  if selected {
                    selection.insert(source.id)
                  } else {
                    selection.remove(source.id)
                  }
                })
            ) {
              VStack(alignment: .leading) {
                Text(row.title)
                if row.archived == true {
                  Label("Archived", systemImage: "archivebox")
                    .font(.caption).foregroundStyle(.secondary)
                }
              }
            }
            .accessibilityLabel(row.title)
            .accessibilityHint(row.archived == true ? "Archived List" : "Active List")
            .accessibilityIdentifier("saved.filters.list.\(source.id.uuidString)")
          }
        }
      }
    }
    .accessibilityIdentifier("saved.filters.list.choices")
    .overlay {
      if let loadingFailure = catalogFailure {
        ContentUnavailableView {
          Label("Lists unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try again") { Task { await loadLists() } }
        }
      } else if window?.state != .ready || loadedIdentity != loadIdentity {
        ProgressView("Loading Lists")
      } else if window?.matchingCount == 0 {
        ContentUnavailableView(
          "No Lists yet", systemImage: "list.bullet.rectangle",
          description: Text("Create a List to filter its Items."))
      }
    }
    .navigationTitle("Lists")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") { dismiss() }
          .accessibilityIdentifier("saved.filters.lists.done")
      }
    }
    .task(id: loadIdentity) { await loadLists() }
    .onDisappear { window?.cancel() }
  }

  private var loadIdentity: SavedItemWindowIdentity? {
    guard let namespace = store.devicePreferenceNamespace else { return nil }
    return .init(namespace: namespace, savedRevision: store.changeRevision)
  }

  private var catalogFailure: String? {
    if case .failed(let reason) = window?.state { return reason }
    return loadingFailure
  }

  private func loadLists() async {
    guard !Task.isCancelled else { return }
    let identity = loadIdentity
    window?.cancel()
    loadedIdentity = nil
    loadingFailure = nil
    guard let identity, let window = store.makeItemWindow() else {
      self.window = nil
      loadingFailure = "Planner is not ready to load its Lists."
      return
    }
    self.window = window
    await window.reload(catalogQuery: .init(sourceKind: .list, archive: .all), identity: identity)
    guard !Task.isCancelled, loadIdentity == identity, self.window === window else { return }
    loadedIdentity = identity
  }
}

struct SavedCatalogArchiveFilterMenu: View {
  @Binding var archive: SavedItemFilters.Archive
  let pluralTitle: String
  let accessibilityIdentifier: String

  private var title: String {
    archive == .all ? "All \(pluralTitle)" : "\(archive.rawValue.capitalized) \(pluralTitle)"
  }

  var body: some View {
    Menu {
      Picker("Archive", selection: $archive) {
        Text("Active \(pluralTitle)").tag(SavedItemFilters.Archive.active)
        Text("Archived \(pluralTitle)").tag(SavedItemFilters.Archive.archived)
        Text("All \(pluralTitle)").tag(SavedItemFilters.Archive.all)
      }
      .pickerStyle(.inline)
    } label: {
      Label(title, systemImage: "line.3.horizontal.decrease")
    }
    .labelStyle(.iconOnly)
    .accessibilityLabel(title)
    .accessibilityIdentifier(accessibilityIdentifier)
    .help("Show \(title.lowercased())")
  }
}

struct SavedListProgress: View {
  var listName: String? = nil
  let progress: PlannerContainerProgress
  let estimates: PlannerContainerEstimates
  let manualEstimate: PlannerEstimate?
  let matchingCount: Int
  var isArchived = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let listName {
        Text(listName)
          .font(.title2.bold())
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
      }
      if isArchived {
        Label("Archived List", systemImage: "archivebox").foregroundStyle(Color.secondary)
      }
      SavedContainerEstimates(
        estimates: estimates, manualEstimate: manualEstimate,
        accessibilityIdentifierPrefix: "saved.list.estimate")
      if let done = progress.doneCount, let archived = progress.archivedCount,
        let total = progress.totalCount, total > 0
      {
        let unit = total == 1 ? "item" : "items"
        SavedCompletionProgress(
          doneCount: done, archivedCount: archived, totalCount: total,
          accessibilityIdentifier: "saved.list.progress")
        if Int64(matchingCount) < total {
          Text("Showing \(matchingCount) of \(total) \(unit)")
            .font(.caption).foregroundStyle(Color.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SavedCompletionProgress: View {
  let doneCount: Int64
  let archivedCount: Int64
  let totalCount: Int64
  let accessibilityIdentifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      let unit = totalCount == 1 ? "item" : "items"
      let finishedCount = doneCount + archivedCount
      ProgressView(value: Double(finishedCount), total: Double(totalCount)) {
        if archivedCount > 0 {
          Text("\(finishedCount) of \(totalCount) \(unit) finished")
            .foregroundStyle(Color.primary)
        } else {
          Text("\(doneCount) of \(totalCount) \(unit) done")
            .foregroundStyle(Color.primary)
        }
      }
      .accessibilityIdentifier(accessibilityIdentifier)
      if archivedCount > 0 {
        Text("\(doneCount) done · \(archivedCount) archived")
          .font(.caption).foregroundStyle(Color.secondary)
      }
    }
  }
}
