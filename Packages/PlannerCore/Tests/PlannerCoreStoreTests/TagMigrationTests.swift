import Foundation
import PlannerCore
import Testing

struct TagMigrationTests {
  @Test func genuineV8MigrationPreservesCategoryAndMembershipStateAndHistoricalRecovery()
    async throws
  {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV8", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let shareConfiguration = configuration(directory, role: .shareExtension)
    let controlBefore = try Data(contentsOf: shareConfiguration.controlURL)
    let share = Planner(configuration: shareConfiguration)
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must defer schema-8 migration to the main app.")
      return
    }
    #expect(try Data(contentsOf: shareConfiguration.controlURL) == controlBefore)
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let appearance = PlannerAppearance.listMembership(
      listId: manifest.listId, membershipId: manifest.membershipId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.category(let retainedCategory)) = await planner.read(
        session: session,
        request: .source(PlannerEntityReference(kind: .category, id: manifest.categoryId))),
      case .appearance(let retainedAppearance) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint)),
      case .applied(let replayed, .complete(let originalCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: manifest.membershipOperationId, session: session,
          command: .addMembership(itemId: item.id, listId: manifest.listId, placement: .last))
      ).outcome,
      case .applied(let replayedCategory, .complete(let categoryCheckpoint)) =
        await planner.execute(
          PlannerOperation(
            operationId: manifest.categoryOperationId, session: session,
            command: .createCategory(
              content: PlannerCategoryContentInput(
                name: "Food", color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1),
                iconName: "fork.knife")))
        ).outcome,
      case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let created, .complete(let checkpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .createTag(content: PlannerTagContentInput(name: "Food")))
      ).outcome,
      let tag = created.generated.first,
      case .source(.tag(let read)) = await planner.read(
        session: session, request: .source(tag)),
      case .selected(let after) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let historicalAfter) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint)),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record(
        "Main migration must retain the existing graph and allow Share to create a Tag.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    #expect(retainedCategory.sourceLifetimeId == manifest.categoryLifetimeId)
    #expect(
      retainedCategory.content
        == PlannerCategoryContentInput(
          name: "Food", color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1),
          iconName: "fork.knife"))
    #expect(retainedCategory.createdAt.timeIntervalSinceReferenceDate == manifest.categoryCreatedAt)
    #expect(retainedCategory.updatedAt.timeIntervalSinceReferenceDate == manifest.categoryUpdatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: retainedCategory.fieldHashes.map {
          ($0.key.rawValue, $0.value.value)
        }) == manifest.categoryFieldHashes)
    #expect(replayedCategory.generated == [retainedCategory.source])
    #expect(categoryCheckpoint == manifest.categoryCheckpoint)
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
    #expect(retainedAppearance.localDone == true)
    #expect(retainedAppearance.effectiveDone == true)
    #expect(originalCheckpoint == manifest.membershipCheckpoint)
    #expect(
      replayed.generatedReferences == [
        .membership(
          id: manifest.membershipId,
          list: PlannerEntityReference(kind: .list, id: manifest.listId), item: item)
      ])
    #expect(checkpoint == manifest.latestCheckpoint + 1)
    #expect(read.content.name == "Food")
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 8)
    #expect(afterNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 16)
    #expect(historicalAfter.portableData == historical.portableData)
    let beforeData = try canonicalPortableFixtureExpectations(historical.portableData)
    let afterData = try #require(
      JSONSerialization.jsonObject(with: after.portableData) as? [String: Any])
    for collection in ["memberships", "ownedLinks", "schedules", "deletionMarkers"] {
      #expect(
        NSArray(array: try #require(beforeData[collection] as? [Any])).isEqual(
          to: try #require(afterData[collection] as? [Any])))
    }
    let beforeSources = try #require(beforeData["sources"] as? [[String: Any]])
    let retainedSources = try #require(afterData["sources"] as? [[String: Any]]).filter {
      $0["kind"] as? String != "tag"
    }
    #expect(NSArray(array: beforeSources).isEqual(to: retainedSources))
    #expect(
      after.decodedBackup.backup.sources.count == historical.decodedBackup.backup.sources.count + 1)
    #expect(afterNamespaces.first?.preparedProposals.isEmpty == true)
  }

  private func configuration(_ directory: URL, role: PlannerStorageConfiguration.ProcessRole)
    -> PlannerStorageConfiguration
  {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"), processRole: role,
      storageMode: .localOnly)
  }

  private struct Manifest: Decodable {
    let datasetId: UUID
    let itemId: UUID
    let listId: UUID
    let membershipId: UUID
    let membershipOperationId: UUID
    let membershipCheckpoint: Int64
    let latestCheckpoint: Int64
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
    let categoryId: UUID
    let categoryLifetimeId: UUID
    let categoryOperationId: UUID
    let categoryCheckpoint: Int64
    let categoryCreatedAt: Double
    let categoryUpdatedAt: Double
    let categoryFieldHashes: [String: String]
  }

  #if !SWIFT_PACKAGE
    private final class NativeFixtureBundle: NSObject {}
  #endif
}
