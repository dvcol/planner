import CryptoKit
import Foundation
import Observation
import PlannerCore

struct SavedPlannerList: Identifiable {
  let source: PlannerEntityReference
  let name: String
  let archived: Bool
  var id: UUID { source.id }
}

struct SavedPlannerItem: Identifiable {
  let id: UUID
  let row: PlannerRowRead
}

struct SavedPlannerLabel: Identifiable {
  let source: PlannerEntityReference
  let name: String
  var id: UUID { source.id }
}

struct SavedPlannerItinerary: Identifiable {
  let source: PlannerEntityReference
  let title: String
  var id: UUID { source.id }
}

enum SavedBulkCompletionResult {
  case applied
  case reviewChanged(PlannerReview)
  case failed
}

@MainActor @Observable
final class SavedPlannerStore {
  private let planner: PlannerCore.Planner?
  private var session: PlannerDatasetSession?
  private(set) var lists: [SavedPlannerList] = []
  private(set) var items: [SavedPlannerItem] = []
  private(set) var isOpening = false
  private(set) var isSaving = false
  private(set) var recoveryBlocked = false
  private(set) var changeRevision = UUID()
  private(set) var openingFailure: String?
  var alertMessage: String?
  var isReady: Bool { session != nil && !isOpening }
  var canCreate: Bool { isReady && !isOpening && !isSaving && !recoveryBlocked }

  var devicePreferenceNamespace: String? {
    guard let session else { return nil }
    let identity = session.datasetId.uuidString + ":" + session.ownershipBinding
    return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let directory: URL
    if let index = arguments.firstIndex(of: "--local-prototype-dataset") {
      guard arguments.indices.contains(index + 1),
        let identifier = UUID(uuidString: arguments[index + 1])
      else {
        planner = nil
        openingFailure = "The local prototype dataset identifier is invalid."
        return
      }
      directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlannerLocalPrototype", isDirectory: true)
        .appendingPathComponent(identifier.uuidString, isDirectory: true)
    } else {
      guard
        let support = FileManager.default.urls(
          for: .applicationSupportDirectory, in: .userDomainMask
        ).first
      else {
        planner = nil
        openingFailure = "Planner's local data directory is unavailable."
        return
      }
      directory = support.appendingPathComponent("Planner/Local", isDirectory: true)
    }
    planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
  }

  func open() async {
    guard let planner, session == nil, !isOpening else { return }
    isOpening = true
    openingFailure = nil
    defer { isOpening = false }
    switch await planner.bootstrap() {
    case .ready(let ready):
      session = ready
      await refreshLists()
      await refreshItems()
    case .unavailable(let reason): openingFailure = reason.message
    case .mainAppSetupRequired, .mainAppMigrationRequired:
      openingFailure = "Planner could not initialize its local data."
    }
  }

  func refreshLists() async {
    if let loaded = await readLists(archive: .active) { lists = loaded }
  }

  func readLists(archive: PlannerItemQuery.Archive) async -> [SavedPlannerList]? {
    guard let planner, let session else { return nil }
    switch await planner.query(
      PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list, archive: archive))))
    {
    case .failed(let reason): alertMessage = reason.message
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
      {
      case .rows(let window):
        return window.rows.compactMap { row in
          guard case .source(let source) = row.identity, source.kind == .list else { return nil }
          return SavedPlannerList(source: source, name: row.title, archived: row.archived == true)
        }
      case .failed(let reason): alertMessage = reason.message
      default: alertMessage = "Planner could not read its Lists."
      }
    }
    return nil
  }

  func readList(_ identifier: UUID) async -> PlannerListSourceRead? {
    guard let planner, let session else { return nil }
    switch await planner.read(
      session: session, request: .source(.init(kind: .list, id: identifier)))
    {
    case .source(.list(let list)): return list
    case .failed(let reason): alertMessage = reason.message
    default: alertMessage = "Planner could not open this List."
    }
    return nil
  }

  func readLabels(_ kind: SavedLabelKind) async -> [SavedPlannerLabel]? {
    guard let planner, let session else { return nil }
    switch await planner.query(
      PlannerQuery(
        session: session, request: .catalog(.init(sourceKind: kind.sourceKind, archive: .all)))
    )
    {
    case .failed(let reason): alertMessage = reason.message
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
      {
      case .rows(let window):
        return window.rows.compactMap { row in
          guard case .source(let source) = row.identity, source.kind == kind.sourceKind else {
            return nil
          }
          return SavedPlannerLabel(source: source, name: row.title)
        }
      case .failed(let reason): alertMessage = reason.message
      default: alertMessage = "Planner could not read its \(kind.pluralTitle)."
      }
    }
    return nil
  }

  func readLabel(_ selection: SavedLabelSelection) async -> SavedLabelSource? {
    guard let planner, let session else { return nil }
    switch await planner.read(
      session: session, request: .source(.init(kind: selection.kind.sourceKind, id: selection.id)))
    {
    case .source(.category(let category)): return .category(category)
    case .source(.tag(let tag)): return .tag(tag)
    case .failed(let reason): alertMessage = reason.message
    default: alertMessage = "Planner could not open this \(selection.kind.title)."
    }
    return nil
  }

  func readItineraries() async -> [SavedPlannerItinerary]? {
    guard let planner, let session else { return nil }
    switch await planner.query(
      .init(session: session, request: .catalog(.init(sourceKind: .itinerary, archive: .active))))
    {
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
      {
      case .rows(let window):
        return window.rows.compactMap { row in
          guard case .source(let source) = row.identity, source.kind == .itinerary else {
            return nil
          }
          return SavedPlannerItinerary(source: source, title: row.title)
        }
      case .failed(let reason): alertMessage = reason.message
      default: alertMessage = "Planner could not read its Itineraries."
      }
    case .failed(let reason): alertMessage = reason.message
    }
    return nil
  }

  func readItinerary(_ identifier: UUID) async -> PlannerItinerarySourceRead? {
    guard let planner, let session else { return nil }
    switch await planner.read(
      session: session, request: .source(.init(kind: .itinerary, id: identifier)))
    {
    case .source(.itinerary(let itinerary)): return itinerary
    case .failed(let reason): alertMessage = reason.message
    default: alertMessage = "Planner could not open this Itinerary."
    }
    return nil
  }

  func refreshItems() async {
    if let loaded = await readItems(completion: .all, archive: .active) {
      items = loaded
    }
  }

  func readItineraryContents(_ identifier: UUID) async -> SavedItineraryContents? {
    guard let planner, let session else { return nil }
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .itinerary(identifier), completion: .all, archive: .all,
              sort: .init(mode: .manual)))))
    else {
      alertMessage = "Planner could not read this Itinerary's entries."
      return nil
    }
    guard let itinerary = await readItinerary(identifier) else { return nil }
    var listNames: [UUID: String] = [:]
    for reference in itinerary.references {
      guard case .itineraryEntry(_, _, let source) = reference, source.kind == .list,
        listNames[source.id] == nil
      else { continue }
      guard let list = await readList(source.id) else { return nil }
      listNames[source.id] = list.content.name
    }
    /** Reading the window last rejects source/header reads if their history has changed. */
    guard
      case .rows(let window) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
    else {
      alertMessage = "The Itinerary changed while opening. Try again."
      return nil
    }
    var itemsByEntry: [UUID: [SavedItineraryItem]] = [:]
    for row in window.rows {
      guard case .appearance(_, let appearance) = row.identity,
        let selection = SavedItineraryRowSelection(appearance, itineraryId: identifier)
      else {
        alertMessage = "Planner could not resolve this Itinerary's Items."
        return nil
      }
      let entryId: UUID
      switch selection {
      case .direct(let identifier): entryId = identifier
      case .expanded(let identifier, _): entryId = identifier
      }
      itemsByEntry[entryId, default: []].append(.init(id: selection, row: row))
    }
    let entries = itinerary.references.compactMap { reference -> SavedItineraryEntryRows? in
      guard case .itineraryEntry(let entryId, _, let source) = reference else { return nil }
      let items = itemsByEntry[entryId] ?? []
      let title: String
      if source.kind == .list {
        title = listNames[source.id] ?? "List"
      } else {
        title = items.first?.row.title ?? "Item"
      }
      return .init(
        id: entryId, source: source, title: title, items: items)
    }
    return .init(itinerary: itinerary, entries: entries)
  }

  func addItineraryEntry(
    itineraryId: UUID, source: PlannerEntityReference, operationIdentifier: UUID
  ) async -> Bool {
    await executeChange(
      .addItineraryEntry(itineraryId: itineraryId, source: source, placement: .last),
      operationId: operationIdentifier) != nil
  }

  func readItems(
    scope: PlannerItemQuery.Scope = .global, text: String = "",
    completion: PlannerItemQuery.Completion, archive: PlannerItemQuery.Archive,
    categories: PlannerItemQuery.IdentityGroup? = nil, tags: PlannerItemQuery.IdentityGroup? = nil,
    lists: PlannerItemQuery.IdentityGroup? = nil,
    hasAddress: Bool = false, hasLinks: Bool = false,
    sort: PlannerItemQuery.Sort = .init(mode: .title)
  ) async -> [SavedPlannerItem]? {
    guard let planner, let session else { return nil }
    switch await planner.query(
      PlannerQuery(
        session: session,
        request: .items(
          .init(
            scope: scope, text: text, completion: completion, archive: archive,
            categories: categories, tags: tags, lists: lists, hasAddress: hasAddress,
            hasLinks: hasLinks,
            sort: sort))
      ))
    {
    case .failed(let reason): alertMessage = reason.message
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
      {
      case .rows(let window):
        var loadedItems: [SavedPlannerItem] = []
        for row in window.rows {
          guard case .source(let source) = row.identity, source.kind == .item else {
            alertMessage = "Planner could not resolve its Items."
            return nil
          }
          loadedItems.append(SavedPlannerItem(id: source.id, row: row))
        }
        return loadedItems
      case .failed(let reason): alertMessage = reason.message
      default: alertMessage = "Planner could not read its Items."
      }
    }
    return nil
  }

  func readItem(_ identifier: UUID) async -> PlannerItemSourceRead? {
    guard let planner, let session else { return nil }
    switch await planner.read(
      session: session, request: .source(.init(kind: .item, id: identifier)))
    {
    case .source(.item(let item)): return item
    case .failed(let reason): alertMessage = reason.message
    default: alertMessage = "Planner could not open this Item."
    }
    return nil
  }

  func readAppearance(_ appearance: PlannerAppearance) async -> PlannerAppearanceRead? {
    guard let planner, let session else { return nil }
    switch await planner.read(session: session, request: .appearance(appearance)) {
    case .appearance(let item): return item
    case .failed(let reason): alertMessage = reason.message
    default: alertMessage = "Planner could not open this List entry."
    }
    return nil
  }

  func createItem(title: String, notes: String, operationId: UUID) async -> PlannerEntityReference?
  {
    guard
      let applied = await executeChange(
        .createItem(content: .init(title: title, notes: notes.isEmpty ? nil : notes)),
        operationId: operationId)
    else { return nil }
    await refreshItems()
    return applied.generated.first { $0.kind == .item }
  }

  func editItem(
    _ item: PlannerItemSourceRead, title: String, subtitle: String, notes: String,
    links: [PlannerLinkInput],
    location: PlannerOwnedLocation?,
    categoryIdentifiers: Set<UUID>, tagIdentifiers: Set<UUID>,
    operationIdentifier: UUID
  ) async -> Bool {
    let titleChange: PlannerFieldChange<String>
    if title == item.content.title {
      titleChange = .unchanged
    } else {
      titleChange = .set(title)
    }
    let subtitleChange: PlannerFieldChange<String>
    if subtitle == (item.content.subtitle ?? "") {
      subtitleChange = .unchanged
    } else if subtitle.isEmpty {
      subtitleChange = .clear
    } else {
      subtitleChange = .set(subtitle)
    }
    let notesChange: PlannerFieldChange<String>
    if notes == (item.content.notes ?? "") {
      notesChange = .unchanged
    } else if notes.isEmpty {
      notesChange = .clear
    } else {
      notesChange = .set(notes)
    }
    let linksChange: PlannerFieldChange<[PlannerLinkInput]>
    if links == item.content.links.map(\.editInput) {
      linksChange = .unchanged
    } else {
      linksChange = .set(links)
    }
    let locationChange: PlannerFieldChange<PlannerOwnedLocation>
    if location == item.content.location {
      locationChange = .unchanged
    } else if let location {
      locationChange = .set(location)
    } else {
      locationChange = .clear
    }
    let categoryChange: PlannerFieldChange<Set<UUID>>
    if categoryIdentifiers == item.content.categoryIds {
      categoryChange = .unchanged
    } else {
      categoryChange = .set(categoryIdentifiers)
    }
    let tagChange: PlannerFieldChange<Set<UUID>>
    if tagIdentifiers == item.content.tagIds {
      tagChange = .unchanged
    } else {
      tagChange = .set(tagIdentifiers)
    }
    return await executeChange(
      .editItem(
        sourceId: item.source.id,
        changes: .init(
          title: titleChange, subtitle: subtitleChange, notes: notesChange,
          location: locationChange, links: linksChange, categoryIds: categoryChange,
          tagIds: tagChange),
        expectedFieldHashes: item.fieldHashes), operationId: operationIdentifier) != nil
  }

  func setItemCompletion(_ identifier: UUID, done: Bool) async -> Bool {
    guard
      await executeChange(
        .setCompletion(scope: .globalItem(itemId: identifier), done: done), operationId: UUID())
        != nil
    else { return false }
    await refreshItems()
    return true
  }

  func setItemArchived(_ identifier: UUID, archived: Bool) async -> Bool {
    guard
      await executeChange(
        .setArchive(source: .init(kind: .item, id: identifier), archived: archived),
        operationId: UUID()) != nil
    else { return false }
    await refreshItems()
    return true
  }

  func setListArchived(_ identifier: UUID, archived: Bool) async -> Bool {
    guard
      await executeChange(
        .setArchive(source: .init(kind: .list, id: identifier), archived: archived),
        operationId: UUID()) != nil
    else { return false }
    await refreshLists()
    return true
  }

  func addMembership(itemId: UUID, listId: UUID, operationId: UUID) async -> Bool {
    await executeChange(
      .addMembership(itemId: itemId, listId: listId, placement: .last), operationId: operationId)
      != nil
  }

  func removeMembership(_ membershipIdentifier: UUID, listIdentifier: UUID) async -> Bool {
    await executeChange(
      .removeMembership(listId: listIdentifier, membershipId: membershipIdentifier),
      operationId: UUID()) != nil
  }

  func moveMembership(
    _ membershipIdentifier: UUID, listIdentifier: UUID, destinationListIdentifier: UUID,
    operationIdentifier: UUID
  ) async -> Bool {
    await executeChange(
      .moveMembership(
        listId: listIdentifier, membershipId: membershipIdentifier,
        destinationListId: destinationListIdentifier, placement: .last),
      operationId: operationIdentifier) != nil
  }

  func setAppearanceCompletion(_ appearance: PlannerAppearance, done: Bool) async -> Bool {
    await executeChange(
      .setCompletion(scope: .appearance(appearance), done: done), operationId: UUID()) != nil
  }

  func prepareBulkCompletion(scope: PlannerBulkScope, done: Bool) async -> PlannerReview? {
    guard let planner, let session, canCreate else { return nil }
    switch await planner.prepareReview(
      session: session, command: .setBulkCompletion(scope: scope, done: done))
    {
    case .reviewed(let review): return review
    case .failed(let reason):
      alertMessage = reason.message
      return nil
    }
  }

  func applyBulkCompletion(_ review: PlannerReview, operationIdentifier: UUID) async
    -> SavedBulkCompletionResult
  {
    guard let planner, let session, canCreate else { return .failed }
    isSaving = true
    alertMessage = nil
    defer { isSaving = false }
    let result = await planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    if case .rejected(let reason) = result.outcome, reason.code == "staleReview" {
      switch await planner.prepareReview(session: session, command: review.command) {
      case .reviewed(let refreshed): return .reviewChanged(refreshed)
      case .failed(let failure):
        alertMessage = failure.message
        return .failed
      }
    }
    guard handleChangeResult(result) != nil else { return .failed }
    return .applied
  }

  func reorderMembership(_ membershipId: UUID, listId: UUID, placement: PlannerPlacement) async
    -> Bool
  {
    await executeChange(
      .reorderMembership(listId: listId, membershipId: membershipId, placement: placement),
      operationId: UUID()) != nil
  }

  private func executeChange(
    _ command: PlannerCommand, operationId: UUID
  ) async -> PlannerAppliedResult? {
    guard let planner, let session, canCreate else { return nil }
    isSaving = true
    defer { isSaving = false }
    let result = await planner.execute(
      PlannerOperation(operationId: operationId, session: session, command: command))
    return handleChangeResult(result)
  }

  private func handleChangeResult(_ result: PlannerOperationResult) -> PlannerAppliedResult? {
    switch result.outcome {
    case .rejected(let reason):
      alertMessage = reason.message
      return nil
    case .unverified:
      recoveryBlocked = true
      alertMessage = "The change could not be verified. Further changes need recovery review."
      return nil
    case .applied(let applied, let recovery):
      changeRevision = UUID()
      if case .incomplete = recovery {
        recoveryBlocked = true
        alertMessage =
          "The change was saved, but its recovery copy is incomplete. Further changes are paused."
      }
      return applied
    }
  }

  func createLabel(_ kind: SavedLabelKind, name: String, operationIdentifier: UUID) async
    -> PlannerEntityReference?
  {
    let command: PlannerCommand
    switch kind {
    case .category: command = .createCategory(content: .init(name: name))
    case .tag: command = .createTag(content: .init(name: name))
    }
    let result = await executeChange(command, operationId: operationIdentifier)
    return result?.generated.first { $0.kind == kind.sourceKind }
  }

  func createItinerary(
    title: String, notes: String, operationIdentifier: UUID
  ) async -> PlannerEntityReference? {
    let result = await executeChange(
      .createItinerary(content: .init(title: title, notes: notes.isEmpty ? nil : notes)),
      operationId: operationIdentifier)
    return result?.generated.first { $0.kind == .itinerary }
  }

  func editItinerary(
    _ itinerary: PlannerItinerarySourceRead, title: String, notes: String,
    operationIdentifier: UUID
  ) async -> Bool {
    let titleChange: PlannerFieldChange<String> =
      title == itinerary.content.title ? .unchanged : .set(title)
    let notesChange: PlannerFieldChange<String>
    if notes == (itinerary.content.notes ?? "") {
      notesChange = .unchanged
    } else {
      notesChange = notes.isEmpty ? .clear : .set(notes)
    }
    return await executeChange(
      .editItinerary(
        sourceId: itinerary.source.id, changes: .init(title: titleChange, notes: notesChange),
        expectedFieldHashes: itinerary.fieldHashes), operationId: operationIdentifier) != nil
  }

  func renameLabel(
    _ label: SavedLabelSource, name: String, operationIdentifier: UUID
  ) async -> Bool {
    let command: PlannerCommand
    switch label {
    case .category(let category):
      command = .editCategory(
        sourceId: category.source.id, changes: .init(name: .set(name)),
        expectedFieldHashes: category.fieldHashes)
    case .tag(let tag):
      command = .editTag(
        sourceId: tag.source.id, changes: .init(name: .set(name)),
        expectedFieldHashes: tag.fieldHashes)
    }
    return await executeChange(command, operationId: operationIdentifier) != nil
  }

  func createList(name: String, operationId: UUID) async -> PlannerEntityReference? {
    guard let planner, let session, canCreate else { return nil }
    isSaving = true
    defer { isSaving = false }
    let result = await planner.execute(
      PlannerOperation(
        operationId: operationId, session: session, command: .createList(content: .init(name: name))
      ))
    switch result.outcome {
    case .rejected(let reason):
      alertMessage = reason.message
      return nil
    case .unverified:
      recoveryBlocked = true
      alertMessage = "The List's save could not be verified. Further changes need recovery review."
      return nil
    case .applied(let applied, let recovery):
      changeRevision = UUID()
      if case .incomplete = recovery {
        recoveryBlocked = true
        alertMessage =
          "The List was saved, but its recovery copy is incomplete. Further changes are paused."
      }
      await refreshLists()
      return applied.generated.first { $0.kind == .list }
    }
  }

  func readListItems(
    _ identifier: UUID, text: String = "", completion: PlannerItemQuery.Completion,
    archive: PlannerItemQuery.Archive,
    categories: PlannerItemQuery.IdentityGroup? = nil, tags: PlannerItemQuery.IdentityGroup? = nil,
    lists: PlannerItemQuery.IdentityGroup? = nil,
    hasAddress: Bool = false, hasLinks: Bool = false,
    sort: PlannerItemQuery.Sort = .init(mode: .manual)
  ) async -> [SavedPlannerItem]? {
    guard let planner, let session else { return nil }
    switch await planner.query(
      PlannerQuery(
        session: session,
        request: .items(
          .init(
            scope: .list(identifier), text: text, completion: completion, archive: archive,
            categories: categories, tags: tags, lists: lists, hasAddress: hasAddress,
            hasLinks: hasLinks,
            sort: sort))))
    {
    case .failed(let reason): alertMessage = reason.message
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
      {
      case .rows(let window):
        var items: [SavedPlannerItem] = []
        for row in window.rows {
          guard case .appearance(_, .listMembership(let listId, let membershipId)) = row.identity,
            listId == identifier
          else {
            alertMessage = "Planner could not resolve this List's Items."
            return nil
          }
          items.append(SavedPlannerItem(id: membershipId, row: row))
        }
        return items
      case .failed(let reason): alertMessage = reason.message
      default: alertMessage = "Planner could not read this List's Items."
      }
    }
    return nil
  }
}
