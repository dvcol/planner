import Foundation
import PlannerCore
import Testing

struct ItineraryEntryMigrationTests {
  @Test func genuineV11MigrationRetainsEditedSourcesAndRecoveryBeforeAddingAnEntry() async throws {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeEntryFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(forResource: "SchemaV11", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    func configuration(_ role: PlannerStorageConfiguration.ProcessRole)
      -> PlannerStorageConfiguration
    {
      .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"), processRole: role,
        storageMode: .localOnly)
    }
    let originalControl = try Data(contentsOf: configuration(.shareExtension).controlURL)
    let share = Planner(configuration: configuration(.shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must leave migration of the real schema-11 store to the main app.")
      return
    }
    #expect(try Data(contentsOf: configuration(.shareExtension).controlURL) == originalControl)
    let planner = Planner(configuration: configuration(.mainApplication))
    let itinerary = PlannerEntityReference(kind: .itinerary, id: manifest.itineraryId)
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let list = PlannerEntityReference(kind: .list, id: manifest.listId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let itemRead)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list)),
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: manifest.namespaceId, checkpointGeneration: 11))
    else { throw CancellationError() }
    #expect(session.datasetId == manifest.datasetId)
    #expect(before.content.title == "Tokyo")
    #expect(before.content.notes == "Updated plan")
    #expect(before.content.links.first?.originalUrl == "https://example.com/route")
    #expect(before.content.categoryIds == [manifest.categoryId])
    #expect(before.content.tagIds == [manifest.tagId])
    #expect(Set(before.labels.map(\.name)) == ["Food", "Rain"])
    #expect(before.createdAt.timeIntervalSinceReferenceDate == manifest.itineraryCreatedAt)
    #expect(before.updatedAt.timeIntervalSinceReferenceDate == manifest.itineraryUpdatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: before.fieldHashes.filter { $0.key != .manualEstimate }.map {
          ($0.key.rawValue, $0.value.value)
        })
        == manifest.itineraryHashes)
    #expect(before.progress.state == .empty)
    #expect(itemRead.state.globalDone == true)
    #expect(itemRead.state.archived == true)
    #expect(itemRead.content.notes == "Original notes")
    #expect(itemRead.content.links.first?.originalUrl == "https://example.com/hotel")
    #expect(listRead.content.name == "Stops")
    #expect(listRead.progress.state == .complete)
    #expect(historical.portableData == Data(base64Encoded: manifest.portableDataBase64))
    #expect(historical.decodedBackup.backup.itineraryEntries.isEmpty)
    #expect(historical.decodedBackup.backup.memberships.first?.localDone == true)
    #expect(historical.decodedBackup.backup.schedules.count == 1)
    guard
      case .applied(let added, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
      ).outcome,
      case .source(.itinerary(let current)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(checkpoint == 12)
    #expect(namespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 16)
    #expect(current.content == before.content)
    #expect(current.fieldHashes == before.fieldHashes)
    #expect(current.progress.doneCount == 1)
    #expect(current.progress.totalCount == 1)
    #expect(current.references == before.references + added.generatedReferences)
    #expect(recovery.decodedBackup.backup.itineraryEntries.count == 1)
    #expect(recovery.decodedBackup.backup.itineraryEntries.first?.localDone == false)
    #expect(
      recovery.decodedBackup.backup.memberships == historical.decodedBackup.backup.memberships)
    #expect(recovery.decodedBackup.backup.schedules.count == 1)
  }

  private struct Manifest: Decodable {
    let datasetId: UUID
    let namespaceId: UUID
    let itemId: UUID
    let listId: UUID
    let itineraryId: UUID
    let categoryId: UUID
    let tagId: UUID
    let itineraryCreatedAt: Double
    let itineraryUpdatedAt: Double
    let itineraryHashes: [String: String]
    let portableDataBase64: String
  }
}

#if !SWIFT_PACKAGE
  private final class NativeEntryFixtureBundle: NSObject {}
#endif
