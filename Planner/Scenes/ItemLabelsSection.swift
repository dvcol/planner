import PlannerCore
import SwiftUI

extension Array where Element == PlannerLabelRead {
  func sortedLabels(of kind: PlannerEntityKind) -> [PlannerLabelRead] {
    filter { $0.reference.kind == kind }.sorted { left, right in
      let comparison = left.name.localizedStandardCompare(right.name)
      if comparison == .orderedSame {
        return left.reference.id.uuidString < right.reference.id.uuidString
      }
      return comparison == .orderedAscending
    }
  }
}

struct ItemLabelsSection: View {
  let labels: [PlannerLabelRead]

  var body: some View {
    labelSection(.category)
    labelSection(.tag)
  }

  @ViewBuilder private func labelSection(_ kind: SavedLabelKind) -> some View {
    let selectedLabels = labels.sortedLabels(of: kind.sourceKind)
    if !selectedLabels.isEmpty {
      Section(kind.pluralTitle) {
        ForEach(selectedLabels, id: \.reference.id) { label in
          Label(label.name, systemImage: kind.systemImage)
        }
      }
    }
  }
}
