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

  var completion: Completion = .all
  var archive: Archive = .all

  var summary: String {
    let restrictions = [completion.rawValue, archive.rawValue]
      .filter { $0 != "all" }.map { $0.capitalized }
    return restrictions.isEmpty ? "All" : restrictions.joined(separator: " · ")
  }
}

struct SavedItemFilterMenu: View {
  @Binding var filters: SavedItemFilters
  let accessibilityIdentifier: String

  var body: some View {
    Menu {
      Picker("Completion", selection: $filters.completion) {
        Text("Todo").tag(SavedItemFilters.Completion.todo)
        Text("Done").tag(SavedItemFilters.Completion.done)
        Text("All completion states").tag(SavedItemFilters.Completion.all)
      }
      .pickerStyle(.inline)
      Divider()
      Picker("Archive", selection: $filters.archive) {
        Text("Active").tag(SavedItemFilters.Archive.active)
        Text("Archived").tag(SavedItemFilters.Archive.archived)
        Text("All archive states").tag(SavedItemFilters.Archive.all)
      }
      .pickerStyle(.inline)
    } label: {
      Text(filters.summary)
        .fixedSize(horizontal: true, vertical: false)
    }
    .accessibilityLabel(filters.summary)
    .accessibilityIdentifier(accessibilityIdentifier)
    .help("Filters: \(filters.summary)")
  }
}

struct SavedListProgress: View {
  let progress: PlannerContainerProgress
  let matchingCount: Int

  var body: some View {
    if let done = progress.doneCount, let total = progress.totalCount, total > 0 {
      let unit = total == 1 ? "item" : "items"
      VStack(alignment: .leading, spacing: 6) {
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
