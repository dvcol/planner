import Foundation
import SwiftData
import Testing

@testable import PlannerCore

#if os(macOS)
  import Darwin
#endif

struct NativeSourceRestorationMaintenanceTests {
  @Test(arguments: [false, true])
  func mixedItemOwnedContentsSurvivePublicationFailureAndKeepIndependentAppearances(
    recoveryFailure: Bool
  ) async throws {
    try await checkMixedOwnedItem(recoveryFailure: recoveryFailure, nativeSaveFailure: false)
  }

  private func checkMixedOwnedItem(recoveryFailure: Bool, nativeSaveFailure: Bool) async throws {
    let fixture = try await SourceRestorationFixture.makeWithEntries(true)
    guard
      case .source(.item(let initial)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .editItem(
            sourceId: fixture.source.id,
            changes: .init(
              notes: .set("Winning Item notes"),
              links: .set([.init(originalUrl: "https://example.com/winner", label: "Guide A")]),
              categoryIds: .set([UUID(uuidString: "00000000-0000-4000-8000-000000000501")!]),
              tagIds: .set([UUID(uuidString: "00000000-0000-4000-8000-000000000601")!])),
            expectedFieldHashes: initial.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createSchedule(
            source: fixture.source,
            form: .allDay(start: .init(year: 2026, month: 10, day: 26), end: nil)))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session),
      case .source(.item(let winner)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    let originalFiles = try fixture.files()
    let originalControl = try Data(contentsOf: fixture.configuration.controlURL)
    let originalReceipts = try fixture.envelope()["receipts"] as? NSArray
    try await fixture.deliverCandidateWithEntries(true)
    try await fixture.addMixedMetadataToLosingSource()
    #if os(macOS)
      var unverifiedMaintenance: UUID?
      var unverifiedFiles: [String: Data]?
      if nativeSaveFailure {
        let originalLinks = try await fixture.rawOwnedLinkData()
        let originalSchedules = try await fixture.rawScheduleData()
        let originalLabels = try await fixture.rawLabelData()
        let originalEntries = try await fixture.rawEntryData()
        let originalExpanded = try await fixture.rawExpandedData()
        let originalHistory = try await fixture.rawCompletionAuthorityData()
        let originalLifetimes = try await fixture.nativeSourceLifetimes()
        let winningSource = try await fixture.backupForOwnedReference(
          ownerLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!)
        let losingSource = try await fixture.backupForOwnedReference()
        let obstruction = NativeSaveFileSizeObstruction(
          configuration: fixture.configuration, maximumFileSize: 0)
        let observer = NotificationCenter.default.addObserver(
          forName: ModelContext.willSave, object: nil, queue: nil
        ) { notification in obstruction.observe(notification) }
        let failed = await fixture.planner.exportData(session: fixture.session)
        NotificationCenter.default.removeObserver(observer)
        try obstruction.restore()
        #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
        guard case .failed(let reason) = failed else {
          Issue.record("A failed native mixed-owned save must remain unapplied: \(failed)")
          return
        }
        #expect(reason.code == "maintenanceRequired")
        #expect(try await fixture.rawOwnedLinkData() == originalLinks)
        #expect(try await fixture.rawScheduleData() == originalSchedules)
        #expect(try await fixture.rawLabelData() == originalLabels)
        #expect(try await fixture.rawEntryData() == originalEntries)
        #expect(try await fixture.rawExpandedData() == originalExpanded)
        #expect(try await fixture.rawCompletionAuthorityData() == originalHistory)
        #expect(try await fixture.nativeSourceLifetimes() == originalLifetimes)
        #expect(
          try fixture.graph(
            await fixture.backupForOwnedReference(
              ownerLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!))
            == fixture.graph(winningSource))
        #expect(
          try fixture.graph(await fixture.backupForOwnedReference()) == fixture.graph(losingSource))
        let failedFiles = try fixture.files()
        for (name, bytes) in originalFiles { #expect(failedFiles[name] == bytes) }
        #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
        let proposals = failedFiles.filter { $0.key.hasPrefix("maintenance-") }
        #expect(proposals.count == 1)
        let proposal = try fixture.object(try #require(proposals.values.first))
        let identifier = try #require(
          (proposal["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
        guard
          case .rejected(let reason) = await fixture.planner.retryMaintenanceRecovery(
            session: fixture.session, maintenanceId: identifier)
        else { throw CancellationError() }
        #expect(reason.code == "maintenanceNotApplied")
        #expect(try fixture.files() == failedFiles)
        unverifiedMaintenance = identifier
        unverifiedFiles = failedFiles
      }
    #endif
    var pendingMaintenance: UUID?
    var pendingExport: Data?
    if recoveryFailure {
      let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let committed = await fixture.planner.exportData(session: fixture.session)
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      guard case .exported(let data) = committed,
        case .status(let status) = await fixture.planner.read(
          session: fixture.session, request: .status),
        case .known(_, let operations, let maintenance, let blocked) = status.recovery
      else {
        Issue.record(
          "Committed Item metadata must remain readable while recovery waits: \(committed)")
        return
      }
      #expect(operations.isEmpty && maintenance.count == 1 && blocked)
      pendingMaintenance = try #require(maintenance.first)
      pendingExport = data
      let files = try fixture.files()
      for (name, bytes) in originalFiles { #expect(files[name] == bytes) }
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
      let operationIdentifier = UUID()
      guard
        case .rejected(let reason) = await fixture.planner.execute(
          .init(
            operationId: operationIdentifier, session: fixture.session,
            command: .createTag(content: .init(name: "Wait for Item metadata recovery")))
        ).outcome,
        case .noReliableEvidence = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { throw CancellationError() }
      #expect(reason.code == "mutationBlocked")
      #expect(try fixture.files() == files)
    }
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session),
      case .source(.item(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    if let pendingExport {
      #expect(try fixture.graph(pendingExport) == fixture.graph(after))
    }
    #expect(retained.fieldHashes == winner.fieldHashes && retained.updatedAt == winner.updatedAt)
    let original = try fixture.object(before)
    var graph = try fixture.object(after)
    let originalMarkers = try #require(original["deletionMarkers"] as? [[String: Any]])
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    let closures = markers.filter { marker in
      !originalMarkers.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    let targets: [[String: Any]] = [
      [
        "kind": "ownedLink", "id": "00000000-0000-4000-8000-000000000871",
        "lifetimeId": "00000000-0000-4000-8000-000000000872",
      ],
      [
        "kind": "source",
        "source": [
          "kind": "schedule",
          "id": "00000000-0000-4000-8000-000000000873",
          "lifetimeId": "00000000-0000-4000-8000-000000000874",
        ],
      ],
      [
        "kind": "labelAssociation", "id": "00000000-0000-4000-8000-000000000875",
        "lifetimeId": "00000000-0000-4000-8000-000000000876",
      ],
      [
        "kind": "labelAssociation", "id": "00000000-0000-4000-8000-000000000877",
        "lifetimeId": "00000000-0000-4000-8000-000000000878",
      ],
    ]
    #expect(closures.count == 4)
    for target in targets {
      #expect(
        closures.contains { $0["target"] as? NSDictionary == NSDictionary(dictionary: target) })
    }
    graph["deletionMarkers"] = markers.filter { marker in
      !closures.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(NSDictionary(dictionary: graph) == NSDictionary(dictionary: original))
    if let pendingMaintenance {
      let files = try fixture.files()
      guard
        case .exported(let readable) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(try fixture.graph(readable) == fixture.graph(after))
      #expect(try fixture.files() == files)
      guard
        case .complete(let checkpoint) = await fixture.planner.retryMaintenanceRecovery(
          session: fixture.session, maintenanceId: pendingMaintenance),
        case .complete(let repeated) = await fixture.planner.retryMaintenanceRecovery(
          session: fixture.session, maintenanceId: pendingMaintenance)
      else { throw CancellationError() }
      #expect(checkpoint == repeated)
    }
    let envelope = try fixture.envelope()
    #expect(envelope["receipts"] as? NSArray == originalReceipts)
    let maintenance = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(maintenance.count == 1)
    let identifier = try #require(maintenance.first?["maintenanceId"] as? String)
    if let pendingMaintenance { #expect(identifier == pendingMaintenance.uuidString) }
    #if os(macOS)
      if let unverifiedMaintenance, let unverifiedFiles {
        #expect(identifier != unverifiedMaintenance.uuidString)
        let files = try fixture.files()
        for (name, bytes) in unverifiedFiles { #expect(files[name] == bytes) }
      }
    #endif
    let preparation = try fixture.object(
      Data(contentsOf: fixture.namespace.appendingPathComponent("maintenance-\(identifier).json")))
    #expect(
      try fixture.graph(
        JSONSerialization.data(withJSONObject: #require(preparation["proposedBackup"])))
        == fixture.graph(after))
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    try await fixture.deliverCandidateWithEntries(true)
    try await fixture.addMixedMetadataToLosingSource()
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
  }

  @Test(arguments: [PlannerEntityKind.item, .itinerary], ["link", "schedule"])
  func unresolvedOwnerAndOwnedWinnerDisagreementPreservesEveryNativeRecord(
    ownerKind: PlannerEntityKind, referenceKind: String
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: ownerKind)
    if referenceKind == "link" {
      try await fixture.deliverCandidateWithOwnedLink()
    } else {
      try await fixture.deliverCandidateWithSchedule(allDay: false)
    }
    let familyData = try await fixture.addOwnedRestorationHistory(referenceKind: referenceKind)
    try await fixture.deliverClosedOwnedSibling(referenceKind: referenceKind)
    let losingBackup = try await fixture.backupForOwnedReference(restorationHistory: familyData)
    var winningFamily = try fixture.object(familyData)
    let candidates = try #require(winningFamily["candidates"] as? [[String: Any]])
    winningFamily["candidates"] = candidates.filter {
      $0["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000889"
    }
    let winningFamilyData = try JSONSerialization.data(withJSONObject: winningFamily)
    let winningBackup = try await fixture.backupForOwnedReference(
      ownerLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!,
      restorationHistory: winningFamilyData)
    guard case .decoded = fixture.planner.decodeImport(losingBackup),
      case .decoded = fixture.planner.decodeImport(winningBackup)
    else {
      Issue.record("Both pre-union source/owned-family snapshots must be valid independently.")
      return
    }
    let linksBefore = try await fixture.rawOwnedLinkData()
    let schedulesBefore = try await fixture.rawScheduleData()
    let sourcesBefore = try await fixture.nativeSourceLifetimes()
    #expect(sourcesBefore.count == 2)
    let filesBefore = try fixture.files()
    let controlBefore = try Data(contentsOf: fixture.configuration.controlURL)
    let result = await fixture.planner.exportData(session: fixture.session)
    let read = await fixture.planner.read(
      session: fixture.session, request: .source(fixture.source))
    guard case .failed(let failure) = result, case .failed = read else {
      Issue.record(
        "Unsettled cross-family ownership must not mutate either version: \(result), \(read)")
      return
    }
    print(
      "PLANNER_CROSSED_FAMILY_FAILURE", ownerKind.rawValue, referenceKind, failure.code,
      failure.propertyPath ?? "", failure.message)
    #expect(try await fixture.rawOwnedLinkData() == linksBefore)
    #expect(try await fixture.rawScheduleData() == schedulesBefore)
    #expect(try await fixture.nativeSourceLifetimes() == sourcesBefore)
    #expect(
      try fixture.graph(await fixture.backupForOwnedReference(restorationHistory: familyData))
        == fixture.graph(losingBackup))
    #expect(
      try fixture.graph(
        await fixture.backupForOwnedReference(
          ownerLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!,
          restorationHistory: winningFamilyData)) == fixture.graph(winningBackup))
    #expect(try fixture.files() == filesBefore)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == controlBefore)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .unavailable = await reopened.bootstrap() else {
      Issue.record("Reopening cannot silently choose a different cross-family precedence.")
      return
    }
    #expect(try await fixture.rawOwnedLinkData() == linksBefore)
    #expect(try await fixture.rawScheduleData() == schedulesBefore)
    #expect(try await fixture.nativeSourceLifetimes() == sourcesBefore)
    #expect(
      try fixture.graph(await fixture.backupForOwnedReference(restorationHistory: familyData))
        == fixture.graph(losingBackup))
    #expect(
      try fixture.graph(
        await fixture.backupForOwnedReference(
          ownerLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!,
          restorationHistory: winningFamilyData)) == fixture.graph(winningBackup))
    #expect(try fixture.files() == filesBefore)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == controlBefore)
  }

  @Test(
    arguments: [PlannerEntityKind.item, .itinerary],
    [
      (PlannerEntityKind.category, "deleted"), (.category, "restored"), (.category, "unknown"),
      (.tag, "deleted"), (.tag, "restored"), (.tag, "unknown"),
    ])
  func closedLabelFamiliesPreserveTheCurrentOwnerAfterLateDelivery(
    ownerKind: PlannerEntityKind, scenario: (PlannerEntityKind, String)
  ) async throws {
    let (labelKind, delivery) = scenario
    let fixture = try await SourceRestorationFixture.make(kind: ownerKind)
    func save(_ command: PlannerCommand) async throws -> PlannerOperationResult {
      let result = await fixture.planner.execute(
        .init(operationId: UUID(), session: fixture.session, command: command))
      guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
      return result
    }
    _ = try await save(fixture.labelSelectionCommand(kind: labelKind, selected: true))
    let firstRemoval = try await save(
      fixture.labelSelectionCommand(kind: labelKind, selected: false))
    _ = try await save(
      .restoreAssociation(snapshot: #require(firstRemoval.associationUndoSnapshot)))
    guard
      case .exported(let restoredData) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let restored) = fixture.planner.decodeImport(restoredData),
      let oldAssociation = restored.backup.labelAssociations.first,
      let family = restored.backup.restorationFamilies.first(where: {
        $0.predecessor.kind == .labelAssociation && $0.predecessor.id == oldAssociation.id
          && $0.candidates.contains { $0.lifetimeId == oldAssociation.lifetimeId }
      })
    else { throw CancellationError() }
    let removal = PlannerOperation(
      operationId: UUID(), session: fixture.session,
      command: try await fixture.labelSelectionCommand(kind: labelKind, selected: false))
    let removed = await fixture.planner.execute(removal)
    guard case .applied(let removalValue, .complete) = removed.outcome else {
      throw CancellationError()
    }
    if delivery == "restored" {
      _ = try await save(.restoreAssociation(snapshot: #require(removed.associationUndoSnapshot)))
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let current) = fixture.planner.decodeImport(before)
    else { throw CancellationError() }
    #expect(current.backup.deletionMarkers.contains { $0.closedFamilyId == family.familyId })
    let deliveredLifetime: UUID
    if delivery == "unknown" {
      deliveredLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000816")!
    } else {
      deliveredLifetime = oldAssociation.lifetimeId
    }
    try await fixture.deliverClosedLabel(oldAssociation, lifetime: deliveredLifetime)
    let labelsBefore = try await fixture.rawLabelData()
    let filesBefore = try fixture.files()
    let controlBefore = try Data(contentsOf: fixture.configuration.controlURL)
    if delivery == "unknown" {
      let read = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
      let exported = await fixture.planner.exportData(session: fixture.session)
      guard case .failed = read, case .failed = exported else {
        Issue.record(
          "An unknown label-selection lifetime must remain unavailable: \(read), \(exported)")
        return
      }
      #expect(try await fixture.rawLabelData() == labelsBefore)
      #expect(try fixture.files() == filesBefore)
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == controlBefore)
      return
    }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard
      case .failed(let failure) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record("Closed label copies must await durable preparation before retirement.")
      return
    }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.rawLabelData() == labelsBefore)
    #expect(try fixture.files() == filesBefore)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == controlBefore)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard
      case .source = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source)),
      case .exported(let after) = await fixture.planner.exportData(session: fixture.session),
      case .applied(let replayed, .complete) = await fixture.planner.execute(removal).outcome
    else {
      Issue.record("Closed label copies must not block or replace the current selection.")
      return
    }
    #expect(try fixture.graph(after) == fixture.graph(before))
    #expect(replayed == removalValue)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let ready) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: ready)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(before))
  }

  @Test(arguments: [PlannerEntityKind.item, .list], ["deleted", "restored", "unknown"])
  func closedEntryFamiliesPreserveTheCurrentRouteAfterLateDelivery(
    sourceKind: PlannerEntityKind, delivery: String
  ) async throws {
    let restoreCurrent = delivery == "restored"
    let fixture = try await SourceRestorationFixture.make(kind: .itinerary)
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let itemIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000101")!
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    let membership = try await save(
      .addMembership(itemId: itemIdentifier, listId: listIdentifier, placement: .last))
    guard case .membership(let membershipIdentifier, _, _)? = membership.generatedReferences.first
    else { throw CancellationError() }
    let source = PlannerEntityReference(
      kind: sourceKind, id: sourceKind == .item ? itemIdentifier : listIdentifier)
    var entries: [UUID] = []
    for _ in 0..<2 {
      let addition = try await save(
        .addItineraryEntry(itineraryId: fixture.source.id, source: source, placement: .last))
      guard case .itineraryEntry(let identifier, _, _)? = addition.generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    let firstEntry = entries[0]
    let appearance: PlannerAppearance
    if sourceKind == .item {
      appearance = .directItineraryItem(itineraryId: fixture.source.id, entryId: firstEntry)
    } else {
      appearance = .expandedListItem(
        itineraryId: fixture.source.id, listEntryId: firstEntry,
        membershipId: membershipIdentifier)
    }
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    let removalCommand = PlannerCommand.removeItineraryEntry(
      itineraryId: fixture.source.id, entryId: firstEntry)
    let firstRemoval = await fixture.planner.execute(
      .init(operationId: UUID(), session: fixture.session, command: removalCommand))
    let firstUndo = try #require(firstRemoval.associationUndoSnapshot)
    _ = try await save(.restoreAssociation(snapshot: firstUndo))
    guard
      case .exported(let restoredData) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let restored) = fixture.planner.decodeImport(restoredData),
      let oldEntry = restored.backup.itineraryEntries.first(where: { $0.id == firstEntry }),
      let family = restored.backup.restorationFamilies.first(where: {
        $0.predecessor.kind == .itineraryEntry && $0.predecessor.id == firstEntry
          && $0.candidates.contains { $0.lifetimeId == oldEntry.lifetimeId }
      })
    else { throw CancellationError() }
    let removal = PlannerOperation(
      operationId: UUID(), session: fixture.session, command: removalCommand)
    let removed = await fixture.planner.execute(removal)
    guard case .applied(let removalValue, .complete) = removed.outcome else {
      throw CancellationError()
    }
    if restoreCurrent {
      _ = try await save(
        .restoreAssociation(snapshot: #require(removed.associationUndoSnapshot)))
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let current) = fixture.planner.decodeImport(before)
    else { throw CancellationError() }
    #expect(current.backup.deletionMarkers.contains { $0.closedFamilyId == family.familyId })
    let deliveredLifetime: UUID
    if delivery == "unknown" {
      deliveredLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000816")!
    } else {
      deliveredLifetime = oldEntry.lifetimeId
    }
    try await fixture.deliverClosedEntry(oldEntry, lifetime: deliveredLifetime)
    let entriesBefore = try await fixture.nativeEntryData()
    let expandedBefore = try await fixture.rawExpandedData()
    let filesBefore = try fixture.files()
    let controlBefore = try Data(contentsOf: fixture.configuration.controlURL)
    if delivery == "unknown" {
      let read = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
      let exported = await fixture.planner.exportData(session: fixture.session)
      guard case .failed = read, case .failed = exported else {
        Issue.record(
          "An unknown entry lifetime must remain unmodified and unavailable: \(read), \(exported)")
        return
      }
      #expect(try await fixture.nativeEntryData() == entriesBefore)
      #expect(try await fixture.rawExpandedData() == expandedBefore)
      #expect(try fixture.files() == filesBefore)
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == controlBefore)
      return
    }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard
      case .failed(let failure) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.nativeEntryData() == entriesBefore)
    #expect(try await fixture.rawExpandedData() == expandedBefore)
    #expect(try fixture.files() == filesBefore)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == controlBefore)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    let query = await fixture.planner.query(
      .init(
        session: fixture.session,
        request: .items(
          .init(scope: .itinerary(fixture.source.id), completion: .all, archive: .all))))
    guard case .snapshot(let contents) = query,
      case .exported(let after) = await fixture.planner.exportData(session: fixture.session),
      case .applied(let replayed, .complete) = await fixture.planner.execute(removal).outcome
    else {
      Issue.record("A closed entry family must not replace or block the current route: \(query)")
      return
    }
    #expect(contents.matchingCount == (restoreCurrent ? 2 : 1))
    #expect(try fixture.graph(after) == fixture.graph(before))
    #expect(replayed == removalValue)
    let read = await fixture.planner.read(
      session: fixture.session, request: .appearance(appearance))
    if restoreCurrent {
      guard case .appearance(let retained) = read else { throw CancellationError() }
      #expect(retained.localDone)
    } else {
      guard case .failed = read else { throw CancellationError() }
    }
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let ready) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: ready)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(before))
  }

  @Test(arguments: [PlannerEntityKind.item, .list, .itinerary, .category, .tag])
  func unknownSourceAfterFamilyClosurePreservesNativeDataAndRecovery(kind: PlannerEntityKind)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    guard
      case .reviewed(let deletion) = await fixture.planner.prepareReview(
        session: fixture.session, command: .deleteSource(source: fixture.source)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome
    else { throw CancellationError() }
    try await fixture.deliverCandidate(
      lifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000816")!)
    let lifetimes = try await fixture.nativeSourceLifetimes()
    #expect(lifetimes == [UUID(uuidString: "00000000-0000-4000-8000-000000000816")!])
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    let exported = await fixture.planner.exportData(session: fixture.session)
    let read = await fixture.planner.read(
      session: fixture.session, request: .source(fixture.source))
    guard case .failed = exported, case .failed = read else {
      Issue.record(
        "A public identity cannot authorize an unknown lifetime: \(read), \(exported)")
      return
    }
    #expect(try await fixture.nativeSourceLifetimes() == lifetimes)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    let reopened = Planner(configuration: fixture.configuration)
    switch await reopened.bootstrap() {
    case .ready(let session):
      let exported = await reopened.exportData(session: session)
      let read = await reopened.read(session: session, request: .source(fixture.source))
      guard case .failed = exported, case .failed = read else {
        Issue.record("Unproven source reads/export must fail: \(read), \(exported)")
        return
      }
    case .unavailable(let failure): #expect(failure.code == "readUnavailable")
    default: Issue.record("The existing dataset needs no new setup or migration.")
    }
    #expect(try await fixture.nativeSourceLifetimes() == lifetimes)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
  }

  @Test(arguments: [PlannerEntityKind.item, .list, .itinerary, .category, .tag], [false, true])
  func closedSourceFamiliesIgnoreLateCandidatesWithoutReplacingFreshRestorations(
    kind: PlannerEntityKind, restoreCurrent: Bool
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    guard case .decoded(let original) = fixture.planner.decodeImport(fixture.baseline),
      case .reviewed(let deletion) = await fixture.planner.prepareReview(
        session: fixture.session, command: .deleteSource(source: fixture.source))
    else { throw CancellationError() }
    let deletionOperation = PlannerOperation(
      operationId: UUID(), session: fixture.session, command: deletion.command,
      reviewToken: deletion.reviewToken)
    guard
      case .applied(let deleted, .complete) = await fixture.planner.execute(deletionOperation)
        .outcome
    else { throw CancellationError() }
    if restoreCurrent {
      guard
        case .reviewed(let restoration) = await fixture.planner.prepareReview(
          session: fixture.session,
          command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true)),
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: restoration.command,
            reviewToken: restoration.reviewToken)
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let lifetimes = try await fixture.nativeSourceLifetimes()
    #expect(lifetimes.count == (restoreCurrent ? 1 : 0))
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    try await fixture.deliverCandidate()
    let deliveredLifetimes = try await fixture.nativeSourceLifetimes()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.nativeSourceLifetimes() == deliveredLifetimes)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    let read = await fixture.planner.read(
      session: fixture.session, request: .source(fixture.source))
    switch read {
    case .source: #expect(restoreCurrent)
    case .failed: #expect(!restoreCurrent)
    default: Issue.record("Read must retain the current source or report its existing deletion.")
    }
    #expect(try await fixture.nativeSourceLifetimes() == lifetimes)
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result else {
      Issue.record("A declared closed source candidate must stay retired: \(result)")
      return
    }
    #expect(try fixture.graph(after) == fixture.graph(before))
    #expect(try await fixture.nativeSourceLifetimes() == lifetimes)
    #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    guard
      case .applied(let replayed, .complete) = await fixture.planner.execute(deletionOperation)
        .outcome
    else { throw CancellationError() }
    #expect(replayed == deleted)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(before))
    try await fixture.deliverCandidate()
    guard case .exported(let redelivered) = await reopened.exportData(session: session) else {
      Issue.record("Repeated closed-candidate delivery must remain readable.")
      return
    }
    #expect(try fixture.graph(redelivered) == fixture.graph(before))
    #expect(try await fixture.nativeSourceLifetimes() == lifetimes)
  }

  @Test(arguments: [PlannerEntityKind.item, .itinerary], ["link", "schedule"])
  func losingOwnedRestorationHistoryClosesWithoutChangingTheWinningSource(
    ownerKind: PlannerEntityKind, referenceKind: String
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: ownerKind)
    if referenceKind == "link" {
      try await fixture.deliverCandidateWithOwnedLink()
    } else {
      try await fixture.deliverCandidateWithSchedule(allDay: false)
    }
    let familyData = try await fixture.addOwnedRestorationHistory(referenceKind: referenceKind)
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result else {
      Issue.record("Discarded owned restoration history must remain exportable: \(result)")
      return
    }
    var graph = try fixture.object(after)
    let original = try fixture.object(fixture.baseline)
    let families = try #require(graph["restorationFamilies"] as? [[String: Any]])
    let ownedFamilies = families.filter {
      $0["familyId"] as? String == "00000000-0000-4000-8000-000000000880"
    }
    #expect(ownedFamilies.count == 1)
    #expect(
      try NSDictionary(dictionary: #require(ownedFamilies.first)) == fixture.graph(familyData))
    let originalMarkers = try #require(original["deletionMarkers"] as? [[String: Any]])
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    let additions = markers.filter { marker in
      !originalMarkers.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(additions.count == 2)
    let root = try #require(
      additions.first { $0["deletionId"] as? String == "00000000-0000-4000-8000-000000000884" })
    #expect(root["operationId"] as? String == "00000000-0000-4000-8000-000000000885")
    let closure = try #require(
      additions.first { $0["closedFamilyId"] as? String == "00000000-0000-4000-8000-000000000880" })
    let expectedRoot: [String: Any]
    let expectedClosure: [String: Any]
    if referenceKind == "link" {
      expectedRoot = [
        "kind": "ownedLink", "id": "00000000-0000-4000-8000-000000000871",
        "lifetimeId": "00000000-0000-4000-8000-000000000870",
      ]
      expectedClosure = [
        "kind": "ownedLink", "id": "00000000-0000-4000-8000-000000000871",
        "lifetimeId": "00000000-0000-4000-8000-000000000872",
      ]
    } else {
      expectedRoot = [
        "kind": "source",
        "source": [
          "kind": "schedule", "id": "00000000-0000-4000-8000-000000000873",
          "lifetimeId": "00000000-0000-4000-8000-000000000870",
        ],
      ]
      expectedClosure = [
        "kind": "source",
        "source": [
          "kind": "schedule", "id": "00000000-0000-4000-8000-000000000873",
          "lifetimeId": "00000000-0000-4000-8000-000000000874",
        ],
      ]
    }
    #expect(root["target"] as? NSDictionary == NSDictionary(dictionary: expectedRoot))
    #expect(closure["target"] as? NSDictionary == NSDictionary(dictionary: expectedClosure))
    graph["deletionMarkers"] = markers.filter { marker in
      !additions.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    graph["restorationFamilies"] = families.filter {
      $0["familyId"] as? String != "00000000-0000-4000-8000-000000000880"
    }
    #expect(NSDictionary(dictionary: graph) == NSDictionary(dictionary: original))
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    if referenceKind == "link" {
      try await fixture.deliverCandidateWithOwnedLink()
    } else {
      try await fixture.deliverCandidateWithSchedule(allDay: false)
    }
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
    try await fixture.deliverClosedOwnedSibling(referenceKind: referenceKind)
    let siblingResult = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let afterSibling) = siblingResult else {
      Issue.record("A known closed sibling must not block the live winner: \(siblingResult)")
      return
    }
    #expect(try fixture.graph(afterSibling) == fixture.graph(after))
  }

  @Test(arguments: [false, true])
  func relatedItemAndListFamiliesPreserveTheWinningPlanInEitherDeliveryOrder(itemFirst: Bool)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(includeRestoredList: true)
    let list = PlannerEntityReference(
      kind: .list, id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!)
    let itinerary = PlannerEntityReference(
      kind: .itinerary, id: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!)
    let listFixture = SourceRestorationFixture(
      configuration: fixture.configuration, planner: fixture.planner, session: fixture.session,
      source: list, namespace: fixture.namespace, baseline: fixture.baseline)
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await fixture.planner.execute(
        .init(operationId: UUID(), session: fixture.session, command: command))
      guard case .applied(let applied, .complete) = response.outcome else {
        Issue.record("Prepare the independent winning route: \(response)")
        throw CancellationError()
      }
      return applied
    }
    let addition = try await save(
      .addMembership(itemId: fixture.source.id, listId: list.id, placement: .last))
    guard case .membership(let membership, _, _)? = addition.generatedReferences.first else {
      throw CancellationError()
    }
    var entries: [UUID] = []
    for source in [fixture.source, list, fixture.source] {
      let added = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
      guard case .itineraryEntry(let identifier, _, _)? = added.generatedReferences.first else {
        throw CancellationError()
      }
      entries.append(identifier)
    }
    for appearance in [
      PlannerAppearance.expandedListItem(
        itineraryId: itinerary.id, listEntryId: entries[1], membershipId: membership),
      .directItineraryItem(itineraryId: itinerary.id, entryId: entries[2]),
    ] {
      _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    if itemFirst {
      try await fixture.deliverCandidateWithOwnedLink()
      try await listFixture.deliverCandidateWithOwnedMembership(entries: [entries[1]])
    } else {
      try await listFixture.deliverCandidateWithOwnedMembership(entries: [entries[1]])
      try await fixture.deliverCandidateWithOwnedLink()
    }
    try await fixture.bindOwnedMembershipToLosingItem()
    try await fixture.bindEntriesToLosingCandidate([entries[0], entries[2]])
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result,
      case .source(.itinerary(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(itinerary))
    else {
      Issue.record("The two proven source families must retire atomically: \(result)")
      return
    }
    #expect(retained.progress.totalCount == 3)
    #expect(retained.progress.doneCount == 2)
    var graph = try fixture.object(after)
    let original = try fixture.object(before)
    let originalMarkers = try #require(original["deletionMarkers"] as? [[String: Any]])
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    let closures = markers.filter { marker in
      !originalMarkers.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(closures.count == 2)
    for target in [
      [
        "kind": "membership", "id": "00000000-0000-4000-8000-000000000403",
        "lifetimeId": "00000000-0000-4000-8000-000000000843",
      ],
      [
        "kind": "ownedLink", "id": "00000000-0000-4000-8000-000000000871",
        "lifetimeId": "00000000-0000-4000-8000-000000000872",
      ],
    ] {
      #expect(
        closures.contains { $0["target"] as? NSDictionary == NSDictionary(dictionary: target) })
    }
    let provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    let retiredProvenance = provenance.filter {
      $0["membershipId"] as? String == "00000000-0000-4000-8000-000000000403"
    }
    #expect(
      NSArray(array: retiredProvenance)
        == NSArray(array: [
          [
            "membershipId": "00000000-0000-4000-8000-000000000403",
            "membershipLifetimeId": "00000000-0000-4000-8000-000000000843",
            "list": [
              "kind": "list", "id": list.id.uuidString,
              "lifetimeId": "00000000-0000-4000-8000-000000000815",
            ],
            "item": [
              "kind": "item", "id": fixture.source.id.uuidString,
              "lifetimeId": "00000000-0000-4000-8000-000000000815",
            ],
            "observedRemovalIds": [],
          ]
        ]))
    graph["membershipProvenance"] = provenance.filter {
      $0["membershipId"] as? String != "00000000-0000-4000-8000-000000000403"
    }
    graph["deletionMarkers"] = markers.filter { marker in
      !closures.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(NSDictionary(dictionary: graph) == NSDictionary(dictionary: original))
    let envelope = try fixture.envelope()
    #expect(envelope["receipts"] as? NSArray == receipts)
    let maintenance = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(maintenance.count == 1)
    let identifier = try #require(maintenance.first?["maintenanceId"] as? String)
    let preparation = try fixture.object(
      Data(contentsOf: fixture.namespace.appendingPathComponent("maintenance-\(identifier).json")))
    #expect(
      try fixture.graph(JSONSerialization.data(withJSONObject: preparation["proposedBackup"]!))
        == fixture.graph(after))
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    if itemFirst {
      try await listFixture.deliverCandidateWithOwnedMembership(entries: [entries[1]])
      try await fixture.deliverCandidateWithOwnedLink()
    } else {
      try await fixture.deliverCandidateWithOwnedLink()
      try await listFixture.deliverCandidateWithOwnedMembership(entries: [entries[1]])
    }
    try await fixture.bindOwnedMembershipToLosingItem()
    try await fixture.bindEntriesToLosingCandidate([entries[0], entries[2]])
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
    #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
  }

  @Test(arguments: [false, true])
  func mixedLosingItineraryContentsRetireInOneTransactionWithoutChangingTheWinner(
    recoveryFailure: Bool
  ) async throws {
    try await checkMixedOwnedItinerary(recoveryFailure: recoveryFailure, nativeSaveFailure: false)
  }

  private func expectMixedItineraryGraph(_ data: Data, preserving before: Data) throws {
    let original = try #require(
      JSONSerialization.jsonObject(with: before) as? [String: Any])
    var graph = try #require(
      JSONSerialization.jsonObject(with: data) as? [String: Any])
    let originalMarkers = try #require(original["deletionMarkers"] as? [[String: Any]])
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    let closures = markers.filter { marker in
      !originalMarkers.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(closures.count == 7)
    let expectedTargets: [[String: Any]] = [
      [
        "kind": "itineraryEntry", "id": "00000000-0000-4000-8000-000000000831",
        "lifetimeId": "00000000-0000-4000-8000-000000000832",
      ],
      [
        "kind": "itineraryEntry", "id": "00000000-0000-4000-8000-000000000833",
        "lifetimeId": "00000000-0000-4000-8000-000000000834",
      ],
      [
        "kind": "itineraryEntry", "id": "00000000-0000-4000-8000-000000000835",
        "lifetimeId": "00000000-0000-4000-8000-000000000836",
      ],
      [
        "kind": "ownedLink", "id": "00000000-0000-4000-8000-000000000871",
        "lifetimeId": "00000000-0000-4000-8000-000000000872",
      ],
      [
        "kind": "source",
        "source": [
          "kind": "schedule", "id": "00000000-0000-4000-8000-000000000873",
          "lifetimeId": "00000000-0000-4000-8000-000000000874",
        ],
      ],
      [
        "kind": "labelAssociation", "id": "00000000-0000-4000-8000-000000000875",
        "lifetimeId": "00000000-0000-4000-8000-000000000876",
      ],
      [
        "kind": "labelAssociation", "id": "00000000-0000-4000-8000-000000000877",
        "lifetimeId": "00000000-0000-4000-8000-000000000878",
      ],
    ]
    for target in expectedTargets {
      #expect(
        closures.contains { $0["target"] as? NSDictionary == NSDictionary(dictionary: target) })
    }
    graph["deletionMarkers"] = markers.filter { marker in
      !closures.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(NSDictionary(dictionary: graph) == NSDictionary(dictionary: original))
  }

  private func checkMixedOwnedItinerary(recoveryFailure: Bool, nativeSaveFailure: Bool) async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: .itinerary)
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let result = await fixture.planner.execute(
        .init(operationId: UUID(), session: fixture.session, command: command))
      guard case .applied(let applied, .complete) = result.outcome else {
        Issue.record("Prepare the winning Itinerary through ordinary saves: \(result)")
        throw CancellationError()
      }
      return applied
    }
    guard
      case .source(.itinerary(let initial)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    _ = try await save(
      .editItinerary(
        sourceId: fixture.source.id,
        changes: .init(
          notes: .set("Winning notes"),
          links: .set([.init(originalUrl: "https://example.com/winner", label: "Guide A")]),
          categoryIds: .set([UUID(uuidString: "00000000-0000-4000-8000-000000000501")!]),
          tagIds: .set([UUID(uuidString: "00000000-0000-4000-8000-000000000601")!])),
        expectedFieldHashes: initial.fieldHashes))
    _ = try await save(
      .createSchedule(
        source: fixture.source,
        form: .allDay(start: .init(year: 2026, month: 10, day: 26), end: nil)))
    let item = PlannerEntityReference(
      kind: .item, id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)
    let list = PlannerEntityReference(
      kind: .list, id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!)
    let addition = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .membership(let membership, _, _)? = addition.generatedReferences.first else {
      throw CancellationError()
    }
    for source in [item, list] {
      _ = try await save(
        .addItineraryEntry(itineraryId: fixture.source.id, source: source, placement: .last))
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    let originalFiles = try fixture.files()
    let originalControl = try Data(contentsOf: fixture.configuration.controlURL)
    try await fixture.deliverCandidateWithOwnedStops(membershipId: membership)
    try await fixture.addMixedMetadataToLosingSource()
    #if os(macOS)
      let environment = ProcessInfo.processInfo.environment
      if let directoryPath = environment["PLANNER_SOURCE_RESTORATION_CHILD"],
        let stage = environment["PLANNER_SOURCE_RESTORATION_STAGE"],
        ["mixedBeforeNativeSave", "mixedAfterNativeSave"].contains(stage)
      {
        let directory = URL(fileURLWithPath: directoryPath)
        let input: [String: Any] = [
          "dataset": fixture.configuration.storeURL.deletingLastPathComponent()
            .deletingLastPathComponent().path,
          "namespace": fixture.namespace.path, "baseline": before.base64EncodedString(),
          "files": originalFiles.mapValues { $0.base64EncodedString() },
          "control": originalControl.base64EncodedString(), "receipts": receipts ?? NSArray(),
        ]
        try JSONSerialization.data(withJSONObject: input).write(
          to: directory.appendingPathComponent("input.json"), options: .atomic)
        let storeURL = fixture.configuration.storeURL.standardizedFileURL
        let notification =
          stage == "mixedBeforeNativeSave" ? ModelContext.willSave : ModelContext.didSave
        let observer = NotificationCenter.default.addObserver(
          forName: notification, object: nil, queue: nil
        ) { value in
          guard let context = value.object as? ModelContext,
            context.container.configurations.contains(where: {
              $0.url.standardizedFileURL == storeURL
            })
          else { return }
          do {
            try JSONSerialization.data(withJSONObject: [
              "stage": stage, "processIdentifier": Int(getpid()),
            ]).write(to: directory.appendingPathComponent("proof.json"), options: .atomic)
          } catch { print("SOURCE_RESTORATION_PROOF_ERROR \(error)") }
          fflush(nil)
          if kill(getpid(), SIGKILL) != 0 { return }
          while true { pause() }
        }
        let result = await fixture.planner.exportData(session: fixture.session)
        NotificationCenter.default.removeObserver(observer)
        Issue.record("Mixed-owned retirement must stop at its actual save boundary: \(result)")
        return
      }
      var unverifiedMaintenance: UUID?
      var unverifiedFiles: [String: Data]?
      if nativeSaveFailure {
        let originalLinks = try await fixture.rawOwnedLinkData()
        let originalSchedules = try await fixture.rawScheduleData()
        let originalLabels = try await fixture.rawLabelData()
        let originalEntries = try await fixture.rawEntryData()
        let originalExpanded = try await fixture.rawExpandedData()
        let originalHistory = try await fixture.rawCompletionAuthorityData()
        let originalLifetimes = try await fixture.nativeSourceLifetimes()
        let winningSource = try await fixture.backupForOwnedReference(
          ownerLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!)
        let losingSource = try await fixture.backupForOwnedReference()
        let obstruction = NativeSaveFileSizeObstruction(
          configuration: fixture.configuration, maximumFileSize: 0)
        let observer = NotificationCenter.default.addObserver(
          forName: ModelContext.willSave, object: nil, queue: nil
        ) { notification in obstruction.observe(notification) }
        let failed = await fixture.planner.exportData(session: fixture.session)
        NotificationCenter.default.removeObserver(observer)
        try obstruction.restore()
        #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
        guard case .failed(let reason) = failed else {
          Issue.record("A failed native mixed-owned save must remain unapplied: \(failed)")
          return
        }
        #expect(reason.code == "maintenanceRequired")
        #expect(try await fixture.rawOwnedLinkData() == originalLinks)
        #expect(try await fixture.rawScheduleData() == originalSchedules)
        #expect(try await fixture.rawLabelData() == originalLabels)
        #expect(try await fixture.rawEntryData() == originalEntries)
        #expect(try await fixture.rawExpandedData() == originalExpanded)
        #expect(try await fixture.rawCompletionAuthorityData() == originalHistory)
        #expect(try await fixture.nativeSourceLifetimes() == originalLifetimes)
        #expect(
          try fixture.graph(
            await fixture.backupForOwnedReference(
              ownerLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!))
            == fixture.graph(winningSource))
        #expect(
          try fixture.graph(await fixture.backupForOwnedReference()) == fixture.graph(losingSource))
        let failedFiles = try fixture.files()
        for (name, bytes) in originalFiles { #expect(failedFiles[name] == bytes) }
        #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
        let proposals = failedFiles.filter { $0.key.hasPrefix("maintenance-") }
        #expect(proposals.count == 1)
        let proposal = try fixture.object(try #require(proposals.values.first))
        let identifier = try #require(
          (proposal["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
        guard
          case .rejected(let reason) = await fixture.planner.retryMaintenanceRecovery(
            session: fixture.session, maintenanceId: identifier)
        else { throw CancellationError() }
        #expect(reason.code == "maintenanceNotApplied")
        #expect(try fixture.files() == failedFiles)
        unverifiedMaintenance = identifier
        unverifiedFiles = failedFiles
      }
    #endif
    var pendingMaintenance: UUID?
    var pendingExport: Data?
    if recoveryFailure {
      let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let committedResult = await fixture.planner.exportData(session: fixture.session)
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      guard case .exported(let committedData) = committedResult,
        case .status(let status) = await fixture.planner.read(
          session: fixture.session, request: .status),
        case .known(_, let operations, let maintenance, let blocked) = status.recovery
      else {
        Issue.record(
          "Mixed owned retirement must remain readable with truthful incomplete recovery: \(committedResult)"
        )
        return
      }
      #expect(operations.isEmpty && maintenance.count == 1 && blocked)
      pendingMaintenance = try #require(maintenance.first)
      pendingExport = committedData
      let files = try fixture.files()
      for (name, bytes) in originalFiles { #expect(files[name] == bytes) }
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
      let blockedOperation = UUID()
      guard
        case .rejected(let blockedReason) = await fixture.planner.execute(
          .init(
            operationId: blockedOperation, session: fixture.session,
            command: .createTag(content: .init(name: "Wait for owned-content recovery")))
        ).outcome,
        case .noReliableEvidence = await fixture.planner.operationStatus(
          session: fixture.session, operationId: blockedOperation)
      else { throw CancellationError() }
      #expect(blockedReason.code == "mutationBlocked")
      #expect(try fixture.files() == files)
    }
    let outcome = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = outcome else {
      Issue.record("Mixed losing contents must retire together: \(outcome)")
      return
    }
    if let pendingExport {
      #expect(try fixture.graph(pendingExport) == fixture.graph(after))
    }
    try expectMixedItineraryGraph(after, preserving: before)
    if let pendingMaintenance {
      let beforeRetryFiles = try fixture.files()
      guard
        case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(try fixture.graph(unchanged) == fixture.graph(after))
      #expect(try fixture.files() == beforeRetryFiles)
      guard
        case .complete(let checkpoint) = await fixture.planner.retryMaintenanceRecovery(
          session: fixture.session, maintenanceId: pendingMaintenance),
        case .complete(let repeated) = await fixture.planner.retryMaintenanceRecovery(
          session: fixture.session, maintenanceId: pendingMaintenance)
      else {
        Issue.record("Committed mixed-owned maintenance must Retry without repeating retirement.")
        return
      }
      #expect(checkpoint == repeated)
      #expect(try fixture.envelope()["checkpointGeneration"] as? String == String(checkpoint))
    }
    let envelope = try fixture.envelope()
    #expect(envelope["receipts"] as? NSArray == receipts)
    let maintenance = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(maintenance.count == 1)
    let identifier = try #require(maintenance.first?["maintenanceId"] as? String)
    #if os(macOS)
      if let unverifiedMaintenance, let unverifiedFiles {
        #expect(identifier != unverifiedMaintenance.uuidString)
        let files = try fixture.files()
        for (name, bytes) in unverifiedFiles { #expect(files[name] == bytes) }
      }
    #endif
    let preparation = try fixture.object(
      Data(contentsOf: fixture.namespace.appendingPathComponent("maintenance-\(identifier).json")))
    #expect(
      try fixture.graph(JSONSerialization.data(withJSONObject: preparation["proposedBackup"]!))
        == fixture.graph(after))
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    try await fixture.deliverCandidateWithOwnedStops(membershipId: membership)
    try await fixture.addMixedMetadataToLosingSource()
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
  }

  @Test(
    arguments: [PlannerEntityKind.item, .itinerary],
    [
      (referenceKind: "link", hasHistory: false), (referenceKind: "link", hasHistory: true),
      (referenceKind: "schedule", hasHistory: false), (referenceKind: "schedule", hasHistory: true),
    ])
  func discardedOwnedReferencesRequireExplicitRestorationForImport(
    ownerKind: PlannerEntityKind, scenario: (referenceKind: String, hasHistory: Bool)
  ) async throws {
    let referenceKind = scenario.referenceKind
    let fixture = try await SourceRestorationFixture.make(kind: ownerKind)
    if referenceKind == "link" {
      try await fixture.deliverCandidateWithOwnedLink()
    } else {
      try await fixture.deliverCandidateWithSchedule(allDay: false)
    }
    let restorationHistory: Data?
    if scenario.hasHistory {
      restorationHistory = try await fixture.addOwnedRestorationHistory(
        referenceKind: referenceKind)
    } else {
      restorationHistory = nil
    }
    let incoming = try await fixture.backupForOwnedReference(
      restorationHistory: restorationHistory)
    guard case .decoded(let backup) = fixture.planner.decodeImport(incoming),
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session),
      case .reviewed(let review) = await fixture.planner.prepareReview(
        session: fixture.session, command: .applyImport(backup: backup, mode: .overwrite))
    else {
      Issue.record("The independently valid losing-version backup must remain reviewable.")
      return
    }
    let files = try fixture.files()
    let operationIdentifier = UUID()
    let result = await fixture.planner.execute(
      .init(
        operationId: operationIdentifier, session: fixture.session,
        command: review.command, reviewToken: review.reviewToken))
    guard case .rejected = result.outcome,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else {
      Issue.record("Discarded \(referenceKind) must require restoration authorization: \(result)")
      return
    }
    #expect(try fixture.files() == files)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(after) == fixture.graph(before))
    let expected: PlannerReferenceRead
    if referenceKind == "link" {
      expected = .ownedLink(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000871")!, owner: fixture.source)
    } else {
      expected = .schedule(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000873")!, source: fixture.source)
    }
    #expect(
      review.impact.importDetails?.referenceChanges.filter { $0.change == .restore }.map(
        \.reference) == [expected])
    guard
      case .reviewed(let authorized) = await fixture.planner.prepareReview(
        session: fixture.session,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    let restorationIdentifier = UUID()
    let operation = PlannerOperation(
      operationId: restorationIdentifier, session: fixture.session,
      command: authorized.command, reviewToken: authorized.reviewToken)
    let response = await fixture.planner.execute(operation)
    guard case .applied(let restoredResult, .complete(let checkpoint)) = response.outcome,
      case .exported(let restoredData) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let restored) = fixture.planner.decodeImport(restoredData)
    else {
      Issue.record("Explicit restoration must use fresh owned identities: \(response)")
      return
    }
    let restoredIdentity: PlannerPortableBoundIdentity
    if referenceKind == "link" {
      let link = try #require(restored.backup.ownedLinks.first)
      #expect(link.id.uuidString == "00000000-0000-4000-8000-000000000871")
      #expect(link.lifetimeId.uuidString != "00000000-0000-4000-8000-000000000872")
      #expect(link.owner.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
      restoredIdentity = .init(kind: .ownedLink, id: link.id, lifetimeId: link.lifetimeId)
    } else {
      let schedule = try #require(restored.backup.schedules.first)
      #expect(schedule.id.uuidString == "00000000-0000-4000-8000-000000000873")
      #expect(schedule.lifetimeId.uuidString != "00000000-0000-4000-8000-000000000874")
      #expect(schedule.sourceLifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
      restoredIdentity = .init(kind: .schedule, id: schedule.id, lifetimeId: schedule.lifetimeId)
    }
    var expectedGraph = try fixture.object(before)
    let incomingGraph = try fixture.object(incoming)
    var sources = try #require(incomingGraph["sources"] as? [[String: Any]])
    let sourceIndex = try #require(
      sources.firstIndex {
        $0["kind"] as? String == ownerKind.rawValue
          && $0["id"] as? String == fixture.source.id.uuidString
      })
    sources[sourceIndex]["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    expectedGraph["sources"] = sources
    let collection: String
    let ownerField: String
    if referenceKind == "link" {
      collection = "ownedLinks"
      ownerField = "owner"
    } else {
      collection = "schedules"
      ownerField = "source"
    }
    var references = try #require(incomingGraph[collection] as? [[String: Any]])
    #expect(references.count == 1)
    references[0]["lifetimeId"] = restoredIdentity.lifetimeId.uuidString
    var owner = try #require(references[0][ownerField] as? [String: Any])
    owner["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    references[0][ownerField] = owner
    expectedGraph[collection] = references
    let referenceFamilies = restored.backup.restorationFamilies.filter {
      $0.predecessor.kind == restoredIdentity.kind
        && $0.candidates.contains { $0.operationId == restorationIdentifier }
    }
    let family = try #require(referenceFamilies.first)
    #expect(referenceFamilies.count == 1)
    #expect(family.predecessor.id == restoredIdentity.id)
    if referenceKind == "link" {
      #expect(family.predecessor.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000872")
    } else {
      #expect(family.predecessor.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000874")
    }
    #expect(family.candidates.count == 1)
    #expect(family.candidates.first?.lifetimeId == restoredIdentity.lifetimeId)
    #expect(family.candidates.first?.operationId == restorationIdentifier)
    let actualGraph = try fixture.object(restoredData)
    let originalFamilies = try #require(expectedGraph["restorationFamilies"] as? [[String: Any]])
    let actualFamilies = try #require(actualGraph["restorationFamilies"] as? [[String: Any]])
    #expect(actualFamilies.count == originalFamilies.count + 1)
    #expect(
      originalFamilies.allSatisfy { original in
        actualFamilies.contains {
          NSDictionary(dictionary: $0) == NSDictionary(dictionary: original)
        }
      })
    expectedGraph["restorationFamilies"] = actualFamilies
    #expect(NSDictionary(dictionary: actualGraph) == NSDictionary(dictionary: expectedGraph))
    let envelope = try fixture.envelope()
    #expect(Int64(try #require(envelope["checkpointGeneration"] as? String)) == checkpoint)
    let payload = try #require(envelope["portablePayloadBase64"] as? String)
    #expect(
      try fixture.graph(#require(Data(base64Encoded: payload))) == fixture.graph(restoredData))
    let reopened = Planner(configuration: fixture.configuration)
    let bootstrap = await reopened.bootstrap()
    guard case .ready(let session) = bootstrap else {
      Issue.record("Restored owned references must reopen: \(bootstrap)")
      return
    }
    let replay = await reopened.execute(
      .init(operationId: restorationIdentifier, session: session, command: authorized.command))
    guard case .applied(let replayed, .complete(let replayCheckpoint)) = replay.outcome,
      case .exported(let persisted) = await reopened.exportData(session: session)
    else {
      Issue.record("Authorized restoration must replay: \(replay)")
      return
    }
    let reimportReview = await reopened.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: .overwrite))
    guard case .reviewed(let reimport) = reimportReview else {
      Issue.record("The restored backup must remain reviewable: \(reimportReview)")
      return
    }
    #expect(replayed == restoredResult)
    #expect(replayCheckpoint == checkpoint)
    #expect(try fixture.graph(persisted) == fixture.graph(restoredData))
    guard
      case .rejected = await reopened.execute(
        .init(
          operationId: UUID(), session: session, command: reimport.command,
          reviewToken: reimport.reviewToken)
      ).outcome,
      case .reviewed(let authorizedReimport) = await reopened.prepareReview(
        session: session,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    let reimportResult = await reopened.execute(
      .init(
        operationId: UUID(), session: session, command: authorizedReimport.command,
        reviewToken: authorizedReimport.reviewToken))
    guard case .applied(_, .complete) = reimportResult.outcome,
      case .exported(let reimported) = await reopened.exportData(session: session)
    else {
      Issue.record("Reimport must retain the current owned restoration: \(reimportResult)")
      return
    }
    #expect(try fixture.graph(reimported) == fixture.graph(restoredData))
    if scenario.hasHistory {
      let receipts = try fixture.envelope()["receipts"] as? NSArray
      let liveLinks = try await fixture.rawOwnedLinkData()
      let liveSchedules = try await fixture.rawScheduleData()
      try await fixture.deliverClosedOwnedSibling(referenceKind: referenceKind)
      let originalLinks = try await fixture.rawOwnedLinkData()
      let originalSchedules = try await fixture.rawScheduleData()
      let originalFiles = try fixture.files()
      let originalControl = try Data(contentsOf: fixture.configuration.controlURL)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
      }
      guard case .failed(let failure) = await reopened.exportData(session: session) else {
        Issue.record("Closed-sibling cleanup must first prepare independent recovery.")
        return
      }
      #expect(failure.code == "maintenanceRequired")
      #expect(try await fixture.rawOwnedLinkData() == originalLinks)
      #expect(try await fixture.rawScheduleData() == originalSchedules)
      #expect(try fixture.files() == originalFiles)
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
      let siblingOutcome = await reopened.exportData(session: session)
      guard case .exported(let survivingRestoration) = siblingOutcome else {
        Issue.record("The fresh live restoration must survive late siblings: \(siblingOutcome)")
        return
      }
      #expect(try fixture.graph(survivingRestoration) == fixture.graph(restoredData))
      #expect(try await fixture.rawOwnedLinkData() == liveLinks)
      #expect(try await fixture.rawScheduleData() == liveSchedules)
      #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    }
  }

  @Test func losingItineraryPreparationFailurePreservesStopsAndExpandedBindingsUntilRetry()
    async throws
  {
    let (fixture, before) = try await SourceRestorationFixture.makeWithOwnedItineraryStops()
    let entries = try await fixture.nativeEntryData()
    let expanded = try await fixture.rawExpandedData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.nativeEntryData() == entries)
    #expect(try await fixture.rawExpandedData() == expanded)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let original = try fixture.object(before)
    let graph = try fixture.object(after)
    for field in ["sources", "memberships", "itineraryEntries", "expandedCompletions"] {
      #expect(graph[field] as? NSArray == original[field] as? NSArray)
    }
  }

  @Test(arguments: ["owner", "source", "expanded"])
  func malformedLosingStopsRejectWithoutChangingNativeOrRecoveryData(scenario: String)
    async throws
  {
    let (fixture, _) = try await SourceRestorationFixture.makeWithOwnedItineraryStops()
    try await fixture.corruptOwnedStop(scenario)
    let entries = try await fixture.rawEntryData()
    let expanded = try await fixture.rawExpandedData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else {
      Issue.record("A malformed losing stop must reject before retirement: \(scenario)")
      return
    }
    #expect(failure.code == "readUnavailable")
    #expect(try await fixture.rawEntryData() == entries)
    #expect(try await fixture.rawExpandedData() == expanded)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
  }

  @Test(arguments: [false, true])
  func losingStopsRetainSavedDoneHistoryWithoutAffectingTheWinningRoute(expanded: Bool)
    async throws
  {
    let (fixture, before) = try await SourceRestorationFixture.makeWithOwnedItineraryStops()
    try await fixture.recordOwnedStopDone(expanded: expanded)
    let history = try await fixture.rawCompletionAuthorityData()
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try await fixture.rawCompletionAuthorityData() == history)
    let original = try fixture.object(before)
    let graph = try fixture.object(after)
    for field in ["sources", "memberships", "itineraryEntries", "expandedCompletions"] {
      #expect(graph[field] as? NSArray == original[field] as? NSArray)
    }
    let changes = try #require(graph["completionChanges"] as? [[String: Any]])
    #expect(changes.count == 1)
    #expect(changes.first?["done"] as? Bool == true)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
  }

  @Test(arguments: [false, true])
  func losingItineraryStopsRetireWithoutMergingRoutesOrDeletingSharedSources(winningRoute: Bool)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: .itinerary)
    let item = PlannerEntityReference(
      kind: .item, id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)
    let list = PlannerEntityReference(
      kind: .list, id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!)
    guard
      case .applied(let addition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membership, _, _)? = addition.generatedReferences.first
    else { throw CancellationError() }
    var entries: [UUID] = []
    if winningRoute {
      for source in [item, list, item] {
        guard
          case .applied(let added, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session,
              command: .addItineraryEntry(
                itineraryId: fixture.source.id, source: source, placement: .last))
          ).outcome,
          case .itineraryEntry(let identifier, _, _)? = added.generatedReferences.first
        else { throw CancellationError() }
        entries.append(identifier)
      }
      for appearance in [
        PlannerAppearance.directItineraryItem(itineraryId: fixture.source.id, entryId: entries[0]),
        .expandedListItem(
          itineraryId: fixture.source.id, listEntryId: entries[1], membershipId: membership),
      ] {
        guard
          case .applied(_, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session,
              command: .setCompletion(scope: .appearance(appearance), done: true))
          ).outcome
        else { throw CancellationError() }
      }
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session),
      case .source(.itinerary(let initial)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    try await fixture.deliverCandidateWithOwnedStops(membershipId: membership)
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result,
      case .source(.itinerary(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record("Only the winning Itinerary's complete route must remain live: \(result)")
      return
    }
    #expect(retained.fieldHashes == initial.fieldHashes)
    #expect(retained.progress.totalCount == initial.progress.totalCount)
    #expect(retained.progress.doneCount == initial.progress.doneCount)
    var graph = try fixture.object(after)
    let original = try fixture.object(before)
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    let identifiers = [
      "00000000-0000-4000-8000-000000000831", "00000000-0000-4000-8000-000000000833",
      "00000000-0000-4000-8000-000000000835",
    ]
    let closures = markers.filter { marker in
      guard let target = marker["target"] as? [String: Any],
        let identifier = target["id"] as? String
      else { return false }
      return target["kind"] as? String == "itineraryEntry" && identifiers.contains(identifier)
    }
    #expect(closures.count == 3)
    for (identifier, lifetime) in [
      ("00000000-0000-4000-8000-000000000831", "00000000-0000-4000-8000-000000000832"),
      ("00000000-0000-4000-8000-000000000833", "00000000-0000-4000-8000-000000000834"),
      ("00000000-0000-4000-8000-000000000835", "00000000-0000-4000-8000-000000000836"),
    ] {
      #expect(
        closures.contains { marker in
          let target = marker["target"] as? [String: Any]
          return target?["id"] as? String == identifier
            && target?["lifetimeId"] as? String == lifetime
        })
    }
    graph["deletionMarkers"] = markers.filter { marker in
      !closures.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(NSDictionary(dictionary: graph) == NSDictionary(dictionary: original))
    #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    let retiredDirect = PlannerAppearance.directItineraryItem(
      itineraryId: fixture.source.id,
      entryId: UUID(uuidString: "00000000-0000-4000-8000-000000000831")!)
    let retiredExpanded = PlannerAppearance.expandedListItem(
      itineraryId: fixture.source.id,
      listEntryId: UUID(uuidString: "00000000-0000-4000-8000-000000000833")!,
      membershipId: membership)
    for appearance in [retiredDirect, retiredExpanded] {
      guard
        case .failed = await fixture.planner.read(
          session: fixture.session, request: .appearance(appearance))
      else {
        Issue.record("Discarded stop identities must not target surviving repeated appearances.")
        return
      }
    }
    let files = try fixture.files()
    guard
      case .rejected = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setCompletion(scope: .appearance(retiredDirect), done: true))
      ).outcome
    else { throw CancellationError() }
    #expect(try fixture.files() == files)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    try await fixture.deliverCandidateWithOwnedStops(membershipId: membership)
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
  }

  @Test(arguments: [false, true])
  func retiredListChildrenKeepReopenHistoryWithoutAdoptingLateDoneFlags(expanded: Bool)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: .list)
    var entries: [UUID] = []
    if expanded {
      guard
        case .applied(let addition, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .addItineraryEntry(
              itineraryId: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
              source: fixture.source, placement: .last))
        ).outcome,
        case .itineraryEntry(let identifier, _, _)? = addition.generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try await fixture.deliverCandidateWithOwnedMembership(entries: entries)
    try await fixture.recordOwnedMembershipReopen(expandedEntry: entries.first)
    let history = try await fixture.rawCompletionAuthorityData()
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result else {
      Issue.record(
        "Retiring losing children must preserve history without adopting late flags: \(result)")
      return
    }
    #expect(try await fixture.rawCompletionAuthorityData() == history)
    let original = try fixture.object(before)
    let graph = try fixture.object(after)
    for field in ["sources", "memberships", "itineraryEntries", "expandedCompletions"] {
      #expect(graph[field] as? NSArray == original[field] as? NSArray)
    }
    let changes = try #require(graph["completionChanges"] as? [[String: Any]])
    #expect(changes.count == 1)
    #expect(changes.first?["done"] as? Bool == false)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
  }

  @Test func losingListPreparationFailurePreservesMembershipAndExpandedBindingsUntilRetry()
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: .list)
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    guard
      case .applied(let addition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addItineraryEntry(
            itineraryId: itineraryIdentifier, source: fixture.source, placement: .last))
      ).outcome,
      case .itineraryEntry(let entry, _, _)? = addition.generatedReferences.first,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try await fixture.deliverCandidateWithOwnedMembership(entries: [entry])
    let memberships = try await fixture.rawMembershipData()
    let expanded = try await fixture.rawExpandedData()
    let entries = try await fixture.rawEntryData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.rawMembershipData() == memberships)
    #expect(try await fixture.rawExpandedData() == expanded)
    #expect(try await fixture.rawEntryData() == entries)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let original = try fixture.object(before)
    let graph = try fixture.object(after)
    for field in ["sources", "memberships", "itineraryEntries", "expandedCompletions"] {
      #expect(graph[field] as? NSArray == original[field] as? NSArray)
    }
  }

  @Test(arguments: [false, true])
  func conflictingOwnedMembershipProvenanceRejectsWithoutChangingAnyAuthority(wrongItem: Bool)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: .list)
    try await fixture.deliverCandidateWithOwnedMembership(entries: [])
    try await fixture.corruptOwnedMembershipProvenance(wrongItem: wrongItem)
    let memberships = try await fixture.rawMembershipData()
    let authority = try await fixture.rawMembershipAuthorityData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else {
      Issue.record("Retirement must not accept Add provenance for another Item or List lifetime.")
      return
    }
    #expect(failure.code == "readUnavailable")
    #expect(try await fixture.rawMembershipData() == memberships)
    #expect(try await fixture.rawMembershipAuthorityData() == authority)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
  }

  @Test(arguments: [false, true], [false, true])
  func losingListMembershipsRetireWithoutMergingRepeatedBranchCompletion(
    referenced: Bool, recoveryFailure: Bool
  ) async throws {
    try await checkOwnedListRetirement(
      referenced: referenced, recoveryFailure: recoveryFailure, nativeSaveFailure: false)
  }

  private func checkOwnedListRetirement(
    referenced: Bool, recoveryFailure: Bool, nativeSaveFailure: Bool
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: .list)
    let itemIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000101")!
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    guard
      case .applied(let addition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addMembership(
            itemId: itemIdentifier, listId: fixture.source.id, placement: .last))
      ).outcome,
      case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
    else { throw CancellationError() }
    var entries: [UUID] = []
    if referenced {
      for _ in 0..<2 {
        guard
          case .applied(let added, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session,
              command: .addItineraryEntry(
                itineraryId: itineraryIdentifier, source: fixture.source, placement: .last))
          ).outcome,
          case .itineraryEntry(let identifier, _, _)? = added.generatedReferences.first
        else { throw CancellationError() }
        entries.append(identifier)
      }
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .setCompletion(
              scope: .appearance(
                .expandedListItem(
                  itineraryId: itineraryIdentifier, listEntryId: entries[1],
                  membershipId: membershipIdentifier)), done: true))
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    let originalFiles = try fixture.files()
    let originalControl = try Data(contentsOf: fixture.configuration.controlURL)
    try await fixture.deliverCandidateWithOwnedMembership(entries: entries)
    #if os(macOS)
      var unverifiedPreparation: UUID?
      var unverifiedFiles: [String: Data]?
      if nativeSaveFailure {
        let originalSources = try await fixture.rawListSourceData()
        let originalMemberships = try await fixture.rawMembershipData()
        let originalAuthority = try await fixture.rawMembershipAuthorityData()
        let originalEntries = try await fixture.rawEntryData()
        let originalExpanded = try await fixture.rawExpandedData()
        let originalCompletion = try await fixture.rawCompletionAuthorityData()
        let obstruction = NativeSaveFileSizeObstruction(
          configuration: fixture.configuration, maximumFileSize: 0)
        let observer = NotificationCenter.default.addObserver(
          forName: ModelContext.willSave, object: nil, queue: nil
        ) { notification in obstruction.observe(notification) }
        let failed = await fixture.planner.exportData(session: fixture.session)
        NotificationCenter.default.removeObserver(observer)
        try obstruction.restore()
        #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
        guard case .failed(let reason) = failed else {
          Issue.record(
            "Failed native List retirement must leave both versions unchanged: \(failed)")
          return
        }
        #expect(reason.code == "maintenanceRequired")
        #expect(try await fixture.rawListSourceData() == originalSources)
        #expect(try await fixture.rawMembershipData() == originalMemberships)
        #expect(try await fixture.rawMembershipAuthorityData() == originalAuthority)
        #expect(try await fixture.rawEntryData() == originalEntries)
        #expect(try await fixture.rawExpandedData() == originalExpanded)
        #expect(try await fixture.rawCompletionAuthorityData() == originalCompletion)
        let files = try fixture.files()
        for (name, bytes) in originalFiles { #expect(files[name] == bytes) }
        #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
        let preparations = files.filter { $0.key.hasPrefix("maintenance-") }
        #expect(preparations.count == 1)
        let preparation = try fixture.object(try #require(preparations.values.first))
        let identifier = try #require(
          (preparation["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
        guard
          case .rejected(let reason) = await fixture.planner.retryMaintenanceRecovery(
            session: fixture.session, maintenanceId: identifier)
        else { throw CancellationError() }
        #expect(reason.code == "maintenanceNotApplied")
        #expect(try fixture.files() == files)
        unverifiedPreparation = identifier
        unverifiedFiles = files
      }
    #endif
    var pendingMaintenance: UUID?
    var pendingExport: Data?
    if recoveryFailure {
      let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let committed = await fixture.planner.exportData(session: fixture.session)
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      guard case .exported(let data) = committed,
        case .status(let status) = await fixture.planner.read(
          session: fixture.session, request: .status),
        case .known(_, let operations, let maintenance, let blocked) = status.recovery
      else {
        Issue.record(
          "Committed List retirement must remain readable while recovery waits: \(committed)")
        return
      }
      #expect(operations.isEmpty && maintenance.count == 1 && blocked)
      pendingMaintenance = try #require(maintenance.first)
      pendingExport = data
      let files = try fixture.files()
      for (name, bytes) in originalFiles { #expect(files[name] == bytes) }
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
      let blockedOperation = UUID()
      guard
        case .rejected(let reason) = await fixture.planner.execute(
          .init(
            operationId: blockedOperation, session: fixture.session,
            command: .createTag(content: .init(name: "Wait for List recovery")))
        ).outcome,
        case .noReliableEvidence = await fixture.planner.operationStatus(
          session: fixture.session, operationId: blockedOperation)
      else { throw CancellationError() }
      #expect(reason.code == "mutationBlocked")
      #expect(try fixture.files() == files)
    }
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result else {
      Issue.record("Only the winning List's memberships and branch states must remain: \(result)")
      return
    }
    if let pendingExport {
      #expect(try fixture.graph(pendingExport) == fixture.graph(after))
    }
    var graph = try fixture.object(after)
    let original = try fixture.object(before)
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    let closures = markers.filter { marker in
      guard let target = marker["target"] as? [String: Any] else { return false }
      return target["kind"] as? String == "membership"
        && target["id"] as? String == "00000000-0000-4000-8000-000000000403"
        && target["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000843"
    }
    #expect(closures.count == 1)
    graph["deletionMarkers"] = markers.filter { marker in
      !closures.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    let provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    let retiredProvenance = provenance.filter {
      $0["membershipId"] as? String == "00000000-0000-4000-8000-000000000403"
    }
    #expect(retiredProvenance.count == 1)
    let list = try #require(retiredProvenance.first?["list"] as? [String: Any])
    #expect(list["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000815")
    graph["membershipProvenance"] = provenance.filter {
      $0["membershipId"] as? String != "00000000-0000-4000-8000-000000000403"
    }
    #expect(NSDictionary(dictionary: graph) == NSDictionary(dictionary: original))
    #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    #if os(macOS)
      if let unverifiedPreparation, let unverifiedFiles {
        let acknowledgements = try #require(
          fixture.envelope()["maintenanceReceipts"] as? [[String: Any]])
        #expect(acknowledgements.count == 1)
        #expect(
          acknowledgements.first?["maintenanceId"] as? String != unverifiedPreparation.uuidString)
        let files = try fixture.files()
        for (name, bytes) in unverifiedFiles { #expect(files[name] == bytes) }
      }
    #endif
    for (index, identifier) in entries.enumerated() {
      let response = await fixture.planner.read(
        session: fixture.session,
        request: .appearance(
          .expandedListItem(
            itineraryId: itineraryIdentifier, listEntryId: identifier,
            membershipId: membershipIdentifier)))
      guard case .appearance(let appearance) = response else {
        Issue.record("The winning List branch must remain readable after retirement: \(response)")
        return
      }
      #expect(appearance.localDone == (index == 1))
    }
    if let pendingMaintenance {
      let files = try fixture.files()
      guard
        case .exported(let readable) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(try fixture.graph(readable) == fixture.graph(after))
      #expect(try fixture.files() == files)
      guard
        case .complete(let checkpoint) = await fixture.planner.retryMaintenanceRecovery(
          session: fixture.session, maintenanceId: pendingMaintenance),
        case .complete(let repeated) = await fixture.planner.retryMaintenanceRecovery(
          session: fixture.session, maintenanceId: pendingMaintenance)
      else { throw CancellationError() }
      #expect(checkpoint == repeated)
      let envelope = try fixture.envelope()
      #expect(envelope["checkpointGeneration"] as? String == String(checkpoint))
      #expect(envelope["receipts"] as? NSArray == receipts)
      let maintenance = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
      #expect(maintenance.count == 1)
      #expect(maintenance.first?["maintenanceId"] as? String == pendingMaintenance.uuidString)
    }
    let retiredMembership = UUID(uuidString: "00000000-0000-4000-8000-000000000403")!
    guard
      case .failed = await fixture.planner.read(
        session: fixture.session,
        request: .appearance(
          .listMembership(listId: fixture.source.id, membershipId: retiredMembership)))
    else {
      Issue.record("The discarded membership must not redirect to the winner's membership.")
      return
    }
    for identifier in entries {
      guard
        case .failed = await fixture.planner.read(
          session: fixture.session,
          request: .appearance(
            .expandedListItem(
              itineraryId: itineraryIdentifier, listEntryId: identifier,
              membershipId: retiredMembership)))
      else {
        Issue.record("A discarded branch child must not redirect to the winning child.")
        return
      }
    }
    let files = try fixture.files()
    let staleOperationIdentifier = UUID()
    let stale = await fixture.planner.execute(
      .init(
        operationId: staleOperationIdentifier, session: fixture.session,
        command: .setCompletion(
          scope: .appearance(
            .listMembership(listId: fixture.source.id, membershipId: retiredMembership)),
          done: true)))
    guard case .rejected = stale.outcome else {
      Issue.record("Completing a discarded membership must reject without changing its survivor.")
      return
    }
    #expect(try fixture.files() == files)
    let reopened = Planner(configuration: fixture.configuration)
    let bootstrap = await reopened.bootstrap()
    guard case .ready(let session) = bootstrap else {
      Issue.record("The winning List must reopen after retirement: \(bootstrap)")
      return
    }
    let persistedResult = await reopened.exportData(session: session)
    guard case .exported(let persisted) = persistedResult else {
      Issue.record("Reopened List content must remain exportable: \(persistedResult)")
      return
    }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    try await fixture.deliverCandidateWithOwnedMembership(entries: entries)
    let redelivery = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let redelivered) = redelivery else {
      Issue.record("Late losing List delivery must not replace its survivor: \(redelivery)")
      return
    }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
  }

  @Test(arguments: [PlannerEntityKind.item, .itinerary])
  func ownedLabelPreparationFailurePreservesSelectionsAndSharedLabelsUntilRetry(
    kind: PlannerEntityKind
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    try await fixture.deliverCandidateWithOwnedLabels()
    let selections = try await fixture.rawLabelData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.rawLabelData() == selections)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    var graph = try fixture.object(after)
    let before = try fixture.object(fixture.baseline)
    let markers = try #require(graph["deletionMarkers"] as? NSArray)
    let originalMarkers = try #require(before["deletionMarkers"] as? NSArray)
    #expect(markers.count == originalMarkers.count + 2)
    graph["deletionMarkers"] = originalMarkers
    #expect(NSDictionary(dictionary: graph) == NSDictionary(dictionary: before))
  }

  @Test(arguments: [PlannerEntityKind.item, .itinerary])
  func winningSourceKeepsItsExactLabelsAndClosesLosingOwnedSelections(kind: PlannerEntityKind)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    let categoryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000501")!
    let tagIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000601")!
    let command: PlannerCommand
    switch await fixture.planner.read(session: fixture.session, request: .source(fixture.source)) {
    case .source(.item(let value)):
      command = .editItem(
        sourceId: fixture.source.id,
        changes: .init(categoryIds: .set([categoryIdentifier]), tagIds: .set([tagIdentifier])),
        expectedFieldHashes: value.fieldHashes)
    case .source(.itinerary(let value)):
      command = .editItinerary(
        sourceId: fixture.source.id,
        changes: .init(categoryIds: .set([categoryIdentifier]), tagIds: .set([tagIdentifier])),
        expectedFieldHashes: value.fieldHashes)
    default: throw CancellationError()
    }
    let operation = PlannerOperation(
      operationId: UUID(), session: fixture.session, command: command)
    guard case .applied(let original, .complete) = await fixture.planner.execute(operation).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    try await fixture.deliverCandidateWithOwnedLabels()
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result,
      case .source = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record("The winner must keep its complete label selections: \(result)")
      return
    }
    let evidence = try fixture.envelope()
    let maintenance = try #require(evidence["maintenanceReceipts"] as? [[String: Any]])
    let identifier = try #require(maintenance.first?["maintenanceId"] as? String)
    let preparation = try fixture.object(
      Data(contentsOf: fixture.namespace.appendingPathComponent("maintenance-\(identifier).json")))
    let proposed = try JSONSerialization.data(withJSONObject: preparation["proposedBackup"]!)
    #expect(try fixture.graph(proposed) == fixture.graph(after))
    var graph = try fixture.object(after)
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    let retiredIdentifiers = [
      "00000000-0000-4000-8000-000000000875", "00000000-0000-4000-8000-000000000877",
    ]
    let closures = markers.filter { marker in
      guard let target = marker["target"] as? [String: Any],
        target["kind"] as? String == "labelAssociation", let identifier = target["id"] as? String
      else { return false }
      return retiredIdentifiers.contains(identifier)
    }
    #expect(closures.count == 2)
    #expect(
      closures.contains { marker in
        let target = marker["target"] as? [String: Any]
        return target?["id"] as? String == "00000000-0000-4000-8000-000000000875"
          && target?["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000876"
      })
    #expect(
      closures.contains { marker in
        let target = marker["target"] as? [String: Any]
        return target?["id"] as? String == "00000000-0000-4000-8000-000000000877"
          && target?["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000878"
      })
    graph["deletionMarkers"] = markers.filter { marker in
      !closures.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(try NSDictionary(dictionary: graph) == fixture.graph(before))
    #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    guard case .applied(let replayed, .complete) = await fixture.planner.execute(operation).outcome
    else { throw CancellationError() }
    #expect(replayed == original)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    try await fixture.deliverCandidateWithOwnedLabels()
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
  }

  @Test(arguments: [PlannerEntityKind.item, .itinerary])
  func ownedSchedulePreparationFailurePreservesNativeDataUntilRetry(kind: PlannerEntityKind)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    try await fixture.deliverCandidateWithSchedule(allDay: false)
    let schedules = try await fixture.rawScheduleData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.rawScheduleData() == schedules)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try fixture.expectOwnedReferenceClosure(after, preserving: fixture.baseline, kind: "schedule")
  }

  @Test(arguments: [PlannerEntityKind.item, .itinerary], [false, true])
  func winningSourceKeepsItsBookingAndRejectsTheRetiredBookingIdentity(
    kind: PlannerEntityKind, allDay: Bool
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    let form: PlannerScheduleForm
    if allDay {
      form = .allDay(start: .init(year: 2026, month: 10, day: 26), end: nil)
    } else {
      form = .timed(
        start: Date(timeIntervalSinceReferenceDate: 1000),
        end: Date(timeIntervalSinceReferenceDate: 2000), planningTimeZone: "Asia/Tokyo")
    }
    let creation = PlannerOperation(
      operationId: UUID(), session: fixture.session,
      command: .createSchedule(source: fixture.source, form: form))
    let originalResult = await fixture.planner.execute(creation)
    guard case .applied(let addition, .complete) = originalResult.outcome,
      let booking = addition.generated.first, booking.kind == .schedule,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else {
      Issue.record("The winning source's initial booking must save: \(originalResult)")
      return
    }
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    try await fixture.deliverCandidateWithSchedule(allDay: allDay)
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result,
      case .source(.schedule(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(booking))
    else {
      Issue.record("Only the winning source's booking must remain live: \(result)")
      return
    }
    #expect(retained.content.source == fixture.source)
    #expect(retained.content.form == form)
    try fixture.expectOwnedReferenceClosure(after, preserving: before, kind: "schedule")
    #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    let retiredBooking = PlannerEntityReference(
      kind: .schedule, id: UUID(uuidString: "00000000-0000-4000-8000-000000000873")!)
    guard
      case .failed = await fixture.planner.read(
        session: fixture.session, request: .source(retiredBooking))
    else {
      Issue.record("The discarded booking identity must not redirect to the winning booking.")
      return
    }
    guard case .applied(let replayed, .complete) = await fixture.planner.execute(creation).outcome
    else { throw CancellationError() }
    #expect(replayed == addition)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    try await fixture.deliverCandidateWithSchedule(allDay: allDay)
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
  }

  @Test func sourceWinnerKeepsItsOwnLinksWithoutAdoptingLosingContents() async throws {
    let fixture = try await SourceRestorationFixture.make()
    guard
      case .source(.item(let initial)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    let edit = PlannerOperation(
      operationId: UUID(), session: fixture.session,
      command: .editItem(
        sourceId: fixture.source.id,
        changes: .init(
          links: .set([.init(originalUrl: "https://example.com/winner", label: "Guide A")])),
        expectedFieldHashes: initial.fieldHashes))
    guard case .applied(_, .complete) = await fixture.planner.execute(edit).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session),
      case .source(.item(let winner)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    let originalRecovery = try fixture.envelope()
    let originalLifetimes = try await fixture.itemLifetimes()
    try await fixture.deliverCandidateWithOwnedLink()
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result,
      case .source(.item(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record("The winning Item's complete link collection must remain readable: \(result)")
      return
    }
    #expect(retained.content.links.count == 1)
    #expect(retained.content.links.first?.originalUrl == "https://example.com/winner")
    #expect(retained.content.links.first?.linkId == winner.content.links.first?.linkId)
    #expect(retained.fieldHashes == winner.fieldHashes)
    try fixture.expectOwnedReferenceClosure(after, preserving: before, kind: "link")
    let expected = try fixture.object(before)
    let actual = try fixture.object(after)
    #expect(actual["sources"] as? NSArray == expected["sources"] as? NSArray)
    #expect(actual["ownedLinks"] as? NSArray == expected["ownedLinks"] as? NSArray)
    #expect(
      actual["restorationFamilies"] as? NSArray == expected["restorationFamilies"] as? NSArray)
    #expect(!String(decoding: after, as: UTF8.self).contains("https://example.com/loser"))
    #expect(try await fixture.itemLifetimes() == originalLifetimes)
    let envelope = try fixture.envelope()
    #expect(envelope["receipts"] as? NSArray == originalRecovery["receipts"] as? NSArray)
    let receipts = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(receipts.count == 1)
    let receipt = try #require(receipts.first)
    #expect(receipt["kind"] as? String == "sourceRestorationConsolidation")
    let identifier = try #require(receipt["maintenanceId"] as? String)
    let preparation = try fixture.object(
      Data(contentsOf: fixture.namespace.appendingPathComponent("maintenance-\(identifier).json")))
    #expect(
      try fixture.graph(JSONSerialization.data(withJSONObject: preparation["proposedBackup"]!))
        == fixture.graph(after))
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let reopenedItem)) = await reopened.read(
        session: session, request: .source(fixture.source))
    else { throw CancellationError() }
    #expect(reopenedItem.content.links.first?.linkId == winner.content.links.first?.linkId)
    #expect(reopenedItem.content.links.count == 1)
    try await fixture.deliverCandidateWithOwnedLink()
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
    #expect(
      try fixture.envelope()["receipts"] as? NSArray == originalRecovery["receipts"] as? NSArray)
  }

  @Test func losingItineraryLinksDoNotChangeItsWinnerOrIndependentItems() async throws {
    let fixture = try await SourceRestorationFixture.make(kind: .itinerary)
    guard
      case .source(.itinerary(let winner)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    try await fixture.deliverCandidateWithOwnedLink()
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result,
      case .source(.itinerary(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record("A losing Itinerary's links must not replace the winning contents: \(result)")
      return
    }
    #expect(retained.content.links.isEmpty)
    #expect(retained.fieldHashes == winner.fieldHashes)
    try fixture.expectOwnedReferenceClosure(after, preserving: fixture.baseline, kind: "link")
  }

  @Test func ownedLinkPreparationFailurePreservesNativeDataUntilRetry() async throws {
    let fixture = try await SourceRestorationFixture.make()
    try await fixture.deliverCandidateWithOwnedLink()
    let originalFiles = try fixture.files()
    let originalLifetimes = try await fixture.itemLifetimes()
    let originalLinks = try await fixture.rawOwnedLinkData()
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try fixture.files() == originalFiles)
    #expect(try await fixture.itemLifetimes() == originalLifetimes)
    #expect(try await fixture.rawOwnedLinkData() == originalLinks)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard case .exported(let recovered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try fixture.expectOwnedReferenceClosure(recovered, preserving: fixture.baseline, kind: "link")
  }

  @Test(arguments: [PlannerEntityKind.item, .list, .itinerary, .category, .tag])
  func everySourceKindRetainsItsExactWinnerAndTruthfulMaintenance(kind: PlannerEntityKind)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    let originalRecovery = try fixture.envelope()
    try await fixture.deliverCandidate()
    let normalized = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let data) = normalized,
      case .source = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else {
      Issue.record(
        "A declared losing \(kind) candidate must leave its winner readable: \(normalized)")
      return
    }
    #expect(try fixture.graph(data) == fixture.graph(fixture.baseline))
    let envelope = try fixture.envelope()
    #expect(envelope["formatVersion"] as? Int == 2)
    #expect(envelope["storageSchemaVersion"] as? String == "23")
    #expect(envelope["receipts"] as? NSArray == originalRecovery["receipts"] as? NSArray)
    let receipts = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(receipts.count == 1)
    let receipt = try #require(receipts.first)
    #expect(receipt["kind"] as? String == "sourceRestorationConsolidation")
    #expect(receipt["ruleVersion"] as? Int == 3)
    let identifier = try #require(receipt["maintenanceId"] as? String)
    let preparation = try fixture.object(
      Data(contentsOf: fixture.namespace.appendingPathComponent("maintenance-\(identifier).json")))
    #expect(preparation["evidence"] as? String == "preparedUnverified")
    #expect(preparation["kind"] as? String == "sourceRestorationConsolidation")
    #expect(
      try fixture.graph(JSONSerialization.data(withJSONObject: preparation["proposedBackup"]!))
        == fixture.graph(fixture.baseline))
    let coherentFiles = try fixture.files()
    guard case .exported = await fixture.planner.exportData(session: fixture.session) else {
      throw CancellationError()
    }
    #expect(try fixture.files() == coherentFiles)
    try await fixture.deliverCandidate()
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(fixture.baseline))
    let retriedReceipts = try #require(
      fixture.envelope()["maintenanceReceipts"] as? [[String: Any]])
    #expect(retriedReceipts.count == 2)
    #expect(Set(retriedReceipts.compactMap { $0["maintenanceId"] as? String }).count == 2)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(reopenedData) == fixture.graph(fixture.baseline))
  }
  @Test(arguments: [
    "unknown", "missingWinner", "scalarLink", "scalarMembership", "scalarEntry", "scalarSchedule",
    "scalarLabel",
  ])
  func unresolvedCandidateInputsPreserveEveryRecoveryByte(scenario: String) async throws {
    let fixture = try await SourceRestorationFixture.make()
    try await fixture.deliverCandidate()
    try await fixture.makeUnresolved(scenario)
    let original = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    let lifetimes = try await fixture.itemLifetimes()
    guard case .failed = await fixture.planner.exportData(session: fixture.session) else {
      Issue.record("Unproven or referenced candidates must remain unavailable: \(scenario)")
      return
    }
    #expect(try fixture.files() == original)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    #expect(try await fixture.itemLifetimes() == lifetimes)
  }

  @Test(
    arguments: ["ordinary", "recoveryFailure", "controlFailure", "unproven", "invalidEntry"],
    [false, true])
  func compatibilityProjectionPrecedesActivationAndPhysicalRetirement(
    scenario: String, directEntries: Bool
  )
    async throws
  {
    let fixture = try await SourceRestorationFixture.makeWithEntries(directEntries)
    try await fixture.deliverCandidateWithEntries(directEntries)
    if scenario == "unproven" { try await fixture.makeUnresolved("unknown") }
    if scenario == "invalidEntry" {
      if directEntries {
        try await fixture.corruptEntry("scalarMismatch")
      } else {
        try await fixture.makeUnresolved("scalarEntry")
      }
    }
    try fixture.rewriteCompatibility(directEntries ? 21 : 20)
    let originalFiles = try fixture.files()
    let originalControl = try Data(contentsOf: fixture.configuration.controlURL)
    let originalLifetimes = try await fixture.itemLifetimes()
    let share = Planner(
      configuration: .init(
        storeURL: fixture.configuration.storeURL, controlURL: fixture.configuration.controlURL,
        recoveryDirectoryURL: fixture.configuration.recoveryDirectoryURL,
        processRole: .shareExtension, storageMode: .localOnly))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      throw CancellationError()
    }
    #expect(try fixture.files() == originalFiles)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
    let upgraded = Planner(configuration: fixture.configuration)
    if scenario != "ordinary" {
      let obstructed: URL
      if scenario == "controlFailure" {
        obstructed = fixture.configuration.controlURL.deletingLastPathComponent()
      } else {
        obstructed = fixture.namespace
      }
      if scenario != "unproven" && scenario != "invalidEntry" {
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o500], ofItemAtPath: obstructed.path)
      }
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: obstructed.path)
      }
      guard case .unavailable = await upgraded.bootstrap() else {
        Issue.record("A failed source projection/activation must not activate writers: \(scenario)")
        return
      }
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
      #expect(try await fixture.itemLifetimes() == originalLifetimes)
      if scenario == "controlFailure" {
        let envelope = try fixture.envelope()
        #expect(envelope["storageSchemaVersion"] as? String == "23")
        #expect((envelope["maintenanceReceipts"] as? [Any] ?? []).isEmpty)
        let bytes = try #require(
          (envelope["portablePayloadBase64"] as? String).flatMap { Data(base64Encoded: $0) })
        #expect(try fixture.graph(bytes) == fixture.graph(fixture.baseline))
        #expect(try fixture.files().keys.filter { $0.hasPrefix("maintenance-") }.isEmpty)
      } else {
        #expect(try fixture.files() == originalFiles)
      }
      if scenario == "unproven" || scenario == "invalidEntry" { return }
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: obstructed.path)
      guard case .mainAppMigrationRequired = await share.bootstrap() else {
        throw CancellationError()
      }
    }
    guard case .ready(let session) = await upgraded.bootstrap(),
      case .exported(let data) = await upgraded.exportData(session: session),
      case .ready = await share.bootstrap()
    else { throw CancellationError() }
    #expect(try fixture.graph(data) == fixture.graph(fixture.baseline))
    let control = try fixture.object(Data(contentsOf: fixture.configuration.controlURL))
    #expect(control["schemaVersion"] as? Int == 23)
    let originalIdentity = try fixture.object(originalControl)
    for field in ["datasetId", "epochId", "namespaceId", "ownershipBinding"] {
      #expect(control[field] as? String == originalIdentity[field] as? String)
    }
    #expect(
      try await fixture.itemLifetimes().filter { $0 == "00000000-0000-4000-8000-000000000815" }
        .isEmpty)
    let maintenance = try #require(fixture.envelope()["maintenanceReceipts"] as? [[String: Any]])
    #expect(
      maintenance.count == 1
        && maintenance.first?["kind"] as? String == "sourceRestorationConsolidation")
    for (name, bytes) in originalFiles where name != "identity.json" {
      #expect(try fixture.files()[name] == bytes)
    }
  }

  @Test(arguments: [false, true])
  func independentNativeDeliveryInvalidatesAnOpenReaderWithoutChangingItsSource(
    directEntries: Bool
  ) async throws {
    let fixture = try await SourceRestorationFixture.makeWithEntries(directEntries)
    let reader = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reader.bootstrap(),
      case .source(.item(let original)) = await reader.read(
        session: session, request: .source(fixture.source))
    else { throw CancellationError() }
    let changes = await reader.changes(session: session)
    try await Task.sleep(for: .milliseconds(100))
    try await fixture.deliverCandidateWithEntries(directEntries)
    guard case .exported = await fixture.planner.exportData(session: fixture.session) else {
      throw CancellationError()
    }
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        for try await change in changes {
          if case .dataChanged = change.payload { return }
        }
        throw CancellationError()
      }
      group.addTask {
        try await Task.sleep(for: .seconds(5))
        throw CancellationError()
      }
      defer { group.cancelAll() }
      try await group.next()
    }
    guard
      case .snapshot(let query) = await reader.query(
        .init(
          session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .source(.item(let current)) = await reader.read(
        session: session, request: .source(fixture.source)),
      case .exported(let data) = await reader.exportData(session: session)
    else { throw CancellationError() }
    #expect(query.matchingCount == 2)
    #expect(current.source == original.source && current.content.title == original.content.title)
    #expect(current.updatedAt == original.updatedAt && current.fieldHashes == original.fieldHashes)
    #expect(try fixture.graph(data) == fixture.graph(fixture.baseline))
  }

  @Test(arguments: [false, true])
  func failedPreparationRetainsBothNativeCandidatesUntilFreshRetry(directEntries: Bool) async throws
  {
    let fixture = try await SourceRestorationFixture.makeWithEntries(directEntries)
    try await fixture.deliverCandidateWithEntries(directEntries)
    let original = try fixture.files()
    let lifetimes = try await fixture.itemLifetimes()
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let reason) = await fixture.planner.exportData(session: fixture.session)
    else {
      throw CancellationError()
    }
    #expect(reason.code == "maintenanceRequired")
    #expect(try fixture.files() == original)
    #expect(try await fixture.itemLifetimes() == lifetimes)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard case .exported(let data) = await fixture.planner.exportData(session: fixture.session)
    else {
      throw CancellationError()
    }
    #expect(try fixture.graph(data) == fixture.graph(fixture.baseline))
  }

  @Test(arguments: [false, true])
  func committedSourceRetirementBlocksWritesUntilItsRecoveryRetry(directEntries: Bool) async throws
  {
    let fixture = try await SourceRestorationFixture.makeWithEntries(directEntries)
    try await fixture.deliverCandidateWithEntries(directEntries)
    let original = try fixture.envelope()
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) {
      notification in obstruction.observe(notification)
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.createTag(content: .init(name: "Waiting for source maintenance"))
    guard
      case .rejected = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    guard case .exported(let data) = await fixture.planner.exportData(session: fixture.session),
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(_, let operations, let pending, let blocked) = status.recovery,
      let maintenanceIdentifier = pending.first,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(try fixture.graph(data) == fixture.graph(fixture.baseline))
    #expect(operations.isEmpty && blocked && pending.count == 1)
    #expect(
      try fixture.envelope()["checkpointGeneration"] as? String == original["checkpointGeneration"]
        as? String)
    guard
      case .complete = await fixture.planner.retryMaintenanceRecovery(
        session: fixture.session, maintenanceId: maintenanceIdentifier)
    else { throw CancellationError() }
    let committed = try fixture.envelope()
    #expect(committed["receipts"] as? NSArray == original["receipts"] as? NSArray)
    let receipts = try #require(committed["maintenanceReceipts"] as? [[String: Any]])
    #expect(
      receipts.count == 1
        && receipts.first?["maintenanceId"] as? String == maintenanceIdentifier.uuidString)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session, command: command)
      ).outcome
    else { throw CancellationError() }
  }

}

private struct SourceRestorationFixture {
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let source: PlannerEntityReference
  let namespace: URL
  let baseline: Data

  static func make(kind: PlannerEntityKind = .item, includeRestoredList: Bool = false) async throws
    -> Self
  {
    var incoming = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    var sources = try #require(incoming["sources"] as? [[String: Any]])
    let index = try #require(sources.firstIndex { $0["kind"] as? String == kind.rawValue })
    let sourceIdentifier = try #require(sources[index]["id"] as? String)
    let predecessorLifetime = try #require(sources[index]["lifetimeId"] as? String)
    sources[index]["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    incoming["sources"] = sources
    for field in [
      "memberships", "itineraryEntries", "expandedCompletions", "schedules", "labelAssociations",
      "ownedLinks", "contextAliases", "completionChanges",
    ] { incoming[field] = [] }
    let predecessor: [String: Any] = [
      "kind": kind.rawValue, "id": sourceIdentifier, "lifetimeId": predecessorLifetime,
    ]
    incoming["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000892",
        "operationId": "00000000-0000-4000-8000-000000000992",
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ]
    ]
    incoming["restorationFamilies"] = [
      [
        "familyId": "00000000-0000-4000-8000-000000000890", "predecessor": predecessor,
        "candidates": [
          [
            "lifetimeId": "00000000-0000-4000-8000-000000000814",
            "operationId": "00000000-0000-4000-8000-000000000994",
          ],
          [
            "lifetimeId": "00000000-0000-4000-8000-000000000815",
            "operationId": "00000000-0000-4000-8000-000000000995",
          ],
        ],
      ]
    ]
    if includeRestoredList {
      let listIndex = try #require(sources.firstIndex { $0["kind"] as? String == "list" })
      let listPredecessor: [String: Any] = [
        "kind": "list", "id": try #require(sources[listIndex]["id"] as? String),
        "lifetimeId": try #require(sources[listIndex]["lifetimeId"] as? String),
      ]
      sources[listIndex]["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
      incoming["sources"] = sources
      var markers = try #require(incoming["deletionMarkers"] as? [[String: Any]])
      markers.append([
        "deletionId": "00000000-0000-4000-8000-000000000893",
        "operationId": "00000000-0000-4000-8000-000000000993",
        "target": ["kind": "source", "source": listPredecessor], "closedFamilyId": NSNull(),
      ])
      incoming["deletionMarkers"] = markers
      var families = try #require(incoming["restorationFamilies"] as? [[String: Any]])
      var listFamily = try #require(families.first)
      listFamily["familyId"] = "00000000-0000-4000-8000-000000000891"
      listFamily["predecessor"] = listPredecessor
      families.append(listFamily)
      incoming["restorationFamilies"] = families
    }
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let baseline) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespaceIdentifier = namespaces.first?.namespaceId
    else { throw CancellationError() }
    return .init(
      configuration: configuration, planner: planner, session: session,
      source: .init(kind: kind, id: try #require(UUID(uuidString: sourceIdentifier))),
      namespace: configuration.recoveryDirectoryURL.appendingPathComponent(
        namespaceIdentifier.uuidString),
      baseline: baseline)
  }

  static func makeWithOwnedItineraryStops() async throws -> (fixture: Self, before: Data) {
    let fixture = try await make(kind: .itinerary)
    guard
      case .applied(let addition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addMembership(
            itemId: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
            listId: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!, placement: .last))
      ).outcome,
      case .membership(let membership, _, _)? = addition.generatedReferences.first,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try await fixture.deliverCandidateWithOwnedStops(membershipId: membership)
    return (fixture, before)
  }

  static func makeWithEntries(_ directEntries: Bool) async throws -> Self {
    let fixture = try await make()
    guard directEntries else { return fixture }
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    for done in [false, true] {
      guard
        case .applied(let result, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .addItineraryEntry(
              itineraryId: itineraryIdentifier, source: fixture.source, placement: .last))
        ).outcome,
        case .itineraryEntry(let identifier, _, _)? = result.generatedReferences.first
      else { throw CancellationError() }
      if done {
        guard
          case .applied(_, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session,
              command: .setCompletion(
                scope: .appearance(
                  .directItineraryItem(itineraryId: itineraryIdentifier, entryId: identifier)),
                done: true))
          ).outcome
        else { throw CancellationError() }
      }
    }
    guard
      case .exported(let withEntries) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let references = Self(
      configuration: fixture.configuration, planner: fixture.planner, session: fixture.session,
      source: fixture.source, namespace: fixture.namespace, baseline: withEntries)
    guard
      case .decoded(let backup) = fixture.planner.decodeImport(
        try references.siblingMembershipData(formatVersion: 5)),
      case .reviewed(let review) = await fixture.planner.prepareReview(
        session: fixture.session, command: .applyImport(backup: backup, mode: .overwrite)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let baseline) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let saved) = fixture.planner.decodeImport(baseline)
    else { throw CancellationError() }
    #expect(saved.backup.memberships.count == 1 && saved.backup.itineraryEntries.count == 2)
    #expect(
      saved.backup.membershipProvenance.first?.item.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000815")
    return .init(
      configuration: fixture.configuration, planner: fixture.planner, session: fixture.session,
      source: fixture.source, namespace: fixture.namespace, baseline: baseline)
  }

  func deliverCandidateWithEntries(_ directEntries: Bool) async throws {
    try await deliverCandidate()
    guard directEntries else { return }
    let entries = try #require(object(baseline)["itineraryEntries"] as? [[String: Any]])
    try await bindEntriesToLosingCandidate(
      entries.map { try #require(($0["id"] as? String).flatMap(UUID.init(uuidString:))) })
    try await bindMembershipsToLosingCandidate()
  }

  @MainActor func bindMembershipsToLosingCandidate() throws {
    let context = try nativeContext()
    let candidate = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
        $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      })
    for membership in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()) {
      membership.itemLifetimeId = candidate.lifetimeId
      membership.item = candidate
    }
    try context.save()
  }

  func siblingMembershipData(formatVersion: Int) throws -> Data {
    var graph = try object(baseline)
    let membershipIdentifier = "00000000-0000-4000-8000-000000000403"
    let membershipLifetime = "00000000-0000-4000-8000-000000000843"
    let list: [String: Any] = [
      "kind": "list", "id": "00000000-0000-4000-8000-000000000201",
      "lifetimeId": "00000000-0000-4000-8000-000000000821",
    ]
    let item: [String: Any] = [
      "kind": "item", "id": source.id.uuidString,
      "lifetimeId": "00000000-0000-4000-8000-000000000814",
    ]
    var attestedItem = item
    attestedItem["lifetimeId"] = "00000000-0000-4000-8000-000000000815"
    graph["memberships"] = [
      [
        "id": membershipIdentifier, "lifetimeId": membershipLifetime,
        "list": list, "item": item, "rank": "0", "localDone": false,
      ]
    ]
    graph["membershipProvenance"] = [
      [
        "membershipId": membershipIdentifier, "membershipLifetimeId": membershipLifetime,
        "list": list, "item": attestedItem, "observedRemovalIds": [],
      ]
    ]
    graph["formatVersion"] = formatVersion
    return try JSONSerialization.data(withJSONObject: graph)
  }

  func object(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func graph(_ data: Data) throws -> NSDictionary {
    try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  func expectOwnedReferenceClosure(_ data: Data, preserving before: Data, kind: String) throws {
    var actual = try object(data)
    let original = try object(before)
    let originalMarkers = try #require(original["deletionMarkers"] as? [[String: Any]])
    let markers = try #require(actual["deletionMarkers"] as? [[String: Any]])
    let additions = markers.filter { marker in
      !originalMarkers.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(additions.count == 1)
    let closure = try #require(additions.first)
    let target = try #require(closure["target"] as? NSDictionary)
    let expected: [String: Any]
    if kind == "link" {
      expected = [
        "kind": "ownedLink", "id": "00000000-0000-4000-8000-000000000871",
        "lifetimeId": "00000000-0000-4000-8000-000000000872",
      ]
    } else {
      expected = [
        "kind": "source",
        "source": [
          "kind": "schedule", "id": "00000000-0000-4000-8000-000000000873",
          "lifetimeId": "00000000-0000-4000-8000-000000000874",
        ],
      ]
    }
    #expect(target == NSDictionary(dictionary: expected))
    actual["deletionMarkers"] = markers.filter { marker in
      !additions.contains { NSDictionary(dictionary: $0) == NSDictionary(dictionary: marker) }
    }
    #expect(NSDictionary(dictionary: actual) == NSDictionary(dictionary: original))
  }

  func files() throws -> [String: Data] {
    try Dictionary(
      uniqueKeysWithValues: FileManager.default.contentsOfDirectory(
        at: namespace, includingPropertiesForKeys: nil
      ).map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
  }

  func envelope() throws -> [String: Any] {
    let checkpoints = try files().filter {
      $0.key.hasPrefix("checkpoint-") && $0.key.hasSuffix(".json")
    }
    let envelopes = try checkpoints.values.map { try object($0) }
    return try #require(
      envelopes.max {
        Int64($0["checkpointGeneration"] as? String ?? "")! < Int64(
          $1["checkpointGeneration"] as? String ?? "")!
      })
  }

  func rewriteCompatibility(_ version: Int = 20) throws {
    for file in [configuration.controlURL, namespace.appendingPathComponent("identity.json")] {
      var identity = try object(Data(contentsOf: file))
      identity["schemaVersion"] = version
      try JSONSerialization.data(withJSONObject: identity).write(to: file, options: .atomic)
    }
    for (name, bytes) in try files() where name.hasPrefix("checkpoint-") {
      var envelope = try object(bytes)
      envelope["storageSchemaVersion"] = String(version)
      try JSONSerialization.data(withJSONObject: envelope).write(
        to: namespace.appendingPathComponent(name), options: .atomic)
    }
  }

  @MainActor func nativeSourceLifetimes() throws -> [UUID] {
    let context = try nativeContext()
    let lifetimes: [UUID?]
    switch source.kind {
    case .item:
      lifetimes = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).filter {
        $0.id == source.id
      }.map(\.lifetimeId)
    case .list:
      lifetimes = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).filter {
        $0.id == source.id
      }.map(\.lifetimeId)
    case .itinerary:
      lifetimes = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).filter {
        $0.id == source.id
      }.map(\.lifetimeId)
    case .category:
      lifetimes = try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).filter {
        $0.id == source.id
      }.map(\.lifetimeId)
    case .tag:
      lifetimes = try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).filter {
        $0.id == source.id
      }.map(\.lifetimeId)
    default: throw CancellationError()
    }
    return try lifetimes.map { try #require($0) }.sorted { $0.uuidString < $1.uuidString }
  }

  @MainActor func itemLifetimes() throws -> [String] {
    let context = try nativeContext()
    return try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).compactMap(\.lifetimeId).map(
      \.uuidString
    ).sorted()
  }

  @MainActor func makeUnresolved(_ scenario: String) throws {
    let context = try nativeContext()
    let items = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())
    let candidate = try #require(
      items.first {
        $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      })
    switch scenario {
    case "unknown": candidate.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000816")!
    case "missingWinner":
      let winner = try #require(
        items.first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000814"
        })
      context.delete(winner)
    case "scalarLink":
      let link = try PlannerSchemaV18.OwnedLink(
        input: .init(originalUrl: "https://example.com/losing"), rank: 0, owner: candidate)
      context.insert(link)
      link.itemOwner = nil
    case "scalarEntry":
      let itinerary = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first)
      let entry = PlannerSchemaV18.ItineraryEntry(
        snapshot: .init(
          id: UUID(), lifetimeId: UUID(),
          itinerary: .init(kind: "itinerary", id: itinerary.id!, lifetimeId: itinerary.lifetimeId!),
          source: .init(kind: "item", id: source.id, lifetimeId: candidate.lifetimeId!),
          rank: 0, localDone: true), itinerary: itinerary, item: candidate, list: nil)
      context.insert(entry)
      entry.item = nil
    case "scalarSchedule":
      let schedule = try PlannerSchemaV18.Schedule(
        snapshot: .init(
          id: UUID(), lifetimeId: UUID(),
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 100), end: nil,
            planningTimeZone: "Asia/Tokyo")), owner: candidate)
      context.insert(schedule)
      schedule.itemOwner = nil
    case "scalarLabel":
      let category = try #require(context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first)
      let association = PlannerSchemaV18.LabelAssociation(item: candidate, category: category)
      context.insert(association)
      association.itemOwner = nil
    case "scalarMembership":
      let list = try #require(context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first)
      let member = PlannerSchemaV18.Membership(
        snapshot: .init(
          id: UUID(), lifetimeId: UUID(),
          list: .init(kind: "list", id: list.id!, lifetimeId: list.lifetimeId!),
          item: .init(kind: "item", id: source.id, lifetimeId: candidate.lifetimeId!), rank: 0,
          localDone: true), list: list, item: candidate)
      context.insert(member)
      member.item = nil
    default: throw CancellationError()
    }
    try context.save()
  }

  @MainActor func deliverSiblingMembership(
    expandedEntryIdentifier: UUID? = nil, observedRemovals: [UUID] = []
  ) throws
    -> UUID
  {
    try deliverCandidate()
    let context = try nativeContext()
    let candidate = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
        $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      })
    let list = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000201"
      })
    let identifier = UUID(uuidString: "00000000-0000-4000-8000-000000000403")!
    let lifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000843")!
    let snapshot = MembershipSnapshot(
      id: identifier, lifetimeId: lifetime,
      list: .init(kind: "list", id: list.id!, lifetimeId: list.lifetimeId!),
      item: .init(kind: "item", id: source.id, lifetimeId: candidate.lifetimeId!),
      rank: 0, localDone: true)
    let membership = PlannerSchemaV18.Membership(snapshot: snapshot, list: list, item: candidate)
    context.insert(membership)
    if let expandedEntryIdentifier {
      let entry = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).first {
          $0.id == expandedEntryIdentifier
        })
      context.insert(
        PlannerSchemaV18.ExpandedCompletion(
          listEntry: entry, membership: membership, localDone: true))
    }
    context.insert(
      PlannerSchemaV19.MembershipProvenance(
        membershipId: identifier, membershipLifetimeId: lifetime,
        recordData: try JSONEncoder().encode(
          PlannerPortableMembershipProvenance(
            membershipId: identifier, membershipLifetimeId: lifetime,
            list: snapshot.baselineProvenance.list, item: snapshot.baselineProvenance.item,
            observedRemovalIds: observedRemovals))))
    try context.save()
    #expect(
      try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).count
        == (expandedEntryIdentifier == nil ? 0 : 1))
    return identifier
  }

  @MainActor func bindLabelToLosingCandidate() throws {
    let context = try nativeContext()
    let associations = try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>())
      .filter {
        $0.labelId == source.id
      }
    #expect(!associations.isEmpty)
    let lifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!
    if source.kind == .category {
      let category = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
          $0.id == source.id && $0.lifetimeId == lifetime
        })
      for association in associations {
        association.category = category
        association.labelLifetimeId = lifetime
      }
    } else {
      let tag = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first {
          $0.id == source.id && $0.lifetimeId == lifetime
        })
      for association in associations {
        association.tag = tag
        association.labelLifetimeId = lifetime
      }
    }
    try context.save()
  }

  @MainActor func invalidateLabelTarget(_ scenario: String) throws {
    let context = try nativeContext()
    let association = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()).first {
        $0.labelId == source.id
      })
    let winnerLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000814")!
    if scenario == "scalarMismatch" {
      association.labelLifetimeId = winnerLifetime
    } else if scenario == "ownerMismatch" {
      association.itemOwner = nil
    } else if source.kind == .category {
      let category = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
          $0.id == source.id && $0.lifetimeId == winnerLifetime
        })
      if let owner = association.itemOwner {
        context.insert(PlannerSchemaV18.LabelAssociation(item: owner, category: category))
      } else {
        context.insert(
          PlannerSchemaV18.LabelAssociation(
            itinerary: try #require(association.itineraryOwner), category: category))
      }
    } else {
      let tag = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first {
          $0.id == source.id && $0.lifetimeId == winnerLifetime
        })
      if let owner = association.itemOwner {
        context.insert(PlannerSchemaV18.LabelAssociation(item: owner, tag: tag))
      } else {
        context.insert(
          PlannerSchemaV18.LabelAssociation(
            itinerary: try #require(association.itineraryOwner), tag: tag))
      }
    }
    try context.save()
  }

  @MainActor func rawLabelData() throws -> Data {
    let context = try nativeContext()
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>())
    let values = records.map { association in
      [
        "id": association.id?.uuidString ?? "",
        "lifetime": association.lifetimeId?.uuidString ?? "",
        "owner": association.ownerId?.uuidString ?? "",
        "ownerLifetime": association.ownerLifetimeId?.uuidString ?? "",
        "ownerObject":
          (association.itemOwner?.lifetimeId ?? association.itineraryOwner?.lifetimeId)?.uuidString
          ?? "",
        "label": association.labelId?.uuidString ?? "",
        "labelLifetime": association.labelLifetimeId?.uuidString ?? "",
        "labelObject": (association.category?.lifetimeId ?? association.tag?.lifetimeId)?.uuidString
          ?? "",
      ]
    }.sorted { ($0["id"] ?? "") < ($1["id"] ?? "") }
    return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
  }

  @MainActor func identifyLabelCollision(losingTargetIsSmaller: Bool) throws {
    let context = try nativeContext()
    let associations = try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>())
      .filter { $0.labelId == source.id }
    #expect(associations.count == 2)
    for association in associations {
      let selectsLoser =
        association.labelLifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      let isSmaller = selectsLoser == losingTargetIsSmaller
      if isSmaller {
        association.id = UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
        association.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000801")!
      } else {
        association.id = UUID(uuidString: "00000000-0000-4000-8000-000000000702")!
        association.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000802")!
      }
    }
    try context.save()
  }

  @MainActor func redeliverClosedLabelAssociation(targetsLoser: Bool) throws {
    let context = try nativeContext()
    let retained = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000701"
      })
    let lifetime: UUID
    if targetsLoser {
      lifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!
    } else {
      lifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000814")!
    }
    let association: PlannerSchemaV18.LabelAssociation
    if source.kind == .category {
      let category = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
          $0.id == source.id && $0.lifetimeId == lifetime
        })
      if let owner = retained.itemOwner {
        association = .init(item: owner, category: category)
      } else {
        association = .init(itinerary: try #require(retained.itineraryOwner), category: category)
      }
    } else {
      let tag = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first {
          $0.id == source.id && $0.lifetimeId == lifetime
        })
      if let owner = retained.itemOwner {
        association = .init(item: owner, tag: tag)
      } else {
        association = .init(itinerary: try #require(retained.itineraryOwner), tag: tag)
      }
    }
    association.id = UUID(uuidString: "00000000-0000-4000-8000-000000000702")!
    association.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000802")!
    context.insert(association)
    try context.save()
  }

  @MainActor func corruptEntry(_ scenario: String) throws {
    let context = try nativeContext()
    let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
    let entry = try #require(entries.first)
    switch scenario {
    case "nilItem": entry.item = nil
    case "scalarMismatch":
      entry.sourceLifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000814")!
    case "nilOwner": entry.itinerary = nil
    case "ownerLifetime": entry.itineraryLifetimeId = UUID()
    case "nilCompletion": entry.localDone = nil
    case "completionHistory":
      let completed = try #require(entries.first { $0.localDone == true })
      completed.localDone = false
    default: throw CancellationError()
    }
    try context.save()
  }

  @MainActor func rawEntryData() throws -> Data {
    let context = try nativeContext()
    let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).sorted {
      ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "")
    }
    let values: [[String: Any]] = entries.map { entry in
      [
        "id": entry.id?.uuidString as Any? ?? NSNull(),
        "lifetime": entry.lifetimeId?.uuidString as Any? ?? NSNull(),
        "owner": entry.itineraryId?.uuidString as Any? ?? NSNull(),
        "ownerLifetime": entry.itineraryLifetimeId?.uuidString as Any? ?? NSNull(),
        "nativeOwner": entry.itinerary?.id?.uuidString as Any? ?? NSNull(),
        "nativeOwnerLifetime": entry.itinerary?.lifetimeId?.uuidString as Any? ?? NSNull(),
        "sourceKind": entry.sourceKind,
        "source": entry.sourceId?.uuidString as Any? ?? NSNull(),
        "sourceLifetime": entry.sourceLifetimeId?.uuidString as Any? ?? NSNull(),
        "nativeItem": entry.item?.id?.uuidString as Any? ?? NSNull(),
        "nativeItemLifetime": entry.item?.lifetimeId?.uuidString as Any? ?? NSNull(),
        "nativeList": entry.list?.id?.uuidString as Any? ?? NSNull(),
        "nativeListLifetime": entry.list?.lifetimeId?.uuidString as Any? ?? NSNull(),
        "rank": String(entry.rank), "localDone": entry.localDone as Any? ?? NSNull(),
      ]
    }
    return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
  }

  @MainActor func nativeEntryData() throws -> Data {
    let context = try nativeContext()
    let values = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).map {
      PortableItineraryEntryRecord(try $0.value())
    }.sorted {
      ($0.id.uuidString, $0.lifetimeId.uuidString) < ($1.id.uuidString, $1.lifetimeId.uuidString)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(values)
  }

  @MainActor func corruptExpandedFlag() throws {
    let context = try nativeContext()
    let completion = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).first)
    #expect(completion.localDone == true)
    completion.localDone = false
    try context.save()
  }

  @MainActor func rawExpandedData() throws -> Data {
    let context = try nativeContext()
    let values = try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).map {
      [
        "entry": $0.listEntryId?.uuidString ?? "",
        "entryLifetime": $0.listEntryLifetimeId?.uuidString ?? "",
        "membership": $0.membershipId?.uuidString ?? "",
        "membershipLifetime": $0.membershipLifetimeId?.uuidString ?? "",
        "nativeEntry": $0.listEntry?.id?.uuidString ?? "",
        "nativeEntryLifetime": $0.listEntry?.lifetimeId?.uuidString ?? "",
        "nativeMembership": $0.membership?.id?.uuidString ?? "",
        "nativeMembershipLifetime": $0.membership?.lifetimeId?.uuidString ?? "",
        "done": String(describing: $0.localDone),
      ]
    }.sorted { ($0["entry"] ?? "") < ($1["entry"] ?? "") }
    return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
  }

  @MainActor func bindEntriesToLosingCandidate(_ identifiers: [UUID]) throws {
    let context = try nativeContext()
    if source.kind == .list {
      let candidate = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
      for identifier in identifiers {
        let entry = try #require(entries.first { $0.id == identifier })
        entry.sourceLifetimeId = candidate.lifetimeId
        entry.list = candidate
      }
      try context.save()
      return
    }
    let candidate = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
        $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      })
    let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
    for identifier in identifiers {
      let entry = try #require(entries.first { $0.id == identifier })
      entry.sourceLifetimeId = candidate.lifetimeId
      entry.item = candidate
    }
    try context.save()
  }

  @MainActor private func nativeContext() throws -> ModelContext {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    return context
  }

  @MainActor func deliverClosedEntry(_ value: PlannerPortableItineraryEntry, lifetime: UUID) throws
  {
    let context = try nativeContext()
    let owner = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
        $0.id == value.itinerary.id && $0.lifetimeId == value.itineraryLifetimeId
      })
    let snapshot = ItineraryEntrySnapshot(
      id: value.id, lifetimeId: lifetime,
      itinerary: .init(
        kind: "itinerary", id: value.itinerary.id, lifetimeId: value.itineraryLifetimeId),
      source: .init(
        kind: value.source.kind.rawValue, id: value.source.id, lifetimeId: value.sourceLifetimeId),
      rank: value.rank, localDone: value.localDone)
    let entry: PlannerSchemaV18.ItineraryEntry
    if value.source.kind == .item {
      let item = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id == value.source.id && $0.lifetimeId == value.sourceLifetimeId
        })
      entry = .init(snapshot: snapshot, itinerary: owner, item: item, list: nil)
    } else {
      let list = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first {
          $0.id == value.source.id && $0.lifetimeId == value.sourceLifetimeId
        })
      entry = .init(snapshot: snapshot, itinerary: owner, item: nil, list: list)
      for membership in try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
      where membership.listId == list.id && membership.listLifetimeId == list.lifetimeId {
        context.insert(
          PlannerSchemaV18.ExpandedCompletion(
            listEntry: entry, membership: membership, localDone: true))
      }
    }
    context.insert(entry)
    try context.save()
  }

  func labelSelectionCommand(kind: PlannerEntityKind, selected: Bool) async throws -> PlannerCommand
  {
    let identifier: UUID
    if kind == .category {
      identifier = UUID(uuidString: "00000000-0000-4000-8000-000000000501")!
    } else {
      identifier = UUID(uuidString: "00000000-0000-4000-8000-000000000601")!
    }
    let identifiers: Set<UUID> = selected ? [identifier] : []
    var categoryChange: PlannerFieldChange<Set<UUID>> = .unchanged
    var tagChange: PlannerFieldChange<Set<UUID>> = .unchanged
    if kind == .category {
      categoryChange = .set(identifiers)
    } else {
      tagChange = .set(identifiers)
    }
    switch await planner.read(session: session, request: .source(source)) {
    case .source(.item(let value)):
      return .editItem(
        sourceId: source.id, changes: .init(categoryIds: categoryChange, tagIds: tagChange),
        expectedFieldHashes: value.fieldHashes)
    case .source(.itinerary(let value)):
      return .editItinerary(
        sourceId: source.id, changes: .init(categoryIds: categoryChange, tagIds: tagChange),
        expectedFieldHashes: value.fieldHashes)
    default: throw CancellationError()
    }
  }

  @MainActor func deliverClosedLabel(_ value: PlannerPortableLabelAssociation, lifetime: UUID)
    throws
  {
    let context = try nativeContext()
    let item = try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
      $0.id == value.owner.id && $0.lifetimeId == value.ownerLifetimeId
    }
    let itinerary = try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
      $0.id == value.owner.id && $0.lifetimeId == value.ownerLifetimeId
    }
    let category = try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
      $0.id == value.label.id && $0.lifetimeId == value.labelLifetimeId
    }
    let tag = try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first {
      $0.id == value.label.id && $0.lifetimeId == value.labelLifetimeId
    }
    let association: PlannerSchemaV18.LabelAssociation
    switch (item, itinerary, category, tag) {
    case (let owner?, nil, let label?, nil): association = .init(item: owner, category: label)
    case (let owner?, nil, nil, let label?): association = .init(item: owner, tag: label)
    case (nil, let owner?, let label?, nil): association = .init(itinerary: owner, category: label)
    case (nil, let owner?, nil, let label?): association = .init(itinerary: owner, tag: label)
    default: throw CancellationError()
    }
    association.id = value.id
    association.lifetimeId = lifetime
    context.insert(association)
    try context.save()
  }

  @MainActor func deliverCandidateWithOwnedLink() throws {
    try deliverCandidate()
    let context = try nativeContext()
    let input = PlannerLinkInput(originalUrl: "https://example.com/loser", label: "Guide B")
    let link: PlannerSchemaV18.OwnedLink
    switch source.kind {
    case .item:
      let candidate = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      link = try .init(input: input, rank: 0, owner: candidate)
    case .itinerary:
      let candidate = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      link = try .init(input: input, rank: 0, owner: candidate)
    default: throw CancellationError()
    }
    link.id = UUID(uuidString: "00000000-0000-4000-8000-000000000871")!
    link.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000872")!
    context.insert(link)
    try context.save()
  }

  @MainActor func rawOwnedLinkData() throws -> Data {
    let context = try nativeContext()
    let values = try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()).map { link in
      let ownerIdentifier = try #require(link.ownerId)
      let ownerLifetime = try #require(link.ownerLifetimeId)
      return try link.value(
        ownerId: ownerIdentifier, ownerLifetimeId: ownerLifetime, ownerKind: link.ownerKind)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(values.sorted { $0.id.uuidString < $1.id.uuidString })
  }

  @MainActor func deliverCandidateWithSchedule(allDay: Bool) throws {
    try deliverCandidate()
    let context = try nativeContext()
    let form: PlannerScheduleForm
    if allDay {
      form = .allDay(start: .init(year: 2026, month: 10, day: 27), end: nil)
    } else {
      form = .timed(
        start: Date(timeIntervalSinceReferenceDate: 3000), end: nil,
        planningTimeZone: "America/New_York")
    }
    let snapshot = ScheduleSnapshot(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000873")!,
      lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000874")!, form: form)
    let schedule: PlannerSchemaV18.Schedule
    switch source.kind {
    case .item:
      let candidate = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      schedule = try .init(snapshot: snapshot, owner: candidate)
    case .itinerary:
      let candidate = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      schedule = try .init(snapshot: snapshot, owner: candidate)
    default: throw CancellationError()
    }
    context.insert(schedule)
    try context.save()
  }

  @MainActor func rawScheduleData() throws -> Data {
    let context = try nativeContext()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let values = try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()).map { schedule in
      let sourceIdentifier = try #require(schedule.sourceId)
      let sourceLifetime = try #require(schedule.sourceLifetimeId)
      let value = try schedule.value(
        ownerId: sourceIdentifier, ownerLifetimeId: sourceLifetime, ownerKind: schedule.sourceKind)
      return [
        "id": value.id.uuidString, "lifetime": value.lifetimeId.uuidString,
        "owner": sourceIdentifier.uuidString, "ownerLifetime": sourceLifetime.uuidString,
        "form": try encoder.encode(value.form).base64EncodedString(),
      ]
    }.sorted { ($0["id"] ?? "") < ($1["id"] ?? "") }
    return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
  }

  @MainActor func deliverCandidateWithOwnedLabels() throws {
    try deliverCandidate()
    let context = try nativeContext()
    let category = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000501"
      })
    let tag = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000601"
      })
    let categorySelection: PlannerSchemaV18.LabelAssociation
    let tagSelection: PlannerSchemaV18.LabelAssociation
    switch source.kind {
    case .item:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      categorySelection = .init(item: owner, category: category)
      tagSelection = .init(item: owner, tag: tag)
    case .itinerary:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      categorySelection = .init(itinerary: owner, category: category)
      tagSelection = .init(itinerary: owner, tag: tag)
    default: throw CancellationError()
    }
    categorySelection.id = UUID(uuidString: "00000000-0000-4000-8000-000000000875")!
    categorySelection.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000876")!
    tagSelection.id = UUID(uuidString: "00000000-0000-4000-8000-000000000877")!
    tagSelection.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000878")!
    context.insert(categorySelection)
    context.insert(tagSelection)
    try context.save()
  }

  @MainActor func bindOwnedMembershipToLosingItem() throws {
    let context = try nativeContext()
    let membership = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000403"
      })
    let item = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
        $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      })
    membership.item = item
    membership.itemLifetimeId = item.lifetimeId
    try context.save()
  }

  @MainActor func deliverCandidateWithOwnedMembership(entries identifiers: [UUID]) throws {
    try deliverCandidate()
    try bindEntriesToLosingCandidate(identifiers)
    let context = try nativeContext()
    let owner = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first {
        $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      })
    let item = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000101"
      })
    let membership = PlannerSchemaV18.Membership(
      snapshot: .init(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000403")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000843")!,
        list: .init(kind: "list", id: owner.id!, lifetimeId: owner.lifetimeId!),
        item: .init(kind: "item", id: item.id!, lifetimeId: item.lifetimeId!),
        rank: 1024, localDone: true), list: owner, item: item)
    context.insert(membership)
    let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
    for (index, identifier) in identifiers.enumerated() {
      let entry = try #require(entries.first { $0.id == identifier })
      context.insert(
        PlannerSchemaV18.ExpandedCompletion(
          listEntry: entry, membership: membership, localDone: index == 0))
    }
    try context.save()
  }

  @MainActor func deliverCandidateWithOwnedStops(membershipId: UUID) throws {
    try deliverCandidate()
    let context = try nativeContext()
    let owner = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
        $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
      })
    let item = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000101"
      })
    let list = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000201"
      })
    let membership = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).first { $0.id == membershipId })
    let ownerBinding = PlannerBoundIdentity(
      kind: "itinerary", id: owner.id!, lifetimeId: owner.lifetimeId!)
    let snapshots: [ItineraryEntrySnapshot] = [
      .init(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000831")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000832")!,
        itinerary: ownerBinding,
        source: .init(kind: "item", id: item.id!, lifetimeId: item.lifetimeId!),
        rank: 0, localDone: false),
      .init(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000833")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000834")!,
        itinerary: ownerBinding,
        source: .init(kind: "list", id: list.id!, lifetimeId: list.lifetimeId!),
        rank: 1024, localDone: nil),
      .init(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000835")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000836")!,
        itinerary: ownerBinding,
        source: .init(kind: "item", id: item.id!, lifetimeId: item.lifetimeId!),
        rank: 2048, localDone: true),
    ]
    for snapshot in snapshots {
      let entry: PlannerSchemaV18.ItineraryEntry
      if snapshot.source.kind == "item" {
        entry = .init(snapshot: snapshot, itinerary: owner, item: item, list: nil)
      } else {
        entry = .init(snapshot: snapshot, itinerary: owner, item: nil, list: list)
      }
      context.insert(entry)
      if snapshot.source.kind == "list" {
        context.insert(
          PlannerSchemaV18.ExpandedCompletion(
            listEntry: entry, membership: membership, localDone: false))
      }
    }
    try context.save()
  }

  @MainActor func deliverClosedOwnedSibling(referenceKind: String) throws {
    let context = try nativeContext()
    let input = PlannerLinkInput(
      originalUrl: "https://example.com/late-sibling", label: "Late guide")
    let snapshot = ScheduleSnapshot(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000873")!,
      lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000889")!,
      form: .allDay(start: .init(year: 2026, month: 10, day: 28), end: nil))
    let link: PlannerSchemaV18.OwnedLink?
    let schedule: PlannerSchemaV18.Schedule?
    switch source.kind {
    case .item:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000814"
        })
      if referenceKind == "link" {
        link = try .init(input: input, rank: 0, owner: owner)
        schedule = nil
      } else {
        link = nil
        schedule = try .init(snapshot: snapshot, owner: owner)
      }
    case .itinerary:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000814"
        })
      if referenceKind == "link" {
        link = try .init(input: input, rank: 0, owner: owner)
        schedule = nil
      } else {
        link = nil
        schedule = try .init(snapshot: snapshot, owner: owner)
      }
    default: throw CancellationError()
    }
    if let link {
      link.id = UUID(uuidString: "00000000-0000-4000-8000-000000000871")!
      link.lifetimeId = snapshot.lifetimeId
      context.insert(link)
    }
    if let schedule { context.insert(schedule) }
    try context.save()
  }

  @MainActor func addOwnedRestorationHistory(referenceKind: String) throws -> Data {
    let context = try nativeContext()
    let referenceIdentifier: UUID
    let kind: PlannerPortableIdentityKind
    let lifetime: UUID
    let target: PortableDeletionTarget
    let predecessorLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000870")!
    if referenceKind == "link" {
      referenceIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000871")!
      kind = .ownedLink
      lifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000872")!
      target = .ownedLink(id: referenceIdentifier, lifetimeId: predecessorLifetime)
    } else {
      referenceIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000873")!
      kind = .schedule
      lifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000874")!
      target = .source(
        .init(kind: "schedule", id: referenceIdentifier, lifetimeId: predecessorLifetime))
    }
    let family = PlannerPortableRestorationFamily(
      familyId: UUID(uuidString: "00000000-0000-4000-8000-000000000880")!,
      predecessor: .init(kind: kind, id: referenceIdentifier, lifetimeId: predecessorLifetime),
      candidates: [
        .init(
          lifetimeId: lifetime,
          operationId: UUID(uuidString: "00000000-0000-4000-8000-000000000886")!),
        .init(
          lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000889")!,
          operationId: UUID(uuidString: "00000000-0000-4000-8000-000000000887")!),
      ])
    let marker = PortableDeletionMarker(
      deletionId: UUID(uuidString: "00000000-0000-4000-8000-000000000884")!,
      operationId: UUID(uuidString: "00000000-0000-4000-8000-000000000885")!,
      target: target, closedFamilyId: nil)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(family)
    context.insert(try PlannerSchemaV4.DeletionMarker(marker))
    context.insert(
      PlannerSchemaV16.LineageRecord(
        identifier: family.familyId, kind: "restorationFamily", data: data))
    try context.save()
    return data
  }

  @MainActor func addMixedMetadataToLosingSource() throws {
    let context = try nativeContext()
    let category = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000501"
      })
    let tag = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000601"
      })
    let linkInput = PlannerLinkInput(originalUrl: "https://example.com/loser", label: "Guide B")
    let scheduleSnapshot = ScheduleSnapshot(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000873")!,
      lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000874")!,
      form: .timed(
        start: Date(timeIntervalSinceReferenceDate: 3000), end: nil,
        planningTimeZone: "America/New_York"))
    let link: PlannerSchemaV18.OwnedLink
    let schedule: PlannerSchemaV18.Schedule
    let categorySelection: PlannerSchemaV18.LabelAssociation
    let tagSelection: PlannerSchemaV18.LabelAssociation
    switch source.kind {
    case .item:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      link = try .init(input: linkInput, rank: 0, owner: owner)
      schedule = try .init(snapshot: scheduleSnapshot, owner: owner)
      categorySelection = .init(item: owner, category: category)
      tagSelection = .init(item: owner, tag: tag)
    case .itinerary:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
          $0.id == source.id && $0.lifetimeId?.uuidString == "00000000-0000-4000-8000-000000000815"
        })
      link = try .init(input: linkInput, rank: 0, owner: owner)
      schedule = try .init(snapshot: scheduleSnapshot, owner: owner)
      categorySelection = .init(itinerary: owner, category: category)
      tagSelection = .init(itinerary: owner, tag: tag)
    default: throw CancellationError()
    }
    link.id = UUID(uuidString: "00000000-0000-4000-8000-000000000871")!
    link.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000872")!
    categorySelection.id = UUID(uuidString: "00000000-0000-4000-8000-000000000875")!
    categorySelection.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000876")!
    tagSelection.id = UUID(uuidString: "00000000-0000-4000-8000-000000000877")!
    tagSelection.lifetimeId = UUID(uuidString: "00000000-0000-4000-8000-000000000878")!
    context.insert(link)
    context.insert(schedule)
    context.insert(categorySelection)
    context.insert(tagSelection)
    try context.save()
  }

  @MainActor func backupForOwnedReference(
    ownerLifetime: UUID = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!,
    restorationHistory: Data? = nil
  ) throws -> Data {
    let context = try nativeContext()
    let sourceRecord: PortableSourceRecord
    let links: [PortableOwnedLink]
    let schedules: [PortableScheduleRecord]
    switch source.kind {
    case .item:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id == source.id && $0.lifetimeId == ownerLifetime
        })
      let value = try owner.value()
      sourceRecord = .item(.init(value))
      links = value.links.map { .init($0, owner: value) }
      schedules = value.schedules.map { .init($0, owner: value) }
    case .itinerary:
      let owner = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).first {
          $0.id == source.id && $0.lifetimeId == ownerLifetime
        })
      let value = try owner.value()
      sourceRecord = .itinerary(.init(value))
      links = value.links.map { .init($0, owner: value) }
      schedules = value.schedules.map { .init($0, owner: value) }
    default: throw CancellationError()
    }
    var graph = try object(baseline)
    var sources = try #require(graph["sources"] as? [[String: Any]])
    let index = try #require(
      sources.firstIndex {
        $0["kind"] as? String == source.kind.rawValue && $0["id"] as? String == source.id.uuidString
      })
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    sources[index] = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(sourceRecord)) as? [String: Any])
    graph["sources"] = sources
    graph["ownedLinks"] = try JSONSerialization.jsonObject(with: encoder.encode(links))
    graph["schedules"] = try JSONSerialization.jsonObject(with: encoder.encode(schedules))
    var families = try #require(graph["restorationFamilies"] as? [[String: Any]])
    let candidates = try #require(families[0]["candidates"] as? [[String: Any]])
    families[0]["candidates"] = candidates.filter {
      $0["lifetimeId"] as? String == ownerLifetime.uuidString
    }
    graph["restorationFamilies"] = families
    if let restorationHistory {
      let family = try JSONDecoder().decode(
        PlannerPortableRestorationFamily.self, from: restorationHistory)
      families.append(try object(restorationHistory))
      graph["restorationFamilies"] = families
      let target: PortableDeletionTarget
      switch family.predecessor.kind {
      case .ownedLink:
        target = .ownedLink(
          id: family.predecessor.id, lifetimeId: family.predecessor.lifetimeId)
      case .schedule:
        target = .source(
          .init(
            kind: "schedule", id: family.predecessor.id,
            lifetimeId: family.predecessor.lifetimeId))
      default: throw CancellationError()
      }
      let marker = PortableDeletionMarker(
        deletionId: UUID(uuidString: "00000000-0000-4000-8000-000000000884")!,
        operationId: UUID(uuidString: "00000000-0000-4000-8000-000000000885")!,
        target: target, closedFamilyId: nil)
      var markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
      markers.append(try object(encoder.encode(marker)))
      graph["deletionMarkers"] = markers
    }
    return try JSONSerialization.data(withJSONObject: graph)
  }

  @MainActor func corruptOwnedStop(_ scenario: String) throws {
    let context = try nativeContext()
    let entry = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000831"
      })
    switch scenario {
    case "owner": entry.itinerary = nil
    case "source": entry.item = nil
    case "expanded":
      let completion = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).first {
          $0.listEntryId?.uuidString == "00000000-0000-4000-8000-000000000833"
        })
      completion.membership = nil
    default: throw CancellationError()
    }
    try context.save()
  }

  @MainActor func recordOwnedStopDone(expanded: Bool) throws {
    let context = try nativeContext()
    let scope: PlannerPortableCompletionContext
    if expanded {
      let completion = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).first {
          $0.listEntryId?.uuidString == "00000000-0000-4000-8000-000000000833"
        })
      scope = .expandedListItem(try completion.value().context)
    } else {
      let entry = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).first {
          $0.id?.uuidString == "00000000-0000-4000-8000-000000000831"
        })
      scope = .directItineraryItem(entryId: entry.id!, entryLifetimeId: entry.lifetimeId!)
    }
    let aliasIdentifier = UUID()
    let changeIdentifier = UUID()
    let alias = PlannerPortableContextAlias(
      aliasId: aliasIdentifier, context: scope, canonicalContext: scope,
      initialDone: false, currentChangeId: changeIdentifier)
    let change = PlannerPortableCompletionChange(
      id: changeIdentifier, aliasId: aliasIdentifier, context: scope,
      done: true, observedChangeIds: [])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    context.insert(
      PlannerSchemaV16.LineageRecord(
        identifier: aliasIdentifier, kind: "contextAlias", data: try encoder.encode(alias)))
    context.insert(
      PlannerSchemaV16.LineageRecord(
        identifier: changeIdentifier, kind: "completionChange", data: try encoder.encode(change)))
    try context.save()
  }

  @MainActor func corruptOwnedMembershipProvenance(wrongItem: Bool) throws {
    let context = try nativeContext()
    let membership = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000403"
      })
    let original = try membership.value().baselineProvenance
    let provenance: PlannerPortableMembershipProvenance
    if wrongItem {
      let other = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first {
          $0.id?.uuidString == "00000000-0000-4000-8000-000000000102"
        })
      provenance = .init(
        membershipId: original.membershipId, membershipLifetimeId: original.membershipLifetimeId,
        list: original.list, item: .init(kind: .item, id: other.id!, lifetimeId: other.lifetimeId!),
        observedRemovalIds: [])
    } else {
      provenance = .init(
        membershipId: original.membershipId, membershipLifetimeId: original.membershipLifetimeId,
        list: .init(
          kind: .list, id: source.id,
          lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000814")!),
        item: original.item, observedRemovalIds: [])
    }
    context.insert(
      PlannerSchemaV19.MembershipProvenance(
        membershipId: original.membershipId, membershipLifetimeId: original.membershipLifetimeId,
        recordData: try JSONEncoder().encode(provenance)))
    try context.save()
  }

  @MainActor func rawListSourceData() throws -> Data {
    let context = try nativeContext()
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).filter {
      $0.id == source.id
    }.sorted {
      ($0.lifetimeId?.uuidString ?? "") < ($1.lifetimeId?.uuidString ?? "")
    }
    let values = try records.map { record in
      PortableSourceRecord.list(.init(try record.value()))
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(values)
  }

  @MainActor func rawMembershipData() throws -> Data {
    let context = try nativeContext()
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).map {
      PortableMembershipRecord(try $0.value())
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(records)
  }

  @MainActor func rawMembershipAuthorityData() throws -> Data {
    let context = try nativeContext()
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV19.MembershipProvenance>()).map {
      [
        "membership": $0.membershipId?.uuidString ?? "",
        "lifetime": $0.membershipLifetimeId?.uuidString ?? "",
        "data": $0.recordData?.base64EncodedString() ?? "",
      ]
    }.sorted { ($0["membership"] ?? "") < ($1["membership"] ?? "") }
    return try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
  }

  @MainActor func recordOwnedMembershipReopen(expandedEntry: UUID?) throws {
    let context = try nativeContext()
    let membership = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).first {
        $0.id?.uuidString == "00000000-0000-4000-8000-000000000403"
      })
    let scope: PlannerPortableCompletionContext
    if let expandedEntry {
      let entry = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).first {
          $0.id == expandedEntry
        })
      scope = .expandedListItem(
        .init(
          listEntryId: expandedEntry, listEntryLifetimeId: entry.lifetimeId!,
          membershipId: membership.id!, membershipLifetimeId: membership.lifetimeId!))
    } else {
      scope = .listMembership(
        membershipId: membership.id!, membershipLifetimeId: membership.lifetimeId!)
    }
    let aliasIdentifier = UUID()
    let changeIdentifier = UUID()
    let alias = PlannerPortableContextAlias(
      aliasId: aliasIdentifier, context: scope, canonicalContext: scope,
      initialDone: true, currentChangeId: changeIdentifier)
    let change = PlannerPortableCompletionChange(
      id: changeIdentifier, aliasId: aliasIdentifier, context: scope,
      done: false, observedChangeIds: [])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    context.insert(
      PlannerSchemaV16.LineageRecord(
        identifier: aliasIdentifier, kind: "contextAlias", data: try encoder.encode(alias)))
    context.insert(
      PlannerSchemaV16.LineageRecord(
        identifier: changeIdentifier, kind: "completionChange", data: try encoder.encode(change)))
    try context.save()
  }

  @MainActor func rawCompletionAuthorityData() throws -> Data {
    let context = try nativeContext()
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>()).filter {
      $0.recordKind == "contextAlias" || $0.recordKind == "completionChange"
    }.map {
      [
        "identity": $0.recordIdentifier?.uuidString ?? "", "kind": $0.recordKind,
        "data": $0.recordData?.base64EncodedString() ?? "",
      ]
    }.sorted { ($0["identity"] ?? "") < ($1["identity"] ?? "") }
    return try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
  }

  @MainActor func deliverCandidate(
    lifetime: UUID = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!
  ) throws {
    let context = try nativeContext()
    switch source.kind {
    case .item:
      let candidate = try PlannerSchemaV18.Item(
        input: .init(title: "Losing museum", notes: "Different content"))
      candidate.id = source.id
      candidate.lifetimeId = lifetime
      candidate.globalDone = true
      candidate.archived = true
      context.insert(candidate)
    case .list:
      let candidate = try PlannerSchemaV18.List(
        content: .init(name: "Losing List", notes: "Different content"))
      candidate.id = source.id
      candidate.lifetimeId = lifetime
      candidate.archived = true
      context.insert(candidate)
    case .itinerary:
      let candidate = try PlannerSchemaV18.Itinerary(
        input: .init(title: "Losing Itinerary", notes: "Different content"))
      candidate.id = source.id
      candidate.lifetimeId = lifetime
      candidate.archived = true
      context.insert(candidate)
    case .category:
      let candidate = try PlannerSchemaV18.Category(content: .init(name: "Losing Category"))
      candidate.id = source.id
      candidate.lifetimeId = lifetime
      context.insert(candidate)
    case .tag:
      let candidate = try PlannerSchemaV18.Tag(content: .init(name: "Losing Tag"))
      candidate.id = source.id
      candidate.lifetimeId = lifetime
      context.insert(candidate)
    default: throw CancellationError()
    }
    try context.save()
  }
}

#if os(macOS)
  extension NativeSourceRestorationMaintenanceTests {
    @Test func failedMixedItemNativeSavePreservesContentsAndAppearancesUntilFreshRetry()
      async throws
    {
      guard
        ProcessInfo.processInfo.environment["PLANNER_SOURCE_RESTORATION_STAGE"]
          == "mixedItemNativeSaveFailure"
      else {
        let directory = try makePlannerStoreFixtureDirectory()
        try runSourceRestorationProcess(
          directory: directory, stage: "mixedItemNativeSaveFailure", directEntries: true)
        return
      }
      try await checkMixedOwnedItem(recoveryFailure: false, nativeSaveFailure: true)
    }

    @Test func failedOwnedListNativeSavePreservesMembershipsAndBranchesUntilFreshRetry()
      async throws
    {
      guard
        ProcessInfo.processInfo.environment["PLANNER_SOURCE_RESTORATION_STAGE"]
          == "ownedListNativeSaveFailure"
      else {
        let directory = try makePlannerStoreFixtureDirectory()
        try runSourceRestorationProcess(
          directory: directory, stage: "ownedListNativeSaveFailure", directEntries: false)
        return
      }
      try await checkOwnedListRetirement(
        referenced: true, recoveryFailure: false, nativeSaveFailure: true)
    }

    @Test func mixedOwnedInterruptionPreservesCompleteWinnerAndRecovery() async throws {
      let stages = ["mixedBeforeNativeSave", "mixedAfterNativeSave"]
      if let stage = ProcessInfo.processInfo.environment["PLANNER_SOURCE_RESTORATION_STAGE"],
        stages.contains(stage)
      {
        try await checkMixedOwnedItinerary(recoveryFailure: false, nativeSaveFailure: false)
        return
      }
      for stage in stages {
        let directory = try makePlannerStoreFixtureDirectory()
        try runSourceRestorationProcess(directory: directory, stage: stage, directEntries: false)
        let input = try #require(
          JSONSerialization.jsonObject(
            with: Data(contentsOf: directory.appendingPathComponent("input.json")))
            as? [String: Any])
        let dataset = URL(fileURLWithPath: try #require(input["dataset"] as? String))
        let namespace = URL(fileURLWithPath: try #require(input["namespace"] as? String))
        let baseline = try #require(
          (input["baseline"] as? String).flatMap { Data(base64Encoded: $0) })
        let control = try #require(
          (input["control"] as? String).flatMap { Data(base64Encoded: $0) })
        let files = try #require(input["files"] as? [String: String])
        let originalReceipts = try #require(input["receipts"] as? NSArray)
        let proof = try #require(
          JSONSerialization.jsonObject(
            with: Data(contentsOf: directory.appendingPathComponent("proof.json")))
            as? [String: Any])
        #expect(proof["stage"] as? String == stage)
        #expect((proof["processIdentifier"] as? Int ?? 0) > 1)
        let configuration = PlannerStorageConfiguration(
          storeURL: dataset.appendingPathComponent("store/Planner.sqlite"),
          controlURL: dataset.appendingPathComponent("control/writer"),
          recoveryDirectoryURL: dataset.appendingPathComponent("recovery"),
          processRole: .mainApplication, storageMode: .localOnly)
        #expect(try Data(contentsOf: configuration.controlURL) == control)
        let identity = try #require(
          JSONSerialization.jsonObject(with: control) as? [String: Any])
        let namespaceIdentifier = try #require(
          (identity["namespaceId"] as? String).flatMap(UUID.init(uuidString:)))
        let planner = Planner(configuration: configuration)
        guard
          case .listed(let view) = await planner.inspectRecovery(
            request: .namespace(namespaceId: namespaceIdentifier)),
          let preparation = view.preparedMaintenance.first
        else { throw CancellationError() }
        #expect(view.preparedMaintenance.count == 1)
        guard case .ready(let session) = await planner.bootstrap() else {
          throw CancellationError()
        }
        let fixture = SourceRestorationFixture(
          configuration: configuration, planner: planner, session: session,
          source: .init(
            kind: .itinerary, id: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!),
          namespace: namespace, baseline: baseline)
        if stage == "mixedAfterNativeSave" {
          guard case .status(let status) = await planner.read(session: session, request: .status),
            case .known(_, let operations, let pending, let blocked) = status.recovery
          else { throw CancellationError() }
          #expect(operations.isEmpty && pending == [preparation.maintenanceId] && blocked)
          guard
            case .complete(let checkpoint) = await planner.retryMaintenanceRecovery(
              session: session, maintenanceId: preparation.maintenanceId),
            case .complete(let repeated) = await planner.retryMaintenanceRecovery(
              session: session, maintenanceId: preparation.maintenanceId)
          else { throw CancellationError() }
          #expect(checkpoint == repeated)
        } else {
          let beforeRetry = try fixture.files()
          guard
            case .rejected(let reason) = await planner.retryMaintenanceRecovery(
              session: session, maintenanceId: preparation.maintenanceId)
          else { throw CancellationError() }
          #expect(reason.code == "maintenanceNotApplied")
          #expect(try fixture.files() == beforeRetry)
        }
        guard case .exported(let current) = await planner.exportData(session: session) else {
          throw CancellationError()
        }
        try expectMixedItineraryGraph(current, preserving: baseline)
        let envelope = try fixture.envelope()
        #expect(envelope["receipts"] as? NSArray == originalReceipts)
        let acknowledgements = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
        #expect(acknowledgements.count == 1)
        let acknowledgedIdentifier = try #require(
          acknowledgements.first?["maintenanceId"] as? String)
        if stage == "mixedBeforeNativeSave" {
          #expect(acknowledgedIdentifier != preparation.maintenanceId.uuidString)
        } else {
          #expect(acknowledgedIdentifier == preparation.maintenanceId.uuidString)
        }
        for (name, encoded) in files {
          #expect(
            try Data(contentsOf: namespace.appendingPathComponent(name))
              == Data(base64Encoded: encoded))
        }
        #expect(try Data(contentsOf: configuration.controlURL) == control)
        let reopened = Planner(configuration: configuration)
        guard case .ready(let reopenedSession) = await reopened.bootstrap(),
          case .exported(let persisted) = await reopened.exportData(session: reopenedSession)
        else { throw CancellationError() }
        #expect(try fixture.graph(persisted) == fixture.graph(current))
      }
    }

    @Test func failedMixedOwnedNativeSavePreservesAllContentsAndRetriesFresh() async throws {
      guard
        ProcessInfo.processInfo.environment["PLANNER_SOURCE_RESTORATION_STAGE"]
          == "mixedOwnedNativeSaveFailure"
      else {
        let directory = try makePlannerStoreFixtureDirectory()
        try runSourceRestorationProcess(
          directory: directory, stage: "mixedOwnedNativeSaveFailure", directEntries: false)
        return
      }
      try await checkMixedOwnedItinerary(recoveryFailure: false, nativeSaveFailure: true)
    }

    @Test func failedSourceNativeSaveRetainsUnverifiedPreparationAndRetriesFresh() async throws {
      guard
        ProcessInfo.processInfo.environment["PLANNER_SOURCE_RESTORATION_STAGE"]
          == "nativeSaveFailure"
      else {
        for directEntries in [false, true] {
          let directory = try makePlannerStoreFixtureDirectory()
          try runSourceRestorationProcess(
            directory: directory, stage: "nativeSaveFailure", directEntries: directEntries)
        }
        return
      }
      let directEntries =
        ProcessInfo.processInfo.environment["PLANNER_SOURCE_DIRECT_ENTRIES"] == "true"
      let fixture = try await SourceRestorationFixture.makeWithEntries(directEntries)
      try await fixture.deliverCandidateWithEntries(directEntries)
      let originalEntries = try await fixture.nativeEntryData()
      let originalFiles = try fixture.files()
      let lifetimes = try await fixture.itemLifetimes()
      let obstruction = NativeSaveFileSizeObstruction(
        configuration: fixture.configuration, maximumFileSize: 0)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.willSave, object: nil, queue: nil
      ) {
        notification in obstruction.observe(notification)
      }
      let failed = await fixture.planner.exportData(session: fixture.session)
      NotificationCenter.default.removeObserver(observer)
      try obstruction.restore()
      #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
      guard case .failed(let reason) = failed else { throw CancellationError() }
      #expect(reason.code == "maintenanceRequired")
      #expect(try await fixture.itemLifetimes() == lifetimes)
      #expect(try await fixture.nativeEntryData() == originalEntries)
      let failedFiles = try fixture.files()
      for (name, bytes) in originalFiles { #expect(failedFiles[name] == bytes) }
      let preparations = failedFiles.filter { $0.key.hasPrefix("maintenance-") }
      #expect(preparations.count == 1)
      let preparation = try fixture.object(try #require(preparations.values.first))
      let identifier = try #require(
        (preparation["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
      #expect(preparation["kind"] as? String == "sourceRestorationConsolidation")
      guard
        case .rejected(let retryFailure) = await fixture.planner.retryMaintenanceRecovery(
          session: fixture.session, maintenanceId: identifier)
      else { throw CancellationError() }
      #expect(retryFailure.code == "maintenanceNotApplied")
      #expect(try fixture.files() == failedFiles)
      let reopened = Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await reopened.bootstrap(),
        case .exported(let data) = await reopened.exportData(session: session)
      else { throw CancellationError() }
      #expect(try fixture.graph(data) == fixture.graph(fixture.baseline))
      let healed = try fixture.files()
      for (name, bytes) in failedFiles { #expect(healed[name] == bytes) }
      let maintenance = try #require(fixture.envelope()["maintenanceReceipts"] as? [[String: Any]])
      #expect(
        maintenance.count == 1
          && maintenance.first?["maintenanceId"] as? String != identifier.uuidString)
    }

    @Test func sourceRestorationInterruptionPreservesPreparationAndActivationOrder() async throws {
      let environment = ProcessInfo.processInfo.environment
      if let directory = environment["PLANNER_SOURCE_RESTORATION_CHILD"],
        let stage = environment["PLANNER_SOURCE_RESTORATION_STAGE"]
      {
        try await runSourceRestorationChild(
          directory: URL(fileURLWithPath: directory), stage: stage)
        return
      }
      for (stage, directEntries) in [false, true].flatMap({ directEntries in
        ["beforeNativeSave", "afterNativeSave", "beforePublication", "beforeActivation"].map {
          ($0, directEntries)
        }
      }) {
        let directory = try makePlannerStoreFixtureDirectory()
        try runSourceRestorationProcess(
          directory: directory, stage: stage, directEntries: directEntries)
        let input = try #require(
          JSONSerialization.jsonObject(
            with: Data(contentsOf: directory.appendingPathComponent("input.json")))
            as? [String: Any])
        let dataset = URL(fileURLWithPath: try #require(input["dataset"] as? String))
        let namespace = URL(fileURLWithPath: try #require(input["namespace"] as? String))
        let baseline = try #require(
          (input["baseline"] as? String).flatMap { Data(base64Encoded: $0) })
        let priorFiles = try #require(input["files"] as? [String: String])
        let configuration = PlannerStorageConfiguration(
          storeURL: dataset.appendingPathComponent("store/Planner.sqlite"),
          controlURL: dataset.appendingPathComponent("control/writer"),
          recoveryDirectoryURL: dataset.appendingPathComponent("recovery"),
          processRole: .mainApplication, storageMode: .localOnly)
        let proof = try #require(
          JSONSerialization.jsonObject(
            with: Data(contentsOf: directory.appendingPathComponent("proof.json")))
            as? [String: Any])
        #expect(proof["stage"] as? String == stage)
        let identity = try #require(
          JSONSerialization.jsonObject(
            with: Data(contentsOf: configuration.controlURL)) as? [String: Any])
        let namespaceIdentifier = try #require(
          (identity["namespaceId"] as? String).flatMap(UUID.init(uuidString:)))
        let source = Planner(configuration: configuration)
        let pending = await source.inspectRecovery(
          request: .namespace(namespaceId: namespaceIdentifier))
        guard case .listed(let view) = pending else { throw CancellationError() }
        let preparation = view.preparedMaintenance.first
        if stage == "beforeNativeSave" || stage == "afterNativeSave" {
          #expect(identity["schemaVersion"] as? Int == 23)
          #expect(view.preparedMaintenance.count == 1)
        } else {
          #expect(identity["schemaVersion"] as? Int == (directEntries ? 21 : 20))
          #expect(view.preparedMaintenance.isEmpty)
          if stage == "beforeActivation" {
            #expect(view.acknowledgedSnapshot?.storageSchemaVersion == 23)
          } else {
            #expect(view.acknowledgedSnapshot?.storageSchemaVersion == (directEntries ? 21 : 20))
          }
        }
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: namespace.path)
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o700],
          ofItemAtPath: configuration.controlURL.deletingLastPathComponent().path)
        guard case .ready(let session) = await source.bootstrap() else { throw CancellationError() }
        if stage == "afterNativeSave" {
          let identifier = try #require(preparation?.maintenanceId)
          guard case .status(let status) = await source.read(session: session, request: .status),
            case .known(_, let operations, let maintenance, let blocked) = status.recovery
          else { throw CancellationError() }
          #expect(operations.isEmpty && maintenance == [identifier] && blocked)
          guard
            case .complete = await source.retryMaintenanceRecovery(
              session: session, maintenanceId: identifier)
          else { throw CancellationError() }
        }
        guard case .exported(let data) = await source.exportData(session: session) else {
          throw CancellationError()
        }
        #expect(
          try JSONSerialization.jsonObject(with: data) as? NSDictionary
            == JSONSerialization.jsonObject(with: baseline) as? NSDictionary)
        for (name, encoded) in priorFiles where name != "identity.json" {
          #expect(
            try Data(contentsOf: namespace.appendingPathComponent(name))
              == Data(base64Encoded: encoded))
        }
        if stage == "beforeNativeSave", let preparation {
          guard
            case .rejected(let reason) = await source.retryMaintenanceRecovery(
              session: session, maintenanceId: preparation.maintenanceId)
          else { throw CancellationError() }
          #expect(reason.code == "maintenanceNotApplied")
        }
      }
    }

    private func runSourceRestorationChild(directory: URL, stage: String) async throws {
      let directEntries =
        ProcessInfo.processInfo.environment["PLANNER_SOURCE_DIRECT_ENTRIES"] == "true"
      let fixture = try await SourceRestorationFixture.makeWithEntries(directEntries)
      try await fixture.deliverCandidateWithEntries(directEntries)
      if stage == "beforePublication" || stage == "beforeActivation" {
        try fixture.rewriteCompatibility(directEntries ? 21 : 20)
      }
      let input: [String: Any] = [
        "dataset": fixture.configuration.storeURL.deletingLastPathComponent()
          .deletingLastPathComponent().path,
        "namespace": fixture.namespace.path, "baseline": fixture.baseline.base64EncodedString(),
        "files": try fixture.files().mapValues { $0.base64EncodedString() },
      ]
      try JSONSerialization.data(withJSONObject: input).write(
        to: directory.appendingPathComponent("input.json"), options: .atomic)
      if stage == "beforePublication" || stage == "beforeActivation" {
        let obstructed: URL
        if stage == "beforePublication" {
          obstructed = fixture.namespace
        } else {
          obstructed = fixture.configuration.controlURL.deletingLastPathComponent()
        }
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o500], ofItemAtPath: obstructed.path)
        let planner = Planner(configuration: fixture.configuration)
        guard case .unavailable = await planner.bootstrap() else { throw CancellationError() }
        try JSONSerialization.data(withJSONObject: ["stage": stage]).write(
          to: directory.appendingPathComponent("proof.json"), options: .atomic)
        try #require(kill(getpid(), SIGKILL) == 0)
        while true { pause() }
      }
      let notification = stage == "afterNativeSave" ? ModelContext.didSave : ModelContext.willSave
      let observer = NotificationCenter.default.addObserver(
        forName: notification, object: nil, queue: nil
      ) { value in
        guard value.object is ModelContext else { return }
        do {
          try JSONSerialization.data(withJSONObject: ["stage": stage]).write(
            to: directory.appendingPathComponent("proof.json"), options: .atomic)
        } catch { print("SOURCE_RESTORATION_PROOF_ERROR \(error)") }
        fflush(nil)
        if kill(getpid(), SIGKILL) != 0 { return }
        while true { pause() }
      }
      let result = await fixture.planner.exportData(session: fixture.session)
      NotificationCenter.default.removeObserver(observer)
      Issue.record("The isolated source retirement must stop at its actual save: \(result)")
    }

    private func runSourceRestorationProcess(
      directory: URL, stage: String, directEntries: Bool
    ) throws {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let outputURL = directory.appendingPathComponent("source-restoration-child.log")
      try Data().write(to: outputURL)
      let output = try FileHandle(forWritingTo: outputURL)
      defer { try? output.close() }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      var arguments: [String] = []
      if let index = CommandLine.arguments.firstIndex(of: "--test-bundle-path"),
        CommandLine.arguments.indices.contains(index + 1)
      {
        arguments = ["--test-bundle-path", CommandLine.arguments[index + 1]]
      }
      let selectedTest: String
      if stage == "nativeSaveFailure" {
        selectedTest = "failedSourceNativeSaveRetainsUnverifiedPreparationAndRetriesFresh"
      } else if stage == "mixedItemNativeSaveFailure" {
        selectedTest = "failedMixedItemNativeSavePreservesContentsAndAppearancesUntilFreshRetry"
      } else if stage == "mixedOwnedNativeSaveFailure" {
        selectedTest = "failedMixedOwnedNativeSavePreservesAllContentsAndRetriesFresh"
      } else if stage == "ownedListNativeSaveFailure" {
        selectedTest = "failedOwnedListNativeSavePreservesMembershipsAndBranchesUntilFreshRetry"
      } else if stage == "mixedBeforeNativeSave" || stage == "mixedAfterNativeSave" {
        selectedTest = "mixedOwnedInterruptionPreservesCompleteWinnerAndRecovery"
      } else {
        selectedTest = "sourceRestorationInterruptionPreservesPreparationAndActivationOrder"
      }
      process.arguments =
        arguments + [
          "--testing-library", "swift-testing", "--filter",
          "NativeSourceRestorationMaintenanceTests/\(selectedTest)",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_SOURCE_RESTORATION_CHILD"] = directory.path
      environment["PLANNER_SOURCE_RESTORATION_STAGE"] = stage
      environment["PLANNER_SOURCE_DIRECT_ENTRIES"] = String(directEntries)
      process.environment = environment
      process.standardOutput = output
      process.standardError = output
      let completion = DispatchSemaphore(value: 0)
      process.terminationHandler = { _ in completion.signal() }
      try process.run()
      let finished = completion.wait(timeout: .now() + 45) == .success
      if !finished {
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
      }
      try output.close()
      let transcript = try String(contentsOf: outputURL, encoding: .utf8)
      if [
        "nativeSaveFailure", "mixedOwnedNativeSaveFailure", "ownedListNativeSaveFailure",
        "mixedItemNativeSaveFailure",
      ].contains(stage) {
        #expect(
          finished && process.terminationReason == .exit && process.terminationStatus == 0,
          Comment(rawValue: String(transcript.suffix(12000))))
        #expect(transcript.contains("Test run with 1 test"))
      } else {
        #expect(
          finished && process.terminationReason == .uncaughtSignal
            && process.terminationStatus == SIGKILL,
          Comment(rawValue: String(transcript.suffix(12000))))
      }
      #expect(!transcript.contains("recorded an issue"))
      try JSONSerialization.data(withJSONObject: [
        "stage": stage, "directEntries": directEntries, "finishedWithinDeadline": finished,
        "terminationStatus": process.terminationStatus,
        "uncaughtSignal": process.terminationReason == .uncaughtSignal,
        "childLog": outputURL.path,
      ]).write(to: directory.appendingPathComponent("termination.json"), options: .atomic)
      print("SOURCE_RESTORATION_INTERRUPTION_CHILD_LOG \(outputURL.path)")
    }
  }
#endif

struct NativeSourceRestorationEntryTests {
  @Test(arguments: [
    "nilItem", "scalarMismatch", "nilOwner", "ownerLifetime", "nilCompletion", "completionHistory",
  ])
  func invalidEntryAuthorityPreservesNativeAndRecoveryData(scenario: String) async throws {
    let fixture = try await SourceRestorationFixture.makeWithEntries(true)
    try await fixture.deliverCandidateWithEntries(true)
    try await fixture.corruptEntry(scenario)
    let originalFiles = try fixture.files()
    let originalControl = try Data(contentsOf: fixture.configuration.controlURL)
    let originalLifetimes = try await fixture.itemLifetimes()
    let originalEntries = try await fixture.rawEntryData()
    guard case .failed = await fixture.planner.exportData(session: fixture.session) else {
      Issue.record("An invalid direct-entry binding must not authorize rebinding: \(scenario)")
      return
    }
    #expect(try fixture.files() == originalFiles)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == originalControl)
    #expect(try await fixture.itemLifetimes() == originalLifetimes)
    #expect(try await fixture.rawEntryData() == originalEntries)
  }

  @Test func repeatedDirectEntriesFollowTheWinnerAndKeepIndependentCompletion() async throws {
    let fixture = try await SourceRestorationFixture.make()
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    var entryIdentifiers: [UUID] = []
    var originalOperations: [(PlannerOperation, PlannerAppliedResult)] = []
    for done in [false, true] {
      let operation = PlannerOperation(
        operationId: UUID(), session: fixture.session,
        command: .addItineraryEntry(
          itineraryId: itineraryIdentifier, source: fixture.source, placement: .last))
      let creation = await fixture.planner.execute(operation)
      guard case .applied(let result, .complete) = creation.outcome,
        case .itineraryEntry(let identifier, _, _)? = result.generatedReferences.first
      else { throw CancellationError() }
      entryIdentifiers.append(identifier)
      originalOperations.append((operation, result))
      if done {
        guard
          case .applied(_, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session,
              command: .setCompletion(
                scope: .appearance(
                  .directItineraryItem(
                    itineraryId: itineraryIdentifier, entryId: identifier)), done: true))
          ).outcome
        else { throw CancellationError() }
      }
    }
    guard case .exported(let expected) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let originalReceipts = try fixture.envelope()["receipts"] as? NSArray
    guard
      case .snapshot(let originalQuery) = await fixture.planner.query(
        .init(session: fixture.session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    try await fixture.deliverCandidate()
    try await fixture.bindEntriesToLosingCandidate(entryIdentifiers)
    let normalized = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let actual) = normalized else {
      Issue.record("Authorized independent itinerary entries must follow the winner: \(normalized)")
      return
    }
    #expect(try fixture.graph(actual) == fixture.graph(expected))
    let envelope = try fixture.envelope()
    #expect(envelope["receipts"] as? NSArray == originalReceipts)
    let maintenance = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(maintenance.count == 1 && maintenance.first?["ruleVersion"] as? Int == 3)
    guard
      case .failed(let stale) = await fixture.planner.read(
        session: fixture.session,
        request: .mapRows(generation: originalQuery.generation, offset: 0, limit: 64))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    for (operation, original) in originalOperations {
      guard
        case .applied(let replayed, .complete) = await fixture.planner.execute(operation).outcome
      else { throw CancellationError() }
      #expect(replayed == original)
    }
    for (index, identifier) in entryIdentifiers.enumerated() {
      guard
        case .appearance(let appearance) = await fixture.planner.read(
          session: fixture.session,
          request: .appearance(
            .directItineraryItem(
              itineraryId: itineraryIdentifier, entryId: identifier)))
      else { throw CancellationError() }
      #expect(appearance.source == fixture.source)
      #expect(appearance.localDone == (index == 1))
      #expect(appearance.globalDone == false && appearance.effectiveDone == (index == 1))
    }
    try await fixture.deliverCandidate()
    try await fixture.bindEntriesToLosingCandidate(entryIdentifiers)
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(expected))
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(reopenedData) == fixture.graph(expected))
  }
}

struct NativeRestoredTargetReferenceTests {
  @Test(arguments: [PlannerEntityKind.category, .tag])
  func restoredLabelCollisionKeepsItineraryContentAndClosedIdentity(kind: PlannerEntityKind)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    guard
      case .applied(let creation, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItinerary(
            content: .init(
              title: "Independent itinerary", notes: "Keep these route notes",
              categoryIds: kind == .category ? [fixture.source.id] : [],
              tagIds: kind == .tag ? [fixture.source.id] : [])))
      ).outcome,
      let owner = creation.generated.first,
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner)),
      case .exported(let original) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try await fixture.deliverCandidate()
    try await fixture.bindLabelToLosingCandidate()
    try await fixture.invalidateLabelTarget("collision")
    try await fixture.identifyLabelCollision(losingTargetIsSmaller: true)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session),
      case .source(.itinerary(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner))
    else { throw CancellationError() }
    #expect(retained.fieldHashes == before.fieldHashes)
    let graph = try fixture.object(after)
    let expected = try fixture.object(original)
    #expect(graph["sources"] as? NSArray == expected["sources"] as? NSArray)
    let associations = try #require(graph["labelAssociations"] as? [[String: Any]])
    #expect(associations.count == 1)
    #expect(associations.first?["id"] as? String == "00000000-0000-4000-8000-000000000701")
    try await fixture.redeliverClosedLabelAssociation(targetsLoser: false)
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(after))
  }

  @Test(arguments: [PlannerEntityKind.category, .tag])
  func labelCollisionPreparationFailurePreservesBothAssociationsUntilRetry(kind: PlannerEntityKind)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItem(
            content: .init(
              title: "Independent owner", categoryIds: kind == .category ? [fixture.source.id] : [],
              tagIds: kind == .tag ? [fixture.source.id] : [])))
      ).outcome
    else { throw CancellationError() }
    try await fixture.deliverCandidate()
    try await fixture.bindLabelToLosingCandidate()
    try await fixture.invalidateLabelTarget("collision")
    try await fixture.identifyLabelCollision(losingTargetIsSmaller: true)
    let before = try await fixture.rawLabelData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: fixture.namespace.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    }
    guard case .failed(let failure) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(failure.code == "maintenanceRequired")
    #expect(try await fixture.rawLabelData() == before)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: fixture.namespace.path)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let associations = try #require(fixture.object(after)["labelAssociations"] as? [[String: Any]])
    #expect(associations.count == 1)
    #expect(associations.first?["id"] as? String == "00000000-0000-4000-8000-000000000701")
  }

  @Test(arguments: [PlannerEntityKind.category, .tag], [false, true])
  func restoredLabelCollisionKeepsSmallestAssociationWithoutEditingItsOwner(
    kind: PlannerEntityKind, losingTargetIsSmaller: Bool
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    guard
      case .applied(let creation, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItem(
            content: .init(
              title: "Independent owner", notes: "Keep this content",
              categoryIds: kind == .category ? [fixture.source.id] : [],
              tagIds: kind == .tag ? [fixture.source.id] : [])))
      ).outcome,
      let owner = creation.generated.first,
      case .source(.item(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner)),
      case .exported(let original) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let receipts = try fixture.envelope()["receipts"] as? NSArray
    try await fixture.deliverCandidate()
    try await fixture.bindLabelToLosingCandidate()
    try await fixture.invalidateLabelTarget("collision")
    try await fixture.identifyLabelCollision(losingTargetIsSmaller: losingTargetIsSmaller)
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result,
      case .source(.item(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(owner))
    else {
      Issue.record("The smallest association must survive a restored-label collision: \(result)")
      return
    }
    #expect(retained.fieldHashes == before.fieldHashes)
    let graph = try fixture.object(after)
    let expected = try fixture.object(original)
    #expect(graph["sources"] as? NSArray == expected["sources"] as? NSArray)
    let associations = try #require(graph["labelAssociations"] as? [[String: Any]])
    #expect(associations.count == 1)
    #expect(associations.first?["id"] as? String == "00000000-0000-4000-8000-000000000701")
    let label = try #require(associations.first?["label"] as? [String: Any])
    #expect(label["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000814")
    let markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    #expect(
      markers.contains { marker in
        guard let target = marker["target"] as? [String: Any] else { return false }
        return target["kind"] as? String == "labelAssociation"
          && target["id"] as? String == "00000000-0000-4000-8000-000000000702"
          && target["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000802"
      })
    #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    #expect(graph["contextAliases"] as? NSArray == expected["contextAliases"] as? NSArray)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    for targetsLoser in [false, true] {
      if targetsLoser { try await fixture.deliverCandidate() }
      try await fixture.redeliverClosedLabelAssociation(targetsLoser: targetsLoser)
      let redelivery = await fixture.planner.exportData(session: fixture.session)
      guard case .exported(let redelivered) = redelivery else {
        Issue.record("A closed association must stay closed after redelivery: \(redelivery)")
        return
      }
      #expect(try fixture.graph(redelivered) == fixture.graph(after))
      #expect(try fixture.envelope()["receipts"] as? NSArray == receipts)
    }
  }

  @Test(arguments: [3, 4])
  func oldValidBackupCannotReintroduceAnUnawareSiblingAfterStrictRemove(formatVersion: Int)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make()
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    guard
      case .applied(let addition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addMembership(
            itemId: fixture.source.id, listId: listIdentifier, placement: .last))
      ).outcome,
      case .membership(let identifier, _, _)? = addition.generatedReferences.first
    else { throw CancellationError() }
    var graph = try fixture.object(fixture.siblingMembershipData(formatVersion: formatVersion))
    var sources = try #require(graph["sources"] as? [[String: Any]])
    let sourceIndex = try #require(
      sources.firstIndex {
        $0["kind"] as? String == "item" && $0["id"] as? String == fixture.source.id.uuidString
      })
    sources[sourceIndex]["lifetimeId"] = "00000000-0000-4000-8000-000000000815"
    graph["sources"] = sources
    var families = try #require(graph["restorationFamilies"] as? [[String: Any]])
    var family = try #require(families.first)
    let candidates = try #require(family["candidates"] as? [[String: Any]])
    family["candidates"] = candidates.filter {
      $0["lifetimeId"] as? String == "00000000-0000-4000-8000-000000000815"
    }
    families[0] = family
    graph["restorationFamilies"] = families
    var memberships = try #require(graph["memberships"] as? [[String: Any]])
    var item = try #require(memberships[0]["item"] as? [String: Any])
    item["lifetimeId"] = "00000000-0000-4000-8000-000000000815"
    memberships[0]["item"] = item
    graph["memberships"] = memberships
    guard
      case .decoded(let backup) = fixture.planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph))
    else { throw CancellationError() }
    let command = PlannerCommand.applyImport(backup: backup, mode: .overwrite)
    let beforeRemove = await fixture.planner.prepareReview(
      session: fixture.session, command: command)
    guard case .reviewed = beforeRemove else {
      Issue.record("The old backup must be independently reviewable before Remove: \(beforeRemove)")
      return
    }
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeMembership(listId: listIdentifier, membershipId: identifier))
      ).outcome,
      case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    let files = try fixture.files()
    let afterRemove = await fixture.planner.prepareReview(
      session: fixture.session, command: command)
    guard case .reviewed(let review) = afterRemove else {
      Issue.record("The old import must reach current-data admission through its ordinary review.")
      return
    }
    let operation = PlannerOperation(
      operationId: UUID(), session: fixture.session, command: review.command,
      reviewToken: review.reviewToken)
    let response = await fixture.planner.execute(operation)
    guard case .rejected(let failure) = response.outcome,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operation.operationId)
    else {
      Issue.record(
        "Strict Remove must reject the whole old unaware import without recording a save.")
      return
    }
    #expect(failure.code == "invalidInput")
    #expect(try fixture.files() == files)
    guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(after) == fixture.graph(before))
  }

  @Test(arguments: [false, true], [false, true])
  func eligibleSiblingMembershipsKeepTheirGenerationAndExplicitCompletion(
    strictRemoval: Bool, explicitReopen: Bool
  ) async throws {
    let fixture = try await SourceRestorationFixture.make()
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    var currentIdentifier: UUID?
    for index in 0..<(strictRemoval ? 2 : 1) {
      guard
        case .applied(let addition, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .addMembership(
              itemId: fixture.source.id, listId: listIdentifier, placement: .last))
        ).outcome,
        case .membership(let identifier, _, _)? = addition.generatedReferences.first
      else { throw CancellationError() }
      currentIdentifier = identifier
      if strictRemoval && index == 0 {
        guard
          case .applied(_, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session,
              command: .removeMembership(listId: listIdentifier, membershipId: identifier))
          ).outcome
        else { throw CancellationError() }
      }
    }
    let originalIdentifier = try #require(currentIdentifier)
    if explicitReopen {
      for done in [true, false] {
        guard
          case .applied(_, .complete) = await fixture.planner.execute(
            .init(
              operationId: UUID(), session: fixture.session,
              command: .setCompletion(
                scope: .appearance(
                  .listMembership(
                    listId: listIdentifier, membershipId: originalIdentifier)), done: done))
          ).outcome
        else { throw CancellationError() }
      }
    }
    guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let previous) = fixture.planner.decodeImport(before)
    else { throw CancellationError() }
    let removals = previous.backup.membershipRemovals.map(\.deletionId)
    let siblingIdentifier = try await fixture.deliverSiblingMembership(observedRemovals: removals)
    let normalized = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let bytes) = normalized,
      case .decoded(let decoded) = fixture.planner.decodeImport(bytes)
    else {
      Issue.record(
        "Eligible sibling memberships must consolidate in their observed generation: \(normalized)")
      return
    }
    let membership = try #require(decoded.backup.memberships.first)
    #expect(decoded.backup.memberships.count == 1)
    #expect(
      membership.id
        == [originalIdentifier, siblingIdentifier].min(by: {
          $0.uuidString < $1.uuidString
        }))
    #expect(membership.localDone == !explicitReopen)
    #expect(membership.itemLifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
    for provenance in previous.backup.membershipProvenance {
      #expect(decoded.backup.membershipProvenance.contains(provenance))
    }
    let originalSibling = try #require(
      decoded.backup.membershipProvenance.first {
        $0.membershipId == siblingIdentifier
      })
    #expect(originalSibling.item.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000815")
    #expect(Set(originalSibling.observedRemovalIds) == Set(removals))
  }

  @Test(
    arguments: [PlannerEntityKind.category, .tag],
    ["scalarMismatch", "ownerMismatch"])
  func invalidLabelRebindingPreservesAllNativeAndRecoveryState(
    kind: PlannerEntityKind, scenario: String
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItem(
            content: .init(
              title: "Independent owner", categoryIds: kind == .category ? [fixture.source.id] : [],
              tagIds: kind == .tag ? [fixture.source.id] : [])))
      ).outcome
    else { throw CancellationError() }
    try await fixture.deliverCandidate()
    try await fixture.bindLabelToLosingCandidate()
    try await fixture.invalidateLabelTarget(scenario)
    let before = try await fixture.rawLabelData()
    let files = try fixture.files()
    let control = try Data(contentsOf: fixture.configuration.controlURL)
    guard case .failed = await fixture.planner.exportData(session: fixture.session) else {
      Issue.record("Invalid \(kind) target \(scenario) must reject the complete projection.")
      return
    }
    #expect(try await fixture.rawLabelData() == before)
    #expect(try fixture.files() == files)
    #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
  }

  @Test(arguments: [false, true], [false, true])
  func repeatedRestoredListTargetsPreserveIndependentExpandedCompletion(
    upgrade: Bool, invalidExpanded: Bool
  ) async throws {
    let fixture = try await SourceRestorationFixture.make(kind: .list)
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    let itemIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000101")!
    guard
      case .applied(let addition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addMembership(
            itemId: itemIdentifier, listId: fixture.source.id, placement: .last))
      ).outcome,
      case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
    else { throw CancellationError() }
    var entries: [UUID] = []
    for _ in 0..<2 {
      guard
        case .applied(let addition, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .addItineraryEntry(
              itineraryId: itineraryIdentifier,
              source: fixture.source, placement: .last))
        ).outcome,
        case .itineraryEntry(let identifier, _, _)? = addition.generatedReferences.first
      else { throw CancellationError() }
      entries.append(identifier)
    }
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setCompletion(
            scope: .appearance(
              .expandedListItem(
                itineraryId: itineraryIdentifier, listEntryId: entries[1],
                membershipId: membershipIdentifier)), done: true))
      ).outcome,
      case .exported(let expected) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try await fixture.deliverCandidate()
    try await fixture.bindEntriesToLosingCandidate(entries)
    if invalidExpanded {
      try await fixture.corruptExpandedFlag()
      if upgrade { try fixture.rewriteCompatibility(22) }
      let files = try fixture.files()
      let control = try Data(contentsOf: fixture.configuration.controlURL)
      let rawEntries = try await fixture.rawEntryData()
      let rawExpanded = try await fixture.rawExpandedData()
      if upgrade {
        let reopened = Planner(configuration: fixture.configuration)
        guard case .unavailable = await reopened.bootstrap() else {
          Issue.record("An invalid expanded flag must block source projection before activation.")
          return
        }
      } else {
        guard case .failed = await fixture.planner.exportData(session: fixture.session) else {
          Issue.record("Source maintenance must not silently repair an invalid expanded flag.")
          return
        }
      }
      #expect(try fixture.files() == files)
      #expect(try Data(contentsOf: fixture.configuration.controlURL) == control)
      #expect(try await fixture.rawEntryData() == rawEntries)
      #expect(try await fixture.rawExpandedData() == rawExpanded)
      return
    }
    let planner: Planner
    let session: PlannerDatasetSession
    if upgrade {
      try fixture.rewriteCompatibility(22)
      let share = Planner(
        configuration: .init(
          storeURL: fixture.configuration.storeURL, controlURL: fixture.configuration.controlURL,
          recoveryDirectoryURL: fixture.configuration.recoveryDirectoryURL,
          processRole: .shareExtension, storageMode: .localOnly))
      guard case .mainAppMigrationRequired = await share.bootstrap() else {
        throw CancellationError()
      }
      planner = Planner(configuration: fixture.configuration)
      let bootstrap = await planner.bootstrap()
      guard case .ready(let readySession) = bootstrap else {
        Issue.record(
          "The complete restored List projection must upgrade before activation: \(bootstrap)")
        return
      }
      session = readySession
      guard case .ready = await share.bootstrap() else { throw CancellationError() }
    } else {
      planner = fixture.planner
      session = fixture.session
    }
    let normalized = await planner.exportData(session: session)
    guard case .exported(let actual) = normalized else {
      Issue.record(
        "Repeated restored List targets must preserve valid expanded state: \(normalized)")
      return
    }
    #expect(try fixture.graph(actual) == fixture.graph(expected))
    for (index, identifier) in entries.enumerated() {
      guard
        case .appearance(let appearance) = await planner.read(
          session: session,
          request: .appearance(
            .expandedListItem(
              itineraryId: itineraryIdentifier, listEntryId: identifier,
              membershipId: membershipIdentifier)))
      else { throw CancellationError() }
      #expect(appearance.localDone == (index == 1))
    }
    guard
      case .appearance(let standalone) = await planner.read(
        session: session,
        request: .appearance(
          .listMembership(
            listId: fixture.source.id, membershipId: membershipIdentifier)))
    else { throw CancellationError() }
    #expect(standalone.localDone == false)
  }

  @Test(arguments: [PlannerEntityKind.list, .category, .tag])
  func independentListAndLabelTargetsKeepTheirCompleteSavedGraph(kind: PlannerEntityKind)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make(kind: kind)
    var entryIdentifier: UUID?
    if kind == .list {
      guard
        case .applied(let result, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .addItineraryEntry(
              itineraryId: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
              source: fixture.source, placement: .last))
        ).outcome,
        case .itineraryEntry(let identifier, _, _)? = result.generatedReferences.first
      else { throw CancellationError() }
      entryIdentifier = identifier
    } else {
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .createItem(
              content: .init(
                title: "Independent visit", notes: "Keep the independent owner unchanged",
                categoryIds: kind == .category ? [fixture.source.id] : [],
                tagIds: kind == .tag ? [fixture.source.id] : [])))
        ).outcome,
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .createItinerary(
              content: .init(
                title: "Independent label route", notes: "Keep this owner unchanged too",
                categoryIds: kind == .category ? [fixture.source.id] : [],
                tagIds: kind == .tag ? [fixture.source.id] : [])))
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let expected) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    try await fixture.deliverCandidate()
    if let entryIdentifier {
      try await fixture.bindEntriesToLosingCandidate([entryIdentifier])
    } else {
      try await fixture.bindLabelToLosingCandidate()
    }
    let normalized = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let actual) = normalized else {
      Issue.record(
        "An independent \(kind) target must follow its winner without changing its owner: \(normalized)"
      )
      return
    }
    #expect(try fixture.graph(actual) == fixture.graph(expected))
  }

  @Test(arguments: [false, true])
  func nativeUnawareSiblingAddStaysRemovedWithoutRewritingItsAttestation(expanded: Bool)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make()
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    guard
      case .applied(let added, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addMembership(
            itemId: fixture.source.id, listId: listIdentifier, placement: .last))
      ).outcome,
      case .membership(let identifier, _, _)? = added.generatedReferences.first
    else { throw CancellationError() }
    var entryIdentifier: UUID?
    if expanded {
      guard
        case .applied(let entry, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .addItineraryEntry(
              itineraryId: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
              source: .init(kind: .list, id: listIdentifier), placement: .last))
        ).outcome,
        case .itineraryEntry(let createdIdentifier, _, _)? = entry.generatedReferences.first
      else { throw CancellationError() }
      entryIdentifier = createdIdentifier
    }
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeMembership(listId: listIdentifier, membershipId: identifier))
      ).outcome
    else { throw CancellationError() }
    let offlineIdentifier = try await fixture.deliverSiblingMembership(
      expandedEntryIdentifier: entryIdentifier)
    let normalized = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let bytes) = normalized,
      case .decoded(let actual) = fixture.planner.decodeImport(bytes)
    else {
      Issue.record(
        "An unaware native sibling Add must normalize without reviving the membership: \(normalized)"
      )
      return
    }
    #expect(actual.backup.memberships.isEmpty)
    #expect(actual.backup.expandedCompletions.isEmpty)
    if let entryIdentifier {
      #expect(actual.backup.itineraryEntries.map(\.id) == [entryIdentifier])
    }
    let retained = try #require(
      actual.backup.membershipProvenance.first {
        $0.membershipId == offlineIdentifier
      })
    #expect(retained.item.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000815")
    #expect(retained.observedRemovalIds.isEmpty)
    guard
      case .source(.item(let item)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.source))
    else { throw CancellationError() }
    #expect(item.state.globalDone == false && item.content.notes == "Original notes")
    let maintenance = try #require(fixture.envelope()["maintenanceReceipts"] as? [[String: Any]])
    #expect(maintenance.count == 1 && maintenance.first?["ruleVersion"] as? Int == 3)
  }

  @Test func deliberateReAddObservesRemovalAttestedAgainstTheSibling() async throws {
    let fixture = try await SourceRestorationFixture.make()
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    guard
      case .decoded(let incoming) = fixture.planner.decodeImport(
        try fixture.siblingMembershipData(formatVersion: 5)),
      case .reviewed(let review) = await fixture.planner.prepareReview(
        session: fixture.session, command: .applyImport(backup: incoming, mode: .overwrite)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeMembership(
            listId: listIdentifier,
            membershipId: UUID(uuidString: "00000000-0000-4000-8000-000000000403")!))
      ).outcome,
      case .exported(let removed) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let removalBackup) = fixture.planner.decodeImport(removed)
    else { throw CancellationError() }
    let addition = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .addMembership(itemId: fixture.source.id, listId: listIdentifier, placement: .last)
      ))
    guard case .applied(_, .complete) = addition.outcome,
      case .exported(let saved) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let actual) = fixture.planner.decodeImport(saved),
      let member = actual.backup.memberships.first
    else {
      Issue.record("A deliberate re-add must observe the sibling's retained Remove: \(addition)")
      return
    }
    let provenance = try #require(
      actual.backup.membershipProvenance.first {
        $0.membershipId == member.id && $0.membershipLifetimeId == member.lifetimeId
      })
    #expect(member.localDone == false)
    #expect(member.itemLifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
    #expect(
      Set(provenance.observedRemovalIds)
        == Set(removalBackup.backup.membershipRemovals.map(\.deletionId)))
  }

  @Test func portableFiveImportSavesOriginalAttestationAndReplaysItsExactResult() async throws {
    let fixture = try await SourceRestorationFixture.make()
    guard
      case .decoded(let incoming) = fixture.planner.decodeImport(
        try fixture.siblingMembershipData(formatVersion: 5))
    else { throw CancellationError() }
    let reviewed = await fixture.planner.prepareReview(
      session: fixture.session, command: .applyImport(backup: incoming, mode: .overwrite))
    guard case .reviewed(let review) = reviewed else {
      Issue.record("A valid version5 membership must be reviewable for real storage: \(reviewed)")
      return
    }
    let operation = PlannerOperation(
      operationId: UUID(), session: fixture.session, command: review.command,
      reviewToken: review.reviewToken)
    let saved = await fixture.planner.execute(operation)
    guard case .applied(let original, .complete(let generation)) = saved.outcome,
      case .exported(let bytes) = await fixture.planner.exportData(session: fixture.session),
      case .decoded(let actual) = fixture.planner.decodeImport(bytes)
    else {
      Issue.record("A reviewed version5 import must save with complete recovery: \(saved)")
      return
    }
    #expect(actual.backup.formatVersion == 5)
    #expect(
      actual.backup.memberships.first?.itemLifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    #expect(
      actual.backup.membershipProvenance.first?.item.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000815")
    guard
      case .applied(let replayed, .complete(let replayGeneration)) = await fixture.planner.execute(
        operation
      ).outcome
    else { throw CancellationError() }
    #expect(replayed == original && replayGeneration == generation)
    let identity = try fixture.object(Data(contentsOf: fixture.configuration.controlURL))
    #expect(identity["schemaVersion"] as? Int == 23)
    #expect(try fixture.envelope()["storageSchemaVersion"] as? String == "23")
    let reimport = await fixture.planner.prepareReview(
      session: fixture.session, command: .applyImport(backup: incoming, mode: .overwrite))
    guard case .reviewed(let nextReview) = reimport else {
      Issue.record("Reimport must recognize the original sibling attestation: \(reimport)")
      return
    }
    let reapplied = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session, command: nextReview.command,
        reviewToken: nextReview.reviewToken))
    guard case .applied(_, .complete) = reapplied.outcome,
      case .exported(let reimported) = await fixture.planner.exportData(session: fixture.session)
    else {
      Issue.record("Reimport must save without changing the retained attestation: \(reapplied)")
      return
    }
    #expect(try fixture.graph(reimported) == fixture.graph(bytes))
  }

  @Test(arguments: [false, true])
  func portableFiveRequiresTheRemovalObservedAcrossItemSiblings(observedRemoval: Bool)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make()
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    guard
      case .applied(let addition, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .addMembership(
            itemId: fixture.source.id, listId: listIdentifier, placement: .last))
      ).outcome,
      case .membership(let removedIdentifier, _, _)? = addition.generatedReferences.first,
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .removeMembership(listId: listIdentifier, membershipId: removedIdentifier))
      ).outcome,
      case .exported(let removed) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    var graph = try fixture.object(removed)
    let removals = try #require(graph["membershipRemovals"] as? [[String: Any]])
    let removalIdentifier = try #require(removals.first?["deletionId"] as? String)
    var provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    let original = try #require(provenance.first)
    let list = try #require(original["list"] as? [String: Any])
    let item = try #require(original["item"] as? [String: Any])
    var sibling = item
    sibling["lifetimeId"] = "00000000-0000-4000-8000-000000000815"
    let identifier = "00000000-0000-4000-8000-000000000403"
    let lifetime = "00000000-0000-4000-8000-000000000843"
    graph["formatVersion"] = 5
    graph["memberships"] = [
      [
        "id": identifier, "lifetimeId": lifetime, "list": list, "item": item,
        "rank": "0", "localDone": false,
      ]
    ]
    provenance.append([
      "membershipId": identifier, "membershipLifetimeId": lifetime,
      "list": list, "item": sibling,
      "observedRemovalIds": observedRemoval ? [removalIdentifier] : [],
    ])
    graph["membershipProvenance"] = provenance
    let decoded = fixture.planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
    if !observedRemoval {
      guard case .invalid = decoded else {
        Issue.record("An unaware sibling Add must not be admitted after Remove.")
        return
      }
      return
    }
    guard case .decoded(let backup) = decoded else {
      Issue.record(
        "An actual removal observation must remain valid across proven Item siblings: \(decoded)")
      return
    }
    let retained = try #require(
      backup.backup.membershipProvenance.first {
        $0.membershipId.uuidString == identifier
      })
    #expect(retained.item.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000815")
    #expect(retained.observedRemovalIds.map(\.uuidString) == [removalIdentifier])

    var markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000893",
      "operationId": "00000000-0000-4000-8000-000000000993",
      "target": ["kind": "membership", "id": identifier, "lifetimeId": lifetime],
      "closedFamilyId": NSNull(),
    ])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000894",
      "operationId": "00000000-0000-4000-8000-000000000996",
      "target": ["kind": "source", "source": item],
      "closedFamilyId": "00000000-0000-4000-8000-000000000890",
    ])
    graph["deletionMarkers"] = markers
    var families = try #require(graph["restorationFamilies"] as? [[String: Any]])
    families.append([
      "familyId": "00000000-0000-4000-8000-000000000891", "predecessor": item,
      "candidates": [
        [
          "lifetimeId": "00000000-0000-4000-8000-000000000816",
          "operationId": "00000000-0000-4000-8000-000000000997",
        ]
      ],
    ])
    graph["restorationFamilies"] = families
    var sources = try #require(graph["sources"] as? [[String: Any]])
    let sourceIndex = try #require(
      sources.firstIndex {
        $0["kind"] as? String == "item" && $0["id"] as? String == item["id"] as? String
      })
    sources[sourceIndex]["lifetimeId"] = "00000000-0000-4000-8000-000000000816"
    graph["sources"] = sources
    var nextItem = item
    nextItem["lifetimeId"] = "00000000-0000-4000-8000-000000000816"
    graph["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000404",
        "lifetimeId": "00000000-0000-4000-8000-000000000844",
        "list": list, "item": nextItem, "rank": "0", "localDone": false,
      ]
    ]
    for inheritsOldRemoval in [false, true] {
      var nextProvenance = provenance
      nextProvenance.append([
        "membershipId": "00000000-0000-4000-8000-000000000404",
        "membershipLifetimeId": "00000000-0000-4000-8000-000000000844",
        "list": list, "item": nextItem,
        "observedRemovalIds": inheritsOldRemoval ? [removalIdentifier] : [],
      ])
      graph["membershipProvenance"] = nextProvenance
      let next = fixture.planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
      if inheritsOldRemoval {
        guard case .invalid = next else {
          Issue.record("A new Item family must not inherit its predecessor's removal authority.")
          return
        }
      } else {
        guard case .decoded(let closedHistory) = next else {
          Issue.record(
            "Closed sibling observations must survive beside an independent new family: \(next)")
          return
        }
        #expect(closedHistory.backup.membershipProvenance.contains(retained))
        #expect(
          closedHistory.backup.memberships.first?.itemLifetimeId.uuidString
            == "00000000-0000-4000-8000-000000000816")
      }
    }
  }

  @Test func portableFivePreservesAttestedSiblingBindingsWithoutReinterpretingVersionFour()
    async throws
  {
    let fixture = try await SourceRestorationFixture.make()
    guard
      case .invalid = fixture.planner.decodeImport(
        try fixture.siblingMembershipData(formatVersion: 4))
    else {
      Issue.record("Version4 must retain its exact attested-endpoint rule.")
      return
    }
    let result = fixture.planner.decodeImport(try fixture.siblingMembershipData(formatVersion: 5))
    guard case .decoded(let decoded) = result else {
      Issue.record(
        "Version5 must retain a proven sibling attestation beside its live winner: \(result)")
      return
    }
    #expect(decoded.backup.formatVersion == 5)
    #expect(
      decoded.backup.memberships.first?.itemLifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    #expect(
      decoded.backup.membershipProvenance.first?.item.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000815")
    #expect(decoded.backup.membershipProvenance.first?.observedRemovalIds.isEmpty == true)
  }
}
