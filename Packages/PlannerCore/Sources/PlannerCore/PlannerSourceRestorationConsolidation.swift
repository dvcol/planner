import Foundation
import SwiftData

/// Rebinds admitted direct entries and retires fully declared losing native source candidates.
struct PlannerSourceRestorationConsolidation {
  private struct Row {
    let identity: PlannerPortableBoundIdentity
    let model: any PersistentModel
    let hasRelationships: Bool
  }

  private struct EntryRebinding {
    let entry: PlannerSchemaV18.ItineraryEntry
    let winner: PlannerSchemaV18.Item
    let projected: PortableItineraryEntryRecord
  }

  private let rows: [Row]
  private let entryRebindings: [EntryRebinding]
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
    if !retired.isEmpty {
      try Self.requireUnreferenced(retired, context: context, admittedEntries: entryRebindings)
    }
    self.rows = rows
    self.retired = retired
    self.entryRebindings = entryRebindings
  }

  func project(_ snapshot: PlannerDataSnapshot) -> PlannerDataSnapshot {
    PlannerDataSnapshot(
      snapshot: snapshot, retiringSources: retired,
      reboundEntries: entryRebindings.map(\.projected))
  }

  func stage(in context: ModelContext) {
    for rebinding in entryRebindings {
      rebinding.entry.sourceLifetimeId = rebinding.winner.lifetimeId
      rebinding.entry.item = rebinding.winner
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
            || !(item.memberships ?? []).isEmpty
            || !(item.labelAssociations ?? []).isEmpty))
    }
    for list in try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()) {
      rows.append(
        .init(
          identity: try binding(.list, list.id, list.lifetimeId), model: list,
          hasRelationships: !(list.memberships ?? []).isEmpty
            || !(list.itineraryEntries ?? []).isEmpty))
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
          hasRelationships: !(category.associations ?? []).isEmpty))
    }
    for tag in try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()) {
      rows.append(
        .init(
          identity: try binding(.tag, tag.id, tag.lifetimeId), model: tag,
          hasRelationships: !(tag.associations ?? []).isEmpty))
    }
    return rows
  }

  private static func entryRebindings(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    winners: [PlannerPortableBoundIdentity: Row]
  ) throws -> [EntryRebinding] {
    guard !retired.isEmpty else { return [] }
    var rebindings: [EntryRebinding] = []
    for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()) {
      guard let sourceKind = PlannerPortableIdentityKind(rawValue: entry.sourceKind) else {
        throw unresolved("A native entry has an unsupported source kind.")
      }
      let source = try binding(sourceKind, entry.sourceId, entry.sourceLifetimeId)
      guard retired.contains(source) else { continue }
      let value = try entry.value()
      let owner = try binding(.itinerary, value.itinerary.id, value.itinerary.lifetimeId)
      guard source.kind == .item, !retired.contains(owner),
        rows.filter({ $0.identity == owner }).count == 1,
        let winner = winners[source]?.model as? PlannerSchemaV18.Item,
        let winnerLifetime = winner.lifetimeId
      else { throw unresolved("A losing source has an unsupported entry or owner binding.") }
      let projected = ItineraryEntrySnapshot(
        id: value.id, lifetimeId: value.lifetimeId, itinerary: value.itinerary,
        source: .init(kind: "item", id: source.id, lifetimeId: winnerLifetime),
        rank: value.rank, localDone: value.localDone)
      rebindings.append(.init(entry: entry, winner: winner, projected: .init(projected)))
    }
    return rebindings
  }

  /// Scalar bindings remain authoritative even when SwiftData has not resolved their objects.
  private static func requireUnreferenced(
    _ retired: Set<PlannerPortableBoundIdentity>, context: ModelContext,
    admittedEntries: [EntryRebinding]
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
      try requireSurvivor("item", member.itemId, member.itemLifetimeId)
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
      try requireSurvivor(association.labelKind, association.labelId, association.labelLifetimeId)
    }
  }

  private static func unresolved(_ message: String) -> PlannerFailure {
    .init("readUnavailable", message)
  }
}

extension PlannerDataSnapshot {
  init(
    snapshot: PlannerDataSnapshot, retiringSources: Set<PlannerPortableBoundIdentity>,
    reboundEntries: [PortableItineraryEntryRecord]
  ) {
    format = snapshot.format
    formatVersion = snapshot.formatVersion
    sources = snapshot.sources.filter { !retiringSources.contains($0.boundIdentity) }
    memberships = snapshot.memberships
    itineraryEntries = snapshot.itineraryEntries.map { entry in
      reboundEntries.first { $0.id == entry.id && $0.lifetimeId == entry.lifetimeId } ?? entry
    }
    expandedCompletions = snapshot.expandedCompletions
    labelAssociations = snapshot.labelAssociations
    ownedLinks = snapshot.ownedLinks
    schedules = snapshot.schedules
    deletionMarkers = snapshot.deletionMarkers
    contextAliases = snapshot.contextAliases
    completionChanges = snapshot.completionChanges
    restorationFamilies = snapshot.restorationFamilies
    membershipProvenance = snapshot.membershipProvenance
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
