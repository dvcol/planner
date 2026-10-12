import Foundation

public enum PlannerPortableDeletionTarget: Sendable, Equatable {
  case source(PlannerEntityReference, lifetimeId: UUID)
  case membership(id: UUID, lifetimeId: UUID)
  case itineraryEntry(id: UUID, lifetimeId: UUID)
  case labelAssociation(id: UUID, lifetimeId: UUID)
  case ownedLink(id: UUID, lifetimeId: UUID)
  case expandedCompletion(PlannerExpandedContext)
}

public struct PlannerPortableDeletionMarker: Sendable, Equatable {
  public let deletionId: UUID
  public let operationId: UUID
  public let target: PlannerPortableDeletionTarget
  public let closedFamilyId: UUID?
}
