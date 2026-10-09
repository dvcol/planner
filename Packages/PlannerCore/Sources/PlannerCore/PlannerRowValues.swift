import Foundation

public struct PlannerRowPresentationContext: Sendable, Equatable {
  public let referenceInstant: Date
  public let displayTimeZone: String

  public init(referenceInstant: Date, displayTimeZone: String) {
    self.referenceInstant = referenceInstant
    self.displayTimeZone = displayTimeZone
  }
}

public enum PlannerRowScheduleSummary: Sendable, Equatable {
  case none
  case directItem(
    schedule: PlannerEntityReference, owner: PlannerEntityReference,
    form: PlannerScheduleForm, additionalCount: Int64)
}

public struct PlannerRowRead: Sendable {
  public let identity: PlannerRowIdentity
  public let title: String
  public let subtitle: String?
  public let estimate: PlannerEstimate?
  public let globalDone: Bool?
  public let localDone: Bool?
  public let effectiveDone: Bool?
  public let archived: Bool?
  public let hasLocation: Bool
  public let hasLinks: Bool
  public let ownedLocation: PlannerOwnedLocation?
  public let previewLink: PlannerOwnedLinkRead?
  public let scheduleSummary: PlannerRowScheduleSummary
}

public struct PlannerRowWindow: Sendable {
  public let generation: UUID
  public let offset: Int64
  public let matchingCount: Int64
  public let rowPresentation: PlannerRowPresentationContext?
  public let rows: [PlannerRowRead]
}

extension PlannerRowPresentationContext {
  func validated() throws -> Self {
    guard referenceInstant.timeIntervalSinceReferenceDate.isFinite else {
      throw PlannerFailure(
        "invalidInput", "The row reference instant must be finite.",
        propertyPath: "/query/rowPresentation/referenceInstant")
    }
    guard TimeZone(identifier: displayTimeZone) != nil else {
      throw PlannerFailure(
        "invalidInput", "The row display timezone must be valid.",
        propertyPath: "/query/rowPresentation/displayTimeZone")
    }
    return self
  }
}
