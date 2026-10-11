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
  var categoryIdentifiers: Set<UUID> = []
  var tagIdentifiers: Set<UUID> = []
  var listIdentifiers: Set<UUID> = []
  var categoryMatch: LabelMatch = .any
  var tagMatch: LabelMatch = .any
  var listMatch: PlannerItemQuery.IdentityGroup.Match = .any
  var hasAddress = false
  var hasLinks = false

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
  @State private var showFilters = false

  var body: some View {
    Button {
      showFilters = true
    } label: {
      Label(filters.summary, systemImage: "line.3.horizontal.decrease")
        .labelStyle(.titleAndIcon)
        .fixedSize(horizontal: true, vertical: false)
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
            Button("Clear Categories") { filters.categoryIdentifiers = [] }
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
            Button("Clear Tags") { filters.tagIdentifiers = [] }
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
            Button("Clear Lists") { filters.listIdentifiers = [] }
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
          Button("Clear Filters") { filters = .init() }
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
  @State private var lists: [SavedPlannerList]?
  @State private var loadingFailure: String?

  var body: some View {
    List {
      ForEach(lists ?? []) { list in
        Toggle(
          isOn: Binding(
            get: { selection.contains(list.id) },
            set: { selected in
              if selected {
                selection.insert(list.id)
              } else {
                selection.remove(list.id)
              }
            })
        ) {
          VStack(alignment: .leading) {
            Text(list.name)
            if list.archived {
              Label("Archived", systemImage: "archivebox")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        .accessibilityLabel(list.name)
        .accessibilityHint(list.archived ? "Archived List" : "Active List")
        .accessibilityIdentifier("saved.filters.list.\(list.id.uuidString)")
      }
    }
    .overlay {
      if let loadingFailure {
        ContentUnavailableView {
          Label("Lists unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try Again") { Task { await loadLists() } }
        }
      } else if lists == nil {
        ProgressView("Loading Lists")
      } else if lists?.isEmpty == true {
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
    .task(id: store.changeRevision) { await loadLists() }
  }

  private func loadLists() async {
    let revision = store.changeRevision
    loadingFailure = nil
    let loaded = await store.readLists(archive: .all)
    guard !Task.isCancelled, revision == store.changeRevision else { return }
    lists = loaded
    if loaded == nil {
      loadingFailure = store.alertMessage ?? "Planner could not load its Lists."
      store.alertMessage = nil
    }
  }
}

struct SavedListArchiveFilterMenu: View {
  @Binding var archive: SavedItemFilters.Archive

  private var title: String {
    archive == .all ? "All Lists" : "\(archive.rawValue.capitalized) Lists"
  }

  var body: some View {
    Menu {
      Picker("Archive", selection: $archive) {
        Text("Active Lists").tag(SavedItemFilters.Archive.active)
        Text("Archived Lists").tag(SavedItemFilters.Archive.archived)
        Text("All Lists").tag(SavedItemFilters.Archive.all)
      }
      .pickerStyle(.inline)
    } label: {
      Text(archive.rawValue.capitalized).fixedSize(horizontal: true, vertical: false)
    }
    .accessibilityLabel(title)
    .accessibilityIdentifier("saved.lists.archive")
    .help("Show \(title.lowercased())")
  }
}

struct SavedListProgress: View {
  let progress: PlannerContainerProgress
  let matchingCount: Int
  var isArchived = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if isArchived {
        Label("Archived List", systemImage: "archivebox").foregroundStyle(.secondary)
      }
      if let done = progress.doneCount, let total = progress.totalCount, total > 0 {
        let unit = total == 1 ? "item" : "items"
        ProgressView(value: Double(done), total: Double(total)) {
          Text("\(done) of \(total) \(unit) done")
        }
        .accessibilityIdentifier("saved.list.progress")
        if Int64(matchingCount) < total {
          Text("Showing \(matchingCount) of \(total) \(unit)")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
}
