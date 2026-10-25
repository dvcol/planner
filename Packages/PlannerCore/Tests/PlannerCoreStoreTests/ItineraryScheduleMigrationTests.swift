import Foundation
import PlannerCore
import Testing

struct ItineraryScheduleMigrationTests {
  @Test func genuineV13MigrationRetainsGraphAndSchedulesBeforeSchedulingItinerary() async throws {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeScheduleFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(forResource: "SchemaV13", withExtension: nil, subdirectory: "Fixtures"))
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
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let list = PlannerEntityReference(kind: .list, id: manifest.listId)
    let appearance = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id,
      listEntryId: manifest.entryIds[2], membershipId: manifest.membershipId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.itinerary(let before)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let retainedItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let retainedList)) = await planner.read(
        session: session, request: .source(list)),
      case .appearance(let retainedAppearance) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: manifest.checkpoint))
    else { throw CancellationError() }
    #expect(session.datasetId == manifest.datasetId)
    #expect(before.content.title == "Route")
    #expect(before.content.notes == "Keep route")
    #expect(before.content.links.first?.originalUrl == "https://example.com/route")
    #expect(Set(before.labels.map(\.name)) == ["Food", "Rain"])
    #expect(before.createdAt.timeIntervalSinceReferenceDate == manifest.itineraryCreatedAt)
    #expect(before.updatedAt.timeIntervalSinceReferenceDate == manifest.itineraryUpdatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: before.fieldHashes.filter { $0.key != .manualEstimate }.map {
          ($0.key.rawValue, $0.value.value)
        })
        == manifest.itineraryHashes)
    #expect(
      Dictionary(
        uniqueKeysWithValues: retainedItem.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
        == manifest.itemHashes)
    #expect(before.progress.totalCount == 4)
    #expect(before.progress.doneCount == 2)
    #expect(retainedList.state.archived == true)
    #expect(retainedList.progress.state == .complete)
    #expect(retainedAppearance.localDone == true)
    #expect(retainedAppearance.effectiveDone == true)
    #expect(retainedItem.state.globalDone == false)
    #expect(historical.portableData == Data(base64Encoded: manifest.portableDataBase64))
    #expect(historical.decodedBackup.backup.schedules.count == 2)
    #expect(historical.decodedBackup.backup.deletionMarkers.count == 1)
    for identifier in manifest.scheduleIds {
      guard
        case .source(.schedule(let assignment)) = await planner.read(
          session: session, request: .source(.init(kind: .schedule, id: identifier)))
      else { throw CancellationError() }
      #expect(assignment.content.source == item)
      #expect(
        historical.decodedBackup.backup.schedules.first { $0.id == identifier }?.form
          == assignment.content.form)
    }
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_214_800),
      end: nil, planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let scheduled, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createSchedule(source: itinerary, form: form))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .ready(let shareSession) = await share.bootstrap(),
      case .source(.schedule(let assignment)) = await share.read(
        session: shareSession, request: .source(schedule)),
      case .source(.itinerary(let after)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      case .selected(let current) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let historicalAfter) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: manifest.namespaceId, checkpointGeneration: manifest.checkpoint))
    else { throw CancellationError() }
    #expect(checkpoint == manifest.checkpoint + 2)
    #expect(shareSession.datasetId == session.datasetId)
    #expect(assignment.content.source == itinerary)
    #expect(assignment.content.form == form)
    #expect(after.content == before.content)
    #expect(after.fieldHashes == before.fieldHashes)
    #expect(after.updatedAt == before.updatedAt)
    #expect(after.progress.totalCount == 4)
    #expect(after.progress.doneCount == 2)
    #expect(after.references.contains(.schedule(id: schedule.id, source: itinerary)))
    #expect(namespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 20)
    #expect(historicalAfter.portableData == historical.portableData)
    #expect(current.decodedBackup.backup.schedules.count == 3)
    #expect(
      current.decodedBackup.backup.itineraryEntries
        == historical.decodedBackup.backup.itineraryEntries)
    #expect(
      current.decodedBackup.backup.expandedCompletions
        == historical.decodedBackup.backup.expandedCompletions)
    #expect(current.decodedBackup.backup.memberships == historical.decodedBackup.backup.memberships)
    #expect(
      current.decodedBackup.backup.deletionMarkers
        == historical.decodedBackup.backup.deletionMarkers)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  private struct Manifest: Decodable {
    let checkpoint: Int64
    let datasetId: UUID
    let namespaceId: UUID
    let itemId: UUID
    let listId: UUID
    let itineraryId: UUID
    let membershipId: UUID
    let entryIds: [UUID]
    let scheduleIds: [UUID]
    let itineraryCreatedAt: Double
    let itineraryUpdatedAt: Double
    let itineraryHashes: [String: String]
    let itemHashes: [String: String]
    let portableDataBase64: String
  }
}

#if !SWIFT_PACKAGE
  private final class NativeScheduleFixtureBundle: NSObject {}
#endif
