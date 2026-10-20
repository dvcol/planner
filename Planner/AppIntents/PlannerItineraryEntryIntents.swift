#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  enum PlannerItineraryEntryKind: String, AppEnum, CaseIterable {
    case item, list
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Itinerary entry type")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .item: .init(title: "Item"), .list: .init(title: "List"),
    ]
  }

  struct PlannerItineraryEntryEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Itinerary Entry")
    static var defaultQuery: PlannerItineraryEntryEntityQuery { PlannerItineraryEntryEntityQuery() }
    let id: String
    @Property(title: "Title") var title: String
    @Property(title: "Context") var context: String
    @Property(title: "Type") var kind: PlannerItineraryEntryKind
    @Property(title: "Archived") var archived: Bool
    var displayRepresentation: DisplayRepresentation {
      DisplayRepresentation(title: "\(title)", subtitle: "\(context)")
    }

    init(
      id: String, title: String, context: String, kind: PlannerItineraryEntryKind, archived: Bool
    ) {
      self.id = id
      self.title = title
      self.context = context
      self.kind = kind
      self.archived = archived
    }
  }

  struct PlannerItineraryEntryEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore
    @IntentParameterDependency<RemovePlannerItineraryEntryIntent>(\.$itinerary) var removalIntent
    @IntentParameterDependency<ReorderPlannerItineraryEntryIntent>(\.$itinerary) var reorderIntent

    @MainActor func entities(for identifiers: [String]) async throws
      -> [PlannerItineraryEntryEntity]
    {
      _ = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<String> = []
      let identities = identifiers.compactMap(PlannerItineraryEntryIdentity.init).filter {
        seenIdentifiers.insert($0.id).inserted
      }
      var seenItineraries: Set<UUID> = []
      var resolved: [String: PlannerItineraryEntryEntity] = [:]
      for identity in identities where seenItineraries.insert(identity.itineraryIdentifier).inserted
      {
        let requested = Set(
          identities.filter { $0.itineraryIdentifier == identity.itineraryIdentifier }.map(\.id))
        for entry in try await loadEntries(
          in: identity.itineraryIdentifier, matching: "", identifiers: requested)
        { resolved[entry.id] = entry }
      }
      return identities.compactMap { resolved[$0.id] }
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerItineraryEntryEntity]
    {
      _ = try await plannerStore.appIntentContext()
      guard let identifier = removalIntent?.itinerary.id ?? reorderIntent?.itinerary.id else {
        return []
      }
      return try await loadEntries(in: identifier, matching: string)
    }

    @MainActor func suggestedEntities() async throws -> [PlannerItineraryEntryEntity] {
      try await entities(matching: "")
    }

    @MainActor private func loadEntries(
      in itineraryIdentifier: UUID, matching text: String, identifiers: Set<String>? = nil
    ) async throws -> [PlannerItineraryEntryEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      let query = PlannerItemQuery(
        scope: .itinerary(itineraryIdentifier), text: text, completion: .all, archive: .all,
        sort: .init(mode: .manual))
      // Guard entry names too if the shared loader refreshes while paging.
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(.init(session: session, request: .items(query))) {
      case .snapshot(let current): snapshot = current
      case .failed(let reason) where reason.code == "missingReference": return []
      case .failed(let reason): throw PlannerItineraryEntryIntentFailure(message: reason.message)
      }
      let window = SavedItemWindow(planner: planner, session: session)
      defer { window.cancel() }
      await window.reload(
        query: query,
        identity: .init(
          namespace: "app-intent-route-\(itineraryIdentifier)", savedRevision: UUID()))
      try Task.checkCancellation()
      if case .failed(let message) = window.state {
        throw PlannerItineraryEntryIntentFailure(message: message)
      }
      guard window.state == .ready, window.rowIdentities == snapshot.rows,
        let metadata = window.itineraryMetadata
      else {
        throw PlannerItineraryEntryIntentFailure(
          message: "Planner changed while reading this Itinerary. Try again.")
      }
      let visibleEntries = Set(metadata.visibleEntries.map(\.id))
      var entities: [PlannerItineraryEntryEntity] = []
      for (index, entry) in metadata.entries.enumerated() {
        try Task.checkCancellation()
        guard visibleEntries.contains(entry.id) else { continue }
        guard
          let identity = PlannerItineraryEntryIdentity(
            itineraryIdentifier: itineraryIdentifier, entryIdentifier: entry.id,
            source: entry.source)
        else {
          throw PlannerItineraryEntryIntentFailure(
            message: "Planner could not identify a route entry.")
        }
        if let identifiers, !identifiers.contains(identity.id) { continue }
        let title: String
        let archived: Bool
        switch identity.kind {
        case .list:
          guard let list = entry.list, let state = list.state.archived else {
            throw PlannerItineraryEntryIntentFailure(
              message: "Planner could not read this List stop.")
          }
          title = list.content.name
          archived = state
        case .item:
          guard entry.matchingRowIndices.count == 1, let rowIndex = entry.matchingRowIndices.first
          else {
            throw PlannerItineraryEntryIntentFailure(
              message: "Planner could not locate this Item stop.")
          }
          await window.requestRows(at: [rowIndex])
          try Task.checkCancellation()
          guard window.rowIdentities == snapshot.rows else {
            throw PlannerItineraryEntryIntentFailure(
              message: "Planner changed while reading this Itinerary. Try again.")
          }
          switch window.presentation(at: rowIndex) {
          case .loaded(let presentation):
            guard
              presentation.row.identity
                == .appearance(
                  source: entry.source,
                  appearance: .directItineraryItem(
                    itineraryId: itineraryIdentifier, entryId: entry.id)),
              let state = presentation.row.archived
            else {
              throw PlannerItineraryEntryIntentFailure(
                message: "Planner could not resolve this Item stop.")
            }
            title = presentation.row.title
            archived = state
          case .failed(let message): throw PlannerItineraryEntryIntentFailure(message: message)
          case .loading:
            throw PlannerItineraryEntryIntentFailure(
              message: "Planner could not finish reading this Item stop.")
          }
        }
        let kindName = identity.kind == .list ? "List" : "Item"
        entities.append(
          .init(
            id: identity.id, title: title,
            context: "\(metadata.itinerary.content.title) · Stop \(index + 1) · \(kindName)",
            kind: identity.kind, archived: archived))
      }
      switch await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
      {
      case .rows(let page) where page.generation == snapshot.generation: break
      case .failed(let reason): throw PlannerItineraryEntryIntentFailure(message: reason.message)
      default:
        throw PlannerItineraryEntryIntentFailure(
          message: "Planner could not verify this route's entries.")
      }
      try Task.checkCancellation()
      return entities
    }
  }

  struct RemovePlannerItineraryEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Entry from Itinerary"
    static let description = IntentDescription(
      "Remove one route stop while retaining its shared Item or List and all other stops.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Entry", query: PlannerItineraryEntryEntityQuery())
    var entry: PlannerItineraryEntryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard let identity = PlannerItineraryEntryIdentity(entry.id),
        identity.itineraryIdentifier == itinerary.id
      else {
        throw PlannerItineraryEntryIntentFailure(
          message: "Choose an entry from the selected Itinerary.")
      }
      let query = PlannerItineraryEntryEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [identity.id])
      guard matches.first != nil else {
        throw PlannerItineraryEntryIntentFailure(
          message: "This entry no longer belongs to the selected Itinerary.")
      }
      let result = try await plannerStore.executeAppIntent(
        .removeItineraryEntry(itineraryId: itinerary.id, entryId: identity.entryIdentifier))
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryEntryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryEntryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          dialog = "Removed this route entry. Shared Items, Lists and other entries are preserved."
        case .incomplete:
          dialog =
            "This route entry was removed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  enum PlannerItineraryReorderPosition: String, AppEnum, CaseIterable {
    case first, last, before, after
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Position in Itinerary")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .first: .init(title: "Beginning"), .last: .init(title: "End"),
      .before: .init(title: "Before Entry"), .after: .init(title: "After Entry"),
    ]
  }

  struct ReorderPlannerItineraryEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Reorder Entry in Itinerary"
    static let description = IntentDescription(
      "Change the saved route order. Before/After require a relative entry in the same route; Beginning/End use only the selected entry."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Entry", query: PlannerItineraryEntryEntityQuery())
    var entry: PlannerItineraryEntryEntity
    @Parameter(title: "Position") var position: PlannerItineraryReorderPosition
    @Parameter(title: "Relative entry", query: PlannerItineraryEntryEntityQuery())
    var relativeEntry: PlannerItineraryEntryEntity?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard let identity = PlannerItineraryEntryIdentity(entry.id),
        identity.itineraryIdentifier == itinerary.id
      else {
        throw PlannerItineraryEntryIntentFailure(
          message: "Choose an entry from the selected Itinerary.")
      }
      let placement: PlannerPlacement
      var identifiers = [identity.id]
      switch position {
      case .first: placement = .first
      case .last: placement = .last
      case .before, .after:
        guard let relativeEntry, let anchor = PlannerItineraryEntryIdentity(relativeEntry.id),
          anchor.itineraryIdentifier == itinerary.id
        else {
          throw PlannerItineraryEntryIntentFailure(
            message: "Choose a relative entry from the same Itinerary.")
        }
        identifiers.append(anchor.id)
        if position == .before {
          placement = .before(associationId: anchor.entryIdentifier)
        } else {
          placement = .after(associationId: anchor.entryIdentifier)
        }
      }
      let query = PlannerItineraryEntryEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: identifiers)
      let resolvedIdentifiers = Set(matches.map(\.id))
      guard identifiers.allSatisfy({ resolvedIdentifiers.contains($0) }) else {
        throw PlannerItineraryEntryIntentFailure(
          message: "The entry or its relative entry no longer belongs to this Itinerary.")
      }
      let result = try await plannerStore.executeAppIntent(
        .reorderItineraryEntry(
          itineraryId: itinerary.id, entryId: identity.entryIdentifier, placement: placement))
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryEntryIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryEntryIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          dialog =
            "Updated the saved route order. Shared Items, Lists, completion and bookings are preserved."
        case .incomplete:
          dialog =
            "The route order changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  private struct PlannerItineraryEntryIdentity {
    let itineraryIdentifier: UUID
    let entryIdentifier: UUID
    let sourceIdentifier: UUID
    let kind: PlannerItineraryEntryKind

    var id: String {
      "v1/entry/\(itineraryIdentifier)/\(entryIdentifier)/\(kind.rawValue)/\(sourceIdentifier)"
    }

    init?(_ identifier: String) {
      let components = identifier.split(separator: "/", omittingEmptySubsequences: false)
      guard components.count == 6, components[0] == "v1", components[1] == "entry",
        let itinerary = UUID(uuidString: String(components[2])),
        let entry = UUID(uuidString: String(components[3])),
        let kind = PlannerItineraryEntryKind(rawValue: String(components[4])),
        let source = UUID(uuidString: String(components[5]))
      else { return nil }
      itineraryIdentifier = itinerary
      entryIdentifier = entry
      sourceIdentifier = source
      self.kind = kind
    }

    init?(itineraryIdentifier: UUID, entryIdentifier: UUID, source: PlannerEntityReference) {
      switch source.kind {
      case .item: kind = .item
      case .list: kind = .list
      default: return nil
      }
      self.itineraryIdentifier = itineraryIdentifier
      self.entryIdentifier = entryIdentifier
      sourceIdentifier = source.id
    }
  }

  private struct PlannerItineraryEntryIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
