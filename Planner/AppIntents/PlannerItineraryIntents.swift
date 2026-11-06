#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import GeoToolbox
  import PlannerCore

  struct PlannerItineraryEntity: PlannerLibraryBoundEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Itinerary")
    static var defaultQuery: PlannerItineraryEntityQuery { PlannerItineraryEntityQuery() }
    let recordIdentifier: UUID
    var libraryBinding: String
    @Property(title: "Title") var title: String
    @Property(title: "Archived") var archived: Bool
    @DeferredProperty(title: "Notes")
    var notes: String? {
      get async throws {
        try await readPlannerDeferredItinerarySource(identifier: id).content.notes
      }
    }
    @DeferredProperty(title: "Location name")
    var locationName: String? {
      get async throws {
        try await readPlannerDeferredItinerarySource(identifier: id).content.location?.displayName
      }
    }
    @DeferredProperty(title: "Address")
    var address: String? {
      get async throws {
        try await readPlannerDeferredItinerarySource(identifier: id).content.location?
          .formattedAddress
      }
    }
    @DeferredProperty(title: "Pin")
    var pin: PlaceDescriptor? {
      get async throws {
        try await plannerDeferredPin(
          readPlannerDeferredItinerarySource(identifier: id).content.location)
      }
    }
    @DeferredProperty(title: "Created")
    var created: Date {
      get async throws {
        try await readPlannerDeferredItinerarySource(identifier: id).createdAt
      }
    }
    @DeferredProperty(title: "Last updated")
    var lastUpdated: Date {
      get async throws {
        try await readPlannerDeferredItinerarySource(identifier: id).updatedAt
      }
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    @MainActor init(id: UUID, title: String, archived: Bool, libraryBinding: String = "") {
      self.recordIdentifier = id
      self.libraryBinding = libraryBinding
      self.title = title
      self.archived = archived
    }
  }

  struct PlannerItineraryEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore

    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerItineraryEntity] {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let binding = plannerStore.appIntentLibraryBinding ?? "unavailable"
      return try await entities(
        for: identifiers.map { plannerEncodeIntentIdentifier($0.uuidString, binding: binding) })
    }

    @MainActor func entities(for identifiers: [String]) async throws -> [PlannerItineraryEntity] {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      let (planner, session) = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<String> = []
      var entities: [PlannerItineraryEntity] = []
      for encoded in identifiers where seenIdentifiers.insert(encoded).inserted {
        let raw = try plannerResolveIntentIdentifier(encoded, store: plannerStore)
        guard let identifier = UUID(uuidString: raw) else { continue }
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
            .init(
              id: source.source.id, title: source.content.title, archived: archived,
              libraryBinding: SavedPlannerStore.intentLibraryBinding(session: session)))
        case .failed(let reason) where reason.code == "missingReference": continue
        case .failed(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
        default:
          throw PlannerItineraryIntentFailure(message: "Planner could not resolve this Itinerary.")
        }
      }
      return entities
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerItineraryEntity] {
      try await loadItineraries(query: .init(sourceKind: .itinerary, text: string, archive: .all))
    }

    @MainActor func suggestedEntities() async throws -> [PlannerItineraryEntity] {
      try await loadItineraries(query: .init(sourceKind: .itinerary, archive: .all))
    }

    @MainActor func loadItineraries(query: PlannerCatalogQuery) async throws
      -> [PlannerItineraryEntity]
    {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      let (planner, session) = try await plannerStore.appIntentContext()
      let capture: SavedQueryCapture
      switch await planner.queryForNativeUse(
        .init(session: session, request: .catalog(query)))
      {
      case .success(let current): capture = current
      case .failure(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      }
      let snapshot = capture.snapshot
      defer { withExtendedLifetime(capture) {} }
      try Task.checkCancellation()
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
            entities.append(
              .init(
                id: source.id, title: row.title, archived: archived,
                libraryBinding: SavedPlannerStore.intentLibraryBinding(session: session)))
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
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
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
          value: PlannerItineraryEntity(
            id: source.id, title: title, archived: false,
            libraryBinding: plannerStore.appIntentLibraryBinding ?? "unavailable"),
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
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundItineraryIdentifier = try itinerary.sourceIdentifier(in: plannerStore)
      let query = PlannerItineraryEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [boundItineraryIdentifier])
      guard let current = matches.first else {
        throw PlannerItineraryIntentFailure(
          message: "This Itinerary is no longer available in Planner's current data.")
      }
      return .result(value: current)
    }
  }

  struct EditPlannerItineraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Itinerary"
    static let description = IntentDescription(
      "Change the title or notes. Leave a field unset to keep it; empty notes clears them.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Title") var title: String?
    @Parameter(title: "Notes") var notes: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      let (planner, session) = try await plannerStore.appIntentContext()
      let boundItineraryIdentifier = try itinerary.sourceIdentifier(in: plannerStore)
      guard title != nil || notes != nil else {
        throw PlannerItineraryIntentFailure(message: "Choose a title or notes to change.")
      }
      let source: PlannerItinerarySourceRead
      switch await planner.read(
        session: session,
        request: .source(.init(kind: .itinerary, id: boundItineraryIdentifier)))
      {
      case .source(.itinerary(let current)): source = current
      case .failed(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      default:
        throw PlannerItineraryIntentFailure(message: "Planner could not read this Itinerary.")
      }
      let titleChange = title.map(PlannerFieldChange.set) ?? .unchanged
      let notesChange: PlannerFieldChange<String>
      if let notes {
        notesChange = notes.isEmpty ? .clear : .set(notes)
      } else {
        notesChange = .unchanged
      }
      let result = try await plannerStore.executeAppIntent(
        .editItinerary(
          sourceId: source.source.id, changes: .init(title: titleChange, notes: notesChange),
          expectedFieldHashes: source.fieldHashes))
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Updated the Itinerary. Its entries are preserved."
        case .incomplete:
          dialog =
            "The Itinerary changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct SetPlannerItineraryArchiveIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Itinerary archive state"
    static let description = IntentDescription(
      "Archive or unarchive this Itinerary while preserving its shared Items, Lists and entry completion."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Archived") var archived: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundItineraryIdentifier = try itinerary.sourceIdentifier(in: plannerStore)
      let result = try await plannerStore.executeAppIntent(
        .setArchive(
          source: .init(kind: .itinerary, id: boundItineraryIdentifier), archived: archived)
      )
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          if archived {
            dialog = "Archived the Itinerary. Its entries and shared content are preserved."
          } else {
            dialog = "Unarchived the Itinerary. Its entries and shared content are preserved."
          }
        case .incomplete:
          dialog =
            "The Itinerary's archive state changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct AddPlannerItemToItineraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Item to Itinerary"
    static let description = IntentDescription(
      "Append a live Item reference. Each addition has independent local completion.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundItineraryIdentifier = try itinerary.sourceIdentifier(in: plannerStore)
      let boundItemIdentifier = try item.sourceIdentifier(in: plannerStore)
      let result = try await plannerStore.executeAppIntent(
        .addItineraryEntry(
          itineraryId: boundItineraryIdentifier,
          source: .init(kind: .item, id: boundItemIdentifier), placement: .last))
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          dialog = "Added a new Item entry to the Itinerary. Its local completion is independent."
        case .incomplete:
          dialog =
            "The Item entry was added on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct AddPlannerListToItineraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add List to Itinerary"
    static let description = IntentDescription(
      "Append a live List reference. Each addition's children have independent local completion.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "List") var list: PlannerListEntity
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      try await plannerStore.beginAppIntentAction()
      defer { plannerStore.endAppIntentAction() }
      _ = try await plannerStore.appIntentContext()
      let boundItineraryIdentifier = try itinerary.sourceIdentifier(in: plannerStore)
      let boundListIdentifier = try list.sourceIdentifier(in: plannerStore)
      let result = try await plannerStore.executeAppIntent(
        .addItineraryEntry(
          itineraryId: boundItineraryIdentifier,
          source: .init(kind: .list, id: boundListIdentifier), placement: .last))
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          dialog = "Added a new List entry to the Itinerary. Its child completion is independent."
        case .incomplete:
          dialog =
            "The List entry was added on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  private struct PlannerItineraryIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
