import Foundation

public struct PlannerPortableMembershipProvenance: Sendable, Equatable, Codable {
  public let membershipId: UUID
  public let membershipLifetimeId: UUID
  public let list: PlannerBoundSource
  public let item: PlannerBoundSource
  public let observedRemovalIds: [UUID]

  var membership: PlannerPortableBoundIdentity {
    .init(kind: .membership, id: membershipId, lifetimeId: membershipLifetimeId)
  }

  var pair: PlannerMembershipPair { .init(list: list, item: item) }

  var normalized: Self {
    .init(
      membershipId: membershipId, membershipLifetimeId: membershipLifetimeId,
      list: list, item: item,
      observedRemovalIds: observedRemovalIds.sorted { $0.uuidString < $1.uuidString })
  }

  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "membershipId": .identity(membershipId),
      "membershipLifetimeId": .identity(membershipLifetimeId),
      "list": list.importCanonicalValue, "item": item.importCanonicalValue,
      "observedRemovalIds": .identitySet(observedRemovalIds.map(PlannerCanonicalValue.identity)),
    ])
  }

  var operationCanonicalValue: PlannerCanonicalValue {
    .record([
      "membership": membership.importCanonicalValue,
      "list": list.importCanonicalValue, "item": item.importCanonicalValue,
      "observedRemovalIds": .identitySet(observedRemovalIds.map(PlannerCanonicalValue.identity)),
    ])
  }
}

public struct PlannerPortableMembershipRemoval: Sendable, Equatable, Codable {
  public let deletionId: UUID
}

struct PlannerMembershipPair: Hashable {
  let list: PlannerBoundSource
  let item: PlannerBoundSource
}

/// Historical siblings retain one authority key after closure; predecessors never join it.
func plannerMembershipHistoryPair(
  _ pair: PlannerMembershipPair, families: [PlannerPortableRestorationFamily]
) throws -> PlannerMembershipPair {
  let matching = families.filter {
    $0.predecessor.kind == .item && $0.predecessor.id == pair.item.id
      && $0.candidates.contains { $0.lifetimeId == pair.item.lifetimeId }
  }
  guard matching.count <= 1 else {
    throw PlannerFailure("readUnavailable", "Membership authority has conflicting Item families.")
  }
  guard let family = matching.first,
    let lifetime = family.candidates.map(\.lifetimeId).min(by: { $0.uuidString < $1.uuidString })
  else { return pair }
  return .init(
    list: pair.list, item: .init(kind: .item, id: pair.item.id, lifetimeId: lifetime))
}

extension PlannerImportGraph {
  func membershipHistoryPair(_ pair: PlannerMembershipPair) throws -> PlannerMembershipPair {
    guard backup.formatVersion >= 5 else { return pair }
    return try plannerMembershipHistoryPair(pair, families: backup.restorationFamilies)
  }

  func retainedMembershipProvenance(for identity: PlannerPortableBoundIdentity)
    -> PlannerPortableMembershipProvenance?
  {
    guard backup.usesMembershipProvenanceFormat else { return nil }
    return backup.membershipProvenance.first { $0.membership == identity }
  }

  func membershipProvenance(for identity: PlannerPortableBoundIdentity)
    -> PlannerPortableMembershipProvenance?
  {
    if let retained = retainedMembershipProvenance(for: identity) { return retained }
    return backup.memberships.first {
      $0.id == identity.id && $0.lifetimeId == identity.lifetimeId
    }?.baselineProvenance
  }

  func suppressedMembershipIdentities() throws -> Set<PlannerPortableBoundIdentity> {
    let requiredRemovals = try validatedMembershipRemovalAuthority()
    return Set(
      try backup.membershipProvenance.filter {
        !(requiredRemovals[try membershipHistoryPair($0.pair)] ?? []).isSubset(
          of: $0.observedRemovalIds)
      }.map(\.membership))
  }

  func validateMembershipProvenance() throws {
    let requiredRemovals = try validatedMembershipRemovalAuthority()
    let provenance = Dictionary(
      uniqueKeysWithValues: backup.membershipProvenance.map { ($0.membership, $0) })
    for (index, membership) in backup.memberships.enumerated() {
      let baseline = membership.baselineProvenance
      let binding = provenance[baseline.membership] ?? baseline
      guard
        (requiredRemovals[try membershipHistoryPair(binding.pair)] ?? []).isSubset(
          of: binding.observedRemovalIds)
      else {
        throw failure(
          "A live membership must observe every strict removal for its exact Item/List pair.",
          "/memberships/\(index)/id")
      }
    }
  }

  func validatedMembershipRemovalAuthority() throws -> [PlannerMembershipPair: Set<UUID>] {
    try unique(
      backup.membershipProvenance.map(\.membership), "/membershipProvenance", "membershipId")
    try unique(backup.membershipRemovals.map(\.deletionId), "/membershipRemovals", "deletionId")
    let provenance = Dictionary(
      uniqueKeysWithValues: backup.membershipProvenance.map { ($0.membership, $0) })
    let markers = Dictionary(
      uniqueKeysWithValues: backup.deletionMarkers.map { ($0.deletionId, $0) })
    var removalPairs: [UUID: PlannerMembershipPair] = [:]
    var removalBindings: [UUID: PlannerPortableMembershipProvenance] = [:]
    for (index, removal) in backup.membershipRemovals.enumerated() {
      guard let target = markers[removal.deletionId]?.target.importIdentity,
        target.kind == .membership, let binding = provenance[target]
      else {
        throw failure(
          "A strict membership removal needs its retained marker and pair binding.",
          "/membershipRemovals/\(index)/deletionId")
      }
      removalPairs[removal.deletionId] = try membershipHistoryPair(binding.pair)
      removalBindings[removal.deletionId] = binding
    }
    for (index, binding) in backup.membershipProvenance.enumerated() {
      try validateProvenanceBinding(binding, index: index)
    }
    for (index, binding) in backup.membershipProvenance.enumerated() {
      var observed: Set<UUID> = []
      for (observedIndex, identifier) in binding.observedRemovalIds.enumerated() {
        guard observed.insert(identifier).inserted,
          removalPairs[identifier] == (try membershipHistoryPair(binding.pair))
        else {
          throw failure(
            "An observation must name a distinct strict removal for this exact Item/List pair.",
            "/membershipProvenance/\(index)/observedRemovalIds/\(observedIndex)")
        }
      }
    }
    try validateRemovalCausality(removalBindings)
    var requiredRemovals: [PlannerMembershipPair: Set<UUID>] = [:]
    for (identifier, pair) in removalPairs {
      requiredRemovals[pair, default: []].insert(identifier)
    }
    return requiredRemovals
  }

  private func validateProvenanceBinding(
    _ binding: PlannerPortableMembershipProvenance, index: Int
  ) throws {
    let path = "/membershipProvenance/\(index)"
    if let member = backup.memberships.first(where: {
      $0.id == binding.membershipId && $0.lifetimeId == binding.membershipLifetimeId
    }) {
      let actual = member.baselineProvenance
      try requireProvenanceEndpoint(binding.list, matches: actual.list, path: path + "/list")
      try requireProvenanceEndpoint(binding.item, matches: actual.item, path: path + "/item")
    } else {
      let aliased = backup.contextAliases.contains {
        $0.context.importContextIdentities.contains(binding.membership)
      }
      guard isClosed(binding.membership) || aliased else {
        throw failure(
          "Retired membership provenance needs its retained closure or original context.",
          path + "/membershipId")
      }
    }
    try requireKnownProvenanceEndpoint(
      binding.list, kind: .list, pair: binding.pair, path: path + "/list")
    try requireKnownProvenanceEndpoint(
      binding.item, kind: .item, pair: binding.pair, path: path + "/item")
  }

  private func requireProvenanceEndpoint(
    _ binding: PlannerBoundSource, matches actual: PlannerBoundSource, path: String
  ) throws {
    guard binding.kind == actual.kind else {
      throw failure("Membership provenance names the wrong source kind.", path + "/kind")
    }
    guard binding.id == actual.id else {
      throw failure("Membership provenance names a different source.", path + "/id")
    }
    if binding.lifetimeId == actual.lifetimeId { return }
    guard backup.formatVersion >= 5, binding.kind == .item,
      resolves(
        .init(kind: .item, id: binding.id, lifetimeId: binding.lifetimeId),
        to: .init(kind: .item, id: actual.id, lifetimeId: actual.lifetimeId))
    else {
      throw failure(
        "Membership provenance names a different source lifetime.", path + "/lifetimeId")
    }
  }

  private func requireKnownProvenanceEndpoint(
    _ binding: PlannerBoundSource, kind: PlannerPortableIdentityKind,
    pair: PlannerMembershipPair, path: String
  ) throws {
    guard binding.kind.rawValue == kind.rawValue else {
      throw failure("Membership provenance names the wrong source kind.", path + "/kind")
    }
    let identity = PlannerPortableBoundIdentity(
      kind: kind, id: binding.id, lifetimeId: binding.lifetimeId)
    if isClosed(identity) { return }
    if let live = liveIdentity(for: identity) {
      guard resolves(identity, to: live) else {
        throw failure("The retained source lifetime is unknown.", path + "/lifetimeId")
      }
      return
    }
    if backup.memberships.contains(where: { $0.baselineProvenance.pair == pair }) { return }
    throw failure("The retained source binding is unknown.", path + "/id")
  }

  private func validateRemovalCausality(
    _ bindings: [UUID: PlannerPortableMembershipProvenance]
  ) throws {
    var remaining: [UUID: Int] = [:]
    var dependents: [UUID: [UUID]] = [:]
    for (identifier, binding) in bindings {
      remaining[identifier] = binding.observedRemovalIds.count
      for predecessor in binding.observedRemovalIds {
        dependents[predecessor, default: []].append(identifier)
      }
    }
    var ready = remaining.filter { $0.value == 0 }.map(\.key)
    while let identifier = ready.popLast() {
      remaining.removeValue(forKey: identifier)
      for dependent in dependents[identifier] ?? [] {
        guard let count = remaining[dependent] else { continue }
        remaining[dependent] = count - 1
        if count == 1 { ready.append(dependent) }
      }
    }
    guard !remaining.isEmpty else { return }
    let cyclicMemberships = Set(remaining.keys.compactMap { bindings[$0]?.membership })
    let index = backup.membershipProvenance.firstIndex {
      cyclicMemberships.contains($0.membership)
    }
    let path =
      index.map { "/membershipProvenance/\($0)/observedRemovalIds" } ?? "/membershipRemovals"
    throw failure("Membership removal history must not contain a causal cycle.", path)
  }
}

extension PlannerPortableMembership {
  var baselineProvenance: PlannerPortableMembershipProvenance {
    .init(
      membershipId: id, membershipLifetimeId: lifetimeId,
      list: .init(kind: .list, id: list.id, lifetimeId: listLifetimeId),
      item: .init(kind: .item, id: item.id, lifetimeId: itemLifetimeId), observedRemovalIds: [])
  }
}

extension PlannerPortableBackup {
  var usesMembershipProvenanceFormat: Bool {
    formatVersion >= 3 || !membershipProvenance.isEmpty || !membershipRemovals.isEmpty
  }

  var resolvedMembershipProvenance: [PlannerPortableMembershipProvenance] {
    let explicit = Set(membershipProvenance.map(\.membership))
    let implicit = memberships.map(\.baselineProvenance).filter {
      !explicit.contains($0.membership)
    }
    return (membershipProvenance + implicit).map(\.normalized).sorted {
      if $0.membershipId != $1.membershipId {
        return $0.membershipId.uuidString < $1.membershipId.uuidString
      }
      return $0.membershipLifetimeId.uuidString < $1.membershipLifetimeId.uuidString
    }
  }
}

extension PlannerNativeLineage {
  func provenanceForNewMembership(
    _ membership: MembershipSnapshot, markers: [PortableDeletionMarker]
  )
    throws -> PlannerPortableMembershipProvenance
  {
    var observedRemovalIdentifiers: [UUID] = []
    for removal in membershipRemovals {
      guard let marker = markers.first(where: { $0.deletionId == removal.deletionId }),
        case .membership(let removedMembership) = marker.target,
        let retained = membershipProvenance.first(where: {
          $0.membershipId == removedMembership.id
            && $0.membershipLifetimeId == removedMembership.lifetimeId
        })
      else {
        throw PlannerFailure(
          "readUnavailable", "A strict membership removal has no retained pair binding.")
      }
      if retained.list.id == membership.list.id,
        retained.list.lifetimeId == membership.list.lifetimeId,
        retained.item.id == membership.item.id,
        retained.item.lifetimeId == membership.item.lifetimeId
      {
        observedRemovalIdentifiers.append(removal.deletionId)
      }
    }
    return PlannerPortableMembershipProvenance(
      membershipId: membership.id, membershipLifetimeId: membership.lifetimeId,
      list: .init(kind: .list, id: membership.list.id, lifetimeId: membership.list.lifetimeId),
      item: .init(kind: .item, id: membership.item.id, lifetimeId: membership.item.lifetimeId),
      observedRemovalIds: observedRemovalIdentifiers
    ).normalized
  }
}

func plannerSortedMembershipEvidence(_ evidence: [PlannerPortableMembershipProvenance])
  -> [PlannerPortableMembershipProvenance]
{
  evidence.map(\.normalized).sorted {
    if $0.membershipId != $1.membershipId {
      return $0.membershipId.uuidString < $1.membershipId.uuidString
    }
    return $0.membershipLifetimeId.uuidString < $1.membershipLifetimeId.uuidString
  }
}

extension MembershipSnapshot {
  var baselineProvenance: PlannerPortableMembershipProvenance {
    .init(
      membershipId: id, membershipLifetimeId: lifetimeId,
      list: .init(kind: .list, id: list.id, lifetimeId: list.lifetimeId),
      item: .init(kind: .item, id: item.id, lifetimeId: item.lifetimeId), observedRemovalIds: [])
  }
}

extension PlannerImportGraph {
  /// The caller validates the complete snapshot before resolving action identities.
  func resolvedMembershipForAction(listIdentifier: UUID, membershipIdentifier: UUID) throws
    -> PlannerPortableMembership
  {
    let missing = PlannerFailure(
      "missingReference", "The selected membership is missing or unresolved.")
    let direct = backup.memberships.filter { $0.id == membershipIdentifier }
    if !direct.isEmpty {
      guard direct.count == 1, let member = direct.first, member.list.id == listIdentifier else {
        throw missing
      }
      return member
    }
    let aliases = backup.contextAliases.filter {
      $0.context.importContextIdentities.contains {
        $0.kind == .membership && $0.id == membershipIdentifier
      }
    }
    let requiredRemovals = try validatedMembershipRemovalAuthority()
    var originalBindings: Set<PlannerPortableBoundIdentity> = []
    var canonicalBindings: Set<PlannerPortableBoundIdentity> = []
    for alias in aliases {
      guard
        let original = alias.context.importContextIdentities.first(where: {
          $0.kind == .membership
        }),
        let canonical = alias.canonicalContext.importContextIdentities.first(where: {
          $0.kind == .membership
        }), !isClosed(original), !isClosed(canonical),
        let binding = retainedMembershipProvenance(for: original),
        binding.list.id == listIdentifier,
        (requiredRemovals[try membershipHistoryPair(binding.pair)] ?? []).isSubset(
          of: binding.observedRemovalIds),
        let target = backup.memberships.first(where: {
          $0.id == canonical.id && $0.lifetimeId == canonical.lifetimeId
        }), target.baselineProvenance.pair == binding.pair,
        let targetBinding = membershipProvenance(for: canonical),
        Set(targetBinding.observedRemovalIds) == Set(binding.observedRemovalIds)
      else { continue }
      originalBindings.insert(original)
      canonicalBindings.insert(canonical)
    }
    guard originalBindings.count == 1, canonicalBindings.count == 1,
      let canonical = canonicalBindings.first,
      let member = backup.memberships.first(where: {
        $0.id == canonical.id && $0.lifetimeId == canonical.lifetimeId
          && $0.list.id == listIdentifier
      })
    else { throw missing }
    return member
  }
}
