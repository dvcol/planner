#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerLinkEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Link")
    static var defaultQuery: PlannerLinkEntityQuery { PlannerLinkEntityQuery() }
    let id: String
    @Property(title: "Link") var url: URL
    @Property(title: "Original URL text") var originalURL: String
    @Property(title: "Label") var label: String?
    @Property(title: "Saved in") var ownerTitle: String
    @Property(title: "Position") var position: Int
    var displayRepresentation: DisplayRepresentation {
      if let label, !label.isEmpty {
        return .init(title: "\(label)", subtitle: "\(ownerTitle) · Link \(position)")
      }
      return .init(title: "\(originalURL)", subtitle: "\(ownerTitle) · Link \(position)")
    }

    init(
      owner: PlannerEntityReference, ownerTitle: String, position: Int, link: PlannerOwnedLinkRead
    ) throws {
      guard let url = URL(string: link.originalUrl) else {
        throw PlannerLinkIntentFailure(message: "Planner could not read this saved Link's URL.")
      }
      self.init(
        owner: owner, ownerTitle: ownerTitle, position: position, linkIdentifier: link.linkId,
        url: url, originalURL: link.originalUrl, label: link.label)
    }

    fileprivate init(
      owner: PlannerEntityReference, ownerTitle: String, position: Int, linkIdentifier: UUID,
      url: URL, originalURL: String, label: String?
    ) {
      self.id = PlannerLinkIdentity(owner: owner, linkIdentifier: linkIdentifier).id
      self.url = url
      self.originalURL = originalURL
      self.label = label
      self.ownerTitle = ownerTitle
      self.position = position
    }
  }

  struct PlannerLinkEntityQuery: EntityQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore

    @MainActor func entities(for identifiers: [String]) async throws -> [PlannerLinkEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      try Task.checkCancellation()
      var seenIdentifiers: Set<String> = []
      let identities = identifiers.compactMap(PlannerLinkIdentity.init).filter {
        seenIdentifiers.insert($0.id).inserted
      }
      var seenOwners: Set<PlannerEntityReference> = []
      var resolved: [String: PlannerLinkEntity] = [:]
      for identity in identities where seenOwners.insert(identity.owner).inserted {
        try Task.checkCancellation()
        guard
          let links = try await loadPlannerLinkEntities(
            owner: identity.owner, planner: planner, session: session)
        else { continue }
        let requested = Set(identities.filter { $0.owner == identity.owner }.map(\.id))
        for link in links where requested.contains(link.id) { resolved[link.id] = link }
      }
      return identities.compactMap { resolved[$0.id] }
    }

    @MainActor func suggestedEntities() async throws -> [PlannerLinkEntity] {
      _ = try await plannerStore.appIntentContext()
      try Task.checkCancellation()
      return []
    }
  }

  struct GetPlannerItemLinksIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Item links"
    static let description = IntentDescription(
      "Read this Item's saved Links in their saved order, including distinct duplicate bookmarks.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerLinkEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      guard
        let links = try await loadPlannerLinkEntities(
          owner: .init(kind: .item, id: item.id), planner: planner, session: session)
      else {
        throw PlannerLinkIntentFailure(
          message: "This Item is no longer available in Planner's current data.")
      }
      return .result(value: links)
    }
  }

  struct GetPlannerItineraryLinksIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Itinerary links"
    static let description = IntentDescription(
      "Read this Itinerary's own saved Links in order. Referenced Items keep their separate bookmarks."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerLinkEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      guard
        let links = try await loadPlannerLinkEntities(
          owner: .init(kind: .itinerary, id: itinerary.id), planner: planner, session: session)
      else {
        throw PlannerLinkIntentFailure(
          message: "This Itinerary is no longer available in Planner's current data.")
      }
      return .result(value: links)
    }
  }

  struct AddPlannerItemLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Item link"
    static let description = IntentDescription(
      "Append a bookmark to this Item and return its exact new Link. Equal URLs remain separate bookmarks."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Link") var originalURL: String
    @Parameter(title: "Label") var label: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerLinkEntity, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let added = try await addPlannerLink(
        to: .init(kind: .item, id: item.id), originalURL: originalURL, label: label,
        store: plannerStore)
      return .result(value: added.link, dialog: added.dialog)
    }
  }

  struct AddPlannerItineraryLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Itinerary link"
    static let description = IntentDescription(
      "Append a bookmark to this Itinerary's own Links and return its exact identity. Referenced Items keep their separate bookmarks."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Link") var originalURL: String
    @Parameter(title: "Label") var label: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerLinkEntity, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let added = try await addPlannerLink(
        to: .init(kind: .itinerary, id: itinerary.id), originalURL: originalURL, label: label,
        store: plannerStore)
      return .result(value: added.link, dialog: added.dialog)
    }
  }

  @MainActor
  private func addPlannerLink(
    to owner: PlannerEntityReference, originalURL: String, label: String?, store: SavedPlannerStore
  ) async throws -> (link: PlannerLinkEntity, dialog: IntentDialog) {
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    guard let url = URL(string: originalURL, encodingInvalidCharacters: false) else {
      throw PlannerLinkIntentFailure(message: "A bookmark must be an absolute HTTP or HTTPS URL.")
    }
    func replacement(_ links: [PlannerOwnedLinkRead]) -> [PlannerLinkInput] {
      links.map {
        .init(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
      } + [.init(originalUrl: originalURL, label: label)]
    }
    let ownerTitle: String
    let position: Int
    let command: PlannerCommand
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let current)) where owner.kind == .item:
      ownerTitle = current.content.title
      position = current.content.links.count + 1
      command = .editItem(
        sourceId: owner.id, changes: .init(links: .set(replacement(current.content.links))),
        expectedFieldHashes: current.fieldHashes)
    case .source(.itinerary(let current)) where owner.kind == .itinerary:
      ownerTitle = current.content.title
      position = current.content.links.count + 1
      command = .editItinerary(
        sourceId: owner.id, changes: .init(links: .set(replacement(current.content.links))),
        expectedFieldHashes: current.fieldHashes)
    case .failed(let reason): throw PlannerLinkIntentFailure(message: reason.message)
    default: throw PlannerLinkIntentFailure(message: "Planner could not read this Link's owner.")
    }
    let response = try await store.executeAppIntent(command)
    switch response.outcome {
    case .rejected(let reason): throw PlannerLinkIntentFailure(message: reason.message)
    case .unverified:
      throw PlannerLinkIntentFailure(
        message:
          "Planner could not verify this change. Open Planner to review recovery before making another change."
      )
    case .applied(let applied, let recovery):
      let identifiers = applied.generatedReferences.compactMap { reference -> UUID? in
        guard case .ownedLink(let identifier, let savedOwner) = reference, savedOwner == owner
        else {
          return nil
        }
        return identifier
      }
      guard identifiers.count == 1, let identifier = identifiers.first else {
        throw PlannerLinkIntentFailure(
          message:
            "The Link was saved, but Planner could not return its identity. Open Planner to review it."
        )
      }
      let dialog: IntentDialog
      switch recovery {
      case .complete: dialog = "Added the Link."
      case .incomplete:
        dialog =
          "The Link was added on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
      return (
        PlannerLinkEntity(
          owner: owner, ownerTitle: ownerTitle, position: position, linkIdentifier: identifier,
          url: url, originalURL: originalURL, label: label), dialog
      )
    }
  }

  private struct PlannerLinkIdentity {
    let owner: PlannerEntityReference
    let linkIdentifier: UUID
    var id: String { "\(owner.kind.rawValue):\(owner.id.uuidString):\(linkIdentifier.uuidString)" }

    init(owner: PlannerEntityReference, linkIdentifier: UUID) {
      self.owner = owner
      self.linkIdentifier = linkIdentifier
    }

    init?(_ value: String) {
      let components = value.split(separator: ":", omittingEmptySubsequences: false)
      guard components.count == 3, let kind = PlannerEntityKind(rawValue: String(components[0])),
        kind == .item || kind == .itinerary,
        let ownerIdentifier = UUID(uuidString: String(components[1])),
        let linkIdentifier = UUID(uuidString: String(components[2]))
      else { return nil }
      self.init(owner: .init(kind: kind, id: ownerIdentifier), linkIdentifier: linkIdentifier)
    }
  }

  @MainActor
  private func loadPlannerLinkEntities(
    owner: PlannerEntityReference, planner: PlannerCore.Planner,
    session: PlannerDatasetSession
  ) async throws -> [PlannerLinkEntity]? {
    try Task.checkCancellation()
    let ownerTitle: String
    let links: [PlannerOwnedLinkRead]
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let source)) where owner.kind == .item:
      ownerTitle = source.content.title
      links = source.content.links
    case .source(.itinerary(let source)) where owner.kind == .itinerary:
      ownerTitle = source.content.title
      links = source.content.links
    case .failed(let reason) where reason.code == "missingReference": return nil
    case .failed(let reason): throw PlannerLinkIntentFailure(message: reason.message)
    default: throw PlannerLinkIntentFailure(message: "Planner could not read this Link's owner.")
    }
    try Task.checkCancellation()
    return try links.enumerated().map { position, link in
      try PlannerLinkEntity(
        owner: owner, ownerTitle: ownerTitle, position: position + 1, link: link)
    }
  }

  private struct PlannerLinkIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
