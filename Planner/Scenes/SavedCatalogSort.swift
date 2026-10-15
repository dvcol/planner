import Foundation
import Observation
import PlannerCore
import SwiftUI

struct SavedCatalogSort: Equatable {
  var mode: PlannerCatalogQuery.Sort.Mode = .title
  var direction: PlannerCatalogQuery.Sort.Direction = .ascending

  var queryValue: PlannerCatalogQuery.Sort { .init(mode: mode, direction: direction) }

  var title: String {
    switch mode {
    case .title: "Title"
    case .created: "Created"
    case .lastUpdated: "Last updated"
    case .fullEstimate: "Full estimate"
    }
  }

  var summary: String { "\(title) · \(direction.rawValue.capitalized)" }
}

@MainActor @Observable
final class SavedCatalogSortPreferences {
  private var selections: [String: SavedCatalogSort] = [:]

  func selection(for key: String?) -> SavedCatalogSort {
    guard let key else { return SavedCatalogSort() }
    if let selection = selections[key] { return selection }
    guard let saved = UserDefaults.standard.dictionary(forKey: key),
      let modeValue = saved["mode"] as? String,
      let directionValue = saved["direction"] as? String,
      let mode = PlannerCatalogQuery.Sort.Mode(rawValue: modeValue),
      let direction = PlannerCatalogQuery.Sort.Direction(rawValue: directionValue)
    else { return SavedCatalogSort() }
    return SavedCatalogSort(mode: mode, direction: direction)
  }

  func select(_ selection: SavedCatalogSort, for key: String?) {
    guard let key else { return }
    UserDefaults.standard.set(
      ["mode": selection.mode.rawValue, "direction": selection.direction.rawValue], forKey: key)
    selections[key] = selection
  }
}

struct SavedCatalogSortMenu: View {
  @Binding var sort: SavedCatalogSort
  let accessibilityIdentifier: String

  var body: some View {
    Menu {
      Picker("Sort by", selection: $sort.mode) {
        Text("Title").tag(PlannerCatalogQuery.Sort.Mode.title)
        Text("Created").tag(PlannerCatalogQuery.Sort.Mode.created)
        Text("Last updated").tag(PlannerCatalogQuery.Sort.Mode.lastUpdated)
        Text("Full estimate").tag(PlannerCatalogQuery.Sort.Mode.fullEstimate)
      }
      .pickerStyle(.inline)
      Divider()
      Picker("Direction", selection: $sort.direction) {
        Text("Ascending").tag(PlannerCatalogQuery.Sort.Direction.ascending)
        Text("Descending").tag(PlannerCatalogQuery.Sort.Direction.descending)
      }
      .pickerStyle(.inline)
    } label: {
      Label("Sort: \(sort.summary)", systemImage: "arrow.up.arrow.down")
    }
    .labelStyle(.iconOnly)
    .accessibilityIdentifier(accessibilityIdentifier)
    .help("Sort: \(sort.summary)")
  }
}
