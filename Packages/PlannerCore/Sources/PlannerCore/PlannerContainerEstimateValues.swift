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

  var contribution: ContainerEstimateContribution {
    let fullEstimate: PlannerDurationTotal
    if let estimate {
      fullEstimate = .exact(minutes: estimate.minutes)
    } else {
      fullEstimate = .lowerBound(minutes: 0, missingEstimateCount: 1)
    }
    return .init(
      fullEstimate: fullEstimate,
      remainingEstimate: finished ? .exact(minutes: 0) : fullEstimate,
      finishedEstimate: finished ? fullEstimate : .exact(minutes: 0))
  }
}

struct ContainerEstimateContribution {
  let fullEstimate: PlannerDurationTotal
  let remainingEstimate: PlannerDurationTotal
  let finishedEstimate: PlannerDurationTotal
}

func listEstimateContribution(
  children: [ContainerEstimateChild], archived: Bool, manualEstimate: PlannerEstimate?
) -> ContainerEstimateContribution {
  let summary = containerEstimates(
    children: children, archived: archived, manualEstimate: manualEstimate)
  let isFinished = archived || (!children.isEmpty && children.allSatisfy(\.finished))
  let finishedEstimate: PlannerDurationTotal
  if isFinished {
    finishedEstimate = summary.fullEstimate
  } else {
    finishedEstimate = sumDurationTotals(children.map { $0.contribution.finishedEstimate })
  }
  return .init(
    fullEstimate: summary.fullEstimate, remainingEstimate: summary.remainingEstimate,
    finishedEstimate: finishedEstimate)
}

func containerEstimates(
  children: [ContainerEstimateChild], archived: Bool, manualEstimate: PlannerEstimate?
) -> PlannerContainerEstimates {
  containerEstimates(
    contributions: children.map(\.contribution), archived: archived,
    manualEstimate: manualEstimate,
    allFinished: !children.isEmpty && children.allSatisfy(\.finished))
}

func containerEstimates(
  contributions: [ContainerEstimateContribution], archived: Bool, manualEstimate: PlannerEstimate?,
  allFinished: Bool
) -> PlannerContainerEstimates {
  let calculatedEstimate = sumDurationTotals(contributions.map(\.fullEstimate))
  if let manualEstimate {
    return manualContainerEstimates(
      finishedTotal: sumDurationTotals(contributions.map(\.finishedEstimate)),
      noRemainingWork: archived || allFinished, totalMinutes: manualEstimate.minutes,
      calculatedEstimate: calculatedEstimate)
  }
  let remainingEstimate: PlannerDurationTotal
  if archived || allFinished {
    remainingEstimate = .exact(minutes: 0)
  } else {
    remainingEstimate = sumDurationTotals(contributions.map(\.remainingEstimate))
  }
  return .init(
    calculatedEstimate: calculatedEstimate, fullEstimate: calculatedEstimate,
    remainingEstimate: remainingEstimate, completedExceedsTotal: false)
}

private func manualContainerEstimates(
  finishedTotal: PlannerDurationTotal, noRemainingWork: Bool, totalMinutes: Int64,
  calculatedEstimate: PlannerDurationTotal
) -> PlannerContainerEstimates {
  let finishedMinutes: Int64
  let missingFinishedCount: Int64
  switch finishedTotal {
  case .exact(let minutes):
    finishedMinutes = minutes
    missingFinishedCount = 0
  case .lowerBound(let minutes, let missingCount):
    finishedMinutes = minutes
    missingFinishedCount = missingCount
  case .unavailable, .upperBound:
    let remainingEstimate: PlannerDurationTotal
    if noRemainingWork {
      remainingEstimate = .exact(minutes: 0)
    } else {
      remainingEstimate = .unavailable
    }
    return .init(
      calculatedEstimate: calculatedEstimate, fullEstimate: .exact(minutes: totalMinutes),
      remainingEstimate: remainingEstimate, completedExceedsTotal: true)
  }
  let remainingEstimate: PlannerDurationTotal
  if noRemainingWork {
    remainingEstimate = .exact(minutes: 0)
  } else if missingFinishedCount > 0 {
    remainingEstimate = .upperBound(
      minutes: max(0, totalMinutes - finishedMinutes),
      missingFinishedEstimateCount: missingFinishedCount)
  } else {
    remainingEstimate = .exact(minutes: max(0, totalMinutes - finishedMinutes))
  }
  return .init(
    calculatedEstimate: calculatedEstimate, fullEstimate: .exact(minutes: totalMinutes),
    remainingEstimate: remainingEstimate, completedExceedsTotal: finishedMinutes > totalMinutes)
}

private func sumDurationTotals(_ totals: [PlannerDurationTotal]) -> PlannerDurationTotal {
  var minutes: Int64 = 0
  var missingCount: Int64 = 0
  var hasLowerBound = false
  var hasUpperBound = false
  for total in totals {
    let contribution: Int64
    let missing: Int64
    switch total {
    case .exact(let value):
      contribution = value
      missing = 0
    case .lowerBound(let value, let count):
      contribution = value
      missing = count
      hasLowerBound = true
    case .upperBound(let value, let count):
      contribution = value
      missing = count
      hasUpperBound = true
    case .unavailable: return .unavailable
    }
    let (updatedMinutes, minutesOverflow) = minutes.addingReportingOverflow(contribution)
    let (updatedMissing, missingOverflow) = missingCount.addingReportingOverflow(missing)
    guard !minutesOverflow, !missingOverflow, !(hasLowerBound && hasUpperBound) else {
      return .unavailable
    }
    minutes = updatedMinutes
    missingCount = updatedMissing
  }
  if hasUpperBound {
    return .upperBound(minutes: minutes, missingFinishedEstimateCount: missingCount)
  }
  if hasLowerBound { return .lowerBound(minutes: minutes, missingEstimateCount: missingCount) }
  return .exact(minutes: minutes)
}
