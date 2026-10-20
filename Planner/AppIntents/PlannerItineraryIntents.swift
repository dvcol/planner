#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerItineraryEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Itinerary")
    static var defaultQuery: PlannerItineraryEntityQuery { PlannerItineraryEntityQuery() }
    let id: UUID
    @Property(title: "Title") var title: String
    @Property(title: "Archived") var archived: Bool
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    init(id: UUID, title: String, archived: Bool) {
      self.id = id
      self.title = title
      self.archived = archived
    }
  }

  struct PlannerItineraryEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore

    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerItineraryEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<UUID> = []
      var entities: [PlannerItineraryEntity] = []
      for identifier in identifiers where seenIdentifiers.insert(identifier).inserted {
        try Task.checkCancellation()
        switch await planner.read(
          session: session, request: .source(.init(kind: .itinerary, id: identifier)))
        {
        case .source(.itinerary(let source)):
          guard let archived = source.state.archived else {
            throw PlannerItineraryIntentFailure(
              message: "Planner could not read this Itinerary's state.")
          }
          entities.append(
            .init(id: source.source.id, title: source.content.title, archived: archived))
        case .failed(let reason) where reason.code == "missingReference": continue
        case .failed(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
        default:
          throw PlannerItineraryIntentFailure(message: "Planner could not resolve this Itinerary.")
        }
      }
      return entities
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerItineraryEntity] {
      try await loadItineraries(matching: string)
    }

    @MainActor func suggestedEntities() async throws -> [PlannerItineraryEntity] {
      try await loadItineraries(matching: "")
    }

    @MainActor private func loadItineraries(matching text: String) async throws
      -> [PlannerItineraryEntity]
    {
      let (planner, session) = try await plannerStore.appIntentContext()
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(
        .init(
          session: session,
          request: .catalog(.init(sourceKind: .itinerary, text: text, archive: .all))))
      {
      case .snapshot(let current): snapshot = current
      case .failed(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      }
      var entities: [PlannerItineraryEntity] = []
      var offset: Int64 = 0
      while offset < snapshot.matchingCount {
        try Task.checkCancellation()
        switch await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: offset, limit: 64))
        {
        case .rows(let window):
          guard !window.rows.isEmpty else {
            throw PlannerItineraryIntentFailure(
              message: "Planner could not load all matching Itineraries.")
          }
          for row in window.rows {
            guard case .source(let source) = row.identity, source.kind == .itinerary,
              let archived = row.archived
            else {
              throw PlannerItineraryIntentFailure(
                message: "Planner could not read its Itinerary choices.")
            }
            entities.append(.init(id: source.id, title: row.title, archived: archived))
          }
          offset += Int64(window.rows.count)
        case .failed(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
        default:
          throw PlannerItineraryIntentFailure(
            message: "Planner could not read its Itinerary choices.")
        }
      }
      return entities
    }
  }

  struct CreatePlannerItineraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Itinerary"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Title") var title: String
    @Parameter(title: "Notes") var notes: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<
      PlannerItineraryEntity, Never, Never, IntentDialog
    >

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .createItinerary(content: .init(title: title, notes: notes)))
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(let applied, let recovery):
        guard let source = applied.generated.first(where: { $0.kind == .itinerary }) else {
          throw PlannerItineraryIntentFailure(
            message:
              "Planner applied this change without returning its Itinerary. Open Planner to inspect the result."
          )
        }
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Created \(title)."
        case .incomplete:
          dialog =
            "The Itinerary was created on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(
          value: PlannerItineraryEntity(id: source.id, title: title, archived: false),
          dialog: dialog)
      }
    }
  }

  struct GetPlannerItineraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Itinerary"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerItineraryEntity, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerItineraryEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [itinerary.id])
      guard let current = matches.first else {
        throw PlannerItineraryIntentFailure(
          message: "This Itinerary is no longer available in Planner's current data.")
      }
      return .result(value: current)
    }
  }

  private struct PlannerItineraryIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
