import Foundation

struct ItineraryEntrySnapshot: PlannerRankedAssociation {
  let id: UUID
  let lifetimeId: UUID
  let itinerary: PlannerBoundIdentity
  let source: PlannerBoundIdentity
  var rank: Int64
  let localDone: Bool?
  var expandedCompletions: [ExpandedCompletionSnapshot] = []

  var sourceReference: PlannerEntityReference {
    .init(kind: source.kind == "item" ? .item : .list, id: source.id)
  }

  var reference: PlannerReferenceRead {
    .itineraryEntry(
      id: id, itinerary: .init(kind: .itinerary, id: itinerary.id), source: sourceReference)
  }
}

extension ContainerEstimateItinerarySnapshot {
  func progressAndEstimates(
    memberships: [MembershipSnapshot], items: [ContainerEstimateItemSnapshot],
    lists: [ContainerEstimateListSnapshot]
  )
    throws
    -> (
      progress: PlannerContainerProgress, estimates: PlannerContainerEstimates,
      listEntrySummaries: [PlannerItineraryListEntrySummary]
    )
  {
    var totalCount: Int64 = 0
    var doneCount: Int64 = 0
    var archivedCount: Int64 = 0
    var estimateContributions: [ContainerEstimateContribution] = []
    var listEntrySummaries: [PlannerItineraryListEntrySummary] = []
    for entry in entries {
      if entry.source.kind == "item" {
        let item = try resolvedItem(entry.source, in: items)
        estimateContributions.append(
          ContainerEstimateChild(
            estimate: item.estimate,
            finished: item.globalDone || entry.localDone == true || item.archived
          ).contribution)
        totalCount += 1
        if item.globalDone || entry.localDone == true {
          doneCount += 1
        } else if item.archived {
          archivedCount += 1
        }
        continue
      }
      let matchingLists = lists.filter {
        $0.id == entry.source.id && $0.lifetimeId == entry.source.lifetimeId
      }
      guard matchingLists.count == 1, let list = matchingLists.first
      else {
        throw PlannerFailure("readUnavailable", "An itinerary List entry is unresolved.")
      }
      var listEstimateChildren: [ContainerEstimateChild] = []
      var branchDoneCount: Int64 = 0
      var branchArchivedCount: Int64 = 0
      for membership in memberships
      where membership.list.id == entry.source.id
        && membership.list.lifetimeId == entry.source.lifetimeId
      {
        let item = try resolvedItem(membership.item, in: items)
        totalCount += 1
        let localDone =
          entry.expandedCompletions.first {
            $0.context.membershipId == membership.id
              && $0.context.membershipLifetimeId == membership.lifetimeId
          }?.localDone ?? false
        listEstimateChildren.append(
          .init(
            estimate: item.estimate,
            finished: item.globalDone || localDone || item.archived || list.archived))
        if item.globalDone || localDone {
          doneCount += 1
          branchDoneCount += 1
        } else if item.archived || list.archived {
          archivedCount += 1
          branchArchivedCount += 1
        }
      }
      let branchTotalCount = Int64(listEstimateChildren.count)
      let branchState: PlannerContainerProgressState
      if branchTotalCount == 0 {
        branchState = .empty
      } else if branchDoneCount + branchArchivedCount == branchTotalCount {
        branchState = .complete
      } else {
        branchState = .partial
      }
      let branchEstimates = containerEstimates(
        children: listEstimateChildren, archived: list.archived,
        manualEstimate: list.manualEstimate)
      listEntrySummaries.append(
        .init(
          entryId: entry.id, source: list.reference, manualEstimate: list.manualEstimate,
          progress: .init(
            container: list.reference, state: branchState,
            doneCount: branchDoneCount, totalCount: branchTotalCount,
            archivedCount: branchArchivedCount),
          estimates: branchEstimates))
      estimateContributions.append(
        listEstimateContribution(
          children: listEstimateChildren, archived: list.archived,
          summary: branchEstimates))
    }
    let state: PlannerContainerProgressState
    if totalCount == 0 {
      state = .empty
    } else if doneCount + archivedCount == totalCount {
      state = .complete
    } else {
      state = .partial
    }
    return (
      progress: .init(
        container: reference, state: state, doneCount: doneCount, totalCount: totalCount,
        archivedCount: archivedCount),
      estimates: containerEstimates(
        contributions: estimateContributions, archived: archived,
        manualEstimate: manualEstimate, allFinished: state == .complete),
      listEntrySummaries: listEntrySummaries
    )
  }

  private func resolvedItem(
    _ binding: PlannerBoundIdentity, in items: [ContainerEstimateItemSnapshot]
  ) throws
    -> ContainerEstimateItemSnapshot
  {
    let matches = items.filter { $0.id == binding.id && $0.lifetimeId == binding.lifetimeId }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure("readUnavailable", "An itinerary child Item is unresolved.")
    }
    return item
  }
}
