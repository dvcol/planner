import Foundation

public enum PlannerPortableDeletionTarget: Sendable, Equatable {
  case source(PlannerEntityReference, lifetimeId: UUID)
}

public struct PlannerPortableDeletionMarker: Sendable, Equatable {
  public let deletionId: UUID
  public let operationId: UUID
  public let target: PlannerPortableDeletionTarget
  public let closedFamilyId: UUID?
}
