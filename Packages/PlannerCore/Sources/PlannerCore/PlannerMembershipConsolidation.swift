import CryptoKit
import Foundation
import SwiftData

struct PlannerMembershipConsolidation {
  let backup: PlannerPortableBackup

  static func aliasesRequiringCanonicalRootResolution(
    memberships: [PlannerPortableMembershipProvenance], aliases: [PlannerPortableContextAlias],
    provenance: [PlannerPortableMembershipProvenance]
  ) -> [PlannerPortableContextAlias] {
    let retained = Dictionary(
      uniqueKeysWithValues: provenance.map { ($0.membership, $0.normalized) })
    let liveIdentities = Set(memberships.map(\.membership))
    let available = memberships.map { retained[$0.membership] ?? $0.normalized }
    return aliases.filter { alias in
      guard sameScope(alias.context, alias.canonicalContext),
        let original = membership(in: alias.context),
        let root = membership(in: alias.canonicalContext), !liveIdentities.contains(root),
        let originalBinding = retained[original]
          ?? available.first(where: { $0.membership == original }),
        let rootBinding = retained[root], originalBinding.pair == rootBinding.pair,
        originalBinding.observedRemovalIds == rootBinding.observedRemovalIds
      else { return false }
      return available.contains {
        $0.membershipId != root.id && $0.pair == rootBinding.pair
          && $0.observedRemovalIds == rootBinding.observedRemovalIds
      }
    }
  }

  static func membershipsRetiredByClosedCanonicalAliases(
    aliases: [PlannerPortableContextAlias], provenance: [PlannerPortableMembershipProvenance],
    graph: PlannerImportGraph
  ) -> Set<PlannerPortableBoundIdentity> {
    let retained = Dictionary(
      uniqueKeysWithValues: provenance.map { ($0.membership, $0.normalized) })
    return Set(
      aliases.compactMap { alias in
        guard case .listMembership = alias.context,
          case .listMembership = alias.canonicalContext,
          let original = membership(in: alias.context),
          let canonical = membership(in: alias.canonicalContext), original.id != canonical.id,
          graph.isClosed(canonical), let originalBinding = retained[original],
          let canonicalBinding = retained[canonical], originalBinding.pair == canonicalBinding.pair,
          originalBinding.observedRemovalIds == canonicalBinding.observedRemovalIds
        else { return nil }
        return original
      })
  }

  private struct Generation: Hashable {
    let pair: PlannerMembershipPair
    let basis: [UUID]
  }

  init(snapshot: PlannerDataSnapshot, detachedExpanded: [PlannerPortableExpandedCompletion]) throws
  {
    let current = try snapshot.decodedRecords().backup
    let graph = PlannerImportGraph(backup: current)
    let requiredRemovals = try graph.validatedMembershipRemovalAuthority()
    var provenance = Dictionary(
      uniqueKeysWithValues: current.membershipProvenance.map { ($0.membership, $0.normalized) })
    var memberPairs: [PlannerPortableBoundIdentity: PlannerMembershipPair] = [:]
    for member in current.memberships {
      let binding = member.baselineProvenance
      if let previous = memberPairs[binding.membership], previous != binding.pair {
        throw Self.unresolved("Copies of a membership disagree on their source bindings.")
      }
      memberPairs[binding.membership] = binding.pair
      if let retained = provenance[binding.membership] {
        guard retained.pair == binding.pair else {
          throw Self.unresolved("Membership provenance describes another source pair.")
        }
      } else {
        provenance[binding.membership] = binding
      }
    }
    var eligible: [PlannerPortableMembership] = []
    var eligibleLifetimes: [UUID: UUID] = [:]
    let retiredMemberships = Self.membershipsRetiredByClosedCanonicalAliases(
      aliases: current.contextAliases, provenance: Array(provenance.values), graph: graph)
    var closedMembershipIdentities: Set<PlannerPortableBoundIdentity> = []
    var suppressed: [Generation: [PlannerPortableMembership]] = [:]
    for member in current.memberships {
      let binding = try Self.binding(member.baselineProvenance.membership, in: provenance)
      if graph.isClosed(binding.membership) || retiredMemberships.contains(binding.membership) {
        closedMembershipIdentities.insert(binding.membership)
        continue
      }
      if (requiredRemovals[binding.pair] ?? []).isSubset(of: binding.observedRemovalIds) {
        if let previous = eligibleLifetimes[member.id], previous != member.lifetimeId {
          throw Self.unresolved("Competing membership lifetimes need restoration reconciliation.")
        }
        eligibleLifetimes[member.id] = member.lifetimeId
        eligible.append(member)
      } else {
        suppressed[.init(pair: binding.pair, basis: binding.observedRemovalIds), default: []]
          .append(member)
      }
    }
    var detachedGenerations: [Generation: [PlannerPortableExpandedCompletion]] = [:]
    var eligibleDetached: [PlannerPortableExpandedCompletion] = []
    for completion in detachedExpanded {
      let identity = PlannerPortableBoundIdentity(
        kind: .membership, id: completion.context.membershipId,
        lifetimeId: completion.context.membershipLifetimeId)
      let binding = try Self.binding(identity, in: provenance)
      if graph.isClosed(identity) || retiredMemberships.contains(identity) { continue }
      guard
        current.itineraryEntries.contains(where: {
          $0.id == completion.context.listEntryId
            && $0.lifetimeId == completion.context.listEntryLifetimeId
            && $0.source.kind == .list && $0.source.id == binding.list.id
            && $0.sourceLifetimeId == binding.list.lifetimeId
        })
      else {
        throw Self.unresolved("An unresolved completion has no proven membership scope.")
      }
      if (requiredRemovals[binding.pair] ?? []).isSubset(of: binding.observedRemovalIds) {
        eligibleDetached.append(completion)
        continue
      }
      detachedGenerations[.init(pair: binding.pair, basis: binding.observedRemovalIds), default: []]
        .append(completion)
    }
    var members = eligible
    var expanded = current.expandedCompletions.filter {
      !closedMembershipIdentities.contains(
        .init(
          kind: .membership, id: $0.context.membershipId,
          lifetimeId: $0.context.membershipLifetimeId))
    }
    var aliases = current.contextAliases
    let changes = Dictionary(uniqueKeysWithValues: current.completionChanges.map { ($0.id, $0) })
    let generations = Set(suppressed.keys).union(detachedGenerations.keys)
    for generation in generations {
      let contributions = suppressed[generation] ?? []
      let roots = provenance.values.filter {
        $0.pair == generation.pair && $0.observedRemovalIds == generation.basis
      }.sorted {
        if $0.membershipId != $1.membershipId {
          return $0.membershipId.uuidString < $1.membershipId.uuidString
        }
        return $0.membershipLifetimeId.uuidString < $1.membershipLifetimeId.uuidString
      }
      guard let root = roots.first(where: { graph.isClosed($0.membership) }) ?? roots.first else {
        throw Self.unresolved("A suppressed generation needs its retained membership binding.")
      }
      if !contributions.isEmpty {
        _ = try Self.normalize(
          canonical: .listMembership(
            membershipId: root.membershipId, membershipLifetimeId: root.membershipLifetimeId),
          contributions: contributions.map {
            (
              .listMembership(membershipId: $0.id, membershipLifetimeId: $0.lifetimeId),
              $0.localDone
            )
          }, pair: generation.pair, basis: generation.basis, provenance: provenance, graph: graph,
          aliases: &aliases, changes: changes)
      }
      let identities = Set(contributions.map { $0.baselineProvenance.membership })
      expanded.removeAll {
        identities.contains(
          .init(
            kind: .membership, id: $0.context.membershipId,
            lifetimeId: $0.context.membershipLifetimeId))
      }
      for entry in current.itineraryEntries
      where entry.source.kind == .list && entry.source.id == generation.pair.list.id
        && entry.sourceLifetimeId == generation.pair.list.lifetimeId
      {
        var initial: [(PlannerPortableCompletionContext, Bool)] = []
        for member in contributions {
          let context = PlannerExpandedContext(
            listEntryId: entry.id, listEntryLifetimeId: entry.lifetimeId,
            membershipId: member.id, membershipLifetimeId: member.lifetimeId)
          let states = current.expandedCompletions.filter { $0.context == context }.map(\.localDone)
          for value in states.isEmpty ? [false] : states {
            initial.append((.expandedListItem(context), value))
          }
        }
        initial += (detachedGenerations[generation] ?? []).filter {
          $0.context.listEntryId == entry.id && $0.context.listEntryLifetimeId == entry.lifetimeId
        }.map { (.expandedListItem($0.context), $0.localDone) }
        if initial.isEmpty { continue }
        _ = try Self.normalize(
          canonical: .expandedListItem(
            .init(
              listEntryId: entry.id, listEntryLifetimeId: entry.lifetimeId,
              membershipId: root.membershipId, membershipLifetimeId: root.membershipLifetimeId)),
          contributions: initial, pair: generation.pair, basis: generation.basis,
          provenance: provenance, graph: graph, aliases: &aliases, changes: changes)
      }
    }
    let groups = Dictionary(grouping: eligible, by: { $0.baselineProvenance.pair })
    let rootResolutionAliases = Self.aliasesRequiringCanonicalRootResolution(
      memberships: eligible.map(\.baselineProvenance), aliases: current.contextAliases,
      provenance: Array(provenance.values))
    let resolvingAliases = rootResolutionAliases.filter {
      !graph.isClosed($0.context) && !graph.isClosed($0.canonicalContext)
    }
    let rootResolutionPairs = Set(
      resolvingAliases.compactMap { alias -> PlannerMembershipPair? in
        guard let root = Self.membership(in: alias.canonicalContext) else { return nil }
        return provenance[root]?.pair
      })
    var consolidatedMembershipIdentities = closedMembershipIdentities
    for (pair, contributions) in groups
    where contributions.count > 1 || rootResolutionPairs.contains(pair) {
      let ordered = contributions.sorted {
        if $0.id != $1.id { return $0.id.uuidString < $1.id.uuidString }
        return $0.rank < $1.rank
      }
      guard let canonical = ordered.first else { continue }
      let canonicalBinding = canonical.baselineProvenance.membership
      let basis = try Self.binding(canonicalBinding, in: provenance).normalized.observedRemovalIds
      let membershipBindings = Set(contributions.map { $0.baselineProvenance.membership })
      consolidatedMembershipIdentities.formUnion(membershipBindings)
      func requiresRootResolution(for context: PlannerPortableCompletionContext) -> Bool {
        resolvingAliases.contains { alias in
          guard Self.sameScope(alias.canonicalContext, context),
            let root = Self.membership(in: alias.canonicalContext)
          else { return false }
          return provenance[root]?.pair == pair
        }
      }
      for alias in current.contextAliases {
        if graph.isClosed(alias.canonicalContext),
          let original = Self.membership(in: alias.context),
          membershipBindings.contains(original)
        {
          throw Self.unresolved(
            "A retired relationship needs closure admission before consolidation.")
        }
        guard let root = Self.membership(in: alias.canonicalContext),
          let binding = provenance[root], binding.pair == pair,
          binding.normalized.observedRemovalIds == basis,
          !graph.isClosed(root), !membershipBindings.contains(root)
        else { continue }
        if root.id.uuidString > canonical.id.uuidString { continue }
        throw Self.unresolved("The known canonical membership has not fully arrived.")
      }
      for member in contributions {
        let binding = member.baselineProvenance
        let retained = try Self.binding(binding.membership, in: provenance)
        guard retained.pair == pair, retained.normalized.observedRemovalIds == basis else {
          throw Self.unresolved("Membership generations cannot be combined.")
        }
        provenance[binding.membership] = retained
      }
      let canonicalContext = PlannerPortableCompletionContext.listMembership(
        membershipId: canonical.id, membershipLifetimeId: canonical.lifetimeId)
      let done: Bool
      if contributions.count > 1 || requiresRootResolution(for: canonicalContext) {
        done = try Self.normalize(
          canonical: canonicalContext,
          contributions: contributions.map {
            (
              .listMembership(membershipId: $0.id, membershipLifetimeId: $0.lifetimeId),
              $0.localDone
            )
          }, pair: pair, basis: basis, provenance: provenance, graph: graph,
          aliases: &aliases, changes: changes)
      } else {
        done = canonical.localDone
      }
      members.removeAll { membershipBindings.contains($0.baselineProvenance.membership) }
      members.append(
        .init(
          id: canonical.id, lifetimeId: canonical.lifetimeId, list: canonical.list,
          listLifetimeId: canonical.listLifetimeId, item: canonical.item,
          itemLifetimeId: canonical.itemLifetimeId, rank: canonical.rank, localDone: done))
      for entry in current.itineraryEntries
      where entry.source.kind == .list && entry.source.id == pair.list.id
        && entry.sourceLifetimeId == pair.list.lifetimeId
      {
        let canonicalExpanded = PlannerExpandedContext(
          listEntryId: entry.id, listEntryLifetimeId: entry.lifetimeId,
          membershipId: canonical.id, membershipLifetimeId: canonical.lifetimeId)
        guard
          contributions.count > 1
            || requiresRootResolution(for: .expandedListItem(canonicalExpanded))
        else { continue }
        var initial: [(PlannerPortableCompletionContext, Bool)] = []
        for member in contributions {
          let context = PlannerExpandedContext(
            listEntryId: entry.id, listEntryLifetimeId: entry.lifetimeId,
            membershipId: member.id, membershipLifetimeId: member.lifetimeId)
          let states = current.expandedCompletions.filter { $0.context == context }.map(\.localDone)
          for value in states.isEmpty ? [false] : states {
            initial.append((.expandedListItem(context), value))
          }
        }
        let localDone = try Self.normalize(
          canonical: .expandedListItem(canonicalExpanded), contributions: initial,
          pair: pair, basis: basis, provenance: provenance, graph: graph,
          aliases: &aliases, changes: changes)
        expanded.removeAll {
          $0.context.listEntryId == entry.id && $0.context.listEntryLifetimeId == entry.lifetimeId
            && membershipBindings.contains(
              .init(
                kind: .membership, id: $0.context.membershipId,
                lifetimeId: $0.context.membershipLifetimeId))
        }
        expanded.append(.init(context: canonicalExpanded, localDone: localDone))
      }
    }
    var eligibleTargets: [PlannerExpandedContext: [PlannerPortableExpandedCompletion]] = [:]
    for completion in eligibleDetached {
      let original = PlannerPortableBoundIdentity(
        kind: .membership, id: completion.context.membershipId,
        lifetimeId: completion.context.membershipLifetimeId)
      let binding = try Self.binding(original, in: provenance)
      guard !graph.isClosed(.expandedListItem(completion.context)),
        let target = members.first(where: {
          $0.baselineProvenance.pair == binding.pair
            && provenance[$0.baselineProvenance.membership]?.normalized.observedRemovalIds
              == binding.normalized.observedRemovalIds
        }), !graph.isClosed(target.baselineProvenance.membership),
        current.memberships.contains(where: { $0.baselineProvenance.membership == original })
          || aliases.contains(where: {
            Self.membership(in: $0.context) == original
              && Self.membership(in: $0.canonicalContext) == target.baselineProvenance.membership
              && !graph.isClosed($0.context) && !graph.isClosed($0.canonicalContext)
          })
      else {
        throw Self.unresolved("The eligible completion's exact canonical binding is unavailable.")
      }
      let canonical = PlannerExpandedContext(
        listEntryId: completion.context.listEntryId,
        listEntryLifetimeId: completion.context.listEntryLifetimeId,
        membershipId: target.id, membershipLifetimeId: target.lifetimeId)
      eligibleTargets[canonical, default: []].append(completion)
    }
    for (canonical, contributions) in eligibleTargets {
      let canonicalContext = PlannerPortableCompletionContext.expandedListItem(canonical)
      let binding = try Self.binding(
        .init(
          kind: .membership, id: canonical.membershipId,
          lifetimeId: canonical.membershipLifetimeId), in: provenance)
      let values = expanded.filter { $0.context == canonical }.map {
        (canonicalContext, $0.localDone)
      }
      _ = try Self.normalize(
        canonical: canonicalContext,
        contributions: values.isEmpty ? [(canonicalContext, false)] : values,
        pair: binding.pair, basis: binding.normalized.observedRemovalIds, provenance: provenance,
        graph: graph, aliases: &aliases, changes: changes)
      for contribution in contributions {
        let originalContext = PlannerPortableCompletionContext.expandedListItem(
          contribution.context)
        if aliases.contains(where: {
          $0.context == originalContext && $0.initialDone == contribution.localDone
        }) {
          continue
        }
        let identifier = plannerInitialCompletionAliasIdentifier(
          context: originalContext, done: contribution.localDone)
        guard !aliases.contains(where: { $0.aliasId == identifier }) else {
          throw Self.unresolved("An initial completion identity describes another contribution.")
        }
        aliases.append(
          .init(
            aliasId: identifier, context: originalContext, canonicalContext: canonicalContext,
            initialDone: contribution.localDone, currentChangeId: nil))
      }
      let done = plannerCompletionHistoryValue(
        contributions: aliases.filter { $0.canonicalContext == canonicalContext }, changes: changes,
        deletionMarkers: current.deletionMarkers)
      expanded.removeAll { $0.context == canonical }
      expanded.append(.init(context: canonical, localDone: done))
    }
    let completionStates = try plannerCompletionHistoryStates(
      aliases: aliases, changes: current.completionChanges, deletionMarkers: current.deletionMarkers
    )
    members = members.map { member in
      let completionContext = PlannerPortableCompletionContext.listMembership(
        membershipId: member.id, membershipLifetimeId: member.lifetimeId)
      guard let expected = completionStates[completionContext], expected != member.localDone else {
        return member
      }
      return .init(
        id: member.id, lifetimeId: member.lifetimeId, list: member.list,
        listLifetimeId: member.listLifetimeId, item: member.item,
        itemLifetimeId: member.itemLifetimeId, rank: member.rank, localDone: expected)
    }
    let entries = current.itineraryEntries.map { entry in
      let completionContext = PlannerPortableCompletionContext.directItineraryItem(
        entryId: entry.id, entryLifetimeId: entry.lifetimeId)
      guard entry.source.kind == .item, let expected = completionStates[completionContext],
        expected != entry.localDone
      else { return entry }
      return PlannerPortableItineraryEntry(
        id: entry.id, lifetimeId: entry.lifetimeId, itinerary: entry.itinerary,
        itineraryLifetimeId: entry.itineraryLifetimeId, source: entry.source,
        sourceLifetimeId: entry.sourceLifetimeId, rank: entry.rank, localDone: expected)
    }
    expanded = expanded.map { value in
      guard let expected = completionStates[.expandedListItem(value.context)],
        expected != value.localDone
      else { return value }
      return .init(context: value.context, localDone: expected)
    }
    let representedExpanded = Set(expanded.map(\.context))
    for (completionContext, done) in completionStates where done {
      guard case .expandedListItem(let context) = completionContext,
        !representedExpanded.contains(context), !graph.isClosed(completionContext),
        let member = members.first(where: {
          $0.id == context.membershipId && $0.lifetimeId == context.membershipLifetimeId
        }),
        entries.contains(where: {
          $0.id == context.listEntryId && $0.lifetimeId == context.listEntryLifetimeId
            && $0.source.kind == .list && $0.source.id == member.list.id
            && $0.sourceLifetimeId == member.listLifetimeId
        })
      else { continue }
      expanded.append(.init(context: context, localDone: done))
    }
    consolidatedMembershipIdentities.formUnion(
      suppressed.values.flatMap { $0.map { $0.baselineProvenance.membership } })
    let represented = Set(current.membershipProvenance.map(\.membership))
      .union(
        aliases.flatMap { $0.context.importContextIdentities }.filter {
          $0.kind == .membership && consolidatedMembershipIdentities.contains($0)
        })
    backup = .init(
      sources: current.sources, labelAssociations: current.labelAssociations,
      memberships: members.sorted { $0.id.uuidString < $1.id.uuidString },
      itineraryEntries: entries,
      expandedCompletions: expanded.sorted { $0.context.orderingKey < $1.context.orderingKey },
      schedules: current.schedules, deletionMarkers: current.deletionMarkers,
      ownedLinks: current.ownedLinks,
      contextAliases: aliases.sorted { $0.aliasId.uuidString < $1.aliasId.uuidString },
      completionChanges: current.completionChanges,
      restorationFamilies: current.restorationFamilies,
      formatVersion: 4,
      membershipProvenance: provenance.values.filter { represented.contains($0.membership) }.sorted
      {
        if $0.membershipId != $1.membershipId {
          return $0.membershipId.uuidString < $1.membershipId.uuidString
        }
        return $0.membershipLifetimeId.uuidString < $1.membershipLifetimeId.uuidString
      },
      membershipRemovals: current.membershipRemovals)
    try PlannerImportGraph(backup: backup).validate()
  }

  private static func normalize(
    canonical: PlannerPortableCompletionContext,
    contributions: [(PlannerPortableCompletionContext, Bool)], pair: PlannerMembershipPair,
    basis: [UUID], provenance: [PlannerPortableBoundIdentity: PlannerPortableMembershipProvenance],
    graph: PlannerImportGraph,
    aliases: inout [PlannerPortableContextAlias], changes: [UUID: PlannerPortableCompletionChange]
  ) throws -> Bool {
    let originals = Dictionary(grouping: contributions, by: { $0.0 })
    for (context, values) in originals {
      if values.count == 1 && aliases.contains(where: { $0.context == context }) { continue }
      for done in Set(values.map { $0.1 }) {
        let identifier = plannerInitialCompletionAliasIdentifier(context: context, done: done)
        if let known = aliases.first(where: { $0.aliasId == identifier }) {
          guard known.context == context, known.initialDone == done else {
            throw unresolved("An initial completion identity describes another contribution.")
          }
          continue
        }
        aliases.append(
          .init(
            aliasId: identifier, context: context, canonicalContext: canonical,
            initialDone: done, currentChangeId: nil))
      }
    }
    for index in aliases.indices {
      let alias = aliases[index]
      guard !graph.isClosed(alias.canonicalContext), sameScope(alias.context, canonical),
        let identity = membership(in: alias.context),
        let binding = provenance[identity], binding.pair == pair,
        binding.normalized.observedRemovalIds == basis
      else { continue }
      aliases[index] = .init(
        aliasId: alias.aliasId, context: alias.context, canonicalContext: canonical,
        initialDone: alias.initialDone, currentChangeId: alias.currentChangeId)
    }
    return plannerCompletionHistoryValue(
      contributions: aliases.filter { $0.canonicalContext == canonical }, changes: changes,
      deletionMarkers: graph.backup.deletionMarkers)
  }

  private static func sameScope(
    _ first: PlannerPortableCompletionContext, _ second: PlannerPortableCompletionContext
  ) -> Bool {
    switch (first, second) {
    case (.listMembership, .listMembership): true
    case (.expandedListItem(let first), .expandedListItem(let second)):
      first.listEntryId == second.listEntryId
        && first.listEntryLifetimeId == second.listEntryLifetimeId
    default: false
    }
  }

  private static func membership(in context: PlannerPortableCompletionContext)
    -> PlannerPortableBoundIdentity?
  {
    context.importContextIdentities.first { $0.kind == .membership }
  }

  private static func binding(
    _ identity: PlannerPortableBoundIdentity,
    in values: [PlannerPortableBoundIdentity: PlannerPortableMembershipProvenance]
  ) throws -> PlannerPortableMembershipProvenance {
    guard let value = values[identity] else {
      throw unresolved("The membership's retained provenance is unavailable.")
    }
    return value
  }

  private static func unresolved(_ message: String) -> PlannerFailure {
    .init("readUnavailable", message)
  }
}

extension PlannerPortableMembership {
  var nativeSnapshot: MembershipSnapshot {
    .init(
      id: id, lifetimeId: lifetimeId,
      list: .init(kind: "list", id: list.id, lifetimeId: listLifetimeId),
      item: .init(kind: "item", id: item.id, lifetimeId: itemLifetimeId), rank: rank,
      localDone: localDone)
  }
}

func plannerInitialCompletionAliasIdentifier(context: PlannerPortableCompletionContext, done: Bool)
  -> UUID
{
  let value = PlannerCanonicalValue.record([
    "context": context.importCanonicalValue, "initialDone": .boolean(done),
  ])
  var digest = Array(
    SHA256.hash(data: Data("PlannerInitialCompletionAlias-v1".utf8) + value.encoded()))
  digest[6] = (digest[6] & 0x0f) | 0x80
  digest[8] = (digest[8] & 0x3f) | 0x80
  return UUID(
    uuid: (
      digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
      digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]
    ))
}

extension PlannerDataSnapshot {
  init(snapshot: PlannerDataSnapshot, canonical: PlannerPortableBackup) throws {
    format = snapshot.format
    formatVersion = 4
    sources = snapshot.sources
    memberships = canonical.memberships.map { PortableMembershipRecord($0.nativeSnapshot) }
    itineraryEntries = canonical.itineraryEntries.map { entry in
      PortableItineraryEntryRecord(
        .init(
          id: entry.id, lifetimeId: entry.lifetimeId,
          itinerary: .init(
            kind: "itinerary", id: entry.itinerary.id,
            lifetimeId: entry.itineraryLifetimeId),
          source: .init(
            kind: entry.source.kind.rawValue, id: entry.source.id,
            lifetimeId: entry.sourceLifetimeId),
          rank: entry.rank, localDone: entry.localDone))
    }
    expandedCompletions = try canonical.expandedCompletions.map { value in
      guard
        let entry = canonical.itineraryEntries.first(where: { $0.id == value.context.listEntryId })
      else {
        throw PlannerFailure("readUnavailable", "The expanded completion owner is unavailable.")
      }
      return PortableExpandedCompletionRecord(
        .init(context: value.context, localDone: value.localDone, itineraryId: entry.itinerary.id))
    }
    labelAssociations = snapshot.labelAssociations
    ownedLinks = snapshot.ownedLinks
    schedules = snapshot.schedules
    deletionMarkers = snapshot.deletionMarkers
    contextAliases = canonical.contextAliases
    completionChanges = canonical.completionChanges
    restorationFamilies = canonical.restorationFamilies
    membershipProvenance = canonical.membershipProvenance
    membershipRemovals = canonical.membershipRemovals
  }
}

func plannerStageMembershipConsolidation(_ backup: PlannerPortableBackup, context: ModelContext)
  throws
{
  let members = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
  var retained: [PlannerPortableBoundIdentity: PlannerSchemaV18.Membership] = [:]
  for member in members {
    let value = try member.value()
    let identity = PlannerPortableBoundIdentity(
      kind: .membership, id: value.id, lifetimeId: value.lifetimeId)
    guard
      let canonical = backup.memberships.first(where: {
        $0.id == value.id && $0.lifetimeId == value.lifetimeId
      }), retained[identity] == nil
    else { continue }
    if member.rank != canonical.rank { member.rank = canonical.rank }
    if member.localDone != canonical.localDone { member.localDone = canonical.localDone }
    retained[identity] = member
  }
  let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
  for entry in entries {
    guard
      let canonical = backup.itineraryEntries.first(where: {
        $0.id == entry.id && $0.lifetimeId == entry.lifetimeId && $0.source.kind == .item
      })
    else { continue }
    if entry.localDone != canonical.localDone { entry.localDone = canonical.localDone }
  }
  var savedExpanded: Set<PlannerExpandedContext> = []
  for expanded in try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()) {
    let value = try expanded.value()
    guard let canonical = backup.expandedCompletions.first(where: { $0.context == value.context }),
      savedExpanded.insert(value.context).inserted,
      let member = retained[
        .init(
          kind: .membership, id: value.context.membershipId,
          lifetimeId: value.context.membershipLifetimeId)]
    else {
      context.delete(expanded)
      continue
    }
    if expanded.localDone != canonical.localDone { expanded.localDone = canonical.localDone }
    if expanded.membership !== member { expanded.membership = member }
  }
  for value in backup.expandedCompletions {
    if savedExpanded.contains(value.context) { continue }
    let identity = PlannerPortableBoundIdentity(
      kind: .membership, id: value.context.membershipId,
      lifetimeId: value.context.membershipLifetimeId)
    guard let member = retained[identity],
      let entry = entries.first(where: {
        $0.id == value.context.listEntryId && $0.lifetimeId == value.context.listEntryLifetimeId
      })
    else {
      throw PlannerFailure(
        "readUnavailable", "An expanded context cannot retain its exact binding.")
    }
    context.insert(
      PlannerSchemaV18.ExpandedCompletion(
        listEntry: entry, membership: member, localDone: value.localDone))
  }
  for member in members {
    let value = try member.value()
    let identity = PlannerPortableBoundIdentity(
      kind: .membership, id: value.id, lifetimeId: value.lifetimeId)
    if retained[identity] !== member { context.delete(member) }
  }
  try plannerStageMembershipProvenance(backup.membershipProvenance, context: context)
  let lineage = try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>())
  for alias in backup.contextAliases {
    try plannerStageLineageRecord(
      alias, identifier: alias.aliasId, kind: "contextAlias", records: lineage, context: context)
  }
  context.processPendingChanges()
}

/// Stage unresolved or surplus rows; retained scope and causal authority are validated before preparation.
func plannerStageDetachedExpandedRetirements(
  context: ModelContext, memberships: [MembershipSnapshot], lineage: PlannerNativeLineage
) throws -> [PlannerPortableExpandedCompletion] {
  let liveMembershipBindings = Set(memberships.map { $0.baselineProvenance.membership })
  let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
  let markers =
    try context.fetch(FetchDescriptor<PlannerSchemaV4.DeletionMarker>()).map { try $0.value() }
    + lineage.deletionMarkers
  let closures = PlannerImportGraph(
    backup: .init(
      sources: [], labelAssociations: [], memberships: [], itineraryEntries: [],
      expandedCompletions: [],
      deletionMarkers: try markers.map {
        try $0.validated(
          items: [], lists: [], itineraries: [], schedules: [], categories: [], tags: [],
          labelAssociations: [], entries: [], ownedLinks: [], expandedCompletions: [])
      },
      restorationFamilies: lineage.restorationFamilies))
  var retainedLiveContexts: [PlannerExpandedContext: Bool] = [:]
  var contributedLiveContexts: Set<PlannerExpandedContext> = []
  var contributions: [PlannerPortableExpandedCompletion] = []
  for record in try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()) {
    guard let entryIdentifier = record.listEntryId,
      let entryLifetime = record.listEntryLifetimeId,
      let membershipIdentifier = record.membershipId,
      let membershipLifetime = record.membershipLifetimeId
    else {
      throw PlannerFailure("readUnavailable", "The completion has incomplete context identities.")
    }
    let identity = PlannerPortableBoundIdentity(
      kind: .membership, id: membershipIdentifier, lifetimeId: membershipLifetime)
    if let entry = record.listEntry,
      entry.id != entryIdentifier || entry.lifetimeId != entryLifetime
    {
      throw PlannerFailure("readUnavailable", "The completion has contradictory entry bindings.")
    }
    if let member = record.membership,
      member.id != membershipIdentifier || member.lifetimeId != membershipLifetime
    {
      throw PlannerFailure(
        "readUnavailable", "The completion has contradictory membership bindings.")
    }
    let expandedContext = PlannerExpandedContext(
      listEntryId: entryIdentifier, listEntryLifetimeId: entryLifetime,
      membershipId: membershipIdentifier, membershipLifetimeId: membershipLifetime)
    let contextIsClosed = closures.isClosed(.expandedListItem(expandedContext))
    if !contextIsClosed, liveMembershipBindings.contains(identity), let value = try? record.value()
    {
      guard let retainedDone = retainedLiveContexts[value.context] else {
        retainedLiveContexts[value.context] = value.localDone
        continue
      }
      if contributedLiveContexts.insert(value.context).inserted {
        contributions.append(.init(context: value.context, localDone: retainedDone))
      }
    }
    let retainedEntry = entries.first {
      $0.id == entryIdentifier && $0.lifetimeId == entryLifetime
    }
    guard
      let binding = lineage.membershipProvenance.first(where: { $0.membership == identity })
        ?? memberships.first(where: { $0.baselineProvenance.membership == identity })?
        .baselineProvenance,
      (contextIsClosed && retainedEntry == nil)
        || (retainedEntry?.sourceKind == "list" && retainedEntry?.sourceId == binding.list.id
          && retainedEntry?.sourceLifetimeId == binding.list.lifetimeId)
    else {
      throw PlannerFailure(
        "readUnavailable", "The unresolved completion has no retained scope binding.")
    }
    if !contextIsClosed {
      contributions.append(.init(context: expandedContext, localDone: record.localDone))
    }
    record.listEntry = nil
    context.delete(record)
  }
  context.processPendingChanges()
  return contributions
}
