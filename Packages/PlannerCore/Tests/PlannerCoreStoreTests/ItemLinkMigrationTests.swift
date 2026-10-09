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
      Issue.record("After main-app migration, Share must save owned links without losing V1 data.")
      return
    }
    #expect(nextCheckpoint == 4)
    #expect(updatedNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 3)
    #expect(newRecovery.decodedBackup.backup.sources.count == 2)
    #expect(newRecovery.decodedBackup.backup.sources.first { $0.id == item.id }?.globalDone == true)
    #expect(newRecovery.decodedBackup.backup.sources.first { $0.id == item.id }?.archived == true)
    #expect(
      newRecovery.decodedBackup.backup.sources.first { $0.id == created.generated.first?.id }?
        .content.links.first?.originalUrl == "https://example.com/menu")
  }

  @Test func mainAppMigratesV2BookmarksThenShareSavesScheduleWithoutChangingOldHistory()
    async throws
  {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV2", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      LinkedManifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    )
    let share = Planner(configuration: configuration(directory, role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must leave the real V2 store for the main app to migrate.")
      return
    }
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(let source) = await planner.read(
        session: session,
        request: .source(PlannerEntityReference(kind: .item, id: manifest.itemId)))
    else {
      Issue.record("The main app must migrate the real V2 store without losing Hotel.")
      return
    }
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    #expect(session.datasetId == manifest.datasetId)
    #expect(source.content.title == "Hotel")
    #expect(source.content.notes == "Original notes")
    #expect(source.state.globalDone == true)
    #expect(source.state.archived == true)
    #expect(source.references.count == 2)
    #expect(source.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(source.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues:
          source.fieldHashes.map { ($0.key.rawValue, $0.value.value) }) == manifest.fieldHashes)
    let expectedLinks = [
      try #require(manifest.ownedLinks.first { $0.rank == "0" }),
      try #require(manifest.ownedLinks.first { $0.rank == "1" }),
    ]
    #expect(source.content.links.map(\.linkId) == expectedLinks.map(\.id))
    #expect(
      source.content.links.map(\.originalUrl) == [
        "https://maps.apple.com/?q=Hotel", "https://example.com/menu",
      ])
    #expect(source.content.links.map(\.label) == ["Map", "Menu"])
    let originalContent = PlannerItemContentInput(
      title: "Hotel", notes: "Original notes",
      location: PlannerOwnedLocation(
        displayName: "Meeting point", formattedAddress: "Meeting point A",
        coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
      estimate: PlannerEstimate(minutes: 120, displayUnit: .hour),
      links: [
        PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
        PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu"),
      ])
    #expect(source.content.location == originalContent.location)
    #expect(source.content.estimate == originalContent.estimate)
    guard
      case .applied(let replayed, .complete(let oldCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: manifest.creationOperationId, session: session,
          command: .createItem(content: originalContent))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let oldRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 3)),
      case .ready(let shareSession) = await share.bootstrap()
    else {
      Issue.record("Migration must preserve old replay/checkpoint evidence and then permit Share.")
      return
    }
    #expect(replayed.generated == [item])
    #expect(oldCheckpoint == 1)
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 2)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(oldRecovery.decodedBackup.backup.schedules.isEmpty)
    let oldItem = try #require(oldRecovery.decodedBackup.backup.sources.first)
    #expect(oldItem.lifetimeId == manifest.ownedLinks.first?.owner.lifetimeId)
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let scheduled, .complete(let nextCheckpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .createSchedule(source: item, form: form))
      ).outcome,
      let assignment = scheduled.generated.first,
      case .source(let retained) = await planner.read(session: session, request: .source(item)),
      case .listedNamespaces(let updatedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let newRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 4)),
      case .selected(let retainedOldRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 3))
    else {
      Issue.record(
        "The migrated writer must save a new Schedule and retain both old and new recovery.")
      return
    }
    #expect(nextCheckpoint == 4)
    #expect(updatedNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 3)
    #expect(retained.content.links == source.content.links)
    #expect(retained.fieldHashes == source.fieldHashes)
    #expect(retained.updatedAt == source.updatedAt)
    #expect(retained.state.globalDone == true)
    #expect(retained.state.archived == true)
    #expect(retained.references == source.references + [.schedule(id: assignment.id, source: item)])
    #expect(newRecovery.decodedBackup.backup.schedules.first?.form == form)
    #expect(newRecovery.decodedBackup.backup.schedules.first?.id == assignment.id)
    #expect(
      newRecovery.decodedBackup.backup.schedules.first?.sourceLifetimeId == oldItem.lifetimeId)
    #expect(retainedOldRecovery.portableData == oldRecovery.portableData)
    let portable = try #require(
      JSONSerialization.jsonObject(with: newRecovery.portableData) as? [String: Any])
    let links = try #require(portable["ownedLinks"] as? [[String: Any]])
    #expect(links.count == 2)
    for expected in manifest.ownedLinks {
      let actual = try #require(links.first { $0["id"] as? String == expected.id.uuidString })
      let owner = try #require(actual["owner"] as? [String: Any])
      #expect(actual["lifetimeId"] as? String == expected.lifetimeId.uuidString)
      #expect(owner["lifetimeId"] as? String == expected.owner.lifetimeId.uuidString)
      #expect(actual["rank"] as? String == expected.rank)
    }
  }

  private struct LinkedManifest: Decodable {
    let datasetId: UUID
    let itemId: UUID
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
    let creationOperationId: UUID
    let ownedLinks: [Link]

    struct Link: Decodable {
      let id: UUID
      let lifetimeId: UUID
      let rank: String
      let owner: Owner
      struct Owner: Decodable { let lifetimeId: UUID }
    }
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
