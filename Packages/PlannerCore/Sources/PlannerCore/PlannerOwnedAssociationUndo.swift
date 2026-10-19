import Foundation
import SwiftData

struct PlannerOwnedAssociationUndoStage {
  let references: [PlannerReferenceRead]
  let bindings: [PlannerBoundIdentity]
  let families: [PlannerPortableRestorationFamily]
}

extension Planner {
  func stageOwnedAssociationUndo(
    _ group: PlannerOwnedAssociationUndoGroup, closingOperationId: UUID, operationId: UUID,
    primary: PlannerPortableBoundIdentity, primaryLifetime: UUID,
    current: PlannerPortableBackup, context: ModelContext
  ) throws -> PlannerOwnedAssociationUndoStage {
    let graph = PlannerImportGraph(backup: current)
    guard let ownerKind = PlannerPortableIdentityKind(rawValue: group.owner.kind.rawValue),
      [.item, .itinerary].contains(group.owner.kind)
    else { throw unavailableOwnedAssociationUndo() }
    let owner = PlannerPortableBoundIdentity(
      kind: ownerKind, id: group.owner.id, lifetimeId: group.owner.lifetimeId)
    guard graph.liveIdentity(for: owner) == owner else { throw unavailableOwnedAssociationUndo() }
    let identities = group.identities
    for identity in identities {
      guard graph.liveIdentity(for: identity) == nil,
        current.deletionMarkers.contains(where: {
          $0.operationId == closingOperationId && $0.target.importIdentity == identity
        }), !current.restorationFamilies.contains(where: { $0.predecessor == identity })
      else { throw unavailableOwnedAssociationUndo() }
    }
    for association in group.removedLabels {
      guard let kind = PlannerPortableIdentityKind(rawValue: association.label.kind.rawValue) else {
        throw unavailableOwnedAssociationUndo()
      }
      let label = PlannerPortableBoundIdentity(
        kind: kind, id: association.label.id, lifetimeId: association.labelLifetimeId)
      guard graph.liveIdentity(for: label) == label,
        !current.labelAssociations.contains(where: {
          $0.owner == association.owner && $0.ownerLifetimeId == association.ownerLifetimeId
            && $0.label == association.label && $0.labelLifetimeId == association.labelLifetimeId
        })
      else { throw unavailableOwnedAssociationUndo() }
    }

    let item: PlannerSchemaV18.Item?
    let itinerary: PlannerSchemaV18.Itinerary?
    let currentLinks: [OwnedLinkSnapshot]
    let currentLabels: [LabelAssociationSnapshot]
    if group.owner.kind == .item {
      let owners = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter {
        $0.id == group.owner.id && $0.lifetimeId == group.owner.lifetimeId
      }
      guard owners.count == 1, let owner = owners.first else {
        throw unavailableOwnedAssociationUndo()
      }
      let value = try owner.value()
      item = owner
      itinerary = nil
      currentLinks = value.links
      currentLabels = value.labelAssociations
    } else {
      let owners = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).filter {
        $0.id == group.owner.id && $0.lifetimeId == group.owner.lifetimeId
      }
      guard owners.count == 1, let owner = owners.first else {
        throw unavailableOwnedAssociationUndo()
      }
      let value = try owner.value()
      item = nil
      itinerary = owner
      currentLinks = value.links
      currentLabels = value.labelAssociations
    }
    var lifetimes: [PlannerPortableBoundIdentity: UUID] = [:]
    for identity in identities {
      if identity == primary {
        lifetimes[identity] = primaryLifetime
      } else {
        lifetimes[identity] = UUID()
      }
    }
    let links = try restoredOwnedLinks(group, current: currentLinks, lifetimes: lifetimes)
    let restoredLabels = try group.removedLabels.map { original in
      let identity = PlannerPortableBoundIdentity(
        kind: .labelAssociation, id: original.id, lifetimeId: original.lifetimeId)
      guard let lifetime = lifetimes[identity] else { throw unavailableOwnedAssociationUndo() }
      return LabelAssociationSnapshot(
        id: original.id, lifetimeId: lifetime,
        owner: .init(
          kind: group.owner.kind.rawValue, id: group.owner.id, lifetimeId: group.owner.lifetimeId),
        label: .init(
          kind: original.label.kind.rawValue, id: original.label.id,
          lifetimeId: original.labelLifetimeId))
    }
    let categories = try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>())
    let tags = try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>())
    let labels = currentLabels + restoredLabels
    if let item {
      if !group.removedLinks.isEmpty { item.replaceLinks(with: links, context: context) }
      if !group.removedLabels.isEmpty {
        try item.replaceLabelAssociations(
          with: labels, categories: categories, tags: tags, context: context)
      }
      item.updatedAt = Date()
    }
    if let itinerary {
      if !group.removedLinks.isEmpty { try itinerary.replaceLinks(with: links, context: context) }
      if !group.removedLabels.isEmpty {
        try itinerary.replaceLabelAssociations(
          with: labels, categories: categories, tags: tags, context: context)
      }
      itinerary.updatedAt = Date()
    }
    let references = try identities.map { identity -> PlannerReferenceRead in
      if identity.kind == .ownedLink {
        return .ownedLink(id: identity.id, owner: group.owner.reference)
      }
      guard let label = restoredLabels.first(where: { $0.id == identity.id }) else {
        throw unavailableOwnedAssociationUndo()
      }
      return label.reference
    }
    let bindings =
      [
        PlannerBoundIdentity(
          kind: group.owner.kind.rawValue, id: group.owner.id, lifetimeId: group.owner.lifetimeId)
      ]
      + identities.map { identity in
        PlannerBoundIdentity(
          kind: identity.kind.rawValue, id: identity.id, lifetimeId: identity.lifetimeId)
      } + restoredLabels.map(\.label)
    let families = try identities.map { identity in
      guard let lifetime = lifetimes[identity] else { throw unavailableOwnedAssociationUndo() }
      return PlannerPortableRestorationFamily(
        familyId: plannerRestorationFamilyIdentifier(identity), predecessor: identity,
        candidates: [.init(lifetimeId: lifetime, operationId: operationId)])
    }
    return .init(references: references, bindings: bindings, families: families)
  }
}

private func restoredOwnedLinks(
  _ group: PlannerOwnedAssociationUndoGroup, current: [OwnedLinkSnapshot],
  lifetimes: [PlannerPortableBoundIdentity: UUID]
) throws -> [OwnedLinkSnapshot] {
  guard !group.removedLinks.isEmpty else { return current }
  let originalOrder = group.originalLinkOrder
  let originalIdentities = Set(originalOrder)
  let surviving = current.map {
    PlannerPortableBoundIdentity(kind: .ownedLink, id: $0.id, lifetimeId: $0.lifetimeId)
  }.filter(originalIdentities.contains)
  let survivingSet = Set(surviving)
  guard surviving == originalOrder.filter(survivingSet.contains) else {
    throw PlannerFailure(
      "associationUndoUnavailable", "Newer bookmark ordering prevents restoring this removal group."
    )
  }
  let removed = Dictionary(uniqueKeysWithValues: group.removedLinks.map { ($0.id, $0) })
  var merged = current
  var originalIndex = 0
  while originalIndex < originalOrder.count {
    guard removed[originalOrder[originalIndex].id] != nil else {
      originalIndex += 1
      continue
    }
    let start = originalIndex
    while originalIndex < originalOrder.count, removed[originalOrder[originalIndex].id] != nil {
      originalIndex += 1
    }
    let successor = originalOrder[originalIndex...].first(where: survivingSet.contains)
    let predecessor = originalOrder[..<start].last(where: survivingSet.contains)
    var insertionIndex = merged.count
    if let successor, let position = merged.firstIndex(where: { $0.id == successor.id }) {
      insertionIndex = position
    } else if let predecessor, let position = merged.firstIndex(where: { $0.id == predecessor.id })
    {
      insertionIndex = position + 1
    }
    for identity in originalOrder[start..<originalIndex] {
      guard let link = removed[identity.id], let lifetime = lifetimes[identity] else {
        throw unavailableOwnedAssociationUndo()
      }
      let rank = try associationInsertionRank(
        at: insertionIndex, ordered: merged, associations: &merged)
      merged.insert(
        .init(
          id: link.id, lifetimeId: lifetime, rank: rank, originalUrl: link.originalUrl,
          label: link.label, kind: link.kind, providerReference: link.providerReference),
        at: insertionIndex)
      insertionIndex += 1
    }
  }
  return merged
}

private func unavailableOwnedAssociationUndo() -> PlannerFailure {
  .init(
    "associationUndoUnavailable", "Newer association history prevents restoring this removal group."
  )
}
