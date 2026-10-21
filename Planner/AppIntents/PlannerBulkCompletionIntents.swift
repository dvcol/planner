#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct SetPlannerListChildCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Set List child completion"
    static let description = IntentDescription(
      "Review and confirm completion for all Item appearances in this List, including hidden and archived children. Done everywhere stays unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var list: PlannerListEntity
    @Parameter(title: "Completed") var completed: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await performPlannerBulkCompletion(
        self, scope: .list(list.id), done: completed, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItineraryChildCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Itinerary child completion"
    static let description = IntentDescription(
      "Review and confirm completion for all Item appearances in this Itinerary, including hidden, archived and repeated children. Done everywhere stays unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Completed") var completed: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await performPlannerBulkCompletion(
        self, scope: .itinerary(itinerary.id), done: completed, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItineraryListChildCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Itinerary List-entry child completion"
    static let description = IntentDescription(
      "Review and confirm completion in one exact List stop. Other stops, the standalone List and Done everywhere stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "List entry", query: PlannerItineraryEntryEntityQuery())
    var entry: PlannerItineraryEntryEntity
    @Parameter(title: "Completed") var completed: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard let identity = PlannerItineraryEntryIdentity(entry.id),
        identity.itineraryIdentifier == itinerary.id, identity.kind == .list
      else {
        throw PlannerBulkIntentFailure(message: "Choose a List entry from the selected Itinerary.")
      }
      let dialog = try await performPlannerBulkCompletion(
        self, scope: .itineraryListEntry(identity), done: completed, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  private enum PlannerBulkIntentScope {
    case list(UUID)
    case itinerary(UUID)
    case itineraryListEntry(PlannerItineraryEntryIdentity)

    var coreScope: PlannerBulkScope {
      switch self {
      case .list(let identifier): .list(listId: identifier)
      case .itinerary(let identifier): .itinerary(itineraryId: identifier)
      case .itineraryListEntry(let identity):
        .itineraryListEntry(
          itineraryId: identity.itineraryIdentifier, listEntryId: identity.entryIdentifier)
      }
    }
  }

  @MainActor
  private func performPlannerBulkCompletion<Intent: AppIntent>(
    _ intent: Intent, scope: PlannerBulkIntentScope, done: Bool, store: SavedPlannerStore
  ) async throws -> IntentDialog {
    while true {
      let name = try await plannerBulkScopeName(scope, store: store)
      let review = try await store.prepareAppIntentBulkCompletion(
        scope: scope.coreScope, done: done)
      try Task.checkCancellation()
      let acceptLabel: LocalizedStringResource = done ? "Mark done" : "Mark undone"
      let confirmation: IntentDialog =
        "Set completion in \(name) for all \(review.targetCount) Item appearances, including hidden and archived children? Done everywhere stays unchanged."
      try await intent.requestConfirmation(
        actionName: .custom(
          acceptLabel: acceptLabel, acceptAlternatives: [],
          denyLabel: "Cancel", denyAlternatives: [], destructive: false),
        dialog: confirmation)
      try Task.checkCancellation()
      let result = try await store.executeAppIntent(review.command, reviewToken: review.reviewToken)
      switch result.outcome {
      case .rejected(let reason) where reason.code == "staleReview": continue
      case .rejected(let reason): throw PlannerBulkIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerBulkIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, .incomplete):
        return
          "Completion changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      case .applied(_, .complete):
        if review.targetCount == 0 { return "No items. No completion flags changed." }
        return
          "Updated completion for \(review.targetCount) Item appearances in \(name). Done everywhere is unchanged."
      }
    }
  }

  @MainActor
  private func plannerBulkScopeName(_ scope: PlannerBulkIntentScope, store: SavedPlannerStore)
    async throws -> String
  {
    let (planner, session) = try await store.appIntentContext()
    switch scope {
    case .list(let identifier):
      switch await planner.read(
        session: session, request: .source(.init(kind: .list, id: identifier)))
      {
      case .source(.list(let source)): return source.content.name
      case .failed(let reason): throw PlannerBulkIntentFailure(message: reason.message)
      default: throw PlannerBulkIntentFailure(message: "Planner could not read this List.")
      }
    case .itinerary(let identifier):
      switch await planner.read(
        session: session, request: .source(.init(kind: .itinerary, id: identifier)))
      {
      case .source(.itinerary(let source)): return source.content.title
      case .failed(let reason): throw PlannerBulkIntentFailure(message: reason.message)
      default: throw PlannerBulkIntentFailure(message: "Planner could not read this Itinerary.")
      }
    case .itineraryListEntry(let identity):
      let query = PlannerItineraryEntryEntityQuery()
      query.plannerStore = store
      let entries = try await query.entities(for: [identity.id])
      guard let entry = entries.first, entry.kind == .list else {
        throw PlannerBulkIntentFailure(
          message: "This List entry no longer belongs to the selected Itinerary.")
      }
      return "\(entry.title) · \(entry.context)"
    }
  }

  private struct PlannerBulkIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
