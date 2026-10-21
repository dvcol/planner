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

  private func iconColor(for label: PlannerLabelRead) -> Color {
    guard let color = label.color else { return .secondary }
    return Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
  }

  @ViewBuilder private func labelSection(_ kind: SavedLabelKind) -> some View {
    let selectedLabels = labels.sortedLabels(of: kind.sourceKind)
    if !selectedLabels.isEmpty {
      Section(kind.pluralTitle) {
        ForEach(selectedLabels, id: \.reference.id) { label in
          Label {
            Text(label.name)
          } icon: {
            Image(systemName: label.iconName ?? kind.systemImage)
              .foregroundStyle(iconColor(for: label))
          }
        }
      }
    }
  }
}
