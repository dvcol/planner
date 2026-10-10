import Foundation
import PlannerCore
import Testing

struct MembershipMigrationTests {
  @Test func genuineV6MigrationRetainsSourcesReceiptsAndRecoveryBeforeShareAddsMembership()
    async throws
  {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV6", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let shareConfiguration = configuration(directory, role: .shareExtension)
    let controlBefore = try Data(contentsOf: shareConfiguration.controlURL)
    let share = Planner(configuration: shareConfiguration)
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must not migrate the genuine schema-6 store.")
      return
    }
    #expect(try Data(contentsOf: shareConfiguration.controlURL) == controlBefore)
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let list = PlannerEntityReference(kind: .list, id: manifest.listId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let before) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint))
    else {
      Issue.record("Migration must retain the original Item and acknowledged recovery.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    #expect(originalItem.content.title == "Hotel")
    #expect(originalItem.content.notes == "Original notes")
    #expect(originalItem.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(originalItem.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: originalItem.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
        == manifest.fieldHashes)
    #expect(originalItem.state.globalDone == true)
    #expect(originalItem.state.archived == true)
    #expect(originalItem.content.links.count == 2)
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 6)
    #expect(before.decodedBackup.backup.memberships.isEmpty)
    var originalLists: [PlannerListSourceRead] = []
    for metadata in manifest.listMetadata {
      guard
        case .source(.list(let read)) = await planner.read(
          session: session,
          request: .source(PlannerEntityReference(kind: .list, id: metadata.id)))
      else {
        Issue.record("Both schema-6 Lists must survive migration.")
        return
      }
      #expect(read.createdAt.timeIntervalSinceReferenceDate == metadata.createdAt)
      #expect(read.updatedAt.timeIntervalSinceReferenceDate == metadata.updatedAt)
      #expect(
        Dictionary(uniqueKeysWithValues: read.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
          == metadata.fieldHashes)
      #expect(read.progress.state == .empty)
      originalLists.append(read)
    }
    for (identifier, hash) in [
      (manifest.retainedScheduleId, manifest.retainedScheduleHash),
      (manifest.allDayScheduleId, manifest.allDayScheduleHash),
    ] {
      guard
        case .source(.schedule(let read)) = await planner.read(
          session: session,
          request: .source(PlannerEntityReference(kind: .schedule, id: identifier)))
      else {
        Issue.record("Both Schedule forms must survive migration.")
        return
      }
      #expect(read.fieldHashes[.form]?.value == hash)
    }
    guard
      case .applied(let oldCreation, .complete(let oldCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: manifest.listCreationOperationId, session: session,
          command: .createList(
            content: PlannerListContentInput(
              name: " Tokyo Food ", notes: "Original List notes",
              color: PlannerColor(red: 0.125, green: 0.5, blue: 0.75, alpha: 1),
              iconName: "fork.knife")))
      ).outcome,
      case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let added, .complete(let checkpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      let reference = added.generatedReferences.first,
      case .source(.list(let updated)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .selected(let after) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let historical) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint)),
      case .listedNamespaces(let updatedNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record(
        "Share must save a membership after main migration while retaining original receipts.")
      return
    }
    #expect(oldCreation.generated == [list])
    #expect(oldCheckpoint == 8)
    #expect(checkpoint == 12)
    #expect(updated.references == [reference])
    #expect(updated.progress.state == .complete)
    #expect(updated.progress.doneCount == 1)
    #expect(updated.progress.totalCount == 1)
    #expect(updated.state.archived == true)
    #expect(updated.content == originalLists.first { $0.source == list }?.content)
    #expect(retained.fieldHashes == originalItem.fieldHashes)
    #expect(retained.updatedAt == originalItem.updatedAt)
    #expect(retained.content.links == originalItem.content.links)
    #expect(after.decodedBackup.backup.memberships.count == 1)
    #expect(after.decodedBackup.backup.memberships.first?.localDone == false)
    #expect(after.decodedBackup.backup.items.count == 1)
    #expect(after.decodedBackup.backup.lists.count == 2)
    #expect(after.decodedBackup.backup.schedules.count == 2)
    #expect(
      after.decodedBackup.backup.deletionMarkers == before.decodedBackup.backup.deletionMarkers)
    #expect(historical.portableData == before.portableData)
    #expect(updatedNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 8)
    #expect(updatedNamespaces.first?.preparedProposals.isEmpty == true)
    for original in originalLists where original.source != list {
      guard
        case .source(.list(let current)) = await planner.read(
          session: session, request: .source(original.source))
      else {
        Issue.record("The unrelated migrated List must remain unchanged.")
        return
      }
      #expect(current.content == original.content)
      #expect(current.updatedAt == original.updatedAt)
      #expect(current.fieldHashes == original.fieldHashes)
      #expect(current.state.archived == original.state.archived)
      #expect(current.references.isEmpty)
    }
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

  private struct ListMetadata: Decodable {
    let id: UUID
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
  }
  private struct Manifest: Decodable {
    let datasetId: UUID
    let itemId: UUID
    let listId: UUID
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
    let listMetadata: [ListMetadata]
    let latestCheckpoint: Int64
    let listCreationOperationId: UUID
    let retainedScheduleId: UUID
    let retainedScheduleHash: String
    let allDayScheduleId: UUID
    let allDayScheduleHash: String
  }
  #if !SWIFT_PACKAGE
    private final class NativeFixtureBundle: NSObject {}
  #endif
}
