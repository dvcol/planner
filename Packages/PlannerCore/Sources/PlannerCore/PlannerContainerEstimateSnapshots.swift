import Foundation
import SwiftData

struct ContainerEstimateItemSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let estimate: PlannerEstimate?
  let globalDone: Bool
  let archived: Bool
}

/// Index once per projection while retaining duplicate candidates for integrity checks.
struct ContainerEstimateIndex {
  let membershipsByList: [UUID: [MembershipSnapshot]]
  let itemsById: [UUID: [ContainerEstimateItemSnapshot]]
  let listsById: [UUID: [ContainerEstimateListSnapshot]]

  init(
    memberships: [MembershipSnapshot], items: [ContainerEstimateItemSnapshot],
    lists: [ContainerEstimateListSnapshot] = []
  ) {
    membershipsByList = Dictionary(grouping: memberships, by: { $0.list.id })
    itemsById = Dictionary(grouping: items, by: \.id)
    listsById = Dictionary(grouping: lists, by: \.id)
  }
}

struct ContainerEstimateListSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let manualEstimate: PlannerEstimate?
  let archived: Bool

  var reference: PlannerEntityReference { .init(kind: .list, id: id) }

  func progressAndEstimates(
    memberships: [MembershipSnapshot], items: [ContainerEstimateItemSnapshot]
  ) throws -> (progress: PlannerContainerProgress, estimates: PlannerContainerEstimates) {
    try progressAndEstimates(index: .init(memberships: memberships, items: items))
  }

  func progressAndEstimates(
    index: ContainerEstimateIndex
  ) throws -> (progress: PlannerContainerProgress, estimates: PlannerContainerEstimates) {
    let children = index.membershipsByList[id] ?? []
    var doneCount: Int64 = 0
    var archivedCount: Int64 = 0
    var estimateChildren: [ContainerEstimateChild] = []
    for membership in children {
      let matches = (index.itemsById[membership.item.id] ?? []).filter {
        $0.lifetimeId == membership.item.lifetimeId
      }
      guard membership.list.lifetimeId == lifetimeId, matches.count == 1,
        let item = matches.first
      else {
        throw PlannerFailure("readUnavailable", "A List child source is unresolved.")
      }
      estimateChildren.append(
        .init(
          estimate: item.estimate,
          finished: item.globalDone || membership.localDone || item.archived))
      if item.globalDone || membership.localDone {
        doneCount += 1
      } else if item.archived {
        archivedCount += 1
      }
    }
    let totalCount = Int64(children.count)
    let state: PlannerContainerProgressState
    if children.isEmpty {
      state = .empty
    } else if doneCount + archivedCount == totalCount {
      state = .complete
    } else {
      state = .partial
    }
    return (
      .init(
        container: reference, state: state, doneCount: doneCount, totalCount: totalCount,
        archivedCount: archivedCount),
      containerEstimates(
        children: estimateChildren, archived: archived, manualEstimate: manualEstimate)
    )
  }
}

struct ContainerEstimateItinerarySnapshot {
  let reference: PlannerEntityReference
  let manualEstimate: PlannerEstimate?
  let archived: Bool
  let entries: [ItineraryEntrySnapshot]
}

extension PlannerSchemaV18.Item {
  func estimateSnapshot() throws -> ContainerEstimateItemSnapshot {
    guard let id, let lifetimeId else {
      throw PlannerFailure("readUnavailable", "An estimate Item has unresolved identity.")
    }
    let estimate = try estimateData.map { try JSONDecoder().decode(PlannerEstimate.self, from: $0) }
    try estimate?.validate(propertyPath: "/content/estimate")
    return .init(
      id: id, lifetimeId: lifetimeId, estimate: estimate, globalDone: globalDone, archived: archived
    )
  }
}

extension PlannerSchemaV18.List {
  func estimateSnapshot() throws -> ContainerEstimateListSnapshot {
    guard let id, let lifetimeId else {
      throw PlannerFailure("readUnavailable", "An estimate List has unresolved identity.")
    }
    let estimate = try manualEstimateData.map {
      try JSONDecoder().decode(PlannerEstimate.self, from: $0)
    }
    try estimate?.validate(propertyPath: "/content/manualEstimate")
    return .init(id: id, lifetimeId: lifetimeId, manualEstimate: estimate, archived: archived)
  }
}

extension PlannerSchemaV18.Itinerary {
  func estimateSnapshot(entries: [ItineraryEntrySnapshot]) throws
    -> ContainerEstimateItinerarySnapshot
  {
    guard let id, let lifetimeId else {
      throw PlannerFailure("readUnavailable", "An estimate Itinerary has unresolved identity.")
    }
    let selectedEntries = entries.filter { $0.itinerary.id == id }
    guard selectedEntries.allSatisfy({ $0.itinerary.lifetimeId == lifetimeId }) else {
      throw PlannerFailure("readUnavailable", "An estimate Itinerary has unresolved entries.")
    }
    let estimate = try manualEstimateData.map {
      try JSONDecoder().decode(PlannerEstimate.self, from: $0)
    }
    try estimate?.validate(propertyPath: "/content/manualEstimate")
    return .init(
      reference: .init(kind: .itinerary, id: id), manualEstimate: estimate,
      archived: archived, entries: selectedEntries)
  }
}
