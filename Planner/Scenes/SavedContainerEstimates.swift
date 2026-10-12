import PlannerCore
import SwiftUI

struct SavedContainerEstimates: View {
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
    LabeledContent {
      HStack {
        Text(
          total.nativeContainerDurationDescription(
            displayUnit: manualEstimate?.displayUnit ?? .hour)
        ).foregroundStyle(Color.primary)
        if isManual { Text("Manual").foregroundStyle(.secondary) }
      }
    } label: {
      Text(title).foregroundStyle(Color.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isManual ? title + ", Manual" : title)
    .accessibilityValue(total.nativeContainerDurationAccessibilityDescription)
    .accessibilityIdentifier(accessibilityIdentifierPrefix + "." + identifier)
  }

  private func warning(_ message: String, identifier: String) -> some View {
    Label(message, systemImage: "exclamationmark.triangle")
      .foregroundStyle(.orange)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(message)
      .accessibilityIdentifier(accessibilityIdentifierPrefix + ".warning." + identifier)
  }

}
