import Foundation
import PlannerCore
import Testing

struct ItineraryMigrationTests {
  @Test func genuineV10MigrationPreservesOwnedGraphBeforeItineraryCreation() async throws {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV10", withExtension: nil, subdirectory: "Fixtures"))
    let directory = try makePlannerStoreFixtureDirectory()
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    func configuration(role: PlannerStorageConfiguration.ProcessRole) -> PlannerStorageConfiguration
    {
      .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: role, storageMode: .localOnly)
    }
    let controlBefore = try Data(contentsOf: configuration(role: .shareExtension).controlURL)
    let share = Planner(configuration: configuration(role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must leave schema-10 migration to the main app.")
      return
    }
    #expect(try Data(contentsOf: configuration(role: .shareExtension).controlURL) == controlBefore)
    let planner = Planner(configuration: configuration(role: .mainApplication))
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let list = PlannerEntityReference(kind: .list, id: manifest.listId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let itemRead)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: 8))
    else {
      Issue.record("Main migration retains the real graph and its acknowledged schema-10 recovery.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    #expect(itemRead.content.title == "Hotel")
    #expect(itemRead.content.notes == "Original notes")
    #expect(itemRead.content.categoryIds == [manifest.categoryId])
    #expect(itemRead.content.tagIds == [manifest.tagId])
    #expect(Set(itemRead.labels.map(\.name)) == ["Food", "Rain"])
    #expect(itemRead.content.links.first?.linkId == manifest.linkId)
    #expect(itemRead.content.links.first?.originalUrl == "https://example.com/hotel")
    #expect(itemRead.state.globalDone == true)
    #expect(itemRead.state.archived == false)
    #expect(itemRead.createdAt.timeIntervalSinceReferenceDate == manifest.itemCreatedAt)
    #expect(itemRead.updatedAt.timeIntervalSinceReferenceDate == manifest.itemUpdatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: itemRead.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
        == manifest.itemHashes)
    #expect(
      Dictionary(
        uniqueKeysWithValues: listRead.fieldHashes.filter { $0.key != .manualEstimate }.map {
          ($0.key.rawValue, $0.value.value)
        })
        == manifest.listHashes)
    #expect(listRead.content.name == "Stops")
    #expect(listRead.state.archived == true)
    #expect(listRead.progress.doneCount == 1)
    #expect(listRead.progress.totalCount == 1)
    #expect(historical.portableData == Data(base64Encoded: manifest.portableDataBase64))
    #expect(historical.decodedBackup.backup.memberships.count == 1)
    #expect(historical.decodedBackup.backup.schedules.count == 1)
    #expect(namespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 20)
    let input = PlannerItineraryContentInput(
      title: "Tokyo", links: [.init(originalUrl: "https://example.com/route")],
      categoryIds: [manifest.categoryId], tagIds: [manifest.tagId])
    guard case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let created, .complete(let checkpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession, command: .createItinerary(content: input))
      ).outcome,
      let itinerary = created.generated.first,
      case .source(.itinerary(let itineraryRead)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let historicalAfter) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: 8)),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record(
        "After main migration, Share saves a real Itinerary through the same durable commands.")
      return
    }
    #expect(checkpoint == 10)
    #expect(itineraryRead.content.title == "Tokyo")
    #expect(Set(itineraryRead.labels.map(\.name)) == ["Food", "Rain"])
    #expect(itineraryRead.progress.state == .empty)
    #expect(afterNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 20)
    #expect(historicalAfter.portableData == historical.portableData)
    #expect(
      recovery.decodedBackup.backup.sources.filter { $0.kind == .itinerary }.map(\.id) == [
        itinerary.id
      ])
    #expect(recovery.decodedBackup.backup.labelAssociations.count == 4)
    #expect(recovery.decodedBackup.backup.memberships.count == 1)
    #expect(recovery.decodedBackup.backup.schedules.count == 1)
    #expect(
      recovery.decodedBackup.backup.items.first?.content.links.first?.linkId == manifest.linkId)
  }

  private struct Manifest: Decodable {
    let datasetId: UUID
    let namespaceId: UUID
    let itemId: UUID
    let listId: UUID
    let categoryId: UUID
    let tagId: UUID
    let itemCreatedAt: Double
    let itemUpdatedAt: Double
    let itemHashes: [String: String]
    let listHashes: [String: String]
    let linkId: UUID
    let portableDataBase64: String
  }
  #if !SWIFT_PACKAGE
    private final class NativeFixtureBundle: NSObject {}
  #endif
}
