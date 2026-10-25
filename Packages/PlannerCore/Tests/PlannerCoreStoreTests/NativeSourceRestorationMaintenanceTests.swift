import Foundation
import SwiftData
import Testing

@testable import PlannerCore

#if os(macOS)
  import Darwin
#endif

struct NativeSourceRestorationMaintenanceTests {
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

  @Test(arguments: [false, true])
  func losingListMembershipsRetireWithoutMergingRepeatedBranchCompletion(referenced: Bool)
    async throws
  {
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
    try await fixture.deliverCandidateWithOwnedMembership(entries: entries)
    let result = await fixture.planner.exportData(session: fixture.session)
    guard case .exported(let after) = result else {
      Issue.record("Only the winning List's memberships and branch states must remain: \(result)")
      return
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
    for (index, identifier) in entries.enumerated() {
      guard
        case .appearance(let appearance) = await fixture.planner.read(
          session: fixture.session,
          request: .appearance(
            .expandedListItem(
              itineraryId: itineraryIdentifier, listEntryId: identifier,
              membershipId: membershipIdentifier)))
      else { throw CancellationError() }
      #expect(appearance.localDone == (index == 1))
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
    let stale = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
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
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let persisted) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(try fixture.graph(persisted) == fixture.graph(after))
    try await fixture.deliverCandidateWithOwnedMembership(entries: entries)
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
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
    #expect(try fixture.graph(after) == fixture.graph(fixture.baseline))
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
    #expect(try fixture.graph(after) == fixture.graph(before))
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
    #expect(try fixture.graph(persisted) == fixture.graph(before))
    try await fixture.deliverCandidateWithSchedule(allDay: allDay)
    guard
      case .exported(let redelivered) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(try fixture.graph(redelivered) == fixture.graph(before))
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
    #expect(try fixture.graph(after) == fixture.graph(fixture.baseline))
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
    #expect(try fixture.graph(recovered) == fixture.graph(fixture.baseline))
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

  static func make(kind: PlannerEntityKind = .item) async throws -> Self {
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
        "rank": String(entry.rank), "localDone": entry.localDone as Any? ?? NSNull(),
      ]
    }
    return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
  }

  @MainActor func nativeEntryData() throws -> Data {
    let context = try nativeContext()
    let values = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).map {
      PortableItineraryEntryRecord(try $0.value())
    }.sorted { $0.id.uuidString < $1.id.uuidString }
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

  @MainActor func deliverCandidate() throws {
    let context = try nativeContext()
    let lifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000815")!
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
      if stage == "nativeSaveFailure" {
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
