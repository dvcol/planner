#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerItemEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")
    static var defaultQuery: PlannerItemEntityQuery { PlannerItemEntityQuery() }
    let id: UUID
    @Property(title: "Title") var title: String
    @Property(title: "Completed everywhere") var done: Bool
    @Property(title: "Archived") var archived: Bool
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    init(id: UUID, title: String, done: Bool, archived: Bool) {
      self.id = id
      self.title = title
      self.done = done
      self.archived = archived
    }

    init(source: PlannerItemSourceRead) throws {
      guard let done = source.state.globalDone, let archived = source.state.archived else {
        throw PlannerIntentFailure(message: "Planner could not read this Item's state.")
      }
      self.init(id: source.source.id, title: source.content.title, done: done, archived: archived)
    }

    init(row: PlannerRowRead) throws {
      guard case .source(let source) = row.identity, source.kind == .item,
        let done = row.globalDone, let archived = row.archived
      else { throw PlannerIntentFailure(message: "Planner could not read its Item choices.") }
      self.init(id: source.id, title: row.title, done: done, archived: archived)
    }
  }

  struct PlannerItemEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore
    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerItemEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<UUID> = []
      var entities: [PlannerItemEntity] = []
      for identifier in identifiers where seenIdentifiers.insert(identifier).inserted {
        try Task.checkCancellation()
        switch await planner.read(
          session: session, request: .source(.init(kind: .item, id: identifier)))
        {
        case .source(.item(let source)): entities.append(try PlannerItemEntity(source: source))
        case .failed(let reason) where reason.code == "missingReference": continue
        case .failed(let reason): throw PlannerIntentFailure(message: reason.message)
        default: throw PlannerIntentFailure(message: "Planner could not resolve this Item.")
        }
      }
      return entities
    }
    @MainActor func entities(matching string: String) async throws -> [PlannerItemEntity] {
      try await loadItems(matching: string)
    }
    @MainActor func suggestedEntities() async throws -> [PlannerItemEntity] {
      try await loadItems(matching: "")
    }

    @MainActor private func loadItems(matching text: String) async throws -> [PlannerItemEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(
        .init(
          session: session,
          request: .items(.init(text: text, completion: .all, archive: .all))))
      {
      case .snapshot(let current): snapshot = current
      case .failed(let reason): throw PlannerIntentFailure(message: reason.message)
      }
      var entities: [PlannerItemEntity] = []
      var offset: Int64 = 0
      while offset < snapshot.matchingCount {
        try Task.checkCancellation()
        switch await planner.read(
          session: session,
          request: .rows(generation: snapshot.generation, offset: offset, limit: 64))
        {
        case .rows(let window):
          guard !window.rows.isEmpty else {
            throw PlannerIntentFailure(message: "Planner could not load all matching Item choices.")
          }
          entities.append(contentsOf: try window.rows.map(PlannerItemEntity.init(row:)))
          offset += Int64(window.rows.count)
        case .failed(let reason): throw PlannerIntentFailure(message: reason.message)
        default: throw PlannerIntentFailure(message: "Planner could not read its Item choices.")
        }
      }
      return entities
    }
  }

  struct CreatePlannerItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Item"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Title") var title: String
    @Parameter(title: "Notes") var notes: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerItemEntity, Never, Never, IntentDialog>
    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .createItem(content: .init(title: title, notes: notes)))
      switch result.outcome {
      case .rejected(let reason): throw PlannerIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(let applied, let recovery):
        guard let source = applied.generated.first(where: { $0.kind == .item }) else {
          throw PlannerIntentFailure(
            message:
              "Planner applied this change without returning its Item. Open Planner to inspect the result."
          )
        }
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Created \(title)."
        case .incomplete:
          dialog =
            "The Item was created on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(
          value: PlannerItemEntity(id: source.id, title: title, done: false, archived: false),
          dialog: dialog)
      }
    }
  }

  struct GetPlannerItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Item"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerItemEntity, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      var query = PlannerItemEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [item.id])
      guard let current = matches.first else {
        throw PlannerIntentFailure(
          message: "This Item is no longer available in Planner's current data.")
      }
      return .result(value: current)
    }
  }

  struct SetPlannerItemCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item Done Everywhere"
    static let description = IntentDescription(
      "Complete or reopen the Item everywhere. Reopening reveals each List and Itinerary entry's retained completion."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Completed") var done: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .setCompletion(scope: .globalItem(itemId: item.id), done: done))
      switch result.outcome {
      case .rejected(let reason): throw PlannerIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          if done {
            dialog = "The Item is completed everywhere."
          } else {
            dialog = "Reopened the Item. Its entries keep their own completion."
          }
        case .incomplete:
          dialog =
            "The Item's completion changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct EditPlannerItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Item"
    static let description = IntentDescription(
      "Change the title or notes. Leave a field unset to keep it; empty notes clears them.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Title") var title: String?
    @Parameter(title: "Notes") var notes: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard title != nil || notes != nil else {
        throw PlannerIntentFailure(message: "Choose a title or notes to change.")
      }
      let (planner, session) = try await plannerStore.appIntentContext()
      let source: PlannerItemSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .item, id: item.id)))
      {
      case .source(.item(let current)): source = current
      case .failed(let reason): throw PlannerIntentFailure(message: reason.message)
      default: throw PlannerIntentFailure(message: "Planner could not read this Item.")
      }
      let titleChange = title.map(PlannerFieldChange.set) ?? .unchanged
      let notesChange: PlannerFieldChange<String>
      if let notes {
        notesChange = notes.isEmpty ? .clear : .set(notes)
      } else {
        notesChange = .unchanged
      }
      let result = try await plannerStore.executeAppIntent(
        .editItem(
          sourceId: source.source.id, changes: .init(title: titleChange, notes: notesChange),
          expectedFieldHashes: source.fieldHashes))
      switch result.outcome {
      case .rejected(let reason): throw PlannerIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Updated the Item."
        case .incomplete:
          dialog =
            "The Item changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct SetPlannerItemArchiveIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item archive state"
    static let description = IntentDescription(
      "Archive or unarchive the shared Item without changing its completion or removing its entries."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Archived") var archived: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .setArchive(source: .init(kind: .item, id: item.id), archived: archived))
      switch result.outcome {
      case .rejected(let reason): throw PlannerIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          if archived {
            dialog = "Archived the Item. Its entries and completion are preserved."
          } else {
            dialog = "Unarchived the Item. Its entries and completion are preserved."
          }
        case .incomplete:
          dialog =
            "The Item's archive state changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  private struct PlannerIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }

#endif
