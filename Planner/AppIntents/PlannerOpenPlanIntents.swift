#if !PLANNER_FIXTURES
  import AppIntents
  import PlannerCore

  struct OpenPlannerListIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open List"
    static let description = IntentDescription("Open a saved List in Planner.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var target: PlannerListEntity
    @Dependency private var plannerStore: SavedPlannerStore
    @Dependency private var planOpening: SavedPlanOpeningCoordinator

    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      _ = try await planOpening.submit(
        source: .init(kind: .list, id: target.id), store: plannerStore)
      return .result(
        dialog:
          "Opening requested. If Planner has an edited Item, choose Save, Discard or Keep editing.")
    }
  }

  struct OpenPlannerItineraryIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Itinerary"
    static let description = IntentDescription("Open a saved Itinerary in Planner.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var target: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    @Dependency private var planOpening: SavedPlanOpeningCoordinator

    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      _ = try await planOpening.submit(
        source: .init(kind: .itinerary, id: target.id), store: plannerStore)
      return .result(
        dialog:
          "Opening requested. If Planner has an edited Item, choose Save, Discard or Keep editing.")
    }
  }
#endif
