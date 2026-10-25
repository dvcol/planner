import Foundation
import SwiftData
import Testing

@testable import PlannerCore

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
    #expect(envelope["storageSchemaVersion"] as? String == "21")
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
  @Test(arguments: ["unknown", "missingWinner", "scalarLink", "scalarMembership"])
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

  @Test(arguments: ["ordinary", "recoveryFailure", "controlFailure", "unproven"])
  func compatibilityProjectionPrecedesActivationAndPhysicalRetirement(scenario: String)
    async throws
  {
    let fixture = try await SourceRestorationFixture.make()
    try await fixture.deliverCandidate()
    if scenario == "unproven" { try await fixture.makeUnresolved("unknown") }
    try fixture.rewriteCompatibility20()
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
      if scenario != "unproven" {
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
        #expect(envelope["storageSchemaVersion"] as? String == "21")
        #expect((envelope["maintenanceReceipts"] as? [Any] ?? []).isEmpty)
        let bytes = try #require(
          (envelope["portablePayloadBase64"] as? String).flatMap { Data(base64Encoded: $0) })
        #expect(try fixture.graph(bytes) == fixture.graph(fixture.baseline))
        #expect(try fixture.files().keys.filter { $0.hasPrefix("maintenance-") }.isEmpty)
      } else {
        #expect(try fixture.files() == originalFiles)
      }
      if scenario == "unproven" { return }
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
    #expect(control["schemaVersion"] as? Int == 21)
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

  @Test func failedPreparationRetainsBothNativeCandidatesUntilFreshRetry() async throws {
    let fixture = try await SourceRestorationFixture.make()
    try await fixture.deliverCandidate()
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

  @Test func committedSourceRetirementBlocksWritesUntilItsRecoveryRetry() async throws {
    let fixture = try await SourceRestorationFixture.make()
    try await fixture.deliverCandidate()
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

  func rewriteCompatibility20() throws {
    for file in [configuration.controlURL, namespace.appendingPathComponent("identity.json")] {
      var identity = try object(Data(contentsOf: file))
      identity["schemaVersion"] = 20
      try JSONSerialization.data(withJSONObject: identity).write(to: file, options: .atomic)
    }
    for (name, bytes) in try files() where name.hasPrefix("checkpoint-") {
      var envelope = try object(bytes)
      envelope["storageSchemaVersion"] = "20"
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
