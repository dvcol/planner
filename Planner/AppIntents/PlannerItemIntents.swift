#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import GeoToolbox
  import PlannerCore

  struct PlannerItemEntity: PlannerLibraryBoundEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")
    static var defaultQuery: PlannerItemEntityQuery { PlannerItemEntityQuery() }
    let recordIdentifier: UUID
    var libraryBinding: String
    @Property(title: "Title") var title: String
    @Property(title: "Completed everywhere") var done: Bool
    @Property(title: "Archived") var archived: Bool
    @DeferredProperty(title: "Notes")
    var notes: String? {
      get async throws {
        try await readPlannerDeferredItemSource(identifier: id).content.notes
      }
    }
    @DeferredProperty(title: "Subtitle")
    var subtitle: String? {
      get async throws {
        try await readPlannerDeferredItemSource(identifier: id).content.subtitle
      }
    }
    @DeferredProperty(title: "Location name")
    var locationName: String? {
      get async throws {
        try await readPlannerDeferredItemSource(identifier: id).content.location?.displayName
      }
    }
    @DeferredProperty(title: "Address")
    var address: String? {
      get async throws {
        try await readPlannerDeferredItemSource(identifier: id).content.location?.formattedAddress
      }
    }
    @DeferredProperty(title: "Pin")
    var pin: PlaceDescriptor? {
      get async throws {
        try await plannerDeferredPin(readPlannerDeferredItemSource(identifier: id).content.location)
      }
    }
    @DeferredProperty(title: "Created")
    var created: Date {
      get async throws {
        try await readPlannerDeferredItemSource(identifier: id).createdAt
      }
    }
    @DeferredProperty(title: "Last updated")
    var lastUpdated: Date {
      get async throws {
        try await readPlannerDeferredItemSource(identifier: id).updatedAt
      }
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    @MainActor init(
      id: UUID, title: String, done: Bool, archived: Bool, libraryBinding: String = ""
    ) {
      self.recordIdentifier = id
      self.libraryBinding = libraryBinding
      self.title = title
      self.done = done
      self.archived = archived
    }

    @MainActor init(source: PlannerItemSourceRead, libraryBinding: String = "") throws {
      guard let done = source.state.globalDone, let archived = source.state.archived else {
        throw PlannerIntentFailure(message: "Planner could not read this Item's state.")
      }
      self.init(
        id: source.source.id, title: source.content.title, done: done, archived: archived,
        libraryBinding: libraryBinding)
    }

    @MainActor init(row: PlannerRowRead, libraryBinding: String = "") throws {
      guard case .source(let source) = row.identity, source.kind == .item,
        let done = row.globalDone, let archived = row.archived
      else { throw PlannerIntentFailure(message: "Planner could not read its Item choices.") }
      self.init(
        id: source.id, title: row.title, done: done, archived: archived,
        libraryBinding: libraryBinding)
    }
  }

  struct PlannerItemEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore
    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerItemEntity] {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let binding = plannerStore.appIntentLibraryBinding ?? "unavailable"
      return try await entities(
        for: identifiers.map { plannerEncodeIntentIdentifier($0.uuidString, binding: binding) })
    }

    @MainActor func entities(for identifiers: [String]) async throws -> [PlannerItemEntity] {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      try Task.checkCancellation()
      let (planner, session) = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<String> = []
      var entities: [PlannerItemEntity] = []
      for encoded in identifiers where seenIdentifiers.insert(encoded).inserted {
        let raw = try plannerResolveIntentIdentifier(encoded, store: plannerStore)
        guard let identifier = UUID(uuidString: raw) else { continue }
        try Task.checkCancellation()
        switch await planner.read(
          session: session, request: .source(.init(kind: .item, id: identifier)))
        {
        case .source(.item(let source)):
          entities.append(
            try PlannerItemEntity(
              source: source,
              libraryBinding: SavedPlannerStore.intentLibraryBinding(session: session)))
        case .failed(let reason) where reason.code == "missingReference": continue
        case .failed(let reason): throw PlannerIntentFailure(message: reason.message)
        default: throw PlannerIntentFailure(message: "Planner could not resolve this Item.")
        }
      }
      return entities
    }
    @MainActor func entities(matching string: String) async throws -> [PlannerItemEntity] {
      try await loadItems(query: .init(text: string, completion: .all, archive: .all))
    }
    @MainActor func suggestedEntities() async throws -> [PlannerItemEntity] {
      try await loadItems(query: .init(completion: .all, archive: .all))
    }

    @MainActor func loadItems(query: PlannerItemQuery) async throws -> [PlannerItemEntity] {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      try Task.checkCancellation()
      let (planner, session) = try await plannerStore.appIntentContext()
      let capture: SavedQueryCapture
      switch await planner.queryForNativeUse(.init(session: session, request: .items(query)))
      {
      case .success(let current): capture = current
      case .failure(let reason): throw PlannerIntentFailure(message: reason.message)
      }
      let snapshot = capture.snapshot
      defer { withExtendedLifetime(capture) {} }
      try Task.checkCancellation()
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
          entities.append(
            contentsOf: try window.rows.map {
              try PlannerItemEntity(
                row: $0, libraryBinding: SavedPlannerStore.intentLibraryBinding(session: session))
            })
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
    @Parameter(title: "Subtitle") var subtitle: String?
    @Parameter(title: "Notes") var notes: String?
    @Parameter(title: "List") var list: PlannerListEntity?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerItemEntity, Never, Never, IntentDialog>
    @MainActor func perform() async throws -> PerformResult {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundListIdentifier = try list?.sourceIdentifier(in: plannerStore)
      let result = try await plannerStore.executeAppIntent(
        .createItem(
          content: .init(title: title, subtitle: subtitle, notes: notes),
          listId: boundListIdentifier))
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
          value: PlannerItemEntity(
            id: source.id, title: title, done: false, archived: false,
            libraryBinding: plannerStore.appIntentLibraryBinding ?? "unavailable"),
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
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundItemIdentifier = try item.sourceIdentifier(in: plannerStore)
      let query = PlannerItemEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [boundItemIdentifier])
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
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundItemIdentifier = try item.sourceIdentifier(in: plannerStore)
      let result = try await plannerStore.executeAppIntent(
        .setCompletion(scope: .globalItem(itemId: boundItemIdentifier), done: done))
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
      "Change the title, subtitle or notes. Leave a field unset to keep it; empty subtitle or notes clears it."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Title") var title: String?
    @Parameter(title: "Subtitle") var subtitle: String?
    @Parameter(title: "Notes") var notes: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      let (planner, session) = try await plannerStore.appIntentContext()
      let boundItemIdentifier = try item.sourceIdentifier(in: plannerStore)
      guard title != nil || subtitle != nil || notes != nil else {
        throw PlannerIntentFailure(message: "Choose a title, subtitle or notes to change.")
      }
      let source: PlannerItemSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .item, id: boundItemIdentifier)))
      {
      case .source(.item(let current)): source = current
      case .failed(let reason): throw PlannerIntentFailure(message: reason.message)
      default: throw PlannerIntentFailure(message: "Planner could not read this Item.")
      }
      let titleChange = title.map(PlannerFieldChange.set) ?? .unchanged
      let subtitleChange: PlannerFieldChange<String>
      if let subtitle {
        subtitleChange = subtitle.isEmpty ? .clear : .set(subtitle)
      } else {
        subtitleChange = .unchanged
      }
      let notesChange: PlannerFieldChange<String>
      if let notes {
        notesChange = notes.isEmpty ? .clear : .set(notes)
      } else {
        notesChange = .unchanged
      }
      let result = try await plannerStore.executeAppIntent(
        .editItem(
          sourceId: source.source.id,
          changes: .init(title: titleChange, subtitle: subtitleChange, notes: notesChange),
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
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundItemIdentifier = try item.sourceIdentifier(in: plannerStore)
      let result = try await plannerStore.executeAppIntent(
        .setArchive(source: .init(kind: .item, id: boundItemIdentifier), archived: archived)
      )
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
