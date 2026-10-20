#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct ClearPlannerItemEstimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Item estimate"
    static let description = IntentDescription(
      "Remove the Item's activity estimate. Its other data, planning entries and bookings stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await resetPlannerEstimate(
        source: .init(kind: .item, id: item.id), store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct UsePlannerListCalculatedEstimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Use calculated List estimate"
    static let description = IntentDescription(
      "Remove the List's manual total and use its live Item estimates. Completion and bookings stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var list: PlannerListEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await resetPlannerEstimate(
        source: .init(kind: .list, id: list.id), store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct UsePlannerItineraryCalculatedEstimateIntent: AppIntent {
    static let title: LocalizedStringResource = "Use calculated Itinerary estimate"
    static let description = IntentDescription(
      "Remove the Itinerary's manual total and use its live Item and List estimates. Completion and bookings stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await resetPlannerEstimate(
        source: .init(kind: .itinerary, id: itinerary.id), store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  @MainActor
  private func resetPlannerEstimate(
    source: PlannerEntityReference, store: SavedPlannerStore
  ) async throws -> IntentDialog {
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    let command: PlannerCommand
    switch await planner.read(session: session, request: .source(source)) {
    case .source(.item(let current)) where source.kind == .item:
      command = .editItem(
        sourceId: current.source.id, changes: .init(estimate: .clear),
        expectedFieldHashes: current.fieldHashes)
    case .source(.list(let current)) where source.kind == .list:
      command = .editList(
        sourceId: current.source.id, changes: .init(manualEstimate: .clear),
        expectedFieldHashes: current.fieldHashes)
    case .source(.itinerary(let current)) where source.kind == .itinerary:
      command = .editItinerary(
        sourceId: current.source.id, changes: .init(manualEstimate: .clear),
        expectedFieldHashes: current.fieldHashes)
    case .failed(let reason): throw PlannerEstimateResetIntentFailure(message: reason.message)
    default:
      throw PlannerEstimateResetIntentFailure(
        message: "Planner could not read this estimate's source.")
    }
    let result = try await store.executeAppIntent(command)
    switch result.outcome {
    case .rejected(let reason): throw PlannerEstimateResetIntentFailure(message: reason.message)
    case .unverified:
      throw PlannerEstimateResetIntentFailure(
        message:
          "Planner could not verify this change. Open Planner to review recovery before making another change."
      )
    case .applied(_, let recovery):
      switch recovery {
      case .complete:
        if source.kind == .item {
          return "The Item has no activity estimate. Its bookings are unchanged."
        }
        return "The plan now uses its calculated estimate. Completion and bookings are unchanged."
      case .incomplete:
        return
          "The estimate setting changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
    }
  }

  private struct PlannerEstimateResetIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
