import Foundation

struct PlannerImportMembershipHistory {
  let provenanceToWrite: [PlannerPortableMembershipProvenance]
  let removalsToWrite: [PlannerPortableMembershipRemoval]
  let projectedProvenance: [PlannerPortableMembershipProvenance]
  let projectedRemovals: [PlannerPortableMembershipRemoval]

  init(
    current: PlannerPortableBackup, incoming: PlannerPortableBackup,
    selectedOwners: Set<PlannerEntityReference>, markers: [PlannerPortableDeletionMarker],
    localRemovalMarkers: [PlannerPortableDeletionMarker], survivingSources: Set<PlannerBoundSource>
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
      if let known = currentMembers[value.membership] {
        var savedPair = known.baselineProvenance.pair
        var incomingPair = value.pair
        if current.formatVersion >= 5 {
          savedPair = try plannerMembershipHistoryPair(
            savedPair, families: current.restorationFamilies)
          incomingPair = try plannerMembershipHistoryPair(
            incomingPair, families: current.restorationFamilies)
        }
        guard savedPair == incomingPair else {
          throw PlannerFailure(
            "invalidInput", "Incoming membership provenance names another saved Item/List pair.")
        }
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
    for marker in localRemovalMarkers {
      guard let target = marker.target.importIdentity, target.kind == .membership,
        let member = currentMembers[target]
      else { continue }
      let binding = retained[target] ?? member.baselineProvenance
      guard survivingSources.contains(binding.list), survivingSources.contains(binding.item) else {
        continue
      }
      if retained[target] == nil { selected.append(binding) }
      retained[target] = binding
      let removal = PlannerPortableMembershipRemoval(deletionId: marker.deletionId)
      if removals[marker.deletionId] == nil { selectedRemovals.append(removal) }
      removals[marker.deletionId] = removal
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

func plannerImportMembershipOperationEvidence(
  incoming: PlannerDecodedBackup, current: PlannerPortableBackup,
  projected: PlannerPortableBackup, changes: [PlannerImportReferenceChange]
) throws -> (bindings: [PlannerBoundIdentity], memberships: [PlannerPortableMembershipProvenance])?
{
  guard
    incoming.backup.usesMembershipProvenanceFormat
      || current.membershipRemovals != projected.membershipRemovals
  else { return nil }
  let incomingEvidence = incoming.backup.resolvedMembershipProvenance
  let changedMemberships = changes.compactMap { change -> UUID? in
    guard case .membership(let identifier, _, _) = change.reference else { return nil }
    return identifier
  }
  let membershipIdentifiers = Set(incomingEvidence.map(\.membershipId) + changedMemberships)
  /// The command retains incoming values; execution evidence uses approved lifetime rewrites.
  let selected =
    current.resolvedMembershipProvenance.filter {
      membershipIdentifiers.contains($0.membershipId)
    }
    + projected.resolvedMembershipProvenance.filter {
      membershipIdentifiers.contains($0.membershipId)
    }
  var byIdentity: [PlannerPortableBoundIdentity: PlannerPortableMembershipProvenance] = [:]
  for value in selected {
    let normalized = value.normalized
    guard byIdentity[value.membership].map({ $0 == normalized }) ?? true else {
      throw PlannerFailure("invalidInput", "An import changes retained membership observations.")
    }
    byIdentity[value.membership] = normalized
  }
  let memberships = plannerSortedMembershipEvidence(Array(byIdentity.values))
  let requestedSources = incoming.backup.sources.map(\.importBinding) + incoming.externalBindings
  let sourceIdentities = Set(requestedSources.map(\.reference))
  let sourceBindings =
    requestedSources
    + (current.sources + projected.sources).map(\.importBinding).filter {
      sourceIdentities.contains($0.reference)
    }
    + memberships.flatMap { [$0.item, $0.list] }
  let bindings =
    sourceBindings.map {
      PlannerBoundIdentity(kind: $0.kind.rawValue, id: $0.id, lifetimeId: $0.lifetimeId)
    }
    + memberships.map {
      PlannerBoundIdentity(
        kind: "membership", id: $0.membershipId, lifetimeId: $0.membershipLifetimeId)
    }
  var uniqueBindings: [Data: PlannerBoundIdentity] = [:]
  for binding in bindings { uniqueBindings[binding.canonicalValue.encoded()] = binding }
  return (
    uniqueBindings.sorted { $0.key.lexicographicallyPrecedes($1.key) }.map(\.value), memberships
  )
}
