#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  enum PlannerEstimateUnitChoice: String, AppEnum {
    case minute, hour, day, week, month, year
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Estimate unit")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .minute: "Minutes", .hour: "Hours", .day: "Days", .week: "Weeks",
      .month: "Months", .year: "Years",
    ]

    var minutesPerUnit: Int64 {
      switch self {
      case .minute: 1
      case .hour: 60
      case .day: 1_440
      case .week: 10_080
      case .month: 43_200
      case .year: 525_600
      }
    }

    var savedUnit: PlannerEstimateUnit {
      switch self {
      case .minute: .minute
      case .hour: .hour
      case .day: .day
      case .week: .week
      case .month: .month
      case .year: .year
      }
    }
  }

  struct SetPlannerItemEstimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item estimate"
    static let description = IntentDescription(
      "Set an exact whole-minute activity estimate. Days mean 24 hours, months 30 days and years 365 days. Bookings stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Quantity") var quantity: Int
    @Parameter(title: "Unit", default: .minute) var unit: PlannerEstimateUnitChoice
    @Parameter(title: "Additional minutes", default: 0) var additionalMinutes: Int
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await setPlannerEstimate(
        source: .init(kind: .item, id: item.id), quantity: quantity,
        unit: unit, additionalMinutes: additionalMinutes, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerListEstimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set List manual estimate"
    static let description = IntentDescription(
      "Set a manual overall estimate until you choose Use calculated List estimate. Days mean 24 hours, months 30 days and years 365 days."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var list: PlannerListEntity
    @Parameter(title: "Quantity") var quantity: Int
    @Parameter(title: "Unit", default: .minute) var unit: PlannerEstimateUnitChoice
    @Parameter(title: "Additional minutes", default: 0) var additionalMinutes: Int
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await setPlannerEstimate(
        source: .init(kind: .list, id: list.id), quantity: quantity,
        unit: unit, additionalMinutes: additionalMinutes, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItineraryEstimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Itinerary manual estimate"
    static let description = IntentDescription(
      "Set a manual overall estimate until you choose Use calculated Itinerary estimate. Days mean 24 hours, months 30 days and years 365 days."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Quantity") var quantity: Int
    @Parameter(title: "Unit", default: .minute) var unit: PlannerEstimateUnitChoice
    @Parameter(title: "Additional minutes", default: 0) var additionalMinutes: Int
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await setPlannerEstimate(
        source: .init(kind: .itinerary, id: itinerary.id), quantity: quantity,
        unit: unit, additionalMinutes: additionalMinutes, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  @MainActor
  private func setPlannerEstimate(
    source: PlannerEntityReference, quantity: Int, unit: PlannerEstimateUnitChoice,
    additionalMinutes: Int, store: SavedPlannerStore
  ) async throws -> IntentDialog {
    try Task.checkCancellation()
    guard quantity >= 0, additionalMinutes >= 0 else {
      throw PlannerEstimateSettingIntentFailure(
        message: "Quantity and additional minutes must be nonnegative whole numbers.")
    }
    let (baseMinutes, multiplicationOverflow) = Int64(quantity).multipliedReportingOverflow(
      by: unit.minutesPerUnit)
    let (minutes, additionOverflow) = baseMinutes.addingReportingOverflow(Int64(additionalMinutes))
    guard !multiplicationOverflow, !additionOverflow, minutes > 0 else {
      throw PlannerEstimateSettingIntentFailure(
        message: "Use an estimate from 1 through 9,223,372,036,854,775,807 minutes.")
    }
    let estimate = PlannerEstimate(minutes: minutes, displayUnit: unit.savedUnit)
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    let command: PlannerCommand
    switch await planner.read(session: session, request: .source(source)) {
    case .source(.item(let current)) where source.kind == .item:
      command = .editItem(
        sourceId: current.source.id, changes: .init(estimate: .set(estimate)),
        expectedFieldHashes: current.fieldHashes)
    case .source(.list(let current)) where source.kind == .list:
      command = .editList(
        sourceId: current.source.id, changes: .init(manualEstimate: .set(estimate)),
        expectedFieldHashes: current.fieldHashes)
    case .source(.itinerary(let current)) where source.kind == .itinerary:
      command = .editItinerary(
        sourceId: current.source.id, changes: .init(manualEstimate: .set(estimate)),
        expectedFieldHashes: current.fieldHashes)
    case .failed(let reason): throw PlannerEstimateSettingIntentFailure(message: reason.message)
    default:
      throw PlannerEstimateSettingIntentFailure(
        message: "Planner could not read this estimate's source.")
    }
    let result = try await store.executeAppIntent(command)
    switch result.outcome {
    case .rejected(let reason): throw PlannerEstimateSettingIntentFailure(message: reason.message)
    case .unverified:
      throw PlannerEstimateSettingIntentFailure(
        message:
          "Planner could not verify this change. Open Planner to review recovery before making another change."
      )
    case .applied(_, let recovery):
      switch recovery {
      case .complete: return "Updated the estimate. Completion and bookings are unchanged."
      case .incomplete:
        return
          "The estimate changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
    }
  }

  private struct PlannerEstimateSettingIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
