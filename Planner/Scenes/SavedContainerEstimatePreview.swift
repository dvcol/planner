import PlannerCore
import SwiftUI

struct SavedContainerEstimatePreview: View {
  let estimates: PlannerContainerEstimates
  let manualEstimate: PlannerEstimate?

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Label {
        Text(displayDescription).fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: "clock")
      }
      if estimates.hasNativeEstimateWarning {
        Image(systemName: "exclamationmark.triangle")
          .foregroundStyle(SavedRowForeground(unselectedColor: .orange))
          .accessibilityHidden(true)
      }
    }
    .font(.caption).foregroundStyle(SavedRowForeground.secondary)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Estimates")
    .accessibilityValue(
      estimates.nativeEstimatePreviewAccessibilityDescription(manualEstimate: manualEstimate))
  }

  private var displayDescription: String {
    let unit = manualEstimate?.displayUnit ?? .hour
    let full = estimates.fullEstimate.nativeContainerDurationDescription(displayUnit: unit)
    let remaining = estimates.remainingEstimate.nativeContainerDurationDescription(
      displayUnit: unit)
    let manual = manualEstimate == nil ? "" : " · Manual"
    return "\(full) estimate · \(remaining) remaining\(manual)"
  }
}

extension PlannerContainerEstimates {
  var hasNativeEstimateWarning: Bool {
    if completedExceedsTotal { return true }
    if case .lowerBound = calculatedEstimate { return true }
    if case .unavailable = calculatedEstimate { return true }
    if case .upperBound = remainingEstimate { return true }
    if case .unavailable = fullEstimate { return true }
    if case .unavailable = remainingEstimate { return true }
    return false
  }

  func nativeEstimatePreviewAccessibilityDescription(manualEstimate: PlannerEstimate?) -> String {
    let manual = manualEstimate == nil ? "" : ", Manual"
    var description =
      "Estimate\(manual), \(fullEstimate.nativeContainerDurationAccessibilityDescription). "
      + "Remaining, \(remainingEstimate.nativeContainerDurationAccessibilityDescription)."
    if manualEstimate != nil, case .lowerBound = calculatedEstimate {
      description +=
        " Calculated, \(calculatedEstimate.nativeContainerDurationAccessibilityDescription)."
    }
    if manualEstimate != nil, case .unavailable = calculatedEstimate {
      description +=
        " Calculated, \(calculatedEstimate.nativeContainerDurationAccessibilityDescription)."
    }
    if completedExceedsTotal {
      description += " Finished estimates exceed the manual total."
    }
    return description
  }
}

extension PlannerDurationTotal {
  func nativeContainerDurationDescription(displayUnit: PlannerEstimateUnit) -> String {
    switch self {
    case .exact(let minutes): nativeDuration(minutes, displayUnit: displayUnit)
    case .lowerBound(let minutes, _):
      "At least \(nativeDuration(minutes, displayUnit: displayUnit))"
    case .upperBound(let minutes, _): "Up to \(nativeDuration(minutes, displayUnit: displayUnit))"
    case .unavailable: "Unavailable"
    }
  }

  var nativeContainerDurationAccessibilityDescription: String {
    switch self {
    case .exact(let minutes): "\(minutes) minutes"
    case .lowerBound(let minutes, let missing):
      "At least \(minutes) minutes; \(missing) \(missing == 1 ? "estimate" : "estimates") missing"
    case .upperBound(let minutes, let missing):
      "Up to \(minutes) minutes; \(missing) finished \(missing == 1 ? "estimate" : "estimates") missing"
    case .unavailable: "Estimate unavailable"
    }
  }

  private func nativeDuration(_ minutes: Int64, displayUnit: PlannerEstimateUnit) -> String {
    guard minutes > 0 else { return "0 minutes" }
    return PlannerEstimate(minutes: minutes, displayUnit: displayUnit).nativeEstimateDescription
  }
}
