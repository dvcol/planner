import Foundation

/// Original association data issued after a saved removal, valid during this app run.
public struct PlannerAssociationUndoSnapshot: Sendable {
  public enum OriginalRecord: Sendable {
    case membership(PlannerPortableMembership)
    case itineraryEntry(PlannerPortableItineraryEntry)
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
}
