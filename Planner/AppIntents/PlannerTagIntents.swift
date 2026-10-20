#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerTagEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tag")
    static var defaultQuery: PlannerTagEntityQuery { PlannerTagEntityQuery() }
    let id: UUID
    @Property(title: "Name") var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: UUID, name: String) {
      self.id = id
      self.name = name
    }
  }

  struct PlannerTagEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore

    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerTagEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<UUID> = []
      var entities: [PlannerTagEntity] = []
      for identifier in identifiers where seenIdentifiers.insert(identifier).inserted {
        try Task.checkCancellation()
        switch await planner.read(
          session: session, request: .source(.init(kind: .tag, id: identifier)))
        {
        case .source(.tag(let source)):
          entities.append(.init(id: source.source.id, name: source.content.name))
        case .failed(let reason) where reason.code == "missingReference": continue
        case .failed(let reason): throw PlannerTagIntentFailure(message: reason.message)
        default: throw PlannerTagIntentFailure(message: "Planner could not resolve this Tag.")
        }
      }
      return entities
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerTagEntity] {
      try await loadTags(matching: string)
    }

    @MainActor func suggestedEntities() async throws -> [PlannerTagEntity] {
      try await loadTags(matching: "")
    }

    @MainActor private func loadTags(matching text: String) async throws -> [PlannerTagEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(
        .init(
          session: session,
          request: .catalog(.init(sourceKind: .tag, text: text, archive: .all))))
      {
      case .snapshot(let current): snapshot = current
      case .failed(let reason): throw PlannerTagIntentFailure(message: reason.message)
      }
      var entities: [PlannerTagEntity] = []
      var offset: Int64 = 0
      while offset < snapshot.matchingCount {
        try Task.checkCancellation()
        switch await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: offset, limit: 64))
        {
        case .rows(let window):
          guard !window.rows.isEmpty else {
            throw PlannerTagIntentFailure(message: "Planner could not load all matching Tags.")
          }
          for row in window.rows {
            guard case .source(let source) = row.identity, source.kind == .tag else {
              throw PlannerTagIntentFailure(message: "Planner could not read its Tag choices.")
            }
            entities.append(.init(id: source.id, name: row.title))
          }
          offset += Int64(window.rows.count)
        case .failed(let reason): throw PlannerTagIntentFailure(message: reason.message)
        default: throw PlannerTagIntentFailure(message: "Planner could not read its Tag choices.")
        }
      }
      return entities
    }
  }

  struct CreatePlannerTagIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Tag"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Name") var name: String
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerTagEntity, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(.createTag(content: .init(name: name)))
      switch result.outcome {
      case .rejected(let reason): throw PlannerTagIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerTagIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(let applied, let recovery):
        guard let source = applied.generated.first(where: { $0.kind == .tag }) else {
          throw PlannerTagIntentFailure(
            message:
              "Planner applied this change without returning its Tag. Open Planner to inspect the result."
          )
        }
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Created \(name)."
        case .incomplete:
          dialog =
            "The Tag was created on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(value: PlannerTagEntity(id: source.id, name: name), dialog: dialog)
      }
    }
  }

  struct GetPlannerTagIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Tag"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Tag") var tag: PlannerTagEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerTagEntity, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerTagEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [tag.id])
      guard let current = matches.first else {
        throw PlannerTagIntentFailure(
          message: "This Tag is no longer available in Planner's current data.")
      }
      return .result(value: current)
    }
  }

  struct RenamePlannerTagIntent: AppIntent {
    static let title: LocalizedStringResource = "Rename Tag"
    static let description = IntentDescription(
      "Rename the shared Tag while preserving its references, color and icon.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Tag") var tag: PlannerTagEntity
    @Parameter(title: "New name") var name: String
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      let source: PlannerTagSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .tag, id: tag.id)))
      {
      case .source(.tag(let current)): source = current
      case .failed(let reason): throw PlannerTagIntentFailure(message: reason.message)
      default: throw PlannerTagIntentFailure(message: "Planner could not read this Tag.")
      }
      let result = try await plannerStore.executeAppIntent(
        .editTag(
          sourceId: source.source.id, changes: .init(name: .set(name)),
          expectedFieldHashes: source.fieldHashes))
      switch result.outcome {
      case .rejected(let reason): throw PlannerTagIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerTagIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Renamed the shared Tag. Its references are preserved."
        case .incomplete:
          dialog =
            "The Tag was renamed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  private struct PlannerTagIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
