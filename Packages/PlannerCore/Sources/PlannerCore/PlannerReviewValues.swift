import Foundation

public enum PlannerBulkScope: Sendable, Equatable {
  case list(listId: UUID)
  case itinerary(itineraryId: UUID)
  case itineraryListEntry(itineraryId: UUID, listEntryId: UUID)
}

public enum PlannerReviewTarget: Sendable, Equatable {
  case source(PlannerEntityReference)
  case appearance(PlannerAppearance)
  case reference(PlannerReferenceRead)
}

public struct PlannerReviewImpact: Sendable {
  public enum Kind: String, Sendable {
    case bulkCompletion, deleteSource
    case importData = "import"
  }
  public let kind: Kind
  public let targetCount: Int64
  public let globalFlagsChanged: Bool
  public let sourceDeletes: [PlannerEntityReference]
  public let referenceRemovals: [PlannerReferenceRead]
  public let importDetails: PlannerImportReview?

  init(
    kind: Kind, targetCount: Int64, globalFlagsChanged: Bool,
    sourceDeletes: [PlannerEntityReference], referenceRemovals: [PlannerReferenceRead],
    importDetails: PlannerImportReview? = nil
  ) {
    self.kind = kind
    self.targetCount = targetCount
    self.globalFlagsChanged = globalFlagsChanged
    self.sourceDeletes = sourceDeletes
    self.referenceRemovals = referenceRemovals
    self.importDetails = importDetails
  }
}

public struct PlannerReview: Sendable {
  public let reviewId: UUID
  public let reviewToken: PlannerReviewToken
  public let command: PlannerCommand
  public let targets: [PlannerReviewTarget]
  public let impact: PlannerReviewImpact
  public var targetCount: Int64 { impact.targetCount }
  public var globalFlagsChanged: Bool { impact.globalFlagsChanged }
}

public enum PlannerReviewResult: Sendable {
  case reviewed(PlannerReview)
  case failed(PlannerFailure)
}
