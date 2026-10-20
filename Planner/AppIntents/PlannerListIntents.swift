#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerListEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "List")
    static var defaultQuery: PlannerListEntityQuery { PlannerListEntityQuery() }
    let id: UUID
    @Property(title: "Name") var name: String
    @Property(title: "Archived") var archived: Bool
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: UUID, name: String, archived: Bool) {
      self.id = id
      self.name = name
      self.archived = archived
    }
  }

  struct PlannerListEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore

    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerListEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<UUID> = []
      var entities: [PlannerListEntity] = []
      for identifier in identifiers where seenIdentifiers.insert(identifier).inserted {
        try Task.checkCancellation()
        switch await planner.read(
          session: session, request: .source(.init(kind: .list, id: identifier)))
        {
        case .source(.list(let source)):
          guard let archived = source.state.archived else {
            throw PlannerListIntentFailure(message: "Planner could not read this List's state.")
          }
          entities.append(
            .init(id: source.source.id, name: source.content.name, archived: archived))
        case .failed(let reason) where reason.code == "missingReference": continue
        case .failed(let reason): throw PlannerListIntentFailure(message: reason.message)
        default: throw PlannerListIntentFailure(message: "Planner could not resolve this List.")
        }
      }
      return entities
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerListEntity] {
      try await loadLists(matching: string)
    }

    @MainActor func suggestedEntities() async throws -> [PlannerListEntity] {
      try await loadLists(matching: "")
    }

    @MainActor private func loadLists(matching text: String) async throws -> [PlannerListEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(
        .init(
          session: session,
          request: .catalog(.init(sourceKind: .list, text: text, archive: .all))))
      {
      case .snapshot(let current): snapshot = current
      case .failed(let reason): throw PlannerListIntentFailure(message: reason.message)
      }
      var entities: [PlannerListEntity] = []
      var offset: Int64 = 0
      while offset < snapshot.matchingCount {
        try Task.checkCancellation()
        switch await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: offset, limit: 64))
        {
        case .rows(let window):
          guard !window.rows.isEmpty else {
            throw PlannerListIntentFailure(message: "Planner could not load all matching Lists.")
          }
          for row in window.rows {
            guard case .source(let source) = row.identity, source.kind == .list,
              let archived = row.archived
            else {
              throw PlannerListIntentFailure(message: "Planner could not read its List choices.")
            }
            entities.append(.init(id: source.id, name: row.title, archived: archived))
          }
          offset += Int64(window.rows.count)
        case .failed(let reason): throw PlannerListIntentFailure(message: reason.message)
        default: throw PlannerListIntentFailure(message: "Planner could not read its List choices.")
        }
      }
      return entities
    }
  }

  struct CreatePlannerListIntent: AppIntent {
    static let title: LocalizedStringResource = "Create List"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Name") var name: String
    @Parameter(title: "Notes") var notes: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerListEntity, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .createList(content: .init(name: name, notes: notes)))
      switch result.outcome {
      case .rejected(let reason): throw PlannerListIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerListIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(let applied, let recovery):
        guard let source = applied.generated.first(where: { $0.kind == .list }) else {
          throw PlannerListIntentFailure(
            message:
              "Planner applied this change without returning its List. Open Planner to inspect the result."
          )
        }
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Created \(name)."
        case .incomplete:
          dialog =
            "The List was created on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(
          value: PlannerListEntity(id: source.id, name: name, archived: false), dialog: dialog)
      }
    }
  }

  struct GetPlannerListIntent: AppIntent {
    static let title: LocalizedStringResource = "Get List"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var list: PlannerListEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerListEntity, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerListEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [list.id])
      guard let current = matches.first else {
        throw PlannerListIntentFailure(
          message: "This List is no longer available in Planner's current data.")
      }
      return .result(value: current)
    }
  }

  struct AddPlannerItemToListIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Item to List"
    static let description = IntentDescription(
      "Reference the shared Item in this List. An existing entry keeps its order and completion.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "List") var list: PlannerListEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .addMembership(itemId: item.id, listId: list.id, placement: .last))
      switch result.outcome {
      case .rejected(let reason): throw PlannerListIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerListIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "The Item is in this List. Its other entries are preserved."
        case .incomplete:
          dialog =
            "The List change applied on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  private struct PlannerListIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
