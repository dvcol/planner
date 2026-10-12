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

extension ItinerarySnapshot {
  func progressAndEstimates(
    memberships: [MembershipSnapshot], items: [ItemSnapshot], lists: [ListSnapshot]
  )
    throws
    -> (progress: PlannerContainerProgress, estimates: PlannerContainerEstimates)
  {
    var totalCount: Int64 = 0
    var doneCount: Int64 = 0
    var archivedCount: Int64 = 0
    var estimateChildren: [ContainerEstimateChild] = []
    for entry in entries {
      if entry.source.kind == "item" {
        let item = try resolvedItem(entry.source, in: items)
        estimateChildren.append(
          .init(
            estimate: item.input.estimate,
            finished: item.globalDone || entry.localDone == true || item.archived))
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
        estimateChildren.append(
          .init(
            estimate: item.input.estimate,
            finished: item.globalDone || localDone || item.archived || list.archived))
        if item.globalDone || localDone {
          doneCount += 1
        } else if item.archived || list.archived {
          archivedCount += 1
        }
      }
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
      estimates: automaticContainerEstimates(children: estimateChildren, archived: archived)
    )
  }

  private func resolvedItem(_ binding: PlannerBoundIdentity, in items: [ItemSnapshot]) throws
    -> ItemSnapshot
  {
    let matches = items.filter { $0.id == binding.id && $0.lifetimeId == binding.lifetimeId }
    guard matches.count == 1, let item = matches.first else {
      throw PlannerFailure("readUnavailable", "An itinerary child Item is unresolved.")
    }
    return item
  }
}
