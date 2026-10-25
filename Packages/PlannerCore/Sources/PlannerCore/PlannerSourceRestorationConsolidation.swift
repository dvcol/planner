import CryptoKit
import Foundation
import SwiftData

/// Rebinds admitted target references and retires fully declared losing native source candidates.
struct PlannerSourceRestorationConsolidation {
  private struct Row {
    let identity: PlannerPortableBoundIdentity
    let model: any PersistentModel
  }

  private struct EntryRebinding {
    let entry: PlannerSchemaV18.ItineraryEntry
    let winner: Row
    let snapshot: ItineraryEntrySnapshot
    var projected: PortableItineraryEntryRecord { .init(snapshot) }
  }

  private struct EntryRetirement {
    let entry: PlannerSchemaV18.ItineraryEntry
    let identity: PlannerPortableBoundIdentity
    let projectedListLifetime: UUID?
    let marker: PortableDeletionMarker?
  }

  private struct MembershipRebinding {
    let membership: PlannerSchemaV18.Membership
    let winner: PlannerSchemaV18.Item
    let projected: PortableMembershipRecord
    let provenance: PlannerPortableMembershipProvenance
  }

  private struct MembershipRetirement {
    let membership: PlannerSchemaV18.Membership
    let identity: PlannerPortableBoundIdentity
    let provenance: PlannerPortableMembershipProvenance
    let marker: PortableDeletionMarker?
  }

  private struct LabelRebinding {
    let association: PlannerSchemaV18.LabelAssociation
    let winner: Row
    let projected: PortableLabelAssociationRecord
  }

  private struct OwnedLinkRetirement {
    let link: PlannerSchemaV18.OwnedLink
    let identity: PlannerPortableBoundIdentity
    let marker: PortableDeletionMarker?
  }

  private struct ScheduleRetirement {
    let schedule: PlannerSchemaV18.Schedule
    let identity: PlannerPortableBoundIdentity
    let marker: PortableDeletionMarker?
  }

  private struct LabelRetirement {
    let association: PlannerSchemaV18.LabelAssociation
    let identity: PlannerPortableBoundIdentity
    let marker: PortableDeletionMarker?
  }

  private let rows: [Row]
  private let entryRebindings: [EntryRebinding]
  private let entryRetirements: [EntryRetirement]
  private let membershipRebindings: [MembershipRebinding]
  private let membershipRetirements: [MembershipRetirement]
  private let expandedRetirements: [PlannerSchemaV18.ExpandedCompletion]
  private let labelRebindings: [LabelRebinding]
  private let ownedLinkRetirements: [OwnedLinkRetirement]
  private let scheduleRetirements: [ScheduleRetirement]
  private let labelRetirements: [LabelRetirement]
  let ruleVersion = 3
  let retired: Set<PlannerPortableBoundIdentity>
  var requiresMaintenance: Bool {
    !retired.isEmpty || !labelRetirements.isEmpty || !ownedLinkRetirements.isEmpty
      || !scheduleRetirements.isEmpty || !entryRetirements.isEmpty
  }
  private var retiredMemberships: Set<PlannerPortableBoundIdentity> {
    Set(membershipRetirements.map(\.identity))
  }

  init(context: ModelContext, markers: [PortableDeletionMarker]) throws {
    let rows = try Self.sourceRows(context)
    let lineage = try PlannerNativeLineage(context: context)
    let families = lineage.restorationFamilies
    let closedFamilies = Set(markers.compactMap(\.closedFamilyId))
    let closedSources = Set(
      [PlannerPortableIdentityKind.item, .list, .itinerary, .category, .tag].flatMap {
        Self.closedNativeIdentities(kind: $0, families: families, markers: markers)
      })
    let groups = Dictionary(grouping: rows.filter { !closedSources.contains($0.identity) }) {
      $0.identity.kind.rawValue + ":" + $0.identity.id.uuidString
    }
    var retired = Set(rows.filter { closedSources.contains($0.identity) }.map(\.identity))
    var winners: [PlannerPortableBoundIdentity: Row] = [:]
    var labelWinners: Set<PlannerPortableBoundIdentity> = []
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
      if group.count == 1, relevant.isEmpty {
        guard
          !closedSources.contains(where: {
            $0.kind == first.identity.kind && $0.id == first.identity.id
          })
        else {
          throw Self.unresolved("A new lifetime for a closed source requires restoration history.")
        }
        continue
      }
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
      if first.identity.kind == .category || first.identity.kind == .tag {
        labelWinners.insert(winnerRow.identity)
      }
      for row in group where row.identity.lifetimeId != winner {
        retired.insert(row.identity)
        winners[row.identity] = winnerRow
      }
    }
    let membershipRetirements = try Self.membershipRetirements(
      context: context, rows: rows, retired: retired, lineage: lineage, markers: markers)
    let entryRetirements = try Self.entryRetirements(
      context: context, rows: rows, retired: retired, winners: winners,
      retiringMemberships: Set(membershipRetirements.map(\.identity)),
      families: families, markers: markers)
    let expandedRetirements = try Self.expandedRetirements(
      context: context, memberships: membershipRetirements, entries: entryRetirements,
      winners: winners)
    let entryRebindings = try Self.entryRebindings(
      context: context, rows: rows, retired: retired, winners: winners,
      retiringMemberships: Set(membershipRetirements.map(\.identity)), excluding: entryRetirements)
    let membershipRebindings = try Self.membershipRebindings(
      context: context, rows: rows, retired: retired, winners: winners)
    let labelRebindings = try Self.labelRebindings(
      context: context, rows: rows, retired: retired, winners: winners)
    let ownedLinkRetirements = try Self.ownedLinkRetirements(
      context: context, rows: rows, retired: retired, families: families, markers: markers)
    let scheduleRetirements = try Self.scheduleRetirements(
      context: context, rows: rows, retired: retired, families: families, markers: markers)
    let ownedLabels = try Self.ownedLabelRetirements(
      context: context, rows: rows, retired: retired, families: families, markers: markers)
    let labelRetirements =
      try ownedLabels
      + Self.labelRetirements(
        context: context, rebindings: labelRebindings, winners: labelWinners,
        families: families, markers: markers, excluding: ownedLabels)
    if !retired.isEmpty {
      try Self.requireUnreferenced(
        retired, context: context, admittedEntries: entryRebindings,
        admittedMemberships: membershipRebindings, admittedLabels: labelRebindings,
        retiredOwnedLinks: ownedLinkRetirements, retiredSchedules: scheduleRetirements,
        retiredLabels: labelRetirements, retiredMemberships: membershipRetirements,
        retiredEntries: entryRetirements)
    }
    self.rows = rows
    self.retired = retired
    self.entryRebindings = entryRebindings
    self.entryRetirements = entryRetirements
    self.membershipRebindings = membershipRebindings
    self.membershipRetirements = membershipRetirements
    self.expandedRetirements = expandedRetirements
    self.labelRebindings = labelRebindings
    self.ownedLinkRetirements = ownedLinkRetirements
    self.scheduleRetirements = scheduleRetirements
    self.labelRetirements = labelRetirements
  }

  func project(_ snapshot: PlannerDataSnapshot) -> PlannerDataSnapshot {
    PlannerDataSnapshot(
      snapshot: snapshot, retiringSources: retired,
      reboundEntries: entryRebindings.map(\.projected),
      reboundMemberships: membershipRebindings.map(\.projected),
      originalProvenance:
        membershipRebindings.map(\.provenance) + membershipRetirements.map(\.provenance),
      reboundLabels: labelRebindings.map(\.projected),
      retiringOwnedLinks: Set(ownedLinkRetirements.map(\.identity)),
      retiringSchedules: Set(scheduleRetirements.map(\.identity)),
      retiringLabels: Set(labelRetirements.map(\.identity)),
      retiringMemberships: retiredMemberships,
      retiringEntries: Set(entryRetirements.map(\.identity)),
      associationClosures:
        labelRetirements.compactMap(\.marker) + membershipRetirements.compactMap(\.marker)
        + entryRetirements.compactMap(\.marker) + ownedLinkRetirements.compactMap(\.marker)
        + scheduleRetirements.compactMap(\.marker))
  }

  func retiresOwnedLink(_ link: PlannerSchemaV18.OwnedLink) -> Bool {
    ownedLinkRetirements.contains { $0.link === link }
  }

  func retiresSchedule(_ schedule: PlannerSchemaV18.Schedule) -> Bool {
    scheduleRetirements.contains { $0.schedule === schedule }
  }

  func retiresLabelAssociation(_ association: PlannerSchemaV18.LabelAssociation) -> Bool {
    labelRetirements.contains { $0.association === association }
  }

  func retiresExpandedCompletion(_ completion: PlannerSchemaV18.ExpandedCompletion) -> Bool {
    expandedRetirements.contains { $0 === completion }
  }

  func retiresEntry(_ entry: PlannerSchemaV18.ItineraryEntry) -> Bool {
    entryRetirements.contains { $0.entry === entry }
  }

  func itemValue(_ item: PlannerSchemaV18.Item) throws -> ItemSnapshot {
    try item.value(retiringOwnedLinks: Set(ownedLinkRetirements.map(\.identity)))
  }

  func itineraryValue(_ itinerary: PlannerSchemaV18.Itinerary) throws -> ItinerarySnapshot {
    let entries = try (itinerary.entries ?? []).filter { !retiresEntry($0) }.map { entry in
      if let rebinding = entryRebindings.first(where: { $0.entry === entry }) {
        return rebinding.snapshot
      }
      return try entry.value(retiringMemberships: retiredMemberships)
    }
    return try itinerary.value(
      entrySnapshots: entries, retiringOwnedLinks: Set(ownedLinkRetirements.map(\.identity)))
  }

  func stage(in context: ModelContext) throws {
    for completion in expandedRetirements { context.delete(completion) }
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
    for retirement in ownedLinkRetirements {
      context.delete(retirement.link)
      if let marker = retirement.marker {
        context.insert(try PlannerSchemaV4.DeletionMarker(marker))
      }
    }
    for retirement in scheduleRetirements {
      context.delete(retirement.schedule)
      if let marker = retirement.marker {
        context.insert(try PlannerSchemaV4.DeletionMarker(marker))
      }
    }
    for retirement in labelRetirements {
      context.delete(retirement.association)
      if let marker = retirement.marker {
        context.insert(try PlannerSchemaV4.DeletionMarker(marker))
      }
    }
    for retirement in membershipRetirements {
      context.delete(retirement.membership)
      if let marker = retirement.marker {
        context.insert(try PlannerSchemaV4.DeletionMarker(marker))
      }
    }
    for retirement in entryRetirements {
      context.delete(retirement.entry)
      if let marker = retirement.marker {
        context.insert(try PlannerSchemaV4.DeletionMarker(marker))
      }
    }
    for row in rows where retired.contains(row.identity) { context.delete(row.model) }
    context.processPendingChanges()
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
          identity: try binding(.item, item.id, item.lifetimeId), model: item))
    }
    for list in try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()) {
      rows.append(
        .init(
          identity: try binding(.list, list.id, list.lifetimeId), model: list))
    }
    for itinerary in try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()) {
      rows.append(
        .init(
          identity: try binding(.itinerary, itinerary.id, itinerary.lifetimeId), model: itinerary))
    }
    for category in try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()) {
      rows.append(
        .init(
          identity: try binding(.category, category.id, category.lifetimeId), model: category))
    }
    for tag in try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()) {
      rows.append(
        .init(
          identity: try binding(.tag, tag.id, tag.lifetimeId), model: tag))
    }
    return rows
  }

  private static func ownedLinkRetirements(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    families: [PlannerPortableRestorationFamily], markers: [PortableDeletionMarker]
  ) throws -> [OwnedLinkRetirement] {
    let closed = closedNativeIdentities(kind: .ownedLink, families: families, markers: markers)
    guard !retired.isEmpty || !closed.isEmpty else { return [] }
    var retirements: [OwnedLinkRetirement] = []
    for link in try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()) {
      let identity = try binding(.ownedLink, link.id, link.lifetimeId)
      guard let ownerKind = PlannerPortableIdentityKind(rawValue: link.ownerKind) else {
        throw unresolved("A native bookmark has an unsupported owner kind.")
      }
      let owner = try binding(ownerKind, link.ownerId, link.ownerLifetimeId)
      guard retired.contains(owner) || closed.contains(identity) else { continue }
      guard let row = rows.first(where: { $0.identity == owner }) else {
        throw unresolved("A retired bookmark owner is unresolved.")
      }
      if let item = row.model as? PlannerSchemaV18.Item {
        guard link.itemOwner === item, link.itineraryOwner == nil else {
          throw unresolved("A retired bookmark has inconsistent Item ownership.")
        }
      } else if let itinerary = row.model as? PlannerSchemaV18.Itinerary {
        guard link.itineraryOwner === itinerary, link.itemOwner == nil else {
          throw unresolved("A retired bookmark has inconsistent Itinerary ownership.")
        }
      } else {
        throw unresolved("A retired bookmark has an unsupported owner.")
      }
      _ = try link.value(
        ownerId: owner.id, ownerLifetimeId: owner.lifetimeId, ownerKind: owner.kind.rawValue)
      let marker: PortableDeletionMarker?
      if closed.contains(identity) {
        marker = nil
      } else {
        marker = try PortableDeletionMarker(
          deletionId: closureIdentifier(identity, role: "deletion"),
          operationId: closureIdentifier(identity, role: "maintenance"),
          target: .ownedLink(id: identity.id, lifetimeId: identity.lifetimeId), closedFamilyId: nil
        ).closingRestorationFamily(families)
      }
      retirements.append(
        .init(link: link, identity: identity, marker: marker))
    }
    return retirements
  }

  private static func scheduleRetirements(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    families: [PlannerPortableRestorationFamily], markers: [PortableDeletionMarker]
  ) throws -> [ScheduleRetirement] {
    let closed = closedNativeIdentities(kind: .schedule, families: families, markers: markers)
    guard !retired.isEmpty || !closed.isEmpty else { return [] }
    var retirements: [ScheduleRetirement] = []
    for schedule in try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()) {
      let identity = try binding(.schedule, schedule.id, schedule.lifetimeId)
      guard let ownerKind = PlannerPortableIdentityKind(rawValue: schedule.sourceKind) else {
        throw unresolved("A native Schedule has an unsupported owner kind.")
      }
      let owner = try binding(ownerKind, schedule.sourceId, schedule.sourceLifetimeId)
      guard retired.contains(owner) || closed.contains(identity) else { continue }
      guard let row = rows.first(where: { $0.identity == owner }) else {
        throw unresolved("A retired Schedule owner is unresolved.")
      }
      if let item = row.model as? PlannerSchemaV18.Item {
        guard schedule.itemOwner === item, schedule.itineraryOwner == nil else {
          throw unresolved("A retired Schedule has inconsistent Item ownership.")
        }
      } else if let itinerary = row.model as? PlannerSchemaV18.Itinerary {
        guard schedule.itineraryOwner === itinerary, schedule.itemOwner == nil else {
          throw unresolved("A retired Schedule has inconsistent Itinerary ownership.")
        }
      } else {
        throw unresolved("A retired Schedule has an unsupported owner.")
      }
      _ = try schedule.value(
        ownerId: owner.id, ownerLifetimeId: owner.lifetimeId, ownerKind: owner.kind.rawValue)
      let marker: PortableDeletionMarker?
      if closed.contains(identity) {
        marker = nil
      } else {
        marker = try PortableDeletionMarker(
          deletionId: closureIdentifier(identity, role: "deletion"),
          operationId: closureIdentifier(identity, role: "maintenance"),
          target: .source(
            .init(kind: "schedule", id: identity.id, lifetimeId: identity.lifetimeId)),
          closedFamilyId: nil
        ).closingRestorationFamily(families)
      }
      retirements.append(
        .init(schedule: schedule, identity: identity, marker: marker))
    }
    return retirements
  }

  private static func closedNativeIdentities(
    kind: PlannerPortableIdentityKind, families: [PlannerPortableRestorationFamily],
    markers: [PortableDeletionMarker]
  ) -> Set<PlannerPortableBoundIdentity> {
    var identities: Set<PlannerPortableBoundIdentity> = []
    for marker in markers {
      switch marker.target {
      case .ownedLink(let identifier, let lifetime) where kind == .ownedLink:
        identities.insert(.init(kind: kind, id: identifier, lifetimeId: lifetime))
      case .source(let source) where kind != .ownedLink && source.kind == kind.rawValue:
        identities.insert(.init(kind: kind, id: source.id, lifetimeId: source.lifetimeId))
      case .itineraryEntry(let identifier, let lifetime) where kind == .itineraryEntry:
        identities.insert(.init(kind: kind, id: identifier, lifetimeId: lifetime))
      default: continue
      }
    }
    let closedFamilies = Set(markers.compactMap(\.closedFamilyId))
    for family in families
    where family.predecessor.kind == kind && closedFamilies.contains(family.familyId) {
      for candidate in family.candidates {
        identities.insert(
          .init(kind: kind, id: family.predecessor.id, lifetimeId: candidate.lifetimeId))
      }
    }
    return identities
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
      if retired.contains(owner) { continue }
      guard rows.filter({ $0.identity == owner }).count == 1,
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

  private static func ownedLabelRetirements(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    families: [PlannerPortableRestorationFamily], markers: [PortableDeletionMarker]
  ) throws -> [LabelRetirement] {
    guard !retired.isEmpty else { return [] }
    var retirements: [LabelRetirement] = []
    for association in try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()) {
      guard let kind = PlannerPortableIdentityKind(rawValue: association.ownerKind) else {
        throw unresolved("A native label selection has an unsupported owner kind.")
      }
      let owner = try binding(kind, association.ownerId, association.ownerLifetimeId)
      guard retired.contains(owner) else { continue }
      guard let row = rows.first(where: { $0.identity == owner }) else {
        throw unresolved("A retired label-selection owner is unresolved.")
      }
      if let item = row.model as? PlannerSchemaV18.Item {
        guard association.itemOwner === item, association.itineraryOwner == nil else {
          throw unresolved("A retired label selection has inconsistent Item ownership.")
        }
      } else if let itinerary = row.model as? PlannerSchemaV18.Itinerary {
        guard association.itineraryOwner === itinerary, association.itemOwner == nil else {
          throw unresolved("A retired label selection has inconsistent Itinerary ownership.")
        }
      } else {
        throw unresolved("A retired label selection has an unsupported owner.")
      }
      let value = try association.value()
      retirements.append(
        try labelRetirement(
          association,
          identity: .init(kind: .labelAssociation, id: value.id, lifetimeId: value.lifetimeId),
          families: families, markers: markers))
    }
    return retirements
  }

  private static func labelRetirements(
    context: ModelContext, rebindings: [LabelRebinding],
    winners: Set<PlannerPortableBoundIdentity>, families: [PlannerPortableRestorationFamily],
    markers: [PortableDeletionMarker], excluding ownedLabels: [LabelRetirement]
  ) throws -> [LabelRetirement] {
    guard !winners.isEmpty else { return [] }
    var groups: [Data: [(PlannerSchemaV18.LabelAssociation, PortableLabelAssociationRecord)]] = [:]
    for association in try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()) {
      if ownedLabels.contains(where: { $0.association === association }) { continue }
      let value =
        try rebindings.first { $0.association === association }?.projected
        ?? PortableLabelAssociationRecord(association.value())
      guard let kind = PlannerPortableIdentityKind(rawValue: value.label.kind),
        winners.contains(.init(kind: kind, id: value.label.id, lifetimeId: value.label.lifetimeId))
      else { continue }
      let key = PlannerCanonicalValue.record([
        "owner": value.owner.canonicalValue, "label": value.label.canonicalValue,
      ]).encoded()
      groups[key, default: []].append((association, value))
    }
    var retirements: [LabelRetirement] = []
    for group in groups.values {
      guard Set(group.map { $0.1.id }).count == group.count else {
        throw unresolved("Competing label associations have the same public identity.")
      }
      let closed = group.filter { _, value in
        markers.contains { marker in
          guard case .labelAssociation(let identifier, let lifetime) = marker.target else {
            return false
          }
          return identifier == value.id && lifetime == value.lifetimeId
        }
      }
      let available = group.filter { record in !closed.contains { $0.0 === record.0 } }
        .sorted { $0.1.id.uuidString < $1.1.id.uuidString }
      for (association, value) in closed + available.dropFirst() {
        let identity = PlannerPortableBoundIdentity(
          kind: .labelAssociation, id: value.id, lifetimeId: value.lifetimeId)
        retirements.append(
          try labelRetirement(
            association, identity: identity, families: families, markers: markers))
      }
    }
    return retirements
  }

  private static func labelRetirement(
    _ association: PlannerSchemaV18.LabelAssociation, identity: PlannerPortableBoundIdentity,
    families: [PlannerPortableRestorationFamily], markers: [PortableDeletionMarker]
  ) throws -> LabelRetirement {
    let closed = markers.contains { marker in
      guard case .labelAssociation(let identifier, let lifetime) = marker.target else {
        return false
      }
      return identifier == identity.id && lifetime == identity.lifetimeId
    }
    if closed { return .init(association: association, identity: identity, marker: nil) }
    let marker = try PortableDeletionMarker(
      deletionId: closureIdentifier(identity, role: "deletion"),
      operationId: closureIdentifier(identity, role: "maintenance"),
      target: .labelAssociation(id: identity.id, lifetimeId: identity.lifetimeId),
      closedFamilyId: nil
    ).closingRestorationFamily(families)
    return .init(association: association, identity: identity, marker: marker)
  }

  /// Stable closure identities keep repeated projections and durable preparation consistent.
  private static func closureIdentifier(_ identity: PlannerPortableBoundIdentity, role: String)
    -> UUID
  {
    let namespace: String
    if identity.kind == .membership {
      namespace = "PlannerRestoredMembershipClosure-v1"
    } else if identity.kind == .itineraryEntry {
      namespace = "PlannerRestoredItineraryEntryClosure-v1"
    } else if identity.kind == .ownedLink {
      namespace = "PlannerRestoredOwnedLinkClosure-v1"
    } else if identity.kind == .schedule {
      namespace = "PlannerRestoredScheduleClosure-v1"
    } else {
      namespace = "PlannerRestoredLabelClosure-v1"
    }
    let input = "\(namespace)/\(identity.id)/\(identity.lifetimeId)/\(role)"
    var digest = Array(SHA256.hash(data: Data(input.utf8)))
    digest[6] = (digest[6] & 0x0f) | 0x80
    digest[8] = (digest[8] & 0x3f) | 0x80
    return UUID(
      uuid: (
        digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
        digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]
      ))
  }

  /// Retired flags do not seed surviving completion; the complete graph retains and validates history.
  private static func entryRetirements(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    winners: [PlannerPortableBoundIdentity: Row],
    retiringMemberships: Set<PlannerPortableBoundIdentity>,
    families: [PlannerPortableRestorationFamily], markers: [PortableDeletionMarker]
  ) throws -> [EntryRetirement] {
    let closedEntries = closedNativeIdentities(
      kind: .itineraryEntry, families: families, markers: markers)
    guard !retired.isEmpty || !closedEntries.isEmpty else { return [] }
    var identities: Set<PlannerPortableBoundIdentity> = []
    var retirements: [EntryRetirement] = []
    for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()) {
      let owner = try binding(.itinerary, entry.itineraryId, entry.itineraryLifetimeId)
      let identity = try binding(.itineraryEntry, entry.id, entry.lifetimeId)
      if !retired.contains(owner), !closedEntries.contains(identity) {
        guard
          !closedEntries.contains(where: { $0.id == identity.id })
            || families.contains(where: { family in
              family.predecessor.kind == .itineraryEntry && family.predecessor.id == identity.id
                && family.candidates.contains { $0.lifetimeId == identity.lifetimeId }
            })
        else {
          throw unresolved("A new lifetime for a closed stop requires restoration history.")
        }
        continue
      }
      guard let row = rows.first(where: { $0.identity == owner }),
        let itinerary = row.model as? PlannerSchemaV18.Itinerary, entry.itinerary === itinerary,
        let sourceKind = PlannerPortableIdentityKind(rawValue: entry.sourceKind)
      else { throw unresolved("A retired stop has inconsistent Itinerary ownership.") }
      let source = try binding(sourceKind, entry.sourceId, entry.sourceLifetimeId)
      let projectedListLifetime: UUID?
      if source.kind == .list {
        projectedListLifetime = winners[source]?.identity.lifetimeId
      } else {
        projectedListLifetime = nil
      }
      let value = try entry.value(
        projectedListLifetimeId: projectedListLifetime, retiringMemberships: retiringMemberships)
      guard identities.insert(identity).inserted else {
        throw unresolved("Competing retired stops have the same bound identity.")
      }
      let marker: PortableDeletionMarker?
      if closedEntries.contains(identity) {
        marker = nil
      } else {
        marker = try PortableDeletionMarker(
          deletionId: closureIdentifier(identity, role: "deletion"),
          operationId: closureIdentifier(identity, role: "maintenance"),
          target: .itineraryEntry(id: value.id, lifetimeId: value.lifetimeId), closedFamilyId: nil
        ).closingRestorationFamily(families)
      }
      retirements.append(
        .init(
          entry: entry, identity: identity, projectedListLifetime: projectedListLifetime,
          marker: marker))
    }
    return retirements
  }

  private static func membershipRetirements(
    context: ModelContext, rows: [Row], retired: Set<PlannerPortableBoundIdentity>,
    lineage: PlannerNativeLineage, markers: [PortableDeletionMarker]
  ) throws -> [MembershipRetirement] {
    guard !retired.isEmpty else { return [] }
    var identities: Set<PlannerPortableBoundIdentity> = []
    var retirements: [MembershipRetirement] = []
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
      let owner = try binding(.list, membership.listId, membership.listLifetimeId)
      guard retired.contains(owner) else { continue }
      guard let row = rows.first(where: { $0.identity == owner }),
        let list = row.model as? PlannerSchemaV18.List, membership.list === list
      else { throw unresolved("A retired membership has inconsistent List ownership.") }
      let value = try membership.value()
      let identity = PlannerPortableBoundIdentity(
        kind: .membership, id: value.id, lifetimeId: value.lifetimeId)
      guard identities.insert(identity).inserted else {
        throw unresolved("Competing retired memberships have the same bound identity.")
      }
      let provenance =
        lineage.membershipProvenance.first { $0.membership == identity } ?? value.baselineProvenance
      guard
        try plannerMembershipHistoryPair(provenance.pair, families: lineage.restorationFamilies)
          == plannerMembershipHistoryPair(
            value.baselineProvenance.pair, families: lineage.restorationFamilies)
      else { throw unresolved("Retired membership provenance describes another source pair.") }
      let closed = markers.contains { marker in
        guard case .membership(let target) = marker.target else { return false }
        return target.kind == "membership" && target.id == value.id
          && target.lifetimeId == value.lifetimeId
      }
      let marker: PortableDeletionMarker?
      if closed {
        marker = nil
      } else {
        marker = try PortableDeletionMarker(
          deletionId: closureIdentifier(identity, role: "deletion"),
          operationId: closureIdentifier(identity, role: "maintenance"),
          target: .membership(
            .init(kind: "membership", id: value.id, lifetimeId: value.lifetimeId)),
          closedFamilyId: nil
        ).closingRestorationFamily(lineage.restorationFamilies)
      }
      retirements.append(
        .init(membership: membership, identity: identity, provenance: provenance, marker: marker))
    }
    return retirements
  }

  private static func expandedRetirements(
    context: ModelContext, memberships: [MembershipRetirement],
    entries: [EntryRetirement],
    winners: [PlannerPortableBoundIdentity: Row]
  ) throws -> [PlannerSchemaV18.ExpandedCompletion] {
    guard !memberships.isEmpty || !entries.isEmpty else { return [] }
    var contexts: Set<PlannerExpandedContext> = []
    var retirements: [PlannerSchemaV18.ExpandedCompletion] = []
    for completion in try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()) {
      let value: ExpandedCompletionSnapshot
      if let retirement = memberships.first(where: {
        $0.identity.id == completion.membershipId
          && $0.identity.lifetimeId == completion.membershipLifetimeId
      }) {
        let member = try retirement.membership.value()
        let owner = try binding(.list, member.list.id, member.list.lifetimeId)
        guard completion.membership === retirement.membership,
          let original = retirement.membership.list,
          let winner = winners[owner]?.model as? PlannerSchemaV18.List,
          let entry = completion.listEntry, entry.list === original || entry.list === winner,
          entry.sourceLifetimeId == original.lifetimeId
            || entry.sourceLifetimeId == winner.lifetimeId
        else { throw unresolved("A retiring expanded completion has an unresolved List scope.") }
        value = try completion.value(projectedListLifetimeId: member.list.lifetimeId)
      } else if let retirement = entries.first(where: {
        $0.identity.id == completion.listEntryId
          && $0.identity.lifetimeId == completion.listEntryLifetimeId
      }) {
        guard completion.listEntry === retirement.entry else {
          throw unresolved("A retiring expanded completion has inconsistent stop ownership.")
        }
        value = try completion.value(projectedListLifetimeId: retirement.projectedListLifetime)
      } else {
        continue
      }
      guard contexts.insert(value.context).inserted else {
        throw unresolved("Retiring associations have duplicate expanded completion contexts.")
      }
      retirements.append(completion)
    }
    return retirements
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
      if retired.contains(owner) { continue }
      guard rows.filter({ $0.identity == owner }).count == 1,
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
    winners: [PlannerPortableBoundIdentity: Row],
    retiringMemberships: Set<PlannerPortableBoundIdentity>, excluding entries: [EntryRetirement]
  ) throws -> [EntryRebinding] {
    guard !retired.isEmpty else { return [] }
    let lineage = try PlannerNativeLineage(context: context)
    let completionStates = try plannerCompletionHistoryStates(
      aliases: lineage.contextAliases, changes: lineage.completionChanges,
      deletionMarkers: lineage.deletionMarkers.compactMap(\.expandedCompletionMarker))
    var rebindings: [EntryRebinding] = []
    for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()) {
      if entries.contains(where: { $0.entry === entry }) { continue }
      guard let sourceKind = PlannerPortableIdentityKind(rawValue: entry.sourceKind) else {
        throw unresolved("A native entry has an unsupported source kind.")
      }
      let source = try binding(sourceKind, entry.sourceId, entry.sourceLifetimeId)
      guard retired.contains(source) else { continue }
      let projectedListLifetime = source.kind == .list ? winners[source]?.identity.lifetimeId : nil
      let value = try entry.value(
        projectedListLifetimeId: projectedListLifetime, retiringMemberships: retiringMemberships)
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
    admittedLabels: [LabelRebinding], retiredOwnedLinks: [OwnedLinkRetirement],
    retiredSchedules: [ScheduleRetirement], retiredLabels: [LabelRetirement],
    retiredMemberships: [MembershipRetirement], retiredEntries: [EntryRetirement]
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
      if retiredMemberships.contains(where: { $0.membership === member }) { continue }
      if !admittedMemberships.contains(where: { $0.membership === member }) {
        try requireSurvivor("item", member.itemId, member.itemLifetimeId)
      }
      try requireSurvivor("list", member.listId, member.listLifetimeId)
    }
    for entry in try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()) {
      if retiredEntries.contains(where: { $0.entry === entry }) { continue }
      try requireSurvivor("itinerary", entry.itineraryId, entry.itineraryLifetimeId)
      if !admittedEntries.contains(where: { $0.entry === entry }) {
        try requireSurvivor(entry.sourceKind, entry.sourceId, entry.sourceLifetimeId)
      }
    }
    for link in try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()) {
      if retiredOwnedLinks.contains(where: { $0.link === link }) { continue }
      try requireSurvivor(link.ownerKind, link.ownerId, link.ownerLifetimeId)
    }
    for schedule in try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()) {
      if retiredSchedules.contains(where: { $0.schedule === schedule }) { continue }
      try requireSurvivor(schedule.sourceKind, schedule.sourceId, schedule.sourceLifetimeId)
    }
    for association in try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()) {
      if retiredLabels.contains(where: { $0.association === association }) { continue }
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
    reboundLabels: [PortableLabelAssociationRecord],
    retiringOwnedLinks: Set<PlannerPortableBoundIdentity>,
    retiringSchedules: Set<PlannerPortableBoundIdentity>,
    retiringLabels: Set<PlannerPortableBoundIdentity>,
    retiringMemberships: Set<PlannerPortableBoundIdentity>,
    retiringEntries: Set<PlannerPortableBoundIdentity>,
    associationClosures: [PortableDeletionMarker]
  ) {
    format = snapshot.format
    formatVersion = snapshot.formatVersion
    sources = snapshot.sources.filter { !retiringSources.contains($0.boundIdentity) }
    memberships = snapshot.memberships.filter {
      !retiringMemberships.contains(.init(kind: .membership, id: $0.id, lifetimeId: $0.lifetimeId))
    }.map { member in
      reboundMemberships.first { $0.id == member.id && $0.lifetimeId == member.lifetimeId }
        ?? member
    }
    itineraryEntries = snapshot.itineraryEntries.filter {
      !retiringEntries.contains(.init(kind: .itineraryEntry, id: $0.id, lifetimeId: $0.lifetimeId))
    }.map { entry in
      reboundEntries.first { $0.id == entry.id && $0.lifetimeId == entry.lifetimeId } ?? entry
    }
    expandedCompletions = snapshot.expandedCompletions.filter {
      !retiringMemberships.contains(
        .init(
          kind: .membership, id: $0.context.membershipId,
          lifetimeId: $0.context.membershipLifetimeId))
        && !retiringEntries.contains(
          .init(
            kind: .itineraryEntry, id: $0.context.listEntryId,
            lifetimeId: $0.context.listEntryLifetimeId))
    }
    labelAssociations = snapshot.labelAssociations.filter {
      !retiringLabels.contains(.init(kind: .labelAssociation, id: $0.id, lifetimeId: $0.lifetimeId))
    }.map { association in
      reboundLabels.first { $0.id == association.id && $0.lifetimeId == association.lifetimeId }
        ?? association
    }
    ownedLinks = snapshot.ownedLinks.filter {
      !retiringOwnedLinks.contains(.init(kind: .ownedLink, id: $0.id, lifetimeId: $0.lifetimeId))
    }
    schedules = snapshot.schedules.filter {
      !retiringSchedules.contains(.init(kind: .schedule, id: $0.id, lifetimeId: $0.lifetimeId))
    }
    deletionMarkers = (snapshot.deletionMarkers + associationClosures).sorted {
      $0.deletionId.uuidString < $1.deletionId.uuidString
    }
    contextAliases = snapshot.contextAliases
    completionChanges = snapshot.completionChanges
    restorationFamilies = snapshot.restorationFamilies
    var represented = Set(snapshot.membershipProvenance.map(\.membership))
    membershipProvenance =
      (snapshot.membershipProvenance
      + originalProvenance.filter {
        represented.insert($0.membership).inserted
      }).map(\.normalized).sorted {
        if $0.membershipId != $1.membershipId {
          return $0.membershipId.uuidString < $1.membershipId.uuidString
        }
        return $0.membershipLifetimeId.uuidString < $1.membershipLifetimeId.uuidString
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
