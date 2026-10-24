import CryptoKit
import Foundation
import SwiftData
import Testing

@testable import PlannerCore

#if os(macOS)
  import Darwin
#endif

struct NativeMembershipConsolidationTests {
  @Test(
    arguments: ["list", "expanded", "direct"],
    [
      "head", "predecessor", "alias", "wrongAlias", "duplicateObservation", "cycle",
      "canonicalDirect", "canonicalExpanded",
    ])
  func incompleteCompletionHistoryRejectsCurrentReadsAndWritesUntilItsRecordsArrive(
    scope: String, historyCondition: String
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("The partial-history fixture action must save: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let addition = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last))
    let expandedAddition = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let directAddition = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard case .membership(let membership, _, _)? = addition.generatedReferences.first,
      case .itineraryEntry(let expandedEntry, _, _)? = expandedAddition.generatedReferences.first,
      case .itineraryEntry(let directEntry, _, _)? = directAddition.generatedReferences.first
    else { throw CancellationError() }
    let appearance: PlannerAppearance
    switch scope {
    case "list": appearance = .listMembership(listId: list.id, membershipId: membership)
    case "expanded":
      appearance = .expandedListItem(
        itineraryId: itinerary.id, listEntryId: expandedEntry, membershipId: membership)
    default: appearance = .directItineraryItem(itineraryId: itinerary.id, entryId: directEntry)
    }
    _ = try await save(.setCompletion(scope: .appearance(appearance), done: true))
    let reopening = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(appearance), done: false))
    guard
      case .applied(let reopened, .complete(let checkpoint)) = await planner.execute(reopening)
        .outcome
    else { throw CancellationError() }
    if historyCondition == "canonicalDirect" {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    } else if historyCondition == "canonicalExpanded" {
      _ = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    }
    guard
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let decoded) = planner.decodeImport(before),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    let alias = try #require(decoded.backup.contextAliases.first)
    #expect(decoded.backup.contextAliases.count == 1)
    #expect(decoded.backup.completionChanges.count == 2)
    let identifier: UUID
    let kind: String
    let content: Data
    let expectedPropertyPath: String
    var inconsistentContent: Data?
    if historyCondition == "canonicalDirect" || historyCondition == "canonicalExpanded" {
      identifier = alias.aliasId
      kind = "contextAlias"
      content = try JSONEncoder().encode(alias)
      expectedPropertyPath = "/contextAliases/0/canonicalContext"
      let canonicalContext: PlannerPortableCompletionContext
      if historyCondition == "canonicalDirect" {
        let target = try #require(
          decoded.backup.itineraryEntries.first { $0.id != directEntry && $0.source.kind == .item })
        canonicalContext = .directItineraryItem(
          entryId: target.id, entryLifetimeId: target.lifetimeId)
      } else {
        let target = try #require(
          decoded.backup.itineraryEntries.first {
            $0.id != expandedEntry && $0.source.kind == .list
          })
        let member = try #require(decoded.backup.memberships.first { $0.id == membership })
        canonicalContext = .expandedListItem(
          .init(
            listEntryId: target.id, listEntryLifetimeId: target.lifetimeId,
            membershipId: member.id, membershipLifetimeId: member.lifetimeId))
      }
      inconsistentContent = try JSONEncoder().encode(
        PlannerPortableContextAlias(
          aliasId: alias.aliasId, context: alias.context, canonicalContext: canonicalContext,
          initialDone: alias.initialDone, currentChangeId: alias.currentChangeId))
    } else if historyCondition == "alias" {
      identifier = alias.aliasId
      kind = "contextAlias"
      content = try JSONEncoder().encode(alias)
      expectedPropertyPath = "/completionChanges/0/aliasId"
    } else {
      let change: PlannerPortableCompletionChange
      if historyCondition == "predecessor" || historyCondition == "cycle" {
        change = try #require(decoded.backup.completionChanges.first { $0.done })
      } else {
        change = try #require(
          decoded.backup.completionChanges.first { $0.id == alias.currentChangeId })
      }
      identifier = change.id
      kind = "completionChange"
      content = try JSONEncoder().encode(change)
      let headIndex = try #require(
        decoded.backup.completionChanges.firstIndex { $0.id == alias.currentChangeId })
      switch historyCondition {
      case "predecessor":
        expectedPropertyPath = "/completionChanges/0/observedChangeIds/0"
      case "wrongAlias":
        expectedPropertyPath = "/contextAliases/0/currentChangeId"
        inconsistentContent = try JSONEncoder().encode(
          PlannerPortableCompletionChange(
            id: change.id, aliasId: UUID(uuidString: "00000000-0000-4000-8000-000000000990")!,
            context: change.context, done: change.done, observedChangeIds: change.observedChangeIds)
        )
      case "duplicateObservation":
        expectedPropertyPath = "/completionChanges/\(headIndex)/observedChangeIds"
        let predecessor = try #require(change.observedChangeIds.first)
        inconsistentContent = try JSONEncoder().encode(
          PlannerPortableCompletionChange(
            id: change.id, aliasId: change.aliasId, context: change.context, done: change.done,
            observedChangeIds: [predecessor, predecessor]))
      case "cycle":
        expectedPropertyPath = "/completionChanges/0/observedChangeIds"
        inconsistentContent = try JSONEncoder().encode(
          PlannerPortableCompletionChange(
            id: change.id, aliasId: change.aliasId, context: change.context, done: change.done,
            observedChangeIds: [try #require(alias.currentChangeId)]))
      default: expectedPropertyPath = "/contextAliases/0/currentChangeId"
      }
    }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let beforeFiles = try maintenanceNamespaceFiles(namespaceDirectory)
    try await setNativeCompletionLineageRecord(
      storeURL: configuration.storeURL, identifier: identifier, kind: kind, content: nil)
    if let inconsistentContent {
      try await setNativeCompletionLineageRecord(
        storeURL: configuration.storeURL, identifier: identifier, kind: kind,
        content: inconsistentContent)
    }
    let query = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .itinerary(itinerary.id), completion: .all, archive: .all))))
    let read = await planner.read(session: session, request: .appearance(appearance))
    guard case .failed(let queryFailure) = query, case .failed(let readFailure) = read else {
      Issue.record(
        "Incomplete causal history must not expose a guessed current state: \(query), \(read)")
      return
    }
    #expect(queryFailure.code == "readUnavailable" && readFailure.code == "readUnavailable")
    #expect(queryFailure.propertyPath == expectedPropertyPath)
    #expect(readFailure.propertyPath == expectedPropertyPath)
    let waiting = PlannerOperation(
      operationId: UUID(), session: session,
      command: .createTag(content: .init(name: "Must remain unapplied")))
    guard case .rejected(let rejected) = await planner.execute(waiting).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: waiting.operationId),
      case .status(let status) = await planner.read(session: session, request: .status),
      case .unavailable(let reason) = status.recovery,
      case .applied(let replayed, .complete(let replayCheckpoint)) = await planner.execute(
        reopening
      )
      .outcome
    else { throw CancellationError() }
    #expect(rejected.code == "readUnavailable" && reason.code == "readUnavailable")
    #expect(replayed == reopened && replayCheckpoint == checkpoint)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
    let fresh = Planner(configuration: configuration)
    guard case .unavailable(let unavailable) = await fresh.bootstrap() else {
      Issue.record("An incomplete history must remain unavailable after relaunch")
      return
    }
    #expect(unavailable.code == "readUnavailable")
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
    if inconsistentContent != nil {
      try await setNativeCompletionLineageRecord(
        storeURL: configuration.storeURL, identifier: identifier, kind: kind, content: nil)
    }
    try await setNativeCompletionLineageRecord(
      storeURL: configuration.storeURL, identifier: identifier, kind: kind, content: content)
    guard case .ready(let freshSession) = await fresh.bootstrap(),
      case .appearance(let current) = await fresh.read(
        session: freshSession, request: .appearance(appearance)),
      case .exported(let after) = await fresh.exportData(session: freshSession)
    else { throw CancellationError() }
    #expect(
      current.source == item && !current.globalDone && !current.localDone && !current.effectiveDone)
    #expect(after == before)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
  }

  @Test(
    arguments: ["individual", "branchBulk", "itineraryBulk"].flatMap {
      [$0, "retiredSibling:" + $0]
    }, [false, true])
  func aMissingExpandedCompletionRetainsItsProvenHistoryAndExactRepeatedScope(
    rawScope: String, preparationFails: Bool
  ) async throws {
    let retireSibling = rawScope.hasPrefix("retiredSibling:")
    let commandScope =
      retireSibling ? String(rawScope.dropFirst("retiredSibling:".count)) : rawScope
    let wholeItinerary = commandScope == "itineraryBulk"
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("The missing-completion fixture action must save: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let membership = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last))
    let firstAddition = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let secondAddition = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let directAddition = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard case .membership(let membershipIdentifier, _, _)? = membership.generatedReferences.first,
      case .itineraryEntry(let firstEntry, _, _)? = firstAddition.generatedReferences.first,
      case .itineraryEntry(let secondEntry, _, _)? = secondAddition.generatedReferences.first,
      case .itineraryEntry(let directEntry, _, _)? = directAddition.generatedReferences.first
    else { throw CancellationError() }
    let selected = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: firstEntry, membershipId: membershipIdentifier)
    let completion: PlannerOperation
    if commandScope == "individual" {
      completion = .init(
        operationId: UUID(), session: session,
        command: .setCompletion(scope: .appearance(selected), done: true))
    } else {
      let bulkScope: PlannerBulkScope
      if wholeItinerary {
        bulkScope = .itinerary(itineraryId: itinerary.id)
      } else {
        bulkScope = .itineraryListEntry(itineraryId: itinerary.id, listEntryId: firstEntry)
      }
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .setBulkCompletion(scope: bulkScope, done: true))
      else { throw CancellationError() }
      completion = .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken)
    }
    guard
      case .applied(let completed, .complete(let checkpoint)) = await planner.execute(completion)
        .outcome
    else { throw CancellationError() }
    if retireSibling {
      _ = try await save(
        .setCompletion(
          scope: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id, listEntryId: secondEntry,
              membershipId: membershipIdentifier)), done: true))
      _ = try await save(.removeItineraryEntry(itineraryId: itinerary.id, entryId: secondEntry))
    }
    guard case .exported(let before) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    try await removeNativeExpandedCompletion(
      storeURL: configuration.storeURL, entryIdentifier: firstEntry,
      membershipIdentifier: membershipIdentifier)
    if preparationFails {
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(
          request: .namespaces), let namespace = namespaces.first
      else { throw CancellationError() }
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespace.namespaceId.uuidString)
      let beforeFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o500], ofItemAtPath: namespaceDirectory.path)
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
      }
      let failedQuery = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .itinerary(itinerary.id), completion: .all, archive: .all))))
      guard case .failed(let failure) = failedQuery,
        case .status(let status) = await planner.read(session: session, request: .status),
        case .unavailable(let reason) = status.recovery
      else {
        Issue.record("Unprepared missing-row repair must stay unavailable: \(failedQuery)")
        return
      }
      #expect(failure.code == "maintenanceRequired" && reason.code == "maintenanceRequired")
      #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
    }
    let fresh = Planner(configuration: configuration)
    let readiness = await fresh.bootstrap()
    guard case .ready(let freshSession) = readiness else {
      Issue.record("Proven completion must survive a missing native row: \(readiness)")
      return
    }
    var expectedAppearances: [(PlannerAppearance, Bool)] = [
      (selected, true),
      (.directItineraryItem(itineraryId: itinerary.id, entryId: directEntry), wholeItinerary),
      (.listMembership(listId: list.id, membershipId: membershipIdentifier), false),
    ]
    if !retireSibling {
      expectedAppearances.append(
        (
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: secondEntry,
            membershipId: membershipIdentifier), wholeItinerary
        ))
    } else {
      guard
        case .snapshot(let contents) = await fresh.query(
          .init(
            session: freshSession,
            request: .items(
              .init(scope: .itinerary(itinerary.id), completion: .all, archive: .all))))
      else { throw CancellationError() }
      #expect(contents.matchingCount == 2)
    }
    for (appearance, expectedDone) in expectedAppearances {
      let response = await fresh.read(session: freshSession, request: .appearance(appearance))
      guard case .appearance(let read) = response else {
        Issue.record("The exact saved appearance must remain readable: \(response)")
        return
      }
      #expect(read.source == item && !read.globalDone)
      #expect(read.localDone == expectedDone && read.effectiveDone == expectedDone)
    }
    let retainedExport = await fresh.exportData(session: freshSession)
    guard case .exported(let retained) = retainedExport else {
      Issue.record(
        "Missing scalar rows must not invalidate complete saved history: \(retainedExport)")
      return
    }
    #expect(retained == before)
    guard
      case .applied(_, .complete) = await fresh.execute(
        .init(
          operationId: UUID(), session: freshSession,
          command: .setCompletion(scope: .appearance(selected), done: false))
      )
      .outcome,
      case .exported(let afterReopening) = await fresh.exportData(session: freshSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await fresh.execute(
        .init(
          operationId: completion.operationId, session: freshSession, command: completion.command)
      ).outcome,
      case .exported(let afterReplay) = await fresh.exportData(session: freshSession)
    else { throw CancellationError() }
    #expect(replayed == completed && replayCheckpoint == checkpoint)
    #expect(afterReplay == afterReopening)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let afterRelaunch) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(afterRelaunch == afterReopening)
  }

  @Test(
    arguments: ["list", "expanded", "direct", "listBulk", "expandedBulk", "itineraryBulk"].flatMap {
      [$0, "first:" + $0, "divergent:" + $0]
    },
    [false, true])
  func reopeningBeforeAnyDuplicateArrivesStillSupersedesALateDoneSeed(
    rawScope: String, preparationFails: Bool
  ) async throws {
    let firstAssertion = rawScope.hasPrefix("first:")
    let divergentHistory = rawScope.hasPrefix("divergent:")
    let scope: String
    if firstAssertion {
      scope = String(rawScope.dropFirst("first:".count))
    } else if divergentHistory {
      scope = String(rawScope.dropFirst("divergent:".count))
    } else {
      scope = rawScope
    }
    let protectsList = scope == "list" || scope == "listBulk"
    let protectsFirstBranch =
      scope == "expanded" || scope == "expandedBulk" || scope == "itineraryBulk"
    let wholeItinerary = scope == "itineraryBulk"
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("The single-member fixture action must save: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let firstAddition = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let secondAddition = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    let directAddition = try await save(
      .addItineraryEntry(
        itineraryId: itinerary.id, source: item, placement: .last))
    guard case .itineraryEntry(let firstEntry, _, _)? = firstAddition.generatedReferences.first,
      case .itineraryEntry(let secondEntry, _, _)? = secondAddition.generatedReferences.first,
      case .itineraryEntry(let directEntry, _, _)? = directAddition.generatedReferences.first
    else { throw CancellationError() }
    let originalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let originalLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000841")!
    let smallerIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000400")!
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [(originalIdentifier.uuidString, originalLifetime.uuidString, 1024, false)])
    try await insertIndependentExpandedCompletion(
      storeURL: configuration.storeURL, entryIdentifier: secondEntry,
      membershipIdentifier: originalIdentifier, membershipLifetime: originalLifetime)
    let selected: PlannerAppearance
    if scope == "direct" {
      selected = .directItineraryItem(itineraryId: itinerary.id, entryId: directEntry)
    } else if protectsFirstBranch {
      selected = .expandedListItem(
        itineraryId: itinerary.id, listEntryId: firstEntry,
        membershipId: originalIdentifier)
    } else {
      selected = .listMembership(listId: list.id, membershipId: originalIdentifier)
    }
    func completionOperation(done: Bool, operationIdentifier: UUID) async throws -> PlannerOperation
    {
      guard scope.hasSuffix("Bulk") else {
        return .init(
          operationId: operationIdentifier, session: session,
          command: .setCompletion(scope: .appearance(selected), done: done))
      }
      let bulkScope: PlannerBulkScope
      if wholeItinerary {
        bulkScope = .itinerary(itineraryId: itinerary.id)
      } else if protectsFirstBranch {
        bulkScope = .itineraryListEntry(itineraryId: itinerary.id, listEntryId: firstEntry)
      } else {
        bulkScope = .list(listId: list.id)
      }
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session, command: .setBulkCompletion(scope: bulkScope, done: done))
      else { throw CancellationError() }
      return .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken)
    }
    var completion = try await completionOperation(
      done: !firstAssertion, operationIdentifier: UUID())
    if preparationFails {
      guard case .exported(let unchanged) = await planner.exportData(session: session),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first
      else { throw CancellationError() }
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespace.namespaceId.uuidString)
      let beforeFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o500], ofItemAtPath: namespaceDirectory.path)
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
      }
      let failure = await planner.execute(completion)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
      guard case .rejected(let rejected) = failure.outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: completion.operationId),
        case .exported(let afterFailure) = await planner.exportData(session: session)
      else { throw CancellationError() }
      #expect(rejected.code == "persistenceFailure")
      #expect(afterFailure == unchanged)
      #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
      completion = try await completionOperation(
        done: !firstAssertion, operationIdentifier: completion.operationId)
    }
    guard case .exported(let beforeAssertion) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    let originalGraph = try #require(
      JSONSerialization.jsonObject(with: beforeAssertion) as? [String: Any])
    let reopening: PlannerOperation
    if firstAssertion {
      reopening = completion
    } else {
      guard case .applied(_, .complete) = await planner.execute(completion).outcome else {
        throw CancellationError()
      }
      reopening = try await completionOperation(done: false, operationIdentifier: UUID())
    }
    guard
      case .applied(let reopened, .complete(let checkpoint)) = await planner.execute(reopening)
        .outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let beforeGraph = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    if firstAssertion && !wholeItinerary {
      #expect((beforeGraph["sources"] as? NSArray) == (originalGraph["sources"] as? NSArray))
    }
    let changes = try #require(beforeGraph["completionChanges"] as? [[String: Any]])
    let expectedChangeCount: Int
    if firstAssertion {
      expectedChangeCount = wholeItinerary ? 3 : 1
    } else {
      expectedChangeCount = wholeItinerary ? 6 : 2
    }
    #expect(changes.count == expectedChangeCount)
    let aliases = try #require(beforeGraph["contextAliases"] as? [[String: Any]])
    #expect(aliases.count == (wholeItinerary ? 3 : 1))
    let initialValues = aliases.compactMap { $0["initialDone"] as? Bool }.sorted { !$0 && $1 }
    #expect(initialValues == (wholeItinerary ? [false, false, true] : [false]))
    if protectsList {
      #expect(aliases.first?["aliasId"] as? String == "C6D0BEC6-0730-8084-9E40-B273BA57B8A8")
    }
    let completing = changes.filter { $0["done"] as? Bool == true }
    let reopeningChanges = changes.filter { $0["done"] as? Bool == false }
    #expect(completing.count == (firstAssertion ? 0 : (wholeItinerary ? 3 : 1)))
    #expect(reopeningChanges.count == (wholeItinerary ? 3 : 1))
    for complete in completing {
      let completeIdentifier = try #require(complete["id"] as? String)
      let completeContext = try #require(complete["context"] as? [String: Any])
      let reopen = try #require(
        reopeningChanges.first {
          guard let context = $0["context"] as? [String: Any] else { return false }
          return NSDictionary(dictionary: completeContext).isEqual(to: context)
        })
      #expect(reopen["observedChangeIds"] as? [String] == [completeIdentifier])
    }
    if divergentHistory {
      try await overwriteNativeCompletionFlag(
        storeURL: configuration.storeURL, appearance: selected, done: true)
    }
    let fresh = Planner(configuration: configuration)
    let readiness = await fresh.bootstrap()
    guard case .ready(let freshSession) = readiness else {
      Issue.record("Explicit completion history must survive a delayed scalar flag: \(readiness)")
      return
    }
    let retainedExport = await fresh.exportData(session: freshSession)
    guard case .exported(let retained) = retainedExport else {
      Issue.record(
        "Delayed scalar flags must not invalidate saved completion history: \(retainedExport)")
      return
    }
    #expect(retained == before)
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [
        (smallerIdentifier.uuidString, "00000000-0000-4000-8000-000000000840", 2048, true)
      ])
    try await insertIndependentExpandedCompletion(
      storeURL: configuration.storeURL, entryIdentifier: firstEntry,
      membershipIdentifier: smallerIdentifier,
      membershipLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000840")!)
    let query = await fresh.query(
      .init(
        session: freshSession,
        request: .items(
          .init(scope: .list(list.id), completion: .all, archive: .all))))
    guard case .snapshot(let current) = query else {
      Issue.record("The first explicit reopen must survive late duplicate delivery: \(query)")
      return
    }
    #expect(
      current.rows == [
        .appearance(
          source: item,
          appearance: .listMembership(listId: list.id, membershipId: smallerIdentifier))
      ])
    for (appearance, expectedDone) in [
      (
        PlannerAppearance.listMembership(listId: list.id, membershipId: originalIdentifier),
        !protectsList
      ),
      (
        .expandedListItem(
          itineraryId: itinerary.id, listEntryId: firstEntry,
          membershipId: originalIdentifier), !protectsFirstBranch
      ),
      (
        .expandedListItem(
          itineraryId: itinerary.id, listEntryId: secondEntry,
          membershipId: originalIdentifier), !wholeItinerary
      ),
      (.directItineraryItem(itineraryId: itinerary.id, entryId: directEntry), false),
    ] {
      guard
        case .appearance(let read) = await fresh.read(
          session: freshSession, request: .appearance(appearance))
      else {
        throw CancellationError()
      }
      #expect(read.source == item && !read.globalDone)
      #expect(read.localDone == expectedDone && read.effectiveDone == expectedDone)
    }
    guard
      case .applied(let replayed, .complete(let replayCheckpoint)) = await fresh.execute(
        .init(operationId: reopening.operationId, session: freshSession, command: reopening.command)
      ).outcome,
      case .exported(let after) = await fresh.exportData(session: freshSession)
    else { throw CancellationError() }
    #expect(replayed == reopened && replayCheckpoint == checkpoint)
    let afterGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(
      (afterGraph["completionChanges"] as? NSArray)
        == (beforeGraph["completionChanges"] as? NSArray))
    #expect((afterGraph["sources"] as? NSArray) == (beforeGraph["sources"] as? NSArray))
    #expect(
      (afterGraph["itineraryEntries"] as? NSArray) == (beforeGraph["itineraryEntries"] as? NSArray))
  }

  @Test func aLaterSmallerCanonicalMembershipRetainsHistoryAndExactRepeatedScopes() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("The route fixture command must save: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(
        .createItem(
          content: .init(title: "Hotel", notes: "Shared source stays intact"))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let firstAddition = try await save(
      .addItineraryEntry(
        itineraryId: itinerary.id, source: list, placement: .last))
    let secondAddition = try await save(
      .addItineraryEntry(
        itineraryId: itinerary.id, source: list, placement: .last))
    let directAddition = try await save(
      .addItineraryEntry(
        itineraryId: itinerary.id, source: item, placement: .last))
    guard case .itineraryEntry(let firstEntry, _, _)? = firstAddition.generatedReferences.first,
      case .itineraryEntry(let secondEntry, _, _)? = secondAddition.generatedReferences.first,
      case .itineraryEntry(let directEntry, _, _)? = directAddition.generatedReferences.first
    else { throw CancellationError() }
    let originalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let losingIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!
    let smallerIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000400")!
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
    try await insertIndependentExpandedCompletion(
      storeURL: configuration.storeURL, entryIdentifier: firstEntry,
      membershipIdentifier: originalIdentifier,
      membershipLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000841")!)
    try await insertIndependentExpandedCompletion(
      storeURL: configuration.storeURL, entryIdentifier: secondEntry,
      membershipIdentifier: losingIdentifier,
      membershipLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000842")!)
    let reopening = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(
        scope: .appearance(
          .listMembership(listId: list.id, membershipId: losingIdentifier)), done: false))
    guard
      case .applied(let reopened, .complete(let reopenCheckpoint)) = await planner.execute(
        reopening
      ).outcome
    else {
      throw CancellationError()
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: firstEntry,
            membershipId: losingIdentifier)), done: false))
    guard case .exported(let before) = await planner.exportData(session: session),
      case .snapshot(let originalWindow) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))))
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [
        (smallerIdentifier.uuidString, "00000000-0000-4000-8000-000000000840", 4096, true)
      ])
    for entry in [firstEntry, secondEntry] {
      try await insertIndependentExpandedCompletion(
        storeURL: configuration.storeURL, entryIdentifier: entry,
        membershipIdentifier: smallerIdentifier,
        membershipLifetime: UUID(uuidString: "00000000-0000-4000-8000-000000000840")!)
    }
    let queryResult = await planner.query(
      .init(
        session: session,
        request: .items(
          .init(scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))
      ))
    guard case .snapshot(let current) = queryResult else {
      Issue.record(
        "A smaller eligible root must retain explicit and branch history: \(queryResult)")
      return
    }
    #expect(
      current.rows == [
        .appearance(
          source: item,
          appearance:
            .listMembership(listId: list.id, membershipId: smallerIdentifier))
      ])
    #expect(current.progress.first?.doneCount == 0 && current.progress.first?.totalCount == 1)
    for identifier in [smallerIdentifier, originalIdentifier, losingIdentifier] {
      for (appearance, expectedDone) in [
        (PlannerAppearance.listMembership(listId: list.id, membershipId: identifier), false),
        (
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: firstEntry, membershipId: identifier), false
        ),
        (
          .expandedListItem(
            itineraryId: itinerary.id, listEntryId: secondEntry, membershipId: identifier), true
        ),
      ] {
        let response = await planner.read(session: session, request: .appearance(appearance))
        guard case .appearance(let read) = response else {
          Issue.record("Every eligible original must retain its exact route scope: \(response)")
          return
        }
        #expect(read.source == item && !read.globalDone)
        #expect(read.localDone == expectedDone && read.effectiveDone == expectedDone)
      }
    }
    guard
      case .appearance(let direct) = await planner.read(
        session: session,
        request: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: directEntry))),
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: originalWindow.generation, offset: 0, limit: 1)
      ),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await planner.execute(
        reopening
      ).outcome,
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(!direct.localDone && !direct.effectiveDone && !direct.globalDone)
    #expect(stale.code == "staleSnapshot")
    #expect(replayed == reopened && replayCheckpoint == reopenCheckpoint)
    let beforeGraph = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let afterGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    for key in [
      "sources", "itineraryEntries", "deletionMarkers", "restorationFamilies", "completionChanges",
      "membershipRemovals",
    ] {
      #expect(
        (beforeGraph[key] as? NSArray) == (afterGraph[key] as? NSArray),
        "Root rotation preserves \(key).")
    }
    let members = try #require(afterGraph["memberships"] as? [[String: Any]])
    #expect(members.count == 1)
    #expect(members.first?["id"] as? String == smallerIdentifier.uuidString)
    #expect(members.first?["rank"] as? String == "4096")
    #expect(members.first?["localDone"] as? Bool == false)
    let beforeAliases = try #require(beforeGraph["contextAliases"] as? [[String: Any]])
    let afterAliases = try #require(afterGraph["contextAliases"] as? [[String: Any]])
    for original in beforeAliases {
      let identifier = try #require(original["aliasId"] as? String)
      let retained = try #require(afterAliases.first { $0["aliasId"] as? String == identifier })
      for key in ["context", "initialDone", "currentChangeId"] {
        #expect(
          NSDictionary(dictionary: [key: try #require(original[key])]).isEqual(
            to: [key: try #require(retained[key])]))
      }
      let canonical = try #require(retained["canonicalContext"] as? [String: Any])
      #expect(canonical["membershipId"] as? String == smallerIdentifier.uuidString)
      #expect(
        canonical["membershipLifetimeId"] as? String == "00000000-0000-4000-8000-000000000840")
    }
    let fresh = Planner(configuration: configuration)
    guard case .ready(let freshSession) = await fresh.bootstrap(),
      case .exported(let freshExport) = await fresh.exportData(session: freshSession)
    else { throw CancellationError() }
    #expect(freshExport == after)
  }

  @Test(arguments: ["missingMembershipHistory", "differentList"])
  func detachedCompletionsCannotBorrowAnUnknownLifetimeOrAnotherListsScope(scenario: String)
    async throws
  {
    let fixture = try await AssociationUndoFixture()
    let itinerary = try #require(
      try await fixture.save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let entrySource: PlannerEntityReference
    if scenario == "differentList" {
      entrySource = try #require(
        try await fixture.save(.createList(content: .init(name: "Other"))).generated.first)
    } else {
      entrySource = fixture.list
    }
    let addition = try await fixture.save(
      .addItineraryEntry(itineraryId: itinerary.id, source: entrySource, placement: .last))
    guard case .itineraryEntry(let entryIdentifier, _, _) = addition.generatedReferences.first,
      case .decoded(let original) = fixture.planner.decodeImport(try await fixture.export()),
      let originalMembership = original.backup.memberships.first
    else { throw CancellationError() }
    let removal = await fixture.remove()
    let undo = try #require(removal.associationUndoSnapshot)
    _ = try await fixture.save(.restoreAssociation(snapshot: undo))
    let deliveredLifetime: UUID
    if scenario == "missingMembershipHistory" {
      deliveredLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000849")!
    } else {
      deliveredLifetime = originalMembership.lifetimeId
    }
    guard
      case .listedNamespaces(let namespaces) = await fixture.planner.inspectRecovery(
        request: .namespaces), let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = fixture.configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let beforeFiles = try maintenanceNamespaceFiles(namespaceDirectory)
    try await insertDetachedExpandedCompletion(
      storeURL: fixture.configuration.storeURL, entryIdentifier: entryIdentifier,
      membershipIdentifier: originalMembership.id, membershipLifetime: deliveredLifetime)
    let response = await fixture.planner.query(
      .init(
        session: fixture.session,
        request: .items(.init(scope: .list(fixture.list.id), completion: .all, archive: .all))))
    guard case .failed(let failure) = response else {
      Issue.record("Unknown or cross-List completion inputs must not be discarded: \(response)")
      return
    }
    #expect(failure.code == "readUnavailable")
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .unavailable(let repeatedFailure) = await reopened.bootstrap() else {
      Issue.record("Unproven completion input must remain intact for reconciliation.")
      return
    }
    #expect(repeatedFailure.code == "readUnavailable")
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
  }

  @Test func unprovenCompetingMembershipLifetimesStayUnmodifiedAndUnavailable() async throws {
    let fixture = try await AssociationUndoFixture()
    guard
      case .listedNamespaces(let namespaces) = await fixture.planner.inspectRecovery(
        request: .namespaces), let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = fixture.configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let beforeFiles = try maintenanceNamespaceFiles(namespaceDirectory)
    try await insertIndependentMemberships(
      storeURL: fixture.configuration.storeURL, itemIdentifier: fixture.item.id,
      listIdentifier: fixture.list.id,
      contributions: [
        (
          fixture.membershipIdentifier.uuidString,
          "00000000-0000-4000-8000-000000000845", 1024, false
        )
      ])
    let response = await fixture.planner.query(
      .init(
        session: fixture.session,
        request: .items(.init(scope: .list(fixture.list.id), completion: .all, archive: .all))))
    guard case .failed(let failure) = response else {
      Issue.record(
        "A lifetime without closure/restoration proof must not replace current work: \(response)")
      return
    }
    #expect(failure.code == "readUnavailable")
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
    let reopened = Planner(configuration: fixture.configuration)
    let bootstrap = await reopened.bootstrap()
    guard case .unavailable(let repeatedFailure) = bootstrap else {
      Issue.record(
        "Unproven conflicting records must remain intact for reconciliation: \(bootstrap)")
      return
    }
    #expect(repeatedFailure.code == "readUnavailable")
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
  }

  @Test(arguments: [true, false], [false, true])
  func oldExpandedDeliveryKeepsRestoredRepeatedBranchesIndependent(
    includesMembership: Bool, preparationFails: Bool
  )
    async throws
  {
    let fixture = try await AssociationUndoFixture()
    let itinerary = try #require(
      try await fixture.save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let firstAddition = try await fixture.save(
      .addItineraryEntry(itineraryId: itinerary.id, source: fixture.list, placement: .last))
    let secondAddition = try await fixture.save(
      .addItineraryEntry(itineraryId: itinerary.id, source: fixture.list, placement: .last))
    guard case .itineraryEntry(let firstEntry, _, _) = firstAddition.generatedReferences.first,
      case .itineraryEntry(let secondEntry, _, _) = secondAddition.generatedReferences.first
    else { throw CancellationError() }
    let firstAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: firstEntry,
      membershipId: fixture.membershipIdentifier)
    let secondAppearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: secondEntry,
      membershipId: fixture.membershipIdentifier)
    _ = try await fixture.save(.setCompletion(scope: .appearance(firstAppearance), done: true))
    let originalData = try await fixture.export()
    guard case .decoded(let original) = fixture.planner.decodeImport(originalData),
      let originalMembership = original.backup.memberships.first
    else { throw CancellationError() }
    let removal = await fixture.remove()
    let undo = try #require(removal.associationUndoSnapshot)
    _ = try await fixture.save(.restoreAssociation(snapshot: undo))
    _ = try await fixture.save(
      .setCompletion(
        scope: .appearance(
          .listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier)),
        done: false))
    let beforeDelivery = try await fixture.export()
    guard case .decoded(let restored) = fixture.planner.decodeImport(beforeDelivery),
      let restoredMembership = restored.backup.memberships.first
    else { throw CancellationError() }
    #expect(restoredMembership.id == originalMembership.id)
    #expect(restoredMembership.lifetimeId != originalMembership.lifetimeId)
    if includesMembership {
      try await insertIndependentMemberships(
        storeURL: fixture.configuration.storeURL, itemIdentifier: fixture.item.id,
        listIdentifier: fixture.list.id,
        contributions: [
          (
            originalMembership.id.uuidString, originalMembership.lifetimeId.uuidString,
            originalMembership.rank, true
          )
        ])
      try await insertIndependentExpandedCompletion(
        storeURL: fixture.configuration.storeURL, entryIdentifier: firstEntry,
        membershipIdentifier: originalMembership.id,
        membershipLifetime: originalMembership.lifetimeId
      )
      try await insertIndependentExpandedCompletion(
        storeURL: fixture.configuration.storeURL, entryIdentifier: secondEntry,
        membershipIdentifier: originalMembership.id,
        membershipLifetime: originalMembership.lifetimeId
      )
    } else {
      try await insertDetachedExpandedCompletion(
        storeURL: fixture.configuration.storeURL, entryIdentifier: firstEntry,
        membershipIdentifier: originalMembership.id,
        membershipLifetime: originalMembership.lifetimeId)
      try await insertDetachedExpandedCompletion(
        storeURL: fixture.configuration.storeURL, entryIdentifier: secondEntry,
        membershipIdentifier: originalMembership.id,
        membershipLifetime: originalMembership.lifetimeId)
    }
    if preparationFails {
      guard
        case .listedNamespaces(let namespaces) = await fixture.planner.inspectRecovery(
          request: .namespaces), let namespace = namespaces.first
      else { throw CancellationError() }
      let namespaceDirectory = fixture.configuration.recoveryDirectoryURL.appendingPathComponent(
        namespace.namespaceId.uuidString)
      let beforeFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o500], ofItemAtPath: namespaceDirectory.path)
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
      }
      let failedQuery = await fixture.planner.query(
        .init(
          session: fixture.session,
          request: .items(.init(scope: .list(fixture.list.id), completion: .all, archive: .all))))
      guard case .failed(let failure) = failedQuery,
        case .status(let status) = await fixture.planner.read(
          session: fixture.session, request: .status),
        case .unavailable(let reason) = status.recovery
      else {
        Issue.record("Failed preparation must retain unresolved native inputs: \(failedQuery)")
        return
      }
      #expect(failure.code == "maintenanceRequired" && reason.code == "maintenanceRequired")
      #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeFiles)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
    }
    let result = await fixture.planner.query(
      .init(
        session: fixture.session,
        request: .items(.init(scope: .list(fixture.list.id), completion: .all, archive: .all))))
    guard case .snapshot(let contents) = result,
      case .appearance(let first) = await fixture.planner.read(
        session: fixture.session, request: .appearance(firstAppearance)),
      case .appearance(let second) = await fixture.planner.read(
        session: fixture.session, request: .appearance(secondAppearance)),
      case .appearance(let standalone) = await fixture.planner.read(
        session: fixture.session,
        request: .appearance(
          .listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier)))
    else {
      Issue.record("Closed expanded copies cannot block independent restored branches: \(result)")
      return
    }
    #expect(contents.matchingCount == 1)
    #expect(first.localDone && first.effectiveDone)
    #expect(!second.localDone && !second.effectiveDone)
    #expect(!standalone.localDone && !standalone.effectiveDone)
    let afterDelivery = try await fixture.export()
    let beforeGraph = try #require(
      JSONSerialization.jsonObject(with: beforeDelivery) as? [String: Any])
    let afterGraph = try #require(
      JSONSerialization.jsonObject(with: afterDelivery) as? [String: Any])
    for key in [
      "sources", "memberships", "itineraryEntries", "expandedCompletions", "deletionMarkers",
      "completionChanges", "restorationFamilies", "membershipProvenance", "membershipRemovals",
    ] {
      #expect(
        (beforeGraph[key] as? NSArray) == (afterGraph[key] as? NSArray),
        "Old branch delivery must preserve \(key).")
    }
    let beforeAliases = try #require(beforeGraph["contextAliases"] as? [[String: Any]])
    let afterAliases = try #require(afterGraph["contextAliases"] as? [[String: Any]])
    #expect(
      beforeAliases.allSatisfy { original in
        afterAliases.contains { NSDictionary(dictionary: $0).isEqual(to: original) }
      })
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .exported(let afterReopen) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    #expect(afterReopen == afterDelivery)
  }

  @Test func anOldDeliveredLifetimeCannotBlockOrCompleteTheSamePublicMembershipAfterUndo()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Keep this shared Item")))
      ).outcome,
      let item = itemCreation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listCreation.generated.first
    else { throw CancellationError() }
    let membershipIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let originalLifetime = UUID(uuidString: "00000000-0000-4000-8000-000000000841")!
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [(membershipIdentifier.uuidString, originalLifetime.uuidString, 1024, false)])
    let removal = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .removeMembership(listId: list.id, membershipId: membershipIdentifier)))
    guard case .applied(_, .complete) = removal.outcome,
      let undo = removal.associationUndoSnapshot,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .restoreAssociation(snapshot: undo))
      ).outcome,
      case .exported(let beforeDelivery) = await planner.exportData(session: session),
      case .decoded(let beforeBackup) = planner.decodeImport(beforeDelivery),
      let restoredMembership = beforeBackup.backup.memberships.first
    else { throw CancellationError() }
    #expect(restoredMembership.id == membershipIdentifier)
    #expect(restoredMembership.lifetimeId != originalLifetime && !restoredMembership.localDone)
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [(membershipIdentifier.uuidString, originalLifetime.uuidString, 1024, true)])
    let result = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .all, archive: .all))))
    guard case .snapshot(let contents) = result,
      case .appearance(let appearance) = await planner.read(
        session: session,
        request: .appearance(
          .listMembership(listId: list.id, membershipId: membershipIdentifier))),
      case .exported(let afterDelivery) = await planner.exportData(session: session),
      case .decoded(let afterBackup) = planner.decodeImport(afterDelivery)
    else {
      Issue.record("A closed old lifetime cannot block the restored public membership: \(result)")
      return
    }
    #expect(contents.matchingCount == 1)
    #expect(
      contents.rows == [
        .appearance(
          source: item,
          appearance: .listMembership(listId: list.id, membershipId: membershipIdentifier))
      ])
    #expect(!appearance.localDone && !appearance.effectiveDone)
    #expect(afterBackup.backup.memberships == [restoredMembership])
    #expect(afterBackup.backup.membershipProvenance == beforeBackup.backup.membershipProvenance)
    #expect(afterBackup.backup.membershipRemovals == beforeBackup.backup.membershipRemovals)
    let beforeGraph = try #require(
      JSONSerialization.jsonObject(with: beforeDelivery) as? [String: Any])
    let afterGraph = try #require(
      JSONSerialization.jsonObject(with: afterDelivery) as? [String: Any])
    for key in [
      "sources", "deletionMarkers", "expandedCompletions", "restorationFamilies",
      "completionChanges",
    ] {
      #expect(
        (beforeGraph[key] as? NSArray) == (afterGraph[key] as? NSArray),
        "Late delivery must preserve \(key).")
    }
    let beforeAliases = try #require(beforeGraph["contextAliases"] as? [[String: Any]])
    let afterAliases = try #require(afterGraph["contextAliases"] as? [[String: Any]])
    #expect(
      beforeAliases.allSatisfy { original in
        afterAliases.contains { NSDictionary(dictionary: $0).isEqual(to: original) }
      })
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let afterReopen) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(afterReopen == afterDelivery)
    var invalidGraph = afterGraph
    var invalidMembers = try #require(invalidGraph["memberships"] as? [[String: Any]])
    invalidMembers[0]["lifetimeId"] = originalLifetime.uuidString
    invalidGraph["memberships"] = invalidMembers
    invalidGraph["formatVersion"] = 2
    invalidGraph.removeValue(forKey: "membershipProvenance")
    invalidGraph.removeValue(forKey: "membershipRemovals")
    for key in ["restorationFamilies", "contextAliases", "completionChanges"] {
      invalidGraph[key] = [Any]()
    }
    let invalidData = try JSONSerialization.data(withJSONObject: invalidGraph, options: .sortedKeys)
    guard case .invalid(let importFailure) = planner.decodeImport(invalidData) else {
      Issue.record("A portable backup must reject an explicitly closed membership lifetime.")
      return
    }
    #expect(importFailure.code == "invalidInput")
    #expect(importFailure.propertyPath == "/memberships/0/lifetimeId")
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let generation = namespace.acknowledgedSnapshot?.checkpointGeneration
    else { throw CancellationError() }
    let checkpointURL = configuration.recoveryDirectoryURL
      .appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-\(generation).json")
    let originalCheckpoint = try Data(contentsOf: checkpointURL)
    defer { try? originalCheckpoint.write(to: checkpointURL, options: .atomic) }
    var envelope = try #require(
      JSONSerialization.jsonObject(with: originalCheckpoint) as? [String: Any])
    envelope["portablePayloadBase64"] = invalidData.base64EncodedString()
    envelope["dataDigest"] =
      "sha256:" + SHA256.hash(data: invalidData).map { String(format: "%02x", $0) }.joined()
    try JSONSerialization.data(withJSONObject: envelope).write(to: checkpointURL, options: .atomic)
    let inspected = await planner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: namespace.namespaceId, checkpointGeneration: generation))
    guard case .failed(let recoveryFailure) = inspected else {
      Issue.record(
        "Recovery must reject the closed native record despite a matching checksum: \(inspected)")
      return
    }
    #expect(recoveryFailure.code == "recoveryIntegrityFailure")
    #expect(recoveryFailure.propertyPath == "/memberships/0/lifetimeId")
    try originalCheckpoint.write(to: checkpointURL, options: .atomic)
    guard case .exported(let afterInvalidReads) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterInvalidReads == afterDelivery)
  }

  @Test(arguments: [false, true])
  func reviewedOverwriteRemovalDefeatsAnUnseenAddWithoutDeletingItsItem(incomingClosure: Bool)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum", notes: "Keep this shared Item")))
      ).outcome,
      let item = itemCreation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let list = listCreation.generated.first,
      case .exported(let emptyListData) = await planner.exportData(session: session),
      case .decoded(let emptyList) = planner.decodeImport(emptyListData),
      case .applied(let addition, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let originalIdentifier, _, _) = addition.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(
              .listMembership(listId: list.id, membershipId: originalIdentifier)), done: true))
      ).outcome,
      case .source(.item(let beforeItem)) = await planner.read(
        session: session, request: .source(item)),
      case .exported(let currentData) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(currentData),
      let originalMember = current.backup.memberships.first(where: { $0.id == originalIdentifier })
    else { throw CancellationError() }
    let foreignDeletionIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000918")!
    var incoming = emptyList
    if incomingClosure {
      var graph = try #require(JSONSerialization.jsonObject(with: emptyListData) as? [String: Any])
      graph["deletionMarkers"] = [
        [
          "deletionId": foreignDeletionIdentifier.uuidString,
          "operationId": "00000000-0000-4000-8000-000000000919",
          "target": [
            "kind": "membership", "id": originalIdentifier.uuidString,
            "lifetimeId": originalMember.lifetimeId.uuidString,
          ],
          "closedFamilyId": NSNull(),
        ]
      ]
      let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
      guard case .decoded(let backup) = decoded else {
        Issue.record(
          "An old marker without a strict declaration is a valid legacy closure: \(decoded)")
        return
      }
      incoming = backup
    }
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: incoming, mode: .overwrite))
    else { throw CancellationError() }
    let overwriteIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: overwriteIdentifier, session: session,
        command: review.command, reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = response.outcome,
      case .exported(let removedData) = await planner.exportData(session: session),
      case .decoded(let removed) = planner.decodeImport(removedData)
    else {
      Issue.record("The reviewed empty contents must remove the current membership: \(response)")
      return
    }
    #expect(removed.backup.memberships.isEmpty)
    #expect(removed.backup.membershipRemovals.count == 1)
    #expect(
      removed.backup.membershipProvenance.contains { binding in
        binding.membershipId == originalIdentifier && binding.list.reference == list
          && binding.item.reference == item && binding.observedRemovalIds.isEmpty
      })
    let localMarker = removed.backup.deletionMarkers.first { $0.operationId == overwriteIdentifier }
    #expect(localMarker != nil)
    #expect(removed.backup.membershipRemovals.first?.deletionId == localMarker?.deletionId)
    if incomingClosure {
      #expect(
        removed.backup.deletionMarkers.contains { $0.deletionId == foreignDeletionIdentifier })
      #expect(
        removed.backup.membershipRemovals.allSatisfy { $0.deletionId != foreignDeletionIdentifier })
    }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL,
      itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [
        (
          "00000000-0000-4000-8000-000000000403",
          "00000000-0000-4000-8000-000000000843", 3072, true
        )
      ])
    let contentsResult = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .all, archive: .all))))
    guard case .snapshot(let contents) = contentsResult,
      case .snapshot(let inbox) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .inbox, completion: .all, archive: .all)))),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("An unseen Add must remain suppressed after Overwrite: \(contentsResult)")
      return
    }
    #expect(contents.matchingCount == 0 && inbox.matchingCount == 1)
    #expect(
      retainedItem.updatedAt == beforeItem.updatedAt
        && retainedItem.fieldHashes == beforeItem.fieldHashes)
    #expect(
      retainedItem.content.notes == "Keep this shared Item"
        && retainedItem.state.globalDone == false)
    if contents.matchingCount != 0 { return }
    guard
      case .applied(let readdition, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let readdedIdentifier, _, _) = readdition.generatedReferences.first,
      case .appearance(let readded) = await planner.read(
        session: session,
        request: .appearance(.listMembership(listId: list.id, membershipId: readdedIdentifier))),
      case .exported(let readdedData) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(readdedData)
    else { throw CancellationError() }
    #expect(readdedIdentifier != originalIdentifier && readded.localDone == false)
    let observed = saved.backup.membershipProvenance.first { $0.membershipId == readdedIdentifier }
    #expect(observed?.observedRemovalIds == removed.backup.membershipRemovals.map(\.deletionId))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == readdedData)
  }

  @Test(arguments: [false, true])
  func anAddMissingASecondRemovalStaysSuppressedWithoutContaminatingAnInformedReadd(
    withRepeatedListEntries: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum", notes: "Keep shared content")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let listResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listResult.generated.first
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
    var itinerary: PlannerEntityReference?
    var entryIdentifiers: [UUID] = []
    if withRepeatedListEntries {
      guard
        case .applied(let created, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItinerary(content: .init(title: "Repeated route")))
        ).outcome, let route = created.generated.first
      else { throw CancellationError() }
      itinerary = route
      for _ in 0..<2 {
        guard
          case .applied(let entry, .complete) = await planner.execute(
            .init(
              operationId: UUID(), session: session,
              command: .addItineraryEntry(itineraryId: route.id, source: list, placement: .last))
          ).outcome, case .itineraryEntry(let identifier, _, _) = entry.generatedReferences.first
        else { throw CancellationError() }
        entryIdentifiers.append(identifier)
      }
    }
    let originalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    guard
      case .snapshot = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(list.id), completion: .all, archive: .all)))),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: originalIdentifier))
      ).outcome,
      case .applied(let partialAddition, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let partialIdentifier, _, _) = partialAddition.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(
              .listMembership(listId: list.id, membershipId: partialIdentifier)), done: true))
      ).outcome
    else { throw CancellationError() }
    if let itinerary {
      guard
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .setCompletion(
              scope: .appearance(
                .expandedListItem(
                  itineraryId: itinerary.id, listEntryId: entryIdentifiers[0],
                  membershipId: partialIdentifier)), done: true))
        ).outcome
      else { throw CancellationError() }
    }
    guard case .exported(let beforeArrival) = await planner.exportData(session: session),
      case .decoded(let before) = planner.decodeImport(beforeArrival),
      let partial = before.backup.membershipProvenance.first(where: {
        $0.membershipId == partialIdentifier
      })
    else { throw CancellationError() }
    let beforeGraph = try #require(
      JSONSerialization.jsonObject(with: beforeArrival) as? NSDictionary)
    #expect(partial.observedRemovalIds.count == 1)
    let secondRemovalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000892")!
    try await insertSecondIndependentRemoval(
      storeURL: configuration.storeURL, deletionIdentifier: secondRemovalIdentifier)
    let result = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .all, archive: .all))))
    guard case .snapshot(let suppressed) = result,
      case .exported(let suppressedData) = await planner.exportData(session: session),
      case .decoded(let suppressedBackup) = planner.decodeImport(suppressedData)
    else {
      Issue.record("The unseen second removal must suppress the partially informed Add: \(result)")
      return
    }
    let suppressedGraph = try #require(
      JSONSerialization.jsonObject(with: suppressedData) as? NSDictionary)
    #expect(suppressed.matchingCount == 0)
    #expect(suppressedBackup.backup.memberships.isEmpty)
    #expect(suppressedBackup.backup.expandedCompletions.isEmpty)
    for entryIdentifier in entryIdentifiers {
      #expect(
        suppressedBackup.backup.contextAliases.contains { alias in
          if case .expandedListItem(let context) = alias.context {
            return context.listEntryId == entryIdentifier
              && context.membershipId == partialIdentifier
              && alias.canonicalContext == alias.context
          }
          return false
        })
    }
    #expect((suppressedGraph["sources"] as? NSArray) == (beforeGraph["sources"] as? NSArray))
    #expect(
      (suppressedGraph["completionChanges"] as? NSArray)
        == (beforeGraph["completionChanges"] as? NSArray))
    #expect(suppressedBackup.backup.membershipProvenance.contains(partial))
    #expect(suppressedBackup.backup.membershipRemovals.count == 2)
    #expect(
      suppressedBackup.backup.deletionMarkers.count == before.backup.deletionMarkers.count + 1)
    #expect(
      suppressedBackup.backup.contextAliases.contains { alias in
        alias.context
          == .listMembership(
            membershipId: partialIdentifier, membershipLifetimeId: partial.membershipLifetimeId)
          && alias.canonicalContext == alias.context
      })
    var unprovenGraph = try #require(
      JSONSerialization.jsonObject(with: suppressedData) as? [String: Any])
    let unprovenMarkers = try #require(unprovenGraph["deletionMarkers"] as? [[String: Any]])
    let unprovenRemovals = try #require(unprovenGraph["membershipRemovals"] as? [[String: Any]])
    unprovenGraph["deletionMarkers"] = unprovenMarkers.filter {
      $0["deletionId"] as? String != secondRemovalIdentifier.uuidString
    }
    unprovenGraph["membershipRemovals"] = unprovenRemovals.filter {
      $0["deletionId"] as? String != secondRemovalIdentifier.uuidString
    }
    guard
      case .invalid(let missingAuthority) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: unprovenGraph))
    else {
      Issue.record("Retained provenance alone must not authorize an absent canonical membership.")
      return
    }
    #expect(missingAuthority.code == "invalidInput")
    #expect(missingAuthority.propertyPath?.hasSuffix("/canonicalContext/membershipId") == true)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let informedAddition, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let informedIdentifier, _, _) = informedAddition.generatedReferences.first,
      case .snapshot(let todo) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(.init(scope: .list(list.id), completion: .todo, archive: .all)))),
      case .snapshot(let done) = await reopened.query(
        .init(
          session: reopenedSession,
          request: .items(.init(scope: .list(list.id), completion: .done, archive: .all)))),
      case .exported(let informedData) = await reopened.exportData(session: reopenedSession),
      case .decoded(let informed) = reopened.decodeImport(informedData),
      let informedProvenance = informed.backup.membershipProvenance.first(where: {
        $0.membershipId == informedIdentifier
      })
    else { throw CancellationError() }
    #expect(reopenedData == suppressedData)
    #expect(todo.matchingCount == 1 && done.matchingCount == 0)
    #expect(informedIdentifier != partialIdentifier)
    #expect(
      Set(informedProvenance.observedRemovalIds)
        == Set([
          partial.observedRemovalIds[0], secondRemovalIdentifier,
        ]))
    if let itinerary {
      for entryIdentifier in entryIdentifiers {
        guard
          case .appearance(let appearance) = await reopened.read(
            session: reopenedSession,
            request: .appearance(
              .expandedListItem(
                itineraryId: itinerary.id, listEntryId: entryIdentifier,
                membershipId: informedIdentifier)))
        else { throw CancellationError() }
        #expect(appearance.localDone == false && appearance.effectiveDone == false)
      }
    }
    let staleAppearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: partialIdentifier)
    guard
      case .failed(let missingAppearance) = await reopened.read(
        session: reopenedSession, request: .appearance(staleAppearance)),
      case .rejected(let missingAction) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .setCompletion(scope: .appearance(staleAppearance), done: true))
      ).outcome,
      case .exported(let afterRejectedAction) = await reopened.exportData(session: reopenedSession)
    else {
      Issue.record("A suppressed context must never target a later informed membership.")
      return
    }
    #expect(missingAppearance.code == "missingReference")
    #expect(missingAction.code == "missingReference")
    #expect(afterRejectedAction == informedData)
    let targetDirectory = try makePlannerStoreFixtureDirectory()
    let target = Planner(
      configuration: .init(
        storeURL: targetDirectory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: targetDirectory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: targetDirectory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let targetSession) = await target.bootstrap(),
      case .decoded(let imported) = target.decodeImport(informedData)
    else { throw CancellationError() }
    let targetReview = await target.prepareReview(
      session: targetSession, command: .applyImport(backup: imported, mode: .overwrite))
    guard case .reviewed(let review) = targetReview else {
      Issue.record("A valid suppressed context must survive empty-dataset review: \(targetReview)")
      return
    }
    let targetResult = await target.execute(
      .init(
        operationId: UUID(), session: targetSession, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = targetResult.outcome else {
      Issue.record("Reviewed suppressed history must round-trip intact: \(targetResult)")
      return
    }
    guard case .exported(let roundTripped) = await target.exportData(session: targetSession)
    else { throw CancellationError() }
    #expect(roundTripped == informedData)
    let informedGraph = try #require(
      JSONSerialization.jsonObject(with: informedData) as? NSDictionary)
    #expect(
      (informedGraph["completionChanges"] as? NSArray)
        == (beforeGraph["completionChanges"] as? NSArray))
  }

  @Test func aSoleUnawareOfflineMembershipStaysRemovedWithoutDiscardingItsItem() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum", notes: "Keep this Item")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let listResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listResult.generated.first,
      case .applied(let addition, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipIdentifier, _, _) = addition.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: membershipIdentifier))
      ).outcome
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [
        ("00000000-0000-4000-8000-000000000403", "00000000-0000-4000-8000-000000000843", 1024, true)
      ])
    let contentsResult = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .all, archive: .all))))
    guard case .snapshot(let contents) = contentsResult,
      case .snapshot(let inbox) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .inbox, completion: .all, archive: .all)))),
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .exported(let beforeRepeat) = await planner.exportData(session: session),
      case .listedNamespaces(let originalNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("A strict Remove must suppress even a sole unseen Add: \(contentsResult)")
      return
    }
    #expect(contents.matchingCount == 0)
    #expect(inbox.matchingCount == 1)
    #expect(retained.content.notes == "Keep this Item" && retained.state.globalDone == false)
    guard
      case .snapshot(let repeated) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(list.id), completion: .all, archive: .all)))),
      case .exported(let afterRepeat) = await planner.exportData(session: session),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else { throw CancellationError() }
    #expect(repeated.matchingCount == 0 && afterRepeat == beforeRepeat)
    #expect(
      afterNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration
        == originalNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration)
  }

  @Test func ordinaryReaddDoesNotInheritAClosedCanonicalGroupsCompletion() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let listResult, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listResult.generated.first
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
    guard
      case .snapshot(let completed) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(list.id), completion: .done, archive: .all)))),
      case .appearance(_, .listMembership(_, let canonicalIdentifier))? = completed.rows.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: canonicalIdentifier))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome
    else { throw CancellationError() }
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
      contributions: [
        (
          "00000000-0000-4000-8000-000000000403", "00000000-0000-4000-8000-000000000843", 3072,
          false
        )
      ])
    let todoResult = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .todo, archive: .all))))
    let doneResult = await planner.query(
      .init(
        session: session,
        request: .items(.init(scope: .list(list.id), completion: .done, archive: .all))))
    let exportResult = await planner.exportData(session: session)
    guard case .snapshot(let todo) = todoResult, case .snapshot(let done) = doneResult,
      case .exported(let data) = exportResult
    else {
      Issue.record(
        "Late membership reads must retain the informed re-add: \(todoResult), \(doneResult), \(exportResult)"
      )
      return
    }
    #expect(todo.matchingCount == 1)
    #expect(done.matchingCount == 0)
    let graph = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let members = try #require(graph["memberships"] as? [[String: Any]])
    #expect(members.count == 1 && members.first?["localDone"] as? Bool == false)
    let aliases = try #require(graph["contextAliases"] as? [[String: Any]])
    let originalIdentifiers = [
      "00000000-0000-4000-8000-000000000401", "00000000-0000-4000-8000-000000000402",
    ]
    let oldHistory = aliases.filter { value in
      guard let context = value["context"] as? [String: Any],
        let identifier = context["membershipId"] as? String
      else { return false }
      return originalIdentifiers.contains(identifier)
    }
    #expect(oldHistory.count == 2)
    #expect(
      oldHistory.allSatisfy {
        ($0["canonicalContext"] as? [String: Any])?["membershipId"] as? String
          == "00000000-0000-4000-8000-000000000401"
      })
    #expect((graph["completionChanges"] as? [Any])?.isEmpty == true)
  }

  @Test func committedMaintenanceBlocksNewCommandsUntilItsOwnRecoveryRetryCompletes() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdItem, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(let createdList, .complete(let initialCheckpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = createdList.generated.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let originalFiles = try maintenanceNamespaceFiles(namespaceDirectory)
    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) {
      notification in obstruction.observe(notification)
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
    }
    let waitingOperationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: waitingOperationIdentifier, session: session,
        command: .createTag(content: .init(name: "Must wait"))))
    guard case .rejected = response.outcome else {
      Issue.record(
        "The waiting command must remain unapplied after maintenance recovery fails: \(response)")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    guard
      case .snapshot(let readable) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(list.id), completion: .done, archive: .all)))),
      case .exported(let committedData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(readable.matchingCount == 1)
    try obstruction.restore()
    let preparationFiles = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasPrefix("maintenance-") }
    #expect(preparationFiles.count == 1)
    let preparationFile = try #require(preparationFiles.first)
    let preparation = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: preparationFile)) as? [String: Any])
    let maintenanceIdentifier = try #require(
      (preparation["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: waitingOperationIdentifier),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: maintenanceIdentifier),
      case .listed(let pendingView) = await planner.inspectRecovery(
        request: .namespace(namespaceId: namespace.namespaceId))
    else { throw CancellationError() }
    #expect(pendingView.acknowledgedSnapshot?.checkpointGeneration == initialCheckpoint)
    let status = await planner.read(session: session, request: .status)
    guard case .status(let pendingStatus) = status,
      case .known(
        let pendingCheckpoint, let incompleteOperations, let incompleteMaintenance,
        let mutationBlocked) =
        pendingStatus.recovery
    else {
      Issue.record(
        "Verified committed maintenance must have a known, blocked recovery status: \(status)")
      return
    }
    #expect(
      pendingCheckpoint == initialCheckpoint && incompleteOperations.isEmpty && mutationBlocked)
    #expect(incompleteMaintenance == [maintenanceIdentifier])
    let blocked = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .createTag(content: .init(name: "Still waiting"))))
    guard case .rejected(let blockedReason) = blocked.outcome else {
      Issue.record("Pending maintenance must block a new ordinary command: \(blocked)")
      return
    }
    #expect(blockedReason.code == "mutationBlocked")
    let beforeRetry = try maintenanceNamespaceFiles(namespaceDirectory)
    for (name, bytes) in originalFiles { #expect(beforeRetry[name] == bytes) }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: namespaceDirectory.path)
    let continued = await planner.retryMaintenanceRecovery(
      session: session, maintenanceId: maintenanceIdentifier)
    guard case .incomplete(let reason) = continued else {
      Issue.record(
        "A verified native commit must remain incomplete when publication still fails: \(continued)"
      )
      return
    }
    #expect(!reason.message.isEmpty)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeRetry)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: namespaceDirectory.path)
    guard
      case .complete(let checkpoint) = await planner.retryMaintenanceRecovery(
        session: session, maintenanceId: maintenanceIdentifier),
      case .exported(let recoveredData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(checkpoint == initialCheckpoint + 1)
    #expect(recoveredData == committedData)
    let acknowledgedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
    guard
      case .complete(let repeatedCheckpoint) = await planner.retryMaintenanceRecovery(
        session: session, maintenanceId: maintenanceIdentifier)
    else { throw CancellationError() }
    #expect(repeatedCheckpoint == checkpoint)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == acknowledgedFiles)
    let saved = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .createTag(content: .init(name: "After recovery"))))
    guard case .applied(_, .complete(let nextCheckpoint)) = saved.outcome,
      case .exported(let finalData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(nextCheckpoint == checkpoint + 1)
    let finalGraph = try #require(JSONSerialization.jsonObject(with: finalData) as? [String: Any])
    let finalSources = try #require(finalGraph["sources"] as? [[String: Any]])
    let tags = finalSources.filter { $0["kind"] as? String == "tag" }
    #expect(tags.count == 1)
    #expect((tags.first?["content"] as? [String: Any])?["name"] as? String == "After recovery")
  }

  @Test func independentNativeMembershipsReadAsOneDoneContextWithoutCompletingTheirItem()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let itemOperationIdentifier = UUID()
    let listOperationIdentifier = UUID()
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdItem, .complete(let itemCheckpoint)) = await planner.execute(
        .init(
          operationId: itemOperationIdentifier, session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(let createdList, .complete(let listCheckpoint)) = await planner.execute(
        .init(
          operationId: listOperationIdentifier, session: session,
          command: .createList(content: .init(name: "Tokyo")))
      ).outcome,
      let list = createdList.generated.first,
      case .exported(let originalData) = await planner.exportData(session: session)
    else { throw CancellationError() }

    try await insertIndependentMemberships(
      storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)

    guard
      case .listedNamespaces(let beforeNamespaces) = await planner.inspectRecovery(
        request: .namespaces), let beforeNamespace = beforeNamespaces.first
    else { throw CancellationError() }
    let beforeDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      beforeNamespace.namespaceId.uuidString)
    let beforeStatusFiles = try maintenanceNamespaceFiles(beforeDirectory)
    let requiredStatus = await planner.read(session: session, request: .status)
    if case .status(let status) = requiredStatus, case .unavailable(let reason) = status.recovery {
      #expect(reason.code == "maintenanceRequired")
    } else {
      Issue.record(
        "Uncommitted consolidation must be reported without normalizing: \(requiredStatus)")
    }
    #expect(try maintenanceNamespaceFiles(beforeDirectory) == beforeStatusFiles)

    let reopened = Planner(configuration: configuration)
    let bootstrap = await reopened.bootstrap()
    guard case .ready(let reopenedSession) = bootstrap else {
      Issue.record("Native relationship delivery must retain a readable dataset: \(bootstrap)")
      return
    }
    let result = await reopened.query(
      .init(
        session: reopenedSession,
        request: .items(.init(scope: .list(list.id), completion: .done, archive: .all))))
    guard case .snapshot(let snapshot) = result else {
      Issue.record("Independent Todo/Done memberships must resolve to one Done context: \(result)")
      return
    }
    #expect(snapshot.matchingCount == 1)
    #expect(
      snapshot.rows == [
        .appearance(
          source: item,
          appearance: .listMembership(
            listId: list.id,
            membershipId: UUID(uuidString: "00000000-0000-4000-8000-000000000401")!))
      ])
    guard
      case .source(.item(let read)) = await reopened.read(
        session: reopenedSession, request: .source(item))
    else { throw CancellationError() }
    #expect(read.state.globalDone == false)
    guard case .exported(let data) = await reopened.exportData(session: reopenedSession),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(checkpoint == listCheckpoint + 1)
    let actual = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var expected = try #require(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let sources = try #require(expected["sources"] as? [[String: Any]])
    let originalItem = try #require(sources.first { $0["id"] as? String == item.id.uuidString })
    let originalList = try #require(sources.first { $0["id"] as? String == list.id.uuidString })
    let itemBinding: [String: Any] = [
      "kind": "item", "id": item.id.uuidString,
      "lifetimeId": try #require(originalItem["lifetimeId"]),
    ]
    let listBinding: [String: Any] = [
      "kind": "list", "id": list.id.uuidString,
      "lifetimeId": try #require(originalList["lifetimeId"]),
    ]
    let canonical: [String: Any] = [
      "kind": "listMembership", "membershipId": "00000000-0000-4000-8000-000000000401",
      "membershipLifetimeId": "00000000-0000-4000-8000-000000000841",
    ]
    expected["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000401",
        "lifetimeId": "00000000-0000-4000-8000-000000000841",
        "list": listBinding, "item": itemBinding, "rank": "1024", "localDone": true,
      ]
    ]
    let seeds = try initialCompletionSeedFixtures()
    expected["contextAliases"] = try seeds.map { seed -> [String: Any] in
      [
        "aliasId": try #require(seed["aliasId"]), "context": try #require(seed["context"]),
        "canonicalContext": canonical, "initialDone": try #require(seed["initialDone"]),
        "currentChangeId": NSNull(),
      ]
    }.sorted { ($0["aliasId"] as? String ?? "") < ($1["aliasId"] as? String ?? "") }
    expected["membershipProvenance"] = [
      [
        "membershipId": "00000000-0000-4000-8000-000000000401",
        "membershipLifetimeId": "00000000-0000-4000-8000-000000000841",
        "list": listBinding, "item": itemBinding, "observedRemovalIds": [],
      ],
      [
        "membershipId": "00000000-0000-4000-8000-000000000402",
        "membershipLifetimeId": "00000000-0000-4000-8000-000000000842",
        "list": listBinding, "item": itemBinding, "observedRemovalIds": [],
      ],
    ]
    #expect(NSDictionary(dictionary: expected).isEqual(to: actual))
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: recoveredGraph))
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let envelope = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(checkpoint).json")))
        as? [String: Any])
    #expect(envelope["formatVersion"] as? Int == 2)
    let maintenanceReceipts = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(maintenanceReceipts.count == 1)
    let maintenance = try #require(maintenanceReceipts.first)
    let maintenanceIdentifier = try #require(
      (maintenance["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
    #expect(
      maintenanceIdentifier != itemOperationIdentifier
        && maintenanceIdentifier != listOperationIdentifier)
    #expect(maintenance["checkpointGeneration"] as? String == String(checkpoint))
    let commandReceipts = try #require(envelope["receipts"] as? [[String: Any]])
    #expect(
      Set(commandReceipts.compactMap { $0["operationId"] as? String }) == [
        itemOperationIdentifier.uuidString, listOperationIdentifier.uuidString,
      ])
    let preparationData = try Data(
      contentsOf: namespaceDirectory.appendingPathComponent(
        "maintenance-\(maintenanceIdentifier.uuidString).json"))
    let preparation = try #require(
      JSONSerialization.jsonObject(with: preparationData) as? [String: Any])
    #expect(
      Set(preparation.keys) == [
        "format", "formatVersion", "maintenanceId", "namespaceId", "datasetId", "epochId",
        "ownershipBinding", "kind", "ruleVersion", "proposedBackup", "evidence",
      ])
    #expect(preparation["format"] as? String == "planner-maintenance-preparation")
    #expect(preparation["evidence"] as? String == "preparedUnverified")
    let preparedGraph = try #require(preparation["proposedBackup"] as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: preparedGraph))
    let digest =
      "sha256:" + SHA256.hash(data: preparationData).map { String(format: "%02x", $0) }.joined()
    #expect(maintenance["preparationDigest"] as? String == digest)
    let beforeNoOp = try maintenanceNamespaceFiles(namespaceDirectory)
    guard
      case .noReliableEvidence = await reopened.operationStatus(
        session: reopenedSession, operationId: maintenanceIdentifier),
      case .complete(let maintenanceCheckpoint) = await reopened.retryMaintenanceRecovery(
        session: reopenedSession, maintenanceId: maintenanceIdentifier),
      case .applied(let replayedItem, .complete(let replayedItemCheckpoint)) =
        await reopened.execute(
          .init(
            operationId: itemOperationIdentifier, session: reopenedSession,
            command: .createItem(content: .init(title: "Hotel")))
        ).outcome,
      case .applied(let replayedList, .complete(let replayedListCheckpoint)) =
        await reopened.execute(
          .init(
            operationId: listOperationIdentifier, session: reopenedSession,
            command: .createList(content: .init(name: "Tokyo")))
        ).outcome
    else { throw CancellationError() }
    #expect(maintenanceCheckpoint == checkpoint)
    #expect(replayedItem == createdItem && replayedItemCheckpoint == itemCheckpoint)
    #expect(replayedList == createdList && replayedListCheckpoint == listCheckpoint)
    let another = Planner(configuration: configuration)
    guard case .ready(let anotherSession) = await another.bootstrap(),
      case .exported(let reopenedData) = await another.exportData(session: anotherSession)
    else { throw CancellationError() }
    #expect(reopenedData == data)
    #expect(try maintenanceNamespaceFiles(namespaceDirectory) == beforeNoOp)
  }

  /// Simulate a second offline Remove of the other baseline contribution without forging a receipt.
  @MainActor private func insertSecondIndependentRemoval(
    storeURL: URL, deletionIdentifier: UUID
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    context.insert(
      try PlannerSchemaV4.DeletionMarker(
        .init(
          deletionId: deletionIdentifier,
          operationId: UUID(uuidString: "00000000-0000-4000-8000-000000000902")!,
          target: .membership(
            .init(
              kind: "membership", id: UUID(uuidString: "00000000-0000-4000-8000-000000000402")!,
              lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000842")!)),
          closedFamilyId: nil)))
    context.insert(
      PlannerSchemaV16.LineageRecord(
        identifier: deletionIdentifier, kind: "membershipRemoval",
        data: try JSONEncoder().encode(
          PlannerPortableMembershipRemoval(deletionId: deletionIdentifier))))
    try context.save()
  }

  @MainActor private func insertDetachedExpandedCompletion(
    storeURL: URL, entryIdentifier: UUID, membershipIdentifier: UUID, membershipLifetime: UUID
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let entry = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).first {
        $0.id == entryIdentifier
      })
    let current = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).first {
        $0.id == membershipIdentifier
      })
    let completion = PlannerSchemaV18.ExpandedCompletion(
      listEntry: entry, membership: current, localDone: true)
    completion.membershipLifetimeId = membershipLifetime
    completion.membership = nil
    context.insert(completion)
    try context.save()
  }

  @MainActor private func insertIndependentExpandedCompletion(
    storeURL: URL, entryIdentifier: UUID, membershipIdentifier: UUID, membershipLifetime: UUID
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let entry = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).first {
        $0.id == entryIdentifier
      })
    let member = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).first {
        $0.id == membershipIdentifier && $0.lifetimeId == membershipLifetime
      })
    context.insert(
      PlannerSchemaV18.ExpandedCompletion(listEntry: entry, membership: member, localDone: true))
    try context.save()
  }

  /// Model access constructs the actual persisted input; all behavioral observations use Planner.
  @MainActor private func setNativeCompletionLineageRecord(
    storeURL: URL, identifier: UUID, kind: String, content: Data?
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>()).filter {
      $0.recordIdentifier == identifier && $0.recordKind == kind
    }
    if let content {
      #expect(records.isEmpty)
      context.insert(
        PlannerSchemaV16.LineageRecord(identifier: identifier, kind: kind, data: content))
    } else {
      let record = try #require(records.first)
      #expect(records.count == 1)
      context.delete(record)
    }
    try context.save()
  }

  /// Model access constructs the actual persisted input; all behavioral observations use Planner.
  @MainActor private func removeNativeExpandedCompletion(
    storeURL: URL, entryIdentifier: UUID, membershipIdentifier: UUID
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let completion = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).first {
        $0.listEntryId == entryIdentifier && $0.membershipId == membershipIdentifier
      })
    context.delete(completion)
    try context.save()
  }

  /// Model access constructs the actual persisted input; all behavioral observations use Planner.
  @MainActor private func overwriteNativeCompletionFlag(
    storeURL: URL, appearance: PlannerAppearance, done: Bool
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    switch appearance {
    case .listMembership(_, let membershipIdentifier):
      let member = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).first {
          $0.id == membershipIdentifier
        })
      member.localDone = done
    case .directItineraryItem(_, let entryIdentifier):
      let entry = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).first {
          $0.id == entryIdentifier
        })
      entry.localDone = done
    case .expandedListItem(_, let entryIdentifier, let membershipIdentifier):
      let completion = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).first {
          $0.listEntryId == entryIdentifier && $0.membershipId == membershipIdentifier
        })
      completion.localDone = done
    }
    try context.save()
  }

  @MainActor private func insertIndependentMemberships(
    storeURL: URL, itemIdentifier: UUID, listIdentifier: UUID,
    contributions: [(identifier: String, lifetime: String, rank: Int64, done: Bool)] = [
      ("00000000-0000-4000-8000-000000000401", "00000000-0000-4000-8000-000000000841", 1024, false),
      ("00000000-0000-4000-8000-000000000402", "00000000-0000-4000-8000-000000000842", 2048, true),
    ]
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let item = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first { $0.id == itemIdentifier })
    let list = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first { $0.id == listIdentifier })
    let itemLifetime = try #require(item.lifetimeId)
    let listLifetime = try #require(list.lifetimeId)
    for (identifier, lifetime, rank, done) in contributions {
      context.insert(
        PlannerSchemaV18.Membership(
          snapshot: .init(
            id: try #require(UUID(uuidString: identifier)),
            lifetimeId: try #require(UUID(uuidString: lifetime)),
            list: .init(kind: "list", id: listIdentifier, lifetimeId: listLifetime),
            item: .init(kind: "item", id: itemIdentifier, lifetimeId: itemLifetime),
            rank: Int64(rank), localDone: done), list: list, item: item))
    }
    try context.save()
  }
}

private func maintenanceNamespaceFiles(_ directory: URL) throws -> [String: Data] {
  try Dictionary(
    uniqueKeysWithValues: FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).map {
      ($0.lastPathComponent, try Data(contentsOf: $0))
    })
}

private func initialCompletionSeedFixtures() throws -> [[String: Any]] {
  #if SWIFT_PACKAGE
    let bundle = Bundle.module
  #else
    let bundle = Bundle(for: InitialCompletionSeedFixtureBundle.self)
  #endif
  let file = try #require(
    bundle.url(
      forResource: "initial-completion-seeds-v1", withExtension: "json",
      subdirectory: "Fixtures/MembershipConsolidation"))
  let root = try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
  return try #require(root["cases"] as? [[String: Any]])
}

private final class InitialCompletionSeedFixtureBundle: NSObject {}

#if os(macOS)
  extension NativeMembershipConsolidationTests {
    @Test func interruptedPreparedMaintenanceStaysUnverifiedAndFreshBootstrapIncludesLaterInput()
      async throws
    {
      if let workPath = ProcessInfo.processInfo.environment["PLANNER_MAINTENANCE_INTERRUPT_WORK"] {
        try await runMaintenanceInterruptionChild(workDirectory: URL(fileURLWithPath: workPath))
        return
      }
      let workDirectory = try makePlannerStoreFixtureDirectory()
      try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
      try runIsolatedMaintenanceInterruption(workDirectory: workDirectory)
      let metadata = try #require(
        JSONSerialization.jsonObject(
          with: Data(
            contentsOf:
              workDirectory.appendingPathComponent("input.json"))) as? [String: Any])
      let directory = URL(fileURLWithPath: try #require(metadata["directory"] as? String))
      let configuration = PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      let namespaceIdentifier = try #require(
        (metadata["namespaceId"] as? String).flatMap(UUID.init(uuidString:)))
      let itemIdentifier = try #require(
        (metadata["itemId"] as? String).flatMap(UUID.init(uuidString:)))
      let listIdentifier = try #require(
        (metadata["listId"] as? String).flatMap(UUID.init(uuidString:)))
      let waitingIdentifier = try #require(
        (metadata["waitingOperationId"] as? String).flatMap(UUID.init(uuidString:)))
      let originalCheckpoint = try #require(metadata["checkpointGeneration"] as? Int)
      let encodedOriginalData = try #require(metadata["originalData"] as? String)
      let originalData = try #require(Data(base64Encoded: encodedOriginalData))
      let originalFiles = try #require(metadata["originalFiles"] as? [String: String])
      let proof = try #require(
        JSONSerialization.jsonObject(
          with: Data(
            contentsOf:
              workDirectory.appendingPathComponent("will-save.json"))) as? [String: Any])
      #expect(proof["preparationCount"] as? Int == 1)
      let planner = Planner(configuration: configuration)
      guard
        case .listed(let interrupted) = await planner.inspectRecovery(
          request: .namespace(namespaceId: namespaceIdentifier)),
        let preparation = interrupted.preparedMaintenance.first,
        case .selected(let selection) = await planner.inspectRecovery(
          request: .maintenanceProposal(
            namespaceId: namespaceIdentifier,
            maintenanceId: preparation.maintenanceId))
      else { throw CancellationError() }
      #expect(interrupted.preparedMaintenance.count == 1)
      #expect(interrupted.acknowledgedSnapshot?.checkpointGeneration == Int64(originalCheckpoint))
      #expect(selection.evidence == .preparedMaintenanceUnverified)
      #expect(selection.proposalId == nil && selection.originalOperationId == nil)
      #expect(selection.checkpointGeneration == nil)
      #expect(selection.decodedBackup.backup.contextAliases.count == 2)
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespaceIdentifier.uuidString)
      let interruptedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      for (name, encoded) in originalFiles {
        #expect(interruptedFiles[name] == Data(base64Encoded: encoded))
      }
      let preparationName = "maintenance-\(preparation.maintenanceId.uuidString).json"
      let preparedBytes = try #require(interruptedFiles[preparationName])
      try await insertIndependentMemberships(
        storeURL: configuration.storeURL,
        itemIdentifier: itemIdentifier, listIdentifier: listIdentifier,
        contributions: [
          (
            "00000000-0000-4000-8000-000000000403",
            "00000000-0000-4000-8000-000000000843", 3072, false
          )
        ])
      guard case .ready(let session) = await planner.bootstrap(),
        case .exported(let healedData) = await planner.exportData(session: session),
        case .decoded(let healed) = planner.decodeImport(healedData),
        case .listed(let repaired) = await planner.inspectRecovery(
          request: .namespace(namespaceId: namespaceIdentifier)),
        let healedCheckpoint = repaired.acknowledgedSnapshot?.checkpointGeneration,
        case .noReliableEvidence = await planner.operationStatus(
          session: session,
          operationId: waitingIdentifier),
        case .rejected(let uncommittedRetry) = await planner.retryMaintenanceRecovery(
          session: session, maintenanceId: preparation.maintenanceId)
      else { throw CancellationError() }
      #expect(healedCheckpoint == Int64(originalCheckpoint) + 1)
      #expect(uncommittedRetry.code == "maintenanceNotApplied")
      #expect(healed.backup.memberships.count == 1)
      #expect(healed.backup.memberships.first?.localDone == true)
      #expect(healed.backup.contextAliases.count == 3)
      #expect(healed.backup.completionChanges.isEmpty && healed.backup.deletionMarkers.isEmpty)
      let original = try #require(JSONSerialization.jsonObject(with: originalData) as? NSDictionary)
      let actual = try #require(JSONSerialization.jsonObject(with: healedData) as? NSDictionary)
      #expect((actual["sources"] as? NSArray) == (original["sources"] as? NSArray))
      let healedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      #expect(healedFiles[preparationName] == preparedBytes)
      let envelope = try #require(
        JSONSerialization.jsonObject(
          with: Data(
            contentsOf:
              namespaceDirectory.appendingPathComponent("checkpoint-\(healedCheckpoint).json")))
          as? [String: Any])
      let maintenanceReceipts = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
      #expect(maintenanceReceipts.count == 1)
      #expect(
        maintenanceReceipts.first?["maintenanceId"] as? String
          != preparation.maintenanceId.uuidString)
      let command = PlannerCommand.createTag(content: .init(name: "Waiting for maintenance"))
      guard
        case .applied(let resumed, .complete(let commandCheckpoint)) = await planner.execute(
          .init(operationId: waitingIdentifier, session: session, command: command)
        ).outcome,
        case .applied(let replayed, .complete(let repeatedCheckpoint)) = await planner.execute(
          .init(operationId: waitingIdentifier, session: session, command: command)
        ).outcome,
        case .snapshot(let tags) = await planner.query(
          .init(
            session: session,
            request: .catalog(.init(sourceKind: .tag, archive: .all))))
      else { throw CancellationError() }
      #expect(commandCheckpoint == healedCheckpoint + 1 && repeatedCheckpoint == commandCheckpoint)
      #expect(resumed == replayed && tags.matchingCount == 1)
    }

    private func runMaintenanceInterruptionChild(workDirectory: URL) async throws {
      let directory = try makePlannerStoreFixtureDirectory()
      let configuration = PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      let planner = Planner(configuration: configuration)
      guard case .ready(let session) = await planner.bootstrap(),
        case .applied(let itemCreation, .complete) = await planner.execute(
          .init(
            operationId: UUID(),
            session: session,
            command: .createItem(content: .init(title: "Hotel", notes: "Keep shared notes")))
        ).outcome,
        let item = itemCreation.generated.first,
        case .applied(let listCreation, .complete(let checkpoint)) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: "Tokyo")))
        ).outcome,
        let list = listCreation.generated.first,
        case .exported(let originalData) = await planner.exportData(session: session),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first
      else { throw CancellationError() }
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespace.namespaceId.uuidString)
      let waitingIdentifier = UUID()
      let originalFiles = try maintenanceNamespaceFiles(namespaceDirectory).mapValues {
        $0.base64EncodedString()
      }
      let metadata: [String: Any] = [
        "directory": directory.path, "namespaceId": namespace.namespaceId.uuidString,
        "itemId": item.id.uuidString, "listId": list.id.uuidString,
        "waitingOperationId": waitingIdentifier.uuidString, "checkpointGeneration": checkpoint,
        "originalData": originalData.base64EncodedString(), "originalFiles": originalFiles,
      ]
      try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]).write(
        to: workDirectory.appendingPathComponent("input.json"), options: .atomic)
      try await insertIndependentMemberships(
        storeURL: configuration.storeURL,
        itemIdentifier: item.id, listIdentifier: list.id)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.willSave,
        object: nil, queue: nil
      ) { notification in
        guard notification.object is ModelContext else { return }
        do {
          let preparations = try FileManager.default.contentsOfDirectory(
            at: namespaceDirectory,
            includingPropertiesForKeys: nil
          ).filter { $0.lastPathComponent.hasPrefix("maintenance-") }
          try JSONSerialization.data(
            withJSONObject: ["preparationCount": preparations.count],
            options: [.sortedKeys]
          ).write(to: workDirectory.appendingPathComponent("will-save.json"), options: .atomic)
        } catch {
          print("MAINTENANCE_INTERRUPT_PROOF_ERROR \(error)")
        }
        fflush(nil)
        kill(getpid(), SIGKILL)
      }
      let unexpected = await planner.execute(
        .init(
          operationId: waitingIdentifier, session: session,
          command: .createTag(content: .init(name: "Waiting for maintenance"))))
      NotificationCenter.default.removeObserver(observer)
      Issue.record("The isolated process must stop at the actual native willSave: \(unexpected)")
    }

    private func runIsolatedMaintenanceInterruption(workDirectory: URL) throws {
      let outputURL = workDirectory.appendingPathComponent("child.log")
      try Data().write(to: outputURL)
      let output = try FileHandle(forWritingTo: outputURL)
      defer { try? output.close() }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      var runnerArguments: [String] = []
      if let index = CommandLine.arguments.firstIndex(of: "--test-bundle-path"),
        CommandLine.arguments.indices.contains(index + 1)
      {
        runnerArguments = ["--test-bundle-path", CommandLine.arguments[index + 1]]
      }
      process.arguments =
        runnerArguments + [
          "--testing-library", "swift-testing", "--filter",
          "NativeMembershipConsolidationTests/interruptedPreparedMaintenanceStaysUnverifiedAndFreshBootstrapIncludesLaterInput",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_MAINTENANCE_INTERRUPT_WORK"] = workDirectory.path
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
      print("MAINTENANCE_INTERRUPTION_CHILD_LOG \(outputURL.path)")
      try JSONSerialization.data(
        withJSONObject: [
          "finishedWithinDeadline": finished,
          "terminationReason": String(describing: process.terminationReason),
          "terminationStatus": process.terminationStatus,
          "childProcessIdentifier": process.processIdentifier,
        ], options: [.sortedKeys]
      ).write(to: workDirectory.appendingPathComponent("termination.json"), options: .atomic)
      #expect(finished, "The isolated child must terminate within its deadline.")
      #expect(process.terminationReason == .uncaughtSignal)
      #expect(
        process.terminationStatus == SIGKILL, Comment(rawValue: String(transcript.suffix(12_000))))
    }

    @Test func failedMaintenanceSaveKeepsItsPreparationUnverifiedAndRetriesFresh() async throws {
      guard ProcessInfo.processInfo.environment["PLANNER_MAINTENANCE_SAVE_FAULT_CHILD"] == "1"
      else {
        try runIsolatedMaintenanceSaveFailure()
        return
      }
      let directory = try makePlannerStoreFixtureDirectory()
      let configuration = PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      let planner = Planner(configuration: configuration)
      guard case .ready(let session) = await planner.bootstrap(),
        case .applied(let itemCreation, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: "Hotel", notes: "Keep these notes")))
        ).outcome,
        let item = itemCreation.generated.first,
        case .applied(let listCreation, .complete(let originalCheckpoint)) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: "Tokyo")))
        ).outcome,
        let list = listCreation.generated.first,
        case .exported(let originalData) = await planner.exportData(session: session),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first
      else { throw CancellationError() }
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespace.namespaceId.uuidString)
      let originalFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      try await insertIndependentMemberships(
        storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id)
      let obstruction = NativeSaveFileSizeObstruction(
        configuration: configuration, maximumFileSize: 0)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.willSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let waitingIdentifier = UUID()
      let command = PlannerCommand.createTag(content: .init(name: "Waiting for maintenance"))
      let failed = await planner.execute(
        .init(operationId: waitingIdentifier, session: session, command: command))
      try obstruction.restore()
      NotificationCenter.default.removeObserver(observer)
      #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
      guard case .rejected(let failure) = failed.outcome else {
        Issue.record("A failed maintenance save must not apply the waiting command: \(failed)")
        return
      }
      #expect(failure.code == "maintenanceRequired")
      let failedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      for (name, bytes) in originalFiles { #expect(failedFiles[name] == bytes) }
      let preparations = failedFiles.filter { $0.key.hasPrefix("maintenance-") }
      #expect(preparations.count == 1)
      let failedPreparationBytes = try #require(preparations.values.first)
      let failedPreparation = try #require(
        JSONSerialization.jsonObject(with: failedPreparationBytes) as? [String: Any])
      let failedIdentifier = try #require(
        (failedPreparation["maintenanceId"] as? String).flatMap(UUID.init(uuidString:)))
      #expect(failedPreparation["evidence"] as? String == "preparedUnverified")
      guard case .status(let status) = await planner.read(session: session, request: .status),
        case .unavailable(let statusFailure) = status.recovery,
        case .rejected(let retryFailure) = await planner.retryMaintenanceRecovery(
          session: session, maintenanceId: failedIdentifier),
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: waitingIdentifier),
        case .listed(let beforeRetry) = await planner.inspectRecovery(
          request: .namespace(namespaceId: namespace.namespaceId))
      else {
        Issue.record(
          "Preparation alone must authorize neither a command nor maintenance acknowledgement.")
        return
      }
      #expect(statusFailure.code == "maintenanceRequired")
      #expect(retryFailure.code == "maintenanceNotApplied")
      #expect(beforeRetry.acknowledgedSnapshot?.checkpointGeneration == originalCheckpoint)
      #expect(try maintenanceNamespaceFiles(namespaceDirectory) == failedFiles)
      let proposed = try #require(failedPreparation["proposedBackup"] as? [String: Any])
      #expect((proposed["contextAliases"] as? [Any])?.count == 2)
      try await insertIndependentMemberships(
        storeURL: configuration.storeURL, itemIdentifier: item.id, listIdentifier: list.id,
        contributions: [
          (
            "00000000-0000-4000-8000-000000000403", "00000000-0000-4000-8000-000000000843", 3072,
            false
          )
        ])
      let reopened = Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .exported(let healedData) = await reopened.exportData(session: reopenedSession),
        case .listed(let healedView) = await reopened.inspectRecovery(
          request: .namespace(namespaceId: namespace.namespaceId)),
        let healedCheckpoint = healedView.acknowledgedSnapshot?.checkpointGeneration
      else { throw CancellationError() }
      #expect(healedCheckpoint == originalCheckpoint + 1)
      let healedFiles = try maintenanceNamespaceFiles(namespaceDirectory)
      #expect(
        healedFiles["maintenance-\(failedIdentifier.uuidString).json"] == failedPreparationBytes)
      #expect(healedFiles.keys.filter { $0.hasPrefix("maintenance-") }.count == 2)
      let envelope = try #require(
        JSONSerialization.jsonObject(
          with: Data(
            contentsOf: namespaceDirectory.appendingPathComponent(
              "checkpoint-\(healedCheckpoint).json"))) as? [String: Any])
      let maintenance = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
      #expect(maintenance.count == 1)
      let healedMaintenance = try #require(maintenance.first)
      let healedIdentifierText = try #require(healedMaintenance["maintenanceId"] as? String)
      let healedIdentifier = try #require(UUID(uuidString: healedIdentifierText))
      #expect(healedIdentifier != failedIdentifier && healedIdentifier != waitingIdentifier)
      let healed = try #require(JSONSerialization.jsonObject(with: healedData) as? [String: Any])
      let original = try #require(
        JSONSerialization.jsonObject(with: originalData) as? [String: Any])
      #expect(
        NSArray(array: try #require(healed["sources"] as? [Any])).isEqual(
          to: try #require(original["sources"] as? [Any])))
      let memberships = try #require(healed["memberships"] as? [[String: Any]])
      #expect(memberships.count == 1)
      #expect(memberships.first?["id"] as? String == "00000000-0000-4000-8000-000000000401")
      #expect(memberships.first?["localDone"] as? Bool == true)
      let healedAliases = try #require(healed["contextAliases"] as? [[String: Any]])
      #expect(healedAliases.count == 3)
      #expect(
        Set(
          healedAliases.compactMap {
            ($0["context"] as? [String: Any])?["membershipId"] as? String
          }) == [
            "00000000-0000-4000-8000-000000000401",
            "00000000-0000-4000-8000-000000000402",
            "00000000-0000-4000-8000-000000000403",
          ])
      #expect((healed["membershipProvenance"] as? [Any])?.count == 3)
      #expect((healed["completionChanges"] as? [Any])?.isEmpty == true)
      #expect((healed["deletionMarkers"] as? [Any])?.isEmpty == true)
      guard
        case .rejected(let staleRetry) = await reopened.retryMaintenanceRecovery(
          session: reopenedSession, maintenanceId: failedIdentifier),
        case .noReliableEvidence = await reopened.operationStatus(
          session: reopenedSession, operationId: waitingIdentifier)
      else { throw CancellationError() }
      #expect(staleRetry.code == "maintenanceNotApplied")
      #expect(try maintenanceNamespaceFiles(namespaceDirectory) == healedFiles)
      let resumed = await reopened.execute(
        .init(operationId: waitingIdentifier, session: reopenedSession, command: command))
      guard case .applied(_, .complete(let commandCheckpoint)) = resumed.outcome,
        case .snapshot(let tags) = await reopened.query(
          .init(session: reopenedSession, request: .catalog(.init(sourceKind: .tag, archive: .all)))
        )
      else {
        Issue.record(
          "After fresh maintenance, the original waiting command must execute once: \(resumed)")
        return
      }
      #expect(commandCheckpoint == healedCheckpoint + 1)
      #expect(tags.matchingCount == 1)
    }

    private func runIsolatedMaintenanceSaveFailure() throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "PlannerMaintenanceSaveFault-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let outputURL = directory.appendingPathComponent("child.log")
      try Data().write(to: outputURL)
      let output = try FileHandle(forWritingTo: outputURL)
      defer { try? output.close() }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      var runnerArguments: [String] = []
      if let index = CommandLine.arguments.firstIndex(of: "--test-bundle-path"),
        CommandLine.arguments.indices.contains(index + 1)
      {
        runnerArguments = ["--test-bundle-path", CommandLine.arguments[index + 1]]
      }
      process.arguments =
        runnerArguments + [
          "--testing-library", "swift-testing", "--filter",
          "NativeMembershipConsolidationTests/failedMaintenanceSaveKeepsItsPreparationUnverifiedAndRetriesFresh",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_MAINTENANCE_SAVE_FAULT_CHILD"] = "1"
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
      print("MAINTENANCE_SAVE_FAULT_CHILD_LOG \(outputURL.path)")
      #expect(finished, "The isolated maintenance save fault must finish within its deadline.")
      #expect(process.terminationReason == .exit)
      #expect(process.terminationStatus == 0, Comment(rawValue: String(transcript.suffix(12_000))))
      #expect(transcript.contains("Test run with 1 test"))
    }
  }
#endif
