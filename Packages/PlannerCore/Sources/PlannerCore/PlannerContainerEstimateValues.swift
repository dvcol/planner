public enum PlannerDurationTotal: Sendable, Equatable {
  case exact(minutes: Int64)
  case lowerBound(minutes: Int64, missingEstimateCount: Int64)
  case upperBound(minutes: Int64, missingFinishedEstimateCount: Int64)
  case unavailable
}

public struct PlannerContainerEstimates: Sendable, Equatable {
  public let calculatedEstimate: PlannerDurationTotal
  public let fullEstimate: PlannerDurationTotal
  public let remainingEstimate: PlannerDurationTotal
  public let completedExceedsTotal: Bool
}

struct ContainerEstimateChild {
  let estimate: PlannerEstimate?
  let finished: Bool
}

func automaticContainerEstimates(
  children: [ContainerEstimateChild], archived: Bool
) -> PlannerContainerEstimates {
  let fullEstimate = automaticDurationTotal(children)
  let remainingEstimate: PlannerDurationTotal
  if archived {
    remainingEstimate = .exact(minutes: 0)
  } else {
    remainingEstimate = automaticDurationTotal(children.filter { !$0.finished })
  }
  return .init(
    calculatedEstimate: fullEstimate, fullEstimate: fullEstimate,
    remainingEstimate: remainingEstimate,
    completedExceedsTotal: false)
}

private func automaticDurationTotal(_ children: [ContainerEstimateChild]) -> PlannerDurationTotal {
  var minutes: Int64 = 0
  var missingEstimateCount: Int64 = 0
  for child in children {
    guard let estimate = child.estimate else {
      missingEstimateCount += 1
      continue
    }
    let (total, overflow) = minutes.addingReportingOverflow(estimate.minutes)
    guard !overflow else { return .unavailable }
    minutes = total
  }
  if missingEstimateCount > 0 {
    return .lowerBound(minutes: minutes, missingEstimateCount: missingEstimateCount)
  }
  return .exact(minutes: minutes)
}
