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

  struct EditPlannerListIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit List"
    static let description = IntentDescription(
      "Change the name or notes. Leave a field unset to keep it; empty notes clears them.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var list: PlannerListEntity
    @Parameter(title: "Name") var name: String?
    @Parameter(title: "Notes") var notes: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard name != nil || notes != nil else {
        throw PlannerListIntentFailure(message: "Choose a name or notes to change.")
      }
      let (planner, session) = try await plannerStore.appIntentContext()
      let source: PlannerListSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
      {
      case .source(.list(let current)): source = current
      case .failed(let reason): throw PlannerListIntentFailure(message: reason.message)
      default: throw PlannerListIntentFailure(message: "Planner could not read this List.")
      }
      let nameChange = name.map(PlannerFieldChange.set) ?? .unchanged
      let notesChange: PlannerFieldChange<String>
      if let notes {
        notesChange = notes.isEmpty ? .clear : .set(notes)
      } else {
        notesChange = .unchanged
      }
      let result = try await plannerStore.executeAppIntent(
        .editList(
          sourceId: source.source.id, changes: .init(name: nameChange, notes: notesChange),
          expectedFieldHashes: source.fieldHashes))
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
        case .complete: dialog = "Updated the List. Its entries are preserved."
        case .incomplete:
          dialog =
            "The List changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct SetPlannerListArchiveIntent: AppIntent {
    static let title: LocalizedStringResource = "Set List archive state"
    static let description = IntentDescription(
      "Archive or unarchive the List while preserving its Items and saved entry completion.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var list: PlannerListEntity
    @Parameter(title: "Archived") var archived: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(
        .setArchive(source: .init(kind: .list, id: list.id), archived: archived))
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
        case .complete:
          if archived {
            dialog = "Archived the List. Its Items and entry completion are preserved."
          } else {
            dialog = "Unarchived the List. Its Items and entry completion are preserved."
          }
        case .incomplete:
          dialog =
            "The List's archive state changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct RemovePlannerItemFromListIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Item from List"
    static let description = IntentDescription(
      "Remove only this List membership. Keep the shared Item and its other references.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "List") var list: PlannerListEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      let current: PlannerListSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
      {
      case .source(.list(let source)): current = source
      case .failed(let reason): throw PlannerListIntentFailure(message: reason.message)
      default: throw PlannerListIntentFailure(message: "Planner could not read this List.")
      }
      let membership = current.references.first { reference in
        guard case .membership(_, let owner, let source) = reference else { return false }
        return owner == .init(kind: .list, id: list.id) && source == .init(kind: .item, id: item.id)
      }
      guard case .membership(let identifier, _, _)? = membership else {
        throw PlannerListIntentFailure(message: "This Item no longer belongs to the selected List.")
      }
      let result = try await plannerStore.executeAppIntent(
        .removeMembership(listId: list.id, membershipId: identifier))
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
        case .complete:
          dialog =
            "Removed the Item from this List. Its shared content and other references are preserved."
        case .incomplete:
          dialog =
            "The membership was removed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct MovePlannerItemBetweenListsIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Item between Lists"
    static let description = IntentDescription(
      "Move only the selected membership. Keep an existing destination entry's order and completion."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "From List") var sourceList: PlannerListEntity
    @Parameter(title: "To List") var destinationList: PlannerListEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      let current: PlannerListSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .list, id: sourceList.id)))
      {
      case .source(.list(let source)): current = source
      case .failed(let reason): throw PlannerListIntentFailure(message: reason.message)
      default: throw PlannerListIntentFailure(message: "Planner could not read the source List.")
      }
      let membership = current.references.first { reference in
        guard case .membership(_, let owner, let source) = reference else { return false }
        return owner == .init(kind: .list, id: sourceList.id)
          && source == .init(kind: .item, id: item.id)
      }
      guard case .membership(let identifier, _, _)? = membership else {
        throw PlannerListIntentFailure(message: "This Item no longer belongs to the source List.")
      }
      let result = try await plannerStore.executeAppIntent(
        .moveMembership(
          listId: sourceList.id, membershipId: identifier,
          destinationListId: destinationList.id, placement: .last))
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
        case .complete:
          dialog = "Moved the Item. Its shared content and other memberships are preserved."
        case .incomplete:
          dialog =
            "The Move applied on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct SetPlannerItemListCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item completion in List"
    static let description = IntentDescription(
      "Change only this List entry's completion. Globally Done Items still appear Done.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "List") var list: PlannerListEntity
    @Parameter(title: "Completed in List") var done: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      let current: PlannerListSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .list, id: list.id)))
      {
      case .source(.list(let source)): current = source
      case .failed(let reason): throw PlannerListIntentFailure(message: reason.message)
      default: throw PlannerListIntentFailure(message: "Planner could not read this List.")
      }
      let membership = current.references.first { reference in
        guard case .membership(_, let owner, let source) = reference else { return false }
        return owner == .init(kind: .list, id: list.id) && source == .init(kind: .item, id: item.id)
      }
      guard case .membership(let identifier, _, _)? = membership else {
        throw PlannerListIntentFailure(message: "This Item no longer belongs to the selected List.")
      }
      let result = try await plannerStore.executeAppIntent(
        .setCompletion(
          scope: .appearance(.listMembership(listId: list.id, membershipId: identifier)), done: done
        ))
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
        case .complete:
          if done {
            dialog =
              "Marked the Item Done in this List. Other entries and global completion are unchanged."
          } else {
            dialog = "Cleared this List entry's completion. Globally Done Items still appear Done."
          }
        case .incomplete:
          dialog =
            "This List entry's completion changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
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
