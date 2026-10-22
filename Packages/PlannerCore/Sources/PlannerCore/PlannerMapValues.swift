import Foundation

public struct PlannerMapCollection: Sendable, Equatable {
  public let source: PlannerEntityReference
  public let sourceLifetimeId: UUID
  public let title: String
}

public enum PlannerMapPlacement: Sendable, Equatable {
  case listMembership(membershipId: UUID, childPosition: Int64)
  case itineraryItem(entryId: UUID, routePosition: Int64)
  case itineraryListItem(
    entryId: UUID, routePosition: Int64, list: PlannerMapCollection, membershipId: UUID,
    childPosition: Int64)
}

public struct PlannerMapListBranch: Sendable, Equatable {
  public let entryId: UUID
  public let routePosition: Int64
  public let list: PlannerMapCollection
  public let matchesHeader: Bool
  public let matchingChildCount: Int64
}

public struct PlannerMapRowRead: Sendable, Equatable {
  public let identity: PlannerRowIdentity
  public let sourceLifetimeId: UUID
  public let title: String
  public let ownedLocation: PlannerOwnedLocation?
  public let mapsLinks: [PlannerOwnedLinkRead]
  public let placement: PlannerMapPlacement?
}

public struct PlannerMapRowWindow: Sendable {
  public let generation: UUID
  public let offset: Int64
  public let matchingCount: Int64
  public let collection: PlannerMapCollection?
  public let listBranches: [PlannerMapListBranch]
  public let rows: [PlannerMapRowRead]
}
