import Foundation
import PlannerCore
import Testing

struct ManualContainerEstimateMigrationTests {
  @Test func genuineV14MigrationKeepsGraphHashesRecoveryAndLegacyCreationReplay() async throws {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeManualEstimateFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(forResource: "SchemaV14", withExtension: nil, subdirectory: "Fixtures"))
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
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: role, storageMode: .localOnly)
    }
    let controlBefore = try Data(contentsOf: configuration(.shareExtension).controlURL)
    let share = Planner(configuration: configuration(.shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      throw CancellationError()
    }
    #expect(try Data(contentsOf: configuration(.shareExtension).controlURL) == controlBefore)
    let planner = Planner(configuration: configuration(.mainApplication))
    let list = PlannerEntityReference(kind: .list, id: manifest.listId)
    let itinerary = PlannerEntityReference(kind: .itinerary, id: manifest.itineraryId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.itinerary(let itineraryRead)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: manifest.checkpoint)),
      case .exported(let dataBefore) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(session.datasetId == manifest.datasetId)
    #expect(listRead.content.manualEstimate == nil)
    #expect(itineraryRead.content.manualEstimate == nil)
    #expect(
      Dictionary(
        uniqueKeysWithValues: listRead.fieldHashes.filter { $0.key != .manualEstimate }.map {
          ($0.key.rawValue, $0.value.value)
        }) == manifest.listHashes)
    #expect(
      Dictionary(
        uniqueKeysWithValues: itineraryRead.fieldHashes.filter { $0.key != .manualEstimate }.map {
          ($0.key.rawValue, $0.value.value)
        }) == manifest.itineraryHashes)
    #expect(listRead.state.archived == true)
    #expect(itineraryRead.progress.totalCount == 4)
    #expect(itineraryRead.progress.doneCount == 2)
    #expect(historical.portableData == Data(base64Encoded: manifest.portableDataBase64))
    #expect(historical.decodedBackup.backup.schedules.count == 3)
    #expect(historical.decodedBackup.backup.memberships.count == 1)
    #expect(historical.decodedBackup.backup.itineraryEntries.count == 4)
    let checkpointObject = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf:
            directory.appendingPathComponent(
              "recovery/\(manifest.namespaceId.uuidString)/checkpoint-\(manifest.checkpoint).json"))
      ) as? [String: Any])
    let receipts = try #require(checkpointObject["receipts"] as? [[String: Any]])
    let itineraryReceipt = try #require(
      receipts.first { receipt in
        guard
          let generated = (receipt["result"] as? [String: Any])?["generated"] as? [[String: Any]]
        else { return false }
        return generated.contains {
          $0["kind"] as? String == "itinerary" && $0["id"] as? String == itinerary.id.uuidString
        }
      })
    let itineraryCreationSpelling = try #require(itineraryReceipt["operationId"] as? String)
    let itineraryCreationIdentifier = try #require(UUID(uuidString: itineraryCreationSpelling))
    guard
      case .applied(let replay, .complete) = await planner.execute(
        .init(
          operationId: manifest.listCreationIdentifier, session: session,
          command: .createList(content: .init(name: "Stops")))
      ).outcome,
      case .applied(let itineraryReplay, .complete) = await planner.execute(
        .init(
          operationId: itineraryCreationIdentifier, session: session,
          command: .createItinerary(
            content: .init(
              title: "Route", notes: "Keep route",
              links: [.init(originalUrl: "https://example.com/route")],
              categoryIds: itineraryRead.content.categoryIds, tagIds: itineraryRead.content.tagIds))
        )
      ).outcome,
      case .exported(let dataAfterReplay) = await planner.exportData(session: session),
      case .ready(let shareSession) = await share.bootstrap(),
      case .applied(_, .complete(let checkpoint)) = await share.execute(
        .init(
          operationId: UUID(), session: shareSession,
          command: .editList(
            sourceId: list.id,
            changes: .init(manualEstimate: .set(.init(minutes: 125, displayUnit: .hour))),
            expectedFieldHashes: listRead.fieldHashes))
      ).outcome,
      case .source(.list(let edited)) = await planner.read(session: session, request: .source(list)),
      case .selected(let oldAfter) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: manifest.checkpoint)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else { throw CancellationError() }
    #expect(replay.generated == [list])
    #expect(itineraryReplay.generated == [itinerary])
    let beforeObject = try JSONSerialization.jsonObject(with: dataBefore) as? [String: Any]
    let afterObject = try #require(
      JSONSerialization.jsonObject(with: dataAfterReplay) as? [String: Any])
    #expect(NSDictionary(dictionary: try #require(beforeObject)).isEqual(to: afterObject))
    #expect(edited.content.manualEstimate == .init(minutes: 125, displayUnit: .hour))
    #expect(edited.references == listRead.references)
    #expect(edited.state.archived == listRead.state.archived)
    #expect(edited.state.globalDone == listRead.state.globalDone)
    #expect(checkpoint == manifest.checkpoint + 2)
    #expect(namespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 23)
    #expect(oldAfter.portableData == historical.portableData)
  }

  private struct Manifest: Decodable {
    let datasetId: UUID
    let namespaceId: UUID
    let listId: UUID
    let itineraryId: UUID
    let checkpoint: Int64
    let listCreationIdentifier: UUID
    let listHashes: [String: String]
    let itineraryHashes: [String: String]
    let portableDataBase64: String
  }
}

#if !SWIFT_PACKAGE
  private final class NativeManualEstimateFixtureBundle: NSObject {}
#endif
