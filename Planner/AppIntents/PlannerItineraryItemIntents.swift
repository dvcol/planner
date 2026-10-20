#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerItineraryItemEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Itinerary Item")
    static var defaultQuery: PlannerItineraryItemEntityQuery { PlannerItineraryItemEntityQuery() }
    let id: String
    @Property(title: "Title") var title: String
    @Property(title: "Context") var context: String
    @Property(title: "Globally completed") var globallyDone: Bool
    @Property(title: "Completed here") var locallyDone: Bool
    @Property(title: "Completed") var done: Bool
    @Property(title: "Archived") var archived: Bool
    var displayRepresentation: DisplayRepresentation {
      DisplayRepresentation(title: "\(title)", subtitle: "\(context)")
    }

    init(
      id: String, title: String, context: String, globallyDone: Bool, locallyDone: Bool,
      done: Bool, archived: Bool
    ) {
      self.id = id
      self.title = title
      self.context = context
      self.globallyDone = globallyDone
      self.locallyDone = locallyDone
      self.done = done
      self.archived = archived
    }
  }

  struct PlannerItineraryItemEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore
    @IntentParameterDependency<GetPlannerItineraryItemIntent>(\.$itinerary) var getIntent
    @IntentParameterDependency<SetPlannerItineraryItemCompletionIntent>(\.$itinerary)
    var completionIntent

    @MainActor func entities(for identifiers: [String]) async throws -> [PlannerItineraryItemEntity]
    {
      _ = try await plannerStore.appIntentContext()
      var seenIdentifiers: Set<String> = []
      let identities = identifiers.compactMap(PlannerItineraryItemIdentity.init).filter {
        seenIdentifiers.insert($0.id).inserted
      }
      var seenItineraries: Set<UUID> = []
      var resolved: [String: PlannerItineraryItemEntity] = [:]
      for identity in identities where seenItineraries.insert(identity.itineraryIdentifier).inserted
      {
        let requestedIdentifiers = Set(
          identities.filter { $0.itineraryIdentifier == identity.itineraryIdentifier }.map(\.id))
        for entity in try await loadItems(
          in: identity.itineraryIdentifier, matching: "", identifiers: requestedIdentifiers)
        {
          resolved[entity.id] = entity
        }
      }
      return identities.compactMap { resolved[$0.id] }
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerItineraryItemEntity] {
      _ = try await plannerStore.appIntentContext()
      guard let identifier = getIntent?.itinerary.id ?? completionIntent?.itinerary.id else {
        return []
      }
      return try await loadItems(in: identifier, matching: string)
    }

    @MainActor func suggestedEntities() async throws -> [PlannerItineraryItemEntity] {
      try await entities(matching: "")
    }

    @MainActor private func loadItems(
      in itineraryIdentifier: UUID, matching text: String, identifiers: Set<String>? = nil
    ) async throws -> [PlannerItineraryItemEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      let query = PlannerItemQuery(
        scope: .itinerary(itineraryIdentifier), text: text, completion: .all, archive: .all,
        sort: .init(mode: .manual))
      // Guard context labels too if the shared loader refreshes while paging.
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(.init(session: session, request: .items(query))) {
      case .snapshot(let current): snapshot = current
      case .failed(let reason) where reason.code == "missingReference": return []
      case .failed(let reason): throw PlannerItineraryItemIntentFailure(message: reason.message)
      }
      let window = SavedItemWindow(planner: planner, session: session)
      defer { window.cancel() }
      await window.reload(
        query: query,
        identity: .init(
          namespace: "app-intent-itinerary-\(itineraryIdentifier)", savedRevision: UUID()))
      try Task.checkCancellation()
      if case .failed(let message) = window.state {
        throw PlannerItineraryItemIntentFailure(message: message)
      }
      guard window.state == .ready, window.rowIdentities == snapshot.rows,
        let metadata = window.itineraryMetadata
      else {
        throw PlannerItineraryItemIntentFailure(
          message: "Planner changed while reading this Itinerary. Try again.")
      }
      var contexts: [String: String] = [:]
      for (entryIndex, entry) in metadata.entries.enumerated() {
        for (childIndex, rowIdentity) in entry.rowIdentities.enumerated() {
          guard let identity = PlannerItineraryItemIdentity(rowIdentity),
            identity.itineraryIdentifier == itineraryIdentifier, contexts[identity.id] == nil
          else {
            throw PlannerItineraryItemIntentFailure(
              message: "Planner could not identify this Itinerary's Items.")
          }
          var context = "\(metadata.itinerary.content.title) · Stop \(entryIndex + 1)"
          if let list = entry.list {
            context += " · \(list.content.name) · Item \(childIndex + 1)"
          }
          contexts[identity.id] = context
        }
      }
      var entities: [PlannerItineraryItemEntity] = []
      for (index, rowIdentity) in snapshot.rows.enumerated() {
        try Task.checkCancellation()
        guard let identity = PlannerItineraryItemIdentity(rowIdentity) else {
          throw PlannerItineraryItemIntentFailure(
            message: "Planner could not identify this Itinerary's Item.")
        }
        if let identifiers, !identifiers.contains(identity.id) { continue }
        await window.requestRows(at: [index])
        try Task.checkCancellation()
        guard window.rowIdentities == snapshot.rows else {
          throw PlannerItineraryItemIntentFailure(
            message: "Planner changed while reading this Itinerary. Try again.")
        }
        switch window.presentation(at: index) {
        case .loaded(let presentation):
          let row = presentation.row
          guard row.identity == rowIdentity, let context = contexts[identity.id],
            let globallyDone = row.globalDone, let locallyDone = row.localDone,
            let done = row.effectiveDone, let archived = row.archived
          else {
            throw PlannerItineraryItemIntentFailure(
              message: "Planner could not read this Itinerary Item's current state.")
          }
          entities.append(
            .init(
              id: identity.id, title: row.title, context: context, globallyDone: globallyDone,
              locallyDone: locallyDone, done: done, archived: archived))
        case .failed(let message): throw PlannerItineraryItemIntentFailure(message: message)
        case .loading:
          throw PlannerItineraryItemIntentFailure(
            message: "Planner could not finish reading this Itinerary Item.")
        }
      }
      switch await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
      {
      case .rows(let page) where page.generation == snapshot.generation: break
      case .failed(let reason): throw PlannerItineraryItemIntentFailure(message: reason.message)
      default:
        throw PlannerItineraryItemIntentFailure(
          message: "Planner could not verify this Itinerary's current Items.")
      }
      try Task.checkCancellation()
      return entities
    }
  }

  struct GetPlannerItineraryItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Item in Itinerary"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Item in Itinerary", query: PlannerItineraryItemEntityQuery())
    var item: PlannerItineraryItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerItineraryItemEntity, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      guard let identity = PlannerItineraryItemIdentity(item.id),
        identity.itineraryIdentifier == itinerary.id
      else {
        throw PlannerItineraryItemIntentFailure(
          message: "Choose an Item appearance from the selected Itinerary.")
      }
      let query = PlannerItineraryItemEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [identity.id])
      guard let current = matches.first else {
        throw PlannerItineraryItemIntentFailure(
          message: "This Item appearance is no longer available in the selected Itinerary.")
      }
      return .result(value: current)
    }
  }

  struct SetPlannerItineraryItemCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item Completion in Itinerary"
    static let description = IntentDescription(
      "Change only this selected appearance. Global completion and other appearances remain unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Item in Itinerary", query: PlannerItineraryItemEntityQuery())
    var item: PlannerItineraryItemEntity
    @Parameter(title: "Completed here") var done: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard let identity = PlannerItineraryItemIdentity(item.id),
        identity.itineraryIdentifier == itinerary.id
      else {
        throw PlannerItineraryItemIntentFailure(
          message: "Choose an Item appearance from the selected Itinerary.")
      }
      let query = PlannerItineraryItemEntityQuery()
      query.plannerStore = plannerStore
      let matches = try await query.entities(for: [identity.id])
      guard matches.first != nil else {
        throw PlannerItineraryItemIntentFailure(
          message: "This Item appearance is no longer available in the selected Itinerary.")
      }
      let result = try await plannerStore.executeAppIntent(
        .setCompletion(scope: .appearance(identity.appearance), done: done))
      switch result.outcome {
      case .rejected(let reason): throw PlannerItineraryItemIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerItineraryItemIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete:
          if done {
            dialog =
              "Marked this appearance Done. Other appearances and global completion are unchanged."
          } else {
            dialog = "Cleared this appearance's completion. Globally Done Items still appear Done."
          }
        case .incomplete:
          dialog =
            "This appearance's completion changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  private struct PlannerItineraryItemIdentity {
    let itineraryIdentifier: UUID
    let entryIdentifier: UUID
    let membershipIdentifier: UUID?
    let sourceIdentifier: UUID

    var id: String {
      if let membershipIdentifier {
        return
          "v1/list/\(itineraryIdentifier)/\(entryIdentifier)/\(membershipIdentifier)/\(sourceIdentifier)"
      }
      return "v1/direct/\(itineraryIdentifier)/\(entryIdentifier)/\(sourceIdentifier)"
    }

    var appearance: PlannerAppearance {
      if let membershipIdentifier {
        return .expandedListItem(
          itineraryId: itineraryIdentifier, listEntryId: entryIdentifier,
          membershipId: membershipIdentifier)
      }
      return .directItineraryItem(itineraryId: itineraryIdentifier, entryId: entryIdentifier)
    }

    init?(_ identifier: String) {
      let components = identifier.split(separator: "/", omittingEmptySubsequences: false)
      guard components.first == "v1", components.count == 5 || components.count == 6,
        let itineraryIdentifier = UUID(uuidString: String(components[2])),
        let entryIdentifier = UUID(uuidString: String(components[3])),
        let sourceIdentifier = UUID(uuidString: String(components[components.count - 1]))
      else { return nil }
      if components[1] == "direct", components.count == 5 {
        membershipIdentifier = nil
      } else if components[1] == "list", components.count == 6,
        let membership = UUID(uuidString: String(components[4]))
      {
        membershipIdentifier = membership
      } else {
        return nil
      }
      self.itineraryIdentifier = itineraryIdentifier
      self.entryIdentifier = entryIdentifier
      self.sourceIdentifier = sourceIdentifier
    }

    init?(_ rowIdentity: PlannerRowIdentity) {
      guard case .appearance(let source, let appearance) = rowIdentity, source.kind == .item else {
        return nil
      }
      sourceIdentifier = source.id
      switch appearance {
      case .directItineraryItem(let itinerary, let entry):
        itineraryIdentifier = itinerary
        entryIdentifier = entry
        membershipIdentifier = nil
      case .expandedListItem(let itinerary, let listEntry, let membership):
        itineraryIdentifier = itinerary
        entryIdentifier = listEntry
        membershipIdentifier = membership
      case .listMembership: return nil
      }
    }
  }

  private struct PlannerItineraryItemIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
