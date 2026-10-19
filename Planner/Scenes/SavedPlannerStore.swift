import Combine
import CryptoKit
import Foundation
import Observation
import PlannerCore

struct SavedPlannerList: Identifiable {
  let source: PlannerEntityReference
  let name: String
  let archived: Bool
  let manualEstimate: PlannerEstimate?
  let estimates: PlannerContainerEstimates
  var id: UUID { source.id }
}

struct SavedPlannerItem: Identifiable {
  let id: UUID
  let row: PlannerRowRead
  let rowPresentation: PlannerRowPresentationContext?
}

struct SavedPlannerLabel: Identifiable {
  let source: PlannerEntityReference
  let name: String
  var id: UUID { source.id }
}

struct SavedPlannerItinerary: Identifiable {
  let source: PlannerEntityReference
  let title: String
  let archived: Bool
  let manualEstimate: PlannerEstimate?
  let estimates: PlannerContainerEstimates
  var id: UUID { source.id }
}

struct SavedSourceDeletionNotice {
  let namespace: String
  let source: PlannerEntityReference
  let review: PlannerReview
}

enum SavedReviewedChangeResult {
  case applied(PlannerAppliedResult)
  case reviewChanged(PlannerReview)
  case failed
}

@MainActor @Observable
final class SavedPlannerStore {
  private let planner: PlannerCore.Planner?
  private var session: PlannerDatasetSession?
  private(set) var isOpening = false
  private(set) var isSaving = false
  private(set) var recoveryBlocked = false
  private(set) var recoveryStatusTitle = "Checking local recovery"
  private(set) var recoveryStatusFailure: String?
  private(set) var isCheckingRecovery = false
  private(set) var isRetryingRecovery = false
  private(set) var incompleteRecoveryOperationIdentifiers: [UUID] = []
  private var requiresRecoveryReview = false
  private(set) var changeRevision = UUID()
  @ObservationIgnored let sourceDeletions = PassthroughSubject<SavedSourceDeletionNotice, Never>()
  private(set) var openingFailure: String?
  var alertMessage: String?
  var isReady: Bool { session != nil && !isOpening }
  var canCreate: Bool { isReady && !isSaving && !isCheckingRecovery && !recoveryBlocked }
  var canRetryRecovery: Bool {
    isReady && !isSaving && !isCheckingRecovery && !requiresRecoveryReview
      && !incompleteRecoveryOperationIdentifiers.isEmpty
  }
  var currentDatasetIdentifier: UUID? { session?.datasetId }

  var devicePreferenceNamespace: String? {
    guard let session else { return nil }
    let identity = session.datasetId.uuidString + ":" + session.ownershipBinding
    return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  init(configuration: PlannerStorageConfiguration) {
    planner = PlannerCore.Planner(configuration: configuration)
  }

  init(planner: PlannerCore.Planner) {
    self.planner = planner
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
      await refreshRecoveryStatus()
    case .unavailable(let reason): openingFailure = reason.message
    case .mainAppSetupRequired:
      openingFailure = "Open Planner once to set up its shared data before using Share."
    case .mainAppMigrationRequired:
      openingFailure = "Open Planner to update its shared data before using Share."
    }
  }

  func refreshRecoveryStatus() async {
    guard let planner, let session, !isCheckingRecovery else { return }
    isCheckingRecovery = true
    defer { isCheckingRecovery = false }
    switch await planner.read(session: session, request: .status) {
    case .status(let status):
      switch status.recovery {
      case .known(let checkpoint, let incompleteIdentifiers, let mutationBlocked):
        incompleteRecoveryOperationIdentifiers = incompleteIdentifiers
        recoveryBlocked = mutationBlocked || requiresRecoveryReview
        recoveryStatusFailure = nil
        if requiresRecoveryReview {
          recoveryStatusTitle = "Recovery review needed"
        } else if mutationBlocked {
          recoveryStatusTitle = "Recovery copy incomplete"
        } else {
          recoveryStatusTitle = checkpoint == nil ? "No saved changes yet" : "Saved on this device"
        }
      case .unavailable(let reason): showUnavailableRecovery(reason.message)
      }
    case .failed(let reason): showUnavailableRecovery(reason.message)
    default: showUnavailableRecovery("Planner could not read its local recovery evidence.")
    }
  }

  func retryIncompleteRecovery() async {
    guard let planner, let session, canRetryRecovery else { return }
    let operationIdentifiers = incompleteRecoveryOperationIdentifiers
    isSaving = true
    isRetryingRecovery = true
    alertMessage = nil
    recoveryStatusFailure = nil
    defer {
      isSaving = false
      isRetryingRecovery = false
    }
    var retryFailure: String?
    for identifier in operationIdentifiers {
      let result = await planner.retryRecovery(session: session, operationId: identifier)
      switch result.outcome {
      case .applied(_, .complete): continue
      case .applied(_, .incomplete(let reason)), .rejected(let reason):
        retryFailure = reason.message
      case .unverified:
        requiresRecoveryReview = true
        retryFailure = "The change needs recovery review before it can be acknowledged."
      }
      break
    }
    await refreshRecoveryStatus()
    if recoveryBlocked, let retryFailure { recoveryStatusFailure = retryFailure }
  }

  private func showUnavailableRecovery(_ message: String) {
    recoveryBlocked = true
    recoveryStatusTitle = "Recovery status unavailable"
    recoveryStatusFailure = message
  }

  func exportBackup() async throws -> Data {
    guard let planner, let session else { throw CocoaError(.fileReadUnknown) }
    switch await planner.exportData(session: session) {
    case .exported(let data): return data
    case .failed(let reason): throw reason
    }
  }

  func readRecoveryCopies() async throws -> [PlannerRecoveryView] {
    guard let planner else { throw CocoaError(.fileReadUnknown) }
    switch await planner.inspectRecovery(request: .namespaces) {
    case .listedNamespaces(let copies): return copies
    case .failed(let reason): throw reason
    default: throw CocoaError(.fileReadUnknown)
    }
  }

  func selectRecoveryCopy(_ request: PlannerRecoveryRequest) async throws
    -> PlannerRecoverySelection
  {
    guard let planner else { throw CocoaError(.fileReadUnknown) }
    switch await planner.inspectRecovery(request: request) {
    case .selected(let selection): return selection
    case .failed(let reason): throw reason
    default: throw CocoaError(.fileReadUnknown)
    }
  }

  func decodeBackup(_ data: Data) async throws -> PlannerDecodedBackup {
    guard let planner else { throw CocoaError(.fileReadUnknown) }
    let decoded = await Task.detached { planner.decodeImport(data) }.value
    try Task.checkCancellation()
    switch decoded {
    case .decoded(let backup): return backup
    case .invalid(let reason): throw reason
    }
  }

  func prepareBackupImport(
    _ backup: PlannerDecodedBackup, mode: PlannerImportMode, restoreDeletedData: Bool
  ) async throws -> PlannerReview {
    try await prepareDataImportReview(
      command: .applyImport(backup: backup, mode: mode, restoreDeletedData: restoreDeletedData))
  }

  func prepareRecoveryRestoration(_ selection: PlannerRecoverySelection, mode: PlannerImportMode)
    async throws -> PlannerReview
  {
    try await prepareDataImportReview(command: .restoreRecovery(selection: selection, mode: mode))
  }

  private func prepareDataImportReview(command: PlannerCommand) async throws -> PlannerReview {
    guard let planner, let session, canCreate else {
      throw CocoaError(
        .fileWriteUnknown,
        userInfo: [NSLocalizedDescriptionKey: "Planner is not ready to import data."])
    }
    switch await planner.prepareReview(
      session: session, command: command)
    {
    case .reviewed(let review): return review
    case .failed(let reason): throw reason
    }
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

  func readSchedule(_ identifier: UUID) async -> PlannerReadResult? {
    guard let planner, let session else { return nil }
    return await planner.read(
      session: session, request: .source(.init(kind: .schedule, id: identifier)))
  }

  func readCalendarEntries(query: PlannerCalendarQuery) async -> [PlannerCalendarEntry]? {
    guard let planner, let session else { return nil }
    while !Task.isCancelled {
      let result = await planner.query(.init(session: session, request: .calendar(query)))
      guard !Task.isCancelled else { return nil }
      guard case .snapshot(let snapshot) = result else {
        if case .failed(let reason) = result { alertMessage = reason.message }
        return nil
      }
      var entries: [PlannerCalendarEntry] = []
      var offset: Int64 = 0
      var needsRefresh = false
      while offset < snapshot.matchingCount {
        let result = await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: offset, limit: 64))
        guard !Task.isCancelled else { return nil }
        switch result {
        case .calendarRows(let page):
          guard !page.rows.isEmpty else {
            alertMessage = "Planner could not read the complete Calendar period."
            return nil
          }
          entries.append(contentsOf: page.rows)
          offset += Int64(page.rows.count)
        case .failed(let reason):
          if reason.code == "staleSnapshot" {
            needsRefresh = true
          } else {
            alertMessage = reason.message
            return nil
          }
        default:
          alertMessage = "Planner could not read its Calendar schedules."
          return nil
        }
        if needsRefresh { break }
      }
      if needsRefresh { continue }
      return entries
    }
    return nil
  }

  func createSchedule(
    source: PlannerEntityReference, form: PlannerScheduleForm, operationIdentifier: UUID
  ) async -> Bool {
    await executeChange(
      .createSchedule(
        source: source,
        form: form),
      operationId: operationIdentifier) != nil
  }

  func removeSchedule(_ identifier: UUID, operationIdentifier: UUID) async {
    _ = await executeChange(
      .removeSchedule(scheduleId: identifier), operationId: operationIdentifier)
  }

  func editSchedule(
    _ schedule: PlannerScheduleSourceRead, form: PlannerScheduleForm,
    operationIdentifier: UUID
  ) async -> Bool {
    await executeChange(
      .editSchedule(
        scheduleId: schedule.source.id, changes: .init(form: form),
        expectedFieldHashes: schedule.fieldHashes), operationId: operationIdentifier) != nil
  }

  func addItineraryEntry(
    itineraryId: UUID, source: PlannerEntityReference, operationIdentifier: UUID
  ) async -> Bool {
    await executeChange(
      .addItineraryEntry(itineraryId: itineraryId, source: source, placement: .last),
      operationId: operationIdentifier) != nil
  }

  func reorderItineraryEntry(
    _ entryIdentifier: UUID, itineraryIdentifier: UUID, placement: PlannerPlacement
  ) async -> Bool {
    await executeChange(
      .reorderItineraryEntry(
        itineraryId: itineraryIdentifier, entryId: entryIdentifier, placement: placement),
      operationId: UUID()) != nil
  }

  func removeItineraryEntry(_ entryIdentifier: UUID, itineraryIdentifier: UUID) async
    -> PlannerOperationResult?
  {
    await executeChangeResponse(
      .removeItineraryEntry(itineraryId: itineraryIdentifier, entryId: entryIdentifier),
      operationId: UUID())
  }

  func makeItemWindow() -> SavedItemWindow? {
    guard let planner, let session else { return nil }
    return SavedItemWindow(planner: planner, session: session)
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

  func createItem(_ draft: SavedNewItemDraft) async -> PlannerAppliedResult? {
    guard devicePreferenceNamespace == draft.namespace else {
      alertMessage = "This draft belongs to another dataset. Discard it to create an Item here."
      return nil
    }
    guard let planner, let session, canCreate else { return nil }
    let command = PlannerCommand.createItem(content: draft.content, listId: draft.listIdentifier)
    let applied: PlannerAppliedResult?
    if let listIdentifier = draft.listIdentifier {
      let review: PlannerReview
      switch await planner.prepareReview(session: session, command: command) {
      case .reviewed(let prepared): review = prepared
      case .failed(let reason):
        alertMessage = reason.message
        return nil
      }
      guard let destination = await readList(listIdentifier),
        devicePreferenceNamespace == draft.namespace
      else { return nil }
      guard let originalNameHash = draft.destination?.fieldHashes[.name],
        destination.fieldHashes[.name] == originalNameHash
      else {
        draft.proposedDestination = destination
        return nil
      }
      switch await applyReviewedChange(review, operationIdentifier: draft.id) {
      case .applied(let result): applied = result
      case .reviewChanged:
        guard let destination = await readList(listIdentifier),
          devicePreferenceNamespace == draft.namespace
        else { return nil }
        draft.proposedDestination = destination
        return nil
      case .failed: return nil
      }
    } else {
      applied = await executeChange(command, operationId: draft.id)
    }
    return applied
  }

  func editItem(
    _ item: PlannerItemSourceRead, title: String, subtitle: String, notes: String,
    estimate: PlannerEstimate?,
    links: [PlannerLinkInput],
    location: PlannerOwnedLocation?,
    categoryIdentifiers: Set<UUID>, tagIdentifiers: Set<UUID>,
    operationIdentifier: UUID
  ) async -> PlannerOperationResult? {
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
    let estimateChange: PlannerFieldChange<PlannerEstimate>
    if estimate == item.content.estimate {
      estimateChange = .unchanged
    } else if let estimate {
      estimateChange = .set(estimate)
    } else {
      estimateChange = .clear
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
    return await executeChangeResponse(
      .editItem(
        sourceId: item.source.id,
        changes: .init(
          title: titleChange, subtitle: subtitleChange, notes: notesChange,
          location: locationChange, estimate: estimateChange, links: linksChange,
          categoryIds: categoryChange,
          tagIds: tagChange),
        expectedFieldHashes: item.fieldHashes), operationId: operationIdentifier)
  }

  func setItemCompletion(_ identifier: UUID, done: Bool) async -> Bool {
    guard
      await executeChange(
        .setCompletion(scope: .globalItem(itemId: identifier), done: done), operationId: UUID())
        != nil
    else { return false }
    return true
  }

  func setItemArchived(_ identifier: UUID, archived: Bool) async -> Bool {
    guard
      await executeChange(
        .setArchive(source: .init(kind: .item, id: identifier), archived: archived),
        operationId: UUID()) != nil
    else { return false }
    return true
  }

  func setListArchived(_ identifier: UUID, archived: Bool) async -> Bool {
    guard
      await executeChange(
        .setArchive(source: .init(kind: .list, id: identifier), archived: archived),
        operationId: UUID()) != nil
    else { return false }
    return true
  }

  func setItineraryArchived(_ identifier: UUID, archived: Bool) async -> Bool {
    await executeChange(
      .setArchive(source: .init(kind: .itinerary, id: identifier), archived: archived),
      operationId: UUID()) != nil
  }

  func addMembership(itemId: UUID, listId: UUID, operationId: UUID) async -> Bool {
    await executeChange(
      .addMembership(itemId: itemId, listId: listId, placement: .last), operationId: operationId)
      != nil
  }

  func removeMembership(_ membershipIdentifier: UUID, listIdentifier: UUID) async
    -> PlannerOperationResult?
  {
    await executeChangeResponse(
      .removeMembership(listId: listIdentifier, membershipId: membershipIdentifier),
      operationId: UUID())
  }

  func restoreAssociation(
    _ snapshot: PlannerAssociationUndoSnapshot, operationIdentifier: UUID
  ) async -> PlannerOperationResult? {
    await executeChangeResponse(
      .restoreAssociation(snapshot: snapshot), operationId: operationIdentifier)
  }

  func moveMembership(
    _ membershipIdentifier: UUID, listIdentifier: UUID, destinationListIdentifier: UUID,
    operationIdentifier: UUID
  ) async -> PlannerOperationResult? {
    await executeChangeResponse(
      .moveMembership(
        listId: listIdentifier, membershipId: membershipIdentifier,
        destinationListId: destinationListIdentifier, placement: .last),
      operationId: operationIdentifier)
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

  func prepareSourceDeletion(_ source: PlannerEntityReference) async -> PlannerReview? {
    guard let planner, let session, canCreate else { return nil }
    alertMessage = nil
    switch await planner.prepareReview(
      session: session, command: .deleteSource(source: source))
    {
    case .reviewed(let review): return review
    case .failed(let reason):
      alertMessage = reason.message
      return nil
    }
  }

  func applyReviewedChange(_ review: PlannerReview, operationIdentifier: UUID) async
    -> SavedReviewedChangeResult
  {
    guard let planner, let session, canCreate else { return .failed }
    let namespace = devicePreferenceNamespace
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
    if case .applied = result.outcome, case .deleteSource(let source) = review.command,
      let namespace
    {
      sourceDeletions.send(.init(namespace: namespace, source: source, review: review))
    }
    guard let applied = await handleChangeResult(result) else { return .failed }
    return .applied(applied)
  }

  func prepareCapture(text: String) async -> PlannerCaptureDraftRead? {
    await prepareCapture(input: .direct([.text(text)]))
  }

  func prepareCapture(input: PlannerCaptureInput) async -> PlannerCaptureDraftRead? {
    guard let planner, let session, canCreate else { return nil }
    alertMessage = nil
    switch await planner.prepareCapture(session: session, input: input) {
    case .draft(let draft): return draft
    case .rejected(let reason): alertMessage = reason.message
    }
    return nil
  }

  func updateCapture(_ draft: PlannerCaptureDraftRead, edit: PlannerCaptureEdit) async
    -> PlannerCaptureDraftRead?
  {
    guard let planner, let session, canCreate else { return nil }
    switch await planner.updateCapture(
      session: session, draftId: draft.draftId, generation: draft.generation, edit: edit)
    {
    case .draft(let updated): return updated
    case .rejected(let reason): alertMessage = reason.message
    }
    return nil
  }

  func lookupCapture(_ draft: PlannerCaptureDraftRead, linkIdentifier: UUID) async
    -> PlannerCaptureDraftRead?
  {
    guard let planner, let session, canCreate else { return nil }
    switch await planner.lookupCapture(
      session: session, draftId: draft.draftId, generation: draft.generation,
      linkId: linkIdentifier)
    {
    case .draft(let updated): return updated
    case .rejected(let reason):
      if !Task.isCancelled, reason.code != "captureDraftUnavailable" {
        alertMessage = reason.message
      }
    }
    return nil
  }

  func discardCapture(_ draft: PlannerCaptureDraftRead) async {
    guard let planner, let session else { return }
    _ = await planner.cancelCapture(
      session: session, draftId: draft.draftId, generation: draft.generation)
  }

  func reviewCapture(
    _ draft: PlannerCaptureDraftRead, choice: PlannerCaptureChoice, listIdentifiers: Set<UUID>
  ) async -> PlannerReview? {
    guard let planner, let session, canCreate else { return nil }
    switch await planner.prepareReview(
      session: session,
      command: .applyCapture(
        draftId: draft.draftId, draftGeneration: draft.generation,
        choice: choice, listIds: listIdentifiers))
    {
    case .reviewed(let review): return review
    case .failed(let reason): alertMessage = reason.message
    }
    return nil
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
    guard let result = await executeChangeResponse(command, operationId: operationId),
      case .applied(let applied, _) = result.outcome
    else { return nil }
    return applied
  }

  private func executeChangeResponse(
    _ command: PlannerCommand, operationId: UUID
  ) async -> PlannerOperationResult? {
    guard let planner, let session, canCreate else { return nil }
    isSaving = true
    defer { isSaving = false }
    let result = await planner.execute(
      PlannerOperation(operationId: operationId, session: session, command: command))
    _ = await handleChangeResult(result)
    return result
  }

  private func handleChangeResult(_ result: PlannerOperationResult) async -> PlannerAppliedResult? {
    switch result.outcome {
    case .rejected(let reason):
      alertMessage = reason.message
      if reason.code == "mutationBlocked" { await refreshRecoveryStatus() }
      return nil
    case .unverified:
      requiresRecoveryReview = true
      recoveryBlocked = true
      recoveryStatusTitle = "Recovery review needed"
      alertMessage = "The change could not be verified. Further changes need recovery review."
      return nil
    case .applied(let applied, let recovery):
      changeRevision = UUID()
      if case .incomplete(let reason) = recovery {
        recoveryBlocked = true
        incompleteRecoveryOperationIdentifiers = [result.operationId]
        recoveryStatusTitle = "Recovery copy incomplete"
        recoveryStatusFailure = reason.message
        alertMessage =
          "Your change is in local storage, but its recovery copy is incomplete. Further changes are paused."
      } else {
        recoveryStatusTitle = "Saved on this device"
        recoveryStatusFailure = nil
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
    title: String, notes: String, location: PlannerOwnedLocation?, links: [PlannerLinkInput],
    categoryIdentifiers: Set<UUID>, tagIdentifiers: Set<UUID>, manualEstimate: PlannerEstimate?,
    operationIdentifier: UUID
  ) async -> PlannerEntityReference? {
    let result = await executeChange(
      .createItinerary(
        content: .init(
          title: title, notes: notes.isEmpty ? nil : notes,
          location: location, links: links,
          categoryIds: categoryIdentifiers, tagIds: tagIdentifiers, manualEstimate: manualEstimate)),
      operationId: operationIdentifier)
    return result?.generated.first { $0.kind == .itinerary }
  }

  func editItinerary(
    _ itinerary: PlannerItinerarySourceRead, title: String, notes: String,
    location: PlannerOwnedLocation?, links: [PlannerLinkInput],
    categoryIdentifiers: Set<UUID>, tagIdentifiers: Set<UUID>, manualEstimate: PlannerEstimate?,
    operationIdentifier: UUID
  ) async -> PlannerOperationResult? {
    let titleChange: PlannerFieldChange<String> =
      title == itinerary.content.title ? .unchanged : .set(title)
    let notesChange: PlannerFieldChange<String>
    if notes == (itinerary.content.notes ?? "") {
      notesChange = .unchanged
    } else {
      notesChange = notes.isEmpty ? .clear : .set(notes)
    }
    let categoryChange: PlannerFieldChange<Set<UUID>>
    if categoryIdentifiers == itinerary.content.categoryIds {
      categoryChange = .unchanged
    } else {
      categoryChange = .set(categoryIdentifiers)
    }
    let tagChange: PlannerFieldChange<Set<UUID>>
    if tagIdentifiers == itinerary.content.tagIds {
      tagChange = .unchanged
    } else {
      tagChange = .set(tagIdentifiers)
    }
    let locationChange: PlannerFieldChange<PlannerOwnedLocation>
    if location == itinerary.content.location {
      locationChange = .unchanged
    } else if let location {
      locationChange = .set(location)
    } else {
      locationChange = .clear
    }
    let linksChange: PlannerFieldChange<[PlannerLinkInput]>
    if links == itinerary.content.links.map(\.editInput) {
      linksChange = .unchanged
    } else {
      linksChange = .set(links)
    }
    let estimateChange: PlannerFieldChange<PlannerEstimate>
    if manualEstimate == itinerary.content.manualEstimate {
      estimateChange = .unchanged
    } else if let manualEstimate {
      estimateChange = .set(manualEstimate)
    } else {
      estimateChange = .clear
    }
    return await executeChangeResponse(
      .editItinerary(
        sourceId: itinerary.source.id,
        changes: .init(
          title: titleChange, notes: notesChange, location: locationChange, links: linksChange,
          categoryIds: categoryChange, tagIds: tagChange, manualEstimate: estimateChange),
        expectedFieldHashes: itinerary.fieldHashes), operationId: operationIdentifier)
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

  func createList(name: String, manualEstimate: PlannerEstimate?, operationId: UUID) async
    -> PlannerEntityReference?
  {
    guard let planner, let session, canCreate else { return nil }
    isSaving = true
    defer { isSaving = false }
    let result = await planner.execute(
      PlannerOperation(
        operationId: operationId, session: session,
        command: .createList(content: .init(name: name, manualEstimate: manualEstimate))
      ))
    guard let applied = await handleChangeResult(result) else { return nil }
    return applied.generated.first { $0.kind == .list }
  }

  func editList(
    _ list: PlannerListSourceRead, name: String, manualEstimate: PlannerEstimate?, operationId: UUID
  ) async -> Bool {
    let nameChange: PlannerFieldChange<String> = name == list.content.name ? .unchanged : .set(name)
    let estimateChange: PlannerFieldChange<PlannerEstimate>
    if manualEstimate == list.content.manualEstimate {
      estimateChange = .unchanged
    } else if let manualEstimate {
      estimateChange = .set(manualEstimate)
    } else {
      estimateChange = .clear
    }
    return await executeChange(
      .editList(
        sourceId: list.source.id,
        changes: .init(name: nameChange, manualEstimate: estimateChange),
        expectedFieldHashes: list.fieldHashes), operationId: operationId) != nil
  }

}
