import Foundation
import SwiftData

/// Rebinds admitted target references and retires fully declared losing native source candidates.
struct PlannerSourceRestorationConsolidation {
  private struct Row {
    let identity: PlannerPortableBoundIdentity
    let model: any PersistentModel
    let hasRelationships: Bool
  }

  private struct EntryRebinding {
    let entry: PlannerSchemaV18.ItineraryEntry
    let winner: Row
    let snapshot: ItineraryEntrySnapshot
    var projected: PortableItineraryEntryRecord { .init(snapshot) }
  }

  private struct MembershipRebinding {
    let membership: PlannerSchemaV18.Membership
    let winner: PlannerSchemaV18.Item
    let projected: PortableMembershipRecord
    let provenance: PlannerPortableMembershipProvenance
  }

  private struct LabelRebinding {
    let association: PlannerSchemaV18.LabelAssociation
    let winner: Row
    let projected: PortableLabelAssociationRecord
  }

  private let rows: [Row]
  private let entryRebindings: [EntryRebinding]
  private let membershipRebindings: [MembershipRebinding]
  private let labelRebindings: [LabelRebinding]
  let ruleVersion = 3
  let retired: Set<PlannerPortableBoundIdentity>

  init(context: ModelContext, markers: [PortableDeletionMarker]) throws {
    let rows = try Self.sourceRows(context)
    let families = try PlannerNativeLineage(context: context).restorationFamilies
    let closedFamilies = Set(markers.compactMap(\.closedFamilyId))
    let groups = Dictionary(grouping: rows) {
      $0.identity.kind.rawValue + ":" + $0.identity.id.uuidString
    }
    var retired: Set<PlannerPortableBoundIdentity> = []
    var winners: [PlannerPortableBoundIdentity: Row] = [:]
    for group in groups.values {
      guard let first = group.first else { continue }
      let relevant = families.filter { family in
        family.predecessor.kind == first.identity.kind
          && family.predecessor.id == first.identity.id
          && !closedFamilies.contains(family.familyId)
          && group.contains { row in
            family.candidates.contains { $0.lifetimeId == row.identity.lifetimeId }
          }
      }
      if group.count == 1, relevant.isEmpty { continue }
      guard relevant.count == 1, let family = relevant.first,
        let winner = family.candidates.map(\.lifetimeId).min(by: { $0.uuidString < $1.uuidString }),
        group.filter({ $0.identity.lifetimeId == winner }).count == 1,
        Set(group.map(\.identity)).count == group.count,
        group.allSatisfy({ row in
          family.candidates.contains { $0.lifetimeId == row.identity.lifetimeId }
        })
      else { throw Self.unresolved("The native source candidates lack a unique present winner.") }
      guard let winnerRow = group.first(where: { $0.identity.lifetimeId == winner }) else {
        throw Self.unresolved("The native source winner is missing.")
      }
      for row in group where row.identity.lifetimeId != winner {
        guard !row.hasRelationships else {
          throw Self.unresolved("A losing restoration candidate still has live relationships.")
        }
        retired.insert(row.identity)
        winners[row.identity] = winnerRow
      }
    }
    let entryRebindings = try Self.entryRebindings(
      context: context, rows: rows, retired: retired, winners: winners)
    let membershipRebindings = try Self.membershipRebindings(
      context: context, rows: rows, retired: retired, winners: winners)
    let labelRebindings = try Self.labelRebindings(
      context: context, rows: rows, retired: retired, winners: winners)
    if !retired.isEmpty {
      try Self.requireUnreferenced(
        retired, context: context, admittedEntries: entryRebindings,
        admittedMemberships: membershipRebindings, admittedLabels: labelRebindings)
    }
    self.rows = rows
    self.retired = retired
    self.entryRebindings = entryRebindings
    self.membershipRebindings = membershipRebindings
    self.labelRebindings = labelRebindings
  }

  func project(_ snapshot: PlannerDataSnapshot) -> PlannerDataSnapshot {
    PlannerDataSnapshot(
      snapshot: snapshot, retiringSources: retired,
      reboundEntries: entryRebindings.map(\.projected),
      reboundMemberships: membershipRebindings.map(\.projected),
      originalProvenance: membershipRebindings.map(\.provenance),
      reboundLabels: labelRebindings.map(\.projected))
  }

  func itineraryValue(_ itinerary: PlannerSchemaV18.Itinerary) throws -> ItinerarySnapshot {
    let entries = try (itinerary.entries ?? []).map { entry in
      if let rebinding = entryRebindings.first(where: { $0.entry === entry }) {
        return rebinding.snapshot
      }
      return try entry.value()
    }
    return try itinerary.value(entrySnapshots: entries)
  }

  func stage(in context: ModelContext) {
    for rebinding in entryRebindings {
      rebinding.entry.sourceLifetimeId = rebinding.winner.identity.lifetimeId
      if let item = rebinding.winner.model as? PlannerSchemaV18.Item {
        rebinding.entry.item = item
      } else if let list = rebinding.winner.model as? PlannerSchemaV18.List {
        rebinding.entry.list = list
      }
    }
    for rebinding in membershipRebindings {
      rebinding.membership.itemLifetimeId = rebinding.winner.lifetimeId
      rebinding.membership.item = rebinding.winner
    }
    for rebinding in labelRebindings {
      rebinding.association.labelLifetimeId = rebinding.winner.identity.lifetimeId
      if let category = rebinding.winner.model as? PlannerSchemaV18.Category {
        rebinding.association.category = category
      } else if let tag = rebinding.winner.model as? PlannerSchemaV18.Tag {
        rebinding.association.tag = tag
      }
    }
    for row in rows where retired.contains(row.identity) { context.delete(row.model) }
  }

  private static func binding(
    _ kind: PlannerPortableIdentityKind, _ identifier: UUID?, _ lifetime: UUID?
  )
    throws -> PlannerPortableBoundIdentity
  {
    guard let identifier, let lifetime else {
      throw unresolved("A native source binding is incomplete.")
    }
    return .init(kind: kind, id: identifier, lifetimeId: lifetime)
  }

  private static func sourceRows(_ context: ModelContext) throws -> [Row] {
    var rows: [Row] = []
    for item in try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()) {
      rows.append(
        .init(
          identity: try binding(.item, item.id, item.lifetimeId), model: item,
          hasRelationships: !(item.links ?? []).isEmpty || !(item.schedules ?? []).isEmpty
            || !(item.labelAssociations ?? []).isEmpty))
    }
    for list in try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()) {
      rows.append(
        .init(
          identity: try binding(.list, list.id, list.lifetimeId), model: list,
          hasRelationships: !(list.memberships ?? []).isEmpty))
    }
    for itinerary in try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()) {
      rows.append(
        .init(
          identity: try binding(.itinerary, itinerary.id, itinerary.lifetimeId), model: itinerary,
          hasRelationships: !(itinerary.links ?? []).isEmpty || !(itinerary.schedules ?? []).isEmpty
            || !(itinerary.entries ?? []).isEmpty || !(itinerary.labelAssociations ?? []).isEmpty))
    }
    for category in try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()) {
      rows.append(
        .init(
          identity: try binding(.category, category.id, category.lifetimeId), model: category,
          hasRelationships: false))
    }
    for tag in try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()) {
      rows.append(
        .init(
          identity: try binding(.tag, tag.id, tag.lifetimeId), model: tag,
          hasRelationships: false))
    }
    return rows
  }

  private static func labelRebindings(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    winners: [PlannerPortableBoundIdentity: Row]
  ) throws -> [LabelRebinding] {
    guard !retired.isEmpty else { return [] }
    var rebindings: [LabelRebinding] = []
    for association in try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()) {
      guard let kind = PlannerPortableIdentityKind(rawValue: association.labelKind) else {
        throw unresolved("A native association has an unsupported label kind.")
      }
      let target = try binding(kind, association.labelId, association.labelLifetimeId)
      guard retired.contains(target) else { continue }
      let value = try association.value()
      guard let ownerKind = PlannerPortableIdentityKind(rawValue: value.owner.kind) else {
        throw unresolved("A native association has an unsupported owner kind.")
      }
      let owner = try binding(ownerKind, value.owner.id, value.owner.lifetimeId)
      guard !retired.contains(owner), rows.filter({ $0.identity == owner }).count == 1,
        let winner = winners[target], target.kind == .category || target.kind == .tag
      else { throw unresolved("A losing label has an unresolved association owner.") }
      let projected = LabelAssociationSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, owner: value.owner,
        label: .init(kind: value.label.kind, id: target.id, lifetimeId: winner.identity.lifetimeId))
      rebindings.append(
        .init(association: association, winner: winner, projected: .init(projected)))
    }
    return rebindings
  }

  private static func membershipRebindings(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    winners: [PlannerPortableBoundIdentity: Row]
  ) throws -> [MembershipRebinding] {
    guard !retired.isEmpty else { return [] }
    let lineage = try PlannerNativeLineage(context: context)
    var rebindings: [MembershipRebinding] = []
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
      let source = try binding(.item, membership.itemId, membership.itemLifetimeId)
      guard retired.contains(source) else { continue }
      let value = try membership.value()
      let owner = try binding(.list, value.list.id, value.list.lifetimeId)
      guard !retired.contains(owner), rows.filter({ $0.identity == owner }).count == 1,
        let winner = winners[source]?.model as? PlannerSchemaV18.Item,
        let winnerLifetime = winner.lifetimeId
      else { throw unresolved("A losing Item has an unresolved membership owner.") }
      let projected = MembershipSnapshot(
        id: value.id, lifetimeId: value.lifetimeId, list: value.list,
        item: .init(kind: "item", id: source.id, lifetimeId: winnerLifetime),
        rank: value.rank, localDone: value.localDone)
      let provenance =
        lineage.membershipProvenance.first {
          $0.membershipId == value.id && $0.membershipLifetimeId == value.lifetimeId
        } ?? value.baselineProvenance
      rebindings.append(
        .init(
          membership: membership, winner: winner, projected: .init(projected),
          provenance: provenance))
    }
    return rebindings
  }

  private static func entryRebindings(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    winners: [PlannerPortableBoundIdentity: Row]
  ) throws -> [EntryRebinding] {
    guard !retired.isEmpty else { return [] }
    let lineage = try PlannerNativeLineage(context: context)
    let completionStates = try plannerCompletionHistoryStates(
      aliases: lineage.contextAliases, changes: lineage.completionChanges,
      deletionMarkers: lineage.deletionMarkers.compactMap(\.expandedCompletionMarker))
    var rebindings: [EntryRebinding] = []
    for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()) {
      guard let sourceKind = PlannerPortableIdentityKind(rawValue: entry.sourceKind) else {
        throw unresolved("A native entry has an unsupported source kind.")
      }
      let source = try binding(sourceKind, entry.sourceId, entry.sourceLifetimeId)
      guard retired.contains(source) else { continue }
      let projectedListLifetime = source.kind == .list ? winners[source]?.identity.lifetimeId : nil
      let value = try entry.value(projectedListLifetimeId: projectedListLifetime)
      if let expected = completionStates[
        .directItineraryItem(
          entryId: value.id, entryLifetimeId: value.lifetimeId)], expected != value.localDone
      {
        throw unresolved("A source entry disagrees with its retained completion history.")
      }
      for completion in value.expandedCompletions {
        if let expected = completionStates[.expandedListItem(completion.context)],
          expected != completion.localDone
        {
          throw unresolved(
            "An expanded source entry disagrees with its retained completion history.")
        }
      }
      let owner = try binding(.itinerary, value.itinerary.id, value.itinerary.lifetimeId)
      guard source.kind == .item || source.kind == .list, !retired.contains(owner),
        rows.filter({ $0.identity == owner }).count == 1,
        let winner = winners[source]
      else { throw unresolved("A losing source has an unsupported entry or owner binding.") }
      let projected = ItineraryEntrySnapshot(
        id: value.id, lifetimeId: value.lifetimeId, itinerary: value.itinerary,
        source: .init(
          kind: value.source.kind, id: source.id, lifetimeId: winner.identity.lifetimeId),
        rank: value.rank, localDone: value.localDone, expandedCompletions: value.expandedCompletions
      )
      rebindings.append(.init(entry: entry, winner: winner, snapshot: projected))
    }
    return rebindings
  }

  /// Scalar bindings remain authoritative even when SwiftData has not resolved their objects.
  private static func requireUnreferenced(
    _ retired: Set<PlannerPortableBoundIdentity>, context: ModelContext,
    admittedEntries: [EntryRebinding], admittedMemberships: [MembershipRebinding],
    admittedLabels: [LabelRebinding]
  ) throws {
    func requireSurvivor(_ kind: String, _ identifier: UUID?, _ lifetime: UUID?) throws {
      guard let kind = PlannerPortableIdentityKind(rawValue: kind) else {
        throw unresolved("A native relationship has an unsupported source kind.")
      }
      guard !retired.contains(try binding(kind, identifier, lifetime)) else {
        throw unresolved("A losing restoration candidate has a persisted reference.")
      }
    }
    for member in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
      if !admittedMemberships.contains(where: { $0.membership === member }) {
        try requireSurvivor("item", member.itemId, member.itemLifetimeId)
      }
      try requireSurvivor("list", member.listId, member.listLifetimeId)
    }
    for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()) {
      try requireSurvivor("itinerary", entry.itineraryId, entry.itineraryLifetimeId)
      if !admittedEntries.contains(where: { $0.entry === entry }) {
        try requireSurvivor(entry.sourceKind, entry.sourceId, entry.sourceLifetimeId)
      }
    }
    for link in try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()) {
      try requireSurvivor(link.ownerKind, link.ownerId, link.ownerLifetimeId)
    }
    for schedule in try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()) {
      try requireSurvivor(schedule.sourceKind, schedule.sourceId, schedule.sourceLifetimeId)
    }
    for association in try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()) {
      try requireSurvivor(association.ownerKind, association.ownerId, association.ownerLifetimeId)
      if !admittedLabels.contains(where: { $0.association === association }) {
        try requireSurvivor(association.labelKind, association.labelId, association.labelLifetimeId)
      }
    }
  }

  private static func unresolved(_ message: String) -> PlannerFailure {
    .init("readUnavailable", message)
  }
}

extension PlannerDataSnapshot {
  init(
    snapshot: PlannerDataSnapshot, retiringSources: Set<PlannerPortableBoundIdentity>,
    reboundEntries: [PortableItineraryEntryRecord],
    reboundMemberships: [PortableMembershipRecord],
    originalProvenance: [PlannerPortableMembershipProvenance],
    reboundLabels: [PortableLabelAssociationRecord]
  ) {
    format = snapshot.format
    formatVersion = snapshot.formatVersion
    sources = snapshot.sources.filter { !retiringSources.contains($0.boundIdentity) }
    memberships = snapshot.memberships.map { member in
      reboundMemberships.first { $0.id == member.id && $0.lifetimeId == member.lifetimeId }
        ?? member
    }
    itineraryEntries = snapshot.itineraryEntries.map { entry in
      reboundEntries.first { $0.id == entry.id && $0.lifetimeId == entry.lifetimeId } ?? entry
    }
    expandedCompletions = snapshot.expandedCompletions
    labelAssociations = snapshot.labelAssociations.map { association in
      reboundLabels.first { $0.id == association.id && $0.lifetimeId == association.lifetimeId }
        ?? association
    }
    ownedLinks = snapshot.ownedLinks
    schedules = snapshot.schedules
    deletionMarkers = snapshot.deletionMarkers
    contextAliases = snapshot.contextAliases
    completionChanges = snapshot.completionChanges
    restorationFamilies = snapshot.restorationFamilies
    var represented = Set(snapshot.membershipProvenance.map(\.membership))
    membershipProvenance =
      snapshot.membershipProvenance
      + originalProvenance.filter {
        represented.insert($0.membership).inserted
      }
    membershipRemovals = snapshot.membershipRemovals
  }
}

extension PortableSourceRecord {
  fileprivate var boundIdentity: PlannerPortableBoundIdentity {
    switch self {
    case .item(let value): .init(kind: .item, id: value.id, lifetimeId: value.lifetimeId)
    case .list(let value): .init(kind: .list, id: value.id, lifetimeId: value.lifetimeId)
    case .itinerary(let value): .init(kind: .itinerary, id: value.id, lifetimeId: value.lifetimeId)
    case .category(let value): .init(kind: .category, id: value.id, lifetimeId: value.lifetimeId)
    case .tag(let value): .init(kind: .tag, id: value.id, lifetimeId: value.lifetimeId)
    }
  }
}
