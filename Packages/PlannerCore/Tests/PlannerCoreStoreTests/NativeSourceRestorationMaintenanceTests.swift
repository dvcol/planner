import Foundation
import SwiftData
import Testing

@testable import PlannerCore

#if os(macOS)
  import Darwin
#endif

struct NativeSourceRestorationMaintenanceTests {
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
    #expect(envelope["storageSchemaVersion"] as? String == "22")
    #expect(envelope["receipts"] as? NSArray == originalRecovery["receipts"] as? NSArray)
    let receipts = try #require(envelope["maintenanceReceipts"] as? [[String: Any]])
    #expect(receipts.count == 1)
    let receipt = try #require(receipts.first)
    #expect(receipt["kind"] as? String == "sourceRestorationConsolidation")
    #expect(receipt["ruleVersion"] as? Int == 1)
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
        #expect(envelope["storageSchemaVersion"] as? String == "22")
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
    #expect(control["schemaVersion"] as? Int == 22)
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
    guard case .exported(let baseline) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
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

  @MainActor func bindEntriesToLosingCandidate(_ identifiers: [UUID]) throws {
    let context = try nativeContext()
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
          #expect(identity["schemaVersion"] as? Int == 22)
          #expect(view.preparedMaintenance.count == 1)
        } else {
          #expect(identity["schemaVersion"] as? Int == (directEntries ? 21 : 20))
          #expect(view.preparedMaintenance.isEmpty)
          if stage == "beforeActivation" {
            #expect(view.acknowledgedSnapshot?.storageSchemaVersion == 22)
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
    #expect(maintenance.count == 1 && maintenance.first?["ruleVersion"] as? Int == 2)
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
  }

  @Test func portableFivePreservesAttestedSiblingBindingsWithoutReinterpretingVersionFour()
    async throws
  {
    let fixture = try await SourceRestorationFixture.make()
    var graph = try fixture.object(fixture.baseline)
    let membershipIdentifier = "00000000-0000-4000-8000-000000000403"
    let membershipLifetime = "00000000-0000-4000-8000-000000000843"
    let list: [String: Any] = [
      "kind": "list", "id": "00000000-0000-4000-8000-000000000201",
      "lifetimeId": "00000000-0000-4000-8000-000000000821",
    ]
    let item: [String: Any] = [
      "kind": "item", "id": fixture.source.id.uuidString,
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
    graph["formatVersion"] = 4
    guard
      case .invalid = fixture.planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph))
    else {
      Issue.record("Version4 must retain its exact attested-endpoint rule.")
      return
    }
    graph["formatVersion"] = 5
    let result = fixture.planner.decodeImport(try JSONSerialization.data(withJSONObject: graph))
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
