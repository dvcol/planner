import Foundation

struct PlannerImportMembershipHistory {
  let provenanceToWrite: [PlannerPortableMembershipProvenance]
  let removalsToWrite: [PlannerPortableMembershipRemoval]
  let projectedProvenance: [PlannerPortableMembershipProvenance]
  let projectedRemovals: [PlannerPortableMembershipRemoval]

  init(
    current: PlannerPortableBackup, incoming: PlannerPortableBackup,
    selectedOwners: Set<PlannerEntityReference>, markers: [PlannerPortableDeletionMarker]
  ) throws {
    var retained = Dictionary(
      uniqueKeysWithValues: current.membershipProvenance.map { ($0.membership, $0.normalized) })
    let currentMembers = Dictionary(
      uniqueKeysWithValues: current.memberships.map { ($0.baselineProvenance.membership, $0) })
    let currentOwners = Set(current.sources.map { $0.importBinding.reference })
    var selected: [PlannerPortableMembershipProvenance] = []
    var admittedBindings: Set<PlannerPortableBoundIdentity> = []
    for value in incoming.membershipProvenance.map(\.normalized) {
      if let known = retained[value.membership], known != value {
        throw PlannerFailure(
          "invalidInput", "Incoming membership provenance conflicts with retained authority.")
      }
      if let known = currentMembers[value.membership], known.baselineProvenance.pair != value.pair {
        throw PlannerFailure(
          "invalidInput", "Incoming membership provenance names another saved Item/List pair.")
      }
      guard
        selectedOwners.contains(value.list.reference)
          || !currentOwners.contains(value.list.reference)
      else { continue }
      admittedBindings.insert(value.membership)
      if retained[value.membership] == nil { selected.append(value) }
      retained[value.membership] = value
    }
    let incomingBindings = Dictionary(
      uniqueKeysWithValues: incoming.membershipProvenance.map { ($0.membership, $0) })
    let incomingMarkers = Dictionary(
      uniqueKeysWithValues: incoming.deletionMarkers.map { ($0.deletionId, $0) })
    let retainedMarkers = Set((current.deletionMarkers + markers).map(\.deletionId))
    var removals = Dictionary(
      uniqueKeysWithValues: current.membershipRemovals.map { ($0.deletionId, $0) })
    var selectedRemovals: [PlannerPortableMembershipRemoval] = []
    for removal in incoming.membershipRemovals {
      guard let target = incomingMarkers[removal.deletionId]?.target.importIdentity,
        incomingBindings[target] != nil, admittedBindings.contains(target),
        retainedMarkers.contains(removal.deletionId)
      else { continue }
      if removals[removal.deletionId] == nil { selectedRemovals.append(removal) }
      removals[removal.deletionId] = removal
    }
    provenanceToWrite = Self.sorted(selected)
    removalsToWrite = selectedRemovals.sorted {
      $0.deletionId.uuidString < $1.deletionId.uuidString
    }
    projectedProvenance = Self.sorted(Array(retained.values))
    projectedRemovals = removals.values.sorted {
      $0.deletionId.uuidString < $1.deletionId.uuidString
    }
  }

  private static func sorted(_ values: [PlannerPortableMembershipProvenance])
    -> [PlannerPortableMembershipProvenance]
  {
    values.sorted {
      if $0.membershipId != $1.membershipId {
        return $0.membershipId.uuidString < $1.membershipId.uuidString
      }
      return $0.membershipLifetimeId.uuidString < $1.membershipLifetimeId.uuidString
    }
  }
}
