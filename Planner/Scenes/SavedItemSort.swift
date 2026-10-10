import Foundation
import Observation
import PlannerCore
import SwiftUI

struct SavedItemSort: Equatable {
  let mode: PlannerItemQuery.Sort.Mode
  let direction: PlannerItemQuery.Sort.Direction

  init(
    mode: PlannerItemQuery.Sort.Mode = .title,
    direction: PlannerItemQuery.Sort.Direction = .ascending
  ) {
    self.mode = mode
    self.direction = mode == .manual ? .ascending : direction
  }

  var queryValue: PlannerItemQuery.Sort { .init(mode: mode, direction: direction) }

  var title: String {
    switch mode {
    case .title: "Title"
    case .created: "Created"
    case .lastUpdated: "Last updated"
    case .duration: "Duration"
    case .manual: "Manual"
    }
  }

  var summary: String {
    if mode == .manual { return title }
    return "\(title) · \(direction.rawValue.capitalized)"
  }
}

@MainActor @Observable
final class SavedItemSortPreferences {
  private var selections: [String: SavedItemSort] = [:]

  func selection(for key: String?, default defaultValue: SavedItemSort) -> SavedItemSort {
    guard let key else { return defaultValue }
    if let selection = selections[key] { return selection }
    guard let saved = UserDefaults.standard.dictionary(forKey: key),
      let modeValue = saved["mode"] as? String,
      let directionValue = saved["direction"] as? String,
      let mode = PlannerItemQuery.Sort.Mode(rawValue: modeValue),
      let direction = PlannerItemQuery.Sort.Direction(rawValue: directionValue),
      mode != .manual || defaultValue.mode == .manual
    else { return defaultValue }
    return SavedItemSort(mode: mode, direction: direction)
  }

  func select(_ selection: SavedItemSort, for key: String?) {
    guard let key else { return }
    UserDefaults.standard.set(
      ["mode": selection.mode.rawValue, "direction": selection.direction.rawValue], forKey: key)
    selections[key] = selection
  }
}

struct SavedItemSortMenu: View {
  @Binding var sort: SavedItemSort
  var allowsManual = false
  let accessibilityIdentifier: String

  var body: some View {
    Menu {
      Picker(
        "Sort by",
        selection: Binding(
          get: { sort.mode },
          set: { sort = SavedItemSort(mode: $0, direction: sort.direction) })
      ) {
        if allowsManual { Text("Manual").tag(PlannerItemQuery.Sort.Mode.manual) }
        Text("Title").tag(PlannerItemQuery.Sort.Mode.title)
        Text("Created").tag(PlannerItemQuery.Sort.Mode.created)
        Text("Last updated").tag(PlannerItemQuery.Sort.Mode.lastUpdated)
        Text("Duration").tag(PlannerItemQuery.Sort.Mode.duration)
      }
      .pickerStyle(.inline)
      if sort.mode != .manual {
        Divider()
        Picker(
          "Direction",
          selection: Binding(
            get: { sort.direction },
            set: { sort = SavedItemSort(mode: sort.mode, direction: $0) })
        ) {
          Text("Ascending").tag(PlannerItemQuery.Sort.Direction.ascending)
          Text("Descending").tag(PlannerItemQuery.Sort.Direction.descending)
        }
        .pickerStyle(.inline)
      }
    } label: {
      Label("Sort: \(sort.summary)", systemImage: "arrow.up.arrow.down")
    }
    .labelStyle(.iconOnly)
    .accessibilityIdentifier(accessibilityIdentifier)
    .help("Sort: \(sort.summary)")
  }
}
