import Foundation
import PlannerCore
import Testing

struct ItemLabelMigrationTests {
  @Test func genuineV9MigrationRetainsGraphAndAllowsShareToCreateLabelledItem() async throws {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV9", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let shareConfiguration = configuration(directory, role: .shareExtension)
    let controlBefore = try Data(contentsOf: shareConfiguration.controlURL)
    let share = Planner(configuration: shareConfiguration)
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must defer schema-9 migration to the main app.")
      return
    }
    #expect(try Data(contentsOf: shareConfiguration.controlURL) == controlBefore)
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    let category = PlannerEntityReference(kind: .category, id: manifest.categoryId)
    let tag = PlannerEntityReference(kind: .tag, id: manifest.tagId)
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.category(let retainedCategory)) = await planner.read(
        session: session, request: .source(category)),
      case .source(.tag(let retainedTag)) = await planner.read(
        session: session, request: .source(tag)),
      case .appearance(let retainedAppearance) = await planner.read(
        session: session,
        request: .appearance(
          .listMembership(
            listId: manifest.listId, membershipId: manifest.membershipId))),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint)),
      case .applied(let replayedTag, .complete(let tagCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: manifest.tagOperationId, session: session,
          command: .createTag(
            content: PlannerTagContentInput(
              name: "Rainy day", color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1),
              iconName: "cloud.rain")))
      ).outcome,
      case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let created, .complete(let checkpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Museum", categoryIds: [category.id], tagIds: [tag.id])))
      ).outcome,
      let createdItem = created.generated.first,
      case .source(.item(let read)) = await planner.read(
        session: session, request: .source(createdItem)),
      case .selected(let after) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let historicalAfter) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint)),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("Migration must preserve existing sources and allow Share to save live labels.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    #expect(retainedItem.content.title == "Hotel")
    #expect(retainedItem.content.notes == "Original notes")
    #expect(retainedItem.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(retainedItem.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: retainedItem.fieldHashes.map {
          ($0.key.rawValue, $0.value.value)
        }) == manifest.fieldHashes)
    #expect(retainedItem.state.globalDone == false)
    #expect(retainedItem.state.archived == true)
    #expect(retainedItem.labels.isEmpty)
    #expect(retainedAppearance.localDone == true)
    #expect(retainedAppearance.effectiveDone == true)
    #expect(retainedCategory.sourceLifetimeId == manifest.categoryLifetimeId)
    #expect(
      retainedCategory.content
        == PlannerCategoryContentInput(
          name: "Food", color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1),
          iconName: "fork.knife"))
    #expect(retainedCategory.references.isEmpty)
    #expect(retainedTag.sourceLifetimeId == manifest.tagLifetimeId)
    #expect(
      retainedTag.content
        == PlannerTagContentInput(
          name: "Rainy day", color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1),
          iconName: "cloud.rain"))
    #expect(retainedTag.createdAt.timeIntervalSinceReferenceDate == manifest.tagCreatedAt)
    #expect(retainedTag.updatedAt.timeIntervalSinceReferenceDate == manifest.tagUpdatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: retainedTag.fieldHashes.map {
          ($0.key.rawValue, $0.value.value)
        }) == manifest.tagFieldHashes)
    #expect(retainedTag.references.isEmpty)
    #expect(replayedTag.generated == [tag])
    #expect(tagCheckpoint == manifest.tagCheckpoint)
    #expect(checkpoint == manifest.latestCheckpoint + 1)
    #expect(read.content.categoryIds == [category.id])
    #expect(read.content.tagIds == [tag.id])
    #expect(read.labels.count == 2)
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 9)
    #expect(afterNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 15)
    #expect(historicalAfter.portableData == historical.portableData)
    let beforeData = try canonicalPortableFixtureExpectations(historical.portableData)
    let afterData = try #require(
      JSONSerialization.jsonObject(with: after.portableData)
        as? [String: Any])
    for collection in ["memberships", "ownedLinks", "schedules", "deletionMarkers"] {
      #expect(
        NSArray(array: try #require(beforeData[collection] as? [Any])).isEqual(
          to: try #require(afterData[collection] as? [Any])))
    }
    let beforeSources = try #require(beforeData["sources"] as? [[String: Any]])
    let retainedSources = try #require(afterData["sources"] as? [[String: Any]]).filter {
      $0["id"] as? String != createdItem.id.uuidString
    }
    #expect(NSArray(array: beforeSources).isEqual(to: retainedSources))
    #expect(after.decodedBackup.backup.labelAssociations.count == 2)
    #expect(afterNamespaces.first?.preparedProposals.isEmpty == true)
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
    let listId: UUID
    let membershipId: UUID
    let latestCheckpoint: Int64
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
    let categoryId: UUID
    let categoryLifetimeId: UUID
    let tagId: UUID
    let tagLifetimeId: UUID
    let tagOperationId: UUID
    let tagCheckpoint: Int64
    let tagCreatedAt: Double
    let tagUpdatedAt: Double
    let tagFieldHashes: [String: String]
  }

  #if !SWIFT_PACKAGE
    private final class NativeFixtureBundle: NSObject {}
  #endif
}
