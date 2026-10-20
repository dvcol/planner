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

  struct PlannerLinkEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore
    @IntentParameterDependency<EditPlannerItemLinkIntent>(\.$item) var itemEditIntent
    @IntentParameterDependency<EditPlannerItineraryLinkIntent>(\.$itinerary) var itineraryEditIntent
    @IntentParameterDependency<RemovePlannerItemLinkIntent>(\.$item) var itemRemovalIntent
    @IntentParameterDependency<RemovePlannerItineraryLinkIntent>(\.$itinerary)
    var itineraryRemovalIntent
    @IntentParameterDependency<ReorderPlannerItemLinkIntent>(\.$item) var itemReorderIntent
    @IntentParameterDependency<ReorderPlannerItineraryLinkIntent>(\.$itinerary)
    var itineraryReorderIntent

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
      try await entities(matching: "")
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerLinkEntity] {
      let (planner, session) = try await plannerStore.appIntentContext()
      try Task.checkCancellation()
      let owner: PlannerEntityReference
      if let item = itemEditIntent?.item {
        owner = .init(kind: .item, id: item.id)
      } else if let itinerary = itineraryEditIntent?.itinerary {
        owner = .init(kind: .itinerary, id: itinerary.id)
      } else if let item = itemRemovalIntent?.item {
        owner = .init(kind: .item, id: item.id)
      } else if let itinerary = itineraryRemovalIntent?.itinerary {
        owner = .init(kind: .itinerary, id: itinerary.id)
      } else if let item = itemReorderIntent?.item {
        owner = .init(kind: .item, id: item.id)
      } else if let itinerary = itineraryReorderIntent?.itinerary {
        owner = .init(kind: .itinerary, id: itinerary.id)
      } else {
        return []
      }
      guard
        let links = try await loadPlannerLinkEntities(
          owner: owner, planner: planner, session: session)
      else { return [] }
      return links.filter {
        string.isEmpty || $0.originalURL.localizedStandardContains(string)
          || $0.label?.localizedStandardContains(string) == true
      }
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

  enum PlannerLinkReorderPosition: String, AppEnum, CaseIterable {
    case first, last, before, after
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Link position")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .first: .init(title: "Beginning"), .last: .init(title: "End"),
      .before: .init(title: "Before link"), .after: .init(title: "After link"),
    ]
  }

  struct ReorderPlannerItemLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Reorder Item link"
    static let description = IntentDescription(
      "Move this exact bookmark in its Item's saved Link order. Before/After need a relative Link in the same Item; Beginning/End ignore it."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Link", query: PlannerLinkEntityQuery()) var link: PlannerLinkEntity
    @Parameter(title: "Position") var position: PlannerLinkReorderPosition
    @Parameter(title: "Relative link", query: PlannerLinkEntityQuery())
    var relativeLink: PlannerLinkEntity?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await changePlannerLink(
        owner: .init(kind: .item, id: item.id), linkIdentifier: link.id,
        change: .reorder(position: position, relativeLinkIdentifier: relativeLink?.id),
        store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct ReorderPlannerItineraryLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Reorder Itinerary link"
    static let description = IntentDescription(
      "Move this exact bookmark in the Itinerary's own Links. Before/After need a relative Link in this plan; Beginning/End ignore it."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Link", query: PlannerLinkEntityQuery()) var link: PlannerLinkEntity
    @Parameter(title: "Position") var position: PlannerLinkReorderPosition
    @Parameter(title: "Relative link", query: PlannerLinkEntityQuery())
    var relativeLink: PlannerLinkEntity?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await changePlannerLink(
        owner: .init(kind: .itinerary, id: itinerary.id), linkIdentifier: link.id,
        change: .reorder(position: position, relativeLinkIdentifier: relativeLink?.id),
        store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct RemovePlannerItemLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Item link"
    static let description = IntentDescription(
      "Remove this exact bookmark while retaining its Item, other Links and planning references.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Link", query: PlannerLinkEntityQuery()) var link: PlannerLinkEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await changePlannerLink(
        owner: .init(kind: .item, id: item.id), linkIdentifier: link.id,
        change: .remove, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct RemovePlannerItineraryLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Itinerary link"
    static let description = IntentDescription(
      "Remove this exact bookmark from the Itinerary's own Links. Keep the plan, referenced Items and other bookmarks."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Link", query: PlannerLinkEntityQuery()) var link: PlannerLinkEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await changePlannerLink(
        owner: .init(kind: .itinerary, id: itinerary.id), linkIdentifier: link.id,
        change: .remove, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct EditPlannerItemLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Item link"
    static let description = IntentDescription(
      "Change this exact bookmark. Omitted fields stay unchanged; empty label text clears its label."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Link", query: PlannerLinkEntityQuery()) var link: PlannerLinkEntity
    @Parameter(title: "New URL") var originalURL: String?
    @Parameter(title: "New label") var label: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await changePlannerLink(
        owner: .init(kind: .item, id: item.id), linkIdentifier: link.id,
        change: .edit(originalURL: originalURL, label: label), store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct EditPlannerItineraryLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Itinerary link"
    static let description = IntentDescription(
      "Change this exact bookmark in the Itinerary's own Links. Omitted fields stay unchanged; empty label text clears its label."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Link", query: PlannerLinkEntityQuery()) var link: PlannerLinkEntity
    @Parameter(title: "New URL") var originalURL: String?
    @Parameter(title: "New label") var label: String?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await changePlannerLink(
        owner: .init(kind: .itinerary, id: itinerary.id), linkIdentifier: link.id,
        change: .edit(originalURL: originalURL, label: label), store: plannerStore)
      return .result(dialog: dialog)
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

  @MainActor
  private func changePlannerLink(
    owner: PlannerEntityReference, linkIdentifier: String, change: PlannerLinkChange,
    store: SavedPlannerStore
  ) async throws -> IntentDialog {
    guard let identity = PlannerLinkIdentity(linkIdentifier), identity.owner == owner else {
      throw PlannerLinkIntentFailure(
        message: "Choose a Link saved in the selected Item or Itinerary.")
    }
    if case .edit(let originalURL, let label) = change, originalURL == nil, label == nil {
      throw PlannerLinkIntentFailure(message: "Choose a URL or label to change.")
    }
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    func replacement(_ links: [PlannerOwnedLinkRead]) throws -> [PlannerLinkInput] {
      guard let currentIndex = links.firstIndex(where: { $0.linkId == identity.linkIdentifier })
      else {
        throw PlannerLinkIntentFailure(
          message: "This Link is no longer saved in the selected Item or Itinerary.")
      }
      var updatedLinks = links.map {
        PlannerLinkInput(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
      }
      switch change {
      case .edit(let originalURL, let label):
        let currentLink = links[currentIndex]
        var updatedLabel = currentLink.label
        if let label { updatedLabel = label.isEmpty ? nil : label }
        updatedLinks[currentIndex] = .init(
          linkId: currentLink.linkId, originalUrl: originalURL ?? currentLink.originalUrl,
          label: updatedLabel)
      case .remove:
        updatedLinks.remove(at: currentIndex)
      case .reorder(let position, let relativeLinkIdentifier):
        let movingLink = updatedLinks.remove(at: currentIndex)
        let insertionIndex: Int
        switch position {
        case .first: insertionIndex = 0
        case .last: insertionIndex = updatedLinks.count
        case .before, .after:
          guard let relativeLinkIdentifier,
            let anchor = PlannerLinkIdentity(relativeLinkIdentifier), anchor.owner == owner,
            anchor.linkIdentifier != identity.linkIdentifier
          else {
            throw PlannerLinkIntentFailure(
              message: "Choose a different relative Link saved in the same Item or Itinerary.")
          }
          guard
            let anchorIndex = updatedLinks.firstIndex(where: { $0.linkId == anchor.linkIdentifier })
          else {
            throw PlannerLinkIntentFailure(
              message: "The relative Link is no longer saved in this Item or Itinerary.")
          }
          if position == .after {
            insertionIndex = anchorIndex + 1
          } else {
            insertionIndex = anchorIndex
          }
        }
        updatedLinks.insert(movingLink, at: insertionIndex)
      }
      return updatedLinks
    }
    let command: PlannerCommand
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let current)) where owner.kind == .item:
      command = .editItem(
        sourceId: owner.id, changes: .init(links: .set(try replacement(current.content.links))),
        expectedFieldHashes: current.fieldHashes)
    case .source(.itinerary(let current)) where owner.kind == .itinerary:
      command = .editItinerary(
        sourceId: owner.id, changes: .init(links: .set(try replacement(current.content.links))),
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
    case .applied(_, .complete): return change.completedDialog
    case .applied(_, .incomplete): return change.incompleteDialog
    }
  }

  private enum PlannerLinkChange {
    case edit(originalURL: String?, label: String?)
    case remove
    case reorder(position: PlannerLinkReorderPosition, relativeLinkIdentifier: String?)

    var completedDialog: IntentDialog {
      switch self {
      case .edit: return "Updated the Link."
      case .remove: return "Removed the Link."
      case .reorder: return "Updated the Link order."
      }
    }

    var incompleteDialog: IntentDialog {
      switch self {
      case .edit:
        return
          "The Link changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      case .remove:
        return
          "The Link was removed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      case .reorder:
        return
          "The Link order changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
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
