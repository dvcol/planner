import CryptoKit
import Foundation
import SwiftData

struct PlannerMembershipConsolidation {
  let backup: PlannerPortableBackup

  init(snapshot: PlannerDataSnapshot) throws {
    let current = try snapshot.decodedRecords().backup
    try PlannerImportGraph(backup: current).validateMembershipProvenance()
    var provenance = Dictionary(
      uniqueKeysWithValues: current.membershipProvenance.map { ($0.membership, $0.normalized) })
    var memberPairs: [PlannerPortableBoundIdentity: PlannerMembershipPair] = [:]
    var lifetimes: [UUID: UUID] = [:]
    for member in current.memberships {
      let binding = member.baselineProvenance
      if let previous = memberPairs[binding.membership], previous != binding.pair {
        throw Self.unresolved("Copies of a membership disagree on their source bindings.")
      }
      if let previous = lifetimes[member.id], previous != member.lifetimeId {
        throw Self.unresolved("Competing membership lifetimes need restoration reconciliation.")
      }
      memberPairs[binding.membership] = binding.pair
      lifetimes[member.id] = member.lifetimeId
      if let retained = provenance[binding.membership] {
        guard retained.pair == binding.pair else {
          throw Self.unresolved("Membership provenance describes another source pair.")
        }
      } else {
        provenance[binding.membership] = binding
      }
    }
    var members = current.memberships
    var expanded = current.expandedCompletions
    var aliases = current.contextAliases
    let changes = Dictionary(uniqueKeysWithValues: current.completionChanges.map { ($0.id, $0) })
    let groups = Dictionary(grouping: current.memberships, by: { $0.baselineProvenance.pair })
    for (pair, contributions) in groups where contributions.count > 1 {
      let ordered = contributions.sorted {
        if $0.id != $1.id { return $0.id.uuidString < $1.id.uuidString }
        return $0.rank < $1.rank
      }
      guard let canonical = ordered.first else { continue }
      let canonicalBinding = canonical.baselineProvenance.membership
      let basis = try Self.binding(canonicalBinding, in: provenance).normalized.observedRemovalIds
      let membershipBindings = Set(contributions.map { $0.baselineProvenance.membership })
      let graph = PlannerImportGraph(backup: current)
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
      let done = try Self.normalize(
        canonical: canonicalContext,
        contributions: contributions.map {
          (.listMembership(membershipId: $0.id, membershipLifetimeId: $0.lifetimeId), $0.localDone)
        }, pair: pair, basis: basis, provenance: provenance, graph: graph,
        aliases: &aliases, changes: changes)
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
    let represented = Set(current.membershipProvenance.map(\.membership))
      .union(
        aliases.flatMap { $0.context.importContextIdentities }.filter { $0.kind == .membership })
    backup = .init(
      sources: current.sources, labelAssociations: current.labelAssociations,
      memberships: members.sorted { $0.id.uuidString < $1.id.uuidString },
      itineraryEntries: current.itineraryEntries,
      expandedCompletions: expanded.sorted { $0.context.orderingKey < $1.context.orderingKey },
      schedules: current.schedules, deletionMarkers: current.deletionMarkers,
      ownedLinks: current.ownedLinks,
      contextAliases: aliases.sorted { $0.aliasId.uuidString < $1.aliasId.uuidString },
      completionChanges: current.completionChanges,
      restorationFamilies: current.restorationFamilies,
      formatVersion: 3,
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
        let identifier = initialAliasIdentifier(context: context, done: done)
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
      contributions: aliases.filter { $0.canonicalContext == canonical }, changes: changes)
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

  private static func initialAliasIdentifier(context: PlannerPortableCompletionContext, done: Bool)
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

extension PlannerDataSnapshot {
  init(snapshot: PlannerDataSnapshot, canonical: PlannerPortableBackup) throws {
    format = snapshot.format
    formatVersion = 3
    sources = snapshot.sources
    memberships = canonical.memberships.map { PortableMembershipRecord($0.nativeSnapshot) }
    itineraryEntries = snapshot.itineraryEntries
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
