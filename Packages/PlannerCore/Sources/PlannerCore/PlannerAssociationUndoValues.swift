import Foundation

/// Original association data issued after a saved removal, valid during this app run.
public struct PlannerAssociationUndoSnapshot: Sendable {
  public enum OriginalRecord: Sendable {
    case membership(PlannerPortableMembership)
    case itineraryEntry(PlannerPortableItineraryEntry)
    case membershipMove(PlannerMembershipMoveUndoRecord)
    case ownedAssociationGroup(PlannerOwnedAssociationUndoGroup)

    var membership: PlannerPortableMembership? {
      switch self {
      case .membership(let original): return original
      case .membershipMove(let move): return move.originalMembership
      case .itineraryEntry, .ownedAssociationGroup: return nil
      }
    }
  }

  init(
    storeIdentity: PlannerStoreIdentity, closingOperationId: UUID,
    entry: ItineraryEntrySnapshot
  ) {
    datasetId = storeIdentity.datasetId
    ownershipBinding = storeIdentity.ownershipBinding
    identity = .init(kind: .itineraryEntry, id: entry.id, lifetimeId: entry.lifetimeId)
    self.closingOperationId = closingOperationId
    originalRecord = .itineraryEntry(
      .init(
        id: entry.id, lifetimeId: entry.lifetimeId,
        itinerary: .init(kind: .itinerary, id: entry.itinerary.id),
        itineraryLifetimeId: entry.itinerary.lifetimeId,
        source: .init(kind: entry.source.kind == "item" ? .item : .list, id: entry.source.id),
        sourceLifetimeId: entry.source.lifetimeId, rank: entry.rank, localDone: entry.localDone))
    originalExpandedStates = entry.expandedCompletions.map {
      .init(context: $0.context, localDone: $0.localDone)
    }
  }

  public let datasetId: UUID
  public let ownershipBinding: String
  public let identity: PlannerPortableBoundIdentity
  public let closingOperationId: UUID
  public let originalRecord: OriginalRecord
  public let originalExpandedStates: [PlannerPortableExpandedCompletion]
  let issuanceIdentifier = UUID()

  init(
    storeIdentity: PlannerStoreIdentity, closingOperationId: UUID,
    membership: MembershipSnapshot, expandedStates: [ExpandedCompletionSnapshot]
  ) {
    datasetId = storeIdentity.datasetId
    ownershipBinding = storeIdentity.ownershipBinding
    identity = .init(kind: .membership, id: membership.id, lifetimeId: membership.lifetimeId)
    self.closingOperationId = closingOperationId
    originalRecord = .membership(
      .init(
        id: membership.id, lifetimeId: membership.lifetimeId,
        list: .init(kind: .list, id: membership.list.id),
        listLifetimeId: membership.list.lifetimeId,
        item: .init(kind: .item, id: membership.item.id),
        itemLifetimeId: membership.item.lifetimeId, rank: membership.rank,
        localDone: membership.localDone))
    originalExpandedStates = expandedStates.map {
      .init(context: $0.context, localDone: $0.localDone)
    }
  }

  var restorationDigest: String {
    let record: PlannerCanonicalValue
    switch originalRecord {
    case .membership(let membership): record = membership.importCanonicalValue
    case .itineraryEntry(let entry): record = entry.importCanonicalValue
    case .membershipMove(let move): record = move.canonicalValue
    case .ownedAssociationGroup(let group): record = group.canonicalValue
    }
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("restoreAssociation"),
        "closingOperationId": .identity(closingOperationId),
        "identity": identity.importCanonicalValue, "originalRecord": record,
        "originalExpandedStates": .ordered(originalExpandedStates.map(\.importCanonicalValue)),
      ]),
      "datasetId": .identity(datasetId), "ownershipBinding": .string(ownershipBinding),
    ])
    return plannerDigest(
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
      prefix: "sha256-payload-v1:")
  }

  init(
    storeIdentity: PlannerStoreIdentity, closingOperationId: UUID,
    move: PlannerMembershipMoveUndoRecord, expandedStates: [ExpandedCompletionSnapshot]
  ) {
    datasetId = storeIdentity.datasetId
    ownershipBinding = storeIdentity.ownershipBinding
    let original = move.originalMembership
    identity = .init(kind: .membership, id: original.id, lifetimeId: original.lifetimeId)
    self.closingOperationId = closingOperationId
    originalRecord = .membershipMove(move)
    originalExpandedStates = expandedStates.map {
      .init(context: $0.context, localDone: $0.localDone)
    }
  }

  init?(
    storeIdentity: PlannerStoreIdentity, closingOperationId: UUID,
    group: PlannerOwnedAssociationUndoGroup
  ) {
    guard let first = group.identities.first else { return nil }
    datasetId = storeIdentity.datasetId
    ownershipBinding = storeIdentity.ownershipBinding
    identity = first
    self.closingOperationId = closingOperationId
    originalRecord = .ownedAssociationGroup(group)
    originalExpandedStates = []
  }
}

public struct PlannerOwnedAssociationUndoGroup: Sendable {
  public let owner: PlannerBoundSource
  public let removedLinks: [PlannerPortableOwnedLink]
  public let removedLabels: [PlannerPortableLabelAssociation]
  public let originalLinkOrder: [PlannerPortableBoundIdentity]

  init(
    owner: PlannerBoundSource, originalLinks: [OwnedLinkSnapshot],
    removedLinks: [OwnedLinkSnapshot], removedLabels: [LabelAssociationSnapshot]
  ) {
    self.owner = owner
    self.removedLinks = removedLinks.map {
      .init(
        id: $0.id, lifetimeId: $0.lifetimeId, owner: owner, rank: $0.rank,
        originalUrl: $0.originalUrl, label: $0.label, kind: $0.kind,
        providerReference: $0.providerReference)
    }
    self.removedLabels = removedLabels.map {
      .init(
        id: $0.id, lifetimeId: $0.lifetimeId, owner: $0.ownerReference,
        ownerLifetimeId: $0.owner.lifetimeId, label: $0.labelReference,
        labelLifetimeId: $0.label.lifetimeId)
    }
    originalLinkOrder = originalLinks.map {
      .init(kind: .ownedLink, id: $0.id, lifetimeId: $0.lifetimeId)
    }
  }

  var identities: [PlannerPortableBoundIdentity] {
    let links = removedLinks.map {
      PlannerPortableBoundIdentity(kind: .ownedLink, id: $0.id, lifetimeId: $0.lifetimeId)
    }
    let labels = removedLabels.map {
      PlannerPortableBoundIdentity(kind: .labelAssociation, id: $0.id, lifetimeId: $0.lifetimeId)
    }
    return (links + labels).sorted {
      if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
      return $0.id.uuidString < $1.id.uuidString
    }
  }

  var canonicalValue: PlannerCanonicalValue {
    .record([
      "type": .string("ownedAssociationGroup"), "owner": owner.importCanonicalValue,
      "removedLinks": .identitySet(removedLinks.map(\.importCanonicalValue)),
      "removedLabels": .identitySet(removedLabels.map(\.importCanonicalValue)),
      "originalLinkOrder": .ordered(originalLinkOrder.map(\.importCanonicalValue)),
    ])
  }
}

public struct PlannerMembershipMoveUndoRecord: Sendable {
  public let originalMembership: PlannerPortableMembership
  public let createdDestinationMembership: PlannerPortableMembership?
  public let destinationEntries: [PlannerPortableBoundIdentity]
  public let destinationExpandedStates: [PlannerPortableExpandedCompletion]

  init(
    original: MembershipSnapshot, createdDestination: MembershipSnapshot?,
    destinationEntries: [ItineraryEntrySnapshot]
  ) {
    originalMembership = original.portableUndoRecord
    createdDestinationMembership = createdDestination?.portableUndoRecord
    self.destinationEntries = destinationEntries.map {
      .init(kind: .itineraryEntry, id: $0.id, lifetimeId: $0.lifetimeId)
    }
    destinationExpandedStates = []
  }

  var canonicalValue: PlannerCanonicalValue {
    .record([
      "type": .string("membershipMove"),
      "originalMembership": originalMembership.importCanonicalValue,
      "createdDestinationMembership": .optional(createdDestinationMembership?.importCanonicalValue),
      "destinationEntries": .identitySet(destinationEntries.map(\.importCanonicalValue)),
      "destinationExpandedStates": .ordered(destinationExpandedStates.map(\.importCanonicalValue)),
    ])
  }
}

extension MembershipSnapshot {
  var portableUndoRecord: PlannerPortableMembership {
    .init(
      id: id, lifetimeId: lifetimeId, list: .init(kind: .list, id: list.id),
      listLifetimeId: list.lifetimeId, item: .init(kind: .item, id: item.id),
      itemLifetimeId: item.lifetimeId, rank: rank, localDone: localDone)
  }
}
