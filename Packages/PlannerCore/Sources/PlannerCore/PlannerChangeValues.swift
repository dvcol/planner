import Foundation

public struct PlannerChange: Sendable {
  public enum Payload: Sendable {
    case dataChanged(affected: [PlannerChangeIdentity]?)
    case recoveryStatusChanged(value: PlannerRecoveryObservation)
    case accountStatusChanged(value: PlannerAccountObservation)
    case cloudActivityChanged(value: PlannerCloudObservation)
  }

  public let notificationId: UUID
  public let payload: Payload
}

public enum PlannerChangeIdentity: Sendable {
  case source(PlannerEntityReference)
  case reference(PlannerReferenceRead)
}
