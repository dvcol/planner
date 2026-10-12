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
        Text(description(total)).foregroundStyle(Color.primary)
        if isManual { Text("Manual").foregroundStyle(.secondary) }
      }
    } label: {
      Text(title).foregroundStyle(Color.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isManual ? title + ", Manual" : title)
    .accessibilityValue(accessibilityDescription(total))
    .accessibilityIdentifier(accessibilityIdentifierPrefix + "." + identifier)
  }

  private func warning(_ message: String, identifier: String) -> some View {
    Label(message, systemImage: "exclamationmark.triangle")
      .foregroundStyle(.orange)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(message)
      .accessibilityIdentifier(accessibilityIdentifierPrefix + ".warning." + identifier)
  }

  private func description(_ total: PlannerDurationTotal) -> String {
    switch total {
    case .exact(let minutes): duration(minutes)
    case .lowerBound(let minutes, _): "At least \(duration(minutes))"
    case .upperBound(let minutes, _): "Up to \(duration(minutes))"
    case .unavailable: "Unavailable"
    }
  }

  private func accessibilityDescription(_ total: PlannerDurationTotal) -> String {
    switch total {
    case .exact(let minutes): "\(minutes) minutes"
    case .lowerBound(let minutes, let missing):
      "At least \(minutes) minutes; \(missing) \(missing == 1 ? "estimate" : "estimates") missing"
    case .upperBound(let minutes, let missing):
      "Up to \(minutes) minutes; \(missing) finished \(missing == 1 ? "estimate" : "estimates") missing"
    case .unavailable: "Estimate unavailable"
    }
  }

  private func duration(_ minutes: Int64) -> String {
    guard minutes > 0 else { return "0 minutes" }
    return PlannerEstimate(minutes: minutes, displayUnit: manualEstimate?.displayUnit ?? .hour)
      .nativeEstimateDescription
  }
}
