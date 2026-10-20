#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerCategoryEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")
    static var defaultQuery: PlannerCategoryEntityQuery { PlannerCategoryEntityQuery() }
    let id: UUID
    @Property(title: "Name") var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: UUID, name: String) {
      self.id = id
      self.name = name
    }
  }

  struct PlannerCategoryEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore

    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerCategoryEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<UUID> = []
      var entities: [PlannerCategoryEntity] = []
      for identifier in identifiers where seenIdentifiers.insert(identifier).inserted {
        try Task.checkCancellation()
        switch await planner.read(
          session: session, request: .source(.init(kind: .category, id: identifier)))
        {
        case .source(.category(let source)):
          entities.append(.init(id: source.source.id, name: source.content.name))
        case .failed(let reason) where reason.code == "missingReference": continue
        case .failed(let reason): throw PlannerCategoryIntentFailure(message: reason.message)
        default:
          throw PlannerCategoryIntentFailure(message: "Planner could not resolve this Category.")
        }
      }
      return entities
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerCategoryEntity] {
      try await loadCategories(matching: string)
    }

    @MainActor func suggestedEntities() async throws -> [PlannerCategoryEntity] {
      try await loadCategories(matching: "")
    }

    @MainActor private func loadCategories(matching text: String) async throws
      -> [PlannerCategoryEntity]
    {
      let (planner, session) = try await plannerStore.appIntentContext()
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(
        .init(
          session: session,
          request: .catalog(.init(sourceKind: .category, text: text, archive: .all))))
      {
      case .snapshot(let current): snapshot = current
      case .failed(let reason): throw PlannerCategoryIntentFailure(message: reason.message)
      }
      var entities: [PlannerCategoryEntity] = []
      var offset: Int64 = 0
      while offset < snapshot.matchingCount {
        try Task.checkCancellation()
        switch await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: offset, limit: 64))
        {
        case .rows(let window):
          guard !window.rows.isEmpty else {
            throw PlannerCategoryIntentFailure(
              message: "Planner could not load all matching Categories.")
          }
          for row in window.rows {
            guard case .source(let source) = row.identity, source.kind == .category else {
              throw PlannerCategoryIntentFailure(
                message: "Planner could not read its Category choices.")
            }
            entities.append(.init(id: source.id, name: row.title))
          }
          offset += Int64(window.rows.count)
        case .failed(let reason): throw PlannerCategoryIntentFailure(message: reason.message)
        default:
          throw PlannerCategoryIntentFailure(
            message: "Planner could not read its Category choices.")
        }
      }
      return entities
    }
  }

  struct CreatePlannerCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Category"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Name") var name: String
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<
      PlannerCategoryEntity, Never, Never, IntentDialog
    >

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .createCategory(content: .init(name: name)))
      switch result.outcome {
      case .rejected(let reason): throw PlannerCategoryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerCategoryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(let applied, let recovery):
        guard let source = applied.generated.first(where: { $0.kind == .category }) else {
          throw PlannerCategoryIntentFailure(
            message:
              "Planner applied this change without returning its Category. Open Planner to inspect the result."
          )
        }
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Created \(name)."
        case .incomplete:
          dialog =
            "The Category was created on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(value: PlannerCategoryEntity(id: source.id, name: name), dialog: dialog)
      }
    }
  }

  struct GetPlannerCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Category"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Category") var category: PlannerCategoryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerCategoryEntity, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerCategoryEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [category.id])
      guard let current = matches.first else {
        throw PlannerCategoryIntentFailure(
          message: "This Category is no longer available in Planner's current data.")
      }
      return .result(value: current)
    }
  }

  struct RenamePlannerCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Rename Category"
    static let description = IntentDescription(
      "Rename the shared Category while preserving its references, color and icon.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Category") var category: PlannerCategoryEntity
    @Parameter(title: "New name") var name: String
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      let source: PlannerCategorySourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .category, id: category.id)))
      {
      case .source(.category(let current)): source = current
      case .failed(let reason): throw PlannerCategoryIntentFailure(message: reason.message)
      default:
        throw PlannerCategoryIntentFailure(message: "Planner could not read this Category.")
      }
      let result = try await plannerStore.executeAppIntent(
        .editCategory(
          sourceId: source.source.id, changes: .init(name: .set(name)),
          expectedFieldHashes: source.fieldHashes))
      switch result.outcome {
      case .rejected(let reason): throw PlannerCategoryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerCategoryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Renamed the shared Category. Its references are preserved."
        case .incomplete:
          dialog =
            "The Category was renamed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  private struct PlannerCategoryIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
