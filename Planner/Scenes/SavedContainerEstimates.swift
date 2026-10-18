import PlannerCore
import SwiftUI

struct SavedContainerEstimates: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let estimates: PlannerContainerEstimates
  let manualEstimate: PlannerEstimate?
  let accessibilityIdentifierPrefix: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      metric(
        "Estimate", total: estimates.fullEstimate, identifier: "full",
        isManual: manualEstimate != nil)
      metric("Remaining", total: estimates.remainingEstimate, identifier: "remaining")
      if manualEstimate != nil, estimates.calculatedEstimate != estimates.fullEstimate {
        metric("Calculated", total: estimates.calculatedEstimate, identifier: "calculated")
      }
      if case .lowerBound(_, let count) = estimates.calculatedEstimate {
        warning("\(count) \(count == 1 ? "estimate" : "estimates") missing", identifier: "missing")
      }
      if case .upperBound(_, let count) = estimates.remainingEstimate {
        warning(
          "\(count) finished \(count == 1 ? "estimate" : "estimates") missing",
          identifier: "finished")
      }
      if estimates.completedExceedsTotal {
        warning("Finished estimates exceed the manual total", identifier: "exceeded")
      }
    }
    .font(.caption)
  }

  private func metric(
    _ title: String, total: PlannerDurationTotal, identifier: String, isManual: Bool = false
  ) -> some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 4) {
          Text(title).foregroundStyle(SavedRowForeground.secondary)
          durationValue(total, isManual: isManual)
        }
      } else {
        LabeledContent {
          durationValue(total, isManual: isManual)
        } label: {
          Text(title).foregroundStyle(SavedRowForeground.secondary)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isManual ? title + ", Manual" : title)
    .accessibilityValue(total.nativeContainerDurationAccessibilityDescription)
    .accessibilityIdentifier(accessibilityIdentifierPrefix + "." + identifier)
  }

  private func durationValue(_ total: PlannerDurationTotal, isManual: Bool) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(
        total.nativeContainerDurationDescription(
          displayUnit: manualEstimate?.displayUnit ?? .hour)
      )
      .foregroundStyle(Color.primary)
      .fixedSize(horizontal: false, vertical: true)
      if isManual { Text("Manual").foregroundStyle(SavedRowForeground.secondary) }
    }
  }

  private func warning(_ message: String, identifier: String) -> some View {
    Label {
      Text(message).foregroundStyle(Color.primary)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(message)
    .accessibilityIdentifier(accessibilityIdentifierPrefix + ".warning." + identifier)
  }

}
