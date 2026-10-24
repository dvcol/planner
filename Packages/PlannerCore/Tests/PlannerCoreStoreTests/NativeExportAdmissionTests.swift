import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeExportAdmissionTests {
  @Test func activeExportIncludesAppliedChangesWhileIndependentRecoveryIsUnreadable()
    async throws
  {
    let fixture = try await NativeExportFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
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
    guard
      case .applied(let creation, .incomplete) = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session,
          command: .createItem(content: .init(title: "Museum", notes: "Applied notes")))
      ).outcome,
      let museum = creation.generated.first,
      case .exported(let data) = await fixture.planner.exportData(session: fixture.session)
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let sources = try #require(object["sources"] as? [[String: Any]])
    #expect(sources.count == 2)
    #expect(
      Set(sources.compactMap { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) }) == [
        fixture.source.id, museum.id,
      ])
    let exportedMuseum = try #require(
      sources.first { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) == museum.id })
    #expect((exportedMuseum["content"] as? [String: Any])?["notes"] as? String == "Applied notes")
    try obstruction.restore()
    guard
      case .status(let status) = await fixture.planner.read(
        session: fixture.session, request: .status),
      case .known(let checkpoint, let incomplete, _, let blocked) = status.recovery,
      case .appliedRecoveryIncomplete(let retainedResult, _) = await fixture.planner
        .operationStatus(
          session: fixture.session, operationId: operationIdentifier),
      case .rejected(let blockReason) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItem(content: .init(title: "Must stay blocked")))
      ).outcome,
      case .selected(let retainedRecovery) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: fixture.recovery.namespaceId, checkpointGeneration: 1))
    else { throw CancellationError() }
    #expect(checkpoint == 1 && incomplete == [operationIdentifier] && blocked)
    #expect(retainedResult == creation)
    #expect(blockReason.code == "mutationBlocked")
    #expect(retainedRecovery.portableData == fixture.recovery.portableData)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    let repeated = try #require(JSONSerialization.jsonObject(with: repeatedData) as? [String: Any])
    #expect(NSDictionary(dictionary: repeated).isEqual(to: object))
  }

  @Test(arguments: ["foreignSession", "missingStore", "unreadableStore"])
  func invalidScopeOrUnavailableStoreFailsWholeExportAndRetainsIndependentData(_ scenario: String)
    async throws
  {
    let fixture = try await NativeExportFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    var requestedSession = fixture.session
    let storeDirectory = fixture.configuration.storeURL.deletingLastPathComponent()
    let retainedDirectory = fixture.directory.appendingPathComponent("retained-store")
    if scenario == "foreignSession" {
      let foreign = Planner(configuration: fixture.configuration)
      guard case .ready(let session) = await foreign.bootstrap() else { throw CancellationError() }
      requestedSession = session
    } else {
      try FileManager.default.moveItem(at: storeDirectory, to: retainedDirectory)
      try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
      if scenario == "unreadableStore" {
        try Data("Invalid SQLite input.".utf8).write(to: fixture.configuration.storeURL)
      }
    }
    let response = await fixture.planner.exportData(session: requestedSession)
    guard case .failed(let reason) = response else {
      Issue.record("Reject the whole \(scenario) export: \(response)")
      return
    }
    #expect(!reason.message.isEmpty)
    if scenario == "foreignSession" { #expect(reason.code == "staleDatasetSession") }
    if scenario == "missingStore" {
      #expect(!FileManager.default.fileExists(atPath: fixture.configuration.storeURL.path))
    }
    guard
      case .selected(let recovery) = await fixture.planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: fixture.recovery.namespaceId, checkpointGeneration: 1))
    else { throw CancellationError() }
    #expect(recovery.portableData == fixture.recovery.portableData)
    if scenario != "foreignSession" {
      try FileManager.default.removeItem(at: storeDirectory)
      try FileManager.default.moveItem(at: retainedDirectory, to: storeDirectory)
    }
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let current)) = await reopened.read(
        session: session, request: .source(fixture.source)),
      case .exported(let retainedData) = await reopened.exportData(session: session)
    else { throw CancellationError() }
    let retainedObject = try #require(
      JSONSerialization.jsonObject(with: retainedData) as? [String: Any])
    let before = try #require(
      JSONSerialization.jsonObject(with: fixture.recovery.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: retainedObject).isEqual(to: before))
    #expect(current.content.title == "Hotel" && current.content.notes == "Original notes")
    #expect(
      current.updatedAt == fixture.item.updatedAt && current.fieldHashes == fixture.item.fieldHashes
    )
  }
}

private struct NativeExportFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let source: PlannerEntityReference
  let item: PlannerItemSourceRead
  let recovery: PlannerRecoverySelection

  static func create() async throws -> Self {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let item)) = await planner.read(session: session, request: .source(source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return .init(
      directory: directory, configuration: configuration, planner: planner, session: session,
      source: source, item: item, recovery: recovery)
  }
}
