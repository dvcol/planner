import Foundation

private struct PlannerImportIdentityKey: Hashable {
  let kind: PlannerPortableIdentityKind
  let id: UUID
}

struct PlannerImportGraph {
  let backup: PlannerPortableBackup
  let liveIdentities: [PlannerPortableBoundIdentity]
  private let liveByIdentity: [PlannerImportIdentityKey: PlannerPortableBoundIdentity]
  private let closedIdentities: Set<PlannerPortableBoundIdentity>
  private let closedRecordKeys: Set<PlannerImportIdentityKey>

  init(backup: PlannerPortableBackup) {
    self.backup = backup
    let identities =
      backup.sources.map(\.importIdentity)
      + backup.schedules.map { .init(kind: .schedule, id: $0.id, lifetimeId: $0.lifetimeId) }
      + backup.memberships.map { .init(kind: .membership, id: $0.id, lifetimeId: $0.lifetimeId) }
      + backup.itineraryEntries.map {
        .init(kind: .itineraryEntry, id: $0.id, lifetimeId: $0.lifetimeId)
      }
      + backup.labelAssociations.map {
        .init(kind: .labelAssociation, id: $0.id, lifetimeId: $0.lifetimeId)
      }
      + backup.ownedLinks.map { .init(kind: .ownedLink, id: $0.id, lifetimeId: $0.lifetimeId) }
    liveIdentities = identities
    liveByIdentity = Dictionary(
      identities.map { (PlannerImportIdentityKey(kind: $0.kind, id: $0.id), $0) },
      uniquingKeysWith: { first, _ in first })
    let closedFamilies = Set(backup.deletionMarkers.compactMap(\.closedFamilyId))
    let familyCandidates = backup.restorationFamilies.filter {
      closedFamilies.contains($0.familyId)
    }
    .flatMap { family in
      family.candidates.map {
        PlannerPortableBoundIdentity(
          kind: family.predecessor.kind, id: family.predecessor.id,
          lifetimeId: $0.lifetimeId)
      }
    }
    closedIdentities = Set(
      backup.deletionMarkers.compactMap { $0.target.importIdentity } + familyCandidates)
    closedRecordKeys = Set(closedIdentities.map { .init(kind: $0.kind, id: $0.id) })
  }

  func liveIdentity(for reference: PlannerPortableBoundIdentity) -> PlannerPortableBoundIdentity? {
    liveByIdentity[.init(kind: reference.kind, id: reference.id)]
  }

  func failure(_ message: String, _ path: String) -> PlannerFailure {
    .init("invalidInput", message, propertyPath: path)
  }

  func validate() throws {
    try unique(backup.sources.map { $0.kind.rawValue + ":" + $0.id.uuidString }, "/sources", "id")
    try unique(backup.memberships.map(\.id), "/memberships", "id")
    try unique(backup.itineraryEntries.map(\.id), "/itineraryEntries", "id")
    try unique(backup.expandedCompletions.map(\.context), "/expandedCompletions", "context")
    try unique(backup.schedules.map(\.id), "/schedules", "id")
    try unique(backup.labelAssociations.map(\.id), "/labelAssociations", "id")
    try unique(backup.ownedLinks.map(\.id), "/ownedLinks", "id")
    try unique(backup.deletionMarkers.map(\.deletionId), "/deletionMarkers", "deletionId")
    try unique(backup.contextAliases.map(\.aliasId), "/contextAliases", "aliasId")
    try unique(backup.completionChanges.map(\.id), "/completionChanges", "id")
    try unique(backup.restorationFamilies.map(\.familyId), "/restorationFamilies", "familyId")
    try unique(
      backup.memberships.map { $0.list.id.uuidString + ":" + $0.item.id.uuidString },
      "/memberships", "item")
    try unique(
      backup.labelAssociations.map {
        $0.owner.kind.rawValue + ":" + $0.owner.id.uuidString + ":" + $0.label.kind.rawValue + ":"
          + $0.label.id.uuidString
      }, "/labelAssociations", "label")
    try plannerValidateCompletionHistoryReferences(
      aliases: backup.contextAliases, changes: backup.completionChanges,
      deletionMarkers: backup.deletionMarkers)
    try validateRestorations()
    try validateDeletions()
    try validateMembershipProvenance()
    for (index, expanded) in backup.expandedCompletions.enumerated() {
      _ = try contextState(
        .expandedListItem(expanded.context), path: "/expandedCompletions/\(index)/context")
    }
    try validateCompletionHistory()
  }

  func unique<Value: Hashable>(_ values: [Value], _ path: String, _ property: String) throws {
    var seen: Set<Value> = []
    for (index, value) in values.enumerated() {
      guard seen.insert(value).inserted else {
        throw failure(
          "The backup contains a duplicate identity or logical key.", path + "/\(index)/" + property
        )
      }
    }
  }

  func resolves(_ reference: PlannerPortableBoundIdentity, to live: PlannerPortableBoundIdentity)
    -> Bool
  {
    guard reference.kind == live.kind, reference.id == live.id else { return false }
    if reference.lifetimeId == live.lifetimeId { return true }
    return backup.restorationFamilies.contains { family in
      family.predecessor.kind == live.kind && family.predecessor.id == live.id
        && family.candidates.contains { $0.lifetimeId == reference.lifetimeId }
        && family.candidates.contains { $0.lifetimeId == live.lifetimeId }
        && !backup.deletionMarkers.contains { $0.closedFamilyId == family.familyId }
    }
  }

  func isClosed(_ identity: PlannerPortableBoundIdentity) -> Bool {
    closedIdentities.contains(identity)
  }

  func authorizesPredecessorValues(
    _ predecessor: PlannerPortableBoundIdentity, for live: PlannerPortableBoundIdentity
  ) -> Bool {
    guard predecessor.kind == live.kind, predecessor.id == live.id, isClosed(predecessor) else {
      return false
    }
    let closedFamilies = Set(backup.deletionMarkers.compactMap(\.closedFamilyId))
    var pendingPredecessors = [predecessor]
    var visitedPredecessors: Set<PlannerPortableBoundIdentity> = []
    while let currentPredecessor = pendingPredecessors.popLast() {
      guard visitedPredecessors.insert(currentPredecessor).inserted else { continue }
      for family in backup.restorationFamilies where family.predecessor == currentPredecessor {
        for candidate in family.candidates {
          let identity = PlannerPortableBoundIdentity(
            kind: predecessor.kind, id: predecessor.id, lifetimeId: candidate.lifetimeId)
          if closedFamilies.contains(family.familyId) {
            pendingPredecessors.append(identity)
          } else if identity == live {
            return true
          }
        }
      }
    }
    return false
  }

  func isClosed(_ context: PlannerPortableCompletionContext) -> Bool {
    if backup.deletionMarkers.contains(where: { $0.target.closes(context) }) {
      guard case .expandedListItem(let expanded) = context,
        hasAuthorizedExpandedAssertion(expanded)
      else { return true }
    }
    return context.importContextIdentities.contains(where: isClosed)
  }

  private func hasAuthorizedExpandedAssertion(_ context: PlannerExpandedContext) -> Bool {
    guard backup.formatVersion >= 4 else { return false }
    let contributions = backup.contextAliases.filter {
      $0.canonicalContext == .expandedListItem(context)
    }
    let closures = plannerExpandedCompletionDeletionIdentifiers(
      contributions: contributions, deletionMarkers: backup.deletionMarkers)
    guard !closures.isEmpty else { return false }
    return backup.completionChanges.contains { change in
      contributions.contains { $0.aliasId == change.aliasId }
        && closures.isSubset(of: Set(change.observedExpandedCompletionDeletionIds))
    }
  }

  func restoredValueFamily(
    for source: PlannerPortableBoundIdentity, to live: PlannerPortableBoundIdentity?,
    in incoming: PlannerPortableBackup
  ) throws -> PlannerPortableRestorationFamily? {
    var selectedFamily = incoming.restorationFamilies.first(where: { family in
      guard family.predecessor.kind == source.kind, family.predecessor.id == source.id,
        family.candidates.contains(where: { $0.lifetimeId == source.lifetimeId })
      else { return false }
      if let live { return authorizesPredecessorValues(family.predecessor, for: live) }
      return isClosed(family.predecessor)
    })
    if selectedFamily == nil, let live, source != live, resolves(source, to: live) {
      selectedFamily = backup.restorationFamilies.first { family in
        family.predecessor.kind == source.kind && family.predecessor.id == source.id
          && family.candidates.contains { $0.lifetimeId == source.lifetimeId }
          && family.candidates.contains { $0.lifetimeId == live.lifetimeId }
          && !backup.deletionMarkers.contains { $0.closedFamilyId == family.familyId }
      }
    }
    guard let family = selectedFamily else { return nil }
    guard !incoming.deletionMarkers.contains(where: { $0.closedFamilyId == family.familyId })
    else {
      throw PlannerFailure("unavailable", "A closed competing family cannot replace live values.")
    }
    for related in incoming.restorationFamilies
    where related.predecessor.kind == source.kind && related.predecessor.id == source.id {
      let knownFamily = backup.restorationFamilies.first { $0.familyId == related.familyId }
      if let knownFamily, knownFamily.predecessor != related.predecessor {
        throw PlannerFailure("unavailable", "A known restoration family names another predecessor.")
      }
      if related.familyId != family.familyId {
        guard let knownFamily,
          Set(knownFamily.candidates.map { $0.lifetimeId.uuidString + $0.operationId.uuidString })
            == Set(related.candidates.map { $0.lifetimeId.uuidString + $0.operationId.uuidString })
        else {
          throw PlannerFailure("unavailable", "Other incoming restoration history is not retained.")
        }
      }
      for candidate in related.candidates {
        guard
          let known = backup.restorationFamilies.first(where: {
            $0.predecessor.kind == source.kind && $0.predecessor.id == source.id
              && $0.candidates.contains { $0.lifetimeId == candidate.lifetimeId }
          }),
          let knownCandidate = known.candidates.first(where: {
            $0.lifetimeId == candidate.lifetimeId
          })
        else { continue }
        guard known.predecessor == related.predecessor,
          knownCandidate.operationId == candidate.operationId
        else {
          throw PlannerFailure(
            "unavailable", "A known restoration candidate has conflicting provenance.")
        }
      }
    }
    for marker in incoming.deletionMarkers
    where marker.target.importIdentity.map({ $0.kind == source.kind && $0.id == source.id }) == true
    {
      guard let known = backup.deletionMarkers.first(where: { $0.deletionId == marker.deletionId }),
        known.operationId == marker.operationId, known.closedFamilyId == marker.closedFamilyId,
        known.target.importCanonicalValue.encoded() == marker.target.importCanonicalValue.encoded()
      else {
        throw PlannerFailure("unavailable", "Incoming values cannot add source-deletion authority.")
      }
    }
    return family
  }

  private func validateRestorations() throws {
    try unique(backup.restorationFamilies.map(\.predecessor), "/restorationFamilies", "predecessor")
    var candidateFamilies: [PlannerPortableBoundIdentity: Int] = [:]
    for (index, family) in backup.restorationFamilies.enumerated() {
      let path = "/restorationFamilies/\(index)"
      guard !family.candidates.isEmpty else {
        throw failure(
          "A restoration family needs at least one candidate.", path + "/candidates")
      }
      try unique(family.candidates.map(\.lifetimeId), path + "/candidates", "lifetimeId")
      guard isClosed(family.predecessor) else {
        throw failure(
          "A restoration predecessor must have declared closure history.", path + "/predecessor")
      }
      for (candidateIndex, candidate) in family.candidates.enumerated() {
        let identity = PlannerPortableBoundIdentity(
          kind: family.predecessor.kind, id: family.predecessor.id, lifetimeId: candidate.lifetimeId
        )
        guard candidate.lifetimeId != family.predecessor.lifetimeId,
          candidateFamilies[identity] == nil
        else {
          throw failure(
            "Restoration candidates must have distinct new lifetimes.",
            path + "/candidates/\(candidateIndex)/lifetimeId")
        }
        candidateFamilies[identity] = index
      }
      if let live = liveIdentities.first(where: {
        $0.kind == family.predecessor.kind && $0.id == family.predecessor.id
      }), family.candidates.contains(where: { $0.lifetimeId == live.lifetimeId }) {
        guard
          live.lifetimeId
            == family.candidates.map(\.lifetimeId).min(by: { $0.uuidString < $1.uuidString })
        else {
          throw failure(
            "The restored live record must use the stable candidate lifetime.", path + "/candidates"
          )
        }
      }
    }
    for (index, family) in backup.restorationFamilies.enumerated() {
      var seen: Set<Int> = [index]
      var predecessor = family.predecessor
      while let parent = candidateFamilies[predecessor] {
        guard seen.insert(parent).inserted else {
          throw failure(
            "Restoration history must not contain a cycle.",
            "/restorationFamilies/\(index)/predecessor")
        }
        predecessor = backup.restorationFamilies[parent].predecessor
      }
    }
  }

  private func validateDeletions() throws {
    for (index, marker) in backup.deletionMarkers.enumerated() {
      let path = "/deletionMarkers/\(index)"
      if let familyId = marker.closedFamilyId {
        guard let family = backup.restorationFamilies.first(where: { $0.familyId == familyId }),
          let target = marker.target.importIdentity,
          family.predecessor.kind == target.kind, family.predecessor.id == target.id,
          family.candidates.contains(where: { $0.lifetimeId == target.lifetimeId })
        else {
          throw failure(
            "A family closure must target a declared candidate of that family.",
            path + "/closedFamilyId")
        }
      }
      if case .expandedCompletion(let context) = marker.target,
        backup.expandedCompletions.contains(where: { $0.context == context }),
        !hasAuthorizedExpandedAssertion(context)
      {
        throw failure("A deleted expanded completion remains present.", path + "/target/context")
      }
    }
    let groups: [(String, [PlannerPortableBoundIdentity])] = [
      ("sources", backup.sources.map(\.importIdentity)),
      (
        "schedules",
        backup.schedules.map { .init(kind: .schedule, id: $0.id, lifetimeId: $0.lifetimeId) }
      ),
      (
        "memberships",
        backup.memberships.map { .init(kind: .membership, id: $0.id, lifetimeId: $0.lifetimeId) }
      ),
      (
        "itineraryEntries",
        backup.itineraryEntries.map {
          .init(kind: .itineraryEntry, id: $0.id, lifetimeId: $0.lifetimeId)
        }
      ),
      (
        "labelAssociations",
        backup.labelAssociations.map {
          .init(kind: .labelAssociation, id: $0.id, lifetimeId: $0.lifetimeId)
        }
      ),
      (
        "ownedLinks",
        backup.ownedLinks.map { .init(kind: .ownedLink, id: $0.id, lifetimeId: $0.lifetimeId) }
      ),
    ]
    for (group, identities) in groups {
      for (index, identity) in identities.enumerated() {
        if isClosed(identity) {
          throw failure(
            "A closed record remains live in the backup.", "/\(group)/\(index)/lifetimeId")
        }
        if closedRecordKeys.contains(.init(kind: identity.kind, id: identity.id)) {
          guard
            backup.restorationFamilies.contains(where: { family in
              family.predecessor.kind == identity.kind && family.predecessor.id == identity.id
                && family.candidates.contains { $0.lifetimeId == identity.lifetimeId }
            })
          else {
            throw failure(
              "A new lifetime for a closed identity requires declared restoration history.",
              "/\(group)/\(index)/lifetimeId")
          }
        }
      }
    }
  }

  private func contextState(
    _ context: PlannerPortableCompletionContext, path: String, allowClosed: Bool = false,
    allowRetiredMembership: Bool = false,
    suppressedMemberships: Set<PlannerPortableBoundIdentity> = []
  ) throws -> Bool? {
    if allowClosed && isClosed(context) { return nil }
    switch context {
    case .listMembership(let identifier, let lifetime):
      let binding = PlannerPortableBoundIdentity(
        kind: .membership, id: identifier, lifetimeId: lifetime)
      guard let membership = backup.memberships.first(where: { $0.id == identifier }),
        resolves(
          binding,
          to: .init(kind: .membership, id: membership.id, lifetimeId: membership.lifetimeId))
      else {
        if allowRetiredMembership || suppressedMemberships.contains(binding),
          retainedMembershipProvenance(for: binding) != nil
        {
          return nil
        }
        throw failure(
          "The completion context has no declared membership lifetime.", path + "/membershipId")
      }
      return membership.localDone
    case .directItineraryItem(let identifier, let lifetime):
      let binding = PlannerPortableBoundIdentity(
        kind: .itineraryEntry, id: identifier, lifetimeId: lifetime)
      guard let entry = backup.itineraryEntries.first(where: { $0.id == identifier }),
        entry.source.kind == .item,
        resolves(
          binding, to: .init(kind: .itineraryEntry, id: entry.id, lifetimeId: entry.lifetimeId))
      else {
        throw failure(
          "The completion context has no declared direct Item entry lifetime.", path + "/entryId")
      }
      return entry.localDone
    case .expandedListItem(let context):
      let entryBinding = PlannerPortableBoundIdentity(
        kind: .itineraryEntry, id: context.listEntryId, lifetimeId: context.listEntryLifetimeId)
      let membershipBinding = PlannerPortableBoundIdentity(
        kind: .membership, id: context.membershipId, lifetimeId: context.membershipLifetimeId)
      guard let entry = backup.itineraryEntries.first(where: { $0.id == context.listEntryId }),
        entry.source.kind == .list,
        resolves(
          entryBinding, to: .init(kind: .itineraryEntry, id: entry.id, lifetimeId: entry.lifetimeId)
        )
      else {
        throw failure(
          "The expanded context has no declared List entry lifetime.", path + "/listEntryId")
      }
      let membership: PlannerPortableMembershipProvenance
      let retired: Bool
      if let live = backup.memberships.first(where: { $0.id == context.membershipId }),
        resolves(
          membershipBinding, to: .init(kind: .membership, id: live.id, lifetimeId: live.lifetimeId))
      {
        membership = live.baselineProvenance
        retired = false
      } else if allowRetiredMembership || suppressedMemberships.contains(membershipBinding),
        let retained = retainedMembershipProvenance(for: membershipBinding)
      {
        membership = retained
        retired = true
      } else {
        throw failure(
          "The expanded context has no declared membership lifetime.", path + "/membershipId")
      }
      guard
        resolves(
          .init(kind: .list, id: membership.list.id, lifetimeId: membership.list.lifetimeId),
          to: .init(kind: .list, id: entry.source.id, lifetimeId: entry.sourceLifetimeId))
      else {
        throw failure(
          "The membership belongs to a different List than this entry.", path + "/membershipId")
      }
      if retired { return nil }
      return backup.expandedCompletions.first(where: { $0.context == context })?.localDone ?? false
    }
  }

  private func sameLogicalContext(
    _ first: PlannerPortableCompletionContext, _ second: PlannerPortableCompletionContext
  ) -> Bool {
    switch (first, second) {
    case (
      .listMembership(let firstId, let firstLifetime),
      .listMembership(let secondId, let secondLifetime)
    ):
      if firstId == secondId {
        return resolves(
          .init(kind: .membership, id: firstId, lifetimeId: firstLifetime),
          to: .init(kind: .membership, id: secondId, lifetimeId: secondLifetime))
      }
      if backup.usesMembershipProvenanceFormat {
        guard
          let first = membershipProvenance(
            for: .init(kind: .membership, id: firstId, lifetimeId: firstLifetime)),
          let second = membershipProvenance(
            for: .init(kind: .membership, id: secondId, lifetimeId: secondLifetime))
        else { return false }
        guard let firstPair = try? membershipHistoryPair(first.pair),
          let secondPair = try? membershipHistoryPair(second.pair)
        else { return false }
        return firstPair == secondPair
          && first.normalized.observedRemovalIds == second.normalized.observedRemovalIds
      }
      if let firstMember = backup.memberships.first(where: { $0.id == firstId }),
        let secondMember = backup.memberships.first(where: { $0.id == secondId })
      {
        return firstMember.list == secondMember.list && firstMember.item == secondMember.item
      }
      return false
    case (
      .directItineraryItem(let firstId, let firstLifetime),
      .directItineraryItem(let secondId, let secondLifetime)
    ):
      return resolves(
        .init(kind: .itineraryEntry, id: firstId, lifetimeId: firstLifetime),
        to: .init(kind: .itineraryEntry, id: secondId, lifetimeId: secondLifetime))
    case (.expandedListItem(let firstContext), .expandedListItem(let secondContext)):
      return resolves(
        .init(
          kind: .itineraryEntry, id: firstContext.listEntryId,
          lifetimeId: firstContext.listEntryLifetimeId),
        to: .init(
          kind: .itineraryEntry, id: secondContext.listEntryId,
          lifetimeId: secondContext.listEntryLifetimeId))
        && sameLogicalContext(
          .listMembership(
            membershipId: firstContext.membershipId,
            membershipLifetimeId: firstContext.membershipLifetimeId),
          .listMembership(
            membershipId: secondContext.membershipId,
            membershipLifetimeId: secondContext.membershipLifetimeId))
    default: return false
    }
  }

  private func validateCompletionHistory() throws {
    let suppressedMemberships = try suppressedMembershipIdentities()
    let changes = Dictionary(uniqueKeysWithValues: backup.completionChanges.map { ($0.id, $0) })
    for (index, alias) in backup.contextAliases.enumerated() {
      let path = "/contextAliases/\(index)"
      _ = try contextState(
        alias.context, path: path + "/context", allowClosed: true, allowRetiredMembership: true)
      _ = try contextState(
        alias.canonicalContext, path: path + "/canonicalContext", allowClosed: true,
        suppressedMemberships: suppressedMemberships)
      guard sameLogicalContext(alias.context, alias.canonicalContext) else {
        throw failure(
          "Aliases must retain the same logical context; repeated route entries stay independent.",
          path + "/canonicalContext")
      }
    }
    let groups = Dictionary(grouping: backup.contextAliases, by: \.canonicalContext)
    for (context, contributions) in groups {
      let expected = plannerCompletionHistoryValue(
        contributions: contributions, changes: changes, deletionMarkers: backup.deletionMarkers)
      if let actual = try contextState(
        context, path: "/contextAliases", allowClosed: true,
        suppressedMemberships: suppressedMemberships), actual != expected
      {
        let index = backup.contextAliases.firstIndex { $0.canonicalContext == context }!
        throw failure(
          "Saved local completion disagrees with its declared canonical history.",
          "/contextAliases/\(index)/canonicalContext")
      }
    }
  }

}

extension PlannerPortableSource {
  var importIdentity: PlannerPortableBoundIdentity {
    let lifetime: UUID
    switch self {
    case .item(let item): lifetime = item.lifetimeId
    case .list(let list): lifetime = list.lifetimeId
    case .itinerary(let itinerary): lifetime = itinerary.lifetimeId
    case .category(let category): lifetime = category.lifetimeId
    case .tag(let tag): lifetime = tag.lifetimeId
    }
    return .init(kind: .init(rawValue: kind.rawValue)!, id: id, lifetimeId: lifetime)
  }
}

extension PlannerPortableDeletionTarget {
  var importIdentity: PlannerPortableBoundIdentity? {
    switch self {
    case .source(let source, let lifetime):
      .init(kind: .init(rawValue: source.kind.rawValue)!, id: source.id, lifetimeId: lifetime)
    case .membership(let identifier, let lifetime):
      .init(kind: .membership, id: identifier, lifetimeId: lifetime)
    case .itineraryEntry(let identifier, let lifetime):
      .init(kind: .itineraryEntry, id: identifier, lifetimeId: lifetime)
    case .labelAssociation(let identifier, let lifetime):
      .init(kind: .labelAssociation, id: identifier, lifetimeId: lifetime)
    case .ownedLink(let identifier, let lifetime):
      .init(kind: .ownedLink, id: identifier, lifetimeId: lifetime)
    case .expandedCompletion: nil
    }
  }
}
