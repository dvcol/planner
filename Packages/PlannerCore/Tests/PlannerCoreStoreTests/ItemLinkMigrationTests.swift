import Foundation
import PlannerCore
import Testing

struct ItemLinkMigrationTests {
  @Test func mainAppMigratesV1WithoutChangingItemIdentityStateOrAcknowledgedHistory() async throws {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV1", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let share = Planner(configuration: configuration(directory, role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must ask the main app to migrate an existing V1 store.")
      return
    }
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The main app must migrate the real V1 fixture.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    guard case .source(let source) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The migrated Item must remain retrievable by its original identity.")
      return
    }
    #expect(source.content.title == "Hotel")
    #expect(source.content.notes == "Original notes")
    #expect(source.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(source.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(source.state.globalDone == true)
    #expect(source.state.archived == true)
    #expect(source.content.links.isEmpty)
    #expect(
      source.fieldHashes.mapValues(\.value).reduce(into: [String: String]()) { result, field in
        result[field.key.rawValue] = field.value
      } == manifest.fieldHashes)
    let originalContent = PlannerItemContentInput(
      title: "Hotel", notes: "Original notes",
      location: PlannerOwnedLocation(
        displayName: "Meeting point", formattedAddress: "Meeting point A",
        coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
      estimate: PlannerEstimate(minutes: 120, displayUnit: .hour))
    #expect(source.content.location == originalContent.location)
    #expect(source.content.estimate == originalContent.estimate)
    guard
      case .applied(let replayed, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: manifest.creationOperationId, session: session,
          command: .createItem(content: originalContent))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let oldRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint))
    else {
      Issue.record("Migration must retain original replay receipts and recovery checkpoints.")
      return
    }
    #expect(replayed.generated == [item])
    #expect(checkpoint == manifest.creationCheckpoint)
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 1)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(oldRecovery.decodedBackup.backup.sources.first?.id == item.id)
    #expect(oldRecovery.decodedBackup.backup.sources.first?.globalDone == true)
    #expect(oldRecovery.decodedBackup.backup.sources.first?.archived == true)
    guard case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let created, .complete(let nextCheckpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Museum", links: [PlannerLinkInput(originalUrl: "https://example.com/menu")])))
      ).outcome,
      case .listedNamespaces(let updatedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let newRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: nextCheckpoint))
    else {
      Issue.record("After main-app migration, Share must save V2 links without losing V1 data.")
      return
    }
    #expect(nextCheckpoint == 4)
    #expect(updatedNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 2)
    #expect(newRecovery.decodedBackup.backup.sources.count == 2)
    #expect(newRecovery.decodedBackup.backup.sources.first { $0.id == item.id }?.globalDone == true)
    #expect(newRecovery.decodedBackup.backup.sources.first { $0.id == item.id }?.archived == true)
    #expect(
      newRecovery.decodedBackup.backup.sources.first { $0.id == created.generated.first?.id }?
        .content.links.first?.originalUrl == "https://example.com/menu")
  }

  private func configuration(_ directory: URL, role: PlannerStorageConfiguration.ProcessRole)
    -> PlannerStorageConfiguration
  {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: role, storageMode: .localOnly)
  }

  private struct Manifest: Decodable {
    let datasetId: UUID
    let itemId: UUID
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
    let creationOperationId: UUID
    let creationCheckpoint: Int64
    let latestCheckpoint: Int64
  }

  #if !SWIFT_PACKAGE
    private final class NativeFixtureBundle: NSObject {}
  #endif
}
