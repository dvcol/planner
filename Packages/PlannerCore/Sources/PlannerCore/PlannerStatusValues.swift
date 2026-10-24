import Foundation

public struct PlannerNativeStatusRead: Sendable {
  public let recovery: PlannerRecoveryObservation
  public let account: PlannerAccountObservation
  public let cloud: PlannerCloudObservation
}

public enum PlannerRecoveryObservation: Sendable {
  case known(
    checkpointGeneration: Int64?, incompleteOperationIds: [UUID],
    incompleteMaintenanceIds: [UUID], mutationBlocked: Bool
  )
  case unavailable(PlannerFailure)
}

public enum PlannerAccountObservation: Sendable {
  case available
  case unavailable(PlannerFailure)
  case unknown
}

public struct PlannerCloudObservation: Sendable {
  public enum State: Sendable { case unknown, idle, inProgress, error }
  public let state: State
  public let storeIdentity: String?
  public let eventId: String?
  public let observedAt: Date?
  public let reason: PlannerFailure?
}
