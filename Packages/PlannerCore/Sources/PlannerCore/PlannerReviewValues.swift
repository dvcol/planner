import Foundation

public enum PlannerBulkScope: Sendable, Equatable {
  case list(listId: UUID)
  case itinerary(itineraryId: UUID)
  case itineraryListEntry(itineraryId: UUID, listEntryId: UUID)
}

public struct PlannerReview: Sendable {
  public let reviewId: UUID
  public let reviewToken: PlannerReviewToken
  public let command: PlannerCommand
  public let targets: [PlannerAppearance]
  public let targetCount: Int64
  public let globalFlagsChanged: Bool
}

public enum PlannerReviewResult: Sendable {
  case reviewed(PlannerReview)
  case failed(PlannerFailure)
}
