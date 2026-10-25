import Foundation
import PlannerCore
import Testing

struct ExpandedCompletionMigrationTests {
  @Test func genuineV12MigrationRetainsRepeatedEntriesAndDirectFlagsBeforeExpandedCompletion()
    async throws
  {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeExpandedFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(forResource: "SchemaV12", withExtension: nil, subdirectory: "Fixtures"))
    let directory = try makePlannerStoreFixtureDirectory()
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
      throw CancellationError()
    }
    #expect(try Data(contentsOf: configuration(.shareExtension).controlURL) == originalControl)
    let planner = Planner(configuration: configuration(.mainApplication))
    let itinerary = PlannerEntityReference(kind: .itinerary, id: manifest.itineraryId)
    let list = PlannerEntityReference(kind: .list, id: manifest.listId)
    let appearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id,
      listEntryId: manifest.entryIds[2], membershipId: manifest.membershipId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list)),
      case .appearance(let inherited) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: manifest.namespaceId, checkpointGeneration: 12))
    else { throw CancellationError() }
    #expect(session.datasetId == manifest.datasetId)
    #expect(before.content.notes == "Updated plan")
    #expect(before.progress.totalCount == 4)
    #expect(before.progress.doneCount == 1)
    #expect(before.createdAt.timeIntervalSinceReferenceDate == manifest.itineraryCreatedAt)
    #expect(before.updatedAt.timeIntervalSinceReferenceDate == manifest.itineraryUpdatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: before.fieldHashes.filter { $0.key != .manualEstimate }.map {
          ($0.key.rawValue, $0.value.value)
        })
        == manifest.itineraryHashes)
    #expect(inherited.localDone == false)
    #expect(inherited.effectiveDone == false)
    #expect(listRead.state.archived == true)
    #expect(listRead.progress.state == .complete)
    #expect(historical.portableData == Data(base64Encoded: manifest.portableDataBase64))
    #expect(historical.decodedBackup.backup.expandedCompletions.isEmpty)
    #expect(historical.decodedBackup.backup.itineraryEntries.count == 4)
    guard
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(appearance), done: true))
      ).outcome,
      case .source(.itinerary(let current)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(checkpoint == 14)
    #expect(namespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 22)
    #expect(current.content == before.content)
    #expect(current.fieldHashes == before.fieldHashes)
    #expect(current.progress.doneCount == 2)
    #expect(current.progress.totalCount == 4)
    #expect(
      recovery.decodedBackup.backup.itineraryEntries
        == historical.decodedBackup.backup.itineraryEntries)
    #expect(
      recovery.decodedBackup.backup.memberships == historical.decodedBackup.backup.memberships)
    #expect(recovery.decodedBackup.backup.expandedCompletions.first?.localDone == true)
    #expect(
      recovery.decodedBackup.backup.expandedCompletions.first?.context.listEntryId
        == manifest.entryIds[2])
  }

  private struct Manifest: Decodable {
    let datasetId: UUID
    let namespaceId: UUID
    let itemId: UUID
    let listId: UUID
    let itineraryId: UUID
    let membershipId: UUID
    let entryIds: [UUID]
    let itineraryCreatedAt: Double
    let itineraryUpdatedAt: Double
    let itineraryHashes: [String: String]
    let portableDataBase64: String
  }
}

#if !SWIFT_PACKAGE
  private final class NativeExpandedFixtureBundle: NSObject {}
#endif
